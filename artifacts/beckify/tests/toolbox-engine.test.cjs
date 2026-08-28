/* Regression tests for the toolbox calculation engine (public/toolbox/js).
   Run with: npm test
   The engine files are plain browser scripts, so they are evaluated in a vm
   context with minimal DOM stubs and the pure functions pulled back out. */
const fs = require('fs');
const vm = require('vm');
const dir = require('path').join(__dirname, '..', 'public', 'toolbox', 'js') + '/';

// Minimal browser stubs so the real files evaluate unchanged.
const sandbox = {
  document: { addEventListener() {}, getElementById() { return null; }, querySelectorAll() { return []; } },
  console,
  Math, Number, Object, Array, String, Set, JSON, isFinite, parseInt, parseFloat,
};
sandbox.window = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(dir + 'nec-data.js', 'utf8'), sandbox, { filename: 'nec-data.js' });
vm.runInContext(fs.readFileSync(dir + 'wire-tools.js', 'utf8'), sandbox, { filename: 'wire-tools.js' });

// `const` at script top level lives in the context's lexical scope, not on the
// sandbox object, so pull the bindings out by evaluating an expression there.
const {
  INSULATION_TYPES, CONDUIT_TYPES, deratedAmpacity, voltageDropVolts,
  effectiveImpedance, cccAdjustmentFactor, conduitFillLimit, ambientCorrectionFactor,
  nextStandardOCPD, WIRE_CMIL, MIN_PARALLEL_SIZE_CMIL,
} = vm.runInContext(`({
  INSULATION_TYPES, CONDUIT_TYPES, deratedAmpacity, voltageDropVolts,
  effectiveImpedance, cccAdjustmentFactor, conduitFillLimit, ambientCorrectionFactor,
  nextStandardOCPD, WIRE_CMIL, MIN_PARALLEL_SIZE_CMIL
})`, sandbox);

let failures = 0;
const ok = (name, got, want, tol) => {
  const t = tol === undefined ? Math.abs(want) * 0.01 : tol;
  const pass = Math.abs(got - want) <= t;
  if (!pass) failures++;
  console.log((pass ? '  PASS  ' : '  FAIL  ') + name.padEnd(52) +
    ' got ' + (typeof got === 'number' ? got.toFixed(4) : got) + ' want ~' + want);
};

console.log('\n--- Conduit fill vs NEC Annex C, Table C.1 (max conductors, 40% fill) ---');
const A = INSULATION_TYPES.THHN.areas, E = CONDUIT_TYPES.EMT.areas;
ok('1/2" EMT, #12 THHN  (C.1 = 9)',  Math.floor(E['1/2'] * 0.4 / A['12']), 9, 0);
ok('3/4" EMT, #12 THHN  (C.1 = 16)', Math.floor(E['3/4'] * 0.4 / A['12']), 16, 0);
ok('1"   EMT, #12 THHN  (C.1 = 25)', Math.floor(E['1'] * 0.4 / A['12']), 25, 0);
ok('1/2" EMT, #14 THHN  (C.1 = 12)', Math.floor(E['1/2'] * 0.4 / A['14']), 12, 0);
// Annex C.1 says 22 here. Computing from Table 5's ROUNDED 0.0097 in gives
// 21.99 -> 21, because Annex C is derived from the unrounded 0.009677 in
// (22.04). A one-conductor boundary artifact, and it errs conservative.
ok('3/4" EMT, #14 THHN  (Table 5 arithmetic = 21)', Math.floor(E['3/4'] * 0.4 / A['14']), 21, 0);
ok('1"   EMT, #14 THHN  (C.1 = 35)', Math.floor(E['1'] * 0.4 / A['14']), 35, 0);
ok('1/2" EMT, #10 THHN  (C.1 = 5)',  Math.floor(E['1/2'] * 0.4 / A['10']), 5, 0);
ok('3/4" EMT, #8  THHN  (C.1 = 5)',  Math.floor(E['3/4'] * 0.4 / A['8']), 5, 0);
ok('2"   EMT, 4/0 THHN  (C.1 = 4)',  Math.floor(E['2'] * 0.4 / A['4/0']), 4, 0);
ok('1"   EMT, #10 THHN  (C.1 = 16)', Math.floor(E['1'] * 0.4 / A['10']), 16, 0);
ok('2"   EMT, #2  THHN  (C.1 = 11)', Math.floor(E['2'] * 0.4 / A['2']), 11, 0);
ok('4"   EMT, 500 kcmil (C.1 = 7)',  Math.floor(E['4'] * 0.4 / A['500']), 7, 0);

