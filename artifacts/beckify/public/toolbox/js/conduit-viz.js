/* ============================================================================
   CONDUIT CROSS-SECTION — to-scale raceway drawing for the Conduit Fill tools.
   ============================================================================
   Port of ios/BeckifyMath/Sources/BeckifyMath/ConduitCrossSection.swift:
   Chapter 9 Table 4 bores (ID, nominal OD where one number is published),
   Table 5 conductor overall diameter from area, Table 8 metal diameter, and the
   same "settled" circle pack (largest conductors toward the bottom, each new
   circle touching two neighbours or the wall).

   The drawing is illustrative. Table 1 percent fill is the NEC check; this is
   not a jam or pull-tension check. Needs nec-data.js (CONDUIT_TYPES,
   WIRE_CMIL, INSULATION_TYPES, wireSizeLabel) and result-visuals.js (shell).
   ============================================================================ */
(function () {
  'use strict';

  var SVG_NS = 'http://www.w3.org/2000/svg';
  var C = {
    bg: '#080b10', surface: '#12161e', accent: '#40bad6', blue: '#609ce6',
    copper: '#e09c56', good: '#56d6a4', warn: '#f0bc48', bad: '#f47078',
    text: '#e8eef5', muted: '#94a2b2', line: 'rgba(148,162,178,0.45)',
  };
  /* Group tints — the app's category colors, in a CVD-friendly order. */
  var GROUP_COLORS = ['#40bad6', '#e09c56', '#609ce6', '#56d6a4', '#f0bc48', '#f47078', '#b58cf0', '#e07fc0'];

  /* Chapter 9 Table 4 internal diameters; OD is the nominal standard OD
     (EMT ANSI C80.3; IMC C80.6; RMC C80.1; PVC ASTM D1785). ENT/FMC/LFMC have
     no single listed OD, so those draw the bore with a thin jacket. */
  var NPS_OD = {
    '1/2': 0.840, '3/4': 1.050, '1': 1.315, '1-1/4': 1.660, '1-1/2': 1.900,
    '2': 2.375, '2-1/2': 2.875, '3': 3.500, '3-1/2': 4.000, '4': 4.500,
    '5': 5.563, '6': 6.625,
  };
  var EMT_OD = {
    '1/2': 0.706, '3/4': 0.922, '1': 1.163, '1-1/4': 1.510, '1-1/2': 1.740,
    '2': 2.197, '2-1/2': 2.875, '3': 3.500, '3-1/2': 4.000, '4': 4.500,
  };
  var ID = {
    EMT: { '1/2': 0.622, '3/4': 0.824, '1': 1.049, '1-1/4': 1.380, '1-1/2': 1.610, '2': 2.067, '2-1/2': 2.731, '3': 3.356, '3-1/2': 3.834, '4': 4.334 },
    IMC: { '1/2': 0.660, '3/4': 0.864, '1': 1.105, '1-1/4': 1.448, '1-1/2': 1.683, '2': 2.150, '2-1/2': 2.557, '3': 3.176, '3-1/2': 3.671, '4': 4.166 },
    RMC: { '1/2': 0.632, '3/4': 0.836, '1': 1.063, '1-1/4': 1.394, '1-1/2': 1.624, '2': 2.083, '2-1/2': 2.489, '3': 3.090, '3-1/2': 3.570, '4': 4.050, '5': 5.073, '6': 6.093 },
    PVC40: { '1/2': 0.602, '3/4': 0.804, '1': 1.029, '1-1/4': 1.360, '1-1/2': 1.590, '2': 2.047, '2-1/2': 2.445, '3': 3.042, '3-1/2': 3.521, '4': 3.998, '5': 5.016, '6': 6.031 },
    PVC80: { '1/2': 0.526, '3/4': 0.722, '1': 0.936, '1-1/4': 1.255, '1-1/2': 1.476, '2': 1.913, '2-1/2': 2.290, '3': 2.864, '3-1/2': 3.326, '4': 3.786, '5': 4.768, '6': 5.709 },
    ENT: { '1/2': 0.602, '3/4': 0.804, '1': 1.029, '1-1/4': 1.360, '1-1/2': 1.590, '2': 2.047 },
    FMC: { '1/2': 0.635, '3/4': 0.824, '1': 1.020, '1-1/4': 1.275, '1-1/2': 1.538, '2': 2.040, '2-1/2': 2.500, '3': 3.000, '3-1/2': 3.500, '4': 4.000 },
    LFMC: { '1/2': 0.632, '3/4': 0.830, '1': 1.054, '1-1/4': 1.395, '1-1/2': 1.588, '2': 2.033, '2-1/2': 2.493, '3': 3.085, '3-1/2': 3.520, '4': 4.020 },
  };
  var METAL = { EMT: 'steel', IMC: 'steel', RMC: 'steel', PVC40: 'pvc', PVC80: 'pvc', ENT: 'flex', FMC: 'flex', LFMC: 'flex' };

  function bore(type, trade) {
    var id = ID[type] && ID[type][trade];
    if (!id) return null;
    var od = null;
    if (type === 'EMT') od = EMT_OD[trade] || null;
    else if (type === 'IMC' || type === 'RMC' || type === 'PVC40' || type === 'PVC80') od = NPS_OD[trade] || null;
    return { id: id, od: od };
  }

  function overallDiameter(area) {
    return area > 0 ? 2 * Math.sqrt(area / Math.PI) : 0;
  }

  function metalDiameter(size) {
    var cm = typeof WIRE_CMIL !== 'undefined' ? WIRE_CMIL[size] : 0;
    return cm > 0 ? Math.sqrt(cm) / 1000 : null;
  }

  /* ---- settled circle pack (same contact-candidate search as the app) ---- */
  var SLOP = 1e-4;

  function fits(x, y, r, placed, R) {
    if (Math.hypot(x, y) + r > R + SLOP) return false;
    for (var i = 0; i < placed.length; i++) {
      if (Math.hypot(x - placed[i].x, y - placed[i].y) + SLOP < r + placed[i].r) return false;
    }
    return true;
  }

  function intersections(x1, y1, r1, x2, y2, r2) {
    var dx = x2 - x1, dy = y2 - y1, d = Math.hypot(dx, dy);
    if (d < 1e-9 || d > r1 + r2 + 1e-7 || d < Math.abs(r1 - r2) - 1e-7) return [];
    var a = (r1 * r1 - r2 * r2 + d * d) / (2 * d);
    var h2 = r1 * r1 - a * a;
    if (h2 < -1e-8) return [];
    var h = Math.sqrt(Math.max(0, h2));
    var xm = x1 + a * dx / d, ym = y1 + a * dy / d;
    if (h < 1e-9) return [{ x: xm, y: ym }];
    var rx = -dy * h / d, ry = dx * h / d;
    return [{ x: xm + rx, y: ym + ry }, { x: xm - rx, y: ym - ry }];
  }

  function bestContact(r, placed, R) {
    var cands = [{ x: 0, y: -(R - r) }];
    var inner = R - r;
    var pool = placed.slice().sort(function (a, b) {
      if (Math.abs(a.y - b.y) > 1e-9) return a.y - b.y;
      return Math.abs(a.x) - Math.abs(b.x);
    }).slice(0, 16);
    pool.forEach(function (d) {
      cands = cands.concat(intersections(d.x, d.y, d.r + r, 0, 0, inner));
    });
    for (var i = 0; i < pool.length; i++) {
      for (var j = i + 1; j < pool.length; j++) {
        cands = cands.concat(intersections(pool[i].x, pool[i].y, pool[i].r + r, pool[j].x, pool[j].y, pool[j].r + r));
      }
    }
    var clear = cands.filter(function (c) { return fits(c.x, c.y, r, placed, R); });
    if (!clear.length) return null;
    clear.sort(function (a, b) {
      if (Math.abs(a.y - b.y) > 1e-6) return a.y - b.y;
      var ax = Math.abs(a.x), bx = Math.abs(b.x);
      if (Math.abs(ax - bx) > 1e-6) return ax - bx;
      return a.x - b.x;
    });
    return clear[0];
  }

  function overlapPenalty(x, y, r, placed, R) {
    var p = Math.max(0, Math.hypot(x, y) + r - R);
    placed.forEach(function (d) { p += Math.max(0, r + d.r - Math.hypot(x - d.x, y - d.y)); });
    return p;
  }

  function gridSpot(r, placed, R, allowOverlap) {
    var limit = R - r;
    if (limit <= 0) return null;
    var step = Math.max(0.012, r * 0.45);
    var best = null;
    for (var y = -limit; y <= limit + 1e-9; y += step) {
      var span = Math.sqrt(Math.max(0, limit * limit - y * y));
      for (var x = -span; x <= span + 1e-9; x += step) {
        if (fits(x, y, r, placed, R)) {
          if (!allowOverlap) return { x: x, y: y };
        } else if (allowOverlap) {
          var pen = overlapPenalty(x, y, r, placed, R);
          if (!best || pen < best.pen - 1e-9 || (Math.abs(pen - best.pen) < 1e-9 && y < best.y)) best = { x: x, y: y, pen: pen };
        }
      }
    }
    return allowOverlap ? best : null;
  }

  /** radii: array of conductor radii (in). Returns [{x,y,r,overlaps}] in input order. */
  function pack(radii, R) {
    var order = radii.map(function (r, i) { return { r: r, i: i }; }).sort(function (a, b) {
      return a.r !== b.r ? b.r - a.r : a.i - b.i;
    });
    var placed = [];
    order.forEach(function (o) {
      var r = Math.max(o.r, 1e-8), spot;
      if (R <= r + SLOP) { placed.push({ i: o.i, r: r, x: 0, y: 0 }); return; }
      if (!placed.length) {
        placed.push({ i: o.i, r: r, x: 0, y: order.length === 1 ? 0 : -(R - r) });
        return;
      }
      spot = bestContact(r, placed, R) || gridSpot(r, placed, R, false) || gridSpot(r, placed, R, true) || { x: 0, y: 0 };
      placed.push({ i: o.i, r: r, x: spot.x, y: spot.y });
    });
    return radii.map(function (_, i) {
      var d = placed.filter(function (p) { return p.i === i; })[0];
      var others = placed.filter(function (p) { return p.i !== i; });
      return { x: d.x, y: d.y, r: d.r, overlaps: !fits(d.x, d.y, d.r, others, R) };
    });
  }

  /* ---- SVG helpers ---- */
  function el(tag, attrs, parent) {
    var n = document.createElementNS(SVG_NS, tag);
    Object.keys(attrs || {}).forEach(function (k) { n.setAttribute(k, String(attrs[k])); });
    if (parent) parent.appendChild(n);
    return n;
  }
  function txt(parent, x, y, s, attrs) {
    var n = el('text', Object.assign({ x: x, y: y, fill: C.text, 'font-size': 11, 'font-family': 'IBM Plex Mono, ui-monospace, monospace' }, attrs || {}), parent);
    n.textContent = s;
    return n;
  }
  function num(n, d) { return Number(n).toFixed(d); }

  /**
   * Draws the cross-section into `svg` (replaces its contents, sets its viewBox).
   * payload: {
   *   type, trade, groups: [{qty, size, insul, area, label}],
   *   fillPct, limitPct, limitBasis, pass, nipple
   * }
   */
  function draw(svg, p) {
    var W = 640, H = 496;
    svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
    while (svg.firstChild) svg.removeChild(svg.firstChild);
    el('rect', { 'data-plot-bg': '1', x: 0, y: 0, width: W, height: H, fill: C.bg }, svg);

    var b = bore(p.type, p.trade);
    var defs = el('defs', {}, svg);
    var grad = el('radialGradient', { id: 'cvWall', cx: '35%', cy: '30%', r: '85%' }, defs);
    el('stop', { offset: '0%', 'stop-color': METAL[p.type] === 'pvc' ? '#d8dee6' : METAL[p.type] === 'flex' ? '#5d6877' : '#aab6c4' }, grad);
    el('stop', { offset: '100%', 'stop-color': METAL[p.type] === 'pvc' ? '#8e99a8' : METAL[p.type] === 'flex' ? '#2c3440' : '#5b6675' }, grad);

    txt(svg, 20, 26, 'RACEWAY CROSS-SECTION', { fill: C.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    txt(svg, 620, 26, p.trade + '" ' + p.type + (p.nipple ? ' nipple' : ''), { fill: C.text, 'font-size': 12, 'font-weight': 700, 'text-anchor': 'end' });

    if (!b) {
      txt(svg, W / 2, H / 2, 'Drawing not available for this raceway size.', { 'text-anchor': 'middle', fill: C.muted });
      return;
    }

    /* Bore drawing, scaled so the outside edge is 300 px across. */
    var outer = b.od || b.id * 1.1;
    var S = 300 / outer;
    var cx = 180, cy = 192;
    var Rid = (b.id / 2) * S, Rod = (outer / 2) * S;

    el('circle', { cx: cx, cy: cy, r: Rod, fill: 'url(#cvWall)', stroke: 'rgba(255,255,255,0.28)', 'stroke-width': 1 }, svg);
    el('circle', { cx: cx, cy: cy, r: Rid, fill: '#0b1017', stroke: 'rgba(0,0,0,0.6)', 'stroke-width': 1.5 }, svg);
    el('circle', { cx: cx, cy: cy, r: Rid, fill: 'none', stroke: p.pass ? 'rgba(86,214,164,0.55)' : 'rgba(244,112,120,0.7)', 'stroke-width': 1, 'stroke-dasharray': '3 4' }, svg);

    /* Conductors. Group index drives the tint; copper core is drawn to Table 8 metal diameter. */
    var flat = [];
    p.groups.forEach(function (g, gi) {
      for (var k = 0; k < g.qty; k++) flat.push({ g: g, gi: gi, d: overallDiameter(g.area) });
    });
    var packed = pack(flat.map(function (f) { return f.d / 2; }), b.id / 2);
    var anyOverlap = false;
    packed.forEach(function (disk, i) {
      var f = flat[i], color = GROUP_COLORS[f.gi % GROUP_COLORS.length];
      var px = cx + disk.x * S, py = cy - disk.y * S;
      if (disk.overlaps) anyOverlap = true;
      el('circle', { cx: px, cy: py, r: disk.r * S, fill: color, 'fill-opacity': 0.88, stroke: disk.overlaps ? C.bad : 'rgba(8,11,16,0.85)', 'stroke-width': disk.overlaps ? 2 : 1 }, svg);
      var md = metalDiameter(f.g.size);
      if (md && md / 2 < disk.r) {
        el('circle', { cx: px, cy: py, r: (md / 2) * S, fill: C.copper, 'fill-opacity': 0.95, stroke: 'rgba(8,11,16,0.55)', 'stroke-width': 0.6 }, svg);
      }
    });

    /* Dimension callouts. */
    var yDim = cy + Rod + 18;
    el('line', { x1: cx - Rid, y1: yDim, x2: cx + Rid, y2: yDim, stroke: C.line, 'stroke-width': 1 }, svg);
    el('line', { x1: cx - Rid, y1: yDim - 4, x2: cx - Rid, y2: yDim + 4, stroke: C.line }, svg);
    el('line', { x1: cx + Rid, y1: yDim - 4, x2: cx + Rid, y2: yDim + 4, stroke: C.line }, svg);
    txt(svg, cx, yDim + 15, 'ID ' + num(b.id, 3) + ' in' + (b.od ? '   OD ' + num(b.od, 3) + ' in' : ''), { 'text-anchor': 'middle', fill: C.muted, 'font-size': 10.5 });

    /* Right column: fill readout + bar + stats. */
    var rx = 372;
    var color = p.pass ? C.good : C.bad;
    txt(svg, rx, 72, 'FILL', { fill: C.muted, 'font-size': 10.5, 'letter-spacing': 1.5 });
    txt(svg, rx, 110, num(p.fillPct, 1) + '%', { fill: color, 'font-size': 32, 'font-weight': 700, 'font-family': 'Exo 2, Sora, system-ui, sans-serif' });
    var pillW = 92;
    el('rect', { x: rx + 248 - pillW, y: 88, width: pillW, height: 26, rx: 13, fill: p.pass ? 'rgba(86,214,164,0.14)' : 'rgba(244,112,120,0.14)', stroke: color, 'stroke-width': 1.2 }, svg);
    txt(svg, rx + 248 - pillW / 2, 105, p.pass ? 'PASS' : 'OVER', { 'text-anchor': 'middle', fill: color, 'font-size': 11.5, 'font-weight': 700, 'letter-spacing': 1 });

    var bx = rx, by = 132, bw = 248, bh = 14;
    el('rect', { x: bx, y: by, width: bw, height: bh, rx: 7, fill: 'rgba(255,255,255,0.07)' }, svg);
    var scaleMax = Math.max(100, p.fillPct);
    var fw = Math.min(bw, (p.fillPct / scaleMax) * bw);
    el('rect', { x: bx, y: by, width: Math.max(fw, 2), height: bh, rx: 7, fill: color }, svg);
    var lx = bx + (p.limitPct / scaleMax) * bw;
    el('line', { x1: lx, y1: by - 5, x2: lx, y2: by + bh + 5, stroke: C.text, 'stroke-width': 2 }, svg);
    txt(svg, lx, by + bh + 19, 'limit ' + p.limitPct + '%', { 'text-anchor': lx > bx + bw - 40 ? 'end' : 'middle', fill: C.text, 'font-size': 10 });

    var free = Math.max(0, 100 - p.fillPct);
    var stats = [
      ['Conductors', String(p.groups.reduce(function (n, g) { return n + g.qty; }, 0))],
      ['Wire area', num(p.totalArea, 4) + ' sq in'],
      ['Bore area', num(p.racewayArea, 3) + ' sq in'],
      ['Free area', num(free, 1) + '%'],
    ];
    stats.forEach(function (row, i) {
      var y = 196 + i * 21;
      txt(svg, rx, y, row[0], { fill: C.muted, 'font-size': 11 });
      txt(svg, rx + 248, y, row[1], { 'text-anchor': 'end', 'font-weight': 600 });
    });

    /* Legend: one line per conductor group. */
    var ly = 296;
    p.groups.slice(0, 6).forEach(function (g, gi) {
      var col = GROUP_COLORS[gi % GROUP_COLORS.length];
      el('circle', { cx: rx + 6, cy: ly - 4, r: 6, fill: col }, svg);
      var md = metalDiameter(g.size), od = overallDiameter(g.area);
      if (md && od) el('circle', { cx: rx + 6, cy: ly - 4, r: Math.max(1.5, 6 * md / od), fill: C.copper }, svg);
      txt(svg, rx + 20, ly, g.qty + ' × ' + g.label, { 'font-size': 10.5 });
      ly += 19;
    });
    if (p.groups.length > 6) txt(svg, rx + 20, ly, '+ ' + (p.groups.length - 6) + ' more groups', { fill: C.muted, 'font-size': 10.5 });

    /* Footer notes. */
    var notes = [];
    if (anyOverlap) notes.push('Conductors do not fit as drawn: the bundle exceeds the bore.');
    else notes.push('Settled packing, largest conductors toward the bottom. Illustrative: a pull does not land in this arrangement.');
    var jam = jamNote(flat, b.id);
    if (jam) notes.push(jam);
    notes.push('Copper = Table 8 metal diameter inside Table 5 insulation. Table 1 percent fill is the NEC check, not a jam check.');
    var ny = 408;
    notes.forEach(function (n) {
      wrapText(svg, 20, ny, n, 62, { fill: anyOverlap && n.indexOf('do not fit') === 0 ? C.bad : C.muted, 'font-size': 10 });
      ny += 13 * Math.ceil(n.length / 62) + 3;
    });
    return svg;
  }

  function wrapText(svg, x, y, s, max, attrs) {
    var words = s.split(' '), line = '', dy = 0;
    words.forEach(function (w) {
      if ((line + ' ' + w).trim().length > max) {
        txt(svg, x, y + dy, line.trim(), attrs);
        dy += 13; line = w;
      } else line += ' ' + w;
    });
    if (line.trim()) txt(svg, x, y + dy, line.trim(), attrs);
  }

  /* Three equal conductors can jam in a bend when ID / OD is 2.8 – 3.2. */
  function jamNote(flat, id) {
    if (flat.length !== 3) return null;
    if (flat.some(function (f) { return Math.abs(f.d - flat[0].d) > 1e-9; }) || flat[0].d <= 0) return null;
    var ratio = id / flat[0].d;
    if (ratio <= 2.8 || ratio >= 3.2) return null;
    return 'Jam ratio ' + num(ratio, 2) + ' is between 2.8 and 3.2. Three equal conductors can lock in a bend. Table 1 does not check that.';
  }

  /**
   * Adds the drawing to a calculator result element. Call after the result rows
   * are built and before appendCopyBtn. Safe to call on every recalculation.
   */
  function mount(resultEl, payload, opts) {
    if (!resultEl) return;
    var old = resultEl.querySelector('.calculation-visual');
    if (old) old.remove();
    resultEl.dataset.visualized = '1';
    var shell = window.BeckifyResultVisuals && window.BeckifyResultVisuals.shell;
    if (!shell) return;
    var svg = shell(resultEl, 'Conduit cross-section: ' + payload.trade + ' inch ' + payload.type + ' at ' + num(payload.fillPct, 1) + ' percent fill, limit ' + payload.limitPct + ' percent');
    draw(svg, payload);
    /* opts.top puts the drawing above the result rows (the iOS app does the
       same: diagram first, numbers under it). */
    if (opts && opts.top && svg.parentNode && svg.parentNode.parentNode === resultEl) {
      resultEl.insertBefore(svg.parentNode, resultEl.firstChild);
    }
    var readout = svg.parentNode.querySelector('.calculation-visual-readout');
    if (readout) {
      readout.textContent = payload.trade + '" ' + payload.type + ' · ' + num(payload.fillPct, 1) + '% of ' + payload.limitPct + '% allowed · ' + (payload.pass ? 'within NEC Table 1' : 'over NEC Table 1');
    }
  }

  window.ConduitViz = { bore: bore, pack: pack, draw: draw, mount: mount, overallDiameter: overallDiameter, metalDiameter: metalDiameter };
})();
