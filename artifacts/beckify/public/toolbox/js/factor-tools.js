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

window.calcLoadFactors = function calcLoadFactors() {
  const connected = factorValue('lf_connected');
  const peak = factorValue('lf_peak');
  const individual = factorValue('lf_individual');
  const average = factorValue('lf_average');
  const capacity = factorValue('lf_capacity');
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
};

if (typeof window !== 'undefined' && window.__ENABLE_FACTOR_TEST_API__) window.__factorTestApi = { factorPercent };
