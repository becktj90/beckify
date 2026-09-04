/* Optional cloud VLM assist for panel directories is ready on
   BeckifyVlmOcr.analyzePanelDirectory (shared with motor nameplate).
   This page stays on-device Tesseract. Photos are not uploaded here. */

const MAX_CIRCUIT_SLOTS = 42;
const PRINT_ROW_PAIRS = MAX_CIRCUIT_SLOTS / 2;
const LOAD_TYPES = ['General', 'Lighting', 'Receptacle', 'Motor', 'HVAC', 'Kitchen', 'IT / Electronics', 'Process', 'EV Charging', 'Spare'];

const state = {
  file: null,
  imageUrl: '',
  rows: [],
  rawText: ''
};

const elements = {};

window.addEventListener('pagehide', () => {
  if (state.imageUrl) {
    URL.revokeObjectURL(state.imageUrl);
    state.imageUrl = '';
  }
  state.file = null;
});

function bootPanelSchedule() {
  if (!document.getElementById || !document.getElementById('fillSlotsButton')) return;
  cacheElements();
  bindEvents();
  seedRows(MAX_CIRCUIT_SLOTS);
  renderAll();
}

if (document.readyState === 'loading') {
  window.addEventListener('DOMContentLoaded', bootPanelSchedule);
} else {
  bootPanelSchedule();
}

function cacheElements() {
  elements.imageInput = document.getElementById('imageInput');
  elements.processButton = document.getElementById('processButton');
  elements.resetButton = document.getElementById('resetButton');
  elements.dropZone = document.getElementById('dropZone');
  elements.statusText = document.getElementById('statusText');
  elements.fileName = document.getElementById('fileName');
  elements.progressFill = document.getElementById('progressFill');
  elements.progressLabel = document.getElementById('progressLabel');
  elements.imagePreview = document.getElementById('imagePreview');
  elements.previewPlaceholder = document.getElementById('previewPlaceholder');
  elements.previewFrame = document.querySelector('.preview-frame');
  elements.rawText = document.getElementById('rawText');
  elements.panelName = document.getElementById('panelName');
  elements.panelVoltage = document.getElementById('panelVoltage');
  elements.panelFeed = document.getElementById('panelFeed');
  elements.panelDate = document.getElementById('panelDate');
  elements.panelPhase = document.getElementById('panelPhase');
  elements.panelCapacityAmps = document.getElementById('panelCapacityAmps');
  elements.panelDiversity = document.getElementById('panelDiversity');
  elements.parseTextButton = document.getElementById('parseTextButton');
  elements.addRowButton = document.getElementById('addRowButton');
  elements.fillSlotsButton = document.getElementById('fillSlotsButton');
  elements.editorTableBody = document.getElementById('editorTableBody');
  elements.reviewedSchedule = document.getElementById('reviewedSchedule');
  elements.openPanelCaution = document.getElementById('openPanelCaution');
  elements.directoryGrid = document.getElementById('directoryGrid');
  elements.directoryGuidance = document.getElementById('directoryGuidance');
  elements.printButton = document.getElementById('printButton');
  elements.sheetPanelName = document.getElementById('sheetPanelName');
  elements.sheetVoltage = document.getElementById('sheetVoltage');
  elements.sheetFeed = document.getElementById('sheetFeed');
  elements.sheetDate = document.getElementById('sheetDate');
  elements.printScheduleBody = document.getElementById('printScheduleBody');
  elements.analysisGrid = document.getElementById('analysisGrid');
  elements.analysisGuidance = document.getElementById('analysisGuidance');
}

function bindEvents() {
  elements.imageInput.addEventListener('change', event => {
    const [file] = event.target.files || [];
    handleFileSelection(file);
  });
  const capture = document.getElementById('imageCapture');
  if (capture) {
    capture.addEventListener('change', event => {
      const [file] = event.target.files || [];
      handleFileSelection(file);
    });
  }

  ['dragenter', 'dragover'].forEach(eventName => {
    elements.dropZone.addEventListener(eventName, event => {
      event.preventDefault();
      elements.dropZone.classList.add('is-dragover');
    });
  });

  ['dragleave', 'drop'].forEach(eventName => {
    elements.dropZone.addEventListener(eventName, event => {
      event.preventDefault();
      elements.dropZone.classList.remove('is-dragover');
    });
  });

  elements.dropZone.addEventListener('drop', event => {
    const [file] = event.dataTransfer?.files || [];
    handleFileSelection(file);
  });

  elements.processButton.addEventListener('click', runOcr);
  elements.resetButton.addEventListener('click', resetApp);
  elements.printButton.addEventListener('click', handlePrint);
  elements.parseTextButton.addEventListener('click', handleParseText);
  elements.addRowButton.addEventListener('click', () => {
    state.rows.push(createEmptyRow());
    clearReview();
    renderAll();
  });
  elements.fillSlotsButton.addEventListener('click', () => {
    seedRows(MAX_CIRCUIT_SLOTS);
    clearReview();
    renderAll();
    setStatus('Seeded 42 editable circuit rows for manual entry.');
  });

  [elements.panelName, elements.panelVoltage, elements.panelFeed, elements.panelDate, elements.panelPhase, elements.panelCapacityAmps, elements.panelDiversity].forEach(input => {
    input.addEventListener('input', renderAll);
    input.addEventListener('change', renderAll);
  });
  if (elements.reviewedSchedule) {
    elements.reviewedSchedule.addEventListener('change', renderAll);
  }
}

function isLikelyImageFile(file) {
  if (window.BeckifyOcr && typeof window.BeckifyOcr.isLikelyImageFile === 'function') {
    return window.BeckifyOcr.isLikelyImageFile(file);
  }
  if (!file) return false;
  const type = String(file.type || '');
  if (type.startsWith('image/')) return true;
  if (type) return false;
  return /\.(jpe?g|png|webp|gif|bmp|tif{1,2}|heic|heif)$/i.test(String(file.name || ''));
}

