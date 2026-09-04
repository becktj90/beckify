/* On-device Tesseract is the default. Optional Enhance with AI calls
   BeckifyVlmOcr.analyzePanelDirectory after the user opts in. Photos are
   never uploaded on file pick. */

const MAX_CIRCUIT_SLOTS = 42;
const MAX_EDITOR_SLOTS = 84;
const MAX_SHOTS_PER_VIEW = 3;
const MAX_SHOTS_TOTAL = 5;
const TYPICAL_SLOT_COUNTS = [8, 12, 16, 18, 20, 24, 30, 32, 36, 40, 42, 48, 54, 60, 72, 84];
const LOAD_TYPES = ['General', 'Lighting', 'Receptacle', 'Motor', 'HVAC', 'Kitchen', 'IT / Electronics', 'Process', 'EV Charging', 'Spare'];
const REQUIRED_VIEWS = ['schedule', 'breakers'];

const state = {
  file: null,
  files: [],
  imageUrl: '',
  imageUrls: [],
  views: {
    schedule: { files: [], urls: [] },
    breakers: { files: [], urls: [] }
  },
  rows: [],
  rawText: '',
  lastProgress: 0,
  source: '',
  slotCount: 0,
  calcReady: false
};

const elements = {};

window.addEventListener('pagehide', () => {
  revokeShotUrls();
  state.file = null;
  state.files = [];
  state.views.schedule = { files: [], urls: [] };
  state.views.breakers = { files: [], urls: [] };
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
  elements.processButton = document.getElementById('processButton');
  elements.resetButton = document.getElementById('resetButton');
  elements.statusText = document.getElementById('statusText');
  elements.fileName = document.getElementById('fileName');
  elements.progressFill = document.getElementById('progressFill');
  elements.progressLabel = document.getElementById('progressLabel');
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
  elements.calculateButton = document.getElementById('ps_calculate');
  elements.openPanelCaution = document.getElementById('openPanelCaution');
  elements.directoryGrid = document.getElementById('directoryGrid');
  elements.directoryGuidance = document.getElementById('directoryGuidance');
  elements.printButton = document.getElementById('printButton');
  elements.copyCsvButton = document.getElementById('copyCsvButton');
  elements.sheetPanelName = document.getElementById('sheetPanelName');
  elements.sheetVoltage = document.getElementById('sheetVoltage');
  elements.sheetFeed = document.getElementById('sheetFeed');
  elements.sheetDate = document.getElementById('sheetDate');
  elements.printScheduleBody = document.getElementById('printScheduleBody');
  elements.analysisGrid = document.getElementById('analysisGrid');
  elements.analysisGuidance = document.getElementById('analysisGuidance');
  elements.enhance = document.getElementById('panelEnhance');
  elements.vlmSettings = document.getElementById('panelVlmSettings');
  elements.vlmEndpoint = document.getElementById('panelVlmEndpoint');
  elements.vlmToken = document.getElementById('panelVlmToken');
  elements.vlmConfig = document.getElementById('panelVlmConfig');
  elements.privacyBanner = document.getElementById('privacyBanner');
  elements.mergeRows = document.getElementById('mergeRows');
  elements.sourceBadge = document.getElementById('ocrSource');
  elements.shotList = document.getElementById('shotList');
  elements.scheduleAdd = document.getElementById('scheduleAdd');
  elements.breakersAdd = document.getElementById('breakersAdd');
}

function bindViewIntake(view) {
  const fileInput = document.getElementById(view + 'File');
  const captureInput = document.getElementById(view + 'Capture');
  const addButton = document.getElementById(view + 'Add');
  const addInput = document.getElementById(view + 'AddFile');
  const dropZone = document.getElementById(view + 'Drop');
  if (fileInput) {
    fileInput.addEventListener('change', event => {
      const [file] = event.target.files || [];
      handleFileSelection(file, { view });
      fileInput.value = '';
    });
  }
  if (captureInput) {
    captureInput.addEventListener('change', event => {
      const [file] = event.target.files || [];
      handleFileSelection(file, { view });
      captureInput.value = '';
    });
  }
  if (addButton && addInput) {
    addButton.addEventListener('click', () => addInput.click());
    addInput.addEventListener('change', event => {
      const [file] = event.target.files || [];
      handleFileSelection(file, { view, append: true });
      addInput.value = '';
    });
  }
  if (dropZone) {
    ['dragenter', 'dragover'].forEach(eventName => {
      dropZone.addEventListener(eventName, event => {
        event.preventDefault();
        dropZone.classList.add('is-dragover');
      });
    });
    ['dragleave', 'drop'].forEach(eventName => {
      dropZone.addEventListener(eventName, event => {
        event.preventDefault();
        dropZone.classList.remove('is-dragover');
      });
    });
    dropZone.addEventListener('drop', event => {
      const [file] = event.dataTransfer?.files || [];
      handleFileSelection(file, { view });
    });
  }
}

function bindEvents() {
  REQUIRED_VIEWS.forEach(bindViewIntake);

  elements.processButton.addEventListener('click', runOcr);
  elements.resetButton.addEventListener('click', resetApp);
  elements.printButton.addEventListener('click', handlePrint);
  if (elements.copyCsvButton) elements.copyCsvButton.addEventListener('click', handleCopyCsv);
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

  [elements.panelName, elements.panelFeed, elements.panelDate].forEach(input => {
    if (!input) return;
    input.addEventListener('input', renderPrintSheet);
    input.addEventListener('change', renderPrintSheet);
  });
  [elements.panelVoltage, elements.panelPhase, elements.panelCapacityAmps, elements.panelDiversity].forEach(input => {
    if (!input) return;
    input.addEventListener('input', () => {
      invalidateCalc();
      renderPrintSheet();
      renderLoadAnalysis();
      renderDirectoryMetrics();
    });
    input.addEventListener('change', () => {
      invalidateCalc();
      renderPrintSheet();
      renderLoadAnalysis();
      renderDirectoryMetrics();
    });
  });
  if (elements.reviewedSchedule) {
    elements.reviewedSchedule.addEventListener('change', () => {
      if (!elements.reviewedSchedule.checked) invalidateCalc();
      renderLoadAnalysis();
      renderDirectoryMetrics();
    });
  }
  if (elements.calculateButton) {
    elements.calculateButton.addEventListener('click', requestCalculate);
  }
  if (elements.enhance) {
    elements.enhance.addEventListener('change', syncVlmUi);
  }
  [elements.vlmEndpoint, elements.vlmToken].forEach(input => {
    if (!input) return;
    input.addEventListener('change', syncVlmUi);
    input.addEventListener('blur', syncVlmUi);
  });
  syncVlmUi();
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
  invalidateCalc();
}

function invalidateCalc() {
  state.calcReady = false;
}

function isScheduleReviewed() {
  return !!(elements.reviewedSchedule && elements.reviewedSchedule.checked);
}

function isCalcReady() {
  return isScheduleReviewed() && state.calcReady === true;
}

function requestCalculate() {
  if (!isScheduleReviewed()) {
    state.calcReady = false;
    setStatus('Check “I reviewed every circuit row” before calculating. Edit the table first — OCR is a draft.');
    renderLoadAnalysis();
    renderDirectoryMetrics();
    return;
  }
  state.calcReady = true;
  renderAll();
  setStatus(selectedPhase()
    ? 'Calculated from the reviewed table. Edit a row to update the schedule, then calculate again.'
    : 'Calculated directory metrics. Select 1-phase or 3-phase, then calculate again for load math.');
}

function scheduleCalcGateMessage(kind) {
  const isLoad = kind === 'load';
  if (!isScheduleReviewed()) {
    return {
      metricLabel: 'Waiting for review',
      metricValue: 'Edit the table',
      metricDetail: isLoad
        ? 'OCR is a draft. Load summary stays hidden until you confirm the table and calculate. Breaker trip is not a reviewed load.'
        : 'OCR is a draft. Directory metrics stay hidden until you confirm the table and calculate.',
      guidance: '<p>Correct any circuit row by hand, then check “I reviewed every circuit row” and click Calculate from reviewed table. You can still type every field with no photo.</p>',
    };
  }
  if (!state.calcReady) {
    return {
      metricLabel: 'Waiting to calculate',
      metricValue: 'Click Calculate',
      metricDetail: isLoad
        ? 'The schedule is editable. Load summary stays hidden until you calculate from the reviewed table. Breaker trip is not a reviewed load.'
        : 'The schedule is editable. Directory metrics stay hidden until you calculate from the reviewed table.',
      guidance: '<p>Update any row or panel field, then click Calculate from reviewed table. Changing a circuit row clears the review check so a second look is required.</p>',
    };
  }
  return null;
}

function viewState(view) {
  if (!state.views[view]) state.views[view] = { files: [], urls: [] };
  return state.views[view];
}

function hasView(view) {
  return viewState(view).files.length > 0;
}

function viewFiles(view) {
  return viewState(view).files.slice();
}

function allViewFiles() {
  return REQUIRED_VIEWS.flatMap(view => viewFiles(view));
}

function canAddPanelShot(photos, kind) {
  const counts = photos || {};
  const schedule = (counts.schedule || []).length;
  const breakers = (counts.breakers || []).length;
  const viewCount = kind === 'breakers' ? breakers : schedule;
  return viewCount < MAX_SHOTS_PER_VIEW && (schedule + breakers) < MAX_SHOTS_TOTAL;
}

function canAddShot(kind) {
  return canAddPanelShot({
    schedule: viewFiles('schedule'),
    breakers: viewFiles('breakers'),
  }, kind);
}

function syncLegacyFiles() {
  state.files = allViewFiles();
  state.file = state.files[state.files.length - 1] || null;
  state.imageUrls = REQUIRED_VIEWS.flatMap(view => viewState(view).urls.slice());
  state.imageUrl = state.imageUrls[state.imageUrls.length - 1] || '';
}

function updateViewPreview(view) {
  const bucket = viewState(view);
  const frame = document.getElementById(view + 'Preview');
  const image = document.getElementById(view + 'PreviewImg');
  const name = document.getElementById(view + 'FileName');
  const addButton = document.getElementById(view + 'Add');
  const last = bucket.files[bucket.files.length - 1];
  const url = bucket.urls[bucket.urls.length - 1];
  if (frame) frame.classList.toggle('has-image', Boolean(url));
  if (image) {
    if (url) image.src = url;
    else image.removeAttribute('src');
  }
  if (name) {
    name.textContent = !last
      ? (view === 'breakers' ? 'No breaker photo yet' : 'No schedule photo yet')
      : (bucket.files.length === 1 ? last.name : bucket.files.length + ' photos — last: ' + last.name);
  }
  if (addButton) addButton.disabled = bucket.files.length === 0 || !canAddShot(view);
}

function describeShotRole(view, index, total) {
  const label = view === 'breakers' ? 'Breakers' : 'Schedule';
  const ordinal = Number(index) + 1;
  const count = Number(total) || 1;
  if (count <= 1) return label + ' 1';
  const half = ordinal === 1 ? 'top/left' : (ordinal === count ? 'bottom/right' : 'middle');
  return label + ' ' + ordinal + '/' + count + ' (' + half + ')';
}

function refreshIntakeUi() {
  syncLegacyFiles();
  REQUIRED_VIEWS.forEach(updateViewPreview);
  const ready = hasView('schedule') && hasView('breakers');
  if (elements.processButton) elements.processButton.disabled = !ready;
  const scheduleNames = viewFiles('schedule').map(file => file.name);
  const breakerNames = viewFiles('breakers').map(file => file.name);
  if (elements.fileName) {
    elements.fileName.textContent = ready
      ? `Schedule ${scheduleNames.length} · Breakers ${breakerNames.length}`
      : (!scheduleNames.length && !breakerNames.length ? 'No files selected' : 'Need both views');
  }
  if (elements.shotList) {
    const parts = [];
    viewFiles('schedule').forEach((_, index, list) => {
      parts.push(describeShotRole('schedule', index, list.length));
    });
    viewFiles('breakers').forEach((_, index, list) => {
      parts.push(describeShotRole('breakers', index, list.length));
    });
    elements.shotList.textContent = parts.join(' · ');
  }
}

function handleFileSelection(file, opts) {
  if (!file || !isLikelyImageFile(file)) {
    setStatus('Please choose a valid image file.');
    return;
  }
  if (file.size > 12 * 1024 * 1024) {
    setStatus('Please choose an image smaller than 12 MB.');
    return;
  }

  const view = opts && REQUIRED_VIEWS.includes(opts.view) ? opts.view : 'schedule';
  const bucket = viewState(view);
  const append = !!(opts && opts.append) && bucket.files.length > 0;
  if (!append) {
    bucket.urls.forEach(url => {
      try { URL.revokeObjectURL(url); } catch (_) { /* ignore */ }
    });
    bucket.files = [file];
    bucket.urls = [URL.createObjectURL(file)];
  } else if (canAddShot(view)) {
    bucket.files.push(file);
    bucket.urls.push(URL.createObjectURL(file));
  } else {
    setStatus(viewState(view).files.length >= MAX_SHOTS_PER_VIEW
      ? 'That view already has three photos. Reset to start a new set.'
      : 'This read is limited to 5 photos total (the AI quota is 5 reads / 15 min). Reset to start a new set.');
    return;
  }

  if (append && elements.mergeRows) elements.mergeRows.checked = true;
  clearReview();
  resetProgress();
  refreshIntakeUi();
  const missing = !hasView('schedule') ? 'schedule / directory' : (!hasView('breakers') ? 'breaker / dead-front' : '');
  setStatus(missing
    ? `Saved the ${view} photo on this device. Add a ${missing} photo — take or upload — then read both views.`
    : (enhanceOn()
      ? 'Both views are ready on this device. Read both views will upload them only because Enhance with AI is on.'
      : 'Both views are ready. Click “Read both views” to OCR the schedule and count breaker spaces.'));
}

function revokeShotUrls() {
  REQUIRED_VIEWS.forEach(view => {
    const bucket = viewState(view);
    bucket.urls.forEach(url => {
      try { URL.revokeObjectURL(url); } catch (_) { /* ignore */ }
    });
    bucket.urls = [];
    bucket.files = [];
  });
  state.imageUrls = [];
  state.imageUrl = '';
}

function selectedPhase() {
  const raw = elements.panelPhase ? elements.panelPhase.value : '';
  const n = Number(raw);
  return n === 1 || n === 3 ? n : null;
}

function tableHasUserContent(rows) {
  return (rows || []).some(row => {
    const desc = String(row.description || '').trim();
    const trip = String(row.trip || '').trim();
    const poles = String(row.poles || '').trim();
    const load = String(row.loadAmps || '').trim();
    return desc || trip || poles || (load && !row.loadAmpsCopiedFromTrip);
  });
}

function mergeCircuitRows(base, incoming) {
  const byKey = new Map();
  const leftover = [];
  (base || []).forEach(row => {
    const key = normalizeCircuit(row.circuit);
    if (key) byKey.set(key, Object.assign({}, row, { circuit: key }));
    else leftover.push(Object.assign({}, row));
  });
  (incoming || []).forEach(row => {
    const key = normalizeCircuit(row.circuit);
    if (!key) {
      leftover.push(Object.assign({}, row));
      return;
    }
    const prev = byKey.get(key);
    if (!prev || !tableHasUserContent([prev])) {
      byKey.set(key, Object.assign({}, row, { circuit: key }));
      return;
    }
    if (!prev.description && row.description) prev.description = row.description;
    if (!prev.trip && row.trip) prev.trip = row.trip;
    if (!prev.poles && row.poles) prev.poles = row.poles;
    byKey.set(key, prev);
  });
  return normalizeRows([...byKey.values(), ...leftover]).slice(0, MAX_EDITOR_SLOTS);
}

function snapSlotCount(value) {
  const count = Number(value);
  if (!Number.isFinite(count) || count < 6) return 0;
  const clamped = Math.min(MAX_EDITOR_SLOTS, Math.max(6, Math.round(count)));
  let best = clamped;
  let dist = Infinity;
  TYPICAL_SLOT_COUNTS.forEach(typical => {
    const next = Math.abs(typical - clamped);
    if (next < dist || (next === dist && typical > best)) {
      dist = next;
      best = typical;
    }
  });
  return dist <= 3 ? best : clamped;
}

function maxCircuitIn(rows) {
  return (rows || []).reduce((max, row) => {
    const n = firstCircuitNumber(row.circuit);
    if (!Number.isFinite(n) || n < 1 || n > MAX_EDITOR_SLOTS) return max;
    return n > max ? n : max;
  }, 0);
}

function sizeTableToSlots(slotCount, rows) {
  const count = snapSlotCount(slotCount) || 0;
  if (!count) return normalizeRows(rows || []);
  const seeded = Array.from({ length: Math.min(MAX_EDITOR_SLOTS, count) }, (_, index) => {
    const row = createEmptyRow();
    row.circuit = String(index + 1);
    return row;
  });
  return mergeCircuitRows(seeded, rows || []);
}

function parseBreakerFace(text) {
  const raw = String(text || '');
  const compact = raw.replace(/\s+/g, ' ').trim();
  const labeled = compact.match(/\b(\d{1,2})\s*[-–]?\s*(?:circuit|ckt|space|slot)s?\b/i)
    || compact.match(/\b(?:circuit|ckt|space|slot)s?\s*[:#-]?\s*(\d{1,2})\b/i);
  let slotCount = labeled ? snapSlotCount(labeled[1]) : 0;
  const rows = [];
  const numbered = raw.matchAll(/\b(?:ckt|circuit|#)?\s*([1-9]\d?)\s+(\d{1,3})\s*A\b/gi);
  for (const match of numbered) {
    rows.push({
      circuit: String(Number(match[1])),
      description: '',
      trip: normalizeTrip(match[2] + 'A'),
      poles: '1',
      loadType: 'General',
      loadAmps: '',
      loadAmpsCopiedFromTrip: false,
      demandFactor: '1'
    });
  }
  if (!slotCount && !rows.length) {
    const trips = [...raw.matchAll(/\b(\d{1,3})\s*A\b/gi)]
      .map(match => Number(match[1]))
      .filter(n => n >= 15 && n <= 400);
    if (trips.length >= 6) {
      trips.forEach((amp, index) => {
        rows.push({
          circuit: String(index + 1),
          description: '',
          trip: String(amp),
          poles: '1',
          loadType: 'General',
          loadAmps: '',
          loadAmpsCopiedFromTrip: false,
          demandFactor: '1'
        });
      });
    }
  }
  return { slotCount: slotCount || 0, rows: normalizeRows(rows) };
}

function applyCombinedRead(scheduleRows, breakerInfo, opts) {
  const incomingSchedule = scheduleRows || [];
  const breakerRows = (breakerInfo && breakerInfo.rows) || [];
  const printed = Number(breakerInfo && breakerInfo.slotCount)
    || Number(opts && opts.slotCount)
    || 0;
  let next = sizeTableToSlots(printed, incomingSchedule);
  if (breakerRows.length) next = mergeCircuitRows(next, breakerRows);
  const merge = !!(opts && opts.merge) && tableHasUserContent(state.rows);
  state.rows = merge ? mergeCircuitRows(state.rows, next) : next;
  state.slotCount = printed > 0 ? printed : 0;
}

function setSource(kind, extra) {
  state.source = kind || '';
  if (!elements.sourceBadge) return;
  if (!kind) {
    elements.sourceBadge.hidden = true;
    elements.sourceBadge.textContent = '';
    return;
  }
  elements.sourceBadge.hidden = false;
  if (kind === 'vlm') {
    elements.sourceBadge.textContent = 'Source: AI draft' + (extra ? ' (' + extra + ')' : '') + '. Photos were forwarded only because Enhance with AI was on.';
  } else {
    elements.sourceBadge.textContent = 'Source: on-device Tesseract. Photos stayed on this device.' + (extra ? ' ' + extra : '');
  }
}

function enhanceOn() {
  return !!(elements.enhance && elements.enhance.checked);
}

function syncVlmUi() {
  const on = enhanceOn();
  if (elements.vlmSettings) elements.vlmSettings.hidden = !on;
  if (elements.privacyBanner) {
    elements.privacyBanner.classList.toggle('is-upload', on);
    const strong = elements.privacyBanner.querySelector('strong');
    const label = on
      ? ' Enhance with AI is on. The photos will leave this device only when you click Read both views. If you use the Beckify proxy, they may be forwarded to OpenAI and/or Anthropic. Default Tesseract stays available if you turn this off.'
      : ' The photos stay on this device. They are never uploaded to Beckify or any server unless you turn on Enhance with AI and then click Read both views. On-device Tesseract.js is the default. The images are not saved after you leave or reset.';
    if (strong) {
      strong.textContent = 'Privacy before you pick a photo.';
      strong.nextSibling && strong.nextSibling.remove();
      strong.after(document.createTextNode(label));
    }
  }
  const Vlm = window.BeckifyVlmOcr;
  if (Vlm && elements.vlmEndpoint && !elements.vlmEndpoint.dataset.hydrated) {
    const saved = Vlm.loadSettings();
    if (saved.endpoint) elements.vlmEndpoint.value = saved.endpoint;
    if (saved.token && elements.vlmToken) elements.vlmToken.value = saved.token;
    elements.vlmEndpoint.dataset.hydrated = '1';
  }
  if (Vlm && on) {
    const savedForm = Vlm.saveFormSettings
      ? Vlm.saveFormSettings(elements.vlmEndpoint && elements.vlmEndpoint.value, elements.vlmToken && elements.vlmToken.value)
      : Vlm.saveSettings({
        endpoint: elements.vlmEndpoint && elements.vlmEndpoint.value,
        token: elements.vlmToken && elements.vlmToken.value,
      });
    if (savedForm && savedForm.tokenCleared && elements.vlmToken) elements.vlmToken.value = '';
  }
  if (elements.vlmConfig && Vlm) {
    const cfg = Vlm.resolveConfig(on);
    if (!on) elements.vlmConfig.textContent = 'Enhance is off. On-device Tesseract is the default.';
    else if (cfg.mode === 'custom') elements.vlmConfig.textContent = 'Custom HTTPS endpoint will receive the photos when you click Read both views.';
    else if (cfg.mode === 'proxy') {
      elements.vlmConfig.textContent = `Beckify proxy (${cfg.proxyUrl}/api/analyze-panel) will receive the photos when you click Read both views. `
        + (Vlm.PROXY_DOWNSTREAM_NOTE || 'The Beckify proxy may forward the photo to OpenAI and/or Anthropic.');
    }
    else elements.vlmConfig.textContent = 'No HTTPS endpoint is configured. Read both views will stay on-device Tesseract.';
  }
}

function rowsFromDraft(draft) {
  const Vlm = window.BeckifyVlmOcr;
  const rows = Vlm && Vlm.rowsFromPanelDraft
    ? Vlm.rowsFromPanelDraft(draft, createEmptyRow)
    : [];
  rows.forEach(row => {
    row.trip = row.trip ? normalizeTrip(row.trip) : '';
    row.poles = String(row.poles || '').replace(/P/i, '').trim();
    row.loadType = inferLoadType(row.description);
    row.loadAmps = '';
    row.loadAmpsCopiedFromTrip = false;
    row.demandFactor = row.demandFactor || '1';
  });
  return rows;
}

function applyDraftMeta(draft) {
  const Vlm = window.BeckifyVlmOcr;
  const meta = Vlm && Vlm.panelMetaFromDraft ? Vlm.panelMetaFromDraft(draft) : {};
  applyMetadataIfBlank({
    panelName: meta.panelName,
    voltage: meta.voltage,
    feed: meta.mainAmps ? `${meta.mainAmps}A Main` : '',
    date: '',
  });
  if (meta.voltage && !elements.panelVoltage.value.trim()) elements.panelVoltage.value = String(meta.voltage);
  if (meta.mainAmps && elements.panelCapacityAmps && !elements.panelCapacityAmps.value.trim()) {
    elements.panelCapacityAmps.value = String(meta.mainAmps);
  }
  if (meta.phases && elements.panelPhase && (meta.phases === 1 || meta.phases === 3)) {
    elements.panelPhase.value = String(meta.phases);
  }
}

function applyVlmDraft(draft, warnings, breakerDraft) {
  const scheduleRows = rowsFromDraft(draft);
  const breakerRows = rowsFromDraft(breakerDraft);
  const slotCount = (breakerDraft && breakerDraft.slotCount)
    || (draft && draft.slotCount)
    || 0;
  applyCombinedRead(scheduleRows, { slotCount, rows: breakerRows }, {
    merge: !!(elements.mergeRows && elements.mergeRows.checked),
  });
  applyDraftMeta(draft);
  applyDraftMeta(breakerDraft);
  const rawParts = [(draft && draft.rawText) || '', (breakerDraft && breakerDraft.rawText) || ''].filter(Boolean);
  state.rawText = rawParts.join('\n--- breakers ---\n');
  if (elements.rawText) elements.rawText.value = state.rawText;
  clearReview();
  const extra = (warnings && warnings.length) ? ` ${warnings.join(' ')}` : '';
  setSource('vlm');
  setStatus(`AI draft filled ${state.rows.length} circuit row${state.rows.length === 1 ? '' : 's'} from the schedule and breaker views. This is not perfect OCR and not an AI electrician. Correct every row, check the review box, then calculate.${extra}`);
  renderAll();
}

async function recognizeView(view, files, progressStart, progressSpan) {
  let combined = '';
  let anyOpen = false;
  let anyLow = false;
  let lastOut = { text: '', failed: true, confidence: 0 };
  for (let index = 0; index < files.length; index += 1) {
    const out = await window.BeckifyOcr.recognize(files[index], {
      mode: 'directory',
      onProgress: (ratio, status) => {
        const start = progressStart + (index / files.length) * progressSpan;
        const span = progressSpan / files.length;
        updateProgress(start + (Number(ratio) || 0) * span, (window.BeckifyOcr.humanizeStatus && window.BeckifyOcr.humanizeStatus(status)) || humanizeStatus(status));
      }
    });
    lastOut = out;
    if (out.looksLikeOpenPanel) anyOpen = true;
    if (out.lowConfidence) anyLow = true;
    if (out.text) combined = combined ? `${combined}\n${out.text}` : out.text;
  }
  return { text: combined, anyOpen, anyLow, lastOut, view };
}

async function runOnDeviceOcr() {
  const scheduleList = viewFiles('schedule');
  const breakerList = viewFiles('breakers');
  const scheduleOut = await recognizeView('schedule', scheduleList, 0, 0.55);
  const breakerOut = await recognizeView('breakers', breakerList, 0.55, 0.45);
  const scheduleParsed = parseScheduleText(scheduleOut.text || '');
  const breakerInfo = parseBreakerFace(breakerOut.text || '');
  applyMetadataIfBlank(scheduleParsed.meta);
  applyCombinedRead(scheduleParsed.rows, breakerInfo, {
    merge: !!(elements.mergeRows && elements.mergeRows.checked),
  });
  const text = [scheduleOut.text, breakerOut.text].filter(Boolean).join('\n--- breakers ---\n');
  state.rawText = text;
  if (elements.rawText) elements.rawText.value = text;
  clearReview();
  const anyOpen = scheduleOut.anyOpen || breakerOut.anyOpen;
  if (elements.openPanelCaution) elements.openPanelCaution.hidden = !anyOpen;
  if (anyOpen) {
    setStatus('A photo looks like a live open interior. Do not work inside a live panel. For breakers, photograph the dead-front with the cover on.');
  }
  if (!String(text).trim()) {
    setStatus('OCR found no usable text. Existing rows were left alone. Fill the table manually — you are not blocked.' + (window.BeckifyVlmOcr ? ' Enhance with AI can draft a two-up directory from a messy photo.' : ''));
    updateProgress(1, 'OCR found no text');
    setSource('tesseract');
    renderAll();
    return breakerOut.lastOut || scheduleOut.lastOut;
  }
  const shotCount = scheduleList.length + breakerList.length;
  setSource('tesseract', shotCount > 1 ? `Read ${scheduleList.length} schedule and ${breakerList.length} breaker photo${breakerList.length === 1 ? '' : 's'}.` : '');
  if (!anyOpen) {
    setStatus(`OCR drafted ${state.rows.length} circuit row${state.rows.length === 1 ? '' : 's'} from the schedule and breaker views${breakerInfo.slotCount ? ` (${breakerInfo.slotCount} spaces)` : ''}. Correct every row, check review, then calculate.`);
  }
  if (scheduleOut.anyLow || breakerOut.anyLow) {
    const conf = (breakerOut.lastOut.confidence || scheduleOut.lastOut.confidence || 0);
    setStatus(`OCR confidence is low (${conf.toFixed(0)}%). Treat every circuit row as a draft and correct it. You are not blocked from typing the directory by hand.`);
  }
  updateProgress(1, 'OCR complete. Review the table before calculating.');
  renderAll();
  return breakerOut.lastOut || scheduleOut.lastOut;
}

async function runOcr() {
  if (!hasView('schedule') || !hasView('breakers')) {
    setStatus('Add both required views: a schedule/directory photo and a breaker/dead-front photo. Take or upload each. Or type the table by hand.');
    return;
  }

  if (!window.BeckifyOcr) {
    setStatus('On-device OCR helper did not load. Fill the table manually — you are not blocked.');
    return;
  }

  elements.processButton.disabled = true;
  const Vlm = window.BeckifyVlmOcr;
  const useVlm = enhanceOn() && Vlm && Vlm.shouldUpload(true);
  if (enhanceOn() && Vlm && !useVlm) {
    setStatus('Enhance with AI is on but no HTTPS endpoint is configured. Using on-device Tesseract instead.');
  }

  try {
    if (useVlm) {
      updateProgress(0.1, 'Uploading both views for optional AI enhance…');
      try {
        const scheduleOut = await Vlm.analyzePanelDirectory(viewFiles('schedule'), {
          enhanceOn: true,
          view: 'schedule',
          onProgress: (ratio, status) => {
            updateProgress(0.1 + (Number(ratio) || 0) * 0.4, status || 'Reading schedule…');
          },
        });
        let breakerDraft = null;
        let breakerWarnings = [];
        try {
          const breakerOut = await Vlm.analyzePanelDirectory(viewFiles('breakers'), {
            enhanceOn: true,
            view: 'breakers',
            onProgress: (ratio, status) => {
              updateProgress(0.5 + (Number(ratio) || 0) * 0.45, status || 'Counting breaker spaces…');
            },
          });
          breakerDraft = breakerOut.draft;
          breakerWarnings = breakerOut.warnings || [];
        } catch (breakerError) {
          const formatted = (Vlm.formatVisionError && Vlm.formatVisionError(breakerError)) || (breakerError && breakerError.message) || 'Breaker AI read failed.';
          setStatus(formatted + ' Counting breaker spaces on-device.');
          const local = await recognizeView('breakers', viewFiles('breakers'), 0.5, 0.45);
          const parsed = parseBreakerFace(local.text || '');
          breakerDraft = { slotCount: parsed.slotCount, rawText: local.text, rows: [] };
          if (parsed.rows.length) {
            breakerDraft = Object.assign(breakerDraft, {
              rows: parsed.rows.map(row => ({
                circuit: { value: row.circuit },
                description: { value: row.description },
                trip: { value: row.trip },
                poles: { value: row.poles },
              })),
            });
          }
        }
        applyVlmDraft(scheduleOut.draft, (scheduleOut.warnings || []).concat(breakerWarnings), breakerDraft);
        updateProgress(1, 'AI draft ready. Review every circuit.');
        return;
      } catch (error) {
        const formatted = (Vlm.formatVisionError && Vlm.formatVisionError(error)) || (error && error.message) || 'AI enhance failed.';
        setStatus(formatted + ' Falling back to on-device OCR.');
      }
    }
    updateProgress(0, 'Starting on-device OCR…');
    await runOnDeviceOcr();
  } catch (error) {
    console.error(error);
    setStatus((error && error.message ? `${error.message} ` : '') + 'OCR failed. Fill the table manually — you are not blocked.');
    updateProgress(0, 'OCR failed');
  } finally {
    elements.processButton.disabled = false;
  }
}

function parseAndApplyText(text, allowMetadataFill, opts) {
  const parsed = parseScheduleText(text || '');
  if (allowMetadataFill) {
    applyMetadataIfBlank(parsed.meta);
  }

  if (parsed.rows.length) {
    const merge = !!(opts && opts.merge);
    state.rows = merge && tableHasUserContent(state.rows)
      ? mergeCircuitRows(state.rows, parsed.rows)
      : parsed.rows;
    setStatus(`Parsed ${parsed.rows.length} circuit row${parsed.rows.length === 1 ? '' : 's'}. Correct any OCR misreads before printing.`);
  } else {
    setStatus('No clear circuit rows were detected. Existing rows were left alone. Edit the OCR text or enter rows manually below.');
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

    const paired = parsePairedDirectoryLine(compact);
    if (paired) {
      paired.forEach(row => pushUniqueRow(row, rows, seen));
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

    splitCircuitSegments(compact).forEach(segment => {
      pushUniqueRow(parseSegmentTokens(segment), rows, seen);
    });
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
  const segments = splitCircuitSegments(compactLine(line));
  if (!segments.length) return null;
  return parseSegmentTokens(segments[0]);
}

const MAX_DIRECTORY_CIRCUIT = 200;

function isBareCircuitToken(token) {
  return /^\d{1,3}(?:[-/,]\d{1,3})*$/.test(String(token).trim());
}

function startsNewCircuit(token, nextToken, previousNumber) {
  if (!isBareCircuitToken(token)) return false;
  if (!nextToken) return false;
  if (looksLikeTrip(nextToken) || looksLikePoles(nextToken)) return false;
  const value = firstCircuitNumber(token);
  if (!Number.isFinite(value) || value < 1 || value > MAX_DIRECTORY_CIRCUIT) return false;
  return previousNumber === null || value > previousNumber;
}

function splitCircuitSegments(line) {
  const tokens = String(line || '').split(/\s+/).filter(Boolean);
  if (!tokens.length || !looksLikeCircuit(tokens[0])) return [];

  const segments = [];
  let current = [tokens[0]];
  let previousNumber = firstCircuitNumber(tokens[0]);

  for (let index = 1; index < tokens.length; index += 1) {
    if (current.length >= 2 && startsNewCircuit(tokens[index], tokens[index + 1], previousNumber)) {
      segments.push(current);
      current = [tokens[index]];
      previousNumber = firstCircuitNumber(tokens[index]);
    } else {
      current.push(tokens[index]);
    }
  }

  segments.push(current);
  return segments;
}

function parseSegmentTokens(tokens) {
  if (!tokens || !tokens.length || !looksLikeCircuit(tokens[0])) return null;
  if (firstCircuitNumber(tokens[0]) > MAX_DIRECTORY_CIRCUIT) return null;

  const row = createEmptyRow();
  row.circuit = normalizeCircuit(tokens[0]);
  const trailing = tokens.slice(1);
  const compactMatch = trailing.length
    ? String(trailing[trailing.length - 1]).match(/^(\d+(?:\.\d+)?)\s*(?:A|AMP|AMPS)?[/\\-]([123])P?$/i)
    : null;

  if (compactMatch) {
    row.trip = `${compactMatch[1]}A`;
    row.poles = compactMatch[2];
    trailing.pop();
  } else {
    if (trailing.length > 1 && looksLikePoles(trailing[trailing.length - 1])) {
      row.poles = String(trailing.pop()).replace(/P/i, '');
    }
    if (trailing.length && looksLikeTrip(trailing[trailing.length - 1]) && (trailing.length > 1 || row.poles)) {
      row.trip = normalizeTrip(trailing.pop());
    }
  }

  row.description = trailing.join(' ').trim();
  row.loadType = inferLoadType(row.description);
  if (!/[A-Za-z]{2,}/.test(row.description) && !(row.trip && row.poles)) return null;
  return row;
}

function parsePairedDirectoryLine(line) {
  const tokens = String(line || '').split(/\s+/).filter(Boolean);
  for (let index = 0; index < tokens.length - 1; index += 1) {
    if (!isBareCircuitToken(tokens[index]) || !isBareCircuitToken(tokens[index + 1])) continue;
    const leftNum = Number(tokens[index]);
    const rightNum = Number(tokens[index + 1]);
    if (leftNum < 1 || rightNum < 1 || leftNum > 84 || rightNum > 84) continue;
    if (Math.abs(rightNum - leftNum) !== 1) continue;
    const left = tokens.slice(0, index).join(' ');
    const right = tokens.slice(index + 2).join(' ');
    if (!/[A-Za-z]{2,}/.test(left) || !/[A-Za-z]{2,}/.test(right)) continue;
    if (looksLikeCircuit(tokens[0])) continue;
    return [
      Object.assign(createEmptyRow(), { circuit: String(leftNum), description: left, loadType: inferLoadType(left) }),
      Object.assign(createEmptyRow(), { circuit: String(rightNum), description: right, loadType: inferLoadType(right) }),
    ];
  }
  return null;
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
  const raw = String(value || '').toUpperCase().replace(/\s+/g, '');
  if (!raw) return '';
  const match = raw.match(/^0*(\d{1,2})([A-Z])?$/);
  if (!match) return raw;
  return String(Number(match[1])) + (match[2] || '');
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
    panelName: findMetadata(lines, [
      /panel\s*(?:name|board)?\s*[:\-]?\s*(.+)/i,
      /^(?:pnl[-\s]+)(.+)$/i,
      /^panel\s+([A-Z0-9][A-Z0-9 \-\/]{1,24})$/i,
    ]),
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

function multiPoleContinuationCircuits(rows, phase) {
  const reserved = Object.create(null);
  const stride = Number(phase) === 1 ? 1 : 2;
  (rows || []).forEach(row => {
    const poles = Math.max(1, Number(row && row.poles) || 1);
    if (poles < 2 || isSpareOrOpen(row)) return;
    const start = firstCircuitNumber(row && row.circuit);
    if (!Number.isFinite(start) || start < 1 || start === Number.MAX_SAFE_INTEGER) return;
    for (let i = 1; i < poles; i += 1) {
      reserved[start + i * stride] = true;
    }
  });
  return reserved;
}

function spareStats(rows, slotCount, phase) {
  const list = Array.isArray(rows) ? rows : [];
  const seeded = Number(slotCount) > 0 && list.length >= Number(slotCount);
  const reserved = seeded ? multiPoleContinuationCircuits(list, phase) : Object.create(null);
  let spare = 0;
  let fromRows = 0;
  list.forEach(row => {
    /* After a full seed, every physical space is already a row. Counting
       poles on top of those rows double-counts a 2-pole breaker. */
    const slots = seeded ? 1 : rowSlotCount(row);
    fromRows += slots;
    const circuit = firstCircuitNumber(row && row.circuit);
    if (seeded && Number.isFinite(circuit) && reserved[circuit]) return;
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
  const phase = Number(opts.phase) === 1 ? 1 : Number(opts.phase) === 3 ? 3 : null;
  const mainAmps = Number(opts.mainAmps);
  const list = Array.isArray(rows) ? rows : [];
  const fromRows = list.reduce((n, row) => n + rowSlotCount(row), 0);
  const slotCount = Number(opts.slotCount) || fromRows;
  const connected = connectedBreakerSum(list);
  const spare = spareStats(list, slotCount, phase);
  const unlabeled = list.filter(isUnlabeled);
  const vague = list.filter(isVague);
  const doubled = list.filter(looksDoubledUp);
  const balance = phase ? phaseBalance(list, phase) : { legs: {}, assumption: 'Select 1-phase or 3-phase before treating leg balance as meaningful. Phase is never assumed.' };
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
  const waiting = scheduleCalcGateMessage('directory');
  if (waiting) {
    elements.directoryGrid.innerHTML = summaryMetric(waiting.metricLabel, waiting.metricValue, waiting.metricDetail);
    elements.directoryGuidance.innerHTML = waiting.guidance;
    return;
  }
  const rows = normalizeRows(state.rows);
  const metrics = computeDirectoryMetrics(rows, {
    phase: selectedPhase(),
    mainAmps: elements.panelCapacityAmps ? elements.panelCapacityAmps.value : '',
    slotCount: Number(state.slotCount) || 0,
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
    summaryMetric('Spare / open slots', `${metrics.spareCount} of ${metrics.spareTotal} (${formatNumber(metrics.sparePct)}%)`, 'Physical spaces in the reviewed table. Multi-pole breakers already occupy following seeded rows.'),
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
  const waiting = scheduleCalcGateMessage('load');
  if (waiting) {
    elements.analysisGrid.innerHTML = summaryMetric(waiting.metricLabel, waiting.metricValue, waiting.metricDetail);
    elements.analysisGuidance.innerHTML = waiting.guidance;
    return;
  }
  const rows = normalizeRows(state.rows).filter(row => row.description || Number(row.loadAmps) > 0);
  const voltage = panelVoltageInfo(elements.panelVoltage.value);
  const phase = selectedPhase();
  if (!phase) {
    elements.analysisGrid.innerHTML = summaryMetric('Waiting for system phase', 'Select 1Ø or 3Ø', 'Load math does not assume 3-phase. Pick the system on the directory card.');
    elements.analysisGuidance.innerHTML = '<p>Phase is never assumed. Choose 1-phase or 3-phase after you read the panel label, then review the table.</p>';
    return;
  }
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
  const pairCount = printPairCount();

  for (let pair = 0; pair < pairCount; pair += 1) {
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

function printedSlotCount(slotCount) {
  return Number(slotCount != null ? slotCount : state.slotCount) || 0;
}

function printSlotCount(rows, slotCount) {
  const printed = printedSlotCount(slotCount);
  const list = rows || state.rows || [];
  const fromRows = maxCircuitIn(list);
  const needed = Math.max(printed, fromRows);
  if (!needed) return 2;
  const even = needed % 2 === 0 ? needed : needed + 1;
  return Math.min(MAX_EDITOR_SLOTS, Math.max(2, even));
}

function printPairCount() {
  return printSlotCount() / 2;
}

function csvCell(value) {
  const Schema = window.BeckifyNameplateSchema;
  if (Schema && typeof Schema.csvCell === 'function') return Schema.csvCell(value);
  let text = value == null ? '' : String(value);
  if (/^[=+\-@]/.test(text)) text = "'" + text;
  if (/[",\n\r]/.test(text)) return '"' + text.replace(/"/g, '""') + '"';
  return text;
}

function buildScheduleExport(rows, meta) {
  meta = meta || {};
  const Schema = window.BeckifyNameplateSchema;
  const draftRows = (rows || []).map(row => ({
    circuit: { value: row.circuit || '' },
    description: { value: row.description || '' },
    trip: { value: tripAmps(row.trip) || null },
    poles: { value: row.poles ? Number(row.poles) : null },
    loadAmps: row.loadAmps != null && row.loadAmps !== ''
      ? (typeof row.loadAmps === 'object' ? row.loadAmps : { value: row.loadAmps })
      : { value: null },
    notes: { value: row.loadAmpsCopiedFromTrip ? 'trip is not a reviewed load' : '' },
  }));
  if (Schema && typeof Schema.exportPanelDraft === 'function') {
    return Schema.exportPanelDraft({
      circuits: draftRows,
      slotCount: printedSlotCount(meta.slotCount != null ? meta.slotCount : state.slotCount),
      panel: {
        name: meta.panelName || (elements.panelName && elements.panelName.value),
        voltage: meta.voltage || (elements.panelVoltage && elements.panelVoltage.value),
        phases: meta.phase != null ? meta.phase : selectedPhase(),
      },
    }, { source: state.source || meta.source || '' });
  }
  const lines = ['circuit,description,trip,poles,loadAmps,notes'];
  let clearedLoad = false;
  (rows || []).forEach(row => {
    const loadCell = row && row.loadAmps;
    const loadVal = loadCell && typeof loadCell === 'object' ? loadCell.value : loadCell;
    if (loadVal != null && loadVal !== '') clearedLoad = true;
    lines.push([
      csvCell(normalizeCircuit(row.circuit)),
      csvCell(row.description || ''),
      csvCell(row.trip || ''),
      csvCell(row.poles || ''),
      csvCell(''),
      csvCell(row.loadAmpsCopiedFromTrip ? 'trip is not a reviewed load' : ''),
    ].join(','));
  });
  const warnings = [];
  if (!selectedPhase() && meta.phase == null) {
    warnings.push('Phase is unknown. Load math stays gated until 1 or 3 is selected.');
  } else if (meta.phase != null && Number(meta.phase) !== 1 && Number(meta.phase) !== 3) {
    warnings.push('Phase is unknown. Load math stays gated until 1 or 3 is selected.');
  }
  if (clearedLoad) warnings.push('loadAmps was cleared — trip is not a reviewed load.');
  return {
    csv: lines.join('\n'),
    slotCount: printedSlotCount(meta.slotCount != null ? meta.slotCount : state.slotCount),
    source: state.source || '',
    phase: selectedPhase() || (Number(meta.phase) === 1 || Number(meta.phase) === 3 ? Number(meta.phase) : null),
    warnings: warnings,
    rowCount: (rows || []).length,
  };
}

function buildCircuitSlots(rows) {
  const normalized = normalizeRows(rows);
  const slots = {};
  const overflow = [];
  const limit = printSlotCount(normalized);

  normalized.forEach(row => {
    const slot = firstCircuitNumber(row.circuit);
    if (slot >= 1 && slot <= limit && !slots[slot]) {
      slots[slot] = row;
    } else {
      overflow.push(row);
    }
  });

  overflow.forEach(row => {
    for (let slot = 1; slot <= limit; slot += 1) {
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
  const safeCount = Math.max(1, Math.min(MAX_EDITOR_SLOTS, Number(count) || MAX_CIRCUIT_SLOTS));
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
  revokeShotUrls();

  state.file = null;
  state.files = [];
  state.rawText = '';
  state.slotCount = 0;
  seedRows(MAX_CIRCUIT_SLOTS);
  if (elements.rawText) elements.rawText.value = '';
  elements.panelName.value = '';
  elements.panelVoltage.value = '';
  elements.panelFeed.value = '';
  elements.panelDate.value = '';
  if (elements.panelPhase) elements.panelPhase.value = '';
  if (elements.mergeRows) elements.mergeRows.checked = false;
  setSource('');
  elements.panelCapacityAmps.value = '';
  elements.panelDiversity.value = '1';
  refreshIntakeUi();
  clearReview();
  if (elements.openPanelCaution) elements.openPanelCaution.hidden = true;
  resetProgress();
  setStatus('Reset complete. Add a schedule photo and a breaker photo — take or upload each — or type rows by hand.');
  renderAll();
}

function handleParseText() {
  clearReview();
  parseAndApplyText(elements.rawText.value, false, { merge: !!(elements.mergeRows && elements.mergeRows.checked) });
}

function updateProgress(value, statusMessage) {
  const next = Math.max(state.lastProgress || 0, Math.max(0, Math.min(1, Number(value) || 0)));
  state.lastProgress = next;
  const percent = Math.round(next * 100);
  if (elements.progressFill) elements.progressFill.style.width = `${percent}%`;
  if (elements.progressLabel) elements.progressLabel.textContent = `${percent}%`;
  if (statusMessage) {
    setStatus(statusMessage);
  }
}

function resetProgress() {
  state.lastProgress = 0;
  if (elements.progressFill) elements.progressFill.style.width = '0%';
  if (elements.progressLabel) elements.progressLabel.textContent = '0%';
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

function handleCopyCsv() {
  if (!isScheduleReviewed()) {
    setStatus('Check “I reviewed every circuit row” before exporting. OCR is a draft, not a finished schedule.');
    return;
  }
  const exported = buildScheduleExport(state.rows, { slotCount: printedSlotCount() });
  const text = exported.csv;
  const done = function () {
    const extra = exported.warnings && exported.warnings.length ? ' ' + exported.warnings.join(' ') : '';
    const sizeBit = exported.slotCount
      ? ' (' + exported.slotCount + ' spaces)'
      : ' (panel size was not printed)';
    setStatus('Copied ' + exported.rowCount + ' circuit row' + (exported.rowCount === 1 ? '' : 's')
      + ' as CSV' + sizeBit + '. Load amps were left blank — trip is not a reviewed load.' + extra);
  };
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).then(done, function () {
      setStatus('Could not copy CSV. Print the reviewed schedule instead.');
    });
    return;
  }
  setStatus('Clipboard is unavailable in this browser. Print the reviewed schedule instead.');
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
    parsePairedDirectoryLine,
    splitCircuitSegments,
    parseSegmentTokens,
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
    isCalcReady,
    requestCalculate,
    snapSlotCount,
    parseBreakerFace,
    sizeTableToSlots,
    applyCombinedRead,
    hasView,
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
    computeDirectoryMetrics,
    mergeCircuitRows,
    tableHasUserContent,
    selectedPhase,
    canAddPanelShot,
    describeShotRole,
    printSlotCount,
    printedSlotCount,
    getPrintedSlotCount: printedSlotCount,
    buildScheduleExport,
    MAX_SHOTS_PER_VIEW,
    MAX_SHOTS_TOTAL
  };
}
