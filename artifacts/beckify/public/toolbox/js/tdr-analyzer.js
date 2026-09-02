/*
 * Megger TDR Trace Analyzer
 * OCRs a TDR500 screen through the API server, then lets the technician
 * override VF and range while fault distances recalculate live.
 */

'use strict';

const TDR_DEFAULT_VF = 0.66;
const TDR_MIN_VF = 0.20;
const TDR_MAX_VF = 0.99;
const TDR_DEFAULT_RANGE = 1000;
const TDR_DEFAULT_IMPEDANCE = 75;
const TDR_SPEED_FT_PER_NS = 0.983571056;

const tdrState = {
  file: null,
  imageUrl: '',
  analysis: null,
  busy: false,
  currentVf: TDR_DEFAULT_VF,
  currentRangeFt: TDR_DEFAULT_RANGE,
  currentImpedanceOhm: TDR_DEFAULT_IMPEDANCE,
  detectedVf: TDR_DEFAULT_VF,
  detectedRangeFt: TDR_DEFAULT_RANGE,
  detectedImpedanceOhm: TDR_DEFAULT_IMPEDANCE,
};

const tdrEl = {};

function tdrNum(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function tdrClamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function tdrFormat(value, digits = 2) {
  if (!Number.isFinite(value)) return '—';
  return Number(value).toFixed(digits).replace(/\.00$/, '').replace(/(\.\d*[1-9])0+$/, '$1');
}

function tdrDistanceFormat(value, unit) {
  if (!Number.isFinite(value)) return '—';
  const digits = Math.abs(value) >= 100 ? 1 : 2;
  return `${tdrFormat(value, digits)} ${unit}`;
}

function tdrSpeedDistanceForVf(vf, timeNs) {
  return 0.5 * vf * TDR_SPEED_FT_PER_NS * timeNs;
}

function tdrFileToDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ''));
    reader.onerror = () => reject(reader.error || new Error('Could not read the image file.'));
    reader.readAsDataURL(file);
  });
}

function tdrApiUrl(path) {
  const configured = document.querySelector('meta[name="beckify-api-base-url"]')?.getAttribute('content')
    || window.BECKIFY_API_BASE_URL
    || '';
  const suffix = path.charAt(0) === '/' ? path : `/${path}`;
  const base = String(configured).trim().replace(/\/$/, '');
  if (!base) return suffix;
  try {
    const u = new URL(base);
    if (u.protocol !== 'https:') return suffix;
    return `${u.origin}${u.pathname.replace(/\/$/, '')}${suffix}`;
  } catch (_) {
    return suffix;
  }
}

function tdrResetProgress() {
  if (tdrEl.progressFill) tdrEl.progressFill.style.width = '0%';
  if (tdrEl.progressLabel) tdrEl.progressLabel.textContent = '0%';
}

function tdrSetProgress(value, label) {
  const pct = tdrClamp(Math.round(value), 0, 100);
  if (tdrEl.progressFill) tdrEl.progressFill.style.width = `${pct}%`;
  if (tdrEl.progressLabel) tdrEl.progressLabel.textContent = `${pct}%`;
  if (label) tdrSetStatus(label);
}

function tdrSetStatus(message) {
  if (tdrEl.status) tdrEl.status.textContent = message;
}

function tdrSetBusy(isBusy) {
  tdrState.busy = isBusy;
  if (tdrEl.analyzeBtn) tdrEl.analyzeBtn.disabled = isBusy || !tdrState.file;
  if (tdrEl.browseBtn) tdrEl.browseBtn.disabled = isBusy;
  if (tdrEl.resetBtn) tdrEl.resetBtn.disabled = isBusy;
}

function tdrUpdatePreview() {
  if (tdrEl.previewFrame) tdrEl.previewFrame.classList.toggle('has-image', Boolean(tdrState.imageUrl));
  if (tdrEl.previewImage) {
    if (tdrState.imageUrl) {
      tdrEl.previewImage.src = tdrState.imageUrl;
    } else {
      tdrEl.previewImage.removeAttribute('src');
    }
  }
  if (tdrEl.previewPlaceholder) {
    tdrEl.previewPlaceholder.style.display = tdrState.imageUrl ? 'none' : '';
  }
  if (tdrEl.fileName) {
    tdrEl.fileName.textContent = tdrState.file ? tdrState.file.name : 'No file selected';
  }
}

