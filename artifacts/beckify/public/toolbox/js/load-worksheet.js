/* ============================================================================
   NEC 220 LOAD CALCULATION WORKSHEET
   ============================================================================
   Row-based feeder / service aid. Design aid — not a PE service calculation.
   Implements only the articles actually coded below.
   ============================================================================ */

(function (global) {
  'use strict';

  var STORAGE_KEY = 'beckify-load-worksheet-v1';
  var XLSX_SRC = 'js/vendor/xlsx.full.min.js';
  var xlsxPromise = null;

  var LOAD_TYPES = [
    { id: 'lighting', label: 'Lighting' },
    { id: 'receptacle', label: 'Receptacle' },
    { id: 'kitchen', label: 'Kitchen / small-appliance' },
    { id: 'dryer', label: 'Clothes dryer' },
    { id: 'hvac', label: 'HVAC' },
    { id: 'motor', label: 'Motor' },
    { id: 'continuous', label: 'Continuous' },
    { id: 'other', label: 'Other / appliance' },
  ];

  var PHASES = [
    { id: 'A', label: 'A' },
    { id: 'B', label: 'B' },
    { id: 'C', label: 'C' },
    { id: '1ph', label: '1Ø' },
    { id: '3ph', label: '3Ø' },
  ];

  /* NEC Table 220.42 — lighting load demand factors (as coded). */
  var LIGHTING_220_42 = {
    dwelling: {
      label: 'Dwelling units (220.42)',
      steps: [
        { upTo: 3000, factor: 1.00 },
        { upTo: 120000, factor: 0.35 },
        { upTo: Infinity, factor: 0.25 },
      ],
    },
    hospital: {
      label: 'Hospitals (220.42)',
      steps: [
        { upTo: 50000, factor: 0.40 },
        { upTo: Infinity, factor: 0.20 },
      ],
    },
    hotel: {
      label: 'Hotels / motels / apartments without cooking (220.42)',
      steps: [
        { upTo: 20000, factor: 0.50 },
        { upTo: 100000, factor: 0.40 },
        { upTo: Infinity, factor: 0.30 },
      ],
    },
    warehouse: {
      label: 'Warehouses — storage (220.42)',
      steps: [
        { upTo: 12500, factor: 1.00 },
        { upTo: Infinity, factor: 0.50 },
      ],
    },
    other: {
      label: 'All others (220.42) — 100%',
      steps: [{ upTo: Infinity, factor: 1.00 }],
    },
  };

  function newRow(partial) {
    var row = {
      id: 'r' + Math.random().toString(36).slice(2, 9),
      description: '',
      type: 'lighting',
      qty: 1,
      value: 0,
      unit: 'VA',
      phase: '3ph',
      dfOverride: '',
    };
    if (partial) Object.keys(partial).forEach(function (k) { row[k] = partial[k]; });
    return row;
  }

  function defaultSheet() {
    return {
      method: 'commercial',
      occupancy: 'other',
      voltage: 208,
      system: '3ph',
      sparePct: 0,
      rows: [
        newRow({ description: 'General lighting', type: 'lighting', qty: 1, value: 0, unit: 'VA', phase: '3ph' }),
      ],
    };
  }

  function parseNum(v) {
    var n = Number(v);
    return isFinite(n) ? n : 0;
  }

  function rowConnectedVA(row, voltage) {
    var qty = Math.max(0, parseNum(row.qty));
    var value = Math.max(0, parseNum(row.value));
    var unit = row.unit || 'VA';
    var v = Math.max(0, parseNum(voltage));
    var one;
    if (unit === 'W') one = value;
    else if (unit === 'A') {
      if (row.phase === '3ph') one = value * v * Math.sqrt(3);
      else one = value * v;
    } else {
      one = value;
    }
    return qty * one;
  }

  function applySteppedDemand(totalVA, steps) {
    var remaining = totalVA;
    var demand = 0;
    var math = [];
    var prev = 0;
    var i;
    for (i = 0; i < steps.length; i += 1) {
      var cap = steps[i].upTo;
      var band = Math.min(remaining, cap - prev);
      if (band < 0) band = 0;
      if (band > 0) {
        var part = band * steps[i].factor;
        demand += part;
        remaining -= band;
        math.push(
          band.toFixed(0) + ' VA × ' + (steps[i].factor * 100).toFixed(0) + '% = ' + part.toFixed(0) + ' VA'
        );
      }
      prev = cap;
      if (remaining <= 0) break;
    }
    return { demandVA: demand, math: math, connectedVA: totalVA };
  }

  function lightingDemand220_42(connectedVA, occupancy) {
    var table = LIGHTING_220_42[occupancy] || LIGHTING_220_42.other;
    var stepped = applySteppedDemand(connectedVA, table.steps);
    stepped.article = '220.42';
    stepped.label = table.label;
    return stepped;
  }

  /* 220.52: small-appliance and laundry loads in a dwelling are included with
     general lighting and then the 220.42 factors apply to that combined pile. */
  function dwellingStandard(groups, occupancy) {
    var lightingOcc = occupancy === 'dwelling' ? 'dwelling' : occupancy;
    var lightingPile = groups.lighting + groups.receptacle + groups.kitchen;
    var light = lightingDemand220_42(lightingPile, lightingOcc);

    var dryerConnected = groups.dryer;
    var dryerDemand = dryerConnected; /* 220.54: 5000 W or nameplate, whichever larger — per dryer row we already have VA */
    /* Nameplate already entered; 220.54 floor is 5000 VA each if the user entered a dryer row. */

    var otherConnected = groups.other;
    var otherCount = groups.otherCount;
    var otherDemand = otherCount >= 4 ? otherConnected * 0.75 : otherConnected;

    var hvac = groups.hvac;
    var motor = groups.motor;
    var continuous = groups.continuous * 1.25;

    var demandVA = light.demandVA + dryerDemand + otherDemand + hvac + motor + continuous;
    return {
      demandVA: demandVA,
      lighting: light,
      dryerDemand: dryerDemand,
      otherDemand: otherDemand,
      otherFactor: otherCount >= 4 ? 0.75 : 1,
      notes: [
        'Dwelling standard method: lighting + receptacle + kitchen/small-appliance (220.52) take Table 220.42 factors.',
        otherCount >= 4
          ? '220.53: ' + otherCount + ' fastened-in-place other/appliance loads × 75%.'
          : '220.53: fewer than 4 other/appliance loads — 100%.',
        '220.54: dryer demand uses the entered VA (code floor is 5 kW or nameplate, whichever larger — enter the larger).',
      ],
    };
  }

  function dwellingOptional220_82(groups) {
    var general = groups.lighting + groups.receptacle + groups.kitchen + groups.dryer + groups.other + groups.motor + groups.continuous;
    var first = Math.min(general, 10000);
    var rest = Math.max(0, general - 10000);
    var generalDemand = first + rest * 0.40;
    var hvac = groups.hvac;
    return {
      demandVA: generalDemand + hvac,
      first: first,
      rest: rest,
      generalDemand: generalDemand,
      hvac: hvac,
      notes: [
        '220.82 optional dwelling: 100% of the first 10 kVA of general loads + 40% of the remainder.',
        'HVAC rows stay at 100% of the entered connected VA (largest heating/cooling selection is the user’s job).',
      ],
    };
  }

  function commercial220_42(groups, occupancy) {
    var light = lightingDemand220_42(groups.lighting, occupancy);
    var demandVA = light.demandVA + groups.receptacle + groups.kitchen + groups.dryer +
      groups.hvac + groups.motor + (groups.continuous * 1.25) + groups.other;
    return {
      demandVA: demandVA,
      lighting: light,
      notes: [
        'Commercial / general: only lighting uses Table 220.42. Other types stay at 100% unless a row override is set.',
      ],
    };
  }

  function phaseShare(phase, system) {
    if (phase === 'A' || phase === 'B' || phase === 'C') {
      var one = { A: 0, B: 0, C: 0 };
      one[phase] = 1;
      return one;
    }
    if (phase === '1ph' || system === '1ph') {
      return { A: 1, B: 0, C: 0 };
    }
    return { A: 1 / 3, B: 1 / 3, C: 1 / 3 };
  }

  function groupRows(rows, voltage) {
    var groups = {
      lighting: 0, receptacle: 0, kitchen: 0, dryer: 0,
      hvac: 0, motor: 0, continuous: 0, other: 0,
      otherCount: 0,
    };
    var details = [];
    rows.forEach(function (row) {
      var connected = rowConnectedVA(row, voltage);
      var type = groups[row.type] != null ? row.type : 'other';
      groups[type] += connected;
      if (type === 'other') groups.otherCount += Math.max(1, parseNum(row.qty) || 1);
      details.push({
        row: row,
        connectedVA: connected,
      });
    });
    return { groups: groups, details: details };
  }

  function computeSheet(sheet) {
    var voltage = Math.max(1, parseNum(sheet.voltage) || 208);
    var system = sheet.system === '1ph' ? '1ph' : '3ph';
    var sparePct = Math.max(0, parseNum(sheet.sparePct));
    var packed = groupRows(sheet.rows || [], voltage);
    var groups = packed.groups;

    var method;
    var methodLabel;
    if (sheet.method === 'dwelling-optional') {
      method = dwellingOptional220_82(groups);
      methodLabel = 'Optional dwelling (220.82)';
    } else if (sheet.method === 'dwelling') {
      method = dwellingStandard(groups, 'dwelling');
      methodLabel = 'Dwelling standard (220.42 / 220.52 / 220.53 / 220.54)';
    } else {
      method = commercial220_42(groups, sheet.occupancy || 'other');
      methodLabel = 'Commercial / general lighting (220.42)';
    }

    var connectedVA = 0;
    var demandVA = 0;
    var phaseConnected = { A: 0, B: 0, C: 0 };
    var phaseDemand = { A: 0, B: 0, C: 0 };
    var rowOut = packed.details.map(function (d) {
      var row = d.row;
      var connected = d.connectedVA;
      connectedVA += connected;
      var override = row.dfOverride === '' || row.dfOverride == null ? null : parseNum(row.dfOverride);
      var df;
      var dfNote;
      if (override != null && isFinite(override) && override >= 0) {
        df = override > 2 ? override / 100 : override;
        dfNote = 'Row override';
      } else if (sheet.method === 'dwelling-optional') {
        df = connectedVA === 0 ? 0 : null;
        dfNote = 'In 220.82 general pile (or HVAC at 100%)';
      } else if (sheet.method === 'dwelling' && (row.type === 'lighting' || row.type === 'receptacle' || row.type === 'kitchen')) {
        df = method.lighting && method.lighting.connectedVA > 0
          ? method.lighting.demandVA / method.lighting.connectedVA
          : 1;
        dfNote = '220.42 via 220.52 pile';
      } else if (sheet.method === 'dwelling' && row.type === 'other') {
        df = method.otherFactor;
        dfNote = '220.53';
      } else if (sheet.method !== 'dwelling-optional' && row.type === 'lighting') {
        df = method.lighting && method.lighting.connectedVA > 0
          ? method.lighting.demandVA / method.lighting.connectedVA
          : 1;
        dfNote = '220.42';
      } else if (row.type === 'continuous') {
        df = 1.25;
        dfNote = 'Continuous 125% sizing check (not a 220 demand factor)';
      } else {
        df = 1;
        dfNote = '100% (no extra 220 factor coded for this type)';
      }

      var rowDemand;
      if (sheet.method === 'dwelling-optional' && override == null) {
        /* Optional method is applied to the pile, not row-by-row, except HVAC. */
        if (row.type === 'hvac') {
          rowDemand = connected;
          df = 1;
          dfNote = '220.82 HVAC at 100% of entered VA';
        } else {
          var general = groups.lighting + groups.receptacle + groups.kitchen + groups.dryer + groups.other + groups.motor + groups.continuous;
          df = general > 0 ? method.generalDemand / general : 1;
          rowDemand = connected * df;
          dfNote = '220.82 pile factor';
        }
      } else {
        rowDemand = connected * df;
      }

      demandVA += rowDemand;
      var share = phaseShare(row.phase, system);
      phaseConnected.A += connected * share.A;
      phaseConnected.B += connected * share.B;
      phaseConnected.C += connected * share.C;
      phaseDemand.A += rowDemand * share.A;
      phaseDemand.B += rowDemand * share.B;
      phaseDemand.C += rowDemand * share.C;

      return {
        id: row.id,
        description: row.description,
        type: row.type,
        qty: parseNum(row.qty),
        value: parseNum(row.value),
        unit: row.unit,
        phase: row.phase,
        connectedVA: connected,
        demandVA: rowDemand,
        df: df,
        dfNote: dfNote,
      };
    });

    /* Reconcile optional-method total to the pile formula so rounding stays honest. */
    if (sheet.method === 'dwelling-optional') {
      demandVA = method.demandVA;
    } else if (sheet.method === 'dwelling') {
      /* Row overrides may have adjusted demand; if no overrides, use method total. */
      var anyOverride = (sheet.rows || []).some(function (r) {
        return r.dfOverride !== '' && r.dfOverride != null;
      });
      if (!anyOverride) demandVA = method.demandVA;
    } else {
      var anyOver = (sheet.rows || []).some(function (r) {
        return r.dfOverride !== '' && r.dfOverride != null;
      });
      if (!anyOver) demandVA = method.demandVA;
    }

    var withSpare = demandVA * (1 + sparePct / 100);
    var divisor = system === '3ph' ? (Math.sqrt(3) * voltage) : voltage;
    var feederA = divisor > 0 ? withSpare / divisor : 0;
    var amps = {
      A: divisor > 0 && system === '3ph' ? (phaseDemand.A * 3) / (Math.sqrt(3) * voltage) : feederA,
      B: system === '3ph' ? (phaseDemand.B * 3) / (Math.sqrt(3) * voltage) : 0,
      C: system === '3ph' ? (phaseDemand.C * 3) / (Math.sqrt(3) * voltage) : 0,
    };
    if (system === '1ph') {
      amps = { A: feederA, B: 0, C: 0 };
    }
    var ampVals = system === '3ph' ? [amps.A, amps.B, amps.C] : [amps.A];
    var avg = ampVals.reduce(function (s, n) { return s + n; }, 0) / ampVals.length;
    var maxA = Math.max.apply(null, ampVals);
    var unbalancePct = avg > 0 ? ((maxA - avg) / avg) * 100 : 0;

    return {
      ok: true,
      method: sheet.method,
      methodLabel: methodLabel,
      occupancy: sheet.occupancy,
      voltage: voltage,
      system: system,
      sparePct: sparePct,
      connectedVA: connectedVA,
      demandVA: demandVA,
      demandWithSpareVA: withSpare,
      feederA: feederA,
      amps: amps,
      unbalancePct: unbalancePct,
      groups: groups,
      methodMath: method,
      rows: rowOut,
      cited: citedArticles(sheet.method),
      disclaimer: 'Design aid — not a PE service calculation. Verify the adopted NEC edition, occupancy, and noncoincident loads before you size a service.',
    };
  }

  function citedArticles(method) {
    if (method === 'dwelling-optional') return ['220.82'];
    if (method === 'dwelling') return ['220.42', '220.52', '220.53', '220.54'];
    return ['220.42'];
  }

  function loadStored() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return defaultSheet();
      var parsed = JSON.parse(raw);
      if (!parsed || !Array.isArray(parsed.rows)) return defaultSheet();
      return parsed;
    } catch (_) {
      return defaultSheet();
    }
  }

  function saveStored(sheet) {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(sheet)); } catch (_) {}
  }

  function el(id) { return document.getElementById(id); }

  function escapeHtml(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function optionList(items, selected) {
    return items.map(function (it) {
      var sel = it.id === selected ? ' selected' : '';
      return '<option value="' + escapeHtml(it.id) + '"' + sel + '>' + escapeHtml(it.label) + '</option>';
    }).join('');
  }

  var sheet = defaultSheet();

  function readFormMeta() {
    sheet.method = (el('lw_method') && el('lw_method').value) || 'commercial';
    sheet.occupancy = (el('lw_occupancy') && el('lw_occupancy').value) || 'other';
    sheet.voltage = parseNum(el('lw_voltage') && el('lw_voltage').value);
    sheet.system = (el('lw_system') && el('lw_system').value) || '3ph';
    sheet.sparePct = parseNum(el('lw_spare') && el('lw_spare').value);
  }

  function writeFormMeta() {
    if (el('lw_method')) el('lw_method').value = sheet.method;
    if (el('lw_occupancy')) el('lw_occupancy').value = sheet.occupancy || 'other';
    if (el('lw_voltage')) el('lw_voltage').value = sheet.voltage;
    if (el('lw_system')) el('lw_system').value = sheet.system;
    if (el('lw_spare')) el('lw_spare').value = sheet.sparePct;
  }

  function renderRows() {
    var host = el('lw_rows');
    if (!host) return;
    var units = [
      { id: 'VA', label: 'VA' },
      { id: 'W', label: 'W' },
      { id: 'A', label: 'A' },
    ];
    host.innerHTML = '<table class="ref-table lw-table"><thead><tr>' +
      '<th>Description</th><th>Type</th><th>Qty</th><th>Value</th><th>Unit</th><th>Phase</th><th>DF override</th><th></th>' +
      '</tr></thead><tbody>' +
      sheet.rows.map(function (row, idx) {
        return '<tr data-id="' + escapeHtml(row.id) + '">' +
          '<td><input type="text" data-k="description" value="' + escapeHtml(row.description) + '" aria-label="Description ' + (idx + 1) + '"></td>' +
          '<td><select data-k="type" aria-label="Load type ' + (idx + 1) + '">' + optionList(LOAD_TYPES, row.type) + '</select></td>' +
          '<td><input type="number" data-k="qty" min="0" step="any" value="' + escapeHtml(row.qty) + '" aria-label="Quantity ' + (idx + 1) + '"></td>' +
          '<td><input type="number" data-k="value" min="0" step="any" value="' + escapeHtml(row.value) + '" aria-label="Value ' + (idx + 1) + '"></td>' +
          '<td><select data-k="unit" aria-label="Unit ' + (idx + 1) + '">' + optionList(units, row.unit) + '</select></td>' +
          '<td><select data-k="phase" aria-label="Phase ' + (idx + 1) + '">' + optionList(PHASES, row.phase) + '</select></td>' +
          '<td><input type="number" data-k="dfOverride" min="0" step="any" placeholder="auto" value="' + escapeHtml(row.dfOverride) + '" aria-label="Demand-factor override ' + (idx + 1) + '"></td>' +
          '<td><button type="button" class="btn btn-sm lw-del" data-id="' + escapeHtml(row.id) + '">Remove</button></td>' +
          '</tr>';
      }).join('') +
      '</tbody></table>';
  }

  function readRowsFromDom() {
    var host = el('lw_rows');
    if (!host) return;
    var next = [];
    host.querySelectorAll('tbody tr').forEach(function (tr) {
      var id = tr.getAttribute('data-id');
      var existing = sheet.rows.filter(function (r) { return r.id === id; })[0] || newRow({ id: id });
      tr.querySelectorAll('[data-k]').forEach(function (field) {
        existing[field.getAttribute('data-k')] = field.value;
      });
      next.push(existing);
    });
    sheet.rows = next;
  }

  function fmt(n, d) {
    if (!isFinite(n)) return '—';
    return Number(n).toFixed(d == null ? 0 : d);
  }

  function renderResult(result) {
    var out = el('lw_result');
    if (!out || !result) return;
    var mathLines = [];
    if (result.methodMath && result.methodMath.lighting && result.methodMath.lighting.math) {
      mathLines.push('<strong>220.42 lighting pile</strong><br>' + result.methodMath.lighting.math.map(escapeHtml).join('<br>'));
    }
    if (result.methodMath && result.methodMath.notes) {
      mathLines.push(result.methodMath.notes.map(escapeHtml).join('<br>'));
    }
    if (result.method === 'dwelling-optional' && result.methodMath) {
      mathLines.push(
        'General loads first 10 kVA: ' + fmt(result.methodMath.first) + ' VA @ 100%<br>' +
        'Remainder: ' + fmt(result.methodMath.rest) + ' VA @ 40% = ' + fmt(result.methodMath.rest * 0.4) + ' VA'
      );
    }
    var rowMath = '<table class="ref-table"><thead><tr><th>Row</th><th>Connected VA</th><th>DF</th><th>Demand VA</th><th>Basis</th></tr></thead><tbody>' +
      result.rows.map(function (r) {
        return '<tr><td>' + escapeHtml(r.description || r.type) + '</td><td>' + fmt(r.connectedVA) +
          '</td><td>' + (r.df == null ? '—' : (r.df * 100).toFixed(1) + '%') +
          '</td><td>' + fmt(r.demandVA) + '</td><td>' + escapeHtml(r.dfNote) + '</td></tr>';
      }).join('') + '</tbody></table>';

    out.className = 'result show';
    out.innerHTML =
      '<p><strong>' + escapeHtml(result.methodLabel) + '</strong> · cited ' + escapeHtml(result.cited.join(', ')) + '</p>' +
      '<p>Connected: <strong>' + fmt(result.connectedVA) + ' VA</strong> (' + fmt(result.connectedVA / 1000, 2) + ' kVA)</p>' +
      '<p>Demand: <strong>' + fmt(result.demandVA) + ' VA</strong> (' + fmt(result.demandVA / 1000, 2) + ' kVA)</p>' +
      '<p>Spare / future +' + fmt(result.sparePct, 1) + '% → <strong>' + fmt(result.demandWithSpareVA) + ' VA</strong></p>' +
      '<p>Feeder / service at ' + fmt(result.voltage, 0) + ' V ' + (result.system === '3ph' ? '3Ø' : '1Ø') +
      ': <strong>' + fmt(result.feederA, 1) + ' A</strong></p>' +
      '<p>Phase A / B / C: ' + fmt(result.amps.A, 1) + ' / ' + fmt(result.amps.B, 1) + ' / ' + fmt(result.amps.C, 1) +
      ' A · unbalance ' + fmt(result.unbalancePct, 1) + '%</p>' +
      '<div class="formula-box">' + mathLines.join('<br><br>') + '</div>' +
      rowMath +
      '<p class="note">' + escapeHtml(result.disclaimer) + '</p>';
  }

  function recalc() {
    readRowsFromDom();
    readFormMeta();
    var result = computeSheet(sheet);
    renderResult(result);
    saveStored(sheet);
    return result;
  }

  function sheetToAoa(result) {
    var header = ['Description', 'Type', 'Qty', 'Value', 'Unit', 'Phase', 'DF override', 'Connected VA', 'Demand VA', 'DF note'];
    var rows = [header];
    result.rows.forEach(function (r, i) {
      var src = sheet.rows[i] || {};
      rows.push([
        r.description, r.type, r.qty, r.value, r.unit, r.phase, src.dfOverride || '',
        r.connectedVA, r.demandVA, r.dfNote,
      ]);
    });
    rows.push([]);
    rows.push(['Method', result.methodLabel]);
    rows.push(['Cited', result.cited.join(', ')]);
    rows.push(['Connected VA', result.connectedVA]);
    rows.push(['Demand VA', result.demandVA]);
    rows.push(['Spare %', result.sparePct]);
    rows.push(['Demand + spare VA', result.demandWithSpareVA]);
    rows.push(['Voltage', result.voltage]);
    rows.push(['System', result.system]);
    rows.push(['Feeder A', result.feederA]);
    rows.push(['Phase A A', result.amps.A]);
    rows.push(['Phase B A', result.amps.B]);
    rows.push(['Phase C A', result.amps.C]);
    rows.push(['Unbalance %', result.unbalancePct]);
    return rows;
  }

  function downloadBlob(name, blob) {
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
  }

  function exportCsv() {
    var result = recalc();
    var aoa = sheetToAoa(result);
    var csv = aoa.map(function (line) {
      return line.map(function (cell) {
        var s = String(cell == null ? '' : cell);
        if (/[",\n]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
        return s;
      }).join(',');
    }).join('\n');
    downloadBlob('load-worksheet.csv', new Blob([csv], { type: 'text/csv;charset=utf-8' }));
  }

  function loadXlsx() {
    if (xlsxPromise) return xlsxPromise;
    xlsxPromise = new Promise(function (resolve, reject) {
      if (global.XLSX && global.XLSX.utils) return resolve(global.XLSX);
      var s = document.createElement('script');
      s.src = XLSX_SRC;
      s.onload = function () {
        if (global.XLSX && global.XLSX.utils) resolve(global.XLSX);
        else reject(new Error('SheetJS failed to load'));
      };
      s.onerror = function () {
        xlsxPromise = null;
        reject(new Error('SheetJS failed to load'));
      };
      document.head.appendChild(s);
    });
    return xlsxPromise;
  }

  function exportXlsx() {
    var result = recalc();
    loadXlsx().then(function (XLSXlib) {
      var wb = XLSXlib.utils.book_new();
      var ws = XLSXlib.utils.aoa_to_sheet(sheetToAoa(result));
      XLSXlib.utils.book_append_sheet(wb, ws, 'Load worksheet');
      var out = XLSXlib.write(wb, { bookType: 'xlsx', type: 'array' });
      downloadBlob('load-worksheet.xlsx', new Blob([out], {
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      }));
    }).catch(function () {
      exportCsv();
    });
  }

  function seedFromSqft() {
    var sqft = parseNum(el('bl_sqft') && el('bl_sqft').value);
    var outlets = parseNum(el('bl_outlets') && el('bl_outlets').value);
    var occ = (el('bl_occupancy') && el('bl_occupancy').value) || 'other';
    var rates = { industrial: 1, office: 3.5, warehouse: 0.25, retail: 3, school: 3, hospital: 2 };
    var vaPer = rates[occ] != null ? rates[occ] : 1;
    if (sqft > 0) {
      sheet.rows.push(newRow({
        description: 'General lighting (' + sqft + ' ft² × ' + vaPer + ' VA/ft²)',
        type: 'lighting',
        qty: 1,
        value: sqft * vaPer,
        unit: 'VA',
        phase: sheet.system === '1ph' ? '1ph' : '3ph',
      }));
    }
    if (outlets > 0) {
      sheet.rows.push(newRow({
        description: 'Receptacles (' + outlets + ' × 180 VA)',
        type: 'receptacle',
        qty: outlets,
        value: 180,
        unit: 'VA',
        phase: sheet.system === '1ph' ? '1ph' : '3ph',
      }));
    }
    var mapOcc = { hospital: 'hospital', warehouse: 'warehouse', office: 'other', industrial: 'other', retail: 'other', school: 'other' };
    sheet.occupancy = mapOcc[occ] || 'other';
    writeFormMeta();
    renderRows();
    recalc();
  }

  function bind() {
    if (!el('sec-bldg-load') || !el('lw_rows')) return;
    sheet = loadStored();
    if (!sheet.rows || !sheet.rows.length) sheet = defaultSheet();
    writeFormMeta();
    renderRows();
    recalc();

    var rowsHost = el('lw_rows');
    rowsHost.addEventListener('input', function () { recalc(); });
    rowsHost.addEventListener('change', function () { recalc(); });
    rowsHost.addEventListener('click', function (ev) {
      var btn = ev.target.closest('.lw-del');
      if (!btn) return;
      var id = btn.getAttribute('data-id');
      sheet.rows = sheet.rows.filter(function (r) { return r.id !== id; });
      if (!sheet.rows.length) sheet.rows.push(newRow());
      renderRows();
      recalc();
    });

    ['lw_method', 'lw_occupancy', 'lw_voltage', 'lw_system', 'lw_spare'].forEach(function (id) {
      var node = el(id);
      if (node) node.addEventListener('change', recalc);
    });

    var addBtn = el('lw_add');
    if (addBtn) addBtn.addEventListener('click', function () {
      readRowsFromDom();
      sheet.rows.push(newRow());
      renderRows();
      recalc();
    });
    var csvBtn = el('lw_export_csv');
    if (csvBtn) csvBtn.addEventListener('click', exportCsv);
    var xlsxBtn = el('lw_export_xlsx');
    if (xlsxBtn) xlsxBtn.addEventListener('click', exportXlsx);
    var seedBtn = el('lw_seed_sqft');
    if (seedBtn) seedBtn.addEventListener('click', seedFromSqft);
    var clearBtn = el('lw_clear');
    if (clearBtn) clearBtn.addEventListener('click', function () {
      sheet = defaultSheet();
      writeFormMeta();
      renderRows();
      recalc();
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bind);
  } else {
    bind();
  }

  global.__loadWorksheetTestApi = {
    LOAD_TYPES: LOAD_TYPES,
    LIGHTING_220_42: LIGHTING_220_42,
    newRow: newRow,
    rowConnectedVA: rowConnectedVA,
    lightingDemand220_42: lightingDemand220_42,
    applySteppedDemand: applySteppedDemand,
    computeSheet: computeSheet,
    dwellingStandard: dwellingStandard,
    dwellingOptional220_82: dwellingOptional220_82,
    citedArticles: citedArticles,
  };
})(typeof window !== 'undefined' ? window : globalThis);
