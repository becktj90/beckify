/* Catalog refine: one Transformer (taps out), aliases, I²R math, MV 4000 kVA / 23.2 kV. */
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');

const root = path.join(__dirname, '..');
const registry = require(path.join(root, 'src/data/toolbox-tools.mjs'));
const html = fs.readFileSync(path.join(root, 'public/toolbox/index.html'), 'utf8');
const familiesSrc = fs.readFileSync(path.join(root, 'public/toolbox/js/toolbox-families.js'), 'utf8');
const wizardSrc = fs.readFileSync(path.join(root, 'public/toolbox/js/xfmr-wizard.js'), 'utf8');
const appSrc = fs.readFileSync(path.join(root, 'public/toolbox/js/app.js'), 'utf8');

let fails = 0;
function ok(name, condition, detail) {
  if (!condition) fails += 1;
  console.log((condition ? '  PASS  ' : '  FAIL  ') + name + (detail ? ' — ' + detail : ''));
}

console.log('\n--- Catalog: one transformer job, taps stay out ---');
ok('canonical transformer slug exists', registry.TOOLS.some((t) => t[0] === 'transformer'));
ok('tap-changer stays first-class', registry.TOOLS.some((t) => t[0] === 'tap-changer' && t[3] === 'sec-tap'));
ok('old xfmr slugs are aliases, not TOOLS', ['transformer-sizing', 'transformer-engine', 'transformer-design']
  .every((slug) => registry.TOOL_ALIASES.some((a) => a[0] === slug) && !registry.TOOLS.some((t) => t[0] === slug)));
ok('basics alias of transformer slug still resolves to sec-xfmr', registry.resolveToolSlug('transformer').anchor === 'sec-xfmr-size');
ok('/#sec-xfmr is a transformer family mode', registry.TOOL_FAMILIES
  .find((f) => f.id === 'transformer').modes.some((m) => m.anchor === 'sec-xfmr' && m.id === 'basics'));
ok('tap-changer is not a transformer mode', !registry.TOOL_FAMILIES
  .find((f) => f.id === 'transformer').modes.some((m) => m.anchor === 'sec-tap' || m.slug === 'tap-changer'));
ok('aliases open the right mode', [
  ['transformer-sizing', 'sec-xfmr-size', 'sizing'],
  ['transformer-engine', 'sec-xfmr-engine', 'conductors'],
  ['transformer-design', 'sec-xfmr-wizard', 'design'],
].every(([slug, anchor, mode]) => {
  const r = registry.resolveToolSlug(slug);
  return r && r.alias && r.anchor === anchor && r.modeId === mode;
}));

console.log('\n--- Nav: no five transformer items ---');
const navTargets = [...html.matchAll(/<button class="nav-btn"[^>]*data-target="([^"]+)"/g)].map((m) => m[1]);
const xfmrNav = navTargets.filter((id) => /^sec-xfmr/.test(id));
ok('sidebar has one transformer nav target', xfmrNav.length === 1 && xfmrNav[0] === 'sec-xfmr-size', xfmrNav.join(','));
ok('tap-changer keeps its nav button', navTargets.includes('sec-tap'));
ok('no sibling xfmr nav buttons', !['sec-xfmr', 'sec-xfmr-engine', 'sec-xfmr-wizard'].some((id) => navTargets.includes(id)));
ok('families.js omits tap-changer from transformer', !/id: 'transformer'[\s\S]*sec-tap/.test(familiesSrc)
  && familiesSrc.includes("id: 'basics'") && familiesSrc.includes('sec-xfmr'));

console.log('\n--- 450.3 engine stays the real tiers ---');
ok('calcXfmr no longer emits flat 125% OCPD', !appSrc.includes("Primary OCPD (≤125% of Ip)"));
ok('sizing UI exposes method + Note 1 + continuous', html.includes('id="xs_method"') && html.includes('id="xs_note1"') && html.includes('id="xs_continuous"'));
ok('engine UI exposes pri+sec + Note 1 + continuous + parallels', html.includes('id="xe_sec_protected"') && html.includes('id="xe_note1"') && html.includes('id="xe_pri_runs"') && html.includes('id="xe_sec_runs"'));
ok('wizard dropped the second price book', !wizardSrc.includes('WIRE_COST_CU') && wizardSrc.includes('PLANNING_CONDUCTOR_PRICE_PER_FT'));
ok('LV construction is a Conductors option', html.includes('id="ws_construction"') && html.includes('4C+E'));
ok('generator starter is an on-site option', html.includes('id="gen_starter"') && html.includes('Wye-delta'));
ok('did not import third-party panel/gen worksheets', !html.includes('Jignesh') && !html.includes('electrical-engineering-portal'));
ok('did not add a second 24 VDC module-current tool', (html.match(/id="sec-ebus-budget"/g) || []).length === 1);