function clearReview() {
  if (elements.reviewedSchedule) elements.reviewedSchedule.checked = false;
}

function isScheduleReviewed() {
  return !!(elements.reviewedSchedule && elements.reviewedSchedule.checked);
}

function handleFileSelection(file) {
  if (!file || !isLikelyImageFile(file)) {
    setStatus('Please choose a valid image file.');
    return;
  }
  if (file.size > 12 * 1024 * 1024) {
    setStatus('Please choose an image smaller than 12 MB.');
    return;
  }

  if (state.imageUrl) {
    URL.revokeObjectURL(state.imageUrl);
  }

  state.file = file;
  state.imageUrl = URL.createObjectURL(file);
  elements.imagePreview.src = state.imageUrl;
  elements.previewFrame.classList.add('has-image');
  elements.fileName.textContent = file.name;
  elements.processButton.disabled = false;
  clearReview();
  resetProgress();
  setStatus('Image ready. Click “Read Schedule” to run OCR.');
}

async function runOcr() {
  if (!state.file) {
    setStatus('Choose a directory photo, or fill the table manually — you are not blocked.');
    return;
  }

  if (!window.BeckifyOcr) {
    setStatus('On-device OCR helper did not load. Fill the table manually — you are not blocked.');
    return;
  }

  elements.processButton.disabled = true;
  updateProgress(0, 'Starting on-device OCR…');

  try {
    const out = await window.BeckifyOcr.recognize(state.file, {
      logger: undefined,
      onProgress: (ratio, status) => {
        updateProgress(ratio, (window.BeckifyOcr.humanizeStatus && window.BeckifyOcr.humanizeStatus(status)) || humanizeStatus(status));
      }
    });
    const text = out.text || '';
    state.rawText = text;
    elements.rawText.value = text;
    clearReview();
    if (elements.openPanelCaution) {
      elements.openPanelCaution.hidden = !out.looksLikeOpenPanel;
    }
    if (out.looksLikeOpenPanel) {
      setStatus('This photo looks like an open panel interior. Do not work inside a live panel. OCR will still try to help — photograph the directory with the door closed if you can.');
    }
    if (out.failed) {
      setStatus('OCR found no usable text. Fill the table manually — you are not blocked.');
      updateProgress(0, 'OCR found no text');
      renderAll();
      return;
    }
    parseAndApplyText(text, true);
    if (out.lowConfidence) {
      setStatus(`OCR confidence is low (${out.confidence.toFixed(0)}%). Treat every circuit row as a draft and correct it. You are not blocked from typing the directory by hand.`);
    } else if (!out.looksLikeOpenPanel) {
      updateProgress(1, 'OCR complete. Review the preview grid before using the estimates.');
    }
  } catch (error) {
    console.error(error);
    setStatus((error && error.message ? `${error.message} ` : '') + 'OCR failed. Fill the table manually — you are not blocked.');
    updateProgress(0, 'OCR failed');
  } finally {
    elements.processButton.disabled = false;
  }
}

function parseAndApplyText(text, allowMetadataFill) {
  const parsed = parseScheduleText(text || '');
  if (allowMetadataFill) {
    applyMetadataIfBlank(parsed.meta);
  }

  if (parsed.rows.length) {
    state.rows = parsed.rows;
    setStatus(`Parsed ${parsed.rows.length} circuit row${parsed.rows.length === 1 ? '' : 's'}. Correct any OCR misreads before printing.`);
  } else {
    setStatus('No clear circuit rows were detected. Edit the OCR text or enter rows manually below.');
  }

  renderAll();
}

function parseScheduleText(text) {
  const rawLines = text
    .replace(/\r/g, '\n')
    .split('\n')
    .map(cleanLine)
    .filter(line => line.trim());
  const lines = rawLines.map(compactLine);

  const meta = extractMetadata(lines, text);
  const rows = [];
  const seen = new Set();

  rawLines.forEach(line => {
    const compact = compactLine(line);
    if (isIgnoredLine(compact)) {
      return;
    }

    const columns = splitColumns(line);
    if (columns.length >= 6) {
      const splitIndex = findSecondaryCircuitIndex(columns);
      if (splitIndex > 0) {
        [columns.slice(0, splitIndex), columns.slice(splitIndex)].forEach(group => {
          const row = parseColumnsToRow(group);
          pushUniqueRow(row, rows, seen);
        });
        return;
      }
    }

    if (columns.length >= 3) {
      pushUniqueRow(parseColumnsToRow(columns), rows, seen);
      return;
    }

    pushUniqueRow(parseFreeformRow(compact), rows, seen);
  });

  return { meta, rows: normalizeRows(rows) };
}

function cleanLine(line) {
  return line
    .replace(/[|]+/g, ' | ')
    .replace(/[•·]/g, ' ')
    .replace(/[“”]/g, '"')
    .replace(/[‘’]/g, "'")
    .trim();
}

function compactLine(line) {
  return line.replace(/\s+/g, ' ').trim();
}

function splitColumns(line) {
  if (!line) {
    return [];
  }

  if (line.includes('|')) {
    return line.split('|').map(part => part.trim()).filter(Boolean);
  }

  return line
    .split(/\t+|\s{2,}/)
    .map(part => part.trim())
    .filter(Boolean);
}

function isIgnoredLine(line) {
  return /^(panel schedule|branch circuits?|circuit directory|load summary|notes?)$/i.test(line)
    || /(ckt|circuit).*(load|description)/i.test(line)
    || /(trip|amps?).*(poles?)/i.test(line)
    || /^odd\s+even$/i.test(line)
    || isPanelMetadataLine(line);
}

