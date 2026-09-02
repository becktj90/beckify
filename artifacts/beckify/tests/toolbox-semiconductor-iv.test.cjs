/* Device I-V math for the Semiconductor Device I-V workbench.
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
vm.runInContext(fs.readFileSync(dir + 'semiconductor-iv.js', 'utf8'), sandbox, { filename: 'semiconductor-iv.js' });

const S = sandbox.SemiconductorIV;
if (!S) {
  console.error('SemiconductorIV namespace was not exported');
  process.exit(1);
}

let failures = 0;
function ok(name, got, want, tol) {
  const t = tol === undefined ? Math.abs(want) * 1e-9 + 1e-12 : tol;
  const pass = typeof got === 'number' && typeof want === 'number'
    ? Math.abs(got - want) <= t
    : got === want;
  if (!pass) failures += 1;
  const g = typeof got === 'number' && isFinite(got) ? got.toExponential(6) : String(got);
  const w = typeof want === 'number' && isFinite(want) ? want.toExponential(6) : String(want);
  console.log((pass ? '  PASS  ' : '  FAIL  ') + name.padEnd(64) + ' got ' + g + ' want ~' + w);
}
function okTrue(name, condition, detail) {
  if (!condition) failures += 1;
  console.log((condition ? '  PASS  ' : '  FAIL  ') + name.padEnd(64) + (detail || ''));
}

const html = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'index.html'), 'utf8');

console.log('\n--- Thermal voltage VT = kT/q ---');
const VT300 = S.K_B * 300 / S.Q_E;
ok('VT at 300 K', S.thermalVoltage(300), VT300, 1e-12);
okTrue('VT at 300 K is about 25.85 mV', Math.abs(VT300 - 0.02585) < 5e-5, String(VT300));

console.log('\n--- Shockley diode ---');
{
  const Is = 1e-12, eta = 1, VT = VT300;
  ok('I(0) = 0', S.shockley(0, Is, eta, VT), 0, 1e-18);
  const I07 = Is * (Math.exp(0.7 / VT) - 1);
  ok('I at 0.7 V, Is=1 pA, η=1, 300 K', S.shockley(0.7, Is, eta, VT), I07, I07 * 1e-9 + 1e-18);
  const ideal = S.diodeSolve(0.6, Is, eta, VT, 0);
  okTrue('ideal Rs=0 uses vD = V', Math.abs(ideal.vD - 0.6) < 1e-12, String(ideal.vD));
  ok('ideal I matches Shockley', ideal.I, S.shockley(0.6, Is, eta, VT), 1e-18);
}

console.log('\n--- Diode with series Rs ---');
{
  const Is = 1e-12, eta = 1, VT = VT300, Rs = 10, V = 0.8;
  const sol = S.diodeSolve(V, Is, eta, VT, Rs);
  okTrue('no error', !sol.error, sol.error);
  const I = S.shockley(sol.vD, Is, eta, VT);
  ok('I matches Shockley(vD)', sol.I, I, Math.abs(I) * 1e-6 + 1e-15);
  ok('V = vD + I Rs', sol.vD + sol.I * Rs, V, 1e-9);
}

console.log('\n--- BJT β-forced Q-point ---');
{
  const q = S.bjtQPoint({ Vcc: 5, Rc: 1000, Rb: 1e5, Vbeon: 0.7, beta: 100, Vcesat: 0.2 });
  okTrue('no error', !q.error, q.error);
  ok('Ib = (5-0.7)/100k', q.Ib, 4.3e-5, 1e-12);
  ok('forward-active Ic = β Ib', q.Ic, 4.3e-3, 1e-12);
  ok('Vce = 5 - Ic Rc', q.Vce, 5 - 4.3e-3 * 1000, 1e-9);
  okTrue('region is forward-active', q.region === 'forward-active', q.region);
}
{
  const sat = S.bjtQPoint({ Vcc: 5, Rc: 1000, Rb: 1e4, Vbeon: 0.7, beta: 100, Vcesat: 0.2 });
  okTrue('heavy base drive saturates', sat.region === 'saturation', sat.region);
  ok('sat Ic = (Vcc - Vcesat)/Rc', sat.Ic, (5 - 0.2) / 1000, 1e-12);
}

console.log('\n--- Long-channel NMOS ---');
{
  const kn = S.nmosKn(200e-6, 10e-6, 1e-6);
  ok('kn = μCox W/L', kn, 2e-3, 1e-12);
  const cut = S.nmosId(0.5, 3, kn, 0.7, 0);
  okTrue('cutoff Vgs < Vt', cut.region === 'cutoff', cut.region);
  ok('cutoff Id = 0', cut.Id, 0, 0);
  const sat = S.nmosId(2, 3, kn, 0.7, 0);
  const Vov = 1.3;
  okTrue('Vds > Vov is saturation', sat.region === 'saturation', sat.region);
  ok('sat Id = 0.5 kn Vov²', sat.Id, 0.5 * kn * Vov * Vov, 1e-12);
  const tri = S.nmosId(2, 0.5, kn, 0.7, 0);
  okTrue('Vds < Vov is triode', tri.region === 'triode', tri.region);
  ok('triode Id', tri.Id, kn * (Vov * 0.5 - 0.5 * 0.5 * 0.5), 1e-12);
  const clm = S.nmosId(2, 3, kn, 0.7, 0.05);
  ok('λ raises sat current', clm.Id, sat.Id * (1 + 0.05 * 3), 1e-12);
}

console.log('\n--- Markup ---');
okTrue('section sec-semiconductor-iv exists', /id="sec-semiconductor-iv"/.test(html));
okTrue('script semiconductor-iv.js is loaded', /semiconductor-iv\.js/.test(html));

console.log(failures ? `\n${failures} FAILURE(S)` : '\nAll semiconductor I-V checks passed');
process.exitCode = failures ? 1 : 0;
