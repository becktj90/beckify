/* Offline first-pass op-amp and analog-filter design workbench. */
(function () {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const num = (id) => Number($(id)?.value);
  const ok = (n) => Number.isFinite(n) && n > 0;
  const text = (node, value) => { node.textContent = value; return node; };
  const row = (host, label, value, emphasis) => { const el = document.createElement('div'); el.className = 'res-row'; if (emphasis) el.style.borderLeft = '3px solid #6ee7b7'; const l = document.createElement('span'); l.className = 'res-label'; l.textContent = label; const v = document.createElement('span'); v.className = 'res-val'; v.textContent = value; if (emphasis) { v.style.color = '#6ee7b7'; v.style.fontWeight = '700'; } el.append(l, v); host.append(el); };
  const value = (n, digits = 3) => Number(n).toLocaleString('en-US', { maximumFractionDigits: digits });
  const ohms = (n) => n >= 1e6 ? `${value(n / 1e6)} MΩ` : n >= 1e3 ? `${value(n / 1e3)} kΩ` : `${value(n)} Ω`;
  const hz = (n) => n >= 1e6 ? `${value(n / 1e6)} MHz` : n >= 1e3 ? `${value(n / 1e3)} kHz` : `${value(n)} Hz`;
  const field = (label, id, current, unit) => `<div><label for="${id}">${label}${unit ? ` (${unit})` : ''}</label><input id="${id}" type="number" value="${current}" min="0.000001" step="any"></div>`;

  const opFields = {
    inverting: () => `<div class="input-group">${field('Input voltage', 'ao_vin', 1, 'V')}${field('Input resistor', 'ao_rin', 10000, 'Ω')}</div><div class="input-group single">${field('Feedback resistor', 'ao_rf', 47000, 'Ω')}</div>`,
    noninverting: () => `<div class="input-group">${field('Input voltage', 'ao_vin', 1, 'V')}${field('Ground resistor', 'ao_rg', 10000, 'Ω')}</div><div class="input-group single">${field('Feedback resistor', 'ao_rf', 47000, 'Ω')}</div>`,
    difference: () => `<div class="input-group">${field('V₂ non-inverting', 'ao_v2', 2, 'V')}${field('V₁ inverting', 'ao_v1', 1, 'V')}</div><div class="input-group">${field('Input R₁', 'ao_rin', 10000, 'Ω')}${field('Feedback / matching R₂', 'ao_rf', 47000, 'Ω')}</div>`,
    summing: () => `<div class="input-group">${field('V₁', 'ao_v1', 1, 'V')}${field('R₁', 'ao_r1', 10000, 'Ω')}</div><div class="input-group">${field('V₂', 'ao_v2', 0.5, 'V')}${field('R₂', 'ao_r2', 10000, 'Ω')}</div><div class="input-group single">${field('Feedback Rf', 'ao_rf', 10000, 'Ω')}</div>`,
    transimpedance: () => `<div class="input-group">${field('Input current', 'ao_iin', 0.00001, 'A')}${field('Feedback Rf', 'ao_rf', 100000, 'Ω')}</div><div class="input-group single">${field('Feedback Cf (optional)', 'ao_cf', 0.00000000001, 'F')}</div>`,
    integrator: () => `<div class="input-group">${field('Input voltage', 'ao_vin', 1, 'V')}${field('Input R', 'ao_rin', 10000, 'Ω')}</div><div class="input-group single">${field('Feedback C', 'ao_cf', 0.0000001, 'F')}</div>`,
    differentiator: () => `<div class="input-group">${field('Input amplitude', 'ao_vin', 1, 'V')}${field('Input C', 'ao_cf', 0.00000001, 'F')}</div><div class="input-group">${field('Feedback R', 'ao_rf', 10000, 'Ω')}${field('Frequency', 'ao_freq', 1000, 'Hz')}</div>`,
    comparator: () => `<div class="input-group">${field('Signal input', 'ao_vin', 1, 'V')}${field('Reference threshold', 'ao_vref', 1.2, 'V')}</div>`,
    schmitt: () => `<div class="input-group">${field('High output rail', 'ao_vh', 5, 'V')}${field('Low output rail', 'ao_vl', 0, 'V')}</div><div class="input-group">${field('R top', 'ao_rf', 10000, 'Ω')}${field('R bottom', 'ao_rg', 10000, 'Ω')}</div>`,
    instrumentation: () => `<div class="input-group">${field('Differential input', 'ao_vin', 0.01, 'V')}${field('Gain resistor RG', 'ao_rg', 1000, 'Ω')}</div><div class="input-group single">${field('Internal gain constant', 'ao_k', 50000, 'Ω')}</div>`,
    firstorder: () => `<div class="input-group">${field('Input voltage', 'ao_vin', 1, 'V')}${field('Input Rin', 'ao_rin', 10000, 'Ω')}</div><div class="input-group">${field('Feedback Rf', 'ao_rf', 10000, 'Ω')}${field('Feedback Cf', 'ao_cf', 0.0000001, 'F')}</div>`,
    lead: () => `<div class="input-group">${field('Input R1', 'ao_rin', 20000, 'Ω')}${field('Input C1', 'ao_c1', 0.0000001, 'F')}</div><div class="input-group">${field('Feedback R2', 'ao_rf', 4700, 'Ω')}${field('Feedback C2', 'ao_c2', 0.0000001, 'F')}</div>`,
  };
  function renderOpAmpSchematic(type) {
    const host = $('ao_schematic');
    if (!host || !window.AnalogSchematics) return;
    host.innerHTML = window.AnalogSchematics.opAmp(type);
    const info = window.AnalogSchematics.opAmpTransfer(type);
    const formula = $('ao_transfer');
    if (formula && info) formula.innerHTML = `<div class="analog-formula">${info.h}</div><p class="analog-formula-note">${info.note}</p>`;
    const label = $('ao_schematic_label');
    if (label) label.textContent = $('ao_type')?.selectedOptions?.[0]?.textContent || '';
  }

  window.renderOpAmpFields = function () {
    const type = $('ao_type')?.value || 'inverting';
    $('ao_fields').innerHTML = opFields[type]();
    renderOpAmpSchematic(type);
  };
  window.calcOpAmp = function () {
    const host = $('ao_result'); host.textContent = ''; const type = $('ao_type').value; const n = (id) => num(id);
    const Rf = n('ao_rf'), Rin = n('ao_rin'), Rg = n('ao_rg'), Vin = n('ao_vin');
    const required = { inverting: [Vin, Rin, Rf], noninverting: [Vin, Rg, Rf], difference: [n('ao_v1'), n('ao_v2'), Rin, Rf], summing: [n('ao_v1'), n('ao_v2'), n('ao_r1'), n('ao_r2'), Rf], transimpedance: [n('ao_iin'), Rf, n('ao_cf')], integrator: [Vin, Rin, n('ao_cf')], differentiator: [Vin, Rf, n('ao_cf'), n('ao_freq')], comparator: [Vin, n('ao_vref')], schmitt: [n('ao_vh'), Rf, Rg], instrumentation: [Vin, Rg, n('ao_k')], firstorder: [Vin, Rin, Rf, n('ao_cf')], lead: [Rin, n('ao_c1'), Rf, n('ao_c2')] };
    if (!required[type].every(ok)) { text(host, 'Enter positive values for every active field.'); return; }
    host.className = 'result show';
    if (type === 'inverting') { const g = -Rf / Rin; row(host, 'Ideal gain', value(g) + ' V/V', true); row(host, 'Output', value(g * Vin) + ' V'); row(host, 'Relationship', 'Vout = −(Rf / Rin) Vin'); }
    else if (type === 'noninverting') { const g = 1 + Rf / Rg; row(host, 'Ideal gain', value(g) + ' V/V', true); row(host, 'Output', value(g * Vin) + ' V'); row(host, 'Relationship', 'Vout = (1 + Rf / Rg) Vin'); }
    else if (type === 'difference') { const g = Rf / Rin; row(host, 'Differential gain', value(g) + ' V/V', true); row(host, 'Output', value(g * (n('ao_v2') - n('ao_v1'))) + ' V'); row(host, 'Matching condition', 'Use R₂/R₁ = R₄/R₃ for CMRR.'); }
    else if (type === 'summing') { const out = -Rf * (n('ao_v1') / n('ao_r1') + n('ao_v2') / n('ao_r2')); row(host, 'Output', value(out) + ' V', true); row(host, 'Relationship', 'Vout = −Rf(V₁/R₁ + V₂/R₂)'); }
    else if (type === 'transimpedance') { const out = -n('ao_iin') * Rf; row(host, 'Transimpedance', value(-Rf) + ' V/A', true); row(host, 'Output', value(out) + ' V'); row(host, 'Feedback-pole estimate', hz(1 / (2 * Math.PI * Rf * n('ao_cf')))); }
    else if (type === 'integrator') { const tau = Rin * n('ao_cf'); row(host, 'Time constant RC', value(tau * 1000) + ' ms', true); row(host, 'Output slope', value(-Vin / tau) + ' V/s'); row(host, 'Relationship', 'Vout = −(1/RC) ∫Vin dt'); }
    else if (type === 'differentiator') { const g = 2 * Math.PI * n('ao_freq') * Rf * n('ao_cf'); row(host, 'Magnitude at frequency', value(g) + ' V/V', true); row(host, 'Output amplitude', value(g * Vin) + ' V'); row(host, 'Relationship', '|H| = 2πfRfC'); }
    else if (type === 'comparator') { row(host, 'Decision', Vin >= n('ao_vref') ? 'HIGH output state' : 'LOW output state', true); row(host, 'Threshold', value(n('ao_vref')) + ' V'); row(host, 'Note', 'Add hysteresis for noisy or slowly crossing inputs.'); }
    else if (type === 'schmitt') { const b = Rg / (Rf + Rg); row(host, 'Upper threshold', value(b * n('ao_vh')) + ' V', true); row(host, 'Lower threshold', value(b * n('ao_vl')) + ' V'); row(host, 'Hysteresis width', value(b * (n('ao_vh') - n('ao_vl'))) + ' V'); }
    else if (type === 'instrumentation') { const gain = 1 + n('ao_k') / Rg; row(host, 'Instrumentation gain', value(gain) + ' V/V', true); row(host, 'Output differential term', value(gain * Vin) + ' V'); row(host, 'Relationship', 'Vout = (1 + 50k/RG)(V₂ − V₁) + Vref'); }
    if (type === 'firstorder') {
      const tau = Rf * n('ao_cf');
      const g = -Rf / Rin;
      row(host, 'DC gain', value(g) + ' V/V', true);
      row(host, 'Time constant Rf Cf', value(tau * 1000) + ' ms');
      row(host, 'Pole', '−1/τ = ' + value(-1 / tau) + ' rad/s');
      row(host, 'H(s)', '−(' + value(Rf) + '/' + value(Rin) + ') / (1 + s·' + tau.toExponential(3) + ')');
      row(host, 'Output at DC', value(g * Vin) + ' V');
    } else if (type === 'lead') {
      const C1 = n('ao_c1');
      const C2 = n('ao_c2');
      const T = Rin * C1;
      const aT = Rf * C2;
      const alpha = aT / T;
      const g = -Rf / Rin;
      row(host, 'T = R1 C1', value(T * 1000) + ' ms', true);
      row(host, 'α = R2 C2 / R1 C1', value(alpha));
      row(host, 'Kind', alpha < 1 ? 'Lead (zero closer to origin than the pole)' : alpha > 1 ? 'Lag (pole closer to origin)' : 'All-pass ratio');
      row(host, 'Zero', '−1/T = ' + value(-1 / T) + ' rad/s');
      row(host, 'Pole', '−1/(αT) = ' + value(-1 / aT) + ' rad/s');
      row(host, 'H(s)', value(g) + ' · (1 + s·' + T.toExponential(3) + ') / (1 + s·' + aT.toExponential(3) + ')');
    }
  };
  window.showAnalogPanel = function (name) { ['opamp', 'filter'].forEach((item) => { $('analog-panel-' + item).hidden = item !== name; $('analog-tab-' + item).classList.toggle('active', item === name); }); if (name === 'filter') window.calcAnalogFilter(); };
  function mag(type, x, q, gain) { const d = Math.sqrt((1 - x * x) ** 2 + (x / q) ** 2); if (['rc-low'].includes(type)) return gain / Math.sqrt(1 + x * x); if (['rc-high'].includes(type)) return gain * x / Math.sqrt(1 + x * x); if (['sk-low'].includes(type)) return gain / d; if (['sk-high'].includes(type)) return gain * x * x / d; if (['rlc-band', 'mfb-band', 'state-variable'].includes(type)) return gain * (x / q) / d; if (['rlc-notch', 'twin-t'].includes(type)) return gain * Math.abs(1 - x * x) / d; return gain; }
  function plot(type, f0, q, gain) {
    const w = 700, h = 320, l = 58, r = 56, t = 28, b = 46;
    const lo = Math.log10(f0) - 3, hi = Math.log10(f0) + 3;
    const plotH = h - t - b;
    const x = (f) => l + (Math.log10(f) - lo) / (hi - lo) * (w - l - r);
    const y = (db) => t + (18 - Math.max(-72, Math.min(18, db))) / 90 * plotH;
    const yPhase = (deg) => t + (180 - Math.max(-180, Math.min(180, deg))) / 360 * plotH;
    const phaseOf = window.AnalogSchematics ? window.AnalogSchematics.phaseDeg : null;

    let line = '', phaseLine = '';
    for (let i = 0; i <= 240; i += 1) {
      const f = 10 ** (lo + (hi - lo) * i / 240);
      const db = 20 * Math.log10(Math.max(1e-6, mag(type, f / f0, q, gain)));
      line += `${i ? 'L' : 'M'}${x(f).toFixed(1)},${y(db).toFixed(1)} `;
      if (phaseOf) {
        const p = phaseOf(type, f / f0, q);
        phaseLine += `${i ? 'L' : 'M'}${x(f).toFixed(1)},${yPhase(p).toFixed(1)} `;
      }
    }
    const grid = [-60, -40, -20, 0].map((db) => `<line x1="${l}" x2="${w - r}" y1="${y(db)}" y2="${y(db)}" stroke="#334155"/><text x="8" y="${y(db) + 4}" fill="#8b7bff" font-size="11">${db} dB</text>`).join('');
    const phaseGrid = [180, 90, 0, -90, -180].map((d) => `<text x="${w - r + 8}" y="${yPhase(d) + 4}" fill="#5ed7ff" font-size="11">${d}°</text>`).join('');
    const marks = [-2, -1, 0, 1, 2].map((p) => {
      const f = 10 ** (Math.log10(f0) + p);
      return `<line x1="${x(f)}" x2="${x(f)}" y1="${t}" y2="${h - b}" stroke="#243047"/><text x="${x(f)}" y="${h - 26}" text-anchor="middle" fill="#94a3b8" font-size="11">${f >= 1000 ? value(f / 1000) + 'k' : value(f)}</text>`;
    }).join('');
    const legend = `<rect x="${l}" y="${h - 18}" width="14" height="3" fill="#8b7bff"/><text x="${l + 20}" y="${h - 12}" fill="#8b7bff" font-size="11">magnitude</text>` +
      `<rect x="${l + 108}" y="${h - 18}" width="14" height="3" fill="#5ed7ff"/><text x="${l + 128}" y="${h - 12}" fill="#5ed7ff" font-size="11">phase</text>`;
    $('af_plot').innerHTML = `<svg viewBox="0 0 ${w} ${h}" role="img" aria-label="Filter magnitude and phase response">${grid}${phaseGrid}${marks}<line x1="${l}" x2="${w - r}" y1="${h - b}" y2="${h - b}" stroke="#64748b"/><line x1="${x(f0)}" x2="${x(f0)}" y1="${t}" y2="${h - b}" stroke="#f5c451" stroke-dasharray="5 4"/><path d="${phaseLine}" fill="none" stroke="#5ed7ff" stroke-width="2" stroke-dasharray="6 4" opacity="0.9"/><path d="${line}" fill="none" stroke="#8b7bff" stroke-width="3"/><text x="${x(f0) + 6}" y="${t + 14}" fill="#f5c451" font-size="12">f₀ ${hz(f0)}</text><text x="${w - r}" y="${h - 26}" text-anchor="end" fill="#94a3b8" font-size="11">Hz (log)</text>${legend}</svg>`;
  }

  function renderFilterSchematic(type) {
    const host = $('af_schematic');
    if (!host || !window.AnalogSchematics) return;
    host.innerHTML = window.AnalogSchematics.filter(type);
    const label = $('af_schematic_label');
    if (label) label.textContent = $('af_type')?.selectedOptions?.[0]?.textContent || '';
  }
  window.calcAnalogFilter = function () { const host = $('af_result'); const type = $('af_type').value, f0 = num('af_freq'), q = num('af_q'), gain = num('af_gain'), R = num('af_r'), C = num('af_c'); host.textContent = ''; if (![f0, q, gain, R, C].every(ok)) { text(host, 'Enter positive frequency, Q, gain, R, and C values.'); return; } host.className = 'result show'; const rc = 1 / (2 * Math.PI * R * C); const label = $('af_type').selectedOptions[0].textContent; row(host, 'Selected family', label, true); row(host, 'Design / center frequency', hz(f0)); if (['rc-low', 'rc-high', 'allpass'].includes(type)) { row(host, 'RC from reference parts', hz(rc)); row(host, 'To hit design f', 'C = ' + value(1e9 / (2 * Math.PI * R * f0)) + ' nF with ' + ohms(R)); } else if (type.startsWith('sk-')) { row(host, 'Equal-value starting point', 'R₁=R₂=' + ohms(R) + ', C₁=C₂=' + value(1e9 / (2 * Math.PI * R * f0)) + ' nF'); row(host, 'Equal-value Sallen–Key Q', 'Q ≈ 1 / (3 − K); Butterworth Q=.707 → K≈1.586'); } else if (type === 'twin-t') { row(host, 'Twin-T starting ratios', 'R, R, 2R and C, C, C/2'); row(host, 'Set C for f₀', value(1e9 / (2 * Math.PI * R * f0)) + ' nF, then use C/2 on the center leg'); } else { row(host, 'Selectivity', 'Q = ' + value(q)); row(host, '−3 dB bandwidth estimate', hz(f0 / q)); row(host, 'Reference RC for f₀', 'C = ' + value(1e9 / (2 * Math.PI * R * f0)) + ' nF with ' + ohms(R)); } row(host, 'Passband gain', value(gain) + ' V/V (' + value(20 * Math.log10(gain), 2) + ' dB)'); row(host, 'Reminder', 'Use the plotted ideal response to compare families; verify component-ratio equations for the selected topology.'); $('af_plot_label').textContent = `f₀ ${hz(f0)} · Q ${value(q)}`; plot(type, f0, q, gain); renderFilterSchematic(type); renderFilterTransfer(type, f0, q, gain); };

  function renderFilterTransfer(type, f0, q, gain) {
    const formula = $('af_transfer');
    if (!formula || !window.AnalogSchematics) return;
    const info = window.AnalogSchematics.filterTransfer(type);
    if (!info) { formula.innerHTML = ''; return; }
    const sub = window.AnalogSchematics.substituted(type, f0, q, gain);
    formula.innerHTML =
      `<div class="analog-formula">${info.h}</div>` +
      `<div class="analog-formula analog-formula-sub">${sub}</div>` +
      `<p class="analog-formula-note">Order ${info.order} · ${info.roll} · ω₀ = 2π·${hz(f0)} = ${value(2 * Math.PI * f0, 1)} rad/s</p>`;
  }
  document.addEventListener('DOMContentLoaded', function () { if (!$('sec-analog-design')) return; window.renderOpAmpFields(); window.calcOpAmp(); window.calcAnalogFilter(); });
}());
