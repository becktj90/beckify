/* Faraday-loop, aperture, and skin-depth math for the EMP/EMC shielding tool.
   Run with: npm test */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const dir = path.join(__dirname, '..', 'public', 'toolbox', 'js') + '/';
const sandbox = {
  document: {
    addEventListener() {},
    getElementById() { return null; },
    querySelector() { return null; },
    querySelectorAll() { return []; },
    readyState: 'complete'
  },
  window: {},
  console,
  Math, Number, Object, Array, String, Set, JSON, isFinite, parseFloat, parseInt
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(dir + 'emp-emc.js', 'utf8'), sandbox, { filename: 'emp-emc.js' });

const E = sandbox.EmpEmc;
if (!E) {
  console.error('EmpEmc namespace was not exported');
  process.exit(1);
}

let failures = 0;
function ok(name, got, want, tol) {
  const t = tol === undefined ? Math.abs(want) * 0.005 + 1e-12 : tol;
  const pass = typeof got === 'number' && typeof want === 'number'
    ? Math.abs(got - want) <= t
    : got === want;
  if (!pass) failures += 1;
  const g = typeof got === 'number' && isFinite(got) ? got.toExponential(4) : String(got);
  const w = typeof want === 'number' && isFinite(want) ? want.toExponential(4) : String(want);
  console.log((pass ? '  PASS  ' : '  FAIL  ') + name.padEnd(62) + ' got ' + g + ' want ~' + w);
}

function okTrue(name, condition, detail) {
  if (!condition) failures += 1;
  console.log((condition ? '  PASS  ' : '  FAIL  ') + name.padEnd(62) + (detail || ''));
}

console.log('\n--- Faraday loop: V = N A |dB/dt| ---');
ok('1 turn, 10 cm square, 1 mT in 1 µs → 10 V', E.inducedVoltage(1, E.loopAreaM2('rect', 0.1, 0.1), E.dBdtFromDeltaB(1e-3, 1e-6)), 10, 1e-9);
ok('1 turn, 0.1 m², 1 mT in 1 µs → 100 V', E.inducedVoltage(1, 0.1, E.dBdtFromDeltaB(1e-3, 1e-6)), 100, 1e-9);
ok('1 turn, 0.01 m², 100 T/s → 1 V', E.inducedVoltage(1, 0.01, 100), 1, 1e-12);
ok('10 turns scale voltage ×10', E.inducedVoltage(10, 0.01, 100), 10, 1e-12);
ok('rect 10 cm × 10 cm area', E.loopAreaM2('rect', 0.1, 0.1), 0.01, 1e-12);
ok('circle r = 10 cm area', E.loopAreaM2('circle', 0.1, 0), Math.PI * 0.01, 1e-12);
ok('direct area passthrough', E.loopAreaM2('area', 0.25, 0), 0.25, 0);

console.log('\n--- dB/dt and bandwidth ---');
ok('ΔB/tr matches direct dB/dt', E.dBdtFromDeltaB(0.02, 10e-6), 2000, 1e-9);
ok('0.35 / 2.5 ns → 140 MHz', E.equivFreqFromRise(2.5e-9), 1.4e8, 1e3);

console.log('\n--- Skin depth (copper, textbook checks) ---');
const cu = E.MATERIALS.cu;
ok('Cu δ at 60 Hz ≈ 8.5 mm', E.skinDepth(cu.sigma, cu.muR, 60), 0.0085, 3e-4);
ok('Cu δ at 1 MHz ≈ 66 µm', E.skinDepth(cu.sigma, cu.muR, 1e6), 6.6e-5, 3e-6);
ok('Cu plane-wave R at 1 MHz ≈ 108 dB', E.planeWaveReflectionDb(cu.sigma, 1, 1e6), 108.2, 0.3);
{
  const est = E.shieldEstimate(cu.sigma, 1, 1e-4, 1e6);
  ok('Cu 0.1 mm at 1 MHz, t/δ ≈ 1.51', est.tOver, 1.51, 0.05);
  okTrue('sheet SE is finite and > reflection', isFinite(est.SE) && est.SE > est.R - 1);
  okTrue('thin-sheet B is 0 when t ≥ δ', est.tOver >= 1 ? est.B === 0 : true);
}
{
  const thin = E.shieldEstimate(cu.sigma, 1, 1e-6, 1e6);
  okTrue('thin sheet applies negative B', thin.B < 0);
  okTrue('thin SE is less than A+R without B', thin.SE < thin.A + thin.R);
}

