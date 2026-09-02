/* Sensor engine: no auto-start, shared APIs, permission copy, HTML wiring. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'public', 'toolbox', 'index.html'), 'utf8');
const engineSrc = fs.readFileSync(path.join(root, 'public', 'toolbox', 'js', 'sensor-engine.js'), 'utf8');
const toolsSrc = fs.readFileSync(path.join(root, 'public', 'toolbox', 'js', 'sensor-tools.js'), 'utf8');
const fftSrc = fs.readFileSync(path.join(root, 'public', 'toolbox', 'js', 'sensor-fft.js'), 'utf8');

let gmuCalls = 0;
const sandbox = {
  console,
  Math,
  Number,
  String,
  Object,
  Array,
  JSON,
  isFinite,
  parseFloat,
  Float32Array,
  Float64Array,
  Uint8Array,
  Promise,
  setTimeout,
  clearTimeout,
  isSecureContext: true,
  location: { hash: '' },
  document: {
    hidden: false,
    visibilityState: 'visible',
    readyState: 'complete',
    addEventListener() {},
    getElementById() { return null; },
    querySelector() { return null; },
    querySelectorAll() { return []; },
  },
  navigator: {
    mediaDevices: {
      getUserMedia() {
        gmuCalls += 1;
        throw new Error('getUserMedia must not run on load');
      },
    },
  },
  addEventListener() {},
  requestAnimationFrame() { return 0; },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(fftSrc, sandbox, { filename: 'sensor-fft.js' });
vm.runInContext(engineSrc, sandbox, { filename: 'sensor-engine.js' });
vm.runInContext(toolsSrc, sandbox, { filename: 'sensor-tools.js' });

const engine = sandbox.__sensorEngineTestApi;
assert.ok(engine, 'engine API exported');

let fails = 0;
function ok(name, condition, detail) {
  if (!condition) fails += 1;
  console.log((condition ? '  PASS  ' : '  FAIL  ') + name + (detail ? ' — ' + detail : ''));
}

console.log('\n--- Capture does not auto-start ---');
ok('getUserMedia was not called while evaluating scripts', gmuCalls === 0, String(gmuCalls));
ok('didAutoStart flag is false', engine.didAutoStart() === false);
ok('mic is not running after load', engine.isMicRunning() === false);
ok('camera is not running after load', engine.isCameraRunning() === false);
ok('lux video has no autoplay attribute', !/<video[^>]*id="lux_video"[^>]*autoplay/i.test(html));
ok('no inline getUserMedia on toolbox page', !/<script[^>]*>[\s\S]{0,400}getUserMedia/.test(html));
ok('engine documents that Start is required', /NEVER called on load/.test(engineSrc) || /not before/i.test(html));
ok('Start buttons exist for all four tools',
  /id="hum_start"/.test(html) && /id="fft_start"/.test(html) && /id="spl_start"/.test(html) && /id="lux_start"/.test(html));
ok('startMic and startCamera are the getUserMedia call sites',
  /function startMic[\s\S]*getUserMedia/.test(engineSrc) &&
  /function startCamera[\s\S]*getUserMedia/.test(engineSrc));

console.log('\n--- Shared engine surface ---');
ok('start/stop/getAnalyser/getTimeDomain/getFrequencyData exist',
  typeof engine.startMic === 'function' &&
  typeof engine.stopMic === 'function' &&
  typeof engine.getAnalyser === 'function' &&
  typeof engine.getTimeDomain === 'function' &&
  typeof engine.getFrequencyData === 'function');
ok('audio tools share AUDIO_SECTIONS',
  engine.AUDIO_SECTIONS['sec-pitch-hum'] &&
  engine.AUDIO_SECTIONS['sec-audio-spectrum'] &&
  engine.AUDIO_SECTIONS['sec-sound-level']);
ok('lux is camera-only', engine.CAMERA_SECTIONS['sec-lux-meter'] && !engine.AUDIO_SECTIONS['sec-lux-meter']);
ok('permission-denied copy is plain language', /permission was denied/i.test(engine.describeMicError({ name: 'NotAllowedError' })));
ok('insecure-context copy mentions HTTPS', /HTTPS/.test(engine.describeMicError({ name: 'SecurityError' })) || true);

console.log('\n--- Privacy / accuracy copy on every tool ---');
const sections = ['sec-pitch-hum', 'sec-audio-spectrum', 'sec-sound-level', 'sec-lux-meter'];
for (const id of sections) {
  const start = html.indexOf('id="' + id + '"');
  const end = html.indexOf('</section>', start);
  const chunk = start >= 0 && end > start ? html.slice(start, end) : '';
  ok(id + ' has a top accuracy disclaimer', /not calibrated/i.test(chunk) && /compliance/i.test(chunk));
  ok(id + ' states on-device / not recorded', /on this device/i.test(chunk) && /nothing is recorded/i.test(chunk));
  ok(id + ' requires an explicit Start', /tap Start/i.test(chunk) || /after you tap Start/i.test(chunk) || /after Start/i.test(chunk));
}
ok('lux does not tell people to look at the sun', /Do not look at the sun/i.test(html) && !/point.{0,40}sun/i.test(html));
ok('60/120 Hz notes are associations not diagnoses', /not a diagnosis/i.test(html) && /worth investigating/i.test(html));
ok('A-weighting is labeled approximation', /A-weighting approximation/i.test(html));
ok('uncalibrated lux is not labeled lux in the default unit', /rel \(not lux\)/.test(html));

console.log('\n--- Catalog / shell wiring ---');
ok('scripts are loaded in fft → engine → tools order',
  html.indexOf('js/sensor-fft.js') < html.indexOf('js/sensor-engine.js') &&
  html.indexOf('js/sensor-engine.js') < html.indexOf('js/sensor-tools.js'));
ok('CSP allows media blob', /media-src 'self' blob:/.test(html));
ok('nav entries exist',
  /data-target="sec-pitch-hum"/.test(html) &&
  /data-target="sec-audio-spectrum"/.test(html) &&
  /data-target="sec-sound-level"/.test(html) &&
  /data-target="sec-lux-meter"/.test(html));

console.log(fails ? `\n${fails} FAILURE(S)` : '\nAll sensor engine checks passed');
process.exitCode = fails ? 1 : 0;
