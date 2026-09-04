/* ============================================================================
   OPTIONAL CLOUD VLM OCR — motor nameplate (panel path ready)
   ============================================================================
   Default path is still on-device Tesseract (ocr-helper.js). This module
   never uploads a photo unless the user turns on “Enhance with AI” and then
   clicks Read. It is an assistive draft, not perfect OCR, and not an AI
   electrician.

   Configure the endpoint (first match wins when Enhance is on):

     1. Custom HTTPS URL in the tool settings (optional Bearer token is kept
        in sessionStorage only — never localStorage, never sent to Beckify).
        POST { imageBase64, mimeType, task: "nameplate"|"panel"|"tdr"|"look" }

     2. Beckify proxy placeholder: <meta name="beckify-api-base-url"> or
        window.BECKIFY_API_BASE_URL (deploy injects TDR_API_BASE_URL here).
        HTTPS only. POST {base}/api/analyze-nameplate, /api/analyze-panel, /api/analyze-tdr, or /api/analyze-look
        Server env: OPENAI_API_KEY or ANTHROPIC_API_KEY
        Optional: NAMEPLATE_VISION_PROVIDER, NAMEPLATE_VISION_MODEL

   Photos are not uploaded on file pick. Tesseract remains the offline default
   when Enhance is off or when no endpoint is configured.
   ============================================================================ */
