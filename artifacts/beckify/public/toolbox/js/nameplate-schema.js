/* ============================================================================
   SHARED MOTOR NAMEPLATE DRAFT SCHEMA
   ============================================================================
   Website + iOS agree on these field names (string unless noted):
     manufacturer, model, serialNumber, ratedHP (number), ratedKW (number),
     voltage, fla (number), sf (number), rpm (number), poles (int),
     frequencyHz (number), phases (1|3), enclosure, frame, designLetter,
     codeLetter, nomEff (number), pf (number), mocp (number), lra (number),
     serviceFactorAmps (number), notes.

   Each extracted field is { value, confidence, userReviewed }. iOS JSON may
   send `reviewed` instead of `userReviewed` — both are accepted on ingest.
   OCR / VLM output is an assistive draft. userReviewed stays false until a
   human checks the review box. NEVER copy MOCP or LRA into FLA.
   ============================================================================ */
(function (global) {
  'use strict';

  var FIELD_SPECS = [
    { name: 'manufacturer', type: 'string', label: 'Manufacturer' },
    { name: 'model', type: 'string', label: 'Model' },
    { name: 'serialNumber', type: 'string', label: 'Serial' },
    { name: 'ratedHP', type: 'number', label: 'HP' },
    { name: 'ratedKW', type: 'number', label: 'kW' },
    { name: 'voltage', type: 'string', label: 'Voltage' },
    { name: 'fla', type: 'number', label: 'FLA' },
    { name: 'sf', type: 'number', label: 'Service factor' },
    { name: 'rpm', type: 'number', label: 'RPM' },
    { name: 'poles', type: 'int', label: 'Poles' },
    { name: 'frequencyHz', type: 'number', label: 'Frequency' },
    { name: 'phases', type: 'phases', label: 'Phase' },
    { name: 'enclosure', type: 'string', label: 'Enclosure' },
    { name: 'frame', type: 'string', label: 'Frame' },
    { name: 'designLetter', type: 'string', label: 'Design letter' },
    { name: 'codeLetter', type: 'string', label: 'Code letter' },
    { name: 'nomEff', type: 'number', label: 'Nom. efficiency' },
    { name: 'pf', type: 'pf', label: 'Power factor' },
    { name: 'mocp', type: 'number', label: 'MOCP' },
    { name: 'lra', type: 'number', label: 'LRA' },
    { name: 'serviceFactorAmps', type: 'number', label: 'SF amps' },
    { name: 'notes', type: 'string', label: 'Notes' },
  ];

  var FIELD_NAMES = FIELD_SPECS.map(function (spec) { return spec.name; });
  var FIELD_LABELS = {};
  FIELD_SPECS.forEach(function (spec) { FIELD_LABELS[spec.name] = spec.label; });
  var REJECTED_AMP_AS_FLA = /(?:MOCP|M\.?O\.?C\.?P\.?|MCA|SCA|LRA|L\.?R\.?A\.?|AIC|KAIC|SCCR)/i;
  var DUAL_NUMBER = /^([0-9]+(?:\.[0-9]+)?)\/([0-9]+(?:\.[0-9]+)?)$/;
  var FLA_NEAR_LABEL = /(?:FLA|FL\s*AMPS?|FULL[\s-]*LOAD(?:\s*AMPS?)?|\bAMP(?:S|ERES)?)\b/i;

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
    if (typeof value === 'string') {
      var s = value.trim().toUpperCase();
      if (/^(?:1|1\.0|1P|1PH|1PHASE|1Ø|SINGLE)$/.test(s)) return 1;
      if (/^(?:3|3\.0|3P|3PH|3PHASE|3Ø|THREE)$/.test(s)) return 3;
    }
    var n = asInt(value);
    return n === 1 || n === 3 ? n : null;
  }

  function asPowerFactor(value) {
    var n = asNumber(value);
    if (n === null) return null;
    if (n > 1 && n <= 100) n = n / 100;
    if (n <= 0 || n > 1) return null;
    return Math.round(n * 1000) / 1000;
  }

  function fieldLabel(name) {
    return FIELD_LABELS[name] || name;
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
    else if (type === 'pf') value = asPowerFactor(raw);
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
      extras: { flaDisplay: '', insulation: '', riseC: '', dualFla: '', ieClass: '', connection: '', ipRating: '' },
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

  function escapeRegExp(value) {
    return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function looksLikeRejectedAmpLabel(text, number) {
    if (!text || number === null || number === undefined) return false;
    var src = String(text);
    var n = String(number);
    var labeled = new RegExp(
      '(?:MOCP|M\\.?O\\.?C\\.?P\\.?|MCA|SCA|LRA|L\\.?R\\.?A\\.?)\\s*[:#]?\\s*' + escapeRegExp(n) + '\\b',
      'i'
    );
    if (labeled.test(src)) return true;
    var hitRe = new RegExp(escapeRegExp(n), 'g');
    var match;
    var rejectedNear = false;
    var flaNear = false;
    while ((match = hitRe.exec(src))) {
      var before = src.slice(Math.max(0, match.index - 28), match.index);
      var after = src.slice(match.index + n.length, match.index + n.length + 18);
      if (REJECTED_AMP_AS_FLA.test(before) || REJECTED_AMP_AS_FLA.test(after)) rejectedNear = true;
      if (FLA_NEAR_LABEL.test(before) || FLA_NEAR_LABEL.test(after)) flaNear = true;
    }
    return rejectedNear && !flaNear;
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
    if (looksLikeRejectedAmpLabel(draft.rawText, flaValue)) {
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

    var envelope = raw && typeof raw === 'object' ? raw : {};
    var payload = envelope.fields && typeof envelope.fields === 'object' ? envelope.fields : envelope;
    var fallbackConf = opts.confidence === undefined || opts.confidence === null
      ? 0.5
      : clampConfidence(opts.confidence);
    var rawFla = unwrapRaw(payload.fla);

    FIELD_SPECS.forEach(function (spec) {
      var type = spec.name === 'designLetter' || spec.name === 'codeLetter' ? 'letter' : spec.type;
      var cell = payload[spec.name];
      draft.fields[spec.name] = fieldFrom(unwrapRaw(cell), type, rawConfidence(cell, fallbackConf));
    });

    function extraFrom(key) {
      if (payload[key] !== undefined) return asString(unwrapRaw(payload[key])) || '';
      if (envelope !== payload && envelope[key] !== undefined) return asString(unwrapRaw(envelope[key])) || '';
      return '';
    }
    if (payload.insulation !== undefined || envelope.insulation !== undefined) {
      draft.extras.insulation = extraFrom('insulation');
    }
    if (!draft.extras.insulation && (payload.insulationClass !== undefined || envelope.insulationClass !== undefined)) {
      draft.extras.insulation = extraFrom('insulationClass');
    }
    if (payload.riseC !== undefined || envelope.riseC !== undefined) {
      draft.extras.riseC = extraFrom('riseC');
    }
    if (payload.flaDisplay || envelope.flaDisplay) {
      draft.extras.flaDisplay = extraFrom('flaDisplay');
    }
    if (payload.dualFla || envelope.dualFla) {
      draft.extras.dualFla = extraFrom('dualFla');
    }
    if (payload.ieClass || envelope.ieClass) {
      draft.extras.ieClass = extraFrom('ieClass');
    }
    if (payload.connection || envelope.connection) {
      draft.extras.connection = extraFrom('connection');
    }
    if (payload.ipRating || envelope.ipRating) {
      draft.extras.ipRating = extraFrom('ipRating');
    }

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
      serialNumber: fields.serialNumber || fields.serial,
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
      ieClass: fields.ieClass || (opts && opts.extras && opts.extras.ieClass),
      connection: fields.connection || (opts && opts.extras && opts.extras.connection),
      ipRating: fields.ipRating || (opts && opts.extras && opts.extras.ipRating),
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
      hz: hz,
      phase: displayValue(f.phases),
      frame: displayValue(f.frame),
      sf: displayValue(f.sf),
      design: displayValue(f.designLetter),
      insulation: draft.extras.insulation || '',
      code: displayValue(f.codeLetter),
      riseC: draft.extras.riseC || '',
      manufacturer: displayValue(f.manufacturer),
      model: displayValue(f.model),
      serialNumber: displayValue(f.serialNumber),
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
      ieClass: draft.extras.ieClass || '',
      connection: draft.extras.connection || '',
      ipRating: draft.extras.ipRating || '',
    };
    FIELD_NAMES.forEach(function (name) {
      if (next.fields[name].value !== null) {
        next.fields[name].userReviewed = !!reviewed;
        next.fields[name].reviewed = !!reviewed;
      }
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

  function lowConfidenceLabels(draft, threshold) {
    return lowConfidenceFields(draft, threshold).map(fieldLabel);
  }

  /**
   * Honest reasons a field is yellow. These are review hints, not validation
   * errors — do not treat them as aria-invalid.
   */
  function highlightReasons(draft, threshold) {
    var reasons = [];
    var seen = {};
    function add(name, kind, reason) {
      var key = name + ':' + kind;
      if (seen[key]) return;
      seen[key] = true;
      reasons.push({
        name: name,
        label: fieldLabel(name),
        kind: kind,
        reason: reason,
      });
    }
    if (draft && draft.extras && draft.extras.dualFla) {
      add('fla', 'dual-fla', 'Dual FLA ' + draft.extras.dualFla + ' — pick one ampere. NEC math cannot use a pair.');
    }
    if (!draft || !draft.fields || !draft.fields.phases || draft.fields.phases.value == null) {
      add('phases', 'missing-phase', 'Phase was not printed. Unknown until you enter 1 or 3.');
    }
    if (draft && draft.extras && draft.extras.ieClass) {
      add('nomEff', 'ie-class', 'Plate shows IEC class ' + draft.extras.ieClass + ', not a percent. Do not treat the class as efficiency.');
    }
    lowConfidenceFields(draft, threshold).forEach(function (name) {
      var cell = draft.fields[name];
      var pct = Math.round((cell && cell.confidence ? cell.confidence : 0) * 100);
      add(name, 'low-confidence', 'OCR confidence ' + pct + '% — glare, stamp depth, or rotation made this uncertain.');
    });
    if (draft && Array.isArray(draft.warnings)) {
      draft.warnings.forEach(function (warning) {
        if (/FLA was ignored/i.test(warning)) {
          add('fla', 'trap', String(warning));
        }
      });
    }
    return reasons;
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
      phases: fieldFrom(unwrapRaw(panelSrc.phases), 'phases', rawConfidence(panelSrc.phases, fallbackConf)),
      location: fieldFrom(unwrapRaw(panelSrc.location), 'string', rawConfidence(panelSrc.location, fallbackConf)),
    };
    if (!panel.mainAmps.value && (panelSrc.busAmps !== undefined || panelSrc.busRating !== undefined)) {
      panel.mainAmps = fieldFrom(unwrapRaw(panelSrc.busAmps || panelSrc.busRating), 'number', rawConfidence(panelSrc.busAmps || panelSrc.busRating, fallbackConf));
    }
    var slotRaw = raw && (raw.slotCount != null ? raw.slotCount : (raw.slot_count != null ? raw.slot_count : (panelSrc.slotCount != null ? panelSrc.slotCount : panelSrc.spaces)));
    var slotCount = Number(typeof slotRaw === 'object' && slotRaw ? slotRaw.value : slotRaw);
    if (!Number.isFinite(slotCount) || slotCount < 6) slotCount = 0;
    else slotCount = Math.min(84, Math.round(slotCount));
    return {
      task: 'panel',
      rows: rows,
      panel: panel,
      slotCount: slotCount,
      source: opts.source || 'unknown',
      rawText: asString(opts.rawText || (raw && raw.raw_ocr) || '') || '',
      warnings: Array.isArray(raw && raw.warnings) ? raw.warnings.map(String) : (opts.warnings || []),
      filled: rows.filter(function (row) {
        return PANEL_ROW_FIELDS.some(function (name) { return row[name].value !== null; });
      }).length,
    };
  }

  function normalizeCircuitKey(value) {
    var raw = value == null ? '' : String(value).trim().toUpperCase();
    if (!raw) return '';
    var m = raw.match(/^0*(\d{1,2})([A-Z])?$/);
    if (!m) return raw;
    return String(Number(m[1])) + (m[2] || '');
  }

  function circuitKey(row) {
    var cell = row && row.circuit;
    var value = cell && typeof cell === 'object' ? cell.value : cell;
    return normalizeCircuitKey(value);
  }

  function rowHasValue(row, name) {
    var cell = row && row[name];
    if (!cell) return false;
    return cell.value !== null && cell.value !== '';
  }

  var TYPICAL_PANEL_SLOTS = [8, 12, 16, 18, 20, 24, 30, 32, 36, 40, 42, 48, 54, 60, 72, 84];

  function snapPanelSlots(n) {
    n = Number(n);
    if (!Number.isFinite(n) || n < 6) return 0;
    n = Math.min(84, Math.round(n));
    var best = n;
    var bestDist = Infinity;
    TYPICAL_PANEL_SLOTS.forEach(function (typical) {
      var dist = Math.abs(typical - n);
      if (dist < bestDist || (dist === bestDist && typical >= n)) {
        bestDist = dist;
        best = typical;
      }
    });
    return bestDist <= 2 ? best : n;
  }

  function collectCircuitNumbers(draft) {
    var seen = {};
    var nums = [];
    (draft && draft.rows || []).forEach(function (row) {
      var n = Number(circuitKey(row));
      if (!Number.isFinite(n) || n < 1 || n > 84) return;
      var rounded = Math.round(n);
      if (seen[rounded]) return;
      seen[rounded] = true;
      nums.push(rounded);
    });
    return nums;
  }

  function mergeSlotCounts(left, right) {
    var a = Number(left && left.slotCount) || 0;
    var b = Number(right && right.slotCount) || 0;
    var ca = collectCircuitNumbers(left);
    var cb = collectCircuitNumbers(right);
    var unionMap = {};
    var overlap = 0;
    var maxCovered = 0;
    ca.forEach(function (n) { unionMap[n] = true; });
    cb.forEach(function (n) {
      if (unionMap[n]) overlap += 1;
      else unionMap[n] = true;
    });
    Object.keys(unionMap).forEach(function (key) {
      var n = Number(key);
      if (n > maxCovered) maxCovered = n;
    });
    var unionSize = Object.keys(unionMap).length;
    var combined;
    var bothPartial = a > 0 && b > 0 && a < 30 && b < 30;
    if (ca.length && cb.length) {
      var smaller = Math.min(ca.length, cb.length);
      /* Sum only when both reads look like panel halves. Two full-panel
         OCR passes can cover disjoint circuit numbers and still each
         report 42 — those must stay 42, not 84. */
      if (bothPartial && smaller && (overlap / smaller) < 0.35) {
        combined = Math.max(a + b, unionSize, maxCovered);
        return snapPanelSlots(combined) || combined;
      }
      combined = Math.max(a, b, maxCovered, unionSize);
      return snapPanelSlots(combined) || combined;
    }
    /* Two partial-looking counts with no shared circuit numbers are treated
       as different halves (21 + 21 → 42). Two full-panel reads stay at max. */
    if (a > 0 && b > 0 && a < 30 && b < 30 && !overlap) {
      combined = a + b;
      return snapPanelSlots(combined) || combined;
    }
    combined = Math.max(a, b, maxCovered);
    return snapPanelSlots(combined) || combined || 0;
  }

  function circuitSortNumber(key) {
    if (!key) return Infinity;
    var n = Number(String(key).replace(/[A-Z]/g, ''));
    return Number.isFinite(n) && n > 0 ? n : Infinity;
  }

  function sortPanelRows(rows) {
    return (rows || []).slice().sort(function (a, b) {
      var ka = circuitKey(a);
      var kb = circuitKey(b);
      var na = circuitSortNumber(ka);
      var nb = circuitSortNumber(kb);
      if (na !== nb) return na - nb;
      return ka.localeCompare(kb);
    });
  }

  /**
   * Print/CSV sanity: never emit trip as loadAmps, keep unknown phase honest,
   * and include the merged slot count + source.
   */
  function exportPanelDraft(draft, opts) {
    opts = opts || {};
    var normalized = normalizePanelDraft(draft || {}, opts);
    var rows = sortPanelRows(normalized.rows);
    var warnings = (normalized.warnings || []).slice();
    if (!normalized.panel.phases || normalized.panel.phases.value == null) {
      warnings.push('Phase is unknown. Load math stays gated until 1 or 3 is selected.');
    }
    var rawRows = (draft && (draft.circuits || draft.rows)) || [];
    var clearedLoad = false;
    rawRows.forEach(function (item) {
      var src = item && item.fields ? item.fields : item;
      var loadCell = src && src.loadAmps;
      var loadVal = loadCell && typeof loadCell === 'object' ? loadCell.value : loadCell;
      if (loadVal != null && loadVal !== '') clearedLoad = true;
    });
    if (clearedLoad) {
      warnings.push('loadAmps was cleared — trip is not a reviewed load.');
    }
    var lines = ['circuit,description,trip,poles,loadAmps,notes'];
    rows.forEach(function (row) {
      var trip = row.trip && row.trip.value != null ? String(row.trip.value) : '';
      var load = '';
      lines.push([
        circuitKey(row) || '',
        String((row.description && row.description.value) || '').replace(/,/g, ' '),
        trip,
        row.poles && row.poles.value != null ? String(row.poles.value) : '',
        load,
        String((row.notes && row.notes.value) || '').replace(/,/g, ' '),
      ].join(','));
    });
    return {
      csv: lines.join('\n'),
      slotCount: normalized.slotCount,
      source: normalized.source || opts.source || '',
      phase: normalized.panel.phases && normalized.panel.phases.value != null
        ? normalized.panel.phases.value
        : null,
      warnings: warnings,
      rowCount: rows.length,
    };
  }

  function mergePanelDrafts(base, incoming) {
    var left = normalizePanelDraft(base || {});
    var right = normalizePanelDraft(incoming || {});
    var byKey = {};
    var order = [];
    function take(row) {
      var key = circuitKey(row);
      if (key && row.circuit && typeof row.circuit === 'object') {
        row.circuit.value = key;
      }
      if (!key) {
        order.push(row);
        return;
      }
      if (!byKey[key]) {
        byKey[key] = row;
        order.push(row);
        return;
      }
      var dest = byKey[key];
      PANEL_ROW_FIELDS.forEach(function (name) {
        if (name === 'loadAmps') return;
        if (!rowHasValue(dest, name) && rowHasValue(row, name)) dest[name] = row[name];
      });
    }
    left.rows.forEach(take);
    right.rows.forEach(take);
    order = sortPanelRows(order);
    var panel = left.panel;
    ['name', 'voltage', 'mainAmps', 'phases', 'location'].forEach(function (name) {
      if ((!panel[name] || panel[name].value == null) && right.panel[name] && right.panel[name].value != null) {
        panel[name] = right.panel[name];
      }
    });
    var warnings = left.warnings.concat(right.warnings);
    var rawParts = [left.rawText, right.rawText].filter(Boolean);
    return {
      task: 'panel',
      rows: order.slice(0, 84),
      panel: panel,
      slotCount: mergeSlotCounts(left, right),
      source: right.source || left.source || 'merged',
      rawText: rawParts.join('\n'),
      warnings: warnings,
      filled: order.filter(function (row) {
        return PANEL_ROW_FIELDS.some(function (name) { return rowHasValue(row, name); });
      }).length,
    };
  }

  global.BeckifyNameplateSchema = {
    FIELD_SPECS: FIELD_SPECS,
    FIELD_NAMES: FIELD_NAMES,
    FIELD_LABELS: FIELD_LABELS,
    PANEL_ROW_FIELDS: PANEL_ROW_FIELDS,
    REJECTED_AMP_AS_FLA: REJECTED_AMP_AS_FLA,
    emptyField: emptyField,
    emptyDraft: emptyDraft,
    normalizeDraft: normalizeDraft,
    fromLegacyParse: fromLegacyParse,
    toLegacyFields: toLegacyFields,
    markReviewed: markReviewed,
    lowConfidenceFields: lowConfidenceFields,
    lowConfidenceLabels: lowConfidenceLabels,
    highlightReasons: highlightReasons,
    fieldLabel: fieldLabel,
    normalizePanelDraft: normalizePanelDraft,
    mergePanelDrafts: mergePanelDrafts,
    mergeSlotCounts: mergeSlotCounts,
    normalizeCircuitKey: normalizeCircuitKey,
    sortPanelRows: sortPanelRows,
    exportPanelDraft: exportPanelDraft,
    emptyPanelRow: emptyPanelRow,
    clampConfidence: clampConfidence,
    dualPair: dualPair,
    asPowerFactor: asPowerFactor,
    asPhases: asPhases,
    applyFlaTraps: applyFlaTraps,
  };
  global.__nameplateSchemaTestApi = global.BeckifyNameplateSchema;
})(typeof window !== 'undefined' ? window : globalThis);
