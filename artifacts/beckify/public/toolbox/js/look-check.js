/*
 * Look Check — playful good / bad photo verdict.
 * Cloud-only. Choosing a file does not upload it; Analyze Look does.
 * Entertainment only. Not medical or dating advice.
 */

'use strict';

const LOOK_MAX_BYTES = 12 * 1024 * 1024;

const lookState = {
  file: null,
  imageUrl: '',
  draft: null,
  busy: false,
};

const lookEl = {};

function lookApiUrl(path) {
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

function lookSetStatus(message) {
  if (lookEl.status) lookEl.status.textContent = message;
}

function lookSetProgress(value, label) {
  const pct = Math.max(0, Math.min(100, Math.round(value)));
  if (lookEl.progressFill) lookEl.progressFill.style.width = `${pct}%`;
  if (lookEl.progressLabel) lookEl.progressLabel.textContent = `${pct}%`;
  if (label) lookSetStatus(label);
}

function lookResetProgress() {
  lookSetProgress(0);
}

function lookSetBusy(isBusy) {
  lookState.busy = isBusy;
  if (lookEl.analyzeBtn) lookEl.analyzeBtn.disabled = isBusy || !lookState.file;
  if (lookEl.browseBtn) lookEl.browseBtn.disabled = isBusy;
  if (lookEl.resetBtn) lookEl.resetBtn.disabled = isBusy;
}

function lookUpdatePreview() {
  if (lookEl.previewFrame) lookEl.previewFrame.classList.toggle('has-image', Boolean(lookState.imageUrl));
  if (lookEl.previewImage) {
    if (lookState.imageUrl) lookEl.previewImage.src = lookState.imageUrl;
    else lookEl.previewImage.removeAttribute('src');
  }
  if (lookEl.previewPlaceholder) {
    lookEl.previewPlaceholder.style.display = lookState.imageUrl ? 'none' : '';
  }
  if (lookEl.fileName) {
    lookEl.fileName.textContent = lookState.file ? lookState.file.name : 'No file selected';
  }
}

function lookBadge(verdict) {
  if (verdict === 'looks_good') return 'Looks good';
  if (verdict === 'looks_bad') return 'Looks off';
  if (verdict === 'no_person') return 'No person';
  if (verdict === 'declined') return 'Not rated';
  return 'Mixed';
}

function lookDefaultHeadline(verdict) {
  if (verdict === 'looks_good') return 'You look good in this frame.';
  if (verdict === 'looks_bad') return 'This is not your strongest photo.';
  if (verdict === 'no_person') return 'Nobody is in this shot — rating the photo instead.';
  if (verdict === 'declined') return 'This photo cannot be rated.';
  return 'Some things work. Some things to retake.';
}

function lookFillList(host, items, emptyText) {
  if (!host) return;
  host.replaceChildren();
  const rows = Array.isArray(items) ? items.filter((item) => String(item || '').trim()) : [];
  if (!rows.length) {
    const li = document.createElement('li');
    li.textContent = emptyText;
    host.appendChild(li);
    return;
  }
  rows.forEach((item) => {
    const li = document.createElement('li');
    li.textContent = String(item);
    host.appendChild(li);
  });
}

function lookRenderDraft(draft) {
  lookState.draft = draft;
  if (!lookEl.verdictCard || !draft) {
    if (lookEl.verdictCard) lookEl.verdictCard.hidden = true;
    return;
  }
  lookEl.verdictCard.hidden = false;
  lookEl.verdictCard.dataset.verdict = draft.verdict;
  if (lookEl.badge) lookEl.badge.textContent = lookBadge(draft.verdict);
  if (lookEl.headline) lookEl.headline.textContent = draft.headline || lookDefaultHeadline(draft.verdict);
  const showScore = draft.verdict !== 'declined' && draft.score != null;
  if (lookEl.scoreWrap) lookEl.scoreWrap.hidden = !showScore;
  if (lookEl.score) lookEl.score.textContent = showScore ? String(draft.score) : '—';
  lookFillList(lookEl.reasons, draft.reasons, 'No specific notes.');
  lookFillList(lookEl.fixes, draft.fixes, draft.verdict === 'declined' ? 'No retake tips for this photo.' : 'No retake tips.');
  lookFillList(lookEl.photoNotes, draft.photoNotes, 'No photo notes.');
  lookFillList(lookEl.warnings, draft.warnings, '');
  if (lookEl.warningsHost) {
    lookEl.warningsHost.hidden = !(draft.warnings && draft.warnings.length);
  }
}

function lookSyncSettings() {
  const Vlm = window.BeckifyVlmOcr;
  if (!Vlm) return;
  if (lookEl.endpoint && !lookEl.endpoint.dataset.hydrated) {
    const saved = Vlm.loadSettings();
    if (saved.endpoint) lookEl.endpoint.value = saved.endpoint;
    if (saved.token && lookEl.token) lookEl.token.value = saved.token;
    lookEl.endpoint.dataset.hydrated = '1';
  }
  if (lookEl.endpoint) Vlm.saveSettings({ endpoint: lookEl.endpoint.value });
  if (lookEl.token) Vlm.saveSettings({ token: lookEl.token.value });
  if (!lookEl.configNote) return;
  const cfg = Vlm.resolveConfig(true);
  if (cfg.mode === 'custom') {
    lookEl.configNote.textContent = 'Custom HTTPS endpoint will receive the photo when you click Analyze Look.';
  } else if (cfg.mode === 'proxy') {
    lookEl.configNote.textContent = 'Beckify proxy (' + cfg.proxyUrl + '/api/analyze-look) will receive the photo when you click Analyze Look.';
  } else {
    lookEl.configNote.textContent = 'No custom URL yet. Analyze Look uses the Beckify API on this site when available.';
  }
}

async function lookFileToDataUrl(file) {
  const Vlm = window.BeckifyVlmOcr;
  if (Vlm && typeof Vlm.prepareUploadDataUrl === 'function') {
    return Vlm.prepareUploadDataUrl(file);
  }
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ''));
    reader.onerror = () => reject(reader.error || new Error('Could not read the image file.'));
    reader.readAsDataURL(file);
  });
}

