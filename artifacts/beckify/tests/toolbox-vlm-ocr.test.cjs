/* Optional VLM client: no upload unless Enhance is on and an HTTPS endpoint exists. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const store = {};
const session = {};
const sandbox = {
  console,
  Math,
  Number,
  String,
  Object,
  Array,
  JSON,
  Promise,
  URL,
  localStorage: {
    getItem(key) { return Object.prototype.hasOwnProperty.call(store, key) ? store[key] : null; },
    setItem(key, val) { store[key] = String(val); },
    removeItem(key) { delete store[key]; },
  },
  sessionStorage: {
    getItem(key) { return Object.prototype.hasOwnProperty.call(session, key) ? session[key] : null; },
    setItem(key, val) { session[key] = String(val); },
    removeItem(key) { delete session[key]; },
  },
  document: {
    querySelector() { return { getAttribute() { return ''; } }; },
  },
  FileReader: class {
    readAsDataURL() {
      this.result = 'data:image/jpeg;base64,/9j/4AAQSkZJRg==';
      if (typeof this.onload === 'function') this.onload();
    }
  },
  fetch() { throw new Error('fetch should not run in this unit test unless stubbed'); },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'nameplate-schema.js'), 'utf8'), sandbox, { filename: 'nameplate-schema.js' });
vm.runInContext(fs.readFileSync(path.join(root, 'vlm-ocr.js'), 'utf8'), sandbox, { filename: 'vlm-ocr.js' });

const api = sandbox.__vlmOcrTestApi;
assert.ok(api);
assert.equal(api.TASK_NAMEPLATE, 'nameplate');
assert.equal(api.TASK_PANEL, 'panel');
assert.equal(api.TASK_TDR, 'tdr');
assert.equal(api.TASK_LOOK, 'look');
assert.equal(typeof api.analyzePanelDirectory, 'function');
assert.equal(typeof api.analyzeTdr, 'function');
assert.equal(typeof api.analyzeLook, 'function');

assert.equal(api.httpsBase('http://evil.example'), '');
assert.equal(api.httpsBase('https://api.beckify.com/'), 'https://api.beckify.com');
assert.equal(api.httpsBase('https://proxy.example/ocr?version=2&region=us'), 'https://proxy.example/ocr?version=2&region=us');
assert.equal(api.httpsBase('https://proxy.example/ocr/?v=1'), 'https://proxy.example/ocr?v=1');
assert.equal(api.uploadMimeType('data:image/jpeg;base64,/9j/xxxx', 'image/heic'), 'image/jpeg');
assert.equal(api.uploadMimeType('data:image/png;base64,iVBOR', 'image/tiff'), 'image/png');
assert.equal(api.uploadMimeType('not-a-data-url', 'image/jpeg'), 'image/jpeg');

let cfg = api.resolveConfig(false);
assert.equal(cfg.ready, false);
assert.equal(api.shouldUpload(false), false);

api.saveSettings({ endpoint: 'https://proxy.example/ocr', token: 'secret-token' });
assert.equal(store[api.SETTINGS_KEY], 'https://proxy.example/ocr');
assert.equal(session[api.TOKEN_KEY], 'secret-token');
assert.ok(!Object.values(store).includes('secret-token'));

api.saveSettings({ endpoint: '', token: '' });
const firstForm = api.saveFormSettings('https://fresh.example/ocr', 'fresh-token');
assert.equal(firstForm.token, 'fresh-token');
assert.equal(firstForm.tokenCleared, false);
assert.equal(session[api.TOKEN_KEY], 'fresh-token');

api.saveSettings({ endpoint: 'https://other.example/vision' });
assert.equal(store[api.SETTINGS_KEY], 'https://other.example/vision');
assert.equal(session[api.TOKEN_KEY] || '', '');
const clearedForm = api.saveFormSettings('https://third.example/ocr', 'stale-token');
assert.equal(clearedForm.token, '');
assert.equal(clearedForm.tokenCleared, true);
assert.equal(session[api.TOKEN_KEY] || '', '');
api.saveSettings({ endpoint: 'https://proxy.example/ocr?version=2', token: 'secret-token' });
assert.equal(store[api.SETTINGS_KEY], 'https://proxy.example/ocr?version=2');
assert.equal(session[api.TOKEN_KEY], 'secret-token');
assert.equal(api.resolveConfig(true).customUrl, 'https://proxy.example/ocr?version=2');

api.saveSettings({ endpoint: 'https://proxy.example/ocr', token: 'secret-token' });
cfg = api.resolveConfig(true);
assert.equal(cfg.mode, 'custom');
assert.equal(cfg.ready, true);
assert.equal(api.endpointFor(cfg, 'nameplate'), 'https://proxy.example/ocr');
assert.equal(api.endpointFor(cfg, 'panel'), 'https://proxy.example/ocr');
assert.equal(api.endpointFor(cfg, 'tdr'), 'https://proxy.example/ocr');
assert.equal(api.endpointFor(cfg, 'look'), 'https://proxy.example/ocr');

api.saveSettings({ endpoint: '', token: '' });
sandbox.BECKIFY_API_BASE_URL = 'https://api.beckify.com';
cfg = api.resolveConfig(true);
assert.equal(cfg.mode, 'proxy');
assert.equal(api.endpointFor(cfg, 'nameplate'), 'https://api.beckify.com/api/analyze-nameplate');
assert.equal(api.endpointFor(cfg, 'panel'), 'https://api.beckify.com/api/analyze-panel');
assert.equal(api.endpointFor(cfg, 'tdr'), 'https://api.beckify.com/api/analyze-tdr');
assert.equal(api.endpointFor(cfg, 'look'), 'https://api.beckify.com/api/analyze-look');
assert.equal(api.shouldUpload(false), false);

const vlmDraft = api.analyzePayload({
  fields: { ratedHP: { value: 10, confidence: 0.8 }, fla: { value: 30, confidence: 0.4 }, mocp: { value: 30, confidence: 0.9 } },
  raw_ocr: 'MOCP 30 HP 10',
}, 'nameplate', 'vlm-test');
assert.equal(vlmDraft.fields.ratedHP.value, 10);
assert.equal(vlmDraft.fields.fla.value, null);
assert.equal(vlmDraft.fields.mocp.value, 30);

const byoEnvelope = api.analyzePayload(api.visionDraftInput({
  fields: { ratedHP: { value: 5, confidence: 0.8 }, fla: { value: null, confidence: 0 } },
  raw_ocr: 'HP 5 glare',
  warnings: ['FLA unreadable under glare'],
  dualFla: '28/14',
}), 'nameplate', 'vlm-custom', 'HP 5 glare');
assert.ok(byoEnvelope.warnings.some((w) => /glare/i.test(w)));
assert.equal(byoEnvelope.extras.dualFla, '28/14');
assert.equal(byoEnvelope.fields.ratedHP.value, 5);

const panelDraft = api.analyzePayload({
  circuits: [{ circuit: '3', description: 'Lighting', trip: 20, poles: 1 }],
}, 'panel', 'vlm-test');
assert.equal(panelDraft.task, 'panel');
assert.equal(panelDraft.rows[0].description.value, 'Lighting');
assert.equal(panelDraft.rows[0].trip.value, 20);
assert.equal(panelDraft.rows[0].loadAmps.value, null);

sandbox.BECKIFY_API_BASE_URL = '';

(async () => {
  await assert.rejects(
    () => api.analyzeNameplate({ size: 10, type: 'image/jpeg' }, { enhanceOn: false }),
    /off/i,
  );
  await assert.rejects(
    () => api.analyzeNameplate({ size: 10, type: 'image/jpeg' }, { enhanceOn: true }),
    /no HTTPS endpoint/i,
  );
  await assert.rejects(
    () => api.analyzePanelDirectory({ size: 10, type: 'image/jpeg' }, { enhanceOn: true }),
    /no HTTPS endpoint/i,
  );

  api.saveSettings({ endpoint: 'https://proxy.example/ocr', token: 'keep-me' });
  let posted;
  sandbox.createImageBitmap = function () {
    return Promise.resolve({
      width: 4,
      height: 4,
      close() {},
    });
  };
  sandbox.document.createElement = function () {
    return {
      width: 0,
      height: 0,
      getContext() { return { drawImage() {} }; },
      toDataURL() { return 'data:image/jpeg;base64,/9j/encodedFromCanvas'; },
    };
  };
  sandbox.fetch = function (_url, opts) {
    posted = JSON.parse(opts.body);
    return Promise.resolve({
      ok: false,
      status: 429,
      headers: { get(name) { return String(name).toLowerCase() === 'retry-after' ? '120' : null; } },
      json() {
        return Promise.resolve({ error: 'Too many nameplate analyses. Please try again later.', retryAfter: 120 });
      },
    });
  };
  await assert.rejects(
    () => api.analyzeNameplate({ size: 24, type: 'image/jpeg' }, { enhanceOn: true }),
    /Too many AI reads/i,
  );
  assert.match(api.formatVisionError({ status: 429, retryAfter: 120 }), /2 min/i);

  sandbox.fetch = function (_url, opts) {
    posted = JSON.parse(opts.body);
    return Promise.resolve({
      ok: true,
      json() {
        return Promise.resolve({
          fields: { ratedHP: { value: 7.5, confidence: 0.8 } },
          raw_ocr: 'HP 7.5',
          warnings: ['ambiguous FLA'],
        });
      },
    });
  };
  const enhanced = await api.analyzeNameplate({ size: 24, type: 'image/heic' }, { enhanceOn: true });
  assert.equal(posted.mimeType, 'image/jpeg');
  assert.match(posted.imageBase64, /^data:image\/jpeg/);
  assert.ok(enhanced.warnings.some((w) => /ambiguous FLA/i.test(w)));
  assert.equal(enhanced.draft.fields.ratedHP.value, 7.5);
  api.saveSettings({ endpoint: '', token: '' });

  const html = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'index.html'), 'utf8');
  assert.match(html, /id="mnp_enhance"[^>]*data-no-persist/);
  assert.match(html, /Enhance with AI/);
  assert.match(html, /OpenAI and\/or Anthropic/);
  assert.match(html, /not an AI electrician/);
  assert.match(html, /js\/vlm-ocr\.js/);
  assert.match(html, /js\/nameplate-schema\.js/);
  const motor = fs.readFileSync(path.join(root, 'motor-nameplate.js'), 'utf8');
  assert.match(motor, /shouldUpload/);
  assert.match(motor, /analyzeNameplate/);
  assert.match(motor, /BeckifyOcr\.recognize/);
  assert.match(motor, /formatVisionError/);
  assert.equal(typeof api.analyzeMany, 'function');
  assert.equal(typeof api.formatVisionError, 'function');
  const panel = fs.readFileSync(path.join(root, 'panel-schedule.js'), 'utf8');
  assert.match(panel, /analyzePanelDirectory\(/);
  assert.match(panel, /shouldUpload/);
  assert.match(panel, /mode: 'directory'/);
  assert.match(panel, /view: 'breakers'/);
  assert.match(panel, /view: 'schedule'/);
  const panelHtml = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'panel-schedule.html'), 'utf8');
  assert.match(panelHtml, /js\/vlm-ocr\.js/);
  assert.match(panelHtml, /id="panelEnhance"[^>]*data-no-persist/);
  assert.match(panelHtml, /Enhance with AI/);
  assert.match(panelHtml, /not an AI electrician/);
  assert.match(panelHtml, /connect-src 'self' https:/);
  assert.match(panelHtml, /beckify-api-base-url/);
  const power = fs.readFileSync(path.join(root, 'panel-power-study.js'), 'utf8');
  assert.match(power, /analyzePanelDirectory\(/);
  const powerHtml = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'panel-power-study.html'), 'utf8');
  assert.match(powerHtml, /id="panelEnhance"[^>]*data-no-persist/);
  assert.match(powerHtml, /connect-src 'self' https:/);

  const fromDraft = api.rowsFromPanelDraft({
    rows: [
      { circuit: { value: '23' }, description: { value: 'WEST SECURITY GATE' }, trip: { value: null }, poles: { value: 2 }, notes: { value: 'handwritten' } },
    ],
  }, () => ({ demandFactor: '1' }));
  assert.equal(fromDraft[0].circuit, '23');
  assert.match(fromDraft[0].description, /WEST SECURITY GATE/);
  assert.equal(fromDraft[0].loadAmps, '');
  const meta = api.panelMetaFromDraft({ panel: { name: { value: 'PANEL BLT 11' }, voltage: { value: '208/120V' } } });
  assert.equal(meta.panelName, 'PANEL BLT 11');

  const lookGood = api.normalizeLookDraft({
    verdict: 'looks_good',
    score: 88.4,
    headline: 'Strong light',
    summary: 'You look sharp in this frame.',
    metrics: { lighting: 90.2, framing: 70, expression: 84, sharpness: 88 },
    reasons: ['Even light'],
    fixes: ['Smile'],
  });
  assert.equal(lookGood.task, 'look');
  assert.equal(lookGood.verdict, 'looks_good');
  assert.equal(lookGood.score, 88);
  assert.equal(lookGood.summary, 'You look sharp in this frame.');
  assert.equal(lookGood.metrics.lighting, 90);
  assert.equal(lookGood.metrics.overall, 88);
  const lookDeclined = api.normalizeLookDraft({
    verdict: 'declined',
    score: 12,
    headline: 'No',
    metrics: { lighting: 80, overall: 90 },
  });
  assert.equal(lookDeclined.verdict, 'declined');
  assert.equal(lookDeclined.score, null);
  assert.equal(lookDeclined.metrics.lighting, null);
  assert.equal(lookDeclined.metrics.overall, null);
  const lookUnknown = api.analyzePayload({ verdict: 'amazing', score: 200 }, 'look');
  assert.equal(lookUnknown.verdict, 'mixed');
  assert.equal(lookUnknown.score, 100);

  assert.equal(api.asLookScore(null), null);
  assert.equal(api.asLookScore(''), null);
  assert.equal(api.asLookScore('  '), null);
  assert.equal(api.asLookScore(0), 0);
  const lookNullMetrics = api.normalizeLookDraft({
    verdict: 'looks_good',
    score: 88,
    metrics: { lighting: null, framing: 70, expression: null, sharpness: 88 },
  });
  assert.equal(lookNullMetrics.metrics.lighting, null);
  assert.equal(lookNullMetrics.metrics.expression, null);
  assert.equal(lookNullMetrics.metrics.framing, 70);
  assert.equal(lookNullMetrics.metrics.overall, 88);

  assert.match(html, /id="sec-look-check"/);
  assert.match(html, /Analyze Look/);
  assert.match(html, /id="look-camera-input"[^>]*capture="user"/);
  assert.match(html, /id="look-summary"/);
  assert.match(html, /id="look-metrics"/);
  assert.match(html, /js\/look-check\.js/);
  assert.match(html, /id="tdr_privacy"/);
  const lookJs = fs.readFileSync(path.join(root, 'look-check.js'), 'utf8');
  assert.match(lookJs, /12 \* 1024 \* 1024/);
  assert.match(lookJs, /does not upload/);
  assert.match(lookJs, /analyzeLook/);
  assert.match(lookJs, /\/api\/analyze-look/);
  assert.match(lookJs, /beckify-api-base-url/);
  assert.match(lookJs, /lookFormatHttpError/);
  assert.match(lookJs, /api\.beckify\.com/);
  assert.match(lookJs, /stale or missing \/api\/analyze-look/);
  assert.match(lookJs, /lookHostIsGitHubPages/);
  assert.match(lookJs, /lookIsImageFile/);
  assert.match(
    api.formatVisionError(api.VisionHttpError('Cannot POST /api/analyze-look', 404)),
    /stale or missing/,
  );
  assert.doesNotMatch(
    api.formatVisionError(api.VisionHttpError('Method Not Allowed', 405)),
    /GitHub Pages/,
  );
  assert.match(
    api.formatVisionError(api.VisionHttpError('Method Not Allowed', 405, 0, 'https://beckify.com/api/analyze-look')),
    /GitHub Pages/,
  );
  assert.match(
    api.formatVisionError(api.VisionHttpError('', 503)),
    /not configured/,
  );
  assert.match(lookJs, /look-camera/);
  assert.match(lookJs, /lookRenderMetrics/);
  assert.match(html, /look-verdict-card\[hidden\]/);
  const tdrJs = fs.readFileSync(path.join(root, 'tdr-analyzer.js'), 'utf8');
  assert.match(tdrJs, /prepareUploadDataUrl/);
  const schema = sandbox.__nameplateSchemaTestApi;
  assert.equal(typeof schema.highlightReasons, 'function');
  assert.equal(typeof schema.exportPanelDraft, 'function');
  const prompt = fs.readFileSync(path.join(__dirname, '..', '..', 'api-server', 'src', 'prompts', 'nameplateVisionPrompt.ts'), 'utf8');
  assert.match(prompt, /IEC plates/);
  assert.match(prompt, /Do not assume 60 Hz/);
  const panelPrompt = fs.readFileSync(path.join(__dirname, '..', '..', 'api-server', 'src', 'prompts', 'panelVisionPrompt.ts'), 'utf8');
  assert.match(panelPrompt, /middle or bottom tile/);

  console.log('VLM OCR client config + schema mapping passed');
})().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
