/* ============================================================================
   SHARED ON-DEVICE OCR HELPER — Option A, Tesseract.js vendored locally
   ============================================================================
   Photos never leave this device. The library, worker, wasm, and English
   traineddata are served from /toolbox/js/vendor/tesseract/. Nothing is
   uploaded to Beckify or any third-party vision API.

   OCR output is a draft. Callers must put extracted fields in editable
   controls and require a human review step before any calculation.
   ============================================================================ */
(function (global) {
  'use strict';

  var VENDOR = 'js/vendor/tesseract/';
  var loadPromise = null;
  var MAX_BYTES = 12 * 1024 * 1024;
  var LOW_CONFIDENCE = 60;

  function vendorUrl(file) {
    try { return new URL(VENDOR + file, global.location && global.location.href || 'http://local/').href; }
    catch (_) { return VENDOR + file; }
  }

  function loadScript() {
    if (global.Tesseract && global.Tesseract.createWorker) return Promise.resolve(global.Tesseract);
    if (loadPromise) return loadPromise;
    loadPromise = new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = vendorUrl('tesseract.min.js');
      s.integrity = 'sha384-GJqSu7vueQ9qN0E9yLPb3Wtpd7OrgK8KmYzC8T1IysG1bcvxvIO4qtYR/D3A991F';
      s.crossOrigin = 'anonymous';
      s.onload = function () {
        if (global.Tesseract && global.Tesseract.createWorker) resolve(global.Tesseract);
        else reject(new Error('Tesseract.js loaded but did not register.'));
      };
      s.onerror = function () {
        loadPromise = null;
        reject(new Error('Could not load the on-device OCR library. Check that js/vendor/tesseract/ is present.'));
      };
      document.head.appendChild(s);
    });
    return loadPromise;
  }

  function meanWordConfidence(data) {
    var words = (data && data.words) || [];
    var scored = words.filter(function (w) { return typeof w.confidence === 'number'; });
    if (!scored.length) return typeof data.confidence === 'number' ? data.confidence : 0;
    var sum = 0;
    for (var i = 0; i < scored.length; i++) sum += scored[i].confidence;
    return sum / scored.length;
  }

  /**
   * Heuristic only: printed panel directories rarely mention bus bars, lugs,
   * or "dead front". A hit is a caution, not a diagnosis.
   */
  function looksLikeOpenPanelInterior(text) {
    var t = String(text || '').toLowerCase();
    var hits = 0;
    ['bus bar', 'busbar', 'live parts', 'dead front', 'branch breaker body', 'panel interior', 'line lugs', 'stab', 'insulated bus'].forEach(function (k) {
      if (t.indexOf(k) !== -1) hits += 1;
    });
    return hits >= 1;
  }

  function recognize(file, opts) {
    opts = opts || {};
    if (!file) return Promise.reject(new Error('Choose a photo first.'));
    if (file.size > MAX_BYTES) return Promise.reject(new Error('Please choose an image smaller than 12 MB.'));
    if (file.type && file.type.indexOf('image/') !== 0) return Promise.reject(new Error('Please choose a photo (PNG, JPG, or WEBP).'));

    var onProgress = typeof opts.onProgress === 'function' ? opts.onProgress : function () {};
    return loadScript().then(function (Tesseract) {
      return Tesseract.createWorker('eng', 1, {
        workerPath: vendorUrl('worker.min.js'),
        corePath: vendorUrl('tesseract-core-simd-lstm.wasm.js'),
        langPath: vendorUrl('').replace(/\/$/, ''),
        gzip: true,
        logger: function (message) {
          var ratio = typeof message.progress === 'number' ? message.progress : 0;
          onProgress(ratio, message.status || '');
        },
      }).then(function (worker) {
        return worker.recognize(file).then(function (result) {
          return worker.terminate().then(function () { return result; }, function () { return result; });
        }, function (err) {
          return worker.terminate().then(function () { throw err; }, function () { throw err; });
        });
      });
    }).then(function (result) {
      var data = (result && result.data) || {};
      var text = data.text || '';
      var confidence = meanWordConfidence(data);
      return {
        text: text,
        confidence: confidence,
        lowConfidence: confidence > 0 && confidence < LOW_CONFIDENCE,
        failed: !String(text).trim(),
        looksLikeOpenPanel: looksLikeOpenPanelInterior(text),
        words: data.words || [],
      };
    });
  }

  function parseMotorNameplate(text) {
    var raw = String(text || '');
    var compact = raw.replace(/\s+/g, ' ');
    function pick(re, g) {
      var m = compact.match(re) || raw.match(re);
      return m ? String(m[g == null ? 1 : g]).trim() : '';
    }
    var hp = pick(/\b([0-9]+(?:\.[0-9]+)?)\s*(?:HP|H\.P\.)\b/i) ||
      pick(/\b(?:HP|H\.P\.|HORSEPOWER)\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?)/i);
    var kw = pick(/\b(?:kW|KW)\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?)/i) ||
      pick(/\b([0-9]+(?:\.[0-9]+)?)\s*kW\b/i);
    var volts = pick(/\b([0-9]{2,4}(?:\/[0-9]{2,4})?)\s*V(?:OLTS?)?\b/i) ||
      pick(/\b(?:VOLTS?|V)\s*[:#]?\s*([0-9]{2,4}(?:\/[0-9]{2,4})?)/i);
    var fla = pick(/\b([0-9]+(?:\.[0-9]+)?)\s*(?:FLA|FL\s*AMPS?)\b/i) ||
      pick(/\b(?:FLA|FL\s*AMPS?)\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?)/i) ||
      pick(/\bAMP(?:S|ERES)?\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?)/i);
    var rpm = pick(/\b([0-9]{3,5})\s*RPM\b/i) ||
      pick(/\b(?:RPM|R\.P\.M\.)\s*[:#]?\s*([0-9]{3,5})/i);
    var hz = pick(/\b(?:HZ|HERTZ|FREQ)\s*[:#]?\s*([0-9]{2,3})/i) ||
      pick(/\b([0-9]{2,3})\s*Hz\b/i);
    var phase = pick(/\b(?:PH|PHASE)\s*[:#]?\s*([13])\b/i);
    if (!phase) {
      if (/\b3[\s-]*PH/i.test(compact) || /\bTHREE[\s-]*PHASE/i.test(compact)) phase = '3';
      else if (/\b1[\s-]*PH/i.test(compact) || /\bSINGLE[\s-]*PHASE/i.test(compact)) phase = '1';
    }
    var frame = pick(/\bFRAME\s*[:#]?\s*([A-Z0-9\-]+)/i);
    var sf = pick(/\b(?:S\.?F\.?|SERVICE\s*FACTOR)\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?)/i);
    var design = pick(/\bDESIGN\s*[:#]?\s*([A-E])\b/i);
    var insul = pick(/\b(?:INS(?:ULATION)?(?:\s*CLASS)?|CLASS)\s*[:#]?\s*([A-H]|F|B|H|155|180|130)\b/i);
    var code = pick(/\b(?:CODE|LRA\s*CODE|KVA\s*CODE)\s*[:#]?\s*([A-V])\b/i);
    var rise = pick(/\b(?:RISE|TEMP(?:ERATURE)?\s*RISE)\s*[:#]?\s*([0-9]{2,3})\s*°?\s*C?\b/i);

    var fields = {
      hp: hp, kw: kw, volts: volts, fla: fla, rpm: rpm, hz: hz || '60',
      phase: phase, frame: frame, sf: sf, design: design, insulation: insul,
      code: code, riseC: rise,
    };
    var filled = Object.keys(fields).filter(function (k) { return fields[k]; }).length;
    return { fields: fields, filled: filled };
  }

  function humanizeStatus(status) {
    if (!status) return 'Processing…';
    return String(status)
      .replace(/recognizing text/i, 'Reading text…')
      .replace(/loading language traineddata/i, 'Loading on-device language pack…')
      .replace(/initializing api/i, 'Initializing OCR engine…')
      .replace(/initializing tesseract/i, 'Starting Tesseract.js…')
      .replace(/loading tesseract core/i, 'Loading on-device OCR engine…');
  }

  global.BeckifyOcr = {
    recognize: recognize,
    loadScript: loadScript,
    looksLikeOpenPanelInterior: looksLikeOpenPanelInterior,
    parseMotorNameplate: parseMotorNameplate,
    meanWordConfidence: meanWordConfidence,
    humanizeStatus: humanizeStatus,
    MAX_BYTES: MAX_BYTES,
    LOW_CONFIDENCE: LOW_CONFIDENCE,
    VENDOR: VENDOR,
  };
  global.__ocrHelperTestApi = global.BeckifyOcr;
})(typeof window !== 'undefined' ? window : globalThis);
