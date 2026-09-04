/* ============================================================================
   SOLAR DESIGN WIZARD
   ============================================================================
   Guided planner for PV systems from residential rooftops to utility arrays.

   What is exact vs. a starting point:
     - Panel count = ceil(needed kW × 1000 / panel W) is arithmetic. Exact for
       the inputs you typed.
     - Year-round tilt ≈ |latitude|, summer ≈ lat−15, winter ≈ lat+15, and
       azimuth 180° (N. hemisphere) / 0° (S. hemisphere) are common fixed-tilt
       rules of thumb — not a site-specific irradiance optimization.
     - Orientation factor uses a transparent cosine model of tilt and azimuth
       error. It is NOT Perez / Hay-Davies / a shade study.
     - Peak sun hours (PSH) presets are planning defaults you can edit.
     - System efficiency (soiling, temperature, wiring, inverter) is an editable
       derate, not a measured PR.
     - Storage sizing divides usable energy by DoD × round-trip η. Planning
       only — not a UL listing, fire code, or interconnection study.

   Phone orientation tool (progressive enhancement):
     DeviceOrientationEvent — beta ≈ panel tilt when the phone lies face-up on
     the module; webkitCompassHeading / alpha ≈ azimuth when the top of the
     phone points toward the skyward (high) edge of the array.
   ============================================================================ */

