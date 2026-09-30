/* Ratio, phase current, connection choice, enclosure, and color notes.
   Run with: node --test tests/toolbox-xfmr-teach.test.cjs
   or npm test from artifacts/beckify. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..');
const js = path.join(root, 'public', 'toolbox', 'js');
const sandbox = {
  console, Math, Number, String, Object, Array, JSON,
  document: {
    readyState: 'complete',
    getElementById() { return null; },
    addEventListener() {},
  },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(js, 'xfmr-teach.js'), 'utf8'), sandbox, { filename: 'xfmr-teach.js' });
vm.runInContext(fs.readFileSync(path.join(js, 'wire-colors.js'), 'utf8'), sandbox, { filename: 'wire-colors.js' });

const T = sandbox.XFMR_TEACH;
const colors = sandbox.__wireColorsTestApi;
const SQRT3 = Math.sqrt(3);

function close(got, want, tol) {
  assert.ok(Math.abs(got - want) <= (tol == null ? 1e-6 : tol), got + ' vs ' + want);
}

const ip = T.lineCurrent(75, 480, 3);
const isec = T.lineCurrent(75, 208, 3);
close(ip, 75000 / (SQRT3 * 480), 1e-6);
close(isec, 75000 / (SQRT3 * 208), 1e-6);
close(T.lineCurrent(25, 240, 1), 25000 / 240, 1e-9);
close(T.kvaFromCurrent(480, ip, 3), 75, 1e-6);
close(T.turnsRatio(480, 208), 480 / 208, 1e-12);

const exact = T.analyze({
  id: 'delta-wye',
  kva: 75,
  primaryVolts: 480,
  secondaryVolts: 120 * SQRT3,
});
close(exact.primaryLineAmps, ip, 1e-6);
close(exact.secondaryPhaseVolts, 120, 1e-9);
close(exact.windingRatio, 4, 1e-9);
close(exact.primaryPhaseAmps, ip / SQRT3, 1e-6);
close(exact.secondaryPhaseAmps, exact.secondaryLineAmps, 1e-9);

const yy = T.analyze({ id: 'wye-wye', kva: 75, vp: 480, vs: 208 });
close(yy.primaryPhaseAmps, yy.primaryLineAmps, 1e-9);
close(yy.windingRatio, 480 / 208, 1e-9);

const dd = T.analyze({ id: 'delta-delta', kva: 75, vp: 480, vs: 480 });
close(dd.secondaryPhaseAmps, dd.secondaryLineAmps / SQRT3, 1e-9);
close(dd.windingRatio, 1, 1e-12);

const leg = T.analyze({ id: 'highleg', kva: 45, vp: 480, vs: 240 });
close(leg.extra.highLeg.van, 120, 1e-9);
close(leg.extra.highLeg.vbn, 240 * SQRT3 / 2, 1e-9);
assert.equal(leg.id, 'high-leg');
assert.equal(leg.colors.schemeId, '120-240-3ph-highleg');
const orange = leg.colors.leads.filter(function (lead) { return lead.colorName === 'Orange'; });
assert.equal(orange.length, 1);
assert.equal(orange[0].role, 'code');
assert.match(leg.colors.summary, /not the 480Y/);

const corner = T.analyze({ id: 'corner', kva: 75, vp: 480, vs: 480 });
assert.equal(corner.extra.corner.groundedPhaseToGround, 0);
assert.equal(corner.extra.corner.ungroundedPhaseToGround, 480);
assert.equal(corner.colors.leads.some(function (lead) { return lead.colorName === 'Orange'; }), false);
const grounded = corner.colors.leads.find(function (lead) { return lead.name === 'Grounded phase'; });
assert.equal(grounded.role, 'code');
assert.match(grounded.colorName, /White or gray/);
assert.match(corner.colors.summary, /do not mark it green/i);
assert.match(corner.colors.summary, /no high leg/i);
assert.ok(corner.install.extras.some(function (line) { return /not for 277 V/.test(line) && /white or gray/i.test(line); }));

const open = T.analyze({ id: 'open-delta', kva: 100, vp: 480, vs: 480 });
close(open.extra.openDelta.capacityOfClosed, SQRT3 / 3, 1e-12);
close(open.extra.openDelta.unitCurrent, open.secondaryLineAmps, 1e-9);
close(open.extra.openDelta.closedBankKva, 100 / (SQRT3 / 3), 1e-6);

const zig = T.analyze({ id: 'zigzag', kva: 100, vp: 480, vs: 480 });
close(zig.extra.zigzag.neutralAmps, SQRT3 * 100000 / 480, 1e-6);
close(zig.extra.zigzag.phaseAmps, zig.extra.zigzag.neutralAmps / 3, 1e-9);

const auto = T.analyze({ id: 'autotransformer', kva: 10, vp: 480, vs: 240, phases: 1 });
close(auto.extra.auto.coRatio, 0.5, 1e-12);
close(auto.extra.auto.windingKva, 5, 1e-9);
close(auto.extra.auto.iHigh, 10000 / 480, 1e-9);
close(auto.extra.auto.commonAmps, (10000 / 240) - (10000 / 480), 1e-9);

const boost = T.analyze({ id: 'buck-boost', kva: 1, vp: 208, vs: 230, phases: 1 });
close(boost.extra.auto.coRatio, 22 / 230, 1e-12);
close(boost.extra.auto.throughputKva, 230 / 22, 1e-9);
close(boost.extra.auto.windingKva, 1, 1e-12);

const fault3 = T.faultCurrent(500, 480, 5, 3);
close(fault3.baseAmps, 500000 / (SQRT3 * 480), 1e-6);
close(fault3.symmetricalAmps, fault3.baseAmps / 0.05, 1e-6);
const fault1 = T.faultCurrent(25, 240, 4, 1);
close(fault1.baseAmps, 25000 / 240, 1e-9);
close(fault1.symmetricalAmps, fault1.baseAmps / 0.04, 1e-6);
const withZ = T.analyze({ id: 'delta-wye', kva: 500, vp: 12470, vs: 480, percentZ: 5 });
close(withZ.fault.symmetricalAmps, fault3.symmetricalAmps, 1e-4);

assert.equal(T.suggest('legacy-240').connectionId, 'high-leg');
assert.equal(T.suggest('ground-a-delta').connectionId, 'corner-grounded');
assert.notEqual(T.suggest('legacy-240').connectionId, T.suggest('ground-a-delta').connectionId);
assert.equal(T.suggest('isolate', '3ph').connectionId, 'delta-wye');
assert.equal(T.suggest('derive-neutral').connectionId, 'zigzag');
assert.equal(T.suggest('trim-voltage').connectionId, 'buck-boost');
assert.match(T.suggest('limit-fault').why, /resistor/i);

const y480 = T.colorPlan('delta-wye', 480, 12470);
assert.equal(y480.schemeId, '277-480-3ph');
assert.equal(y480.leads.find(function (lead) { return lead.colorName === 'Brown'; }).role, 'convention');
assert.equal(y480.leads.find(function (lead) { return lead.colorName === 'Orange'; }).role, 'convention');
assert.match(y480.summary, /not the high-leg/);
assert.match(y480.twoSystems, /210\.5\(C\)/);
assert.match(y480.disclaimer, /AHJ/);

const catalog480 = colors.NEC_SYSTEMS.find(function (sys) { return sys.id === '277-480-3ph'; });
const catalogOrange = catalog480.rows.find(function (row) { return row.color === 'Orange'; });
assert.equal(catalogOrange.mandate, 'convention');
assert.match(catalogOrange.cite, /not the high-leg/);
const catalogLeg = colors.NEC_SYSTEMS.find(function (sys) { return sys.id === leg.colors.schemeId; });
const catalogHigh = catalogLeg.rows.find(function (row) { return /high-leg/i.test(row.conductor); });
assert.equal(catalogHigh.mandate, 'code');
assert.match(catalogHigh.cite, /110\.15/);

const indoor = T.placement('dry-vent', 'indoor');
assert.equal(indoor.nema, '1');
assert.match(indoor.ip, /IP20/);
const outdoor = T.placement('dry-vent', 'outdoor');
assert.equal(outdoor.nema, '3R');
assert.match(outdoor.note, /indoor/i);
const wet = T.racewayNotes('outdoor', 'delta-wye', 208);
assert.match(wet.insulation, /THWN-2/);
assert.match(wet.raceway, /EMT is a dry-location/);
const dry = T.racewayNotes('indoor', 'high-leg', 240);
assert.match(dry.insulation, /THHN\/THWN-2/);
assert.ok(dry.extras.some(function (line) { return /orange/i.test(line) && /480Y/.test(line); }));

assert.match(T.DISCLAIMER, /Not a PE stamp/);
assert.match(T.kFactorNote('k13'), /Harmonics tool/);
assert.equal(T.connectionById('resistance-ground').computesOhms, false);

const wizard = fs.readFileSync(path.join(js, 'xfmr-wizard.js'), 'utf8');
const html = fs.readFileSync(path.join(root, 'public', 'toolbox', 'index.html'), 'utf8');
const families = fs.readFileSync(path.join(js, 'toolbox-families.js'), 'utf8');
const registry = fs.readFileSync(path.join(root, 'src', 'data', 'toolbox-tools.mjs'), 'utf8');
assert.equal(/High-Leg Delta \(Corner-Grounded\)/.test(wizard), false);
assert.match(wizard, /XFMR_TEACH|teachApi/);
assert.match(html, /id="xw_teach_detail"/);
assert.match(html, /id="xw_phase_note"/);
assert.match(html, /id="xw_env"/);
assert.match(wizard, /Switch phase to 3Ø/);
assert.match(wizard, /lead\.hex/);
assert.match(html, /js\/xfmr-teach\.js/);
assert.match(families, /Teach & size/);
assert.match(registry, /Teach & size/);
assert.equal((registry.match(/slug: "transformer-design"/g) || []).length, 1);
assert.match(fs.readFileSync(path.join(root, 'public', 'toolbox', 'sw.js'), 'utf8'), /CACHE_VERSION = 'v47'/);

console.log('Transformer teach math: ratio, phase current, high-leg vs corner, colors, enclosure');
