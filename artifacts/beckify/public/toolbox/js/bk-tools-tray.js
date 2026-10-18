/* Ported from the Beckify iOS app (CableLadder.swift): NEC Article 392 cable-tray fill, rung check and NEMA VE 1-style load class.
   Core only: fill limit, load class, supports and bend radius. The iOS circle-packing sketch, environment chips and color legend are not ported. */
(function (global) {
  'use strict';
  const T = global.BeckifyTool, fx = T.fixed, esc = T.esc;
  const MULTI = [[6, 7, 5.5], [9, 10.5, 8], [12, 14, 11], [18, 21, 16.5], [24, 28, 22], [30, 35, 27.5], [36, 42, 33]];
  const SINGLE = [[6, 6.5], [12, 13], [18, 19.5], [24, 26], [30, 32.5], [36, 39]];
  const CHAN = [[3, 2.3, 1.3], [4, 4.5, 2.5], [6, 7, 3.8]];
  function interp(w, rows) {
    const s = rows.slice().sort((a, b) => a[0] - b[0]), f = s[0], l = s[s.length - 1];
    const ex = s.find((r) => Math.abs(r[0] - w) < 1e-9); if (ex) return { area: ex[1], ext: false };
    if (w < f[0]) { const n = s[1], k = (n[1] - f[1]) / (n[0] - f[0]); return { area: f[1] + k * (w - f[0]), ext: true }; }
    if (w > l[0]) { const p = s[s.length - 2], k = (l[1] - p[1]) / (l[0] - p[0]); return { area: l[1] + k * (w - l[0]), ext: true }; }
    for (let i = 0; i < s.length - 1; i++) if (w >= s[i][0] && w <= s[i + 1][0]) { const t = (w - s[i][0]) / (s[i + 1][0] - s[i][0]); return { area: s[i][1] + t * (s[i + 1][1] - s[i][1]), ext: false }; }
    return { area: l[1], ext: true };
  }
  const pct = (a, b) => (b > 1e-12 ? a / b * 100 : a > 0 ? 999 : 0);
  const rank = { pass: 0, warn: 1, fail: 2 };
  function tray(v) {
    const W = T.positive(v, 'width', 'Inside width'), D = T.positive(v, 'depth', 'Usable depth'), rung = T.positive(v, 'rung', 'Rung spacing'), len = T.positive(v, 'length', 'Run length'), span = T.positive(v, 'span', 'Support span');
    const type = v.type, cover = v.cover, contents = v.contents, rows = [];
    [['a', 'Cable A'], ['b', 'Cable B']].forEach(([k, name]) => {
      const od = T.optional(v, 'od' + k); const cntRaw = T.optional(v, 'n' + k);
      if (od == null && cntRaw == null && k === 'b') return;
      if (od == null) throw new Error(name + ': overall diameter is required.');
      if (!(od > 0)) throw new Error(name + ': overall diameter must be positive.');
      const n = cntRaw == null ? 1 : cntRaw;
      if (!(n >= 1) || Math.abs(n - Math.round(n)) > 1e-9) throw new Error(name + ': count must be a whole number of 1 or more.');
      const wt = T.optional(v, 'w' + k); if (wt != null && !(wt > 0)) throw new Error(name + ': weight must be positive.');
      rows.push({ name, od, n: Math.round(n), wt, big: v['big' + k] === 'yes' });
    });
    const total = rows.reduce((s, r) => s + r.n, 0); if (total > 400) throw new Error('This tool stops at 400 cables. Split the run or reduce the count.');
    const area = rows.reduce((s, r) => s + r.n * Math.PI * r.od * r.od / 4, 0), solid = type === 'solid' || (cover === 'solid' && (type === 'ladder' || type === 'vent'));
    const openFam = (type === 'ladder' || type === 'vent') && !solid;
    let allowable, p, basis, ext = false, over = 'Over the cited fill area.'; const notes = [];
    if (type === 'channel') {
      const r = interp(W, CHAN.map((c) => [c[0], total <= 1 ? c[1] : c[2]])); allowable = r.area; ext = r.ext; p = pct(area, allowable); basis = 'Table 392.22(A)(5) ' + (total <= 1 ? 'Column 1, one cable' : 'Column 2, more than one cable');
    } else if (contents === 'control') {
      allowable = W * Math.min(D, 6) * (solid ? 0.4 : 0.5); p = pct(area, allowable); basis = solid ? '392.22(A)(4): 40 % of interior area (depth capped at 6 in)' : '392.22(A)(2): 50 % of interior area (depth capped at 6 in)';
    } else if (contents === 'single' && openFam) {
      const col = interp(W, SINGLE), big = rows.filter((r) => r.big), small = rows.filter((r) => !r.big);
      const sd = big.reduce((s, r) => s + r.n * r.od, 0), sa = small.reduce((s, r) => s + r.n * Math.PI * r.od * r.od / 4, 0);
      if (!small.length) { p = pct(sd, W); allowable = null; basis = '392.22(B)(1)(a): 1000 kcmil and larger, one layer. Sum of diameters vs inside width.'; }
      else if (!big.length) { allowable = col.area; ext = col.ext; p = pct(area, allowable); basis = '392.22(B)(1)(b): single conductors under 1000 kcmil, Table 392.22(B)(1) Column 1.'; }
      else { allowable = col.area - 1.1 * sd; ext = col.ext; p = Math.max(allowable > 1e-9 ? pct(sa, allowable) : sa > 0 ? 999 : 0, pct(sd, W)); basis = '392.22(B)(1)(c): smaller-cable area ≤ Column 1 − 1.1×Sd; 1000 kcmil and larger stay in one layer.'; }
    } else {
      const r = interp(W, MULTI.map((m) => [m[0], solid ? m[2] : m[1]])); allowable = r.area; ext = r.ext; p = pct(area, allowable);
      basis = 'Table 392.22(A) ' + (solid ? 'Column 2, solid bottom' : 'Column 1, ladder or ventilated trough');
      if (cover === 'solid' && type !== 'solid') notes.push('A solid cover on ladder or trough uses the solid-bottom column as a planning treatment. Confirm with the AHJ.');
      if (contents === 'single' && !openFam) notes.push('392.22(B) single-conductor fill is for open ladder or trough. This uses the multiconductor column as a stand-in.');
    }
    let status = 'pass'; const reasons = [], raise = (s, t) => { if (s !== 'pass') reasons.push(t); if (rank[s] > rank[status]) status = s; };
    if (p > 100 + 1e-6) raise('fail', over); else if (p > 80 + 1e-6) raise('warn', 'Over 80 % of the cited fill limit.');
    const maxOD = Math.max.apply(null, rows.map((r) => r.od));
    if (maxOD > W + 1e-9 || maxOD > D + 1e-9) raise('fail', 'A cable does not fit in the inside width or the usable depth.');
    if (ext) raise('warn', 'Inside width is outside the published table; the allowable area is a planning extrapolation.');
    if ((type === 'ladder' || type === 'vent') && contents === 'single' && rung > 9 + 1e-9) raise('warn', 'Rung spacing is over 9 in (NEC 392.10 limit for single conductors).');
    if (cover === 'vent') notes.push('Ventilated cover: fill column unchanged. Ampacity can still change under 392.80, not calculated here.');
    let lb = 0, complete = true; rows.forEach((r) => { if (r.wt != null) lb += r.wt / 1000 * r.n; else complete = false; });
    let load = 'Cable weight is incomplete: enter lb per 1000 ft for every row to see a load class.';
    if (complete) {
      const letter = lb <= 50 + 1e-9 ? 'A' : lb <= 75 + 1e-9 ? 'B' : lb <= 100 + 1e-9 ? 'C' : null, pub = [8, 12, 16, 20].find((s) => Math.abs(s - span) <= 0.05);
      if (!letter) { load = fx(lb, 2) + ' lb/ft is past NEMA VE 1 class C (100 lb/ft). Check the manufacturer load class.'; raise('warn', 'Estimated load is over 100 lb/ft (class C).'); }
      else load = fx(lb, 2) + ' lb/ft fits a class ' + letter + ' working load (' + { A: 50, B: 75, C: 100 }[letter] + ' lb/ft)' + (pub ? ' at ' + pub + ' ft: NEMA VE 1 class ' + pub + letter + '.' : ', but ' + fx(span, 1) + ' ft is not a NEMA VE 1 span (8, 12, 16 or 20 ft).') + ' Planning check, not the maker’s table.';
    }
    if (status === 'pass') reasons.push('Within the cited fill limit.');
    if (Math.floor(len / span + 1e-9) > 500) throw new Error('Support span is very short for this run. Use a longer span.');
    let stations = 1, sx = span; while (sx < len - 1e-6) { stations++; sx += span; } stations++;
    const bendMult = v.shielded === 'yes' ? 12 : 8, bend = maxOD * bendMult;
    notes.push('Minimum bend ' + fx(bend, 2) + ' in is ' + bendMult + '× the largest OD (manufacturer / ICEA planning note, not an NEC 392 rule).', 'Metal cable tray must be grounded and bonded (NEC 392.60). Size a separate EGC with the Equipment Grounding tool.', 'Planning estimate. Verify the manufacturer load table and the AHJ. Not a PE stamp.');
    const color = { pass: '#56d6a4', warn: '#f0bc48', fail: '#f47078' }[status], bw = Math.min(100, p) * 3.2;
    const svg = '<svg viewBox="0 0 460 70" class="bkt-svg" role="img" aria-label="Fill percent of limit" font-family="system-ui,sans-serif"><rect width="460" height="70" rx="10" fill="#0e1118"/><rect x="20" y="26" width="320" height="16" rx="5" fill="#1b2230"/><rect x="20" y="26" width="' + bw.toFixed(1) + '" height="16" rx="5" fill="' + color + '"/><line x1="276" y1="20" x2="276" y2="48" stroke="#f0bc48"/><text x="276" y="16" font-size="10" text-anchor="middle" fill="#94a2b2">80 %</text><text x="350" y="40" font-size="14" font-weight="700" fill="#e8eef5">' + fx(p, 1) + ' %</text><text x="20" y="62" font-size="10" fill="#94a2b2">' + esc(status.toUpperCase()) + ' · ' + fx(area, 2) + ' in² of ' + (allowable != null ? fx(allowable, 2) + ' in²' : 'width') + '</text></svg>';
    return { headline: status.toUpperCase() + ' · ' + fx(p, 1) + ' % of limit', rows: [['Fill', fx(p, 1, '% of limit'), true], ['Status', status.toUpperCase(), status !== 'pass'], ['Cable area', fx(area, 3, 'in²')], ['Allowable', allowable != null ? fx(allowable, 2, 'in²') : 'Single layer (width)'], ['Cables', String(total)], ['Support stations', stations + ' at ' + fx(span, 1) + ' ft'], ['Min bend radius', fx(bend, 2, 'in')], ['Load', complete ? fx(lb, 2, 'lb/ft') : 'Incomplete']], warning: status === 'pass' ? '' : reasons.join(' '), steps: [basis, 'fill % = cable area / allowable = ' + fx(area, 3) + ' / ' + (allowable != null ? fx(allowable, 2) : '—') + '', load], notes, svg };
  }
  T.define({ id: 'cableLadder', root: 'bk-tray-root', title: 'Cable tray fill', lede: 'NEC Article 392 fill, rung check and load class for ladder, trough, solid-bottom and channel tray.',
    fields: [{ id: 'type', label: 'Tray type', choices: [['ladder', 'Ladder'], ['vent', 'Ventilated trough'], ['solid', 'Solid bottom'], ['channel', 'Ventilated channel']], def: 'ladder' }, { id: 'cover', label: 'Cover', choices: [['none', 'No cover'], ['vent', 'Ventilated cover'], ['solid', 'Solid cover']], def: 'none' },
      { id: 'contents', label: 'Contents', choices: [['single', 'Single conductors'], ['multi', 'Multiconductor, power or mixed'], ['control', 'Control and signal only']], def: 'multi' },
      { id: 'width', label: 'Inside width', unit: 'in', def: '12' }, { id: 'depth', label: 'Usable depth', unit: 'in', def: '4' }, { id: 'rung', label: 'Rung spacing', unit: 'in', def: '9' }, { id: 'length', label: 'Run length', unit: 'ft', def: '80' }, { id: 'span', label: 'Support span', unit: 'ft', def: '8' },
      { id: 'oda', label: 'Cable A overall OD', unit: 'in', def: '1.2' }, { id: 'na', label: 'Cable A count', def: '3' }, { id: 'wa', label: 'Cable A weight', unit: 'lb/kft', def: '', optional: true }, { id: 'biga', label: 'A is 1000 kcmil or larger', choices: [['no', 'No'], ['yes', 'Yes']], def: 'no', showIf: (v) => v.contents === 'single' },
      { id: 'odb', label: 'Cable B overall OD', unit: 'in', def: '', optional: true }, { id: 'nb', label: 'Cable B count', def: '', optional: true }, { id: 'wb', label: 'Cable B weight', unit: 'lb/kft', def: '', optional: true }, { id: 'bigb', label: 'B is 1000 kcmil or larger', choices: [['no', 'No'], ['yes', 'Yes']], def: 'no', showIf: (v) => v.contents === 'single' },
      { id: 'shielded', label: 'Shielded cable', choices: [['no', 'No (8× bend)'], ['yes', 'Yes (12× bend)']], def: 'no' }],
    compute: tray, example: { width: '18', contents: 'single', oda: '0.75', na: '12', odb: '1.2', nb: '2', biga: 'no', wa: '600' }, foot: 'Planning estimate. Verify the manufacturer load table and the AHJ. Not a PE stamp.' });
})(typeof window !== 'undefined' ? window : globalThis);
