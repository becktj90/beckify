/* Regression tests for the Conductor Length by Resistance model in app.js.
   Run with: npm test */
const fs = require('fs');
const vm = require('vm');
const dir = require('path').join(__dirname, '..', 'public', 'toolbox', 'js') + '/';

const sandbox = {
  document: {
    addEventListener() {},
    getElementById() { return null; },
    querySelectorAll() { return []; },
    querySelector() { return null; },
    documentElement: { style: { setProperty() {} } },
    body: { classList: { remove() {}, add() {}, contains() { return false; }, toggle() { return false; } } }
  },
  window: {},
  location: { hash: '', search: '' },
  localStorage: { setItem() {}, getItem() { return null; } },
  Event: function Event() {},
  console,
  Math, Number, Object, Array, String, Set, JSON, isFinite, parseInt, parseFloat,
};
sandbox.window = sandbox;
sandbox.window.matchMedia = () => ({ matches: false, addEventListener() {} });
sandbox.window.scrollTo = () => {};
sandbox.window.addEventListener = () => {};
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(dir + 'app.js', 'utf8'), sandbox, { filename: 'app.js' });

const { conductorLengthByResistanceModel } = vm.runInContext('({ conductorLengthByResistanceModel })', sandbox);

let failures = 0;
const ok = (name, got, want, tol) => {
  const t = tol === undefined ? Math.abs(want) * 0.01 : tol;
  const pass = Math.abs(got - want) <= t;
  if (!pass) failures++;
  console.log((pass ? '  PASS  ' : '  FAIL  ') + name.padEnd(56) +
    ' got ' + got.toFixed(4) + ' want ~' + want);
};

console.log('\n--- Conductor Length by Resistance ---');
// Cu @20C, 250 mΩ, 1/0 (105,600 cmil), single conductor.
let r = conductorLengthByResistanceModel({
  resistance: 250,
  resistanceUnit: 'mohm',
  circularMils: 105600,
  method: 'single',
  temperature: 20,
  temperatureUnit: 'c',
  referenceTempC: 20,
  alpha: 0.00393,
  rho: 10.371
});
ok('single path total length (ft)', r.totalLengthFt, 2545.56, 0.5);
ok('single path one-way equals total', r.oneWayLengthFt, 2545.56, 0.5);

// Same run measured hot at 75C should be corrected down at 20C.
r = conductorLengthByResistanceModel({
  resistance: 250,
  resistanceUnit: 'mohm',
  circularMils: 105600,
  method: 'single',
  temperature: 75,
  temperatureUnit: 'c',
  referenceTempC: 20,
  alpha: 0.00393,
  rho: 10.371
});
ok('hot-to-20C compensated resistance (ohm)', r.resistanceAtRefTemp, 0.2056, 0.001);

// Loop method should halve one-way distance from solved total path.
r = conductorLengthByResistanceModel({
  resistance: 0.5,
  resistanceUnit: 'ohm',
  circularMils: 66360,
  method: 'loop2',
  temperature: 68,
  temperatureUnit: 'f',
  referenceTempC: 75,
  alpha: 0.00403,
  rho: 21.2
});
ok('loop total path length (ft)', r.totalLengthFt, 2010.78, 0.5);
ok('loop one-way distance (ft)', r.oneWayLengthFt, 1005.39, 0.5);

console.log(failures ? `\n${failures} FAILURE(S)` : '\nAll checks passed');
process.exitCode = failures ? 1 : 0;
