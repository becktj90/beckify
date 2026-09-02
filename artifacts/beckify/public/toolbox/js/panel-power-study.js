const DEFAULT_CIRCUIT_SLOTS = 42;
const LOAD_TYPES = ['General', 'Lighting', 'Receptacle', 'Motor', 'HVAC', 'Kitchen', 'IT / Electronics', 'Process', 'EV Charging', 'Spare'];
const CIRCUIT_CLASSES = ['General', 'Lighting', 'Receptacle', 'HVAC', 'Motor', 'Critical', 'Emergency', 'Spare'];

const state = {
  file: null,
  imageUrl: '',
  rows: [],
  rawText: ''
};

const elements = {};

window.addEventListener('DOMContentLoaded', () => {
  cacheElements();
  bindEvents();
  seedRows(DEFAULT_CIRCUIT_SLOTS);
  renderAll();
});

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
  elements.panelMainRating = document.getElementById('panelMainRating');
  elements.panelFeed = document.getElementById('panelFeed');
  elements.panelMainType = document.getElementById('panelMainType');
  elements.panelPositions = document.getElementById('panelPositions');
  elements.panelBreakerSeries = document.getElementById('panelBreakerSeries');
  elements.panelDate = document.getElementById('panelDate');
  elements.panelPhase = document.getElementById('panelPhase');
  elements.panelDiversity = document.getElementById('panelDiversity');
  elements.parseTextButton = document.getElementById('parseTextButton');
  elements.addRowButton = document.getElementById('addRowButton');
  elements.fillSlotsButton = document.getElementById('fillSlotsButton');
  elements.saveJsonButton = document.getElementById('saveJsonButton');
  elements.editorTableBody = document.getElementById('editorTableBody');
  elements.printButton = document.getElementById('printButton');
  elements.sheetPanelName = document.getElementById('sheetPanelName');
  elements.sheetVoltage = document.getElementById('sheetVoltage');
  elements.sheetFeed = document.getElementById('sheetFeed');
  elements.sheetMain = document.getElementById('sheetMain');
  elements.sheetPositions = document.getElementById('sheetPositions');
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
  elements.saveJsonButton.addEventListener('click', saveStudyData);

  elements.addRowButton.addEventListener('click', () => {
    state.rows.push(createEmptyRow());
    renderAll();
  });

  elements.fillSlotsButton.addEventListener('click', () => {
    seedRows(positionCount());
    renderAll();
    setStatus(`Seeded ${positionCount()} editable circuit rows for manual entry.`);
  });

  [
    elements.panelName,
    elements.panelVoltage,
    elements.panelMainRating,
    elements.panelFeed,
    elements.panelMainType,
    elements.panelPositions,
    elements.panelBreakerSeries,
    elements.panelDate,
    elements.panelPhase,
    elements.panelDiversity
  ].forEach(input => {
    input.addEventListener('input', renderAll);
    input.addEventListener('change', renderAll);
  });
}

function positionCount() {
  return Math.max(1, Number(elements.panelPositions.value) || DEFAULT_CIRCUIT_SLOTS);
}

function handleFileSelection(file) {
  if (!file || !file.type.startsWith('image/')) {
    setStatus('Please choose a valid image file.');
    return;
  }
  if (file.size > 12 * 1024 * 1024) {
    setStatus('Please choose an image smaller than 12 MB.');
    return;
  }

  if (state.imageUrl) URL.revokeObjectURL(state.imageUrl);

  state.file = file;
  state.imageUrl = URL.createObjectURL(file);
  elements.imagePreview.src = state.imageUrl;
  elements.previewFrame.classList.add('has-image');
  elements.fileName.textContent = file.name;
  elements.processButton.disabled = false;
  resetProgress();
  setStatus('Image ready. Click “Read Schedule” to run OCR.');
}

