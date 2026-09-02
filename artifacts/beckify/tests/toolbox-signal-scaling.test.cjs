/* Process-value / signal scaling — linear both ways, 4–20 mA flags. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const sandbox = {
  console,
  Math,
  Number,
  String,
  Object,
  Array,
  JSON,
  isFinite,
  parseFloat,
  parseInt,
  localStorage: {
    _d: {},
    getItem(k) { return this._d[k] || null; },
    setItem(k, v) { this._d[k] = String(v); },
  },
  document: {
    getElementById() { return null; },
    querySelector() { return null; },
    addEventListener() {},
    readyState: 'complete',
  },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(
  fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'js', 'signal-scaling.js'), 'utf8'),
  sandbox,
  { filename: 'signal-scaling.js' }
);

const api = sandbox.__signalScalingTestApi;
assert.ok(api && typeof api.scaleForward === 'function', 'test API exported');

function almost(a, b, tol) {
  const t = tol === undefined || tol === null ? 1e-9 : tol;
  assert.ok(Math.abs(a - b) <= t, 'expected ' + b + ' got ' + a);
}

/* 14.2 mA on 4–20 mA → 0–500 psi is 318.75 psi. */
{
  const r = api.scaleForward(14.2, 4, 20, 0, 500);
  assert.equal(r.ok, true);
  almost(r.value, 318.75);
}

/* Reverse: 250 psi → 12 mA. */
{
  const r = api.scaleReverse(250, 4, 20, 0, 500);
  assert.equal(r.ok, true);
  almost(r.value, 12);
}

/* Round-trip identity. */
{
  const eng = api.scaleForward(16, 4, 20, 0, 100);
  const raw = api.scaleReverse(eng.value, 4, 20, 0, 100);
  almost(raw.value, 16);
}

/* Endpoints. */
{
  almost(api.scaleForward(4, 4, 20, 0, 500).value, 0);
  almost(api.scaleForward(20, 4, 20, 0, 500).value, 500);
  almost(api.scaleReverse(0, 4, 20, 0, 500).value, 4);
  almost(api.scaleReverse(500, 4, 20, 0, 500).value, 20);
}

/* Zero span is an error, not Infinity. */
{
  const r = api.scaleForward(10, 4, 4, 0, 100);
  assert.equal(r.ok, false);
}

/* 4–20 mA live-zero / over-range flags. */
{
  const ok = api.rangeFlags('4-20mA', 12, 4, 20);
  assert.equal(ok.outOfRange, false);
  assert.equal(ok.liveZeroFault, false);

  const under = api.rangeFlags('4-20mA', 3.5, 4, 20);
  assert.equal(under.outOfRange, true);
  assert.equal(under.liveZeroFault, true);
  assert.equal(under.underRange, true);
  assert.match(under.message, /live-zero/i);

  const over = api.rangeFlags('4-20mA', 20.4, 4, 20);
  assert.equal(over.outOfRange, true);
  assert.equal(over.liveZeroFault, false);
  assert.equal(over.overRange, true);

  const atLiveZero = api.rangeFlags('4-20mA', 4, 4, 20);
  assert.equal(atLiveZero.outOfRange, false, 'exactly 4 mA is in range');
}

/* 0–20 mA does not treat 3 mA as a live-zero fault. */
{
  const f = api.rangeFlags('0-20mA', 3, 0, 20);
  assert.equal(f.liveZeroFault, false);
  assert.equal(f.outOfRange, false);
}

/* 12-bit unsigned midpoint. */
{
  const r = api.scaleForward(2048, 0, 4095, 0, 100);
  almost(r.value, 2048 * 100 / 4095, 1e-9);
}

/* Formula text plugs in the actual numbers. */
{
  const text = api.pluggedFormula(14.2, 4, 20, 0, 500, 318.75, 'raw', 'eng', 'mA', 'psi');
  assert.match(text, /14\.2/);
  assert.match(text, /318\.75/);
  assert.match(text, /psi/);
  assert.match(text, /4/);
  assert.match(text, /20/);
}

/* Unit conversions: 500 psi → kPa, and back. */
{
  const kPa = api.convertEng(500, 'pressure', 'psi', 'kPa');
  almost(kPa, 500 * 6.894757293168, 1e-6);
  almost(api.convertEng(kPa, 'pressure', 'kPa', 'psi'), 500, 1e-6);
  almost(api.convertEng(32, 'temperature', 'F', 'C'), 0, 1e-9);
  almost(api.convertEng(0, 'temperature', 'C', 'K'), 273.15, 1e-9);
}

/* Pt100 helper at 0 °C / 100 °C. */
{
  almost(api.pt100TemperatureC(100).c, 0, 1e-6);
  almost(api.pt100TemperatureC(138.51).c, 100, 0.05);
}