console.log('\n--- I²R + MV ---');
const dir = path.join(root, 'public/toolbox/js') + '/';
const sandbox = {
  document: { addEventListener() {}, getElementById() { return null; }, querySelectorAll() { return []; } },
  console, Math, Number, Object, Array, String, Set, JSON, isFinite, parseInt, parseFloat,
  isPos: function (...args) { return args.every(function (v) { return isFinite(v) && v > 0; }); },
  isNum: function (...args) { return args.every(function (v) { return isFinite(v); }); },
};
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const f of ['nec-data.js', 'wire-tools.js', 'mv-cable.js']) {
  vm.runInContext(fs.readFileSync(dir + f, 'utf8'), sandbox, { filename: f });
}
const startFn = appSrc.match(/function generatorStartMultiple\([\s\S]*?\n\}/);
if (startFn) vm.runInContext(startFn[0], sandbox);
const G = vm.runInContext(`({
  conductorI2RWatts, annualI2RCost, pvOfAnnuity, DC_RESISTANCE,
  PLANNING_CONDUCTOR_PRICE_PER_FT: (typeof PLANNING_CONDUCTOR_PRICE_PER_FT !== 'undefined' ? PLANNING_CONDUCTOR_PRICE_PER_FT : window.PLANNING_CONDUCTOR_PRICE_PER_FT),
  lvCableTypeString, lvConstructionCores, generatorStartMultiple,
  mvLoadAmps, mvSuggestedClassKv, mvTypeString, mvSelect, mvVoltageDrop
})`, sandbox);

const rKft = G.DC_RESISTANCE.cu['4/0'];
const rOneWay = rKft * (200 / 1000) / 1;
const watts = G.conductorI2RWatts(100, '4/0', 'cu', 200, 1, '3ph');
ok('3Ø I²R uses 3 × I² × R_one_way', Math.abs(watts - (3 * 100 * 100 * rOneWay)) < 1e-9, String(watts));
const annual = G.annualI2RCost(watts, 0.12, 8760);
ok('annual = (W/1000) × $/kWh × hours', Math.abs(annual - (watts / 1000) * 0.12 * 8760) < 1e-9, String(annual));
const watts1 = G.conductorI2RWatts(100, '4/0', 'cu', 200, 1, '1ph');
ok('1Ø I²R uses 2 × I² × R_one_way', Math.abs(watts1 - (2 * 100 * 100 * rOneWay)) < 1e-9);
ok('shared planning book is exposed', G.PLANNING_CONDUCTOR_PRICE_PER_FT && G.PLANNING_CONDUCTOR_PRICE_PER_FT.cu['4/0'] === 5.75);
ok('4C+E type string includes parallels', G.lvCableTypeString({
  construction: '4c+e', runs: 2, size: '4/0', material: 'cu', insulation: 'THHN',
}) === '2 × 4C+E 4/0 AWG Cu THHN');
ok('3C+E type string', G.lvCableTypeString({
  construction: '3c+e', runs: 1, size: '2', material: 'al', insulation: 'THHN',
}) === '3C+E 2 AWG Al THHN');
ok('DOL starting multiple is 6×', G.generatorStartMultiple('dol').mult === 6);
ok('wye-delta starting multiple is 2×', G.generatorStartMultiple('yd').mult === 2);
ok('10 kW motor PF 0.85 DOL start kVA', Math.abs((10 / 0.85) * G.generatorStartMultiple('dol').mult - 70.588) < 0.02);

const load = G.mvLoadAmps({ phase: '3ph', loadUnit: 'kva', loadValue: 4000, systemKv: 23.2, powerFactor: 0.9 });
ok('4000 kVA / 23.2 kV → ≈ 99.56 A', Math.abs(load.amps - 99.56) < 0.02, String(load.amps));
ok('23.2 kV suggests 25 kV class', G.mvSuggestedClassKv(23.2) === 25);
ok('15 kV is below 23.2 kV', G.mvSuggestedClassKv(23.2) > 15);
const type = G.mvTypeString({
  size: '1/0', material: 'cu', classKv: 25, level: 133, insulation: 'xlpe',
  tempC: 105, construction: '3x1c', cn: '1/3',
});
ok('type string names insulation + class', /1\/0/.test(type) && /25 kV/.test(type) && /133%/.test(type) && /TR-XLPE|XLPE/i.test(type), type);
const picked = G.mvSelect({
  phase: '3ph', loadUnit: 'kva', loadValue: 4000, systemKv: 23.2, lengthFt: 300,
  classKv: 25, insulation: 'xlpe', level: 133, material: 'cu', construction: '3x1c',
  cn: '1/3', tempC: 105, install: 'duct', continuous: true, maxVdPct: 3, powerFactor: 0.9,
});
ok('MV select returns a size and VD for 300 ft', picked.selected && picked.selected.vd && picked.selected.vd.volts > 0, JSON.stringify(picked.selected && { type: picked.selected.typeString, vd: picked.selected.vd }));
ok('15 kV class is flagged too low vs 23.2 kV', G.mvSelect({
  phase: '3ph', loadUnit: 'kva', loadValue: 4000, systemKv: 23.2, lengthFt: 300,
  classKv: 15, insulation: 'xlpe', level: 133, material: 'cu', construction: '3x1c',
  cn: '1/3', tempC: 105, install: 'duct', continuous: true, maxVdPct: 3, powerFactor: 0.9,
}).classLow === true);

console.log(fails ? `\n${fails} FAILURE(S)` : '\nAll catalog-refine checks passed');
process.exitCode = fails ? 1 : 0;