async function lookRunSameOrigin(file) {
  const dataUrl = await lookFileToDataUrl(file);
  const mimeType = String(dataUrl).indexOf('data:image/png') === 0
    ? 'image/png'
    : (file.type || 'image/jpeg');
  const response = await fetch(lookApiUrl('/api/analyze-look'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      imageBase64: dataUrl,
      mimeType,
      task: 'look',
    }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload.error || `Look check failed with HTTP ${response.status}.`);
  }
  const Vlm = window.BeckifyVlmOcr;
  const raw = payload.analysis || payload.draft || payload;
  return Vlm && typeof Vlm.normalizeLookDraft === 'function'
    ? Vlm.normalizeLookDraft(raw)
    : raw;
}

async function lookRunAnalysis() {
  if (!lookState.file || lookState.busy) return;
  lookSetBusy(true);
  lookSetProgress(16, 'Preparing photo…');
  try {
    const Vlm = window.BeckifyVlmOcr;
    lookSyncSettings();
    let draft;
    if (Vlm && typeof Vlm.shouldUpload === 'function' && Vlm.shouldUpload(true) && typeof Vlm.analyzeLook === 'function') {
      const result = await Vlm.analyzeLook(lookState.file, {
        enhanceOn: true,
        onProgress: function (frac, label) {
          lookSetProgress(Math.round(18 + frac * 70), label);
        },
      });
      draft = result.draft;
    } else {
      lookSetProgress(42, 'Sending upright photo for a look check…');
      draft = await lookRunSameOrigin(lookState.file);
    }
    lookSetProgress(92, 'Reading the verdict…');
    lookRenderDraft(draft);
    lookSetProgress(100, 'Done. Entertainment only — not a beauty contest.');
    if (typeof window.showToast === 'function') window.showToast('Look check complete');
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown look-check error';
    lookSetStatus(message);
    if (typeof window.showToast === 'function') window.showToast(message);
    lookSetProgress(0, 'Look check failed');
  } finally {
    lookSetBusy(false);
  }
}

function lookHandleFile(file) {
  if (!file) return;
  if (!file.type || !file.type.startsWith('image/')) {
    lookSetStatus('Please choose a valid image file.');
    return;
  }
  if (file.size > LOOK_MAX_BYTES) {
    lookSetStatus('Please choose an image smaller than 12 MB.');
    return;
  }
  if (lookState.imageUrl) URL.revokeObjectURL(lookState.imageUrl);
  lookState.file = file;
  lookState.imageUrl = URL.createObjectURL(file);
  lookState.draft = null;
  lookRenderDraft(null);
  lookUpdatePreview();
  lookResetProgress();
  lookSetStatus('Photo is on this device only. Analyze Look uploads it. Choosing a file does not.');
  if (lookEl.analyzeBtn) lookEl.analyzeBtn.disabled = false;
}