function tdrSyncControlReadouts() {
  if (tdrEl.vfSlider) tdrEl.vfSlider.value = String(tdrState.currentVf.toFixed(2));
  if (tdrEl.vfValue) tdrEl.vfValue.value = String(tdrState.currentVf.toFixed(2));
  if (tdrEl.rangeFt) tdrEl.rangeFt.value = String(Math.round(tdrState.currentRangeFt));
  if (tdrEl.impedanceOhm) tdrEl.impedanceOhm.value = String(Math.round(tdrState.currentImpedanceOhm));
}

function tdrScaleFactor() {
  const vfRatio = tdrState.detectedVf > 0 ? tdrState.currentVf / tdrState.detectedVf : 1;
  const rangeRatio = tdrState.detectedRangeFt > 0 ? tdrState.currentRangeFt / tdrState.detectedRangeFt : 1;
  return vfRatio * rangeRatio;
}

function tdrScaledDistance(event) {
  const factor = tdrScaleFactor();
  if (Number.isFinite(event.distance_ft)) {
    const ft = event.distance_ft * factor;
    return {
      ft,
      m: Number.isFinite(event.distance_m) ? event.distance_m * factor : ft * 0.3048,
    };
  }
  if (Number.isFinite(event.range_fraction)) {
    const ft = tdrState.currentRangeFt * event.range_fraction * factor;
    return { ft, m: ft * 0.3048 };
  }
  return { ft: NaN, m: NaN };
}

function tdrPulseClass(polarity) {
  if (polarity === 'positive') return 'up';
  if (polarity === 'negative') return 'down';
  return 'unknown';
}

function tdrPulseLabel(polarity) {
  if (polarity === 'positive') return 'Up / Open';
  if (polarity === 'negative') return 'Down / Short';
  return 'Unknown';
}

function tdrBuildEventCard(event, index) {
  const { ft, m } = tdrScaledDistance(event);
  const card = document.createElement('article');
  card.className = 'tdr-event-card';

  const head = document.createElement('div');
  head.className = 'tdr-event-head';

  const titleWrap = document.createElement('div');
  const title = document.createElement('div');
  title.style.fontWeight = '700';
  title.textContent = event.label || `Reflection ${index + 1}`;
  const meta = document.createElement('div');
  meta.style.fontSize = '0.82rem';
  meta.style.color = 'var(--fg-muted)';
  meta.textContent = event.faultType || 'fault event';
  titleWrap.appendChild(title);
  titleWrap.appendChild(meta);

  const pill = document.createElement('span');
  pill.className = `tdr-pill ${tdrPulseClass(event.polarity)}`;
  pill.textContent = tdrPulseLabel(event.polarity);

  head.appendChild(titleWrap);
  head.appendChild(pill);
  card.appendChild(head);

  const grid = document.createElement('div');
  grid.className = 'meta-grid';
  grid.style.marginTop = '12px';

  const rows = [
    ['Distance', `${tdrDistanceFormat(ft, 'ft')} / ${tdrDistanceFormat(m, 'm')}`],
    ['Confidence', `${tdrFormat((event.confidence ?? 0) * 100, 0)}%`],
    ['Range Fraction', Number.isFinite(event.range_fraction) ? `${tdrFormat(event.range_fraction * 100, 1)}% of span` : '—'],
    ['Action', event.recommendation || 'Inspect the nearest termination and splice.'],
  ];

  rows.forEach(([label, value]) => {
    const block = document.createElement('div');
    block.className = 'field-block';
    const labelEl = document.createElement('span');
    labelEl.textContent = label;
    const valueEl = document.createElement('div');
    valueEl.textContent = value;
    valueEl.style.fontSize = '0.92rem';
    valueEl.style.color = 'var(--fg)';
    block.appendChild(labelEl);
    block.appendChild(valueEl);
    grid.appendChild(block);
  });

  card.appendChild(grid);
  return card;
}

function tdrRenderWarnings(warnings) {
  if (!tdrEl.warningsHost) return;
  tdrEl.warningsHost.textContent = '';
  if (!warnings.length) {
    tdrEl.warningsHost.style.display = 'none';
    return;
  }
  tdrEl.warningsHost.style.display = '';
  const list = document.createElement('ul');
  list.style.margin = '0';
  list.style.paddingLeft = '18px';
  list.style.color = 'var(--fg-muted)';
  warnings.forEach((warning) => {
    const li = document.createElement('li');
    li.textContent = warning;
    list.appendChild(li);
  });
  tdrEl.warningsHost.appendChild(list);
}

