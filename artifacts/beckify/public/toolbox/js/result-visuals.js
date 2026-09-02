(function () {
  'use strict';

  /*
   * Calculator results are deliberately plain text so they remain copyable,
   * searchable, and usable offline. This layer adds a visual reading path
   * beside the same values without making any calculator depend on a chart
   * library or a second rendering pipeline.
   */
  const SVG_NS = 'http://www.w3.org/2000/svg';
  const PALETTE = { accent: '#8b7bff', blue: '#60a5fa', green: '#6ee7b7', yellow: '#f5c451', red: '#ff8a8a', text: '#eef0fa', muted: '#9497b8', line: 'rgba(255,255,255,0.14)' };

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
    // SVG height must be a numeric length or omitted. CSS owns responsive sizing.
    const svg = svgElement('svg', { viewBox: '0 0 640 180', width: '100%', focusable: 'false', 'aria-hidden': 'true' });
    wrap.appendChild(svg);
    const copy = result.querySelector('.result-copy-row');
    result.insertBefore(wrap, copy || null);
    return svg;
  }

  function text(svg, x, y, value, attrs) {
    const node = svgElement('text', Object.assign({ x, y, fill: PALETTE.text, 'font-size': 13, 'font-family': 'JetBrains Mono, monospace' }, attrs || {}));
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

  function waveform(svg, title, color) {
    text(svg, 16, 24, title, { fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    line(svg, 24, 88, 616, 88, { stroke: PALETTE.line });
    const points = [];
    for (let x = 24; x <= 616; x += 6) points.push(x + ',' + (88 - Math.sin((x - 24) / 48) * 35));
    svg.appendChild(svgElement('polyline', { points: points.join(' '), fill: 'none', stroke: color, 'stroke-width': 3, 'stroke-linejoin': 'round' }));
    text(svg, 24, 124, '0', { fill: PALETTE.muted, 'font-size': 11 });
    text(svg, 616, 124, 'time ->', { fill: PALETTE.muted, 'font-size': 11, 'text-anchor': 'end' });
  }

  function plotAxes(svg, title, xLabel, yLabel) {
    text(svg, 16, 24, title, { fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    line(svg, 48, 132, 616, 132, { stroke: PALETTE.line });
    line(svg, 48, 42, 48, 132, { stroke: PALETTE.line });
    text(svg, 616, 151, xLabel, { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'end' });
    text(svg, 42, 42, yLabel, { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'end' });
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
    plotAxes(svg, 'REACTANCE VS FREQUENCY', 'frequency →', 'Ω');
    const xl = [], xc = [];
    for (let x = 48; x <= 616; x += 7) {
      const t = (x - 48) / 568;
      xl.push(`${x},${132 - t * 76}`);
      xc.push(`${x},${47 + t * 76}`);
    }
    svg.appendChild(svgElement('polyline', { points: xl.join(' '), fill: 'none', stroke: PALETTE.blue, 'stroke-width': 3 }));
    svg.appendChild(svgElement('polyline', { points: xc.join(' '), fill: 'none', stroke: PALETTE.yellow, 'stroke-width': 3 }));
    text(svg, 570, 58, 'XL = 2πfL', { fill: PALETTE.blue, 'font-size': 10, 'text-anchor': 'end' });
    text(svg, 570, 126, 'XC = 1/(2πfC)', { fill: PALETTE.yellow, 'font-size': 10, 'text-anchor': 'end' });
  }

  function resonancePlot(svg) {
    plotAxes(svg, 'RESONANCE WINDOW', 'frequency →', 'response');
    const points = [];
    for (let x = 48; x <= 616; x += 7) {
      const t = (x - 48) / 568;
      const y = 132 - 82 * Math.exp(-Math.pow((t - 0.52) / 0.12, 2));
      points.push(`${x},${y}`);
    }
    svg.appendChild(svgElement('polyline', { points: points.join(' '), fill: 'none', stroke: PALETTE.green, 'stroke-width': 3 }));
    line(svg, 343, 42, 343, 132, { stroke: PALETTE.green, 'stroke-width': 1.5, 'stroke-dasharray': '4 4' });
    text(svg, 343, 38, 'f₀', { fill: PALETTE.green, 'font-size': 12, 'text-anchor': 'middle', 'font-weight': 700 });
    text(svg, 343, 151, 'resonant frequency', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
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
    text(svg, 320, 23, 'HARMONIC SPECTRUM', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    line(svg, 80, 130, 590, 130, { stroke: PALETTE.line });
    [0.92, 0.2, 0.36, 0.1, 0.22, 0.07, 0.14].forEach((height, index) => {
      const x = 104 + index * 70;
      svg.appendChild(svgElement('rect', { x, y: 130 - height * 76, width: 30, height: height * 76, rx: 4, fill: index === 0 ? PALETTE.blue : PALETTE.red }));
      text(svg, x + 15, 148, `${index + 1}`, { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
    });
    text(svg, 320, 23, 'HARMONIC SPECTRUM', { 'text-anchor': 'middle', fill: PALETTE.muted, 'font-size': 11, 'letter-spacing': 1.5 });
    text(svg, 320, 166, 'order →', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
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
    text(svg, 548, 126, 'far end', { fill: PALETTE.yellow, 'font-size': 10, 'text-anchor': 'middle' });
    text(svg, 320, 151, 'measured resistance × conductor area estimates the path length', { fill: PALETTE.muted, 'font-size': 10, 'text-anchor': 'middle' });
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
    if (id === 'sec-conductor-length') return conductorLength(shell(result, 'Conductor path measured from test resistance'));
    if (id === 'sec-vdrop') return gauge(shell(result, 'Voltage drop shown as a percentage of the source voltage'), values.find((_value, index) => /drop/i.test(result.querySelectorAll('.res-label')[index]?.textContent || '')) || values[0], 'VOLTAGE DROP', PALETTE.yellow);
    if (id === 'sec-conduit' || id === 'sec-conduit-adv') return conduitSection(shell(result, 'Conduit cross-section and conductor fill envelope'));
    if (id === 'sec-power-dc') return energyBars(shell(result, 'DC power load and capacity relationship'), 'DC POWER BALANCE');
    if (id === 'sec-power-wizard') return;
    if (id === 'sec-magnetic-circuit' || id === 'sec-transient-circuits' || id === 'sec-phasor-diagram') return;
    if (id === 'sec-reactance') return reactancePlot(shell(result, 'Inductive reactance rises while capacitive reactance falls with frequency'));
    if (id === 'sec-resonance') return resonancePlot(shell(result, 'Resonance response with a marked resonant frequency'));
    if (id === 'sec-harmonics') return harmonicSpectrum(shell(result, 'Harmonic spectrum by order'));
    if (id === 'sec-pfc') return powerTriangle(shell(result, 'Power triangle showing real, reactive, and apparent power'));
    if (id === 'sec-sp') return network(shell(result, 'Series or parallel circuit relationship'), /parallel/i.test(result.textContent || ''));
    if (id === 'sec-motor') return energyBars(shell(result, 'Motor electrical input, mechanical output, and reserve relationship'), 'MOTOR POWER PATH');
    if (id === 'sec-xfmr' || id === 'sec-xfmr-size' || id === 'sec-xfmr-engine' || id === 'sec-xfmr-wizard') return transformer(shell(result, 'Transformer primary to secondary energy transfer'));
    if (id === 'sec-wire-select') return capacity(shell(result, 'Conductor ampacity against the allowable design envelope'), 'AMPACITY SELECTION', 'selected conductor vs allowable envelope', PALETTE.green);
    if (id === 'sec-sc') return faultPath(shell(result, 'Source through overcurrent protection to fault path'));
    if (id === 'sec-ups' || id === 'sec-gen' || id === 'sec-hybrid' || id === 'sec-bess') return energyBars(shell(result, 'Load, reserve, and capacity relationship'), 'ENERGY CAPACITY');
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
    if (id === 'sec-lp-optimizer' || id === 'sec-base-converter') return;
    return numericSignal(shell(result, 'Data-driven visual summary of the calculated values shown above'), values.length ? values : [0, 1]);
  }

  function init() {
    const observe = () => document.querySelectorAll('.result.show').forEach(build);
    observe();
    const observer = new MutationObserver(observe);
    observer.observe(document.body, { subtree: true, childList: true });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
