/* Ported from the Beckify iOS app (MotorMath.swift, HomeworkMath.swift): Motor speed / slip / torque, Resistor color code. */
(function (global) {
  'use strict';
  const T = global.BeckifyTool, si = T.si, fx = T.fixed;
  const NM = 1.3558179483314004;

  function motor(v) {
    const f = T.positive(v, 'freq', 'Frequency'), poles = Math.round(T.need(v, 'poles', 'Poles'));
    if (poles < 2) throw new Error('Pole count must be 2 or more.');
    if (poles % 2) throw new Error('Pole count must be even.');
    const sync = 120 * f / poles;
    let rpm, slip;
    if (v.mode === 'slip') { slip = T.need(v, 'slip', 'Slip'); if (!(slip >= 0 && slip <= 100)) throw new Error('Slip must be between 0 and 100 %.'); rpm = sync * (1 - slip / 100); }
    else {
      rpm = T.positive(v, 'rpm', 'Nameplate RPM');
      if (rpm > sync) throw new Error('Nameplate RPM (' + Math.round(rpm) + ') is above synchronous speed (' + Math.round(sync) + '). Check the pole count and the line frequency.');
      slip = (sync - rpm) / sync * 100;
    }
    const rows = [['Synchronous speed', fx(sync, 1, 'rpm')], ['Rotor speed', fx(rpm, 1, 'rpm'), true], ['Slip', fx(slip, 2, '%'), true], ['Rotor slip frequency', fx(slip / 100 * f, 3, 'Hz')]];
    const steps = ['n_s = 120 f / p = 120 × ' + fx(f, 3) + ' / ' + poles + ' = ' + fx(sync, 1) + ' rpm', 'slip = (n_s − n) / n_s'];
    if (v.hp !== '' && v.hp != null) {
      const hp = T.positive(v, 'hp', 'Horsepower'), lbft = 5252 * hp / rpm;
      rows.push(['Shaft torque', fx(lbft, 2, 'lb·ft'), true], ['Shaft torque', fx(lbft * NM, 2, 'N·m')]);
      steps.push('T = 5252 · HP / RPM = ' + fx(lbft, 2) + ' lb·ft');
    }
    return { headline: fx(rpm, 0) + ' rpm, slip ' + fx(slip, 2) + ' %', rows, steps, notes: ['Induction motor nameplate RPM is always below synchronous speed; the gap is slip.', 'Torque uses 5252 = 33 000 ft·lb/min per HP ÷ 2π.'] };
  }
  T.define({ id: 'motorSpeed', root: 'bk-motor-root', title: 'Motor speed, slip & torque', lede: 'Synchronous speed, slip and shaft torque.',
    fields: [{ id: 'mode', label: 'From', choices: [['rpm', 'Nameplate RPM'], ['slip', 'Slip %']], def: 'rpm' },
      { id: 'freq', label: 'Line frequency', unit: 'Hz', def: '60' }, { id: 'poles', label: 'Poles', def: '4' },
      { id: 'rpm', label: 'Nameplate RPM', unit: 'rpm', def: '1750', showIf: (v) => v.mode !== 'slip' }, { id: 'slip', label: 'Slip', unit: '%', def: '2.8', showIf: (v) => v.mode === 'slip' },
      { id: 'hp', label: 'Horsepower', unit: 'HP', def: '5', optional: true, help: 'Optional. Gives shaft torque.' }],
    compute: motor, example: { freq: '50', poles: '6', rpm: '960' }, foot: 'Design aid. Check the motor nameplate.' });

  /* ---------- Resistor color code ---------- */
  const COL = { black: ['#222', 0, 1, null], brown: ['#7a4a1e', 1, 10, 1], red: ['#d33', 2, 100, 2], orange: ['#f08a1c', 3, 1e3, null], yellow: ['#f2d12a', 4, 1e4, null], green: ['#2aa84a', 5, 1e5, 0.5], blue: ['#2f6fe0', 6, 1e6, 0.25], violet: ['#8a4ad6', 7, 1e7, 0.1], gray: ['#8c8c8c', 8, 1e8, 0.05], white: ['#f2f2f2', 9, 1e9, null], gold: ['#d4a82a', null, 0.1, 5], silver: ['#c0c0c0', null, 0.01, 10] };
  const NAMES = Object.keys(COL);
  const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
  const opts = (f) => NAMES.filter((n) => f(COL[n])).map((n) => [n, cap(n)]);
  function bandSvg(bands) {
    const W = 300, H = 70; let s = '<svg viewBox="0 0 ' + W + ' ' + H + '" class="bkt-svg" role="img" aria-label="Resistor bands: ' + bands.join(', ') + '"><rect width="' + W + '" height="' + H + '" rx="10" fill="#0e1118"/><line x1="10" y1="35" x2="60" y2="35" stroke="#94a2b2" stroke-width="3"/><line x1="240" y1="35" x2="290" y2="35" stroke="#94a2b2" stroke-width="3"/><rect x="55" y="12" width="190" height="46" rx="16" fill="#d9c7a0"/>';
    const n = bands.length, step = 150 / n;
    bands.forEach((b, i) => { const x = 78 + i * step + (i === n - 1 ? 14 : 0); s += '<rect x="' + x.toFixed(1) + '" y="12" width="12" height="46" fill="' + COL[b][0] + '" stroke="#000" stroke-opacity=".6"/>'; });
    return s + '</svg>';
  }
  const fromBand = (b) => b;
  function fmtR(o) { return si(o, 'Ω'); }
  function resistor(v) {
    let bands, ohms, tol, steps;
    if (v.mode === 'encode') {
      const r = T.positive(v, 'ohms', 'Resistance'), nb = v.count === '5' ? 5 : 4, digits = nb === 4 ? 2 : 3, tolName = v.tolE || 'gold', t = COL[tolName][3];
      let mag = r, mult = 1;
      while (mag >= (digits === 2 ? 99.5 : 999.5)) { mag /= 10; mult *= 10; if (mult > 1e9) throw new Error('Resistance is too large for this color code.'); }
      while (mag < Math.pow(10, digits - 1) && mult > 0.01) { mag *= 10; mult /= 10; }
      let rounded = Math.round(mag);
      if (rounded < 1) throw new Error('Resistance is too small for this color code.');
      if (rounded >= Math.pow(10, digits)) { rounded /= 10; mult *= 10; if (mult > 1e9) throw new Error('Resistance is too large for this color code.'); }
      const mb = NAMES.find((n) => Math.abs(COL[n][2] - mult) < mult * 1e-9);
      if (!mb) throw new Error('No multiplier band for this value.');
      const ds = String(rounded).padStart(digits, '0').split('').map((d) => NAMES[+d]);
      bands = ds.concat([mb, tolName]); ohms = rounded * mult; tol = t;
      steps = ['Significant digits: ' + rounded + ', multiplier ×' + mult];
      if (Math.abs(ohms - r) > r * 1e-9) steps.push('Rounded from ' + fmtR(r) + ' to the nearest value the bands can show.');
    } else {
      const nb = v.count === '5' ? 5 : 4, ds = [v.d1, v.d2].concat(nb === 5 ? [v.d3] : []), m = v.mult, tl = v.tol;
      if (ds.some((d) => COL[d][1] == null)) throw new Error('Gold and silver are not digit bands.');
      if (COL[tl][3] == null) throw new Error('That band is not a tolerance.');
      const val = ds.reduce((a, d) => a * 10 + COL[d][1], 0);
      ohms = val * COL[m][2]; tol = COL[tl][3]; bands = ds.concat([m, tl]);
      steps = [nb === 5 ? 'R = (100×d1 + 10×d2 + d3) × 10^n' : 'R = (10×d1 + d2) × 10^n', 'R = ' + val + ' × ' + COL[m][2]];
    }
    const lo = ohms * (1 - tol / 100), hi = ohms * (1 + tol / 100);
    return { headline: fmtR(ohms) + ' ±' + tol + '%', rows: [['Resistance', fmtR(ohms), true], ['Tolerance', '±' + tol + ' %'], ['Range', fmtR(lo) + ' to ' + fmtR(hi)], ['Bands', bands.map(cap).join(' · ')]], steps, notes: ['Tolerance band reading is by position; the gap before it marks the end.'], svg: bandSvg(bands) };
  }
  const digitOpts = opts((c) => c[1] != null), tolOpts = opts((c) => c[3] != null);
  const dec = (v) => v.mode !== 'encode';
  T.define({ id: 'resistorColor', root: 'bk-rcolor-root', title: 'Resistor color code', lede: 'Decode 4- and 5-band resistors, or find the bands for a value.',
    fields: [{ id: 'mode', label: 'Mode', choices: [['decode', 'Bands → value'], ['encode', 'Value → bands']], def: 'decode' },
      { id: 'count', label: 'Bands', choices: [['4', '4-band'], ['5', '5-band']], def: '4' },
      { id: 'd1', label: 'Digit 1', choices: digitOpts, def: 'brown', showIf: dec }, { id: 'd2', label: 'Digit 2', choices: digitOpts, def: 'black', showIf: dec },
      { id: 'd3', label: 'Digit 3', choices: digitOpts, def: 'black', showIf: (v) => dec(v) && v.count === '5' },
      { id: 'mult', label: 'Multiplier', choices: opts((c) => c[2] != null), def: 'red', showIf: dec }, { id: 'tol', label: 'Tolerance', choices: tolOpts, def: 'gold', showIf: dec },
      { id: 'ohms', label: 'Resistance', unit: 'Ω', def: '4700', showIf: (v) => !dec(v) }, { id: 'tolE', label: 'Tolerance band', choices: tolOpts, def: 'gold', showIf: (v) => !dec(v) }],
    compute: resistor, example: { mode: 'encode', ohms: '4.7k' }, foot: 'Standard color code. Confirm with a meter on precision work.' });
})(typeof window !== 'undefined' ? window : globalThis);
