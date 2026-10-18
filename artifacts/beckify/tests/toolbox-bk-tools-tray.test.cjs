'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const js = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const ctx = vm.createContext({ console, Math, JSON, Number, String, Object, Array, isFinite, parseFloat, Date, Set });
ctx.window = ctx; ctx.globalThis = ctx;
for (const f of ['bk-tool.js', 'bk-tools-tray.js']) vm.runInContext(fs.readFileSync(path.join(js, f), 'utf8'), ctx, { filename: f });
const T = ctx.BeckifyTool;
const run = (over) => { const d = T.registry.cableLadder; return T.run(d, Object.assign(T.defaults(d), over || {})); };
const cell = (r, l) => r.r.rows.find((x) => x[0] === l)[1];
let r = run(); assert.equal(cell(r, 'Allowable'), '14.00 in²'); assert.match(cell(r, 'Fill'), /^24\.2/); assert.equal(cell(r, 'Status'), 'PASS');
assert.equal(cell(run({ cover: 'solid' }), 'Allowable'), '11.00 in²'); // solid column
assert.equal(cell(run({ width: '9', type: 'solid' }), 'Allowable'), '8.00 in²'); // published 9 in solid
assert.equal(cell(run({ width: '15' }), 'Allowable'), '17.50 in²'); // interpolation
assert.match(run({ width: '48' }).r.warning, /extrapolation/);
assert.equal(cell(run({ contents: 'control', width: '12', depth: '8' }), 'Allowable'), '36.00 in²'); // 12*6*0.5
assert.equal(cell(run({ type: 'channel', width: '4', na: '1' }), 'Allowable'), '4.50 in²');
assert.equal(cell(run({ type: 'channel', width: '4' }), 'Allowable'), '2.50 in²');
r = run({ na: '10', oda: '1.5' }); assert.equal(cell(r, 'Status'), 'FAIL'); // 17.7 in2 > 14
r = run({ na: '9', oda: '1.3' }); assert.equal(cell(r, 'Status'), 'WARN'); // 11.9/14 = 85 %
assert.equal(cell(run({ contents: 'single', oda: '0.5', na: '10' }), 'Allowable'), '13.00 in²');
assert.match(run({ contents: 'single', rung: '12' }).r.warning, /Rung spacing/);
assert.equal(cell(run({ contents: 'single', biga: 'yes', oda: '1.2', na: '3' }), 'Allowable'), 'Single layer (width)');
assert.match(cell(run({ wa: '2000' }), 'Load'), /6\.00 lb\/ft/); // 3 x 2 lb/ft
assert.match(run({ wa: '40000' }).r.steps[2], /past NEMA VE 1 class C/);
assert.equal(cell(run({ length: '20', span: '8' }), 'Support stations'), '4 at 8.0 ft'); // 0,8,16,20
for (const bad of [{ width: '0' }, { depth: '' }, { oda: '' }, { oda: '-1' }, { na: '2.5' }, { na: '500' }, { span: '0' }, { odb: '1', wb: '-3' }]) assert.ok(!run(bad).ok, JSON.stringify(bad));
assert.equal(cell(run({ oda: '20' }), 'Status'), 'FAIL');
console.log('ok');
