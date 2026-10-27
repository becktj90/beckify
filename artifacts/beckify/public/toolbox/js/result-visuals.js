(function () {
  'use strict';

  /*
   * Calculator results are deliberately plain text so they remain copyable,
   * searchable, and usable offline. This layer adds a visual reading path
   * beside the same values without making any calculator depend on a chart
   * library or a second rendering pipeline.
   */
  const SVG_NS = 'http://www.w3.org/2000/svg';
  /* Dark-mode Beckify plot tokens. Match ios/Beckify/Theme/Theme.swift chart colors. */
  const PALETTE = {
    bg: '#080b10',
    accent: '#40bad6',
    blue: '#609ce6',
    copper: '#e09c56',
    good: '#56d6a4',
    warn: '#f0bc48',
    bad: '#f47078',
    text: '#e8eef5',
    muted: '#94a2b2',
    line: 'rgba(148,162,178,0.45)',
    grid: 'rgba(148,162,178,0.22)',
    yellow: '#e09c56',
    green: '#56d6a4',
    red: '#f47078',
  };

  function numberFrom(text) {
    const match = String(text || '').replace(/,/g, '').match(/-?\d+(?:\.\d+)?/);
    return match ? Number(match[0]) : NaN;
  }

  function resultNumbers(result) {
    return Array.from(result.querySelectorAll('.res-val')).map((node) => numberFrom(node.textContent)).filter(Number.isFinite).slice(0, 8);
  }

  function svgElement(tag, attrs) {
    const node = document.createElementNS(SVG_NS, tag);
    Object.keys(attrs || {}).forEach((key) => node.setAttribute(key, String(attrs[key])));
    return node;
  }

  function shell(result, label) {
    const wrap = document.createElement('div');
    wrap.className = 'calculation-visual';
    wrap.setAttribute('role', 'img');
    wrap.setAttribute('aria-label', label);
    wrap.setAttribute('data-chart-export-root', '1');

    const toolbar = document.createElement('div');
    toolbar.className = 'calculation-visual-toolbar';
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'calculation-visual-export';
    btn.textContent = 'Save PNG';
    btn.title = 'Download this plot as a PNG image';
    btn.addEventListener('click', () => exportVisualPng(wrap, label));
    toolbar.appendChild(btn);
    wrap.appendChild(toolbar);

    // SVG height must be a numeric length or omitted. CSS owns responsive sizing.
    const svg = svgElement('svg', { viewBox: '0 0 640 180', width: '100%', focusable: 'false', 'aria-hidden': 'true' });
    svg.appendChild(svgElement('rect', { 'data-plot-bg': '1', x: 0, y: 0, width: 640, height: 180, fill: PALETTE.bg }));
    wrap.appendChild(svg);
    const readout = document.createElement('p');
    readout.className = 'calculation-visual-readout';
    readout.setAttribute('aria-live', 'polite');
    wrap.appendChild(readout);
    const copy = result.querySelector('.result-copy-row');
    result.insertBefore(wrap, copy || null);
    return svg;
  }

  function exportVisualPng(wrap, label) {
    const svg = wrap.querySelector('svg');
    if (!svg) return;
    const clone = svg.cloneNode(true);
    if (!clone.getAttribute('xmlns')) clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    const viewBox = (svg.getAttribute('viewBox') || '0 0 640 180').split(/[\s,]+/).map(Number);
    const exportHeight = Math.round(1280 * ((viewBox[3] || 180) / (viewBox[2] || 640)));
    clone.setAttribute('width', '1280');
    clone.setAttribute('height', String(exportHeight));
    const xml = new XMLSerializer().serializeToString(clone);
    const blob = new Blob([xml], { type: 'image/svg+xml;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const image = new Image();
    image.onload = () => {
      const canvas = document.createElement('canvas');
      canvas.width = 1280;
      canvas.height = exportHeight;
      const ctx = canvas.getContext('2d');
      if (!ctx) {
        URL.revokeObjectURL(url);
        return;
      }
      ctx.fillStyle = '#080b10';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(image, 0, 0, canvas.width, canvas.height);
      URL.revokeObjectURL(url);
      canvas.toBlob((png) => {
        if (!png) return;
        const href = URL.createObjectURL(png);
        const a = document.createElement('a');
        const slug = String(label || 'beckify-plot').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'beckify-plot';
        a.href = href;
        a.download = slug + '.png';
        a.rel = 'noopener';
        document.body.appendChild(a);
        a.click();
        a.remove();
        URL.revokeObjectURL(href);
      }, 'image/png');
    };
    image.onerror = () => URL.revokeObjectURL(url);
    image.src = url;
  }

  function rcChargeDischarge(svg) {
    plotAxes(svg, 'RC CHARGE / DISCHARGE', 'time (τ)', 'v / V');
    const charge = [];
    const discharge = [];
    for (let i = 0; i <= 80; i += 1) {
      const t = (i / 80) * 5;
      const x = 48 + (t / 5) * 568;
      const yc = 132 - (1 - Math.exp(-t)) * 84;
      const yd = 132 - Math.exp(-t) * 84;
      charge.push(x + ',' + yc);
      discharge.push(x + ',' + yd);
    }
    svg.appendChild(svgElement('polyline', { points: charge.join(' '), fill: 'none', stroke: PALETTE.accent, 'stroke-width': 3, 'stroke-linejoin': 'round' }));
    svg.appendChild(svgElement('polyline', { points: discharge.join(' '), fill: 'none', stroke: PALETTE.yellow, 'stroke-width': 2.5, 'stroke-linejoin': 'round' }));
    const xTau = 48 + (1 / 5) * 568;
    line(svg, xTau, 42, xTau, 132, { stroke: PALETTE.muted, 'stroke-width': 1.5, 'stroke-dasharray': '4 3' });
    text(svg, xTau + 4, 56, 'τ', { fill: PALETTE.muted, 'font-size': 11 });
    text(svg, 560, 56, 'charge', { fill: PALETTE.accent, 'font-size': 11 });
    text(svg, 560, 74, 'discharge', { fill: PALETTE.yellow, 'font-size': 11 });
  }

  function text(svg, x, y, value, attrs) {
    const node = svgElement('text', Object.assign({ x, y, fill: PALETTE.text, 'font-size': 13, 'font-family': 'IBM Plex Mono, ui-monospace, monospace' }, attrs || {}));
    // The 640-unit plot is shown at 300 to 600 px, so label sizes are scaled up to stay readable at that width.
    node.setAttribute('font-size', String(Math.round(Math.max(14, Number(node.getAttribute('font-size')) * 1.5) * 10) / 10));
    node.textContent = value;
    svg.appendChild(node);
  }

  function line(svg, x1, y1, x2, y2, attrs) {
    svg.appendChild(svgElement('line', Object.assign({ x1, y1, x2, y2, stroke: PALETTE.line, 'stroke-width': 2, 'stroke-linecap': 'round' }, attrs || {})));
  }

  function ohms(svg) {
    text(svg, 320, 25, 'OHM\'S LAW', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 2 });
    line(svg, 320, 45, 180, 120, { stroke: PALETTE.accent, 'stroke-width': 3 });
    line(svg, 320, 45, 460, 120, { stroke: PALETTE.blue, 'stroke-width': 3 });
    line(svg, 180, 120, 460, 120, { stroke: PALETTE.green, 'stroke-width': 3 });
    text(svg, 320, 42, 'V', { 'text-anchor': 'middle', 'font-size': 24, 'font-weight': 700 });
    text(svg, 165, 140, 'I', { 'text-anchor': 'middle', fill: PALETTE.blue, 'font-size': 22, 'font-weight': 700 });
    text(svg, 475, 140, 'R', { 'text-anchor': 'middle', fill: PALETTE.green, 'font-size': 22, 'font-weight': 700 });
    text(svg, 320, 145, 'V = I x R', { 'text-anchor': 'middle', fill: PALETTE.accent, 'font-weight': 700 });
  }

  function waveform(svg) {
    const samples = [];
    const cycles = 3;
    const duty = 0.62;
    for (let i = 0; i <= 90; i += 1) {
      const t = (i / 90) * cycles;
      const phase = t - Math.floor(t);
      samples.push([t, phase < duty ? 1 : 0]);
    }
    seriesPlot(svg, {
      xLabel: 'Time (periods)',
      yLabel: 'Output (normalized)',
      xUnit: 'periods',
      yUnit: '',
      xMin: 0,
      xMax: cycles,
      yMin: -0.15,
      yMax: 1.25,
      series: [{ name: '555 output', color: PALETTE.accent, samples }],
    });
  }

  function plotAxes(svg, title, xLabel, yLabel) {
    text(svg, 16, 22, title, { fill: PALETTE.text, 'font-size': 12, 'font-weight': 700 });
    for (let i = 0; i <= 4; i += 1) {
      const y = 42 + ((132 - 42) * i) / 4;
      line(svg, 48, y, 616, y, { stroke: PALETTE.grid, 'stroke-width': 1 });
    }
    line(svg, 48, 132, 616, 132, { stroke: PALETTE.line });
    line(svg, 48, 42, 48, 132, { stroke: PALETTE.line });
    text(svg, 616, 156, xLabel, { fill: PALETTE.text, 'font-size': 11, 'text-anchor': 'end' });
    text(svg, 44, 36, yLabel, { fill: PALETTE.text, 'font-size': 11, 'text-anchor': 'end' });
  }

  function formatTick(value) {
    const abs = Math.abs(value);
    const digits = abs >= 100 ? 0 : abs >= 10 ? 1 : 2;
    return Number(value.toFixed(digits)).toString();
  }

  function usePlotBox(svg, height) {
    svg.setAttribute('viewBox', '0 0 640 ' + height);
    const bg = svg.querySelector('[data-plot-bg]');
    if (bg) {
      bg.setAttribute('width', '640');
      bg.setAttribute('height', String(height));
    }
  }

  function bindHover(svg, samples, xUnit, yUnit) {
    const readout = svg.parentElement && svg.parentElement.querySelector('.calculation-visual-readout');
    if (!readout) return;
    const show = (event) => {
      const point = svg.createSVGPoint();
      point.x = event.clientX;
      point.y = event.clientY;
      const matrix = svg.getScreenCTM();
      if (!matrix) return;
      const local = point.matrixTransform(matrix.inverse());
      let best = null;
      let bestDist = 28;
      samples.forEach((sample) => {
        const dist = Math.hypot(sample.px - local.x, sample.py - local.y);
        if (dist < bestDist) {
          best = sample;
          bestDist = dist;
        }
      });
      readout.textContent = best
        ? best.name + '  ' + formatTick(best.x) + ' ' + xUnit + '  ·  ' + formatTick(best.y) + ' ' + yUnit
        : '';
    };
    svg.style.touchAction = 'manipulation';
    svg.addEventListener('pointermove', show);
    svg.addEventListener('pointerleave', () => { readout.textContent = ''; });
  }

  function seriesPlot(svg, spec) {
    const height = 228;
    const left = 62;
    const right = 612;
    const top = 36;
    const bottom = 176;
    usePlotBox(svg, height);
    const xMin = spec.xMin == null ? 0 : spec.xMin;
    const xMax = spec.xMax == null ? 1 : spec.xMax;
    const yMin = spec.yMin == null ? 0 : spec.yMin;
    const yMax = spec.yMax == null ? 1 : spec.yMax;
    const xSpan = xMax - xMin || 1;
    const ySpan = yMax - yMin || 1;
    const X = (x) => left + ((x - xMin) / xSpan) * (right - left);
    const Y = (y) => bottom - ((y - yMin) / ySpan) * (bottom - top);
    text(svg, left, 20, spec.yLabel, { fill: PALETTE.text, 'font-size': 12, 'font-weight': 700 });
    for (let i = 0; i <= 4; i += 1) {
      const y = top + ((bottom - top) * i) / 4;
      const x = left + ((right - left) * i) / 4;
      line(svg, left, y, right, y, { stroke: PALETTE.grid, 'stroke-width': 1 });
      line(svg, x, top, x, bottom, { stroke: PALETTE.grid, 'stroke-width': 1 });
      text(svg, left - 8, y + 4, formatTick(yMax - (ySpan * i) / 4), { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'end' });
      text(svg, x, bottom + 16, formatTick(xMin + (xSpan * i) / 4), { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
    }
    line(svg, left, top, left, bottom, { stroke: PALETTE.muted, 'stroke-width': 1.25 });
    line(svg, left, bottom, right, bottom, { stroke: PALETTE.muted, 'stroke-width': 1.25 });
    text(svg, (left + right) / 2, height - 12, spec.xLabel, { fill: PALETTE.text, 'font-size': 12, 'font-weight': 700, 'text-anchor': 'middle' });
    const samples = [];
    (spec.guides || []).forEach((guide) => {
      if (guide.y < yMin || guide.y > yMax) return;
      const y = Y(guide.y);
      line(svg, left, y, right, y, { stroke: guide.color, 'stroke-width': 1.25, 'stroke-dasharray': '5 4' });
      text(svg, left + 8, y - 4, guide.label, { fill: guide.color, 'font-size': 10, 'text-anchor': 'start' });
    });
    (spec.series || []).forEach((series, index) => {
      const points = series.samples.map(([x, y]) => {
        const px = X(x);
        const py = Y(y);
        samples.push({ name: series.name, x, y, px, py });
        return px + ',' + py;
      });
      const trace = svgElement('polyline', {
        points: points.join(' '),
        fill: 'none',
        stroke: series.color,
        'stroke-width': 2.5,
        'stroke-linejoin': 'round',
        'stroke-linecap': 'round',
        pathLength: 1,
      });
      trace.setAttribute('class', 'plot-trace');
      svg.appendChild(trace);
      text(svg, right - index * 148, 20, series.name, { fill: series.color, 'font-size': 11, 'font-weight': 700, 'text-anchor': 'end' });
    });
    if (spec.marker) {
      svg.appendChild(svgElement('circle', {
        cx: X(spec.marker.x),
        cy: Y(spec.marker.y),
        r: 5.5,
        fill: PALETTE.copper,
        stroke: PALETTE.text,
        'stroke-width': 1.5,
      }));
    }
    bindHover(svg, samples, spec.xUnit || '', spec.yUnit || '');
  }

  function labeledNumber(result, pattern) {
    const labels = result.querySelectorAll('.res-label');
    const values = result.querySelectorAll('.res-val');
    for (let i = 0; i < values.length; i += 1) {
      if (pattern.test((labels[i] && labels[i].textContent) || '')) return numberFrom(values[i].textContent);
    }
    return NaN;
  }

  function inputNumber(id) {
    const node = document.getElementById(id);
    const value = node ? Number(node.value) : NaN;
    return Number.isFinite(value) ? value : NaN;
  }

  function powerTriangle(svg, title) {
    text(svg, 320, 23, title, { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    line(svg, 180, 118, 470, 118, { stroke: PALETTE.blue, 'stroke-width': 3 });
    line(svg, 470, 118, 470, 58, { stroke: PALETTE.yellow, 'stroke-width': 3 });
    line(svg, 180, 118, 470, 58, { stroke: PALETTE.accent, 'stroke-width': 3 });
    text(svg, 320, 137, 'kW · real work', { 'text-anchor': 'middle', fill: PALETTE.blue, 'font-size': 11, 'font-weight': 700 });
    text(svg, 486, 91, 'kVAR', { fill: PALETTE.yellow, 'font-size': 11, 'font-weight': 700 });
    text(svg, 315, 75, 'kVA · apparent', { 'text-anchor': 'middle', fill: PALETTE.accent, 'font-size': 11, 'font-weight': 700 });
    text(svg, 180, 151, 'PF = kW / kVA', { fill: PALETTE.muted, 'font-size': 10 });
  }

  function reactancePlot(svg) {
    const inductive = [];
    const capacitive = [];
    for (let i = 0; i <= 40; i += 1) {
      const f = 0.2 + (i / 40) * 0.8;
      inductive.push([f, f]);
      capacitive.push([f, 0.2 / f]);
    }
    seriesPlot(svg, {
      xLabel: 'Frequency (relative)',
      yLabel: 'Reactance (relative Ω)',
      xUnit: 'f',
      yUnit: 'Ω',
      xMin: 0.2,
      xMax: 1,
      yMin: 0,
      yMax: 1.15,
      series: [
        { name: 'XL = 2πfL', color: PALETTE.blue, samples: inductive },
        { name: 'XC = 1/(2πfC)', color: PALETTE.copper, samples: capacitive },
      ],
    });
  }

  function resonancePlot(svg) {
    const samples = [];
    for (let i = 0; i <= 48; i += 1) {
      const f = i / 48;
      samples.push([f, Math.exp(-Math.pow((f - 0.52) / 0.12, 2))]);
    }
    seriesPlot(svg, {
      xLabel: 'Frequency (relative)',
      yLabel: 'Response',
      xUnit: 'f',
      yUnit: '',
      xMin: 0,
      xMax: 1,
      yMin: 0,
      yMax: 1.15,
      series: [{ name: 'Resonance', color: PALETTE.accent, samples }],
      marker: { x: 0.52, y: 1 },
    });
  }

  function voltageDropPlot(svg, dropPct) {
    const drop = Number.isFinite(dropPct) ? Math.abs(dropPct) : 2;
    const yMax = Math.max(6, drop * 1.2);
    const samples = [];
    for (let i = 0; i <= 40; i += 1) {
      const distance = (i / 40) * 100;
      samples.push([distance, drop * (distance / 100)]);
    }
    seriesPlot(svg, {
      xLabel: 'Distance along run (%)',
      yLabel: 'Voltage drop (%)',
      xUnit: '%',
      yUnit: '%',
      xMin: 0,
      xMax: 100,
      yMin: 0,
      yMax,
      guides: [
        { y: 3, label: '3%', color: PALETTE.copper },
        { y: 5, label: '5%', color: PALETTE.warn },
      ],
      series: [{ name: 'Resistive drop', color: PALETTE.accent, samples }],
      marker: { x: 100, y: drop },
    });
  }

  function motorCurve(svg, horsepower) {
    const samples = [];
    for (let i = 0; i <= 40; i += 1) {
      const speed = 0.4 + (i / 40) * 1.6;
      samples.push([speed, 1 / speed]);
    }
    const name = horsepower > 0 ? horsepower.toFixed(2) + ' HP, constant power' : 'Constant power';
    seriesPlot(svg, {
      xLabel: 'Speed (per unit of rated)',
      yLabel: 'Torque (per unit of rated)',
      xUnit: 'pu',
      yUnit: 'pu',
      xMin: 0.4,
      xMax: 2,
      yMin: 0,
      yMax: 2.7,
      series: [{ name, color: PALETTE.accent, samples }],
      marker: { x: 1, y: 1 },
    });
  }

  function network(svg, parallel) {
    text(svg, 320, 23, parallel ? 'PARALLEL PATHS' : 'SERIES PATH', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    const left = 94, right = 546, top = parallel ? 62 : 92;
    if (parallel) {
      line(svg, left, top, left, 122, { stroke: PALETTE.line });
      line(svg, right, top, right, 122, { stroke: PALETTE.line });
      line(svg, left, top, 546, top, { stroke: PALETTE.line });
      line(svg, left, 122, 546, 122, { stroke: PALETTE.line });
      line(svg, left, 72, 188, 72, { stroke: PALETTE.blue, 'stroke-width': 3 });
      line(svg, 188, 72, 188, 112, { stroke: PALETTE.blue, 'stroke-width': 3 });
      line(svg, 188, 112, 452, 112, { stroke: PALETTE.blue, 'stroke-width': 3 });
      line(svg, 188, 72, 452, 72, { stroke: PALETTE.yellow, 'stroke-width': 3 });
      text(svg, 320, 68, 'R₁', { fill: PALETTE.yellow, 'font-size': 12, 'font-weight': 700, 'text-anchor': 'middle' });
      text(svg, 320, 108, 'R₂', { fill: PALETTE.blue, 'font-size': 12, 'font-weight': 700, 'text-anchor': 'middle' });
      text(svg, 320, 151, 'two paths share the same voltage', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
    } else {
      line(svg, left, top, 205, top, { stroke: PALETTE.line });
      line(svg, 205, top, 320, top, { stroke: PALETTE.blue, 'stroke-width': 3 });
      line(svg, 320, top, 435, top, { stroke: PALETTE.yellow, 'stroke-width': 3 });
      line(svg, 435, top, right, top, { stroke: PALETTE.line });
      text(svg, 262, top - 10, 'R₁', { fill: PALETTE.blue, 'font-size': 12, 'font-weight': 700, 'text-anchor': 'middle' });
      text(svg, 378, top - 10, 'R₂', { fill: PALETTE.yellow, 'font-size': 12, 'font-weight': 700, 'text-anchor': 'middle' });
      text(svg, 320, 151, 'same current flows through each element', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
    }
    [left, right].forEach((x) => svg.appendChild(svgElement('circle', { cx: x, cy: top, r: 5, fill: PALETTE.text })));
  }

  function transformer(svg) {
    text(svg, 320, 23, 'ENERGY TRANSFER', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    for (let i = 0; i < 4; i += 1) {
      svg.appendChild(svgElement('path', { d: `M 176 ${55 + i * 18} q 24 9 0 18`, fill: 'none', stroke: PALETTE.blue, 'stroke-width': 3 }));
      svg.appendChild(svgElement('path', { d: `M 464 ${55 + i * 18} q -24 9 0 18`, fill: 'none', stroke: PALETTE.green, 'stroke-width': 3 }));
    }
    line(svg, 232, 92, 400, 92, { stroke: PALETTE.accent, 'stroke-width': 2, 'stroke-dasharray': '5 5' });
    text(svg, 138, 145, 'primary', { fill: PALETTE.blue, 'font-size': 11, 'text-anchor': 'middle' });
    text(svg, 582, 145, 'secondary', { fill: PALETTE.green, 'font-size': 11, 'text-anchor': 'middle' });
    text(svg, 320, 145, 'magnetic coupling', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function faultPath(svg) {
    text(svg, 320, 23, 'FAULT CURRENT PATH', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    line(svg, 70, 92, 170, 92, { stroke: PALETTE.blue, 'stroke-width': 4 });
    line(svg, 270, 92, 370, 92, { stroke: PALETTE.yellow, 'stroke-width': 4 });
    line(svg, 470, 92, 570, 92, { stroke: PALETTE.red, 'stroke-width': 4 });
    [70, 170, 270, 370, 470, 570].forEach((x) => svg.appendChild(svgElement('circle', { cx: x, cy: 92, r: 5, fill: PALETTE.text })));
    text(svg, 120, 125, 'source', { fill: PALETTE.blue, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 220, 72, 'OCPD', { fill: PALETTE.yellow, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 420, 125, 'impedance', { fill: PALETTE.yellow, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 520, 72, 'fault', { fill: PALETTE.red, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 320, 151, 'available current is limited by the path impedance', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function capacity(svg, title, valueLabel, color) {
    text(svg, 20, 24, title, { fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    line(svg, 36, 88, 604, 88, { stroke: PALETTE.line, 'stroke-width': 16 });
    line(svg, 36, 88, 470, 88, { stroke: color, 'stroke-width': 16 });
    line(svg, 470, 56, 470, 120, { stroke: PALETTE.text, 'stroke-width': 2, 'stroke-dasharray': '4 4' });
    text(svg, 470, 45, 'limit', { fill: PALETTE.text, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 36, 126, '0', { fill: PALETTE.muted, 'font-size': 10 });
    text(svg, 604, 126, 'envelope', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'end' });
    text(svg, 320, 151, valueLabel, { fill: color, 'font-size': 12, 'font-weight': 700, 'text-anchor': 'middle' });
  }

  function conduitSection(svg) {
    text(svg, 320, 23, 'RACEWAY FILL ENVELOPE', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    svg.appendChild(svgElement('ellipse', { cx: 320, cy: 91, rx: 78, ry: 49, fill: 'rgba(96,165,250,0.08)', stroke: PALETTE.blue, 'stroke-width': 3 }));
    [[287, 72, PALETTE.red], [353, 72, PALETTE.yellow], [287, 111, PALETTE.green], [353, 111, PALETTE.accent]].forEach(([cx, cy, color]) => {
      svg.appendChild(svgElement('circle', { cx, cy, r: 18, fill: String(color), opacity: 0.88 }));
    });
    text(svg, 320, 151, 'conductors must stay inside the permitted fill area', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function conductorCrossSection(svg) {
    text(svg, 320, 23, 'CONDUCTOR AREA', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    svg.appendChild(svgElement('circle', { cx: 260, cy: 91, r: 48, fill: 'rgba(245,196,81,0.12)', stroke: PALETTE.yellow, 'stroke-width': 3 }));
    svg.appendChild(svgElement('circle', { cx: 260, cy: 91, r: 30, fill: 'rgba(245,196,81,0.2)', stroke: PALETTE.yellow, 'stroke-width': 1 }));
    line(svg, 332, 91, 548, 91, { stroke: PALETTE.green, 'stroke-width': 4 });
    line(svg, 332, 65, 332, 117, { stroke: PALETTE.green, 'stroke-width': 2 });
    line(svg, 548, 65, 548, 117, { stroke: PALETTE.green, 'stroke-width': 2 });
    text(svg, 440, 78, 'diameter → circular mils', { fill: PALETTE.green, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 260, 151, 'area grows with the square of diameter', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function unitFlow(svg) {
    text(svg, 320, 23, 'UNIT CONVERSION PATH', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    const nodes = [['input', 112, PALETTE.blue], ['base unit', 320, PALETTE.accent], ['output', 528, PALETTE.green]];
    nodes.forEach(([label, x, color]) => {
      svg.appendChild(svgElement('rect', { x: Number(x) - 50, y: 68, width: 100, height: 44, rx: 10, fill: 'rgba(255,255,255,0.05)', stroke: String(color), 'stroke-width': 2 }));
      text(svg, Number(x), 95, String(label), { fill: String(color), 'font-size': 11, 'font-weight': 700, 'text-anchor': 'middle' });
    });
    line(svg, 164, 90, 268, 90, { stroke: PALETTE.line, 'stroke-width': 3 });
    line(svg, 372, 90, 476, 90, { stroke: PALETTE.line, 'stroke-width': 3 });
    text(svg, 320, 151, 'the numerical value changes; the physical quantity does not', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function hazardBoundary(svg) {
    text(svg, 320, 23, 'HAZARD BOUNDARY', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    svg.appendChild(svgElement('circle', { cx: 320, cy: 91, r: 48, fill: 'rgba(255,138,138,0.14)', stroke: PALETTE.red, 'stroke-width': 3 }));
    svg.appendChild(svgElement('circle', { cx: 320, cy: 91, r: 26, fill: 'rgba(245,196,81,0.18)', stroke: PALETTE.yellow, 'stroke-width': 2 }));
    text(svg, 320, 95, 'classified', { fill: PALETTE.red, 'font-size': 10, 'text-anchor': 'middle', 'font-weight': 700 });
    text(svg, 320, 158, 'equipment, gas group, and protection method must agree', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function energyBars(svg, title) {
    text(svg, 320, 23, title, { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    const bars = [['load', 0.7, PALETTE.blue], ['headroom', 0.3, PALETTE.green], ['reserve', 0.18, PALETTE.yellow]];
    bars.forEach(([label, width, color], index) => {
      const y = 52 + index * 29;
      text(svg, 86, y + 7, label, { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'end' });
      svg.appendChild(svgElement('rect', { x: 104, y, width: 470, height: 13, rx: 6, fill: 'rgba(255,255,255,0.08)' }));
      svg.appendChild(svgElement('rect', { x: 104, y, width: 470 * width, height: 13, rx: 6, fill: color }));
    });
    text(svg, 320, 151, 'capacity is read against demand and reserve', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function drivetrain(svg) {
    text(svg, 320, 23, 'DRIVETRAIN RATIO', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    svg.appendChild(svgElement('circle', { cx: 190, cy: 92, r: 48, fill: 'none', stroke: PALETTE.blue, 'stroke-width': 3 }));
    svg.appendChild(svgElement('circle', { cx: 450, cy: 92, r: 25, fill: 'none', stroke: PALETTE.yellow, 'stroke-width': 3 }));
    for (let i = 0; i < 12; i += 1) {
      const a = i * Math.PI / 6;
      line(svg, 190 + Math.cos(a) * 40, 92 + Math.sin(a) * 40, 190 + Math.cos(a) * 50, 92 + Math.sin(a) * 50, { stroke: PALETTE.blue, 'stroke-width': 2 });
    }
    for (let i = 0; i < 8; i += 1) {
      const a = i * Math.PI / 4;
      line(svg, 450 + Math.cos(a) * 20, 92 + Math.sin(a) * 20, 450 + Math.cos(a) * 28, 92 + Math.sin(a) * 28, { stroke: PALETTE.yellow, 'stroke-width': 2 });
    }
    line(svg, 245, 92, 392, 92, { stroke: PALETTE.green, 'stroke-width': 3 });
    text(svg, 190, 151, 'driven', { fill: PALETTE.blue, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 450, 151, 'driver', { fill: PALETTE.yellow, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function safetyLoop(svg) {
    text(svg, 320, 23, 'INTRINSIC-SAFETY LOOP', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    line(svg, 108, 66, 214, 66, { stroke: PALETTE.blue, 'stroke-width': 3 });
    line(svg, 326, 66, 432, 66, { stroke: PALETTE.yellow, 'stroke-width': 3 });
    line(svg, 432, 118, 108, 118, { stroke: PALETTE.green, 'stroke-width': 3 });
    [108, 214, 326, 432].forEach((x) => svg.appendChild(svgElement('circle', { cx: x, cy: x === 108 || x === 432 ? 66 : 66, r: 5, fill: PALETTE.text })));
    text(svg, 160, 53, 'barrier', { fill: PALETTE.blue, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 380, 53, 'field device', { fill: PALETTE.yellow, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 320, 145, 'entity parameters must close the loop', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function empCage(svg) {
    text(svg, 320, 20, 'VICTIM LOOP AND CAGE', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    svg.appendChild(svgElement('rect', { x: 70, y: 40, width: 220, height: 100, fill: 'none', stroke: PALETTE.accent, 'stroke-width': 3 }));
    svg.appendChild(svgElement('rect', { x: 286, y: 78, width: 10, height: 28, fill: '#05060f', stroke: PALETTE.yellow, 'stroke-width': 2 }));
    svg.appendChild(svgElement('rect', { x: 370, y: 58, width: 160, height: 64, fill: 'none', stroke: PALETTE.blue, 'stroke-width': 2 }));
    text(svg, 180, 94, 'cage', { fill: PALETTE.accent, 'font-size': 12, 'text-anchor': 'middle', 'font-weight': 700 });
    text(svg, 450, 94, 'victim loop', { fill: PALETTE.blue, 'font-size': 11, 'text-anchor': 'middle' });
    text(svg, 291, 72, 'slot', { fill: PALETTE.yellow, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 320, 162, 'Close slots, shrink loop area, filter the cable entry', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function lightRays(svg) {
    text(svg, 320, 23, 'ILLUMINATION GEOMETRY', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    svg.appendChild(svgElement('circle', { cx: 320, cy: 72, r: 10, fill: PALETTE.yellow }));
    for (let i = 0; i < 9; i += 1) {
      const x = 116 + i * 51;
      line(svg, 320, 82, x, 128, { stroke: i % 2 ? PALETTE.yellow : PALETTE.blue, 'stroke-width': 2 });
    }
    line(svg, 88, 132, 552, 132, { stroke: PALETTE.line, 'stroke-width': 3 });
    text(svg, 320, 151, 'inverse-square behavior depends on distance and geometry', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function tapLadder(svg) {
    text(svg, 320, 23, 'TRANSFORMER TAP POSITION', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    line(svg, 88, 108, 552, 108, { stroke: PALETTE.line, 'stroke-width': 2 });
    for (let i = 0; i < 7; i += 1) {
      const x = 112 + i * 72;
      const y = 108 - Math.abs(i - 3) * 12;
      line(svg, x, y, x, 108, { stroke: i === 3 ? PALETTE.green : PALETTE.blue, 'stroke-width': 3 });
      svg.appendChild(svgElement('circle', { cx: x, cy: y, r: 5, fill: i === 3 ? PALETTE.green : PALETTE.blue }));
      text(svg, x, 132, `${i - 3 > 0 ? '+' : ''}${i - 3}`, { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
    }
    text(svg, 320, 151, 'tap changes shift the secondary voltage around nominal', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function harmonicSpectrum(svg) {
    const orders = [1, 0.18, 0.34, 0.08, 0.2, 0.05, 0.12];
    const samples = orders.map((height, index) => [index + 1, height]);
    seriesPlot(svg, {
      xLabel: 'Harmonic order',
      yLabel: 'Magnitude (relative)',
      xUnit: '',
      yUnit: 'pu',
      xMin: 1,
      xMax: 7,
      yMin: 0,
      yMax: 1.1,
      series: [{ name: 'Spectrum', color: PALETTE.blue, samples }],
    });
  }

  function pulseTrace(svg) {
    text(svg, 16, 24, 'REFLECTION TRACE', { fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    line(svg, 24, 88, 616, 88, { stroke: PALETTE.line });
    const points = [];
    for (let x = 24; x <= 616; x += 4) {
      let y = 88;
      if (x > 94 && x < 168) y = 88 - (x < 112 ? (x - 94) * 1.8 : x < 150 ? 32 : (168 - x) * 1.8);
      if (x > 360 && x < 430) y = 88 + (x < 378 ? (x - 360) * 1.5 : x < 414 ? 27 : (430 - x) * 1.5);
      points.push(x + ',' + y);
    }
    svg.appendChild(svgElement('polyline', { points: points.join(' '), fill: 'none', stroke: PALETTE.green, 'stroke-width': 3, 'stroke-linejoin': 'round' }));
    text(svg, 112, 58, 'launch', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 395, 125, 'reflected event', { fill: PALETTE.green, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 24, 124, 'time ->', { fill: PALETTE.muted, 'font-size': 11 });
  }

  function gauge(svg, value, label, color) {
    const pct = Math.max(0, Math.min(100, Number.isFinite(value) ? value : 0));
    text(svg, 20, 28, label, { fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.2 });
    svg.appendChild(svgElement('rect', { x: 20, y: 62, width: 600, height: 22, rx: 11, fill: 'rgba(255,255,255,0.08)' }));
    svg.appendChild(svgElement('rect', { x: 20, y: 62, width: 6 * pct, height: 22, rx: 11, fill: color }));
    text(svg, 20, 120, '0%', { fill: PALETTE.muted, 'font-size': 11 });
    text(svg, 320, 120, pct.toFixed(1) + '%', { fill: color, 'font-size': 20, 'font-weight': 700, 'text-anchor': 'middle' });
    text(svg, 620, 120, '100%', { fill: PALETTE.muted, 'font-size': 11, 'text-anchor': 'end' });
  }

  function numericSignal(svg, values) {
    const max = Math.max.apply(null, values.map((v) => Math.abs(v)).concat([1]));
    const points = values.map((value, index) => (40 + index * (560 / Math.max(values.length - 1, 1))) + ',' + (82 - (value / max) * 48));
    text(svg, 20, 24, 'CALCULATION SIGNAL', { fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.2 });
    line(svg, 20, 82, 620, 82, { stroke: PALETTE.line });
    if (points.length > 1) svg.appendChild(svgElement('polyline', { points: points.join(' '), fill: 'none', stroke: PALETTE.accent, 'stroke-width': 3, 'stroke-linejoin': 'round' }));
    values.forEach((value, index) => {
      const x = 40 + index * (560 / Math.max(values.length - 1, 1));
      const y = 82 - (value / max) * 48;
      svg.appendChild(svgElement('circle', { cx: x, cy: y, r: 5, fill: PALETTE.accent, stroke: PALETTE.text, 'stroke-width': 1 }));
    });
    text(svg, 20, 124, 'Inputs and outputs stay in the result above', { fill: PALETTE.muted, 'font-size': 11 });
  }

  function conductorLength(svg) {
    text(svg, 320, 23, 'CONDUCTOR LENGTH FROM RESISTANCE', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.4 });
    line(svg, 78, 92, 562, 92, { stroke: PALETTE.blue, 'stroke-width': 5 });
    for (let x = 98; x <= 542; x += 37) line(svg, x, 80, x, 104, { stroke: PALETTE.text, 'stroke-width': 1 });
    svg.appendChild(svgElement('circle', { cx: 92, cy: 92, r: 12, fill: PALETTE.green }));
    svg.appendChild(svgElement('circle', { cx: 548, cy: 92, r: 12, fill: PALETTE.yellow }));
    text(svg, 92, 126, 'test lead', { fill: PALETTE.green, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 548, 126, 'short / far end', { fill: PALETTE.yellow, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 320, 151, 'milliohm reading × conductor area, then book lb/kft × one-way length for metal weight', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function loadFactors(svg) {
    text(svg, 320, 23, 'LOAD FACTOR RELATIONSHIPS', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.4 });
    const rows = [
      ['connected', 0.92, PALETTE.blue],
      ['peak demand', 0.68, PALETTE.yellow],
      ['average load', 0.42, PALETTE.green],
    ];
    rows.forEach(([label, value, color], index) => {
      const y = 53 + index * 28;
      text(svg, 132, y + 8, label, { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'end' });
      svg.appendChild(svgElement('rect', { x: 148, y, width: 360, height: 14, rx: 4, fill: 'rgba(255,255,255,0.08)' }));
      svg.appendChild(svgElement('rect', { x: 148, y, width: 360 * Number(value), height: 14, rx: 4, fill: color }));
    });
    line(svg, 508, 44, 508, 134, { stroke: PALETTE.text, 'stroke-width': 1, 'stroke-dasharray': '4 4' });
    text(svg, 508, 40, 'capacity', { fill: PALETTE.text, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 320, 151, 'compare like-for-like intervals before applying demand or diversity assumptions', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function panelLoad(svg) {
    text(svg, 320, 23, 'PANEL LOAD BUILD-UP', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.4 });
    const blocks = [['lighting', PALETTE.yellow], ['motors', PALETTE.blue], ['receptacles', PALETTE.green], ['process', PALETTE.accent]];
    blocks.forEach(([label, color], index) => {
      const x = 112 + index * 108;
      svg.appendChild(svgElement('rect', { x, y: 66, width: 78, height: 48, rx: 5, fill: 'rgba(255,255,255,0.05)', stroke: color, 'stroke-width': 2 }));
      text(svg, x + 39, 94, label, { fill: color, 'font-size': 10, 'font-weight': 700, 'text-anchor': 'middle' });
      if (index < blocks.length - 1) line(svg, x + 80, 90, x + 101, 90, { stroke: PALETTE.line, 'stroke-width': 2 });
    });
    text(svg, 320, 151, 'OCR extracts the schedule; reviewed load categories build the planning estimate', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
  }

  function build(result) {
    if (!result || result.dataset.visualized === '1' || !result.classList.contains('show') || result.classList.contains('error')) return;
    // Native STEM charts carry the explanation; do not append a generic signal over them.
    if (result.querySelector('svg, .calculation-visual')) return;
    const section = result.closest('.section');
    if (!section) return;
    result.dataset.visualized = '1';
    const values = resultNumbers(result);
    const id = section.id;
    if (id === 'sec-ohm') return ohms(shell(result, 'Ohm\'s law relationship between voltage, current, and resistance'));
    if (id === 'sec-555') return waveform(shell(result, '555 timer output waveform over three periods'));
    if (id === 'sec-conductor-length') return conductorLength(shell(result, 'Length and estimated metal weight from a milliohm reading — end-to-end or short-to-parallel'));
    if (id === 'sec-vdrop') {
      const percent = labeledNumber(result, /drop\s*%|percent/i);
      const fallback = labeledNumber(result, /drop/i);
      return voltageDropPlot(shell(result, 'Voltage drop along the run, with the 3 percent and 5 percent design notes'), Number.isFinite(percent) ? percent : fallback);
    }
    if (id === 'sec-conduit' || id === 'sec-conduit-adv') return conduitSection(shell(result, 'Conduit cross-section and conductor fill envelope'));
    if (id === 'sec-power-dc') return energyBars(shell(result, 'DC power load and capacity relationship'), 'DC POWER BALANCE');
    if (id === 'sec-power-wizard') return;
    if (id === 'sec-magnetic-circuit' || id === 'sec-transient-circuits' || id === 'sec-phasor-diagram') return;
    if (id === 'sec-semiconductor-iv' || id === 'sec-fiber-link' || id === 'sec-gaussian-beam') return;
    if (id === 'sec-reactance') return reactancePlot(shell(result, 'Inductive reactance rises while capacitive reactance falls with frequency'));
    if (id === 'sec-resonance') return resonancePlot(shell(result, 'Resonance response with a marked resonant frequency'));
    if (id === 'sec-harmonics') return harmonicSpectrum(shell(result, 'Harmonic spectrum by order'));
    if (id === 'sec-pfc') return powerTriangle(shell(result, 'Power triangle showing real, reactive, and apparent power'));
    if (id === 'sec-sp') return network(shell(result, 'Series or parallel circuit relationship'), /parallel/i.test(result.textContent || ''));
    if (id === 'sec-motor') {
      const horsepower = result.id === 'mfla_result' ? inputNumber('mfla_hp') : labeledNumber(result, /horsepower/i);
      return motorCurve(shell(result, 'Constant-horsepower torque falls as speed rises. Rated torque is 1.0 at rated speed.'), horsepower);
    }
    if (id === 'sec-xfmr' || id === 'sec-xfmr-size' || id === 'sec-xfmr-engine' || id === 'sec-xfmr-wizard') return transformer(shell(result, 'Transformer primary to secondary energy transfer'));
    if (id === 'sec-wire-select') return capacity(shell(result, 'Conductor ampacity against the allowable design envelope'), 'AMPACITY SELECTION', 'selected conductor vs allowable envelope', PALETTE.green);
    if (id === 'sec-sc') return faultPath(shell(result, 'Source through overcurrent protection to fault path'));
    if (id === 'sec-ups' || id === 'sec-gen' || id === 'sec-hybrid' || id === 'sec-bess' || id === 'sec-solar-wizard') return energyBars(shell(result, 'Load, reserve, and capacity relationship'), 'ENERGY CAPACITY');
    if (id === 'sec-ebike-tools') return drivetrain(shell(result, 'E-bike drivetrain gear ratio relationship'));
    if (id === 'sec-nec') return faultPath(shell(result, 'Branch circuit source, protection, conductors, and load path'));
    if (id === 'sec-isloop') return safetyLoop(shell(result, 'Intrinsic-safety barrier and field-device loop'));
    if (id === 'sec-emp-emc') return empCage(shell(result, 'Shielded volume with a slot and a victim loop outside the opening'));
    if (id === 'sec-lighting-opt' || id === 'sec-photometrics') return lightRays(shell(result, 'Lighting geometry and illumination spread'));
    if (id === 'sec-tap') return tapLadder(shell(result, 'Transformer tap positions around nominal voltage'));
    if (id === 'sec-cm') return conductorCrossSection(shell(result, 'Conductor diameter and circular-mil area relationship'));
    if (id === 'sec-convert') return unitFlow(shell(result, 'Electrical unit conversion path'));
    if (id === 'sec-haz') return hazardBoundary(shell(result, 'Hazardous-area classification boundary'));
    if (id === 'sec-bldg-load') return energyBars(shell(result, 'Building load and reserve relationship'), 'BUILDING LOAD');
    if (id === 'sec-load-factors') return loadFactors(shell(result, 'Connected, peak, and average load relationships used for demand and diversity factors'));
    if (id === 'sec-power-ac') return powerTriangle(shell(result, 'Power triangle showing real, reactive, and apparent power'));
    if (id === 'sec-tdr') return pulseTrace(shell(result, 'Time-domain reflectometry launch pulse and reflected fault event'));
    if (id === 'sec-stem-tools') return numericSignal(shell(result, 'Visual summary of the numerical values shown above'), values.length ? values : [0, 1]);
    if (id === 'sec-panel-schedule' || id === 'sec-panel-power-study') return panelLoad(shell(result, 'Panel schedule load categories building toward a capacity estimate'));
    if (id === 'sec-lp-optimizer' || id === 'sec-base-converter' || id === 'sec-io-list-generator' || id === 'sec-signal-scaling' || id === 'sec-ebus-budget' || id === 'sec-modbus-address' || id === 'sec-plc-timer-preset') return;
    return numericSignal(shell(result, 'Data-driven visual summary of the calculated values shown above'), values.length ? values : [0, 1]);
  }

  window.BeckifyResultVisuals = { shell: shell };

  function init() {
    const observe = () => document.querySelectorAll('.result.show').forEach(build);
    observe();
    const observer = new MutationObserver(observe);
    observer.observe(document.body, { subtree: true, childList: true });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
