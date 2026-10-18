/* Ported from the Beckify iOS app: EquipmentGrounding.swift, ReceptacleCircuit.swift, LightningProtection.swift.
   NEC 2023 / NFPA 780 section numbers only. Design aids; the adopted Code and the AHJ govern. */
(function (global) {
  'use strict';
  const T = global.BeckifyTool, fx = T.fixed, esc = T.esc;
  const ORDER = ['14', '12', '10', '8', '6', '4', '3', '2', '1', '1/0', '2/0', '3/0', '4/0', '250', '300', '350', '400', '500', '600', '700', '750', '800', '900', '1000'];
  const KC = new Set(['250', '300', '350', '400', '500', '600', '700', '750', '800', '900', '1000']);
  const label = (s) => (s === '1200' ? '1200 kcmil' : s + (KC.has(s) ? ' kcmil' : ' AWG'));
  const CM = { '14': 4110, '12': 6530, '10': 10380, '8': 16510, '6': 26240, '4': 41740, '3': 52620, '2': 66360, '1': 83690, '1/0': 105600, '2/0': 133100, '3/0': 167800, '4/0': 211600, '250': 250000, '300': 300000, '350': 350000, '400': 400000, '500': 500000, '600': 600000, '700': 700000, '750': 750000, '800': 800000, '900': 900000, '1000': 1000000 };
  const AMP75 = { cu: { '14': 20, '12': 25, '10': 35, '8': 50, '6': 65, '4': 85, '3': 100, '2': 115, '1': 130, '1/0': 150, '2/0': 175, '3/0': 200, '4/0': 230, '250': 255, '300': 285, '350': 310, '400': 335, '500': 380, '600': 420, '700': 460, '750': 475, '800': 490, '900': 520, '1000': 545 },
    al: { '12': 20, '10': 30, '8': 40, '6': 50, '4': 65, '3': 75, '2': 90, '1': 100, '1/0': 120, '2/0': 135, '3/0': 155, '4/0': 180, '250': 205, '300': 230, '350': 250, '400': 270, '500': 310, '600': 340, '700': 375, '750': 385, '800': 395, '900': 425, '1000': 445 } };
  const K = { cu: 12.9, al: 21.2 };
  const OCPD = [10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 110, 125, 150, 175, 200, 225, 250, 300, 350, 400, 450, 500, 600, 700, 800, 1000, 1200, 1600, 2000, 2500, 3000, 4000, 5000, 6000];
  const T250 = [[15, '14', '12'], [20, '12', '10'], [60, '10', '8'], [100, '8', '6'], [200, '6', '4'], [300, '4', '2'], [400, '3', '1'], [500, '2', '1/0'], [600, '1', '2/0'], [800, '1/0', '3/0'], [1000, '2/0', '4/0'], [1200, '3/0', '250'], [1600, '4/0', '350'], [2000, '250', '400'], [2500, '350', '600'], [3000, '400', '600'], [4000, '500', '750'], [5000, '700', '1200'], [6000, '800', '1200']];
  const MAT = [['cu', 'Copper'], ['al', 'Aluminum']];
  const sizes = (al) => ORDER.filter((s) => !al || AMP75.al[s]).map((s) => [s, label(s)]);

  /* ---------- Equipment grounding conductor ---------- */
  function egc(v) {
    const amps = T.positive(v, 'amps', 'Amps'), isOCPD = v.basis !== 'load', ctx = v.context;
    if (ctx === 'none') throw new Error('Phase conductors only: no equipment grounding conductor is implied. Pick 1Ø, multiwire or 3Ø.');
    let basis;
    if (isOCPD) basis = amps; else { basis = OCPD.find((o) => o >= amps); if (!basis) throw new Error('Load is above the largest standard device (6000 A).'); }
    const row = T250.find((r) => r[0] + 1e-9 >= basis);
    if (!row) throw new Error('OCPD rating is above the last transcribed row of Table 250.122 (6000 A).');
    let size = v.material === 'al' ? row[2] : row[1], capped = false;
    const notes = ['Table 250.122 sizes the EGC from the OCPD ahead of the equipment, not from ampacity.', '250.122(B) proportional increase for voltage-drop upsizing is not applied.', 'A service grounding electrode conductor is Table 250.66, not this row.'];
    if (!isOCPD) notes.unshift('Provisional: OCPD not entered. Sized from the next 240.6(A) device (' + basis + ' A) above the load. Enter the real OCPD to lock the row.');
    const ug = v.ungrounded;
    if (ug && ug !== 'none' && CM[size] && CM[ug]) {
      if (CM[ug] + 1e-6 < CM[size]) { size = ug; capped = true; notes.push('250.122(A): the EGC need not be larger than the ungrounded conductors (' + label(ug) + ').'); }
      else if (CM[ug] > CM[size] + 1e-6) notes.push('Ungrounded conductors are larger than this table minimum; 250.122(B) may require a larger EGC if the increase was for voltage drop.');
    }
    return { headline: 'EGC ' + label(size) + (v.material === 'al' ? ' aluminum' : ' copper'), rows: [['Equipment ground', label(size), true], ['Table row (not exceeding)', row[0] + ' A'], ['Basis', isOCPD ? 'OCPD ' + fx(amps, 0, 'A') + ' entered' : 'Provisional, next device ' + basis + ' A'], ['Capped to ungrounded', capped ? 'Yes' : 'No']], steps: ['Find the first Table 250.122 row with OCPD ≤ ' + row[0] + ' A that covers ' + basis + ' A.', 'Copper ' + row[1] + ', aluminum ' + (row[2] === '1200' ? '1200 kcmil' : row[2]) + '.'], notes };
  }
  T.define({ id: 'equipmentGround', root: 'bk-egc-root', title: 'Equipment grounding conductor', lede: 'NEC 2023 Table 250.122 minimum EGC from the overcurrent device.',
    fields: [{ id: 'amps', label: 'Amps', unit: 'A', def: '60' }, { id: 'basis', label: 'Amps are', choices: [['ocpd', 'OCPD rating (entered)'], ['load', 'Load amps (infer next device)']], def: 'ocpd' },
      { id: 'material', label: 'Material', choices: MAT, def: 'cu' }, { id: 'context', label: 'Context', choices: [['singlePhase', '1Ø'], ['multiwire', 'Multiwire'], ['threePhase', '3Ø'], ['none', 'Phase conductors only']], def: 'threePhase' },
      { id: 'ungrounded', label: 'Ungrounded conductor size (cap)', choices: [['none', 'Not entered']].concat(sizes(false)), def: 'none' }],
    compute: egc, example: { amps: '100', ungrounded: '10' }, foot: 'Design aid transcribed from NEC 2023 Table 250.122. Confirm the current Code and the AHJ. Not a PE stamp.' });

  /* ---------- Receptacle circuit ---------- */
  function minCond(b, m) { return m === 'cu' ? (b <= 15 ? '14' : '12') : (b <= 15 ? '12' : '10'); }
  function yokes(va, cont) { return !(va > 0) ? 0 : Math.floor((cont ? va * 0.8 : va) / 180 + 1e-9); }
  function recept(v) {
    const b = Math.round(T.need(v, 'breaker', 'Breaker')), volts = T.positive(v, 'volts', 'Voltage'), feet = T.positive(v, 'feet', 'One-way length');
    if (b !== 15 && b !== 20) throw new Error('Circuit rating must be 15 A or 20 A for 5-15R / 5-20R general-purpose receptacles.');
    const mat = v.material, size = v.size, cont = v.continuous === 'yes';
    if (mat === 'al' && !AMP75.al[size]) throw new Error('Aluminum starts at 12 AWG.');
    const pl = T.optional(v, 'planned'); if (pl != null && pl < 0) throw new Error('Planned load cannot be negative.');
    const planned = pl && pl > 0 ? pl : null;
    const cva = b * volts, usable = cont ? cva * 0.8 : cva, full = yokes(cva, false), cn = yokes(cva, true);
    const hi = cn, lo = Math.min(hi, Math.floor(b * 0.8 / 2)), g = [Math.max(1, lo), Math.max(1, hi)];
    const need = minCond(b, mat), okC = ORDER.indexOf(size) >= ORDER.indexOf(need);
    const amps = planned != null ? planned / volts : usable / volts;
    const vd = 2 * K[mat] * amps * feet / CM[size], pct = vd / volts * 100, ampc = AMP75[mat][size];
    const nd = v.occupancy === 'dwelling';
    const rows = [[nd ? 'Receptacles (practice)' : 'Receptacles (220.14(I))', nd ? g[0] + '–' + g[1] : String(cont ? cn : full), true], ['Circuit VA', fx(cva, 0, 'VA')], ['Usable VA', fx(usable, 0, 'VA')], ['Conductor', okC ? 'OK for ' + b + ' A (min ' + label(need) + ')' : 'Below 240.4(D) minimum ' + label(need), false], ['5-20R allowed', b >= 20 ? 'Yes' : 'Not on a 15 A circuit'], ['Check current', fx(amps, 1, 'A') + (planned != null ? ' (planned)' : ' (usable)')], ['Voltage drop', fx(vd, 2, 'V') + ' · ' + fx(pct, 2, '%'), pct > 3], ['Ampacity 75 °C', ampc + ' A' + (ampc >= amps ? '' : ' (too small)')]];
    if (planned != null) rows.push(['Planned load', fx(planned / cva * 100, 0, '% of circuit') + (planned <= usable + 1e-9 ? ' · fits' : ' · over usable')]);
    const notes = [];
    if (b < 20) notes.push('A 15 A circuit takes 5-15R receptacles when there are two or more (Table 210.21(B)(3)).');
    if (!okC) notes.push(label(size) + ' ' + (mat === 'cu' ? 'copper' : 'aluminum') + ' is below the 240.4(D) minimum of ' + label(need) + ' for a ' + b + ' A breaker.');
    if (mat === 'al') notes.push('Aluminum on 15/20 A receptacles needs devices marked CO/ALR (406.3).');
    notes.push(nd ? 'Dwelling: the NEC sets no receptacle count for general-purpose circuits (220.14(J)); ' + g[0] + '–' + g[1] + ' is common practice. Kitchen, laundry and bath circuits are separate (210.11(C)).' : 'Non-dwelling: 180 VA per yoke. ' + full + ' at 100 %, ' + cn + ' continuous (210.19(A), 210.20(A)).');
    notes.push('Voltage drop lumps the load at the far receptacle; 3 % / 5 % are Informational Notes, not hard limits.', v.feed === 'through' ? 'Through-feed carries the downstream load across device terminals; use screw terminals and pigtail a multiwire neutral (300.13(B)).' : 'Pigtailing keeps downstream outlets live if a device fails; each splice adds box fill (314.16).', 'Based on the 2023 NEC. Local amendments and the AHJ govern.');
    return { headline: (nd ? g[0] + '–' + g[1] : (cont ? cn : full)) + ' receptacles on a ' + b + ' A circuit', rows, steps: ['Circuit VA = ' + b + ' × ' + volts + ' = ' + fx(cva, 0), 'Yokes = floor(' + (cont ? '0.8 × ' : '') + 'VA / 180)', 'VD = 2 K I L / CM = 2 × ' + K[mat] + ' × ' + fx(amps, 2) + ' × ' + feet + ' / ' + CM[size]], notes, warning: pct > 3 ? 'Voltage drop is over 3 %. Use a larger conductor or a shorter run.' : '' };
  }
  T.define({ id: 'receptacleCircuit', root: 'bk-recept-root', title: 'Receptacle circuit', lede: 'How many 5-20R receptacles fit on a 15 or 20 A branch circuit, with a conductor and voltage-drop check.',
    fields: [{ id: 'breaker', label: 'Breaker', unit: 'A', choices: [['15', '15 A'], ['20', '20 A']], def: '20' }, { id: 'volts', label: 'Voltage', unit: 'V', def: '120' },
      { id: 'occupancy', label: 'Occupancy', choices: [['nonDwelling', 'Commercial / non-dwelling'], ['dwelling', 'Dwelling']], def: 'nonDwelling' }, { id: 'continuous', label: 'Continuous load', choices: [['yes', 'Yes (80 %)'], ['no', 'No (100 %)']], def: 'yes' },
      { id: 'size', label: 'Conductor', choices: sizes(false).slice(0, 13), def: '12' }, { id: 'material', label: 'Material', choices: MAT, def: 'cu' }, { id: 'feet', label: 'One-way length', unit: 'ft', def: '75' },
      { id: 'planned', label: 'Planned load', unit: 'VA', def: '', optional: true, help: 'Optional. Approx. watts for resistive loads.' }, { id: 'feed', label: 'Wiring', choices: [['pigtail', 'Pigtailed'], ['through', 'Through-feed']], def: 'pigtail' }],
    compute: recept, example: { breaker: '15', size: '14', feet: '120', planned: '1200' }, foot: 'Design aid based on the 2023 NEC. The AHJ governs.' });

  /* ---------- Lightning protection (NFPA 780) ---------- */
  const sphereProfile = (h, r) => { const hh = Math.min(h, r), d = Math.sqrt(2 * r * hh - hh * hh); return { d, pts: Array.from({ length: 41 }, (_, i) => { const x = d * i / 40, dx = d - x; return [x, x >= d ? 0 : Math.max(0, r - Math.sqrt(r * r - dx * dx))]; }) }; };
  function lpsSvg(h, r) {
    const p = sphereProfile(h, r), W = 460, H = 180, xs = (W - 60) / Math.max(p.d, 1), ys = 140 / Math.max(h, 1), s = Math.min(xs, ys), x0 = 30, gy = 160;
    let path = ''; p.pts.forEach((q, i) => { path += (i ? 'L' : 'M') + (x0 + q[0] * s).toFixed(1) + ' ' + (gy - q[1] * s).toFixed(1); });
    return '<svg viewBox="0 0 ' + W + ' ' + H + '" class="bkt-svg" role="img" aria-label="Rolling sphere protection profile" font-family="system-ui,sans-serif"><rect width="' + W + '" height="' + H + '" rx="10" fill="#0e1118"/><line x1="10" y1="' + gy + '" x2="' + (W - 10) + '" y2="' + gy + '" stroke="#94a2b2"/><line x1="' + x0 + '" y1="' + gy + '" x2="' + x0 + '" y2="' + (gy - Math.min(h, r) * s) + '" stroke="#e09c56" stroke-width="3"/><path d="' + path + ' L' + (x0 + p.d * s).toFixed(1) + ' ' + gy + ' L' + x0 + ' ' + gy + ' Z" fill="#40bad6" fill-opacity=".18" stroke="#40bad6" stroke-width="2"/><text x="' + (x0 + 6) + '" y="22" font-size="11" fill="#e8eef5">Mast ' + fx(h, 0) + ' ft · sphere ' + r + ' ft</text><text x="' + (W - 12) + '" y="' + (gy - 6) + '" font-size="11" text-anchor="end" fill="#94a2b2">Protected to ' + fx(p.d, 0) + ' ft from the mast</text></svg>';
  }
  function lps(v) {
    const L = T.positive(v, 'len', 'Length'), Wd = T.positive(v, 'wid', 'Width'), H = T.positive(v, 'height', 'Height'), th = T.positive(v, 'term', 'Terminal height'), rise = T.need(v, 'rise', 'Roof rise');
    if (rise < 0 || rise > 24) throw new Error('Roof rise should be 0 to 24 inches per 12.');
    if (th < 10) throw new Error('Strike termination devices stand at least 10 in above what they protect (4.6).');
    const haz = v.hazardous === 'yes', span = Math.min(L, Wd);
    const pitch = rise / 12 / 2, lim = span <= 40 ? 1 / 8 : 1 / 4;
    const roof = !(rise > 0) ? 'Flat' : pitch <= lim + 1e-9 ? 'Gently sloping' : 'Pitched (steep)', steep = roof === 'Pitched (steep)';
    const per = 2 * (L + Wd), sp = th >= 24 ? 25 : 20;
    const perT = Math.max(4, Math.ceil(per / sp - 1e-9)), ridge = Math.max(2, Math.ceil(Math.max(0, Math.max(L, Wd) - 4) / sp) + 1);
    const interior = steep || !(L > 50 && Wd > 50) ? 0 : Math.max(0, Math.ceil(L / 50 - 1e-9) - 1) * Math.max(0, Math.ceil(Wd / 50 - 1e-9) - 1);
    const downs = Math.max(2, Math.ceil(per / 100 - 1e-9)), n = downs >= 4 ? 2.25 : downs >= 2 ? 1.5 : 1, sep = H / (6 * n);
    const r = haz ? 100 : 150, cone = haz ? null : H <= 25 ? 2 * H : H <= 50 ? H : null, total = steep ? ridge : perT + interior;
    const rows = [['Roof class', roof], ['Strike terminals', String(total), true], ['Spacing', sp + ' ft'], ['Down conductors', String(downs), true], ['Materials', H > 75 ? 'Class II (over 75 ft)' : 'Class I'], ['Rolling sphere', r + ' ft'], ['Cone zone at ground', cone == null ? 'Use rolling sphere' : fx(cone, 0, 'ft')], ['Separation (air)', fx(sep, 1, 'ft')], ['Perimeter', fx(per, 0, 'ft')]];
    if (steep) rows.splice(2, 0, ['Ridge terminals', String(ridge)]); else rows.splice(2, 0, ['Perimeter / field', perT + ' / ' + interior]);
    return { headline: total + ' terminals · ' + downs + ' down conductors', rows, steps: ['Perimeter = 2 (L + W) = ' + fx(per, 0) + ' ft', 'Terminal spacing ' + sp + ' ft (' + (th >= 24 ? 'devices ≥ 24 in' : 'devices under 24 in') + ')', 'Down conductors ≥ 2, average spacing ≤ 100 ft', 'Separation D = h / (6 n) × Km, n = ' + n + ', Km = 1 (air)'], notes: ['NFPA 780-2023 section numbers only (4.5–4.8, 4.15). The adopted edition, listed components and the AHJ govern.', 'One terminal within 2 ft of each ridge end and outside corner.', haz ? 'Flammable-vapor and explosives structures use the 100 ft sphere and chapters 7 and 8.' : 'Structures over 50 ft tall use the rolling sphere; the cone only applies up to 50 ft.'], svg: lpsSvg(Math.min(H, r), r) };
  }
  T.define({ id: 'lightningProtection', root: 'bk-lps-root', title: 'Lightning protection (NFPA 780)', lede: 'Strike-terminal and down-conductor counts, material class, rolling-sphere reach and separation distance.',
    fields: [{ id: 'len', label: 'Length', unit: 'ft', def: '120' }, { id: 'wid', label: 'Width', unit: 'ft', def: '80' }, { id: 'height', label: 'Height', unit: 'ft', def: '30' },
      { id: 'rise', label: 'Roof rise per 12', unit: 'in', def: '0' }, { id: 'term', label: 'Terminal height', unit: 'in', def: '12' }, { id: 'hazardous', label: 'Hazardous contents', choices: [['no', 'No'], ['yes', 'Flammable vapor / explosives']], def: 'no' }],
    compute: lps, example: { len: '60', wid: '40', height: '35', rise: '6', term: '24' }, foot: 'Design aid. Section numbers only, in plain words. The adopted edition, listed components and the AHJ govern.' });
})(typeof window !== 'undefined' ? window : globalThis);