console.log('\n--- Aperture leakage ---');
{
  const a = E.apertureSE(0.1, 1e8, 0);
  ok('λ at 100 MHz ≈ 3 m', a.lambda, 2.9979, 0.01);
  ok('10 cm slot at 100 MHz SE ≈ 23.5 dB', a.SE, 20 * Math.log10(1.4989 / 0.1), 0.05);
  okTrue('below half-wave has positive SE', a.SE > 20);
}
{
  const open = E.apertureSE(0.1, 1.5e9, 0);
  ok('10 cm slot at 1.5 GHz → 0 dB', open.SE, 0, 0);
  okTrue('half-wave regime flagged', /half-wave/.test(open.regime));
}
{
  const wg = E.apertureSE(0.02, 1e6, 0.01);
  okTrue('waveguide extra attenuation is positive below cutoff', wg.extraDb > 10);
  okTrue('total includes extra depth term', wg.totalDb > wg.SE);
}

console.log('\n--- Plane-wave and downconductor B ---');
ok('50 kV/m → B = E/c', E.bFromEPlaneWave(50e3), 50e3 / E.C0, 1e-16);
ok('100 kA at 1 m → 20 mT', E.bFromLineCurrent(1e5, 1), 0.02, 1e-9);
{
  const B = E.bFromEPlaneWave(50e3);
  const V = E.inducedVoltage(1, 0.01, E.dBdtFromDeltaB(B, 2.5e-9));
  ok('E1 10 cm square loop ≈ 667 V', V, 0.01 * (50e3 / E.C0) / 2.5e-9, 1e-6);
}

console.log('\n--- Published environments are protection-side only ---');
okTrue('ESD is a current test, not a plane-wave coupling model', E.ENVIRONMENTS.esd.coupling === 'none');
okTrue('HEMP E1 is an incident e-field for a victim loop', E.ENVIRONMENTS.hemp_e1.coupling === 'plane');
okTrue('HEMP E1 peak E is the IEC 61000-2-9 50 kV/m figure', E.ENVIRONMENTS.hemp_e1.peakE === 50e3);
okTrue('lightning uses downconductor distance, not a source design', E.ENVIRONMENTS.lightning.coupling === 'line');
okTrue('solar/GMD is a long-line geoelectric product', E.ENVIRONMENTS.solar.coupling === 'line-e');

console.log('\n--- Safety: source-design language stays out of the tool ---');
const sources = [
  fs.readFileSync(dir + 'emp-emc.js', 'utf8'),
  fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'index.html'), 'utf8')
];
const forbidden = [
  /marx/i,
  /spark[-\s]?gap/i,
  /flux[-\s]?compression/i,
  /vircator/i,
  /explosively\s+pumped/i,
  /coilgun/i,
  /\bherf\b/i,
  /e-?bomb/i,
  /how much (power|energy) to (disable|fry|kill|take down)/i,
  /maximize damage/i,
  /bill of materials/i,
  /part numbers? for a/i
];
const htmlHasSection = /id="sec-emp-emc"/.test(sources[1]);
okTrue('toolbox HTML includes sec-emp-emc', htmlHasSection, htmlHasSection ? '' : '(section missing — expected after wiring)');
if (htmlHasSection) {
  const start = sources[1].indexOf('id="sec-emp-emc"');
  const end = sources[1].indexOf('end sec-emp-emc', start);
  const section = end > start ? sources[1].slice(start, end) : sources[1].slice(start, start + 80000);
  const blobs = [sources[0], section];
  forbidden.forEach((re) => {
    const hit = blobs.some((text) => re.test(text));
    okTrue('forbidden pattern absent: ' + re, !hit);
  });
  okTrue('disclaimer states educational / not a weapon', /not a weapon/i.test(section) || /educational design aid/i.test(section));
  okTrue('victim loop diagram is present', /victim loop/i.test(section) || /changing B/i.test(section));
  okTrue('cage-with-slot diagram is present', /slot/i.test(section) && /cage|enclosure|faraday/i.test(section));
  okTrue('cable-entry protection diagram is present', /cable entry/i.test(section));
}

console.log(failures ? '\n' + failures + ' FAILURE(S)' : '\nAll checks passed');
process.exitCode = failures ? 1 : 0;
