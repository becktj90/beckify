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
  document: {
    getElementById() { return null; },
    querySelector() { return null; },
    addEventListener() {},
  },
};
sandbox.window = sandbox;
sandbox.window.addEventListener = () => {};
sandbox.window.__ENABLE_HEATER_WIZARD_TEST_API__ = true;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'heater-wizard.js'), 'utf8'), sandbox, { filename: 'heater-wizard.js' });

const hw = sandbox.__heaterWizardTestApi;

/* ── AWG diameter formula against well-known standard reference points ── */
assert.ok(Math.abs(hw.hwAwgDiameterIn(36) - 0.005) < 1e-6, 'AWG 36 must be exactly 0.005 in by definition');
assert.ok(Math.abs(hw.hwAwgDiameterIn(20) - 0.0320) < 1e-3, 'AWG 20 ~= 0.0320 in');
assert.ok(Math.abs(hw.hwAwgDiameterIn(10) - 0.1019) < 1e-3, 'AWG 10 ~= 0.1019 in');
assert.ok(Math.abs(hw.hwAwgDiameterIn(0) - 0.3249) < 1e-3, 'AWG 1/0 (n=0) ~= 0.3249 in');

/* ── Three-phase wye/delta relations for a 30 kW, 480 V balanced heater ── */
const P = 30000, V = 480;
const legRWye = hw.hwLegResistance(P, V, '3ph', 'wye');
const legRDelta = hw.hwLegResistance(P, V, '3ph', 'delta');
const iLine = hw.hwLineCurrent(P, V, '3ph');

assert.ok(Math.abs(legRWye - 7.68) < 1e-9, 'Wye R_leg = V_LL^2 / P = 480^2/30000 = 7.68 ohm');
assert.ok(Math.abs(legRDelta - 23.04) < 1e-9, 'Delta R_leg = 3 x V_LL^2 / P = 23.04 ohm');
assert.ok(Math.abs(legRDelta / legRWye - 3) < 1e-9, 'A delta leg needs exactly 3x the resistance of a wye leg for the same job');
assert.ok(Math.abs(iLine - 30000 / (Math.sqrt(3) * 480)) < 1e-9, 'I_line = P / (sqrt(3) x V_LL)');

// Internal consistency: each connection must independently sum to the same total power.
const vPhaseWye = hw.hwPhaseVoltage(V, '3ph', 'wye');
assert.ok(Math.abs((vPhaseWye * vPhaseWye / legRWye) * 3 - P) < 1e-6, 'Wye: 3 legs at V_phase^2/R_leg sum back to P_total');
const vPhaseDelta = hw.hwPhaseVoltage(V, '3ph', 'delta');
const legCurrentDelta = vPhaseDelta / legRDelta;
assert.ok(Math.abs(Math.sqrt(3) * legCurrentDelta - iLine) < 1e-9, 'Delta: sqrt(3) x leg current reproduces the same line current');
assert.ok(Math.abs(vPhaseDelta * legCurrentDelta * 3 - P) < 1e-6, 'Delta: 3 legs at V_leg x I_leg sum back to P_total');

/* ── 1-phase Ohm's-law path ── */
const legR1ph = hw.hwLegResistance(6000, 240, '1ph', 'wye'); // conn ignored for 1ph
assert.ok(Math.abs(legR1ph - (240 * 240) / 6000) < 1e-9, '1-phase: R = V^2/P');
assert.ok(Math.abs(hw.hwLineCurrent(6000, 240, '1ph') - 25) < 1e-9, '1-phase: I = P/V = 6000/240 = 25 A');

/* ── Series/parallel per-element split, 3 elements on a wye leg ── */
const legPower = P / 3;
const series = hw.hwElementFromLeg(legRWye, iLine, vPhaseWye, legPower, 3, 'series');
assert.ok(Math.abs(series.resistance - legRWye / 3) < 1e-9, 'Series: R_element = R_leg / n');
assert.ok(Math.abs(series.current - iLine) < 1e-9, 'Series: current unchanged through series elements');
assert.ok(Math.abs(series.power - legPower / 3) < 1e-6, 'Series: power splits evenly');

const parallel = hw.hwElementFromLeg(legRWye, iLine, vPhaseWye, legPower, 3, 'parallel');
assert.ok(Math.abs(parallel.resistance - legRWye * 3) < 1e-9, 'Parallel: R_element = R_leg x n');
assert.ok(Math.abs(parallel.current - iLine / 3) < 1e-9, 'Parallel: current splits evenly');
assert.ok(Math.abs(parallel.power - legPower / 3) < 1e-6, 'Parallel: power splits evenly (same total either way)');

/* ── Custom element design: R=10 ohm, P=500 W, AWG 20, rho=1.09 (Nichrome 80) ── */
const design = hw.hwElementDesign(10, 500, 1.09, 20);
const expectedArea = Math.PI / 4 * Math.pow(hw.hwAwgDiameterMm(20), 2);
assert.ok(Math.abs(design.areaMm2 - expectedArea) < 1e-9, 'Cross-section area = (pi/4) x d^2');
const expectedResPerM = 1.09 / expectedArea;
assert.ok(Math.abs(design.resPerMeter - expectedResPerM) < 1e-9, 'R-per-meter = rho / A');
assert.ok(Math.abs(design.lengthM - 10 / expectedResPerM) < 1e-9, 'Length = target R / R-per-meter');
assert.ok(Math.abs(design.current - Math.sqrt(500 / 10)) < 1e-9, 'I = sqrt(P/R)');
assert.ok(Math.abs(design.voltage - design.current * 10) < 1e-9, 'V = I x R');
assert.ok(Math.abs(design.currentDensity - design.current / design.areaMm2) < 1e-9, 'Current density = I / A');

// A thicker wire needs proportionally more length for the same resistance
// (R = rho L / A means L = R A / rho), so AWG 10 (fatter) must be longer
// than AWG 30 (thinner) for the same 10 ohm target.
const thick = hw.hwElementDesign(10, 500, 1.09, 10);
const thin = hw.hwElementDesign(10, 500, 1.09, 30);
assert.ok(thick.lengthM > thin.lengthM, 'Thicker wire needs more length for the same resistance');
assert.ok(thick.diameterMm > thin.diameterMm, 'Lower AWG number is a thicker wire');

/* ── Coil geometry ── */
const geom = hw.hwCoilGeometry(design.lengthM, design.diameterMm, 10, null);
const expectedCirc = Math.PI * (10 + design.diameterMm);
assert.ok(Math.abs(geom.turns - (design.lengthM * 1000) / expectedCirc) < 1e-6, 'Turns = length / (pi x mean coil diameter)');
assert.ok(Math.abs(geom.meanCoilDiameterMm - (10 + design.diameterMm)) < 1e-9, 'Mean coil diameter = mandrel + wire diameter');

console.log('Heater wizard math verified: AWG geometry, 3-phase wye/delta, series/parallel split, element design, coil geometry');
