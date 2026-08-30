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
    const svg = svgElement('svg', { viewBox: '0 0 640 156', width: '100%', height: 'auto', focusable: 'false', 'aria-hidden': 'true' });
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

  function build(result) {
    if (!result || result.dataset.visualized === '1' || !result.classList.contains('show') || result.classList.contains('error')) return;
    const section = result.closest('.section');
    if (!section) return;
    result.dataset.visualized = '1';
    const values = resultNumbers(result);
    const id = section.id;
    if (id === 'sec-ohm') return ohms(shell(result, 'Ohm\'s law relationship between voltage, current, and resistance'));
    if (id === 'sec-vdrop' || id === 'sec-lighting-opt') return gauge(shell(result, 'Voltage drop shown as a percentage of the source voltage'), values.find((value, index) => /drop/i.test(result.querySelectorAll('.res-label')[index]?.textContent || '')) || values[0], 'VOLTAGE DROP', PALETTE.yellow);
    if (id === 'sec-conduit' || id === 'sec-conduit-adv') return gauge(shell(result, 'Conduit fill shown against the permitted fill envelope'), values.find((value, index) => /fill/i.test(result.querySelectorAll('.res-label')[index]?.textContent || '')) || values[0], 'RACEWAY FILL', PALETTE.green);
    if (id === 'sec-reactance' || id === 'sec-resonance' || id === 'sec-harmonics') return waveform(shell(result, 'AC waveform showing changing electrical response over time'), 'AC RESPONSE', PALETTE.blue);
    if (id === 'sec-power-ac' || id === 'sec-pfc') return waveform(shell(result, 'Power waveform showing phase and energy flow'), 'POWER FLOW', PALETTE.accent);
    if (id === 'sec-tdr') return waveform(shell(result, 'Time-domain reflectometry pulse trace with a reflected event'), 'TDR TRACE', PALETTE.green);
    if (id === 'sec-stem-tools') return waveform(shell(result, 'Numerical solution changing across the independent variable'), 'NUMERICAL SOLUTION', PALETTE.yellow);
    return numericSignal(shell(result, 'Visual summary of the calculator values shown above'), values.length ? values : [0, 1]);
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
