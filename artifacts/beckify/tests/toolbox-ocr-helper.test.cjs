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
assert.equal(mocp.fields.mocp, '30');
assert.notEqual(mocp.fields.fla, '30');

const lra = api.parseMotorNameplate('LRA 84 HP 10 VOLTS 460');
assert.equal(lra.fields.hp, '10');
assert.equal(lra.fields.volts, '460');
assert.equal(lra.fields.fla, '');
assert.equal(lra.fields.lra, '84');
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
assert.equal(api.MAX_DIRECTORY_EDGE, 2400);
assert.equal(typeof api.preprocessForOcr, 'function');
assert.equal(typeof api.reconstructDirectoryFromWords, 'function');
assert.ok(api.directoryScore('PANEL BLT 11 SPARE RECEPT POWER POLE 1 2 3 4 5 6 7 8') >= 6);
assert.ok(api.directoryScore('xyz') < 3);

const rebuilt = api.reconstructDirectoryFromWords([
  { text: 'POWER', bbox: { x0: 10, y0: 10, x1: 60, y1: 24 }, confidence: 80 },
  { text: 'POLE', bbox: { x0: 64, y0: 10, x1: 110, y1: 24 }, confidence: 80 },
  { text: '1', bbox: { x0: 200, y0: 10, x1: 214, y1: 24 }, confidence: 90 },
  { text: '2', bbox: { x0: 230, y0: 10, x1: 244, y1: 24 }, confidence: 90 },
  { text: 'POWER', bbox: { x0: 300, y0: 10, x1: 350, y1: 24 }, confidence: 80 },
  { text: 'POLE', bbox: { x0: 354, y0: 10, x1: 400, y1: 24 }, confidence: 80 },
  { text: 'RECP', bbox: { x0: 10, y0: 40, x1: 60, y1: 54 }, confidence: 80 },
  { text: '3', bbox: { x0: 200, y0: 40, x1: 214, y1: 54 }, confidence: 90 },
  { text: '4', bbox: { x0: 230, y0: 40, x1: 244, y1: 54 }, confidence: 90 },
  { text: 'RECP', bbox: { x0: 300, y0: 40, x1: 350, y1: 54 }, confidence: 80 },
]);
assert.ok(rebuilt);
assert.match(rebuilt.text, /1\s+2/);
assert.match(rebuilt.text, /POWER/);

assert.equal(api.looksLikeOpenPanelInterior('Lighting 20A ckt 1'), false);
assert.equal(api.looksLikeOpenPanelInterior('voltage stabilizer on circuit 4'), false);
assert.equal(api.looksLikeOpenPanelInterior('breaker stabs on the bus'), true);
assert.equal(api.looksLikeOpenPanelInterior('live parts behind the dead front near the bus bar'), true);
assert.equal(api.meanWordConfidence(null), 0);
assert.equal(api.meanWordConfidence({}), 0);
assert.equal(api.meanWordConfidence({ confidence: 81, words: [] }), 81);
assert.equal(api.mapOcrProgress({ ratio: 1, directoryMode: true, pass: 1 }), 0.55);
assert.equal(api.mapOcrProgress({ ratio: 0, directoryMode: true, pass: 2 }), 0.62);
assert.ok(api.mapOcrProgress({ ratio: 0.1, directoryMode: true, pass: 2 }) > 0.62);
assert.ok(api.mapOcrProgress({ ratio: 1, directoryMode: true, pass: 2 }) >= 0.99);
assert.ok(api.mapOcrProgress({ ratio: 1, directoryMode: true, pass: 1 })
  < api.mapOcrProgress({ ratio: 0, directoryMode: true, pass: 2 }));

const messyPlate = api.parseMotorNameplate([
  'BALDOR RELIANCE',
  'MODEL 10HP-215',
  'HP 10',
  'VOLTS 230/460',
  'AMPS 25.0/12.5',
  'RPM 1750',
  '3Ø 60 HZ',
  'SF 1.15',
  'TEFC FRAME 215T',
  'PF 82',
  'SER A12345',
  'MOCP 40',
  'LRA 72',
].join('\n'));
assert.equal(messyPlate.fields.hp, '10');
assert.notEqual(messyPlate.fields.hp, '215');
assert.equal(messyPlate.fields.volts, '230/460');
assert.equal(messyPlate.fields.fla, '25.0/12.5');
assert.equal(messyPlate.fields.phase, '3');
assert.equal(messyPlate.fields.pf, '0.82');
assert.equal(messyPlate.fields.serialNumber, 'A12345');
assert.equal(messyPlate.fields.mocp, '40');
assert.equal(messyPlate.fields.lra, '72');
assert.match(String(messyPlate.fields.manufacturer), /BALDOR/i);
assert.equal(api.extractPhase('PH 3'), '3');
assert.equal(api.extractPhase('single phase'), '1');
assert.equal(api.extractPhase('230/460'), '');
assert.ok(api.nameplateScore('10 HP 460V 14 FLA 1750 RPM') >= 3);
assert.ok(api.nameplateScore('random photo') < 3);

const noStealAmp = api.parseMotorNameplate('MOCP 30 LRA 84 HP 10 VOLTS 460');
assert.equal(noStealAmp.fields.fla, '');
assert.equal(noStealAmp.fields.mocp, '30');
assert.equal(noStealAmp.fields.lra, '84');

