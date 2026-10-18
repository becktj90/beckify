/* Electronics Bench — ported math, breadboard audit, renderers, and site wiring. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..');
const js = (f) => fs.readFileSync(path.join(root, 'public', 'toolbox', 'js', f), 'utf8');
const sandbox = { console, Math, Number, String, Object, Array, JSON, Set, Map, isFinite, parseInt, setTimeout, clearTimeout, encodeURIComponent };
sandbox.window = sandbox; sandbox.globalThis = sandbox;
const ctx = vm.createContext(sandbox);
vm.runInContext(js('electronics-bench-engine.js'), ctx, { filename: 'electronics-bench-engine.js' });
vm.runInContext(js('electronics-bench-render.js'), ctx, { filename: 'electronics-bench-render.js' });
const E = sandbox.BeckifyBenchEngine;
const R = sandbox.BeckifyBenchRender;
const near = (a, b, tol, msg) => assert.ok(Math.abs(a - b) <= (tol || 1e-9), `${msg || ''} ${a} vs ${b}`);

/* parsing and formatting */
assert.equal(E.parseEngineering('4.7k'), 4700);
near(E.parseEngineering('100n'), 1e-7, 1e-18);
near(E.parseEngineering('2.2µ'), 2.2e-6, 1e-18);
assert.equal(E.parseEngineering('1M'), 1e6);
assert.equal(E.parseEngineering('12.5abc'), null);
assert.equal(E.parseEngineering('12.5.6'), null);
assert.equal(E.parseEngineering(''), null);
assert.equal(E.eng(4700), '4.70k');
assert.equal(E.si(0.0006, 'A'), '600 µA');
assert.equal(E.si(12, 'V'), '12.0 V');
assert.equal(E.trim(4700), '4.7k');
assert.equal(E.trim(1000), '1k');

/* resistor color code: 4.7k = yellow violet red gold, 10k = brown black orange gold */
assert.deepEqual(Array.from(E.fourBand(4700)), ['yellow', 'violet', 'red', 'gold']);
assert.deepEqual(Array.from(E.fourBand(10000)), ['brown', 'black', 'orange', 'gold']);
assert.deepEqual(Array.from(E.fourBand(1)), ['brown', 'black', 'gold', 'gold']);

/* golden values */
const D = (id) => E.specOf(id).defaults;
let s = E.solve('seriesResistors', 'current', D('seriesResistors'));
near(s.quantity ? 0 : s.quantities.find((x) => x.id === 'current').value, 0.004, 1e-12, 'series I');
s = E.solve('voltageDivider', 'vout', D('voltageDivider'));
near(s.quantities.find((x) => x.id === 'vout').value, 6, 1e-12);
s = E.solve('parallelResistors', 'sourceCurrent', D('parallelResistors'));
near(s.quantities.find((x) => x.id === 'sourceCurrent').value, 12 / 1000 + 12 / 2000, 1e-12);
s = E.solve('theveninNorton', 'load', D('theveninNorton'));
near(s.quantities.find((x) => x.id === 'vth').value, 6, 1e-12);
near(s.quantities.find((x) => x.id === 'rth').value, 500, 1e-9);
near(s.quantities.find((x) => x.id === 'vl').value, 4, 1e-9);
s = E.solve('rcStep', 'voltage', D('rcStep'));
near(s.quantities.find((x) => x.id === 'vt').value, 5 * (1 - Math.exp(-1)), 1e-9);
s = E.solve('rlStep', 'current', D('rlStep'));
near(s.quantities.find((x) => x.id === 'current').value, 0.1 * (1 - Math.exp(-1)), 1e-9);
s = E.solve('firstOrderFilter', 'cutoff', D('firstOrderFilter'));
near(s.quantities.find((x) => x.id === 'fc').value, 1 / (2 * Math.PI * 1e4 * 1e-8), 1e-6);
s = E.solve('seriesRLC', 'response', D('seriesRLC'));
near(s.quantities.find((x) => x.id === 'f0').value, 1 / (2 * Math.PI * Math.sqrt(1e-3 * 1e-7)), 1e-6);
s = E.solve('ledSeries', 'resistance', D('ledSeries'));
near(s.quantities.find((x) => x.id === 'r').value, 150, 1e-9);

/* DC filter and RLC: capacitor open, no phantom current */
s = E.solve('firstOrderFilter', 'cutoff', Object.assign({}, D('firstOrderFilter'), { source: 'dc', kind: 'highpass' }));
near(s.nodes.find((x) => x.id === 'out').value, 0, 0, 'DC high-pass blocks');
s = E.solve('seriesRLC', 'response', Object.assign({}, D('seriesRLC'), { source: 'dc' }));
near(s.branches[0].value, 0, 0, 'RLC DC current');

/* errors are plain English */
assert.throws(() => E.solve('seriesResistors', 'current', { vs: '12', r1: '', r2: '1k' }), /Need R1/);
assert.throws(() => E.solve('seriesResistors', 'r1', { vs: '12', i: '1', r2: '1k' }), /R1 would not be positive/);
assert.throws(() => E.solve('seriesResistors', 'bogus', D('seriesResistors')), /not on this circuit/);
assert.throws(() => E.solve('voltageDivider', 'r1', { vin: '5', vout: '6', r2: '1k' }), /less than Vin/);
assert.throws(() => E.solve('rcStep', 'time', Object.assign({}, D('rcStep'), { vt: '9' })), /strictly between/);
assert.ok(!E.solveSafe('seriesResistors', 'current', { vs: '0', r1: '1', r2: '1' }).ok);

