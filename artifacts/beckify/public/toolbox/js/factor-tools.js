/* Load-factor relationships for planning and utilization checks. */
'use strict';

function factorValue(id) {
  const element = document.getElementById(id);
  const text = element ? String(element.value).trim() : '';
  if (!text) return null;
  const value = Number(text);
  return Number.isFinite(value) && value >= 0 ? value : null;
}

function factorPercent(value) {
  return `${(value * 100).toFixed(1).replace(/\.0$/, '')}%`;
}

function appendGrowthChart(host, peak, capacity, growthRate, years) {
  if (peak == null || growthRate == null || years == null || years < 1) return;
  const namespace = 'http://www.w3.org/2000/svg';
  const make = (name, attrs, label) => {
    const el = document.createElementNS(namespace, name);
    Object.entries(attrs || {}).forEach(([key, value]) => el.setAttribute(key, value));
    if (label != null) el.textContent = label;
    return el;
  };
  const projected = peak * ((1 + growthRate) ** years);
  const maximum = Math.max(projected, capacity || 0, peak) * 1.12 || 1;
  const x0 = 52, y0 = 24, width = 500, height = 130;
  const x = (year) => x0 + (year / years) * width;
  const y = (value) => y0 + height - (value / maximum) * height;
  const wrap = document.createElement('div');
  wrap.className = 'calculation-visual lf-growth-chart';
  const title = document.createElement('p');
  title.className = 'visual-title';
  title.textContent = `Demand forecast · ${factorPercent(growthRate)} annual growth`;
  const svg = make('svg', { viewBox: '0 0 620 205', role: 'img', 'aria-label': `Projected peak demand rises from ${fmt(peak)} kilovolt-amperes today to ${fmt(projected)} kilovolt-amperes in ${years} years.` });
  svg.append(make('line', { x1: x0, y1: y0, x2: x0, y2: y0 + height, stroke: '#6f7486', 'stroke-width': '1' }));
  svg.append(make('line', { x1: x0, y1: y0 + height, x2: x0 + width, y2: y0 + height, stroke: '#6f7486', 'stroke-width': '1' }));
  [0, 0.5, 1].forEach((step) => {
    const value = maximum * step;
    const py = y(value);
    svg.append(make('line', { x1: x0, y1: py, x2: x0 + width, y2: py, stroke: '#292e3a', 'stroke-width': '1' }));
    svg.append(make('text', { x: x0 - 8, y: py + 4, fill: '#aeb5c4', 'font-size': '10', 'text-anchor': 'end' }, `${fmt(value)} kVA`));
  });
  if (capacity != null && capacity > 0) {
    const py = y(capacity);
    svg.append(make('line', { x1: x0, y1: py, x2: x0 + width, y2: py, stroke: '#f6c453', 'stroke-width': '2', 'stroke-dasharray': '6 4' }));
    svg.append(make('text', { x: x0 + width, y: py - 6, fill: '#f6c453', 'font-size': '11', 'text-anchor': 'end' }, `capacity ${fmt(capacity)} kVA`));
  }
  let points = '';
  for (let year = 0; year <= years; year += 1) points += `${x(year)},${y(peak * ((1 + growthRate) ** year))} `;
  svg.append(make('polyline', { points, fill: 'none', stroke: '#49b8ff', 'stroke-width': '3', 'stroke-linejoin': 'round', 'stroke-linecap': 'round' }));
  [0, years].forEach((year) => {
    const value = peak * ((1 + growthRate) ** year);
    svg.append(make('circle', { cx: x(year), cy: y(value), r: '4', fill: '#49b8ff', stroke: '#f8fbff', 'stroke-width': '1.5' }));
    svg.append(make('text', { x: x(year), y: y(value) - 10, fill: '#f8fbff', 'font-size': '11', 'font-weight': '700', 'text-anchor': year === 0 ? 'start' : 'end' }, `${fmt(value, 1)} kVA`));
    svg.append(make('text', { x: x(year), y: y0 + height + 18, fill: '#aeb5c4', 'font-size': '10', 'text-anchor': 'middle' }, year === 0 ? 'today' : `year ${year}`));
  });
  svg.append(make('text', { x: x0, y: 190, fill: '#aeb5c4', 'font-size': '10' }, 'Blue = projected peak demand · dashed gold = entered available capacity'));
  wrap.append(title, svg);
  host.append(wrap);
}

window.calcLoadFactors = function calcLoadFactors() {
  const connected = factorValue('lf_connected');
  const peak = factorValue('lf_peak');
  const individual = factorValue('lf_individual');
  const average = factorValue('lf_average');
  const capacity = factorValue('lf_capacity');
  const growthPercent = factorValue('lf_growth');
  const years = factorValue('lf_years');
  const growthRate = growthPercent == null ? null : growthPercent / 100;
  const rows = [];
  const suggestions = [];

  if (connected != null && peak != null) rows.push(['Demand factor', factorPercent(peak / connected)]);
  else suggestions.push('Demand factor needs connected load and maximum system demand. Use schedules/nameplates for connected load and a matching-interval meter or BMS peak for demand.');
  if (individual != null && peak != null && peak > 0) {
    const diversity = individual / peak;
    rows.push(['Diversity factor', diversity.toFixed(3)]);
    rows.push(['Coincidence factor', (1 / diversity).toFixed(3)]);
  } else suggestions.push('Diversity and coincidence need the sum of individual maximum demands and the maximum system demand over the same interval.');
  if (average != null && peak != null && peak > 0) rows.push(['Load factor', factorPercent(average / peak)]);
  else suggestions.push('Load factor needs average demand and the matching peak over the same time period.');
  if (capacity != null && peak != null && capacity > 0) {
    const margin = capacity - peak;
    rows.push(['Capacity utilization', factorPercent(peak / capacity)]);
    rows.push(['Capacity remaining', `${fmt(margin)} kVA${margin < 0 ? ' (over stated capacity)' : ''}`]);
  } else suggestions.push('Capacity utilization needs the equipment capacity and maximum system demand. Use the applicable continuous-duty/equipment basis.');
  if (growthRate != null && years != null && peak != null && years > 0) {
    const projected = peak * ((1 + growthRate) ** years);
    rows.push([`Projected peak (${fmt(years)} yr)`, `${fmt(projected, 1)} kVA`]);
    if (capacity != null && capacity > 0) {
      rows.push([`Projected utilization (${fmt(years)} yr)`, factorPercent(projected / capacity)]);
      if (growthRate > 0 && peak < capacity) {
        const threshold = Math.log(capacity / peak) / Math.log(1 + growthRate);
        rows.push(['Capacity reached (growth case)', threshold >= 0 ? `${fmt(threshold, 1)} years` : 'Already exceeded']);
      }
    }
  } else if (growthRate != null || years != null) suggestions.push('Growth projection needs current maximum demand, an annual growth percentage, and a forecast horizon.');

  if (!rows.length) return showError('lf_result', 'Enter at least one complete pair of values. Blank fields are treated as unknown, not zero.');
  showResult('lf_result', rows);
  const result = document.getElementById('lf_result');
  if (result && suggestions.length) {
    const guidance = document.createElement('div');
    guidance.className = 'note';
    guidance.style.marginTop = '10px';
    guidance.textContent = suggestions.join(' ');
    result.appendChild(guidance);
  }
  appendGrowthChart(result, peak, capacity, growthRate, years);
};

if (typeof window !== 'undefined' && window.__ENABLE_FACTOR_TEST_API__) window.__factorTestApi = { factorPercent };