function looksLikeCircuit(value) {
  return /^\d+[A-Z]?(?:[-/,]\d+[A-Z]?)*$/.test(String(value).replace(/\s+/g, '').toUpperCase());
}

function looksLikeTrip(value) {
  return /^\d+(?:\.\d+)?\s*(?:A|AMP|AMPS)?$/i.test(String(value).trim());
}

function looksLikePoles(value) {
  return /^(?:[123]|1P|2P|3P)$/i.test(String(value).trim());
}

function isPanelMetadataLine(line) {
  return /^panel\b/i.test(line) && !looksLikeCircuit(line.split(' ')[0]);
}

function findSecondaryCircuitIndex(columns) {
  for (let index = 2; index < columns.length - 1; index += 1) {
    const candidate = columns[index];
    const previous = columns[index - 1] || '';
    if (
      looksLikeCircuit(candidate)
      && !/P$/i.test(String(candidate).trim())
      && (looksLikeTrip(previous) || looksLikePoles(previous))
    ) {
      return index;
    }
  }
  return -1;
}

function parseColumnsToRow(columns) {
  if (!columns.length || !looksLikeCircuit(columns[0])) {
    return null;
  }

  const row = createEmptyRow();
  row.circuit = normalizeCircuit(columns[0]);

  const trailing = [...columns.slice(1)];
  const compactMatch = trailing.length
    ? trailing[trailing.length - 1].match(/^(\d+(?:\.\d+)?)\s*(?:A|AMP|AMPS)?\s*[/\\-]\s*([123])P?$/i)
    : null;

  if (compactMatch) {
    row.trip = `${compactMatch[1]}A`;
    row.poles = compactMatch[2];
    trailing.pop();
  } else {
    if (trailing.length && looksLikePoles(trailing[trailing.length - 1])) {
      row.poles = trailing.pop().replace(/P/i, '');
    }
    if (trailing.length && looksLikeTrip(trailing[trailing.length - 1])) {
      row.trip = normalizeTrip(trailing.pop());
    }
  }

  row.description = trailing.join(' ').trim();

  if (!row.description && (!row.trip || !row.poles)) {
    return null;
  }

  return row;
}

function parseFreeformRow(line) {
  const match = line.match(/^(\d+[A-Z]?(?:[-/,]\d+[A-Z]?)*)\s+(.+?)\s+(\d+(?:\.\d+)?)\s*(?:A|AMP|AMPS)?\s+([123])P?$/i);
  if (!match) {
    return null;
  }

  return {
    circuit: normalizeCircuit(match[1]),
    description: match[2].trim(),
    trip: `${match[3]}A`,
    poles: match[4]
  };
}

function pushUniqueRow(row, rows, seen) {
  if (!row) {
    return;
  }

  const signature = `${row.circuit}|${row.description}|${row.trip}|${row.poles}`.toUpperCase();
  if (seen.has(signature)) {
    return;
  }

  seen.add(signature);
  rows.push(row);
}

function normalizeRows(rows) {
  return rows
    .map(row => ({
      circuit: normalizeCircuit(row.circuit),
      description: String(row.description || '').trim(),
      trip: normalizeTrip(row.trip),
      poles: String(row.poles || '').replace(/P/i, '').trim(),
      loadType: LOAD_TYPES.includes(row.loadType) ? row.loadType : inferLoadType(row.description),
      loadAmps: normalizeLoadAmps(row.loadAmps, row.trip),
      loadAmpsCopiedFromTrip: row.loadAmpsCopiedFromTrip === true || isLoadAmpsCopiedFromTrip(row.loadAmps, row.trip),
      demandFactor: normalizeDemandFactor(row.demandFactor)
    }))
    .filter(row => row.circuit || row.description || row.trip || row.poles || row.loadAmps)
    .sort(compareCircuitRows);
}

function compareCircuitRows(a, b) {
  const aNum = firstCircuitNumber(a.circuit);
  const bNum = firstCircuitNumber(b.circuit);
  if (aNum === bNum) {
    return a.circuit.localeCompare(b.circuit, undefined, { numeric: true, sensitivity: 'base' });
  }
  if (aNum === Number.MAX_SAFE_INTEGER) {
    return 1;
  }
  if (bNum === Number.MAX_SAFE_INTEGER) {
    return -1;
  }
  return aNum - bNum;
}

function normalizeCircuit(value) {
  return String(value || '').toUpperCase().replace(/\s+/g, '');
}

function normalizeTrip(value) {
  const cleaned = String(value || '').trim().toUpperCase().replace(/\s+/g, '');
  if (!cleaned) {
    return '';
  }
  return /A$/.test(cleaned) ? cleaned : `${cleaned}A`;
}

function tripAmps(value) {
  const match = String(value || '').match(/[\d.]+/);
  return match ? Number(match[0]) : 0;
}

function normalizeLoadAmps(value, trip) {
  const text = String(value ?? '').trim();
  const number = Number(text);
  if (text && Number.isFinite(number) && number >= 0) return String(number);
  const fallback = tripAmps(trip);
  return fallback > 0 ? String(fallback) : '';
}

function isLoadAmpsCopiedFromTrip(value, trip) {
  const text = String(value ?? '').trim();
  const number = Number(text);
  if (text && Number.isFinite(number) && number >= 0) return false;
  return tripAmps(trip) > 0;
}

function normalizeDemandFactor(value) {
  const text = String(value ?? '').trim();
  const number = Number(text);
  return text && Number.isFinite(number) && number >= 0 ? String(number) : '1';
}