async function runOcr() {
  if (!state.file) {
    setStatus('Upload an image before starting OCR.');
    return;
  }

  if (!window.Tesseract) {
    setStatus('Tesseract.js failed to load. Check your network connection and try again.');
    return;
  }

  elements.processButton.disabled = true;
  updateProgress(0, 'Starting OCR…');

  let worker;
  try {
    worker = await Tesseract.createWorker('eng', 1, {
      logger: message => {
        const ratio = typeof message.progress === 'number' ? message.progress : 0;
        updateProgress(ratio, humanizeStatus(message.status));
      }
    });

    const result = await worker.recognize(state.file);
    const text = result?.data?.text || '';
    state.rawText = text;
    elements.rawText.value = text;
    parseAndApplyText(text, true);
    updateProgress(1, 'OCR complete. Verify fields, then print or save.');
  } catch (error) {
    console.error(error);
    setStatus('OCR failed. Try a sharper image or edit text manually.');
    updateProgress(0, 'OCR failed');
  } finally {
    if (worker) await worker.terminate();
    elements.processButton.disabled = false;
  }
}

function parseAndApplyText(text, allowMetadataFill) {
  const parsed = parseScheduleText(text || '');
  if (allowMetadataFill) applyMetadataIfBlank(parsed.meta);

  if (parsed.rows.length) {
    state.rows = parsed.rows;
    setStatus(`Parsed ${parsed.rows.length} circuit row${parsed.rows.length === 1 ? '' : 's'}. Correct OCR misreads before using the study.`);
  } else {
    setStatus('No clear circuit rows detected. Edit OCR text or enter rows manually.');
  }

  renderAll();
}

