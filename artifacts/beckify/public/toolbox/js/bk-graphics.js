/* Shared graphics style for Beckify web tools: the iOS look (Theme.swift, BenchDiagrams.swift).
   Palette, retina canvas setup, labels, dimension lines, legends, series colors. */
(function (global) {
  'use strict';

  const P = {
    bg: '#080b10', surface: '#12161e', raised: '#1c222c', inputFill: '#0e1118',
    fg: '#e8eef5', muted: '#94a2b2',
    border: 'rgba(255,255,255,0.10)', hairline: 'rgba(255,255,255,0.06)',
    accent: '#40bad6', accent2: '#609ce6', copper: '#e09c56',
    good: '#56d6a4', warn: '#f0bc48', bad: '#f47078',
    wrap: '#245294', wrapLight: '#3873bf',
  };

  const FONT = '"Exo 2","IBM Plex Sans",system-ui,-apple-system,"Segoe UI",sans-serif';
  const MONO = '"IBM Plex Mono",ui-monospace,monospace';

  // Eight non-violet series hues, second lap one step lighter, so 16 groups stay distinct.
  const SERIES = ['#40bad6', '#e09c56', '#56d6a4', '#609ce6', '#f0bc48', '#f47078', '#2fa39a', '#9fb4c9'];
  function seriesColor(i) {
    const n = Math.max(0, (i | 0) - 1);
    const base = SERIES[n % SERIES.length];
    return n >= SERIES.length ? mix(base, '#ffffff', 0.32) : base;
  }

  function hex(c) { const n = parseInt(c.slice(1), 16); return [n >> 16 & 255, n >> 8 & 255, n & 255]; }
  function mix(a, b, t) {
    const x = hex(a), y = hex(b);
    return '#' + x.map((v, i) => ('0' + Math.round(v + (y[i] - v) * t).toString(16)).slice(-2)).join('');
  }
  function alpha(c, a) { const x = hex(c); return 'rgba(' + x[0] + ',' + x[1] + ',' + x[2] + ',' + a + ')'; }

  /** Size a canvas in CSS pixels and scale its backing store by devicePixelRatio (cap 3). */
  function setupCanvas(canvas, cssW, cssH) {
    const dpr = Math.min(3, Math.max(1, global.devicePixelRatio || 1));
    canvas.width = Math.round(cssW * dpr);
    canvas.height = Math.round(cssH * dpr);
    canvas.style.width = cssW + 'px';
    canvas.style.height = cssH + 'px';
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, cssW, cssH);
    return ctx;
  }

  function panel(ctx, w, h) {
    const g = ctx.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, P.surface);
    g.addColorStop(1, P.bg);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, w, h);
  }

  function label(ctx, text, x, y, o) {
    o = o || {};
    ctx.font = (o.weight || 600) + ' ' + (o.size || 11) + 'px ' + (o.mono ? MONO : FONT);
    ctx.fillStyle = o.color || P.fg;
    ctx.textAlign = o.align || 'center';
    ctx.textBaseline = o.baseline || 'middle';
    ctx.fillText(text, x, y);
  }

  function roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  /** Dimension line with end ticks and a label on a small raised plate (BenchInk.dimension). */
  function dimension(ctx, a, b, text, o) {
    o = o || {};
    const color = o.color || P.accent2;
    ctx.strokeStyle = color; ctx.lineWidth = 1; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
    const dx = b.x - a.x, dy = b.y - a.y, len = Math.max(Math.hypot(dx, dy), 0.001);
    const nx = -dy / len * 4, ny = dx / len * 4;
    [a, b].forEach(function (e) {
      ctx.beginPath(); ctx.moveTo(e.x - nx, e.y - ny); ctx.lineTo(e.x + nx, e.y + ny); ctx.stroke();
    });
    const ox = (o.dx || 0), oy = (o.dy || 0);
    const mx = (a.x + b.x) / 2 + ox, my = (a.y + b.y) / 2 + oy;
    ctx.font = '600 10.5px ' + FONT;
    const w = ctx.measureText(text).width + 10;
    ctx.fillStyle = 'rgba(28,34,44,0.92)';
    roundRect(ctx, mx - w / 2, my - 8, w, 16, 4); ctx.fill();
    label(ctx, text, mx, my + 0.5, { size: 10.5, color: color });
  }

  /** Legend chips along the bottom-left; items = [{color, text}]. Wraps by width. */
  function legend(ctx, items, x, y, maxW) {
    ctx.font = '500 10.5px ' + FONT;
    let cx = x, cy = y;
    items.forEach(function (it) {
      const w = ctx.measureText(it.text).width + 22;
      if (cx + w > x + maxW) { cx = x; cy += 16; }
      ctx.fillStyle = it.color;
      ctx.beginPath(); ctx.arc(cx + 5, cy, 4, 0, Math.PI * 2); ctx.fill();
      label(ctx, it.text, cx + 14, cy + 0.5, { size: 10.5, weight: 500, color: P.muted, align: 'left' });
      cx += w + 6;
    });
    return cy;
  }

  global.BeckifyGfx = { P: P, FONT: FONT, MONO: MONO, seriesColor: seriesColor, mix: mix, alpha: alpha,
    setupCanvas: setupCanvas, panel: panel, label: label, roundRect: roundRect, dimension: dimension, legend: legend };
})(typeof window !== 'undefined' ? window : globalThis);