function inferLoadType(description) {
  const text = String(description || '').toLowerCase();
  if (/spare|space|future/.test(text)) return 'Spare';
  if (/light|fixture|luminaire|led/.test(text)) return 'Lighting';
  if (/recept|outlet|plug/.test(text)) return 'Receptacle';
  if (/motor|pump|fan|blower|compressor|elevator/.test(text)) return 'Motor';
  if (/hvac|air.?handler|condens|furnace|rtu|heat/.test(text)) return 'HVAC';
  if (/kitchen|range|oven|dishwasher|disposal/.test(text)) return 'Kitchen';
  if (/server|data|network|ups|computer/.test(text)) return 'IT / Electronics';
  if (/charger|evse|electric vehicle/.test(text)) return 'EV Charging';
  if (/machine|welder|process|equipment/.test(text)) return 'Process';
  return 'General';
}

function firstCircuitNumber(value) {
  const match = String(value || '').match(/\d+/);
  return match ? Number(match[0]) : Number.MAX_SAFE_INTEGER;
}

function extractMetadata(lines, rawText) {
  const joined = rawText.replace(/\r/g, '\n');
  return {
    panelName: findMetadata(lines, [/panel\s*(?:name|board)?\s*[:\-]?\s*(.+)/i]),
    voltage: findMetadata(lines, [/voltage\s*[:\-]?\s*(.+)/i, /(\d{2,4}(?:Y)?\s*\/\s*\d{2,4}\s*V?)/i, /(\d{3,4}\s*V)/i]),
    feed: findMetadata(lines, [/feed(?:er)?\s*[:\-]?\s*(.+)/i, /mains?\s*[:\-]?\s*(.+)/i]),
    date: findMetadata(lines, [/date\s*[:\-]?\s*(.+)/i, /(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})/, /([A-Z][a-z]{2,8}\s+\d{1,2},\s+\d{4})/])
  };
}

function findMetadata(lines, patterns) {
  for (const line of lines) {
    for (const pattern of patterns) {
      const match = line.match(pattern);
      if (match && match[1]) {
        return match[1].trim();
      }
    }
  }
  return '';
}

function applyMetadataIfBlank(meta) {
  if (meta.panelName && !elements.panelName.value.trim()) {
    elements.panelName.value = meta.panelName;
  }
  if (meta.voltage && !elements.panelVoltage.value.trim()) {
    elements.panelVoltage.value = meta.voltage;
  }
  if (meta.feed && !elements.panelFeed.value.trim()) {
    elements.panelFeed.value = meta.feed;
  }
  if (meta.date && !elements.panelDate.value.trim()) {
    elements.panelDate.value = meta.date;
  }
}

function renderAll() {
  renderEditorTable();
  renderPrintSheet();
  renderLoadAnalysis();
  renderDirectoryMetrics();
}

function renderEditorTable() {
  const rows = state.rows.length ? state.rows : [createEmptyRow()];

  elements.editorTableBody.innerHTML = rows.map((row, index) => {
    const type = LOAD_TYPES.includes(row.loadType) ? row.loadType : inferLoadType(row.description);
    const loadAmps = normalizeLoadAmps(row.loadAmps, row.trip);
    const demandFactor = normalizeDemandFactor(row.demandFactor);
    const copied = row.loadAmpsCopiedFromTrip === true || isLoadAmpsCopiedFromTrip(row.loadAmps, row.trip);
    return `
      <tr>
      <td><input type="text" data-field="circuit" data-index="${index}" value="${escapeHtml(row.circuit)}" placeholder="1"></td>
      <td><input type="text" data-field="description" data-index="${index}" value="${escapeHtml(row.description)}" placeholder="Lighting"></td>
      <td><input type="text" data-field="trip" data-index="${index}" value="${escapeHtml(row.trip)}" placeholder="20A"></td>
      <td>
        <select data-field="poles" data-index="${index}" aria-label="Poles for circuit ${escapeHtml(row.circuit || String(index + 1))}">
          <option value="" ${row.poles ? '' : 'selected'}>—</option>
          <option value="1" ${row.poles === '1' ? 'selected' : ''}>1</option>
          <option value="2" ${row.poles === '2' ? 'selected' : ''}>2</option>
          <option value="3" ${row.poles === '3' ? 'selected' : ''}>3</option>
        </select>
      </td>
      <td><select data-field="loadType" data-index="${index}" aria-label="Load type for circuit ${escapeHtml(row.circuit || String(index + 1))}">${LOAD_TYPES.map(option => `<option value="${escapeHtml(option)}" ${type === option ? 'selected' : ''}>${escapeHtml(option)}</option>`).join('')}</select></td>
      <td class="${copied ? 'is-trip-copy' : ''}"><input type="number" min="0" step="any" data-field="loadAmps" data-index="${index}" value="${escapeHtml(loadAmps)}" placeholder="edit FLA"${copied ? ` aria-describedby="trip-copy-${index}"` : ''}>${copied ? `<small id="trip-copy-${index}" class="trip-copy-flag">copied from trip — edit me</small>` : ''}</td>
      <td><input type="number" min="0" step="0.01" data-field="demandFactor" data-index="${index}" value="${escapeHtml(demandFactor)}" aria-label="Demand factor for circuit ${escapeHtml(row.circuit || String(index + 1))}"></td>
      <td><button class="btn btn-row-delete" type="button" data-delete-index="${index}">Delete</button></td>
    </tr>
  `;
  }).join('');

  elements.editorTableBody.querySelectorAll('[data-field]').forEach(input => {
    input.addEventListener('input', handleRowEdit);
    input.addEventListener('change', handleRowEdit);
  });

  elements.editorTableBody.querySelectorAll('[data-delete-index]').forEach(button => {
    button.addEventListener('click', () => {
      const index = Number(button.dataset.deleteIndex);
      state.rows.splice(index, 1);
      clearReview();
      renderAll();
    });
  });
}

