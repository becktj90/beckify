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

assert.equal(panel.phaseLegFromCircuit('1', 1), 'L1');
assert.equal(panel.phaseLegFromCircuit('2', 1), 'L2');
assert.equal(panel.phaseLegFromCircuit('3', 1), 'L1');
assert.equal(panel.phaseLegFromCircuit('4', 1), 'L2');
assert.equal(panel.phaseLegFromCircuit('1', 3), 'A');
assert.equal(panel.phaseLegFromCircuit('2', 3), 'A');
assert.equal(panel.phaseLegFromCircuit('3', 3), 'B');
assert.equal(panel.phaseLegFromCircuit('5', 3), 'C');
assert.equal(panel.isSpareOrOpen({ description: 'SPARE', trip: '' }), true);
assert.equal(panel.isUnlabeled({ description: '', trip: '20A' }), true);

const metrics = panel.computeDirectoryMetrics([
  { circuit: '1', description: 'Lights', trip: '20A', poles: '1' },
  { circuit: '2', description: 'Receptacles', trip: '20A', poles: '1' },
  { circuit: '3', description: 'SPARE', trip: '', poles: '' },
  { circuit: '4', description: '', trip: '15A', poles: '1' },
], { phase: 1, mainAmps: 100, slotCount: 4 });
assert.equal(metrics.connectedBreakerAmps, 55);
assert.equal(metrics.connectedToMainPct, 55);
assert.equal(String(metrics.connectedToMainPct), '55');
assert.equal(metrics.spareCount, 1);

const twoPoleSpare = panel.computeDirectoryMetrics([
  { circuit: '1', description: 'Lights', trip: '20A', poles: '1' },
  { circuit: '3', description: 'SPARE', trip: '', poles: '2' },
], { phase: 1, mainAmps: 100 });
assert.equal(twoPoleSpare.spareCount, 2);
assert.equal(twoPoleSpare.spareTotal, 3);
assert.equal(metrics.unlabeledCount, 1);
assert.match(metrics.connectedNote, /not an NEC Article 220/i);
assert.match(metrics.connectedNote, /does not mean the panel is unsafe/i);
assert.ok(metrics.flags.some((f) => /blank labels found: 1/.test(f)));
assert.match(metrics.phaseBalance.assumption, /odd circuits on L1/i);
assert.equal(metrics.phaseBalance.legs.L1, 20);
assert.equal(metrics.phaseBalance.legs.L2, 35);

const twoPole = panel.phaseBalance(
  [{ circuit: '1', description: 'Range', trip: '30A', poles: '2' }],
  1,
);
assert.equal(twoPole.legs.L1, 30);
assert.equal(twoPole.legs.L2, 30);

const threePole = panel.phaseBalance(
  [{ circuit: '1', description: 'AHU', trip: '40A', poles: '3' }],
  3,
);
assert.equal(threePole.legs.A, 40);
assert.equal(threePole.legs.B, 40);
assert.equal(threePole.legs.C, 40);
assert.match(threePole.assumption, /3-pole breaker/i);

const floatPct = panel.computeDirectoryMetrics(
  [{ circuit: '1', description: 'Lights', trip: '11A', poles: '1' }],
  { phase: 1, mainAmps: 20, slotCount: 1 }
);
assert.equal(floatPct.connectedToMainPct, 55);
assert.equal(String(floatPct.connectedToMainPct), '55');

const panelSrc = fs.readFileSync(path.join(root, 'panel-schedule.js'), 'utf8');
assert.match(panelSrc, /DOMContentLoaded/);
assert.match(panelSrc, /bootPanelSchedule/);
assert.match(panelSrc, /pagehide/);
assert.match(panelSrc, /cacheElements\(\)/);
assert.match(panelSrc, /bindEvents\(\)/);

console.log('Panel load analyzer helpers passed');
