(function () {
  'use strict';

  const SVG_NS = 'http://www.w3.org/2000/svg';
  const BG = '#0d1117';
  const ACCENT = '#8b7bff';
  const GREEN = '#6ee7b7';
  const MUTED = '#64748b';
  const TEXT = '#e5e7eb';
  const GRID = 60;
  const PAD = 36;
  const SHORT_G = 1e9;
  const EPS = 1e-12;

  const state = {
    currentExample: 1,
    currentCircuit: null,
    lastResult: null,
  };

  function numFmt(n, d) {
    if (typeof window.fmt === 'function') return window.fmt(n, d);
    if (!isFinite(n)) return '—';
    return parseFloat(Number(n).toFixed(d == null ? 4 : d)).toString();
  }

  function cx(re, im) {
    return { re: re || 0, im: im || 0 };
  }

  function cAdd(a, b) { return cx(a.re + b.re, a.im + b.im); }
  function cSub(a, b) { return cx(a.re - b.re, a.im - b.im); }
  function cMul(a, b) { return cx(a.re * b.re - a.im * b.im, a.re * b.im + a.im * b.re); }
  function cScale(a, k) { return cx(a.re * k, a.im * k); }
  function cMag(a) { return Math.sqrt(a.re * a.re + a.im * a.im); }
  function cPhase(a) { return Math.atan2(a.im, a.re); }
  function cPolar(mag, rad) { return cx(mag * Math.cos(rad), mag * Math.sin(rad)); }
  function cDiv(a, b) {
    const den = b.re * b.re + b.im * b.im;
    if (den < EPS) throw new Error('Singular complex division.');
    return cx((a.re * b.re + a.im * b.im) / den, (a.im * b.re - a.re * b.im) / den);
  }
  function cNeg(a) { return cx(-a.re, -a.im); }
  function cZero() { return cx(0, 0); }
  function cIsZero(a) { return cMag(a) < EPS; }
  function toDb(a) { return 20 * Math.log10(Math.max(cMag(a), 1e-30)); }

  function solveComplexMatrix(A, b) {
    const n = A.length;
    const M = [];
    const y = [];
    let i;
    let j;
    let k;

    for (i = 0; i < n; i += 1) {
      M[i] = [];
      for (j = 0; j < n; j += 1) M[i][j] = cx(A[i][j].re, A[i][j].im);
      y[i] = cx(b[i].re, b[i].im);
    }

    for (k = 0; k < n; k += 1) {
      let pivot = k;
      let pivotMag = cMag(M[k][k]);
      for (i = k + 1; i < n; i += 1) {
        const mag = cMag(M[i][k]);
        if (mag > pivotMag) {
          pivot = i;
          pivotMag = mag;
        }
      }
      if (pivotMag < EPS) throw new Error('Circuit matrix is singular.');
      if (pivot !== k) {
        const row = M[k];
        const rhs = y[k];
        M[k] = M[pivot];
        M[pivot] = row;
        y[k] = y[pivot];
        y[pivot] = rhs;
      }

      for (i = k + 1; i < n; i += 1) {
        if (cIsZero(M[i][k])) continue;
        const factor = cDiv(M[i][k], M[k][k]);
        M[i][k] = cZero();
        for (j = k + 1; j < n; j += 1) {
          M[i][j] = cSub(M[i][j], cMul(factor, M[k][j]));
        }
        y[i] = cSub(y[i], cMul(factor, y[k]));
      }
    }

    const x = new Array(n);
    for (i = n - 1; i >= 0; i -= 1) {
      let sum = cx(y[i].re, y[i].im);
      for (j = i + 1; j < n; j += 1) sum = cSub(sum, cMul(M[i][j], x[j]));
      x[i] = cDiv(sum, M[i][i]);
    }
    return x;
  }

  function mk(tag, cls, text) {
    const el = document.createElement(tag);
    if (cls) el.className = cls;
    if (text != null) el.textContent = text;
    return el;
  }

  function svg(tag, attrs) {
    const el = document.createElementNS(SVG_NS, tag);
    const keys = Object.keys(attrs || {});
    let i;
    for (i = 0; i < keys.length; i += 1) el.setAttribute(keys[i], String(attrs[keys[i]]));
    return el;
  }

  function setStyles(el, styles) {
    const keys = Object.keys(styles);
    let i;
    for (i = 0; i < keys.length; i += 1) el.style[keys[i]] = styles[keys[i]];
    return el;
  }

  function rootEl() {
    let root = document.getElementById('cs_root') ||
      document.getElementById('circuit-sim-root') ||
      document.querySelector('[data-circuit-sim-root]');
    if (!root) {
      root = document.createElement('section');
      root.id = 'cs_root';
      document.body.appendChild(root);
    }
    ensureLayout(root);
    return root;
  }

  function ensureStyles() {
    if (document.getElementById('cs-style')) return;
    const style = document.createElement('style');
    style.id = 'cs-style';
    style.textContent =
      '#cs_root,#circuit-sim-root,[data-circuit-sim-root]{background:' + BG + ';color:' + TEXT + ';border:1px solid #1f2937;border-radius:16px;padding:18px;font:14px/1.45 system-ui,-apple-system,Segoe UI,sans-serif;}' +
      '#cs_root button,#circuit-sim-root button,[data-circuit-sim-root] button{background:#161b22;color:' + TEXT + ';border:1px solid #30363d;border-radius:10px;padding:8px 12px;cursor:pointer;}' +
      '#cs_root button:hover,#circuit-sim-root button:hover,[data-circuit-sim-root] button:hover{border-color:' + ACCENT + ';}' +
      '.cs-toolbar{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:14px;}' +
      '.cs-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:14px;align-items:start;}' +
      '.cs-card{background:#111827;border:1px solid #1f2937;border-radius:14px;padding:14px;}' +
      '.cs-card h3,.cs-card h4{margin:0 0 10px;color:' + ACCENT + ';}' +
      '.cs-meta{color:#cbd5e1;margin:0 0 14px;}' +
      '.cs-note{color:' + MUTED + ';font-size:12px;}' +
      '.cs-editor-row{display:grid;grid-template-columns:90px 1fr auto;gap:10px;align-items:center;margin-bottom:8px;}' +
      '.cs-editor-row input{width:100%;box-sizing:border-box;background:#0b1220;color:' + TEXT + ';border:1px solid #334155;border-radius:8px;padding:8px;}' +
      '.cs-row{display:flex;justify-content:space-between;gap:12px;padding:5px 0;border-bottom:1px solid rgba(100,116,139,.18);}' +
      '.cs-row:last-child{border-bottom:none;}' +
      '.cs-k{color:#cbd5e1;}' +
      '.cs-v{color:' + GREEN + ';text-align:right;}' +
      '.cs-table-wrap{max-height:420px;overflow:auto;border:1px solid #1f2937;border-radius:12px;}' +
      '.cs-table{width:100%;border-collapse:collapse;font-size:12px;}' +
      '.cs-table th,.cs-table td{padding:7px 8px;border-bottom:1px solid rgba(100,116,139,.18);text-align:left;white-space:nowrap;}' +
      '.cs-table th{position:sticky;top:0;background:#101826;color:' + ACCENT + ';}' +
      '.cs-detail-toggle{margin:0 0 10px;}' +
      '.cs-detail-panel{display:none;border-top:1px solid rgba(100,116,139,.22);padding-top:10px;margin-top:10px;}' +
      '.cs-detail-panel.show{display:block;}' +
      '.cs-detail-panel ol{margin:8px 0 0 18px;padding:0;}' +
      '.cs-detail-panel li{margin:6px 0;}' +
      '.cs-badge{display:inline-block;border-radius:999px;padding:3px 8px;font-size:12px;background:rgba(139,123,255,.12);color:' + ACCENT + ';border:1px solid rgba(139,123,255,.35);}' +
      '.cs-chart-title{margin:0 0 8px;color:#cbd5e1;font-size:13px;}';
    document.head.appendChild(style);
  }

  function ensureLayout(root) {
    ensureStyles();
    if (root.querySelector('[data-cs-mounted="1"]')) return;

    root.textContent = '';
    const mount = mk('div');
    mount.setAttribute('data-cs-mounted', '1');

    const toolbar = mk('div', 'cs-toolbar');
    let i;
    for (i = 1; i <= 6; i += 1) {
      const btn = mk('button', '', 'Example ' + i);
      btn.type = 'button';
      btn.addEventListener('click', (function (index) {
        return function () { window.csLoadExample(index); };
      })(i));
      toolbar.appendChild(btn);
    }
    const runBtn = mk('button', '', 'Run Analysis');
    runBtn.type = 'button';
    runBtn.addEventListener('click', function () { window.csRunAnalysis(); });
    toolbar.appendChild(runBtn);
    mount.appendChild(toolbar);

    const title = mk('h2', '', 'Circuit Simulator');
    title.id = 'cs_title';
    mount.appendChild(title);

    const meta = mk('p', 'cs-meta', 'Modified nodal analysis with SVG schematics and AC/DC examples.');
    meta.id = 'cs_description';
    mount.appendChild(meta);

    const badge = mk('div', 'cs-badge');
    badge.id = 'cs_mode_badge';
    mount.appendChild(badge);

    const grid = mk('div', 'cs-grid');

    const editor = mk('div', 'cs-card');
    editor.id = 'cs_editor';
    grid.appendChild(editor);

    const schematic = mk('div', 'cs-card');
    schematic.id = 'cs_schematic';
    grid.appendChild(schematic);

    const summary = mk('div', 'cs-card');
    summary.id = 'cs_summary';
    grid.appendChild(summary);

    const details = mk('div', 'cs-card');
    details.id = 'cs_details';
    grid.appendChild(details);

    mount.appendChild(grid);
    root.appendChild(mount);
  }

  function clone(obj) {
    return JSON.parse(JSON.stringify(obj));
  }

  function freqFmt(hz) {
    if (!isFinite(hz) || hz <= 0) return '—';
    if (hz >= 1e6) return numFmt(hz / 1e6, 4) + ' MHz';
    if (hz >= 1e3) return numFmt(hz / 1e3, 4) + ' kHz';
    return numFmt(hz, 4) + ' Hz';
  }

  function unitFmt(value, unit) {
    if (!isFinite(value)) return '—';
    if (unit === 'Ω') {
      if (Math.abs(value) >= 1e6) return numFmt(value / 1e6, 4) + ' MΩ';
      if (Math.abs(value) >= 1e3) return numFmt(value / 1e3, 4) + ' kΩ';
      return numFmt(value, 4) + ' Ω';
    }
    if (unit === 'F') {
      if (Math.abs(value) >= 1e-6) return numFmt(value * 1e6, 4) + ' µF';
      if (Math.abs(value) >= 1e-9) return numFmt(value * 1e9, 4) + ' nF';
      if (Math.abs(value) >= 1e-12) return numFmt(value * 1e12, 4) + ' pF';
      return numFmt(value, 4) + ' F';
    }
    if (unit === 'H') {
      if (Math.abs(value) >= 1) return numFmt(value, 4) + ' H';
      if (Math.abs(value) >= 1e-3) return numFmt(value * 1e3, 4) + ' mH';
      if (Math.abs(value) >= 1e-6) return numFmt(value * 1e6, 4) + ' µH';
      return numFmt(value, 4) + ' H';
    }
    return numFmt(value, 4) + ' ' + unit;
  }

  function complexFmt(z, unit) {
    return numFmt(cMag(z), 4) + ' ∠ ' + numFmt(cPhase(z) * 180 / Math.PI, 2) + '° ' + unit;
  }

  function valueOfSource(comp, mode) {
    if (mode === 'ac') {
      const mag = comp.ac != null ? comp.ac : (comp.value != null ? comp.value : (comp.dc || 0));
      const phaseDeg = comp.phase || 0;
      return cPolar(mag, phaseDeg * Math.PI / 180);
    }
    return cx(comp.dc != null ? comp.dc : (comp.value != null ? comp.value : 0), 0);
  }

  function admittanceOf(comp, mode, omega) {
    if (comp.type === 'R') return cx(1 / comp.value, 0);
    if (comp.type === 'C') {
      if (mode === 'dc') return cZero();
      return cx(0, omega * comp.value);
    }
    if (comp.type === 'L') {
      if (mode === 'dc') return cx(SHORT_G, 0);
      return cDiv(cx(1, 0), cx(0, omega * comp.value));
    }
    return cZero();
  }

  function validateCircuit(netlist) {
    let i;
    for (i = 0; i < netlist.length; i += 1) {
      const comp = netlist[i];
      if ((comp.type === 'R' || comp.type === 'C' || comp.type === 'L') &&
          (!isFinite(comp.value) || comp.value <= 0)) {
        throw new Error(comp.name + ' must be greater than zero.');
      }
      if ((comp.type === 'V' || comp.type === 'I')) {
        const val = comp.ac != null ? comp.ac : (comp.dc != null ? comp.dc : comp.value);
        if (!isFinite(val)) throw new Error(comp.name + ' must be a valid source value.');
      }
    }
  }

  function solveMna(netlist, opts) {
    validateCircuit(netlist);
    const mode = opts && opts.mode ? opts.mode : 'dc';
    const omega = opts && isFinite(opts.omega) ? opts.omega : 0;
    const nodeMap = {};
    const nodes = [];
    const vSources = [];
    let i;

    for (i = 0; i < netlist.length; i += 1) {
      const comp = netlist[i];
      if (comp.n1 !== 0 && nodeMap[comp.n1] == null) {
        nodeMap[comp.n1] = nodes.length;
        nodes.push(comp.n1);
      }
      if (comp.n2 !== 0 && nodeMap[comp.n2] == null) {
        nodeMap[comp.n2] = nodes.length;
        nodes.push(comp.n2);
      }
      if (comp.type === 'V') vSources.push(comp);
    }

    const N = nodes.length + vSources.length;
    const A = [];
    const z = [];

    function nIdx(node) {
      return node === 0 ? -1 : nodeMap[node];
    }

    function addA(r, c, val) {
      if (r < 0 || c < 0) return;
      A[r][c] = cAdd(A[r][c], val);
    }

    function addZ(r, val) {
      if (r < 0) return;
      z[r] = cAdd(z[r], val);
    }

    function stampY(n1, n2, yVal) {
      const a = nIdx(n1);
      const b = nIdx(n2);
      addA(a, a, yVal);
      addA(b, b, yVal);
      addA(a, b, cNeg(yVal));
      addA(b, a, cNeg(yVal));
    }

    function stampI(n1, n2, iVal) {
      const a = nIdx(n1);
      const b = nIdx(n2);
      addZ(a, cNeg(iVal));
      addZ(b, iVal);
    }

    function stampV(comp, vsIndex) {
      const a = nIdx(comp.n1);
      const b = nIdx(comp.n2);
      const s = nodes.length + vsIndex;
      addA(a, s, cx(1, 0));
      addA(b, s, cx(-1, 0));
      addA(s, a, cx(1, 0));
      addA(s, b, cx(-1, 0));
      addZ(s, valueOfSource(comp, mode));
    }

    for (i = 0; i < N; i += 1) {
      A[i] = [];
      z[i] = cZero();
      let j;
      for (j = 0; j < N; j += 1) A[i][j] = cZero();
    }

    for (i = 0; i < netlist.length; i += 1) {
      const comp = netlist[i];
      if (comp.type === 'R' || comp.type === 'C' || comp.type === 'L') {
        stampY(comp.n1, comp.n2, admittanceOf(comp, mode, omega));
      } else if (comp.type === 'I') {
        stampI(comp.n1, comp.n2, valueOfSource(comp, mode));
      }
    }

    for (i = 0; i < vSources.length; i += 1) stampV(vSources[i], i);

    const x = solveComplexMatrix(A, z);
    const nodeVoltages = { 0: cZero() };
    const sourceCurrents = {};
    const branchCurrents = {};

    for (i = 0; i < nodes.length; i += 1) nodeVoltages[nodes[i]] = x[i];
    for (i = 0; i < vSources.length; i += 1) sourceCurrents[vSources[i].name] = x[nodes.length + i];

    for (i = 0; i < netlist.length; i += 1) {
      const item = netlist[i];
      const v1 = nodeVoltages[item.n1] || cZero();
      const v2 = nodeVoltages[item.n2] || cZero();
      if (item.type === 'R' || item.type === 'C' || item.type === 'L') {
        branchCurrents[item.name] = cMul(admittanceOf(item, mode, omega), cSub(v1, v2));
      } else if (item.type === 'I') {
        branchCurrents[item.name] = valueOfSource(item, mode);
      } else if (item.type === 'V') {
        branchCurrents[item.name] = sourceCurrents[item.name];
      }
    }

    return {
      mode: mode,
      omega: omega,
      nodeVoltages: nodeVoltages,
      branchCurrents: branchCurrents,
      sourceCurrents: sourceCurrents,
      nodes: nodes,
    };
  }

  function zeroIndependentSources(netlist) {
    return netlist.map(function (comp) {
      const copy = clone(comp);
      if (copy.type === 'V' || copy.type === 'I') {
        copy.dc = 0;
        copy.ac = 0;
        copy.value = 0;
      }
      return copy;
    });
  }

  function logSpace(start, stop, count) {
    const vals = [];
    const ls = Math.log10(start);
    const le = Math.log10(stop);
    let i;
    for (i = 0; i < count; i += 1) {
      const t = count === 1 ? 0 : i / (count - 1);
      vals.push(Math.pow(10, ls + (le - ls) * t));
    }
    return vals;
  }

  function componentValueText(comp) {
    if (comp.type === 'R') return unitFmt(comp.value, 'Ω');
    if (comp.type === 'C') return unitFmt(comp.value, 'F');
    if (comp.type === 'L') return unitFmt(comp.value, 'H');
    if (comp.type === 'V') {
      if (comp.ac != null) return numFmt(comp.ac, 4) + ' V AC';
      return numFmt(comp.dc != null ? comp.dc : comp.value, 4) + ' V';
    }
    if (comp.type === 'I') {
      if (comp.ac != null) return numFmt(comp.ac, 4) + ' A AC';
      return numFmt(comp.dc != null ? comp.dc : comp.value, 4) + ' A';
    }
    return String(comp.value);
  }

  function componentUnit(comp) {
    if (comp.type === 'R') return 'Ω';
    if (comp.type === 'C') return 'F';
    if (comp.type === 'L') return 'H';
    if (comp.type === 'V') return comp.ac != null ? 'V AC' : 'V';
    if (comp.type === 'I') return comp.ac != null ? 'A AC' : 'A';
    return '';
  }

  function drawWire(group, a, b) {
    group.appendChild(svg('line', {
      x1: a.x, y1: a.y, x2: b.x, y2: b.y,
      stroke: '#cbd5e1', 'stroke-width': 2, 'stroke-linecap': 'round',
    }));
  }

  function axisInfo(a, b) {
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const len = Math.sqrt(dx * dx + dy * dy) || 1;
    return {
      ux: dx / len,
      uy: dy / len,
      nx: -dy / len,
      ny: dx / len,
      len: len,
      mx: (a.x + b.x) / 2,
      my: (a.y + b.y) / 2,
    };
  }

  function pointFrom(base, ux, uy, dist) {
    return { x: base.x + ux * dist, y: base.y + uy * dist };
  }

  function drawResistor(group, a, b) {
    const g = axisInfo(a, b);
    const lead = Math.min(18, g.len * 0.2);
    const s = pointFrom(a, g.ux, g.uy, lead);
    const e = pointFrom(b, -g.ux, -g.uy, lead);
    drawWire(group, a, s);
    drawWire(group, e, b);
    const steps = 8;
    let d = 'M ' + s.x + ' ' + s.y;
    let i;
    for (i = 1; i < steps; i += 1) {
      const t = i / steps;
      const p = {
        x: s.x + (e.x - s.x) * t + g.nx * (i % 2 === 0 ? -8 : 8),
        y: s.y + (e.y - s.y) * t + g.ny * (i % 2 === 0 ? -8 : 8),
      };
      d += ' L ' + p.x + ' ' + p.y;
    }
    d += ' L ' + e.x + ' ' + e.y;
    group.appendChild(svg('path', { d: d, fill: 'none', stroke: TEXT, 'stroke-width': 2 }));
  }

  function drawCapacitor(group, a, b) {
    const g = axisInfo(a, b);
    const gap = 8;
    const halfPlate = 10;
    const s = { x: g.mx - g.ux * gap, y: g.my - g.uy * gap };
    const e = { x: g.mx + g.ux * gap, y: g.my + g.uy * gap };
    drawWire(group, a, s);
    drawWire(group, e, b);
    group.appendChild(svg('line', {
      x1: s.x + g.nx * halfPlate, y1: s.y + g.ny * halfPlate,
      x2: s.x - g.nx * halfPlate, y2: s.y - g.ny * halfPlate,
      stroke: TEXT, 'stroke-width': 2,
    }));
    group.appendChild(svg('line', {
      x1: e.x + g.nx * halfPlate, y1: e.y + g.ny * halfPlate,
      x2: e.x - g.nx * halfPlate, y2: e.y - g.ny * halfPlate,
      stroke: TEXT, 'stroke-width': 2,
    }));
  }

  function drawInductor(group, a, b) {
    const g = axisInfo(a, b);
    const lead = Math.min(18, g.len * 0.18);
    const s = pointFrom(a, g.ux, g.uy, lead);
    const e = pointFrom(b, -g.ux, -g.uy, lead);
    drawWire(group, a, s);
    drawWire(group, e, b);
    const turns = 4;
    const span = Math.max(10, (g.len - lead * 2) / turns);
    let d = 'M ' + s.x + ' ' + s.y;
    let i;
    for (i = 0; i < turns; i += 1) {
      const pA = pointFrom(s, g.ux, g.uy, span * i);
      const pM = pointFrom(s, g.ux, g.uy, span * (i + 0.5));
      const pB = pointFrom(s, g.ux, g.uy, span * (i + 1));
      d += ' Q ' + (pM.x + g.nx * 12) + ' ' + (pM.y + g.ny * 12) + ' ' + pB.x + ' ' + pB.y;
    }
    group.appendChild(svg('path', { d: d, fill: 'none', stroke: TEXT, 'stroke-width': 2 }));
  }

  function drawVoltageSource(group, a, b) {
    const g = axisInfo(a, b);
    const r = 14;
    const s = pointFrom({ x: g.mx, y: g.my }, -g.ux, -g.uy, r);
    const e = pointFrom({ x: g.mx, y: g.my }, g.ux, g.uy, r);
    drawWire(group, a, s);
    drawWire(group, e, b);
    group.appendChild(svg('circle', {
      cx: g.mx, cy: g.my, r: r, fill: 'none', stroke: TEXT, 'stroke-width': 2,
    }));
    const plus = svg('text', {
      x: g.mx - g.ux * 1 + g.nx * 0,
      y: g.my - g.uy * 7 - g.ny * 7,
      fill: TEXT, 'font-size': 12, 'text-anchor': 'middle',
    });
    plus.textContent = '+';
    group.appendChild(plus);
    const minus = svg('text', {
      x: g.mx + g.ux * 1 + g.nx * 0,
      y: g.my + g.uy * 10 + g.ny * 10,
      fill: TEXT, 'font-size': 12, 'text-anchor': 'middle',
    });
    minus.textContent = '−';
    group.appendChild(minus);
  }

  function drawCurrentSource(group, a, b) {
    const g = axisInfo(a, b);
    const r = 14;
    const s = pointFrom({ x: g.mx, y: g.my }, -g.ux, -g.uy, r);
    const e = pointFrom({ x: g.mx, y: g.my }, g.ux, g.uy, r);
    drawWire(group, a, s);
    drawWire(group, e, b);
    group.appendChild(svg('circle', {
      cx: g.mx, cy: g.my, r: r, fill: 'none', stroke: TEXT, 'stroke-width': 2,
    }));
    group.appendChild(svg('line', {
      x1: g.mx - g.ux * 7, y1: g.my - g.uy * 7,
      x2: g.mx + g.ux * 7, y2: g.my + g.uy * 7,
      stroke: TEXT, 'stroke-width': 2,
    }));
    group.appendChild(svg('path', {
      d: 'M ' + (g.mx + g.ux * 7) + ' ' + (g.my + g.uy * 7) +
        ' L ' + (g.mx + g.ux * 1 + g.nx * 5) + ' ' + (g.my + g.uy * 1 + g.ny * 5) +
        ' L ' + (g.mx + g.ux * 1 - g.nx * 5) + ' ' + (g.my + g.uy * 1 - g.ny * 5) + ' Z',
      fill: TEXT,
    }));
  }

  function drawGround(group, p) {
    group.appendChild(svg('line', { x1: p.x, y1: p.y, x2: p.x, y2: p.y + 8, stroke: TEXT, 'stroke-width': 2 }));
    group.appendChild(svg('line', { x1: p.x - 12, y1: p.y + 8, x2: p.x + 12, y2: p.y + 8, stroke: TEXT, 'stroke-width': 2 }));
    group.appendChild(svg('line', { x1: p.x - 8, y1: p.y + 13, x2: p.x + 8, y2: p.y + 13, stroke: TEXT, 'stroke-width': 2 }));
    group.appendChild(svg('line', { x1: p.x - 4, y1: p.y + 18, x2: p.x + 4, y2: p.y + 18, stroke: TEXT, 'stroke-width': 2 }));
  }

  function drawComponent(group, comp, pos) {
    if (comp.type === 'R') drawResistor(group, pos.a, pos.b);
    else if (comp.type === 'C') drawCapacitor(group, pos.a, pos.b);
    else if (comp.type === 'L') drawInductor(group, pos.a, pos.b);
    else if (comp.type === 'V') drawVoltageSource(group, pos.a, pos.b);
    else if (comp.type === 'I') drawCurrentSource(group, pos.a, pos.b);

    const g = axisInfo(pos.a, pos.b);
    const label = svg('text', {
      x: g.mx + g.nx * 18,
      y: g.my + g.ny * 18,
      fill: ACCENT,
      'font-size': 12,
      'text-anchor': 'middle',
    });
    label.textContent = comp.name;
    group.appendChild(label);

    const value = svg('text', {
      x: g.mx - g.nx * 18,
      y: g.my - g.ny * 18,
      fill: GREEN,
      'font-size': 11,
      'text-anchor': 'middle',
    });
    value.textContent = componentValueText(comp);
    group.appendChild(value);
  }

  function pt(gridPt) {
    return { x: PAD + gridPt[0] * GRID, y: PAD + gridPt[1] * GRID };
  }

  function renderSchematic(circuit) {
    const host = document.getElementById('cs_schematic');
    host.textContent = '';
    host.appendChild(mk('h3', '', 'Schematic'));

    const layout = circuit.layout;
    const width = PAD * 2 + layout.size[0] * GRID;
    const height = PAD * 2 + layout.size[1] * GRID;
    const svgRoot = svg('svg', {
      viewBox: '0 0 ' + width + ' ' + height,
      width: '100%',
      height: height,
      role: 'img',
      'aria-label': circuit.name + ' schematic',
    });
    setStyles(svgRoot, { display: 'block', background: '#0b1220', borderRadius: '12px', border: '1px solid #1f2937' });

    let i;
    const wires = svg('g');
    for (i = 0; i < layout.wires.length; i += 1) drawWire(wires, pt(layout.wires[i][0]), pt(layout.wires[i][1]));
    svgRoot.appendChild(wires);

    const comps = svg('g');
    for (i = 0; i < circuit.netlist.length; i += 1) {
      const comp = circuit.netlist[i];
      const pos = layout.components[comp.name];
      if (pos) drawComponent(comps, comp, { a: pt(pos[0]), b: pt(pos[1]) });
    }
    svgRoot.appendChild(comps);

    for (i = 0; i < layout.grounds.length; i += 1) drawGround(svgRoot, pt(layout.grounds[i]));

    for (i = 0; i < layout.labels.length; i += 1) {
      const item = layout.labels[i];
      const label = svg('text', {
        x: pt(item.at).x,
        y: pt(item.at).y,
        fill: '#cbd5e1',
        'font-size': 12,
        'text-anchor': item.anchor || 'middle',
      });
      label.textContent = item.text;
      svgRoot.appendChild(label);
    }

    host.appendChild(svgRoot);
  }

  function renderEditor(circuit) {
    const host = document.getElementById('cs_editor');
    host.textContent = '';
    host.appendChild(mk('h3', '', 'Component Values'));
    host.appendChild(mk('p', 'cs-note', 'Edit values, then run analysis. Scientific notation is supported.'));

    let i;
    for (i = 0; i < circuit.netlist.length; i += 1) {
      const comp = circuit.netlist[i];
      const row = mk('div', 'cs-editor-row');
      const name = mk('div', '', comp.name + ' (' + comp.type + ')');
      setStyles(name, { color: '#cbd5e1' });

      const input = document.createElement('input');
      input.type = 'number';
      input.step = 'any';
      input.setAttribute('data-comp-name', comp.name);
      input.setAttribute('data-field', comp.type === 'V' && comp.ac != null ? 'ac' : comp.type === 'I' && comp.ac != null ? 'ac' : (comp.dc != null ? 'dc' : 'value'));
      input.value = String(comp.type === 'V' && comp.ac != null ? comp.ac : comp.type === 'I' && comp.ac != null ? comp.ac : (comp.dc != null ? comp.dc : comp.value));

      const unit = mk('div', '', componentUnit(comp));
      setStyles(unit, { color: MUTED, minWidth: '42px', textAlign: 'right' });

      row.appendChild(name);
      row.appendChild(input);
      row.appendChild(unit);
      host.appendChild(row);
    }
  }

  function readEditedCircuit() {
    const circuit = clone(state.currentCircuit || examples()[1]);
    const inputs = rootEl().querySelectorAll('[data-comp-name][data-field]');
    let i;
    for (i = 0; i < inputs.length; i += 1) {
      const input = inputs[i];
      const name = input.getAttribute('data-comp-name');
      const field = input.getAttribute('data-field');
      const value = parseFloat(input.value);
      if (!isFinite(value)) continue;
      let j;
      for (j = 0; j < circuit.netlist.length; j += 1) {
        if (circuit.netlist[j].name === name) {
          circuit.netlist[j][field] = value;
          if (field === 'dc' && circuit.netlist[j].value != null) circuit.netlist[j].value = value;
          break;
        }
      }
    }
    return circuit;
  }

  function addSection(host, title) {
    const card = mk('div');
    card.appendChild(mk('h4', '', title));
    host.appendChild(card);
    return card;
  }

  function addRow(host, key, value) {
    const row = mk('div', 'cs-row');
    row.appendChild(mk('div', 'cs-k', key));
    row.appendChild(mk('div', 'cs-v', value));
    host.appendChild(row);
  }

  function renderNodeRows(host, solution, mode) {
    const sec = addSection(host, 'Node Voltages');
    const nodes = Object.keys(solution.nodeVoltages).map(Number).sort(function (a, b) { return a - b; });
    let i;
    for (i = 0; i < nodes.length; i += 1) {
      const node = nodes[i];
      if (node === 0) continue;
      addRow(sec, 'V(' + node + ')', mode === 'ac' ? complexFmt(solution.nodeVoltages[node], 'V') : numFmt(solution.nodeVoltages[node].re, 4) + ' V');
    }
  }

  function renderCurrentRows(host, solution, mode) {
    const sec = addSection(host, 'Branch Currents');
    const names = Object.keys(solution.branchCurrents);
    let i;
    for (i = 0; i < names.length; i += 1) {
      const name = names[i];
      addRow(sec, name + ' (' + nameDirection(solution, name) + ')',
        mode === 'ac' ? complexFmt(solution.branchCurrents[name], 'A') : numFmt(solution.branchCurrents[name].re, 6) + ' A');
    }
  }

  function nameDirection(solution, name) {
    const circuit = state.currentCircuit || {};
    const netlist = circuit.netlist || [];
    let i;
    for (i = 0; i < netlist.length; i += 1) {
      if (netlist[i].name === name) return netlist[i].n1 + '→' + netlist[i].n2;
    }
    return '';
  }

  function renderSweepTable(host, points, kind) {
    const sec = addSection(host, kind === 'impedance' ? 'Frequency Sweep: |Z|' : 'Frequency Sweep: Bode');
    const wrap = mk('div', 'cs-table-wrap');
    const table = mk('table', 'cs-table');
    const thead = mk('thead');
    const trh = mk('tr');
    ['Frequency', kind === 'impedance' ? '|Z|' : 'Magnitude', 'dB', 'Phase'].forEach(function (text) {
      trh.appendChild(mk('th', '', text));
    });
    thead.appendChild(trh);
    table.appendChild(thead);
    const tbody = mk('tbody');
    let i;
    for (i = 0; i < points.length; i += 1) {
      const tr = mk('tr');
      tr.appendChild(mk('td', '', freqFmt(points[i].freq)));
      tr.appendChild(mk('td', '', kind === 'impedance' ? unitFmt(points[i].mag, 'Ω') : numFmt(points[i].mag, 4) + ' V/V'));
      tr.appendChild(mk('td', '', numFmt(points[i].db, 3) + ' dB'));
      tr.appendChild(mk('td', '', numFmt(points[i].phase, 2) + '°'));
      tbody.appendChild(tr);
    }
    table.appendChild(tbody);
    wrap.appendChild(table);
    sec.appendChild(wrap);
  }

  function renderChart(host, points, markerFreq, label) {
    const sec = addSection(host, label);
    sec.appendChild(mk('p', 'cs-chart-title', 'Mini Bode magnitude plot'));
    const W = 520;
    const H = 150;
    const L = 42;
    const R = 12;
    const T = 12;
    const B = 26;
    const plotW = W - L - R;
    const plotH = H - T - B;
    let i;
    let minDb = Infinity;
    let maxDb = -Infinity;
    for (i = 0; i < points.length; i += 1) {
      minDb = Math.min(minDb, points[i].db);
      maxDb = Math.max(maxDb, points[i].db);
    }
    if (Math.abs(maxDb - minDb) < 1e-9) {
      maxDb += 1;
      minDb -= 1;
    }
    const fMin = Math.log10(points[0].freq);
    const fMax = Math.log10(points[points.length - 1].freq);
    function x(freq) { return L + (Math.log10(freq) - fMin) / (fMax - fMin) * plotW; }
    function y(db) { return T + (maxDb - db) / (maxDb - minDb) * plotH; }

    const chart = svg('svg', { viewBox: '0 0 ' + W + ' ' + H, width: '100%', height: H });
    setStyles(chart, { background: '#0b1220', borderRadius: '12px', border: '1px solid #1f2937' });
    chart.appendChild(svg('line', { x1: L, y1: T, x2: L, y2: H - B, stroke: MUTED, 'stroke-width': 1.5 }));
    chart.appendChild(svg('line', { x1: L, y1: H - B, x2: W - R, y2: H - B, stroke: MUTED, 'stroke-width': 1.5 }));

    const path = [];
    for (i = 0; i < points.length; i += 1) path.push((i ? 'L ' : 'M ') + x(points[i].freq) + ' ' + y(points[i].db));
    chart.appendChild(svg('path', { d: path.join(' '), fill: 'none', stroke: ACCENT, 'stroke-width': 2.5 }));

    chart.appendChild(svg('text', { x: L, y: H - 6, fill: MUTED, 'font-size': 10, 'text-anchor': 'start' })).textContent = freqFmt(points[0].freq);
    chart.appendChild(svg('text', { x: W - R, y: H - 6, fill: MUTED, 'font-size': 10, 'text-anchor': 'end' })).textContent = freqFmt(points[points.length - 1].freq);
    chart.appendChild(svg('text', { x: 6, y: T + 8, fill: MUTED, 'font-size': 10 })).textContent = numFmt(maxDb, 1) + ' dB';
    chart.appendChild(svg('text', { x: 6, y: H - B, fill: MUTED, 'font-size': 10 })).textContent = numFmt(minDb, 1) + ' dB';

    if (markerFreq && isFinite(markerFreq) && markerFreq >= points[0].freq && markerFreq <= points[points.length - 1].freq) {
      const mx = x(markerFreq);
      chart.appendChild(svg('line', { x1: mx, y1: T, x2: mx, y2: H - B, stroke: GREEN, 'stroke-width': 1.2, 'stroke-dasharray': '4 3' }));
      const mt = svg('text', { x: mx, y: T + 10, fill: GREEN, 'font-size': 10, 'text-anchor': 'middle' });
      mt.textContent = freqFmt(markerFreq);
      chart.appendChild(mt);
    }
    sec.appendChild(chart);
  }

  function renderDetails(host, result) {
    host.textContent = '';
    host.appendChild(mk('h3', '', 'Explanation'));
    const toggle = mk('button', 'cs-detail-toggle', 'Show Step-by-Step');
    toggle.type = 'button';
    const panelId = 'cs_detail_panel';
    toggle.addEventListener('click', function () { window.csToggleDetails(panelId); });
    host.appendChild(toggle);

    const panel = mk('div', 'cs-detail-panel');
    panel.id = panelId;
    const list = mk('ol');
    let i;
    for (i = 0; i < result.steps.length; i += 1) list.appendChild(mk('li', '', result.steps[i]));
    panel.appendChild(list);
    host.appendChild(panel);
  }

  function analyzeVoltageDivider(circuit) {
    const sol = solveMna(circuit.netlist, { mode: 'dc' });
    const r1 = findComp(circuit, 'R1').value;
    const r2 = findComp(circuit, 'R2').value;
    const vin = findComp(circuit, 'V1').dc;
    const vout = vin * r2 / (r1 + r2);
    return {
      mode: 'dc',
      badge: 'DC operating point',
      solution: sol,
      steps: [
        'Stamp the ideal voltage source, then stamp R1 and R2 as conductances 1/R.',
        'For DC, resistors remain active and the MNA solve returns the node voltages directly.',
        'The divider relation is Vout = Vin × R2 / (R1 + R2).',
        'The current through both resistors is the same because they are in series.',
      ],
      extras: function (host) {
        const sec = addSection(host, 'Key Result');
        addRow(sec, 'Calculated Vout', numFmt(sol.nodeVoltages[2].re, 4) + ' V');
        addRow(sec, 'Divider formula', numFmt(vout, 4) + ' V');
      },
    };
  }

  function analyzeThevenin(circuit) {
    const open = solveMna(circuit.netlist, { mode: 'dc' });
    const passive = zeroIndependentSources(circuit.netlist);
    passive.push({ name: 'ITEST', type: 'I', n1: 0, n2: 3, dc: 1 });
    const test = solveMna(passive, { mode: 'dc' });
    const vth = open.nodeVoltages[3].re;
    const rth = test.nodeVoltages[3].re;
    return {
      mode: 'dc',
      badge: 'DC Thevenin solve',
      solution: open,
      steps: [
        'Solve the original circuit with the output open to get the open-circuit voltage Vth.',
        'Zero the independent voltage source to a short circuit.',
        'Inject a 1 A test current into the output node and solve again.',
        'Rth equals the resulting output voltage divided by the 1 A test current.',
      ],
      extras: function (host) {
        const sec = addSection(host, 'Thevenin Equivalent');
        addRow(sec, 'Vth', numFmt(vth, 4) + ' V');
        addRow(sec, 'Rth', unitFmt(rth, 'Ω'));
        addRow(sec, 'Isc = Vth / Rth', numFmt(vth / rth, 6) + ' A');
      },
    };
  }

  function analyzeRcLowPass(circuit) {
    const r = findComp(circuit, 'R1').value;
    const c = findComp(circuit, 'C1').value;
    const fc = 1 / (2 * Math.PI * r * c);
    const sweep = logSpace(1, 1e6, 30).map(function (freq) {
      const sol = solveMna(circuit.netlist, { mode: 'ac', omega: 2 * Math.PI * freq });
      const out = sol.nodeVoltages[2];
      return { freq: freq, mag: cMag(out), db: toDb(out), phase: cPhase(out) * 180 / Math.PI };
    });
    const nominal = solveMna(circuit.netlist, { mode: 'ac', omega: 2 * Math.PI * fc });
    return {
      mode: 'ac',
      badge: 'AC sweep · 1 Hz to 1 MHz',
      solution: nominal,
      sweep: sweep,
      chartMarker: fc,
      chartTitle: 'Bode Magnitude',
      steps: [
        'At each frequency, stamp R as 1/R and C as jωC.',
        'Solve the complex MNA system to get the capacitor node phasor.',
        'Convert |Vout| to dB with 20 log10(|Vout|).',
        'The corner frequency is fc = 1 / (2πRC), where the magnitude is about −3 dB.',
      ],
      extras: function (host) {
        const sec = addSection(host, 'Filter Metrics');
        addRow(sec, 'Cutoff frequency', freqFmt(fc));
        addRow(sec, 'Vout @ fc', complexFmt(nominal.nodeVoltages[2], 'V'));
        addRow(sec, 'Magnitude @ fc', numFmt(toDb(nominal.nodeVoltages[2]), 3) + ' dB');
      },
      sweepKind: 'gain',
    };
  }

  function analyzeRlc(circuit) {
    const l = findComp(circuit, 'L1').value;
    const c = findComp(circuit, 'C1').value;
    const f0 = 1 / (2 * Math.PI * Math.sqrt(l * c));
    const sweep = logSpace(10, 1e5, 30).map(function (freq) {
      const sol = solveMna(circuit.netlist, { mode: 'ac', omega: 2 * Math.PI * freq });
      const isrc = cNeg(sol.branchCurrents.V1);
      const z = cDiv(cx(1, 0), isrc);
      return { freq: freq, mag: cMag(z), db: toDb(z), phase: cPhase(z) * 180 / Math.PI };
    });
    const nominal = solveMna(circuit.netlist, { mode: 'ac', omega: 2 * Math.PI * f0 });
    return {
      mode: 'ac',
      badge: 'AC sweep · series resonance',
      solution: nominal,
      sweep: sweep,
      chartMarker: f0,
      chartTitle: 'Impedance Magnitude',
      steps: [
        'At each frequency, stamp the inductor as 1/(jωL) and the capacitor as jωC.',
        'The voltage source current gives the total series current through the RLC loop.',
        'Input impedance is Z = Vin / Iin.',
        'At resonance, XL and XC cancel and |Z| approaches the series resistance.',
      ],
      extras: function (host) {
        const sec = addSection(host, 'Resonance');
        const zin = cDiv(cx(1, 0), cNeg(nominal.branchCurrents.V1));
        addRow(sec, 'Resonant frequency', freqFmt(f0));
        addRow(sec, '|Z| @ f0', unitFmt(cMag(zin), 'Ω'));
        addRow(sec, '∠Z @ f0', numFmt(cPhase(zin) * 180 / Math.PI, 2) + '°');
      },
      sweepKind: 'impedance',
    };
  }

  function analyzeSuperposition(circuit) {
    const total = solveMna(circuit.netlist, { mode: 'dc' });
    const v1Only = clone(circuit.netlist).map(function (comp) {
      if (comp.name === 'V2') { comp.dc = 0; comp.value = 0; }
      return comp;
    });
    const v2Only = clone(circuit.netlist).map(function (comp) {
      if (comp.name === 'V1') { comp.dc = 0; comp.value = 0; }
      return comp;
    });
    const s1 = solveMna(v1Only, { mode: 'dc' });
    const s2 = solveMna(v2Only, { mode: 'dc' });
    return {
      mode: 'dc',
      badge: 'DC superposition',
      solution: total,
      steps: [
        'Solve with both sources active to get the total response.',
        'Zero V2 to a short and solve for the V1-only contribution.',
        'Zero V1 to a short and solve for the V2-only contribution.',
        'Add the individual node-voltage contributions to recover the total result.',
      ],
      extras: function (host) {
        const sec = addSection(host, 'Superposition Check');
        addRow(sec, 'Node 2 from V1 only', numFmt(s1.nodeVoltages[2].re, 4) + ' V');
        addRow(sec, 'Node 2 from V2 only', numFmt(s2.nodeVoltages[2].re, 4) + ' V');
        addRow(sec, 'Sum', numFmt(s1.nodeVoltages[2].re + s2.nodeVoltages[2].re, 4) + ' V');
        addRow(sec, 'Direct solve', numFmt(total.nodeVoltages[2].re, 4) + ' V');
      },
    };
  }

  function analyzeWheatstone(circuit) {
    const sol = solveMna(circuit.netlist, { mode: 'dc' });
    const r1 = findComp(circuit, 'R1').value;
    const r2 = findComp(circuit, 'R2').value;
    const r3 = findComp(circuit, 'R3').value;
    const r4 = findComp(circuit, 'R4').value;
    const balanceLeft = r1 / r2;
    const balanceRight = r3 / r4;
    return {
      mode: 'dc',
      badge: 'DC bridge analysis',
      solution: sol,
      steps: [
        'Stamp the five resistors and one source into the MNA matrix.',
        'Solve for the two midpoint voltages across the galvanometer branch.',
        'Galvanometer current is the resistor current from node 2 to node 3.',
        'A bridge is balanced when R1/R2 = R3/R4, which makes the midpoint differential zero.',
      ],
      extras: function (host) {
        const sec = addSection(host, 'Bridge Condition');
        addRow(sec, 'Left ratio R1/R2', numFmt(balanceLeft, 4));
        addRow(sec, 'Right ratio R3/R4', numFmt(balanceRight, 4));
        addRow(sec, 'Midpoint ΔV', numFmt(sol.nodeVoltages[2].re - sol.nodeVoltages[3].re, 6) + ' V');
        addRow(sec, 'Galvanometer current', numFmt(sol.branchCurrents.Rg.re, 6) + ' A');
      },
    };
  }

  function findComp(circuit, name) {
    let i;
    for (i = 0; i < circuit.netlist.length; i += 1) {
      if (circuit.netlist[i].name === name) return circuit.netlist[i];
    }
    return null;
  }

  function analyzeCircuit(circuit) {
    if (circuit.analysis.kind === 'voltage-divider') return analyzeVoltageDivider(circuit);
    if (circuit.analysis.kind === 'thevenin') return analyzeThevenin(circuit);
    if (circuit.analysis.kind === 'rc-lowpass') return analyzeRcLowPass(circuit);
    if (circuit.analysis.kind === 'rlc-series') return analyzeRlc(circuit);
    if (circuit.analysis.kind === 'superposition') return analyzeSuperposition(circuit);
    return analyzeWheatstone(circuit);
  }

  function renderSummary(result) {
    const host = document.getElementById('cs_summary');
    host.textContent = '';
    host.appendChild(mk('h3', '', 'Analysis Results'));
    if (result.extras) result.extras(host);
    renderNodeRows(host, result.solution, result.mode);
    renderCurrentRows(host, result.solution, result.mode);
    if (result.sweep) {
      renderChart(host, result.sweep, result.chartMarker, result.chartTitle);
      renderSweepTable(host, result.sweep, result.sweepKind === 'impedance' ? 'impedance' : 'gain');
    }
  }

  function examples() {
    return {
      1: {
        name: 'Voltage Divider',
        description: '12 V source feeding a 10 kΩ / 22 kΩ divider. Output is the midpoint node.',
        analysis: { kind: 'voltage-divider', mode: 'dc' },
        netlist: [
          { name: 'V1', type: 'V', n1: 1, n2: 0, dc: 12, value: 12 },
          { name: 'R1', type: 'R', n1: 1, n2: 2, value: 10000 },
          { name: 'R2', type: 'R', n1: 2, n2: 0, value: 22000 },
        ],
        layout: {
          size: [5, 4],
          components: { V1: [[1, 3], [1, 1]], R1: [[1, 1], [3, 1]], R2: [[3, 1], [3, 3]] },
          wires: [ [[3, 3], [1, 3]] ],
          grounds: [[1, 3]],
          labels: [{ text: 'Vout', at: [3.5, 0.7] }],
        },
      },
      2: {
        name: 'Thevenin Equivalent',
        description: 'Open-circuit output after R3. Solve for Vth and Rth at node 3 to ground.',
        analysis: { kind: 'thevenin', mode: 'dc' },
        netlist: [
          { name: 'V1', type: 'V', n1: 1, n2: 0, dc: 15, value: 15 },
          { name: 'R1', type: 'R', n1: 1, n2: 2, value: 5000 },
          { name: 'R2', type: 'R', n1: 2, n2: 0, value: 10000 },
          { name: 'R3', type: 'R', n1: 2, n2: 3, value: 15000 },
        ],
        layout: {
          size: [6, 4],
          components: { V1: [[1, 3], [1, 1]], R1: [[1, 1], [3, 1]], R2: [[3, 1], [3, 3]], R3: [[3, 1], [5, 1]] },
          wires: [ [[3, 3], [1, 3]] ],
          grounds: [[1, 3]],
          labels: [{ text: 'Output', at: [5.2, 0.7] }, { text: '+', at: [5.25, 1.15] }, { text: '−', at: [5.2, 3.05] }],
        },
      },
      3: {
        name: 'RC Low-Pass Filter',
        description: '1 V AC source, 1 kΩ series resistor, 100 nF shunt capacitor. Sweep 1 Hz to 1 MHz.',
        analysis: { kind: 'rc-lowpass', mode: 'ac' },
        netlist: [
          { name: 'V1', type: 'V', n1: 1, n2: 0, ac: 1, phase: 0, value: 1 },
          { name: 'R1', type: 'R', n1: 1, n2: 2, value: 1000 },
          { name: 'C1', type: 'C', n1: 2, n2: 0, value: 100e-9 },
        ],
        layout: {
          size: [5, 4],
          components: { V1: [[1, 3], [1, 1]], R1: [[1, 1], [3, 1]], C1: [[3, 1], [3, 3]] },
          wires: [ [[3, 3], [1, 3]] ],
          grounds: [[1, 3]],
          labels: [{ text: 'Vout', at: [3.5, 0.7] }],
        },
      },
      4: {
        name: 'RLC Resonant Circuit',
        description: 'Series RLC with 1 V AC source, 100 Ω, 10 mH, and 1 µF. Sweep for resonance.',
        analysis: { kind: 'rlc-series', mode: 'ac' },
        netlist: [
          { name: 'V1', type: 'V', n1: 1, n2: 0, ac: 1, phase: 0, value: 1 },
          { name: 'R1', type: 'R', n1: 1, n2: 2, value: 100 },
          { name: 'L1', type: 'L', n1: 2, n2: 3, value: 10e-3 },
          { name: 'C1', type: 'C', n1: 3, n2: 0, value: 1e-6 },
        ],
        layout: {
          size: [6, 4],
          components: { V1: [[1, 3], [1, 1]], R1: [[1, 1], [2.5, 1]], L1: [[2.5, 1], [4, 1]], C1: [[4, 1], [4, 3]] },
          wires: [ [[4, 3], [1, 3]] ],
          grounds: [[1, 3]],
          labels: [{ text: 'Series loop current', at: [3.0, 0.6] }],
        },
      },
      5: {
        name: 'Superposition',
        description: 'Two DC sources feeding a three-resistor network. Compare source contributions at node 2.',
        analysis: { kind: 'superposition', mode: 'dc' },
        netlist: [
          { name: 'V1', type: 'V', n1: 1, n2: 0, dc: 10, value: 10 },
          { name: 'V2', type: 'V', n1: 3, n2: 0, dc: 5, value: 5 },
          { name: 'R1', type: 'R', n1: 1, n2: 2, value: 1000 },
          { name: 'R2', type: 'R', n1: 2, n2: 3, value: 2000 },
          { name: 'R3', type: 'R', n1: 2, n2: 0, value: 3000 },
        ],
        layout: {
          size: [6, 4],
          components: { V1: [[1, 3], [1, 1]], V2: [[5, 3], [5, 1]], R1: [[1, 1], [3, 1]], R2: [[3, 1], [5, 1]], R3: [[3, 1], [3, 3]] },
          wires: [ [[1, 3], [5, 3]] ],
          grounds: [[1, 3]],
          labels: [{ text: 'Node 2', at: [3, 0.65] }],
        },
      },
      6: {
        name: 'Wheatstone Bridge',
        description: '9 V bridge with 1 kΩ / 2 kΩ arms and a 500 Ω galvanometer branch.',
        analysis: { kind: 'wheatstone', mode: 'dc' },
        netlist: [
          { name: 'V1', type: 'V', n1: 1, n2: 0, dc: 9, value: 9 },
          { name: 'R1', type: 'R', n1: 1, n2: 2, value: 1000 },
          { name: 'R2', type: 'R', n1: 2, n2: 0, value: 2000 },
          { name: 'R3', type: 'R', n1: 1, n2: 3, value: 2000 },
          { name: 'R4', type: 'R', n1: 3, n2: 0, value: 1000 },
          { name: 'Rg', type: 'R', n1: 2, n2: 3, value: 500 },
        ],
        layout: {
          size: [7, 5],
          components: { V1: [[1, 4], [1, 1]], R1: [[2, 1], [2, 2.5]], R2: [[2, 2.5], [2, 4]], R3: [[5, 1], [5, 2.5]], R4: [[5, 2.5], [5, 4]], Rg: [[2, 2.5], [5, 2.5]] },
          wires: [ [[1, 1], [2, 1]], [[2, 1], [5, 1]], [[1, 4], [2, 4]], [[2, 4], [5, 4]] ],
          grounds: [[1, 4]],
          labels: [{ text: 'Top rail', at: [3.5, 0.7] }, { text: 'Galvanometer', at: [3.5, 2.2] }],
        },
      },
    };
  }

  function updateHeader(circuit, result) {
    document.getElementById('cs_title').textContent = circuit.name;
    document.getElementById('cs_description').textContent = circuit.description;
    document.getElementById('cs_mode_badge').textContent = result.badge;
  }

  window.csLoadExample = function (n) {
    const all = examples();
    const selected = all[n] || all[1];
    state.currentExample = all[n] ? n : 1;
    state.currentCircuit = clone(selected);
    rootEl();
    renderEditor(state.currentCircuit);
    renderSchematic(state.currentCircuit);
    window.csRunAnalysis();
  };

  window.csRunAnalysis = function () {
    rootEl();
    const summary = document.getElementById('cs_summary');
    const details = document.getElementById('cs_details');
    try {
      const circuit = readEditedCircuit();
      state.currentCircuit = clone(circuit);
      renderSchematic(circuit);
      const result = analyzeCircuit(circuit);
      state.lastResult = result;
      updateHeader(circuit, result);
      renderSummary(result);
      renderDetails(details, result);
    } catch (err) {
      state.lastResult = null;
      if (state.currentCircuit) {
        document.getElementById('cs_title').textContent = state.currentCircuit.name;
        document.getElementById('cs_description').textContent = state.currentCircuit.description;
      }
      document.getElementById('cs_mode_badge').textContent = 'Analysis error';
      summary.textContent = '';
      summary.appendChild(mk('h3', '', 'Analysis Results'));
      const msg = mk('p', '', '⚠ ' + (err && err.message ? err.message : 'Circuit analysis failed.'));
      setStyles(msg, { color: '#fda4af' });
      summary.appendChild(msg);
      details.textContent = '';
      details.appendChild(mk('h3', '', 'Explanation'));
      details.appendChild(mk('p', 'cs-note', 'Check component values and topology, then run analysis again.'));
    }
  };

  window.csToggleDetails = function (id) {
    const el = document.getElementById(id);
    if (!el) return;
    el.classList.toggle('show');
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      if (document.getElementById('cs_root') || document.getElementById('circuit-sim-root') || document.querySelector('[data-circuit-sim-root]')) {
        window.csLoadExample(1);
      }
    });
  } else if (document.getElementById('cs_root') || document.getElementById('circuit-sim-root') || document.querySelector('[data-circuit-sim-root]')) {
    window.csLoadExample(1);
  }
})();
