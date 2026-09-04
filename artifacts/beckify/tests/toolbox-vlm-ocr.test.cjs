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
assert.equal(typeof api.analyzePanelDirectory, 'function');

assert.equal(api.httpsBase('http://evil.example'), '');
assert.equal(api.httpsBase('https://api.beckify.com/'), 'https://api.beckify.com');

let cfg = api.resolveConfig(false);
assert.equal(cfg.ready, false);
assert.equal(api.shouldUpload(false), false);

api.saveSettings({ endpoint: 'https://proxy.example/ocr', token: 'secret-token' });
assert.equal(store[api.SETTINGS_KEY], 'https://proxy.example/ocr');
assert.equal(session[api.TOKEN_KEY], 'secret-token');
assert.ok(!Object.values(store).includes('secret-token'));

cfg = api.resolveConfig(true);
assert.equal(cfg.mode, 'custom');
assert.equal(cfg.ready, true);
assert.equal(api.endpointFor(cfg, 'nameplate'), 'https://proxy.example/ocr');
assert.equal(api.endpointFor(cfg, 'panel'), 'https://proxy.example/ocr');

api.saveSettings({ endpoint: '', token: '' });
sandbox.BECKIFY_API_BASE_URL = 'https://api.beckify.com';
cfg = api.resolveConfig(true);
assert.equal(cfg.mode, 'proxy');
assert.equal(api.endpointFor(cfg, 'nameplate'), 'https://api.beckify.com/api/analyze-nameplate');
assert.equal(api.endpointFor(cfg, 'panel'), 'https://api.beckify.com/api/analyze-panel');
assert.equal(api.shouldUpload(false), false);

const vlmDraft = api.analyzePayload({
  fields: { ratedHP: { value: 10, confidence: 0.8 }, fla: { value: 30, confidence: 0.4 }, mocp: { value: 30, confidence: 0.9 } },
  raw_ocr: 'MOCP 30 HP 10',
}, 'nameplate', 'vlm-test');
assert.equal(vlmDraft.fields.ratedHP.value, 10);
assert.equal(vlmDraft.fields.fla.value, null);
assert.equal(vlmDraft.fields.mocp.value, 30);

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

  const html = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'index.html'), 'utf8');
  assert.match(html, /id="mnp_enhance"[^>]*data-no-persist/);
  assert.match(html, /Enhance with AI/);
  assert.match(html, /not an AI electrician/);
  assert.match(html, /js\/vlm-ocr\.js/);
  assert.match(html, /js\/nameplate-schema\.js/);
  const motor = fs.readFileSync(path.join(root, 'motor-nameplate.js'), 'utf8');
  assert.match(motor, /shouldUpload/);
  assert.match(motor, /analyzeNameplate/);
  assert.match(motor, /BeckifyOcr\.recognize/);
  const panel = fs.readFileSync(path.join(root, 'panel-schedule.js'), 'utf8');
  assert.match(panel, /analyzePanelDirectory/);
  assert.doesNotMatch(panel, /analyzePanelDirectory\(/);
  const panelHtml = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'panel-schedule.html'), 'utf8');
  assert.match(panelHtml, /js\/vlm-ocr\.js/);
  console.log('VLM OCR client config + schema mapping passed');
})().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
