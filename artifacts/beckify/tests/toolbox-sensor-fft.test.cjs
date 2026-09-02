/* Shared sensor DSP: Hann FFT bins, autocorrelation pitch, RMS/dBFS,
   A-weighting approximation, lux relative vs calibrated. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function load() {
  const sandbox = { console, Math, Number, String, Object, Array, JSON, isFinite, parseFloat, Float64Array, Float32Array, Uint8Array };
  sandbox.window = sandbox;
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  vm.runInContext(
    fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'js', 'sensor-fft.js'), 'utf8'),
    sandbox,
    { filename: 'sensor-fft.js' }
  );
  assert.ok(sandbox.__sensorFftTestApi, 'FFT API exported');
  return sandbox.__sensorFftTestApi;
}

function sine(n, freq, sampleRate, amp) {
  amp = amp == null ? 1 : amp;
  const x = new Float64Array(n);
  for (let i = 0; i < n; i++) x[i] = amp * Math.sin(2 * Math.PI * freq * i / sampleRate);
  return x;
}

const api = load();
let fails = 0;
function ok(name, condition, detail) {
  if (!condition) fails += 1;
  console.log((condition ? '  PASS  ' : '  FAIL  ') + name + (detail ? ' — ' + detail : ''));
}

console.log('\n--- FFT bin math (Hann, N=2048) ---');
{
  ok('window name is hann', api.WINDOW === 'hann');
  ok('default FFT size is 2048', api.DEFAULT_FFT_SIZE === 2048);
  const sr = 44100;
  const n = 2048;
  const freq = 440;
  const spec = api.analyzeSpectrum(sine(n, freq, sr), sr, { fftSize: n });
  const expectedBin = Math.round(freq * n / sr);
  ok('bin Hz = sampleRate / N', Math.abs(spec.binHz - sr / n) < 1e-9, String(spec.binHz));
  ok('peak bin near 440 Hz', Math.abs(spec.peakBin - expectedBin) <= 1,
    'got bin ' + spec.peakBin + ' want ~' + expectedBin + ' (' + spec.peakHz.toFixed(2) + ' Hz)');
  ok('peak Hz within one bin of 440', Math.abs(spec.peakHz - freq) <= spec.binHz * 1.01,
    spec.peakHz.toFixed(2) + ' Hz');
  const low = api.analyzeSpectrum(sine(n, 1000, sr), sr, { fftSize: n });
  ok('1 kHz lands near bin 46', Math.abs(low.peakBin - Math.round(1000 * n / sr)) <= 1,
    'bin ' + low.peakBin);
}

console.log('\n--- Autocorrelation pitch on a synthetic 60 Hz tone ---');
{
  const sr = 48000;
  const n = 8192;
  const p = api.autocorrelationPitch(sine(n, 60, sr), sr, { minHz: 40, maxHz: 400 });
  ok('60 Hz tone → ~60 Hz', Math.abs(p.hz - 60) < 0.5, p.hz.toFixed(3) + ' Hz, conf ' + p.confidence.toFixed(3));
  ok('confidence is high on a clean sine', p.confidence > 0.6, String(p.confidence));
  const p50 = api.autocorrelationPitch(sine(n, 50, sr), sr, { minHz: 40, maxHz: 400 });
  ok('50 Hz tone → ~50 Hz', Math.abs(p50.hz - 50) < 0.5, p50.hz.toFixed(3) + ' Hz');
  const p120 = api.autocorrelationPitch(sine(n, 120, sr), sr, { minHz: 40, maxHz: 400 });
  ok('120 Hz tone → ~120 Hz (not 60)', Math.abs(p120.hz - 120) < 1.0, p120.hz.toFixed(3) + ' Hz');
}

console.log('\n--- RMS / dBFS ---');
{
  const n = 4096;
  const x = sine(n, 1000, 48000, 1);
  const r = api.rms(x);
  const d = api.dbfs(x);
  ok('sine amplitude 1 → RMS ~ 1/√2', Math.abs(r - Math.SQRT1_2) < 0.002, r.toFixed(5));
  ok('sine amplitude 1 → dBFS ~ −3.01', Math.abs(d - (-20 * Math.log10(Math.sqrt(2)))) < 0.05, d.toFixed(4));
  const quiet = sine(n, 1000, 48000, 0.1);
  ok('−20 dBFS at amplitude 0.1', Math.abs(api.dbfs(quiet) - (-20 - 20 * Math.log10(Math.sqrt(2)))) < 0.05,
    api.dbfs(quiet).toFixed(3));
  const z = new Float64Array(n);
  ok('silence is −Infinity dBFS', api.dbfs(z) === -Infinity);
}

console.log('\n--- A-weighting approximation (IEC 61672 shape) ---');
{
  ok('1 kHz is 0 dB by definition', Math.abs(api.aWeightDb(1000)) < 0.05, api.aWeightDb(1000).toFixed(3));
  ok('100 Hz ≈ −19.1 dB', Math.abs(api.aWeightDb(100) - (-19.1)) < 0.4, api.aWeightDb(100).toFixed(2));
  ok('20 Hz ≈ −50.5 dB', Math.abs(api.aWeightDb(20) - (-50.5)) < 0.6, api.aWeightDb(20).toFixed(2));
  ok('10 kHz ≈ −2.5 dB', Math.abs(api.aWeightDb(10000) - (-2.5)) < 0.5, api.aWeightDb(10000).toFixed(2));
  const sr = 48000;
  const n = 8192;
  const corr1k = api.aWeightCorrectionDb(sine(n, 1000, sr), sr, { fftSize: 2048 });
  const corr100 = api.aWeightCorrectionDb(sine(n, 100, sr), sr, { fftSize: 2048 });
  ok('1 kHz tone A-correction ~ 0 dB', Math.abs(corr1k) < 1.5, corr1k.toFixed(2) + ' dB');
  ok('100 Hz tone A-correction is negative and near −19 dB', corr100 < -10 && corr100 > -28,
    corr100.toFixed(2) + ' dB');
}

console.log('\n--- Lux relative vs calibrated ---');
{
  const rel = api.applyLuxCalibration(12.5, null);
  ok('uncalibrated unit is rel, not lx', rel.unit === 'rel' && rel.calibrated === false, rel.unit);
  ok('uncalibrated value stays relative', Math.abs(rel.value - 12.5) < 1e-9);
  const cal = api.applyLuxCalibration(12.5, 32);
  ok('calibrated value = relative × scale', Math.abs(cal.value - 400) < 1e-9, String(cal.value));
  ok('calibrated unit is lx', cal.unit === 'lx' && cal.calibrated === true);
  const zero = api.applyLuxCalibration(10, 0);
  ok('scale 0 stays relative (never fake lux)', zero.calibrated === false && zero.unit === 'rel');
}

console.log('\n--- SPL calibration units ---');
{
  const raw = api.applySplCalibration(-20, null, false);
  ok('uncalibrated unweighted is dBFS', raw.unit === 'dBFS' && raw.calibrated === false);
  const aRel = api.applySplCalibration(-20, null, true);
  ok('uncalibrated A-weight stays relative, not dB(A)', /rel/.test(aRel.unit) && !aRel.calibrated);
  const cal = api.applySplCalibration(-20, 90, true);
  ok('calibrated + A-weight is still labeled approximation', /approx/.test(cal.unit) && cal.calibrated);
  ok('offset applies', Math.abs(cal.value - 70) < 1e-9, String(cal.value));
}

console.log('\n--- Center-weighted luminance ---');
{
  const w = 20, h = 20;
  const data = new Uint8Array(w * h * 4);
  for (let i = 0; i < data.length; i += 4) {
    data[i] = 0; data[i + 1] = 0; data[i + 2] = 0; data[i + 3] = 255;
  }
  /* Bright center pixel vs dark frame: center-weighted must exceed a full-frame mean. */
  const cx = 10, cy = 10;
  const i = (cy * w + cx) * 4;
  data[i] = data[i + 1] = data[i + 2] = 255;
  const y = api.centerWeightedLuminance(data, w, h);
  ok('center-weighted reading is > 0 on a bright center', y > 0, String(y));
}

console.log(fails ? `\n${fails} FAILURE(S)` : '\nAll sensor FFT checks passed');
process.exitCode = fails ? 1 : 0;