function tdrRenderResults() {
  if (!tdrEl.resultsHost) return;
  tdrEl.resultsHost.textContent = '';

  if (!tdrState.analysis) {
    const empty = document.createElement('p');
    empty.className = 'note';
    empty.textContent = 'Upload a Megger TDR500 screen and run the analyzer to populate reflection cards.';
    tdrEl.resultsHost.appendChild(empty);
    return;
  }

  const analysis = tdrState.analysis;
  const summary = document.createElement('div');
  summary.className = 'formula-box';
  summary.innerHTML = [
    `<strong>Summary:</strong> ${escapeHtml(analysis.summary || 'No summary returned.')}`,
    `<strong>Detected VF:</strong> ${tdrFormat(analysis.screen?.vf ?? tdrState.currentVf, 2)}`,
    `<strong>Range:</strong> ${tdrFormat(analysis.screen?.range?.value ?? tdrState.currentRangeFt, 0)} ${escapeHtml(analysis.screen?.range?.unit || 'ft')}`,
    `<strong>Impedance:</strong> ${tdrFormat(analysis.screen?.impedance?.value ?? tdrState.currentImpedanceOhm, 0)} ${escapeHtml(analysis.screen?.impedance?.unit || 'Ω')}`,
    `<strong>Scale factor:</strong> ${tdrFormat(tdrScaleFactor(), 3)}×`,
  ].join('<br>');
  tdrEl.resultsHost.appendChild(summary);

  const raw = document.createElement('details');
  raw.className = 'section-info';
  raw.style.marginTop = '12px';
  const rawSummary = document.createElement('summary');
  rawSummary.textContent = 'Raw OCR text';
  const rawBody = document.createElement('div');
  rawBody.className = 'section-info-body';
  rawBody.style.whiteSpace = 'pre-wrap';
  rawBody.textContent = analysis.raw_ocr || 'No raw OCR text returned.';
  raw.appendChild(rawSummary);
  raw.appendChild(rawBody);
  tdrEl.resultsHost.appendChild(raw);

  if (!analysis.events.length) {
    const empty = document.createElement('p');
    empty.className = 'note';
    empty.style.marginTop = '12px';
    empty.textContent = 'No clear reflections were identified in the screenshot.';
    tdrEl.resultsHost.appendChild(empty);
    return;
  }

  const eventsWrap = document.createElement('div');
  eventsWrap.style.display = 'grid';
  eventsWrap.style.gap = '12px';
  eventsWrap.style.marginTop = '12px';
  analysis.events.forEach((event, index) => {
    eventsWrap.appendChild(tdrBuildEventCard(event, index));
  });
  tdrEl.resultsHost.appendChild(eventsWrap);
}

function tdrRenderReadouts() {
  if (!tdrEl.detectedReadout) return;

  const baseRange = tdrState.detectedRangeFt || tdrState.currentRangeFt || TDR_DEFAULT_RANGE;
  const factor = tdrScaleFactor();
  tdrEl.detectedReadout.innerHTML = [
    `<strong>Detected settings:</strong>`,
    `VF ${tdrFormat(tdrState.detectedVf, 2)} | Range ${tdrFormat(baseRange, 0)} ft | Impedance ${tdrFormat(tdrState.detectedImpedanceOhm, 0)} Ω`,
    `Current VF ${tdrFormat(tdrState.currentVf, 2)} | Current Range ${tdrFormat(tdrState.currentRangeFt, 0)} ft | Current Impedance ${tdrFormat(tdrState.currentImpedanceOhm, 0)} Ω`,
    `Distance scale ${tdrFormat(factor, 3)}×`,
  ].join('<br>');
}

function tdrRenderEverything() {
  tdrSyncControlReadouts();
  tdrRenderReadouts();
  tdrRenderWarnings(tdrState.analysis?.warnings || []);
  tdrRenderResults();
  if (tdrEl.analyzeBtn) tdrEl.analyzeBtn.disabled = tdrState.busy || !tdrState.file;
  if (tdrEl.resetBtn) tdrEl.resetBtn.disabled = tdrState.busy && !tdrState.file;
}