function handleRowEdit(event) {
  const index = Number(event.target.dataset.index);
  const field = event.target.dataset.field;
  if (!state.rows[index]) {
    state.rows[index] = createEmptyRow();
  }

  if (field === 'circuit') {
    state.rows[index][field] = normalizeCircuit(event.target.value);
  } else if (field === 'trip') {
    state.rows[index][field] = normalizeTrip(event.target.value);
    if (!String(state.rows[index].loadAmps || '').trim() || state.rows[index].loadAmpsCopiedFromTrip) {
      state.rows[index].loadAmps = normalizeLoadAmps('', event.target.value);
      state.rows[index].loadAmpsCopiedFromTrip = isLoadAmpsCopiedFromTrip('', event.target.value);
    }
  } else if (field === 'loadAmps') {
    state.rows[index][field] = normalizeLoadAmps(event.target.value, '');
    state.rows[index].loadAmpsCopiedFromTrip = false;
  } else if (field === 'demandFactor') {
    state.rows[index][field] = normalizeDemandFactor(event.target.value);
  } else if (field === 'loadType') {
    state.rows[index][field] = LOAD_TYPES.includes(event.target.value) ? event.target.value : 'General';
  } else {
    state.rows[index][field] = String(event.target.value || '').trim();
  }

  clearReview();
  renderPrintSheet();
  renderLoadAnalysis();
  renderDirectoryMetrics();
}

function panelVoltageInfo(value) {
  const text = String(value || '');
  const pair = text.match(/(\d+(?:\.\d+)?)\s*(?:Y)?\s*\/\s*(\d+(?:\.\d+)?)/i);
  if (pair) return { lineToLine: Number(pair[1]), lineToNeutral: Number(pair[2]) };
  const single = text.match(/\d+(?:\.\d+)?/);
  const lineToLine = single ? Number(single[0]) : NaN;
  return { lineToLine, lineToNeutral: lineToLine };
}

function rowLoadVa(row, voltage, phase) {
  const amps = Number(row.loadAmps);
  const poles = Number(row.poles) || 1;
  if (!Number.isFinite(amps) || amps <= 0 || !Number.isFinite(voltage.lineToLine) || voltage.lineToLine <= 0) return 0;
  if (phase === 3 && poles >= 3) return Math.sqrt(3) * voltage.lineToLine * amps;
  if (phase === 3 && poles === 1) return voltage.lineToNeutral * amps;
  return voltage.lineToLine * amps;
}

function panelNumber(value, fallback = NaN) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function summaryMetric(label, value, detail = '') {
  return `<article class="analysis-metric"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong>${detail ? `<small>${escapeHtml(detail)}</small>` : ''}</article>`;
}

function tripAmpsFromRow(row) {
  return tripAmps(row && row.trip);
}

function isSpareOrOpen(row) {
  const desc = String(row && row.description || '').trim();
  const lower = desc.toLowerCase();
  const amps = tripAmpsFromRow(row);
  if (!desc && !(amps > 0)) return true;
  if (row && row.loadType === 'Spare') return true;
  return /^(spare|space|blank|future|open)(\b|$)/i.test(desc) || (/\b(spare|space|future)\b/.test(lower) && desc.length < 24);
}

function isUnlabeled(row) {
  if (isSpareOrOpen(row)) return false;
  const desc = String(row && row.description || '').trim();
  const amps = tripAmpsFromRow(row);
  return amps > 0 && (!desc || /^(ckt|circuit|\d+)$/i.test(desc));
}

function isVague(row) {
  if (isSpareOrOpen(row) || isUnlabeled(row)) return false;
  const desc = String(row && row.description || '').trim();
  if (!desc) return false;
  return desc.length < 3 || /^(load|tbd|n\/a|na|-|\.|x|misc)$/i.test(desc);
}

function looksDoubledUp(row) {
  return /tandem|cheater|double.?stuff|half.?size|duplex breaker|wafer/i.test(String(row && row.description || ''));
}

function connectedBreakerSum(rows) {
  let sum = 0;
  (rows || []).forEach(row => {
    if (isSpareOrOpen(row)) return;
    const amps = tripAmpsFromRow(row);
    if (amps > 0) sum += amps;
  });
  return sum;
}

function rowSlotCount(row) {
  return Math.max(1, Number(row && row.poles) || 1);
}

function spareStats(rows, slotCount) {
  const list = Array.isArray(rows) ? rows : [];
  let spare = 0;
  let fromRows = 0;
  list.forEach(row => {
    const slots = rowSlotCount(row);
    fromRows += slots;
    if (isSpareOrOpen(row)) spare += slots;
  });
  const total = slotCount > 0 ? slotCount : fromRows;
  return { spare, total, pct: total ? (spare / total) * 100 : 0 };
}

function phaseLegFromCircuit(circuit, phase) {
  const n = firstCircuitNumber(circuit);
  if (!Number.isFinite(n) || n < 1 || n === Number.MAX_SAFE_INTEGER) return null;
  if (Number(phase) === 1) {
    /* Typical split-phase panelboard: odd spaces on L1, even spaces on L2. */
    return n % 2 === 1 ? 'L1' : 'L2';
  }
  const g = (n - 1) % 6;
  if (g <= 1) return 'A';
  if (g <= 3) return 'B';
  return 'C';
}

function occupiedLegsForRow(row, phase) {
  const start = firstCircuitNumber(row && row.circuit);
  if (!Number.isFinite(start) || start < 1 || start === Number.MAX_SAFE_INTEGER) return [];
  const poles = Math.max(1, Number(row && row.poles) || 1);
  /* 1φ: consecutive spaces (odd L1, even L2) so a 2-pole 240 V breaker
     lands on both legs. 3φ uses the pair layout (1–2 A, 3–4 B, 5–6 C),
     so a multi-pole breaker steps by 2 spaces to reach the next phase. */
  const stride = Number(phase) === 1 ? 1 : 2;
  const legs = [];
  for (let i = 0; i < poles; i += 1) {
    const leg = phaseLegFromCircuit(String(start + i * stride), phase);
    if (leg && legs.indexOf(leg) === -1) legs.push(leg);
  }
  return legs;
}