const unlistedMfr = api.parseMotorNameplate('MFR ACME MODEL ABC123 HP 10 VOLTS 460');
assert.equal(unlistedMfr.fields.manufacturer, 'ACME');
assert.doesNotMatch(String(unlistedMfr.fields.manufacturer), /MODEL|VOLTS|HP 10/i);
assert.equal(unlistedMfr.fields.model, 'ABC123');
assert.equal(unlistedMfr.fields.hp, '10');
assert.equal(unlistedMfr.fields.volts, '460');

const ampsThenLra = api.parseMotorNameplate('HP 10 VOLTS 460 AMPS 12 LRA 84');
assert.equal(ampsThenLra.fields.fla, '12');
assert.equal(ampsThenLra.fields.lra, '84');
assert.notEqual(ampsThenLra.fields.fla, '84');
assert.equal(ampsThenLra.fields.hp, '10');
assert.equal(ampsThenLra.fields.volts, '460');

const vendorDir = path.join(root, 'vendor', 'tesseract');
for (const file of ['tesseract.min.js', 'worker.min.js', 'tesseract-core-simd-lstm.wasm.js', 'eng.traineddata.gz']) {
  assert.ok(fs.existsSync(path.join(vendorDir, file)), 'missing vendor file ' + file);
}

const iecPlate = api.parseMotorNameplate([
  'SIEMENS',
  'TYPE 1LA7090-4AA60',
  '7.5 kW',
  '400/690 V',
  'IN 14.8/8.5 A',
  'n=1450 r/min',
  '50 Hz',
  'cos φ 0.84',
  'IP55',
  'IE3',
  'Cl. F',
  'D/Y',
].join('\n'));
assert.equal(iecPlate.fields.kw, '7.5');
assert.equal(iecPlate.fields.hp, '');
assert.equal(iecPlate.fields.volts, '400/690');
assert.equal(iecPlate.fields.fla, '14.8/8.5');
assert.equal(iecPlate.fields.rpm, '1450');
assert.equal(iecPlate.fields.hz, '50');
assert.equal(iecPlate.fields.pf, '0.84');
assert.equal(iecPlate.fields.enclosure, 'IP55');
assert.equal(iecPlate.fields.insulation, 'F');
assert.equal(iecPlate.fields.ieClass, 'IE3');
assert.equal(iecPlate.fields.connection, 'D/Y');
assert.match(iecPlate.fields.notes, /7\.5 kW/i);
assert.doesNotMatch(iecPlate.fields.notes, /10 HP|convert/i);
assert.equal(iecPlate.iec, true);
assert.ok(api.looksLikeIecPlate('7.5 kW IP55 IE3 400 V'));
assert.equal(api.looksLikeIecPlate('BALDOR 10 HP 460V 14 FLA'), false);

const iecNoHz = api.parseMotorNameplate('7.5 kW IP55 IE3 IN 14.8 400 V n=1450');
assert.equal(iecNoHz.fields.hz, '');
assert.equal(iecNoHz.fields.fla, '14.8');
assert.equal(iecNoHz.fields.rpm, '1450');
assert.notEqual(iecNoHz.fields.hz, '60');

const nemaStill60 = api.parseMotorNameplate('AC MOTOR 10 HP 460V 14 FLA 1750 RPM');
assert.equal(nemaStill60.fields.hz, '60');

const nameplateWords = [
  { text: 'HP', bbox: { x0: 10, y0: 10, x1: 40, y1: 24 }, confidence: 80 },
  { text: '10', bbox: { x0: 44, y0: 10, x1: 70, y1: 24 }, confidence: 80 },
  { text: 'FLA', bbox: { x0: 80, y0: 10, x1: 110, y1: 24 }, confidence: 80 },
  { text: '14', bbox: { x0: 114, y0: 10, x1: 140, y1: 24 }, confidence: 80 },
];
const packedNameplate = api.packOcrResult({
  data: { text: 'HP 10 FLA 14', words: nameplateWords, confidence: 80 },
}, { directoryMode: false });
assert.equal(packedNameplate.text, 'HP 10 FLA 14');
assert.equal(packedNameplate.reconstructed, null);

const pixels = new Uint8ClampedArray(16 * 16 * 4);
for (let y = 0; y < 16; y += 1) {
  for (let x = 0; x < 16; x += 1) {
    const i = (y * 16 + x) * 4;
    const v = (x < 8 ? 40 : 180) + (y % 8) * 4;
    pixels[i] = pixels[i + 1] = pixels[i + 2] = v;
    pixels[i + 3] = 255;
  }
}
api.tileContrastStretch(pixels, 16, 16, 2);
assert.ok(pixels[0] < 20, 'darkest sample in the left tile stretches toward black');
assert.ok(pixels[(7 * 16) * 4] > 230, 'lightest sample in the left tile stretches toward white');
api.unsharpLight(pixels, 16, 16);
assert.ok(Number.isFinite(pixels[0]));

assert.ok(api.nameplateScore('7.5 kW IN 14.8 400 V n=1450 IE3') >= 3);
assert.ok(api.nameplateScore('put the motor in the cabinet') < 3);
assert.ok(api.nameplateScore('IN 14.8') >= 3);
assert.ok(api.nameplateScore('I_N 12.5') >= 3);

console.log('OCR helper parsers and vendor paths passed');