function tdrApplyAnalysis(payload) {
  tdrState.analysis = payload.analysis || null;
  const screen = tdrState.analysis?.screen || {};
  tdrState.detectedVf = tdrClamp(tdrNum(screen.vf, tdrState.currentVf), TDR_MIN_VF, TDR_MAX_VF);
  tdrState.detectedRangeFt = Math.max(1, tdrNum(screen.range?.value, tdrState.currentRangeFt));
  tdrState.detectedImpedanceOhm = Math.max(1, tdrNum(screen.impedance?.value, tdrState.currentImpedanceOhm));
  tdrState.currentVf = tdrState.detectedVf;
  tdrState.currentRangeFt = tdrState.detectedRangeFt;
  tdrState.currentImpedanceOhm = tdrState.detectedImpedanceOhm;
  tdrSetStatus('Analysis complete. Review the fault cards and tweak VF if the cable spec differs.');
  if (typeof window.showToast === 'function') window.showToast('TDR analysis complete');
  tdrRenderEverything();
}

async function tdrRunAnalysis() {
  if (!tdrState.file || tdrState.busy) return;
  tdrSetBusy(true);
  tdrSetProgress(18, 'Reading image…');

  try {
    const dataUrl = await tdrFileToDataUrl(tdrState.file);
    tdrSetProgress(42, 'Sending to vision model…');
    const response = await fetch(tdrApiUrl('/api/analyze-tdr'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        imageBase64: dataUrl,
        mimeType: tdrState.file.type || 'image/jpeg',
      }),
    });

    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(payload.error || `Analyzer request failed with HTTP ${response.status}.`);
    }

    tdrSetProgress(88, 'Rendering fault cards…');
    tdrApplyAnalysis(payload);
    tdrSetProgress(100, 'Done.');
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown analyzer error';
    tdrSetStatus(message);
    if (typeof window.showToast === 'function') window.showToast(message);
    tdrSetProgress(0, 'Analysis failed');
  } finally {
    tdrSetBusy(false);
  }
}

function tdrHandleFile(file) {
  if (!file) return;
  if (!file.type || !file.type.startsWith('image/')) {
    tdrSetStatus('Please choose a valid image file.');
    return;
  }
  if (file.size > 12 * 1024 * 1024) {
    tdrSetStatus('Please choose an image smaller than 12 MB.');
    return;
  }

  if (tdrState.imageUrl) URL.revokeObjectURL(tdrState.imageUrl);
  tdrState.file = file;
  tdrState.imageUrl = URL.createObjectURL(file);
  tdrState.analysis = null;
  tdrState.detectedVf = tdrState.currentVf;
  tdrState.detectedRangeFt = tdrState.currentRangeFt;
  tdrState.detectedImpedanceOhm = tdrState.currentImpedanceOhm;
  tdrUpdatePreview();
  tdrSetStatus('Image loaded. Press Analyze Trace to OCR the screen.');
  tdrResetProgress();
  tdrRenderEverything();
}

function tdrReset() {
  if (tdrState.imageUrl) URL.revokeObjectURL(tdrState.imageUrl);
  tdrState.file = null;
  tdrState.imageUrl = '';
  tdrState.analysis = null;
  tdrState.currentVf = TDR_DEFAULT_VF;
  tdrState.currentRangeFt = TDR_DEFAULT_RANGE;
  tdrState.currentImpedanceOhm = TDR_DEFAULT_IMPEDANCE;
  tdrState.detectedVf = TDR_DEFAULT_VF;
  tdrState.detectedRangeFt = TDR_DEFAULT_RANGE;
  tdrState.detectedImpedanceOhm = TDR_DEFAULT_IMPEDANCE;
  if (tdrEl.fileInput) tdrEl.fileInput.value = '';
  tdrUpdatePreview();
  tdrSetStatus('Ready for a TDR image.');
  tdrResetProgress();
  tdrRenderEverything();
}

