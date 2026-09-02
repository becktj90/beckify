/* Reluctance-network math for the Magnetic Circuit Workbench.
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
vm.runInContext(fs.readFileSync(dir + 'magnetic-circuit.js', 'utf8'), sandbox, { filename: 'magnetic-circuit.js' });

const M = sandbox.MagneticCircuit;
if (!M) {
  console.error('MagneticCircuit namespace was not exported');
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

const MU0 = 4 * Math.PI * 1e-7;
const L = 0.2, A = 4e-4, UR = 4000;
const mu = UR * MU0;
const Rcore = L / (mu * A);

console.log('\n--- Reluctance identity R = ℓ / (μ A) ---');
ok('μ0 = 4π × 10⁻⁷', M.MU0, MU0, 0);
ok('core R, ℓ=0.2 m, A=4e-4 m², μr=4000', M.reluctance(L, A, mu), Rcore, 1e-6);
ok('permeability from μr', M.permeability('ur', UR, 0), mu, 1e-18);
ok('permeability from μ', M.permeability('mu', 0, 0.005), 0.005, 0);

console.log('\n--- Series / parallel network ---');
ok('two equal series reluctances', M.seriesReluctance([100, 100]), 200, 0);
ok('two equal parallel reluctances', M.parallelReluctance([100, 100]), 50, 0);
ok('three parallel 30 Ω-analog', M.parallelReluctance([90, 90, 90]), 30, 1e-12);

console.log('\n--- Gap fringing A_eff = (√A + k ℓg)² ---');
ok('k=0 leaves area unchanged', M.fringeArea(4e-4, 0.001, 0), 4e-4, 0);
ok('k=1 square-equivalent', M.fringeArea(4e-4, 0.001, 1), Math.pow(0.02 + 0.001, 2), 1e-18);
ok('k=2 grows twice as far', M.fringeArea(4e-4, 0.001, 2), Math.pow(0.02 + 0.002, 2), 1e-18);

console.log('\n--- Gapped series core: Φ = NI / Rtot ---');
{
  const lg = 0.001;
  const Rgap = lg / (MU0 * A);
  const sol = M.solveMagneticCircuit({
    network: 'series',
    steel: [{ on: true, label: 'Core', lengthM: L, areaM2: A, muMode: 'ur', ur: UR }],
    gap: { on: true, lengthM: lg, areaM2: A, fringing: false, k: 1 },
    turns: 200,
    amps: 2,
    bsat: 1.5
  });
  okTrue('no error', !sol.error, sol.error);
  ok('Rsteel matches core', sol.Rsteel, Rcore, 1e-4);
  ok('Rgap = ℓg / (μ0 A)', sol.Rgap, Rgap, 1e-3);
  ok('Rtot = Rsteel + Rgap', sol.Rtot, Rcore + Rgap, 1e-3);
  ok('F = 400 A·t', sol.F, 400, 0);
  ok('Φ = F / Rtot', sol.flux, 400 / (Rcore + Rgap), 1e-12);
  const B = sol.flux / A;
  ok('core B = Φ / A', sol.drops[0].B, B, 1e-12);
  ok('H = B / μ', sol.drops[0].H, B / mu, 1e-9);
  const mmfSum = sol.drops.reduce((s, d) => s + d.mmf, 0);
  ok('Ampere: Σ ΦR = NI', mmfSum, 400, 1e-6);
}

console.log('\n--- Parallel steel, shared series gap ---');
{
  const sol = M.solveMagneticCircuit({
    network: 'parallel',
    steel: [
      { on: true, label: 'A', lengthM: L, areaM2: A, muMode: 'ur', ur: UR },
      { on: true, label: 'B', lengthM: L, areaM2: A, muMode: 'ur', ur: UR }
    ],
    gap: { on: false, lengthM: 0, areaM2: A, fringing: false, k: 1 },
    turns: 100,
    amps: 1,
    bsat: 2
  });
  ok('Rsteel is half of one core', sol.Rsteel, Rcore / 2, 1e-4);
  ok('flux splits equally', sol.drops[0].flux, sol.drops[1].flux, 1e-16);
  ok('each branch flux is half of total', sol.drops[0].flux, sol.flux / 2, 1e-16);
  const mmfSum = sol.drops.reduce((s, d) => s + d.mmf, 0);
  /* Parallel without gap: each drop is Φ_i R_i = F, but we must not double-count.
     The Ampere loop through one branch equals F; the listed drops are per-leg. */
  ok('each steel MMF drop equals F', sol.drops[0].mmf, 100, 1e-6);
  okTrue('two legs listed', sol.drops.length === 2);
  void mmfSum;
}

console.log('\n--- Fringing reduces gap reluctance ---');
{
  const plain = M.solveMagneticCircuit({
    network: 'series',
    steel: [{ on: true, lengthM: L, areaM2: A, muMode: 'ur', ur: UR }],
    gap: { on: true, lengthM: 0.001, areaM2: A, fringing: false, k: 1 },
    turns: 200, amps: 2, bsat: 1.5
  });
  const fringe = M.solveMagneticCircuit({
    network: 'series',
    steel: [{ on: true, lengthM: L, areaM2: A, muMode: 'ur', ur: UR }],
    gap: { on: true, lengthM: 0.001, areaM2: A, fringing: true, k: 1 },
    turns: 200, amps: 2, bsat: 1.5
  });
  okTrue('fringing Rgap < geometric Rgap', fringe.Rgap < plain.Rgap);
  okTrue('fringing flux > geometric flux', fringe.flux > plain.flux);
}

console.log('\n--- Original markup, no publisher-figure traces ---');
{
  const html = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'index.html'), 'utf8');
  okTrue('section sec-magnetic-circuit exists', /id="sec-magnetic-circuit"/.test(html));
  okTrue('core+gap SVG host exists', /id="mc_diagram"/.test(html));
  okTrue('B vs NI plot host exists', /id="mc_plot"/.test(html));
  okTrue('Iskander citation is present', /Iskander/.test(html) && /Waveland/.test(html) && /2013/.test(html));
  okTrue('not a transformer kVA sizer', /not a transformer kVA sizer/i.test(html));
  okTrue('saturation caveat', /saturation is not modeled/i.test(html));
}

console.log(failures ? '\n' + failures + ' FAILURE(S)' : '\nMagnetic circuit checks passed');
process.exitCode = failures ? 1 : 0;
