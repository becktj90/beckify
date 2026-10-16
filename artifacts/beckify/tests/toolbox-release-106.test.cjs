/* 1.0.6 release guards: K-method voltage drop unchanged, conduit fill example
   consistent with its doc copy, one demand-rate input, index taxonomy unified. */
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const assert = require('assert');
const dir = path.join(__dirname, '..', 'public', 'toolbox');
const html = fs.readFileSync(path.join(dir, 'classic', 'index.html'), 'utf8');

// ── Voltage drop spot check: 3Ø, 480 V, 100 A, 200 ft, 3/0 Cu → 2.66 V, 0.55 % ──
{
  const fields = { vd_i_3p: '100', vd_l_3p: '200', vd_awg_3p: '3/0', vd_mat_3p: 'CU', vd_vs_3p: '480' };
  let rows = null;
  const el = (id) => ({ value: fields[id] ?? '', textContent: '', innerHTML: '', style: {}, classList: { add() {}, remove() {}, toggle() {} },
    appendChild() {}, addEventListener() {}, setAttribute() {}, querySelector() { return null; }, querySelectorAll() { return []; } });
  const sandbox = {
    document: { addEventListener() {}, getElementById: el, querySelector() { return null; }, querySelectorAll() { return []; }, createElement: el, body: el('body') },
    console, Math, Number, Object, Array, String, Set, Map, JSON, isFinite, parseInt, parseFloat, isNaN,
    localStorage: { getItem() { return null; }, setItem() {} }, setTimeout() {}, location: { hash: '', search: '' },
    navigator: {}, history: { replaceState() {} }, matchMedia: () => ({ matches: false, addEventListener() {} }),
  };
  sandbox.window = sandbox;
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(path.join(dir, 'js', 'app.js'), 'utf8'), sandbox, { filename: 'app.js' });
  sandbox.showResult = (_id, r) => { rows = r; };
  vm.runInContext('showResult = window.showResult', sandbox);
  sandbox.calcVDrop('3p');
  assert.ok(rows, 'calcVDrop produced a result');
  const get = (label) => rows.find((r) => r[0] === label)[1];
  assert.strictEqual(get('Voltage Drop (VD)'), '2.66 V');
  assert.strictEqual(get('Voltage Drop %'), '0.55 %');
}

// ── Conduit fill: documented same-size example matches what the button loads ──
{
  const docs = fs.readFileSync(path.join(dir, 'js', 'math-explanations.js'), 'utf8');
  const wire = fs.readFileSync(path.join(dir, 'js', 'wire-tools.js'), 'utf8');
  const block = docs.slice(docs.indexOf("'sec-conduit': {"), docs.indexOf("'sec-conduit-adv': {"));
  assert.match(block, /loadConduitFillSameSizeExample/);
  assert.match(block, /3\/4" EMT/);
  assert.match(block, /4× #12 AWG THHN/);
  const fn = wire.slice(wire.indexOf('window.loadConduitFillSameSizeExample'), wire.indexOf('window.loadConduitFillExample'));
  assert.match(fn, /conduitEl\.value = '3\/4'/);
  assert.match(fn, /awgEl\.value = '12'/);
  assert.match(fn, /qtyEl\.value = '4'/);
  assert.match(fn, /calcConduitFill\(\)/);
}

// ── Exactly one demand-rate input and one demand-kW input, both read by the cost calc ──
{
  assert.strictEqual((html.match(/id="ws_demand_rate"/g) || []).length, 1);
  assert.strictEqual((html.match(/id="ws_demand_kw"/g) || []).length, 1);
  assert.strictEqual((html.match(/Demand \$\/kW/gi) || []).length, 0, 'no ambiguous duplicate-looking labels');
}

// ── Index taxonomy: 8 sidebar categories, every tool once, names identical ──
{
  const nav = html.slice(html.indexOf('<nav class="sidebar"'), html.indexOf('</nav>'));
  const sideCats = [...nav.matchAll(/sidebar-section-title">([^<]*)</g)].map((m) => m[1]);
  assert.strictEqual(sideCats.length, 8);
  const sideTools = [...nav.matchAll(/<button class="nav-btn" data-target="(sec-[^"]+)"[^>]*>([^<]*)<\/button>/g)]
    .filter((m) => m[1] !== 'sec-home').map((m) => [m[1], m[2]]);
  const gs = html.indexOf('<div class="home-grid">');
  const grid = html.slice(gs, html.indexOf('</section>', gs));
  const gridCats = [...grid.matchAll(/home-cat-name">([^<]*)</g)].map((m) => m[1]);
  assert.deepStrictEqual(gridCats, sideCats);
  const gridTools = [...grid.matchAll(/class="home-tool-link" href="#(sec-[^"]+)">([^<]*)</g)].map((m) => [m[1], m[2]]);
  assert.deepStrictEqual(gridTools, sideTools);
  const hrefs = [...grid.matchAll(/href="([^"]+)"/g)].map((m) => m[1]);
  assert.strictEqual(new Set(hrefs).size, hrefs.length, 'no duplicate index links');
  for (const [id, name] of sideTools) {
    const m = html.match(new RegExp('<section id="' + id + '"[^>]*>[\\s\\S]*?<h2[^>]*>([\\s\\S]*?)</h2>'));
    assert.ok(m && m[1].includes(name), id + ' header carries canonical name "' + name + '"');
  }
  // Featured row has no repeated targets either.
  const feat = html.slice(html.indexOf('home-featured-list'), html.indexOf('</ul>', html.indexOf('home-featured-list')));
  const fh = [...feat.matchAll(/href="([^"]+)"/g)].map((m) => m[1]);
  assert.strictEqual(new Set(fh).size, fh.length);
  // Control theory is clearly marked as a separate page.
  assert.match(nav, /nav-ext[^>]*>Control System Toolbox <span class="nav-ext-tag"[^>]*>Separate page ↗<\/span>/);
}
console.log('toolbox-release-106: ok');
