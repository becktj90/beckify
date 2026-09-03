/**
 * Beckify Battery Pack Designer — visual S/P cell layout for e-bike packs.
 * Paint cells into series groups, hit a parallel target, and read pack stats.
 * Planning aid only — not a build approval, BMS design, or thermal model.
 */
(function (global) {
  'use strict';

  const MAX_S = 24;
  const MAX_DIM = 28;
  const GROUP_HUES = [
    195, 265, 145, 25, 310, 55, 230, 175, 0, 90,
    340, 205, 120, 40, 280, 160, 15, 245, 70, 295,
    185, 105, 330, 215,
  ];

  const CELL_PRESETS = {
    '18650': { v: 3.6, ah: 2.5, a: 20, d: 18.5, label: '18650 · 2.5 Ah / 20 A' },
    '21700': { v: 3.6, ah: 4.0, a: 15, d: 21.2, label: '21700 · 4.0 Ah / 15 A' },
    custom: { v: 3.6, ah: 3.0, a: 10, d: 18.5, label: 'Custom' },
  };

  const PACK_PRESETS = {
    '36v': { s: 10, p: 10, label: '36 V · 10S10P' },
    '48v': { s: 13, p: 8, label: '48 V · 13S8P' },
    '52v': { s: 14, p: 10, label: '52 V · 14S10P' },
    '72v': { s: 20, p: 10, label: '72 V · 20S10P' },
  };

  function clampInt(value, min, max, fallback) {
    const n = Math.round(Number(value));
    if (!Number.isFinite(n)) return fallback;
    return Math.max(min, Math.min(max, n));
  }

  function pos(value) {
    return Number.isFinite(value) && value > 0;
  }

  function fmt(value, digits) {
    if (!Number.isFinite(value)) return '—';
    return Number(value).toLocaleString('en-US', { maximumFractionDigits: digits == null ? 2 : digits });
  }

  function groupHue(group) {
    return GROUP_HUES[(Math.max(1, group) - 1) % GROUP_HUES.length];
  }

  function emptyGrid(cols, rows) {
    const grid = new Array(rows);
    for (let r = 0; r < rows; r += 1) {
      grid[r] = new Array(cols).fill(0);
    }
    return grid;
  }

  function countGroups(grid, targetS) {
    const counts = new Array(Math.max(1, targetS) + 1).fill(0);
    let filled = 0;
    for (let r = 0; r < grid.length; r += 1) {
      for (let c = 0; c < grid[r].length; c += 1) {
        const g = grid[r][c] | 0;
        if (g > 0) {
          filled += 1;
          if (g < counts.length) counts[g] += 1;
        }
      }
    }
    return { counts: counts, filled: filled };
  }

  function analyzeLayout(grid, opts) {
    const targetS = clampInt(opts.targetS, 1, MAX_S, 14);
    const targetP = clampInt(opts.targetP, 1, 80, 10);
    const cellV = Number(opts.cellV);
    const cellAh = Number(opts.cellAh);
    const cellA = Number(opts.cellA);
    const loadA = Number(opts.loadA) || 0;
    const { counts, filled } = countGroups(grid, targetS);

    const usedGroups = [];
    for (let g = 1; g <= targetS; g += 1) {
      if (counts[g] > 0) usedGroups.push(g);
    }

    const parallelValues = usedGroups.map((g) => counts[g]);
    const minP = parallelValues.length ? Math.min.apply(null, parallelValues) : 0;
    const maxP = parallelValues.length ? Math.max.apply(null, parallelValues) : 0;
    const balanced = usedGroups.length > 0 && minP === maxP;
    const series = usedGroups.length;
    const parallel = balanced ? minP : 0;
    const exactTarget = balanced && series === targetS && parallel === targetP;
    const missingGroups = [];
    for (let g = 1; g <= targetS; g += 1) {
      if (counts[g] !== targetP) missingGroups.push({ group: g, have: counts[g], need: targetP });
    }

    const nominalV = series > 0 && balanced ? series * cellV : NaN;
    const capacityAh = balanced && parallel > 0 ? parallel * cellAh : NaN;
    const energyWh = pos(nominalV) && pos(capacityAh) ? nominalV * capacityAh : NaN;
    const packContinuousA = balanced && parallel > 0 && pos(cellA) ? parallel * cellA : NaN;
    const perCellLoadA = balanced && parallel > 0 && loadA > 0 ? loadA / parallel : NaN;
    const crate = pos(perCellLoadA) && pos(cellAh) ? perCellLoadA / cellAh : NaN;

    return {
      targetS: targetS,
      targetP: targetP,
      filled: filled,
      counts: counts.slice(1, targetS + 1),
      usedGroups: usedGroups,
      series: series,
      parallel: parallel,
      balanced: balanced,
      exactTarget: exactTarget,
      minP: minP,
      maxP: maxP,
      missingGroups: missingGroups,
      architecture: balanced && series > 0 ? series + 'S' + parallel + 'P' : 'unbalanced',
      nominalV: nominalV,
      maxV: series > 0 && balanced ? series * 4.2 : NaN,
      capacityAh: capacityAh,
      energyWh: energyWh,
      packContinuousA: packContinuousA,
      perCellLoadA: perCellLoadA,
      crate: crate,
      loadOk: !pos(perCellLoadA) || !pos(cellA) || perCellLoadA <= cellA,
    };
  }

  /**
   * Place series groups as adjacent columns. Each group is a vertical strip
   * of `targetP` cells (wrapping to the next column of that group when needed).
   */
  function autoFillColumns(cols, rows, targetS, targetP) {
    const grid = emptyGrid(cols, rows);
    const slots = cols * rows;
    const needed = targetS * targetP;
    if (needed > slots) {
      return { grid: grid, error: 'Need at least ' + needed + ' slots for ' + targetS + 'S' + targetP + 'P on a ' + cols + '×' + rows + ' canvas.' };
    }
    let index = 0;
    for (let g = 1; g <= targetS; g += 1) {
      for (let n = 0; n < targetP; n += 1) {
        const r = Math.floor(index / cols);
        const c = index % cols;
        grid[r][c] = g;
        index += 1;
      }
    }
    return { grid: grid, error: null };
  }

  function pitch(diameter, honeycomb) {
    const col = diameter + 3;
    return { col: col, row: honeycomb ? col * 0.8660254 : col };
  }

  function cellCenter(col, row, diameter, honeycomb, originX, originY) {
    const p = pitch(diameter, honeycomb);
    const offset = honeycomb && (row % 2) ? p.col / 2 : 0;
    return {
      x: originX + col * p.col + offset,
      y: originY + row * p.row,
      radius: diameter * 0.42,
      colPitch: p.col,
      rowPitch: p.row,
    };
  }

  function hitTest(grid, x, y, diameter, honeycomb, originX, originY) {
    let best = null;
    let bestDist = Infinity;
    for (let r = 0; r < grid.length; r += 1) {
      for (let c = 0; c < grid[r].length; c += 1) {
        const pt = cellCenter(c, r, diameter, honeycomb, originX, originY);
        const dx = x - pt.x;
        const dy = y - pt.y;
        const d2 = dx * dx + dy * dy;
        const hitR = pt.radius * 1.15;
        if (d2 <= hitR * hitR && d2 < bestDist) {
          bestDist = d2;
          best = { row: r, col: c };
        }
      }
    }
    return best;
  }

  /* ── DOM wiring ─────────────────────────────────────────────────────────── */

  function $(id) {
    return document.getElementById(id);
  }

  function num(id) {
    return Number($(id) && $(id).value);
  }

  const state = {
    grid: emptyGrid(16, 12),
    cols: 16,
    rows: 12,
    mode: 'paint',
    activeGroup: 1,
    painting: false,
    pointerId: null,
    lastCell: null,
  };

  function readOpts() {
    return {
      targetS: clampInt(num('ebd_target_s'), 1, MAX_S, 14),
      targetP: clampInt(num('ebd_target_p'), 1, 80, 10),
      cellV: num('ebd_cell_v'),
      cellAh: num('ebd_cell_ah'),
      cellA: num('ebd_cell_a'),
      cellD: num('ebd_cell_d') || 18.5,
      loadA: num('ebd_load_a'),
      honeycomb: ($('ebd_pattern') && $('ebd_pattern').value) === 'honeycomb',
    };
  }

  function resizeGrid(cols, rows) {
    const next = emptyGrid(cols, rows);
    for (let r = 0; r < Math.min(rows, state.grid.length); r += 1) {
      for (let c = 0; c < Math.min(cols, state.grid[r].length); c += 1) {
        next[r][c] = state.grid[r][c];
      }
    }
    state.cols = cols;
    state.rows = rows;
    state.grid = next;
  }

  function syncGroupSelect(targetS) {
    const sel = $('ebd_active_group');
    if (!sel) return;
    const current = clampInt(sel.value, 1, targetS, state.activeGroup);
    sel.replaceChildren();
    for (let g = 1; g <= targetS; g += 1) {
      const opt = document.createElement('option');
      opt.value = String(g);
      opt.textContent = 'Group S' + g;
      sel.append(opt);
    }
    sel.value = String(Math.min(current, targetS));
    state.activeGroup = Number(sel.value);
  }

  function setMode(mode) {
    state.mode = mode === 'erase' ? 'erase' : 'paint';
    const paintBtn = $('ebd_mode_paint');
    const eraseBtn = $('ebd_mode_erase');
    if (paintBtn) paintBtn.classList.toggle('active', state.mode === 'paint');
    if (eraseBtn) eraseBtn.classList.toggle('active', state.mode === 'erase');
    const canvas = $('ebd_canvas');
    if (canvas) canvas.dataset.mode = state.mode;
  }

  function applyCell(row, col) {
    if (row < 0 || col < 0 || row >= state.rows || col >= state.cols) return false;
    const key = row + ',' + col;
    if (state.lastCell === key) return false;
    state.lastCell = key;
    const next = state.mode === 'erase' ? 0 : state.activeGroup;
    if (state.grid[row][col] === next) return false;
    state.grid[row][col] = next;
    return true;
  }

  function renderStats(analysis) {
    const host = $('ebd_result');
    if (!host) return;
    host.textContent = '';
    host.className = 'result show';

    function row(label, value, ok) {
      const e = document.createElement('div');
      e.className = 'res-row';
      const l = document.createElement('span');
      l.className = 'res-label';
      l.textContent = label;
      const v = document.createElement('span');
      v.className = 'res-val';
      v.textContent = value;
      if (ok === true) {
        v.style.color = '#6ee7b7';
        v.style.fontWeight = '700';
      } else if (ok === false) {
        v.style.color = '#f87171';
        v.style.fontWeight = '700';
      }
      e.append(l, v);
      host.append(e);
    }

    row('Cells placed', String(analysis.filled));
    row(
      'Architecture',
      analysis.balanced ? analysis.architecture : 'Unbalanced (' + analysis.minP + '–' + analysis.maxP + 'P across ' + analysis.series + ' groups)',
      analysis.exactTarget
    );
    row('Target', analysis.targetS + 'S' + analysis.targetP + 'P', analysis.exactTarget);

    if (analysis.balanced && analysis.series > 0) {
      row('Nominal / max voltage', fmt(analysis.nominalV, 1) + ' V / ' + fmt(analysis.maxV, 1) + ' V', true);
      row('Capacity / energy', fmt(analysis.capacityAh, 1) + ' Ah / ' + fmt(analysis.energyWh, 0) + ' Wh', true);
      row('Pack continuous capability', fmt(analysis.packContinuousA, 1) + ' A', true);
      if (pos(analysis.perCellLoadA)) {
        row(
          'Per-cell load / C-rate',
          fmt(analysis.perCellLoadA, 2) + ' A · ' + fmt(analysis.crate, 2) + ' C',
          analysis.loadOk
        );
      }
    } else {
      row('Status', 'Every series group needs the same parallel count before voltage and capacity are meaningful.', false);
    }

    const balance = document.createElement('div');
    balance.className = 'ebd-group-bars';
    balance.setAttribute('aria-label', 'Cells per series group');
    analysis.counts.forEach((count, idx) => {
      const g = idx + 1;
      const chip = document.createElement('div');
      chip.className = 'ebd-group-chip' + (count === analysis.targetP ? ' is-ok' : '');
      chip.style.setProperty('--ebd-hue', String(groupHue(g)));
      chip.innerHTML = '<strong>S' + g + '</strong><span>' + count + ' / ' + analysis.targetP + '</span>';
      balance.append(chip);
    });
    host.append(balance);
  }

  function drawCanvas() {
    const canvas = $('ebd_canvas');
    if (!canvas || !canvas.getContext) return;
    const opts = readOpts();
    const diameter = Math.max(10, opts.cellD || 18.5);
    const honeycomb = opts.honeycomb;
    const p = pitch(diameter, honeycomb);
    const pad = 18;
    const width = Math.ceil(pad * 2 + (state.cols - 1) * p.col + p.col + (honeycomb ? p.col / 2 : 0));
    const height = Math.ceil(pad * 2 + (state.rows - 1) * p.row + p.col);
    const dpr = Math.min(2, global.devicePixelRatio || 1);

    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    canvas.style.width = width + 'px';
    canvas.style.height = height + 'px';

    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, width, height);
    ctx.fillStyle = '#0b0f1a';
    ctx.fillRect(0, 0, width, height);

    const originX = pad + p.col / 2;
    const originY = pad + p.col / 2;

    for (let r = 0; r < state.rows; r += 1) {
      for (let c = 0; c < state.cols; c += 1) {
        const group = state.grid[r][c] | 0;
        const pt = cellCenter(c, r, diameter, honeycomb, originX, originY);
        ctx.beginPath();
        ctx.arc(pt.x, pt.y, pt.radius, 0, Math.PI * 2);
        if (group > 0) {
          ctx.fillStyle = 'hsl(' + groupHue(group) + ' 62% 38%)';
          ctx.fill();
          ctx.lineWidth = 1.4;
          ctx.strokeStyle = 'rgba(238,240,250,0.85)';
          ctx.stroke();
          ctx.fillStyle = '#fff';
          ctx.font = '600 10px Space Grotesk, JetBrains Mono, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'middle';
          ctx.fillText(String(group), pt.x, pt.y + 0.5);
        } else {
          ctx.fillStyle = 'rgba(255,255,255,0.035)';
          ctx.fill();
          ctx.lineWidth = 1;
          ctx.strokeStyle = 'rgba(148,151,184,0.35)';
          ctx.stroke();
        }
      }
    }

    canvas._ebdOrigin = { x: originX, y: originY, diameter: diameter, honeycomb: honeycomb };
  }

  function refresh() {
    const opts = readOpts();
    syncGroupSelect(opts.targetS);
    const analysis = analyzeLayout(state.grid, opts);
    renderStats(analysis);
    drawCanvas();
    const status = $('ebd_status');
    if (status) {
      status.textContent = analysis.exactTarget
        ? 'Target met: ' + analysis.architecture + '.'
        : analysis.balanced
          ? 'Balanced ' + analysis.architecture + ' — adjust groups to hit ' + opts.targetS + 'S' + opts.targetP + 'P.'
          : 'Paint cells into series groups until each group reaches ' + opts.targetP + ' parallel cells.';
    }
  }

  function pointerToCell(event) {
    const canvas = $('ebd_canvas');
    if (!canvas || !canvas._ebdOrigin) return null;
    const rect = canvas.getBoundingClientRect();
    if (!(rect.width > 0) || !(rect.height > 0)) return null;
    const cssW = parseFloat(canvas.style.width) || rect.width;
    const cssH = parseFloat(canvas.style.height) || rect.height;
    const px = ((event.clientX - rect.left) / rect.width) * cssW;
    const py = ((event.clientY - rect.top) / rect.height) * cssH;
    const o = canvas._ebdOrigin;
    return hitTest(state.grid, px, py, o.diameter, o.honeycomb, o.x, o.y);
  }

  function onPointerDown(event) {
    const canvas = $('ebd_canvas');
    if (!canvas || event.button === 2) return;
    event.preventDefault();
    state.painting = true;
    state.pointerId = event.pointerId;
    state.lastCell = null;
    try { canvas.setPointerCapture(event.pointerId); } catch (_) {}
    const hit = pointerToCell(event);
    if (hit && applyCell(hit.row, hit.col)) refresh();
  }

  function onPointerMove(event) {
    if (!state.painting || event.pointerId !== state.pointerId) return;
    const hit = pointerToCell(event);
    if (hit && applyCell(hit.row, hit.col)) refresh();
  }

  function onPointerUp(event) {
    if (event.pointerId !== state.pointerId) return;
    state.painting = false;
    state.pointerId = null;
    state.lastCell = null;
    const canvas = $('ebd_canvas');
    if (canvas && canvas.hasPointerCapture && canvas.hasPointerCapture(event.pointerId)) {
      try { canvas.releasePointerCapture(event.pointerId); } catch (_) {}
    }
  }

  function applyPackPreset(key) {
    const preset = PACK_PRESETS[key];
    if (!preset) return;
    if ($('ebd_target_s')) $('ebd_target_s').value = String(preset.s);
    if ($('ebd_target_p')) $('ebd_target_p').value = String(preset.p);
    const cols = clampInt(num('ebd_cols'), 4, MAX_DIM, 16);
    const rows = clampInt(num('ebd_rows'), 4, MAX_DIM, 12);
    const needed = preset.s * preset.p;
    let nextCols = cols;
    let nextRows = rows;
    if (needed > cols * rows) {
      nextCols = Math.min(MAX_DIM, Math.max(cols, Math.ceil(Math.sqrt(needed * 1.2))));
      nextRows = Math.min(MAX_DIM, Math.max(rows, Math.ceil(needed / nextCols)));
      if ($('ebd_cols')) $('ebd_cols').value = String(nextCols);
      if ($('ebd_rows')) $('ebd_rows').value = String(nextRows);
    }
    resizeGrid(nextCols, nextRows);
    const filled = autoFillColumns(state.cols, state.rows, preset.s, preset.p);
    if (filled.error) {
      const status = $('ebd_status');
      if (status) status.textContent = filled.error;
      return;
    }
    state.grid = filled.grid;
    state.activeGroup = 1;
    setMode('paint');
    refresh();
  }

  function applyCellPreset(key) {
    const preset = CELL_PRESETS[key];
    if (!preset || key === 'custom') return;
    if ($('ebd_cell_v')) $('ebd_cell_v').value = String(preset.v);
    if ($('ebd_cell_ah')) $('ebd_cell_ah').value = String(preset.ah);
    if ($('ebd_cell_a')) $('ebd_cell_a').value = String(preset.a);
    if ($('ebd_cell_d')) $('ebd_cell_d').value = String(preset.d);
    refresh();
  }

  function wire() {
    if (!$('ebd_canvas')) return;

    ['ebd_target_s', 'ebd_target_p', 'ebd_cell_v', 'ebd_cell_ah', 'ebd_cell_a', 'ebd_cell_d', 'ebd_load_a', 'ebd_pattern']
      .forEach((id) => {
        const el = $(id);
        if (el) el.addEventListener('input', refresh);
        if (el) el.addEventListener('change', refresh);
      });

    ['ebd_cols', 'ebd_rows'].forEach((id) => {
      const el = $(id);
      if (!el) return;
      el.addEventListener('change', () => {
        const cols = clampInt(num('ebd_cols'), 4, MAX_DIM, state.cols);
        const rows = clampInt(num('ebd_rows'), 4, MAX_DIM, state.rows);
        el.value = String(id === 'ebd_cols' ? cols : rows);
        if ($('ebd_cols')) $('ebd_cols').value = String(cols);
        if ($('ebd_rows')) $('ebd_rows').value = String(rows);
        resizeGrid(cols, rows);
        refresh();
      });
    });

    const groupSel = $('ebd_active_group');
    if (groupSel) {
      groupSel.addEventListener('change', () => {
        state.activeGroup = clampInt(groupSel.value, 1, MAX_S, 1);
        setMode('paint');
      });
    }

    if ($('ebd_mode_paint')) $('ebd_mode_paint').addEventListener('click', () => setMode('paint'));
    if ($('ebd_mode_erase')) $('ebd_mode_erase').addEventListener('click', () => setMode('erase'));

    if ($('ebd_autofill')) {
      $('ebd_autofill').addEventListener('click', () => {
        const opts = readOpts();
        const filled = autoFillColumns(state.cols, state.rows, opts.targetS, opts.targetP);
        if (filled.error) {
          const status = $('ebd_status');
          if (status) status.textContent = filled.error;
          return;
        }
        state.grid = filled.grid;
        refresh();
      });
    }

    if ($('ebd_clear')) {
      $('ebd_clear').addEventListener('click', () => {
        state.grid = emptyGrid(state.cols, state.rows);
        refresh();
      });
    }

    const packPreset = $('ebd_pack_preset');
    if (packPreset) {
      packPreset.addEventListener('change', () => {
        if (packPreset.value) applyPackPreset(packPreset.value);
      });
    }

    const cellPreset = $('ebd_cell_preset');
    if (cellPreset) {
      cellPreset.addEventListener('change', () => applyCellPreset(cellPreset.value));
    }

    const canvas = $('ebd_canvas');
    canvas.addEventListener('pointerdown', onPointerDown);
    canvas.addEventListener('pointermove', onPointerMove);
    canvas.addEventListener('pointerup', onPointerUp);
    canvas.addEventListener('pointercancel', onPointerUp);
    canvas.addEventListener('lostpointercapture', () => {
      state.painting = false;
      state.pointerId = null;
      state.lastCell = null;
    });
    canvas.addEventListener('contextmenu', (event) => event.preventDefault());

    document.addEventListener('keydown', (event) => {
      const section = $('sec-ebike-tools');
      if (!section || !section.classList.contains('active')) return;
      const tag = (event.target && event.target.tagName) || '';
      if (/INPUT|TEXTAREA|SELECT/.test(tag)) return;
      if (event.key === 'e' || event.key === 'E') {
        setMode('erase');
        return;
      }
      if (event.key === 'p' || event.key === 'P') {
        setMode('paint');
        return;
      }
      const digit = Number(event.key);
      if (digit >= 1 && digit <= 9) {
        const opts = readOpts();
        if (digit <= opts.targetS && $('ebd_active_group')) {
          $('ebd_active_group').value = String(digit);
          state.activeGroup = digit;
          setMode('paint');
        }
      }
    });

    // Seed a useful 52 V starter layout so the canvas is not an empty grid.
    if ($('ebd_pack_preset')) $('ebd_pack_preset').value = '52v';
    if ($('ebd_cell_preset')) $('ebd_cell_preset').value = '18650';
    applyCellPreset('18650');
    applyPackPreset('52v');
    setMode('paint');
  }

  global.__ebikeBatteryDesignerTestApi = {
    analyzeLayout: analyzeLayout,
    autoFillColumns: autoFillColumns,
    emptyGrid: emptyGrid,
    hitTest: hitTest,
    cellCenter: cellCenter,
    countGroups: countGroups,
    CELL_PRESETS: CELL_PRESETS,
    PACK_PRESETS: PACK_PRESETS,
    MAX_S: MAX_S,
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', wire);
  } else {
    wire();
  }
}(typeof window !== 'undefined' ? window : globalThis));
