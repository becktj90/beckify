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
  Set,
  JSON,
  document: { getElementById() { return null; } },
};
sandbox.window = sandbox;
sandbox.window.addEventListener = () => {};
sandbox.window.__ENABLE_PANEL_SCHEDULE_TEST_API__ = true;
sandbox.window.__ENABLE_FACTOR_TEST_API__ = true;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'panel-schedule.js'), 'utf8'), sandbox, { filename: 'panel-schedule.js' });
vm.runInContext(fs.readFileSync(path.join(root, 'factor-tools.js'), 'utf8'), sandbox, { filename: 'factor-tools.js' });

const panel = sandbox.__panelScheduleTestApi;
const factors = sandbox.__factorTestApi;

assert.equal(panel.inferLoadType('Roof top AC condenser'), 'HVAC');
assert.equal(panel.inferLoadType('LED corridor lighting'), 'Lighting');
const parsedVoltage = panel.panelVoltageInfo('208Y/120V');
assert.equal(parsedVoltage.lineToLine, 208);
assert.equal(parsedVoltage.lineToNeutral, 120);
assert.equal(panel.rowLoadVa({ loadAmps: '20', poles: '1' }, panel.panelVoltageInfo('208Y/120V'), 3), 2400);
assert.ok(Math.abs(panel.rowLoadVa({ loadAmps: '10', poles: '3' }, panel.panelVoltageInfo('208Y/120V'), 3) - 3602.665) < 0.01);
assert.equal(panel.normalizeLoadAmps('', '30A'), '30');
assert.equal(panel.normalizeDemandFactor('0.8'), '0.8');
assert.equal(factors.factorPercent(0.7), '70%');

console.log('Panel load analyzer helpers passed');