function phaseBalance(rows, phase) {
  const legs = {};
  (rows || []).forEach(row => {
    if (isSpareOrOpen(row)) return;
    const amps = tripAmpsFromRow(row);
    if (!(amps > 0)) return;
    occupiedLegsForRow(row, phase).forEach(leg => {
      legs[leg] = (legs[leg] || 0) + amps;
    });
  });
  return {
    legs,
    assumption: Number(phase) === 1
      ? 'Assumption: odd/even 1φ panelboard numbering — odd circuits on L1, even circuits on L2. A 2-pole breaker counts trip amps on both legs. Inference from numbering, not a measurement.'
      : 'Assumption: odd-even 3φ layout, circuits 1–2 phase A, 3–4 B, 5–6 C, repeating. A 3-pole breaker at circuit 1 occupies A, B, and C. Inference from numbering, not a measurement.',
  };
}

function computeDirectoryMetrics(rows, opts) {
  opts = opts || {};
  const phase = Number(opts.phase) === 1 ? 1 : 3;
  const mainAmps = Number(opts.mainAmps);
  const list = Array.isArray(rows) ? rows : [];
  const fromRows = list.reduce((n, row) => n + rowSlotCount(row), 0);
  const slotCount = Number(opts.slotCount) || fromRows;
  const connected = connectedBreakerSum(list);
  const spare = spareStats(list, slotCount);
  const unlabeled = list.filter(isUnlabeled);
  const vague = list.filter(isVague);
  const doubled = list.filter(looksDoubledUp);
  const balance = phaseBalance(list, phase);
  const ratio = Number.isFinite(mainAmps) && mainAmps > 0 ? connected / mainAmps : null;
  const flags = [];
  if (unlabeled.length) flags.push('blank labels found: ' + unlabeled.length);
  if (vague.length) flags.push('vague labels found: ' + vague.length);
  if (doubled.length) flags.push('apparent doubled-up / tandem wording on ' + doubled.length + ' row(s)');
  return {
    connectedBreakerAmps: connected,
    mainAmps: Number.isFinite(mainAmps) && mainAmps > 0 ? mainAmps : null,
    connectedToMainPct: ratio != null ? Math.round(ratio * 10000) / 100 : null,
    connectedNote: 'Rough loading indicator only — not an NEC Article 220 demand-load calculation. Panels are routinely designed with connected breaker totals well above the main rating. Over 100% connected does not mean the panel is unsafe.',
    spareCount: spare.spare,
    spareTotal: spare.total,
    sparePct: spare.pct,
    unlabeledCount: unlabeled.length,
    vagueCount: vague.length,
    doubledCount: doubled.length,
    flags,
    phaseBalance: balance,
  };
}

function renderDirectoryMetrics() {
  if (!elements.directoryGrid || !elements.directoryGuidance) return;
  const reviewed = isScheduleReviewed();
  if (!reviewed) {
    elements.directoryGrid.innerHTML = summaryMetric('Waiting for review', 'Check the box', 'OCR is a draft. Directory metrics stay hidden until you confirm the table.');
    elements.directoryGuidance.innerHTML = '<p>Check “I reviewed every circuit row” after correcting the table. You can still type every field by hand with no photo.</p>';
    return;
  }
  const rows = normalizeRows(state.rows);
  const metrics = computeDirectoryMetrics(rows, {
    phase: elements.panelPhase ? elements.panelPhase.value : 3,
    mainAmps: elements.panelCapacityAmps ? elements.panelCapacityAmps.value : '',
    slotCount: rows.reduce((n, row) => n + rowSlotCount(row), 0) || MAX_CIRCUIT_SLOTS,
  });
  const mainLabel = metrics.mainAmps
    ? `${formatNumber(metrics.connectedBreakerAmps)} A vs ${formatNumber(metrics.mainAmps)} A main (${formatNumber(metrics.connectedToMainPct)}% connected)`
    : `${formatNumber(metrics.connectedBreakerAmps)} A connected (enter main size)`;
  const legs = metrics.phaseBalance.legs;
  const legText = Object.keys(legs).length
    ? Object.entries(legs).map(([leg, amps]) => `${leg} ${formatNumber(amps)} A`).join(' · ')
    : 'Not enough numbered circuits to infer legs';
  elements.directoryGrid.innerHTML = [
    summaryMetric('Main vs connected branch breakers', mainLabel, 'Sum of trip ratings on non-spare rows. Rough indicator only.'),
    summaryMetric('Rough phase balance', legText, metrics.phaseBalance.assumption),
    summaryMetric('Spare / open slots', `${metrics.spareCount} of ${metrics.spareTotal} (${formatNumber(metrics.sparePct)}%)`, 'Physical slots from pole count on spare/blank/open wording.'),
    summaryMetric('Worth asking an electrician', metrics.flags.length ? metrics.flags.join('; ') : 'No extra flags from labels', 'Flags are not diagnosed defects.'),
  ].join('');
  const notes = [
    metrics.connectedNote,
    'Informational estimate from a photo or typed directory, not an electrical inspection. Any safety concern goes to a licensed electrician.',
  ];
  if (metrics.flags.length) {
    notes.push('Worth asking an electrician about: ' + metrics.flags.join('; ') + '.');
  }
  elements.directoryGuidance.innerHTML = notes.map(note => `<p>${escapeHtml(note)}</p>`).join('');
}

