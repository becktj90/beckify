/* ============================================================================
   LINEAR PROGRAMMING OPTIMIZER
   ============================================================================
   Educational two-phase simplex solver for small ordinary linear programs:

     maximize or minimize  c · x
     subject to            A_i x  { ≤, ≥, = }  b_i
                           0 ≤ x_j ≤ u_j   (upper bounds optional)

   Phase I drives artificial variables to zero (detects infeasible).
   Phase II optimizes the original objective (detects unbounded).
   Bland's rule is used on both the entering column and the leaving row so
   degenerate problems cannot cycle.

   For two decision variables the feasible region is also drawn: constraint
   lines, corner vertices, and the optimum. For n > 2 the result is a labelled
   summary (status, objective, primal x, slack / surplus) rather than a raw
   tableau dump.

   This is ordinary operations-research linear programming — resource
   allocation, blending, and graphical 2-variable examples. It is not related
   to EMP, shielding, targeting, or weapon-yield work.
   ============================================================================ */

(function (global) {
  'use strict';

  const EPS = 1e-9;
  const MAX_ITERS = 256;
  const MAX_VARS = 6;
  const MAX_CONS = 8;
  const COLORS = {
    bg: '#0d1117', text: '#eef0fa', muted: '#9497b8',
    accent: '#8b7bff', blue: '#60a5fa', green: '#6ee7b7',
    yellow: '#f5c451', red: '#ff8a8a', line: 'rgba(255,255,255,0.14)',
  };

  /* -------------------------------------------------------------------------
     Presets — generic OR, with one field-EE source-mix blending example.
     ------------------------------------------------------------------------- */
  const PRESETS = {
    mix: {
      label: 'Product mix',
      sense: 'max',
      names: ['Widget A', 'Widget B'],
      c: [40, 30],
      hi: [null, null],
      units: ['units', 'units'],
      objUnit: '$ profit',
      constraints: [
        { a: [2, 1], op: '<=', b: 100, label: 'Labor (h)' },
        { a: [1, 2], op: '<=', b: 80, label: 'Machine (h)' },
      ],
      note: 'Maximize profit from two products sharing labor and machine hours. Optimum is 40 of A and 20 of B (z = $2,200).',
    },
    blend: {
      label: 'Source mix (kW)',
      sense: 'min',
      names: ['Grid', 'Diesel', 'Battery'],
      c: [0.08, 0.14, 0.22],
      hi: [300, 200, 120],
      units: ['kW', 'kW', 'kW'],
      objUnit: '$ / h',
      constraints: [
        { a: [1, 1, 1], op: '=', b: 400, label: 'Meet load (kW)' },
        { a: [0, 0, 1], op: '>=', b: 40, label: 'Min battery (kW)' },
      ],
      note: 'Cheapest mix of grid, diesel, and battery power to serve a 400 kW load, with a 40 kW battery-floor and per-source kW caps. Generic OR blending — not a protection or EMP study.',
    },
    graph: {
      label: 'Graphical 2-var',
      sense: 'max',
      names: ['x1', 'x2'],
      c: [5, 4],
      hi: [null, null],
      units: ['', ''],
      objUnit: '',
      constraints: [
        { a: [6, 4], op: '<=', b: 24, label: 'Resource A' },
        { a: [1, 2], op: '<=', b: 6, label: 'Resource B' },
      ],
      note: 'Textbook 2-variable LP. Feasible polygon vertices: (0,0), (4,0), (3, 1.5), (0,3). Optimum is (3, 1.5) with z = 21.',
    },
  };

  /* -------------------------------------------------------------------------
     Two-phase simplex
     ------------------------------------------------------------------------- */

  function isFiniteNum(v) {
    return typeof v === 'number' && isFinite(v);
  }

  function zeros(n) {
    const a = new Array(n);
    for (let i = 0; i < n; i++) a[i] = 0;
    return a;
  }

  function cloneRow(row) {
    return row.slice();
  }

  /**
   * Turn optional finite bounds into extra inequality rows. The UI (formulation,
   * empty-constraint check, 2-var plot) and the solver share this expansion so
   * an upper bound is never a silent extra that the picture ignores.
   */
  function expandConstraintSet(problem) {
    const n = (problem.c || []).length;
    const names = (problem.names || []).slice();
    while (names.length < n) names.push('x' + (names.length + 1));
    const bounds = (problem.bounds || []).slice();
    while (bounds.length < n) bounds.push({ lo: 0, hi: null });

    const constraints = [];
    (problem.constraints || []).forEach((row, idx) => {
      if (!row) return;
      const a = (row.a || []).slice(0, n);
      while (a.length < n) a.push(0);
      if (!a.every(isFiniteNum) || !isFiniteNum(Number(row.b))) return;
      const op = row.op === '>=' || row.op === '=' ? row.op : '<=';
      constraints.push({ a: a, op: op, b: Number(row.b), label: row.label || ('C' + (idx + 1)) });
    });

    for (let j = 0; j < n; j++) {
      const lo = bounds[j] && isFiniteNum(bounds[j].lo) ? bounds[j].lo : 0;
      const hi = bounds[j] && isFiniteNum(bounds[j].hi) ? bounds[j].hi : null;
      if (lo < -EPS) {
        return { error: 'This solver requires x ≥ 0. Use a lower bound of 0 or greater.', names: names, constraints: constraints };
      }
      if (lo > EPS) {
        const a = zeros(n); a[j] = 1;
        constraints.push({ a: a, op: '>=', b: lo, label: names[j] + ' min' });
      }
      if (hi != null) {
        if (hi < lo - EPS) {
          return { error: 'Upper bound of ' + names[j] + ' is below its lower bound.', names: names, constraints: constraints };
        }
        const a = zeros(n); a[j] = 1;
        constraints.push({ a: a, op: '<=', b: hi, label: names[j] + ' max' });
      }
    }
    return { names: names, constraints: constraints };
  }

  /**
   * Solve a small LP. Returns a plain result object; never throws for
   * infeasible / unbounded (those are statuses).
   *
   * @param {object} problem
   * @param {string} problem.sense  'max' | 'min'
   * @param {number[]} problem.c    objective coefficients (length n)
   * @param {Array<{a:number[], op:string, b:number, label?:string}>} problem.constraints
   * @param {Array<{lo?:number, hi?:number|null}>} [problem.bounds]
   * @param {string[]} [problem.names]
   */
  function solveLP(problem) {
    const sense = problem.sense === 'min' ? 'min' : 'max';
    const c = (problem.c || []).map(Number);
    const n = c.length;
    if (n < 1) return { status: 'error', message: 'Enter at least one decision variable.' };
    if (!c.every(isFiniteNum)) return { status: 'error', message: 'Objective coefficients must be finite numbers.' };

    const expanded = expandConstraintSet({ sense: sense, c: c, names: problem.names, constraints: problem.constraints, bounds: problem.bounds });
    if (expanded.error) return { status: 'error', message: expanded.error };
    const names = expanded.names;
    const cons = expanded.constraints;

    const origCons = cons.slice();

    if (cons.length === 0) {
      // Only x ≥ 0. Origin is feasible; unbounded if any improving ray exists.
      const objAtZero = 0;
      if (sense === 'max') {
        for (let j = 0; j < n; j++) {
          if (c[j] > EPS) return finishUnbounded(sense, c, names, origCons, zeros(n));
        }
      } else {
        for (let j = 0; j < n; j++) {
          if (c[j] < -EPS) return finishUnbounded(sense, c, names, origCons, zeros(n));
        }
      }
      return finishOptimal(sense, c, names, origCons, zeros(n), objAtZero, []);
    }

    // Convert each constraint to equality with slack / surplus / artificial, b ≥ 0.
    const processed = cons.map((row) => {
      let a = row.a.slice();
      let b = row.b;
      let op = row.op;
      if (b < 0) {
        a = a.map((v) => -v);
        b = -b;
        if (op === '<=') op = '>=';
        else if (op === '>=') op = '<=';
      }
      return { a: a, op: op, b: b, label: row.label };
    });

    const nSlack = processed.filter((p) => p.op === '<=' || p.op === '>=').length;
    const nArt = processed.filter((p) => p.op === '>=' || p.op === '=').length;
    const m = processed.length;
    const total = n + nSlack + nArt;
    const slackNames = [];
    const artNames = [];
    const colKind = new Array(total); // 'orig' | 'slack' | 'surplus' | 'art'
    for (let j = 0; j < n; j++) colKind[j] = 'orig';

    const M = [];
    const rhs = [];
    const basis = [];
    const artCols = [];
    const slackOfRow = []; // original-constraint index → slack/surplus column or -1
    let sCol = n;
    let aCol = n + nSlack;

    processed.forEach((p, i) => {
      const row = zeros(total);
      for (let j = 0; j < n; j++) row[j] = p.a[j];
      rhs[i] = p.b;
      if (p.op === '<=') {
        row[sCol] = 1;
        colKind[sCol] = 'slack';
        slackNames[sCol] = 's' + (i + 1);
        slackOfRow[i] = sCol;
        basis[i] = sCol;
        sCol += 1;
      } else if (p.op === '>=') {
        row[sCol] = -1;
        colKind[sCol] = 'surplus';
        slackNames[sCol] = 'e' + (i + 1);
        slackOfRow[i] = sCol;
        sCol += 1;
        row[aCol] = 1;
        colKind[aCol] = 'art';
        artNames[aCol] = 'a' + (i + 1);
        artCols.push(aCol);
        basis[i] = aCol;
        aCol += 1;
      } else {
        slackOfRow[i] = -1;
        row[aCol] = 1;
        colKind[aCol] = 'art';
        artNames[aCol] = 'a' + (i + 1);
        artCols.push(aCol);
        basis[i] = aCol;
        aCol += 1;
      }
      M.push(row);
    });

    const artSet = {};
    artCols.forEach((j) => { artSet[j] = true; });

    function objectiveValue(objCoeffs) {
      let z = 0;
      for (let i = 0; i < m; i++) z += (objCoeffs[basis[i]] || 0) * rhs[i];
      return z;
    }

    function reducedCosts(objCoeffs) {
      const red = objCoeffs.slice();
      for (let i = 0; i < m; i++) {
        const cb = objCoeffs[basis[i]] || 0;
        if (Math.abs(cb) < EPS) continue;
        const row = M[i];
        for (let j = 0; j < total; j++) red[j] -= cb * row[j];
      }
      return red;
    }

    function pivot(pr, pc) {
      const piv = M[pr][pc];
      const prow = M[pr];
      for (let j = 0; j < total; j++) prow[j] /= piv;
      rhs[pr] /= piv;
      for (let i = 0; i < m; i++) {
        if (i === pr) continue;
        const f = M[i][pc];
        if (Math.abs(f) < EPS) continue;
        const row = M[i];
        for (let j = 0; j < total; j++) row[j] -= f * prow[j];
        rhs[i] -= f * rhs[pr];
        // Snap near-zeros so the ratio test does not chase noise.
        if (Math.abs(rhs[i]) < 1e-12) rhs[i] = 0;
      }
      basis[pr] = pc;
    }

    function runSimplex(objCoeffs, forbidArt) {
      for (let iter = 0; iter < MAX_ITERS; iter++) {
        const red = reducedCosts(objCoeffs);
        let entering = -1;
        for (let j = 0; j < total; j++) {
          if (forbidArt && artSet[j]) continue;
          if (red[j] > EPS) { entering = j; break; } // Bland: smallest index
        }
        if (entering === -1) {
          return { status: 'optimal', z: objectiveValue(objCoeffs), iters: iter };
        }
        let leaving = -1;
        let bestRatio = Infinity;
        for (let i = 0; i < m; i++) {
          const aij = M[i][entering];
          if (aij > EPS) {
            const ratio = rhs[i] / aij;
            if (ratio < -EPS) continue; // numerical guard
            if (ratio < bestRatio - EPS || (Math.abs(ratio - bestRatio) <= EPS && (leaving === -1 || i < leaving))) {
              bestRatio = ratio;
              leaving = i;
            }
          }
        }
        if (leaving === -1) return { status: 'unbounded', z: objectiveValue(objCoeffs), iters: iter };
        pivot(leaving, entering);
      }
      return { status: 'iteration-limit', z: objectiveValue(objCoeffs) };
    }

    // Phase I: maximize −Σ artificials  (i.e. drive them to zero).
    const phase1 = zeros(total);
    artCols.forEach((j) => { phase1[j] = -1; });
    const p1 = runSimplex(phase1, false);
    if (p1.status === 'iteration-limit') {
      return { status: 'error', message: 'Simplex hit the iteration limit in phase I.' };
    }
    const artSum = -p1.z; // because z = −Σ a_i
    if (p1.status === 'unbounded' || artSum > 1e-6) {
      return {
        status: 'infeasible',
        message: 'No feasible solution: the constraints cannot be satisfied with x ≥ 0.',
        sense: sense, names: names, c: c, constraints: origCons,
      };
    }

    // Drop any leftover artificial that is basic at ~0 (redundant row).
    for (let i = 0; i < m; i++) {
      if (!artSet[basis[i]]) continue;
      if (Math.abs(rhs[i]) > 1e-6) {
        return {
          status: 'infeasible',
          message: 'No feasible solution: the constraints cannot be satisfied with x ≥ 0.',
          sense: sense, names: names, c: c, constraints: origCons,
        };
      }
      let pc = -1;
      for (let j = 0; j < total; j++) {
        if (artSet[j]) continue;
        if (Math.abs(M[i][j]) > EPS) { pc = j; break; }
      }
      if (pc !== -1) pivot(i, pc);
    }

    // Phase II: maximize c·x (or −c·x when minimizing).
    const phase2 = zeros(total);
    for (let j = 0; j < n; j++) phase2[j] = sense === 'max' ? c[j] : -c[j];
    const p2 = runSimplex(phase2, true);
    if (p2.status === 'iteration-limit') {
      return { status: 'error', message: 'Simplex hit the iteration limit in phase II.' };
    }

    const x = zeros(n);
    const extra = zeros(total);
    for (let i = 0; i < m; i++) {
      extra[basis[i]] = Math.max(0, rhs[i]);
      if (basis[i] < n) x[basis[i]] = Math.max(0, rhs[i]);
    }
    // Snap tiny noise.
    for (let j = 0; j < n; j++) {
      if (Math.abs(x[j]) < 1e-10) x[j] = 0;
    }

    if (p2.status === 'unbounded') {
      return finishUnbounded(sense, c, names, origCons, x);
    }

    const z = dot(c, x);
    const slacks = origCons.map((row, i) => {
      const ax = dot(row.a, x);
      let slack = 0;
      let kind = 'equality residual';
      if (row.op === '<=') { slack = row.b - ax; kind = 'slack'; }
      else if (row.op === '>=') { slack = ax - row.b; kind = 'surplus'; }
      else { slack = ax - row.b; kind = 'equality residual'; }
      if (Math.abs(slack) < 1e-8) slack = 0;
      return { label: row.label, kind: kind, value: slack, ax: ax, b: row.b, op: row.op };
    });

    return finishOptimal(sense, c, names, origCons, x, z, slacks);
  }

  function dot(a, b) {
    let s = 0;
    const n = Math.min(a.length, b.length);
    for (let i = 0; i < n; i++) s += a[i] * b[i];
    return s;
  }

  function finishOptimal(sense, c, names, cons, x, z, slacks) {
    return {
      status: 'optimal',
      sense: sense, c: c, names: names, constraints: cons,
      x: x, objective: z, slacks: slacks,
      message: 'Optimal feasible solution.',
    };
  }

  function finishUnbounded(sense, c, names, cons, x) {
    return {
      status: 'unbounded',
      sense: sense, c: c, names: names, constraints: cons,
      x: x, objective: null,
      message: 'Unbounded: the objective can be improved without limit inside the feasible region.',
    };
  }

  /* -------------------------------------------------------------------------
     2-variable feasible-region geometry
     ------------------------------------------------------------------------- */

  function feasiblePoint(p, constraints) {
    if (p.x < -1e-8 || p.y < -1e-8) return false;
    return constraints.every((row) => {
      const a0 = row.a[0] || 0;
      const a1 = row.a[1] || 0;
      const v = a0 * p.x + a1 * p.y;
      if (row.op === '<=') return v <= row.b + 1e-7;
      if (row.op === '>=') return v >= row.b - 1e-7;
      return Math.abs(v - row.b) <= 1e-7;
    });
  }

  function feasibleRegion2D(problem) {
    const c0 = problem.c[0] || 0;
    const c1 = problem.c[1] || 0;
    const expanded = expandConstraintSet(problem);
    const cons = (expanded.constraints || []).filter((row) => row && row.a);
    const lines = cons.map((row) => ({
      a: row.a[0] || 0, b: row.a[1] || 0, c: row.b, label: row.label || '',
    }));
    lines.push({ a: 1, b: 0, c: 0, axis: 'x1=0' });
    lines.push({ a: 0, b: 1, c: 0, axis: 'x2=0' });
    const pts = [];
    for (let i = 0; i < lines.length; i++) {
      for (let j = i + 1; j < lines.length; j++) {
        const L1 = lines[i], L2 = lines[j];
        const det = L1.a * L2.b - L2.a * L1.b;
        if (Math.abs(det) < EPS) continue;
        const x = (L1.c * L2.b - L2.c * L1.b) / det;
        const y = (L1.a * L2.c - L2.a * L1.c) / det;
        if (!isFinite(x) || !isFinite(y)) continue;
        pts.push({ x: x, y: y });
      }
    }
    const verts = [];
    pts.forEach((p) => {
      if (!feasiblePoint(p, cons)) return;
      const key = Math.round(p.x * 1e7) + ':' + Math.round(p.y * 1e7);
      if (!verts.some((q) => q.key === key)) {
        verts.push({ key: key, x: Math.max(0, p.x), y: Math.max(0, p.y) });
      }
    });
    if (!verts.length) return { ok: false, reason: 'No feasible corner points.', vertices: [] };
    const cx = verts.reduce((s, p) => s + p.x, 0) / verts.length;
    const cy = verts.reduce((s, p) => s + p.y, 0) / verts.length;
    verts.sort((p, q) => Math.atan2(p.y - cy, p.x - cx) - Math.atan2(q.y - cy, q.x - cx));
    verts.forEach((p) => { p.z = c0 * p.x + c1 * p.y; });
    let best = verts[0];
    verts.forEach((p) => {
      if (problem.sense === 'min') {
        if (p.z < best.z - EPS) best = p;
      } else if (p.z > best.z + EPS) best = p;
    });
    return { ok: true, vertices: verts, optimal: best, constraints: cons, c0: c0, c1: c1, sense: problem.sense };
  }

  /* -------------------------------------------------------------------------
     Formatting helpers
     ------------------------------------------------------------------------- */

  function fmtNum(n, digits) {
    if (n == null || !isFinite(n)) return '—';
    const d = digits == null ? 6 : digits;
    const abs = Math.abs(n);
    if (abs !== 0 && (abs >= 1e7 || abs < 1e-5)) return n.toExponential(4);
    let s = n.toFixed(d);
    s = s.replace(/\.?0+$/, '');
    return s === '-0' ? '0' : s;
  }

  function term(coeff, name, first) {
    const c = Number(coeff) || 0;
    if (Math.abs(c) < 1e-12) return first ? '0' : '';
    const mag = fmtNum(Math.abs(c), 4);
    const body = mag === '1' ? name : mag + ' ' + name;
    if (first) return (c < 0 ? '−' : '') + body;
    return (c < 0 ? ' − ' : ' + ') + body;
  }

  function expr(coeffs, names) {
    let out = '';
    let first = true;
    for (let j = 0; j < coeffs.length; j++) {
      if (Math.abs(Number(coeffs[j]) || 0) < 1e-12) continue;
      out += term(coeffs[j], names[j] || ('x' + (j + 1)), first);
      first = false;
    }
    return out || '0';
  }

  function formulationText(problem) {
    const expanded = expandConstraintSet(problem);
    const names = expanded.names;
    const verb = problem.sense === 'min' ? 'Minimize' : 'Maximize';
    const unit = problem.objUnit ? '   [' + problem.objUnit + ']' : '';
    let s = verb + '  z = ' + expr(problem.c, names) + unit + '\nsubject to\n';
    (expanded.constraints || []).forEach((row) => {
      const tag = row.label ? '   (' + row.label + ')' : '';
      s += '  ' + expr(row.a, names) + '  ' + row.op + '  ' + fmtNum(row.b, 4) + tag + '\n';
    });
    s += '  ' + names.join(', ') + ' ≥ 0';
    return s;
  }

  function visualCaption(status, graphOk) {
    if (!graphOk) return 'No 2-variable region to draw.';
    if (status === 'optimal') {
      return 'Feasible region in the x1–x2 plane. Green = feasible polygon, blue = constraint lines, yellow dashed = objective through the vertex optimum, red = simplex optimum vertex.';
    }
    return 'Feasible region in the x1–x2 plane. Green = feasible polygon, blue = constraint lines. The solver status is ' + status + ', so the objective line and optimum vertex are not marked.';
  }

  /* -------------------------------------------------------------------------
     SVG: feasible region
     ------------------------------------------------------------------------- */

  function svgEl(tag, attrs) {
    const el = document.createElementNS('http://www.w3.org/2000/svg', tag);
    Object.keys(attrs || {}).forEach((k) => el.setAttribute(k, String(attrs[k])));
    return el;
  }

  function renderFeasibleRegion(graph, problem) {
    const w = 520, h = 360;
    const svg = svgEl('svg', {
      viewBox: '0 0 ' + w + ' ' + h, width: '100%',
      role: 'img', focusable: 'false',
      'aria-label': 'Feasible region of the two-variable linear program',
    });
    svg.appendChild(svgEl('rect', { x: 0, y: 0, width: w, height: h, fill: COLORS.bg, rx: 8 }));
    if (!graph || !graph.ok) {
      const t = svgEl('text', { x: w / 2, y: h / 2, fill: COLORS.red, 'text-anchor': 'middle', 'font-size': 14, 'font-family': 'IBM Plex Mono, monospace' });
      t.textContent = (graph && graph.reason) || 'No feasible region';
      svg.appendChild(t);
      return svg;
    }

    const plotCons = (graph.constraints && graph.constraints.length)
      ? graph.constraints
      : (problem.constraints || []);
    const markOptimum = !!(graph.markOptimum && graph.optimal && isFinite(graph.optimal.z));
    let xmax = Math.max(1, ...graph.vertices.map((p) => p.x));
    let ymax = Math.max(1, ...graph.vertices.map((p) => p.y));
    plotCons.forEach((row) => {
      const a0 = row.a[0] || 0, a1 = row.a[1] || 0;
      if (Math.abs(a0) > EPS && row.b / a0 > 0) xmax = Math.max(xmax, row.b / a0);
      if (Math.abs(a1) > EPS && row.b / a1 > 0) ymax = Math.max(ymax, row.b / a1);
    });
    xmax *= 1.18; ymax *= 1.18;
    const padL = 48, padR = 16, padT = 20, padB = 36;
    const px = (x) => padL + x * (w - padL - padR) / xmax;
    const py = (y) => h - padB - y * (h - padT - padB) / ymax;

    svg.appendChild(svgEl('line', { x1: padL, y1: h - padB, x2: w - padR, y2: h - padB, stroke: COLORS.line, 'stroke-width': 1.5 }));
    svg.appendChild(svgEl('line', { x1: padL, y1: padT, x2: padL, y2: h - padB, stroke: COLORS.line, 'stroke-width': 1.5 }));
    const xLabel = svgEl('text', { x: w - padR, y: h - 10, fill: COLORS.muted, 'font-size': 11, 'text-anchor': 'end', 'font-family': 'IBM Plex Mono, monospace' });
    xLabel.textContent = problem.names[0] || 'x1';
    svg.appendChild(xLabel);
    const yLabel = svgEl('text', { x: 8, y: padT + 4, fill: COLORS.muted, 'font-size': 11, 'font-family': 'IBM Plex Mono, monospace' });
    yLabel.textContent = problem.names[1] || 'x2';
    svg.appendChild(yLabel);

    const ticks = 4;
    for (let i = 1; i <= ticks; i++) {
      const xv = xmax * i / ticks, yv = ymax * i / ticks;
      svg.appendChild(svgEl('line', { x1: px(xv), y1: h - padB, x2: px(xv), y2: h - padB + 4, stroke: COLORS.muted }));
      const tx = svgEl('text', { x: px(xv), y: h - 14, fill: COLORS.muted, 'font-size': 10, 'text-anchor': 'middle', 'font-family': 'IBM Plex Mono, monospace' });
      tx.textContent = fmtNum(xv, 2);
      svg.appendChild(tx);
      svg.appendChild(svgEl('line', { x1: padL - 4, y1: py(yv), x2: padL, y2: py(yv), stroke: COLORS.muted }));
      const ty = svgEl('text', { x: padL - 8, y: py(yv) + 3, fill: COLORS.muted, 'font-size': 10, 'text-anchor': 'end', 'font-family': 'IBM Plex Mono, monospace' });
      ty.textContent = fmtNum(yv, 2);
      svg.appendChild(ty);
    }

    plotCons.forEach((row, idx) => {
      const a0 = row.a[0] || 0, a1 = row.a[1] || 0, b = row.b;
      const pts = [];
      // Intersections with plot-window edges x=0, x=xmax, y=0, y=ymax.
      function addIf(x, y) {
        if (x >= -1e-9 && y >= -1e-9 && x <= xmax * 1.001 && y <= ymax * 1.001) pts.push({ x: x, y: y });
      }
      if (Math.abs(a1) > EPS) { addIf(0, b / a1); addIf(xmax, (b - a0 * xmax) / a1); }
      if (Math.abs(a0) > EPS) { addIf(b / a0, 0); addIf((b - a1 * ymax) / a0, ymax); }
      if (pts.length >= 2) {
        svg.appendChild(svgEl('line', {
          x1: px(pts[0].x), y1: py(pts[0].y), x2: px(pts[1].x), y2: py(pts[1].y),
          stroke: COLORS.blue, 'stroke-width': 1.4, 'stroke-dasharray': idx % 2 ? '5 4' : '0',
        }));
      }
    });

    const poly = graph.vertices.map((p) => px(p.x) + ',' + py(p.y)).join(' ');
    if (graph.vertices.length >= 3) {
      svg.appendChild(svgEl('polygon', { points: poly, fill: 'rgba(110,231,183,0.18)', stroke: COLORS.green, 'stroke-width': 2 }));
    } else if (graph.vertices.length === 2) {
      svg.appendChild(svgEl('line', {
        x1: px(graph.vertices[0].x), y1: py(graph.vertices[0].y),
        x2: px(graph.vertices[1].x), y2: py(graph.vertices[1].y),
        stroke: COLORS.green, 'stroke-width': 3,
      }));
    }

    if (markOptimum) {
      const z = graph.optimal.z;
      const c0 = problem.c[0] || 0;
      const c1 = problem.c[1] || 0;
      const objPts = [];
      if (Math.abs(c1) > EPS) {
        objPts.push({ x: 0, y: z / c1 });
        objPts.push({ x: xmax, y: (z - c0 * xmax) / c1 });
      } else if (Math.abs(c0) > EPS) {
        objPts.push({ x: z / c0, y: 0 });
        objPts.push({ x: z / c0, y: ymax });
      }
      if (objPts.length >= 2) {
        svg.appendChild(svgEl('line', {
          x1: px(objPts[0].x), y1: py(objPts[0].y),
          x2: px(objPts[1].x), y2: py(objPts[1].y),
          stroke: COLORS.yellow, 'stroke-width': 1.8, 'stroke-dasharray': '6 4',
        }));
      }
    }

    graph.vertices.forEach((p, i) => {
      const isOpt = markOptimum && p === graph.optimal;
      svg.appendChild(svgEl('circle', {
        cx: px(p.x), cy: py(p.y), r: isOpt ? 6 : 4,
        fill: isOpt ? COLORS.red : COLORS.text,
        stroke: isOpt ? '#fff' : 'none', 'stroke-width': isOpt ? 1.5 : 0,
      }));
      const t = svgEl('text', {
        x: px(p.x) + 8, y: py(p.y) - 8, fill: isOpt ? COLORS.yellow : COLORS.text,
        'font-size': 11, 'font-family': 'IBM Plex Mono, monospace',
      });
      t.textContent = 'V' + (i + 1) + ' (' + fmtNum(p.x, 2) + ', ' + fmtNum(p.y, 2) + ')';
      svg.appendChild(t);
    });
    return svg;
  }

  /* -------------------------------------------------------------------------
     DOM
     ------------------------------------------------------------------------- */

  function byId(id) { return document.getElementById(id); }

  function readProblemFromDom() {
    const n = Math.max(1, Math.min(MAX_VARS, parseInt((byId('orlp_nvars') || {}).value, 10) || 2));
    const m = Math.max(1, Math.min(MAX_CONS, parseInt((byId('orlp_ncons') || {}).value, 10) || 1));
    const sense = ((byId('orlp_sense') || {}).value) === 'min' ? 'min' : 'max';
    const names = [];
    const c = [];
    const bounds = [];
    const units = [];
    for (let j = 0; j < n; j++) {
      names.push(((byId('orlp_name_' + j) || {}).value || ('x' + (j + 1))).trim() || ('x' + (j + 1)));
      c.push(parseFloat((byId('orlp_c_' + j) || {}).value));
      const hiRaw = (byId('orlp_hi_' + j) || {}).value;
      const hi = hiRaw === '' || hiRaw == null ? null : parseFloat(hiRaw);
      bounds.push({ lo: 0, hi: isFiniteNum(hi) ? hi : null });
      units.push(((byId('orlp_unit_' + j) || {}).value || '').trim());
    }
    const constraints = [];
    for (let i = 0; i < m; i++) {
      const a = [];
      let any = false;
      for (let j = 0; j < n; j++) {
        const raw = (byId('orlp_a_' + i + '_' + j) || {}).value;
        const v = raw === '' || raw == null ? 0 : parseFloat(raw);
        if (raw !== '' && raw != null) any = true;
        a.push(v);
      }
      const bRaw = (byId('orlp_b_' + i) || {}).value;
      if (!any && (bRaw === '' || bRaw == null)) continue;
      constraints.push({
        a: a,
        op: ((byId('orlp_op_' + i) || {}).value) || '<=',
        b: parseFloat(bRaw),
        label: ((byId('orlp_clabel_' + i) || {}).value || ('C' + (i + 1))).trim(),
      });
    }
    return {
      sense: sense, names: names, c: c, bounds: bounds, units: units,
      objUnit: ((byId('orlp_objunit') || {}).value || '').trim(),
      constraints: constraints,
    };
  }

  function applyPreset(key) {
    const preset = PRESETS[key] || PRESETS.graph;
    const n = preset.c.length;
    const m = preset.constraints.length;
    if (byId('orlp_sense')) byId('orlp_sense').value = preset.sense;
    if (byId('orlp_nvars')) byId('orlp_nvars').value = String(n);
    if (byId('orlp_ncons')) byId('orlp_ncons').value = String(m);
    if (byId('orlp_objunit')) byId('orlp_objunit').value = preset.objUnit || '';
    syncGridVisibility();
    for (let j = 0; j < MAX_VARS; j++) {
      if (byId('orlp_name_' + j)) byId('orlp_name_' + j).value = preset.names[j] || ('x' + (j + 1));
      if (byId('orlp_c_' + j)) byId('orlp_c_' + j).value = j < n ? String(preset.c[j]) : '';
      if (byId('orlp_hi_' + j)) byId('orlp_hi_' + j).value = (preset.hi && preset.hi[j] != null) ? String(preset.hi[j]) : '';
      if (byId('orlp_unit_' + j)) byId('orlp_unit_' + j).value = (preset.units && preset.units[j]) || '';
    }
    for (let i = 0; i < MAX_CONS; i++) {
      const row = preset.constraints[i];
      if (byId('orlp_clabel_' + i)) byId('orlp_clabel_' + i).value = row ? (row.label || '') : '';
      if (byId('orlp_op_' + i)) byId('orlp_op_' + i).value = row ? row.op : '<=';
      if (byId('orlp_b_' + i)) byId('orlp_b_' + i).value = row ? String(row.b) : '';
      for (let j = 0; j < MAX_VARS; j++) {
        const el = byId('orlp_a_' + i + '_' + j);
        if (!el) continue;
        el.value = row && j < row.a.length ? String(row.a[j]) : '';
      }
    }
    const note = byId('orlp_preset_note');
    if (note) note.textContent = preset.note || '';
    solveAndRender();
  }

  function syncGridVisibility() {
    const n = Math.max(1, Math.min(MAX_VARS, parseInt((byId('orlp_nvars') || {}).value, 10) || 2));
    const m = Math.max(1, Math.min(MAX_CONS, parseInt((byId('orlp_ncons') || {}).value, 10) || 1));
    const cols = 'minmax(90px, 1.2fr) repeat(' + n + ', minmax(64px, 0.8fr)) 72px minmax(72px, 0.9fr)';
    for (let j = 0; j < MAX_VARS; j++) {
      const row = byId('orlp_varrow_' + j);
      if (row) row.hidden = j >= n;
      for (let i = 0; i < MAX_CONS; i++) {
        const cell = byId('orlp_acell_' + i + '_' + j);
        if (cell) cell.hidden = j >= n;
      }
    }
    for (let i = 0; i < MAX_CONS; i++) {
      const row = byId('orlp_conrow_' + i);
      if (row) {
        row.hidden = i >= m;
        row.style.gridTemplateColumns = cols;
      }
    }
    const head = byId('orlp_cons_head');
    if (head) {
      head.style.gridTemplateColumns = cols;
      Array.prototype.forEach.call(head.querySelectorAll('[data-orlp-var]'), (el) => {
        const j = parseInt(el.getAttribute('data-orlp-var'), 10);
        el.hidden = j >= n;
      });
    }
    const table = document.querySelector('#orlp_cons_host .orlp-cons-table');
    if (table) table.style.minWidth = (280 + n * 72) + 'px';
  }

  function buildGrids() {
    const varHost = byId('orlp_var_host');
    const consHost = byId('orlp_cons_host');
    if (!varHost || !consHost) return;
    if (varHost.getAttribute('data-built') === '1') return;
    varHost.setAttribute('data-built', '1');

    for (let j = 0; j < MAX_VARS; j++) {
      const row = document.createElement('div');
      row.className = 'orlp-var-row';
      row.id = 'orlp_varrow_' + j;
      row.innerHTML =
        '<div><label for="orlp_name_' + j + '">Variable ' + (j + 1) + '</label>' +
        '<input type="text" id="orlp_name_' + j + '" value="x' + (j + 1) + '" maxlength="24"></div>' +
        '<div><label for="orlp_c_' + j + '">c (objective)</label>' +
        '<input type="number" id="orlp_c_' + j + '" value="0" step="any"></div>' +
        '<div><label for="orlp_hi_' + j + '">Upper bound (blank = none)</label>' +
        '<input type="number" id="orlp_hi_' + j + '" placeholder="none" min="0" step="any"></div>' +
        '<div><label for="orlp_unit_' + j + '">Unit</label>' +
        '<input type="text" id="orlp_unit_' + j + '" placeholder="e.g. kW" maxlength="12"></div>';
      varHost.appendChild(row);
    }

    const table = document.createElement('div');
    table.className = 'orlp-cons-table';
    const head = document.createElement('div');
    head.className = 'orlp-cons-row orlp-cons-head';
    head.id = 'orlp_cons_head';
    let headHtml = '<span>Constraint</span>';
    for (let j = 0; j < MAX_VARS; j++) {
      headHtml += '<span data-orlp-var="' + j + '">a' + (j + 1) + '</span>';
    }
    headHtml += '<span>Op</span><span>b</span>';
    head.innerHTML = headHtml;
    table.appendChild(head);

    for (let i = 0; i < MAX_CONS; i++) {
      const row = document.createElement('div');
      row.className = 'orlp-cons-row';
      row.id = 'orlp_conrow_' + i;
      let html = '<input type="text" id="orlp_clabel_' + i + '" value="C' + (i + 1) + '" maxlength="24" aria-label="Constraint ' + (i + 1) + ' label">';
      for (let j = 0; j < MAX_VARS; j++) {
        html += '<span id="orlp_acell_' + i + '_' + j + '"><input type="number" id="orlp_a_' + i + '_' + j + '" step="any" aria-label="Constraint ' + (i + 1) + ' coefficient of variable ' + (j + 1) + '"></span>';
      }
      html += '<select id="orlp_op_' + i + '" aria-label="Constraint ' + (i + 1) + ' operator">' +
        '<option value="<=" selected>≤</option><option value=">=">≥</option><option value="=">=</option></select>';
      html += '<input type="number" id="orlp_b_' + i + '" step="any" aria-label="Constraint ' + (i + 1) + ' right-hand side">';
      row.innerHTML = html;
      table.appendChild(row);
    }
    consHost.appendChild(table);
  }

  function showError(msg) {
    const el = byId('orlp_result');
    if (!el) return;
    el.className = 'result error show';
    el.textContent = msg;
    const vis = byId('orlp_visual');
    if (vis) vis.innerHTML = '';
  }

  function solveAndRender() {
    if (!byId('orlp_result')) return;
    syncGridVisibility();
    const problem = readProblemFromDom();
    const form = byId('orlp_formulation');
    if (form) form.textContent = formulationText(problem);

    if (!problem.c.every(isFiniteNum)) {
      return showError('Objective coefficients must be finite numbers.');
    }
    const expanded = expandConstraintSet(problem);
    if (expanded.error) return showError(expanded.error);
    if (!expanded.constraints.length) {
      return showError('Enter at least one constraint (or an upper bound, which becomes a constraint).');
    }
    if (problem.constraints.some((row) => !row.a.every(isFiniteNum) || !isFiniteNum(row.b))) {
      return showError('Constraint coefficients and right-hand sides must be finite numbers.');
    }

    const result = solveLP(problem);
    const out = byId('orlp_result');
    const vis = byId('orlp_visual');
    if (vis) vis.innerHTML = '';

    if (result.status === 'error') return showError(result.message);

    const rows = [];
    const statusLabel = result.status === 'optimal' ? 'Optimal'
      : result.status === 'infeasible' ? 'Infeasible'
      : result.status === 'unbounded' ? 'Unbounded'
      : result.status;
    rows.push(['Status', statusLabel]);
    rows.push(['Sense', result.sense === 'min' ? 'Minimize' : 'Maximize']);
    if (result.status === 'optimal') {
      const unit = problem.objUnit ? ' ' + problem.objUnit : '';
      rows.push(['Objective z*', fmtNum(result.objective, 6) + unit]);
      result.names.forEach((name, j) => {
        const u = problem.units[j] ? ' ' + problem.units[j] : '';
        rows.push([name + '  x' + (j + 1) + '*', fmtNum(result.x[j], 6) + u]);
      });
      (result.slacks || []).forEach((s) => {
        rows.push([s.label + '  (' + s.kind + ')', fmtNum(s.value, 6)]);
      });
    } else {
      rows.push(['Detail', result.message]);
    }

    out.className = 'result show' + (result.status === 'optimal' ? '' : ' orlp-status-' + result.status);
    out.innerHTML = rows.map((r) =>
      '<div class="res-row"><span class="res-label">' + escapeHtml(r[0]) + '</span><span class="res-val">' + escapeHtml(r[1]) + '</span></div>'
    ).join('');
    if (typeof appendCopyBtn === 'function') appendCopyBtn(out);

    if (problem.c.length === 2 && vis) {
      const graph = feasibleRegion2D(problem);
      graph.markOptimum = result.status === 'optimal';
      const caption = document.createElement('div');
      caption.className = 'orlp-visual-caption';
      caption.textContent = graph.ok
        ? visualCaption(result.status, true)
        : (graph.reason || visualCaption(result.status, false));
      vis.appendChild(caption);
      vis.appendChild(renderFeasibleRegion(graph, problem));
      if (graph.ok) {
        const table = document.createElement('table');
        table.className = 'orlp-vertex-table';
        table.innerHTML = '<thead><tr><th>Vertex</th><th>' + escapeHtml(problem.names[0]) + '</th><th>' + escapeHtml(problem.names[1]) + '</th><th>z</th></tr></thead>';
        const tb = document.createElement('tbody');
        const mark = result.status === 'optimal';
        graph.vertices.forEach((p, i) => {
          const tr = document.createElement('tr');
          const isOpt = mark && p === graph.optimal;
          if (isOpt) tr.className = 'orlp-opt-row';
          tr.innerHTML = '<td>V' + (i + 1) + (isOpt ? ' ★' : '') + '</td><td>' +
            fmtNum(p.x, 6) + '</td><td>' + fmtNum(p.y, 6) + '</td><td>' + fmtNum(p.z, 6) + '</td>';
          tb.appendChild(tr);
        });
        table.appendChild(tb);
        vis.appendChild(table);
      }
    } else if (vis) {
      const caption = document.createElement('div');
      caption.className = 'orlp-visual-caption';
      caption.textContent = 'n-variable summary. Feasible-region plots are drawn only for two decision variables; the simplex solution (status, z*, x*, slack) is the record for every size.';
      vis.appendChild(caption);
      const wrap = document.createElement('div');
      wrap.className = 'orlp-n-summary';
      wrap.setAttribute('role', 'img');
      wrap.setAttribute('aria-label', 'Primal solution bars');
      if (result.status === 'optimal' && result.x) {
        const maxAbs = Math.max(1e-9, ...result.x.map((v) => Math.abs(v)));
        result.x.forEach((v, j) => {
          const row = document.createElement('div');
          row.className = 'orlp-bar-row';
          const lab = document.createElement('span');
          lab.textContent = result.names[j];
          const track = document.createElement('span');
          track.className = 'orlp-bar-track';
          const fill = document.createElement('span');
          fill.className = 'orlp-bar-fill';
          fill.style.width = (100 * Math.abs(v) / maxAbs) + '%';
          track.appendChild(fill);
          const val = document.createElement('span');
          val.textContent = fmtNum(v, 4) + (problem.units[j] ? ' ' + problem.units[j] : '');
          row.appendChild(lab); row.appendChild(track); row.appendChild(val);
          wrap.appendChild(row);
        });
      } else {
        wrap.textContent = result.message;
      }
      vis.appendChild(wrap);
    }

    if (typeof writeUrlState === 'function') writeUrlState('sec-lp-optimizer');
  }

  function escapeHtml(s) {
    if (typeof global.escapeHtml === 'function') return global.escapeHtml(s);
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  let liveTimer = null;
  function scheduleSolve() {
    clearTimeout(liveTimer);
    liveTimer = setTimeout(solveAndRender, 60);
  }

  function onNChange() {
    syncGridVisibility();
    scheduleSolve();
  }

  window.loadLpOptimizerExample = function () {
    applyPreset('graph');
  };

  window.orlpLoadPreset = function (key) {
    applyPreset(key);
  };

  window.orlpSolve = solveAndRender;

  function init() {
    if (!byId('sec-lp-optimizer')) return;
    buildGrids();
    syncGridVisibility();
    applyPreset('graph');

    const section = byId('sec-lp-optimizer');
    section.addEventListener('input', function (ev) {
      const id = ev.target && ev.target.id;
      if (id === 'orlp_nvars' || id === 'orlp_ncons') return;
      scheduleSolve();
    });
    section.addEventListener('change', function (ev) {
      const id = ev.target && ev.target.id;
      if (id === 'orlp_nvars' || id === 'orlp_ncons') onNChange();
      else scheduleSolve();
    });

    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-lp-optimizer', 'lp-optimizer', solveAndRender);
    }
    if (typeof registerReport === 'function') {
      registerReport('orlp_result', {
        title: 'Linear Program',
        formula: function () { return formulationText(readProblemFromDom()); },
        codeRefs: function () {
          return [
            'Two-phase simplex (Bland’s rule) for a small LP in standard form',
            'x ≥ 0; optional finite upper bounds become extra ≤ constraints',
            'Educational operations-research tool — not related to EMP or shielding',
          ];
        },
      });
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();

  global.__lpOptimizerTestApi = {
    solveLP: solveLP,
    feasibleRegion2D: feasibleRegion2D,
    formulationText: formulationText,
    expandConstraintSet: expandConstraintSet,
    visualCaption: visualCaption,
    PRESETS: PRESETS,
    EPS: EPS,
  };
})(typeof window !== 'undefined' ? window : globalThis);
