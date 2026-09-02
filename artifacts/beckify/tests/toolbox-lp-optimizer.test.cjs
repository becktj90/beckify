/* Linear-programming optimizer — two-phase simplex and 2-var geometry. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const sandbox = {
  console,
  Math,
  Number,
  String,
  Object,
  Array,
  JSON,
  isFinite,
  parseFloat,
  parseInt,
  setTimeout,
  clearTimeout,
  document: {
    getElementById() { return null; },
    querySelector() { return null; },
    addEventListener() {},
    readyState: 'complete',
  },
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(
  fs.readFileSync(path.join(__dirname, '..', 'public', 'toolbox', 'js', 'lp-optimizer.js'), 'utf8'),
  sandbox,
  { filename: 'lp-optimizer.js' }
);

const api = sandbox.__lpOptimizerTestApi;
assert.ok(api && typeof api.solveLP === 'function', 'test API exported');

function almost(a, b, tol) {
  const t = tol == null ? 1e-6 : tol;
  assert.ok(Math.abs(a - b) <= t, 'expected ' + b + ' got ' + a);
}

/* ── Known 2-var optimum: max 5x + 4y  s.t. 6x+4y≤24, x+2y≤6, x,y≥0
   Unique vertex optimum is (3, 1.5), z = 21. ── */
{
  const r = api.solveLP({
    sense: 'max',
    c: [5, 4],
    constraints: [
      { a: [6, 4], op: '<=', b: 24 },
      { a: [1, 2], op: '<=', b: 6 },
    ],
  });
  assert.equal(r.status, 'optimal', '2-var graphical example is optimal, got ' + r.status + ' ' + r.message);
  almost(r.x[0], 3);
  almost(r.x[1], 1.5);
  almost(r.objective, 21);

  const g = api.feasibleRegion2D({
    sense: 'max', c: [5, 4],
    constraints: [
      { a: [6, 4], op: '<=', b: 24 },
      { a: [1, 2], op: '<=', b: 6 },
    ],
  });
  assert.ok(g.ok, 'feasible region found');
  almost(g.optimal.x, 3, 1e-5);
  almost(g.optimal.y, 1.5, 1e-5);
  almost(g.optimal.z, 21, 1e-5);
}

/* ── Product-mix preset: (40, 20), z = 2200 ── */
{
  const p = api.PRESETS.mix;
  const r = api.solveLP({
    sense: p.sense, c: p.c,
    constraints: p.constraints,
    bounds: p.hi.map((hi) => ({ lo: 0, hi: hi })),
  });
  assert.equal(r.status, 'optimal');
  almost(r.x[0], 40);
  almost(r.x[1], 20);
  almost(r.objective, 2200);
}

/* ── Blending / cheapest kW mix: grid 300 + diesel 60 + battery 40, z = 41.2 ── */
{
  const p = api.PRESETS.blend;
  const r = api.solveLP({
    sense: p.sense, c: p.c,
    constraints: p.constraints,
    bounds: p.hi.map((hi) => ({ lo: 0, hi: hi })),
  });
  assert.equal(r.status, 'optimal', 'blend status ' + r.status + ' ' + r.message);
  almost(r.x[0], 300, 1e-4);
  almost(r.x[1], 60, 1e-4);
  almost(r.x[2], 40, 1e-4);
  almost(r.objective, 41.2, 1e-4);
}

/* ── Infeasible: x + y ≤ 1 and x + y ≥ 3 ── */
{
  const r = api.solveLP({
    sense: 'max',
    c: [1, 1],
    constraints: [
      { a: [1, 1], op: '<=', b: 1 },
      { a: [1, 1], op: '>=', b: 3 },
    ],
  });
  assert.equal(r.status, 'infeasible', 'expected infeasible, got ' + r.status);
}

/* ── Unbounded: max x + y  s.t.  x − y ≤ 1, x,y ≥ 0 ── */
{
  const r = api.solveLP({
    sense: 'max',
    c: [1, 1],
    constraints: [
      { a: [1, -1], op: '<=', b: 1 },
    ],
  });
  assert.equal(r.status, 'unbounded', 'expected unbounded, got ' + r.status + ' z=' + r.objective);
}

/* ── Minimize with equality (2-var blending): min 8x + 6y, x+y=100, x≥30, y≥20 → (30, 70), z=660 ── */
{
  const r = api.solveLP({
    sense: 'min',
    c: [8, 6],
    constraints: [
      { a: [1, 1], op: '=', b: 100 },
      { a: [1, 0], op: '>=', b: 30 },
      { a: [0, 1], op: '>=', b: 20 },
    ],
  });
  assert.equal(r.status, 'optimal', r.message);
  almost(r.x[0], 30);
  almost(r.x[1], 70);
  almost(r.objective, 660);
}

/* ── Bounds-only 2-var: max 3x+2y, x≤4, y≤3, x,y≥0. No DOM rows — upper bounds are the constraints. ── */
{
  const problem = {
    sense: 'max',
    names: ['x1', 'x2'],
    c: [3, 2],
    constraints: [],
    bounds: [{ lo: 0, hi: 4 }, { lo: 0, hi: 3 }],
  };
  const expanded = api.expandConstraintSet(problem);
  assert.ok(expanded.constraints.length >= 2, 'upper bounds become constraint rows');
  assert.ok(expanded.constraints.some((row) => row.op === '<=' && row.a[0] === 1 && row.a[1] === 0 && row.b === 4), 'x1 ≤ 4 row');
  assert.ok(expanded.constraints.some((row) => row.op === '<=' && row.a[0] === 0 && row.a[1] === 1 && row.b === 3), 'x2 ≤ 3 row');

  const text = api.formulationText(problem);
  assert.match(text, /x1 max/);
  assert.match(text, /x2 max/);
  assert.match(text, /4/);
  assert.match(text, /3/);

  const r = api.solveLP(problem);
  assert.equal(r.status, 'optimal', r.message);
  almost(r.x[0], 4);
  almost(r.x[1], 3);
  almost(r.objective, 18);
  assert.ok(r.constraints.some((row) => row.label === 'x1 max' && row.b === 4));
  assert.ok(r.constraints.some((row) => row.label === 'x2 max' && row.b === 3));

  const g = api.feasibleRegion2D(problem);
  assert.ok(g.ok, 'feasible region from bound rows only');
  assert.ok(g.constraints.length >= 2, 'plot uses expanded bound constraints');
  assert.ok(g.vertices.some((p) => Math.abs(p.x - 4) < 1e-5 && Math.abs(p.y - 3) < 1e-5), 'vertex (4, 3) present');
  assert.ok(g.vertices.some((p) => Math.abs(p.x) < 1e-5 && Math.abs(p.y) < 1e-5), 'origin present');
  almost(g.optimal.x, 4, 1e-5);
  almost(g.optimal.y, 3, 1e-5);
}

/* ── Unbounded 2-var keeps a region but does not label a fake optimum ── */
{
  const cap = api.visualCaption('unbounded', true);
  assert.ok(!/simplex optimum/i.test(cap), 'unbounded caption must not claim an optimum vertex');
  assert.match(cap, /not marked/);
  const optCap = api.visualCaption('optimal', true);
  assert.match(optCap, /simplex optimum vertex/);
}

console.log('LP optimizer verified: 2-var optimum (3, 1.5, z=21), product mix, kW blending, infeasible, unbounded, bound-only plot');
