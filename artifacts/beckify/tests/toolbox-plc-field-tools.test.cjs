/* E-bus budget, Modbus address, PLC timer preset. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function load(filename, exportName) {
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
    fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'js', filename), 'utf8'),
    sandbox,
    { filename: filename }
  );
  const api = sandbox[exportName];
  assert.ok(api, exportName + ' exported from ' + filename);
  return api;
}

const ebus = load('ebus-budget.js', '__ebusBudgetTestApi');
{
  const r = ebus.computeBudget([
    { pn: 'EK1100', name: 'coupler', ma: 2000, widthMm: '44', signalType: 'Coupler' },
    { pn: 'EL1819', name: 'DI', ma: -100, widthMm: '12', signalType: 'DI' },
    { pn: 'EL9410', name: 'refresh', ma: 2000, widthMm: '12', signalType: 'Power', reset: true },
    { pn: 'EL2828', name: 'DO', ma: -140, widthMm: '12', signalType: 'DO' },
  ], { reserve: 200 });
  assert.equal(r.rows[0].remainingMa, 2000);
  assert.equal(r.rows[1].remainingMa, 1900);
  assert.equal(r.rows[2].remainingMa, 2000, 'power refresh resets remaining');
  assert.equal(r.rows[3].remainingMa, 1860);
  assert.equal(r.ok, true);
  const low = ebus.computeBudget([
    { pn: 'EK1100', ma: 200, signalType: 'Coupler' },
    { pn: 'EL', ma: -50, signalType: 'DI' },
  ], { reserve: 200 });
  assert.equal(low.rows[1].lowReserve, true);
  const neg = ebus.computeBudget([{ pn: 'X', ma: -10, signalType: 'DI' }], { reserve: 200 });
  assert.equal(neg.rows[0].negative, true);
  assert.equal(neg.ok, false);
}

const mb = load('modbus-address.js', '__modbusAddressTestApi');
{
  const h = mb.convert({ space: 'holding', offset0: 0 });
  assert.equal(h.ok, true);
  assert.equal(h.fc, 3);
  assert.equal(h.offset0, 0);
  assert.equal(h.oneBased, 1);
  assert.equal(h.addr5, 40001);
  assert.equal(h.addr6, 400001);
  assert.match(h.tagNote, /40001 = holding 0/);

  const from5 = mb.convert({ address: 40001 });
  assert.equal(from5.space, 'holding');
  assert.equal(from5.offset0, 0);

  const from6 = mb.convert({ address: 400001 });
  assert.equal(from6.offset0, 0);
  assert.equal(from6.addr5, 40001);

  const coil = mb.convert({ space: 'coil', offset0: 0 });
  assert.equal(coil.fc, 1);
  assert.equal(coil.addr5Padded, '00001');

  const disc = mb.convert({ address: 10001 });
  assert.equal(disc.space, 'discrete');
  assert.equal(disc.fc, 2);
  assert.equal(disc.offset0, 0);
}

const tmr = load('plc-timer-preset.js', '__plcTimerPresetTestApi');
{
  const p = tmr.presetFromTime(1.5, 's', '10ms');
  assert.equal(p.ok, true);
  assert.equal(p.counts, 150);
  assert.equal(p.actualMs, 1500);
  const back = tmr.timeFromPreset(150, '10ms');
  assert.equal(back.actualS, 1.5);
  const scan = tmr.presetFromTime(320, 'ms', 'scan', null, 8);
  assert.equal(scan.counts, 40);
  const custom = tmr.presetFromTime(1, 's', 'custom', 5);
  assert.equal(custom.counts, 200);
}
