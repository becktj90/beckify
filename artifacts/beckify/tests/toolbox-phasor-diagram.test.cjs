/* Phasor arithmetic and balanced Δ-Y for the Phasor Diagram Workbench. */
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
vm.runInContext(fs.readFileSync(dir + 'phasor-diagram.js', 'utf8'), sandbox, { filename: 'phasor-diagram.js' });

const P = sandbox.PhasorDiagram;
if (!P) {
  console.error('PhasorDiagram namespace was not exported');
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

console.log('\n--- Complex arithmetic ---');
{
  const a = P.c(3, 4);
  ok('|3+j4| = 5', P.cmag(a), 5, 0);
  ok('arg(3+j4) = atan2(4,3)', P.carg(a), Math.atan2(4, 3), 1e-15);
  const p = P.cmul(a, P.cconj(a));
  ok('(3+j4)(3−j4) = 25', p.re, 25, 1e-12);
  ok('imag part of |z|² is 0', p.im, 0, 1e-12);
}

console.log('\n--- Series RL 3 + j4 at 10 V RMS ---');
{
  /* Pick f, L so ωL = 4 Ω: L = 4 / ω. Use f = 1/(2π) so ω = 1, L = 4. */
  const sol = P.solvePhasors({
    topology: 'series',
    freqHz: 1 / (2 * Math.PI),
    R: 3,
    L: 4,
    C: 0,
    vs: 10,
    vsMode: 'rms',
    extra: { on: false }
  });
  okTrue('no error', !sol.error, sol.error);
  ok('|Z| = 5 Ω', P.cmag(sol.Zeq), 5, 1e-12);
  ok('|I| = 2 A RMS', P.cmag(sol.I), 2, 1e-12);
  ok('θ = −atan(4/3)', sol.theta, -Math.atan(4 / 3), 1e-12);
  ok('PF = 0.6 lagging', sol.pf, 0.6, 1e-12);
  ok('P = I²R = 12 W', sol.P, 12, 1e-12);
  ok('Q = I² XL = 16 VAR', sol.Q, 16, 1e-12);
  okTrue('lagging label', /lag/.test(sol.leadLag));
  const sumV = P.cadd(P.cadd(sol.VR, sol.VL), sol.VC);
  ok('KVL Re: VR+VL+VC = Vs', sumV.re, 10, 1e-10);
  ok('KVL Im: VR+VL+VC = 0', sumV.im, 0, 1e-10);
}

console.log('\n--- Parallel RC current triangle ---');
{
  const sol = P.solvePhasors({
    topology: 'parallel',
    freqHz: 1 / (2 * Math.PI),
    R: 10,
    L: 0,
    C: 0.05,
    vs: 10,
    vsMode: 'rms',
    extra: { on: false }
  });
  /* ω=1, XC = 1/(ωC)=20 Ω, IC = Vs/XC = 0.5 A leading */
  ok('|IR| = 1 A', P.cmag(sol.IR), 1, 1e-12);
  ok('|IC| = 0.5 A', P.cmag(sol.IC), 0.5, 1e-12);
  ok('Q is negative (leading)', sol.Q, -5, 1e-12);
  okTrue('leading label', /lead/.test(sol.leadLag));
}

console.log('\n--- Peak vs RMS toggle ---');
{
  const rms = P.solvePhasors({
    topology: 'series', freqHz: 60, R: 10, L: 0, C: 0, vs: 120, vsMode: 'rms', extra: { on: false }
  });
  const peak = P.solvePhasors({
    topology: 'series', freqHz: 60, R: 10, L: 0, C: 0, vs: 120 * Math.SQRT2, vsMode: 'peak', extra: { on: false }
  });
  ok('same RMS from peak entry', rms.vsRms, peak.vsRms, 1e-12);
  ok('same |I|', P.cmag(rms.I), P.cmag(peak.I), 1e-12);
}

console.log('\n--- Balanced Δ-Y: ZΔ = 3 Zy ---');
{
  const zy = P.c(10, 4);
  const zd = P.deltaFromWye(zy);
  ok('ZΔ real = 30', zd.re, 30, 0);
  ok('ZΔ imag = 12', zd.im, 12, 0);
  const back = P.wyeFromDelta(zd);
  ok('round-trip real', back.re, 10, 1e-12);
  ok('round-trip imag', back.im, 4, 1e-12);
  const mag3 = P.cmag(zd) / P.cmag(zy);
  ok('|ZΔ| / |Zy| = 3', mag3, 3, 1e-12);
}

console.log('\n--- Markup is a phasor workbench, not 3-phase kVA ---');
{
  const html = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'index.html'), 'utf8');
  okTrue('section sec-phasor-diagram exists', /id="sec-phasor-diagram"/.test(html));
  okTrue('diagram host exists', /id="pd_diagram"/.test(html));
  okTrue('delta-y panel exists', /id="pd_dy_result"/.test(html));
  okTrue('not a 3-phase kVA sizer', /not a 3-phase kVA/i.test(html) || /not the three-phase/i.test(html));
  okTrue('ZΔ = 3 Zy shown', /ZΔ = 3 Zy/.test(html));
}

console.log(failures ? '\n' + failures + ' FAILURE(S)' : '\nPhasor diagram checks passed');
process.exitCode = failures ? 1 : 0;
