/* ============================================================================
   SHARED PHONE-SENSOR ENGINE — microphone, camera, permission, lifecycle
   ============================================================================
   One getUserMedia microphone stream + AudioContext + AnalyserNode, shared by
   pitch, FFT/spectrum, and the sound-level meter. Switching audio tools must
   not open a second stream or re-prompt if the session already granted access.

   Camera is a separate stream (lux meter only) with the same permission UX
   and the same stop-on-hide / stop-on-navigate rules.

   Nothing starts on page load. Every tool requires an explicit Start tap.
   AudioContext.resume() runs inside that tap (iOS autoplay policy).

   Privacy: live, on-device, display only. Streams are never recorded,
   stored, or transmitted.

   Depends on: none (FFT lives in sensor-fft.js).
   ============================================================================ */

(function (global) {
  'use strict';

  var AUDIO_SECTIONS = {
    'sec-pitch-hum': true,
    'sec-audio-spectrum': true,
    'sec-sound-level': true
  };
  var CAMERA_SECTIONS = {
    'sec-lux-meter': true
  };
  var SENSOR_SECTIONS = {
    'sec-pitch-hum': true,
    'sec-audio-spectrum': true,
    'sec-sound-level': true,
    'sec-lux-meter': true
  };

  var ANALYSER_FFT_SIZE = 2048;
  var TIME_RING = 8192;

  var didAutoStart = false;
  var micPermissionGranted = false;
  var camPermissionGranted = false;

  var audioCtx = null;
  var analyser = null;
  var micStream = null;
  var micSource = null;
  var micUsers = Object.create(null);
  var timeRing = new Float32Array(TIME_RING);
  var timeRingWrite = 0;
  var freqBuf = null;
  var timeBuf = null;

  var camStream = null;
  var camUsers = Object.create(null);

  var lastSectionId = '';
  var hookedNav = false;

  function isSecure() {
    try { return !!global.isSecureContext; } catch (_) { return false; }
  }

  function mediaDevices() {
    return global.navigator && global.navigator.mediaDevices;
  }

  function describeMicError(err) {
    if (!isSecure()) {
      return 'Microphone access needs a secure page (HTTPS). GitHub Pages is fine; opening this file over http:// or file:// is not.';
    }
    if (!mediaDevices() || !mediaDevices().getUserMedia) {
      return 'This browser does not expose a microphone API. Try current Safari or Chrome on the phone.';
    }
    var name = err && (err.name || err.code) || '';
    var msg = (err && err.message) || '';
    if (name === 'NotAllowedError' || name === 'PermissionDeniedError') {
      return 'Microphone permission was denied. In Safari: aA / Site Settings → Microphone. In Chrome: the lock icon in the address bar. Nothing is recorded — live display only.';
    }
    if (name === 'NotFoundError' || name === 'DevicesNotFoundError') {
      return 'No microphone was found on this device.';
    }
    if (name === 'NotReadableError' || name === 'TrackStartError') {
      return 'The microphone is in use by another app, or the device refused exclusive access. Close the other app and tap Start again.';
    }
    if (name === 'NotSupportedError' || name === 'TypeError') {
      return 'This browser blocked getUserMedia. Use HTTPS (beckify.com) in Safari or Chrome.';
    }
    if (name === 'SecurityError') {
      return 'The browser blocked the microphone for security. Reload over HTTPS and tap Start.';
    }
    if (/audio context|suspended|autoplay/i.test(msg) || name === 'InvalidStateError') {
      return 'This browser paused audio until a tap. Tap Start again — AudioContext has to resume on a user gesture (iOS).';
    }
    return 'Could not open the microphone' + (msg ? ' (' + msg + ')' : '') + '. Tap Start after granting permission.';
  }

  function describeCamError(err) {
    if (!isSecure()) {
      return 'Camera access needs a secure page (HTTPS). GitHub Pages is fine; opening this file over http:// or file:// is not.';
    }
    if (!mediaDevices() || !mediaDevices().getUserMedia) {
      return 'This browser does not expose a camera API. Try current Safari or Chrome on the phone.';
    }
    var name = err && (err.name || err.code) || '';
    var msg = (err && err.message) || '';
    if (name === 'NotAllowedError' || name === 'PermissionDeniedError') {
      return 'Camera permission was denied. In Safari: aA / Site Settings → Camera. In Chrome: the lock icon in the address bar. Nothing is recorded or uploaded — live display only.';
    }
    if (name === 'NotFoundError' || name === 'DevicesNotFoundError') {
      return 'No camera was found on this device.';
    }
    if (name === 'NotReadableError' || name === 'TrackStartError') {
      return 'The camera is in use by another app, or the device refused exclusive access.';
    }
    if (name === 'OverconstrainedError' || name === 'ConstraintNotSatisfiedError') {
      return 'No rear camera matched the request; tap Start again to try the default camera.';
    }
    return 'Could not open the camera' + (msg ? ' (' + msg + ')' : '') + '. Tap Start after granting permission.';
  }

  function AudioContextCtor() {
    return global.AudioContext || global.webkitAudioContext;
  }

  function ensureAudioGraph() {
    var Ctor = AudioContextCtor();
    if (!Ctor) throw Object.assign(new Error('Web Audio is not available in this browser.'), { name: 'NotSupportedError' });
    if (!audioCtx) {
      audioCtx = new Ctor();
      analyser = audioCtx.createAnalyser();
      analyser.fftSize = ANALYSER_FFT_SIZE;
      analyser.smoothingTimeConstant = 0;
      analyser.minDecibels = -90;
      analyser.maxDecibels = -10;
      freqBuf = new Float32Array(analyser.frequencyBinCount);
      timeBuf = new Float32Array(analyser.fftSize);
    }
    return audioCtx;
  }

  function stopTracks(stream) {
    if (!stream) return;
    var tracks = stream.getTracks ? stream.getTracks() : [];
    for (var i = 0; i < tracks.length; i++) {
      try { tracks[i].stop(); } catch (_) {}
    }
  }

  function disconnectMicGraph() {
    if (micSource) {
      try { micSource.disconnect(); } catch (_) {}
      micSource = null;
    }
  }

  function closeMicStream() {
    disconnectMicGraph();
    stopTracks(micStream);
    micStream = null;
    micUsers = Object.create(null);
  }

  function closeCamStream() {
    stopTracks(camStream);
    camStream = null;
    camUsers = Object.create(null);
  }

  function pushTimeDomain(buf) {
    var i;
    for (i = 0; i < buf.length; i++) {
      timeRing[timeRingWrite] = buf[i];
      timeRingWrite = (timeRingWrite + 1) % TIME_RING;
    }
  }

  function copyRing(out) {
    var n = out.length;
    var start = (timeRingWrite - n + TIME_RING) % TIME_RING;
    var first = Math.min(n, TIME_RING - start);
    var i;
    for (i = 0; i < first; i++) out[i] = timeRing[start + i];
    for (i = first; i < n; i++) out[i] = timeRing[i - first];
    return out;
  }

  /**
   * Open (or reuse) the shared microphone. `toolId` is a section id so we
   * can ref-count users without opening three streams.
   */
  function startMic(toolId) {
    toolId = toolId || 'audio';
    return Promise.resolve().then(function () {
      if (!isSecure()) {
        throw Object.assign(new Error('insecure'), { name: 'SecurityError' });
      }
      if (!mediaDevices() || !mediaDevices().getUserMedia) {
        throw Object.assign(new Error('no getUserMedia'), { name: 'NotSupportedError' });
      }
      ensureAudioGraph();
      var resume = audioCtx.resume ? audioCtx.resume() : Promise.resolve();
      return Promise.resolve(resume).then(function () {
        if (audioCtx.state === 'suspended') {
          throw Object.assign(new Error('AudioContext suspended until a user gesture'), { name: 'InvalidStateError' });
        }
        if (micStream && micStream.active !== false) {
          micUsers[toolId] = true;
          return getMicHandle();
        }
        var constraints = {
          audio: {
            echoCancellation: false,
            noiseSuppression: false,
            autoGainControl: false,
            channelCount: 1
          },
          video: false
        };
        return mediaDevices().getUserMedia(constraints).then(function (stream) {
          micStream = stream;
          micPermissionGranted = true;
          disconnectMicGraph();
          micSource = audioCtx.createMediaStreamSource(stream);
          micSource.connect(analyser);
          /* Intentionally not connected to destination — we analyse, we do not play back. */
          micUsers[toolId] = true;
          return getMicHandle();
        }, function (err) {
          /* Fallback: some browsers reject the advanced constraint object. */
          if (err && (err.name === 'OverconstrainedError' || err.name === 'ConstraintNotSatisfiedError' || err.name === 'TypeError')) {
            return mediaDevices().getUserMedia({ audio: true, video: false }).then(function (stream) {
              micStream = stream;
              micPermissionGranted = true;
              disconnectMicGraph();
              micSource = audioCtx.createMediaStreamSource(stream);
              micSource.connect(analyser);
              micUsers[toolId] = true;
              return getMicHandle();
            });
          }
          throw err;
        });
      });
    });
  }

  function stopMic(toolId) {
    if (toolId) delete micUsers[toolId];
    else micUsers = Object.create(null);
    var still = false;
    for (var k in micUsers) { if (micUsers[k]) { still = true; break; } }
    if (!still) closeMicStream();
  }

  function stopAllMic() {
    closeMicStream();
  }

  function getMicHandle() {
    return {
      audioContext: audioCtx,
      analyser: analyser,
      stream: micStream,
      sampleRate: audioCtx ? audioCtx.sampleRate : 0,
      fftSize: analyser ? analyser.fftSize : ANALYSER_FFT_SIZE,
      binHz: audioCtx && analyser ? audioCtx.sampleRate / analyser.fftSize : 0
    };
  }

  function getAnalyser() {
    return analyser;
  }

  function getTimeDomain(optionalOut) {
    if (!analyser) {
      var empty = optionalOut || new Float32Array(ANALYSER_FFT_SIZE);
      empty.fill(0);
      return empty;
    }
    if (!timeBuf || timeBuf.length !== analyser.fftSize) timeBuf = new Float32Array(analyser.fftSize);
    if (analyser.getFloatTimeDomainData) analyser.getFloatTimeDomainData(timeBuf);
    else {
      var bytes = new Uint8Array(analyser.fftSize);
      analyser.getByteTimeDomainData(bytes);
      for (var i = 0; i < bytes.length; i++) timeBuf[i] = (bytes[i] - 128) / 128;
    }
    pushTimeDomain(timeBuf);
    if (!optionalOut) return timeBuf;
    if (optionalOut.length === timeBuf.length) {
      optionalOut.set(timeBuf);
      return optionalOut;
    }
    return copyRing(optionalOut);
  }

  function getFrequencyData(optionalOut) {
    if (!analyser) {
      var empty = optionalOut || new Float32Array(ANALYSER_FFT_SIZE / 2);
      empty.fill(-Infinity);
      return empty;
    }
    if (!freqBuf || freqBuf.length !== analyser.frequencyBinCount) {
      freqBuf = new Float32Array(analyser.frequencyBinCount);
    }
    if (analyser.getFloatFrequencyData) analyser.getFloatFrequencyData(freqBuf);
    if (!optionalOut) return freqBuf;
    var n = Math.min(optionalOut.length, freqBuf.length);
    for (var i = 0; i < n; i++) optionalOut[i] = freqBuf[i];
    return optionalOut;
  }

  function getPitchBuffer(out) {
    var dest = out || new Float32Array(TIME_RING);
    getTimeDomain();
    return copyRing(dest);
  }

  function isMicRunning() {
    return !!(micStream && analyser);
  }

  function getSampleRate() {
    return audioCtx && audioCtx.sampleRate ? audioCtx.sampleRate : 0;
  }

  function startCamera(toolId, constraints) {
    toolId = toolId || 'camera';
    return Promise.resolve().then(function () {
      if (!isSecure()) {
        throw Object.assign(new Error('insecure'), { name: 'SecurityError' });
      }
      if (!mediaDevices() || !mediaDevices().getUserMedia) {
        throw Object.assign(new Error('no getUserMedia'), { name: 'NotSupportedError' });
      }
      if (camStream && camStream.active !== false) {
        camUsers[toolId] = true;
        return camStream;
      }
      var c = constraints || {
        audio: false,
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 640 },
          height: { ideal: 480 }
        }
      };
      return mediaDevices().getUserMedia(c).then(function (stream) {
        camStream = stream;
        camPermissionGranted = true;
        camUsers[toolId] = true;
        return stream;
      }, function (err) {
        if (err && (err.name === 'OverconstrainedError' || err.name === 'ConstraintNotSatisfiedError')) {
          return mediaDevices().getUserMedia({ audio: false, video: true }).then(function (stream) {
            camStream = stream;
            camPermissionGranted = true;
            camUsers[toolId] = true;
            return stream;
          });
        }
        throw err;
      });
    });
  }

  function stopCamera(toolId) {
    if (toolId) delete camUsers[toolId];
    else camUsers = Object.create(null);
    var still = false;
    for (var k in camUsers) { if (camUsers[k]) { still = true; break; } }
    if (!still) closeCamStream();
  }

  function stopAllCamera() {
    closeCamStream();
  }

  function isCameraRunning() {
    return !!camStream;
  }

  function stopAllSensors() {
    stopAllMic();
    stopAllCamera();
  }

  function onSectionChange(sectionId) {
    lastSectionId = sectionId || '';
    if (!AUDIO_SECTIONS[lastSectionId]) stopAllMic();
    if (!CAMERA_SECTIONS[lastSectionId]) stopAllCamera();
  }

  function onVisibility() {
    if (typeof document === 'undefined') return;
    if (document.hidden || document.visibilityState === 'hidden') stopAllSensors();
  }

  function hookLifecycle() {
    if (hookedNav) return;
    hookedNav = true;
    if (typeof document !== 'undefined' && document.addEventListener) {
      document.addEventListener('visibilitychange', onVisibility);
    }
    if (typeof global.addEventListener === 'function') {
      global.addEventListener('pagehide', stopAllSensors);
      global.addEventListener('hashchange', function () {
        var id = '';
        try { id = (global.location.hash || '').slice(1).split('?')[0]; } catch (_) {}
        onSectionChange(id);
      });
    }
    if (typeof setActiveSection === 'function') {
      var orig = setActiveSection;
      global.setActiveSection = function (sectionId, opts) {
        orig(sectionId, opts);
        onSectionChange(sectionId);
      };
    }
  }

  function currentSectionId() {
    try { return (global.location.hash || '').slice(1).split('?')[0]; } catch (_) { return lastSectionId; }
  }

  /* Bind Start/Stop. NEVER called on load with a stream. */
  function bindGate(opts) {
    opts = opts || {};
    var startBtn = opts.startBtn;
    var stopBtn = opts.stopBtn;
    var statusEl = opts.statusEl;
    var toolId = opts.toolId;
    var kind = opts.kind || 'mic';
    var onStart = opts.onStart;
    var onStop = opts.onStop;
    var onError = opts.onError;

    function setStatus(text, cls) {
      if (!statusEl) return;
      statusEl.textContent = text;
      statusEl.className = 'sensor-status' + (cls ? ' ' + cls : '');
    }

    function doStop() {
      if (kind === 'camera') stopCamera(toolId);
      else stopMic(toolId);
      if (typeof onStop === 'function') onStop();
      setStatus('Stopped. Sensors are off — battery and privacy stay quiet until you tap Start.', '');
    }

    function doStart() {
      setStatus('Starting…', 'is-busy');
      var p = kind === 'camera' ? startCamera(toolId) : startMic(toolId);
      return p.then(function (handle) {
        setStatus('Live — processed on this device only. Nothing is recorded or sent.', 'is-live');
        if (typeof onStart === 'function') onStart(handle);
      }).catch(function (err) {
        var text = kind === 'camera' ? describeCamError(err) : describeMicError(err);
        setStatus(text, 'is-error');
        if (typeof onError === 'function') onError(err, text);
      });
    }

    if (startBtn && startBtn.addEventListener) {
      startBtn.addEventListener('click', function (ev) {
        if (ev && ev.preventDefault) ev.preventDefault();
        doStart();
      });
    }
    if (stopBtn && stopBtn.addEventListener) {
      stopBtn.addEventListener('click', function (ev) {
        if (ev && ev.preventDefault) ev.preventDefault();
        doStop();
      });
    }
  }

  hookLifecycle();

  var api = {
    AUDIO_SECTIONS: AUDIO_SECTIONS,
    CAMERA_SECTIONS: CAMERA_SECTIONS,
    SENSOR_SECTIONS: SENSOR_SECTIONS,
    ANALYSER_FFT_SIZE: ANALYSER_FFT_SIZE,
    TIME_RING: TIME_RING,
    startMic: startMic,
    stopMic: stopMic,
    stopAllMic: stopAllMic,
    getAnalyser: getAnalyser,
    getSampleRate: getSampleRate,
    getTimeDomain: getTimeDomain,
    getFrequencyData: getFrequencyData,
    getPitchBuffer: getPitchBuffer,
    isMicRunning: isMicRunning,
    startCamera: startCamera,
    stopCamera: stopCamera,
    stopAllCamera: stopAllCamera,
    isCameraRunning: isCameraRunning,
    stopAllSensors: stopAllSensors,
    onSectionChange: onSectionChange,
    describeMicError: describeMicError,
    describeCamError: describeCamError,
    bindGate: bindGate,
    isSecure: isSecure,
    micPermissionGranted: function () { return micPermissionGranted; },
    camPermissionGranted: function () { return camPermissionGranted; },
    didAutoStart: function () { return didAutoStart; },
    currentSectionId: currentSectionId
  };

  global.BeckifySensors = api;
  global.__sensorEngineTestApi = api;
})(typeof window !== 'undefined' ? window : globalThis);
