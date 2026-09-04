/* Shared motor nameplate draft schema + MOCP/LRA traps. */
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
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'nameplate-schema.js'), 'utf8'), sandbox, { filename: 'nameplate-schema.js' });
vm.runInContext(fs.readFileSync(path.join(root, 'ocr-helper.js'), 'utf8'), sandbox, { filename: 'ocr-helper.js' });

const schema = sandbox.__nameplateSchemaTestApi;
const ocr = sandbox.__ocrHelperTestApi;
assert.ok(schema);
assert.ok(ocr);

const names = schema.FIELD_NAMES;
for (const required of [
  'manufacturer', 'model', 'ratedHP', 'ratedKW', 'voltage', 'fla', 'sf', 'rpm',
  'poles', 'frequencyHz', 'phases', 'enclosure', 'frame', 'designLetter',
  'codeLetter', 'nomEff', 'pf', 'mocp', 'lra', 'serviceFactorAmps', 'notes',
]) {
  assert.ok(names.includes(required), 'missing field ' + required);
}

const draft = schema.normalizeDraft({
  manufacturer: { value: 'Baldor', confidence: 0.9 },
  ratedHP: 10,
  voltage: '460',
  fla: 14.5,
  phases: 3,
  mocp: 30,
  lra: 84,
}, { source: 'vlm-test', rawText: 'BALDOR 10 HP 460V FLA 14.5 MOCP 30 LRA 84 3 PH' });

assert.equal(draft.fields.manufacturer.value, 'Baldor');
assert.equal(draft.fields.ratedHP.value, 10);
assert.equal(draft.fields.voltage.value, '460');
assert.equal(draft.fields.fla.value, 14.5);
assert.equal(draft.fields.phases.value, 3);
assert.equal(draft.fields.mocp.value, 30);
assert.equal(draft.fields.lra.value, 84);
assert.equal(draft.fields.fla.userReviewed, false);
assert.ok(draft.fields.fla.confidence > 0);

const mocpAsFla = schema.normalizeDraft({
  fla: 30,
  mocp: 30,
  ratedHP: 10,
}, { rawText: 'MOCP 30 HP 10' });
assert.equal(mocpAsFla.fields.fla.value, null);
assert.equal(mocpAsFla.fields.mocp.value, 30);
assert.ok(mocpAsFla.warnings.some((w) => /MOCP/i.test(w)));

const lraAsFla = schema.normalizeDraft({
  fla: 84,
  lra: 84,
}, { rawText: 'LRA 84' });
assert.equal(lraAsFla.fields.fla.value, null);
assert.equal(lraAsFla.fields.lra.value, 84);

const unlabeledMocp = schema.normalizeDraft({
  fla: 30,
}, { rawText: 'MOCP 30 HP 10' });
assert.equal(unlabeledMocp.fields.fla.value, null);

const dual = schema.fromLegacyParse({ volts: '230/460', fla: '28/14', hp: '10', phase: '' });
assert.equal(dual.fields.voltage.value, '230/460');
assert.equal(dual.fields.fla.value, null);
assert.equal(dual.extras.dualFla, '28/14');
assert.equal(schema.toLegacyFields(dual).fla, '28/14');
assert.equal(schema.toLegacyFields(dual).phase, '');
assert.equal(dual.fields.phases.value, null);

const badPhase = schema.normalizeDraft({ phases: 2, fla: 14 });
assert.equal(badPhase.fields.phases.value, null);

const tess = ocr.parseMotorNameplate('MFG WEG MODEL 123 TEFC 4 POLE MOCP 30 FLA 14.5 HP 10 LRA 84 SFA 16.7 EFF 91.7 PF 0.84');
assert.equal(tess.fields.fla, '14.5');
assert.notEqual(tess.fields.fla, '30');
assert.notEqual(tess.fields.fla, '84');
assert.equal(tess.fields.mocp, '30');
assert.equal(tess.fields.lra, '84');
assert.equal(tess.fields.serviceFactorAmps, '16.7');
assert.equal(tess.fields.enclosure, 'TEFC');
assert.equal(tess.fields.poles, '4');
assert.equal(tess.fields.manufacturer, 'WEG');
assert.equal(tess.fields.model, '123');

const fromTess = ocr.toNameplateDraft('MOCP 30 FLA 14.5 HP 10 VOLTS 460 3 PH', 82);
assert.equal(fromTess.fields.fla.value, 14.5);
assert.equal(fromTess.fields.mocp.value, 30);
assert.equal(fromTess.fields.ratedHP.value, 10);
assert.equal(fromTess.fields.phases.value, 3);
assert.equal(fromTess.fields.fla.userReviewed, false);
assert.equal(fromTess.source, 'tesseract');

const reviewed = schema.markReviewed(fromTess, true);
assert.equal(reviewed.fields.fla.userReviewed, true);
assert.equal(fromTess.fields.fla.userReviewed, false);

const panel = schema.normalizePanelDraft({
  circuits: [
    { circuit: '1', description: 'AHU-1', trip: 20, poles: 2, loadAmps: 20 },
  ],
});
assert.equal(panel.task, 'panel');
assert.equal(panel.rows[0].circuit.value, '1');
assert.equal(panel.rows[0].trip.value, 20);
assert.equal(panel.rows[0].loadAmps.value, 20);
assert.equal(panel.rows[0].circuit.userReviewed, false);

console.log('Nameplate schema + parse traps passed');