(function (global) {
  'use strict';

  var PSH_PRESETS = {
    arid: 6.0,
    southwest: 5.5,
    temperate: 4.5,
    mixed: 3.5,
    cloudy: 2.5,
    custom: 4.5
  };

  var SCALE_DEFAULTS = {
    residential: { eta: 80, ratio: 1.20, area: 6.0, label: 'Residential' },
    commercial: { eta: 82, ratio: 1.25, area: 5.5, label: 'Commercial' },
    utility: { eta: 85, ratio: 1.30, area: 5.0, label: 'Utility / facility' }
  };

  var sensorState = {
    listening: false,
    tilt: NaN,
    heading: NaN,
    absolute: false,
    status: 'Sensors idle'
  };

  function num(id) {
    var el = document.getElementById(id);
    if (!el) return NaN;
    var n = Number(el.value);
    return Number.isFinite(n) ? n : NaN;
  }

  function val(id) {
    var el = document.getElementById(id);
    return el ? el.value : '';
  }

  function setVal(id, v) {
    var el = document.getElementById(id);
    if (el) el.value = v;
  }

  function fmt(x, d) {
    if (!Number.isFinite(x)) return '—';
    return Number(x).toLocaleString('en-US', {
      maximumFractionDigits: d == null ? 2 : d,
      minimumFractionDigits: 0
    });
  }

  function normalizeDeg(deg) {
    if (!Number.isFinite(deg)) return NaN;
    var x = deg % 360;
    if (x < 0) x += 360;
    return x;
  }

  function azimuthError(measured, target) {
    var d = Math.abs(normalizeDeg(measured) - normalizeDeg(target));
    if (d > 180) d = 360 - d;
    return d;
  }

  function orientationAdvice(lat) {
    if (!Number.isFinite(lat) || Math.abs(lat) > 90) {
      return { error: 'Latitude must be between −90° and +90°.' };
    }
    var absLat = Math.abs(lat);
    var southern = lat < 0;
    return {
      yearRound: absLat,
      summer: Math.max(0, absLat - 15),
      winter: Math.min(90, absLat + 15),
      azimuth: southern ? 0 : 180,
      hemisphere: southern ? 'southern' : (lat > 0 ? 'northern' : 'equatorial')
    };
  }

  function orientationFactor(tilt, azimuth, advice) {
    if (!Number.isFinite(tilt) || tilt < 0 || tilt > 90) {
      return { error: 'Tilt must be between 0° and 90°.' };
    }
    if (!Number.isFinite(azimuth)) {
      return { error: 'Azimuth must be a finite compass heading.' };
    }
    var tiltErr = Math.abs(tilt - advice.yearRound);
    var azErr = azimuthError(azimuth, advice.azimuth);
    var tiltRad = tiltErr * Math.PI / 180;
    var azRad = azErr * Math.PI / 180;
    var tiltWeight = advice.yearRound * Math.PI / 180;
    var azWeight = Math.sin(Math.max(0.05, tiltWeight));
    var cosInc = Math.cos(tiltRad) * Math.cos(azRad * azWeight);
    var factor = Math.max(0.25, Math.min(1, cosInc));
    return { factor: factor, tiltErr: tiltErr, azErr: azErr };
  }

  function sizeStorage(opts) {
    var dod = opts.dod / 100;
    var rte = opts.rte / 100;
    var denom = dod * rte;
    if (!(denom > 0)) return { error: 'DoD × round-trip efficiency must be greater than zero.' };

    var usable;
    var powerKw;
    var label;

    if (opts.mode === 'peakShave') {
      if (!(opts.peakKw > 0) || !(opts.peakHours > 0)) {
        return { error: 'Peak load and duration must be greater than zero.' };
      }
      if (opts.peakHours > 24) return { error: 'Peak duration should be 24 hours or less.' };
      usable = opts.peakKw * opts.peakHours;
      powerKw = opts.peakKw;
      label = 'Peak-shave (' + fmt(opts.peakHours, 1) + ' h)';
    } else if (opts.mode === 'selfConsumption') {
      if (!(opts.selfPct > 0) || opts.selfPct > 100) {
        return { error: 'Self-consumption fraction must be greater than 0 and at most 100 %.' };
      }
      if (!(opts.dailyProd > 0)) return { error: 'Daily production must be greater than zero.' };
      usable = opts.dailyProd * (opts.selfPct / 100);
      powerKw = Math.max(opts.arrayKw * 0.4, usable / 6);
      label = 'Self-consumption (' + Math.round(opts.selfPct) + '% of daily PV)';
    } else {
      if (!(opts.days > 0)) return { error: 'Autonomy days must be greater than zero.' };
      usable = opts.dailyLoad * opts.days;
      powerKw = Math.max(opts.arrayKw * 0.5, opts.dailyLoad / 24 * 1.5);
      label = 'Autonomy (' + fmt(opts.days, 1) + ' d)';
    }

    var nameplate = usable / denom;
    var avgLoad = opts.dailyLoad / 24;
    return {
      nameplateKwh: nameplate,
      usableKwh: usable,
      autonomyHours: avgLoad > 0 ? usable / avgLoad : 0,
      powerKw: powerKw,
      label: label
    };
  }

  function design(inputs) {
    var advice = orientationAdvice(inputs.lat);
    if (advice.error) return advice;

    var orient = orientationFactor(inputs.tilt, inputs.azimuth, advice);
    if (orient.error) return orient;

    if (!(inputs.dailyLoad > 0)) return { error: 'Daily load must be greater than zero.' };
    if (!(inputs.psh > 0) || inputs.psh > 12) {
      return { error: 'Peak sun hours must be between 0 and 12.' };
    }
    if (!(inputs.panelW > 0)) return { error: 'Panel wattage must be greater than zero.' };
    if (!(inputs.eta > 0) || inputs.eta > 100) {
      return { error: 'System efficiency must be greater than 0 and at most 100 %.' };
    }
    if (!(inputs.ratio >= 0.8) || inputs.ratio > 2) {
      return { error: 'DC:AC ratio should be between 0.8 and 2.0.' };
    }

    var eta = inputs.eta / 100;
    var scale = SCALE_DEFAULTS[inputs.scale] || SCALE_DEFAULTS.residential;
    var panelCount;
    var arrayKw;

    if (inputs.panelCountOverride > 0) {
      panelCount = Math.max(1, Math.round(inputs.panelCountOverride));
      arrayKw = panelCount * inputs.panelW / 1000;
    } else {
      var denom = inputs.psh * eta * orient.factor;
      if (!(denom > 0)) return { error: 'Effective sun hours after losses must be greater than zero.' };
      var neededKw = inputs.dailyLoad / denom;
      panelCount = Math.max(1, Math.ceil(neededKw * 1000 / inputs.panelW - 1e-9));
      arrayKw = panelCount * inputs.panelW / 1000;
    }

    var dailyProd = arrayKw * inputs.psh * eta * orient.factor;
    var annual = dailyProd * 365;
    var specific = arrayKw > 0 ? annual / arrayKw : 0;
    var inverterKw = arrayKw / inputs.ratio;
    var area = arrayKw * scale.area;

    var storage = null;
    if (inputs.includeStorage) {
      storage = sizeStorage({
        mode: inputs.storageMode,
        dailyLoad: inputs.dailyLoad,
        dailyProd: dailyProd,
        days: inputs.autonomyDays,
        peakKw: inputs.peakKw,
        peakHours: inputs.peakHours,
        selfPct: inputs.selfPct,
        dod: inputs.storageDod,
        rte: inputs.storageRte,
        arrayKw: arrayKw
      });
      if (storage.error) return storage;
    }

    return {
      advice: advice,
      orient: orient,
      scale: scale,
      panelCount: panelCount,
      arrayKw: arrayKw,
      dailyProd: dailyProd,
      annual: annual,
      specific: specific,
      inverterKw: inverterKw,
      ratio: inputs.ratio,
      systemEfficiencyFraction: eta,
      psh: inputs.psh,
      area: area,
      panelW: inputs.panelW,
      storage: storage
    };
  }

  function showError(msg) {
    var el = document.getElementById('solar_result');
    if (!el) return;
    el.innerHTML = '<div class="result-error">' + msg + '</div>';
    el.classList.add('has-result');
  }

  function collectInputs() {
    var scale = val('solar_scale') || 'residential';
    var defs = SCALE_DEFAULTS[scale] || SCALE_DEFAULTS.residential;
    var pshPreset = val('solar_psh_preset') || 'temperate';
    var psh = pshPreset === 'custom' ? num('solar_psh') : (PSH_PRESETS[pshPreset] || num('solar_psh'));
    var includeStorage = !!(document.getElementById('solar_include_storage') || {}).checked;
    return {
      scale: scale,
      lat: num('solar_lat'),
      dailyLoad: num('solar_daily_kwh'),
      psh: psh,
      panelW: num('solar_panel_w'),
      tilt: num('solar_tilt'),
      azimuth: num('solar_azimuth'),
      eta: Number.isFinite(num('solar_eta')) ? num('solar_eta') : defs.eta,
      ratio: Number.isFinite(num('solar_dcac')) ? num('solar_dcac') : defs.ratio,
      panelCountOverride: num('solar_panel_count'),
      includeStorage: includeStorage,
      storageMode: val('solar_storage_mode') || 'autonomy',
      autonomyDays: num('solar_autonomy_days'),
      peakKw: num('solar_peak_kw'),
      peakHours: num('solar_peak_hours'),
      selfPct: num('solar_self_pct'),
      storageDod: Number.isFinite(num('solar_storage_dod')) ? num('solar_storage_dod') : 90,
      storageRte: Number.isFinite(num('solar_storage_rte')) ? num('solar_storage_rte') : 90
    };
  }

  function renderResult(r) {
    var el = document.getElementById('solar_result');
    if (!el) return;
    var azLabel = r.advice.azimuth === 180 ? 'true south' : (r.advice.azimuth === 0 ? 'true north' : fmt(r.advice.azimuth, 0) + '°');
    var html = '';
    html += '<div class="result-grid">';
    html += '<div class="result-stat"><span class="result-stat-label">Array DC</span><span class="result-stat-value">' + fmt(r.arrayKw, 2) + ' kW</span></div>';
    html += '<div class="result-stat"><span class="result-stat-label">Panels</span><span class="result-stat-value">' + r.panelCount + ' × ' + fmt(r.panelW, 0) + ' W</span></div>';
    html += '<div class="result-stat"><span class="result-stat-label">Inverter AC</span><span class="result-stat-value">' + fmt(r.inverterKw, 2) + ' kW</span></div>';
    html += '<div class="result-stat"><span class="result-stat-label">DC:AC</span><span class="result-stat-value">' + fmt(r.ratio, 2) + '</span></div>';
    html += '<div class="result-stat"><span class="result-stat-label">Daily production</span><span class="result-stat-value">' + fmt(r.dailyProd, 1) + ' kWh</span></div>';
    html += '<div class="result-stat"><span class="result-stat-label">Annual</span><span class="result-stat-value">' + fmt(r.annual, 0) + ' kWh</span></div>';
    html += '<div class="result-stat"><span class="result-stat-label">Specific yield</span><span class="result-stat-value">' + fmt(r.specific, 0) + ' kWh/kWp·yr</span></div>';
    html += '<div class="result-stat"><span class="result-stat-label">Footprint (approx.)</span><span class="result-stat-value">' + fmt(r.area, 0) + ' m²</span></div>';
    html += '</div>';

    html += '<div class="formula-box" style="margin-top:12px">';
    html += '<strong>Orientation</strong><br>';
    html += 'Target tilt ' + fmt(r.advice.yearRound, 1) + '° (summer ' + fmt(r.advice.summer, 1) + '° / winter ' + fmt(r.advice.winter, 1) + '°) · azimuth ' + azLabel + ' (' + r.advice.hemisphere + ')<br>';
    html += 'Your errors: tilt Δ ' + fmt(r.orient.tiltErr, 1) + '° · azimuth Δ ' + fmt(r.orient.azErr, 1) + '° → orientation factor ' + fmt(r.orient.factor * 100, 1) + '%<br>';
    html += 'System η ' + fmt(r.systemEfficiencyFraction * 100, 0) + '% · PSH ' + fmt(r.psh, 2) + ' h/day · scale ' + r.scale.label;
    html += '</div>';

    if (r.storage) {
      html += '<div class="formula-box" style="margin-top:10px">';
      html += '<strong>Energy storage — ' + r.storage.label + '</strong><br>';
      html += 'Nameplate ' + fmt(r.storage.nameplateKwh, 1) + ' kWh · usable ' + fmt(r.storage.usableKwh, 1) + ' kWh<br>';
      html += 'Recommended inverter/PCS power ≈ ' + fmt(r.storage.powerKw, 1) + ' kW · ~' + fmt(r.storage.autonomyHours, 1) + ' h at average load';
      html += '</div>';
    }

    html += '<div class="note" style="margin-top:10px">Planning aid only — not a shade study, PE stamp, interconnection application, or fire-code review. Confirm irradiance with local TMY / utility data and verify structural, electrical, and AHJ requirements.</div>';
    el.innerHTML = html;
    el.classList.add('has-result');

    if (typeof attachResultVisual === 'function') {
      try { attachResultVisual(el, 'sec-solar-wizard'); } catch (e) { /* optional */ }
    }
  }

  function calcSolarDesign() {
    var r = design(collectInputs());
    if (r.error) return showError(r.error);
    renderResult(r);
    if (typeof writeUrlState === 'function') writeUrlState('sec-solar-wizard');
  }

  function applyOptimalOrientation() {
    var advice = orientationAdvice(num('solar_lat'));
    if (advice.error) return showError(advice.error);
    setVal('solar_tilt', advice.yearRound.toFixed(1));
    setVal('solar_azimuth', String(advice.azimuth));
    updateAdviceBanner();
  }

  function onScaleChange() {
    var scale = val('solar_scale') || 'residential';
    var defs = SCALE_DEFAULTS[scale];
    if (!defs) return;
    setVal('solar_eta', defs.eta);
    setVal('solar_dcac', defs.ratio);
  }

  function onPshPresetChange() {
    var preset = val('solar_psh_preset');
    var customWrap = document.getElementById('solar_psh_custom_wrap');
    if (customWrap) customWrap.hidden = preset !== 'custom';
    if (preset !== 'custom' && PSH_PRESETS[preset] != null) {
      setVal('solar_psh', PSH_PRESETS[preset]);
    }
  }

  function onStorageToggle() {
    var on = !!(document.getElementById('solar_include_storage') || {}).checked;
    var panel = document.getElementById('solar_storage_panel');
    if (panel) panel.hidden = !on;
  }

  function onStorageModeChange() {
    var mode = val('solar_storage_mode');
    var auto = document.getElementById('solar_mode_autonomy');
    var peak = document.getElementById('solar_mode_peak');
    var selfc = document.getElementById('solar_mode_self');
    if (auto) auto.hidden = mode !== 'autonomy';
    if (peak) peak.hidden = mode !== 'peakShave';
    if (selfc) selfc.hidden = mode !== 'selfConsumption';
  }

  function updateAdviceBanner() {
    var el = document.getElementById('solar_advice_banner');
    if (!el) return;
    var advice = orientationAdvice(num('solar_lat'));
    if (advice.error) {
      el.textContent = advice.error;
      return;
    }
    var az = advice.azimuth === 180 ? 'true south (180°)' : 'true north (0°)';
    el.textContent = 'Suggested fixed tilt ' + fmt(advice.yearRound, 1) + '° (summer ' +
      fmt(advice.summer, 1) + '° / winter ' + fmt(advice.winter, 1) + '°), face ' + az +
      ' — ' + advice.hemisphere + ' hemisphere.';
  }

  /* ---------- Phone / device orientation ---------- */

  function updateSensorUI() {
    var tiltEl = document.getElementById('solar_sensor_tilt');
    var headEl = document.getElementById('solar_sensor_heading');
    var statusEl = document.getElementById('solar_sensor_status');
    var gauge = document.getElementById('solar_orient_gauge');
    if (tiltEl) tiltEl.textContent = Number.isFinite(sensorState.tilt) ? fmt(sensorState.tilt, 1) + '°' : '—';
    if (headEl) headEl.textContent = Number.isFinite(sensorState.heading) ? fmt(sensorState.heading, 0) + '°' : '—';
    if (statusEl) statusEl.textContent = sensorState.status;

    if (gauge) {
      var targetTilt = num('solar_tilt');
      var targetAz = num('solar_azimuth');
      var tip = document.getElementById('solar_gauge_tip');
      var needle = document.getElementById('solar_gauge_needle');
      if (tip && Number.isFinite(sensorState.tilt)) {
        var tipAngle = Math.max(-80, Math.min(80, sensorState.tilt - 45));
        tip.setAttribute('transform', 'rotate(' + tipAngle + ' 100 100)');
      }
      if (needle && Number.isFinite(sensorState.heading)) {
        needle.setAttribute('transform', 'rotate(' + sensorState.heading + ' 100 100)');
      }
      var matchEl = document.getElementById('solar_sensor_match');
      if (matchEl && Number.isFinite(sensorState.tilt) && Number.isFinite(sensorState.heading) &&
          Number.isFinite(targetTilt) && Number.isFinite(targetAz)) {
        var tErr = Math.abs(sensorState.tilt - targetTilt);
        var aErr = azimuthError(sensorState.heading, targetAz);
        var ok = tErr <= 3 && aErr <= 8;
        matchEl.textContent = ok
          ? 'Aligned — within ±3° tilt and ±8° azimuth of targets.'
          : 'Δ tilt ' + fmt(tErr, 1) + '° · Δ azimuth ' + fmt(aErr, 1) + '° — adjust the array (or the phone).';
        matchEl.className = 'note ' + (ok ? 'solar-match-ok' : 'solar-match-off');
      }
    }
  }

  function onDeviceOrientation(ev) {
    // beta: front-back tilt (−180…180). Face-up on a panel ≈ panel tilt from horizontal when |gamma| is small.
    var beta = ev.beta;
    var gamma = ev.gamma;
    if (Number.isFinite(beta) && Number.isFinite(gamma)) {
      // Combined tilt of the device face from horizontal.
      var radB = beta * Math.PI / 180;
      var radG = gamma * Math.PI / 180;
      var cosInc = Math.cos(radB) * Math.cos(radG);
      cosInc = Math.max(-1, Math.min(1, cosInc));
      sensorState.tilt = Math.acos(Math.abs(cosInc)) * 180 / Math.PI;
    }

    var heading = NaN;
    if (typeof ev.webkitCompassHeading === 'number' && Number.isFinite(ev.webkitCompassHeading)) {
      heading = ev.webkitCompassHeading;
      sensorState.absolute = true;
    } else if (ev.absolute && Number.isFinite(ev.alpha)) {
      // alpha is degrees from north clockwise when absolute is true (W3C).
      heading = normalizeDeg(360 - ev.alpha);
      sensorState.absolute = true;
    } else if (Number.isFinite(ev.alpha)) {
      heading = normalizeDeg(360 - ev.alpha);
      sensorState.absolute = false;
    }
    if (Number.isFinite(heading)) sensorState.heading = heading;

    sensorState.status = sensorState.absolute
      ? 'Live — absolute / compass heading'
      : 'Live — relative heading (calibrate outdoors if possible)';
    updateSensorUI();
  }

  function stopSolarSensors() {
    if (!sensorState.listening) return;
    window.removeEventListener('deviceorientationabsolute', onDeviceOrientation);
    window.removeEventListener('deviceorientation', onDeviceOrientation);
    sensorState.listening = false;
    sensorState.status = 'Sensors stopped';
    updateSensorUI();
  }

  function startSolarSensors() {
    if (sensorState.listening) return;

    function attach() {
      // Prefer absolute when available.
      if ('ondeviceorientationabsolute' in window) {
        window.addEventListener('deviceorientationabsolute', onDeviceOrientation, true);
      }
      window.addEventListener('deviceorientation', onDeviceOrientation, true);
      sensorState.listening = true;
      sensorState.status = 'Listening for DeviceOrientation…';
      updateSensorUI();
    }

    var DOE = window.DeviceOrientationEvent;
    if (DOE && typeof DOE.requestPermission === 'function') {
      DOE.requestPermission().then(function (state) {
        if (state === 'granted') attach();
        else {
          sensorState.status = 'Orientation permission denied — enter tilt/azimuth manually.';
          updateSensorUI();
        }
      }).catch(function () {
        sensorState.status = 'Could not request orientation permission.';
        updateSensorUI();
      });
    } else if (window.DeviceOrientationEvent) {
      attach();
    } else {
      sensorState.status = 'Device orientation is not available in this browser.';
      updateSensorUI();
    }
  }

  function useSensorForDesign() {
    if (!Number.isFinite(sensorState.tilt) || !Number.isFinite(sensorState.heading)) {
      return showError('Start the phone sensors and hold the phone on the panel first.');
    }
    setVal('solar_tilt', sensorState.tilt.toFixed(1));
    setVal('solar_azimuth', Math.round(sensorState.heading));
    calcSolarDesign();
  }

  function exampleResidential() {
    setVal('solar_scale', 'residential');
    onScaleChange();
    setVal('solar_lat', '40');
    setVal('solar_daily_kwh', '30');
    setVal('solar_psh_preset', 'temperate');
    onPshPresetChange();
    setVal('solar_panel_w', '400');
    setVal('solar_panel_count', '');
    applyOptimalOrientation();
    var storage = document.getElementById('solar_include_storage');
    if (storage) storage.checked = true;
    onStorageToggle();
    setVal('solar_storage_mode', 'autonomy');
    onStorageModeChange();
    setVal('solar_autonomy_days', '1');
    setVal('solar_storage_dod', '90');
    setVal('solar_storage_rte', '90');
    calcSolarDesign();
  }

  function exampleUtility() {
    setVal('solar_scale', 'utility');
    onScaleChange();
    setVal('solar_lat', '33');
    setVal('solar_daily_kwh', '50000');
    setVal('solar_psh_preset', 'southwest');
    onPshPresetChange();
    setVal('solar_panel_w', '550');
    setVal('solar_panel_count', '');
    applyOptimalOrientation();
    var storage = document.getElementById('solar_include_storage');
    if (storage) storage.checked = true;
    onStorageToggle();
    setVal('solar_storage_mode', 'peakShave');
    onStorageModeChange();
    setVal('solar_peak_kw', '2000');
    setVal('solar_peak_hours', '4');
    calcSolarDesign();
  }

  // Expose for onclick / tests
  global.calcSolarDesign = calcSolarDesign;
  global.solarApplyOptimalOrientation = applyOptimalOrientation;
  global.solarOnScaleChange = onScaleChange;
  global.solarOnPshPresetChange = onPshPresetChange;
  global.solarOnStorageToggle = onStorageToggle;
  global.solarOnStorageModeChange = onStorageModeChange;
  global.solarStartSensors = startSolarSensors;
  global.solarStopSensors = stopSolarSensors;
  global.solarUseSensorForDesign = useSensorForDesign;
  global.solarExampleResidential = exampleResidential;
  global.solarExampleUtility = exampleUtility;
  global.solarUpdateAdvice = updateAdviceBanner;
  global.__solarWizardTestApi = {
    design: design,
    orientationAdvice: orientationAdvice,
    orientationFactor: orientationFactor,
    sizeStorage: sizeStorage,
    azimuthError: azimuthError,
    PSH_PRESETS: PSH_PRESETS,
    SCALE_DEFAULTS: SCALE_DEFAULTS
  };

  document.addEventListener('DOMContentLoaded', function () {
    onPshPresetChange();
    onStorageToggle();
    onStorageModeChange();
    updateAdviceBanner();
    var lat = document.getElementById('solar_lat');
    if (lat) lat.addEventListener('change', updateAdviceBanner);
    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-solar-wizard', 'solar-wizard', function () {
        calcSolarDesign();
      });
    }
  });
})(typeof window !== 'undefined' ? window : globalThis);