function renderLoadAnalysis() {
  if (!elements.analysisGrid || !elements.analysisGuidance) return;
  if (!isScheduleReviewed()) {
    elements.analysisGrid.innerHTML = summaryMetric('Waiting for review', 'Check the box', 'OCR is a draft. Load summary stays hidden until you confirm the table. Breaker trip is not a reviewed load.');
    elements.analysisGuidance.innerHTML = '<p>Check “I reviewed every circuit row” after correcting the table. Est. Load A values copied from trip stay flagged until you edit them.</p>';
    return;
  }
  const rows = normalizeRows(state.rows).filter(row => row.description || Number(row.loadAmps) > 0);
  const voltage = panelVoltageInfo(elements.panelVoltage.value);
  const phase = Number(elements.panelPhase.value) || 3;
  const diversity = Math.max(1, panelNumber(elements.panelDiversity.value, 1));
  const knownVoltage = Number.isFinite(voltage.lineToLine) && voltage.lineToLine > 0;
  const connectedVa = knownVoltage ? rows.reduce((total, row) => total + rowLoadVa(row, voltage, phase), 0) : 0;
  const demandVa = knownVoltage ? rows.reduce((total, row) => total + rowLoadVa(row, voltage, phase) * panelNumber(row.demandFactor, 1), 0) : 0;
  const coincidentVa = demandVa / diversity;
  const equivalentAmps = knownVoltage && coincidentVa > 0
    ? coincidentVa / (phase === 3 ? Math.sqrt(3) * voltage.lineToLine : voltage.lineToLine)
    : 0;
  const capacityAmps = panelNumber(elements.panelCapacityAmps.value, 0);
  const capacityVa = knownVoltage && capacityAmps > 0
    ? capacityAmps * voltage.lineToLine * (phase === 3 ? Math.sqrt(3) : 1)
    : 0;
  const remainingVa = capacityVa ? capacityVa - coincidentVa : 0;
  const typeCounts = rows.reduce((counts, row) => {
    counts[row.loadType] = (counts[row.loadType] || 0) + 1;
    return counts;
  }, {});

  elements.analysisGrid.innerHTML = [
    summaryMetric('Scheduled connected load', knownVoltage ? `${formatKva(connectedVa)} kVA` : 'Needs voltage', `${rows.length} circuit${rows.length === 1 ? '' : 's'} in the table`),
    summaryMetric('After circuit demand factors', knownVoltage ? `${formatKva(demandVa)} kVA` : 'Needs voltage', `before diversity`),
    summaryMetric('Estimated coincident demand', knownVoltage ? `${formatKva(coincidentVa)} kVA` : 'Needs voltage', `diversity ${diversity.toFixed(2)}`),
    summaryMetric('Estimated panel FLA', knownVoltage ? `${formatNumber(equivalentAmps)} A` : 'Needs voltage', phase === 3 ? `${formatNumber(voltage.lineToLine)} V 3Ø equivalent` : `${formatNumber(voltage.lineToLine)} V 1Ø equivalent`),
    summaryMetric('Available capacity', capacityVa ? `${formatKva(capacityVa)} kVA` : 'Not entered', capacityAmps ? `${formatNumber(capacityAmps)} A` : 'read the panel main/feed'),
    summaryMetric('Capacity remaining', capacityVa ? `${formatKva(remainingVa)} kVA` : 'Not calculated', capacityVa && remainingVa < 0 ? 'estimated demand exceeds stated capacity' : 'planning check'),
  ].join('');

  const notes = [];
  if (!knownVoltage) notes.push('Enter the panel voltage (for example, 208Y/120V or 480Y/277V) to convert reviewed circuit amps into kVA.');
  if (!rows.length) notes.push('No loaded circuits are available yet. Upload and read a schedule, or add/edit rows manually.');
  if (rows.some(row => Number(row.loadAmps) === tripAmps(row.trip) && tripAmps(row.trip) > 0)) notes.push('Some estimated-load amps still match breaker trip values. Confirm motor FLA, nameplate current, or measured load before treating this as a design value.');
  if (diversity === 1) notes.push('System diversity is 1.00, a conservative no-diversity assumption. Enter a documented diversity value only when the individual and coincident peaks use the same interval.');
  if (!capacityAmps) notes.push('Enter the panel capacity from the main/feed to see remaining capacity; a branch breaker sum is not panel capacity.');
  if (Object.keys(typeCounts).length) notes.push(`Detected / selected load types: ${Object.entries(typeCounts).map(([type, count]) => `${count} ${type}`).join(', ')}.`);
  elements.analysisGuidance.innerHTML = notes.map(note => `<p>${escapeHtml(note)}</p>`).join('');
}

function formatKva(va) {
  return formatNumber(va / 1000);
}

function formatNumber(value) {
  return Number(value || 0).toLocaleString(undefined, { maximumFractionDigits: 2 });
}

function renderPrintSheet() {
  elements.sheetPanelName.textContent = elements.panelName.value.trim() || 'Untitled Panel';
  elements.sheetVoltage.textContent = elements.panelVoltage.value.trim() || '—';
  elements.sheetFeed.textContent = elements.panelFeed.value.trim() || '—';
  elements.sheetDate.textContent = elements.panelDate.value.trim() || defaultPrintDate();

  const slots = buildCircuitSlots(state.rows);
  const bodyRows = [];

  for (let pair = 0; pair < PRINT_ROW_PAIRS; pair += 1) {
    const left = slots[pair * 2 + 1] || createPlaceholderRow(pair * 2 + 1);
    const right = slots[pair * 2 + 2] || createPlaceholderRow(pair * 2 + 2);
    bodyRows.push(`
      <tr>
        ${renderPrintCell(left.circuit, 'circuit')}
        ${renderPrintCell(left.description, 'description')}
        ${renderPrintCell(left.trip, 'trip')}
        ${renderPrintCell(left.poles, 'poles')}
        ${renderPrintCell(right.trip, 'trip')}
        ${renderPrintCell(right.poles, 'poles')}
        ${renderPrintCell(right.description, 'description')}
        ${renderPrintCell(right.circuit, 'circuit')}
      </tr>
    `);
  }

  elements.printScheduleBody.innerHTML = bodyRows.join('');
}

