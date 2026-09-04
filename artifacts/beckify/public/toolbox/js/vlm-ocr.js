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
    var trimmed = String(raw || '').trim().replace(/\/$/, '');
    if (!trimmed) return '';
    try {
      var u = new URL(trimmed);
      if (u.protocol !== 'https:') return '';
      return u.origin + u.pathname.replace(/\/$/, '');
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
    if (partial && Object.prototype.hasOwnProperty.call(partial, 'endpoint')) {
      storageSet(global.localStorage, SETTINGS_KEY, httpsBase(partial.endpoint));
    }
    if (partial && Object.prototype.hasOwnProperty.call(partial, 'token')) {
      storageSet(global.sessionStorage, TOKEN_KEY, String(partial.token || ''));
    }
    return loadSettings();
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

  /**
   * EXIF-upright + shrink before upload. Panel directories are often landscape
   * pixels with Orientation=6; sending them sideways hurts VLM accuracy and
   * burns tokens. Falls back to the raw file data URL on any failure.
   */
  function prepareUploadDataUrl(file) {
    if (!file || typeof createImageBitmap !== 'function' || typeof document === 'undefined') {
      return fileToDataUrl(file);
    }
    return createImageBitmap(file, { imageOrientation: 'from-image' })
      .catch(function () { return createImageBitmap(file); })
      .then(function (bitmap) {
        try {
          var w = bitmap.width || 0;
          var h = bitmap.height || 0;
          if (!w || !h) {
            try { bitmap.close(); } catch (_) { /* ignore */ }
            return fileToDataUrl(file);
          }
          var scale = 1;
          var edge = Math.max(w, h);
          if (edge > MAX_UPLOAD_EDGE) scale = MAX_UPLOAD_EDGE / edge;
          var cw = Math.max(1, Math.round(w * scale));
          var ch = Math.max(1, Math.round(h * scale));
          var canvas = document.createElement('canvas');
          canvas.width = cw;
          canvas.height = ch;
          var ctx = canvas.getContext && canvas.getContext('2d');
          if (!ctx) {
            try { bitmap.close(); } catch (_) { /* ignore */ }
            return fileToDataUrl(file);
          }
          ctx.drawImage(bitmap, 0, 0, cw, ch);
          try { bitmap.close(); } catch (_) { /* ignore */ }
          return canvas.toDataURL('image/jpeg', 0.88);
        } catch (_) {
          try { bitmap.close(); } catch (__) { /* ignore */ }
          return fileToDataUrl(file);
        }
      }, function () { return fileToDataUrl(file); });
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

  function postVision(url, body, token) {
    var headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = 'Bearer ' + token;
    return fetch(url, {
      method: 'POST',
      headers: headers,
      body: JSON.stringify(body),
    }).then(function (response) {
      return response.json().catch(function () { return {}; }).then(function (payload) {
        if (!response.ok) {
          throw new Error(payload.error || ('Vision request failed with HTTP ' + response.status + '.'));
        }
        return payload;
      });
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
    var onProgress = typeof opts.onProgress === 'function' ? opts.onProgress : function () {};
    onProgress(0.15, 'Preparing photo for optional AI enhance…');
    return prepareUploadDataUrl(file).then(function (dataUrl) {
      onProgress(0.4, 'Uploading photo for optional AI enhance…');
      var body = {
        imageBase64: dataUrl,
        mimeType: (String(dataUrl).indexOf('data:image/png') === 0)
          ? 'image/png'
          : ((file && file.type) || 'image/jpeg'),
        task: task,
      };
      var token = config.mode === 'custom' ? config.token : '';
      return postVision(url, body, token).then(function (payload) {
        onProgress(0.85, 'Reading AI draft…');
        var analysis = payload.analysis || payload.fields || payload;
        var draft = analyzePayload(analysis, task, 'vlm-' + config.mode, payload.raw_ocr || analysis.raw_ocr);
        onProgress(1, 'AI draft ready. Review every field.');
        return {
          task: task,
          draft: draft,
          rawText: draft.rawText || payload.raw_ocr || '',
          warnings: draft.warnings || [],
          provider: payload.provider || config.mode,
          model: payload.model || '',
        };
      });
    });
  }

  function analyzeNameplate(file, opts) {
    var next = Object.assign({}, opts || {}, { task: TASK_NAMEPLATE });
    return analyze(file, next);
  }

  function analyzePanelDirectory(file, opts) {
    var next = Object.assign({}, opts || {}, { task: TASK_PANEL });
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
    resolveConfig: resolveConfig,
    endpointFor: endpointFor,
    metaApiBase: metaApiBase,
    httpsBase: httpsBase,
    shouldUpload: shouldUpload,
    analyze: analyze,
    analyzeNameplate: analyzeNameplate,
    analyzePanelDirectory: analyzePanelDirectory,
    analyzeTdr: analyzeTdr,
    analyzeLook: analyzeLook,
    normalizeLookDraft: normalizeLookDraft,
    extractJsonObject: extractJsonObject,
    analyzePayload: analyzePayload,
    prepareUploadDataUrl: prepareUploadDataUrl,
    fileToDataUrl: fileToDataUrl,
    rowsFromPanelDraft: rowsFromPanelDraft,
    panelMetaFromDraft: panelMetaFromDraft,
    MAX_UPLOAD_EDGE: MAX_UPLOAD_EDGE,
  };
  global.__vlmOcrTestApi = global.BeckifyVlmOcr;
})(typeof window !== 'undefined' ? window : globalThis);
