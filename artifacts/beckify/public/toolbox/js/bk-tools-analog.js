/* Ported from the Beckify iOS app (AnalogDesignMath.swift): Noise & SNR, Linear regulator, Instrumentation amp, ADC / DAC. */
(function (global) {
  'use strict';
  const T = global.BeckifyTool, si = T.si, fx = T.fixed;
  const KB = 1.380649e-23, QE = 1.602176634e-19;
  const E24 = [1.0, 1.1, 1.2, 1.3, 1.5, 1.6, 1.8, 2.0, 2.2, 2.4, 2.7, 3.0, 3.3, 3.6, 3.9, 4.3, 4.7, 5.1, 5.6, 6.2, 6.8, 7.5, 8.2, 9.1];
  function nearestE24(v) {
    if (!(v > 0)) return v;
    const dec = Math.floor(Math.log10(v)), base = Math.pow(10, dec), m = v / base;
    let best = E24[0] * base, err = Infinity;
    E24.concat([10]).forEach((s) => { const e = Math.abs(Math.log(m / s)); if (e < err) { err = e; best = s * base; } });
    return best;
  }

  /* ---------- Noise & SNR ---------- */
  function noise(v) {
    const R = T.nonNeg(v, 'resistance', 'Resistance'), Tk = T.positive(v, 'temperature', 'Temperature'), bw3 = T.positive(v, 'bandwidth', 'Bandwidth');
    const en = T.nonNeg(v, 'en', 'Amplifier e_n') * 1e-9, inn = T.nonNeg(v, 'in', 'Amplifier i_n') * 1e-12;
    const B = bw3 * (v.bwKind === 'first' ? Math.PI / 2 : 1);
    const johnson = Math.sqrt(4 * KB * Tk * R * B), enV = en * Math.sqrt(B), inV = inn * R * Math.sqrt(B);
    let shotI = 0, shotV = 0;
    if (v.includeShot === 'yes') { const ish = T.nonNeg(v, 'shot', 'Shot current') * 1e-3; shotI = Math.sqrt(2 * QE * ish * B); shotV = shotI * R; }
    const total = Math.sqrt(johnson * johnson + shotV * shotV + enV * enV + inV * inV);
    const rows = [['Noise bandwidth', si(B, 'Hz')], ['Johnson', si(johnson, 'Vrms')], ['Amp voltage noise', si(enV, 'Vrms')], ['Amp current noise × R', si(inV, 'Vrms')]];
    if (v.includeShot === 'yes') rows.push(['Shot in', si(shotI, 'Arms')], ['Shot noise × R', si(shotV, 'Vrms')]);
    rows.push(['Total referred noise', si(total, 'Vrms'), true]);
    let headline = 'Total noise ' + si(total, 'Vrms');
    if (v.includeSNR === 'yes') {
      const sig = T.positive(v, 'signal', 'Signal amplitude') * 1e-3;
      if (!(total > 0)) throw new Error('Total noise is zero — SNR is undefined.');
      const snr = 20 * Math.log10(sig / total); rows.push(['SNR', fx(snr, 1, 'dB'), true]); headline = 'SNR ' + fx(snr, 1) + ' dB';
    }
    if (johnson > 0) rows.push(['Noise figure (rough)', fx(10 * Math.log10(total * total / (johnson * johnson)), 2, 'dB')]);
    const parts = [['Resistor (Johnson)', johnson], ['Amp voltage noise', enV], ['Amp current noise × R', inV], ['Shot noise × R', shotV]];
    const power = parts.reduce((s, p) => s + p[1] * p[1], 0);
    const steps = ['vn = √(4kTRB),  in,shot = √(2qIB)', 'Total = √(Johnson² + shot² + e_n² + (i_n·R)²)'];
    if (power > 0) parts.filter((p) => p[1] > 0).forEach((p) => steps.push(p[0] + ': ' + fx(p[1] * p[1] / power * 100, 1) + '% of noise power'));
    return { headline, rows, steps, notes: ['Noise sources add in power, not in volts.', 'First-order low-pass equivalent noise bandwidth is π/2 × the 3 dB bandwidth.', 'Noise figure here is total referred noise against the source resistor alone. It is a rough number.'], svg: noiseBars(parts, power) };
  }
  function noiseBars(parts, power) {
    if (!(power > 0)) return '';
    const live = parts.filter((p) => p[1] > 0), W = 460, rowH = 26, H = live.length * rowH + 16, G = global.BeckifyGfx;
    const col = (i) => (G ? G.seriesColor(i + 1) : '#40bad6');
    let s = '<svg viewBox="0 0 ' + W + ' ' + H + '" class="bkt-svg" role="img" aria-label="Share of noise power by source" font-family="system-ui,sans-serif"><rect width="' + W + '" height="' + H + '" rx="10" fill="#0e1118"/>';
    live.forEach((p, i) => { const share = p[1] * p[1] / power, y = 10 + i * rowH; s += '<text x="10" y="' + (y + 11) + '" font-size="11" fill="#94a2b2">' + T.esc(p[0]) + '</text><rect x="170" y="' + y + '" width="' + (240 * share).toFixed(1) + '" height="16" rx="4" fill="' + col(i) + '"/><text x="' + (176 + 240 * share).toFixed(1) + '" y="' + (y + 12) + '" font-size="11" font-weight="600" fill="#e8eef5">' + (share * 100).toFixed(1) + '%</text>'; });
    return s + '</svg>';
  }
  T.define({ id: 'noiseSNR', root: 'bk-noise-root', title: 'Noise & SNR', lede: 'Johnson and optional shot noise, amplifier e_n and i_n, total referred noise, SNR, and a rough noise figure.',
    fields: [
      { id: 'bwKind', label: 'Bandwidth is', choices: [['brick', 'Hz (already noise BW)'], ['first', '3 dB BW × π/2']], def: 'brick' },
      { id: 'resistance', label: 'Source resistance', unit: 'Ω', def: '10000' }, { id: 'temperature', label: 'Temperature', unit: 'K', def: '290' }, { id: 'bandwidth', label: 'Bandwidth', unit: 'Hz', def: '10000' },
      { id: 'en', label: 'Amp e_n', unit: 'nV/√Hz', def: '5' }, { id: 'in', label: 'Amp i_n', unit: 'pA/√Hz', def: '1' },
      { id: 'includeShot', label: 'Include shot noise', choices: [['no', 'No'], ['yes', 'Yes']], def: 'no' }, { id: 'shot', label: 'DC current', unit: 'mA', def: '1', showIf: (v) => v.includeShot === 'yes' },
      { id: 'includeSNR', label: 'Compute SNR', choices: [['yes', 'Yes'], ['no', 'No']], def: 'yes' }, { id: 'signal', label: 'Signal (rms)', unit: 'mV', def: '1', showIf: (v) => v.includeSNR === 'yes' }],
    compute: noise, example: { resistance: '100000', bandwidth: '20000', signal: '10' }, foot: 'Design aid. Ideal white-noise model, no 1/f noise. Check the amplifier datasheet for e_n and i_n.' });

  /* ---------- Linear / LDO regulator ---------- */
  function ldo(v) {
    const vin = T.positive(v, 'vin', 'Vin'), vref = T.positive(v, 'vref', 'Vref'), r1 = T.positive(v, 'r1', 'R1'), iadj = T.nonNeg(v, 'iadj', 'Iadj') * 1e-6;
    const vdo = T.nonNeg(v, 'dropout', 'Dropout'), iload = T.nonNeg(v, 'load', 'Load current'), amb = T.need(v, 'ambient', 'Ambient'), thJA = T.positive(v, 'thja', 'θJA');
    let r2, vout;
    if (v.mode === 'solveR2') {
      const target = T.positive(v, 'vout', 'Vout');
      if (!(target > vref)) throw new Error('Vout must be greater than Vref.');
      const den = vref / r1 + iadj; if (!(den > 0)) throw new Error('R2 is undefined for these parts.');
      r2 = (target - vref) / den;
    } else r2 = T.positive(v, 'r2', 'R2');
    vout = vref * (1 + r2 / r1) + iadj * r2;
    const head = vin - vout, pd = Math.max(0, head) * iload;
    let thetaUsed = thJA;
    const saRaw = T.optional(v, 'thsa');
    if (String(v.thsa || '').trim() !== '') { const sa = T.positive(v, 'thsa', 'θSA'); const jc = String(v.thjc || '').trim() === '' ? 5 : T.positive(v, 'thjc', 'θJC'); thetaUsed = jc + sa; }
    void saRaw;
    const tj = amb + pd * thetaUsed, hi = tj >= 125;
    const rows = [['Vout', si(vout, 'V'), true], ['R1', si(r1, 'Ω')], ['R2', si(r2, 'Ω'), v.mode === 'solveR2'], ['R1 nearest E24', si(nearestE24(r1), 'Ω')], ['R2 nearest E24', si(nearestE24(r2), 'Ω')],
      ['Headroom Vin − Vout', si(head, 'V')], ['Margin over dropout', si(head - vdo, 'V')], ['Power in pass element', si(pd, 'W')], ['θ used', fx(thetaUsed, 1, '°C/W')], ['Junction Tj', fx(tj, 1, '°C'), true]];
    const warn = head < 0 ? 'Vin is below Vout. A linear regulator cannot boost.' : (head - vdo < 0 ? 'Headroom is under the dropout you entered. The regulator will fall out of regulation.' : (hi ? 'Tj is at or above 125 °C. Add a heatsink or cut the drop.' : null));
    return { headline: 'Vout = ' + si(vout, 'V') + ',  Tj ≈ ' + fx(tj, 0) + ' °C', rows, warning: warn,
      steps: ['Vout = Vref(1 + R2/R1) + Iadj·R2 = ' + si(vout, 'V'), 'Pd = (Vin − Vout)·I = ' + si(pd, 'W'), 'Tj = Ta + Pd·θ = ' + fx(tj, 1) + ' °C'],
      notes: ['LM317-style adjustable regulator. Vref 1.25 V and Iadj 50 µA are typical, not guaranteed.', 'If you enter a heatsink θSA, θ is θJC + θSA. Free-air θJA is ignored then.', 'Linear / LDO thermal estimate only. Not a switch-mode design and Tj is not a measured case temperature.'], svg: ldoFig(vin, vout, head, pd, tj) };
  }
  function ldoFig(vin, vout, head, pd, tj) {
    const W = 460, H = 90; const pct = vin > 0 ? Math.max(0, Math.min(1, vout / vin)) : 0;
    return '<svg viewBox="0 0 ' + W + ' ' + H + '" class="bkt-svg" role="img" aria-label="Vin split into Vout and heat drop" font-family="system-ui,sans-serif"><rect width="' + W + '" height="' + H + '" rx="10" fill="#0e1118"/>' +
      '<rect x="20" y="30" width="' + (420 * pct).toFixed(1) + '" height="26" rx="5" fill="#56d6a4"/><rect x="' + (20 + 420 * pct).toFixed(1) + '" y="30" width="' + (420 * (1 - pct)).toFixed(1) + '" height="26" rx="5" fill="#e09c56"/>' +
      '<text x="20" y="22" font-size="11" fill="#94a2b2">Vin ' + si(vin, 'V') + ' split</text><text x="24" y="47" font-size="11" font-weight="700" fill="#080b10">Vout ' + si(vout, 'V') + '</text>' +
      (pct < 0.999 ? '<text x="' + (436) + '" y="47" text-anchor="end" font-size="11" font-weight="700" fill="#080b10">drop ' + si(head, 'V') + '</text>' : '') +
      '<text x="20" y="78" font-size="11" fill="' + (tj >= 125 ? '#f47078' : '#94a2b2') + '">Heat ' + si(pd, 'W') + '  ·  Tj ' + fx(tj, 0) + ' °C</text></svg>';
  }
  T.define({ id: 'linearRegulator', root: 'bk-ldo-root', title: 'Linear / LDO Regulator', lede: 'LM317-style Vout from R1 and R2, dropout margin, pass-element power, and a junction-temperature estimate.',
    fields: [{ id: 'mode', label: 'Solve', choices: [['fromR', 'R1 / R2 → Vout'], ['solveR2', 'Target Vout → R2']], def: 'fromR' },
      { id: 'vin', label: 'Vin', unit: 'V', def: '12' }, { id: 'vout', label: 'Target Vout', unit: 'V', def: '5', showIf: (v) => v.mode === 'solveR2' },
      { id: 'r1', label: 'R1', unit: 'Ω', def: '240' }, { id: 'r2', label: 'R2', unit: 'Ω', def: '720', showIf: (v) => v.mode !== 'solveR2' },
      { id: 'vref', label: 'Vref', unit: 'V', def: '1.25' }, { id: 'iadj', label: 'Iadj', unit: 'µA', def: '50', help: 'Typical 50 µA. Enter 0 to ignore.' },
      { id: 'dropout', label: 'Dropout', unit: 'V', def: '2' }, { id: 'load', label: 'Load current', unit: 'A', def: '0.5' }, { id: 'ambient', label: 'Ambient', unit: '°C', def: '25' }, { id: 'thja', label: 'θJA free air', unit: '°C/W', def: '50' },
      { id: 'thsa', label: 'Heatsink θSA', unit: '°C/W', def: '', optional: true, help: 'If set, Tj uses θJC + θSA instead of free-air θJA.' }, { id: 'thjc', label: 'θJC', unit: '°C/W', def: '5', showIf: (v) => String(v.thsa || '').trim() !== '' }],
    compute: ldo, example: { mode: 'solveR2', vout: '9', vin: '15', load: '1' }, foot: 'Thermal estimate only. Check the datasheet for dropout, Iadj, and θ values.' });

  /* ---------- Instrumentation / difference amp ---------- */
  function inamp(v) {
    const v2 = T.need(v, 'v2', 'V2'), v1 = T.need(v, 'v1', 'V1'), r = T.positive(v, 'r', v.mode === 'diff' ? 'Rf' : 'R'), rg = T.positive(v, 'rg', v.mode === 'diff' ? 'Rin' : 'Rg'), vref = T.need(v, 'vref', 'Vref');
    const rp = T.need(v, 'railP', '+ rail'), rn = T.need(v, 'railN', '− rail'), cmin = T.need(v, 'cmMin', 'CM min'), cmax = T.need(v, 'cmMax', 'CM max');
    if (!(rp > rn)) throw new Error('Positive rail must be above the negative rail.');
    if (!(cmax > cmin)) throw new Error('CM max must be greater than CM min.');
    const diff = v2 - v1, cm = (v2 + v1) / 2, gain = v.mode === 'diff' ? r / rg : 1 + 2 * r / rg, vout = gain * diff + vref;
    const inSwing = vout <= rp && vout >= rn, cmOk = cm >= cmin && cm <= cmax;
    const warn = !inSwing ? 'Vout is outside the rails. The real output would clip at the supply.' : (!cmOk ? 'Input common-mode is outside the allowed range.' : null);
    return { headline: 'Vout = ' + si(vout, 'V') + '  (G = ' + gain.toPrecision(4).replace(/\.?0+$/, '') + ')', warning: warn,
      rows: [['Gain', fx(gain, 3), true], ['Vout', si(vout, 'V'), true], ['Differential in', si(diff, 'V')], ['Common mode', si(cm, 'V')], ['Headroom to + rail', si(rp - vout, 'V')], ['Headroom to − rail', si(vout - rn, 'V')], ['Output in swing', inSwing ? 'Yes' : 'No'], ['CM in range', cmOk ? 'Yes' : 'No']],
      steps: [v.mode === 'diff' ? 'G = Rf / Rin   Vout = G·(V2 − V1) + Vref   (matched 4-resistor)' : 'G = 1 + 2R / Rg   Vout = G·(V2 − V1) + Vref'],
      notes: ['Ideal amplifier and perfectly matched resistors. CMRR and offsets are not modeled.', 'Check the common-mode range of the real part against its datasheet.'], svg: inampFig(vout, rp, rn, vref) };
  }
  function inampFig(vout, rp, rn, vref) {
    const W = 460, H = 70, span = rp - rn, x = (val) => 30 + 400 * Math.max(0, Math.min(1, (val - rn) / span)), ok = vout <= rp && vout >= rn;
    return '<svg viewBox="0 0 ' + W + ' ' + H + '" class="bkt-svg" role="img" aria-label="Output against the supply rails" font-family="system-ui,sans-serif"><rect width="' + W + '" height="' + H + '" rx="10" fill="#0e1118"/><rect x="30" y="28" width="400" height="12" rx="6" fill="#1c222c"/>' +
      '<line x1="' + x(vref).toFixed(1) + '" y1="22" x2="' + x(vref).toFixed(1) + '" y2="46" stroke="#609ce6" stroke-width="2"/><circle cx="' + x(vout).toFixed(1) + '" cy="34" r="7" fill="' + (ok ? '#56d6a4' : '#f47078') + '"/>' +
      '<text x="30" y="60" font-size="11" fill="#94a2b2">' + si(rn, 'V') + '</text><text x="430" y="60" text-anchor="end" font-size="11" fill="#94a2b2">' + si(rp, 'V') + '</text><text x="230" y="16" text-anchor="middle" font-size="11" fill="#e8eef5">Vout ' + si(vout, 'V') + ' (blue tick = Vref)</text></svg>';
  }
  T.define({ id: 'instrumentationAmp', root: 'bk-inamp-root', title: 'Instrumentation Amp', lede: 'Three-op-amp InAmp gain from Rg, or a matched four-resistor difference amp, with output swing and common-mode checks.',
    fields: [{ id: 'mode', label: 'Type', choices: [['three', '3-op-amp InAmp'], ['diff', 'Difference amp']], def: 'three' },
      { id: 'v2', label: 'V2 (+ input)', unit: 'V', def: '2.05' }, { id: 'v1', label: 'V1 (− input)', unit: 'V', def: '2.00' },
      { id: 'r', label: 'R (or Rf)', unit: 'Ω', def: '25000', help: '3-op-amp: the two matched feedback resistors. Difference: Rf.' }, { id: 'rg', label: 'Rg (or Rin)', unit: 'Ω', def: '1000' },
      { id: 'vref', label: 'Vref', unit: 'V', def: '0' }, { id: 'railP', label: '+ rail', unit: 'V', def: '5' }, { id: 'railN', label: '− rail', unit: 'V', def: '0' }, { id: 'cmMin', label: 'CM min', unit: 'V', def: '0' }, { id: 'cmMax', label: 'CM max', unit: 'V', def: '4' }],
    compute: inamp, example: { v2: '2.5', v1: '2.0' }, foot: 'Ideal gain only. Design aid — check the datasheet for CMRR, offset, and swing.' });

  /* ---------- ADC / DAC ---------- */
  function adc(v) {
    const bits = T.need(v, 'bits', 'Bits');
    if (!(bits >= 1) || Math.floor(bits) !== bits) throw new Error('Bits must be a whole number of 1 or more.');
    if (bits > 32) throw new Error('Bits must be 32 or fewer.');
    const fs = T.positive(v, 'fs', 'Full-scale range'), fsamp = T.positive(v, 'sample', 'Sample rate');
    const lsb = fs / Math.pow(2, bits), codes = Math.pow(2, bits), snr = 6.02 * bits + 1.76;
    const rows = [['LSB', si(lsb, 'V'), true], ['Codes', codes.toLocaleString('en-US')], ['Ideal quantization SNR', fx(snr, 2, 'dB')], ['Nyquist', si(fsamp / 2, 'Hz')], ['Suggested anti-alias fc', si(0.4 * fsamp, 'Hz')]];
    const raw = String(v.code == null ? '' : v.code).trim();
    if (raw !== '') {
      const code = T.need(v, 'code', 'DAC code');
      if (!(code >= 0 && code <= codes - 1)) throw new Error('DAC code must be between 0 and ' + (codes - 1) + '.');
      rows.push(['DAC voltage', si(code * lsb, 'V'), true]);
    }
    return { headline: 'LSB = ' + si(lsb, 'V') + '  ·  ' + bits + ' bits', rows, steps: ['LSB = FS / 2ⁿ = ' + si(lsb, 'V'), 'SNR ≈ 6.02n + 1.76 = ' + fx(snr, 2) + ' dB', 'Nyquist = Fs / 2'],
      notes: ['Ideal full-scale sine into a uniform quantizer. ENOB of a real part is lower.', 'The anti-alias corner is a starting point at 0.4·Fs, not a filter design.', 'DAC voltage is code × LSB, with no offset or gain error.'], svg: adcFig(bits, lsb, fs) };
  }
  function adcFig(bits, lsb, fs) {
    const W = 460, H = 130, n = Math.min(3, bits), steps = 1 << n, px = 40, py = 14, w = 400, h = 90;
    let d = 'M' + px + ' ' + (py + h);
    for (let k = 0; k < steps; k++) { const x0 = px + w * k / steps, x1 = px + w * (k + 1) / steps, y = py + h - h * (k + 1) / steps; d += 'L' + x0.toFixed(1) + ' ' + (py + h - h * k / steps).toFixed(1) + 'L' + x0.toFixed(1) + ' ' + y.toFixed(1) + 'L' + x1.toFixed(1) + ' ' + y.toFixed(1); }
    return '<svg viewBox="0 0 ' + W + ' ' + H + '" class="bkt-svg" role="img" aria-label="Quantizer staircase, first levels" font-family="system-ui,sans-serif"><rect width="' + W + '" height="' + H + '" rx="10" fill="#0e1118"/>' +
      '<line x1="' + px + '" y1="' + (py + h) + '" x2="' + (px + w) + '" y2="' + py + '" stroke="#609ce6" stroke-dasharray="4 3"/><path d="' + d + '" fill="none" stroke="#40bad6" stroke-width="2"/>' +
      '<text x="' + px + '" y="' + (H - 16) + '" font-size="11" fill="#94a2b2">First ' + steps + ' codes drawn  ·  step = 1 LSB = ' + si(lsb, 'V') + '  ·  full scale ' + si(fs, 'V') + '</text></svg>';
  }
  T.define({ id: 'adcDac', root: 'bk-adc-root', title: 'ADC / DAC', lede: 'LSB, code count, ideal quantization SNR, Nyquist, and an optional DAC code-to-voltage.',
    fields: [{ id: 'bits', label: 'Bits', unit: '', def: '12' }, { id: 'fs', label: 'Full-scale range', unit: 'V', def: '5' }, { id: 'sample', label: 'Sample rate', unit: 'Hz', def: '1000' }, { id: 'code', label: 'DAC code', unit: '', def: '', optional: true, help: '0 … 2ⁿ−1. V = code · LSB.' }],
    compute: adc, example: { bits: '12', fs: '5', sample: '1000', code: '2048' }, foot: 'Ideal converter. Real parts have INL, DNL, offset, and noise.' });

  global.BeckifyToolsAnalog = { nearestE24 };
})(typeof window !== 'undefined' ? window : globalThis);
