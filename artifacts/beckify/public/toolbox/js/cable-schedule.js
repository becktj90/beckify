/* ============================================================================
   CABLE SCHEDULE GENERATOR
   ============================================================================
   Same scaffolding as the I/O list generator, applied to power/control cable
   runs: editable type catalog, quantity cart, sequential Cable IDs from an
   editable project prefix, in-browser grid, .xlsx/.csv/.json.
   Length, Routing / Tray, and Comments stay blank for field fill-in.
   Ampacity and voltage-drop notes reuse NEC Table 310.16 / Ch.9 Table 8 via
   BeckifyWireMath when that helper is present — tables are not duplicated.
   ============================================================================ */
(function (global) {
  'use strict';

  var COLUMNS = [
    'Cable ID', 'From', 'To', 'Cable Type', 'Conductor Size', 'Conductor Count',
    'Insulation', 'Voltage Rating', 'Length', 'Routing / Tray', 'Ampacity',
    'Voltage Drop', 'System', 'Termination From', 'Termination To', 'Comments',
  ];
  var BLANK_ON_GENERATE = ['Length', 'Routing / Tray', 'Comments'];
  var XLSX_SRC = 'js/vendor/xlsx.full.min.js';

  var SEED_CATALOG = [
    { id: 'PWR-4C-12', size: '12', count: 4, insulation: 'THHN/THWN-2', voltage: '600 V', use: 'power' },
    { id: 'PWR-3C-10', size: '10', count: 3, insulation: 'THHN/THWN-2', voltage: '600 V', use: 'power' },
    { id: 'PWR-4C-8', size: '8', count: 4, insulation: 'XHHW-2', voltage: '600 V', use: 'power' },
    { id: 'PWR-3C-4', size: '4', count: 3, insulation: 'XHHW-2', voltage: '600 V', use: 'power' },
    { id: 'PWR-3C-2/0', size: '2/0', count: 3, insulation: 'XHHW-2', voltage: '600 V', use: 'power' },
    { id: 'CTL-8C-14', size: '14', count: 8, insulation: 'THHN/THWN-2', voltage: '600 V', use: 'control' },
    { id: 'CTL-12C-16', size: '16', count: 12, insulation: 'PVC', voltage: '300 V', use: 'control' },
    { id: 'INS-1P-18', size: '18', count: 2, insulation: 'XLPE', voltage: '300 V', use: 'instrumentation' },
    { id: 'INS-2P-18', size: '18', count: 4, insulation: 'XLPE', voltage: '300 V', use: 'instrumentation' },
    { id: 'COM-CAT6', size: '23', count: 8, insulation: 'PVC', voltage: '300 V', use: 'communication' },
  ];

  var catalog = cloneCatalog(SEED_CATALOG);
  var cart = [];
  var gridRows = [];
  var xlsxPromise = null;
  var cartSeq = 1;

  function cloneCatalog(list) {
    return (list || []).map(function (item) {
      return {
        id: String(item.id || ''),
        size: String(item.size || ''),
        count: Math.max(1, Math.floor(Number(item.count) || 1)),
        insulation: String(item.insulation || ''),
        voltage: String(item.voltage || ''),
        use: String(item.use || 'power'),
      };
    });
  }

  function catalogById(list, id) {
    var key = String(id || '').trim().toUpperCase();
    for (var i = 0; i < list.length; i++) {
      if (String(list[i].id || '').trim().toUpperCase() === key) return list[i];
    }
    return null;
  }

  function padNumber(n, width) {
    var s = String(Math.max(0, Math.floor(n)));
    var w = Math.max(1, Math.floor(Number(width) || 3));
    while (s.length < w) s = '0' + s;
    return s;
  }

  function nextCableId(prefix, start, index, width) {
    var n = Math.max(1, Math.floor(Number(start) || 1)) + index;
    return String(prefix || '') + padNumber(n, width);
  }

  function blankRow() {
    var row = {};
    for (var i = 0; i < COLUMNS.length; i++) row[COLUMNS[i]] = '';
    return row;
  }

  function formatConductorSize(size) {
    var s = String(size || '').trim();
    if (!s) return '';
    if (/kcmil/i.test(s) || /AWG/i.test(s)) return s;
    if (/^(1\/0|2\/0|3\/0|4\/0)$/i.test(s)) return s + ' AWG';
    if (/^\d+$/.test(s)) {
      return Number(s) >= 250 ? s + ' kcmil' : s + ' AWG';
    }
    return s;
  }

  function ampacityNote(size, use) {
    var math = global.BeckifyWireMath;
    if (!math || typeof math.ampacity75 !== 'function') return '';
    if (use === 'communication' || use === 'instrumentation') return '';
    var cu = math.ampacity75(size, 'cu');
    if (cu == null) return '';
    return cu + ' A Cu 75°C (NEC Table 310.16, ≤3 CCC)';
  }

  function voltageDropNote(size, lengthFt, systemV, phase, amps) {
    var math = global.BeckifyWireMath;
    if (!math || typeof math.voltageDropVolts !== 'function') return '';
    var L = Number(lengthFt);
    if (!Number.isFinite(L) || L <= 0) return '';
    var I = Number(amps);
    var V = Number(systemV);
    if (!Number.isFinite(I) || I <= 0) {
      if (math.ampacity75) {
        var a = math.ampacity75(size, 'cu');
        if (a) I = 0.8 * a;
      }
    }
    if (!Number.isFinite(I) || I <= 0 || !Number.isFinite(V) || V <= 0) return '';
    var ph = phase === '3ph' ? '3ph' : '1ph';
    var vd = math.voltageDropVolts(size, 'cu', ph, I, L, 1, 1);
    if (vd == null) return '';
    var pct = (vd / V) * 100;
    var flag = pct > 5 ? ' over 5%' : pct > 3 ? ' over 3% note' : '';
    return pct.toFixed(2) + '% at ' + I.toFixed(1) + ' A assumed' + flag;
  }

  function expandBuildList(cartList, catalogList, opts) {
    var prefix = String((opts && opts.prefix) || 'C-');
    var start = (opts && opts.start) || 1;
    var width = (opts && opts.width) || 3;
    var systemV = (opts && opts.systemV) || '';
    var phase = (opts && opts.phase) || '1ph';
    var rows = [];
    var index = 0;
    var list = Array.isArray(cartList) ? cartList : [];
    var cat = Array.isArray(catalogList) ? catalogList : [];
    for (var i = 0; i < list.length; i++) {
      var item = list[i] || {};
      var qty = Math.max(1, Math.floor(Number(item.qty) || 1));
      var entry = catalogById(cat, item.typeId);
      var typeId = entry ? entry.id : String(item.typeId || '');
      var size = entry ? entry.size : String(item.size || '');
      var count = entry ? entry.count : (Number(item.count) || '');
      var insul = entry ? entry.insulation : String(item.insulation || '');
      var volt = entry ? entry.voltage : String(item.voltage || '');
      var use = entry ? entry.use : String(item.use || '');
      for (var q = 0; q < qty; q++) {
        var row = blankRow();
        row['Cable ID'] = nextCableId(prefix, start, index, width);
        row.From = String(item.from || '');
        row.To = String(item.to || '');
        row['Cable Type'] = typeId;
        row['Conductor Size'] = formatConductorSize(size);
        row['Conductor Count'] = count === '' ? '' : String(count);
        row.Insulation = insul;
        row['Voltage Rating'] = volt;
        row.Length = '';
        row['Routing / Tray'] = '';
        row.Ampacity = ampacityNote(size, use);
        row['Voltage Drop'] = '';
        row.System = String(item.system || '');
        row['Termination From'] = String(item.termFrom || '');
        row['Termination To'] = String(item.termTo || '');
        row.Comments = '';
        rows.push(row);
        index += 1;
      }
    }
    return rows;
  }

  function applyLengthVoltageDrop(rows, opts) {
    var list = Array.isArray(rows) ? rows : [];
    for (var i = 0; i < list.length; i++) {
      var row = list[i];
      var sizeKey = String(row['Conductor Size'] || '').replace(/\s*AWG\s*/i, '').replace(/\s*kcmil\s*/i, '').trim();
      row['Voltage Drop'] = voltageDropNote(sizeKey, row.Length, opts && opts.systemV, opts && opts.phase, opts && opts.amps);
    }
    return list;
  }

  function rowsToAoa(rows) {
    var aoa = [COLUMNS.slice()];
    var list = Array.isArray(rows) ? rows : [];
    for (var i = 0; i < list.length; i++) {
      var line = [];
      for (var c = 0; c < COLUMNS.length; c++) {
        var val = list[i][COLUMNS[c]];
        line.push(val == null ? '' : String(val));
      }
      aoa.push(line);
    }
    return aoa;
  }

  function csvEscape(value) {
    var s = value == null ? '' : String(value);
    if (/[",\n\r]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
    return s;
  }

  function rowsToCsv(rows) {
    return rowsToAoa(rows).map(function (line) {
      return line.map(csvEscape).join(',');
    }).join('\r\n') + '\r\n';
  }

  function serializeProject(cartList, catalogList, numbering) {
    return {
      version: 1,
      kind: 'cable-schedule-build',
      numbering: numbering || { prefix: 'C-', start: 1, width: 3 },
      catalog: cloneCatalog(catalogList || catalog),
      cart: (cartList || cart).map(function (item) {
        return {
          typeId: item.typeId,
          qty: item.qty,
          from: item.from,
          to: item.to,
          system: item.system,
          termFrom: item.termFrom,
          termTo: item.termTo,
        };
      }),
    };
  }

  function parseProject(raw) {
    var data = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (!data || typeof data !== 'object') throw new Error('Not a JSON object.');
    if (data.kind && data.kind !== 'cable-schedule-build') {
      throw new Error('This file is not a cable-schedule build (kind=' + data.kind + ').');
    }
    return {
      numbering: data.numbering || { prefix: 'C-', start: 1, width: 3 },
      catalog: Array.isArray(data.catalog) && data.catalog.length ? cloneCatalog(data.catalog) : cloneCatalog(SEED_CATALOG),
      cart: Array.isArray(data.cart) ? data.cart.map(function (item) {
        return {
          typeId: String(item.typeId || ''),
          qty: Math.max(1, Math.floor(Number(item.qty) || 1)),
          from: String(item.from || ''),
          to: String(item.to || ''),
          system: String(item.system || ''),
          termFrom: String(item.termFrom || ''),
          termTo: String(item.termTo || ''),
        };
      }) : [],
    };
  }

  function loadXlsx() {
    if (xlsxPromise) return xlsxPromise;
    xlsxPromise = new Promise(function (resolve, reject) {
      if (global.XLSX && global.XLSX.utils) return resolve(global.XLSX);
      var s = document.createElement('script');
      s.src = XLSX_SRC;
      s.onload = function () {
        if (global.XLSX && global.XLSX.utils) resolve(global.XLSX);
        else reject(new Error('SheetJS loaded but did not register'));
      };
      s.onerror = function () {
        xlsxPromise = null;
        reject(new Error('Could not load the local SheetJS library'));
      };
      document.head.appendChild(s);
    });
    return xlsxPromise;
  }

  function downloadBlob(filename, blob) {
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
  }
  function downloadText(filename, text, mime) {
    downloadBlob(filename, new Blob([text], { type: mime || 'text/plain' }));
  }
  function el(id) { return document.getElementById(id); }
  function escapeHtml(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function numberingOpts() {
    return {
      prefix: el('cab_prefix') ? el('cab_prefix').value : 'C-',
      start: el('cab_start') ? Number(el('cab_start').value) || 1 : 1,
      width: el('cab_width') ? Number(el('cab_width').value) || 3 : 3,
      systemV: el('cab_sys_v') ? Number(el('cab_sys_v').value) : NaN,
      phase: el('cab_phase') ? el('cab_phase').value : '1ph',
    };
  }

  function renderCatalog() {
    var host = el('cab_catalog_host');
    if (!host) return;
    var html = '<div class="ref-table-wrap iol-table-wrap"><table class="ref-table iol-table" aria-label="Cable type catalog"><thead><tr>' +
      '<th>Cable ID prefix</th><th>Size</th><th>Count</th><th>Insulation</th><th>Voltage</th><th>Typical use</th><th> </th></tr></thead><tbody>';
    for (var i = 0; i < catalog.length; i++) {
      var c = catalog[i];
      html += '<tr><td><input type="text" data-cab-cat="id" data-i="' + i + '" value="' + escapeHtml(c.id) + '" aria-label="Type id"></td>';
      html += '<td><input type="text" data-cab-cat="size" data-i="' + i + '" value="' + escapeHtml(c.size) + '" aria-label="Conductor size"></td>';
      html += '<td><input type="number" min="1" step="1" data-cab-cat="count" data-i="' + i + '" value="' + escapeHtml(c.count) + '" aria-label="Conductor count"></td>';
      html += '<td><input type="text" data-cab-cat="insulation" data-i="' + i + '" value="' + escapeHtml(c.insulation) + '" aria-label="Insulation"></td>';
      html += '<td><input type="text" data-cab-cat="voltage" data-i="' + i + '" value="' + escapeHtml(c.voltage) + '" aria-label="Voltage rating"></td>';
      html += '<td><input type="text" list="cab_uses" data-cab-cat="use" data-i="' + i + '" value="' + escapeHtml(c.use) + '" aria-label="Typical use"></td>';
      html += '<td><button type="button" class="btn-remove" data-cab-cat-remove="' + i + '" aria-label="Remove type">×</button></td></tr>';
    }
    html += '</tbody></table></div>';
    host.innerHTML = html;
  }

  function renderCart() {
    var host = el('cab_cart_host');
    if (!host) return;
    var options = catalog.map(function (c) {
      return '<option value="' + escapeHtml(c.id) + '">' + escapeHtml(c.id + ' — ' + c.size + ' AWG × ' + c.count + ' · ' + c.use) + '</option>';
    }).join('');
    var sel = el('cab_type');
    if (sel) sel.innerHTML = options;
    var html = '<ol class="iol-cart" aria-label="Cable build list">';
    if (!cart.length) html += '<li class="iol-cart-empty">No cables yet. Pick a type, from/to tags, and add a quantity.</li>';
    for (var i = 0; i < cart.length; i++) {
      var item = cart[i];
      html += '<li><span>' + escapeHtml(item.typeId) + ' × ' + item.qty + ' · ' + escapeHtml(item.from || '—') + ' → ' + escapeHtml(item.to || '—') + '</span>';
      html += '<button type="button" class="btn-remove" data-cab-cart-remove="' + i + '" aria-label="Remove cable">×</button></li>';
    }
    html += '</ol>';
    host.innerHTML = html;
  }

  function renderGrid() {
    var host = el('cab_grid_host');
    if (!host) return;
    if (!gridRows.length) {
      host.innerHTML = '<p class="note">Generate a schedule from the build list, or add a blank row.</p>';
      return;
    }
    var html = '<div class="ref-table-wrap iol-grid-wrap"><table class="ref-table iol-grid" aria-label="Editable cable schedule"><thead><tr>';
    for (var c = 0; c < COLUMNS.length; c++) html += '<th scope="col">' + escapeHtml(COLUMNS[c]) + '</th>';
    html += '<th scope="col"> </th></tr></thead><tbody>';
    for (var r = 0; r < gridRows.length; r++) {
      html += '<tr>';
      for (var c = 0; c < COLUMNS.length; c++) {
        var key = COLUMNS[c];
        var val = gridRows[r][key] == null ? '' : String(gridRows[r][key]);
        html += '<td><input type="text" data-cab-cell="' + r + ':' + c + '" value="' + escapeHtml(val) + '" aria-label="' + escapeHtml(key + ' row ' + (r + 1)) + '"></td>';
      }
      html += '<td><button type="button" class="btn-remove" data-cab-del-row="' + r + '" aria-label="Remove row">×</button></td></tr>';
    }
    html += '</tbody></table></div>';
    host.innerHTML = html;
  }

  function generateFromCart() {
    gridRows = expandBuildList(cart, catalog, numberingOpts());
    renderGrid();
    setStatus('Generated ' + gridRows.length + ' cable row' + (gridRows.length === 1 ? '' : 's') + '. Length, routing, and comments are blank for the field.');
  }

  function setStatus(msg) {
    var host = el('cab_status');
    if (host) host.textContent = msg;
  }

  function onSectionClick(ev) {
    var t = ev.target;
    if (!t || !t.getAttribute) return;
    if (t.getAttribute('data-cab-cat-remove') !== null) {
      catalog.splice(Number(t.getAttribute('data-cab-cat-remove')), 1);
      renderCatalog();
      renderCart();
      return;
    }
    if (t.getAttribute('data-cab-cart-remove') !== null) {
      cart.splice(Number(t.getAttribute('data-cab-cart-remove')), 1);
      renderCart();
      return;
    }
    if (t.getAttribute('data-cab-del-row') !== null) {
      gridRows.splice(Number(t.getAttribute('data-cab-del-row')), 1);
      renderGrid();
    }
  }

  function onSectionInput(ev) {
    var t = ev.target;
    if (!t || !t.getAttribute) return;
    if (t.getAttribute('data-cab-cat') !== null) {
      var i = Number(t.getAttribute('data-i'));
      var field = t.getAttribute('data-cab-cat');
      if (!catalog[i] || !field) return;
      if (field === 'count') catalog[i].count = Math.max(1, Math.floor(Number(t.value) || 1));
      else catalog[i][field] = t.value;
      return;
    }
    if (t.getAttribute('data-cab-cell') !== null) {
      var parts = t.getAttribute('data-cab-cell').split(':');
      var r = Number(parts[0]);
      var c = Number(parts[1]);
      if (gridRows[r] && COLUMNS[c]) {
        gridRows[r][COLUMNS[c]] = t.value;
        if (COLUMNS[c] === 'Length') {
          applyLengthVoltageDrop([gridRows[r]], numberingOpts());
          var cell = ev.target;
          if (COLUMNS.indexOf('Voltage Drop') >= 0) {
            var vdIdx = COLUMNS.indexOf('Voltage Drop');
            var vdInput = cell.closest('tr') && cell.closest('tr').querySelector('[data-cab-cell="' + r + ':' + vdIdx + '"]');
            if (vdInput) vdInput.value = gridRows[r]['Voltage Drop'];
          }
        }
      }
    }
  }

  function init() {
    if (!el('sec-cable-schedule')) return;
    renderCatalog();
    renderCart();
    renderGrid();
    var section = el('sec-cable-schedule');
    section.addEventListener('click', onSectionClick);
    section.addEventListener('input', onSectionInput);
    section.addEventListener('change', onSectionInput);

    var addCat = el('cab_add_catalog');
    if (addCat) addCat.addEventListener('click', function () {
      catalog.push({ id: '', size: '12', count: 3, insulation: 'THHN/THWN-2', voltage: '600 V', use: 'power' });
      renderCatalog();
    });
    var addCart = el('cab_add');
    if (addCart) addCart.addEventListener('click', function () {
      cart.push({
        id: 'cab-' + (cartSeq++),
        typeId: el('cab_type') ? el('cab_type').value : '',
        qty: Math.max(1, Math.floor(Number(el('cab_qty') && el('cab_qty').value) || 1)),
        from: el('cab_from') ? el('cab_from').value : '',
        to: el('cab_to') ? el('cab_to').value : '',
        system: el('cab_system') ? el('cab_system').value : '',
        termFrom: el('cab_term_from') ? el('cab_term_from').value : '',
        termTo: el('cab_term_to') ? el('cab_term_to').value : '',
      });
      renderCart();
    });
    var gen = el('cab_generate');
    if (gen) gen.addEventListener('click', generateFromCart);
    var addRow = el('cab_add_row');
    if (addRow) addRow.addEventListener('click', function () {
      gridRows.push(blankRow());
      renderGrid();
    });
    var csvBtn = el('cab_export_csv');
    if (csvBtn) csvBtn.addEventListener('click', function () {
      if (!gridRows.length) generateFromCart();
      downloadText('cable-schedule.csv', rowsToCsv(gridRows), 'text/csv;charset=utf-8');
    });
    var xlsxBtn = el('cab_export_xlsx');
    if (xlsxBtn) xlsxBtn.addEventListener('click', function () {
      if (!gridRows.length) generateFromCart();
      loadXlsx().then(function (XLSX) {
        var wb = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(rowsToAoa(gridRows)), 'Cable Schedule');
        var out = XLSX.write(wb, { bookType: 'xlsx', type: 'array' });
        downloadBlob('cable-schedule.xlsx', new Blob([out], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }));
      }).catch(function (err) { setStatus(err.message || String(err)); });
    });
    var saveBtn = el('cab_save');
    if (saveBtn) saveBtn.addEventListener('click', function () {
      downloadText('cable-schedule-build.json', JSON.stringify(serializeProject(cart, catalog, numberingOpts()), null, 2), 'application/json;charset=utf-8');
    });
    var loadBtn = el('cab_load');
    var fileEl = el('cab_load_file');
    if (loadBtn && fileEl) {
      loadBtn.addEventListener('click', function () { fileEl.click(); });
      fileEl.addEventListener('change', function () {
        var f = fileEl.files && fileEl.files[0];
        if (!f) return;
        var reader = new FileReader();
        reader.onload = function () {
          try {
            var parsed = parseProject(String(reader.result || ''));
            catalog = parsed.catalog;
            cart = parsed.cart;
            if (el('cab_prefix') && parsed.numbering.prefix) el('cab_prefix').value = parsed.numbering.prefix;
            if (el('cab_start') && parsed.numbering.start) el('cab_start').value = parsed.numbering.start;
            if (el('cab_width') && parsed.numbering.width) el('cab_width').value = parsed.numbering.width;
            gridRows = [];
            renderCatalog();
            renderCart();
            renderGrid();
            setStatus('Loaded build list from ' + f.name + '. Generate to expand the table.');
          } catch (err) { setStatus(err.message || String(err)); }
        };
        reader.readAsText(f);
        fileEl.value = '';
      });
    }
    if (typeof registerUrlState === 'function') registerUrlState('sec-cable-schedule', 'cable-schedule', null);
    if (typeof bindLastUsed === 'function') bindLastUsed('sec-cable-schedule', 'cable-schedule');
  }

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
  }

  global.__cableScheduleTestApi = {
    COLUMNS: COLUMNS,
    BLANK_ON_GENERATE: BLANK_ON_GENERATE,
    SEED_CATALOG: cloneCatalog(SEED_CATALOG),
    catalogById: catalogById,
    nextCableId: nextCableId,
    padNumber: padNumber,
    formatConductorSize: formatConductorSize,
    expandBuildList: expandBuildList,
    applyLengthVoltageDrop: applyLengthVoltageDrop,
    rowsToCsv: rowsToCsv,
    rowsToAoa: rowsToAoa,
    serializeProject: serializeProject,
    parseProject: parseProject,
  };
})(typeof window !== 'undefined' ? window : globalThis);
