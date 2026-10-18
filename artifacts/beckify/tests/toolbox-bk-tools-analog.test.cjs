'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const js = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const ctx = vm.createContext({ console, Math, JSON, Number, String, Object, Array, isFinite, parseFloat, Date });
ctx.window = ctx; ctx.globalThis = ctx;
for (const f of ['bk-tool.js', 'bk-tools-analog.js']) vm.runInContext(fs.readFileSync(path.join(js, f), 'utf8'), ctx, { filename: f });
const T = ctx.BeckifyTool;
const near = (a, b, tol) => assert.ok(Math.abs(a - b) <= (tol == null ? 1e-9 : tol) * Math.max(1, Math.abs(b)), a + ' vs ' + b);
const run = (id, over) => { const d = T.registry[id]; const r = T.run(d, Object.assign(T.defaults(d), over || {})); return r; };
const row = (r, label) => r.r.rows.find((x) => x[0] === label)[1];

/* parser */
assert.equal(T.parse('4.7k'), 4700); assert.equal(T.parse('100n'), 1e-7); assert.equal(T.parse('1,000'), 1000); assert.equal(T.parse('2e-3'), 0.002);
assert.equal(T.parse(''), null); assert.equal(T.parse('abc'), null); assert.equal(T.parse('1M'), 1e6); assert.equal(T.parse('-5m'), -0.005);
assert.equal(T.si(1.38e-9, 'F'), '1.38 nF'); assert.equal(T.si(0, 'V'), '0 V'); assert.equal(T.si(-2, 'V'), '-2.00 V');

/* every tool runs on defaults, and gives a readable error on blank input */
for (const id of Object.keys(T.registry)) {
  const d = T.registry[id];
  const ok = T.run(d, T.defaults(d));
  assert.ok(ok.ok, id + ': ' + ok.error);
  assert.ok(ok.r.headline && ok.r.rows.length >= 3, id + ' rows');
  const blank = {}; d.fields.forEach((f) => { blank[f.id] = f.choices ? f.def : ''; });
  const bad = T.run(d, blank);
  if (!d.fields.every((f) => f.optional || f.choices)) assert.ok(!bad.ok && /missing|number/.test(bad.error), id + ' blank input');
}

/* noise: Johnson 4kTRB, power sum, SNR */
{
  const r = run('noiseSNR');
  const johnson = Math.sqrt(4 * 1.380649e-23 * 290 * 1e4 * 1e4), en = 5e-9 * 100, inn = 1e-12 * 1e4 * 100, total = Math.sqrt(johnson ** 2 + en ** 2 + inn ** 2);
  near(parseFloat(row(r, 'SNR')), 20 * Math.log10(1e-3 / total), 1e-3);
  assert.match(row(r, 'Johnson'), /1\.27 µVrms/);
  const first = run('noiseSNR', { bwKind: 'first' });
  assert.match(row(first, 'Noise bandwidth'), /15\.7 kHz/);
  const zeroR = run('noiseSNR', { resistance: '0' });
  assert.ok(zeroR.ok && !zeroR.r.rows.some((x) => x[0] === 'Noise figure (rough)'), 'zero R has no NF');
  assert.ok(!run('noiseSNR', { temperature: '0' }).ok, 'zero kelvin rejected');
  assert.ok(!run('noiseSNR', { resistance: '-5' }).ok, 'negative R rejected');
  assert.ok(run('noiseSNR', { includeShot: 'yes', shot: '1' }).r.rows.some((x) => x[0] === 'Shot in'));
  assert.ok(run('noiseSNR', { includeSNR: 'no' }).r.headline.startsWith('Total noise'));
  assert.ok(run('noiseSNR', { en: '0', in: '0', resistance: '0', includeSNR: 'yes' }).error === undefined ? false : true, 'zero total noise SNR is an error');
}
/* regulator */
{
  const r = run('linearRegulator');
  near(parseFloat(row(r, 'Vout')), 1.25 * 4 + 50e-6 * 720, 1e-3);
  const s = run('linearRegulator', { mode: 'solveR2', vout: '5' });
  near(T.parse(row(s, 'R2').replace(/ Ω.*/, '').replace(' k', 'k')) || 0, (5 - 1.25) / (1.25 / 240 + 50e-6), 5e-3);
  assert.ok(!run('linearRegulator', { mode: 'solveR2', vout: '1' }).ok, 'Vout below Vref');
  assert.ok(run('linearRegulator', { thsa: '10' }).r.rows.some((x) => x[0] === 'θ used' && x[1] === '15.0 °C/W'), 'heatsink uses θJC + θSA');
  assert.ok(run('linearRegulator', { vin: '3' }).r.warning, 'Vin below Vout warns');
  assert.ok(!run('linearRegulator', { r1: '0' }).ok);
}
/* instrumentation amp */
{
  const r = run('instrumentationAmp');
  near(parseFloat(row(r, 'Gain')), 51, 1e-9); assert.match(r.r.headline, /2\.55 V/);
  const d = run('instrumentationAmp', { mode: 'diff', r: '100000', rg: '10000' });
  near(parseFloat(row(d, 'Gain')), 10, 1e-9);
  assert.ok(run('instrumentationAmp', { v2: '4', v1: '0' }).r.warning, 'clipping warns');
  assert.ok(!run('instrumentationAmp', { railP: '-1' }).ok);
  assert.ok(!run('instrumentationAmp', { cmMax: '0' }).ok);
}
/* adc */
{
  const r = run('adcDac');
  assert.match(row(r, 'LSB'), /1\.22 mV/); assert.equal(row(r, 'Codes'), '4,096'); assert.equal(row(r, 'Ideal quantization SNR'), '74.00 dB');
  assert.equal(row(r, 'Nyquist'), '500 Hz');
  near(parseFloat(row(run('adcDac', { code: '2048' }), 'DAC voltage')), 2.5, 1e-6);
  assert.ok(!run('adcDac', { code: '4096' }).ok, 'code above max'); assert.ok(!run('adcDac', { bits: '33' }).ok); assert.ok(!run('adcDac', { bits: '12.5' }).ok); assert.ok(!run('adcDac', { bits: '0' }).ok);
  assert.ok(run('adcDac', { bits: '1' }).ok);
}
console.log('bk-tools-analog ok');
