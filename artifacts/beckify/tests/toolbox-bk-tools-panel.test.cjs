'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const js = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const ctx = vm.createContext({ console, Math, JSON, Number, String, Object, Array, isFinite, parseFloat, Date, Set });
ctx.window = ctx; ctx.globalThis = ctx;
for (const f of ['bk-tool.js', 'bk-tools-panel.js']) vm.runInContext(fs.readFileSync(path.join(js, f), 'utf8'), ctx, { filename: f });
const T = ctx.BeckifyTool;
const run = (over) => { const d = T.registry.ul508aPanelLab; return T.run(d, Object.assign(T.defaults(d), over || {})); };
const cell = (r, l) => r.r.rows.find((x) => x[0] === l)[1];
let r = run(); // 500 VA 480->120: primary 1.04 A -> 500% = 5.21 -> 6? next standard is 10
assert.equal(cell(r, 'Primary band'), '500 %'); assert.equal(cell(r, 'Primary device'), '10 A'); assert.equal(cell(r, 'Secondary device'), '5.2'.length ? cell(r, 'Secondary device') : '');
r = run({ va: '5000' }); assert.equal(cell(r, 'Primary band'), '125 %'); // 10.4 A
assert.equal(cell(r, 'Primary device'), '10 A'); // 13.0 ceiling -> 10
r = run({ va: '2000' }); assert.equal(cell(r, 'Primary band'), '167 %'); // 4.17A -> 6.96 -> 10
r = run({ mode: 'isc', va: '1000', sv: '120' }); assert.match(cell(r, 'Secondary Isc'), /^(397|397\.\d+|[\d.]+ A)/); assert.ok(Math.abs(parseFloat(cell(r, 'Full-load current')) - 8.33) < 0.01);
r = run({ mode: 'isc', va: '75000', sv: '208', phases: '3', z: '5' }); assert.ok(Math.abs(parseFloat(cell(r, 'Full-load current')) - 208.2) < 0.2);
assert.equal(cell(run({ mode: 'isc', z: '1' }), '%Z used'), '2.10 %');
r = run({ mode: 'disc', amps: '45' }); assert.equal(cell(r, 'Next standard size'), '45 A');
for (const bad of [{ va: '0' }, { pv: '' }, { sv: '-120' }, { mode: 'isc', z: '-1' }, { mode: 'disc', amps: '0' }]) assert.ok(!run(bad).ok, JSON.stringify(bad));
console.log('ok');
