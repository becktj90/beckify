/* Ported from the Beckify iOS app (FlexibleCableAmpacity.swift): NEC Table 400.5 portable cord and Type W ampacity. Planning aid. */
(function (global) {
  'use strict';
  const T = global.BeckifyTool, fx = T.fixed, esc = T.esc;
  const FAM = { so: 'SO / SOOW (600 V)', sjo: 'SJO / SJOW (300 V)', sto: 'STO / SJT (thermoplastic)', typeW: 'Type W (portable power)' };
  const CORD = [['18', 7, 10], ['17', 9, 12], ['16', 10, 13], ['15', 12, 16], ['14', 15, 18], ['12', 20, 25], ['10', 25, 30], ['8', 35, 40], ['6', 45, 55], ['4', 60, 70], ['2', 80, 95]];
  const TW = [['8', 80, 74, 65], ['6', 105, 99, 87], ['4', 140, 130, 114], ['2', 190, 174, 152], ['1', 220, 202, 177], ['1/0', 260, 234, 205], ['2/0', 300, 271, 237], ['3/0', null, 313, 274], ['4/0', 405, 361, 316], ['250', null, null, 352], ['350', null, null, 433], ['500', 700, null, 536]];
  const AMB = { 60: [[25, 1.08], [30, 1], [35, 0.91], [40, 0.82], [45, 0.71], [50, 0.58], [55, 0.41]], 75: [[25, 1.05], [30, 1], [35, 0.94], [40, 0.88], [45, 0.82], [50, 0.75], [55, 0.67], [60, 0.58], [65, 0.47], [70, 0.33]], 90: [[25, 1.04], [30, 1], [35, 0.96], [40, 0.91], [45, 0.87], [50, 0.82], [55, 0.76], [60, 0.71], [65, 0.65], [70, 0.58], [75, 0.5], [80, 0.41], [85, 0.29]] };
  const KC = new Set(['250', '300', '350', '400', '500', '600', '750', '1000']);
  const lab = (s) => s + (KC.has(s) ? ' kcmil' : ' AWG');
  const ambient = (t, col) => { for (const p of AMB[col]) if (t <= p[0]) return p[1]; return 0; };
  const bundle = (n) => (n <= 3 ? 1 : n <= 6 ? 0.8 : n <= 9 ? 0.7 : n <= 20 ? 0.5 : n <= 30 ? 0.45 : n <= 40 ? 0.4 : 0.35);
  const cord = (f) => f !== 'typeW';
  function rowsFor(f, ccc) {
    if (cord(f)) return ccc < 2 ? [] : CORD.map((r) => [r[0], ccc <= 2 ? r[2] : r[1]]);
    const i = ccc === 1 ? 1 : ccc === 2 ? 2 : 3;
    return TW.filter((r) => r[i] != null).map((r) => [r[0], r[i]]);
  }
  function cable(v) {
    const f = v.family, conductors = T.need(v, 'conductors', 'Conductor count'), ccc = T.need(v, 'ccc', 'Current-carrying count');
    for (const [n, x] of [['Conductor count', conductors], ['Current-carrying count', ccc]]) if (!(x >= 1) || Math.abs(x - Math.round(x)) > 1e-9) throw new Error(n + ' must be a whole number of 1 or more.');
    if (ccc > conductors) throw new Error('Current-carrying conductors (' + ccc + ') cannot exceed the conductor count (' + conductors + '). A grounding conductor is not current-carrying.');
    const amb = T.need(v, 'ambient', 'Ambient temperature'), col = +v.insulation;
    if (f === 'typeW' && col !== 90) throw new Error('Type W here is the 90 °C column of Table 400.5(A)(2). The 60 °C and 75 °C columns are not transcribed.');
    if (cord(f) && ccc < 2) throw new Error('Table 400.5(A)(1) starts at two current-carrying conductors. A single conductor is Type W.');
    const rows = rowsFor(f, ccc), size = v.size, hit = rows.find((r) => r[0] === size);
    if (!hit) throw new Error(lab(size) + ' is not listed for ' + FAM[f] + ' with ' + ccc + ' current-carrying conductor' + (ccc === 1 ? '' : 's') + '. Missing cells are not interpolated.');
    const af = ambient(amb, col); if (af <= 0) throw new Error('Ambient ' + fx(amb, 0) + ' °C is outside the ' + col + ' °C correction range in Table 310.15(B)(1).');
    const bf = bundle(ccc), allow = (r) => r[1] * af * bf, allowable = allow(hit);
    const out = [['Table ampacity', hit[1] + ' A'], ['Ambient factor', fx(af, 2)], ['Adjustment factor', fx(bf, 2)], ['Allowable ampacity', fx(allowable, 1, 'A'), true], ['Table', cord(f) ? 'NEC Table 400.5(A)(1)' + (ccc <= 2 ? ' Column B' : ' Column A') : 'NEC Table 400.5(A)(2), 90 °C']];
    let headline = lab(size) + ' · ' + fx(allowable, 1) + ' A allowable', warning = '';
    const ld = T.optional(v, 'load');
    if (ld != null) {
      if (!(ld > 0)) throw new Error('Target load must be positive.');
      const need = v.continuous === 'yes' ? ld * 1.25 : ld;
      if (need > 400 + 1e-9) throw new Error('This selector stops at 400 A. ' + fx(need, 1) + ' A is above that. Split the load or look it up in the Code book.');
      const pick = rows.find((r) => allow(r) + 1e-9 >= need);
      out.push(['Required', fx(need, 1, 'A')], ['Selected size', allowable + 1e-9 >= need ? 'Passes' : 'Too small', allowable + 1e-9 < need]);
      if (pick) out.push(['Smallest that works', lab(pick[0]) + ' at ' + fx(allow(pick), 1, 'A'), true]); else warning = 'No size in this transcription carries ' + fx(need, 1) + ' A under these conditions.';
      if (allowable + 1e-9 < need && pick) warning = lab(size) + ' is too small. Use ' + lab(pick[0]) + ' or larger.';
    }
    const notes = [cord(f) ? 'Table 400.5(A)(1) has one copper value per size and column. Insulation temperature only changes ambient correction.' : 'Only the 90 °C Type W column is transcribed. A 75 °C termination can still limit the circuit (110.14(C)).', 'The equipment grounding conductor is not counted as current-carrying.', 'Cord ends on a listed cord connector (400.10); this is not a conduit-fill problem. Overcurrent protection (240.5) is not calculated here.', 'Planning aid. The AHJ and the cable manufacturer prevail. Copper only.'];
    if (ccc > 3) notes.unshift('More than three current-carrying conductors: Table 400.5(A)(3) multiplies the three-conductor value by ' + fx(bf, 2) + '.');
    const mx = Math.max.apply(null, rows.map((r) => r[1]));
    const W = 460, rh = 18, H = rows.length * rh + 14;
    let svg = '<svg viewBox="0 0 ' + W + ' ' + H + '" class="bkt-svg" role="img" aria-label="Table ampacity by size" font-family="system-ui,sans-serif"><rect width="' + W + '" height="' + H + '" rx="10" fill="#0e1118"/>';
    rows.forEach((r, i) => { const y = 8 + i * rh, w = 250 * r[1] / mx, sel = r[0] === size; svg += '<text x="10" y="' + (y + 12) + '" font-size="11" fill="' + (sel ? '#e8eef5' : '#94a2b2') + '">' + esc(lab(r[0])) + '</text><rect x="90" y="' + y + '" width="' + w.toFixed(1) + '" height="13" rx="3" fill="' + (sel ? '#56d6a4' : '#40bad6') + '" fill-opacity="' + (sel ? 1 : 0.55) + '"/><text x="' + (96 + w).toFixed(1) + '" y="' + (y + 11) + '" font-size="10" fill="#e8eef5">' + r[1] + ' A</text>'; });
    return { headline, rows: out, warning, steps: ['Allowable = table ampacity × Table 310.15(B)(1) ambient factor × Table 400.5(A)(3) adjustment', '= ' + hit[1] + ' × ' + fx(af, 2) + ' × ' + fx(bf, 2) + ' = ' + fx(allowable, 1) + ' A'], notes, svg: svg + '</svg>' };
  }
  const allSizes = [], seen = {}; CORD.concat(TW).forEach((r) => { if (!seen[r[0]]) { seen[r[0]] = 1; allSizes.push([r[0], lab(r[0])]); } });
  allSizes.sort((a, b) => { const o = ['18', '17', '16', '15', '14', '12', '10', '8', '6', '4', '3', '2', '1', '1/0', '2/0', '3/0', '4/0', '250', '350', '500']; return o.indexOf(a[0]) - o.indexOf(b[0]); });
  T.define({ id: 'flexibleCable', root: 'bk-cable-root', title: 'Flexible cable ampacity', lede: 'Portable cord (SO, SJO, STO) and Type W ampacity from NEC Table 400.5.',
    fields: [{ id: 'family', label: 'Cable family', choices: Object.keys(FAM).map((k) => [k, FAM[k]]), def: 'so' }, { id: 'size', label: 'Conductor size', choices: allSizes, def: '12' },
      { id: 'conductors', label: 'Conductors in cable', def: '3' }, { id: 'ccc', label: 'Current-carrying', def: '3', help: 'The grounding conductor does not count.' },
      { id: 'insulation', label: 'Insulation column', unit: '°C', choices: [['60', '60'], ['75', '75'], ['90', '90']], def: '90' }, { id: 'ambient', label: 'Ambient', unit: '°C', def: '30' },
      { id: 'continuous', label: 'Continuous load', choices: [['no', 'No'], ['yes', 'Yes (×1.25)']], def: 'no' }, { id: 'load', label: 'Target load', unit: 'A', def: '', optional: true, help: 'Optional. Finds the smallest size that works.' }],
    compute: cable, example: { family: 'typeW', size: '4', conductors: '4', ccc: '3', ambient: '40', load: '100' }, foot: 'Planning aid. The AHJ and the manufacturer prevail. Not a listing, not a PE stamp, and not permission to use cord as fixed wiring.' });
})(typeof window !== 'undefined' ? window : globalThis);
