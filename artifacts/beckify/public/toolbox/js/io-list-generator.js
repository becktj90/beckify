/* ============================================================================
   I/O LIST GENERATOR
   ============================================================================
   Scaffold a PLC I/O list from a parts cart of EtherCAT (or similar) modules.
   Couplers and power-refresh cards consume a slot and emit one documentation
   row even with zero channels. Analog families copy Raw Min / Raw Max from the
   editable catalog — those numbers are not guessed at generate time.

   Design aid only. Not a PE stamp, not a wiring schedule, not a submittal.
   ============================================================================ */

(function (global) {
  'use strict';

  const COLUMNS = [
    'Controller',
    'Card Name',
    'Card Part Number',
    'Station Name',
    'Slot Number',
    'Channel Number',
    'Wire Terminal',
    'Wire Number',
    'Linked PLC Variable Name',
    'Description',
    'System',
    'Device Category',
    'Signal Type',
    'Min',
    'Max',
    'Units',
    'Raw Min',
    'Raw Max',
    'Field Device',
    'Intermediate Device',
    'Comments',
  ];

  const BLANK_ON_GENERATE = [
    'Wire Number',
    'Linked PLC Variable Name',
    'Description',
    'System',
    'Device Category',
    'Min',
    'Max',
    'Units',
    'Field Device',
    'Intermediate Device',
    'Comments',
  ];

  const ANALOG_FAMILIES = { AI: true, AO: true, RTD: true, TC: true };
  const CHANNEL_FAMILIES = { DI: true, DO: true, AI: true, AO: true, RTD: true, TC: true, 'IO-Link': true };
  const XLSX_SRC = 'js/vendor/xlsx.full.min.js';

  const SEED_CATALOG = [
    { pn: 'EK1100', description: 'EtherCAT Coupler RJ45', channels: 0, signalType: 'Coupler', rawMin: '', rawMax: '' },
    { pn: 'EK1110', description: 'EtherCAT Extension RJ45', channels: 0, signalType: 'Coupler', rawMin: '', rawMax: '' },
    { pn: 'EL9410', description: 'E-bus / Power Refresh', channels: 0, signalType: 'Power', rawMin: '', rawMax: '' },
    { pn: 'EL1819', description: '16ch DI 24VDC', channels: 16, signalType: 'DI', rawMin: '', rawMax: '' },
    { pn: 'EL2828', description: '8ch DO 24VDC 2A', channels: 8, signalType: 'DO', rawMin: '', rawMax: '' },
    { pn: 'EL3048', description: '8ch AI 0–20mA 12-bit', channels: 8, signalType: 'AI', rawMin: '0', rawMax: '4095' },
    { pn: 'EL4022', description: '2ch AO 4–20mA', channels: 2, signalType: 'AO', rawMin: '0', rawMax: '32767' },
    { pn: 'EL4024', description: '4ch AO 4–20mA', channels: 4, signalType: 'AO', rawMin: '0', rawMax: '32767' },
    { pn: 'EL3068', description: '8ch AI 0–10V 12-bit', channels: 8, signalType: 'AI', rawMin: '0', rawMax: '4095' },
    { pn: 'EL3214', description: '4ch AI RTD Pt100', channels: 4, signalType: 'RTD', rawMin: '0', rawMax: '32767' },
    { pn: 'EL3318', description: '8ch AI thermocouple 16-bit', channels: 8, signalType: 'TC', rawMin: '-32768', rawMax: '32767' },
    { pn: 'EL6224', description: '4ch IO-Link master', channels: 4, signalType: 'IO-Link', rawMin: '', rawMax: '' },
  ];

  let xlsxPromise = null;
  let catalog = cloneCatalog(SEED_CATALOG);
  let stations = [emptyStation(1)];
  let gridRows = [];
  let stationSeq = 1;
  let moduleSeq = 1;

  function cloneCatalog(list) {
    return list.map(function (item) {
      return {
        pn: String(item.pn || ''),
        description: String(item.description || ''),
        channels: Number(item.channels) || 0,
        signalType: String(item.signalType || ''),
        rawMin: item.rawMin === undefined || item.rawMin === null ? '' : String(item.rawMin),
        rawMax: item.rawMax === undefined || item.rawMax === null ? '' : String(item.rawMax),
      };
    });
  }

  function emptyStation(n) {
    return {
      id: 'st-' + n,
      controller: 'PLC-1',
      stationName: n === 1 ? 'Station 1' : 'Station ' + n,
      cardPrefix: 'C',
      modules: [],
    };
  }

  function catalogByPn(list, pn) {
    const key = String(pn || '').trim().toUpperCase();
    for (let i = 0; i < list.length; i++) {
      if (String(list[i].pn || '').trim().toUpperCase() === key) return list[i];
    }
    return null;
  }

  function isAnalogFamily(signalType) {
    return !!ANALOG_FAMILIES[String(signalType || '').trim()];
  }

  function cardNameFor(prefix, slot) {
    return String(prefix || '') + String(slot);
  }

  function blankRow() {
    const row = {};
    for (let i = 0; i < COLUMNS.length; i++) row[COLUMNS[i]] = '';
    return row;
  }

  function makeChannelRow(opts) {
    const row = blankRow();
    row.Controller = opts.controller;
    row['Card Name'] = opts.cardName;
    row['Card Part Number'] = opts.partNumber;
    row['Station Name'] = opts.stationName;
    row['Slot Number'] = String(opts.slot);
    row['Channel Number'] = opts.channel === '' || opts.channel === undefined || opts.channel === null ? '' : String(opts.channel);
    row['Wire Terminal'] = row['Channel Number'];
    row['Signal Type'] = opts.signalType;
    if (isAnalogFamily(opts.signalType)) {
      row['Raw Min'] = opts.rawMin === undefined || opts.rawMin === null ? '' : String(opts.rawMin);
      row['Raw Max'] = opts.rawMax === undefined || opts.rawMax === null ? '' : String(opts.rawMax);
    }
    return row;
  }

  /**
   * Expand a station/module BUILD LIST into one row per channel.
   * Zero-channel modules (coupler / power) still emit one documentation row
   * and still consume a slot.
   */
  function expandBuildList(stationList, catalogList) {
    const rows = [];
    const stationsIn = Array.isArray(stationList) ? stationList : [];
    const cat = Array.isArray(catalogList) ? catalogList : [];
    for (let s = 0; s < stationsIn.length; s++) {
      const station = stationsIn[s] || {};
      const controller = String(station.controller || '');
      const stationName = String(station.stationName || '');
      const prefix = String(station.cardPrefix || '');
      const modules = Array.isArray(station.modules) ? station.modules : [];
      let slot = 0;
      for (let m = 0; m < modules.length; m++) {
        const item = modules[m] || {};
        const qty = Math.max(1, Math.floor(Number(item.qty) || 1));
        const entry = catalogByPn(cat, item.pn);
        const partNumber = entry ? entry.pn : String(item.pn || '');
        const signalType = entry ? entry.signalType : String(item.signalType || '');
        const channels = entry ? (Number(entry.channels) || 0) : (Number(item.channels) || 0);
        const rawMin = entry ? entry.rawMin : '';
        const rawMax = entry ? entry.rawMax : '';
        for (let q = 0; q < qty; q++) {
          slot += 1;
          const cardName = cardNameFor(prefix, slot);
          if (channels <= 0) {
            rows.push(makeChannelRow({
              controller: controller,
              cardName: cardName,
              partNumber: partNumber,
              stationName: stationName,
              slot: slot,
              channel: '',
              signalType: signalType,
              rawMin: rawMin,
              rawMax: rawMax,
            }));
          } else {
            for (let ch = 1; ch <= channels; ch++) {
              rows.push(makeChannelRow({
                controller: controller,
                cardName: cardName,
                partNumber: partNumber,
                stationName: stationName,
                slot: slot,
                channel: ch,
                signalType: signalType,
                rawMin: rawMin,
                rawMax: rawMax,
              }));
            }
          }
        }
      }
    }
    return rows;
  }

  function summarizeRows(rows) {
    const totals = { DI: 0, DO: 0, AI: 0, AO: 0, RTD: 0, TC: 0, couplers: 0, power: 0, totalChannels: 0, rows: 0, slots: 0 };
    const slots = new Set();
    const list = Array.isArray(rows) ? rows : [];
    totals.rows = list.length;
    for (let i = 0; i < list.length; i++) {
      const row = list[i] || {};
      const kind = String(row['Signal Type'] || '').trim();
      const slotKey = [row.Controller, row['Station Name'], row['Slot Number']].join('\u0001');
      slots.add(slotKey);
      if (kind === 'Coupler') totals.couplers += 1;
      if (kind === 'Power') totals.power += 1;
      if (CHANNEL_FAMILIES[kind]) {
        totals.totalChannels += 1;
        if (Object.prototype.hasOwnProperty.call(totals, kind)) totals[kind] += 1;
      }
    }
    totals.slots = slots.size;
    // Coupler count is modules (rows), not channels — each 0-ch module is one row.
    return totals;
  }

  function rowsToAoa(rows) {
    const aoa = [COLUMNS.slice()];
    const list = Array.isArray(rows) ? rows : [];
    for (let i = 0; i < list.length; i++) {
      const row = list[i] || {};
      const line = [];
      for (let c = 0; c < COLUMNS.length; c++) {
        const key = COLUMNS[c];
        const val = row[key];
        line.push(val === undefined || val === null ? '' : String(val));
      }
      aoa.push(line);
    }
    return aoa;
  }

  function csvEscape(value) {
    const s = value === undefined || value === null ? '' : String(value);
    if (/[",\n\r]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
    return s;
  }

  function rowsToCsv(rows) {
    const aoa = rowsToAoa(rows);
    return aoa.map(function (line) {
      return line.map(csvEscape).join(',');
    }).join('\r\n') + '\r\n';
  }

  function summarySheetAoa(summary) {
    return [
      ['Metric', 'Count'],
      ['DI channels', summary.DI],
      ['DO channels', summary.DO],
      ['AI channels', summary.AI],
      ['AO channels', summary.AO],
      ['RTD channels', summary.RTD],
      ['TC channels', summary.TC],
      ['Coupler count', summary.couplers],
      ['Total channels', summary.totalChannels],
    ];
  }

  function serializeProject(stationList, catalogList) {
    return {
      version: 1,
      kind: 'io-list-build',
      catalog: cloneCatalog(catalogList || catalog),
      stations: (stationList || stations).map(function (st) {
        return {
          id: st.id,
          controller: st.controller,
          stationName: st.stationName,
          cardPrefix: st.cardPrefix,
          modules: (st.modules || []).map(function (m) {
            return { pn: m.pn, qty: m.qty };
          }),
        };
      }),
    };
  }

  function parseProject(raw) {
    const data = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (!data || typeof data !== 'object') throw new Error('Not a JSON object.');
    if (data.kind && data.kind !== 'io-list-build') {
      throw new Error('This file is not an I/O list build (kind=' + data.kind + ').');
    }
    const nextCatalog = Array.isArray(data.catalog) && data.catalog.length
      ? cloneCatalog(data.catalog)
      : cloneCatalog(SEED_CATALOG);
    const nextStations = Array.isArray(data.stations) && data.stations.length
      ? data.stations.map(function (st, i) {
        return {
          id: st.id || ('st-' + (i + 1)),
          controller: String(st.controller || ''),
          stationName: String(st.stationName || ''),
          cardPrefix: String(st.cardPrefix || ''),
          modules: Array.isArray(st.modules) ? st.modules.map(function (m) {
            return { pn: String(m.pn || ''), qty: Math.max(1, Math.floor(Number(m.qty) || 1)) };
          }) : [],
        };
      })
      : [emptyStation(1)];
    return { catalog: nextCatalog, stations: nextStations };
  }

  function loadXlsx() {
    if (xlsxPromise) return xlsxPromise;
    xlsxPromise = new Promise(function (resolve, reject) {
      if (global.XLSX && global.XLSX.utils) return resolve(global.XLSX);
      const s = document.createElement('script');
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
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
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
    return String(s === undefined || s === null ? '' : s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function renderCatalog() {
    const host = el('iol_catalog_host');
    if (!host) return;
    let html = '<div class="ref-table-wrap iol-table-wrap"><table class="ref-table iol-table" aria-label="I/O module catalog">';
    html += '<thead><tr><th scope="col">Part number</th><th scope="col">Description</th><th scope="col">Channels</th><th scope="col">Signal type</th><th scope="col">Raw min</th><th scope="col">Raw max</th><th scope="col"> </th></tr></thead><tbody>';
    for (let i = 0; i < catalog.length; i++) {
      const c = catalog[i];
      const analog = isAnalogFamily(c.signalType);
      html += '<tr data-index="' + i + '">';
      html += '<td><input type="text" data-iol-cat="pn" data-i="' + i + '" value="' + escapeHtml(c.pn) + '" aria-label="Part number"></td>';
      html += '<td><input type="text" data-iol-cat="description" data-i="' + i + '" value="' + escapeHtml(c.description) + '" aria-label="Description"></td>';
      html += '<td><input type="number" min="0" step="1" data-iol-cat="channels" data-i="' + i + '" value="' + escapeHtml(c.channels) + '" aria-label="Channel count"></td>';
      html += '<td><input type="text" list="iol_signal_types" data-iol-cat="signalType" data-i="' + i + '" value="' + escapeHtml(c.signalType) + '" aria-label="Signal type"></td>';
      html += '<td><input type="text" data-iol-cat="rawMin" data-i="' + i + '" value="' + escapeHtml(c.rawMin) + '" aria-label="Raw min"' + (analog ? '' : ' placeholder="AI/AO/RTD/TC"') + '></td>';
      html += '<td><input type="text" data-iol-cat="rawMax" data-i="' + i + '" value="' + escapeHtml(c.rawMax) + '" aria-label="Raw max"' + (analog ? '' : ' placeholder="AI/AO/RTD/TC"') + '></td>';
      html += '<td><button type="button" class="btn-remove" data-iol-cat-remove="' + i + '" aria-label="Remove catalog part ' + escapeHtml(c.pn) + '">×</button></td>';
      html += '</tr>';
    }
    html += '</tbody></table></div>';
    host.innerHTML = html;
  }

  function renderStations() {
    const host = el('iol_stations_host');
    if (!host) return;
    const options = catalog.map(function (c) {
      return '<option value="' + escapeHtml(c.pn) + '">' + escapeHtml(c.pn + ' — ' + c.description + ' (' + c.signalType + ', ' + c.channels + ' ch)') + '</option>';
    }).join('');
    let html = '';
    for (let s = 0; s < stations.length; s++) {
      const st = stations[s];
      html += '<div class="iol-station" data-station="' + escapeHtml(st.id) + '">';
      html += '<div class="iol-station-head">';
      html += '<strong>' + escapeHtml(st.stationName || ('Station ' + (s + 1))) + '</strong>';
      html += '<button type="button" class="btn btn-secondary btn-sm" data-iol-remove-station="' + s + '">Remove station</button>';
      html += '</div>';
      html += '<div class="input-group triple">';
      html += '<div><label for="iol_ctrl_' + s + '">Controller</label><input type="text" id="iol_ctrl_' + s + '" data-iol-st="controller" data-s="' + s + '" value="' + escapeHtml(st.controller) + '"></div>';
      html += '<div><label for="iol_name_' + s + '">Station name</label><input type="text" id="iol_name_' + s + '" data-iol-st="stationName" data-s="' + s + '" value="' + escapeHtml(st.stationName) + '"></div>';
      html += '<div><label for="iol_pfx_' + s + '">Card-name prefix</label><input type="text" id="iol_pfx_' + s + '" data-iol-st="cardPrefix" data-s="' + s + '" value="' + escapeHtml(st.cardPrefix) + '" aria-describedby="iol_pfx_hint"></div>';
      html += '</div>';
      html += '<div class="input-group triple iol-cart-add">';
      html += '<div><label for="iol_pn_' + s + '">Catalog part</label><select id="iol_pn_' + s + '">' + options + '</select></div>';
      html += '<div><label for="iol_qty_' + s + '">Quantity</label><input type="number" id="iol_qty_' + s + '" min="1" step="1" value="1"></div>';
      html += '<div class="iol-add-wrap"><button type="button" class="btn btn-sm" data-iol-add="' + s + '">Add to cart</button></div>';
      html += '</div>';
      html += '<ol class="iol-cart" aria-label="Module build list">';
      if (!st.modules.length) {
        html += '<li class="iol-cart-empty">No modules yet. Pick a part number and add it.</li>';
      }
      let slotPreview = 0;
      for (let m = 0; m < st.modules.length; m++) {
        const item = st.modules[m];
        const entry = catalogByPn(catalog, item.pn);
        const qty = item.qty;
        const ch = entry ? entry.channels : 0;
        const kind = entry ? entry.signalType : '';
        const firstSlot = slotPreview + 1;
        slotPreview += qty;
        const lastSlot = slotPreview;
        const slotLabel = firstSlot === lastSlot ? ('slot ' + firstSlot) : ('slots ' + firstSlot + '–' + lastSlot);
        html += '<li>';
        html += '<span>' + escapeHtml(item.pn) + ' × ' + qty + ' · ' + escapeHtml(kind) + ' · ' + ch + ' ch · ' + slotLabel + '</span>';
        html += '<button type="button" class="btn-remove" data-iol-remove-mod="' + s + ':' + m + '" aria-label="Remove ' + escapeHtml(item.pn) + '">×</button>';
        html += '</li>';
      }
      html += '</ol></div>';
    }
    host.innerHTML = html;
  }

  function renderSummary() {
    const host = el('iol_summary');
    if (!host) return;
    const s = summarizeRows(gridRows);
    host.innerHTML =
      '<div class="res-row"><span class="res-label">DI channels</span><span class="res-val">' + s.DI + '</span></div>' +
      '<div class="res-row"><span class="res-label">DO channels</span><span class="res-val">' + s.DO + '</span></div>' +
      '<div class="res-row"><span class="res-label">AI channels</span><span class="res-val">' + s.AI + '</span></div>' +
      '<div class="res-row"><span class="res-label">AO channels</span><span class="res-val">' + s.AO + '</span></div>' +
      '<div class="res-row"><span class="res-label">RTD channels</span><span class="res-val">' + s.RTD + '</span></div>' +
      '<div class="res-row"><span class="res-label">TC channels</span><span class="res-val">' + s.TC + '</span></div>' +
      '<div class="res-row"><span class="res-label">Coupler count</span><span class="res-val">' + s.couplers + '</span></div>' +
      '<div class="res-row"><span class="res-label">Total channels</span><span class="res-val">' + s.totalChannels + '</span></div>';
    host.classList.add('show');
  }

  function renderGrid() {
    const host = el('iol_grid_host');
    if (!host) return;
    if (!gridRows.length) {
      host.innerHTML = '<p class="note">Generate a list from the parts cart, or add a blank row.</p>';
      return;
    }
    let html = '<div class="ref-table-wrap iol-grid-wrap"><table class="ref-table iol-grid" aria-label="Editable I/O list">';
    html += '<thead><tr>';
    for (let c = 0; c < COLUMNS.length; c++) {
      html += '<th scope="col">' + escapeHtml(COLUMNS[c]) + '</th>';
    }
    html += '<th scope="col"> </th></tr></thead><tbody>';
    for (let r = 0; r < gridRows.length; r++) {
      html += '<tr>';
      for (let c = 0; c < COLUMNS.length; c++) {
        const key = COLUMNS[c];
        const val = gridRows[r][key] === undefined || gridRows[r][key] === null ? '' : String(gridRows[r][key]);
        html += '<td><input type="text" data-iol-cell="' + r + ':' + c + '" value="' + escapeHtml(val) + '" aria-label="' + escapeHtml(key + ' row ' + (r + 1)) + '"></td>';
      }
      html += '<td><button type="button" class="btn-remove" data-iol-del-row="' + r + '" aria-label="Remove row ' + (r + 1) + '">×</button></td>';
      html += '</tr>';
    }
    html += '</tbody></table></div>';
    host.innerHTML = html;
  }

  function readCatalogField(target) {
    const i = Number(target.getAttribute('data-i'));
    const field = target.getAttribute('data-iol-cat');
    if (!catalog[i] || !field) return;
    if (field === 'channels') catalog[i].channels = Math.max(0, Math.floor(Number(target.value) || 0));
    else catalog[i][field] = target.value;
  }

  function generateFromCart() {
    gridRows = expandBuildList(stations, catalog);
    renderGrid();
    renderSummary();
  }

  function addBlankRow() {
    gridRows.push(blankRow());
    renderGrid();
    renderSummary();
  }

  function stampProjectName() {
    const first = stations[0];
    const name = first && (first.stationName || first.controller);
    const slug = String(name || 'io-list').replace(/[^\w.-]+/g, '-').replace(/^-|-$/g, '');
    return slug || 'io-list';
  }

  function exportCsv() {
    if (!gridRows.length) generateFromCart();
    downloadText(stampProjectName() + '-io-list.csv', rowsToCsv(gridRows), 'text/csv;charset=utf-8');
  }

  function exportXlsx() {
    if (!gridRows.length) generateFromCart();
    const summary = summarizeRows(gridRows);
    loadXlsx().then(function (XLSX) {
      const wb = XLSX.utils.book_new();
      const ioSheet = XLSX.utils.aoa_to_sheet(rowsToAoa(gridRows));
      const sumSheet = XLSX.utils.aoa_to_sheet(summarySheetAoa(summary));
      XLSX.utils.book_append_sheet(wb, ioSheet, 'I-O List');
      XLSX.utils.book_append_sheet(wb, sumSheet, 'Summary');
      const out = XLSX.write(wb, { bookType: 'xlsx', type: 'array' });
      downloadBlob(stampProjectName() + '-io-list.xlsx', new Blob([out], {
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      }));
    }).catch(function (err) {
      const host = el('iol_status');
      if (host) host.textContent = err.message || String(err);
    });
  }

  function saveProject() {
    const json = JSON.stringify(serializeProject(stations, catalog), null, 2);
    downloadText(stampProjectName() + '-io-build.json', json, 'application/json;charset=utf-8');
  }

  function applyProject(parsed) {
    catalog = parsed.catalog;
    stations = parsed.stations;
    stationSeq = stations.length;
    gridRows = [];
    renderCatalog();
    renderStations();
    renderGrid();
    renderSummary();
  }

  function loadProjectFile(file) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = function () {
      try {
        applyProject(parseProject(String(reader.result || '')));
        const host = el('iol_status');
        if (host) host.textContent = 'Loaded build list from ' + file.name + '. Generate to expand the table.';
      } catch (err) {
        const host = el('iol_status');
        if (host) host.textContent = err.message || String(err);
      }
    };
    reader.readAsText(file);
  }

  function onSectionClick(ev) {
    const t = ev.target;
    if (!t || !t.getAttribute) return;
    if (t.getAttribute('data-iol-cat-remove') !== null) {
      const i = Number(t.getAttribute('data-iol-cat-remove'));
      catalog.splice(i, 1);
      renderCatalog();
      renderStations();
      return;
    }
    if (t.getAttribute('data-iol-remove-station') !== null) {
      const s = Number(t.getAttribute('data-iol-remove-station'));
      stations.splice(s, 1);
      if (!stations.length) stations = [emptyStation(1)];
      renderStations();
      return;
    }
    if (t.getAttribute('data-iol-add') !== null) {
      const s = Number(t.getAttribute('data-iol-add'));
      const pnEl = el('iol_pn_' + s);
      const qtyEl = el('iol_qty_' + s);
      const pn = pnEl ? pnEl.value : '';
      const qty = Math.max(1, Math.floor(Number(qtyEl && qtyEl.value) || 1));
      if (pn && stations[s]) {
        stations[s].modules.push({ pn: pn, qty: qty, id: 'mod-' + (moduleSeq++) });
        renderStations();
      }
      return;
    }
    if (t.getAttribute('data-iol-remove-mod') !== null) {
      const parts = t.getAttribute('data-iol-remove-mod').split(':');
      const s = Number(parts[0]);
      const m = Number(parts[1]);
      if (stations[s]) {
        stations[s].modules.splice(m, 1);
        renderStations();
      }
      return;
    }
    if (t.getAttribute('data-iol-del-row') !== null) {
      const r = Number(t.getAttribute('data-iol-del-row'));
      gridRows.splice(r, 1);
      renderGrid();
      renderSummary();
    }
  }

  function onSectionInput(ev) {
    const t = ev.target;
    if (!t || !t.getAttribute) return;
    if (t.getAttribute('data-iol-cat') !== null) {
      readCatalogField(t);
      return;
    }
    if (t.getAttribute('data-iol-st') !== null) {
      const s = Number(t.getAttribute('data-s'));
      const field = t.getAttribute('data-iol-st');
      if (stations[s] && field) stations[s][field] = t.value;
      return;
    }
    if (t.getAttribute('data-iol-cell') !== null) {
      const parts = t.getAttribute('data-iol-cell').split(':');
      const r = Number(parts[0]);
      const c = Number(parts[1]);
      if (gridRows[r] && COLUMNS[c]) {
        gridRows[r][COLUMNS[c]] = t.value;
        if (COLUMNS[c] === 'Signal Type' || COLUMNS[c] === 'Channel Number') renderSummary();
      }
    }
  }

  function init() {
    if (!el('sec-io-list-generator')) return;
    renderCatalog();
    renderStations();
    renderSummary();
    renderGrid();

    const section = el('sec-io-list-generator');
    section.addEventListener('click', onSectionClick);
    section.addEventListener('input', onSectionInput);
    section.addEventListener('change', onSectionInput);

    const addCat = el('iol_add_catalog');
    if (addCat) addCat.addEventListener('click', function () {
      catalog.push({ pn: '', description: '', channels: 0, signalType: 'DI', rawMin: '', rawMax: '' });
      renderCatalog();
      renderStations();
    });
    const addSt = el('iol_add_station');
    if (addSt) addSt.addEventListener('click', function () {
      stationSeq += 1;
      stations.push(emptyStation(stationSeq));
      renderStations();
    });
    const gen = el('iol_generate');
    if (gen) gen.addEventListener('click', generateFromCart);
    const addRow = el('iol_add_row');
    if (addRow) addRow.addEventListener('click', addBlankRow);
    const csvBtn = el('iol_export_csv');
    if (csvBtn) csvBtn.addEventListener('click', exportCsv);
    const xlsxBtn = el('iol_export_xlsx');
    if (xlsxBtn) xlsxBtn.addEventListener('click', exportXlsx);
    const saveBtn = el('iol_save');
    if (saveBtn) saveBtn.addEventListener('click', saveProject);
    const loadBtn = el('iol_load');
    const fileEl = el('iol_load_file');
    if (loadBtn && fileEl) {
      loadBtn.addEventListener('click', function () { fileEl.click(); });
      fileEl.addEventListener('change', function () {
        const f = fileEl.files && fileEl.files[0];
        loadProjectFile(f);
        fileEl.value = '';
      });
    }

    window.iolGenerateExample = generateFromCart;

    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-io-list-generator', 'io-list-generator', null);
    }
  }

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
  }

  global.__ioListGeneratorTestApi = {
    COLUMNS: COLUMNS,
    BLANK_ON_GENERATE: BLANK_ON_GENERATE,
    SEED_CATALOG: cloneCatalog(SEED_CATALOG),
    ANALOG_FAMILIES: ANALOG_FAMILIES,
    expandBuildList: expandBuildList,
    summarizeRows: summarizeRows,
    rowsToCsv: rowsToCsv,
    rowsToAoa: rowsToAoa,
    summarySheetAoa: summarySheetAoa,
    serializeProject: serializeProject,
    parseProject: parseProject,
    cardNameFor: cardNameFor,
    catalogByPn: catalogByPn,
    isAnalogFamily: isAnalogFamily,
  };
})(typeof window !== 'undefined' ? window : globalThis);