function lookReset() {
  if (lookState.imageUrl) URL.revokeObjectURL(lookState.imageUrl);
  lookState.file = null;
  lookState.imageUrl = '';
  lookState.draft = null;
  if (lookEl.fileInput) lookEl.fileInput.value = '';
  lookRenderDraft(null);
  lookUpdatePreview();
  lookResetProgress();
  lookSetStatus('Ready for a photo. Choosing a file does not upload it.');
  if (lookEl.analyzeBtn) lookEl.analyzeBtn.disabled = true;
}

function lookBindEvents() {
  if (lookEl.browseBtn && lookEl.fileInput) {
    lookEl.browseBtn.addEventListener('click', () => lookEl.fileInput.click());
  }
  if (lookEl.fileInput) {
    lookEl.fileInput.addEventListener('change', (event) => {
      const [file] = event.target.files || [];
      lookHandleFile(file);
    });
  }
  if (lookEl.dropZone) {
    ['dragenter', 'dragover'].forEach((eventName) => {
      lookEl.dropZone.addEventListener(eventName, (event) => {
        event.preventDefault();
        lookEl.dropZone.classList.add('is-dragover');
      });
    });
    ['dragleave', 'drop'].forEach((eventName) => {
      lookEl.dropZone.addEventListener(eventName, (event) => {
        event.preventDefault();
        lookEl.dropZone.classList.remove('is-dragover');
      });
    });
    lookEl.dropZone.addEventListener('drop', (event) => {
      const [file] = event.dataTransfer?.files || [];
      lookHandleFile(file);
    });
    lookEl.dropZone.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        lookEl.fileInput && lookEl.fileInput.click();
      }
    });
  }
  if (lookEl.analyzeBtn) lookEl.analyzeBtn.addEventListener('click', lookRunAnalysis);
  if (lookEl.resetBtn) lookEl.resetBtn.addEventListener('click', lookReset);
  if (lookEl.endpoint) lookEl.endpoint.addEventListener('change', lookSyncSettings);
  if (lookEl.token) lookEl.token.addEventListener('change', lookSyncSettings);
}

function lookCacheElements() {
  lookEl.dropZone = document.getElementById('look-drop-zone');
  lookEl.fileInput = document.getElementById('look-file-input');
  lookEl.browseBtn = document.getElementById('look-browse-btn');
  lookEl.analyzeBtn = document.getElementById('look-analyze-btn');
  lookEl.resetBtn = document.getElementById('look-reset-btn');
  lookEl.previewFrame = document.getElementById('look-preview-frame');
  lookEl.previewImage = document.getElementById('look-preview-image');
  lookEl.previewPlaceholder = document.getElementById('look-preview-placeholder');
  lookEl.fileName = document.getElementById('look-file-name');
  lookEl.status = document.getElementById('look-status');
  lookEl.progressFill = document.getElementById('look-progress-fill');
  lookEl.progressLabel = document.getElementById('look-progress-label');
  lookEl.endpoint = document.getElementById('look-vlm-endpoint');
  lookEl.token = document.getElementById('look-vlm-token');
  lookEl.configNote = document.getElementById('look-vlm-config');
  lookEl.verdictCard = document.getElementById('look-verdict-card');
  lookEl.badge = document.getElementById('look-verdict-badge');
  lookEl.headline = document.getElementById('look-headline');
  lookEl.score = document.getElementById('look-score');
  lookEl.scoreWrap = document.getElementById('look-score-wrap');
  lookEl.reasons = document.getElementById('look-reasons');
  lookEl.fixes = document.getElementById('look-fixes');
  lookEl.photoNotes = document.getElementById('look-photo-notes');
  lookEl.warnings = document.getElementById('look-warnings');
  lookEl.warningsHost = document.getElementById('look-warnings-host');
}

function lookBoot() {
  lookCacheElements();
  if (!lookEl.dropZone) return;
  lookBindEvents();
  lookSyncSettings();
  lookReset();
  if (typeof window.registerUrlState === 'function') {
    window.registerUrlState('sec-look-check', 'look-check', function () {
      if (typeof window.calcLookCheck === 'function') window.calcLookCheck();
    });
  }
}

function lookUpdateFromUrl() {
  lookSyncSettings();
}

window.calcLookCheck = lookUpdateFromUrl;

document.addEventListener('DOMContentLoaded', lookBoot);
