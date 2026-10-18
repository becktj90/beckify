/* Ported from the Beckify iOS app (SolenoidDesign.swift): air-core / soft-iron solenoid design aid. Not FEA. */
(function (global) {
  'use strict';
  const T = global.BeckifyTool, si = T.si, fx = T.fixed, esc = T.esc;
  const MU0 = 4 * Math.PI * 1e-7, RHO = 1.724e-8;
  const awgD = (n) => 0.005 * Math.pow(92, (36 - n) / 39) * 0.0254;
  const awgA = (n) => { const d = awgD(n) * 1000; return Math.PI / 4 * d * d; };
  function axial(z, L, R, N, I, mur) { const t = (q) => q / Math.sqrt(R * R + q * q); return 0.5 * MU0 * mur * (N / L) * I * (t(z + L / 2) - t(z - L / 2)); }
  function plot(pts, xl, yl, title, fmtY) {
    const W = 460, H = 170, x0 = 46, x1 = W - 12, y0 = 18, y1 = H - 30;
    const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]), xmin = Math.min.apply(null, xs), xmax = Math.max.apply(null, xs), ymax = Math.max.apply(null, ys) || 1, ymin = Math.min(0, Math.min.apply(null, ys));
    const sx = (x) => x0 + (x - xmin) / ((xmax - xmin) || 1) * (x1 - x0), sy = (y) => y1 - (y - ymin) / ((ymax - ymin) || 1) * (y1 - y0);
    const d = pts.map((p, i) => (i ? 'L' : 'M') + sx(p[0]).toFixed(1) + ' ' + sy(p[1]).toFixed(1)).join('');
    return '<svg viewBox="0 0 ' + W + ' ' + H + '" class="bkt-svg" role="img" aria-label="' + esc(title) + '" font-family="system-ui,sans-serif"><rect width="' + W + '" height="' + H + '" rx="10" fill="#0e1118"/><text x="' + x0 + '" y="12" font-size="11" fill="#e8eef5">' + esc(title) + '</text><line x1="' + x0 + '" y1="' + y1 + '" x2="' + x1 + '" y2="' + y1 + '" stroke="#94a2b2"/><line x1="' + x0 + '" y1="' + y0 + '" x2="' + x0 + '" y2="' + y1 + '" stroke="#94a2b2"/><path d="' + d + '" fill="none" stroke="#40bad6" stroke-width="2.2"/><text x="' + x0 + '" y="' + (H - 6) + '" font-size="10" fill="#94a2b2">' + fx(xmin, 1) + '</text><text x="' + x1 + '" y="' + (H - 6) + '" font-size="10" text-anchor="end" fill="#94a2b2">' + fx(xmax, 1) + ' ' + esc(xl) + '</text><text x="' + (x0 - 4) + '" y="' + (y0 + 8) + '" font-size="10" text-anchor="end" fill="#94a2b2">' + fmtY(ymax) + '</text><text x="' + (x0 - 4) + '" y="' + y1 + '" font-size="10" text-anchor="end" fill="#94a2b2">' + fmtY(ymin) + '</text></svg>';
  }
  function solenoid(v) {
    const L = T.positive(v, 'len', 'Coil length') / 1000, R = T.positive(v, 'rad', 'Mean radius') / 1000, turns = T.positive(v, 'turns', 'Turns'), I = T.positive(v, 'current', 'Current'), mur = T.positive(v, 'mur', 'Relative permeability');
    const awg = Math.round(T.need(v, 'awg', 'AWG'));
    if (!(Math.abs(turns - Math.round(turns)) < 1e-9)) throw new Error('Turns must be a whole number.');
    const N = Math.round(turns);
    if (awg < -3 || awg > 40) throw new Error('AWG must be between 4/0 (−3) and 40.');
    const d = awgD(awg), dIns = d * 1.15;
    if (!(dIns < L)) throw new Error('Wire diameter is incompatible with coil length.');
    const tpl = Math.max(1, Math.floor(L / dIns)), layers = Math.ceil(N / tpl), build = layers * dIns, outer = R + build / 2;
    const fill = Math.min(1, N * Math.PI / 4 * d * d / (L * Math.max(build, dIns)));
    const wireLen = 2 * Math.PI * R * N, area = Math.PI / 4 * d * d, res = RHO * wireLen / area;
    const gapMm = T.optional(v, 'gap'), vs = T.optional(v, 'supply');
    if (gapMm != null && !(gapMm > 0)) throw new Error('Air gap must be positive.');
    if (vs != null && !(vs > 0)) throw new Error('Supply voltage must be positive.');
    const volts = vs != null ? vs : I * res, loss = I * I * res, J = I / awgA(awg);
    const B = axial(0, L, R, N, I, mur), H = N / L * I, Lh = MU0 * mur * N * N * Math.PI * R * R / L, E = 0.5 * Lh * I * I;
    const force = (g) => (N * I) * (N * I) * MU0 * mur * Math.PI * R * R / (2 * g * g);
    const rows = [['Center B', si(B, 'T'), true], ['Ampere-turns', fx(N * I, 1, 'A·t')], ['H field', fx(H, 0, 'A/m')], ['Inductance', si(Lh, 'H')], ['Stored energy', si(E, 'J')], ['Wire length', fx(wireLen, 2, 'm')], ['Resistance', si(res, 'Ω')], ['Voltage for ' + fx(I, 2, 'A'), si(volts, 'V')], ['Copper loss', si(loss, 'W'), true], ['Current density', fx(J, 2, 'A/mm²')], ['Turns × layers', tpl + ' per layer × ' + layers], ['Fill factor', fx(fill * 100, 0, '%')], ['Outer radius', fx(outer * 1000, 2, 'mm')]];
    if (gapMm != null) rows.push(['Plunger force', fx(force(gapMm / 1000), 2, 'N'), true]);
    const warn = [];
    if (L / (2 * R) < 2) warn.push('Short coil (ℓ/D < 2): long-solenoid inductance is optimistic.');
    if (J > 6) warn.push('Current density ' + fx(J, 1) + ' A/mm² is aggressive for continuous duty without cooling.');
    if (mur > 1.5) warn.push('µᵣ > 1 assumes a soft-iron path without saturation (real B saturates near 1.5–2 T).');
    if (B > 1.8) warn.push('Center B exceeds ~1.8 T: iron would saturate; treat the air-core math only.');
    const ax = Array.from({ length: 81 }, (_, i) => { const z = L * (i - 40) / 40; return [z * 1000, axial(z, L, R, N, I, mur) * 1000]; });
    let svg = plot(ax, 'mm', 'mT', 'On-axis field B(z) in mT', (y) => fx(y, 1));
    if (gapMm != null) svg += plot(Array.from({ length: 24 }, (_, i) => { const g = Math.max(L * 0.002, L * 0.25 * (i + 1) / 24); return [g * 1000, force(g)]; }), 'mm gap', 'N', 'Plunger force vs gap in N', (y) => fx(y, 1));
    return { headline: 'B = ' + si(B, 'T') + ' at ' + fx(N * I, 0) + ' A·turns', rows, warning: warn.join(' '), steps: ['B(0) = ½ μ₀ μᵣ N I / √(R² + (ℓ/2)²)', 'L ≈ μ₀ μᵣ N² A / ℓ', 'R = ρ × (2πR N) / A_wire, ρ = 1.724e-8 Ω·m', 'F ≈ (NI)² μ₀ μᵣ A / (2 g²)'], notes: ['Design aid, not FEA. The coil is modeled as a thin current sheet at the mean radius.', 'Winding packs at 1.15 × the bare wire diameter.'], svg };
  }
  T.define({ id: 'solenoidDesign', root: 'bk-sol-root', title: 'Solenoid design', lede: 'Center field, inductance, copper loss and plunger force for an air-core or soft-iron solenoid.',
    fields: [{ id: 'len', label: 'Coil length', unit: 'mm', def: '50' }, { id: 'rad', label: 'Mean radius', unit: 'mm', def: '10' }, { id: 'turns', label: 'Turns', def: '500' }, { id: 'current', label: 'Current', unit: 'A', def: '1' },
      { id: 'awg', label: 'Wire AWG', def: '24' }, { id: 'mur', label: 'Relative permeability µᵣ', def: '1' }, { id: 'gap', label: 'Air gap', unit: 'mm', def: '', optional: true, help: 'Optional. Gives plunger force.' }, { id: 'supply', label: 'Supply voltage', unit: 'V', def: '', optional: true }],
    compute: solenoid, example: { len: '80', rad: '15', turns: '1000', current: '2', gap: '2', mur: '200' }, foot: 'Design aid. Finite-solenoid on-axis field, long-solenoid inductance and a single-gap force estimate.' });
})(typeof window !== 'undefined' ? window : globalThis);
