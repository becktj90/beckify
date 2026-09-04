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
assert.match(api.analyze({ fla: '28/14', hp: 10, volts: '230/460', phase: 3, sf: 1.15 }).error, /dual FLA/i);
assert.match(api.lockedRotorRange('F', 10, 460, '').error, /phase/i);

const html = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'index.html'), 'utf8');
const phaseBlock = html.slice(html.indexOf('id="mnp_phase"'), html.indexOf('id="mnp_phase"') + 280);
assert.match(phaseBlock, /<option value="" selected>/);
assert.doesNotMatch(phaseBlock, /<option value="3" selected>/);
assert.match(html, /id="mnp_reviewed"[^>]*data-no-persist/);
assert.match(html, /id="mnp_enhance"[^>]*data-no-persist/);
assert.match(html, /id="mnp_vlm_token"[^>]*data-no-persist/);
assert.match(html, /id="mnp_serial"/);
assert.match(html, /id="mnp_parse"/);
assert.match(html, /id="mnp_progress"/);
assert.match(html, /id="mnp_source"/);
assert.match(html, /id="mnp_dual"/);
assert.match(src, /Fill the fields manually/);
assert.match(src, /applyTesseractResult/);
assert.match(src, /Previous draft fields were cleared/);
assert.match(src, /ocr-low-conf/);
assert.match(src, /Falling back to on-device OCR/);
assert.match(src, /OCR failed\. Fill the fields manually/);
assert.match(src, /el\('mnp_phase'\)\.value = ''/);
assert.equal((src.match(/mnp_phase'\)\.value = '3'/g) || []).length, 0);

const afterAi = api.nextSourceAfterEditedParse('vlm');
assert.equal(afterAi.kind, 'edited-ai');
assert.match(api.sourceMessage(afterAi.kind, afterAi.extra), /edited AI transcript/i);
assert.doesNotMatch(api.sourceMessage(afterAi.kind, afterAi.extra), /photo stayed on this device/i);
const afterTess = api.nextSourceAfterEditedParse('tesseract');
assert.equal(afterTess.kind, 'tesseract');
assert.match(api.sourceMessage(afterTess.kind, afterTess.extra), /Parsed from edited text/i);
assert.match(api.sourceMessage('tesseract'), /photo stayed on this device/i);
assert.match(src, /keepAiSource/);

vm.runInContext(fs.readFileSync(path.join(root, 'ocr-helper.js'), 'utf8'), sandbox, { filename: 'ocr-helper.js' });
const ocr = sandbox.__ocrHelperTestApi;
const mocp = ocr.parseMotorNameplate('MOCP 30 FLA 14.5 HP 10');
assert.equal(mocp.fields.fla, '14.5');
assert.notEqual(mocp.fields.fla, '30');
const lraPlate = ocr.parseMotorNameplate('LRA 84 HP 10 VOLTS 460');
assert.equal(lraPlate.fields.fla, '');
assert.equal(lraPlate.fields.volts, '460');
const dualPlate = ocr.parseMotorNameplate('230/460V 28/14 FLA');
assert.equal(dualPlate.fields.volts, '230/460');
assert.equal(dualPlate.fields.fla, '28/14');

console.log('Motor nameplate NEC percentage tables passed');
