/* Regression tests for the 555 timer and the transformer selection engine
   (public/toolbox/js). Run with: npm test

   Both files are plain browser scripts, so they are evaluated in a vm context
   with minimal DOM and helper stubs, and the pure functions are pulled back
   out of the context's lexical scope. */
const fs = require('fs');
const vm = require('vm');
const dir = require('path').join(__dirname, '..', 'public', 'toolbox', 'js') + '/';

const sandbox = {
  document: { addEventListener() {}, getElementById() { return null; }, querySelectorAll() { return []; } },
  console, Math, Number, Object, Array, String, Set, JSON, isFinite, parseInt, parseFloat,
  // Helpers these modules borrow from app.js / wire-tools.js at call time.
  fmt: (n, d) => Number(n).toFixed(d === undefined ? 4 : d),
  val: () => NaN,
  isPos: (...a) => a.every((v) => isFinite(v) && v > 0),
  isNum: (...a) => a.every((v) => isFinite(v)),
  showError: () => {},
  appendCopyBtn: () => {},
  wtClear: () => null,
  wtRow: () => {}, wtHeading: () => {}, wtNote: () => {},
  PASS_COLOR: '', FAIL_COLOR: '', WARN_COLOR: '',
};
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const f of ['nec-data.js', 'wire-tools.js', 'power-tools.js', 'timer555.js', 'xfmr-engine.js']) {
  vm.runInContext(fs.readFileSync(dir + f, 'utf8'), sandbox, { filename: f });
}

const G = vm.runInContext(`({
  LN2, LN3, egcForOCPD, gecForConductor, WIRE_CMIL,
  xeFla, xePickConductor, xeImpedance, xeVoltageDrop, xeConduit, xeConductorsPerRun
})`, sandbox);

let failures = 0;
const ok = (name, got, want, tol) => {
  const t = tol === undefined ? Math.abs(want) * 0.005 : tol;
  const pass = typeof want === 'string' ? got === want : Math.abs(got - want) <= t;
  if (!pass) failures++;
  console.log((pass ? '  PASS  ' : '  FAIL  ') + name.padEnd(52) +
    ' got ' + (typeof got === 'number' ? got.toFixed(4) : got) + ' want ' + want);
};

console.log('\n--- 555 timer constants ---');
ok('ln(2) astable coefficient', G.LN2, 0.693147, 1e-5);
ok('ln(3) monostable coefficient (the "1.1")', G.LN3, 1.098612, 1e-5);

console.log('\n--- 555 astable, R1=10k R2=47k C=1uF ---');
const R1 = 10e3, R2 = 47e3, C = 1e-6;
const tHigh = G.LN2 * (R1 + R2) * C, tLow = G.LN2 * R2 * C;
ok('t_high 39.51 ms', tHigh * 1e3, 39.5094, 0.001);
ok('t_low 32.58 ms', tLow * 1e3, 32.5779, 0.001);
ok('frequency 13.87 Hz', 1 / (tHigh + tLow), 13.8721, 0.001);
ok('duty cycle 54.81 %', (tHigh / (tHigh + tLow)) * 100, 54.8077, 0.01);
// Standard configuration can never reach 50%: t_high > t_low for any positive R1.
ok('duty always above 50% without a diode', (tHigh / (tHigh + tLow)) * 100 > 50 ? 1 : 0, 1, 0);
console.log('  (with a diode across R2 the charge path is R1 only, so R1=R2 gives exactly 50%)');
ok('diode R1=R2=10k gives 50 %',
  (G.LN2 * R1 * C) / (G.LN2 * R1 * C + G.LN2 * R1 * C) * 100, 50, 1e-9);

console.log('\n--- 555 monostable, R=100k C=10uF ---');
ok('pulse width 1.0986 s', G.LN3 * 100e3 * 10e-6, 1.098612, 1e-5);

console.log('\n--- Transformer FLA ---');
ok('75 kVA 480 V 3ph primary', G.xeFla(75, 480, '3ph'), 90.2110, 0.001);
ok('75 kVA 208 V 3ph secondary', G.xeFla(75, 208, '3ph'), 208.1793, 0.001);
ok('25 kVA 240 V 1ph', G.xeFla(25, 240, '1ph'), 104.1667, 0.001);