function tdrBindEvents() {
  if (tdrEl.browseBtn && tdrEl.fileInput) {
    tdrEl.browseBtn.addEventListener('click', () => tdrEl.fileInput.click());
  }
  if (tdrEl.fileInput) {
    tdrEl.fileInput.addEventListener('change', (event) => {
      const [file] = event.target.files || [];
      tdrHandleFile(file);
    });
  }
  if (tdrEl.dropZone) {
    ['dragenter', 'dragover'].forEach((eventName) => {
      tdrEl.dropZone.addEventListener(eventName, (event) => {
        event.preventDefault();
        tdrEl.dropZone.classList.add('is-dragover');
      });
    });
    ['dragleave', 'drop'].forEach((eventName) => {
      tdrEl.dropZone.addEventListener(eventName, (event) => {
        event.preventDefault();
        tdrEl.dropZone.classList.remove('is-dragover');
      });
    });
    tdrEl.dropZone.addEventListener('drop', (event) => {
      const [file] = event.dataTransfer?.files || [];
      tdrHandleFile(file);
    });
  }

  const syncVf = (raw) => {
    const vf = tdrClamp(tdrNum(raw, tdrState.currentVf), TDR_MIN_VF, TDR_MAX_VF);
    tdrState.currentVf = vf;
    tdrRenderEverything();
  };
  const syncRange = (raw) => {
    tdrState.currentRangeFt = Math.max(1, tdrNum(raw, tdrState.currentRangeFt));
    tdrRenderEverything();
  };
  const syncImpedance = (raw) => {
    tdrState.currentImpedanceOhm = Math.max(1, tdrNum(raw, tdrState.currentImpedanceOhm));
    tdrRenderEverything();
  };

  if (tdrEl.vfSlider) {
    tdrEl.vfSlider.addEventListener('input', (event) => syncVf(event.target.value));
  }
  if (tdrEl.vfValue) {
    tdrEl.vfValue.addEventListener('input', (event) => syncVf(event.target.value));
  }
  if (tdrEl.rangeFt) {
    tdrEl.rangeFt.addEventListener('input', (event) => syncRange(event.target.value));
  }
  if (tdrEl.impedanceOhm) {
    tdrEl.impedanceOhm.addEventListener('input', (event) => syncImpedance(event.target.value));
  }
  if (tdrEl.analyzeBtn) {
    tdrEl.analyzeBtn.addEventListener('click', tdrRunAnalysis);
  }
  if (tdrEl.resetBtn) {
    tdrEl.resetBtn.addEventListener('click', tdrReset);
  }
}

function tdrCacheElements() {
  tdrEl.dropZone = document.getElementById('tdr-drop-zone');
  tdrEl.fileInput = document.getElementById('tdr-file-input');
  tdrEl.browseBtn = document.getElementById('tdr-browse-btn');
  tdrEl.analyzeBtn = document.getElementById('tdr-analyze-btn');
  tdrEl.resetBtn = document.getElementById('tdr-reset-btn');
  tdrEl.previewFrame = document.getElementById('tdr-preview-frame');
  tdrEl.previewImage = document.getElementById('tdr-preview-image');
  tdrEl.previewPlaceholder = document.getElementById('tdr-preview-placeholder');
  tdrEl.fileName = document.getElementById('tdr-file-name');
  tdrEl.status = document.getElementById('tdr-status');
  tdrEl.progressFill = document.getElementById('tdr-progress-fill');
  tdrEl.progressLabel = document.getElementById('tdr-progress-label');
  tdrEl.vfSlider = document.getElementById('tdr-vf-slider');
  tdrEl.vfValue = document.getElementById('tdr-vf-value');
  tdrEl.rangeFt = document.getElementById('tdr-range-ft');
  tdrEl.impedanceOhm = document.getElementById('tdr-impedance-ohm');
  tdrEl.detectedReadout = document.getElementById('tdr-detected-readout');
  tdrEl.warningsHost = document.getElementById('tdr-warnings-host');
  tdrEl.resultsHost = document.getElementById('tdr-events-host');
}

function tdrBoot() {
  tdrCacheElements();
  if (!tdrEl.dropZone) return;
  tdrBindEvents();
  tdrSetStatus('Ready for a TDR image.');
  tdrResetProgress();
  tdrRenderEverything();
  if (typeof window.registerUrlState === 'function') {
    window.registerUrlState('sec-tdr', 'tdr', function () {
      if (typeof window.calcTdrAnalyzer === 'function') window.calcTdrAnalyzer();
    });
  }
}

function tdrUpdateFromUrl() {
  tdrRenderEverything();
}

window.calcTdrAnalyzer = tdrUpdateFromUrl;

document.addEventListener('DOMContentLoaded', tdrBoot);
