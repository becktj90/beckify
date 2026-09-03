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

// A bare line-to-line voltage has to derive line-to-neutral, not reuse the
// same number: on a 3-phase panel "480" means 277 V to neutral, so a 1-pole
// circuit is 2770 VA, not 4800 VA.
const bare3Phase = panel.panelVoltageInfo('480', 3);
assert.equal(bare3Phase.lineToLine, 480);
assert.ok(Math.abs(bare3Phase.lineToNeutral - 277.128) < 0.01);
assert.ok(Math.abs(panel.rowLoadVa({ loadAmps: '10', poles: '1' }, bare3Phase, 3) - 2771.28) < 0.01);

// Single-phase 3-wire: a bare 240 means 120 V to neutral.
const bare1Phase = panel.panelVoltageInfo('240', 1);
assert.equal(bare1Phase.lineToNeutral, 120);

// An explicit pair is still trusted verbatim.
assert.equal(panel.panelVoltageInfo('208Y/120', 3).lineToNeutral, 120);

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

// OCR collapses runs of spaces, so a photographed schedule arrives as one
// space-separated line rather than aligned columns. A panel directory sticker
// also stops after the circuit name — there is no trip or pole column to find.
// Both used to parse to zero rows, leaving the editor empty after a scan.
const directory = panel.parseScheduleText(`1 LIGHTING OFFICE
2 RECEPTACLES BREAK ROOM
3 HVAC RTU-1
4 SPARE`);
assert.equal(directory.rows.length, 4);
assert.equal(directory.rows[0].circuit, '1');
assert.equal(directory.rows[0].description, 'LIGHTING OFFICE');
assert.equal(directory.rows[2].description, 'HVAC RTU-1');
assert.equal(directory.rows[2].circuitClass, 'HVAC');
assert.equal(directory.rows[3].description, 'SPARE');

// Two-up directories put the odd and even columns on one line.
const twoUp = panel.parseScheduleText(`1 LIGHTING OFFICE 2 RECEPTACLES BREAK ROOM
3 HVAC RTU-1 4 SPARE`);
assert.equal(twoUp.rows.length, 4);
assert.equal(twoUp.rows.map(row => row.circuit).join(','), '1,2,3,4');
assert.equal(twoUp.rows[1].description, 'RECEPTACLES BREAK ROOM');

// A trip with no pole column still yields a row.
const tripOnly = panel.parseScheduleText('1 LIGHTING OFFICE 20A');
assert.equal(tripOnly.rows.length, 1);
assert.equal(tripOnly.rows[0].trip, '20A');
assert.equal(tripOnly.rows[0].description, 'LIGHTING OFFICE');

// "20A" and "1P" must not be mistaken for the next circuit position, and a
// hyphenated equipment tag must not split a row either.
const fullRow = panel.parseScheduleText('1 LIGHTING OFFICE 20A 1P 2 RECEPTACLES 20A 1P');
assert.equal(fullRow.rows.length, 2);
assert.equal(fullRow.rows[0].description, 'LIGHTING OFFICE');
assert.equal(fullRow.rows[0].trip, '20A');
assert.equal(fullRow.rows[0].poles, '1');
assert.equal(fullRow.rows[1].circuit, '2');

// Ratings and unnamed noise are not circuits.
assert.equal(panel.parseScheduleText('400A MCB').rows.length, 0);
assert.equal(panel.parseScheduleText('1 20A').rows.length, 0);

console.log('Panel power study helpers passed');