(function (global) {
  'use strict';

  var SETTINGS_KEY = 'beckify-vlm-endpoint';
  var TOKEN_KEY = 'beckify-vlm-token';
  var TASK_NAMEPLATE = 'nameplate';
  var TASK_PANEL = 'panel';
  var TASK_TDR = 'tdr';
  var TASK_LOOK = 'look';
  var MAX_BYTES = 8 * 1024 * 1024;
  var MAX_UPLOAD_EDGE = 2048;
  var PROXY_DOWNSTREAM_NOTE = 'The Beckify proxy may forward the photo to OpenAI and/or Anthropic.';

  function schema() {
    return global.BeckifyNameplateSchema;
  }

  function storageGet(store, key) {
    try {
      if (!store) return '';
      return String(store.getItem(key) || '');
    } catch (_) {
      return '';
    }
  }

  function storageSet(store, key, value) {
    try {
      if (!store) return;
      if (!value) store.removeItem(key);
      else store.setItem(key, String(value));
    } catch (_) { /* private mode */ }
  }

  function httpsBase(raw) {
    var trimmed = String(raw || '').trim();
    if (!trimmed) return '';
    try {
      var u = new URL(trimmed);
      if (u.protocol !== 'https:') return '';
      return u.origin + u.pathname.replace(/\/$/, '') + u.search;
    } catch (_) {
      return '';
    }
  }

  function metaApiBase() {
    var fromWindow = global.BECKIFY_API_BASE_URL;
    var fromMeta = '';
    try {
      var node = global.document && global.document.querySelector('meta[name="beckify-api-base-url"]');
      fromMeta = node ? node.getAttribute('content') : '';
    } catch (_) { /* ignore */ }
    return httpsBase(fromMeta || fromWindow || '');
  }

  function loadSettings() {
    return {
      endpoint: httpsBase(storageGet(global.localStorage, SETTINGS_KEY)),
      token: storageGet(global.sessionStorage, TOKEN_KEY),
    };
  }

  function saveSettings(partial) {
    var current = loadSettings();
    var nextEndpoint = current.endpoint;
    var nextToken = current.token;
    var hasEndpoint = !!(partial && Object.prototype.hasOwnProperty.call(partial, 'endpoint'));
    var hasToken = !!(partial && Object.prototype.hasOwnProperty.call(partial, 'token'));
    if (hasEndpoint) {
      nextEndpoint = httpsBase(partial.endpoint);
      if (nextEndpoint !== current.endpoint && current.endpoint && !hasToken) nextToken = '';
    }
    if (hasToken) nextToken = String(partial.token || '');
    storageSet(global.localStorage, SETTINGS_KEY, nextEndpoint);
    storageSet(global.sessionStorage, TOKEN_KEY, nextToken);
    return loadSettings();
  }

  /**
   * Persist the settings form. Changing the custom URL drops the stored
   * bearer token so a credential for endpoint A is never posted to B.
   */
  function saveFormSettings(endpointRaw, tokenRaw) {
    var current = loadSettings();
    var nextEndpoint = httpsBase(endpointRaw);
    var switchedEndpoint = nextEndpoint !== current.endpoint && !!current.endpoint;
    var nextToken = switchedEndpoint ? '' : String(tokenRaw || '');
    storageSet(global.localStorage, SETTINGS_KEY, nextEndpoint);
    storageSet(global.sessionStorage, TOKEN_KEY, nextToken);
    return {
      endpoint: nextEndpoint,
      token: nextToken,
      tokenCleared: switchedEndpoint,
    };
  }

  function resolveConfig(enhanceOn) {
    var settings = loadSettings();
    var proxy = metaApiBase();
    var custom = settings.endpoint;
    var mode = 'none';
    if (custom) mode = 'custom';
    else if (proxy) mode = 'proxy';
    return {
      enhanceOn: !!enhanceOn,
      mode: mode,
      proxyUrl: proxy,
      customUrl: custom,
      token: settings.token,
      ready: !!enhanceOn && mode !== 'none',
    };
  }

  function endpointFor(config, task) {
    var suffix = '/api/analyze-nameplate';
    if (task === TASK_PANEL) suffix = '/api/analyze-panel';
    else if (task === TASK_TDR) suffix = '/api/analyze-tdr';
    else if (task === TASK_LOOK) suffix = '/api/analyze-look';
    if (config.mode === 'custom') return config.customUrl;
    if (config.mode === 'proxy') return config.proxyUrl + suffix;
    return '';
  }

  function fileToDataUrl(file) {
    return new Promise(function (resolve, reject) {
      if (!file) {
        reject(new Error('Choose a photo first.'));
        return;
      }
      if (file.size > MAX_BYTES) {
        reject(new Error('AI enhance needs an image smaller than 8 MB.'));
        return;
      }
      var reader = new FileReader();
      reader.onload = function () { resolve(String(reader.result || '')); };
      reader.onerror = function () { reject(reader.error || new Error('Could not read the image file.')); };
      reader.readAsDataURL(file);
    });
  }

  function uploadMimeType(dataUrl, fallback) {
    var match = /^data:([^;,]+)/i.exec(String(dataUrl || ''));
    return match ? String(match[1]).toLowerCase() : (fallback || 'image/jpeg');
  }

  function canvasToJpegDataUrl(source, width, height) {
    if (!source || typeof document === 'undefined') return '';
    var w = width || source.width || source.naturalWidth || 0;
    var h = height || source.height || source.naturalHeight || 0;
    if (!w || !h) return '';
    var scale = 1;
    var edge = Math.max(w, h);
    if (edge > MAX_UPLOAD_EDGE) scale = MAX_UPLOAD_EDGE / edge;
    var cw = Math.max(1, Math.round(w * scale));
    var ch = Math.max(1, Math.round(h * scale));
    var canvas = document.createElement('canvas');
    canvas.width = cw;
    canvas.height = ch;
    var ctx = canvas.getContext && canvas.getContext('2d');
    if (!ctx) return '';
    ctx.drawImage(source, 0, 0, cw, ch);
    try {
      return canvas.toDataURL('image/jpeg', 0.88);
    } catch (_) {
      return '';
    }
  }

  function decodeWithImageElement(file) {
    if (!file || typeof Image === 'undefined' || typeof URL === 'undefined') {
      return Promise.resolve('');
    }
    return new Promise(function (resolve) {
      var url;
      try { url = URL.createObjectURL(file); } catch (_) { resolve(''); return; }
      var img = new Image();
      img.onload = function () {
        try { URL.revokeObjectURL(url); } catch (_) { /* ignore */ }
        resolve(canvasToJpegDataUrl(img) || '');
      };
      img.onerror = function () {
        try { URL.revokeObjectURL(url); } catch (_) { /* ignore */ }
        resolve('');
      };
      img.src = url;
    });
  }

  /**
   * EXIF-upright + shrink + JPEG re-encode before upload. HEIC/BMP/TIFF picks
   * become image/jpeg when the browser can decode them so the proxy MIME
   * check matches the data URL. Falls back to the raw file data URL on any
   * failure.
   */
  function prepareUploadDataUrl(file) {
    if (!file || typeof document === 'undefined') {
      return fileToDataUrl(file);
    }
    var fromBitmap = Promise.resolve('');
    if (typeof createImageBitmap === 'function') {
      fromBitmap = createImageBitmap(file, { imageOrientation: 'from-image' })
        .catch(function () { return createImageBitmap(file); })
        .then(function (bitmap) {
          if (!bitmap) return '';
          try {
            var jpeg = canvasToJpegDataUrl(bitmap, bitmap.width, bitmap.height);
            try { bitmap.close(); } catch (_) { /* ignore */ }
            return jpeg;
          } catch (_) {
            try { bitmap.close(); } catch (__) { /* ignore */ }
            return '';
          }
        }, function () { return ''; });
    }
    return fromBitmap.then(function (jpeg) {
      if (jpeg && jpeg.indexOf('data:image/jpeg') === 0) return jpeg;
      return decodeWithImageElement(file).then(function (fromImage) {
        if (fromImage && fromImage.indexOf('data:image/jpeg') === 0) return fromImage;
        return fileToDataUrl(file);
      });
    });
  }

  function extractJsonObject(text) {
    var trimmed = String(text || '').trim();
    var fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
    var source = fenced ? fenced[1] : trimmed;
    var start = source.indexOf('{');
    var end = source.lastIndexOf('}');
    var json = start >= 0 && end >= 0 ? source.slice(start, end + 1) : source;
    return JSON.parse(json);
  }

  function safeExtractJsonObject(text) {
    try {
      return extractJsonObject(text);
    } catch (_) {
      return null;
    }
  }

  function VisionHttpError(message, status, retryAfter) {
    var err = new Error(message);
    err.name = 'VisionHttpError';
    err.status = status || 0;
    err.retryAfter = retryAfter || 0;
    return err;
  }

  function parseRetryAfter(response, payload) {
    var header = 0;
    try {
      if (response && response.headers && typeof response.headers.get === 'function') {
        header = Number(response.headers.get('Retry-After'));
      }
    } catch (_) { /* ignore */ }
    var body = payload && (payload.retryAfter != null ? payload.retryAfter : payload.retry_after);
    var seconds = Number(header || body || 0);
    return Number.isFinite(seconds) && seconds > 0 ? Math.round(seconds) : 0;
  }

  function formatVisionError(err) {
    if (!err) return 'Vision request failed.';
    var status = err.status || 0;
    if (status === 429) {
      var wait = err.retryAfter;
      if (wait >= 60) return 'Too many AI reads. Try again in about ' + Math.ceil(wait / 60) + ' min, or use on-device OCR.';
      if (wait > 0) return 'Too many AI reads. Try again in ' + wait + ' s, or use on-device OCR.';
      return 'Too many AI reads right now. Wait a few minutes, or use on-device OCR.';
    }
    if (status === 413) return err.message || 'The photo is too large for AI enhance (8 MB after JPEG encode).';
    if (status === 504) return 'The vision provider timed out. On-device OCR is still available.';
    return err.message || 'Vision request failed.';
  }

  function knownTask(task) {
    if (task === TASK_PANEL || task === TASK_TDR || task === TASK_LOOK) return task;
    return TASK_NAMEPLATE;
  }

  function normalizeLookDraft(raw) {
    var allowed = { looks_good: 1, mixed: 1, looks_bad: 1, no_person: 1, declined: 1 };
    var verdict = String((raw && raw.verdict) || '').toLowerCase();
    if (!allowed[verdict]) verdict = 'mixed';
    var score = Number(raw && raw.score);
    if (!Number.isFinite(score)) score = null;
    else score = Math.max(0, Math.min(100, Math.round(score)));
    if (verdict === 'declined') score = null;
    return {
      task: TASK_LOOK,
      verdict: verdict,
      score: score,
      headline: String((raw && raw.headline) || ''),
      reasons: Array.isArray(raw && raw.reasons) ? raw.reasons.map(String) : [],
      fixes: Array.isArray(raw && raw.fixes) ? raw.fixes.map(String) : [],
      photoNotes: Array.isArray(raw && (raw.photoNotes || raw.photo_notes))
        ? (raw.photoNotes || raw.photo_notes).map(String)
        : [],
      warnings: Array.isArray(raw && raw.warnings) ? raw.warnings.map(String) : [],
    };
  }

  function analyzePayload(payload, task, source, rawFallback) {
    if (task === TASK_LOOK) return normalizeLookDraft(payload);
    if (task === TASK_TDR) return payload || {};
    var Schema = schema();
    if (!Schema) throw new Error('Nameplate schema helper did not load.');
    if (task === TASK_PANEL) {
      return Schema.normalizePanelDraft(payload, { source: source, rawText: rawFallback });
    }
    return Schema.normalizeDraft(payload, { source: source, rawText: rawFallback || (payload && payload.raw_ocr) });
  }

  function visionDraftInput(payload) {
    if (payload && payload.analysis && typeof payload.analysis === 'object') return payload.analysis;
    return payload || {};
  }

  function postVision(url, body, token) {
    var headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = 'Bearer ' + token;
    function once() {
      return fetch(url, {
        method: 'POST',
        headers: headers,
        body: JSON.stringify(body),
      }).then(function (response) {
        return response.json().catch(function () { return {}; }).then(function (payload) {
          if (!response.ok) {
            throw VisionHttpError(
              payload.error || ('Vision request failed with HTTP ' + response.status + '.'),
              response.status,
              parseRetryAfter(response, payload)
            );
          }
          return payload;
        });
      });
    }
    return once().catch(function (err) {
      if (err && (err.status === 502 || err.status === 504)) {
        return new Promise(function (resolve) { setTimeout(resolve, 800); }).then(once);
      }
      throw err;
    });
  }

  /**
   * Upload happens only here, after Enhance is on and the user clicked Read.
   * Callers must not invoke this on file pick.
   */
  function analyze(file, opts) {
    opts = opts || {};
    var task = knownTask(opts.task);
    var config = resolveConfig(opts.enhanceOn);
    if (!opts.enhanceOn) {
      return Promise.reject(new Error('AI enhance is off. On-device OCR will be used instead.'));
    }
    if (!config.ready) {
      return Promise.reject(new Error('AI enhance is on but no HTTPS endpoint is configured. Use on-device OCR or set a VLM endpoint.'));
    }
    var url = endpointFor(config, task);
    var lastProgress = 0;
    var onProgress = typeof opts.onProgress === 'function' ? opts.onProgress : function () {};
    function report(ratio, status) {
      var next = Math.max(lastProgress, Math.max(0, Math.min(1, Number(ratio) || 0)));
      lastProgress = next;
      onProgress(next, status || '');
    }
    report(0.15, 'Preparing photo for optional AI enhance…');
    return prepareUploadDataUrl(file).then(function (dataUrl) {
      report(0.4, 'Uploading photo for optional AI enhance…');
      var body = {
        imageBase64: dataUrl,
        mimeType: uploadMimeType(dataUrl, 'image/jpeg'),
        task: task,
      };
      var token = config.mode === 'custom' ? config.token : '';
      return postVision(url, body, token).then(function (payload) {
        report(0.85, 'Reading AI draft…');
        var analysis = visionDraftInput(payload);
        var draft = analyzePayload(analysis, task, 'vlm-' + config.mode, payload.raw_ocr || analysis.raw_ocr);
        report(1, 'AI draft ready. Review every field.');
        return {
          task: task,
          draft: draft,
          rawText: draft.rawText || payload.raw_ocr || '',
          warnings: draft.warnings || [],
          provider: payload.provider || config.mode,
          model: payload.model || '',
        };
      }).catch(function (err) {
        err.message = formatVisionError(err);
        throw err;
      });
    });
  }

  function analyzeMany(files, opts) {
    var list = (files || []).filter(Boolean);
    if (!list.length) return Promise.reject(new Error('Choose a photo first.'));
    var task = knownTask(opts && opts.task);
    if (task !== TASK_PANEL || list.length === 1) {
      return analyze(list[0], opts);
    }
    var Schema = schema();
    var onProgress = typeof opts.onProgress === 'function' ? opts.onProgress : function () {};
    var merged = null;
    var warnings = [];
    var rawParts = [];
    var provider = '';
    var model = '';
    var chain = Promise.resolve();
    list.forEach(function (file, index) {
      chain = chain.then(function () {
        onProgress(Math.min(0.95, index / list.length), 'Reading photo ' + (index + 1) + ' of ' + list.length + '…');
        return analyze(file, Object.assign({}, opts || {}, {
          onProgress: function (ratio, status) {
            var start = index / list.length;
            var span = 1 / list.length;
            onProgress(Math.min(0.99, start + (Number(ratio) || 0) * span), status || '');
          },
        })).then(function (out) {
          provider = out.provider || provider;
          model = out.model || model;
          if (out.rawText) rawParts.push(out.rawText);
          if (out.warnings && out.warnings.length) warnings = warnings.concat(out.warnings);
          merged = merged && Schema ? Schema.mergePanelDrafts(merged, out.draft) : out.draft;
          return out;
        });
      });
    });
    return chain.then(function () {
      onProgress(1, 'Merged AI draft ready. Review every circuit.');
      return {
        task: TASK_PANEL,
        draft: merged,
        rawText: (merged && merged.rawText) || rawParts.join('\n'),
        warnings: warnings,
        provider: provider,
        model: model,
        shotCount: list.length,
      };
    });
  }

  function analyzeNameplate(file, opts) {
    var next = Object.assign({}, opts || {}, { task: TASK_NAMEPLATE });
    return analyze(file, next);
  }

  function analyzePanelDirectory(file, opts) {
    var next = Object.assign({}, opts || {}, { task: TASK_PANEL });
    if (Array.isArray(file)) return analyzeMany(file, next);
    return analyze(file, next);
  }

  function analyzeTdr(file, opts) {
    var next = Object.assign({}, opts || {}, { task: TASK_TDR, enhanceOn: true });
    return analyze(file, next);
  }

  function analyzeLook(file, opts) {
    var next = Object.assign({}, opts || {}, { task: TASK_LOOK, enhanceOn: true });
    return analyze(file, next);
  }

  function rowsFromPanelDraft(draft, makeRow) {
    var create = typeof makeRow === 'function' ? makeRow : function () { return {}; };
    return ((draft && draft.rows) || []).map(function (cell) {
      var row = create();
      var circuit = cell && cell.circuit && cell.circuit.value;
      var description = cell && cell.description && cell.description.value;
      var trip = cell && cell.trip && cell.trip.value;
      var poles = cell && cell.poles && cell.poles.value;
      var notes = cell && cell.notes && cell.notes.value;
      row.circuit = circuit == null ? '' : String(circuit);
      row.description = description == null ? '' : String(description);
      if (notes && row.description && String(notes) !== String(description)) {
        row.description = String(description) + ' (' + String(notes) + ')';
      } else if (notes && !row.description) {
        row.description = String(notes);
      }
      row.trip = trip == null || trip === '' ? '' : String(trip);
      row.poles = poles == null || poles === '' ? '' : String(poles);
      row.loadAmps = '';
      row.loadAmpsCopiedFromTrip = false;
      return row;
    }).filter(function (row) {
      return row.circuit || row.description || row.trip || row.poles;
    });
  }

  function panelMetaFromDraft(draft) {
    var panel = (draft && draft.panel) || {};
    function val(field) {
      if (!field || field.value == null || field.value === '') return '';
      return field.value;
    }
    return {
      panelName: val(panel.name),
      voltage: val(panel.voltage),
      mainAmps: val(panel.mainAmps),
      phases: val(panel.phases),
      location: val(panel.location),
    };
  }

  function shouldUpload(enhanceOn) {
    return resolveConfig(enhanceOn).ready;
  }

  global.BeckifyVlmOcr = {
    SETTINGS_KEY: SETTINGS_KEY,
    TOKEN_KEY: TOKEN_KEY,
    TASK_NAMEPLATE: TASK_NAMEPLATE,
    TASK_PANEL: TASK_PANEL,
    TASK_TDR: TASK_TDR,
    TASK_LOOK: TASK_LOOK,
    MAX_BYTES: MAX_BYTES,
    loadSettings: loadSettings,
    saveSettings: saveSettings,
    saveFormSettings: saveFormSettings,
    resolveConfig: resolveConfig,
    endpointFor: endpointFor,
    metaApiBase: metaApiBase,
    httpsBase: httpsBase,
    shouldUpload: shouldUpload,
    analyze: analyze,
    analyzeMany: analyzeMany,
    analyzeNameplate: analyzeNameplate,
    analyzePanelDirectory: analyzePanelDirectory,
    analyzeTdr: analyzeTdr,
    analyzeLook: analyzeLook,
    normalizeLookDraft: normalizeLookDraft,
    extractJsonObject: extractJsonObject,
    safeExtractJsonObject: safeExtractJsonObject,
    formatVisionError: formatVisionError,
    VisionHttpError: VisionHttpError,
    analyzePayload: analyzePayload,
    prepareUploadDataUrl: prepareUploadDataUrl,
    uploadMimeType: uploadMimeType,
    visionDraftInput: visionDraftInput,
    fileToDataUrl: fileToDataUrl,
    PROXY_DOWNSTREAM_NOTE: PROXY_DOWNSTREAM_NOTE,
    rowsFromPanelDraft: rowsFromPanelDraft,
    panelMetaFromDraft: panelMetaFromDraft,
    MAX_UPLOAD_EDGE: MAX_UPLOAD_EDGE,
  };
  global.__vlmOcrTestApi = global.BeckifyVlmOcr;
})(typeof window !== 'undefined' ? window : globalThis);
