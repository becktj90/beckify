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
  var MAX_DIRECTORY_EDGE = 2400;
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
   * Optional, best-effort EXIF-aware upright + shrink + grayscale. Failures
   * fall back to the original file so HEIC/odd decoders never block manual entry.
   * Phone panel-directory shots often store landscape pixels with Orientation=6;
   * drawing without EXIF correction leaves the schedule sideways for Tesseract.
   */
  function preprocessForOcr(file, opts) {
    opts = opts || {};
    if (!file || typeof document === 'undefined') {
      return Promise.resolve(file);
    }
    return loadBitmap(file).then(function (bitmap) {
      if (!bitmap) return file;
      try {
        var w = bitmap.width || 0;
        var h = bitmap.height || 0;
        if (!w || !h) {
          closeBitmap(bitmap);
          return file;
        }
        var scale = 1;
        var edge = Math.max(w, h);
        var maxEdge = (opts && opts.maxEdge) || MAX_PREPROCESS_EDGE;
        if (edge > maxEdge) scale = maxEdge / edge;
        var cw = Math.max(1, Math.round(w * scale));
        var ch = Math.max(1, Math.round(h * scale));
        var canvas = document.createElement('canvas');
        canvas.width = cw;
        canvas.height = ch;
        var ctx = canvas.getContext && canvas.getContext('2d');
        if (!ctx) {
          closeBitmap(bitmap);
          return file;
        }
        ctx.drawImage(bitmap, 0, 0, cw, ch);
        closeBitmap(bitmap);
        var imageData = ctx.getImageData(0, 0, cw, ch);
        var d = imageData.data;
        for (var i = 0; i < d.length; i += 4) {
          var g = d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114;
          d[i] = d[i + 1] = d[i + 2] = g;
        }
        stretchContrast(d);
        ctx.putImageData(imageData, 0, 0);
        return canvasToBlob(canvas).then(function (blob) { return blob || canvas; });
      } catch (_) {
        closeBitmap(bitmap);
        return file;
      }
    }, function () { return file; });
  }

  function closeBitmap(bitmap) {
    try {
      if (bitmap && typeof bitmap.close === 'function') bitmap.close();
    } catch (_) { /* ignore */ }
  }

  function canvasToBlob(canvas) {
    return new Promise(function (resolve) {
      if (typeof canvas.toBlob === 'function') {
        canvas.toBlob(function (blob) { resolve(blob || null); }, 'image/png');
      } else {
        resolve(null);
      }
    });
  }

  function loadBitmap(file) {
    if (typeof createImageBitmap === 'function') {
      return createImageBitmap(file, { imageOrientation: 'from-image' }).catch(function () {
        return createImageBitmap(file).catch(function () { return null; });
      });
    }
    if (typeof Image === 'undefined' || typeof URL === 'undefined') {
      return Promise.resolve(null);
    }
    return new Promise(function (resolve) {
      var url;
      try { url = URL.createObjectURL(file); }
      catch (_) { resolve(null); return; }
      var img = new Image();
      img.onload = function () {
        try { URL.revokeObjectURL(url); } catch (_) { /* ignore */ }
        resolve(img);
      };
      img.onerror = function () {
        try { URL.revokeObjectURL(url); } catch (_) { /* ignore */ }
        resolve(null);
      };
      img.src = url;
    });
  }

  function stretchContrast(data) {
    var hist = new Uint32Array(256);
    var i;
    for (i = 0; i < data.length; i += 4) hist[data[i]] += 1;
    var total = data.length / 4;
    if (!total) return;
    var lo = 0;
    var hi = 255;
    var acc = 0;
    var loCut = total * 0.02;
    var hiCut = total * 0.98;
    for (i = 0; i < 256; i += 1) {
      acc += hist[i];
      if (lo === 0 && acc >= loCut) lo = i;
      if (acc >= hiCut) { hi = i; break; }
    }
    if (hi <= lo) return;
    var scale = 255 / (hi - lo);
    for (i = 0; i < data.length; i += 4) {
      var v = Math.max(0, Math.min(255, Math.round((data[i] - lo) * scale)));
      data[i] = data[i + 1] = data[i + 2] = v;
    }
  }

  function rotateImageSource(source, degrees) {
    if (!source || typeof document === 'undefined' || !degrees) {
      return Promise.resolve(source);
    }
    return loadBitmap(source).then(function (bitmap) {
      if (!bitmap) return source;
      try {
        var w = bitmap.width || 0;
        var h = bitmap.height || 0;
        if (!w || !h) {
          closeBitmap(bitmap);
          return source;
        }
        var rad = (degrees * Math.PI) / 180;
        var swap = Math.abs(degrees) % 180 === 90;
        var canvas = document.createElement('canvas');
        canvas.width = swap ? h : w;
        canvas.height = swap ? w : h;
        var ctx = canvas.getContext && canvas.getContext('2d');
        if (!ctx) {
          closeBitmap(bitmap);
          return source;
        }
        ctx.translate(canvas.width / 2, canvas.height / 2);
        ctx.rotate(rad);
        ctx.drawImage(bitmap, -w / 2, -h / 2);
        closeBitmap(bitmap);
        return canvasToBlob(canvas).then(function (blob) { return blob || canvas; });
      } catch (_) {
        closeBitmap(bitmap);
        return source;
      }
    }, function () { return source; });
  }

  function collectWords(data) {
    var words = (data && data.words) || [];
    if (words.length) return words;
    var blocks = (data && data.blocks) || [];
    var out = [];
    for (var b = 0; b < blocks.length; b += 1) {
      var paras = (blocks[b] && blocks[b].paragraphs) || [];
      for (var p = 0; p < paras.length; p += 1) {
        var lines = (paras[p] && paras[p].lines) || [];
        for (var l = 0; l < lines.length; l += 1) {
          var lineWords = (lines[l] && lines[l].words) || [];
          for (var w = 0; w < lineWords.length; w += 1) out.push(lineWords[w]);
        }
      }
    }
    return out;
  }

  function wordBox(word) {
    var box = word && (word.bbox || word.boundingBox || word);
    if (!box) return null;
    var x0 = Number(box.x0 != null ? box.x0 : box.x);
    var y0 = Number(box.y0 != null ? box.y0 : box.y);
    var x1 = Number(box.x1 != null ? box.x1 : (x0 + Number(box.w || box.width || 0)));
    var y1 = Number(box.y1 != null ? box.y1 : (y0 + Number(box.h || box.height || 0)));
    if (![x0, y0, x1, y1].every(Number.isFinite)) return null;
    return { x0: x0, y0: y0, x1: x1, y1: y1, cx: (x0 + x1) / 2, cy: (y0 + y1) / 2 };
  }

  function normalizeOcrWord(word) {
    var text = String((word && (word.text || word.word)) || '').replace(/[|]+/g, '').trim();
    var box = wordBox(word);
    if (!text || !box) return null;
    return {
      text: text,
      confidence: typeof word.confidence === 'number' ? word.confidence : 60,
      x0: box.x0,
      y0: box.y0,
      x1: box.x1,
      y1: box.y1,
      cx: box.cx,
      cy: box.cy,
    };
  }

  function isCircuitToken(text) {
    var n = Number(String(text || '').replace(/[^\d]/g, ''));
    return Number.isFinite(n) && n >= 1 && n <= 84 && /^\d{1,2}[A-Z]?$/.test(String(text || '').trim());
  }

  function directoryScore(text) {
    var t = String(text || '');
    if (!t.trim()) return 0;
    var score = 0;
    if (/\b(?:spare|space|recept|panel|ckt|circuit|lighting|power\s*pole|crac|turnstile)\b/i.test(t)) score += 4;
    var nums = t.match(/\b(?:[1-9]|[1-7]\d|8[0-4])\b/g);
    if (nums) score += Math.min(10, Math.floor(nums.length / 3));
    if (t.length > 40) score += 1;
    if (t.length > 200) score += 1;
    return score;
  }

  function reconstructDirectoryFromWords(words) {
    var items = (words || []).map(normalizeOcrWord).filter(function (w) {
      return w && w.confidence >= 20;
    });
    if (items.length < 6) return null;
    items.sort(function (a, b) { return a.cy - b.cy || a.cx - b.cx; });
    var heights = items.map(function (w) { return Math.max(4, w.y1 - w.y0); }).sort(function (a, b) { return a - b; });
    var rowTol = Math.max(8, heights[Math.floor(heights.length / 2)] * 0.75);
    var rows = [];
    items.forEach(function (word) {
      var last = rows[rows.length - 1];
      if (!last || Math.abs(word.cy - last.cy) > rowTol) {
        rows.push({ cy: word.cy, words: [word] });
      } else {
        last.words.push(word);
        last.cy = ((last.cy * (last.words.length - 1)) + word.cy) / last.words.length;
      }
    });
    var lines = rows.map(function (row) {
      row.words.sort(function (a, b) { return a.cx - b.cx; });
      return formatDirectoryRow(row.words);
    }).filter(Boolean);
    if (lines.length < 2) return null;
    return { text: lines.join('\n'), lineCount: lines.length, lines: lines };
  }

  function formatDirectoryRow(words) {
    var circuits = words.filter(function (w) { return isCircuitToken(w.text); });
    if (circuits.length >= 2) {
      var leftC = circuits[0];
      var rightC = circuits[circuits.length - 1];
      var leftDesc = words.filter(function (w) { return w.cx < leftC.cx; });
      var mid = words.filter(function (w) { return w.cx > leftC.cx && w.cx < rightC.cx; });
      var rightDesc = words.filter(function (w) { return w.cx > rightC.cx; });
      if (leftDesc.length && rightDesc.length) {
        return [joinWords(leftDesc), leftC.text, rightC.text, joinWords(rightDesc)].join('  ');
      }
      if (mid.length >= 2) {
        var split = splitAtLargestGap(mid);
        return [leftC.text, joinWords(split[0]), rightC.text, joinWords(split[1])].join('  ');
      }
    }
    return joinWords(words);
  }

  function joinWords(words) {
    return (words || []).map(function (w) { return w.text; }).join(' ').trim();
  }

  function splitAtLargestGap(words) {
    if (!words || words.length < 2) return [words || [], []];
    var best = -1;
    var idx = Math.floor((words.length - 1) / 2);
    for (var i = 0; i < words.length - 1; i += 1) {
      var gap = words[i + 1].x0 - words[i].x1;
      if (gap > best) {
        best = gap;
        idx = i;
      }
    }
    return [words.slice(0, idx + 1), words.slice(idx + 1)];
  }

  function packOcrResult(result) {
    var data = (result && result.data) || {};
    var words = collectWords(data);
    var text = data.text || '';
    var reconstructed = reconstructDirectoryFromWords(words);
    if (reconstructed && directoryScore(reconstructed.text) >= directoryScore(text)) {
      text = reconstructed.text;
    }
    var confidence = meanWordConfidence({ words: words, confidence: data.confidence });
    return {
      text: text,
      confidence: confidence,
      lowConfidence: isLowConfidence(confidence, text),
      failed: !String(text).trim(),
      looksLikeOpenPanel: looksLikeOpenPanelInterior(text),
      words: words,
      reconstructed: reconstructed,
      score: directoryScore(text),
    };
  }

  function recognizeOnce(worker, source, psm) {
    var params = {
      tessedit_pageseg_mode: String(psm),
      preserve_interword_spaces: '1',
    };
    var run = function () {
      return worker.recognize(source);
    };
    if (typeof worker.setParameters === 'function') {
      return worker.setParameters(params).then(run, run);
    }
    return run();
  }

  function mapOcrProgress(opts) {
    opts = opts || {};
    var ratio = typeof opts.ratio === 'number' ? opts.ratio : 0;
    if (ratio < 0) ratio = 0;
    if (ratio > 1) ratio = 1;
    if (!opts.directoryMode) return ratio;
    if ((opts.pass || 1) <= 1) return ratio * 0.55;
    return 0.62 + ratio * 0.38;
  }

  function recognize(file, opts) {
    opts = opts || {};
    if (!file) return Promise.reject(new Error('Choose a photo first.'));
    if (file.size > MAX_BYTES) return Promise.reject(new Error('Please choose an image smaller than 12 MB.'));
    if (!isLikelyImageFile(file)) return Promise.reject(new Error('Please choose a photo (' + ACCEPTED_IMAGE_LABEL + ').'));

    var onProgress = typeof opts.onProgress === 'function' ? opts.onProgress : function () {};
    var directoryMode = opts.mode === 'directory';
    var preprocessOpts = directoryMode ? { maxEdge: MAX_DIRECTORY_EDGE } : {};
    var lastProgress = 0;
    var directoryPass = 1;
    function reportProgress(ratio, status) {
      var next = Math.max(lastProgress, Math.max(0, Math.min(1, Number(ratio) || 0)));
      lastProgress = next;
      onProgress(next, status || '');
    }
    return loadScript().then(function (Tesseract) {
      return preprocessForOcr(file, preprocessOpts).then(function (source) {
        return Tesseract.createWorker('eng', 1, {
          workerPath: vendorUrl('worker.min.js'),
          corePath: vendorUrl('tesseract-core-simd-lstm.wasm.js'),
          langPath: vendorUrl('').replace(/\/$/, ''),
          gzip: true,
          logger: function (message) {
            var ratio = typeof message.progress === 'number' ? message.progress : 0;
            reportProgress(mapOcrProgress({
              ratio: ratio,
              directoryMode: directoryMode,
              pass: directoryPass,
            }), message.status || '');
          },
        }).then(function (worker) {
          var firstPsm = directoryMode ? 4 : 3;
          return recognizeOnce(worker, source, firstPsm).then(function (first) {
            var best = packOcrResult(first);
            if (!directoryMode || best.score >= 6) return best;
            directoryPass = 2;
            reportProgress(0.62, 'Trying a second pass for a rotated directory…');
            return rotateImageSource(source, 90).then(function (rotated) {
              return recognizeOnce(worker, rotated, 4).then(function (second) {
                var scored = packOcrResult(second);
                return scored.score > best.score ? scored : best;
              }, function () { return best; });
            }, function () { return best; });
          }).then(function (packed) {
            return worker.terminate().then(function () { return packed; }, function () { return packed; });
          }, function (err) {
            return worker.terminate().then(function () { throw err; }, function () { throw err; });
          });
        });
      });
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
    reconstructDirectoryFromWords: reconstructDirectoryFromWords,
    directoryScore: directoryScore,
    rotateImageSource: rotateImageSource,
    MAX_BYTES: MAX_BYTES,
    LOW_CONFIDENCE: LOW_CONFIDENCE,
    MAX_PREPROCESS_EDGE: MAX_PREPROCESS_EDGE,
    MAX_DIRECTORY_EDGE: MAX_DIRECTORY_EDGE,
    ACCEPTED_IMAGE_LABEL: ACCEPTED_IMAGE_LABEL,
    mapOcrProgress: mapOcrProgress,
    VENDOR: VENDOR,
  };
  global.__ocrHelperTestApi = global.BeckifyOcr;
})(typeof window !== 'undefined' ? window : globalThis);
