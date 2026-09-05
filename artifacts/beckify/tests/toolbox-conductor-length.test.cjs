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

const { conductorLengthByResistanceModel, conductorMetalMassFromLength, ebPowerToWatts, ebWheelSpeedMph } =
  vm.runInContext('({ conductorLengthByResistanceModel, conductorMetalMassFromLength, ebPowerToWatts, ebWheelSpeedMph })', sandbox);

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
ok('single path copper weight (lb)', r.oneWayMassLb, 813.7, 1.0);
ok('single path copper weight equals total-path weight', r.oneWayMassLb, r.totalPathMassLb, 1e-9);

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
  rho: 21.2,
  material: 'al'
});
ok('loop total path length (ft)', r.totalLengthFt, 2010.78, 0.5);
ok('loop one-way distance (ft)', r.oneWayLengthFt, 1005.39, 0.5);
ok('loop aluminum one-way weight is half of path weight', r.oneWayMassLb, r.totalPathMassLb / 2, 1e-9);

// 3-phase loop follows product requirement: one-way is solved length / 2.
r = conductorLengthByResistanceModel({
  resistance: 0.3,
  resistanceUnit: 'ohm',
  circularMils: 167800,
  method: 'loop3',
  temperature: 20,
  temperatureUnit: 'c',
  referenceTempC: 20,
  alpha: 0.00393,
  rho: 10.371
});
ok('3-phase loop one-way uses ÷2 factor', r.oneWayLengthFt, r.totalLengthFt / 2, 1e-9);

const cuKft = conductorMetalMassFromLength(1000, 105600, 'cu-annealed');
const alKft = conductorMetalMassFromLength(1000, 105600, 'al');
ok('1/0 copper ~320 lb per 1000 ft at 8.89 g/cm³', cuKft.massLb, 319.7, 0.4);
ok('aluminum mass scales by 2.70/8.89', alKft.massLb, cuKft.massLb * 2.70 / 8.89, 1e-9);

const html = fs.readFileSync(require('path').join(__dirname, '..', 'public', 'toolbox', 'index.html'), 'utf8');
const catalog = fs.readFileSync(require('path').join(__dirname, '..', '..', '..', 'ios', 'Beckify', 'Models', 'ToolboxCatalog.swift'), 'utf8');
const assert = (name, condition) => {
  if (!condition) failures++;
  console.log((condition ? '  PASS  ' : '  FAIL  ') + name);
};
assert('copper weight label', cuKft.weightLabel === 'Copper Weight');
assert('aluminum weight label', alKft.weightLabel === 'Aluminum Weight');
const optionLabel = (value) => {
  const match = html.match(new RegExp('<option value="' + value + '">([^<]+)</option>'));
  return match ? match[1] : '';
};
assert('HTML option: short to parallel', /^Short to parallel\b/.test(optionLabel('loop2')));
assert('HTML option: end-to-end', /^End-to-end\b/.test(optionLabel('single')));
assert('HTML option: 3-phase far-end short', /^3-phase far-end short\b/.test(optionLabel('loop3')));
assert('iOS catalog subtitle mentions milliohm and short-to-parallel',
  catalog.includes('milliohm (mΩ)') && catalog.includes('short-to-parallel'));
assert('iOS catalog subtitle mentions estimated copper or aluminum weight',
  catalog.includes('estimated copper or aluminum weight'));
assert('iOS catalog synonyms include shorted parallel and kelvin',
  catalog.includes('"shorted parallel"') && catalog.includes('"kelvin"') && catalog.includes('"mohm"'));
assert('iOS catalog synonyms include copper weight', catalog.includes('"copper weight"'));
assert('HTML more-info documents density × volume weight',
  html.includes('estimated metal weight') && html.includes('8.89 g/cm³') && html.includes('2.70 g/cm³'));

console.log('\n--- E-bike helpers ---');
ok('2 kW to watts', ebPowerToWatts(2, 'kw'), 2000, 0);
ok('1 hp to watts', ebPowerToWatts(1, 'hp'), 746, 0);
ok('800 rpm, 26in wheel speed mph', ebWheelSpeedMph(800, 26), 61.85, 0.05);

console.log(failures ? `\n${failures} FAILURE(S)` : '\nAll checks passed');
process.exitCode = failures ? 1 : 0;
