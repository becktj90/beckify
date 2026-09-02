/* Motor nameplate NEC 430.32 / Table 430.52 / code-letter LRA. No invented articles. */
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
  isFinite,
  parseInt,
  parseFloat,
  document: {
    readyState: 'complete',
    addEventListener() {},
    getElementById() { return null; },
    querySelectorAll() { return []; },
  },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'nec-data.js'), 'utf8'), sandbox, { filename: 'nec-data.js' });
vm.runInContext(fs.readFileSync(path.join(root, 'wire-tools.js'), 'utf8'), sandbox, { filename: 'wire-tools.js' });
vm.runInContext(fs.readFileSync(path.join(root, 'motor-nameplate.js'), 'utf8'), sandbox, { filename: 'motor-nameplate.js' });

const api = sandbox.__motorNameplateTestApi;
assert.ok(api);

const sf125 = api.overloadPercent(1.15, '');
assert.equal(sf125.pct, 125);
assert.equal(sf125.article, 'NEC 430.32(A)(1)');
const rise125 = api.overloadPercent('', 40);
assert.equal(rise125.pct, 125);
const other = api.overloadPercent(1.0, 50);
assert.equal(other.pct, 115);
assert.equal(api.overloadNextHigherPercent(1.15, '').pct, 140);
assert.equal(api.overloadNextHigherPercent(1.0, 80).pct, 130);
assert.equal(api.overloadNextHigherPercent(1.0, 80).article, 'NEC 430.32(C)');

const scpd = api.scpdFromFla(14, 'sc-bde', 'inv');
assert.equal(scpd.pct, 250);
assert.equal(scpd.article, 'NEC Table 430.52');
assert.ok(Math.abs(scpd.raw - 35) < 1e-9);

const fuse = api.scpdFromFla(14, 'sc-bde', 'td');
assert.equal(fuse.pct, 175);

const lra = api.lockedRotorRange('F', 10, 460, 3);
assert.equal(lra.letter, 'F');
assert.equal(lra.kvaMin, 5.0);
assert.equal(lra.kvaMax, 5.59);
assert.match(lra.article, /430\.7\(B\)/);
assert.match(lra.note, /table range/i);
const ampsMin = (5.0 * 10 * 1000) / (Math.sqrt(3) * 460);
assert.ok(Math.abs(lra.ampsMin - ampsMin) < 0.02);

const openEnded = api.lockedRotorRange('V', 10, 460, 3);
assert.equal(openEnded.kvaMin, 22.4);
assert.equal(openEnded.kvaMax, null);
assert.equal(openEnded.ampsMax, null);
assert.ok(Number.isFinite(openEnded.ampsMin));

const junkDevice = api.scpdFromFla(14, 'sc-bde', 'label');
assert.equal(junkDevice.device, 'inv');
assert.equal(junkDevice.pct, 250);

assert.match(api.TABLE_430_52['sc-bde'].label, /other than Design B energy-efficient/i);
assert.match(api.TABLE_430_52['sc-bde'].label, /premium-efficiency/i);
assert.match(api.TABLE_430_52['sc-ee'].label, /Design B energy-efficient/i);
assert.match(api.TABLE_430_52['sc-ee'].label, /premium-efficiency/i);
assert.equal(api.TABLE_430_52['sc-bde'].inst, 800);
assert.equal(api.TABLE_430_52['sc-ee'].inst, 1100);
assert.match(api.TABLE_430_52['sync-pw'].article, /older NEC Table 430\.52/);

const src = fs.readFileSync(path.join(root, 'motor-nameplate.js'), 'utf8');
assert.equal((src.match(/NEC 999/g) || []).length, 0);
assert.match(src, /NEC 430\.32/);
assert.match(src, /NEC Table 430\.52/);
assert.match(src, /NEC 430\.22/);

const analyzed = api.analyze({ fla: 14, hp: 10, volts: 460, phase: 3, sf: 1.15, motorType: 'sc-bde', device: 'inv', code: 'F' });
assert.ok(!analyzed.error);
assert.equal(analyzed.overload.pct, 125);
assert.equal(analyzed.scpd.pct, 250);

assert.equal(api.parsePhase(''), null);
assert.equal(api.parsePhase('2'), null);
assert.equal(api.parsePhase('1'), 1);
assert.equal(api.parsePhase('3'), 3);
assert.match(api.analyze({ fla: 14, hp: 10, volts: 460, sf: 1.15 }).error, /phase/i);
assert.match(api.analyze({ fla: 14, hp: 10, volts: 460, phase: '2', sf: 1.15 }).error, /phase/i);

console.log('Motor nameplate NEC percentage tables passed');
