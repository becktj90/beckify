/* ============================================================================
   SHARED MOTOR NAMEPLATE DRAFT SCHEMA
   ============================================================================
   Website + iOS agree on these field names (string unless noted):
     manufacturer, model, ratedHP (number), ratedKW (number), voltage, fla
     (number), sf (number), rpm (number), poles (int), frequencyHz (number),
     phases (1|3), enclosure, frame, designLetter, codeLetter, nomEff (number),
     pf (number), mocp (number), lra (number), serviceFactorAmps (number), notes.

   Each extracted field is { value, confidence, userReviewed }.
   OCR / VLM output is an assistive draft. userReviewed stays false until a
   human checks the review box. NEVER copy MOCP or LRA into FLA.
   ============================================================================ */
(function (global) {
  'use strict';

  var FIELD_SPECS = [
    { name: 'manufacturer', type: 'string' },
    { name: 'model', type: 'string' },
    { name: 'ratedHP', type: 'number' },
    { name: 'ratedKW', type: 'number' },
    { name: 'voltage', type: 'string' },
    { name: 'fla', type: 'number' },
    { name: 'sf', type: 'number' },
    { name: 'rpm', type: 'number' },
    { name: 'poles', type: 'int' },
    { name: 'frequencyHz', type: 'number' },
    { name: 'phases', type: 'phases' },
    { name: 'enclosure', type: 'string' },
    { name: 'frame', type: 'string' },
    { name: 'designLetter', type: 'string' },
    { name: 'codeLetter', type: 'string' },
    { name: 'nomEff', type: 'number' },
    { name: 'pf', type: 'number' },
    { name: 'mocp', type: 'number' },
    { name: 'lra', type: 'number' },
    { name: 'serviceFactorAmps', type: 'number' },
    { name: 'notes', type: 'string' },
  ];

  var FIELD_NAMES = FIELD_SPECS.map(function (spec) { return spec.name; });
  var REJECTED_AMP_AS_FLA = /(?:MOCP|M\.?O\.?C\.?P\.?|MCA|SCA|LRA|L\.?R\.?A\.?|AIC|KAIC|SCCR)/i;
  var DUAL_NUMBER = /^([0-9]+(?:\.[0-9]+)?)\/([0-9]+(?:\.[0-9]+)?)$/;

  function emptyField() {
    return { value: null, confidence: 0, userReviewed: false };
  }

  function clampConfidence(value) {
    var n = Number(value);
    if (!Number.isFinite(n)) return 0;
    if (n > 1 && n <= 100) n = n / 100;
    if (n < 0) return 0;
    if (n > 1) return 1;
    return n;
  }

  function isBlank(value) {
    return value === undefined || value === null || String(value).trim() === '';
  }

  function asString(value) {
    if (isBlank(value)) return null;
    var s = String(value).trim();
    return s || null;
  }

  function asNumber(value) {
    if (isBlank(value)) return null;
    if (typeof value === 'string' && DUAL_NUMBER.test(value.trim())) return null;
    var n = typeof value === 'number' ? value : Number(String(value).replace(/,/g, ''));
    return Number.isFinite(n) ? n : null;
  }

  function asInt(value) {
    var n = asNumber(value);
    if (n === null) return null;
    var i = Math.round(n);
    return Number.isFinite(i) ? i : null;
  }

  function asPhases(value) {
    var n = asInt(value);
    return n === 1 || n === 3 ? n : null;
  }

  function asLetter(value) {
    var s = asString(value);
    if (!s) return null;
    var letter = s.replace(/[^A-Za-z]/g, '').charAt(0);
    return letter ? letter.toUpperCase() : null;
  }

  function fieldFrom(raw, type, confidence) {
    var value = null;
    if (type === 'number') value = asNumber(raw);
    else if (type === 'int') value = asInt(raw);
    else if (type === 'phases') value = asPhases(raw);
    else if (type === 'letter') value = asLetter(raw);
    else value = asString(raw);
    return {
      value: value,
      confidence: value === null ? 0 : clampConfidence(confidence),
      userReviewed: false,
    };
  }

  function unwrapRaw(raw) {
    if (!raw || typeof raw !== 'object') return raw;
    if (Object.prototype.hasOwnProperty.call(raw, 'value')) return raw.value;
    return raw;
  }

  function rawConfidence(raw, fallback) {
    if (raw && typeof raw === 'object' && raw.confidence !== undefined) return raw.confidence;
    return fallback;
  }

  function emptyDraft() {
    var fields = {};
    FIELD_SPECS.forEach(function (spec) { fields[spec.name] = emptyField(); });
    return {
      fields: fields,
      extras: { flaDisplay: '', insulation: '', riseC: '', dualFla: '' },
      source: 'empty',
      rawText: '',
      warnings: [],
      filled: 0,
    };
  }

  function countFilled(fields) {
    return FIELD_NAMES.filter(function (name) {
      return fields[name] && fields[name].value !== null && fields[name].value !== '';
    }).length;
  }

  function dualPair(value) {
    var s = asString(value);
    if (!s) return '';
    var m = s.match(DUAL_NUMBER);
    return m ? (m[1] + '/' + m[2]) : '';
  }

  function looksLikeRejectedAmpLabel(text, number) {
    if (!text || number === null || number === undefined) return false;
    var src = String(text);
    var n = String(number);
    var re = new RegExp('(?:MOCP|M\\.?O\\.?C\\.?P\\.?|MCA|SCA|LRA|L\\.?R\\.?A\\.?)\\s*[:#]?\\s*' + n.replace('.', '\\.') + '\\b', 'i');
    return re.test(src);
  }

  /**
   * Drop FLA when it is actually MOCP/LRA. Dual FLA stays in extras, not the
   * numeric fla field — NEC math still requires the user to pick one ampere.
   */
  function applyFlaTraps(draft, rawFla) {
    var fields = draft.fields;
    var flaValue = fields.fla.value;
    var mocp = fields.mocp.value;
    var lra = fields.lra.value;
    var dual = dualPair(rawFla) || dualPair(draft.extras.dualFla);
    if (dual) {
      draft.extras.dualFla = dual;
      draft.extras.flaDisplay = dual;
      fields.fla = emptyField();
      if (!fields.notes.value) {
        fields.notes = fieldFrom('Dual FLA ' + dual + ' — enter the amperes that match the voltage you are using.', 'string', 0.9);
      }
      return draft;
    }
    if (flaValue === null) return draft;
    if (mocp !== null && flaValue === mocp) {
      fields.fla = emptyField();
      draft.warnings.push('FLA was ignored because it matched MOCP. MOCP is not FLA.');
      return draft;
    }
    if (lra !== null && flaValue === lra) {
      fields.fla = emptyField();
      draft.warnings.push('FLA was ignored because it matched LRA. LRA is not FLA.');
      return draft;
    }
    if (looksLikeRejectedAmpLabel(draft.rawText, flaValue) && !/\bFLA\b|\bFL\s*AMPS?\b/i.test(draft.rawText)) {
      fields.fla = emptyField();
      draft.warnings.push('FLA was ignored because the only nearby amp label was MOCP/LRA/MCA.');
    }
    return draft;
  }

  function normalizeDraft(raw, opts) {
    opts = opts || {};
    var draft = emptyDraft();
    draft.source = opts.source || 'unknown';
    draft.rawText = asString(opts.rawText || (raw && raw.raw_ocr) || (raw && raw.rawText) || '') || '';
    draft.warnings = Array.isArray(opts.warnings) ? opts.warnings.map(String) : [];
    if (Array.isArray(raw && raw.warnings)) {
      raw.warnings.forEach(function (w) { draft.warnings.push(String(w)); });
    }

    var payload = raw && raw.fields && typeof raw.fields === 'object' ? raw.fields : (raw || {});
    var fallbackConf = opts.confidence === undefined || opts.confidence === null
      ? 0.5
      : clampConfidence(opts.confidence);
    var rawFla = unwrapRaw(payload.fla);

    FIELD_SPECS.forEach(function (spec) {
      var type = spec.name === 'designLetter' || spec.name === 'codeLetter' ? 'letter' : spec.type;
      var cell = payload[spec.name];
      draft.fields[spec.name] = fieldFrom(unwrapRaw(cell), type, rawConfidence(cell, fallbackConf));
    });

    if (payload.insulation !== undefined) draft.extras.insulation = asString(unwrapRaw(payload.insulation)) || '';
    if (payload.riseC !== undefined) draft.extras.riseC = asString(unwrapRaw(payload.riseC)) || '';
    if (payload.flaDisplay) draft.extras.flaDisplay = asString(payload.flaDisplay) || '';
    if (payload.dualFla) draft.extras.dualFla = asString(payload.dualFla) || '';

    applyFlaTraps(draft, rawFla);
    draft.filled = countFilled(draft.fields);
    if (draft.extras.dualFla) draft.filled += 1;
    return draft;
  }

  function fromLegacyParse(fields, opts) {
    fields = fields || {};
    return normalizeDraft({
      manufacturer: fields.manufacturer,
      model: fields.model,
      ratedHP: fields.hp,
      ratedKW: fields.kw,
      voltage: fields.volts,
      fla: fields.fla,
      sf: fields.sf,
      rpm: fields.rpm,
      poles: fields.poles,
      frequencyHz: fields.hz,
      phases: fields.phase,
      enclosure: fields.enclosure,
      frame: fields.frame,
      designLetter: fields.design,
      codeLetter: fields.code,
      nomEff: fields.nomEff,
      pf: fields.pf,
      mocp: fields.mocp,
      lra: fields.lra,
      serviceFactorAmps: fields.serviceFactorAmps,
      notes: fields.notes,
      insulation: fields.insulation,
      riseC: fields.riseC,
    }, {
      source: (opts && opts.source) || 'tesseract',
      rawText: opts && opts.rawText,
      confidence: opts && opts.confidence,
      warnings: opts && opts.warnings,
    });
  }

  function displayValue(field) {
    if (!field || field.value === null || field.value === undefined) return '';
    return String(field.value);
  }

  function toLegacyFields(draft) {
    draft = draft || emptyDraft();
    var f = draft.fields;
    var hz = displayValue(f.frequencyHz);
    return {
      hp: displayValue(f.ratedHP),
      kw: displayValue(f.ratedKW),
      volts: displayValue(f.voltage),
      fla: draft.extras.flaDisplay || displayValue(f.fla),
      rpm: displayValue(f.rpm),
      hz: hz || '60',
      phase: displayValue(f.phases),
      frame: displayValue(f.frame),
      sf: displayValue(f.sf),
      design: displayValue(f.designLetter),
      insulation: draft.extras.insulation || '',
      code: displayValue(f.codeLetter),
      riseC: draft.extras.riseC || '',
      manufacturer: displayValue(f.manufacturer),
      model: displayValue(f.model),
      enclosure: displayValue(f.enclosure),
      poles: displayValue(f.poles),
      nomEff: displayValue(f.nomEff),
      pf: displayValue(f.pf),
      mocp: displayValue(f.mocp),
      lra: displayValue(f.lra),
      serviceFactorAmps: displayValue(f.serviceFactorAmps),
      notes: displayValue(f.notes),
    };
  }

  function markReviewed(draft, reviewed) {
    var next = normalizeDraft({
      fields: draft && draft.fields,
      warnings: draft && draft.warnings,
      raw_ocr: draft && draft.rawText,
    }, { source: draft && draft.source, rawText: draft && draft.rawText });
    if (draft && draft.extras) next.extras = {
      flaDisplay: draft.extras.flaDisplay || '',
      insulation: draft.extras.insulation || '',
      riseC: draft.extras.riseC || '',
      dualFla: draft.extras.dualFla || '',
    };
    FIELD_NAMES.forEach(function (name) {
      if (next.fields[name].value !== null) next.fields[name].userReviewed = !!reviewed;
    });
    return next;
  }

  function lowConfidenceFields(draft, threshold) {
    var cut = threshold === undefined || threshold === null ? 0.6 : threshold;
    return FIELD_NAMES.filter(function (name) {
      var cell = draft && draft.fields && draft.fields[name];
      return cell && cell.value !== null && cell.confidence < cut;
    });
  }

  var PANEL_ROW_FIELDS = ['circuit', 'description', 'trip', 'poles', 'loadAmps', 'notes'];

  function emptyPanelRow() {
    var row = {};
    PANEL_ROW_FIELDS.forEach(function (name) { row[name] = emptyField(); });
    return row;
  }

  function normalizePanelDraft(raw, opts) {
    opts = opts || {};
    var rowsIn = (raw && (raw.circuits || raw.rows)) || [];
    if (!Array.isArray(rowsIn)) rowsIn = [];
    var fallbackConf = opts.confidence === undefined || opts.confidence === null
      ? 0.5
      : clampConfidence(opts.confidence);
    var rows = rowsIn.slice(0, 84).map(function (item) {
      var row = emptyPanelRow();
      var src = item && item.fields ? item.fields : item;
      PANEL_ROW_FIELDS.forEach(function (name) {
        var type = name === 'trip' || name === 'loadAmps' || name === 'poles' ? (name === 'poles' ? 'int' : 'number') : 'string';
        var cell = src && src[name];
        row[name] = fieldFrom(unwrapRaw(cell), type, rawConfidence(cell, fallbackConf));
      });
      // Trip is never a reviewed load from VLM.
      row.loadAmps = emptyField();
      return row;
    });
    var panelSrc = (raw && raw.panel) || {};
    var panel = {
      name: fieldFrom(unwrapRaw(panelSrc.name), 'string', rawConfidence(panelSrc.name, fallbackConf)),
      voltage: fieldFrom(unwrapRaw(panelSrc.voltage), 'string', rawConfidence(panelSrc.voltage, fallbackConf)),
      mainAmps: fieldFrom(unwrapRaw(panelSrc.mainAmps), 'number', rawConfidence(panelSrc.mainAmps, fallbackConf)),
      phases: fieldFrom(unwrapRaw(panelSrc.phases), 'int', rawConfidence(panelSrc.phases, fallbackConf)),
      location: fieldFrom(unwrapRaw(panelSrc.location), 'string', rawConfidence(panelSrc.location, fallbackConf)),
    };
    return {
      task: 'panel',
      rows: rows,
      panel: panel,
      source: opts.source || 'unknown',
      rawText: asString(opts.rawText || (raw && raw.raw_ocr) || '') || '',
      warnings: Array.isArray(raw && raw.warnings) ? raw.warnings.map(String) : (opts.warnings || []),
      filled: rows.filter(function (row) {
        return PANEL_ROW_FIELDS.some(function (name) { return row[name].value !== null; });
      }).length,
    };
  }

  global.BeckifyNameplateSchema = {
    FIELD_SPECS: FIELD_SPECS,
    FIELD_NAMES: FIELD_NAMES,
    PANEL_ROW_FIELDS: PANEL_ROW_FIELDS,
    REJECTED_AMP_AS_FLA: REJECTED_AMP_AS_FLA,
    emptyField: emptyField,
    emptyDraft: emptyDraft,
    normalizeDraft: normalizeDraft,
    fromLegacyParse: fromLegacyParse,
    toLegacyFields: toLegacyFields,
    markReviewed: markReviewed,
    lowConfidenceFields: lowConfidenceFields,
    normalizePanelDraft: normalizePanelDraft,
    emptyPanelRow: emptyPanelRow,
    clampConfidence: clampConfidence,
    dualPair: dualPair,
  };
  global.__nameplateSchemaTestApi = global.BeckifyNameplateSchema;
})(typeof window !== 'undefined' ? window : globalThis);
