/* Closed-form RC / RL / RLC transients for the Transient Circuit Lab. */
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
vm.runInContext(fs.readFileSync(dir + 'transient-circuits.js', 'utf8'), sandbox, { filename: 'transient-circuits.js' });

const T = sandbox.TransientCircuits;
if (!T) {
  console.error('TransientCircuits namespace was not exported');
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

console.log('\n--- First-order RC ---');
{
  const R = 1e3, C = 1e-6, Vs = 10, v0 = 0;
  const sol = T.solveRC(R, C, Vs, v0, false);
  ok('τ = RC = 1 ms', sol.tau, 0.001, 0);
  ok('vC(0) = v0', sol.vAt(0), 0, 1e-12);
  ok('vC(τ) = 10 (1 − 1/e)', sol.vAt(0.001), 10 * (1 - Math.exp(-1)), 1e-12);
  ok('vC(∞) → Vs', sol.vAt(0.05), 10, 1e-12);
  ok('i(0) = (Vs − v0)/R', sol.iAt(0), 10 / 1000, 1e-12);
  ok('10–90% tr = τ ln 9', sol.rise.tr, 0.001 * Math.log(9), 1e-15);
  ok('2% settle = τ ln 50', sol.ts, 0.001 * Math.log(50), 1e-15);
}
{
  const sol = T.solveRC(1000, 1e-6, 10, 5, true);
  ok('source-free vC(0)=5', sol.vAt(0), 5, 1e-12);
  ok('source-free vC(∞)=0', sol.vAt(0.05), 0, 1e-12);
  ok('source-free vC(τ)=5/e', sol.vAt(0.001), 5 * Math.exp(-1), 1e-12);
}

console.log('\n--- First-order RL ---');
{
  const sol = T.solveRL(10, 0.01, 10, 0, false);
  ok('τ = L/R = 1 ms', sol.tau, 0.001, 0);
  ok('iL(∞) = Vs/R = 1 A', sol.If, 1, 0);
  ok('iL(τ) = 1 − 1/e', sol.iAt(0.001), 1 - Math.exp(-1), 1e-12);
}

console.log('\n--- Series RLC damping cases ---');
{
  const L = 1, C = 1;
  const over = T.solveSeriesRLC(10, L, C, 0, 1, 0, true);
  okTrue('R=10, L=C=1 is overdamped', over.kind === 'over', over.kind);
  ok('α = R/(2L) = 5', over.alpha, 5, 0);
  ok('ω0 = 1', over.omega0, 1, 1e-12);
  const disc = Math.sqrt(25 - 1);
  ok('s1 = −α + √(α²−ω0²)', over.s1, -5 + disc, 1e-12);
  ok('v(0)=1', over.vAt(0), 1, 1e-10);
  ok('i(0)=C v\'(0)=0', over.iAt(0), 0, 1e-10);

  const crit = T.solveSeriesRLC(2, L, C, 0, 1, 0, true);
  okTrue('R=2, L=C=1 is critical', crit.kind === 'critical', crit.kind);
  ok('v(0)=1 critical', crit.vAt(0), 1, 1e-10);
  ok('i(0)=0 critical', crit.iAt(0), 0, 1e-10);

  const under = T.solveSeriesRLC(0.2, L, C, 0, 1, 0, true);
  okTrue('R=0.2, L=C=1 is underdamped', under.kind === 'under', under.kind);
  ok('ωd = √(ω0² − α²)', under.omegad, Math.sqrt(1 - 0.01), 1e-12);
  ok('v(0)=1 under', under.vAt(0), 1, 1e-10);
}

console.log('\n--- Series RLC step vs known numbers ---');
{
  /* R=10, L=10 mH, C=1 µF, Vs=10, v0=0, i0=0 */
  const sol = T.solveSeriesRLC(10, 0.01, 1e-6, 10, 0, 0, false);
  ok('α = 500 /s', sol.alpha, 500, 1e-9);
  ok('ω0 = 10 krad/s', sol.omega0, 1e4, 1e-6);
  okTrue('underdamped homework demo', sol.kind === 'under');
  ok('vC(0)=0', sol.vAt(0), 0, 1e-10);
  ok('i(0)=0', sol.iAt(0), 0, 1e-10);
  ok('vC(∞) → Vs', sol.vAt(0.05), 10, 1e-6);
}

console.log('\n--- Parallel RLC ---');
{
  const sol = T.solveParallelRLC(1, 1, 1, 1, 0, 0, false);
  ok('α = 1/(2RC) = 0.5', sol.alpha, 0.5, 1e-12);
  ok('ω0 = 1', sol.omega0, 1, 1e-12);
  okTrue('underdamped', sol.kind === 'under');
  ok('v(0)=0', sol.vAt(0), 0, 1e-10);
  ok('iL(0)=0', sol.iAt(0), 0, 1e-10);
  ok('iL at 40 s ≈ Is', sol.iAt(40), 1, 1e-4);
  ok('v at 40 s ≈ 0', sol.vAt(40), 0, 1e-6);
}

console.log('\n--- Markup is time-domain homework, not resonance/MNA ---');
{
  const html = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'index.html'), 'utf8');
  okTrue('section sec-transient-circuits exists', /id="sec-transient-circuits"/.test(html));
  okTrue('waveform host exists', /id="tc_wave"/.test(html));
  okTrue('says not the resonance calculator', /not the resonance calculator/i.test(html));
  okTrue('says not the MNA simulator', /not the MNA/i.test(html));
}

console.log(failures ? '\n' + failures + ' FAILURE(S)' : '\nTransient circuit checks passed');
process.exitCode = failures ? 1 : 0;
