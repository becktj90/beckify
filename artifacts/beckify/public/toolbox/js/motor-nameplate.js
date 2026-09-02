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
     instantaneous-trip breaker, inverse-time breaker. */
  var TABLE_430_52 = {
    '1ph': { label: 'Single-phase AC, all types', ntd: 300, td: 175, inst: 800, inv: 250, article: 'NEC Table 430.52' },
    'sc-bde': { label: 'AC squirrel-cage other than 1φ: Design B, D, E', ntd: 300, td: 175, inst: 800, inv: 250, article: 'NEC Table 430.52' },
    'sc-ee': { label: 'AC squirrel-cage: Design B or E energy efficient', ntd: 300, td: 175, inst: 1100, inv: 250, article: 'NEC Table 430.52' },
    'sync': { label: 'AC synchronous (full-voltage, resistor or reactor start)', ntd: 300, td: 175, inst: 800, inv: 250, article: 'NEC Table 430.52' },
    'sync-pw': { label: 'AC synchronous (part-winding)', ntd: 150, td: 150, inst: 800, inv: 200, article: 'NEC Table 430.52' },
    'wound': { label: 'AC wound-rotor', ntd: 150, td: 150, inst: 800, inv: 150, article: 'NEC Table 430.52' },
    'dc': { label: 'DC (constant voltage)', ntd: 150, td: 150, inst: 250, inv: 150, article: 'NEC Table 430.52' },
  };

  function table43052Row(motorType) {
    return TABLE_430_52[motorType] || TABLE_430_52['sc-bde'];
  }

  function scpdFromFla(fla, motorType, device) {
    var row = table43052Row(motorType);
    var pct = row[device] || row.inv;
    var raw = Number(fla) * (pct / 100);
    var next = (typeof nextStandardOCPD === 'function') ? nextStandardOCPD(raw) : null;
    return {
      pct: pct,
      raw: raw,
      next: next,
      article: row.article,
      label: row.label,
      device: device,
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
    var P = Number(hp);
    var V = Number(String(volts || '').split('/')[0]);
    var ph = Number(phase) === 1 ? 1 : 3;
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

  function analyze(input) {
    var fla = Number(input.fla);
    if (!Number.isFinite(fla) || fla <= 0) return { error: 'Enter a positive nameplate FLA after you review the fields.' };
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
      var phase = Number(input.phase) === 1 ? '1ph' : '3ph';
      if (Number.isFinite(volts) && volts > 0) {
        var drop = global.BeckifyWireMath.voltageDropVolts(cond.size, input.material || 'cu', phase, fla, length, 1, 1);
        if (drop != null) vd = { volts: drop, pct: (drop / volts) * 100, lengthFt: length, article: 'NEC Ch.9 Tables 8 and 9 (DC resistance / reactance)' };
      }
    }
    var lra = lockedRotorRange(input.code, hp, input.volts, input.phase);
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
        cond ? 'Conductor ampacity ≥ 125% × FLA = 1.25 × ' + fla + ' A = ' + cond.required.toFixed(1) + ' A → ' + cond.size + ' Cu 75°C lists ' + cond.ampacity + ' A (NEC 430.22, Table 310.16)' : 'Conductor size needs BeckifyWireMath (NEC Table 310.16).',
      ],
    };
  }

  function el(id) { return document.getElementById(id); }
  function val(id) { return el(id) ? el(id).value : ''; }
  function setVal(id, v) { if (el(id) && v != null && v !== '') el(id).value = v; }
  function fmt(x, d) { return Number.isFinite(x) ? Number(x).toLocaleString('en-US', { maximumFractionDigits: d == null ? 1 : d }) : '—'; }

  var photoUrl = '';
  var reviewed = false;

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

  function applyFields(fields) {
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
    if (result.conductor) row('Suggested conductor (NEC 430.22)', result.conductor.size + ' Cu @ 75°C lists ' + result.conductor.ampacity + ' A; need ≥ ' + fmt(result.conductor.required) + ' A');
    if (result.voltageDrop) row('Voltage drop note', fmt(result.voltageDrop.pct, 2) + '% over ' + result.voltageDrop.lengthFt + ' ft (Ch.9 Tables 8/9)');
    if (result.lockedRotor && !result.lockedRotor.error) {
      var max = result.lockedRotor.ampsMax == null ? 'and up' : fmt(result.lockedRotor.ampsMax) + ' A';
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

  function handleFile(file) {
    if (!file) return;
    if (file.size > 12 * 1024 * 1024) { setStatus('Please choose an image smaller than 12 MB.'); return; }
    revokePhoto();
    photoUrl = URL.createObjectURL(file);
    var img = el('mnp_preview');
    if (img) { img.src = photoUrl; img.hidden = false; }
    el('mnp_file')._file = file;
    setStatus('Photo is on this device only. Click Read nameplate to run on-device OCR, then correct every field.');
  }

  function runOcr() {
    var file = el('mnp_file') && el('mnp_file')._file;
    if (!file) { setStatus('Choose a nameplate photo, or fill the fields manually.'); return; }
    if (!global.BeckifyOcr) { setStatus('OCR helper did not load. Fill the fields manually.'); return; }
    var btn = el('mnp_ocr');
    if (btn) btn.disabled = true;
    setStatus('Starting on-device OCR…');
    global.BeckifyOcr.recognize(file, {
      onProgress: function (ratio, status) {
        var pct = Math.round(Math.max(0, Math.min(1, ratio)) * 100);
        setStatus((global.BeckifyOcr.humanizeStatus(status) || 'Reading…') + ' ' + pct + '%');
      },
    }).then(function (out) {
      if (el('mnp_raw')) el('mnp_raw').value = out.text || '';
      var parsed = global.BeckifyOcr.parseMotorNameplate(out.text || '');
      applyFields(parsed.fields);
      if (el('mnp_reviewed')) el('mnp_reviewed').checked = false;
      var msg = out.failed
        ? 'OCR found no usable text. Fill the fields manually — you are not blocked.'
        : (out.lowConfidence ? 'OCR confidence is low (' + out.confidence.toFixed(0) + '%). Treat every field as a draft and correct it.' : 'OCR filled ' + parsed.filled + ' field(s) as a draft. Correct them, then check the review box.');
      setStatus(msg);
    }).catch(function (err) {
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
    var calcBtn = el('mnp_calc');
    if (calcBtn) calcBtn.addEventListener('click', runCalc);
    var resetBtn = el('mnp_reset');
    if (resetBtn) resetBtn.addEventListener('click', function () {
      revokePhoto();
      if (input) { input.value = ''; input._file = null; }
      var img = el('mnp_preview');
      if (img) { img.removeAttribute('src'); img.hidden = true; }
      if (el('mnp_raw')) el('mnp_raw').value = '';
      if (el('mnp_reviewed')) el('mnp_reviewed').checked = false;
      setStatus('Cleared. The photo was not saved.');
    });
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
    CODE_LETTER: CODE_LETTER,
    analyze: analyze,
  };
})(typeof window !== 'undefined' ? window : globalThis);