console.log('\n--- Conductor selection (310.16 + 110.14(C)) ---');
let c = G.xePickConductor(112.76, 'cu', 90, 75, 30, 3);
ok('112.76 A -> 2 AWG Cu', c.size, '2');
ok('  capped by 75C termination', c.usable, 115, 0);
ok('  governed by termination', c.limitedBy, 'termination');
c = G.xePickConductor(260.22, 'cu', 90, 75, 30, 3);
ok('260.22 A -> 300 kcmil Cu', c.size, '300');
ok('  usable 285 A', c.usable, 285, 0);
c = G.xePickConductor(112.76, 'CU', 90, 75, 30, 3);
ok('uppercase copper key is normalized', c.size, '2');
c = G.xePickConductor(112.76, 'AL', 90, 75, 30, 3);
ok('uppercase aluminium key is normalized', typeof c.size, 'string');
c = G.xePickConductor(112.76, 'cu', 75, 75, 30, 3);
ok('THW selection uses its 75C column', c.base, 115, 0);
// 40C ambient and 6 CCC must push the size up.
const hot = G.xePickConductor(112.76, 'cu', 90, 75, 40, 6);
ok('derated 40C/6CCC needs a larger size', G.WIRE_CMIL[hot.size] > G.WIRE_CMIL['2'] ? 1 : 0, 1, 0);

console.log('\n--- Grounding tables ---');
ok('EGC for 225 A device (Table 250.122)', G.egcForOCPD(225, 'cu').size, '4');
ok('EGC for 300 A device', G.egcForOCPD(300, 'cu').size, '4');
ok('EGC for 100 A device', G.egcForOCPD(100, 'cu').size, '8');
ok('EGC for 20 A device', G.egcForOCPD(20, 'cu').size, '12');
ok('EGC aluminium for 225 A', G.egcForOCPD(225, 'al').size, '2');
ok('GEC for 300 kcmil Cu (Table 250.66)', G.gecForConductor(G.WIRE_CMIL['300'], 'cu').size, '2');
ok('GEC for 2 AWG Cu', G.gecForConductor(G.WIRE_CMIL['2'], 'cu').size, '8');
ok('GEC for 1/0 Cu', G.gecForConductor(G.WIRE_CMIL['1/0'], 'cu').size, '6');
ok('GEC for 600 kcmil Cu', G.gecForConductor(G.WIRE_CMIL['600'], 'cu').size, '1/0');

console.log('\n--- Voltage drop ---');
// 2 AWG Cu, R=0.194, X=0.045 at PF 0.9 -> Z = 0.1746 + 0.01961 = 0.19421
ok('Z for 2 AWG at PF 0.9', G.xeImpedance('2', 'cu', 0.9), 0.194214, 1e-5);
const vd = G.xeVoltageDrop('2', 'cu', '3ph', 90.211, 120, 0.9, 480);
ok('3ph 90.2 A 120 ft 2 AWG drop', vd.volts, 3.6414, 0.01);
ok('  as a percentage of 480 V', vd.percent, 0.7586, 0.01);

console.log('\n--- Conductors per run ---');
ok('3ph wye = 4 (adds neutral)', G.xeConductorsPerRun('3ph', 'wye'), 4, 0);
ok('3ph delta = 3', G.xeConductorsPerRun('3ph', 'delta'), 3, 0);
ok('1ph = 2', G.xeConductorsPerRun('1ph', 'single'), 2, 0);

console.log('\n--- Conduit at 40% fill ---');
// 4 x 300 kcmil THHN (0.4608) + 1 x 4 AWG EGC (0.0824) = 1.9256 in2
// 2-1/2" EMT 40% = 1.9152 (short), 3" EMT 40% = 2.9572 -> 3"
const cd = G.xeConduit('EMT', 4, '300', '4', 'THHN');
ok('4x300kcmil + 4AWG EGC area', cd.totalArea, 1.9256, 1e-4);
ok('  needs 3" EMT', cd.size, '3');
ok('  counts 5 conductors', cd.conductorCount, 5, 0);

console.log(failures ? `\n${failures} FAILURE(S)` : '\nAll checks passed');
process.exitCode = failures ? 1 : 0;
