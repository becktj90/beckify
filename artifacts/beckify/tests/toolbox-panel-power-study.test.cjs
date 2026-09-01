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
  document: {
    getElementById() { return null; },
    querySelector() { return null; }
  }
};

sandbox.window = sandbox;
sandbox.window.addEventListener = () => {};
sandbox.window.__ENABLE_PANEL_POWER_STUDY_TEST_API__ = true;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'panel-power-study.js'), 'utf8'), sandbox, { filename: 'panel-power-study.js' });

const panel = sandbox.__panelPowerStudyTestApi;

assert.equal(panel.inferCircuitClass('Emergency egress lighting'), 'Emergency');
assert.equal(panel.inferCircuitClass('Server room UPS panel'), 'Critical');

const parsedVoltage = panel.panelVoltageInfo('480Y/277V');
assert.equal(parsedVoltage.lineToLine, 480);
assert.equal(parsedVoltage.lineToNeutral, 277);
assert.ok(Math.abs(panel.rowLoadVa({ loadAmps: '10', poles: '3' }, parsedVoltage, 3) - 8313.843) < 0.01);

const parsed = panel.parseScheduleText(`
Panel: MDP-2
Voltage: 480Y/277V
Main Rating: 400A MCB
Positions: 84
Series: QO
1 Lighting Office 20A 1P
2 Server UPS Rack 30A 2P
`);

assert.equal(parsed.meta.mainRating, '400');
assert.equal(parsed.meta.positions, '84');
assert.equal(parsed.meta.defaultSeries.toUpperCase(), 'QO');
assert.equal(parsed.rows[0].breakerSeries, 'QO');
assert.equal(parsed.rows[1].circuitClass, 'Critical');

console.log('Panel power study helpers passed');
