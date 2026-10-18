'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const js = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const ctx = vm.createContext({ console, Math, JSON, Number, String, Object, Array, isFinite, parseFloat, Date, Set });
ctx.window = ctx; ctx.globalThis = ctx;
for (const f of ['bk-tool.js', 'bk-tools-code.js']) vm.runInContext(fs.readFileSync(path.join(js, f), 'utf8'), ctx, { filename: f });
const T = ctx.BeckifyTool;
const run = (id, over) => { const d = T.registry[id]; return T.run(d, Object.assign(T.defaults(d), over || {})); };
const cell = (r, l) => r.r.rows.find((x) => x[0] === l)[1];
/* Table 250.122 */
assert.equal(cell(run('equipmentGround', { amps: '60' }), 'Equipment ground'), '10 AWG');
assert.equal(cell(run('equipmentGround', { amps: '61' }), 'Equipment ground'), '8 AWG');
assert.equal(cell(run('equipmentGround', { amps: '20', material: 'al' }), 'Equipment ground'), '10 AWG');
assert.equal(cell(run('equipmentGround', { amps: '5000', material: 'al' }), 'Equipment ground'), '1200 kcmil');
assert.equal(cell(run('equipmentGround', { amps: '41', basis: 'load' }), 'Table row (not exceeding)'), '60 A'); // next device 45... row 60
assert.equal(cell(run('equipmentGround', { amps: '100', ungrounded: '10' }), 'Equipment ground'), '10 AWG'); // capped
assert.equal(cell(run('equipmentGround', { amps: '100', ungrounded: '10' }), 'Capped to ungrounded'), 'Yes');
for (const bad of [{ amps: '0' }, { amps: '' }, { amps: '-5' }, { amps: '7000' }, { context: 'none' }]) assert.ok(!run('equipmentGround', bad).ok, JSON.stringify(bad));
/* receptacle */
let r = run('receptacleCircuit'); assert.equal(cell(r, 'Receptacles (220.14(I))'), '10'); assert.match(cell(r, 'Voltage drop'), /^4\.74 V/);
r = run('receptacleCircuit', { continuous: 'no' }); assert.equal(cell(r, 'Receptacles (220.14(I))'), '13');
r = run('receptacleCircuit', { breaker: '15', continuous: 'no' }); assert.equal(cell(r, 'Receptacles (220.14(I))'), '10');
r = run('receptacleCircuit', { breaker: '15', size: '14' }); assert.match(cell(r, 'Conductor'), /^OK/);
r = run('receptacleCircuit', { size: '14' }); assert.match(cell(r, 'Conductor'), /Below/);
r = run('receptacleCircuit', { occupancy: 'dwelling' }); assert.equal(cell(r, 'Receptacles (practice)'), '8–10');
assert.ok(!run('receptacleCircuit', { feet: '0' }).ok); assert.ok(!run('receptacleCircuit', { volts: '' }).ok); assert.ok(!run('receptacleCircuit', { breaker: '30' }).ok);
assert.ok(!run('receptacleCircuit', { material: 'al', size: '14' }).ok); assert.ok(run('receptacleCircuit', { planned: '0' }).ok); assert.ok(!run('receptacleCircuit', { planned: '-1' }).ok);
/* lightning */
r = run('lightningProtection'); assert.equal(cell(r, 'Strike terminals'), '22'); assert.equal(cell(r, 'Down conductors'), '4');
r = run('lightningProtection', { len: '60', wid: '40', rise: '6', term: '24' }); assert.equal(cell(r, 'Roof class'), 'Pitched (steep)'); assert.equal(cell(r, 'Ridge terminals'), '4');
r = run('lightningProtection', { height: '80' }); assert.match(cell(r, 'Materials'), /Class II/); assert.equal(cell(r, 'Cone zone at ground'), 'Use rolling sphere');
assert.equal(cell(run('lightningProtection', { hazardous: 'yes' }), 'Rolling sphere'), '100 ft');
for (const bad of [{ len: '0' }, { term: '9' }, { rise: '30' }, { height: '' }, { wid: '-3' }]) assert.ok(!run('lightningProtection', bad).ok, JSON.stringify(bad));
console.log('ok');
