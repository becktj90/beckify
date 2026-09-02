/* ============================================================================
   PHONE-SENSOR FIELD TOOLS — pitch, FFT spectrum, sound level, lux
   ============================================================================
   Uses BeckifySensors (shared mic/camera + lifecycle) and BeckifySensorFft
   (Hann FFT, autocorrelation pitch, RMS/dBFS, A-weighting, lux math).

   None of these start listening or open a camera on page load. Start is a
   tap. Navigating away or hiding the tab stops the sensors.

   Exports contain only computed numeric readings (or a spectrum PNG/CSV of
   bins) — never raw audio or raw video frames.
   ============================================================================ */

(function (global) {
  'use strict';

  var fft = global.BeckifySensorFft;
  var sensors = global.BeckifySensors;
  if (!fft || !sensors) return;

  var LUX_SCALE_KEY = 'beckify-lux-scale';
  var SPL_OFFSET_KEY = 'beckify-spl-offset-db';
  var AUDIO_SECTIONS = ['sec-pitch-hum', 'sec-audio-spectrum', 'sec-sound-level'];

  var rafId = 0;
  var activeTool = '';
  var pitchHold = false;
  var heldHz = 0;
  var specAvg = null;
  var specPeak = null;
  var specLast = null;
  var specSampleRate = 48000;
  var specFftSize = fft.DEFAULT_FFT_SIZE;

  var splPeak = -Infinity;
  var splMsSum = 0;
  var splMsCount = 0;
  var splWindowStart = 0;

  var luxMin = Infinity;
  var luxMax = -Infinity;
  var luxSum = 0;
  var luxCount = 0;
  var luxSmooth = 0;
  var luxFlicker = [];
  var luxLastTs = 0;
  var luxVideo = null;
  var luxCanvas = null;
  var luxCtx = null;
  var luxPreviewRaf = 0;

  var pitchLogs = [];
  var splLogs = [];
  var luxLogs = [];

  var HUM_TABLE = [
    { hz: 50, note: 'Strong 50 Hz is consistent with mains-frequency hum in 50 Hz regions (often grounding or induction). Worth investigating — not a diagnosis.' },
    { hz: 60, note: 'Strong 60 Hz is consistent with mains-frequency hum (often grounding or induction). Worth investigating — not a diagnosis.' },
    { hz: 100, note: 'Around 100 Hz is consistent with full-wave-rectified ripple on 50 Hz mains (2×). Worth investigating — not a diagnosis.' },
    { hz: 120, note: 'Around 120 Hz is consistent with full-wave-rectified ripple on 60 Hz mains (2×). Worth investigating — not a diagnosis.' },
    { hz: 150, note: 'Around 150 Hz is a 3rd harmonic of 50 Hz — transformer magnetostriction or mechanical buzz is a common association. Worth investigating — not a diagnosis.' },
    { hz: 180, note: 'Around 180 Hz is a 3rd harmonic of 60 Hz — transformer magnetostriction or mechanical buzz is a common association. Worth investigating — not a diagnosis.' },
    { hz: 300, note: 'Around 300 Hz can associate with 6-pulse rectifier harmonics on 50 Hz systems. Worth investigating — not a diagnosis.' },
    { hz: 360, note: 'Around 360 Hz can associate with 6-pulse rectifier harmonics on 60 Hz systems. Worth investigating — not a diagnosis.' }
  ];

  function $(id) { return document.getElementById(id); }

  function loadNumber(key) {
    try {
      var v = parseFloat(localStorage.getItem(key) || '');
      return isFinite(v) ? v : null;
    } catch (_) { return null; }
  }

  function saveNumber(key, value) {
    try {
      if (value == null || !isFinite(value)) localStorage.removeItem(key);
      else localStorage.setItem(key, String(value));
    } catch (_) {}
  }

  function fmtHz(hz) {
    if (!isFinite(hz) || hz <= 0) return '—';
    if (hz >= 100) return hz.toFixed(1) + ' Hz';
    return hz.toFixed(2) + ' Hz';
  }

  function fmtDb(v) {
    if (!isFinite(v)) return '—';
    return v.toFixed(1);
  }

  function fmtLux(reading) {
    if (!reading) return '—';
    if (!isFinite(reading.value)) return '—';
    if (reading.calibrated) {
      if (reading.value >= 100) return reading.value.toFixed(0);
      if (reading.value >= 10) return reading.value.toFixed(1);
      return reading.value.toFixed(2);
    }
    return reading.value.toFixed(1);
  }

  function nowIso() {
    try { return new Date().toISOString(); } catch (_) { return ''; }
  }

  function downloadText(filename, text, mime) {
    var blob = new Blob([text], { type: mime || 'text/csv;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.rel = 'noopener';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(url); }, 500);
  }

  function csvEscape(s) {
    s = String(s == null ? '' : s);
    if (/[",\n]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
    return s;
  }

  function renderLogTable(host, rows, unit) {
    if (!host) return;
    if (!rows.length) {
      host.innerHTML = '<p class="note">No logged readings yet. Numeric rows only — never raw audio or frames.</p>';
      return;
    }
    var html = '<div class="ref-table-wrap"><table class="ref-table"><thead><tr><th>Position / note</th><th>Timestamp</th><th>Reading</th><th>Unit</th></tr></thead><tbody>';
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      html += '<tr><td>' + escapeHtml(r.note) + '</td><td>' + escapeHtml(r.ts) + '</td><td>' +
        escapeHtml(r.reading) + '</td><td>' + escapeHtml(r.unit || unit || '') + '</td></tr>';
    }
    html += '</tbody></table></div>';
    host.innerHTML = html;
  }

  function escapeHtml(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function humNote(hz) {
    if (!isFinite(hz) || hz <= 0) {
      return 'No stable fundamental yet. Hold the phone near the source (not in the air stream of a fan) and wait a second.';
    }
    var best = HUM_TABLE[0];
    var bestD = Math.abs(hz - best.hz);
    for (var i = 1; i < HUM_TABLE.length; i++) {
      var d = Math.abs(hz - HUM_TABLE[i].hz);
      if (d < bestD) { bestD = d; best = HUM_TABLE[i]; }
    }
    var tol = Math.max(2.5, best.hz * 0.04);
    if (bestD <= tol) return best.note;
    return 'Dominant frequency about ' + fmtHz(hz) + '. Compare with the table — this is an association, not a confirmed cause.';
  }

  /* ── Pitch ──────────────────────────────────────────────────────────── */

  function tickPitch() {
    var out = $('hum_hz');
    var confEl = $('hum_conf');
    var noteEl = $('hum_note');
    var specEl = $('hum_spec');
    if (!sensors.isMicRunning()) return;
    var buf = sensors.getPitchBuffer(new Float32Array(4096));
    var sr = (sensors.getSampleRate && sensors.getSampleRate()) || 48000;
    var pitch = fft.autocorrelationPitch(buf, sr, { minHz: 40, maxHz: 500 });
    var hz = pitchHold && heldHz > 0 ? heldHz : pitch.hz;
    if (!pitchHold) heldHz = pitch.hz;
    if (out) out.textContent = fmtHz(hz);
    if (confEl) confEl.textContent = pitch.confidence > 0
      ? ('ACF peak ' + (pitch.confidence * 100).toFixed(0) + '% · autocorrelation fundamental, not FFT-peak')
      : 'Waiting for a stable tone';
    if (noteEl) noteEl.textContent = humNote(hz);
    if (specEl) {
      var spec = fft.analyzeSpectrum(buf, sr, { fftSize: 2048 });
      specEl.textContent = 'Spectrum helper (Hann, N=' + spec.fftSize + ', bin ' + spec.binHz.toFixed(2) +
        ' Hz): FFT peak ' + fmtHz(spec.peakHz) + ' — use autocorrelation above for the hum fundamental.';
    }
  }

  function bindPitch() {
    var start = $('hum_start');
    var stop = $('hum_stop');
    var hold = $('hum_hold');
    var status = $('hum_status');
    sensors.bindGate({
      startBtn: start,
      stopBtn: stop,
      statusEl: status,
      toolId: 'sec-pitch-hum',
      kind: 'mic',
      onStart: function () {
        activeTool = 'sec-pitch-hum';
        pitchHold = false;
        if (hold) {
          hold.setAttribute('aria-pressed', 'false');
          hold.classList.remove('is-on');
        }
        kickLoop();
      },
      onStop: function () {
        if (activeTool === 'sec-pitch-hum') activeTool = '';
      }
    });
    if (hold) {
      hold.addEventListener('click', function () {
        pitchHold = !pitchHold;
        hold.setAttribute('aria-pressed', pitchHold ? 'true' : 'false');
        hold.classList.toggle('is-on', pitchHold);
        if (pitchHold) heldHz = heldHz || 0;
      });
    }
  }

  /* ── Spectrum ───────────────────────────────────────────────────────── */

  function specSmoothing() {
    var el = $('fft_smooth');
    var v = el ? parseFloat(el.value) : 0.6;
    if (!isFinite(v)) v = 0.6;
    return Math.min(0.95, Math.max(0, v));
  }

  function specLogAxis() {
    var el = $('fft_axis');
    return el ? el.value === 'log' : false;
  }

  function drawSpectrum(canvas, mag, peak, sr, n, logAxis) {
    if (!canvas) return;
    var ctx = canvas.getContext('2d');
    if (!ctx) return;
    var cssW = canvas.clientWidth || 640;
    var cssH = canvas.clientHeight || 220;
    var dpr = global.devicePixelRatio || 1;
    if (canvas.width !== Math.floor(cssW * dpr) || canvas.height !== Math.floor(cssH * dpr)) {
      canvas.width = Math.floor(cssW * dpr);
      canvas.height = Math.floor(cssH * dpr);
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    var w = cssW;
    var h = cssH;
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = 'rgba(13,17,23,0.95)';
    ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = 'rgba(255,255,255,0.08)';
    ctx.lineWidth = 1;
    var g;
    for (g = 1; g < 4; g++) {
      var y = (h * g) / 4;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }
    var bins = mag.length;
    var nyquist = sr / 2;
    var minF = 20;
    function xOf(k) {
      var f = k * (sr / n);
      if (!logAxis) return (k / (bins - 1)) * w;
      if (f <= minF) return 0;
      return (Math.log(f / minF) / Math.log(nyquist / minF)) * w;
    }
    var maxMag = 1e-9;
    var k;
    for (k = 1; k < bins; k++) if (mag[k] > maxMag) maxMag = mag[k];
    if (peak) {
      for (k = 1; k < peak.length; k++) if (peak[k] > maxMag) maxMag = peak[k];
    }
    if (peak) {
      ctx.beginPath();
      ctx.strokeStyle = 'rgba(245,196,81,0.85)';
      ctx.lineWidth = 1.25;
      var started = false;
      for (k = 1; k < bins; k++) {
        var x = xOf(k);
        var yb = h - (peak[k] / maxMag) * (h - 8) - 4;
        if (!started) { ctx.moveTo(x, yb); started = true; }
        else ctx.lineTo(x, yb);
      }
      ctx.stroke();
    }
    ctx.beginPath();
    ctx.strokeStyle = '#8b7bff';
    ctx.lineWidth = 1.75;
    var started2 = false;
    for (k = 1; k < bins; k++) {
      var x2 = xOf(k);
      var y2 = h - (mag[k] / maxMag) * (h - 8) - 4;
      if (!started2) { ctx.moveTo(x2, y2); started2 = true; }
      else ctx.lineTo(x2, y2);
    }
    ctx.stroke();
    ctx.fillStyle = '#9497b8';
    ctx.font = '11px "JetBrains Mono", monospace';
    var ticks = logAxis ? [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000] : [0, 2000, 4000, 8000, 12000, 16000, 20000];
    for (var t = 0; t < ticks.length; t++) {
      var f = ticks[t];
      if (f > nyquist) continue;
      var xt = logAxis
        ? (f <= minF ? 0 : (Math.log(f / minF) / Math.log(nyquist / minF)) * w)
        : (f / nyquist) * w;
      var label = f >= 1000 ? (f / 1000) + 'k' : String(f);
      ctx.fillText(label, Math.min(w - 24, Math.max(2, xt - 8)), h - 4);
    }
  }

  function tickSpectrum() {
    if (!sensors.isMicRunning()) return;
    var buf = sensors.getTimeDomain();
    var sr = (sensors.getSampleRate && sensors.getSampleRate()) || 48000;
    specSampleRate = sr;
    var spec = fft.analyzeSpectrum(buf, sr, { fftSize: specFftSize });
    var mag = spec.magnitudes;
    var s = specSmoothing();
    if (!specAvg || specAvg.length !== mag.length) {
      specAvg = new Float64Array(mag.length);
      specPeak = new Float64Array(mag.length);
      specAvg.set(mag);
      specPeak.set(mag);
    } else {
      for (var k = 0; k < mag.length; k++) {
        specAvg[k] = specAvg[k] * s + mag[k] * (1 - s);
        specPeak[k] = Math.max(specPeak[k] * 0.996, specAvg[k]);
      }
    }
    specLast = spec;
    var canvas = $('fft_canvas');
    var hold = $('fft_peakhold');
    var showPeak = !hold || hold.checked;
    drawSpectrum(canvas, specAvg, showPeak ? specPeak : null, sr, spec.fftSize, specLogAxis());
    var read = $('fft_readout');
    if (read) {
      read.textContent = 'Peak ' + fmtHz(spec.peakHz) + ' · Hann · N=' + spec.fftSize +
        ' · bin ' + spec.binHz.toFixed(2) + ' Hz';
    }
  }

  function exportSpectrumCsv() {
    var spec = specLast;
    if (!spec) return;
    var mag = specAvg || spec.magnitudes;
    var lines = ['bin,hz,magnitude'];
    for (var k = 0; k < mag.length; k++) {
      lines.push(k + ',' + (k * spec.binHz).toFixed(4) + ',' + mag[k].toExponential(6));
    }
    downloadText('beckify-spectrum.csv', lines.join('\n'), 'text/csv;charset=utf-8');
  }

  function exportSpectrumPng() {
    var canvas = $('fft_canvas');
    if (!canvas || !canvas.toBlob) {
      if (canvas && canvas.toDataURL) {
        var a = document.createElement('a');
        a.href = canvas.toDataURL('image/png');
        a.download = 'beckify-spectrum.png';
        a.click();
      }
      return;
    }
    canvas.toBlob(function (blob) {
      if (!blob) return;
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url;
      a.download = 'beckify-spectrum.png';
      a.click();
      setTimeout(function () { URL.revokeObjectURL(url); }, 500);
    }, 'image/png');
  }

  function bindSpectrum() {
    sensors.bindGate({
      startBtn: $('fft_start'),
      stopBtn: $('fft_stop'),
      statusEl: $('fft_status'),
      toolId: 'sec-audio-spectrum',
      kind: 'mic',
      onStart: function () {
        activeTool = 'sec-audio-spectrum';
        specAvg = null;
        specPeak = null;
        kickLoop();
      },
      onStop: function () {
        if (activeTool === 'sec-audio-spectrum') activeTool = '';
      }
    });
    var csv = $('fft_csv');
    var png = $('fft_png');
    if (csv) csv.addEventListener('click', exportSpectrumCsv);
    if (png) png.addEventListener('click', exportSpectrumPng);
    var reset = $('fft_reset_peak');
    if (reset) reset.addEventListener('click', function () { specPeak = null; });
  }

  /* ── Sound level ────────────────────────────────────────────────────── */

  function splOffset() { return loadNumber(SPL_OFFSET_KEY); }

  function tickSpl() {
    if (!sensors.isMicRunning()) return;
    var buf = sensors.getTimeDomain();
    var sr = (sensors.getSampleRate && sensors.getSampleRate()) || 48000;
    var unweighted = fft.dbfs(buf);
    var aOn = $('spl_aweight') && $('spl_aweight').checked;
    var corr = aOn ? fft.aWeightCorrectionDb(buf, sr, { fftSize: 2048 }) : 0;
    var dbfsVal = unweighted + corr;
    var reading = fft.applySplCalibration(dbfsVal, splOffset(), aOn);
    if (isFinite(reading.value) && reading.value > splPeak) splPeak = reading.value;

    var ms = Math.pow(10, (isFinite(dbfsVal) ? dbfsVal : -120) / 10);
    var now = Date.now();
    var intervalMs = parseFloat(($('spl_leq_s') && $('spl_leq_s').value) || '10') * 1000;
    if (!isFinite(intervalMs) || intervalMs < 500) intervalMs = 10000;
    if (!splWindowStart) splWindowStart = now;
    if (now - splWindowStart > intervalMs) {
      splMsSum = 0;
      splMsCount = 0;
      splWindowStart = now;
    }
    splMsSum += ms;
    splMsCount += 1;
    var leqDbfs = splMsCount ? 10 * Math.log10(splMsSum / splMsCount) : dbfsVal;
    var leq = fft.applySplCalibration(leqDbfs, splOffset(), aOn);

    var inst = $('spl_inst');
    var peak = $('spl_peak');
    var leqEl = $('spl_leq');
    var unitEl = $('spl_unit');
    if (inst) inst.textContent = fmtDb(reading.value);
    if (peak) peak.textContent = fmtDb(splPeak);
    if (leqEl) leqEl.textContent = fmtDb(leq.value);
    if (unitEl) unitEl.textContent = reading.unit;
    var bar = $('spl_bar_fill');
    if (bar) {
      var pct = isFinite(reading.value) ? Math.min(100, Math.max(0, (reading.value + 80) * 1.1)) : 0;
      bar.style.width = pct + '%';
    }
  }

  function bindSpl() {
    sensors.bindGate({
      startBtn: $('spl_start'),
      stopBtn: $('spl_stop'),
      statusEl: $('spl_status'),
      toolId: 'sec-sound-level',
      kind: 'mic',
      onStart: function () {
        activeTool = 'sec-sound-level';
        splPeak = -Infinity;
        splMsSum = 0;
        splMsCount = 0;
        splWindowStart = 0;
        kickLoop();
      },
      onStop: function () {
        if (activeTool === 'sec-sound-level') activeTool = '';
      }
    });
    var calBtn = $('spl_calibrate');
    if (calBtn) {
      calBtn.addEventListener('click', function () {
        var known = parseFloat(($('spl_known') && $('spl_known').value) || '');
        if (!isFinite(known)) return;
        var buf = sensors.isMicRunning() ? sensors.getTimeDomain() : null;
        if (!buf) return;
        var sr = (sensors.getSampleRate && sensors.getSampleRate()) || 48000;
        var aOn = $('spl_aweight') && $('spl_aweight').checked;
        var dbfsVal = fft.dbfs(buf) + (aOn ? fft.aWeightCorrectionDb(buf, sr, { fftSize: 2048 }) : 0);
        if (!isFinite(dbfsVal)) return;
        saveNumber(SPL_OFFSET_KEY, known - dbfsVal);
        var hint = $('spl_cal_hint');
        if (hint) hint.textContent = 'Saved a device offset of ' + (known - dbfsVal).toFixed(1) +
          ' dB in localStorage. Still a phone mic — not a calibrated meter.';
      });
    }
    var clearCal = $('spl_clear_cal');
    if (clearCal) {
      clearCal.addEventListener('click', function () {
        saveNumber(SPL_OFFSET_KEY, null);
        var hint = $('spl_cal_hint');
        if (hint) hint.textContent = 'Calibration cleared. Showing relative dBFS, not dB(A).';
      });
    }
    var logBtn = $('spl_log');
    if (logBtn) {
      logBtn.addEventListener('click', function () {
        var inst = $('spl_inst');
        var unit = $('spl_unit');
        splLogs.push({
          note: ($('spl_note') && $('spl_note').value) || '',
          ts: nowIso(),
          reading: inst ? inst.textContent : '',
          unit: unit ? unit.textContent : 'dBFS'
        });
        renderLogTable($('spl_log_host'), splLogs);
      });
    }
    var csv = $('spl_csv');
    if (csv) {
      csv.addEventListener('click', function () {
        var lines = ['position,timestamp,reading,unit'];
        for (var i = 0; i < splLogs.length; i++) {
          var r = splLogs[i];
          lines.push([csvEscape(r.note), csvEscape(r.ts), csvEscape(r.reading), csvEscape(r.unit)].join(','));
        }
        downloadText('beckify-sound-level.csv', lines.join('\n'));
      });
    }
    var reset = $('spl_reset');
    if (reset) {
      reset.addEventListener('click', function () {
        splPeak = -Infinity;
        splMsSum = 0;
        splMsCount = 0;
        splWindowStart = 0;
      });
    }
  }

  /* ── Lux ────────────────────────────────────────────────────────────── */

  function luxScale() { return loadNumber(LUX_SCALE_KEY); }

  function sampleLuxFrame() {
    if (!luxVideo || !luxCanvas || !luxCtx) return null;
    var vw = luxVideo.videoWidth;
    var vh = luxVideo.videoHeight;
    if (!vw || !vh) return null;
    var dw = 160;
    var dh = Math.max(1, Math.round(160 * vh / vw));
    if (luxCanvas.width !== dw) luxCanvas.width = dw;
    if (luxCanvas.height !== dh) luxCanvas.height = dh;
    luxCtx.drawImage(luxVideo, 0, 0, dw, dh);
    var img = luxCtx.getImageData(0, 0, dw, dh);
    return fft.centerWeightedLuminance(img.data, dw, dh);
  }

  function tickLux() {
    if (!sensors.isCameraRunning()) return;
    var rel = sampleLuxFrame();
    if (rel == null) return;
    var now = (global.performance && performance.now) ? performance.now() : Date.now();
    var dt = luxLastTs ? (now - luxLastTs) : 16;
    luxLastTs = now;
    /* Smooth over ≥ 1/60 s so LED PWM is not a single flickering instant. */
    var tau = 1000 / 30;
    var a = 1 - Math.exp(-Math.max(8, dt) / tau);
    luxSmooth = luxSmooth ? luxSmooth + (rel - luxSmooth) * Math.min(1, a) : rel;
    var reading = fft.applyLuxCalibration(luxSmooth, luxScale());
    if (reading.value < luxMin) luxMin = reading.value;
    if (reading.value > luxMax) luxMax = reading.value;
    luxSum += reading.value;
    luxCount += 1;

    luxFlicker.push(rel);
    if (luxFlicker.length > 256) luxFlicker.shift();

    var inst = $('lux_inst');
    var unit = $('lux_unit');
    var mn = $('lux_min');
    var mx = $('lux_max');
    var av = $('lux_avg');
    var mode = $('lux_mode');
    if (inst) inst.textContent = fmtLux(reading);
    if (unit) unit.textContent = reading.calibrated ? 'lx (one-point, phone camera)' : 'rel (not lux)';
    if (mn) mn.textContent = isFinite(luxMin) ? (reading.calibrated ? luxMin.toFixed(1) : luxMin.toFixed(1)) : '—';
    if (mx) mx.textContent = isFinite(luxMax) ? luxMax.toFixed(1) : '—';
    if (av) av.textContent = luxCount ? (luxSum / luxCount).toFixed(1) : '—';
    if (mode) {
      mode.textContent = reading.calibrated
        ? 'Calibrated mode — still a phone camera, not a photometer.'
        : 'Relative mode — these numbers are not lux. Calibrate against a known meter to label lux.';
    }

    if (luxFlicker.length >= 64) {
      var fps = dt > 1 ? 1000 / dt : 30;
      var spec = fft.analyzeSpectrum(luxFlicker, fps, { fftSize: 128 });
      var nyquist = fps / 2;
      var fl = $('lux_flicker');
      if (fl) {
        fl.textContent = 'Flicker estimate ' + fmtHz(spec.peakHz) +
          ' (camera-frame-rate limited; Nyquist ≈ ' + nyquist.toFixed(0) +
          ' Hz). A 120 Hz driver on a 30 fps camera may alias to a beat or look like DC. Not a flicker-meter.';
      }
    }
  }

  function attachVideo(stream) {
    luxVideo = $('lux_video');
    luxCanvas = $('lux_sample');
    if (!luxVideo || !luxCanvas) return;
    luxCtx = luxCanvas.getContext('2d', { willReadFrequently: true });
    luxVideo.setAttribute('playsinline', 'true');
    luxVideo.setAttribute('muted', 'true');
    luxVideo.muted = true;
    luxVideo.autoplay = false;
    if ('srcObject' in luxVideo) luxVideo.srcObject = stream;
    var play = luxVideo.play();
    if (play && play.catch) play.catch(function () {});
  }

  function detachVideo() {
    if (luxVideo) {
      try { luxVideo.pause(); } catch (_) {}
      try { luxVideo.srcObject = null; } catch (_) {}
    }
  }

  function bindLux() {
    sensors.bindGate({
      startBtn: $('lux_start'),
      stopBtn: $('lux_stop'),
      statusEl: $('lux_status'),
      toolId: 'sec-lux-meter',
      kind: 'camera',
      onStart: function (stream) {
        activeTool = 'sec-lux-meter';
        luxMin = Infinity;
        luxMax = -Infinity;
        luxSum = 0;
        luxCount = 0;
        luxSmooth = 0;
        luxFlicker = [];
        luxLastTs = 0;
        attachVideo(stream);
        kickLoop();
      },
      onStop: function () {
        if (activeTool === 'sec-lux-meter') activeTool = '';
        detachVideo();
      }
    });
    var calBtn = $('lux_calibrate');
    if (calBtn) {
      calBtn.addEventListener('click', function () {
        var known = parseFloat(($('lux_known') && $('lux_known').value) || '');
        if (!(known > 0)) return;
        var rel = luxSmooth || sampleLuxFrame();
        if (!(rel > 0)) return;
        saveNumber(LUX_SCALE_KEY, known / rel);
        var hint = $('lux_cal_hint');
        if (hint) hint.textContent = 'Saved scale ' + (known / rel).toFixed(3) +
          ' lx per relative unit on this device. Same fixture position is the honest use.';
      });
    }
    var clearCal = $('lux_clear_cal');
    if (clearCal) {
      clearCal.addEventListener('click', function () {
        saveNumber(LUX_SCALE_KEY, null);
        var hint = $('lux_cal_hint');
        if (hint) hint.textContent = 'Calibration cleared. Showing relative units, not lux.';
      });
    }
    var logBtn = $('lux_log');
    if (logBtn) {
      logBtn.addEventListener('click', function () {
        var inst = $('lux_inst');
        var unit = $('lux_unit');
        luxLogs.push({
          note: ($('lux_note') && $('lux_note').value) || '',
          ts: nowIso(),
          reading: inst ? inst.textContent : '',
          unit: unit ? unit.textContent : 'rel'
        });
        renderLogTable($('lux_log_host'), luxLogs);
      });
    }
    var csv = $('lux_csv');
    if (csv) {
      csv.addEventListener('click', function () {
        var lines = ['position,timestamp,reading,unit'];
        for (var i = 0; i < luxLogs.length; i++) {
          var r = luxLogs[i];
          lines.push([csvEscape(r.note), csvEscape(r.ts), csvEscape(r.reading), csvEscape(r.unit)].join(','));
        }
        downloadText('beckify-lux.csv', lines.join('\n'));
      });
    }
    var reset = $('lux_reset');
    if (reset) {
      reset.addEventListener('click', function () {
        luxMin = Infinity;
        luxMax = -Infinity;
        luxSum = 0;
        luxCount = 0;
      });
    }
  }

  /* ── Loop / lifecycle ───────────────────────────────────────────────── */

  function loop() {
    rafId = 0;
    if (activeTool === 'sec-pitch-hum') tickPitch();
    else if (activeTool === 'sec-audio-spectrum') tickSpectrum();
    else if (activeTool === 'sec-sound-level') tickSpl();
    else if (activeTool === 'sec-lux-meter') tickLux();
    else return;
    if (typeof document !== 'undefined' && document.hidden) return;
    rafId = global.requestAnimationFrame ? requestAnimationFrame(loop) : setTimeout(loop, 33);
  }

  function kickLoop() {
    if (rafId) return;
    loop();
  }

  function onLeaveSensors(sectionId) {
    if (sensors.SENSOR_SECTIONS[sectionId]) return;
    activeTool = '';
    detachVideo();
  }

  function init() {
    if (typeof document === 'undefined') return;
    bindPitch();
    bindSpectrum();
    bindSpl();
    bindLux();
    if (typeof setActiveSection === 'function' || global.setActiveSection) {
      /* Engine already wraps setActiveSection; also stop the rAF loop. */
      var orig = global.setActiveSection || setActiveSection;
      if (!orig.__sensorToolsWrapped) {
        var wrapped = function (id, opts) {
          orig(id, opts);
          onLeaveSensors(id);
        };
        wrapped.__sensorToolsWrapped = true;
        global.setActiveSection = wrapped;
      }
    }
    global.addEventListener('hashchange', function () {
      var id = '';
      try { id = (location.hash || '').slice(1).split('?')[0]; } catch (_) {}
      onLeaveSensors(id);
    });
    document.addEventListener('visibilitychange', function () {
      if (document.hidden) {
        activeTool = '';
        detachVideo();
      }
    });
  }

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
  }

  global.__sensorToolsTestApi = {
    applyLuxCalibration: fft.applyLuxCalibration,
    applySplCalibration: fft.applySplCalibration,
    humNote: humNote,
    HUM_TABLE: HUM_TABLE,
    LUX_SCALE_KEY: LUX_SCALE_KEY,
    SPL_OFFSET_KEY: SPL_OFFSET_KEY,
    didBindOnLoadWithoutStart: true,
    activeTool: function () { return activeTool; }
  };
})(typeof window !== 'undefined' ? window : globalThis);
