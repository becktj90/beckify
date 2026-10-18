'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const js = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const ctx = vm.createContext({ console, Math, JSON, Number, String, Object, Array, isFinite, parseFloat, Date, Set });
ctx.window = ctx; ctx.globalThis = ctx;
for (const f of ['bk-tool.js', 'bk-tools-solenoid.js', 'bk-tools-cable.js']) vm.runInContext(fs.readFileSync(path.join(js, f), 'utf8'), ctx, { filename: f });
const T = ctx.BeckifyTool;
const run = (id, over) => { const d = T.registry[id]; return T.run(d, Object.assign(T.defaults(d), over || {})); };
const cell = (r, l) => r.r.rows.find((x) => x[0] === l)[1];
const near = (a, b, t) => assert.ok(Math.abs(a - b) <= t * Math.abs(b), a + ' vs ' + b);
/* cable */
assert.equal(cell(run('flexibleCable'), 'Allowable ampacity'), '20.0 A'); // 12 AWG col A 20
assert.equal(cell(run('flexibleCable', { ccc: '2', conductors: '2' }), 'Allowable ampacity'), '25.0 A');
assert.equal(cell(run('flexibleCable', { ccc: '4', conductors: '5' }), 'Allowable ampacity'), '16.0 A'); // x0.8
assert.equal(cell(run('flexibleCable', { ambient: '40' }), 'Allowable ampacity'), '18.2 A'); // x0.91
assert.equal(cell(run('flexibleCable', { family: 'typeW', size: '4' }), 'Allowable ampacity'), '114.0 A');
assert.equal(cell(run('flexibleCable', { family: 'typeW', size: '4/0', ccc: '1', conductors: '1' }), 'Allowable ampacity'), '405.0 A');
assert.match(cell(run('flexibleCable', { load: '30' }), 'Smallest that works'), /^8 AWG/);
assert.match(cell(run('flexibleCable', { load: '20', continuous: 'yes' }), 'Smallest that works'), /^10 AWG/);
for (const bad of [{ ccc: '1' }, { ccc: '4', conductors: '3' }, { ambient: '100' }, { family: 'typeW', insulation: '75' }, { family: 'typeW', size: '3/0', ccc: '1', conductors: '1' }, { size: '4/0' }, { load: '500' }, { load: '-1' }, { ccc: '' }, { ccc: '2.5' }, { ambient: '' }]) assert.ok(!run('flexibleCable', bad).ok, JSON.stringify(bad));
assert.ok(run('flexibleCable', { ambient: '-10' }).ok);
/* solenoid */
let r = run('solenoidDesign'); assert.ok(r.ok); assert.equal(cell(r, 'Center B'), '11.7 mT'); assert.equal(cell(r, 'Inductance'), '1.97 mH');
r = run('solenoidDesign', { gap: '1', mur: '1' }); near(parseFloat(cell(r, 'Plunger force')), 500 * 500 * 4e-7 * Math.PI * Math.PI * 1e-4 / (2 * 1e-6), 0.01);
for (const bad of [{ len: '0' }, { rad: '' }, { turns: '0' }, { turns: '10.5' }, { current: '-1' }, { awg: '50' }, { awg: '-5' }, { gap: '-1' }, { len: '0.1' }, { mur: '0' }]) assert.ok(!run('solenoidDesign', bad).ok, JSON.stringify(bad));
assert.ok(run('solenoidDesign', { turns: '1', len: '5' }).ok);
assert.ok(run('solenoidDesign', { mur: '1000', current: '50' }).r.warning.includes('saturat'));
console.log('ok');