/* every circuit x every unknown solves with its defaults and yields an audited board */
for (const id of E.circuits()) {
  const spec = E.specOf(id);
  assert.ok(E.FAMILIES.some((f) => f.id === spec.family), id + ' family');
  assert.ok(spec.unknowns.some((u) => u.id === spec.defaultUnknown), id + ' default unknown');
  for (const u of spec.unknowns) {
    const r = E.solveSafe(id, u.id, spec.defaults);
    assert.ok(r.ok, `${id}/${u.id}: ${r.error}`);
    const sol = r.solution;
    assert.ok(sol.layout, id + ' has a breadboard');
    assert.ok(sol.layout.audit.ok, `${id}/${u.id} audit ${JSON.stringify(sol.layout.audit)}`);
    assert.ok(E.visibleFields(id, u.id, spec.defaults).length >= 2, id + ' fields');
    assert.ok(R.renderSchematic(sol).startsWith('<svg'));
    assert.ok(R.renderBreadboard(sol.layout, { pitch: 14 }).includes('class="eb-svg eb-breadboard"'));
    assert.ok(sol.layout.meters.length >= 1, id + ' meters');
  }
}

/* audit catches mistakes: a short, an off-board hole, and a split net */
{
  const sol = E.solve('seriesResistors', 'current', D('seriesResistors'));
  const bad = JSON.parse(JSON.stringify(sol.layout));
  bad.jumpers.push({ id: 'oops', net: 'Vs', a: { column: 14, row: 'a' }, b: { column: 30, row: 'topPlus' }, color: 'red' });
  assert.ok(!E.auditBoard(bad).ok && E.auditBoard(bad).shorts.length >= 1, 'short is caught');
  const off = JSON.parse(JSON.stringify(sol.layout));
  off.jumpers[0].a.column = 40;
  assert.ok(E.auditBoard(off).faults.some((f) => /off the board/.test(f)), 'off-board is caught');
  const split = JSON.parse(JSON.stringify(sol.layout));
  split.jumpers = split.jumpers.filter((j) => j.id !== 'vs');
  assert.ok(E.auditBoard(split).opens.length >= 1, 'open is caught');
}

/* renderer: retina-safe SVG, app palette, band colors, escaped text */
{
  const sol = E.solve('voltageDivider', 'vout', D('voltageDivider'));
  const svg = R.renderBreadboard(sol.layout, { pitch: 20 });
  assert.match(svg, /viewBox="0 0 /);
  assert.match(svg, /#E4C99A/, 'resistor body');
  assert.match(svg, /#D4AF37/, 'gold tolerance band');
  assert.match(svg, /#E4DDD2/, 'board');
  const sch = R.renderSchematic(sol);
  assert.match(sch, /#40BAD6/, 'app accent');
  assert.match(sch, /viewBox="0 0 400 320"/);
  assert.ok(!/<script/i.test(R.renderSchematic(sol, { layer: 'minimal' })));
}

/* site wiring: section, scripts, service worker, registry, SEO, sitemap page, search */
const html = fs.readFileSync(path.join(root, 'public/toolbox/classic/index.html'), 'utf8');
assert.match(html, /id="sec-electronics-bench"/);
assert.match(html, /id="eb-root"/);
assert.match(html, /data-target="sec-electronics-bench"/);
assert.match(html, /href="#sec-electronics-bench"/);
for (const f of ['electronics-bench-engine.js', 'electronics-bench-render.js', 'electronics-bench.js']) {
  assert.ok(html.includes('js/' + f), f + ' loaded by classic page');
  assert.ok(fs.readFileSync(path.join(root, 'public/toolbox/sw.js'), 'utf8').includes('./js/' + f), f + ' precached');
}
assert.ok(html.indexOf('electronics-bench-engine.js') < html.indexOf('electronics-bench-render.js'));
assert.ok(html.indexOf('electronics-bench-render.js') < html.indexOf('js/electronics-bench.js'));
const reg = fs.readFileSync(path.join(root, 'src/data/toolbox-registry.mjs'), 'utf8');
assert.match(reg, /toolId: "electronicsLab"[^\n]*availability: "web"[^\n]*slug: "electronics-bench"/);
assert.match(fs.readFileSync(path.join(root, 'src/data/toolbox-tools.mjs'), 'utf8'), /\["electronics-bench"/);
assert.match(fs.readFileSync(path.join(root, 'src/data/seo-copy.mjs'), 'utf8'), /"electronics-bench": "Breadboard generator/);
assert.match(fs.readFileSync(path.join(root, 'src/pages/sitemap.tsx'), 'utf8'), /sec-electronics-bench/);
assert.match(fs.readFileSync(path.join(root, 'src/lib/assistant/search.ts'), 'utf8'), /"electronics-bench"/);
console.log('electronics bench ok');
