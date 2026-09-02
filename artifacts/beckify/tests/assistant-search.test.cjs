/* Regression test for the "Ask Beckify" global search index.
   Before this, src/lib/assistant/search.ts hand-maintained its own list of
   17 documents (8 of them tools) that had drifted from the toolbox's real
   44-tool registry: searching "smith chart", "555 timer", "harmonics",
   "resonance", "nema", "lighting", "generator", or "ups" returned nothing,
   though every one of those is a real, linked, sitemapped tool. The index is
   now derived from src/data/toolbox-tools.mjs (the same registry
   scripts/generate-sitemap.mjs uses), so this checks that derivation stays
   complete and that previously-broken queries actually return the right
   tool. */
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('typescript');

const root = path.join(__dirname, '..');
const registry = require(path.join(root, 'src', 'data', 'toolbox-tools.mjs'));

// search.ts imports the registry via the "@/" alias, which only Vite
// understands. Rewrite it to a real relative path before transpiling so
// plain Node can resolve it, the same tradeoff control-engine.test.cjs makes
// by transpiling in memory instead of adding a build step just for tests.
const searchSourcePath = path.join(root, 'src', 'lib', 'assistant', 'search.ts');
const source = fs.readFileSync(searchSourcePath, 'utf8')
  .replace('@/data/toolbox-tools.mjs', '../../data/toolbox-tools.mjs');
const { outputText } = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
});
const generatedPath = path.join(path.dirname(searchSourcePath), 'search.generated.js');
const searchModule = new Module(generatedPath);
searchModule.filename = generatedPath;
searchModule.paths = Module._nodeModulePaths(path.dirname(generatedPath));
searchModule._compile(outputText, generatedPath);
const { ASSISTANT_DOCUMENTS, searchAssistant } = searchModule.exports;

let fails = 0;
function ok(name, condition, detail) {
  if (!condition) fails += 1;
  console.log((condition ? '  PASS  ' : '  FAIL  ') + name.padEnd(64) + (detail ?? ''));
}

console.log('\n--- Assistant search: registry coverage ---');
{
  const ids = new Set(ASSISTANT_DOCUMENTS.map((d) => d.id));
  const missingTools = registry.TOOLS.filter(([slug]) => !ids.has(slug));
  ok('every toolbox tool is a searchable document', missingTools.length === 0, missingTools.map((t) => t[0]).join(', '));
  const missingRefs = registry.REFERENCE_TABLES.filter(([slug]) => !ids.has(slug));
  ok('every reference table is a searchable document', missingRefs.length === 0, missingRefs.map((t) => t[0]).join(', '));
  ok('at least 44 tool/reference documents are indexed', ASSISTANT_DOCUMENTS.filter((d) => d.kind === 'tool' || d.kind === 'reference').length >= registry.TOOLS.length + registry.REFERENCE_TABLES.length);
}

console.log('\n--- Assistant search: previously-broken queries now resolve ---');
const expectResult = [
  ['smith chart', 'smith-chart'],
  ['555 timer', '555-timer'],
  ['harmonics', 'harmonics'],
  ['nema', 'nema-class'],
  ['resonance', 'resonance'],
  ['generator', 'generator-sizing'],
  ['ups sizing', 'ups-sizing'],
  ['magnetic circuit', 'magnetic-circuit'],
  ['reluctance', 'magnetic-circuit'],
  ['transient rlc', 'transient-circuits'],
  ['phasor diagram', 'phasor-diagram'],
  ['delta wye', 'phasor-diagram'],
  ['shockley', 'semiconductor-iv'],
  ['mosfet', 'semiconductor-iv'],
  ['numerical aperture', 'fiber-link'],
  ['link budget', 'fiber-link'],
  ['gaussian beam', 'gaussian-beam'],
  ['rayleigh range', 'gaussian-beam'],
];
for (const [query, expectedId] of expectResult) {
  const results = searchAssistant(query, 6);
  const hit = results.some((r) => r.id === expectedId);
  ok(`"${query}" finds ${expectedId}`, hit, results.map((r) => r.id).join(', ') || '(no results)');
}

console.log('\n--- Assistant search: previously-working queries still work ---');
for (const [query, expectedId] of [['transformer sizing', 'transformer-sizing'], ['voltage drop', 'voltage-drop'], ['conduit fill', 'conduit-fill'], ['megger tdr', 'megger-tdr-analyzer'], ['faraday shielding', 'emp-emc-shielding']]) {
  const results = searchAssistant(query, 6);
  ok(`"${query}" still finds ${expectedId}`, results.some((r) => r.id === expectedId), results.map((r) => r.id).join(', '));
}

console.log('\n--- Assistant search: new educational tools ---');
for (const [query, expectedId] of [['linear programming', 'lp-optimizer'], ['simplex', 'lp-optimizer'], ['hexadecimal', 'number-base-converter'], ["two's complement", 'number-base-converter'], ['io list', 'io-list-generator'], ['ethercat', 'io-list-generator'], ['4-20ma', 'signal-scaling'], ['live zero', 'signal-scaling'], ['40001', 'modbus-address'], ['ton', 'plc-timer-preset']]) {
  const results = searchAssistant(query, 6);
  ok(`"${query}" finds ${expectedId}`, results.some((r) => r.id === expectedId), results.map((r) => r.id).join(', '));
}

console.log('\n--- Assistant search: five new toolbox tools ---');
for (const [query, expectedId] of [
  ['nema 5-15', 'nema-wiring'],
  ['5-15', 'nema-wiring'],
  ['cable schedule', 'cable-schedule'],
  ['battery bank', 'battery-bank'],
  ['motor nameplate', 'motor-nameplate'],
  ['lfp backup', 'battery-bank'],
]) {
  const results = searchAssistant(query, 6);
  ok(`"${query}" finds ${expectedId}`, results.some((r) => r.id === expectedId), results.map((r) => r.id).join(', '));
}

console.log('\n--- Assistant search: no duplicate ids, every href is real ---');
{
  const ids = ASSISTANT_DOCUMENTS.map((d) => d.id);
  ok('no duplicate document ids', new Set(ids).size === ids.length, ids.filter((id, i) => ids.indexOf(id) !== i).join(', '));
  const badHrefs = ASSISTANT_DOCUMENTS.filter((d) => !d.href.startsWith('/'));
  ok('every href is a site-relative path', badHrefs.length === 0, badHrefs.map((d) => d.id).join(', '));
}

console.log(fails ? `\n${fails} FAILURE(S)` : '\nAll assistant search checks passed');
process.exitCode = fails ? 1 : 0;
