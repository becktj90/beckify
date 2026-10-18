'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const js = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const ctx = vm.createContext({ console, Math, JSON, Number, String, Object, Array, isFinite, parseFloat, Date });
ctx.window = ctx; ctx.globalThis = ctx;
for (const f of ['bk-tool.js', 'bk-tools-motor.js']) vm.runInContext(fs.readFileSync(path.join(js, f), 'utf8'), ctx, { filename: f });
const T = ctx.BeckifyTool;
const run = (id, over) => { const d = T.registry[id]; return T.run(d, Object.assign(T.defaults(d), over || {})); };
const cell = (r, l) => r.r.rows.find((x) => x[0] === l)[1];
let r = run('motorSpeed');
assert.ok(r.ok); assert.equal(cell(r, 'Synchronous speed'), '1800.0 rpm'); assert.match(cell(r, 'Slip'), /^2\.78/);
assert.match(cell(r, 'Shaft torque'), /15\.01 lb/); // 5252*5/1750
r = run('motorSpeed', { mode: 'slip', slip: '0' }); assert.equal(cell(r, 'Rotor speed'), '1800.0 rpm');
assert.ok(!run('motorSpeed', { rpm: '1900' }).ok); assert.ok(!run('motorSpeed', { poles: '3' }).ok);
assert.ok(!run('motorSpeed', { freq: '0' }).ok); assert.ok(!run('motorSpeed', { freq: '' }).ok); assert.ok(!run('motorSpeed', { mode: 'slip', slip: '101' }).ok);
assert.ok(run('motorSpeed', { hp: '' }).ok);
r = run('resistorColor'); assert.equal(cell(r, 'Resistance'), '1.00 kΩ'); assert.match(cell(r, 'Bands'), /Brown · Black · Red · Gold/);
r = run('resistorColor', { mode: 'encode', ohms: '4.7k' }); assert.match(cell(r, 'Bands'), /Yellow · Violet · Red · Gold/);
r = run('resistorColor', { mode: 'encode', ohms: '4.7k', count: '5' }); assert.match(cell(r, 'Bands'), /Yellow · Violet · Black · Brown/);
r = run('resistorColor', { mode: 'encode', ohms: '0.47' }); assert.match(cell(r, 'Bands'), /Yellow · Violet · Silver/);
assert.ok(!run('resistorColor', { mode: 'encode', ohms: '0' }).ok); assert.ok(!run('resistorColor', { mode: 'encode', ohms: '1e12' }).ok);
r = run('resistorColor', { count: '5', d1: 'brown', d2: 'black', d3: 'black', mult: 'brown', tol: 'brown' }); assert.equal(cell(r, 'Resistance'), '1.00 kΩ');
assert.ok(run('resistorColor', { d1: 'gold' }).ok); // unknown choice falls back to the default band
console.log('ok');
