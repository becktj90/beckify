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

/* diode family */
{
  const get = (sol, id) => sol.quantities.find((x) => x.id === id).value;
  let h = E.solve('halfWave', 'report', D('halfWave'));
  near(get(h, 'vpk'), 12 * Math.SQRT2 - 0.7, 1e-9, 'half-wave peak');
  near(get(h, 'vdcAvg'), (12 * Math.SQRT2 - 0.7) / Math.PI, 1e-9);
  near(get(h, 'ripple'), (get(h, 'vpk') / 100) / (60 * 1e-4), 1e-9, 'half-wave ripple');
  const b = E.solve('fullBridge', 'report', D('fullBridge'));
  near(get(b, 'vpk'), 12 * Math.SQRT2 - 1.4, 1e-9, 'bridge peak');
  near(get(b, 'vdcAvg'), 2 * get(b, 'vpk') / Math.PI, 1e-9);
  const bc = E.solve('fullBridge', 'c', D('fullBridge'));
  near(get(bc, 'ripple'), 0.5, 1e-9, 'C sized for 0.5 V ripple');
  const cl = E.solve('shuntClipper', 'report', D('shuntClipper'));
  near(get(cl, 'vout'), 0.7, 1e-12); near(get(cl, 'ipeak'), 9.3 / 1000, 1e-12);
  const cr = E.solve('shuntClipper', 'r', D('shuntClipper'));
  near(get(cr, 'r'), 930, 1e-9);
  const cp = E.solve('clamper', 'report', D('clamper'));
  near(get(cp, 'vmax'), 19.3, 1e-12); near(get(cp, 'vmin'), -0.7, 1e-12);
  assert.throws(() => E.solve('halfWave', 'c', Object.assign({}, D('halfWave'), { source: 'dc' })), /Ripple is zero/);
  assert.throws(() => E.solve('halfWave', 'report', Object.assign({}, D('halfWave'), { vrms: '0.3' })), /clears the diode drop/);
  for (const id of ['halfWave', 'fullBridge', 'shuntClipper']) {
    const dc = E.solve(id, 'report', Object.assign({}, D(id), { source: 'dc' }));
    assert.ok(dc.layout.audit.ok, id + ' DC audit ' + JSON.stringify(dc.layout.audit));
  }
  const biased = E.solve('shuntClipper', 'report', Object.assign({}, D('shuntClipper'), { vbias: '2' }));
  assert.ok(biased.layout.audit.ok, 'biased clipper audit ' + JSON.stringify(biased.layout.audit));
  near(get(biased, 'vout'), 2.7, 1e-12);
}

/* BJT and MOSFET family */
{
  const get = (sol, id) => sol.quantities.find((x) => x.id === id).value;
  const bias = E.solve('bjtBias', 'point', D('bjtBias'));
  const vbb = 12 * 10000 / 57000, rb = 1 / (1 / 47000 + 1 / 10000), ie = (vbb - 0.7) / (1000 + rb / 101);
  near(get(bias, 'ie'), ie, 1e-12); near(get(bias, 'ic'), ie * 100 / 101, 1e-12);
  near(get(bias, 'vce'), 12 - get(bias, 'ic') * 2200 - ie * 1000, 1e-9);
  const re = E.solve('bjtBias', 're', D('bjtBias'));
  near(get(E.solve('bjtBias', 'point', Object.assign({}, D('bjtBias'), { re: String(get(re, 're')) })), 'ic'), 0.001, 1e-9, 'Re round trip');
  const rcs = E.solve('bjtBias', 'rc', D('bjtBias'));
  near(get(E.solve('bjtBias', 'point', Object.assign({}, D('bjtBias'), { rc: String(get(rcs, 'rc')) })), 'vc'), 9, 1e-6, 'Rc round trip');
  assert.equal(E.solve('bjtBias', 'point', Object.assign({}, D('bjtBias'), { r2: '1000' })).warning.includes('cut off'), true);
  assert.ok(E.solve('bjtBias', 'point', Object.assign({}, D('bjtBias'), { rc: '20000', re: '100' })).warning.includes('saturation'));
  const ce = E.solve('ceAmp', 'gain', D('ceAmp'));
  near(get(ce, 'av'), -(get(ce, 'ic') / 0.026) * (1 / (1 / 2200 + 1 / 10000)), 1e-9, 'CE gain');
  const ceo = E.solve('ceAmp', 'gain', Object.assign({}, D('ceAmp'), { bypass: 'open' }));
  assert.ok(Math.abs(get(ceo, 'av')) < Math.abs(get(ce, 'av')));
  assert.ok(E.solve('ceAmp', 'rc', D('ceAmp')).quantities.find((x) => x.id === 'av').value < 0);
  const sw = E.solve('bjtSwitch', 'state', D('bjtSwitch'));
  near(get(sw, 'ic'), 11.8 / 1000, 1e-12); assert.equal(sw.headline, 'Saturated');
  assert.equal(E.solve('bjtSwitch', 'state', Object.assign({}, D('bjtSwitch'), { rb: '1000000' })).headline, 'Not saturated');
  assert.throws(() => E.solve('bjtSwitch', 'state', Object.assign({}, D('bjtSwitch'), { vin: '0.5' })), /above 0.7/);
  const cs = E.solve('csAmp', 'point', D('csAmp'));
  near(get(cs, 'id'), 0.5 * 0.02 * 1, 1e-12); near(get(cs, 'av'), -0.02 * 200, 1e-12);
  const csd = E.solve('csAmp', 'point', Object.assign({}, D('csAmp'), { rs: '100' }));
  const vov = get(csd, 'vgs') - 1; near(get(csd, 'id'), 0.01 * vov * vov, 1e-12);
  near(get(csd, 'vs'), get(csd, 'id') * 100, 1e-12);
  assert.ok(E.solve('csAmp', 'point', Object.assign({}, D('csAmp'), { vg: '0.5' })).warning.includes('Id = 0'));
  near(get(E.solve('csAmp', 'rd', D('csAmp')), 'av'), -4, 1e-9);
  const ms = E.solve('mosSwitch', 'state', D('mosSwitch'));
  near(get(ms, 'vds'), 12 / 100.05 * 0.05, 1e-12);
  assert.equal(E.solve('mosSwitch', 'state', Object.assign({}, D('mosSwitch'), { vgs: '1' })).headline, 'Off');
  near(get(E.solve('mosSwitch', 'rdson', D('mosSwitch')), 'rdson'), 100 * 0.1 / 11.9, 1e-12);
  const cm = E.solve('cmosInverter', 'threshold', D('cmosInverter'));
  near(get(cm, 'vm'), 2.5, 1e-12);
  near(get(E.solve('cmosInverter', 'vout', D('cmosInverter')), 'vout'), 5, 1e-12);
  near(get(E.solve('cmosInverter', 'vout', Object.assign({}, D('cmosInverter'), { vin: '4' })), 'vout'), 0, 1e-12);
  for (const id of ['bjtBias', 'ceAmp', 'bjtSwitch']) {
    const odd = E.solve(id, id === 'ceAmp' ? 'gain' : (id === 'bjtBias' ? 'point' : 'state'), Object.assign({}, D(id), { vcc: '5', beta: '250' }));
    assert.ok(odd.layout.audit.ok, id + ' audit at other values');
  }
  assert.ok(E.solve('csAmp', 'point', Object.assign({}, D('csAmp'), { rs: '100' })).layout.audit.ok, 'degenerated CS audit');
  const sch = R.renderSchematic(E.solve('cmosInverter', 'threshold', D('cmosInverter')));
  assert.ok(sch.includes('<path') && /A[0-9.]+ [0-9.]+ 0 1 0 /.test(sch), 'pmos bubble drawn');
}

