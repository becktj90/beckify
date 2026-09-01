/* Regression tests for the Demand/Diversity/Growth planner (factor-tools.js).
   Covers a real defect found during a hostile-input sweep: an unbounded
   growth horizon crashed the growth-chart renderer with
   "RangeError: Invalid string length", and three divisions (demand factor,
   coincidence factor, projected utilization) were unguarded against a zero
   or overflowing denominator and leaked NaN%/Infinity% into the result. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// A minimal fake DOM: enough for factor-tools.js + the app.js helpers it
// calls (showResult/showError/fmt/escapeHtml/appendCopyBtn) to run for real,
// without pulling in a full DOM implementation for four pure functions.
function makeElement(tag) {
  const el = {
    tagName: tag,
    value: '',
    className: '',
    children: [],
    attrs: {},
    style: {},
    setAttribute(k, v) { this.attrs[k] = v; },
    appendChild(child) { this.children.push(child); return child; },
    append(...items) { this.children.push(...items); },
    querySelector() { return null; },
    remove() {},
    get innerHTML() { return this._innerHTML || ''; },
    // showError sets .textContent directly (no markup); showResult sets
    // .innerHTML. Track whichever the code under test actually used so the
    // test reads real output instead of assuming one code path.
    set innerHTML(v) { this._innerHTML = v; this._plainText = v.replace(/<[^>]*>/g, ' '); },
    get textContent() { return this._textContent || ''; },
    set textContent(v) { this._textContent = v; this._plainText = v; },
  };
  return el;
}

function buildSandbox(fieldIds) {
  const elements = new Map();
  for (const id of fieldIds) elements.set(id, makeElement('input'));
  elements.set('lf_result', makeElement('div'));

  const document = {
    getElementById: (id) => elements.get(id) || null,
    createElement: (tag) => makeElement(tag),
    createElementNS: (_ns, tag) => makeElement(tag),
  };
  const sandbox = { document, console, Math, Number, Object, Array, String, JSON, isFinite, parseFloat };
  sandbox.window = sandbox;
  vm.createContext(sandbox);
  return { sandbox, elements };
}

const FIELDS = ['lf_connected', 'lf_peak', 'lf_individual', 'lf_average', 'lf_capacity', 'lf_growth', 'lf_years'];
const root = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const appFull = fs.readFileSync(path.join(root, 'app.js'), 'utf8');
const factorSrc = fs.readFileSync(path.join(root, 'factor-tools.js'), 'utf8');

// app.js is the full toolbox controller: its top-level code wires real page
// navigation and expects a full DOM. factor-tools.js only needs the shared
// result-rendering helpers further down the file (escapeHtml/appendCopyBtn/
// showResult/showError/fmt), so pull that block out by its section comments
// rather than re-implementing the helpers and risking drift from production.
const helperStart = appFull.indexOf('HELPER UTILITIES');
const helperSectionEnd = appFull.indexOf('\n/* =', helperStart + 1);
assert.ok(helperStart > 0 && helperSectionEnd > helperStart, 'app.js HELPER UTILITIES section markers found');
const appHelpers = appFull.slice(appFull.lastIndexOf('/*', helperStart), helperSectionEnd);
assert.ok(/function showResult/.test(appHelpers) && /function fmt/.test(appHelpers), 'extracted helpers include showResult and fmt');

function run(values) {
  const { sandbox, elements } = buildSandbox(FIELDS);
  vm.runInContext(appHelpers, sandbox, { filename: 'app-helpers.js' });
  vm.runInContext(factorSrc, sandbox, { filename: 'factor-tools.js' });
  for (const [id, v] of Object.entries(values)) elements.get(id).value = v;
  vm.runInContext('window.calcLoadFactors()', sandbox, { filename: 'invoke.js' });
  const resultEl = elements.get('lf_result');
  return { text: elementText(resultEl), className: resultEl.className, children: resultEl.children };
}

// showResult sets innerHTML for the rows, then appendCopyBtn and the growth-
// rate suggestions note are appended afterward as real child elements — so
// reading only .innerHTML misses them. Walk the whole tree.
function elementText(el) {
  let text = el._plainText || '';
  for (const child of el.children || []) text += ' ' + elementText(child);
  return text;
}

let fails = 0;
function ok(name, condition, detail) {
  if (!condition) fails += 1;
  console.log((condition ? '  PASS  ' : '  FAIL  ') + name.padEnd(64) + (detail ?? ''));
}

console.log('\n--- Load Factors: crash guard ---');
{
  // The historical crash: a huge horizon built one string-concat point per
  // year (10^12 iterations). This must complete and produce a real answer.
  const r = run({ lf_peak: '500', lf_growth: '5', lf_years: '1e12' });
  ok('huge growth horizon does not throw', !/Error/.test(r.text));
  ok('huge growth horizon reports a bounded message, not Infinity kVA',
    !/Infinity/.test(r.text) && /exceeds the range/i.test(r.text), r.text.slice(0, 160));
}

console.log('\n--- Load Factors: unguarded-division leaks ---');
{
  // connected = 0 previously gave "Demand factor: Infinity%". Pair it with a
  // valid average/peak entry so the calculator has a complete pair elsewhere
  // and actually reaches the per-field guidance branch instead of the
  // generic "no complete pair" error.
  const r = run({ lf_connected: '0', lf_peak: '100', lf_average: '50' });
  ok('zero connected load does not leak Infinity%', !/Infinity/.test(r.text), r.text);
  ok('zero connected load falls back to guidance text', /connected load greater than zero/i.test(r.text), r.text);
}
{
  // connected = peak = 0 previously gave "Demand factor: NaN%"
  const r = run({ lf_connected: '0', lf_peak: '0' });
  ok('zero connected and zero peak does not leak NaN%', !/NaN/.test(r.text), r.text);
}
{
  // individual = 0, peak > 0 previously gave "Coincidence factor: Infinity" (1/0)
  const r = run({ lf_individual: '0', lf_peak: '100' });
  ok('zero individual demand does not leak Infinity coincidence factor', !/Infinity/.test(r.text), r.text);
}
{
  // A growth projection that overflows Number range previously gave
  // "Projected utilization: Infinity%".
  const r = run({ lf_peak: '100', lf_capacity: '200', lf_growth: '500', lf_years: '400' });
  ok('overflowing projection does not leak Infinity%', !/Infinity/.test(r.text), r.text.slice(0, 160));
}

console.log('\n--- Load Factors: real answers still correct ---');
{
  // Hand check: demand factor = peak/connected = 800/1000 = 80%
  const r = run({ lf_connected: '1000', lf_peak: '800' });
  ok('demand factor computes correctly', /Demand factor\s*80%/.test(r.text), r.text);
}
{
  // Hand check: diversity = individual/peak = 150/100 = 1.5, coincidence = 1/1.5 = 0.667
  const r = run({ lf_individual: '150', lf_peak: '100' });
  ok('diversity factor computes correctly', /1\.500/.test(r.text));
  ok('coincidence factor computes correctly', /0\.667/.test(r.text));
}
{
  // Hand check: 100 kVA growing 10%/yr for 5 years = 100*1.1^5 = 161.05 kVA
  const r = run({ lf_peak: '100', lf_growth: '10', lf_years: '5' });
  ok('growth projection computes correctly', /161\.1|161\.0/.test(r.text), r.text);
}

console.log(fails ? `\n${fails} FAILURE(S)` : '\nAll load-factor regression checks passed');
process.exitCode = fails ? 1 : 0;