console.log('\n--- Ch.9 Table 1 fill limits ---');
ok('1 conductor  = 53%', conduitFillLimit(1, false).pct, 53, 0);
ok('2 conductors = 31%', conduitFillLimit(2, false).pct, 31, 0);
ok('3 conductors = 40%', conduitFillLimit(3, false).pct, 40, 0);
ok('nipple       = 60%', conduitFillLimit(9, true).pct, 60, 0);

console.log('\n--- Ampacity derating: 310.15 + 110.14(C) ---');
let a = deratedAmpacity('4/0', 'cu', 90, 75, 30, 3);
ok('4/0 Cu base @90C', a.base, 260, 0);
ok('4/0 Cu usable capped by 75C termination', a.usable, 230, 0);
a = deratedAmpacity('4/0', 'cu', 90, 75, 30, 6);
ok('4/0 Cu, 6 CCC -> x0.80', a.derated, 208, 0.5);
ok('4/0 Cu, 6 CCC usable (below cap)', a.usable, 208, 0.5);
a = deratedAmpacity('4/0', 'cu', 90, 75, 40, 3);
ok('4/0 Cu @40C ambient -> x0.91', a.derated, 236.6, 0.5);
a = deratedAmpacity('12', 'cu', 90, 60, 30, 3);
ok('#12 Cu capped by 60C termination', a.usable, 20, 0);

console.log('\n--- Ambient correction (310.15(B)(1)) ---');
ok('90C insulation @ 40C', ambientCorrectionFactor(40, 90), 0.91, 0);
ok('75C insulation @ 40C', ambientCorrectionFactor(40, 75), 0.88, 0);
ok('60C insulation @ 40C', ambientCorrectionFactor(40, 60), 0.82, 0);
ok('90C insulation @ 30C', ambientCorrectionFactor(30, 90), 1.0, 0);

console.log('\n--- Voltage drop ---');
ok('3ph 100A 200ft 4/0 Cu PF=1', voltageDropVolts('4/0','cu','3ph',100,200,1,1), 2.1062, 0.01);
ok('1ph  20A 100ft #12 Cu PF=1', voltageDropVolts('12','cu','1ph',20,100,1,1), 7.92, 0.01);
ok('2 parallel runs halve the drop', voltageDropVolts('4/0','cu','3ph',100,200,1,2), 1.0531, 0.01);
ok('Z at PF 0.9 for 4/0', effectiveImpedance('4/0','cu',0.9), 0.072721, 0.0005);
ok('Z at PF 1.0 = R only', effectiveImpedance('4/0','cu',1), 0.0608, 0.0001);

console.log('\n--- CCC adjustment (310.15(C)(1)) ---');
[[3,1.0],[4,0.8],[6,0.8],[7,0.7],[9,0.7],[10,0.5],[20,0.5],[21,0.45],[30,0.45],[31,0.4],[41,0.35]]
  .forEach(([n,f]) => ok(n + ' CCC', cccAdjustmentFactor(n), f, 0));

console.log('\n--- Misc ---');
ok('next standard OCPD above 187A', nextStandardOCPD(187), 200, 0);
ok('parallel minimum is 1/0', MIN_PARALLEL_SIZE_CMIL, WIRE_CMIL['1/0'], 0);

console.log(failures ? `\n${failures} FAILURE(S)` : '\nAll checks passed');
process.exitCode = failures ? 1 : 0;