function buildCircuitSlots(rows) {
  const normalized = normalizeRows(rows);
  const slots = {};
  const overflow = [];

  normalized.forEach(row => {
    const slot = firstCircuitNumber(row.circuit);
    if (slot >= 1 && slot <= MAX_CIRCUIT_SLOTS && !slots[slot]) {
      slots[slot] = row;
    } else {
      overflow.push(row);
    }
  });

  overflow.forEach(row => {
    for (let slot = 1; slot <= MAX_CIRCUIT_SLOTS; slot += 1) {
      if (!slots[slot]) {
        slots[slot] = { ...row, circuit: row.circuit || String(slot) };
        break;
      }
    }
  });

  return slots;
}

function renderPrintCell(value, type) {
  const safe = escapeHtml(value || '');
  const text = safe || '&nbsp;';
  const blankClass = safe ? '' : ' blank';
  return `<td class="${type}${blankClass}">${text}</td>`;
}

function createPlaceholderRow(circuit) {
  return { circuit: String(circuit), description: '', trip: '', poles: '' };
}

function createEmptyRow() {
  return { circuit: '', description: '', trip: '', poles: '', loadType: 'General', loadAmps: '', loadAmpsCopiedFromTrip: false, demandFactor: '1' };
}

function seedRows(count) {
  const safeCount = Math.max(1, Math.min(MAX_CIRCUIT_SLOTS, Number(count) || MAX_CIRCUIT_SLOTS));
  state.rows = Array.from({ length: safeCount }, (_, index) => ({
    circuit: String(index + 1),
    description: '',
    trip: '',
    poles: '',
    loadType: 'General',
    loadAmps: '',
    loadAmpsCopiedFromTrip: false,
    demandFactor: '1'
  }));
}

function resetApp() {
  if (state.imageUrl) {
    URL.revokeObjectURL(state.imageUrl);
  }

  state.file = null;
  state.imageUrl = '';
  state.rawText = '';
  seedRows(MAX_CIRCUIT_SLOTS);
  elements.imageInput.value = '';
  elements.rawText.value = '';
  elements.panelName.value = '';
  elements.panelVoltage.value = '';
  elements.panelFeed.value = '';
  elements.panelDate.value = '';
  elements.panelPhase.value = '3';
  elements.panelCapacityAmps.value = '';
  elements.panelDiversity.value = '1';
  elements.imagePreview.removeAttribute('src');
  elements.previewFrame.classList.remove('has-image');
  elements.fileName.textContent = 'No file selected';
  elements.processButton.disabled = true;
  clearReview();
  if (elements.openPanelCaution) elements.openPanelCaution.hidden = true;
  resetProgress();
  setStatus('Reset complete. Upload a new schedule image to begin again.');
  renderAll();
}

function handleParseText() {
  clearReview();
  parseAndApplyText(elements.rawText.value, false);
}

function updateProgress(value, statusMessage) {
  const percent = Math.max(0, Math.min(100, Math.round(value * 100)));
  elements.progressFill.style.width = `${percent}%`;
  elements.progressLabel.textContent = `${percent}%`;
  if (statusMessage) {
    setStatus(statusMessage);
  }
}

function resetProgress() {
  updateProgress(0);
}

function setStatus(message) {
  elements.statusText.textContent = message;
}

function humanizeStatus(status) {
  if (!status) {
    return 'Processing…';
  }
  return status
    .replace(/recognizing text/i, 'Reading schedule text…')
    .replace(/loading language traineddata/i, 'Loading OCR language pack…')
    .replace(/initializing api/i, 'Initializing OCR engine…')
    .replace(/initializing tesseract/i, 'Starting Tesseract.js…');
}

function defaultPrintDate() {
  return new Date().toLocaleDateString();
}

function handlePrint() {
  if (!isScheduleReviewed()) {
    setStatus('Check “I reviewed every circuit row” before printing. OCR is a draft, not a finished schedule.');
    return;
  }
  if (!state.rows.some(row => row.description || row.trip || row.poles)) {
    setStatus('Add or parse at least one circuit row before printing.');
    return;
  }

  window.print();
}

function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

if (typeof window !== 'undefined' && window.__ENABLE_PANEL_SCHEDULE_TEST_API__) {
  window.__panelScheduleTestApi = {
    parseScheduleText,
    splitColumns,
    parseColumnsToRow,
    parseFreeformRow,
    normalizeRows,
    normalizeTrip,
    normalizeCircuit,
    firstCircuitNumber,
    extractMetadata,
    buildCircuitSlots,
    humanizeStatus,
    isIgnoredLine,
    findSecondaryCircuitIndex,
    createEmptyRow,
    createPlaceholderRow,
    inferLoadType,
    panelVoltageInfo,
    rowLoadVa,
    normalizeLoadAmps,
    isLoadAmpsCopiedFromTrip,
    isScheduleReviewed,
    isLikelyImageFile,
    normalizeDemandFactor,
    isSpareOrOpen,
    isUnlabeled,
    isVague,
    looksDoubledUp,
    connectedBreakerSum,
    spareStats,
    rowSlotCount,
    phaseLegFromCircuit,
    occupiedLegsForRow,
    phaseBalance,
    computeDirectoryMetrics
  };
}
