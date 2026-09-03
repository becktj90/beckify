/* ============================================================================
   TORQUE LOOKUP — terminal / lug (UL 486A-B) and fastener handbook values
   ============================================================================
   Field EE / panel-shop lookup. Not a calibrated torque-tool substitute.
   Manufacturer marking on the device always wins.
   ============================================================================ */

(function (global) {
  'use strict';

  var INLB_PER_NM = 8.8507457676;
  var FTLB_PER_INLB = 1 / 12;

  /* Typical tightening torque reprinted from UL 486A-B (the tables also
     appear as NEC Informative Annex I). Values are Column B–style typicals
     used in electrician pocket refs when the lug is unmarked.
     inLb is pound-inches. A dash means that screw style is not listed for
     that conductor size in the published table. */
  var LUG_ROWS = [
    { size: '18–10 AWG', sizeKey: '18-10', sizes: ['18', '16', '14', '12', '10'], slotNarrow: 20, slotWide: 35, hex: 80, splitBolt: 80, other: 75 },
    { size: '8 AWG', sizeKey: '8', sizes: ['8'], slotNarrow: 25, slotWide: 40, hex: 80, splitBolt: 80, other: 75 },
    { size: '6–4 AWG', sizeKey: '6-4', sizes: ['6', '4'], slotNarrow: 35, slotWide: 45, hex: 165, splitBolt: 165, other: 110 },
    { size: '3 AWG', sizeKey: '3', sizes: ['3'], slotNarrow: 35, slotWide: 50, hex: 275, splitBolt: 275, other: 150 },
    { size: '2 AWG', sizeKey: '2', sizes: ['2'], slotNarrow: 40, slotWide: 50, hex: 275, splitBolt: 275, other: 150 },
    { size: '1 AWG', sizeKey: '1', sizes: ['1'], slotNarrow: null, slotWide: 50, hex: 275, splitBolt: 275, other: 150 },
    { size: '1/0–2/0 AWG', sizeKey: '1/0-2/0', sizes: ['1/0', '2/0', '0', '00'], slotNarrow: null, slotWide: 50, hex: 385, splitBolt: 385, other: 180 },
    { size: '3/0–4/0 AWG', sizeKey: '3/0-4/0', sizes: ['3/0', '4/0', '000', '0000'], slotNarrow: null, slotWide: 50, hex: 500, splitBolt: 500, other: 250 },
    { size: '250–350 kcmil', sizeKey: '250-350', sizes: ['250', '300', '350'], slotNarrow: null, slotWide: 50, hex: 650, splitBolt: 650, other: 325 },
    { size: '400 kcmil', sizeKey: '400', sizes: ['400'], slotNarrow: null, slotWide: 50, hex: 825, splitBolt: 825, other: 325 },
    { size: '500 kcmil', sizeKey: '500', sizes: ['500'], slotNarrow: null, slotWide: 50, hex: 825, splitBolt: 825, other: 375 },
    { size: '600–750 kcmil', sizeKey: '600-750', sizes: ['600', '700', '750'], slotNarrow: null, slotWide: 50, hex: 1000, splitBolt: 1000, other: 375 },
    { size: '800–1000 kcmil', sizeKey: '800-1000', sizes: ['800', '900', '1000'], slotNarrow: null, slotWide: 50, hex: 1100, splitBolt: 1100, other: 500 },
    { size: '1250–2000 kcmil', sizeKey: '1250-2000', sizes: ['1250', '1500', '1750', '2000'], slotNarrow: null, slotWide: null, hex: 1100, splitBolt: 1100, other: 600 },
  ];

  var SCREW_TYPES = {
    slotNarrow: { id: 'slotNarrow', label: 'Slot, narrow (#10+ ≤0.047 in × ≤0.25 in)', short: 'Slot narrow' },
    slotWide: { id: 'slotWide', label: 'Slot, wide (#10+ larger slot)', short: 'Slot wide' },
    hex: { id: 'hex', label: 'Hex head / external-drive socket', short: 'Hex' },
    splitBolt: { id: 'splitBolt', label: 'Split-bolt connector', short: 'Split-bolt' },
    other: { id: 'other', label: 'Other pressure wire connector', short: 'Other' },
  };

  /* UL 486A-B connecting-hardware table (hex socket across flats). Typical. */
  var HEX_SOCKET_ROWS = [
    { socket: '1/8 in', inLb: 45 },
    { socket: '5/32 in', inLb: 100 },
    { socket: '3/16 in', inLb: 120 },
    { socket: '7/32 in', inLb: 150 },
    { socket: '1/4 in', inLb: 200 },
    { socket: '5/16 in', inLb: 275 },
    { socket: '3/8 in', inLb: 375 },
    { socket: '1/2 in', inLb: 500 },
    { socket: '9/16 in and larger', inLb: 600 },
  ];

  /* Typical handbook fastener torque. Dry ≈ K=0.20; lubed shown at 75% of dry.
     Not a clamp-load study or FEA. */
  var SAE_ROWS = [
    { size: '1/4-20', grade2: 6, grade5: 10, grade8: 14 },
    { size: '5/16-18', grade2: 12, grade5: 19, grade8: 29 },
    { size: '3/8-16', grade2: 20, grade5: 33, grade8: 47 },
    { size: '7/16-14', grade2: 32, grade5: 54, grade8: 78 },
    { size: '1/2-13', grade2: 47, grade5: 78, grade8: 119 },
    { size: '9/16-12', grade2: 69, grade5: 114, grade8: 169 },
    { size: '5/8-11', grade2: 96, grade5: 154, grade8: 230 },
    { size: '3/4-10', grade2: 155, grade5: 257, grade8: 380 },
    { size: '7/8-9', grade2: 206, grade5: 382, grade8: 600 },
    { size: '1-8', grade2: 310, grade5: 587, grade8: 900 },
  ];

  var METRIC_ROWS = [
    { size: 'M5', c88: 7, c109: 10, c129: 12 },
    { size: 'M6', c88: 12, c109: 17, c129: 20 },
    { size: 'M8', c88: 29, c109: 41, c129: 48 },
    { size: 'M10', c88: 58, c109: 81, c129: 96 },
    { size: 'M12', c88: 100, c109: 140, c129: 165 },
    { size: 'M14', c88: 160, c109: 225, c129: 260 },
    { size: 'M16', c88: 240, c109: 340, c129: 400 },
    { size: 'M18', c88: 330, c109: 470, c129: 550 },
    { size: 'M20', c88: 470, c109: 660, c129: 770 },
    { size: 'M24', c88: 800, c109: 1130, c129: 1320 },
  ];

  function inLbToNm(inLb) {
    if (inLb == null) return null;
    return inLb / INLB_PER_NM;
  }

  function ftLbToNm(ftLb) {
    if (ftLb == null) return null;
    return (ftLb * 12) / INLB_PER_NM;
  }

  function formatInLbNm(inLb) {
    if (inLb == null) return '—';
    return inLb + ' in·lb  (' + inLbToNm(inLb).toFixed(1) + ' N·m)';
  }

  function normalizeSizeQuery(raw) {
    var q = String(raw || '').toLowerCase().replace(/awg|kcmil|mcm|kcm|#/g, ' ').replace(/\s+/g, ' ').trim();
    q = q.replace(/gauge/, '').trim();
    if (q === '0') q = '1/0';
    if (q === '00') q = '2/0';
    if (q === '000') q = '3/0';
    if (q === '0000') q = '4/0';
    return q;
  }

  function findLugRow(sizeQuery) {
    var q = normalizeSizeQuery(sizeQuery);
    if (!q) return null;
    var i;
    for (i = 0; i < LUG_ROWS.length; i += 1) {
      var row = LUG_ROWS[i];
      if (row.sizeKey === q || row.size.toLowerCase() === q) return row;
      if (row.sizes.indexOf(q) !== -1) return row;
    }
    /* Accept "8 awg", "4/0", "250 kcmil" after normalize. */
    for (i = 0; i < LUG_ROWS.length; i += 1) {
      if (LUG_ROWS[i].sizes.indexOf(q) !== -1) return LUG_ROWS[i];
    }
    return null;
  }

  function lookupLug(sizeQuery, screwType) {
    var row = findLugRow(sizeQuery);
    if (!row) {
      return { ok: false, error: 'No UL 486A-B typical row for that conductor size.' };
    }
    var type = SCREW_TYPES[screwType] ? screwType : 'slotNarrow';
    var inLb = row[type];
    if (inLb == null) {
      return {
        ok: false,
        error: 'UL 486A-B does not list ' + SCREW_TYPES[type].short + ' for ' + row.size + '.',
        row: row,
        screwType: type,
      };
    }
    return {
      ok: true,
      size: row.size,
      sizeKey: row.sizeKey,
      screwType: type,
      screwLabel: SCREW_TYPES[type].label,
      inLb: inLb,
      nm: inLbToNm(inLb),
      citation: 'UL 486A-B typical tightening torque (reprinted as NEC Informative Annex I). Column B–style pocket-ref values when the lug is unmarked.',
      caveat: 'Manufacturer marking on the device wins. These are typical values for an unmarked pressure wire connector — not a calibrated torque-tool substitute.',
    };
  }

  function filterLugRows(query) {
    var q = normalizeSizeQuery(query);
    if (!q) return LUG_ROWS.slice();
    return LUG_ROWS.filter(function (row) {
      if (row.size.toLowerCase().indexOf(q) !== -1) return true;
      if (row.sizeKey.indexOf(q) !== -1) return true;
      return row.sizes.some(function (s) { return s === q || s.indexOf(q) !== -1; });
    });
  }

  function lookupFastener(family, size, grade, lubed) {
    var dry;
    var unit;
    if (family === 'metric') {
      var m = METRIC_ROWS.filter(function (r) { return r.size.toLowerCase() === String(size || '').toLowerCase(); })[0];
      if (!m) return { ok: false, error: 'No typical metric row for that size.' };
      var mk = grade === '12.9' ? 'c129' : grade === '10.9' ? 'c109' : 'c88';
      dry = m[mk];
      unit = 'N·m';
      return finishFastener(m.size, 'Metric class ' + (grade || '8.8'), dry, unit, lubed, true);
    }
    var s = SAE_ROWS.filter(function (r) { return r.size.toLowerCase() === String(size || '').toLowerCase(); })[0];
    if (!s) return { ok: false, error: 'No typical SAE row for that size.' };
    var gk = grade === '8' || grade === 'grade8' ? 'grade8' : grade === '2' || grade === 'grade2' ? 'grade2' : 'grade5';
    dry = s[gk];
    unit = 'ft·lb';
    var gradeLabel = gk === 'grade8' ? 'SAE Grade 8' : gk === 'grade2' ? 'SAE Grade 2' : 'SAE Grade 5';
    return finishFastener(s.size, gradeLabel, dry, unit, lubed, false);
  }

  function finishFastener(size, gradeLabel, dry, unit, lubed, metric) {
    var factor = lubed ? 0.75 : 1;
    var value = dry * factor;
    var nm = metric ? value : ftLbToNm(value);
    var inLb = metric ? value * INLB_PER_NM : value * 12;
    return {
      ok: true,
      size: size,
      grade: gradeLabel,
      condition: lubed ? 'Lubricated (typical 75% of dry)' : 'Dry',
      dry: dry,
      value: value,
      unit: unit,
      nm: nm,
      inLb: inLb,
      citation: 'Typical published fastener handbook values. Lookup only — not a clamp-load study or FEA.',
      caveat: 'Not a calibrated torque-tool substitute. Confirm the fastener spec, plating, and lubrication with the joint design.',
    };
  }

  function el(id) {
    return document.getElementById(id);
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function cellTorque(inLb) {
    if (inLb == null) return '<td>—</td>';
    return '<td>' + inLb + ' <span class="tq-unit">in·lb</span><br><span class="tq-si">' + inLbToNm(inLb).toFixed(1) + ' N·m</span></td>';
  }

  function renderLugTable(rows) {
    var host = el('tq_lug_table');
    if (!host) return;
    var body = rows.map(function (row) {
      return '<tr data-size="' + escapeHtml(row.sizeKey) + '">' +
        '<td>' + escapeHtml(row.size) + '</td>' +
        cellTorque(row.slotNarrow) +
        cellTorque(row.slotWide) +
        cellTorque(row.hex) +
        cellTorque(row.splitBolt) +
        cellTorque(row.other) +
        '</tr>';
    }).join('');
    host.innerHTML = '<table class="ref-table tq-table"><thead><tr>' +
      '<th>Conductor</th><th>Slot narrow</th><th>Slot wide</th><th>Hex / socket</th><th>Split-bolt</th><th>Other connector</th>' +
      '</tr></thead><tbody>' + body + '</tbody></table>';
  }

  function renderHexSocketTable() {
    var host = el('tq_hex_table');
    if (!host) return;
    host.innerHTML = '<table class="ref-table tq-table"><thead><tr><th>Hex socket (across flats)</th><th>Typical torque</th></tr></thead><tbody>' +
      HEX_SOCKET_ROWS.map(function (row) {
        return '<tr><td>' + escapeHtml(row.socket) + '</td>' + cellTorque(row.inLb) + '</tr>';
      }).join('') +
      '</tbody></table>';
  }

  function renderSaeTable(lubed) {
    var host = el('tq_sae_table');
    if (!host) return;
    var factor = lubed ? 0.75 : 1;
    var cond = lubed ? 'lubed' : 'dry';
    host.innerHTML = '<table class="ref-table tq-table"><thead><tr><th>Size (UNC)</th><th>Grade 2 (' + cond + ')</th><th>Grade 5 (' + cond + ')</th><th>Grade 8 (' + cond + ')</th></tr></thead><tbody>' +
      SAE_ROWS.map(function (row) {
        return '<tr><td>' + escapeHtml(row.size) + '</td>' +
          '<td>' + (row.grade2 * factor).toFixed(0) + ' ft·lb<br><span class="tq-si">' + ftLbToNm(row.grade2 * factor).toFixed(1) + ' N·m</span></td>' +
          '<td>' + (row.grade5 * factor).toFixed(0) + ' ft·lb<br><span class="tq-si">' + ftLbToNm(row.grade5 * factor).toFixed(1) + ' N·m</span></td>' +
          '<td>' + (row.grade8 * factor).toFixed(0) + ' ft·lb<br><span class="tq-si">' + ftLbToNm(row.grade8 * factor).toFixed(1) + ' N·m</span></td></tr>';
      }).join('') +
      '</tbody></table>';
  }

  function renderMetricTable(lubed) {
    var host = el('tq_metric_table');
    if (!host) return;
    var factor = lubed ? 0.75 : 1;
    var cond = lubed ? 'lubed' : 'dry';
    host.innerHTML = '<table class="ref-table tq-table"><thead><tr><th>Size</th><th>Class 8.8 (' + cond + ')</th><th>Class 10.9 (' + cond + ')</th><th>Class 12.9 (' + cond + ')</th></tr></thead><tbody>' +
      METRIC_ROWS.map(function (row) {
        return '<tr><td>' + escapeHtml(row.size) + '</td>' +
          '<td>' + (row.c88 * factor).toFixed(0) + ' N·m<br><span class="tq-si">' + ((row.c88 * factor) * INLB_PER_NM).toFixed(0) + ' in·lb</span></td>' +
          '<td>' + (row.c109 * factor).toFixed(0) + ' N·m<br><span class="tq-si">' + ((row.c109 * factor) * INLB_PER_NM).toFixed(0) + ' in·lb</span></td>' +
          '<td>' + (row.c129 * factor).toFixed(0) + ' N·m<br><span class="tq-si">' + ((row.c129 * factor) * INLB_PER_NM).toFixed(0) + ' in·lb</span></td></tr>';
      }).join('') +
      '</tbody></table>';
  }

  function showLugResult() {
    var sizeEl = el('tq_size');
    var typeEl = el('tq_screw');
    var out = el('tq_lug_result');
    if (!sizeEl || !typeEl || !out) return;
    var result = lookupLug(sizeEl.value, typeEl.value);
    if (!result.ok) {
      out.className = 'result show';
      out.innerHTML = '<p>' + escapeHtml(result.error) + '</p>';
      return;
    }
    out.className = 'result show';
    out.innerHTML =
      '<p><strong>' + escapeHtml(result.size) + '</strong> · ' + escapeHtml(result.screwLabel) + '</p>' +
      '<p class="tq-hero">' + escapeHtml(String(result.inLb)) + ' in·lb <span class="tq-si">= ' + result.nm.toFixed(1) + ' N·m</span></p>' +
      '<p class="note">' + escapeHtml(result.citation) + '</p>' +
      '<p class="note">' + escapeHtml(result.caveat) + '</p>';
    renderLugTable(filterLugRows(el('tq_search') ? el('tq_search').value : ''));
    var match = document.querySelector('#tq_lug_table tr[data-size="' + result.sizeKey + '"]');
    if (match) match.classList.add('highlight');
  }

  function bind() {
    if (!el('sec-torque-lookup')) return;
    renderLugTable(LUG_ROWS);
    renderHexSocketTable();
    renderSaeTable(false);
    renderMetricTable(false);

    var search = el('tq_search');
    if (search) {
      search.addEventListener('input', function () {
        renderLugTable(filterLugRows(search.value));
      });
    }
    var lookupBtn = el('tq_lookup');
    if (lookupBtn) lookupBtn.addEventListener('click', showLugResult);
    ['tq_size', 'tq_screw'].forEach(function (id) {
      var node = el(id);
      if (node) node.addEventListener('change', showLugResult);
    });
    var printBtn = el('tq_print');
    if (printBtn) {
      printBtn.addEventListener('click', function () {
        document.body.classList.add('tq-printing');
        window.print();
        document.body.classList.remove('tq-printing');
      });
    }
    var lube = el('tq_lube');
    if (lube) {
      lube.addEventListener('change', function () {
        var lubed = lube.checked;
        renderSaeTable(lubed);
        renderMetricTable(lubed);
      });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bind);
  } else {
    bind();
  }

  global.__torqueLookupTestApi = {
    LUG_ROWS: LUG_ROWS,
    SCREW_TYPES: SCREW_TYPES,
    lookupLug: lookupLug,
    findLugRow: findLugRow,
    lookupFastener: lookupFastener,
    inLbToNm: inLbToNm,
    filterLugRows: filterLugRows,
  };
})(typeof window !== 'undefined' ? window : globalThis);
