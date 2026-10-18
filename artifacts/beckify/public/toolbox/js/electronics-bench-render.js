/* ============================================================================
   ELECTRONICS BENCH — SVG renderers (schematic + breadboard)
   ============================================================================
   Looks like the iOS Electronics Lab: copper current arrows, teal node dots,
   beige solderless board with banded resistors, can/disc caps, red LED, black
   DIPs and TO-92s, color-coded jumpers. SVG scales crisply on retina.
   Palette = the app's dark theme tokens (Theme.swift).
   ============================================================================ */
(function (global) {
  'use strict';
  const E = global.BeckifyBenchEngine;
  const C = {
    fg: '#E8EEF5', muted: '#94A2B2', accent: '#40BAD6', energized: '#E09C56', good: '#56D6A4',
    surface: '#12161E', inputFill: '#0E1118', border: 'rgba(255,255,255,0.10)',
  };
  const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  const f2 = (x) => (Math.round(x * 100) / 100);
  const reading = (v, unit) => E.si(v, unit || 'A');

  /* ---------- label placement (greedy, avoids parts and other labels) ---------- */
  function textWidth(text, size) { return String(text).length * size * 0.6 + 10; }
  function overlap(a, b) { return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y; }
  function placeLabels(requests, obstacles, canvas) {
    const placed = [];
    requests.forEach((r) => {
      const w = textWidth(r.text, r.size), h = r.size + 8;
      const offs = [[0, -1], [0, 1], [1, 0], [-1, 0], [1, -1], [-1, -1], [1, 1], [-1, 1], [0, -2], [0, 2], [2, 0], [-2, 0], [2, -1], [-2, -1], [2, 1], [-2, 1]];
      let best = null;
      for (let k = 0; k < offs.length && !best; k++) {
        const dx = offs[k][0] * (w / 2 + 8), dy = offs[k][1] * (h + 6);
        const box = { x: r.x + dx - w / 2, y: r.y + dy - h / 2, w, h };
        box.x = Math.max(2, Math.min(canvas.w - w - 2, box.x));
        box.y = Math.max(2, Math.min(canvas.h - h - 2, box.y));
        if (obstacles.some((o) => overlap(box, o)) || placed.some((p) => overlap(box, p.box))) continue;
        best = { box, leader: k > 3 };
      }
      if (!best) best = { box: { x: Math.max(2, Math.min(canvas.w - w - 2, r.x - w / 2)), y: Math.max(2, r.y - h - 8), w, h }, leader: true };
      placed.push({ r, box: best.box, leader: best.leader });
    });
    return placed;
  }
  function labelSvg(p, color) {
    const b = p.box, cx = b.x + b.w / 2, cy = b.y + b.h / 2;
    let s = '';
    if (p.leader) s += '<line x1="' + f2(p.r.x) + '" y1="' + f2(p.r.y) + '" x2="' + f2(cx) + '" y2="' + f2(cy) + '" stroke="' + C.muted + '" stroke-width="0.8"/>';
    s += '<rect x="' + f2(b.x) + '" y="' + f2(b.y) + '" width="' + f2(b.w) + '" height="' + f2(b.h) + '" rx="5" fill="' + C.surface + '" fill-opacity="0.92" stroke="rgba(255,255,255,0.18)"/>';
    s += '<text x="' + f2(cx) + '" y="' + f2(cy) + '" text-anchor="middle" dominant-baseline="central" font-size="' + p.r.size + '" font-weight="600" fill="' + (p.r.color || color || C.fg) + '" style="font-variant-numeric:tabular-nums">' + esc(p.r.text) + '</text>';
    return s;
  }

  /* ============================== SCHEMATIC ============================== */
  const SW = 400, SH = 320, SX = SW / 100, SY = SH / 80;
  const mp = (p) => ({ x: p.x * SX, y: p.y * SY });
  function axis(a, b) {
    const dx = b.x - a.x, dy = b.y - a.y, len = Math.hypot(dx, dy);
    if (len < 1) return null;
    const u = { x: dx / len, y: dy / len };
    return { u, n: { x: -u.y, y: u.x }, len };
  }
  const M = (p) => 'M' + f2(p.x) + ' ' + f2(p.y);
  const Lx = (p) => 'L' + f2(p.x) + ' ' + f2(p.y);
  const at = (p, u, d) => ({ x: p.x + u.x * d, y: p.y + u.y * d });

  function zigzag(a, b) {
    const ax = axis(a, b); if (!ax) return '';
    const lead = ax.len * 0.16, span = ax.len - 2 * lead, teeth = 6, amp = Math.min(7, span * 0.16);
    const start = at(a, ax.u, lead);
    let d = M(a) + Lx(start);
    for (let i = 0; i <= teeth; i++) {
      const t = i / teeth, along = at(start, ax.u, span * t);
      const sign = i === 0 || i === teeth ? 0 : (i % 2 === 0 ? 1 : -1);
      d += Lx(at(along, ax.n, amp * sign));
    }
    return d + Lx(b);
  }
  function capacitorPath(a, b) {
    const ax = axis(a, b); if (!ax) return '';
    const mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }, gap = 5, plate = Math.min(12, ax.len * 0.35);
    const l = at(mid, ax.u, -gap), r = at(mid, ax.u, gap);
    return M(a) + Lx(l) + M(r) + Lx(b) + M(at(l, ax.n, plate)) + Lx(at(l, ax.n, -plate)) + M(at(r, ax.n, plate)) + Lx(at(r, ax.n, -plate));
  }
  function inductorPath(a, b) {
    const ax = axis(a, b); if (!ax) return '';
    const lead = ax.len * 0.14, span = ax.len - 2 * lead, bumps = 4, rad = span / bumps / 2;
    const start = at(a, ax.u, lead);
    let d = M(a) + Lx(start);
    for (let i = 0; i < bumps; i++) {
      const end = at(start, ax.u, (i + 1) * rad * 2);
      d += 'A' + f2(rad) + ' ' + f2(rad) + ' 0 0 1 ' + f2(end.x) + ' ' + f2(end.y);
    }
    return d + Lx(b);
  }
  function sourcePath(a, b, ac) {
    const ax = axis(a, b); if (!ax) return '';
    const mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }, rad = Math.min(11, ax.len * 0.28);
    const p1 = at(mid, ax.u, -rad), p2 = at(mid, ax.u, rad);
    let d = M(a) + Lx(p1) + M(p1) + 'A' + rad + ' ' + rad + ' 0 1 1 ' + f2(p2.x) + ' ' + f2(p2.y) + 'A' + rad + ' ' + rad + ' 0 1 1 ' + f2(p1.x) + ' ' + f2(p1.y) + M(p2) + Lx(b);
    if (ac) {
      const span = rad * 1.35, amp = rad * 0.42;
      for (let i = 0; i <= 8; i++) {
        const t = i / 8, along = (t - 0.5) * span, w = Math.sin(t * 2 * Math.PI) * amp;
        const pt = { x: mid.x + ax.u.x * along + ax.n.x * w, y: mid.y + ax.u.y * along + ax.n.y * w };
        d += (i === 0 ? M(pt) : Lx(pt));
      }
    } else {
      const pl = at(mid, ax.u, -rad * 0.45), mi = at(mid, ax.u, rad * 0.45);
      d += M({ x: pl.x - 3, y: pl.y }) + Lx({ x: pl.x + 3, y: pl.y }) + M({ x: pl.x, y: pl.y - 3 }) + Lx({ x: pl.x, y: pl.y + 3 }) + M({ x: mi.x - 3, y: mi.y }) + Lx({ x: mi.x + 3, y: mi.y });
    }
    return d;
  }
  function diodePath(a, b, led) {
    const ax = axis(a, b); if (!ax) return '';
    const lead = ax.len * 0.22, base = at(a, ax.u, lead), tip = at(b, ax.u, -lead), amp = Math.min(9, ax.len * 0.22);
    let d = M(a) + Lx(base) + M(tip) + Lx(b) + M(at(base, ax.n, amp)) + Lx(tip) + Lx(at(base, ax.n, -amp)) + 'Z' + M(at(tip, ax.n, amp)) + Lx(at(tip, ax.n, -amp));
    if (led) {
      const corner = at(tip, ax.n, -amp * 0.2);
      for (let i = 0; i < 2; i++) {
        const tail = at(corner, ax.n, i * 4);
        const head = { x: tail.x + ax.n.x * 7 - ax.u.x * 2, y: tail.y + ax.n.y * 7 - ax.u.y * 2 };
        d += M(tail) + Lx(head);
      }
    }
    return d;
  }
  function groundPath(a) {
    let d = M(a) + Lx({ x: a.x, y: a.y + 6 });
    [14, 9, 4].forEach((w, i) => { const y = a.y + 6 + i * 4; d += M({ x: a.x - w / 2, y }) + Lx({ x: a.x + w / 2, y }); });
    return d;
  }
  function arrowHead(tip, dir, size) {
    const len = Math.hypot(dir.x, dir.y) || 1, u = { x: dir.x / len, y: dir.y / len }, n = { x: -u.y, y: u.x };
    const base = { x: tip.x - u.x * size, y: tip.y - u.y * size };
    return M(tip) + Lx({ x: base.x + n.x * size * 0.5, y: base.y + n.y * size * 0.5 }) + Lx({ x: base.x - n.x * size * 0.5, y: base.y - n.y * size * 0.5 }) + 'Z';
  }

  // Transistor symbols are drawn in schematic units (the solver's wires meet their pins), scaled to pixels.
  function npnPath(c, sc) {
    const k = SX * (sc || 1), P = (dx, dy) => ({ x: c.x + dx * k, y: c.y + dy * k });
    let d = M(P(-16, 0)) + Lx(P(-4, 0)) + M(P(-4, -12)) + Lx(P(-4, 12)) + M(P(-4, -6)) + Lx(P(10, -16)) + M(P(-4, 6)) + Lx(P(10, 16));
    return d + arrowHead(P(10, 16), { x: 0.62, y: 0.78 }, 7 * k * 0.8);
  }
  function mosPath(c, pch, sc) {
    const k = SX * (sc || 1), P = (dx, dy) => ({ x: c.x + dx * k, y: c.y + dy * k });
    let d = M(P(-18, 0)) + Lx(P(-8, 0));
    if (pch) { const r = 2.5 * k; d += M(P(-7, 0)) + 'A' + f2(r) + ' ' + f2(r) + ' 0 1 0 ' + f2(c.x - 12 * k) + ' ' + f2(c.y) + 'A' + f2(r) + ' ' + f2(r) + ' 0 1 0 ' + f2(c.x - 7 * k) + ' ' + f2(c.y); }
    d += M(P(-8, -12)) + Lx(P(-8, 12));
    [-8, 0, 8].forEach((o) => { d += M(P(-4, o - 3)) + Lx(P(-4, o + 3)); });
    d += M(P(-4, -8)) + Lx(P(12, -8)) + Lx(P(12, -18)) + M(P(-4, 8)) + Lx(P(8, 8)) + Lx(P(8, 18));
    return d + arrowHead(P(pch ? -4 : 6, 8), { x: pch ? -1 : 1, y: 0 }, 6 * k * 0.8);
  }

  function strokeEl(el, hot) {
    const a = mp(el.a), b = mp(el.b);
    const sw = (w) => (hot ? w * 1.35 : w);
    const path = (d, color, w, extra) => '<path d="' + d + '" fill="' + (extra || 'none') + '" stroke="' + color + '" stroke-width="' + sw(w) + '" stroke-linecap="round" stroke-linejoin="round"/>';
    switch (el.part) {
      case 'wire': return path(M(a) + Lx(b), hot ? C.good : C.fg, 1.6);
      case 'resistor': return path(zigzag(a, b), C.fg, 1.7);
      case 'capacitor': return path(capacitorPath(a, b), C.fg, 1.7);
      case 'inductor': return path(inductorPath(a, b), C.fg, 1.7);
      case 'voltageSource': return path(sourcePath(a, b, !!(el.flags & 1)), C.accent, 1.7);
      case 'diode': return path(diodePath(a, b, false), C.fg, 1.7);
      case 'led': return path(diodePath(a, b, true), C.energized, 1.7);
      case 'ground': return path(groundPath(a), C.fg, 1.7);
      case 'npn': return path(npnPath(a, el.scale), C.fg, 1.7);
      case 'nmos': return path(mosPath(a, false, el.scale), C.fg, 1.7);
      case 'pmos': return path(mosPath(a, true, el.scale), C.fg, 1.7);
      default: return '';
    }
  }

  function renderSchematic(sol, opts) {
    opts = opts || {};
    const layer = opts.layer || 'values';
    const hot = opts.highlight || {};
    let svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + SW + ' ' + SH + '" role="img" aria-label="' + esc(schematicSummary(sol)) + '" class="eb-svg eb-schematic" font-family="-apple-system,system-ui,Segoe UI,sans-serif">';
    svg += '<rect width="' + SW + '" height="' + SH + '" rx="10" fill="' + C.inputFill + '"/>';
    sol.elements.filter((e) => e.part === 'wire').forEach((e) => { svg += strokeEl(e, false); });
    sol.elements.filter((e) => e.part !== 'wire').forEach((e) => { svg += strokeEl(e, !!hot[e.id]); });
    const obstacles = [], reqs = [];
    const rect = (a, b, pad) => ({ x: Math.min(a.x, b.x) - pad, y: Math.min(a.y, b.y) - pad, w: Math.abs(a.x - b.x) + pad * 2, h: Math.abs(a.y - b.y) + pad * 2 });
    sol.elements.forEach((e) => {
      const a = mp(e.a), b = mp(e.b);
      if (e.part === 'wire') { obstacles.push(rect(a, b, 3)); return; }
      obstacles.push(rect(a, b, 12));
      const mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }, dx = b.x - a.x, dy = b.y - a.y, len = Math.max(Math.hypot(dx, dy), 1);
      const anchor = { x: mid.x - dy / len * 12, y: mid.y + dx / len * 12 };
      if (e.part === 'ground') return;
      const ref = e.label || e.id.toUpperCase();
      const text = layer === 'minimal' ? ref : (e.detail ? ref + ' ' + e.detail : ref);
      reqs.push({ text, x: anchor.x, y: anchor.y, size: 13, color: C.muted });
    });
    const nreq = [];
    sol.nodes.forEach((nd) => {
      const c = mp(nd.at);
      obstacles.push({ x: c.x - 10, y: c.y - 10, w: 20, h: 20 });
      if (layer === 'minimal') return;
      nreq.push({ text: nd.name + ' ' + E.si(nd.value, nd.unit || 'V'), x: c.x, y: c.y, size: 14, color: opts.pickedNode === nd.id ? C.good : C.fg });
    });
    const breq = [];
    sol.branches.forEach((br) => {
      const a = mp(br.a), b = mp(br.b), mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
      obstacles.push({ x: a.x + (b.x - a.x) * 0.72 - 9, y: a.y + (b.y - a.y) * 0.72 - 9, w: 18, h: 18 });
      if (layer === 'minimal') return;
      breq.push({ text: br.name + ' ' + reading(Math.abs(br.value), br.unit || 'A'), x: mid.x, y: mid.y, size: 14, color: C.energized });
    });
    const all = nreq.concat(breq, reqs);
    if (all.length > 10) all.forEach((r) => { r.size = Math.max(10, r.size - (all.length > 13 ? 3 : 2)); });
    const placed = placeLabels(all, obstacles, { w: SW, h: SH });
    placed.forEach((p) => { svg += labelSvg(p); });
    // current arrows with animated dot, then node dots
    const reduce = global.matchMedia && global.matchMedia('(prefers-reduced-motion: reduce)').matches;
    sol.branches.forEach((br) => {
      if (!(Math.abs(br.value) > 1e-15 || br.unit === '')) return;
      const s = mp(br.value >= 0 ? br.a : br.b), e = mp(br.value >= 0 ? br.b : br.a);
      const dx = e.x - s.x, dy = e.y - s.y, len = Math.hypot(dx, dy);
      if (len <= 8) return;
      const u = { x: dx / len, y: dy / len };
      svg += '<path d="' + arrowHead({ x: s.x + dx * 0.72, y: s.y + dy * 0.72 }, u, 8) + '" fill="' + C.energized + '"/>';
      svg += '<circle r="3" fill="' + C.energized + '" fill-opacity="0.9" cx="' + f2(s.x) + '" cy="' + f2(s.y) + '">' +
        (reduce ? '' : '<animateMotion dur="2.4s" repeatCount="indefinite" path="M0 0 L' + f2(dx) + ' ' + f2(dy) + '"/>') + '</circle>';
    });
    sol.nodes.forEach((nd) => {
      const c = mp(nd.at);
      svg += '<circle cx="' + f2(c.x) + '" cy="' + f2(c.y) + '" r="' + (opts.pickedNode === nd.id ? 6 : 4.5) + '" fill="' + (opts.pickedNode === nd.id ? C.good : C.accent) + '"/>';
    });
    return svg + '</svg>';
  }
  function schematicSummary(sol) {
    const nodes = sol.nodes.map((n) => n.name + ' ' + E.si(n.value, n.unit)).join(', ');
    const branches = sol.branches.map((b) => b.name + ' ' + E.si(b.value, b.unit || 'A')).join(', ');
    const sources = sol.elements.filter((e) => e.part === 'voltageSource').map((e) => ((e.flags & 1) ? 'AC sine' : 'DC') + ' source, ' + e.label + ' ' + e.detail).join('. ');
    return 'Schematic. ' + (sources ? sources + '. ' : '') + 'Nodes: ' + nodes + '. Branches: ' + branches + '.';
  }

  /* ============================== BREADBOARD ============================== */
  const WIRE = { red: '#E23B32', black: '#1C1C1C', blue: '#2457C5', yellow: '#E6B400', green: '#2E9E45', orange: '#F07A14', violet: '#7A3FF0', white: '#F7F4EE' };
  const BAND = { black: '#1A1A1A', brown: '#8B4513', red: '#D32F2F', orange: '#F57C00', yellow: '#F6D000', green: '#2E7D32', blue: '#1565C0', violet: '#6A1B9A', gray: '#9E9E9E', white: '#F5F5F5', gold: '#D4AF37', silver: '#C0C0C0' };
  const netWire = (net) => (net === 'GND' ? WIRE.black : net === '−V' ? WIRE.blue : WIRE.red);
  const UNIT_H = E.ROW_Y.botPlus;

  function bbSize(p) { return { w: 92 + E.BB_COLUMNS * p + 16, h: 28 + 15.4 * p + 20 }; }
  function bbMap(p) {
    return {
      p,
      pt: (x, y) => ({ x: 92 + (x - 1) * p, y: 22 + (UNIT_H - y) * p }),
      c(h) { return this.pt(h.column, E.ROW_Y[h.row]); },
    };
  }
  function partName(c, layer) {
    const t = c.part.type; let full;
    if (c.part.label && t !== 'npn' && t !== 'nmos' && t !== 'pmos' && t !== 'dip8' && t !== 'dip14' && t !== 'display') full = c.part.label;
    else if (t === 'display') full = c.id.toUpperCase() + '  ' + c.part.name + ' digit ' + c.part.digit;
    else full = c.id.toUpperCase() + '  ' + c.part.name;
    if (layer === 'minimal') return String(full).split(/\s+/)[0];
    return full;
  }

  function renderBreadboard(layout, opts) {
    opts = opts || {};
    const p = opts.pitch || 20, layer = opts.layer || 'values', sel = opts.selected || null, hl = opts.highlightNets || {};
    const size = bbSize(p), map = bbMap(p);
    const o = [];
    const A = (s) => o.push(s);
    A('<svg xmlns="http://www.w3.org/2000/svg" width="' + f2(size.w) + '" height="' + f2(size.h) + '" viewBox="0 0 ' + f2(size.w) + ' ' + f2(size.h) + '" class="eb-svg eb-breadboard" role="img" aria-label="' + esc(bbSummary(layout)) + '" font-family="-apple-system,system-ui,Segoe UI,sans-serif">');
    A('<defs><linearGradient id="ebBoard" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E4DDD2"/><stop offset="1" stop-color="#C9C2B6"/></linearGradient>' +
      '<linearGradient id="ebChip" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3A3A3A"/><stop offset="1" stop-color="#141414"/></linearGradient>' +
      '<radialGradient id="ebLed" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#FF8A80"/><stop offset="1" stop-color="#E10600"/></radialGradient></defs>');
    A('<rect width="' + f2(size.w) + '" height="' + f2(size.h) + '" rx="10" fill="' + C.inputFill + '"/>');
    // board
    const left = map.c({ column: 1, row: 'a' }).x - p * 0.85, right = map.c({ column: E.BB_COLUMNS, row: 'a' }).x + p * 0.85;
    const top = map.c({ column: 1, row: 'botPlus' }).y - p * 0.85, bottom = map.c({ column: 1, row: 'topPlus' }).y + p * 0.85;
    A('<rect x="' + f2(left) + '" y="' + f2(top + 3) + '" width="' + f2(right - left) + '" height="' + f2(bottom - top) + '" rx="14" fill="#000" fill-opacity="0.18"/>');
    A('<rect x="' + f2(left) + '" y="' + f2(top) + '" width="' + f2(right - left) + '" height="' + f2(bottom - top) + '" rx="12" fill="url(#ebBoard)" stroke="#8E877C" stroke-width="1.2"/>');
    const gT = map.c({ column: 1, row: 'f' }).y + p * 0.42, gB = map.c({ column: 1, row: 'e' }).y - p * 0.42;
    A('<rect x="' + f2(left + 8) + '" y="' + f2(gT) + '" width="' + f2(right - left - 16) + '" height="' + f2(gB - gT) + '" rx="5" fill="#B7A99A" stroke="#9A8C7E" stroke-opacity="0.7" stroke-width="0.8"/>');
    // rails
    const x0 = map.c({ column: 1, row: 'a' }).x - p * 0.45, x1 = map.c({ column: layout.columns, row: 'a' }).x + p * 0.45;
    const stripe = (row, off, color) => { const y = map.c({ column: 1, row }).y + p * off; A('<rect x="' + f2(x0) + '" y="' + f2(y) + '" width="' + f2(x1 - x0) + '" height="' + f2(p * 0.16) + '" rx="2" fill="' + color + '"/>'); };
    stripe('topPlus', 0.30, '#E23B32'); stripe('topMinus', -0.44, '#2A57C4'); stripe('botMinus', 0.30, '#2A57C4'); stripe('botPlus', -0.44, '#E23B32');
    const mark = (g, pt, color) => A('<text x="' + f2(pt.x + p * 0.34) + '" y="' + f2(pt.y) + '" dominant-baseline="central" font-size="' + f2(Math.max(7, p * 0.32)) + '" font-weight="700" fill="' + color + '">' + g + '</text>');
    for (let col = 1; col <= layout.columns; col += 5) {
      mark('+', map.c({ column: col, row: 'topPlus' }), '#E23B32'); mark('−', map.c({ column: col, row: 'topMinus' }), '#2A57C4');
      mark('−', map.c({ column: col, row: 'botMinus' }), '#2A57C4'); mark('+', map.c({ column: col, row: 'botPlus' }), '#E23B32');
    }
    (layout.railLabels || []).forEach((l) => {
      const pt = map.c({ column: 1, row: l.row });
      A('<text x="' + f2(pt.x - p * 0.95) + '" y="' + f2(pt.y) + '" text-anchor="end" dominant-baseline="central" font-size="' + f2(Math.max(8, p * 0.42)) + '" font-weight="700" fill="#3E3A34">' + esc(l.text) + '</text>');
    });
    // holes
    const d = p * 0.34;
    let holes = '';
    for (let col = 1; col <= layout.columns; col++) {
      E.BB_ROWS.forEach((row) => {
        const c = map.c({ column: col, row });
        holes += '<circle cx="' + f2(c.x) + '" cy="' + f2(c.y) + '" r="' + f2(d / 2) + '"/>';
      });
    }
    A('<g fill="#2C3036">' + holes + '</g>');
    // row/column indexes
    ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'].forEach((row) => {
      const pt = map.c({ column: 1, row });
      A('<text x="' + f2(pt.x - p * 0.72) + '" y="' + f2(pt.y) + '" text-anchor="end" dominant-baseline="central" font-size="' + f2(Math.max(7, p * 0.36)) + '" font-weight="500" fill="#6E675C">' + row + '</text>');
    });
    [1, 5, 10, 15, 20, 25, 30].forEach((col) => {
      if (col > layout.columns) return;
      const pt = map.c({ column: col, row: 'botPlus' });
      A('<text x="' + f2(pt.x) + '" y="' + f2(pt.y - p * 0.78) + '" text-anchor="middle" font-size="' + f2(Math.max(7, p * 0.34)) + '" font-weight="600" fill="#5C564C">' + col + '</text>');
    });
    // supplies
    (layout.supplies || []).forEach((s) => {
      const ys = s.leads.map((l) => map.c(l.hole).y), minY = Math.min.apply(null, ys), maxY = Math.max.apply(null, ys);
      const brick = { x: 8, y: minY - 16, w: 52, h: maxY - minY + 36 };
      A('<rect x="' + brick.x + '" y="' + f2(brick.y) + '" width="' + brick.w + '" height="' + f2(brick.h) + '" rx="6" fill="#2F343C" stroke="#1B1E24"/>');
      A('<text x="' + (brick.x + brick.w / 2) + '" y="' + f2(brick.y + brick.h / 2) + '" text-anchor="middle" dominant-baseline="central" font-size="10" font-weight="700" fill="#fff">' + esc(s.label) + '</text>');
      s.leads.forEach((l) => {
        const end = map.c(l.hole), col = netWire(l.net), my = brick.y + brick.h / 2;
        A('<path d="M' + (brick.x + brick.w) + ' ' + f2(my) + 'L' + f2(end.x - p * 0.2) + ' ' + f2(my) + 'L' + f2(end.x) + ' ' + f2(end.y) + '" fill="none" stroke="' + col + '" stroke-width="' + f2(p * 0.14) + '" stroke-linecap="round" stroke-linejoin="round"/>');
        plug(A, end, col, p);
      });
    });
    // jumpers
    (layout.jumpers || []).forEach((j) => {
      const pts = E.manhattan(j.a, j.b).map((q) => map.pt(q.x, q.y));
      const dpath = pts.map((q, i) => (i ? 'L' : 'M') + f2(q.x) + ' ' + f2(q.y)).join('');
      const col = WIRE[j.color], emph = !!hl[j.net];
      A('<path d="' + dpath + '" fill="none" stroke="' + col + '" stroke-opacity="0.35" stroke-width="' + f2(p * 0.22) + '" stroke-linecap="round" stroke-linejoin="round"/>');
      A('<path d="' + dpath + '" fill="none" stroke="' + col + '" stroke-width="' + f2(Math.max(emph ? 3.4 : 2.2, p * (emph ? 0.22 : 0.16))) + '" stroke-linecap="round" stroke-linejoin="round"/>');
      plug(A, pts[0], col, p); plug(A, pts[pts.length - 1], col, p);
    });
    // components
    layout.components.forEach((c) => {
      drawComponent(A, c, map);
      if (c.id === sel) {
        const cs = c.leads.map((l) => map.c(l.hole)), mx = cs.reduce((s, q) => s + q.x, 0) / cs.length, my = cs.reduce((s, q) => s + q.y, 0) / cs.length;
        A('<circle cx="' + f2(mx) + '" cy="' + f2(my) + '" r="' + f2(p * 1.6) + '" fill="none" stroke="#22D3EE" stroke-opacity="0.95" stroke-width="2"/>');
      }
    });
    // meters
    const showMeters = layer === 'measurements' || layer === 'all' || (layer === 'values' && p >= 12);
    if (showMeters) layout.meters.slice(0, layer === 'values' ? 4 : layout.meters.length).forEach((m) => drawMeter(A, m, map));
    // labels
    const obstacles = [], reqs = [];
    layout.components.forEach((c) => {
      const cs = c.leads.map((l) => map.c(l.hole)), pad = p * 0.65;
      const minX = Math.min.apply(null, cs.map((q) => q.x)), maxX = Math.max.apply(null, cs.map((q) => q.x));
      const minY = Math.min.apply(null, cs.map((q) => q.y)), maxY = Math.max.apply(null, cs.map((q) => q.y));
      obstacles.push({ x: minX - pad, y: minY - pad, w: Math.max(maxX - minX + pad * 2, p * 1.7), h: Math.max(maxY - minY + pad * 2, p * 1.7) });
      reqs.push({ text: partName(c, layer), x: cs.reduce((s, q) => s + q.x, 0) / cs.length, y: cs.reduce((s, q) => s + q.y, 0) / cs.length, size: Math.max(9, Math.min(13, p * 0.62)), color: '#2C2924' });
    });
    layout.jumpers.forEach((j) => {
      const pts = E.manhattan(j.a, j.b).map((q) => map.pt(q.x, q.y));
      for (let i = 1; i < pts.length; i++) obstacles.push({ x: Math.min(pts[i - 1].x, pts[i].x) - 3, y: Math.min(pts[i - 1].y, pts[i].y) - 3, w: Math.abs(pts[i - 1].x - pts[i].x) + 6, h: Math.abs(pts[i - 1].y - pts[i].y) + 6 });
    });
    layout.supplies.forEach((s) => {
      const ys = s.leads.map((l) => map.c(l.hole).y);
      obstacles.push({ x: 8, y: Math.min.apply(null, ys) - 16, w: 52, h: Math.max.apply(null, ys) - Math.min.apply(null, ys) + 36 });
    });
    if (showMeters) layout.meters.forEach((m) => { const a = map.c(m.hole), w = textWidth(m.title + ' ' + m.reading, 13); obstacles.push({ x: a.x - w / 2 - 6, y: a.y - p * 0.95 - 12, w: w + 12, h: 24 }); });
    placeLabels(reqs, obstacles, { w: size.w, h: size.h }).forEach((pl) => {
      const b = pl.box;
      if (pl.leader) A('<line x1="' + f2(pl.r.x) + '" y1="' + f2(pl.r.y) + '" x2="' + f2(b.x + b.w / 2) + '" y2="' + f2(b.y + b.h / 2) + '" stroke="#6E675C" stroke-width="0.8"/>');
      A('<rect x="' + f2(b.x) + '" y="' + f2(b.y) + '" width="' + f2(b.w) + '" height="' + f2(b.h) + '" rx="4" fill="#E4DDD2" fill-opacity="0.98" stroke="#8E877C" stroke-width="0.8"/>');
      A('<text x="' + f2(b.x + b.w / 2) + '" y="' + f2(b.y + b.h / 2) + '" text-anchor="middle" dominant-baseline="central" font-size="' + pl.r.size + '" font-weight="600" fill="#2C2924" style="font-variant-numeric:tabular-nums">' + esc(pl.r.text) + '</text>');
    });
    A('</svg>');
    return o.join('');
  }
  function bbSummary(layout) {
    const parts = layout.components.map((c) => partName(c, 'values')).join(', ');
    const meters = layout.meters.map((m) => m.title + ' ' + m.reading).join('  ·  ');
    return 'Breadboard. ' + parts + '. ' + layout.caption + (meters ? ' Readings: ' + meters + '.' : '');
  }
  function plug(A, pt, color, p) {
    A('<circle cx="' + f2(pt.x) + '" cy="' + f2(pt.y) + '" r="' + f2(p * 0.11) + '" fill="' + color + '" stroke="#000" stroke-opacity="0.35" stroke-width="0.6"/>');
  }
  function lead(A, a, b, p) {
    A('<line x1="' + f2(a.x) + '" y1="' + f2(a.y) + '" x2="' + f2(b.x) + '" y2="' + f2(b.y) + '" stroke="#B7BDC4" stroke-width="' + f2(Math.max(1.2, p * 0.07)) + '" stroke-linecap="round"/>');
  }
  function drawMeter(A, m, map) {
    const a = map.c(m.hole), p = map.p, title = m.title + ' ' + m.reading, fs = Math.min(15, Math.max(12, p * 0.55));
    const w = textWidth(title, fs), h = Math.max(fs + 8, p * 0.7), cur = m.kind === 'current';
    const cy = a.y + (cur ? -p * 0.95 : -p * 0.72);
    A('<rect x="' + f2(a.x - w / 2) + '" y="' + f2(cy - h / 2) + '" width="' + f2(w) + '" height="' + f2(h) + '" rx="5" fill="' + (cur ? '#D6E6FF' : '#DFF5E2') + '" fill-opacity="0.94" stroke="' + (cur ? '#3D6FB4' : '#3D8B4F') + '"/>');
    A('<text x="' + f2(a.x) + '" y="' + f2(cy) + '" text-anchor="middle" dominant-baseline="central" font-size="' + f2(fs) + '" font-weight="700" fill="' + (cur ? '#0B3D91' : '#1B5E20') + '" style="font-variant-numeric:tabular-nums">' + esc(title) + '</text>');
  }
  const rot = (mid, ang) => 'translate(' + f2(mid.x) + ' ' + f2(mid.y) + ') rotate(' + f2(ang * 180 / Math.PI) + ')';

  function drawComponent(A, c, map) {
    const p = map.p, t = c.part.type, L = c.leads.map((l) => map.c(l.hole));
    if (t === 'resistor' && L.length === 2) {
      lead(A, L[0], L[1], p);
      const mid = { x: (L[0].x + L[1].x) / 2, y: (L[0].y + L[1].y) / 2 }, ang = Math.atan2(L[1].y - L[0].y, L[1].x - L[0].x);
      const len = Math.max(Math.hypot(L[1].x - L[0].x, L[1].y - L[0].y) * 0.62, p * 1.15), h = p * 0.42;
      let g = '<g transform="' + rot(mid, ang) + '"><rect x="' + f2(-len / 2) + '" y="' + f2(-h / 2) + '" width="' + f2(len) + '" height="' + f2(h) + '" rx="' + f2(h / 2) + '" fill="#E4C99A" stroke="#C4A574" stroke-width="0.6"/>';
      const bands = c.part.bands || [], count = Math.max(bands.length, 1);
      bands.forEach((name, i) => {
        const tt = -0.28 + i * (i === count - 1 ? 0.2 : 0.13);
        g += '<rect x="' + f2(len * tt - p * 0.055) + '" y="' + f2(-h / 2) + '" width="' + f2(p * 0.11) + '" height="' + f2(h) + '" fill="' + (BAND[name] || '#888') + '"/>';
      });
      A(g + '</g>');
    } else if (t === 'ceramic' && L.length === 2) {
      lead(A, L[0], L[1], p);
      const mid = { x: (L[0].x + L[1].x) / 2, y: (L[0].y + L[1].y) / 2 }, r = p * 0.48;
      A('<ellipse cx="' + f2(mid.x) + '" cy="' + f2(mid.y) + '" rx="' + f2(r) + '" ry="' + f2(r * 0.82) + '" fill="#E07A32" stroke="#A8501C" stroke-width="0.8"/>');
    } else if (t === 'electrolytic' && L.length === 2) {
      lead(A, L[0], L[1], p);
      const mid = { x: (L[0].x + L[1].x) / 2, y: (L[0].y + L[1].y) / 2 }, ang = Math.atan2(L[1].y - L[0].y, L[1].x - L[0].x);
      const len = Math.max(Math.hypot(L[1].x - L[0].x, L[1].y - L[0].y) * 0.5, p * 0.9), h = p * 0.7, fs = f2(Math.max(8, p * 0.4));
      A('<g transform="' + rot(mid, ang) + '"><rect x="' + f2(-len / 2) + '" y="' + f2(-h / 2) + '" width="' + f2(len) + '" height="' + f2(h) + '" rx="3" fill="#1E4E86" stroke="#0E2C52" stroke-width="0.8"/>' +
        '<rect x="' + f2(len * 0.18) + '" y="' + f2(-h / 2) + '" width="' + f2(p * 0.16) + '" height="' + f2(h) + '" fill="#fff" fill-opacity="0.92"/>' +
        '<text x="' + f2(len * 0.28) + '" y="0" text-anchor="middle" dominant-baseline="central" font-size="' + fs + '" font-weight="700" fill="#1E4E86">−</text>' +
        '<text x="' + f2(-len * 0.22) + '" y="0" text-anchor="middle" dominant-baseline="central" font-size="' + fs + '" font-weight="700" fill="#fff">+</text></g>');
    } else if (t === 'led' && L.length === 2) {
      lead(A, L[0], L[1], p);
      const mid = { x: (L[0].x + L[1].x) / 2, y: (L[0].y + L[1].y) / 2 }, r = p * 0.42, ang = Math.atan2(L[1].y - L[0].y, L[1].x - L[0].x);
      const cut = { x: mid.x + Math.cos(ang) * r * 0.72, y: mid.y + Math.sin(ang) * r * 0.72 };
      A('<circle cx="' + f2(mid.x) + '" cy="' + f2(mid.y) + '" r="' + f2(r * 1.35) + '" fill="#FF3B30" fill-opacity="0.28"/>' +
        '<circle cx="' + f2(mid.x) + '" cy="' + f2(mid.y) + '" r="' + f2(r) + '" fill="url(#ebLed)"/>' +
        '<line x1="' + f2(cut.x - Math.sin(ang) * r) + '" y1="' + f2(cut.y + Math.cos(ang) * r) + '" x2="' + f2(cut.x + Math.sin(ang) * r) + '" y2="' + f2(cut.y - Math.cos(ang) * r) + '" stroke="#7A120C" stroke-width="1.4" stroke-linecap="round"/>' +
        '<ellipse cx="' + f2(mid.x - r * 0.26) + '" cy="' + f2(mid.y - r * 0.36) + '" rx="' + f2(r * 0.19) + '" ry="' + f2(r * 0.14) + '" fill="#fff" fill-opacity="0.7"/>');
    } else if (t === 'diode' && L.length === 2) {
      lead(A, L[0], L[1], p);
      const mid = { x: (L[0].x + L[1].x) / 2, y: (L[0].y + L[1].y) / 2 }, ang = Math.atan2(L[1].y - L[0].y, L[1].x - L[0].x), body = p * 0.55, half = p * 0.28;
      A('<g transform="' + rot(mid, ang) + '"><path d="M' + f2(-body / 2) + ' ' + f2(-half) + 'L' + f2(body / 2) + ' 0L' + f2(-body / 2) + ' ' + f2(half) + 'Z" fill="#2B2B2B"/>' +
        '<line x1="' + f2(body / 2) + '" y1="' + f2(-half) + '" x2="' + f2(body / 2) + '" y2="' + f2(half) + '" stroke="#E8E2D8" stroke-width="' + f2(Math.max(1.4, p * 0.1)) + '"/></g>');
    } else if (t === 'inductor' && L.length === 2) {
      lead(A, L[0], L[1], p);
      const mid = { x: (L[0].x + L[1].x) / 2, y: (L[0].y + L[1].y) / 2 }, ang = Math.atan2(L[1].y - L[0].y, L[1].x - L[0].x);
      const len = Math.max(Math.hypot(L[1].x - L[0].x, L[1].y - L[0].y) * 0.55, p * 1.1), amp = p * 0.22, turns = 4;
      let dd = 'M' + f2(-len / 2) + ' 0';
      for (let i = 0; i < turns; i++) {
        const x0 = -len / 2 + i * len / turns, x1 = x0 + len / turns;
        dd += 'C' + f2(x0 + (x1 - x0) * 0.25) + ' ' + f2(-amp * 1.33) + ' ' + f2(x0 + (x1 - x0) * 0.75) + ' ' + f2(-amp * 1.33) + ' ' + f2(x1) + ' 0';
      }
      A('<path transform="' + rot(mid, ang) + '" d="' + dd + '" fill="none" stroke="#4A5560" stroke-width="' + f2(Math.max(1.6, p * 0.12)) + '" stroke-linecap="round"/>');
    } else if (t === 'source' && L.length === 2) {
      lead(A, L[0], L[1], p);
      const mid = { x: (L[0].x + L[1].x) / 2, y: (L[0].y + L[1].y) / 2 }, ang = Math.atan2(L[1].y - L[0].y, L[1].x - L[0].x), w = p * 0.85, h = p * 0.55, fs = f2(Math.max(8, p * 0.4));
      A('<g transform="' + rot(mid, ang) + '"><rect x="' + f2(-w / 2) + '" y="' + f2(-h / 2) + '" width="' + f2(w) + '" height="' + f2(h) + '" rx="3" fill="#F4F0E6" stroke="#3E3A34"/>' +
        '<text x="' + f2(-w * 0.22) + '" y="0" text-anchor="middle" dominant-baseline="central" font-size="' + fs + '" font-weight="700" fill="#C62828">+</text>' +
        '<text x="' + f2(w * 0.22) + '" y="0" text-anchor="middle" dominant-baseline="central" font-size="' + fs + '" font-weight="700" fill="#1A1A1A">−</text></g>');
    } else if ((t === 'npn' || t === 'nmos' || t === 'pmos') && L.length === 3) {
      const marks = ['E', 'B', 'C'].map((m, i) => (t === 'npn' ? m : ['S', 'G', 'D'][i]));
      const midx = (L[0].x + L[2].x) / 2, midy = Math.min.apply(null, L.map((q) => q.y)) - p * 0.15;
      L.forEach((pin) => lead(A, pin, { x: pin.x, y: midy }, p));
      const bx = midx - p * 0.85, by = midy - p * 0.95, bw = p * 1.7, bh = p * 1.15, r = bw / 2;
      A('<path d="M' + f2(bx) + ' ' + f2(by + r) + 'A' + f2(r) + ' ' + f2(r) + ' 0 0 1 ' + f2(bx + bw) + ' ' + f2(by + r) + 'L' + f2(bx + bw) + ' ' + f2(by + bh) + 'L' + f2(bx) + ' ' + f2(by + bh) + 'Z" fill="#1A1A1A" stroke="#0A0A0A" stroke-width="0.8"/>');
      A('<text x="' + f2(bx + bw / 2) + '" y="' + f2(by + bh / 2 - 1) + '" text-anchor="middle" dominant-baseline="central" font-size="' + f2(Math.max(6, Math.min(9, p * 0.48))) + '" font-weight="700" fill="#fff">' + (t === 'npn' ? 'Q' : 'M') + '</text>');
      L.forEach((pin, i) => A('<text x="' + f2(pin.x) + '" y="' + f2(pin.y + p * 0.38) + '" text-anchor="middle" dominant-baseline="hanging" font-size="' + f2(Math.max(7, p * 0.32)) + '" font-weight="700" fill="#3E3A34">' + marks[i] + '</text>'));
    } else if ((t === 'dip8' || t === 'dip14') && L.length >= 8) {
      const per = L.length / 2, xs = L.map((q) => q.x), ys = L.map((q) => q.y);
      const lx = Math.min.apply(null, xs), rx = Math.max.apply(null, xs), ty = Math.min.apply(null, ys), by = Math.max.apply(null, ys);
      const body = { x: lx - p * 0.28, y: ty + p * 0.28, w: rx - lx + p * 0.56, h: by - ty - p * 0.56 };
      L.forEach((pin, i) => {
        A('<line x1="' + f2(pin.x) + '" y1="' + f2(pin.y) + '" x2="' + f2(pin.x) + '" y2="' + f2(i < per ? body.y + body.h : body.y) + '" stroke="#C5CCD2" stroke-width="' + f2(Math.max(1.4, p * 0.09)) + '"/>');
        plug(A, pin, '#9AA3AB', p * 0.7);
      });
      A('<rect x="' + f2(body.x) + '" y="' + f2(body.y) + '" width="' + f2(body.w) + '" height="' + f2(body.h) + '" rx="3" fill="url(#ebChip)" stroke="#0A0A0A"/>');
      A('<path d="M' + f2(body.x + Math.cos(-70 * Math.PI / 180) * p * 0.22) + ' ' + f2(body.y + body.h / 2 + Math.sin(-70 * Math.PI / 180) * p * 0.22) + 'A' + f2(p * 0.22) + ' ' + f2(p * 0.22) + ' 0 0 1 ' + f2(body.x + Math.cos(70 * Math.PI / 180) * p * 0.22) + ' ' + f2(body.y + body.h / 2 + Math.sin(70 * Math.PI / 180) * p * 0.22) + '" fill="none" stroke="#D7D3CC" stroke-width="1.3" stroke-linecap="round"/>');
      A('<circle cx="' + f2(body.x + p * 0.26) + '" cy="' + f2(body.y + body.h - p * 0.24) + '" r="' + f2(p * 0.08) + '" fill="#fff"/>');
      const fit = (body.w - p * 0.9) / (Math.max(c.part.name.length, 1) * 0.62), ts = Math.min(Math.max(11, p * 0.62), Math.max(6.5, fit));
      A('<text x="' + f2(body.x + body.w / 2) + '" y="' + f2(body.y + body.h / 2) + '" text-anchor="middle" dominant-baseline="central" font-size="' + f2(ts) + '" font-weight="700" fill="#fff">' + esc(c.part.name) + '</text>');
    }
  }

  /* ---------- inspector rows ---------- */
  function inspectorRows(sol) {
    const rows = [];
    sol.quantities.forEach((qq) => rows.push({ kind: 'Quantity', name: qq.name, value: E.si(qq.value, qq.unit), emphasis: qq.emphasis }));
    sol.nodes.forEach((nd) => rows.push({ kind: 'Node', name: nd.name, value: E.si(nd.value, nd.unit || 'V') }));
    sol.branches.forEach((b) => rows.push({ kind: 'Branch', name: b.name, value: E.si(b.value, b.unit || 'A') }));
    sol.elements.filter((e) => e.part !== 'wire' && e.part !== 'ground').forEach((e) => rows.push({ kind: 'Part', name: e.label || e.id, value: e.detail }));
    return rows;
  }

  global.BeckifyBenchRender = { renderSchematic, renderBreadboard, bbSize, inspectorRows, schematicSummary, bbSummary, C };
})(typeof window !== 'undefined' ? window : globalThis);
