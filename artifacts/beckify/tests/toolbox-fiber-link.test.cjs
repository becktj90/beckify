/* Fiber NA and link-budget math.
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
vm.runInContext(fs.readFileSync(dir + 'fiber-link.js', 'utf8'), sandbox, { filename: 'fiber-link.js' });

const F = sandbox.FiberLink;
if (!F) {
  console.error('FiberLink namespace was not exported');
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

console.log('\n--- NA = √(n1² − n2²) ---');
{
  const n1 = 1.48, n2 = 1.46;
  const na = Math.sqrt(n1 * n1 - n2 * n2);
  ok('silica-ish NA', F.numericalAperture(n1, n2), na, 1e-12);
  const dlt = (n1 - n2) / n1;
  ok('Δ = (n1 − n2)/n1', F.deltaRel(n1, n2), dlt, 0);
  ok('weakly-guiding n1 √(2Δ)', F.naFromDelta(n1, dlt), n1 * Math.sqrt(2 * dlt), 1e-12);
  okTrue('weakly-guiding NA is nearby at this Δ', Math.abs(na - n1 * Math.sqrt(2 * dlt)) < 1e-3, String(Math.abs(na - n1 * Math.sqrt(2 * dlt))));
}

console.log('\n--- Acceptance and critical angles ---');
{
  const na = F.numericalAperture(1.48, 1.46);
  ok('θa = arcsin(NA)', F.acceptanceAngleRad(na), Math.asin(na), 1e-15);
  ok('θc = arcsin(n2/n1)', F.criticalAngleRad(1.48, 1.46), Math.asin(1.46 / 1.48), 1e-15);
  okTrue('NA > 1 has no real air cone', !isFinite(F.acceptanceAngleRad(1.2)), String(F.acceptanceAngleRad(1.2)));
}

console.log('\n--- Link budget ---');
{
  const b = F.linkBudget({
    pinDbm: 0,
    alphaDbPerKm: 0.3,
    lengthM: 2000,
    nConnectors: 2,
    lossPerConnectorDb: 0.3,
    nSplices: 1,
    lossPerSpliceDb: 0.1,
    sensitivityDbm: -20
  });
  ok('fiber 0.3 dB/km × 2 km', b.fiberDb, 0.6, 1e-12);
  ok('two 0.3 dB connectors', b.connDb, 0.6, 1e-12);
  ok('one 0.1 dB splice', b.spliceDb, 0.1, 1e-12);
  ok('total loss', b.totalDb, 1.3, 1e-12);
  ok('Pout', b.poutDbm, -1.3, 1e-12);
  ok('margin vs −20 dBm', b.marginDb, 18.7, 1e-12);
  okTrue('budget closes', b.closes === true, String(b.closes));
}
{
  const short = F.linkBudget({
    pinDbm: -10,
    alphaDbPerKm: 1,
    lengthM: 20000,
    nConnectors: 0,
    lossPerConnectorDb: 0,
    nSplices: 0,
    lossPerSpliceDb: 0,
    sensitivityDbm: -20
  });
  ok('20 km × 1 dB/km', short.fiberDb, 20, 0);
  okTrue('does not close', short.closes === false, String(short.closes));
}

console.log('\n--- Markup ---');
okTrue('section sec-fiber-link exists', /id="sec-fiber-link"/.test(html));
okTrue('script fiber-link.js is loaded', /fiber-link\.js/.test(html));

console.log(failures ? `\n${failures} FAILURE(S)` : '\nAll fiber-link checks passed');
process.exitCode = failures ? 1 : 0;