function parseScheduleText(text) {
  const rawLines = text.replace(/\r/g, '\n').split('\n').map(cleanLine).filter(line => line.trim());
  const lines = rawLines.map(compactLine);
  const meta = extractMetadata(lines, text);
  const rows = [];
  const seen = new Set();

  rawLines.forEach(line => {
    const compact = compactLine(line);
    if (isIgnoredLine(compact)) return;

    const columns = splitColumns(line);
    if (columns.length >= 6) {
      const splitIndex = findSecondaryCircuitIndex(columns);
      if (splitIndex > 0) {
        [columns.slice(0, splitIndex), columns.slice(splitIndex)].forEach(group => {
          pushUniqueRow(parseColumnsToRow(group, meta.defaultSeries), rows, seen);
        });
        return;
      }
    }

    if (columns.length >= 3) {
      pushUniqueRow(parseColumnsToRow(columns, meta.defaultSeries), rows, seen);
      return;
    }

    pushUniqueRow(parseFreeformRow(compact, meta.defaultSeries), rows, seen);
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
  if (!line) return [];
  if (line.includes('|')) return line.split('|').map(part => part.trim()).filter(Boolean);
  return line.split(/\t+|\s{2,}/).map(part => part.trim()).filter(Boolean);
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
    if (looksLikeCircuit(candidate) && !/P$/i.test(String(candidate).trim()) && (looksLikeTrip(previous) || looksLikePoles(previous))) {
      return index;
    }
  }
  return -1;
}

function parseColumnsToRow(columns, defaultSeries) {
  if (!columns.length || !looksLikeCircuit(columns[0])) return null;

  const row = createEmptyRow();
  row.circuit = normalizeCircuit(columns[0]);
  row.breakerSeries = defaultSeries || '';

  const trailing = [...columns.slice(1)];
  const compactMatch = trailing.length
    ? trailing[trailing.length - 1].match(/^(\d+(?:\.\d+)?)\s*(?:A|AMP|AMPS)?\s*[/\\-]\s*([123])P?$/i)
    : null;

  if (compactMatch) {
    row.trip = `${compactMatch[1]}A`;
    row.poles = compactMatch[2];
    trailing.pop();
  } else {
    if (trailing.length && looksLikePoles(trailing[trailing.length - 1])) row.poles = trailing.pop().replace(/P/i, '');
    if (trailing.length && looksLikeTrip(trailing[trailing.length - 1])) row.trip = normalizeTrip(trailing.pop());
  }

  row.description = trailing.join(' ').trim();
  row.circuitClass = inferCircuitClass(row.description);

  if (!row.description && (!row.trip || !row.poles)) return null;
  return row;
}

function parseFreeformRow(line, defaultSeries) {
  const match = line.match(/^(\d+[A-Z]?(?:[-/,]\d+[A-Z]?)*)\s+(.+?)\s+(\d+(?:\.\d+)?)\s*(?:A|AMP|AMPS)?\s+([123])P?$/i);
  if (!match) return null;

  return {
    circuit: normalizeCircuit(match[1]),
    description: match[2].trim(),
    trip: `${match[3]}A`,
    poles: match[4],
    breakerSeries: defaultSeries || '',
    circuitClass: inferCircuitClass(match[2]),
    loadType: inferLoadType(match[2]),
    loadAmps: '',
    demandFactor: '1'
  };
}

function pushUniqueRow(row, rows, seen) {
  if (!row) return;
  const signature = `${row.circuit}|${row.description}|${row.trip}|${row.poles}`.toUpperCase();
  if (seen.has(signature)) return;
  seen.add(signature);
  rows.push(row);
}

function normalizeRows(rows) {
  const defaultSeries = String(elements.panelBreakerSeries?.value || '').trim();
  return rows
    .map(row => ({
      circuit: normalizeCircuit(row.circuit),
      description: String(row.description || '').trim(),
      trip: normalizeTrip(row.trip),
      breakerSeries: String(row.breakerSeries || defaultSeries || '').trim().toUpperCase(),
      poles: String(row.poles || '').replace(/P/i, '').trim(),
      circuitClass: CIRCUIT_CLASSES.includes(row.circuitClass) ? row.circuitClass : inferCircuitClass(row.description),
      loadType: LOAD_TYPES.includes(row.loadType) ? row.loadType : inferLoadType(row.description),
      loadAmps: normalizeLoadAmps(row.loadAmps, row.trip),
      demandFactor: normalizeDemandFactor(row.demandFactor)
    }))
    .filter(row => row.circuit || row.description || row.trip || row.poles || row.loadAmps || row.breakerSeries)
    .sort(compareCircuitRows);
}

function compareCircuitRows(a, b) {
  const aNum = firstCircuitNumber(a.circuit);
  const bNum = firstCircuitNumber(b.circuit);
  if (aNum === bNum) return a.circuit.localeCompare(b.circuit, undefined, { numeric: true, sensitivity: 'base' });
  if (aNum === Number.MAX_SAFE_INTEGER) return 1;
  if (bNum === Number.MAX_SAFE_INTEGER) return -1;
  return aNum - bNum;
}

function normalizeCircuit(value) {
  return String(value || '').toUpperCase().replace(/\s+/g, '');
}

function normalizeTrip(value) {
  const cleaned = String(value || '').trim().toUpperCase().replace(/\s+/g, '');
  if (!cleaned) return '';
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

function inferCircuitClass(description) {
  const text = String(description || '').toLowerCase();
  if (/spare|space|future/.test(text)) return 'Spare';
  if (/emergency|egress|life safety/.test(text)) return 'Emergency';
  if (/critical|it|server|ups|data/.test(text)) return 'Critical';
  if (/motor|pump|fan|compressor/.test(text)) return 'Motor';
  if (/hvac|furnace|rtu|condens/.test(text)) return 'HVAC';
  if (/recept|outlet|plug/.test(text)) return 'Receptacle';
  if (/light|fixture|luminaire|led/.test(text)) return 'Lighting';
  return 'General';
}

function firstCircuitNumber(value) {
  const match = String(value || '').match(/\d+/);
  return match ? Number(match[0]) : Number.MAX_SAFE_INTEGER;
}

function extractMetadata(lines, rawText) {
  const text = rawText.replace(/\r/g, '\n');
  const mainRatingMatch = text.match(/(?:main|mains?|service|feed(?:er)?)\s*(?:rating)?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*A/i)
    || text.match(/\b(\d+(?:\.\d+)?)\s*A\s*(?:main|mcb|mlo)\b/i);
  const positionsMatch = text.match(/(?:positions?|spaces?|circuits?)\s*[:\-]?\s*(\d{1,3})\b/i);

  return {
    panelName: findMetadata(lines, [/panel\s*(?:name|board)?\s*[:\-]?\s*(.+)/i]),
    voltage: findMetadata(lines, [/voltage\s*[:\-]?\s*(.+)/i, /(\d{2,4}(?:Y)?\s*\/\s*\d{2,4}\s*V?)/i, /(\d{3,4}\s*V)/i]),
    feed: findMetadata(lines, [/feed(?:er)?\s*[:\-]?\s*(.+)/i, /mains?\s*[:\-]?\s*(.+)/i]),
    date: findMetadata(lines, [/date\s*[:\-]?\s*(.+)/i, /(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})/, /([A-Z][a-z]{2,8}\s+\d{1,2},\s+\d{4})/]),
    defaultSeries: findMetadata(lines, [/(?:series|breaker\s*series)\s*[:\-]?\s*([A-Z0-9-]{1,10})/i]),
    mainType: /\bMLO\b/i.test(text) ? 'MLO' : (/\bMCB\b|main\s+breaker/i.test(text) ? 'MCB' : ''),
    mainRating: mainRatingMatch ? mainRatingMatch[1] : '',
    positions: positionsMatch ? positionsMatch[1] : ''
  };
}

function findMetadata(lines, patterns) {
  for (const line of lines) {
    for (const pattern of patterns) {
      const match = line.match(pattern);
      if (match && match[1]) return match[1].trim();
    }
  }
  return '';
}

function applyMetadataIfBlank(meta) {
  if (meta.panelName && !elements.panelName.value.trim()) elements.panelName.value = meta.panelName;
  if (meta.voltage && !elements.panelVoltage.value.trim()) elements.panelVoltage.value = meta.voltage;
  if (meta.feed && !elements.panelFeed.value.trim()) elements.panelFeed.value = meta.feed;
  if (meta.date && !elements.panelDate.value.trim()) elements.panelDate.value = meta.date;
  if (meta.defaultSeries && !elements.panelBreakerSeries.value.trim()) elements.panelBreakerSeries.value = meta.defaultSeries.toUpperCase();
  if (meta.mainType && !elements.panelMainType.value) elements.panelMainType.value = meta.mainType;
  if (meta.mainRating && !String(elements.panelMainRating.value || '').trim()) elements.panelMainRating.value = meta.mainRating;
  if (meta.positions && !String(elements.panelPositions.value || '').trim()) elements.panelPositions.value = meta.positions;
}

function renderAll() {
  renderEditorTable();
  renderPrintSheet();
  renderLoadAnalysis();
}

function renderEditorTable() {
  const rows = state.rows.length ? state.rows : [createEmptyRow()];
  const defaultSeries = String(elements.panelBreakerSeries.value || '').trim().toUpperCase();

  elements.editorTableBody.innerHTML = rows.map((row, index) => {
    const type = LOAD_TYPES.includes(row.loadType) ? row.loadType : inferLoadType(row.description);
    const circuitClass = CIRCUIT_CLASSES.includes(row.circuitClass) ? row.circuitClass : inferCircuitClass(row.description);
    const loadAmps = normalizeLoadAmps(row.loadAmps, row.trip);
    const demandFactor = normalizeDemandFactor(row.demandFactor);
    const breakerSeries = String(row.breakerSeries || defaultSeries || '').toUpperCase();
    return `
      <tr>
        <td><input type="text" data-field="circuit" data-index="${index}" value="${escapeHtml(row.circuit)}" placeholder="1"></td>
        <td><input type="text" data-field="description" data-index="${index}" value="${escapeHtml(row.description)}" placeholder="Lighting"></td>
        <td><input type="text" data-field="trip" data-index="${index}" value="${escapeHtml(row.trip)}" placeholder="20A"></td>
        <td><input type="text" data-field="breakerSeries" data-index="${index}" value="${escapeHtml(breakerSeries)}" placeholder="QO"></td>
        <td>
          <select data-field="poles" data-index="${index}" aria-label="Poles for circuit ${escapeHtml(row.circuit || String(index + 1))}">
            <option value="" ${row.poles ? '' : 'selected'}>—</option>
            <option value="1" ${row.poles === '1' ? 'selected' : ''}>1</option>
            <option value="2" ${row.poles === '2' ? 'selected' : ''}>2</option>
            <option value="3" ${row.poles === '3' ? 'selected' : ''}>3</option>
          </select>
        </td>
        <td><select data-field="circuitClass" data-index="${index}" aria-label="Circuit class for circuit ${escapeHtml(row.circuit || String(index + 1))}">${CIRCUIT_CLASSES.map(option => `<option value="${escapeHtml(option)}" ${circuitClass === option ? 'selected' : ''}>${escapeHtml(option)}</option>`).join('')}</select></td>
        <td><select data-field="loadType" data-index="${index}" aria-label="Load type for circuit ${escapeHtml(row.circuit || String(index + 1))}">${LOAD_TYPES.map(option => `<option value="${escapeHtml(option)}" ${type === option ? 'selected' : ''}>${escapeHtml(option)}</option>`).join('')}</select></td>
        <td><input type="number" min="0" step="any" data-field="loadAmps" data-index="${index}" value="${escapeHtml(loadAmps)}" placeholder="edit FLA"></td>
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
      renderAll();
    });
  });
}

function handleRowEdit(event) {
  const index = Number(event.target.dataset.index);
  const field = event.target.dataset.field;
  if (!state.rows[index]) state.rows[index] = createEmptyRow();

  if (field === 'circuit') {
    state.rows[index][field] = normalizeCircuit(event.target.value);
  } else if (field === 'trip') {
    state.rows[index][field] = normalizeTrip(event.target.value);
    if (!state.rows[index].loadAmps) state.rows[index].loadAmps = normalizeLoadAmps('', event.target.value);
  } else if (field === 'loadAmps') {
    state.rows[index][field] = normalizeLoadAmps(event.target.value, '');
  } else if (field === 'demandFactor') {
    state.rows[index][field] = normalizeDemandFactor(event.target.value);
  } else if (field === 'loadType') {
    state.rows[index][field] = LOAD_TYPES.includes(event.target.value) ? event.target.value : 'General';
  } else if (field === 'circuitClass') {
    state.rows[index][field] = CIRCUIT_CLASSES.includes(event.target.value) ? event.target.value : 'General';
  } else if (field === 'breakerSeries') {
    state.rows[index][field] = String(event.target.value || '').toUpperCase().trim();
  } else {
    state.rows[index][field] = String(event.target.value || '').trim();
  }

  renderPrintSheet();
  renderLoadAnalysis();
}

// Accepts "208Y/120", "480/277", or a bare "480". When only one number is
// given it is the line-to-line value, so the line-to-neutral value has to be
// derived rather than reused: a bare 480 on a 3-phase panel means 277 V to
// neutral, and treating it as 480 overstates every single-pole circuit by 73%.
function panelVoltageInfo(value, phase = 3) {
  const text = String(value || '');
  const pair = text.match(/(\d+(?:\.\d+)?)\s*(?:Y)?\s*\/\s*(\d+(?:\.\d+)?)/i);
  if (pair) return { lineToLine: Number(pair[1]), lineToNeutral: Number(pair[2]) };
  const single = text.match(/\d+(?:\.\d+)?/);
  const lineToLine = single ? Number(single[0]) : NaN;
  if (!Number.isFinite(lineToLine)) return { lineToLine, lineToNeutral: lineToLine };
  // 3-phase wye: V_LN = V_LL / sqrt(3). Single-phase 3-wire (240/120): V_LL / 2.
  const divisor = Number(phase) === 3 ? Math.sqrt(3) : 2;
  return { lineToLine, lineToNeutral: lineToLine / divisor };
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

function renderLoadAnalysis() {
  if (!elements.analysisGrid || !elements.analysisGuidance) return;

  const rows = normalizeRows(state.rows).filter(row => row.description || Number(row.loadAmps) > 0);
  const phase = Number(elements.panelPhase.value) || 3;
  const voltage = panelVoltageInfo(elements.panelVoltage.value, phase);
  const diversityInput = Math.max(1, panelNumber(elements.panelDiversity.value, 1));
  const knownVoltage = Number.isFinite(voltage.lineToLine) && voltage.lineToLine > 0;

  const connectedVa = knownVoltage ? rows.reduce((total, row) => total + rowLoadVa(row, voltage, phase), 0) : 0;
  const demandAdjustedVa = knownVoltage ? rows.reduce((total, row) => total + rowLoadVa(row, voltage, phase) * panelNumber(row.demandFactor, 1), 0) : 0;
  const coincidentVa = demandAdjustedVa / diversityInput;

  const equivalentAmps = knownVoltage && coincidentVa > 0
    ? coincidentVa / (phase === 3 ? Math.sqrt(3) * voltage.lineToLine : voltage.lineToLine)
    : 0;

  const mainRatingAmps = panelNumber(elements.panelMainRating.value, 0);
  const capacityVa = knownVoltage && mainRatingAmps > 0
    ? mainRatingAmps * voltage.lineToLine * (phase === 3 ? Math.sqrt(3) : 1)
    : 0;

  const remainingVa = capacityVa ? capacityVa - coincidentVa : 0;
  const expansionPercent = capacityVa > 0 ? (remainingVa / capacityVa) * 100 : 0;
  const effectiveDemandFactor = connectedVa > 0 ? coincidentVa / connectedVa : 0;
  const achievedDiversity = coincidentVa > 0 ? connectedVa / coincidentVa : 0;

  const positions = positionCount();
  const occupiedPositions = rows.filter(row => Number(row.poles) >= 1).reduce((sum, row) => sum + Math.max(1, Number(row.poles) || 1), 0);
  const freePositions = Math.max(0, positions - occupiedPositions);

  const classCounts = rows.reduce((counts, row) => {
    counts[row.circuitClass] = (counts[row.circuitClass] || 0) + 1;
    return counts;
  }, {});

  elements.analysisGrid.innerHTML = [
    summaryMetric('Connected load', knownVoltage ? `${formatKva(connectedVa)} kVA` : 'Needs voltage', `${rows.length} reviewed circuit${rows.length === 1 ? '' : 's'}`),
    summaryMetric('After circuit demand factors', knownVoltage ? `${formatKva(demandAdjustedVa)} kVA` : 'Needs voltage', 'before diversity'),
    summaryMetric('Estimated coincident demand', knownVoltage ? `${formatKva(coincidentVa)} kVA` : 'Needs voltage', `input diversity ${diversityInput.toFixed(2)}`),
    summaryMetric('Estimated panel FLA', knownVoltage ? `${formatNumber(equivalentAmps)} A` : 'Needs voltage', phase === 3 ? `${formatNumber(voltage.lineToLine)} V 3Ø` : `${formatNumber(voltage.lineToLine)} V 1Ø`),
    summaryMetric('Demand factor (coincident ÷ connected)', connectedVa > 0 ? `${formatPercent(effectiveDemandFactor)}` : 'Not calculated', 'calculated from reviewed values'),
    summaryMetric('Diversity factor (connected ÷ coincident)', connectedVa > 0 ? `${formatNumber(achievedDiversity)}` : 'Not calculated', 'calculated from reviewed values'),
    summaryMetric('Main capacity', capacityVa ? `${formatKva(capacityVa)} kVA` : 'Not entered', mainRatingAmps ? `${formatNumber(mainRatingAmps)} A` : 'enter main rating'),
    summaryMetric('Room for expansion', capacityVa ? `${formatKva(remainingVa)} kVA` : 'Not calculated', capacityVa ? `${formatPercent(expansionPercent / 100)} of capacity` : ''),
    summaryMetric('Panel positions used', `${Math.min(occupiedPositions, positions)} / ${positions}`, `${freePositions} open position${freePositions === 1 ? '' : 's'}`)
  ].join('');

  const notes = [];
  if (!knownVoltage) notes.push('Enter panel voltage (for example 208Y/120V or 480Y/277V) to convert current to kVA.');
  if (!rows.length) notes.push('No loaded circuits are available yet. Upload and read a schedule, or add rows manually.');
  if (rows.some(row => Number(row.loadAmps) === tripAmps(row.trip) && tripAmps(row.trip) > 0)) notes.push('Some estimated-load amps still match breaker trip values. Replace with scheduled/measured current before final use.');
  if (diversityInput === 1) notes.push('System diversity is 1.00 (conservative no-diversity assumption).');
  if (!mainRatingAmps) notes.push('Enter panel main rating to calculate expansion room.');
  if (capacityVa && remainingVa < 0) notes.push('Estimated demand exceeds stated panel main capacity.');
  if (Object.keys(classCounts).length) {
    notes.push(`Detected / selected circuit classes: ${Object.entries(classCounts).map(([type, count]) => `${count} ${type}`).join(', ')}.`);
  }

  elements.analysisGuidance.innerHTML = notes.map(note => `<p>${escapeHtml(note)}</p>`).join('');
}

function formatKva(va) {
  return formatNumber(va / 1000);
}

function formatNumber(value) {
  return Number(value || 0).toLocaleString(undefined, { maximumFractionDigits: 2 });
}

function formatPercent(value) {
  return `${(Number(value || 0) * 100).toLocaleString(undefined, { maximumFractionDigits: 1 })}%`;
}

function renderPrintSheet() {
  elements.sheetPanelName.textContent = elements.panelName.value.trim() || 'Untitled Panel';
  elements.sheetVoltage.textContent = elements.panelVoltage.value.trim() || '—';
  elements.sheetFeed.textContent = elements.panelFeed.value.trim() || '—';
  elements.sheetMain.textContent = elements.panelMainRating.value ? `${elements.panelMainRating.value}A ${elements.panelMainType.value}` : '—';
  elements.sheetPositions.textContent = String(positionCount());
  elements.sheetDate.textContent = elements.panelDate.value.trim() || defaultPrintDate();

  const slots = buildCircuitSlots(state.rows);
  const bodyRows = [];
  const pairCount = Math.ceil(positionCount() / 2);

  for (let pair = 0; pair < pairCount; pair += 1) {
    const leftSlot = pair * 2 + 1;
    const rightSlot = pair * 2 + 2;
    const left = slots[leftSlot] || createPlaceholderRow(leftSlot);
    const right = slots[rightSlot] || createPlaceholderRow(rightSlot);

    bodyRows.push(`
      <tr>
        ${renderPrintCell(left.circuit, 'circuit')}
        ${renderPrintCell(left.description, 'description')}
        ${renderPrintCell(left.trip, 'trip')}
        ${renderPrintCell(left.poles, 'poles')}
        ${renderPrintCell(left.circuitClass, 'class')}
        ${renderPrintCell(left.breakerSeries, 'series')}
        ${renderPrintCell(right.breakerSeries, 'series')}
        ${renderPrintCell(right.circuitClass, 'class')}
        ${renderPrintCell(right.poles, 'poles')}
        ${renderPrintCell(right.trip, 'trip')}
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
  const maxSlots = positionCount();

  normalized.forEach(row => {
    const slot = firstCircuitNumber(row.circuit);
    if (slot >= 1 && slot <= maxSlots && !slots[slot]) slots[slot] = row;
    else overflow.push(row);
  });

  overflow.forEach(row => {
    for (let slot = 1; slot <= maxSlots; slot += 1) {
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
  return { circuit: String(circuit), description: '', trip: '', poles: '', breakerSeries: '', circuitClass: '' };
}

function createEmptyRow() {
  return {
    circuit: '',
    description: '',
    trip: '',
    breakerSeries: '',
    poles: '',
    circuitClass: 'General',
    loadType: 'General',
    loadAmps: '',
    demandFactor: '1'
  };
}

function seedRows(count) {
  const safeCount = Math.max(1, Number(count) || DEFAULT_CIRCUIT_SLOTS);
  state.rows = Array.from({ length: safeCount }, (_, index) => ({
    circuit: String(index + 1),
    description: '',
    trip: '',
    breakerSeries: '',
    poles: '',
    circuitClass: 'General',
    loadType: 'General',
    loadAmps: '',
    demandFactor: '1'
  }));
}

function resetApp() {
  if (state.imageUrl) URL.revokeObjectURL(state.imageUrl);

  state.file = null;
  state.imageUrl = '';
  state.rawText = '';
  seedRows(DEFAULT_CIRCUIT_SLOTS);
  elements.imageInput.value = '';
  elements.rawText.value = '';
  elements.panelName.value = '';
  elements.panelVoltage.value = '';
  elements.panelMainRating.value = '';
  elements.panelFeed.value = '';
  elements.panelMainType.value = 'MLO';
  elements.panelPositions.value = String(DEFAULT_CIRCUIT_SLOTS);
  elements.panelBreakerSeries.value = '';
  elements.panelDate.value = '';
  elements.panelPhase.value = '3';
  elements.panelDiversity.value = '1';
  elements.imagePreview.removeAttribute('src');
  elements.previewFrame.classList.remove('has-image');
  elements.fileName.textContent = 'No file selected';
  elements.processButton.disabled = true;
  resetProgress();
  setStatus('Reset complete. Upload a new schedule image to begin again.');
  renderAll();
}

function handleParseText() {
  parseAndApplyText(elements.rawText.value, false);
}

function updateProgress(value, statusMessage) {
  const percent = Math.max(0, Math.min(100, Math.round(value * 100)));
  elements.progressFill.style.width = `${percent}%`;
  elements.progressLabel.textContent = `${percent}%`;
  if (statusMessage) setStatus(statusMessage);
}

function resetProgress() {
  updateProgress(0);
}

function setStatus(message) {
  elements.statusText.textContent = message;
}

function humanizeStatus(status) {
  if (!status) return 'Processing…';
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
  if (!state.rows.some(row => row.description || row.trip || row.poles || row.breakerSeries)) {
    setStatus('Add or parse at least one circuit row before printing.');
    return;
  }

  window.print();
}

function saveStudyData() {
  const data = {
    panel: {
      name: elements.panelName.value.trim(),
      voltage: elements.panelVoltage.value.trim(),
      mainRatingAmps: elements.panelMainRating.value ? Number(elements.panelMainRating.value) : null,
      feed: elements.panelFeed.value.trim(),
      mainType: elements.panelMainType.value,
      positions: positionCount(),
      breakerSeries: elements.panelBreakerSeries.value.trim().toUpperCase(),
      date: elements.panelDate.value.trim() || defaultPrintDate(),
      phase: Number(elements.panelPhase.value) || 3,
      diversity: Math.max(1, panelNumber(elements.panelDiversity.value, 1))
    },
    rows: normalizeRows(state.rows)
  };

  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  const safeName = (data.panel.name || 'panel-schedule').replace(/[^a-z0-9-_]+/gi, '-').toLowerCase();
  anchor.href = url;
  anchor.download = `${safeName}-power-study.json`;
  anchor.click();
  URL.revokeObjectURL(url);
  setStatus('Saved panel study data as JSON.');
}

function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

if (typeof window !== 'undefined' && window.__ENABLE_PANEL_POWER_STUDY_TEST_API__) {
  window.__panelPowerStudyTestApi = {
    parseScheduleText,
    parseColumnsToRow,
    parseFreeformRow,
    normalizeRows,
    normalizeTrip,
    normalizeCircuit,
    firstCircuitNumber,
    extractMetadata,
    buildCircuitSlots,
    humanizeStatus,
    inferLoadType,
    inferCircuitClass,
    panelVoltageInfo,
    rowLoadVa,
    normalizeLoadAmps,
    normalizeDemandFactor,
    positionCount
  };
}
