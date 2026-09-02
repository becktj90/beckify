/* ============================================================================
   BATTERY BANK CALCULATOR
   ============================================================================
   Forward: load + duration + module specs → count, usable energy, C-rate flag.
   Reverse: installed count/config → backup duration at a stated load.
   Series/parallel helper sizes strings from module V/Ah and a target system V.
   Planning math only — not a UL listing, fire-code, or PE stamp.
   ============================================================================ */
(function (global) {
  'use strict';

  var PRESETS = {
    lfp: { label: 'LiFePO₄ (LFP)', dod: 90, eta: 95, crate: 1.0 },
    flooded: { label: 'Flooded lead-acid', dod: 50, eta: 90, crate: 0.2 },
    agm: { label: 'AGM lead-acid', dod: 50, eta: 92, crate: 0.3 },
    custom: { label: 'Generic / custom', dod: 80, eta: 90, crate: 0.5 },
  };

  function num(v) {
    var n = Number(v);
    return Number.isFinite(n) ? n : NaN;
  }
  function pos(v) { return Number.isFinite(v) && v > 0; }
  function clampPct(v, fallback) {
    var n = num(v);
    if (!Number.isFinite(n)) return fallback;
    if (n > 1 && n <= 100) n = n / 100;
    if (n <= 0 || n > 1) return fallback;
    return n;
  }
  function fmt(x, d) {
    if (!Number.isFinite(x)) return '—';
    return Number(x).toLocaleString('en-US', { maximumFractionDigits: d === undefined || d === null ? 2 : d });
  }
  function ceilUnits(x) { return Math.max(1, Math.ceil(x - 1e-9)); }

  /**
   * Series string length to hit target voltage with module nominal V.
   * Parallel strings to hit target capacity (Ah) once series is fixed.
   */
  function seriesParallel(moduleV, moduleAh, targetV, targetAh) {
    if (!pos(moduleV) || !pos(targetV)) {
      return { error: 'Module voltage and target system voltage must be greater than zero.' };
    }
    var series = Math.max(1, Math.round(targetV / moduleV));
    var actualV = series * moduleV;
    var parallel = 1;
    if (pos(moduleAh) && pos(targetAh)) {
      parallel = Math.max(1, Math.ceil(targetAh / moduleAh));
    }
    var units = series * parallel;
    return {
      series: series,
      parallel: parallel,
      units: units,
      actualV: actualV,
      actualAh: pos(moduleAh) ? parallel * moduleAh : NaN,
      moduleV: moduleV,
      moduleAh: moduleAh,
      targetV: targetV,
      targetAh: targetAh,
    };
  }

  function usableWhPerUnit(spec) {
    if (pos(spec.kwh)) return spec.kwh * 1000 * spec.dod;
    if (pos(spec.v) && pos(spec.ah)) return spec.v * spec.ah * spec.dod;
    return NaN;
  }

  function nameplateWhPerUnit(spec) {
    if (pos(spec.kwh)) return spec.kwh * 1000;
    if (pos(spec.v) && pos(spec.ah)) return spec.v * spec.ah;
    return NaN;
  }

  /**
   * Forward: energy the inverter must deliver, then batteries after DoD and η.
   * Continuous watts, if given, is the load. Daily kWh is always a 24 h
   * average (never divided by backup hours — that would size a 4 h bank
   * as if the whole day's energy had to fit in those 4 hours).
   */
  function sizeForward(input) {
    var dod = clampPct(input.dod, NaN);
    var eta = clampPct(input.eta, NaN);
    if (!pos(dod) || !pos(eta)) return { error: 'Depth of discharge and inverter efficiency must be between 0 and 100%.' };

    var hours = num(input.hours);
    var loadW = num(input.watts);
    var dailyKwh = num(input.dailyKwh);
    if (!pos(loadW) && pos(dailyKwh)) {
      loadW = (dailyKwh * 1000) / 24;
    }
    if (!pos(hours) && pos(dailyKwh)) hours = 24;
    if (!pos(loadW)) return { error: 'Enter continuous watts or daily kWh.' };
    if (!pos(hours)) return { error: 'Enter backup duration in hours.' };

    var spec = { v: num(input.v), ah: num(input.ah), kwh: num(input.kwh), dod: dod };
    var usable = usableWhPerUnit(spec);
    if (!pos(usable)) return { error: 'Enter module Ah (with nominal V) or module kWh.' };

    var acWh = loadW * hours;
    var batteryWh = acWh / eta;
    var units = ceilUnits(batteryWh / usable);
    var nameplate = nameplateWhPerUnit(spec);
    var totalNameplateWh = units * nameplate;
    var totalUsableWh = units * usable;
    var packV = pos(spec.v) ? spec.v : NaN;
    var totalAh = pos(spec.ah) ? units * spec.ah : (pos(packV) ? totalNameplateWh / packV : NaN);
    var dcW = loadW / eta;
    var crate = pos(totalAh) && pos(packV) ? dcW / (packV * totalAh) : NaN;

    var layout = null;
    if (pos(input.targetV) && pos(spec.v)) {
      layout = seriesParallel(spec.v, spec.ah || (pos(spec.kwh) && pos(spec.v) ? (spec.kwh * 1000) / spec.v : NaN), input.targetV, NaN);
      /* Recompute parallel so usable energy still covers the load. */
      var usableString = layout.series * usable;
      layout.parallel = Math.max(1, Math.ceil(batteryWh / usableString));
      layout.units = layout.series * layout.parallel;
      units = layout.units;
      totalNameplateWh = units * nameplate;
      totalUsableWh = units * usable;
      packV = layout.actualV;
      totalAh = pos(spec.ah) ? layout.parallel * spec.ah : (pos(packV) ? totalNameplateWh / packV : NaN);
      crate = pos(totalAh) && pos(packV) ? dcW / (packV * totalAh) : NaN;
    }

    return {
      mode: 'forward',
      loadW: loadW,
      hours: hours,
      acWh: acWh,
      eta: eta,
      dod: dod,
      batteryWh: batteryWh,
      usablePerUnitWh: usable,
      nameplatePerUnitWh: nameplate,
      units: units,
      totalNameplateWh: totalNameplateWh,
      totalUsableWh: totalUsableWh,
      packV: packV,
      totalAh: totalAh,
      dcW: dcW,
      crate: crate,
      crateLimit: pos(input.crateLimit) ? input.crateLimit : 0.5,
      layout: layout,
      runtimeHoursAtLoad: totalUsableWh * eta / loadW,
      math: [
        'AC energy = P × t = ' + fmt(loadW, 1) + ' W × ' + fmt(hours, 2) + ' h = ' + fmt(acWh, 0) + ' Wh',
        'Battery energy (inverter η) = AC energy / η = ' + fmt(acWh, 0) + ' / ' + fmt(eta * 100, 1) + '% = ' + fmt(batteryWh, 0) + ' Wh',
        'Usable per unit = nameplate × DoD = ' + fmt(nameplate, 0) + ' Wh × ' + fmt(dod * 100, 1) + '% = ' + fmt(usable, 0) + ' Wh',
        'Units = ceil(battery energy / usable) = ceil(' + fmt(batteryWh, 0) + ' / ' + fmt(usable, 0) + ') = ' + units,
      ],
    };
  }

  function sizeReverse(input) {
    var dod = clampPct(input.dod, NaN);
    var eta = clampPct(input.eta, NaN);
    if (!pos(dod) || !pos(eta)) return { error: 'Depth of discharge and inverter efficiency must be between 0 and 100%.' };
    var loadW = num(input.watts);
    if (!pos(loadW)) return { error: 'Enter the continuous load in watts.' };
    var series = Math.max(1, Math.floor(num(input.series) || 1));
    var parallel = Math.max(1, Math.floor(num(input.parallel) || 1));
    var spec = { v: num(input.v), ah: num(input.ah), kwh: num(input.kwh), dod: dod };
    var usable = usableWhPerUnit(spec);
    if (!pos(usable)) return { error: 'Enter module Ah (with nominal V) or module kWh.' };
    var units = series * parallel;
    var totalUsableWh = units * usable;
    var hours = (totalUsableWh * eta) / loadW;
    var packV = pos(spec.v) ? series * spec.v : NaN;
    var totalAh = pos(spec.ah) ? parallel * spec.ah : NaN;
    var dcW = loadW / eta;
    var crate = pos(totalAh) && pos(packV) ? dcW / (packV * totalAh) : NaN;
    return {
      mode: 'reverse',
      loadW: loadW,
      hours: hours,
      eta: eta,
      dod: dod,
      units: units,
      series: series,
      parallel: parallel,
      totalUsableWh: totalUsableWh,
      packV: packV,
      totalAh: totalAh,
      dcW: dcW,
      crate: crate,
      crateLimit: pos(input.crateLimit) ? input.crateLimit : 0.5,
      math: [
        'Units = series × parallel = ' + series + ' × ' + parallel + ' = ' + units,
        'Usable bank = units × (nameplate × DoD) = ' + units + ' × ' + fmt(usable, 0) + ' Wh = ' + fmt(totalUsableWh, 0) + ' Wh',
        'Runtime = (usable × η) / P = (' + fmt(totalUsableWh, 0) + ' × ' + fmt(eta * 100, 1) + '%) / ' + fmt(loadW, 1) + ' W = ' + fmt(hours, 2) + ' h',
      ],
    };
  }

  function crateFlag(result) {
    if (!result || !pos(result.crate)) return null;
    if (result.crate <= result.crateLimit) {
      return { ok: true, text: 'Continuous C-rate ' + fmt(result.crate, 2) + ' C is at or under the ' + fmt(result.crateLimit, 2) + ' C planning limit for this chemistry.' };
    }
    return { ok: false, text: 'Continuous C-rate ' + fmt(result.crate, 2) + ' C exceeds the ' + fmt(result.crateLimit, 2) + ' C planning limit. The bank may not deliver this load continuously — add parallel strings, raise the limit only from the datasheet, or reduce the load. This is not a UL or fire-code check.' };
  }

  function el(id) { return document.getElementById(id); }
  function val(id) { return el(id) ? el(id).value : ''; }

  function applyPreset(name) {
    var p = PRESETS[name] || PRESETS.custom;
    if (el('bb_dod')) el('bb_dod').value = String(p.dod);
    if (el('bb_eta')) el('bb_eta').value = String(p.eta);
    if (el('bb_crate')) el('bb_crate').value = String(p.crate);
  }

  function gather() {
    return {
      watts: val('bb_watts'),
      dailyKwh: val('bb_kwh_day'),
      hours: val('bb_hours'),
      v: val('bb_v'),
      ah: val('bb_ah'),
      kwh: val('bb_mod_kwh'),
      dod: val('bb_dod'),
      eta: val('bb_eta'),
      crateLimit: val('bb_crate'),
      targetV: val('bb_target_v'),
      series: val('bb_series'),
      parallel: val('bb_parallel'),
    };
  }

  function renderMath(host, lines) {
    host.innerHTML = '';
    var box = document.createElement('div');
    box.className = 'formula-box';
    box.setAttribute('data-show-work', '1');
    lines.forEach(function (line, i) {
      if (i) box.appendChild(document.createElement('br'));
      box.appendChild(document.createTextNode(line));
    });
    host.appendChild(box);
  }

  function row(host, label, value, good) {
    var e = document.createElement('div');
    e.className = 'res-row';
    var l = document.createElement('span');
    l.className = 'res-label';
    l.textContent = label;
    var v = document.createElement('span');
    v.className = 'res-val';
    v.textContent = value;
    if (good === true) v.style.color = 'var(--green-ok)';
    if (good === false) v.style.color = 'var(--yellow)';
    e.append(l, v);
    host.appendChild(e);
  }

  function paintResult(host, result) {
    host.textContent = '';
    host.className = 'result show';
    if (result.error) {
      host.classList.add('error');
      host.textContent = result.error;
      return;
    }
    row(host, 'Units required', String(result.units), true);
    if (result.layout) {
      row(host, 'Suggested stringing', result.layout.series + 'S' + result.layout.parallel + 'P at ' + fmt(result.layout.actualV, 1) + ' V');
    }
    if (result.mode === 'reverse') {
      row(host, 'Backup duration', fmt(result.hours, 2) + ' h', true);
    } else {
      row(host, 'Backup at this load', fmt(result.runtimeHoursAtLoad, 2) + ' h');
    }
    row(host, 'Usable bank energy', fmt(result.totalUsableWh / 1000, 2) + ' kWh');
    if (pos(result.packV)) row(host, 'Pack voltage', fmt(result.packV, 1) + ' V');
    if (pos(result.totalAh)) row(host, 'Pack capacity', fmt(result.totalAh, 1) + ' Ah');
    var crateNote = crateFlag(result);
    if (pos(result.crate)) {
      row(host, 'Continuous C-rate', fmt(result.crate, 2) + ' C', crateNote && crateNote.ok);
    }
    if (crateNote) {
      var p = document.createElement('p');
      p.className = 'note';
      p.style.marginTop = '10px';
      p.textContent = crateNote.text;
      host.appendChild(p);
    }
    var disc = document.createElement('p');
    disc.className = 'note';
    disc.textContent = 'Planning estimate only. Not a UL listing, fire-code, ventilation, or PE review. Verify BMS, inverter continuous rating, cable ampacity, and the battery datasheet.';
    host.appendChild(disc);
    renderMath(host, result.math);
  }

  function runForward() { paintResult(el('bb_forward_result'), sizeForward(gather())); }
  function runReverse() { paintResult(el('bb_reverse_result'), sizeReverse(gather())); }
  function runLayout() {
    var host = el('bb_layout_result');
    if (!host) return;
    var r = seriesParallel(num(val('bb_v')), num(val('bb_ah')), num(val('bb_target_v')), num(val('bb_target_ah')));
    host.textContent = '';
    host.className = 'result show';
    if (r.error) { host.classList.add('error'); host.textContent = r.error; return; }
    row(host, 'Series per string', String(r.series), true);
    row(host, 'Parallel strings', String(r.parallel));
    row(host, 'Total modules', String(r.units));
    row(host, 'String voltage', fmt(r.actualV, 1) + ' V (target ' + fmt(r.targetV, 1) + ' V)');
    if (pos(r.actualAh)) row(host, 'Bank capacity', fmt(r.actualAh, 1) + ' Ah');
    renderMath(host, [
      'Series = round(V_sys / V_mod) = round(' + fmt(r.targetV, 2) + ' / ' + fmt(r.moduleV, 2) + ') = ' + r.series,
      pos(r.moduleAh) && pos(r.targetAh)
        ? 'Parallel = ceil(Ah_sys / Ah_mod) = ceil(' + fmt(r.targetAh, 2) + ' / ' + fmt(r.moduleAh, 2) + ') = ' + r.parallel
        : 'Parallel left at 1 because no target Ah was entered.',
      'Actual V = ' + r.series + ' × ' + fmt(r.moduleV, 2) + ' = ' + fmt(r.actualV, 2) + ' V',
    ]);
  }

  function init() {
    if (!el('sec-battery-bank')) return;
    var preset = el('bb_chem');
    if (preset) {
      applyPreset(preset.value);
      preset.addEventListener('change', function () { applyPreset(preset.value); });
    }
    var fwd = el('bb_run_forward');
    if (fwd) fwd.addEventListener('click', runForward);
    var rev = el('bb_run_reverse');
    if (rev) rev.addEventListener('click', runReverse);
    var lay = el('bb_run_layout');
    if (lay) lay.addEventListener('click', runLayout);
    ['bb_watts', 'bb_kwh_day', 'bb_hours', 'bb_v', 'bb_ah', 'bb_mod_kwh', 'bb_dod', 'bb_eta', 'bb_crate', 'bb_target_v'].forEach(function (id) {
      var n = el(id);
      if (n) n.addEventListener('change', function () { /* last-used via bindLastUsed */ });
    });
    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-battery-bank', 'battery-bank', runForward);
    }
    if (typeof bindLastUsed === 'function') bindLastUsed('sec-battery-bank', 'battery-bank');
  }

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
  }

  global.__batteryBankTestApi = {
    PRESETS: PRESETS,
    seriesParallel: seriesParallel,
    sizeForward: sizeForward,
    sizeReverse: sizeReverse,
    crateFlag: crateFlag,
    usableWhPerUnit: usableWhPerUnit,
  };
})(typeof window !== 'undefined' ? window : globalThis);
