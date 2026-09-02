/* Gaussian-beam identities.
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
vm.runInContext(fs.readFileSync(dir + 'gaussian-beam.js', 'utf8'), sandbox, { filename: 'gaussian-beam.js' });

const G = sandbox.GaussianBeam;
if (!G) {
  console.error('GaussianBeam namespace was not exported');
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

const lambda = 633e-9;
const w0 = 50e-6;
const zR = Math.PI * w0 * w0 / lambda;

console.log('\n--- Rayleigh, spot, curvature ---');
ok('zR = π w0² / λ', G.rayleigh(w0, lambda), zR, zR * 1e-12);
ok('w(0) = w0', G.spot(w0, 0, zR), w0, 0);
ok('w(zR) = w0 √2', G.spot(w0, zR, zR), w0 * Math.SQRT2, w0 * 1e-12);
okTrue('R(0) is infinite', !Number.isFinite(G.curvature(0, zR)), String(G.curvature(0, zR)));
ok('R(zR) = 2 zR', G.curvature(zR, zR), 2 * zR, zR * 1e-12);
ok('confocal b = 2 zR', G.confocal(zR), 2 * zR, 0);
ok('θ = λ / (π w0)', G.divergence(lambda, w0), lambda / (Math.PI * w0), 1e-18);
ok('I(zR)/I0 = 1/2', G.onAxisIntensityRatio(w0, w0 * Math.SQRT2), 0.5, 1e-12);

console.log('\n--- Solved beam at z = zR ---');
{
  const sol = G.solveBeam({ w0: w0, lambda: lambda, z: zR });
  okTrue('no error', !sol.error, sol.error);
  ok('solved zR', sol.zR, zR, zR * 1e-12);
  ok('solved w', sol.w, w0 * Math.SQRT2, w0 * 1e-12);
  ok('solved R', sol.R, 2 * zR, zR * 1e-12);
}

console.log('\n--- Markup ---');
okTrue('section sec-gaussian-beam exists', /id="sec-gaussian-beam"/.test(html));
okTrue('script gaussian-beam.js is loaded', /gaussian-beam\.js/.test(html));

console.log(failures ? `\n${failures} FAILURE(S)` : '\nAll gaussian-beam checks passed');
process.exitCode = failures ? 1 : 0;
