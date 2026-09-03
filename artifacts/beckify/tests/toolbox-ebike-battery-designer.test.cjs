/* Beckify e-bike battery pack designer: S/P math, autofill, hit testing. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..', 'public', 'toolbox', 'js');
const sandbox = {
  console,
  Math,
  Number,
  String,
  Object,
  Array,
  JSON,
  parseFloat,
  isFinite,
  document: {
    readyState: 'complete',
    addEventListener() {},
    getElementById() { return null; },
  },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(
  fs.readFileSync(path.join(root, 'ebike-battery-designer.js'), 'utf8'),
  sandbox,
  { filename: 'ebike-battery-designer.js' }
);

const api = sandbox.__ebikeBatteryDesignerTestApi;
assert.ok(api, 'test API exported');

const filled = api.autoFillColumns(16, 12, 14, 10);
assert.equal(filled.error, null);
assert.equal(filled.grid.length, 12);
assert.equal(filled.grid[0].length, 16);

const analysis = api.analyzeLayout(filled.grid, {
  targetS: 14,
  targetP: 10,
  cellV: 3.6,
  cellAh: 2.5,
  cellA: 20,
  loadA: 40,
});
assert.equal(analysis.exactTarget, true);
assert.equal(analysis.architecture, '14S10P');
assert.equal(analysis.filled, 140);
assert.ok(Math.abs(analysis.nominalV - 50.4) < 1e-9);
assert.ok(Math.abs(analysis.capacityAh - 25) < 1e-9);
assert.ok(Math.abs(analysis.energyWh - 1260) < 1e-6);
assert.ok(Math.abs(analysis.packContinuousA - 200) < 1e-9);
assert.ok(Math.abs(analysis.perCellLoadA - 4) < 1e-9);
assert.equal(analysis.loadOk, true);

const tooSmall = api.autoFillColumns(5, 5, 14, 10);
assert.ok(tooSmall.error);

const unbalanced = api.emptyGrid(8, 8);
unbalanced[0][0] = 1;
unbalanced[0][1] = 1;
unbalanced[1][0] = 2;
const bad = api.analyzeLayout(unbalanced, {
  targetS: 2,
  targetP: 2,
  cellV: 3.6,
  cellAh: 2.5,
  cellA: 10,
});
assert.equal(bad.balanced, false);
assert.equal(bad.architecture, 'unbalanced');
assert.equal(bad.counts[0], 2);
assert.equal(bad.counts[1], 1);

const center = api.cellCenter(0, 0, 18.5, false, 20, 20);
assert.ok(center.radius > 0);
const hit = api.hitTest([[1]], center.x, center.y, 18.5, false, 20, 20);
assert.ok(hit);
assert.equal(hit.row, 0);
assert.equal(hit.col, 0);
assert.equal(api.hitTest([[1]], 0, 0, 18.5, false, 20, 20), null);

assert.equal(api.PACK_PRESETS['52v'].s, 14);
assert.equal(api.CELL_PRESETS['18650'].ah, 2.5);
assert.equal(api.CELL_PRESETS['18650'].l, 65.2);

const pack3d = api.buildPackCells(filled.grid, { cellD: 18.5, cellL: 65.2, honeycomb: false });
assert.equal(pack3d.cells.length, 140);
assert.ok(pack3d.span > 0);
const basis = api.cameraBasis(0.8, 0.4);
const eye = {
  x: pack3d.center.x - basis.forward.x * 400,
  y: pack3d.center.y - basis.forward.y * 400,
  z: pack3d.center.z - basis.forward.z * 400,
};
const projected = api.projectPoint(pack3d.cells[0], eye, basis, 300, 720, 420);
assert.ok(projected);
assert.ok(Number.isFinite(projected.x));
assert.ok(Number.isFinite(projected.y));
assert.ok(projected.z > 0);

const html = fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'index.html'), 'utf8');
assert.match(html, /id="ebd_canvas"/);
assert.match(html, /id="ebd_canvas_3d"/);
assert.match(html, /ebike-battery-designer\.js/);
assert.doesNotMatch(html, /href="https:\/\/batterydesigner\.com"/);

console.log('E-bike battery pack designer checks passed');
