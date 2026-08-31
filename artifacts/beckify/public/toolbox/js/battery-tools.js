/* Battery-build planning helpers. Values are user-adjustable estimates, not safety ratings. */
(function () {
  'use strict';
  const $ = (id) => document.getElementById(id); const n = (id) => Number($(id)?.value); const pos = (x) => Number.isFinite(x) && x > 0;
  const fmt = (x, d = 2) => Number(x).toLocaleString('en-US', { maximumFractionDigits: d });
  const row = (host, label, val, green) => { const e = document.createElement('div'); e.className = 'res-row'; const l = document.createElement('span'); l.className = 'res-label'; l.textContent = label; const v = document.createElement('span'); v.className = 'res-val'; v.textContent = val; if (green) { v.style.color = '#6ee7b7'; v.style.fontWeight = '700'; } e.append(l, v); host.append(e); };
  const strips = [[6,.1],[8,.1],[6,.15],[8,.15],[10,.15],[8,.2],[10,.2]];
  window.showBatteryPanel = (name) => ['strip','pack'].forEach((p) => { $('battery-panel-'+p).hidden = p !== name; $('battery-tab-'+p).classList.toggle('active', p === name); });
  function renderStripTable() { const host = $('ns_table'); if (!host) return; const cj = n('ns_cont_j') || 5, pj = n('ns_pulse_j') || 10; const table = document.createElement('table'); table.innerHTML = '<thead><tr><th>Strip</th><th>Cross section</th><th>Continuous planning</th><th>Short pulse planning</th></tr></thead>'; const body = document.createElement('tbody'); strips.forEach(([w,t]) => { const a = w*t, tr = document.createElement('tr'); [ `${w} × ${t} mm`, `${fmt(a,3)} mm²`, `${fmt(a*cj,1)} A`, `${fmt(a*pj,1)} A`].forEach((x) => { const td = document.createElement('td'); td.textContent=x; tr.append(td); }); body.append(tr); }); table.append(body); host.replaceChildren(table); }
  window.calcNickelStrip = () => { const host=$('ns_result'), w=n('ns_width'), t=n('ns_thickness'), cj=n('ns_cont_j'), pj=n('ns_pulse_j'); host.textContent=''; if (![w,t,cj,pj].every(pos)) { host.textContent='Enter positive width, thickness, and current-density values.'; return; } host.className='result show'; const a=w*t; row(host,'Cross section',fmt(a,3)+' mm²',true); row(host,'Continuous planning current',fmt(a*cj,1)+' A'); row(host,'Short-pulse planning current',fmt(a*pj,1)+' A'); row(host,'Caution','Derate for nickel-plated steel, long paths, poor welds, insulation, and temperature rise.'); renderStripTable(); };
  // Column pitch (cell-to-cell spacing within a row) is the same for grid and
  // honeycomb packing — only the ROW pitch shrinks in honeycomb, because
  // offset rows nest into the gaps of the row above (hex close-packing,
  // row pitch = col pitch × √3⁄2 ≈ 0.866). Getting this right is the
  // difference between "honeycomb" being a real space saving and just a
  // cosmetic zig-zag.
  const CLEARANCE = 3, MARGIN_W = 30, MARGIN_H = 35, GROUP_GAP = 10;
  function packPitch(d, honeycomb) { const col = d + CLEARANCE; return { col, rowPitch: honeycomb ? col * 0.8660254 : col }; }

  // Given the series count (fixed by voltage) and an available footprint,
  // find how many columns fit across one series group's width and how many
  // rows fit down the enclosure's height — i.e. actually design FROM the
  // geometry instead of only checking a pre-picked layout against it.
  function solveGeometry(series, maxW, maxH, d, honeycomb) {
    if (!pos(maxW) || !pos(maxH)) return null;
    const { col, rowPitch } = packPitch(d, honeycomb);
    const groupBudget = (maxW - MARGIN_W) / series - GROUP_GAP;
    return { perRow: Math.max(0, Math.floor(groupBudget / col)), rows: Math.max(0, Math.floor((maxH - MARGIN_H) / rowPitch)), col, rowPitch };
  }

  function drawLayout(series, parallel, perRow, rows, diameter, honeycomb, cellLength, maxW, maxH) {
    const host = $('bp_layout'), display = Math.min(series * parallel, 240), { col, rowPitch } = packPitch(diameter, honeycomb);
    const groupW = perRow * col + GROUP_GAP, gridW = series * groupW - GROUP_GAP, gridH = Math.max(0, rows - 1) * rowPitch + col;
    const hasBox = pos(maxW) && pos(maxH), originX = 24, originY = 40;
    const width = Math.max(380, originX + gridW + 30, hasBox ? originX + maxW + 30 : 0) + 90, height = Math.max(260, originY + gridH + 60, hasBox ? originY + maxH + 40 : 0);
    let cells = '';
    for (let s = 0; s < series; s += 1) {
      for (let p = 0; p < parallel && s * parallel + p < display; p += 1) {
        const r = Math.floor(p / perRow), c = p % perRow, cx = originX + s * groupW + c * col + (honeycomb && r % 2 ? col / 2 : 0), cy = originY + r * rowPitch, hue = 190 + (s * 31) % 130;
        cells += `<circle cx="${cx}" cy="${cy}" r="${diameter * .34}" fill="hsl(${hue} 65% 35%)" stroke="#d9d6ff" stroke-width="1.2"/><text x="${cx}" y="${cy + 3}" text-anchor="middle" fill="#fff" font-size="7">${s + 1}</text>`;
      }
    }
    let labels = '';
    for (let s = 0; s < series; s += 1) {
      const cx = originX + s * groupW + (perRow * col) / 2 - col / 2, tag = series === 1 ? '±' : s === 0 ? '+' : s === series - 1 ? '−' : '';
      labels += `<text x="${cx}" y="${originY - 16}" text-anchor="middle" fill="#9497b8" font-size="9" font-weight="700">S${s + 1}${tag ? '  ' + tag : ''}</text>`;
    }
    const gridRight = originX + gridW, gridBottom = originY + gridH - col / 2;
    const dims = `<line x1="${originX}" y1="${gridBottom + 16}" x2="${gridRight}" y2="${gridBottom + 16}" stroke="#5a5c76" stroke-width="1"/><line x1="${originX}" y1="${gridBottom + 12}" x2="${originX}" y2="${gridBottom + 20}" stroke="#5a5c76" stroke-width="1"/><line x1="${gridRight}" y1="${gridBottom + 12}" x2="${gridRight}" y2="${gridBottom + 20}" stroke="#5a5c76" stroke-width="1"/><text x="${(originX + gridRight) / 2}" y="${gridBottom + 30}" text-anchor="middle" fill="#9497b8" font-size="9">${fmt(gridW, 0)} mm</text><line x1="${gridRight + 14}" y1="${originY - col / 2}" x2="${gridRight + 14}" y2="${originY + gridH - col / 2}" stroke="#5a5c76" stroke-width="1"/><text x="${gridRight + 26}" y="${originY + gridH / 2 - col / 2}" fill="#9497b8" font-size="9" transform="rotate(90 ${gridRight + 26} ${originY + gridH / 2 - col / 2})" text-anchor="middle">${fmt(gridH, 0)} mm</text>`;
    const overflow = hasBox && (gridW > maxW || gridH > maxH), boxColor = overflow ? '#f87171' : '#4ade80';
    const box = hasBox ? `<rect x="${originX - GROUP_GAP}" y="${originY - col / 2 - 6}" width="${maxW}" height="${maxH}" fill="none" stroke="${boxColor}" stroke-width="1.5" stroke-dasharray="5 4"/><text x="${originX - GROUP_GAP}" y="${originY - col / 2 - 12}" fill="${boxColor}" font-size="9">Enclosure ${fmt(maxW, 0)} × ${fmt(maxH, 0)} mm${overflow ? ' — layout exceeds this' : ''}</text>` : '';
    const sideX = width - 60, sideLen = Math.min(cellLength, height - originY - 40);
    const sideView = `<text x="${sideX}" y="${originY - 16}" fill="#9497b8" font-size="9" font-weight="700" text-anchor="middle">Cell length</text><rect x="${sideX - 11}" y="${originY}" width="22" height="${sideLen}" rx="4" fill="#151a2b" stroke="#d9d6ff" stroke-width="1.2"/><line x1="${sideX + 20}" y1="${originY}" x2="${sideX + 20}" y2="${originY + sideLen}" stroke="#5a5c76"/><text x="${sideX + 30}" y="${originY + sideLen / 2}" fill="#9497b8" font-size="9" transform="rotate(90 ${sideX + 30} ${originY + sideLen / 2})" text-anchor="middle">${fmt(cellLength, 1)} mm</text>`;
    const more = series * parallel > display ? `<text x="${originX}" y="${height - 10}" fill="#f5c451" font-size="12">Layout shows first ${display} of ${series * parallel} cells.</text>` : '';
    host.innerHTML = `<svg viewBox="0 0 ${width} ${height}" aria-hidden="true">${box}${labels}${cells}${dims}${sideView}${more}</svg>`;
  }

  window.calc18650Pack = () => {
    const host = $('bp_result'); host.textContent = '';
    const V = n('bp_voltage'), I = n('bp_current') || 0, P = n('bp_power') || 0, cv = n('bp_cell_v'), ah = n('bp_cell_ah'), ca = n('bp_cell_a'), d = n('bp_cell_d'), len = n('bp_cell_l'), massG = n('bp_cell_m'), maxW = n('bp_space_w'), maxH = n('bp_space_h'), honey = $('bp_pattern').value === 'honeycomb';
    if (![V, cv, ah, ca, d, len].every(pos) || (!pos(I) && !pos(P))) { host.className = 'result show'; host.textContent = 'Enter a nominal voltage, at least one current or power target, and positive cell specifications.'; return; }
    const series = Math.max(1, Math.round(V / cv)), nominal = series * cv, required = Math.max(I, P / nominal), requiredParallel = Math.max(1, Math.ceil(required / ca));

    // This is the actual fix: when an enclosure footprint is given, DESIGN
    // the parallel count and grid shape from that footprint instead of only
    // checking a sqrt()-guessed square grid against it after the fact.
    const geom = solveGeometry(series, maxW, maxH, d, honey);
    let parallel, perRow, rows, spaceLimited = false, geomImpossible = false, minHNeeded = null;
    if (geom && geom.perRow > 0 && geom.rows > 0) {
      const parallelGeom = geom.perRow * geom.rows;
      parallel = Math.min(requiredParallel, parallelGeom);
      spaceLimited = parallelGeom < requiredParallel;
      rows = Math.min(geom.rows, Math.max(1, Math.ceil(parallel / geom.perRow)));
      perRow = Math.min(geom.perRow, Math.max(1, Math.ceil(parallel / rows)));
      if (spaceLimited) minHNeeded = Math.ceil(requiredParallel / geom.perRow) * geom.rowPitch + MARGIN_H;
    } else {
      if (geom) geomImpossible = true; // enclosure can't fit even 1 column × 1 row of this series count
      parallel = requiredParallel; perRow = Math.max(1, Math.ceil(Math.sqrt(parallel))); rows = Math.ceil(parallel / perRow);
    }

    const total = series * parallel, capacity = parallel * ah, wh = nominal * capacity, cellCurrent = required / parallel, crate = cellCurrent / ah;
    const { col, rowPitch } = packPitch(d, honey), packW = series * (perRow * col + GROUP_GAP) - GROUP_GAP, packH = Math.max(0, rows - 1) * rowPitch + col;

    host.className = 'result show';
    row(host, 'Architecture', `${series}S${parallel}P · ${total} cells`, true);
    row(host, 'Nominal / maximum voltage', `${fmt(nominal, 1)} V / ${fmt(series * 4.2, 1)} V`);
    row(host, 'Required current', `${fmt(required, 1)} A${P ? ' · ' + fmt(P, 0) + ' W target' : ''}`);
    row(host, 'Per-cell current / C-rate', `${fmt(cellCurrent, 2)} A · ${fmt(crate, 2)} C`, cellCurrent <= ca);
    row(host, 'Pack capacity / energy', `${fmt(capacity, 1)} Ah / ${fmt(wh, 0)} Wh${spaceLimited ? ' (space-limited, below target)' : ''}`);
    row(host, 'Cell current margin', `${fmt(parallel * ca, 1)} A pack capability (cell datasheet limit)`, cellCurrent <= ca);
    row(host, 'String layout', `${perRow} × ${rows} cells per string (${honey ? 'honeycomb' : 'grid'} pitch: ${fmt(col, 1)} × ${fmt(rowPitch, 1)} mm)`);
    row(host, 'Layout envelope (cell centers)', '≈ ' + fmt(packW, 0) + ' × ' + fmt(packH, 0) + ' mm; cell length ' + fmt(len, 1) + ' mm');
    if (pos(maxW) && pos(maxH)) {
      if (geomImpossible) row(host, 'Enclosure check', `Too small to fit ${series} series string(s) at this cell diameter — widen the enclosure or reduce the pack voltage.`, false);
      else if (spaceLimited) row(host, 'Enclosure check', `Space-limited to ${parallel}P — the target needs ${requiredParallel}P. Grow the enclosure to ≈${fmt(minHNeeded, 0)} mm tall at this width, or accept ${fmt(capacity, 1)} Ah / ${fmt(wh, 0)} Wh.`, false);
      else row(host, 'Enclosure check', `Fits, with ${geom.perRow * geom.rows - parallel} cell slot(s) of headroom in this footprint.`, true);
    }
    if (pos(massG)) { const massKg = total * massG / 1000; row(host, 'Estimated pack mass', `${fmt(massKg, 2)} kg (${fmt(massG, 1)} g/cell × ${total} cells, cells only)`); row(host, 'Energy density (cells only)', `${fmt(wh / massKg, 0)} Wh/kg`); }
    row(host, 'Safety note', 'Use a BMS/fusing and verify all real cell, strip, thermal, and enclosure limits.');
    drawLayout(series, parallel, perRow, rows, d, honey, len, maxW, maxH);
  };
  document.addEventListener('DOMContentLoaded',()=>{if(!$('sec-battery-build'))return; window.calcNickelStrip(); window.calc18650Pack();});
}());
