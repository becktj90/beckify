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
assert.equal(parsed.fields.code, 'G');

assert.equal(api.looksLikeOpenPanelInterior('Lighting 20A ckt 1'), false);
assert.equal(api.looksLikeOpenPanelInterior('live parts behind the dead front near the bus bar'), true);

const vendorDir = path.join(root, 'vendor', 'tesseract');
for (const file of ['tesseract.min.js', 'worker.min.js', 'tesseract-core-simd-lstm.wasm.js', 'eng.traineddata.gz']) {
  assert.ok(fs.existsSync(path.join(vendorDir, file)), 'missing vendor file ' + file);
}

console.log('OCR helper parsers and vendor paths passed');
