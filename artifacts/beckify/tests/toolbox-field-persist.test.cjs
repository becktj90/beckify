/* last-used persist must never restore OCR review checkboxes. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const store = {};
const sandbox = {
  console,
  document: {
    getElementById() { return null; },
  },
  localStorage: {
    getItem(key) { return Object.prototype.hasOwnProperty.call(store, key) ? store[key] : null; },
    setItem(key, val) { store[key] = String(val); },
  },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'field-persist.js'), 'utf8'), sandbox, { filename: 'field-persist.js' });

const api = sandbox.__fieldPersistTestApi;
assert.ok(api);

function fakeEl(id, type, extra) {
  const el = {
    id,
    type,
    tagName: type === 'select' ? 'SELECT' : type === 'textarea' ? 'TEXTAREA' : 'INPUT',
    value: '',
    checked: false,
    options: [],
    attrs: extra && extra.attrs ? extra.attrs : {},
    getAttribute(name) {
      return Object.prototype.hasOwnProperty.call(this.attrs, name) ? this.attrs[name] : null;
    },
  };
  return el;
}

const reviewed = fakeEl('mnp_reviewed', 'checkbox', { attrs: { 'data-no-persist': '' } });
const hp = fakeEl('mnp_hp', 'number', { attrs: {} });
hp.value = '10';
const section = {
  querySelectorAll() { return [reviewed, hp]; },
};

const persisted = api.fields(section);
assert.equal(persisted.length, 1);
assert.equal(persisted[0].id, 'mnp_hp');
assert.ok(!persisted.some((el) => el.id === 'mnp_reviewed'));

reviewed.checked = true;
api.save(section, api.PREFIX + 'motor-nameplate');
const saved = JSON.parse(store[api.PREFIX + 'motor-nameplate']);
assert.equal(saved.mnp_hp, '10');
assert.equal(saved.mnp_reviewed, undefined);

reviewed.checked = false;
hp.value = '';
store[api.PREFIX + 'motor-nameplate'] = JSON.stringify({ mnp_hp: '7.5', mnp_reviewed: '1' });
api.restore(section, api.PREFIX + 'motor-nameplate');
assert.equal(hp.value, '7.5');
assert.equal(reviewed.checked, false);

const html = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'index.html'), 'utf8');
assert.match(html, /id="mnp_reviewed"[^>]*data-no-persist/);
const persistSrc = fs.readFileSync(path.join(root, 'field-persist.js'), 'utf8');
assert.match(persistSrc, /data-no-persist/);
const urlSrc = fs.readFileSync(path.join(root, 'url-state.js'), 'utf8');
assert.match(urlSrc, /data-no-persist/);

console.log('Field persist skips OCR review checkboxes');