/* op-amp family: golden values, clipping, audit */
{
  const get = (sol, id) => sol.quantities.find((x) => x.id === id).value;
  const ia = E.solve('invertingAmp', 'gain', D('invertingAmp'));
  near(get(ia, 'vout'), -2, 1e-12);
  const clip = E.solve('invertingAmp', 'gain', Object.assign({}, D('invertingAmp'), { vin: '5' }));
  near(get(clip, 'vout'), -12, 1e-12); assert.ok(clip.warning, 'clip warns');
  near(get(E.solve('invertingAmp', 'rf', D('invertingAmp')), 'rf'), 100000, 1e-6);
  near(get(E.solve('invertingAmp', 'vin', D('invertingAmp')), 'vin'), 0.2, 1e-12);
  near(get(E.solve('nonInvertingAmp', 'gain', D('nonInvertingAmp')), 'vout'), 2, 1e-12);
  near(get(E.solve('nonInvertingAmp', 'rf', D('nonInvertingAmp')), 'rf'), 90000, 1e-6);
  assert.throws(() => E.solve('nonInvertingAmp', 'rf', Object.assign({}, D('nonInvertingAmp'), { av: '1' })), /greater than 1/);
  near(get(E.solve('summingAmp', 'output', D('summingAmp')), 'vout'), -2, 1e-12);
  near(get(E.solve('summingAmp', 'rf', D('summingAmp')), 'rf'), 10000, 1e-6);
  near(get(E.solve('diffAmp', 'output', D('diffAmp')), 'vout'), 0.2, 1e-12);
  near(get(E.solve('integrator', 'ramp', D('integrator')), 'vt'), -1, 1e-12);
  near(get(E.solve('integrator', 'time', D('integrator')), 'time'), 0.1, 1e-12);
  near(get(E.solve('integrator', 'c', D('integrator')), 'c'), 1e-6, 1e-15);
  near(get(E.solve('differentiator', 'output', D('differentiator')), 'vout'), -1, 1e-12);
  near(get(E.solve('differentiator', 'r', D('differentiator')), 'r'), 10000, 1e-6);
  assert.equal(E.solve('comparator', 'output', D('comparator')).headline, 'Output high');
  assert.equal(E.solve('comparator', 'output', Object.assign({}, D('comparator'), { vin: '1' })).headline, 'Output low');
  for (const id of ['invertingAmp', 'nonInvertingAmp', 'summingAmp', 'diffAmp', 'integrator', 'differentiator', 'comparator']) {
    const sol = E.solve(id, E.SPECS.find((x) => x.id === id).defaultUnknown, D(id));
    assert.ok(sol.layout.audit.ok, id + ' audit: ' + JSON.stringify(sol.layout.audit));
    assert.ok(R.renderSchematic(sol).includes('<text'), id + ' schematic');
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
