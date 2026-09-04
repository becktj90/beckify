/* Shared on-device OCR helper parsers. Does not run Tesseract in vm. */
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
  Promise,
  URL: class {
    constructor(file, base) { this.href = String(base || '') + String(file); }
  },
  document: {
    readyState: 'complete',
    addEventListener() {},
    createElement() { return {}; },
    head: { appendChild() {} },
  },
  location: { href: 'https://beckify.com/toolbox/' },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'ocr-helper.js'), 'utf8'), sandbox, { filename: 'ocr-helper.js' });

const api = sandbox.__ocrHelperTestApi;
assert.ok(api);
assert.equal(api.VENDOR, 'js/vendor/tesseract/');
assert.match(fs.readFileSync(path.join(root, 'ocr-helper.js'), 'utf8'), /sha384-GJqSu7vueQ9qN0E9yLPb3Wtpd7OrgK8KmYzC8T1IysG1bcvxvIO4qtYR\/D3A991F/);

const parsed = api.parseMotorNameplate('AC MOTOR 10 HP 460V 14 FLA 1750 RPM 60 Hz 3 PH FRAME 215T SF 1.15 DESIGN B CLASS F CODE G RISE 40 C');
assert.equal(parsed.fields.hp, '10');
assert.equal(parsed.fields.volts, '460');
assert.equal(parsed.fields.fla, '14');
assert.equal(parsed.fields.rpm, '1750');
assert.equal(parsed.fields.hz, '60');
assert.equal(parsed.fields.phase, '3');
assert.equal(parsed.fields.frame, '215T');
assert.equal(parsed.fields.sf, '1.15');
assert.equal(parsed.fields.design, 'B');
assert.equal(parsed.fields.insulation, 'F');
assert.equal(parsed.fields.code, 'G');
assert.equal(parsed.fields.riseC, '40');

const noHz = api.parseMotorNameplate('AC MOTOR 10 HP 460V 14 FLA');
assert.equal(noHz.fields.hz, '60');
assert.equal(noHz.filled, 3);

const mocp = api.parseMotorNameplate('MOCP 30 FLA 14.5 HP 10');
assert.equal(mocp.fields.fla, '14.5');
assert.equal(mocp.fields.hp, '10');
assert.notEqual(mocp.fields.fla, '30');

const lra = api.parseMotorNameplate('LRA 84 HP 10 VOLTS 460');
assert.equal(lra.fields.hp, '10');
assert.equal(lra.fields.volts, '460');
assert.equal(lra.fields.fla, '');
assert.notEqual(lra.fields.fla, '84');

const dual = api.parseMotorNameplate('230/460V 28/14 FLA');
assert.equal(dual.fields.volts, '230/460');
assert.equal(dual.fields.fla, '28/14');

const mca = api.parseMotorNameplate('MCA 40 SCA 65 FLA 12.8 HP 7.5 VOLTS 230');
assert.equal(mca.fields.fla, '12.8');
assert.equal(mca.fields.hp, '7.5');
assert.equal(mca.fields.volts, '230');

assert.equal(api.ACCEPTED_IMAGE_LABEL, 'JPG, PNG, WEBP, HEIC/HEIF, GIF, BMP, or TIFF');
assert.match(fs.readFileSync(path.join(root, 'ocr-helper.js'), 'utf8'), /ACCEPTED_IMAGE_LABEL/);
assert.match(fs.readFileSync(path.join(root, 'ocr-helper.js'), 'utf8'), /HEIC\/HEIF/);
assert.equal(api.isLikelyImageFile({ type: '', name: 'plate.JPG' }), true);
assert.equal(api.isLikelyImageFile({ type: '', name: 'plate.png' }), true);
assert.equal(api.isLikelyImageFile({ type: '', name: 'plate.heic' }), true);
assert.equal(api.isLikelyImageFile({ type: 'application/pdf', name: 'plate.jpg' }), false);
assert.equal(api.isLikelyImageFile({ type: 'image/jpeg', name: 'plate.bin' }), true);

assert.equal(api.isLowConfidence(0, 'FLA 14'), true);
assert.equal(api.isLowConfidence(0, ''), false);
assert.equal(api.isLowConfidence(59, 'FLA 14'), true);
assert.equal(api.isLowConfidence(60, 'FLA 14'), false);
assert.equal(api.MAX_PREPROCESS_EDGE, 1600);
assert.equal(typeof api.preprocessForOcr, 'function');

assert.equal(api.looksLikeOpenPanelInterior('Lighting 20A ckt 1'), false);
assert.equal(api.looksLikeOpenPanelInterior('voltage stabilizer on circuit 4'), false);
assert.equal(api.looksLikeOpenPanelInterior('breaker stabs on the bus'), true);
assert.equal(api.looksLikeOpenPanelInterior('live parts behind the dead front near the bus bar'), true);
assert.equal(api.meanWordConfidence(null), 0);
assert.equal(api.meanWordConfidence({}), 0);
assert.equal(api.meanWordConfidence({ confidence: 81, words: [] }), 81);

const vendorDir = path.join(root, 'vendor', 'tesseract');
for (const file of ['tesseract.min.js', 'worker.min.js', 'tesseract-core-simd-lstm.wasm.js', 'eng.traineddata.gz']) {
  assert.ok(fs.existsSync(path.join(vendorDir, file)), 'missing vendor file ' + file);
}

console.log('OCR helper parsers and vendor paths passed');
