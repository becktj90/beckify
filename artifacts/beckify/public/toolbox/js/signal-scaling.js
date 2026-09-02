/* ============================================================================
   PROCESS VALUE / SIGNAL SCALING CALCULATOR
   ============================================================================
   Linear scaling between a raw instrument signal and engineering units.

     eng = engMin + (raw − rawMin) × (engMax − engMin) / (rawMax − rawMin)
     raw = rawMin + (eng − engMin) × (rawMax − rawMin) / (engMax − engMin)

   Live, both directions. 4–20 mA flags values below 4 mA (live-zero / under-
   range) or above 20 mA (over-range). Design aid — not a PE stamp, not a
   transmitter configuration download.
   ============================================================================ */

(function (global) {
  'use strict';

  const PRESET_KEY = 'beckify-signal-scaling-presets';

  const SIGNAL_TYPES = {
    '4-20mA': { label: '4–20 mA', rawMin: 4, rawMax: 20, rawUnit: 'mA', liveZero: true },
    '0-20mA': { label: '0–20 mA', rawMin: 0, rawMax: 20, rawUnit: 'mA', liveZero: false },
    '0-10V': { label: '0–10 V', rawMin: 0, rawMax: 10, rawUnit: 'V', liveZero: false },
    '1-5V': { label: '1–5 V', rawMin: 1, rawMax: 5, rawUnit: 'V', liveZero: false },
    'adc-12u': { label: 'ADC 12-bit unsigned', rawMin: 0, rawMax: 4095, rawUnit: 'counts', liveZero: false },
    'adc-16u': { label: 'ADC 16-bit unsigned', rawMin: 0, rawMax: 65535, rawUnit: 'counts', liveZero: false },
    'adc-16-420': { label: '16-bit 4–20 mA counts (6554–32767)', rawMin: 6554, rawMax: 32767, rawUnit: 'counts', liveZero: false },
    'adc-12s': { label: 'ADC 12-bit signed', rawMin: -2048, rawMax: 2047, rawUnit: 'counts', liveZero: false },
    'adc-16s': { label: 'ADC 16-bit signed', rawMin: -32768, rawMax: 32767, rawUnit: 'counts', liveZero: false },
    'rtd-pt100': { label: 'RTD Pt100 (resistance Ω, linear)', rawMin: 100, rawMax: 138.51, rawUnit: 'Ω', liveZero: false },
    'rtd-counts': { label: 'RTD / skip to linear counts', rawMin: 0, rawMax: 32767, rawUnit: 'counts', liveZero: false },
  };

  /* Pressure stored as psi; temperature as °C; flow as gpm. */
  const UNIT_FAMILIES = {
    pressure: {
      label: 'Pressure',
      units: {
        psi: { label: 'psi', toBase: 1 },
        kPa: { label: 'kPa', toBase: 1 / 6.894757293168 },
        bar: { label: 'bar', toBase: 14.503773773 },
        inH2O: { label: 'inH2O', toBase: 1 / 27.6799048 },
      },
    },
    temperature: {
      label: 'Temperature',
      units: {
        C: { label: '°C', affine: true },
        F: { label: '°F', affine: true },
        K: { label: 'K', affine: true },
      },
    },
    flow: {
      label: 'Flow',
      units: {
        gpm: { label: 'gpm', toBase: 1 },
        lpm: { label: 'lpm', toBase: 1 / 3.785411784 },
      },
    },
    percent: {
      label: 'Percent',
      units: { pct: { label: '%', toBase: 1 } },
    },
    custom: {
      label: 'Custom',
      units: { custom: { label: '', toBase: 1 } },
    },
  };

  function toCelsius(value, unit) {
    if (unit === 'C') return value;
    if (unit === 'F') return (value - 32) * 5 / 9;
    if (unit === 'K') return value - 273.15;
    return value;
  }

  function fromCelsius(c, unit) {
    if (unit === 'C') return c;
    if (unit === 'F') return c * 9 / 5 + 32;
    if (unit === 'K') return c + 273.15;
    return c;
  }

  function convertEng(value, family, fromUnit, toUnit) {
    if (fromUnit === toUnit) return value;
    if (family === 'temperature') return fromCelsius(toCelsius(value, fromUnit), toUnit);
    const fam = UNIT_FAMILIES[family];
    if (!fam || !fam.units[fromUnit] || !fam.units[toUnit]) return value;
    const base = value * fam.units[fromUnit].toBase;
    return base / fam.units[toUnit].toBase;
  }

  function unitLabel(family, unit, customText) {
    if (family === 'custom') return String(customText || '').trim() || 'EU';
    const fam = UNIT_FAMILIES[family];
    if (!fam || !fam.units[unit]) return unit;
    return fam.units[unit].label;
  }

  function linearMap(x, x0, x1, y0, y1) {
    const dx = x1 - x0;
    if (!isFinite(x) || !isFinite(x0) || !isFinite(x1) || !isFinite(y0) || !isFinite(y1)) {
      return { ok: false, error: 'All ranges and the input must be finite numbers.' };
    }
    if (dx === 0) {
      return { ok: false, error: 'Signal range span is zero — pick distinct raw min and max.' };
    }
    return { ok: true, value: y0 + (x - x0) * (y1 - y0) / dx };
  }

  function scaleForward(raw, rawMin, rawMax, engMin, engMax, law) {
    if (law !== 'sqrt') return linearMap(raw, rawMin, rawMax, engMin, engMax);
    const dx = rawMax - rawMin;
    if (!isFinite(raw) || !isFinite(rawMin) || !isFinite(rawMax) || !isFinite(engMin) || !isFinite(engMax)) {
      return { ok: false, error: 'All ranges and the input must be finite numbers.' };
    }
    if (dx === 0) return { ok: false, error: 'Signal range span is zero — pick distinct raw min and max.' };
    const t = (raw - rawMin) / dx;
    if (t < 0) return { ok: false, error: 'Square-root scale is not real below the raw minimum.' };
    return { ok: true, value: engMin + (engMax - engMin) * Math.sqrt(t) };
  }

  function scaleReverse(eng, rawMin, rawMax, engMin, engMax, law) {
    if (law !== 'sqrt') return linearMap(eng, engMin, engMax, rawMin, rawMax);
    const dy = engMax - engMin;
    if (!isFinite(eng) || !isFinite(rawMin) || !isFinite(rawMax) || !isFinite(engMin) || !isFinite(engMax)) {
      return { ok: false, error: 'All ranges and the input must be finite numbers.' };
    }
    if (dy === 0) return { ok: false, error: 'Engineering range span is zero — pick distinct eng min and max.' };
    const t = (eng - engMin) / dy;
    if (t < 0) return { ok: false, error: 'Square-root reverse is not real below the engineering minimum.' };
    return { ok: true, value: rawMin + (rawMax - rawMin) * (t * t) };
  }

  function formatNum(n, digits) {
    if (!isFinite(n)) return '—';
    const d = digits === undefined || digits === null ? 6 : digits;
    const s = Number(n).toPrecision(d);
    return String(Number(s));
  }

  function pluggedFormula(x, x0, x1, y0, y1, y, xName, yName, xUnit, yUnit, law) {
    if (law === 'sqrt') {
      const t = (x - x0) / (x1 - x0);
      return yName + ' = ' + formatNum(y0) + ' + (' + formatNum(y1) + ' − ' + formatNum(y0) + ') × √((' +
        formatNum(x) + ' − ' + formatNum(x0) + ') / (' + formatNum(x1) + ' − ' + formatNum(x0) + '))\n' +
        '    = ' + formatNum(y0) + ' + (' + formatNum(y1 - y0) + ') × √(' + formatNum(t) + ')\n' +
        '    = ' + formatNum(y) + ' ' + yUnit +
        '\nwhere ' + xName + ' = ' + formatNum(x) + ' ' + xUnit + ' (DP / square-root flow)';
    }
    const spanY = y1 - y0;
    const spanX = x1 - x0;
    return yName + ' = ' + formatNum(y0) + ' + (' + formatNum(x) + ' − ' + formatNum(x0) + ') × (' +
      formatNum(y1) + ' − ' + formatNum(y0) + ') / (' + formatNum(x1) + ' − ' + formatNum(x0) + ')\n' +
      '    = ' + formatNum(y0) + ' + (' + formatNum(x - x0) + ') × (' + formatNum(spanY) + ') / (' + formatNum(spanX) + ')\n' +
      '    = ' + formatNum(y) + ' ' + yUnit +
      '\nwhere ' + xName + ' = ' + formatNum(x) + ' ' + xUnit;
  }

  /**
   * 4–20 mA live-zero / range flags. Values below 4 mA are a live-zero fault
   * (0% is 4 mA, not 0 mA). Values above 20 mA are over-range. Other signal
   * types only flag when raw is outside the configured raw min/max.
   */
  function rangeFlags(signalType, raw, rawMin, rawMax) {
    const flags = {
      outOfRange: false,
      liveZeroFault: false,
      underRange: false,
      overRange: false,
      message: '',
    };
    if (!isFinite(raw)) return flags;
    if (signalType === '4-20mA') {
      if (raw < 4) {
        flags.outOfRange = true;
        flags.liveZeroFault = true;
        flags.underRange = true;
        flags.message = 'Below 4 mA: live-zero fault / under-range (0% is 4 mA, not 0 mA).';
      } else if (raw > 20) {
        flags.outOfRange = true;
        flags.overRange = true;
        flags.message = 'Above 20 mA: over-range.';
      }
      return flags;
    }
    if (raw < rawMin) {
      flags.outOfRange = true;
      flags.underRange = true;
      flags.message = 'Below the configured signal minimum.';
    } else if (raw > rawMax) {
      flags.outOfRange = true;
      flags.overRange = true;
      flags.message = 'Above the configured signal maximum.';
    }
    return flags;
  }

  /* IEC 60751 Callendar–Van Dusen helper for Pt100, R0 = 100 Ω. Optional
     readout when the signal type is resistance — the main scale stays linear. */
  function pt100TemperatureC(ohms) {
    const R0 = 100;
    const A = 3.9083e-3;
    const B = -5.775e-7;
    const C = -4.183e-12;
    if (!isFinite(ohms) || ohms <= 0) return { ok: false, error: 'Resistance must be positive.' };
    if (ohms >= R0) {
      const disc = A * A - 4 * B * (1 - ohms / R0);
      if (disc < 0) return { ok: false, error: 'Resistance is outside the IEC 60751 positive branch.' };
      const t = (-A + Math.sqrt(disc)) / (2 * B);
      return { ok: true, c: t };
    }
    // Negative temperatures: iterate R = R0 (1 + A t + B t² + C (t−100) t³).
    let t = (ohms / R0 - 1) / A;
    for (let i = 0; i < 12; i++) {
      const r = R0 * (1 + A * t + B * t * t + C * (t - 100) * t * t * t);
      const dr = R0 * (A + 2 * B * t + C * (4 * t * t * t - 300 * t * t));
      if (Math.abs(dr) < 1e-12) break;
      t -= (r - ohms) / dr;
    }
    return { ok: true, c: t };
  }

  function loadPresets() {
    try {
      const raw = global.localStorage && localStorage.getItem(PRESET_KEY);
      const list = raw ? JSON.parse(raw) : [];
      return Array.isArray(list) ? list : [];
    } catch (_) {
      return [];
    }
  }

  function savePresets(list) {
    try {
      if (global.localStorage) localStorage.setItem(PRESET_KEY, JSON.stringify(list));
    } catch (_) { /* private mode / quota */ }
  }

  function el(id) { return document.getElementById(id); }

  function num(id, fallback) {
    const node = el(id);
    if (!node) return fallback;
    const v = Number(node.value);
    return isFinite(v) ? v : fallback;
  }

  function setVal(id, value) {
    const node = el(id);
    if (node) node.value = value;
  }

  function currentUnit() {
    const family = (el('ssc_family') && el('ssc_family').value) || 'pressure';
    const unit = (el('ssc_unit') && el('ssc_unit').value) || 'psi';
    const custom = (el('ssc_custom') && el('ssc_custom').value) || '';
    return { family: family, unit: unit, custom: custom, label: unitLabel(family, unit, custom) };
  }

  function fillUnitSelect(family, selected) {
    const sel = el('ssc_unit');
    if (!sel) return;
    const fam = UNIT_FAMILIES[family] || UNIT_FAMILIES.pressure;
    const keys = Object.keys(fam.units);
    sel.innerHTML = keys.map(function (k) {
      return '<option value="' + k + '"' + (k === selected ? ' selected' : '') + '>' + fam.units[k].label + '</option>';
    }).join('');
    const wrap = el('ssc_custom_wrap');
    if (wrap) wrap.hidden = family !== 'custom';
  }

  let lastFamily = 'pressure';
  let lastUnit = 'psi';
  let applying = false;

  function applySignalType(key, keepRaw) {
    const spec = SIGNAL_TYPES[key] || SIGNAL_TYPES['4-20mA'];
    if (!keepRaw) {
      setVal('ssc_raw_min', spec.rawMin);
      setVal('ssc_raw_max', spec.rawMax);
    }
    const rawLab = el('ssc_raw_unit_label');
    if (rawLab) rawLab.textContent = spec.rawUnit;
    const hint = el('ssc_rtd_hint');
    if (hint) hint.hidden = key !== 'rtd-pt100';
  }

  function readState() {
    const signalType = (el('ssc_type') && el('ssc_type').value) || '4-20mA';
    const u = currentUnit();
    return {
      signalType: signalType,
      raw: num('ssc_raw', 0),
      rawMin: num('ssc_raw_min', 0),
      rawMax: num('ssc_raw_max', 1),
      eng: num('ssc_eng', 0),
      engMin: num('ssc_eng_min', 0),
      engMax: num('ssc_eng_max', 100),
      family: u.family,
      unit: u.unit,
      custom: u.custom,
      unitLabel: u.label,
      law: (el('ssc_law') && el('ssc_law').value) || 'linear',
    };
  }

  function renderPresets() {
    const host = el('ssc_preset_list');
    if (!host) return;
    const list = loadPresets();
    if (!list.length) {
      host.innerHTML = '<p class="note">No named presets yet. Save the current ranges (for example “PT-204 0–500 psi 4–20mA”).</p>';
      return;
    }
    host.innerHTML = '<ul class="ssc-preset-ul">' + list.map(function (p, i) {
      return '<li><button type="button" class="btn btn-secondary btn-sm" data-ssc-recall="' + i + '">' +
        escapeHtml(p.name) + '</button>' +
        '<button type="button" class="btn-remove" data-ssc-del="' + i + '" aria-label="Delete preset ' + escapeHtml(p.name) + '">×</button></li>';
    }).join('') + '</ul>';
  }

  function escapeHtml(s) {
    return String(s === undefined || s === null ? '' : s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function updateSliderBounds(st) {
    const slider = el('ssc_slider');
    if (!slider) return;
    const lo = Math.min(st.rawMin, st.rawMax);
    const hi = Math.max(st.rawMin, st.rawMax);
    slider.min = String(lo);
    slider.max = String(hi);
    slider.step = hi - lo > 100 ? '1' : '0.01';
    if (!applying) slider.value = String(st.raw);
  }

  function render(source) {
    if (applying) return;
    const st = readState();
    updateSliderBounds(st);
    const spec = SIGNAL_TYPES[st.signalType] || SIGNAL_TYPES['4-20mA'];

    const law = st.law || 'linear';
    let raw = st.raw;
    let eng = st.eng;
    if (source === 'eng') {
      const rev = scaleReverse(st.eng, st.rawMin, st.rawMax, st.engMin, st.engMax, law);
      if (rev.ok) {
        raw = rev.value;
        applying = true;
        setVal('ssc_raw', formatNum(raw, 8));
        const slider = el('ssc_slider');
        if (slider) slider.value = String(raw);
        applying = false;
      }
    } else {
      const fwd = scaleForward(st.raw, st.rawMin, st.rawMax, st.engMin, st.engMax, law);
      if (fwd.ok) {
        eng = fwd.value;
        applying = true;
        setVal('ssc_eng', formatNum(eng, 8));
        applying = false;
      }
    }

    const fwd = scaleForward(raw, st.rawMin, st.rawMax, st.engMin, st.engMax, law);
    const rev = scaleReverse(eng, st.rawMin, st.rawMax, st.engMin, st.engMax, law);
    const flags = rangeFlags(st.signalType, raw, st.rawMin, st.rawMax);

    const fwdHost = el('ssc_fwd_formula');
    if (fwdHost) {
      if (fwd.ok) {
        fwdHost.textContent = pluggedFormula(
          raw, st.rawMin, st.rawMax, st.engMin, st.engMax, fwd.value,
          'raw', 'eng', spec.rawUnit, st.unitLabel, law
        );
      } else {
        fwdHost.textContent = fwd.error;
      }
    }
    const revHost = el('ssc_rev_formula');
    if (revHost) {
      if (rev.ok) {
        if (law === 'sqrt') {
          const t = (eng - st.engMin) / (st.engMax - st.engMin);
          revHost.textContent = 'raw = ' + formatNum(st.rawMin) + ' + (' + formatNum(st.rawMax) + ' − ' + formatNum(st.rawMin) +
            ') × ((' + formatNum(eng) + ' − ' + formatNum(st.engMin) + ') / (' + formatNum(st.engMax) + ' − ' + formatNum(st.engMin) + '))²\n' +
            '    = ' + formatNum(st.rawMin) + ' + (' + formatNum(st.rawMax - st.rawMin) + ') × (' + formatNum(t) + ')²\n' +
            '    = ' + formatNum(rev.value) + ' ' + spec.rawUnit +
            '\nwhere eng = ' + formatNum(eng) + ' ' + st.unitLabel + ' (DP / square-root flow)';
        } else {
          revHost.textContent = pluggedFormula(
            eng, st.engMin, st.engMax, st.rawMin, st.rawMax, rev.value,
            'eng', 'raw', st.unitLabel, spec.rawUnit, law
          );
        }
      } else {
        revHost.textContent = rev.error;
      }
    }

    const live = el('ssc_live');
    if (live) {
      live.classList.add('show');
      live.classList.toggle('error', flags.outOfRange);
      let html = '<div class="res-row"><span class="res-label">Engineering value</span><span class="res-val">' +
        (fwd.ok ? formatNum(fwd.value) + ' ' + escapeHtml(st.unitLabel) : '—') + '</span></div>';
      html += '<div class="res-row"><span class="res-label">Raw to inject</span><span class="res-val">' +
        (rev.ok ? formatNum(rev.value) + ' ' + escapeHtml(spec.rawUnit) : '—') + '</span></div>';
      html += '<div class="res-row"><span class="res-label">Span</span><span class="res-val">' +
        formatNum(st.rawMin) + '–' + formatNum(st.rawMax) + ' ' + escapeHtml(spec.rawUnit) +
        ' → ' + formatNum(st.engMin) + '–' + formatNum(st.engMax) + ' ' + escapeHtml(st.unitLabel) + '</span></div>';
      if (flags.message) {
        html += '<div class="res-row"><span class="res-label">Range</span><span class="res-val">' + escapeHtml(flags.message) + '</span></div>';
      }
      if (st.signalType === 'rtd-pt100') {
        const pt = pt100TemperatureC(raw);
        if (pt.ok) {
          html += '<div class="res-row"><span class="res-label">IEC 60751 Pt100 (ref.)</span><span class="res-val">' +
            formatNum(pt.c) + ' °C — not used by the linear scale</span></div>';
        }
      }
      live.innerHTML = html;
    }

    const flagEl = el('ssc_flag');
    if (flagEl) {
      flagEl.hidden = !flags.outOfRange;
      flagEl.textContent = flags.message;
      flagEl.classList.toggle('ssc-flag-fault', flags.liveZeroFault);
    }
  }

  function onFamilyChange() {
    const family = (el('ssc_family') && el('ssc_family').value) || 'pressure';
    const nextDefault = Object.keys((UNIT_FAMILIES[family] || UNIT_FAMILIES.pressure).units)[0];
    const st = readState();
    const convertedMin = convertEng(st.engMin, lastFamily, lastUnit, nextDefault);
    const convertedMax = convertEng(st.engMax, lastFamily, lastUnit, nextDefault);
    const convertedEng = convertEng(st.eng, lastFamily, lastUnit, nextDefault);
    fillUnitSelect(family, nextDefault);
    applying = true;
    setVal('ssc_eng_min', formatNum(convertedMin, 8));
    setVal('ssc_eng_max', formatNum(convertedMax, 8));
    setVal('ssc_eng', formatNum(convertedEng, 8));
    applying = false;
    lastFamily = family;
    lastUnit = nextDefault;
    render('eng');
  }

  function onUnitChange() {
    const family = (el('ssc_family') && el('ssc_family').value) || 'pressure';
    const unit = (el('ssc_unit') && el('ssc_unit').value) || lastUnit;
    const st = readState();
    const convertedMin = convertEng(st.engMin, family, lastUnit, unit);
    const convertedMax = convertEng(st.engMax, family, lastUnit, unit);
    const convertedEng = convertEng(st.eng, family, lastUnit, unit);
    applying = true;
    setVal('ssc_eng_min', formatNum(convertedMin, 8));
    setVal('ssc_eng_max', formatNum(convertedMax, 8));
    setVal('ssc_eng', formatNum(convertedEng, 8));
    applying = false;
    lastUnit = unit;
    render('eng');
  }

  function recallPreset(p) {
    applying = true;
    setVal('ssc_type', p.signalType);
    applySignalType(p.signalType, true);
    setVal('ssc_raw_min', p.rawMin);
    setVal('ssc_raw_max', p.rawMax);
    setVal('ssc_eng_min', p.engMin);
    setVal('ssc_eng_max', p.engMax);
    setVal('ssc_family', p.family || 'pressure');
    fillUnitSelect(p.family || 'pressure', p.unit);
    setVal('ssc_unit', p.unit);
    if (p.custom) setVal('ssc_custom', p.custom);
    if (el('ssc_law')) el('ssc_law').value = p.law || 'linear';
    lastFamily = p.family || 'pressure';
    lastUnit = p.unit;
    applying = false;
    render('raw');
  }

  function init() {
    if (!el('sec-signal-scaling')) return;
    fillUnitSelect('pressure', 'psi');
    applySignalType('4-20mA', false);
    setVal('ssc_raw', '14.2');
    setVal('ssc_eng_min', '0');
    setVal('ssc_eng_max', '500');
    renderPresets();
    render('raw');

    const section = el('sec-signal-scaling');
    section.addEventListener('input', function (ev) {
      const id = ev.target && ev.target.id;
      if (id === 'ssc_type') {
        applySignalType(ev.target.value, false);
        render('raw');
        return;
      }
      if (id === 'ssc_family') { onFamilyChange(); return; }
      if (id === 'ssc_unit') { onUnitChange(); return; }
      if (id === 'ssc_eng') { render('eng'); return; }
      if (id === 'ssc_slider') {
        applying = true;
        setVal('ssc_raw', ev.target.value);
        applying = false;
        render('raw');
        return;
      }
      render('raw');
    });
    section.addEventListener('change', function (ev) {
      const id = ev.target && ev.target.id;
      if (id === 'ssc_type') {
        applySignalType(ev.target.value, false);
        render('raw');
      } else if (id === 'ssc_family') onFamilyChange();
      else if (id === 'ssc_unit') onUnitChange();
      else if (id === 'ssc_law') render('raw');
    });
    section.addEventListener('click', function (ev) {
      const t = ev.target;
      if (!t || !t.getAttribute) return;
      if (t.getAttribute('data-ssc-recall') !== null) {
        const list = loadPresets();
        const p = list[Number(t.getAttribute('data-ssc-recall'))];
        if (p) recallPreset(p);
        return;
      }
      if (t.getAttribute('data-ssc-del') !== null) {
        const list = loadPresets();
        list.splice(Number(t.getAttribute('data-ssc-del')), 1);
        savePresets(list);
        renderPresets();
      }
    });

    const saveBtn = el('ssc_save_preset');
    if (saveBtn) saveBtn.addEventListener('click', function () {
      const nameEl = el('ssc_preset_name');
      const name = String((nameEl && nameEl.value) || '').trim();
      if (!name) {
        if (nameEl) nameEl.placeholder = 'Name required, e.g. PT-204 0–500 psi 4–20mA';
        return;
      }
      const st = readState();
      const list = loadPresets();
      list.push({
        name: name,
        signalType: st.signalType,
        rawMin: st.rawMin,
        rawMax: st.rawMax,
        engMin: st.engMin,
        engMax: st.engMax,
        family: st.family,
        unit: st.unit,
        custom: st.custom,
        law: st.law,
      });
      savePresets(list);
      renderPresets();
    });

    window.loadSignalScalingExample = function () {
      applying = true;
      setVal('ssc_type', '4-20mA');
      applySignalType('4-20mA', false);
      setVal('ssc_raw', '14.2');
      setVal('ssc_eng_min', '0');
      setVal('ssc_eng_max', '500');
      setVal('ssc_family', 'pressure');
      fillUnitSelect('pressure', 'psi');
      setVal('ssc_unit', 'psi');
      lastFamily = 'pressure';
      lastUnit = 'psi';
      applying = false;
      render('raw');
    };

    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-signal-scaling', 'signal-scaling', function () { render('raw'); });
    }
    if (typeof registerReport === 'function') {
      registerReport('ssc_live', {
        title: 'Signal Scaling',
        formula: function () {
          const node = el('ssc_fwd_formula');
          return node ? node.textContent : '';
        },
        codeRefs: function () {
          return [
            'Linear scale: eng = engMin + (raw − rawMin) × (engMax − engMin) / (rawMax − rawMin)',
            '4–20 mA live-zero: 4 mA is 0% of span; below 4 mA is flagged as a fault',
            'Design aid only — verify against the transmitter datasheet',
          ];
        },
      });
    }
  }

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
  }

  global.__signalScalingTestApi = {
    SIGNAL_TYPES: SIGNAL_TYPES,
    UNIT_FAMILIES: UNIT_FAMILIES,
    linearMap: linearMap,
    scaleForward: scaleForward,
    scaleReverse: scaleReverse,
    rangeFlags: rangeFlags,
    convertEng: convertEng,
    unitLabel: unitLabel,
    pluggedFormula: pluggedFormula,
    pt100TemperatureC: pt100TemperatureC,
    formatNum: formatNum,
  };
})(typeof window !== 'undefined' ? window : globalThis);
