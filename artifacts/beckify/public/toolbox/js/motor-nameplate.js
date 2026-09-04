/* ============================================================================
   MOTOR NAMEPLATE ANALYZER
   ============================================================================
   Optional on-device OCR (shared BeckifyOcr helper) fills editable fields.
   Calculations run only after the user confirms review. Citations:
     NEC 430.32  overload (separate device) as % of nameplate FLA
     NEC 430.52  Table 430.52 motor branch-circuit SCPD maximum % of FLA
     NEC 430.22  branch-circuit conductor ampacity ≥ 125% of FLA
     NEC 430.7(B) / NEMA MG-1 code letter → locked-rotor kVA/HP range
   ============================================================================ */
(function (global) {
  'use strict';

  /* NEC 430.32(A)(1) — motors more than 1 hp, separate overload device.
     Service factor 1.15 or greater, OR marked temperature rise 40°C or less:
     125%. All other motors: 115%. */
  function overloadPercent(sf, riseC) {
    var s = Number(sf);
    var rise = Number(riseC);
    if ((Number.isFinite(s) && s >= 1.15) || (Number.isFinite(rise) && rise > 0 && rise <= 40)) {
      return { pct: 125, article: 'NEC 430.32(A)(1)', reason: 'SF ≥ 1.15 or temperature rise ≤ 40°C' };
    }
    return { pct: 115, article: 'NEC 430.32(A)(1)', reason: 'all other motors' };
  }

  function overloadNextHigherPercent(sf, riseC) {
    var s = Number(sf);
    var rise = Number(riseC);
    if ((Number.isFinite(s) && s >= 1.15) || (Number.isFinite(rise) && rise > 0 && rise <= 40)) {
      return { pct: 140, article: 'NEC 430.32(C)' };
    }
    return { pct: 130, article: 'NEC 430.32(C)' };
  }

  /* NEC Table 430.52 — maximum rating or setting as % of motor FLA.
     Columns: nontime-delay fuse, dual-element time-delay fuse,
     instantaneous-trip breaker, inverse-time breaker.
     Labels follow current Table 430.52 squirrel-cage rows (other than
     Design B energy-efficient / premium-efficiency vs that Design B
     energy-efficient and premium-efficiency row). Design D/E are not
     listed as the 800% row. Percentages are unchanged. Part-winding
     percentages are kept only as an older-cycle Table 430.52 row — they
     are not claimed as current 430.52(C)(1). */
  var TABLE_430_52 = {
    '1ph': { label: 'Single-phase AC, all types', ntd: 300, td: 175, inst: 800, inv: 250, article: 'NEC Table 430.52' },
    'sc-bde': { label: 'AC squirrel-cage other than Design B energy-efficient / premium-efficiency', ntd: 300, td: 175, inst: 800, inv: 250, article: 'NEC Table 430.52' },
    'sc-ee': { label: 'AC squirrel-cage Design B energy-efficient or premium-efficiency', ntd: 300, td: 175, inst: 1100, inv: 250, article: 'NEC Table 430.52' },
    'sync': { label: 'AC synchronous (full-voltage, resistor or reactor start)', ntd: 300, td: 175, inst: 800, inv: 250, article: 'NEC Table 430.52' },
    'sync-pw': { label: 'AC synchronous (part-winding, older Table 430.52)', ntd: 150, td: 150, inst: 800, inv: 200, article: 'older NEC Table 430.52 (part-winding)' },
    'wound': { label: 'AC wound-rotor', ntd: 150, td: 150, inst: 800, inv: 150, article: 'NEC Table 430.52' },
    'dc': { label: 'DC (constant voltage)', ntd: 150, td: 150, inst: 250, inv: 150, article: 'NEC Table 430.52' },
  };

  function table43052Row(motorType) {
    return TABLE_430_52[motorType] || TABLE_430_52['sc-bde'];
  }

  function scpdFromFla(fla, motorType, device) {
    var row = table43052Row(motorType);
    var allowed = { ntd: 'ntd', td: 'td', inst: 'inst', inv: 'inv' };
    var key = allowed[device] || 'inv';
    var pct = row[key];
    var raw = Number(fla) * (pct / 100);
    var next = (typeof nextStandardOCPD === 'function') ? nextStandardOCPD(raw) : null;
    return {
      pct: pct,
      raw: raw,
      next: next,
      article: row.article,
      label: row.label,
      device: key,
    };
  }

  /* NEMA MG-1 Table 10-1 code letters, also referenced by NEC 430.7(B).
     Values are locked-rotor kVA per horsepower ranges. */
  var CODE_LETTER = {
    A: [0, 3.14], B: [3.15, 3.54], C: [3.55, 3.99], D: [4.0, 4.49],
    E: [4.5, 4.99], F: [5.0, 5.59], G: [5.6, 6.29], H: [6.3, 7.09],
    J: [7.1, 7.99], K: [8.0, 8.99], L: [9.0, 9.99], M: [10.0, 11.19],
    N: [11.2, 12.49], P: [12.5, 13.99], R: [14.0, 15.99], S: [16.0, 17.99],
    T: [18.0, 19.99], U: [20.0, 22.39], V: [22.4, Infinity],
  };

  function lockedRotorRange(letter, hp, volts, phase) {
    var key = String(letter || '').trim().toUpperCase();
    var range = CODE_LETTER[key];
    if (!range) return { error: 'No NEMA code letter, so locked-rotor current is not estimated from the table.' };
    var ph = parsePhase(phase);
    if (!ph) {
      return { error: 'Select 1-phase or 3-phase before estimating locked-rotor current. Phase is never assumed.', letter: key, kvaMin: range[0], kvaMax: range[1] === Infinity ? null : range[1] };
    }
    var P = Number(hp);
    var V = Number(String(volts || '').split('/')[0]);
    if (!Number.isFinite(P) || P <= 0 || !Number.isFinite(V) || V <= 0) {
      return { error: 'HP and voltage are needed to convert the code-letter kVA/HP range into amperes.', letter: key, kvaMin: range[0], kvaMax: range[1] };
    }
    function amps(kvaPerHp) {
      var va = kvaPerHp * P * 1000;
      return ph === 3 ? va / (Math.sqrt(3) * V) : va / V;
    }
    return {
      letter: key,
      kvaMin: range[0],
      kvaMax: range[1] === Infinity ? null : range[1],
      ampsMin: amps(range[0]),
      ampsMax: range[1] === Infinity ? null : amps(range[1]),
      article: 'NEC 430.7(B); NEMA MG-1 Table 10-1',
      note: 'Table range, not a substitute for manufacturer locked-rotor amperes (LRA).',
    };
  }

  function hpFromKw(kw) { return Number(kw) / 0.746; }

  function parsePhase(value) {
    var n = Number(value);
    if (n === 1 || n === 3) return n;
    return null;
  }

  function analyze(input) {
    var flaRaw = String(input.fla == null ? '' : input.fla).trim();
    if (/[\/,]/.test(flaRaw)) {
      return { error: 'This nameplate lists dual FLA. Enter the amperes that match the voltage you are using. Do not leave a paired value for NEC 430 calculations.' };
    }
    var fla = Number(flaRaw);
    if (!Number.isFinite(fla) || fla <= 0) return { error: 'Enter a positive nameplate FLA after you review the fields.' };
    var ph = parsePhase(input.phase);
    if (!ph) return { error: 'Select 1-phase or 3-phase before calculating. OCR leaves phase blank when it cannot read it. Phase is never assumed.' };
    var hp = Number(input.hp);
    if ((!Number.isFinite(hp) || hp <= 0) && Number(input.kw) > 0) hp = hpFromKw(input.kw);
    var ol = overloadPercent(input.sf, input.riseC);
    var olNext = overloadNextHigherPercent(input.sf, input.riseC);
    var scpd = scpdFromFla(fla, input.motorType || 'sc-bde', input.device || 'inv');
    var cond = (global.BeckifyWireMath && typeof global.BeckifyWireMath.suggestSizeForFla === 'function')
      ? global.BeckifyWireMath.suggestSizeForFla(fla, input.material || 'cu')
      : null;
    var vd = null;
    var length = Number(input.lengthFt);
    if (cond && Number.isFinite(length) && length > 0 && global.BeckifyWireMath && global.BeckifyWireMath.voltageDropVolts) {
      var volts = Number(String(input.volts || '').split('/')[0]);
      var phaseKey = ph === 1 ? '1ph' : '3ph';
      if (Number.isFinite(volts) && volts > 0) {
        var drop = global.BeckifyWireMath.voltageDropVolts(cond.size, input.material || 'cu', phaseKey, fla, length, 1, 1);
        if (drop !== undefined && drop !== null) vd = { volts: drop, pct: (drop / volts) * 100, lengthFt: length, article: 'NEC Ch.9 Tables 8 and 9 (DC resistance / reactance)' };
      }
    }
    var lra = lockedRotorRange(input.code, hp, input.volts, ph);
    return {
      fla: fla,
      hp: hp,
      overload: ol,
      overloadAmps: fla * ol.pct / 100,
      overloadNext: olNext,
      overloadNextAmps: fla * olNext.pct / 100,
      scpd: scpd,
      conductor: cond,
      voltageDrop: vd,
      lockedRotor: lra,
      math: [
        'Overload setting ≤ ' + ol.pct + '% × FLA = ' + ol.pct + '% × ' + fla + ' A = ' + (fla * ol.pct / 100).toFixed(1) + ' A  (' + ol.article + ', ' + ol.reason + ')',
        'If that will not start the motor, NEC 430.32(C) allows the next higher size not exceeding ' + olNext.pct + '% = ' + (fla * olNext.pct / 100).toFixed(1) + ' A',
        'SCPD maximum = ' + scpd.pct + '% × ' + fla + ' A = ' + scpd.raw.toFixed(1) + ' A  (' + scpd.article + ', ' + scpd.label + ')',
        cond ? 'Conductor ampacity ≥ 125% × FLA = 1.25 × ' + fla + ' A = ' + cond.required.toFixed(1) + ' A → ' + cond.size + ' ' + (cond.material === 'al' ? 'Al' : 'Cu') + ' 75°C lists ' + cond.ampacity + ' A (NEC 430.22, Table 310.16)' : 'Conductor size needs BeckifyWireMath (NEC Table 310.16).',
      ],
    };
  }

  function el(id) { return document.getElementById(id); }
  function val(id) { return el(id) ? el(id).value : ''; }
  function setVal(id, v) { if (el(id) && v !== undefined && v !== null && v !== '') el(id).value = v; }
  function fmt(x, d) { return Number.isFinite(x) ? Number(x).toLocaleString('en-US', { maximumFractionDigits: d === undefined || d === null ? 1 : d }) : '—'; }

  var photoUrl = '';

  function gather() {
    return {
      hp: val('mnp_hp'),
      kw: val('mnp_kw'),
      volts: val('mnp_volts'),
      fla: val('mnp_fla'),
      rpm: val('mnp_rpm'),
      hz: val('mnp_hz'),
      phase: val('mnp_phase'),
      frame: val('mnp_frame'),
      sf: val('mnp_sf'),
      design: val('mnp_design'),
      insulation: val('mnp_insul'),
      code: val('mnp_code'),
      riseC: val('mnp_rise'),
      motorType: val('mnp_type'),
      device: val('mnp_device'),
      material: val('mnp_mat'),
      lengthFt: val('mnp_length'),
    };
  }

  var PARSED_FIELD_IDS = [
    'mnp_hp', 'mnp_kw', 'mnp_volts', 'mnp_fla', 'mnp_rpm', 'mnp_hz', 'mnp_phase',
    'mnp_frame', 'mnp_sf', 'mnp_design', 'mnp_insul', 'mnp_code', 'mnp_rise',
    'mnp_mfr', 'mnp_model', 'mnp_serial', 'mnp_encl', 'mnp_poles', 'mnp_eff', 'mnp_pf',
    'mnp_mocp', 'mnp_lra', 'mnp_sfa', 'mnp_notes',
  ];
  var FIELD_ID_BY_NAME = {
    ratedHP: 'mnp_hp',
    ratedKW: 'mnp_kw',
    voltage: 'mnp_volts',
    fla: 'mnp_fla',
    rpm: 'mnp_rpm',
    frequencyHz: 'mnp_hz',
    phases: 'mnp_phase',
    frame: 'mnp_frame',
    sf: 'mnp_sf',
    designLetter: 'mnp_design',
    insulation: 'mnp_insul',
    codeLetter: 'mnp_code',
    manufacturer: 'mnp_mfr',
    model: 'mnp_model',
    serialNumber: 'mnp_serial',
    enclosure: 'mnp_encl',
    poles: 'mnp_poles',
    nomEff: 'mnp_eff',
    pf: 'mnp_pf',
    mocp: 'mnp_mocp',
    lra: 'mnp_lra',
    serviceFactorAmps: 'mnp_sfa',
    notes: 'mnp_notes',
  };
  var lastDraft = null;
  var lastSourceKind = '';
  var lastProgress = 0;

  function clearParsedFields() {
    for (var i = 0; i < PARSED_FIELD_IDS.length; i++) {
      var n = el(PARSED_FIELD_IDS[i]);
      if (n) n.value = '';
    }
  }

  function applyFields(fields) {
    clearParsedFields();
    setVal('mnp_hp', fields.hp);
    setVal('mnp_kw', fields.kw);
    setVal('mnp_volts', fields.volts);
    setVal('mnp_fla', fields.fla);
    setVal('mnp_rpm', fields.rpm);
    setVal('mnp_hz', fields.hz);
    if (fields.phase === '1' || fields.phase === '3') setVal('mnp_phase', fields.phase);
    setVal('mnp_frame', fields.frame);
    setVal('mnp_sf', fields.sf);
    setVal('mnp_design', fields.design);
    setVal('mnp_insul', fields.insulation);
    setVal('mnp_code', fields.code);
    setVal('mnp_rise', fields.riseC);
    setVal('mnp_mfr', fields.manufacturer);
    setVal('mnp_model', fields.model);
    setVal('mnp_serial', fields.serialNumber);
    setVal('mnp_encl', fields.enclosure);
    setVal('mnp_poles', fields.poles);
    setVal('mnp_eff', fields.nomEff);
    setVal('mnp_pf', fields.pf);
    setVal('mnp_mocp', fields.mocp);
    setVal('mnp_lra', fields.lra);
    setVal('mnp_sfa', fields.serviceFactorAmps);
    setVal('mnp_notes', fields.notes);
  }

  function renderDraftNotes(draft) {
    var Schema = global.BeckifyNameplateSchema;
    var conf = el('mnp_conf');
    if (!conf) return;
    var lows = Schema && draft && typeof Schema.lowConfidenceLabels === 'function'
      ? Schema.lowConfidenceLabels(draft, 0.6)
      : (Schema && draft && Schema.lowConfidenceFields ? Schema.lowConfidenceFields(draft, 0.6) : []);
    var parts = [];
    if (lows.length) parts.push('Low-confidence draft fields: ' + lows.join(', ') + '. Correct them before NEC math.');
    if (draft && draft.warnings && draft.warnings.length) parts.push(draft.warnings.join(' '));
    if (draft && draft.extras && draft.extras.dualFla) {
      parts.push('Dual FLA ' + draft.extras.dualFla + ' — pick one ampere for the voltage you are using.');
    }
    if (parts.length) {
      conf.hidden = false;
      conf.textContent = parts.join(' ');
    } else {
      conf.hidden = true;
      conf.textContent = '';
    }
  }

  function applyDraft(draft) {
    lastDraft = draft || null;
    var Schema = global.BeckifyNameplateSchema;
    var fields = Schema && draft ? Schema.toLegacyFields(draft) : (draft && draft.fields) || {};
    applyFields(fields);
    highlightDraftFields(draft);
    renderHighlightReasons(draft);
    renderDualFlaChooser(draft);
    renderDraftNotes(draft);
  }

  function pickDualFlaAmp(amp) {
    var picked = String(amp || '').replace(/\s*A\s*$/i, '').trim();
    if (!picked) return false;
    setVal('mnp_fla', picked);
    if (lastDraft && lastDraft.fields) {
      var cell = lastDraft.fields.fla;
      if (cell && typeof cell === 'object') {
        lastDraft.fields.fla = {
          value: picked,
          confidence: cell.confidence,
          userReviewed: cell.userReviewed,
          reviewed: cell.reviewed,
        };
      } else {
        lastDraft.fields.fla = { value: picked, confidence: 1, userReviewed: false };
      }
    }
    if (lastDraft && lastDraft.extras && typeof lastDraft.extras === 'object') {
      lastDraft.extras.dualFla = '';
      lastDraft.extras.flaDisplay = picked;
    }
    highlightDraftFields(lastDraft);
    renderHighlightReasons(lastDraft);
    renderDualFlaChooser(lastDraft);
    renderDraftNotes(lastDraft);
    clearReview();
    setStatus('Using ' + picked + ' A. Confirm phase and voltage before calculating.');
    return true;
  }

  function highlightDraftFields(draft) {
    PARSED_FIELD_IDS.forEach(function (id) {
      var node = el(id);
      if (!node) return;
      node.classList.remove('ocr-low-conf');
      node.removeAttribute('title');
      if (node.getAttribute('aria-describedby') === 'mnp_why') {
        node.removeAttribute('aria-describedby');
      }
    });
    var Schema = global.BeckifyNameplateSchema;
    if (!Schema || !draft) return;
    var reasons = typeof Schema.highlightReasons === 'function'
      ? Schema.highlightReasons(draft, 0.6)
      : [];
    var byName = {};
    reasons.forEach(function (item) {
      if (!byName[item.name]) byName[item.name] = [];
      byName[item.name].push(item.reason);
    });
    Object.keys(byName).forEach(function (name) {
      var id = FIELD_ID_BY_NAME[name];
      var node = id && el(id);
      if (!node) return;
      node.classList.add('ocr-low-conf');
      node.title = byName[name].join(' ');
      node.setAttribute('aria-describedby', 'mnp_why');
    });
  }

  function renderHighlightReasons(draft) {
    var host = el('mnp_why');
    if (!host) return;
    host.textContent = '';
    var Schema = global.BeckifyNameplateSchema;
    var reasons = Schema && draft && typeof Schema.highlightReasons === 'function'
      ? Schema.highlightReasons(draft, 0.6)
      : [];
    if (!reasons.length) {
      host.hidden = true;
      return;
    }
    host.hidden = false;
    reasons.forEach(function (item) {
      var li = document.createElement('li');
      li.textContent = item.label + ': ' + item.reason;
      host.appendChild(li);
    });
  }

  function renderDualFlaChooser(draft) {
    var host = el('mnp_dual');
    if (!host) return;
    host.textContent = '';
    var pair = draft && draft.extras && draft.extras.dualFla;
    if (!pair) {
      host.hidden = true;
      return;
    }
    var parts = String(pair).split('/');
    if (parts.length !== 2) {
      host.hidden = true;
      return;
    }
    host.hidden = false;
    var label = document.createElement('span');
    label.textContent = 'Dual FLA ' + pair + ' — pick the amperes that match the voltage you are using:';
    host.appendChild(label);
    parts.forEach(function (amp, index) {
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'ocr-chip';
      btn.textContent = amp + ' A' + (index === 0 ? ' (low-voltage side)' : ' (high-voltage side)');
      btn.addEventListener('click', function () {
        pickDualFlaAmp(amp);
      });
      host.appendChild(btn);
    });
  }

  function sourceMessage(kind, extra) {
    if (!kind) return '';
    if (kind === 'vlm') {
      return 'Source: AI draft' + (extra ? ' (' + extra + ')' : '') + '. Photos were forwarded only because Enhance with AI was on. On-device Tesseract was not used for this read.';
    }
    if (kind === 'edited-ai') {
      return extra || 'Source: local parse of the edited AI transcript. The original photo was sent to the AI reader; this step did not re-read the photo.';
    }
    if (kind === 'tesseract') {
      return extra
        ? 'Source: on-device parse. ' + extra
        : 'Source: on-device Tesseract. The photo stayed on this device.';
    }
    return extra || '';
  }

  function nextSourceAfterEditedParse(priorKind) {
    if (priorKind === 'vlm' || priorKind === 'edited-ai' || priorKind === 'merged') {
      return {
        kind: 'edited-ai',
        extra: 'Source: local parse of the edited AI transcript. The original photo was sent to the AI reader; this step did not re-read the photo.',
      };
    }
    return { kind: 'tesseract', extra: 'Parsed from edited text.' };
  }

  function setSource(kind, extra) {
    lastSourceKind = kind || '';
    var n = el('mnp_source');
    if (!n) return;
    if (!kind) {
      n.hidden = true;
      n.textContent = '';
      return;
    }
    n.hidden = false;
    n.textContent = sourceMessage(kind, extra);
  }

  function setProgress(ratio, status) {
    var fill = el('mnp_progress_fill');
    var label = el('mnp_progress_label');
    var shell = el('mnp_progress');
    var next = Math.max(lastProgress, Math.max(0, Math.min(1, Number(ratio) || 0)));
    lastProgress = next;
    if (shell) shell.hidden = false;
    if (fill) fill.style.width = Math.round(next * 100) + '%';
    if (label) label.textContent = Math.round(next * 100) + '%';
    if (status) setStatus(status);
  }

  function resetProgress() {
    lastProgress = 0;
    var fill = el('mnp_progress_fill');
    var label = el('mnp_progress_label');
    var shell = el('mnp_progress');
    if (fill) fill.style.width = '0%';
    if (label) label.textContent = '0%';
    if (shell) shell.hidden = true;
  }

  function setStatus(msg) {
    var n = el('mnp_status');
    if (n) n.textContent = msg;
  }

  function paint(result) {
    var host = el('mnp_result');
    if (!host) return;
    host.textContent = '';
    host.className = 'result show';
    if (result.error) {
      host.classList.add('error');
      host.textContent = result.error;
      return;
    }
    function row(label, value) {
      var e = document.createElement('div');
      e.className = 'res-row';
      var l = document.createElement('span'); l.className = 'res-label'; l.textContent = label;
      var v = document.createElement('span'); v.className = 'res-val'; v.textContent = value;
      e.append(l, v); host.appendChild(e);
    }
    row('Overload (NEC 430.32(A)(1))', '≤ ' + result.overload.pct + '% of FLA = ' + fmt(result.overloadAmps) + ' A — ' + result.overload.reason);
    row('If starting needs more (430.32(C))', 'next size not exceeding ' + result.overloadNext.pct + '% = ' + fmt(result.overloadNextAmps) + ' A');
    row('Branch-circuit SCPD (Table 430.52)', result.scpd.pct + '% × FLA = ' + fmt(result.scpd.raw) + ' A max; next standard ' + (result.scpd.next || '—') + ' A (' + result.scpd.label + ')');
    if (result.conductor) {
      var matLabel = result.conductor.material === 'al' ? 'Al' : 'Cu';
      row('Suggested conductor (NEC 430.22)', result.conductor.size + ' ' + matLabel + ' @ 75°C lists ' + result.conductor.ampacity + ' A; need ≥ ' + fmt(result.conductor.required) + ' A');
    }
    if (result.voltageDrop) row('Voltage drop note', fmt(result.voltageDrop.pct, 2) + '% over ' + result.voltageDrop.lengthFt + ' ft (Ch.9 Tables 8/9)');
    if (result.lockedRotor && !result.lockedRotor.error) {
      var max = result.lockedRotor.ampsMax === undefined || result.lockedRotor.ampsMax === null ? 'and up' : fmt(result.lockedRotor.ampsMax) + ' A';
      row('Locked-rotor current (code letter ' + result.lockedRotor.letter + ')', fmt(result.lockedRotor.ampsMin) + ' A to ' + max);
      var n = document.createElement('p'); n.className = 'note'; n.textContent = result.lockedRotor.note + ' ' + result.lockedRotor.article + '.';
      host.appendChild(n);
    } else if (result.lockedRotor && result.lockedRotor.error) {
      var n2 = document.createElement('p'); n2.className = 'note'; n2.textContent = result.lockedRotor.error;
      host.appendChild(n2);
    }
    var box = document.createElement('div');
    box.className = 'formula-box';
    result.math.forEach(function (line, i) {
      if (i) box.appendChild(document.createElement('br'));
      box.appendChild(document.createTextNode(line));
    });
    host.appendChild(box);
    var disc = document.createElement('p');
    disc.className = 'note';
    disc.textContent = 'Informational estimate from a reviewed nameplate. Not an inspection. Use nameplate FLA for overload (430.6(A)(2)); use NEC Tables 430.248/430.250 FLA for conductors and SCPD except as 430.6 allows. Any safety concern goes to a licensed electrician.';
    host.appendChild(disc);
  }

  function runCalc() {
    if (!el('mnp_reviewed') || !el('mnp_reviewed').checked) {
      paint({ error: 'Check “I reviewed these values” before calculating. OCR is a draft, not verified input.' });
      return;
    }
    paint(analyze(gather()));
  }

  function revokePhoto() {
    if (photoUrl) { URL.revokeObjectURL(photoUrl); photoUrl = ''; }
  }

  function clearReview() {
    var box = el('mnp_reviewed');
    if (!box) return;
    if (box.checked) {
      box.checked = false;
      box.dispatchEvent(new Event('change', { bubbles: true }));
    }
  }

  function isLikelyImageFile(file) {
    if (global.BeckifyOcr && typeof global.BeckifyOcr.isLikelyImageFile === 'function') {
      return global.BeckifyOcr.isLikelyImageFile(file);
    }
    if (!file) return false;
    var type = String(file.type || '');
    if (type.indexOf('image/') === 0) return true;
    if (type) return false;
    return /\.(jpe?g|png|webp|gif|bmp|tif{1,2}|heic|heif)$/i.test(String(file.name || ''));
  }

  function handleFile(file) {
    if (!file) return;
    if (file.size > 12 * 1024 * 1024) { setStatus('Please choose an image smaller than 12 MB.'); return; }
    if (!isLikelyImageFile(file)) {
      var formats = (global.BeckifyOcr && global.BeckifyOcr.ACCEPTED_IMAGE_LABEL) || 'JPG, PNG, WEBP, HEIC/HEIF, GIF, BMP, or TIFF';
      setStatus('Please choose a photo (' + formats + ').');
      return;
    }
    revokePhoto();
    photoUrl = URL.createObjectURL(file);
    var img = el('mnp_preview');
    if (img) { img.src = photoUrl; img.hidden = false; }
    el('mnp_file')._file = file;
    clearReview();
    setStatus(enhanceOn()
      ? 'Photo is ready on this device. Read nameplate will upload it only because Enhance with AI is on. Correct every field afterward.'
      : 'Photo is on this device only. Click Read nameplate to run on-device OCR, then correct every field.');
  }

  function enhanceOn() {
    return !!(el('mnp_enhance') && el('mnp_enhance').checked);
  }

  function syncVlmUi() {
    var on = enhanceOn();
    var settings = el('mnp_vlm_settings');
    if (settings) settings.hidden = !on;
    var banner = el('mnp_privacy');
    if (banner) {
      banner.classList.toggle('is-upload', on);
      banner.textContent = '';
      var strong = document.createElement('strong');
      strong.textContent = 'Privacy:';
      banner.append(strong, document.createTextNode(on
        ? ' Enhance with AI is on. The photo will leave this device only when you click Read nameplate. If you use the Beckify proxy, the photo may be forwarded to OpenAI and/or Anthropic. Default Tesseract stays available if you turn this off.'
        : ' the default path is on-device Tesseract.js. The photo stays here and is never uploaded unless you turn on Enhance with AI and then click Read nameplate. The photo is not saved after you leave or reset.'));
    }
    var Vlm = global.BeckifyVlmOcr;
    if (Vlm && el('mnp_vlm_endpoint') && !el('mnp_vlm_endpoint').dataset.hydrated) {
      var saved = Vlm.loadSettings();
      if (saved.endpoint) el('mnp_vlm_endpoint').value = saved.endpoint;
      if (saved.token && el('mnp_vlm_token')) el('mnp_vlm_token').value = saved.token;
      el('mnp_vlm_endpoint').dataset.hydrated = '1';
    }
    if (Vlm && on) {
      var savedForm = Vlm.saveFormSettings
        ? Vlm.saveFormSettings(el('mnp_vlm_endpoint') && el('mnp_vlm_endpoint').value, el('mnp_vlm_token') && el('mnp_vlm_token').value)
        : Vlm.saveSettings({
          endpoint: el('mnp_vlm_endpoint') && el('mnp_vlm_endpoint').value,
          token: el('mnp_vlm_token') && el('mnp_vlm_token').value,
        });
      if (savedForm && savedForm.tokenCleared && el('mnp_vlm_token')) el('mnp_vlm_token').value = '';
    }
    var configNote = el('mnp_vlm_config');
    if (configNote && Vlm) {
      var cfg = Vlm.resolveConfig(on);
      if (!on) configNote.textContent = 'Enhance is off. On-device Tesseract is the default.';
      else if (cfg.mode === 'custom') configNote.textContent = 'Custom HTTPS endpoint will receive the photo when you click Read nameplate.';
      else if (cfg.mode === 'proxy') {
        configNote.textContent = 'Beckify proxy (' + cfg.proxyUrl + '/api/analyze-nameplate) will receive the photo when you click Read nameplate. '
          + (Vlm.PROXY_DOWNSTREAM_NOTE || 'The Beckify proxy may forward the photo to OpenAI and/or Anthropic.');
      }
      else configNote.textContent = 'No HTTPS endpoint is configured. Read nameplate will stay on-device Tesseract.';
    }
  }

  function applyTesseractResult(out, options) {
    options = options || {};
    var text = (out && out.text) || '';
    if (el('mnp_raw')) el('mnp_raw').value = text;
    var empty = !!(out && out.failed) || !String(text).trim();
    var draft = global.BeckifyOcr && global.BeckifyOcr.toNameplateDraft
      ? global.BeckifyOcr.toNameplateDraft(text, out && out.confidence)
      : (global.BeckifyNameplateSchema
        ? global.BeckifyNameplateSchema.fromLegacyParse({}, { source: 'tesseract', rawText: text })
        : null);
    if (empty) {
      clearParsedFields();
      lastDraft = draft;
      highlightDraftFields(null);
      renderHighlightReasons(null);
      renderDualFlaChooser(null);
      if (el('mnp_conf')) { el('mnp_conf').hidden = true; el('mnp_conf').textContent = ''; }
      if (el('mnp_hz')) el('mnp_hz').value = '60';
      if (el('mnp_phase')) el('mnp_phase').value = '';
    } else if (draft) {
      applyDraft(draft);
    }
    clearReview();
    if (options.keepAiSource) {
      setSource('edited-ai', options.extra);
    } else {
      setSource('tesseract', options.extra);
    }
    var filled = draft && typeof draft.filled === 'number' ? draft.filled : 0;
    var msg = empty
      ? 'OCR found no usable text. Previous draft fields were cleared. Fill the fields manually — you are not blocked.'
      : (out.lowConfidence ? 'OCR confidence is low (' + out.confidence.toFixed(0) + '%). Treat every field as a draft and correct it.' : 'On-device OCR filled ' + filled + ' field(s) as a draft. Correct them, then check the review box.');
    setStatus(msg);
  }

  function parseEditedText() {
    var text = el('mnp_raw') ? el('mnp_raw').value : '';
    if (!global.BeckifyOcr || !global.BeckifyOcr.toNameplateDraft) {
      setStatus('OCR helper did not load. Fill the fields manually.');
      return;
    }
    var next = nextSourceAfterEditedParse(lastSourceKind);
    var opts = next.kind === 'edited-ai'
      ? { keepAiSource: true, extra: next.extra }
      : { extra: next.extra };
    if (!String(text).trim()) {
      applyTesseractResult({ text: '', failed: true, confidence: 0 }, opts);
      setStatus('Raw text is empty. Draft fields were cleared. Type or paste OCR text, or fill the fields manually.');
      return;
    }
    applyTesseractResult({ text: text, failed: false, lowConfidence: false, confidence: 70 }, opts);
    setStatus('Parsed the edited text into a draft. Correct every field, then check the review box.');
  }

  function runOcr() {
    var file = el('mnp_file') && el('mnp_file')._file;
    if (!file) { setStatus('Choose a nameplate photo, or fill the fields manually.'); return; }
    if (!global.BeckifyOcr) { setStatus('OCR helper did not load. Fill the fields manually.'); return; }
    var btn = el('mnp_ocr');
    if (btn) btn.disabled = true;
    var Vlm = global.BeckifyVlmOcr;
    var useVlm = enhanceOn() && Vlm && Vlm.shouldUpload(true);
    if (enhanceOn() && Vlm && !useVlm) {
      setStatus('Enhance with AI is on but no HTTPS endpoint is configured. Using on-device Tesseract instead.');
    }
    resetProgress();
    if (useVlm) {
      setProgress(0.1, 'Uploading photo for optional AI enhance…');
      Vlm.analyzeNameplate(file, {
        enhanceOn: true,
        onProgress: function (ratio, status) {
          setProgress(ratio, status || 'Enhancing…');
        },
      }).then(function (out) {
        if (el('mnp_raw')) el('mnp_raw').value = out.rawText || '';
        if (out.draft && out.draft.filled === 0 && !(out.rawText || '').trim()) {
          applyTesseractResult({ text: '', failed: true, confidence: 0 });
        } else {
          applyDraft(out.draft);
        }
        clearReview();
        setSource('vlm', out.provider || '');
        var extra = (out.warnings && out.warnings.length) ? ' ' + out.warnings.join(' ') : '';
        setProgress(1, 'AI draft filled ' + ((out.draft && out.draft.filled) || 0) + ' field(s). This is not perfect OCR and not an AI electrician. Correct every field, then check the review box.' + extra);
      }).catch(function (err) {
        var formatted = (Vlm.formatVisionError && Vlm.formatVisionError(err)) || (err && err.message) || 'AI enhance failed.';
        setStatus(formatted + ' Falling back to on-device OCR.');
        return global.BeckifyOcr.recognize(file, {
          onProgress: function (ratio, status) {
            setProgress(ratio, (global.BeckifyOcr.humanizeStatus(status) || 'Reading…'));
          },
        }).then(applyTesseractResult).catch(function (fallbackErr) {
          setStatus((fallbackErr && fallbackErr.message)
            ? fallbackErr.message + ' Fill the fields manually.'
            : 'OCR failed. Fill the fields manually — you are not blocked.');
        });
      }).then(function () { if (btn) btn.disabled = false; }, function () { if (btn) btn.disabled = false; });
      return;
    }
    setProgress(0.05, 'Starting on-device OCR…');
    global.BeckifyOcr.recognize(file, {
      onProgress: function (ratio, status) {
        setProgress(ratio, (global.BeckifyOcr.humanizeStatus(status) || 'Reading…'));
      },
    }).then(applyTesseractResult).catch(function (err) {
      setStatus((err && err.message) ? err.message + ' Fill the fields manually.' : 'OCR failed. Fill the fields manually — you are not blocked.');
    }).then(function () { if (btn) btn.disabled = false; });
  }

  function init() {
    if (!el('sec-motor-nameplate')) return;
    var input = el('mnp_file');
    if (input) input.addEventListener('change', function (ev) {
      var f = ev.target.files && ev.target.files[0];
      handleFile(f);
    });
    var drop = el('mnp_drop');
    if (drop) {
      ['dragenter', 'dragover'].forEach(function (n) {
        drop.addEventListener(n, function (e) { e.preventDefault(); drop.classList.add('is-dragover'); });
      });
      ['dragleave', 'drop'].forEach(function (n) {
        drop.addEventListener(n, function (e) { e.preventDefault(); drop.classList.remove('is-dragover'); });
      });
      drop.addEventListener('drop', function (e) {
        handleFile(e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0]);
      });
    }
    var ocrBtn = el('mnp_ocr');
    if (ocrBtn) ocrBtn.addEventListener('click', runOcr);
    var parseBtn = el('mnp_parse');
    if (parseBtn) parseBtn.addEventListener('click', parseEditedText);
    var calcBtn = el('mnp_calc');
    if (calcBtn) calcBtn.addEventListener('click', runCalc);
    var enhance = el('mnp_enhance');
    if (enhance) enhance.addEventListener('change', syncVlmUi);
    ['mnp_vlm_endpoint', 'mnp_vlm_token'].forEach(function (id) {
      var n = el(id);
      if (!n) return;
      n.addEventListener('change', syncVlmUi);
      n.addEventListener('blur', syncVlmUi);
    });
    var reviewed = el('mnp_reviewed');
    if (reviewed) {
      reviewed.addEventListener('change', function () {
        if (!lastDraft || !global.BeckifyNameplateSchema) return;
        lastDraft = global.BeckifyNameplateSchema.markReviewed(lastDraft, reviewed.checked);
      });
    }
    var resetBtn = el('mnp_reset');
    if (resetBtn) resetBtn.addEventListener('click', function () {
      revokePhoto();
      if (input) { input.value = ''; input._file = null; }
      var img = el('mnp_preview');
      if (img) { img.removeAttribute('src'); img.hidden = true; }
      if (el('mnp_raw')) el('mnp_raw').value = '';
      if (el('mnp_conf')) { el('mnp_conf').hidden = true; el('mnp_conf').textContent = ''; }
      lastDraft = null;
      highlightDraftFields(null);
      renderHighlightReasons(null);
      renderDualFlaChooser(null);
      setSource('');
      resetProgress();
      clearReview();
      clearParsedFields();
      if (el('mnp_hz')) el('mnp_hz').value = '60';
      if (el('mnp_phase')) el('mnp_phase').value = '';
      setStatus('Cleared. The photo was not saved.');
    });
    PARSED_FIELD_IDS.forEach(function (id) {
      var n = el(id);
      if (!n) return;
      n.addEventListener('input', clearReview);
      n.addEventListener('change', clearReview);
    });
    syncVlmUi();
    window.addEventListener('pagehide', revokePhoto);
    if (typeof registerUrlState === 'function') registerUrlState('sec-motor-nameplate', 'motor-nameplate', null);
    if (typeof bindLastUsed === 'function') bindLastUsed('sec-motor-nameplate', 'motor-nameplate');
  }

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
  }

  global.__motorNameplateTestApi = {
    overloadPercent: overloadPercent,
    overloadNextHigherPercent: overloadNextHigherPercent,
    TABLE_430_52: TABLE_430_52,
    scpdFromFla: scpdFromFla,
    lockedRotorRange: lockedRotorRange,
    parsePhase: parsePhase,
    CODE_LETTER: CODE_LETTER,
    analyze: analyze,
    applyDraft: applyDraft,
    applyFields: applyFields,
    applyTesseractResult: applyTesseractResult,
    parseEditedText: parseEditedText,
    sourceMessage: sourceMessage,
    nextSourceAfterEditedParse: nextSourceAfterEditedParse,
    highlightDraftFields: highlightDraftFields,
    renderHighlightReasons: renderHighlightReasons,
    pickDualFlaAmp: pickDualFlaAmp,
    getLastDraft: function () { return lastDraft; },
  };
})(typeof window !== 'undefined' ? window : globalThis);
