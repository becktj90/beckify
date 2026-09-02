/* NEMA wiring reference: required configs, 200.6 / 250.119 vs convention. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const sandbox = {
  console,
  Math,
  Number,
  String,
  Object,
  Array,
  JSON,
  document: { readyState: 'complete', addEventListener() {}, getElementById() { return null; } },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'nema-wiring.js'), 'utf8'), sandbox, { filename: 'nema-wiring.js' });

const api = sandbox.__nemaWiringTestApi;
assert.ok(api);
const ids = api.CONFIGS.map((c) => c.id);
for (const id of ['5-15', '5-20', '6-15', '6-20', 'L5-20', 'L5-30', 'L6-20', 'L6-30', 'L14-20', 'L14-30', 'L15-30']) {
  assert.ok(ids.includes(id), 'missing config ' + id);
}

const five15 = api.configById('5-15');
assert.equal(five15.volts, 125);
assert.equal(five15.amps, 15);
const roles = five15.blades.map((b) => b.kind).sort().join(',');
assert.equal(roles, 'gnd,hot,neu');
assert.ok(five15.blades.some((b) => b.code === 'NEC 200.6'));
assert.ok(five15.blades.some((b) => b.code === 'NEC 250.119'));
assert.ok(five15.blades.some((b) => b.code === 'convention'));

const colors = api.COLOR_SYSTEMS;
assert.ok(colors.some((s) => /120\/240/.test(s.title) && /1/.test(s.title)));
assert.ok(colors.some((s) => /208/.test(s.title)));
assert.ok(colors.some((s) => /high-leg/i.test(s.title)));
assert.ok(colors.some((s) => /480/.test(s.title)));
assert.ok(colors.some((s) => /DC/i.test(s.title)));

const mandates = colors.flatMap((s) => s.rows.map((r) => r.mandate)).join('\n');
assert.match(mandates, /NEC 200\.6/);
assert.match(mandates, /NEC 250\.119/);
assert.match(mandates, /NEC 110\.15/);
assert.match(mandates, /Industry convention/);
assert.doesNotMatch(mandates, /NEC 999/);

const highLeg = colors.find((s) => /high-leg/i.test(s.title));
assert.ok(highLeg.rows.some((r) => /110\.15/.test(r.mandate) && /Orange/i.test(r.color)));

const svg = api.renderDiagram(five15);
assert.match(svg, /<svg/);
assert.match(svg, /receptacle/i);

console.log('NEMA wiring reference accuracy checks passed');
