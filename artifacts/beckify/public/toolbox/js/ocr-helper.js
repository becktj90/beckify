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
  var MAX_PREPROCESS_EDGE = 1600;
  var IMAGE_EXT = /\.(jpe?g|png|webp|gif|bmp|tif{1,2}|heic|heif)$/i;
  var ACCEPTED_IMAGE_LABEL = 'JPG, PNG, WEBP, HEIC/HEIF, GIF, BMP, or TIFF';
  var REJECTED_AMP_LABEL = /(?:MOCP|M\.?O\.?C\.?P\.?|MCA|SCA|LRA|L\.?R\.?A\.?|AIC|KAIC|SCCR)\s*[:#]?\s*$/i;

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
    if (!scored.length) return (data && typeof data.confidence === 'number') ? data.confidence : 0;
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
    var phrases = ['bus bar', 'busbar', 'live parts', 'dead front', 'branch breaker body', 'panel interior', 'line lugs', 'insulated bus'];
    phrases.forEach(function (k) {
      if (t.indexOf(k) !== -1) hits += 1;
    });
    if (/\bstabs?\b/.test(t)) hits += 1;
    return hits >= 1;
  }

  function isLikelyImageFile(file) {
    if (!file) return false;
    var type = String(file.type || '');
    if (type.indexOf('image/') === 0) return true;
    if (type) return false;
    return IMAGE_EXT.test(String(file.name || ''));
  }

  function isLowConfidence(confidence, text) {
    if (!String(text || '').trim()) return false;
    var c = Number(confidence);
    if (!Number.isFinite(c)) return true;
    return c < LOW_CONFIDENCE;
  }

  function rejectedAmpPrefix(str, index) {
    var before = String(str || '').slice(Math.max(0, index - 16), index);
    return REJECTED_AMP_LABEL.test(before);
  }

  /**
   * Optional, best-effort shrink + grayscale. Failures fall back to the
   * original file so HEIC/odd decoders never block manual entry.
   */
  function preprocessForOcr(file) {
    if (!file || typeof document === 'undefined' || typeof Image === 'undefined') {
      return Promise.resolve(file);
    }
    return new Promise(function (resolve) {
      var url;
      try { url = URL.createObjectURL(file); }
      catch (_) { resolve(file); return; }
      var img = new Image();
      function finish(result) {
        try { URL.revokeObjectURL(url); } catch (_) { /* ignore */ }
        resolve(result);
      }
      img.onload = function () {
        try {
          var w = img.naturalWidth || img.width;
          var h = img.naturalHeight || img.height;
          if (!w || !h) { finish(file); return; }
          var scale = 1;
          var edge = Math.max(w, h);
          if (edge > MAX_PREPROCESS_EDGE) scale = MAX_PREPROCESS_EDGE / edge;
          var cw = Math.max(1, Math.round(w * scale));
          var ch = Math.max(1, Math.round(h * scale));
          var canvas = document.createElement('canvas');
          canvas.width = cw;
          canvas.height = ch;
          var ctx = canvas.getContext && canvas.getContext('2d');
          if (!ctx) { finish(file); return; }
          ctx.drawImage(img, 0, 0, cw, ch);
          var imageData = ctx.getImageData(0, 0, cw, ch);
          var d = imageData.data;
          for (var i = 0; i < d.length; i += 4) {
            var g = d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114;
            d[i] = d[i + 1] = d[i + 2] = g;
          }
          ctx.putImageData(imageData, 0, 0);
          if (typeof canvas.toBlob === 'function') {
            canvas.toBlob(function (blob) { finish(blob || canvas); }, 'image/png');
          } else {
            finish(canvas);
          }
        } catch (_) {
          finish(file);
        }
      };
      img.onerror = function () { finish(file); };
      img.src = url;
    });
  }

  function recognize(file, opts) {
    opts = opts || {};
    if (!file) return Promise.reject(new Error('Choose a photo first.'));
    if (file.size > MAX_BYTES) return Promise.reject(new Error('Please choose an image smaller than 12 MB.'));
    if (!isLikelyImageFile(file)) return Promise.reject(new Error('Please choose a photo (' + ACCEPTED_IMAGE_LABEL + ').'));

    var onProgress = typeof opts.onProgress === 'function' ? opts.onProgress : function () {};
    return loadScript().then(function (Tesseract) {
      return preprocessForOcr(file).then(function (source) {
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
          return worker.recognize(source).then(function (result) {
            return worker.terminate().then(function () { return result; }, function () { return result; });
          }, function (err) {
            return worker.terminate().then(function () { throw err; }, function () { throw err; });
          });
        });
      });
    }).then(function (result) {
      var data = (result && result.data) || {};
      var text = data.text || '';
      var confidence = meanWordConfidence(data);
      return {
        text: text,
        confidence: confidence,
        lowConfidence: isLowConfidence(confidence, text),
        failed: !String(text).trim(),
        looksLikeOpenPanel: looksLikeOpenPanelInterior(text),
        words: data.words || [],
      };
    });
  }

  function extractLabeledHp(str) {
    var src = String(str || '');
    var re = /\b(?:HP|H\.P\.|HORSEPOWER)\b/gi;
    var m;
    while ((m = re.exec(src))) {
      var afterSlice = src.slice(m.index + m[0].length);
      var after = afterSlice.match(/^\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?)/);
      var beforeMatch = src.slice(0, m.index).match(/([0-9]+(?:\.[0-9]+)?)\s*[:#]?\s*$/);
      var afterIsVoltage = after && /^\s*[:#]?\s*[0-9]+(?:\.[0-9]+)?\s*V\b(?!OLT)/i.test(afterSlice);
      var beforeIsOtherRating = beforeMatch && /\b(?:MOCP|M\.?O\.?C\.?P\.?|MCA|SCA|LRA|L\.?R\.?A\.?|FLA|FL\s*AMPS?|AIC|KAIC)\s*[:#]?\s*[0-9]+(?:\.[0-9]+)?(?:\/[0-9]+(?:\.[0-9]+)?)?\s*[:#]?\s*$/i.test(src.slice(0, m.index));
      if (beforeIsOtherRating && after && !afterIsVoltage) return after[1];
      if (beforeMatch && !beforeIsOtherRating) return beforeMatch[1];
      if (after && !afterIsVoltage) return after[1];
      if (beforeMatch) return beforeMatch[1];
    }
    return '';
  }

  function extractLabeledFla(str) {
    var src = String(str || '');
    var re = /\b(?:FLA|FL\s*AMPS?)\b/gi;
    var m;
    while ((m = re.exec(src))) {
      var after = src.slice(m.index + m[0].length).match(/^\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?(?:\/[0-9]+(?:\.[0-9]+)?)?)/);
      var beforeMatch = src.slice(0, m.index).match(/([0-9]+(?:\.[0-9]+)?(?:\/[0-9]+(?:\.[0-9]+)?)?)\s*[:#]?\s*$/);
      if (beforeMatch) {
        var beforeIndex = m.index - beforeMatch[0].length;
        if (!rejectedAmpPrefix(src, beforeIndex)) return beforeMatch[1];
      }
      if (after) return after[1];
    }
    return '';
  }

  function parseMotorNameplate(text) {
    var raw = String(text || '');
    var compact = raw.replace(/\s+/g, ' ');
    function pick(re, g) {
      var m = compact.match(re) || raw.match(re);
      return m ? String(m[g === undefined || g === null ? 1 : g]).trim() : '';
    }
    function pickAmp(re) {
      var src = compact;
      var globalRe = new RegExp(re.source, re.flags.indexOf('g') === -1 ? re.flags + 'g' : re.flags);
      var m;
      while ((m = globalRe.exec(src))) {
        if (rejectedAmpPrefix(src, m.index)) continue;
        return String(m[1]).trim();
      }
      return '';
    }

    var hp = extractLabeledHp(compact);
    var kw = pick(/\b(?:kW|KW)\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?)/i) ||
      pick(/\b([0-9]+(?:\.[0-9]+)?)\s*kW\b/i);

    /* Dual voltage + dual FLA must stay paired (230/460 with 28/14), never
       first-V mashed with the last lone amp figure. */
    var dualPair = compact.match(/\b([0-9]{2,4}\/[0-9]{2,4})\s*V(?:OLTS?)?\s+([0-9]+(?:\.[0-9]+)?\/[0-9]+(?:\.[0-9]+)?)(?:\s*(?:FLA|FL\s*AMPS?|A(?:MPS?)?))?\b/i);

    /* Prefer VOLTS 460 over "10 VOLTS 460" (HP sitting in front of the label). */
    var volts = (dualPair && dualPair[1]) ||
      pick(/\b(?:VOLTS?|VOLTAGE)\s*[:#]?\s*([0-9]{2,4}(?:\/[0-9]{2,4})?)\b/i) ||
      pick(/\b([0-9]{2,4}(?:\/[0-9]{2,4})?)\s*V\b(?!OLT)/i) ||
      pick(/\b([0-9]{2,4}(?:\/[0-9]{2,4})?)\s*VOLTS?\b(?!\s*[:#]?\s*[0-9])/i);

    var fla = (dualPair && dualPair[2]) || extractLabeledFla(compact) ||
      pickAmp(/\bAMP(?:S|ERES)?\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?(?:\/[0-9]+(?:\.[0-9]+)?)?)\b/i) ||
      pickAmp(/\b([0-9]+(?:\.[0-9]+)?(?:\/[0-9]+(?:\.[0-9]+)?)?)\s*A(?:MPS?)?\b/i);

    var rpm = pick(/\b([0-9]{3,5})\s*RPM\b/i) ||
      pick(/\b(?:RPM|R\.P\.M\.)\s*[:#]?\s*([0-9]{3,5})\b/i);
    var hz = pick(/\b(?:HZ|HERTZ|FREQ)\s*[:#]?\s*([0-9]{2,3})\b/i) ||
      pick(/\b([0-9]{2,3})\s*Hz\b/i);
    var phase = pick(/\b(?:PH|PHASE)\s*[:#]?\s*([13])\b/i);
    if (!phase) {
      if (/\b3[\s-]*PH\b/i.test(compact) || /\bTHREE[\s-]*PHASE\b/i.test(compact)) phase = '3';
      else if (/\b1[\s-]*PH\b/i.test(compact) || /\bSINGLE[\s-]*PHASE\b/i.test(compact)) phase = '1';
    }
    var frame = pick(/\bFRAME\s*[:#]?\s*([A-Z0-9\-]+)\b/i);
    var sf = pick(/\b(?:S\.?F\.?|SERVICE\s*FACTOR)\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?)\b/i);
    var design = pick(/\bDESIGN\s*[:#]?\s*([A-E])\b/i);
    var insul = pick(/\b(?:INS(?:ULATION)?(?:\s*CLASS)?|CLASS)\s*[:#]?\s*([A-H]|F|B|H|155|180|130)\b/i);
    var code = pick(/\b(?:CODE|LRA\s*CODE|KVA\s*CODE)\s*[:#]?\s*([A-V])\b/i);
    var rise = pick(/\b(?:RISE|TEMP(?:ERATURE)?\s*RISE)\s*[:#]?\s*([0-9]{2,3})\s*°?\s*C?\b/i);
    var manufacturer = pick(/\b(?:MFG|MFR|MANUFACTURER)\s*[:#]?\s*([A-Z][A-Z0-9.&-]{1,24})\b/i);
    var model = pick(/\b(?:MODEL|CAT(?:ALOG)?(?:\s*NO\.?)?)\s*[:#]?\s*([A-Z0-9][A-Z0-9\-\/.]{1,24})\b/i);
    var enclosure = pick(/\b(TEFC|TENV|TEAO|ODP|XP|EXP(?:LOSION)?[\s-]*PROOF|WPI|WPII)\b/i);
    var poles = pick(/\b(?:POLES?)\s*[:#]?\s*([0-9]{1,2})\b/i) ||
      pick(/\b([0-9]{1,2})\s*POLES?\b/i);
    var nomEff = pick(/\b(?:NOM(?:INAL)?\s*)?EFF(?:ICIENCY)?\s*[:#]?\s*([0-9]{2,3}(?:\.[0-9]+)?)\s*%?/i);
    var pf = pick(/\b(?:P\.?F\.?|POWER\s*FACTOR)\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?)\b/i);
    var mocp = pick(/\b(?:MOCP|M\.?O\.?C\.?P\.?|MAX(?:IMUM)?\s*OCP)\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?)\b/i);
    var lra = pick(/\b(?:LRA|L\.?R\.?A\.?)\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?)\b/i) ||
      pick(/\bLOCKED[\s-]*ROTOR(?:\s*AMPS?)?\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?)\b/i);
    var sfa = pick(/\b(?:SFA|SF\s*AMPS?|SERVICE\s*FACTOR\s*AMPS?)\s*[:#]?\s*([0-9]+(?:\.[0-9]+)?)\b/i);

    var fields = {
      hp: hp, kw: kw, volts: volts, fla: fla, rpm: rpm, hz: hz || '60',
      phase: phase, frame: frame, sf: sf, design: design, insulation: insul,
      code: code, riseC: rise, manufacturer: manufacturer, model: model,
      enclosure: enclosure, poles: poles, nomEff: nomEff, pf: pf, mocp: mocp,
      lra: lra, serviceFactorAmps: sfa, notes: '',
    };
    var counted = { hp: hp, kw: kw, volts: volts, fla: fla, rpm: rpm, hz: hz,
      phase: phase, frame: frame, sf: sf, design: design, insulation: insul,
      code: code, riseC: rise };
    var filled = Object.keys(counted).filter(function (k) { return counted[k]; }).length;
    return { fields: fields, filled: filled };
  }

  function toNameplateDraft(text, confidence) {
    var parsed = parseMotorNameplate(text);
    var Schema = global.BeckifyNameplateSchema;
    if (!Schema) return { fields: parsed.fields, filled: parsed.filled, source: 'tesseract' };
    return Schema.fromLegacyParse(parsed.fields, {
      source: 'tesseract',
      rawText: text,
      confidence: typeof confidence === 'number' ? confidence / 100 : 0,
    });
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
    toNameplateDraft: toNameplateDraft,
    meanWordConfidence: meanWordConfidence,
    humanizeStatus: humanizeStatus,
    isLikelyImageFile: isLikelyImageFile,
    isLowConfidence: isLowConfidence,
    preprocessForOcr: preprocessForOcr,
    MAX_BYTES: MAX_BYTES,
    LOW_CONFIDENCE: LOW_CONFIDENCE,
    MAX_PREPROCESS_EDGE: MAX_PREPROCESS_EDGE,
    ACCEPTED_IMAGE_LABEL: ACCEPTED_IMAGE_LABEL,
    VENDOR: VENDOR,
  };
  global.__ocrHelperTestApi = global.BeckifyOcr;
})(typeof window !== 'undefined' ? window : globalThis);
