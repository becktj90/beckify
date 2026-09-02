/* Battery bank series/parallel and forward/reverse sizing math. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const sandbox = {
  console,
  Math,
  Number,
  String,
  Object,
  Array,
  JSON,
  document: { readyState: 'complete', addEventListener() {}, getElementById() { return null; } },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'battery-bank.js'), 'utf8'), sandbox, { filename: 'battery-bank.js' });

const api = sandbox.__batteryBankTestApi;
assert.ok(api);

const sp = api.seriesParallel(12, 100, 48, 200);
assert.equal(sp.series, 4);
assert.equal(sp.parallel, 2);
assert.equal(sp.units, 8);
assert.equal(sp.actualV, 48);
assert.equal(sp.actualAh, 200);

const fwd = api.sizeForward({
  watts: 1000, hours: 4, v: 12, ah: 100, dod: 90, eta: 95,
});
assert.ok(!fwd.error, fwd.error);
assert.equal(fwd.units, 4);
assert.ok(Math.abs(fwd.acWh - 4000) < 1e-6);
assert.ok(Math.abs(fwd.usablePerUnitWh - 1080) < 1e-6);

const rev = api.sizeReverse({
  watts: 1000, series: 4, parallel: 2, v: 12, ah: 100, dod: 90, eta: 95,
});
assert.ok(!rev.error, rev.error);
assert.equal(rev.units, 8);
assert.ok(Math.abs(rev.hours - ((8 * 1080 * 0.95) / 1000)) < 1e-6);

assert.equal(api.PRESETS.lfp.dod, 90);
assert.equal(api.PRESETS.flooded.dod, 50);
assert.equal(api.PRESETS.agm.dod, 50);

const over = api.sizeForward({ watts: 5000, hours: 1, v: 12, ah: 100, dod: 50, eta: 90, crateLimit: 0.2 });
const flag = api.crateFlag(over);
assert.ok(flag);
assert.equal(flag.ok, false);

console.log('Battery bank series/parallel and sizing math passed');
