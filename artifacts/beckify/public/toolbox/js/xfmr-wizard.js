/* ============================================================================
   TRANSFORMER DESIGN WIZARD
   Comprehensive step-by-step transformer selection, protection, conductor
   sizing, and single-line diagram generator.
   NEC 450, 310.16, 250.122, 250.30, 240, Chapter 9
   ============================================================================ */

(function () {
  'use strict';

  /* ── Standard kVA Sizes ── */
  const XFMR_KVA_3PH = [3, 6, 9, 15, 30, 37.5, 45, 75, 112.5, 150, 225, 300, 500, 750, 1000, 1500, 2000, 2500, 3000, 3750, 4000];
  const XFMR_KVA_1PH = [1, 2, 3, 5, 7.5, 10, 15, 25, 37.5, 50, 75, 100, 167, 250, 333, 500];

  /* ── Transformer Types ── */
  const XFMR_TYPES = [
    {
      id: 'dry-vent',
      name: 'Dry-Type Ventilated (AA)',
      short: 'Dry Ventilated',
      context: 'Most common type for commercial/industrial indoor use. Relies on natural air convection for cooling. No oil, no special containment required. Typical 150°C or 220°C insulation class. ANSI/NEMA ST-20 compliant.',
      pros: ['No oil — no spill risk', 'Indoor installations', 'Low maintenance', 'Lower weight than liquid', 'Self-extinguishing insulation available'],
      cons: ['Lower efficiency than liquid at large kVA', 'Not suitable for outdoor (weather) use without enclosure', 'Audible hum', 'Limited to ~500 kVA for single-phase, ~5 MVA three-phase'],
      nec: 'NEC 450.21–450.27 — dry-type transformers over 112.5 kVA require a vault or approved location. Indoor transformer rooms must comply with 450.26.',
      maxKva: 4000,
      envs: ['indoor', 'industrial', 'commercial'],
      tempRise: [80, 115, 150],
      insulClass: ['220°C (H)', '185°C (N)', '150°C (F)', '130°C (B)'],
      typical: 'Office buildings, schools, hospitals, industrial plants, data centers',
    },
    {
      id: 'dry-encap',
      name: 'Dry-Type Encapsulated / Cast Coil',
      short: 'Cast Coil',
      context: 'Windings fully encapsulated in epoxy resin. Extremely robust against moisture, dust, chemicals, and vibration. Class F or H insulation. Higher cost than standard dry-type.',
      pros: ['Moisture and dust proof', 'Chemical resistant', 'No fire hazard', 'Suitable for harsh environments', 'Very low audible noise'],
      cons: ['Higher initial cost', 'Heavier than ventilated', 'Difficult to repair if winding fails', 'Lead times can be long'],
      nec: 'NEC 450.22 — ventilation not required for sealed/non-ventilated type. Still subject to separation and clearance requirements.',
      maxKva: 4000,
      envs: ['indoor', 'outdoor', 'coastal', 'industrial', 'harsh'],
      tempRise: [100, 125],
      insulClass: ['F (155°C)', 'H (180°C)'],
      typical: 'Marine, offshore, tunnels, chemical plants, food processing, wastewater treatment',
    },
    {
      id: 'liquid-mineral',
      name: 'Liquid-Filled (Mineral Oil)',
      short: 'Oil-Filled',
      context: 'Windings immersed in mineral oil for cooling and insulation. Most efficient at large kVA. Used extensively in utility distribution and large industrial facilities. Requires spill containment (oil containment pit) per NEC 450.27.',
      pros: ['Highest efficiency', 'Best for large kVA (>1000 kVA)', 'Excellent thermal performance', 'Long service life (30–40 years)', 'Lower cost per kVA at large sizes'],
      cons: ['Oil fire hazard (flash point ~150°C)', 'Requires oil containment / berm', 'Periodic oil testing / maintenance', 'Not suitable for most indoor locations without a vault', 'Heavier than dry-type'],
      nec: 'NEC 450.27 — combustible liquids require separation from combustible materials. Less-flammable or non-combustible liquids (FR3, silicone) have relaxed placement requirements. Oil containment per 450.27.',
      maxKva: 4000,
      envs: ['outdoor', 'utility', 'substation', 'industrial'],
      tempRise: [55, 65],
      insulClass: ['Mineral oil (flash ~150°C)'],
      typical: 'Utility pad-mount substations, large industrial facilities, outdoor switchyards',
    },
    {
      id: 'liquid-fr3',
      name: 'Liquid-Filled (FR3 / Natural Ester)',
      short: 'FR3 / Bio-Oil',
      context: 'Uses vegetable-based FR3 fluid (flash point >300°C) instead of mineral oil. Classified as less-flammable per IEEE C57.155. Can be installed indoors in some jurisdictions without a vault. Biodegradable. Excellent choice when indoor liquid-filled is needed.',
      pros: ['Flash point >300°C — much safer than mineral oil', 'Biodegradable (ASTM D6866)', 'Can be used indoors per NEC 450.23', 'Better moisture tolerance', 'Higher efficiency than dry-type'],
      cons: ['Higher fluid cost than mineral oil', 'Still requires containment', 'Freezing point higher than mineral oil (gel point ~−20°C)', 'Less widely stocked'],
      nec: 'NEC 450.23 — less-flammable liquid-filled transformers may be installed indoors with listed containment. Flash point must be >300°C.',
      maxKva: 4000,
      envs: ['indoor', 'outdoor', 'industrial', 'substation'],
      tempRise: [55, 65],
      insulClass: ['FR3 fluid (flash >300°C)'],
      typical: 'Indoor substations, hospital main services, data center PDU transformers',
    },
  ];

  /* ── Winding Configurations ── */
  const XFMR_WINDING = [
    {
      id: 'delta-wye',
      name: 'Delta–Wye (Δ–Y)',
      priConn: 'delta', secConn: 'wye',
      context: 'Most common configuration for step-down transformers. Delta primary eliminates 3rd harmonic distortion from propagating upstream. Wye secondary provides a neutral for grounded distribution. 30° phase shift between primary and secondary (ANSI Std12N).',
      grounding: 'Secondary neutral solidly grounded per NEC 250.30',
      typical: '480V primary → 208/120V secondary; 13.8 kV → 480V',
      nec: 'NEC 250.30(A) — separately derived system grounding required at secondary',
    },
    {
      id: 'wye-delta',
      name: 'Wye–Delta (Y–Δ)',
      priConn: 'wye', secConn: 'delta',
      context: 'Common for step-up applications. Wye primary provides a neutral point for grounding on the primary side. Delta secondary has no neutral. Used in industrial motor drive systems where a neutral is not needed on secondary.',
      grounding: 'Primary neutral grounded; secondary delta — no neutral',
      typical: 'Generator step-up, industrial drives',
      nec: 'NEC 450.5 — zigzag grounding required if neutral needed on delta secondary',
    },
    {
      id: 'delta-delta',
      name: 'Delta–Delta (Δ–Δ)',
      priConn: 'delta', secConn: 'delta',
      context: 'No phase shift. Reliable — if one winding fails, can run open-delta at 57.7% capacity. No neutral on secondary. Less common in modern facilities due to grounding limitations.',
      grounding: 'No neutral on either side — grounding harder to achieve',
      typical: 'Industrial, mining, legacy systems',
      nec: 'NEC 250.30(A)(5) — if neutral required, derive via zigzag or additional winding',
    },
    {
      id: 'high-leg-delta',
      name: 'High-Leg Delta (Corner-Grounded)',
      priConn: 'delta', secConn: 'delta-wye',
      context: 'Three-phase 4-wire delta with center-tap on one winding grounded. Provides 120V for single-phase loads and 240V three-phase. The "high leg" (wild leg, stinger) is phase B at 208V to neutral — must be identified with orange color per NEC. Very common in older US commercial buildings.',
      grounding: 'Center-tap of one winding grounded. High leg = 208V to neutral',
      typical: 'Older US commercial — 240/120V 4-wire delta systems',
      nec: 'NEC 110.15, 230.56 — high leg must be identified with orange color. NEC 408.3(F) — high leg in panelboard must be on B phase (center position).',
    },
    {
      id: 'wye-wye',
      name: 'Wye–Wye (Y–Y)',
      priConn: 'wye', secConn: 'wye',
      context: 'Both sides have neutrals. Susceptible to 3rd harmonic issues unless a tertiary delta winding is added. Used in some utility applications with careful design. Rarely used alone in commercial/industrial without a delta tertiary.',
      grounding: 'Both neutrals can be grounded — requires tertiary delta for harmonic stability',
      typical: 'Utility transmission, large substations with tertiary delta',
      nec: 'NEC 250.30(A) — both neutrals require proper grounding',
    },
    {
      id: '1ph',
      name: 'Single-Phase',
      priConn: '1ph', secConn: '1ph',
      context: 'Single-phase transformer with two windings. Can be used for step-up, step-down, isolation, or autotransformer. Common for lighting panels, control power, HVAC, and residential distribution.',
      grounding: 'Secondary neutral grounded per NEC 250.30',
      typical: 'Residential, lighting panels, control power, HVAC',
      nec: 'NEC 250.30 — separately derived system requires grounding electrode at secondary',
    },
  ];

  /* Shared planning-allowance book from wire-tools.js. No second price table. */
  function wzPriceBook(materialKey) {
    const book = (typeof PLANNING_CONDUCTOR_PRICE_PER_FT !== 'undefined' && PLANNING_CONDUCTOR_PRICE_PER_FT)
      || (typeof window !== 'undefined' && window.PLANNING_CONDUCTOR_PRICE_PER_FT)
      || null;
    return (book && book[materialKey]) || {};
  }

  /* ── State ── */
  let WZ = {
    step: 1,
    phase: '3ph',
    priV: 480,
    secV: 208,
    kva: null,
    xfmrType: null,
    windingId: null,
    material: 'CU',
    insulation: 'THHN',
    conduitType: 'EMT',
    ambientC: 30,
    ccc: 3,
    pf: 0.85,
    priLen: 50,
    secLen: 75,
    distFt: null,
    loadKva: null,
    demand: 1.0,
  };

  /* ── Helper: next standard OCPD (from nec-data.js) ── */
  function wzNextOcpd(a) {
    return typeof nextStandardOCPD === 'function'
      ? nextStandardOCPD(a)
      : (typeof STD_OCPD_RATINGS !== 'undefined' && STD_OCPD_RATINGS.find(r => r >= a)) || null;
  }

  function wzMaterialKey(value) {
    return String(value || 'CU').toLowerCase() === 'al' ? 'al' : 'cu';
  }

  function wzInsulationTemp(value) {
    const type = typeof INSULATION_TYPES !== 'undefined' && INSULATION_TYPES[value];
    return type && Number(type.tempRating) || (value === 'THW' ? 75 : 90);
  }

  /* ── Next standard kVA ── */
  function wzNextKva(requiredKva, phase) {
    const arr = phase === '1ph' ? XFMR_KVA_1PH : XFMR_KVA_3PH;
    return arr.find(k => k >= requiredKva) || arr[arr.length - 1];
  }

  /* ── Parallel run cost optimizer ── */
  function parallelRunOptions(requiredAmps, material, _insulation, ambientC, ccc, terminationTemp, phase, connection) {
    const materialKey = wzMaterialKey(material);
    const costs = wzPriceBook(materialKey);
    const results = [];
    for (let runs = 1; runs <= 6; runs++) {
      const ampsPerRun = requiredAmps / runs;
      const cond = typeof xePickConductor === 'function'
        ? xePickConductor(ampsPerRun, materialKey, wzInsulationTemp(_insulation), terminationTemp, ambientC, ccc)
        : null;
      if (!cond) continue;
      const costPerFt = costs[cond.size] || 0;
      const conductorsPerRun = (phase === '1ph') ? 2 : (connection === 'delta' ? 3 : 4);
      const totalConductors = conductorsPerRun * runs;
      results.push({
        runs,
        size: cond.size,
        ampsPerRun,
        usableAmps: cond.usable * runs,
        costPerFt: (costPerFt * totalConductors).toFixed(2),
        cond,
      });
    }
    // Mark lowest cost
    let minCost = Infinity;
    results.forEach(r => { if (parseFloat(r.costPerFt) < minCost) minCost = parseFloat(r.costPerFt); });
    results.forEach(r => { r.optimal = parseFloat(r.costPerFt) === minCost; });
    return results;
  }

  /* ═══════════════════════════════════════════════════════════════════════════
     SVG TRANSFORMER GRAPHIC
     ═══════════════════════════════════════════════════════════════════════════ */
  function buildXfmrSvg(params) {
    const ns = 'http://www.w3.org/2000/svg';
    const W = 340, H = 220;
    const svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
    svg.setAttribute('width', '100%');
    svg.setAttribute('style', 'max-width:340px;background:#0d1117;border-radius:8px;display:block;margin:0 auto');

    function el(tag, attrs) {
      const e = document.createElementNS(ns, tag);
      Object.entries(attrs).forEach(([k, v]) => e.setAttribute(k, v));
      return e;
    }
    function text(content, x, y, attrs = {}) {
      const t = document.createElementNS(ns, 'text');
      t.textContent = content;
      t.setAttribute('x', x); t.setAttribute('y', y);
      t.setAttribute('fill', attrs.fill || '#94a3b8');
      t.setAttribute('font-size', attrs.size || '10');
      t.setAttribute('font-family', 'monospace');
      t.setAttribute('text-anchor', attrs.anchor || 'middle');
      if (attrs.weight) t.setAttribute('font-weight', attrs.weight);
      return t;
    }

    // Background panel
    svg.appendChild(el('rect', { x: 0, y: 0, width: W, height: H, fill: '#0d1117' }));
    svg.appendChild(el('rect', { x: 5, y: 5, width: W - 10, height: H - 10, fill: 'none', stroke: '#1e293b', 'stroke-width': 1, rx: 6 }));

    const isLiquid = params.type && params.type.startsWith('liquid');
    const priConn = params.priConn || 'delta';
    const secConn = params.secConn || 'wye';

    // Core (center rectangle)
    const cx = W / 2, cy = H / 2;
    svg.appendChild(el('rect', { x: cx - 25, y: cy - 55, width: 50, height: 110, fill: '#1e293b', stroke: '#8b7bff', 'stroke-width': 2, rx: 4 }));
    // Core lamination lines
    for (let i = -40; i <= 40; i += 10) {
      svg.appendChild(el('line', { x1: cx - 22, y1: cy + i, x2: cx + 22, y2: cy + i, stroke: '#334155', 'stroke-width': 1 }));
    }
    svg.appendChild(text('CORE', cx, cy + 4, { fill: '#64748b', size: '9' }));

    // Primary winding (left coils)
    const coilColor = '#8b7bff';
    const wx = 40, wy = cy - 30;
    for (let i = 0; i < 5; i++) {
      svg.appendChild(el('ellipse', { cx: wx, cy: wy + i * 14, rx: 20, ry: 7, fill: 'none', stroke: coilColor, 'stroke-width': 2.5 }));
    }

    // Secondary winding (right coils)
    const wx2 = W - 40;
    for (let i = 0; i < 5; i++) {
      svg.appendChild(el('ellipse', { cx: wx2, cy: wy + i * 14, rx: 20, ry: 7, fill: 'none', stroke: '#6ee7b7', 'stroke-width': 2.5 }));
    }

    // Primary leads
    svg.appendChild(el('line', { x1: wx - 20, y1: wy, x2: 10, y2: wy, stroke: '#8b7bff', 'stroke-width': 2 }));
    svg.appendChild(el('line', { x1: wx - 20, y1: wy + 56, x2: 10, y2: wy + 56, stroke: '#8b7bff', 'stroke-width': 2 }));
    // Secondary leads
    svg.appendChild(el('line', { x1: wx2 + 20, y1: wy, x2: W - 10, y2: wy, stroke: '#6ee7b7', 'stroke-width': 2 }));
    svg.appendChild(el('line', { x1: wx2 + 20, y1: wy + 56, x2: W - 10, y2: wy + 56, stroke: '#6ee7b7', 'stroke-width': 2 }));

    // Winding symbols
    function drawDelta(x, y, color) {
      const pts = `${x},${y - 12} ${x + 14},${y + 8} ${x - 14},${y + 8}`;
      svg.appendChild(el('polygon', { points: pts, fill: 'none', stroke: color, 'stroke-width': 2 }));
    }
    function drawWye(x, y, color) {
      svg.appendChild(el('line', { x1: x, y1: y - 10, x2: x, y2: y + 2, stroke: color, 'stroke-width': 2 }));
      svg.appendChild(el('line', { x1: x, y1: y + 2, x2: x - 9, y2: y + 10, stroke: color, 'stroke-width': 2 }));
      svg.appendChild(el('line', { x1: x, y1: y + 2, x2: x + 9, y2: y + 10, stroke: color, 'stroke-width': 2 }));
      svg.appendChild(el('circle', { cx: x, cy: y + 12, r: 3, fill: color }));
    }
    function draw1Ph(x, y, color) {
      svg.appendChild(el('line', { x1: x - 10, y1: y, x2: x + 10, y2: y, stroke: color, 'stroke-width': 2 }));
      svg.appendChild(el('line', { x1: x, y1: y - 10, x2: x, y2: y + 10, stroke: color, 'stroke-width': 2 }));
    }

    const priSym = { x: 15, y: cy + 65 };
    const secSym = { x: W - 15, y: cy + 65 };
    if (priConn === 'delta') drawDelta(priSym.x, priSym.y, '#8b7bff');
    else if (priConn === '1ph') draw1Ph(priSym.x, priSym.y, '#8b7bff');
    else drawWye(priSym.x, priSym.y, '#8b7bff');
    if (secConn === 'delta' || secConn === 'delta-wye') drawDelta(secSym.x, secSym.y, '#6ee7b7');
    else if (secConn === '1ph') draw1Ph(secSym.x, secSym.y, '#6ee7b7');
    else drawWye(secSym.x, secSym.y, '#6ee7b7');

    // Oil tank body if liquid type
    if (isLiquid) {
      svg.appendChild(el('rect', { x: 8, y: 30, width: W - 16, height: H - 60, fill: 'none', stroke: '#f5c451', 'stroke-width': 1.5, 'stroke-dasharray': '6 3', rx: 8 }));
      svg.appendChild(text('Oil Tank', cx, 44, { fill: '#f5c451', size: '9' }));
    }

    // Labels
    svg.appendChild(text('PRIMARY', 40, 18, { fill: '#8b7bff', size: '9', weight: 'bold' }));
    svg.appendChild(text(`${params.priV || '—'} V  ${params.phase === '1ph' ? '1Ø' : '3Ø'}`, 40, 28, { fill: '#94a3b8', size: '8' }));
    svg.appendChild(text('SECONDARY', W - 40, 18, { fill: '#6ee7b7', size: '9', weight: 'bold' }));
    svg.appendChild(text(`${params.secV || '—'} V`, W - 40, 28, { fill: '#94a3b8', size: '8' }));
    svg.appendChild(text(`${params.kva || '—'} kVA`, cx, 18, { fill: '#f5c451', size: '10', weight: 'bold' }));
    svg.appendChild(text(`${(params.typeName || '').slice(0, 20)}`, cx, 30, { fill: '#64748b', size: '8' }));
    svg.appendChild(text(`${params.winding || ''}`, cx, H - 8, { fill: '#64748b', size: '8' }));

    return svg;
  }

  /* ═══════════════════════════════════════════════════════════════════════════
     SVG SINGLE-LINE DIAGRAM
     ═══════════════════════════════════════════════════════════════════════════ */
  function buildSldSvg(params) {
    const ns = 'http://www.w3.org/2000/svg';
    const W = 720, H = 440;
    const svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
    svg.setAttribute('width', '100%');
    svg.setAttribute('style', 'max-width:720px;background:#0a0e17;border-radius:8px;display:block;margin:0 auto');

    const el = (tag, attrs) => {
      const e = document.createElementNS(ns, tag);
      Object.entries(attrs).forEach(([k, v]) => e.setAttribute(k, v));
      return e;
    };
    const line = (x1, y1, x2, y2, color = '#8b7bff', w = 2) =>
      el('line', { x1, y1, x2, y2, stroke: color, 'stroke-width': w });
    const rect = (x, y, w, h, fill, stroke, rx = 0) =>
      el('rect', { x, y, width: w, height: h, fill, stroke, 'stroke-width': 1.5, rx });
    const circle = (cx, cy, r, fill, stroke) =>
      el('circle', { cx, cy, r, fill, stroke, 'stroke-width': 1.5 });
    const txt = (content, x, y, fillC = '#94a3b8', size = 9, anchor = 'middle', weight = 'normal') => {
      const t = document.createElementNS(ns, 'text');
      t.textContent = content;
      ['x', 'y'].forEach((a, i) => t.setAttribute(a, [x, y][i]));
      t.setAttribute('fill', fillC); t.setAttribute('font-size', size);
      t.setAttribute('font-family', 'monospace'); t.setAttribute('text-anchor', anchor);
      t.setAttribute('font-weight', weight);
      return t;
    };

    // Background
    svg.appendChild(el('rect', { x: 0, y: 0, width: W, height: H, fill: '#0a0e17' }));
    svg.appendChild(txt('SINGLE-LINE DIAGRAM', W / 2, 20, '#8b7bff', 11, 'middle', 'bold'));

    const p = params;
    const midY = H / 2;

    /* ── Utility / Source (left) ── */
    const srcX = 30;
    svg.appendChild(circle(srcX, midY, 18, 'none', '#8b7bff'));
    svg.appendChild(txt('~', srcX, midY + 4, '#8b7bff', 14));
    svg.appendChild(txt('SOURCE', srcX, midY + 28, '#8b7bff', 8));
    svg.appendChild(txt(`${p.priV || '?'} V`, srcX, midY + 38, '#94a3b8', 8));
    svg.appendChild(txt(p.phase === '1ph' ? '1Ø' : '3Ø', srcX, midY + 48, '#94a3b8', 8));

    /* ── Primary disconnect (NEC 450.14) ── */
    const pdX = 120;
    svg.appendChild(line(srcX + 18, midY, pdX - 14, midY));
    // Disconnect symbol (box with switch)
    svg.appendChild(rect(pdX - 14, midY - 14, 28, 28, '#0f172a', '#8b7bff', 3));
    svg.appendChild(line(pdX - 6, midY + 8, pdX + 4, midY - 8, '#8b7bff', 2));
    svg.appendChild(txt('DISC', pdX, midY + 24, '#8b7bff', 8));
    svg.appendChild(txt('NEC 450.14', pdX, midY + 34, '#64748b', 7));
    svg.appendChild(txt(p.priDisc || '', pdX, midY + 44, '#f5c451', 7));

    /* ── Primary OCPD ── */
    const pocX = 210;
    svg.appendChild(line(pdX + 14, midY, pocX - 14, midY));
    svg.appendChild(rect(pocX - 14, midY - 14, 28, 28, '#0f172a', '#f5c451', 3));
    // Breaker zigzag
    svg.appendChild(el('polyline', {
      points: `${pocX - 6},${midY + 8} ${pocX},${midY} ${pocX - 4},${midY - 4} ${pocX + 6},${midY - 8}`,
      fill: 'none', stroke: '#f5c451', 'stroke-width': 2,
    }));
    svg.appendChild(txt('Pri OCPD', pocX, midY + 24, '#f5c451', 8));
    svg.appendChild(txt('NEC 450.3(B)', pocX, midY + 34, '#64748b', 7));
    svg.appendChild(txt(p.priOcpd ? p.priOcpd + ' A' : '', pocX, midY + 44, '#f5c451', 7));

    /* ── Primary conductor label ── */
    const priLineX = 295;
    svg.appendChild(line(pocX + 14, midY, priLineX, midY));
    // Phase lines visual (3 lines for 3ph)
    if (p.phase !== '1ph') {
      for (let i = -4; i <= 4; i += 4) {
        svg.appendChild(line(priLineX - 12, midY + i, priLineX + 12, midY + i, '#8b7bff', 1));
      }
    }
    const priLabel = p.priCond ? `${p.priCond.runs || 1}×${p.priCond.size} ${p.material || 'CU'} THHN` : '';
    svg.appendChild(txt(priLabel, (pocX + 14 + priLineX) / 2, midY - 10, '#6ee7b7', 8));
    const priVdLabel = p.priVd ? `Vd=${fmt(p.priVd.percent, 1)}%` : '';
    svg.appendChild(txt(priVdLabel, (pocX + 14 + priLineX) / 2, midY - 20, '#94a3b8', 7));

    /* ── Transformer symbol ── */
    const txX = 360;
    const txY = midY;
    // Two concentric circles for transformer symbol
    svg.appendChild(circle(txX - 16, txY, 22, 'none', '#8b7bff'));
    svg.appendChild(circle(txX + 16, txY, 22, 'none', '#6ee7b7'));
    svg.appendChild(txt(`${p.kva || '?'} kVA`, txX, txY - 30, '#f5c451', 9, 'middle', 'bold'));
    svg.appendChild(txt(p.typeName ? p.typeName.split(' ').slice(0, 2).join(' ') : '', txX, txY + 36, '#64748b', 7));
    svg.appendChild(txt(p.winding || '', txX, txY + 46, '#64748b', 7));
    svg.appendChild(txt(`${p.priV || '?'}V / ${p.secV || '?'}V`, txX, txY - 40, '#94a3b8', 7));

    /* ── Secondary conductor label ── */
    const secLineX = 450;
    svg.appendChild(line(txX + 38, midY, secLineX, midY));
    if (p.phase !== '1ph') {
      for (let i = -4; i <= 4; i += 4) {
        svg.appendChild(line(secLineX - 12, midY + i, secLineX + 12, midY + i, '#6ee7b7', 1));
      }
    }
    const secLabel = p.secCond ? `${p.secCond.runs || 1}×${p.secCond.size} ${p.material || 'CU'} THHN` : '';
    svg.appendChild(txt(secLabel, (txX + 38 + secLineX) / 2, midY - 10, '#6ee7b7', 8));
    const secVdLabel = p.secVd ? `Vd=${fmt(p.secVd.percent, 1)}%` : '';
    svg.appendChild(txt(secVdLabel, (txX + 38 + secLineX) / 2, midY - 20, '#94a3b8', 7));

    /* ── Secondary OCPD ── */
    const socX = 510;
    svg.appendChild(line(secLineX, midY, socX - 14, midY));
    svg.appendChild(rect(socX - 14, midY - 14, 28, 28, '#0f172a', '#f5c451', 3));
    svg.appendChild(el('polyline', {
      points: `${socX - 6},${midY + 8} ${socX},${midY} ${socX - 4},${midY - 4} ${socX + 6},${midY - 8}`,
      fill: 'none', stroke: '#f5c451', 'stroke-width': 2,
    }));
    svg.appendChild(txt('Sec OCPD', socX, midY + 24, '#f5c451', 8));
    svg.appendChild(txt('NEC 450.3(B)', socX, midY + 34, '#64748b', 7));
    svg.appendChild(txt(p.secOcpd ? p.secOcpd + ' A' : '', socX, midY + 44, '#f5c451', 7));

    /* ── Secondary panel / load ── */
    const panX = 620;
    svg.appendChild(line(socX + 14, midY, panX - 20, midY));
    svg.appendChild(rect(panX - 20, midY - 40, 40, 80, '#0f172a', '#6ee7b7', 4));
    // Bus bars
    for (let i = -20; i <= 20; i += 10) {
      svg.appendChild(line(panX - 10, midY + i, panX + 10, midY + i, '#6ee7b7', 1));
    }
    svg.appendChild(txt('PANEL', panX, midY + 52, '#6ee7b7', 8));
    svg.appendChild(txt(`${p.secV || '?'} V`, panX, midY + 62, '#94a3b8', 8));

    /* ── Ground symbol at secondary neutral ── */
    if (p.secConn !== 'delta') {
      const gx = panX, gy = midY + 50;
      // Grounding electrode conductor (GEC)
      svg.appendChild(line(panX, midY + 40, gx, gy + 5, '#6ee7b7', 1.5));
      svg.appendChild(line(gx - 12, gy + 5, gx + 12, gy + 5, '#6ee7b7', 2));
      svg.appendChild(line(gx - 8, gy + 9, gx + 8, gy + 9, '#6ee7b7', 1.5));
      svg.appendChild(line(gx - 4, gy + 13, gx + 4, gy + 13, '#6ee7b7', 1));
      svg.appendChild(txt('GEC', gx, gy + 24, '#94a3b8', 7));
      svg.appendChild(txt(p.gec ? p.gec + ' ' + (p.material || 'CU') : '', gx, gy + 33, '#6ee7b7', 7));
      svg.appendChild(txt('NEC 250.30(A)', gx, gy + 42, '#64748b', 7));
    }

    /* ── EGC label ── */
    if (p.egc) {
      svg.appendChild(txt(`EGC: ${p.egc} ${p.material || 'CU'} (NEC 250.122)`, W / 2, H - 20, '#94a3b8', 8));
    }

    /* ── Legend / notes ── */
    svg.appendChild(txt('▪ DISC = Disconnect (NEC 450.14, within sight ≤30 ft)', 15, H - 45, '#64748b', 7, 'start'));
    svg.appendChild(txt('▪ OCPD = Overcurrent Protective Device (NEC 450.3(B))', 15, H - 33, '#64748b', 7, 'start'));

    return svg;
  }

  /* ═══════════════════════════════════════════════════════════════════════════
     STEP NAVIGATION
     ═══════════════════════════════════════════════════════════════════════════ */
  window.xwStep = function (n) {
    for (let i = 1; i <= 4; i++) {
      const s = document.getElementById('xw-step-' + i);
      const t = document.getElementById('xw-tab-' + i);
      if (s) s.style.display = i === n ? '' : 'none';
      if (t) {
        t.classList.toggle('active', i === n);
        t.classList.toggle('tab-btn', true);
      }
    }
    WZ.step = n;
  };

  window.xwNext1 = function () {
    // Collect step-1 inputs
    const ph = document.getElementById('xw_phase');
    const priV = document.getElementById('xw_pri_v');
    const secV = document.getElementById('xw_sec_v');
    const loadKva = document.getElementById('xw_load_kva');
    const demand = document.getElementById('xw_demand');

    if (!ph || !priV || !secV) return;
    WZ.phase = ph.value;
    WZ.priV = parseFloat(priV.value) || 480;
    WZ.secV = parseFloat(secV.value) || 208;
    WZ.loadKva = parseFloat(loadKva && loadKva.value) || null;
    WZ.demand = parseFloat(demand && demand.value) || 1.0;

    if (!WZ.priV || !WZ.secV) {
      showError('xw_step1_err', 'Enter primary and secondary voltages.');
      return;
    }

    // Populate step-2 options
    _populateStep2();
    xwStep(2);
  };

  function _populateStep2() {
    const recKva = WZ.loadKva ? wzNextKva(WZ.loadKva * WZ.demand, WZ.phase) : null;
    const kvaArr = WZ.phase === '1ph' ? XFMR_KVA_1PH : XFMR_KVA_3PH;

    // kVA selector
    const kvaEl = document.getElementById('xw_kva');
    if (kvaEl) {
      kvaEl.innerHTML = '';
      kvaArr.forEach(k => {
        const opt = document.createElement('option');
        opt.value = k;
        opt.textContent = k + ' kVA' + (k === recKva ? ' ✓ Recommended' : '');
        if (k === recKva) opt.selected = true;
        kvaEl.appendChild(opt);
      });
    }

    // Type cards
    const typeDiv = document.getElementById('xw_type_cards');
    if (!typeDiv) return;
    typeDiv.textContent = '';
    XFMR_TYPES.forEach(t => {
      const card = document.createElement('div');
      card.className = 'xw-type-card';
      card.setAttribute('data-id', t.id);
      card.onclick = () => xwSelectType(t.id);

      const title = document.createElement('div');
      title.className = 'xw-type-title';
      title.textContent = t.name;
      card.appendChild(title);

      const ctx = document.createElement('div');
      ctx.className = 'xw-type-ctx';
      ctx.textContent = t.context;
      card.appendChild(ctx);

      const ul = document.createElement('ul');
      ul.className = 'xw-pros';
      t.pros.slice(0, 3).forEach(p => {
        const li = document.createElement('li'); li.textContent = '✓ ' + p; ul.appendChild(li);
      });
      card.appendChild(ul);

      const necNote = document.createElement('div');
      necNote.className = 'xw-nec-note';
      necNote.textContent = t.nec;
      card.appendChild(necNote);

      typeDiv.appendChild(card);
    });

    // Winding cards
    const windDiv = document.getElementById('xw_winding_cards');
    if (!windDiv) return;
    windDiv.textContent = '';
    const validWindings = WZ.phase === '1ph'
      ? XFMR_WINDING.filter(w => w.id === '1ph')
      : XFMR_WINDING.filter(w => w.id !== '1ph');
    validWindings.forEach(w => {
      const card = document.createElement('div');
      card.className = 'xw-type-card';
      card.setAttribute('data-wid', w.id);
      card.onclick = () => xwSelectWinding(w.id);

      const title = document.createElement('div');
      title.className = 'xw-type-title';
      title.textContent = w.name;
      card.appendChild(title);

      const ctx = document.createElement('div');
      ctx.className = 'xw-type-ctx';
      ctx.textContent = w.context;
      card.appendChild(ctx);

      const grnd = document.createElement('div');
      grnd.className = 'xw-nec-note';
      grnd.textContent = '⚡ ' + w.grounding + ' | ' + w.nec;
      card.appendChild(grnd);

      windDiv.appendChild(card);
    });

    // Pre-select first winding if 1ph
    if (WZ.phase === '1ph') xwSelectWinding('1ph');
  }

  window.xwSelectType = function (id) {
    document.querySelectorAll('[data-id]').forEach(c => c.classList.remove('selected'));
    document.querySelectorAll(`[data-id="${id}"]`).forEach(c => c.classList.add('selected'));
    WZ.xfmrType = id;
  };

  window.xwSelectWinding = function (id) {
    document.querySelectorAll('[data-wid]').forEach(c => c.classList.remove('selected'));
    document.querySelectorAll(`[data-wid="${id}"]`).forEach(c => c.classList.add('selected'));
    WZ.windingId = id;
  };

  window.xwNext2 = function () {
    const kvaEl = document.getElementById('xw_kva');
    if (kvaEl) WZ.kva = parseFloat(kvaEl.value);
    if (!WZ.kva) return showError('xw_step2_err', 'Select a kVA rating.');
    if (!WZ.xfmrType) return showError('xw_step2_err', 'Select a transformer type.');
    if (!WZ.windingId) return showError('xw_step2_err', 'Select a winding configuration.');
    xwStep(3);
  };

  window.xwNext3 = function () {
    const ids = ['xw_material', 'xw_insulation', 'xw_conduit', 'xw_ambient', 'xw_ccc', 'xw_pf', 'xw_pri_len', 'xw_sec_len', 'xw_term'];
    const fields = {};
    ids.forEach(id => {
      const el = document.getElementById(id);
      if (el) fields[id] = el.value;
    });
    WZ.material = fields.xw_material || 'CU';
    WZ.insulation = fields.xw_insulation || 'THHN';
    WZ.conduitType = fields.xw_conduit || 'EMT';
    WZ.ambientC = parseFloat(fields.xw_ambient) || 30;
    WZ.ccc = parseInt(fields.xw_ccc) || 3;
    const pfRaw = parseFloat(fields.xw_pf);
    WZ.pf = isNaN(pfRaw) ? 0.85 : (pfRaw > 1 ? pfRaw / 100 : pfRaw);
    WZ.priLen = parseFloat(fields.xw_pri_len) || 50;
    WZ.secLen = parseFloat(fields.xw_sec_len) || 75;
    WZ.terminationTemp = parseInt(fields.xw_term) || 75;
    window.runXfmrWizard();
  };

  window.xwBack = function (n) { xwStep(n); };

  /* ═══════════════════════════════════════════════════════════════════════════
     MAIN CALCULATION
     ═══════════════════════════════════════════════════════════════════════════ */
  window.runXfmrWizard = function () {
    const resultEl = document.getElementById('xw_result');
    const sldEl = document.getElementById('xw_sld');
    const xfmrSvgEl = document.getElementById('xw_xfmr_svg');
    if (!resultEl) return;
    resultEl.textContent = '';

    const kva = WZ.kva;
    const phase = WZ.phase;
    const priV = WZ.priV;
    const secV = WZ.secV;
    const material = wzMaterialKey(WZ.material);
    const ambientC = WZ.ambientC;
    const ccc = WZ.ccc;
    const pf = WZ.pf;
    const priLen = WZ.priLen;
    const secLen = WZ.secLen;
    const termTemp = WZ.terminationTemp || 75;

    const typeObj = XFMR_TYPES.find(t => t.id === WZ.xfmrType);
    const windObj = XFMR_WINDING.find(w => w.id === WZ.windingId);
    const priConn = windObj ? windObj.priConn : 'delta';
    const secConn = windObj ? windObj.secConn : 'wye';

    /* ── FLA ── */
    const priFla = xeFla(kva, priV, phase);
    const secFla = xeFla(kva, secV, phase);

    /* ── OCPD per NEC 450.3(B) ── */
    // Primary-only protection (no separate secondary device)
    const priTier = typeof xfmrPrimaryOnlyLimit === 'function' ? xfmrPrimaryOnlyLimit(priFla) : { pct: 125, roundUp: true, note: 'NEC 450.3(B)' };
    const priCeiling = priFla * (priTier.pct / 100);
    const priOcpd = priTier.roundUp ? wzNextOcpd(priCeiling) : (STD_OCPD_RATINGS.filter(r => r <= priCeiling).pop() || null);

    const secTier = typeof xfmrSecondaryLimit === 'function' ? xfmrSecondaryLimit(secFla) : { pct: 125, roundUp: true, note: '' };
    const secCeiling = secFla * (secTier.pct / 100);
    const secOcpd = secTier.roundUp ? wzNextOcpd(secCeiling) : (STD_OCPD_RATINGS.filter(r => r <= secCeiling).pop() || null);

    /* ── Disconnect sizing ── */
    // NEC 450.14 — disconnect must be within sight and ≤30 ft from transformer
    // Disconnect ampacity ≥ 125% of transformer FLA
    const priDiscAmps = priFla * 1.25;
    const secDiscAmps = secFla * 1.25;
    const priDisc = wzNextOcpd(priDiscAmps);
    const secDisc = wzNextOcpd(secDiscAmps);

    /* ── Conductors ── */
    function pickCond(fla) {
      if (typeof xePickConductor !== 'function') return null;
      return xePickConductor(fla * 1.25, material, wzInsulationTemp(WZ.insulation), termTemp, ambientC, ccc);
    }
    const priCond = pickCond(priFla);
    const secCond = pickCond(secFla);

    /* ── Parallel run options ── */
    const priParallel = parallelRunOptions(priFla * 1.25, material, WZ.insulation, ambientC, ccc, termTemp, phase, priConn);
    const secParallel = parallelRunOptions(secFla * 1.25, material, WZ.insulation, ambientC, ccc, termTemp, phase, secConn);
    const priOptimal = priParallel.find(r => r.optimal) || priParallel[0];
    const secOptimal = secParallel.find(r => r.optimal) || secParallel[0];

    /* ── Voltage drop ── */
    let priVd = null, secVd = null;
    if (priCond && typeof xeVoltageDrop === 'function') {
      priVd = xeVoltageDrop(priCond.size, material, phase, priFla, priLen, pf, priV);
    }
    if (secCond && typeof xeVoltageDrop === 'function') {
      secVd = xeVoltageDrop(secCond.size, material, phase, secFla, secLen, pf, secV);
    }

    /* ── EGC / GEC ── */
    const egcObj = (typeof egcForOCPD === 'function' && secOcpd) ? egcForOCPD(secOcpd, material) : null;
    const secBaseCmil = secCond ? WIRE_CMIL[secCond.size] : 0;
    const secEquivalentCmil = secOptimal ? WIRE_CMIL[secOptimal.size] * secOptimal.runs : secBaseCmil;
    const gecObj = (typeof gecForConductor === 'function' && secEquivalentCmil > 0)
      ? gecForConductor(secEquivalentCmil, material) : null;

    /* ── Render results ── */
    xwStep(4);

    function section(title, color) {
      const h = document.createElement('div');
      h.className = 'wtHeading';
      h.style.color = color || '#8b7bff';
      h.textContent = title;
      resultEl.appendChild(h);
    }
    function row(label, value, note) {
      const r = document.createElement('div');
      r.className = 'res-row';
      const l = document.createElement('span'); l.className = 'res-label'; l.textContent = label;
      const v = document.createElement('span'); v.className = 'res-value'; v.textContent = value;
      r.appendChild(l); r.appendChild(v);
      if (note) {
        const n = document.createElement('span'); n.className = 'res-note'; n.style.fontSize = '0.8em'; n.style.color = '#64748b';
        n.textContent = '  ' + note; r.appendChild(n);
      }
      resultEl.appendChild(r);
    }
    function note(text) {
      const d = document.createElement('div'); d.className = 'xe-note'; d.textContent = text;
      resultEl.appendChild(d);
    }

    section('▶ Transformer Specifications', '#f5c451');
    row('kVA Rating', kva + ' kVA');
    row('Phase', phase === '1ph' ? 'Single-Phase (1Ø)' : 'Three-Phase (3Ø)');
    row('Primary Voltage', fmt(priV, 0) + ' V');
    row('Secondary Voltage', fmt(secV, 0) + ' V');
    row('Type', typeObj ? typeObj.name : WZ.xfmrType);
    row('Winding', windObj ? windObj.name : WZ.windingId);
    row('Turns Ratio', fmt(priV / secV, 3) + ' : 1');

    section('▶ Full Load Amps (FLA)', '#8b7bff');
    const flaFormula = phase === '1ph' ? 'FLA = kVA × 1000 / V' : 'FLA = kVA × 1000 / (√3 × V)';
    note(flaFormula);
    row('Primary FLA', fmt(priFla, 2) + ' A', `at ${priV} V`);
    row('Secondary FLA', fmt(secFla, 2) + ' A', `at ${secV} V`);

    section('▶ Overcurrent Protection — NEC 450.3(B)', '#f5c451');
    row('Primary OCPD ceiling', fmt(priCeiling, 1) + ' A', `(${priTier.pct}% × ${fmt(priFla, 2)} A)`);
    row('Primary OCPD selected', (priOcpd || '—') + ' A', priTier.note);
    row('Secondary OCPD ceiling', fmt(secCeiling, 1) + ' A', `(${secTier.pct}% × ${fmt(secFla, 2)} A)`);
    row('Secondary OCPD selected', (secOcpd || '—') + ' A', secTier ? secTier.note : '');
    note('NEC Table 450.3(B) — all transformers 600V and below');

    section('▶ Disconnect — NEC 450.14', '#6ee7b7');
    row('Primary disconnect', (priDisc || '—') + ' A', '≥125% × primary FLA');
    row('Secondary disconnect', (secDisc || '—') + ' A', '≥125% × secondary FLA, within sight ≤30 ft');
    note('NEC 450.14 requires a means to disconnect the transformer from all ungrounded conductors, within sight or lockable.');

    section('▶ Primary Conductors', '#8b7bff');
    if (priCond) {
      row('Required ampacity', fmt(priFla * 1.25, 2) + ' A', '125% × FLA per NEC 215.2(A)');
      row('Conductor size', priCond.size + ' AWG/kcmil ' + material.toUpperCase() + ' ' + WZ.insulation);
      row('Base ampacity', fmt(priCond.base, 0) + ' A', 'NEC Table 310.16');
      row('Derated usable', fmt(priCond.usable, 1) + ' A');
      if (priVd) {
        row('Voltage drop', fmt(priVd.volts, 2) + ' V (' + fmt(priVd.percent, 2) + '%)', priLen + ' ft @ ' + fmt(pf, 2) + ' PF');
        if (priVd.percent > 3) note('⚠ Voltage drop exceeds recommended 3% — consider larger conductor or reducing distance.');
      }
    } else { note('⚠ Primary conductor selection failed — check parameters.'); }

    section('▶ Secondary Conductors', '#6ee7b7');
    if (secCond) {
      row('Required ampacity', fmt(secFla * 1.25, 2) + ' A', '125% × FLA per NEC 215.2(A)');
      row('Conductor size', secCond.size + ' AWG/kcmil ' + material.toUpperCase() + ' ' + WZ.insulation);
      row('Base ampacity', fmt(secCond.base, 0) + ' A', 'NEC Table 310.16');
      row('Derated usable', fmt(secCond.usable, 1) + ' A');
      if (secVd) {
        row('Voltage drop', fmt(secVd.volts, 2) + ' V (' + fmt(secVd.percent, 2) + '%)', secLen + ' ft @ ' + fmt(pf, 2) + ' PF');
        if (secVd.percent > 3) note('⚠ Voltage drop exceeds recommended 3% — consider larger conductor or reducing distance.');
      }
    } else { note('⚠ Secondary conductor selection failed — check parameters.'); }

    section('▶ Parallel Run Cost Optimization', '#f5c451');
    note('Showing cost ($/ft installed, all conductors) for 1–6 parallel runs:');

    function parallelTable(opts, side) {
      const tbl = document.createElement('table');
      tbl.className = 'ref-table';
      tbl.style.marginBottom = '8px';
      const hdr = document.createElement('tr');
      ['Runs', 'Size', 'A/run', 'Total A', '$/ft total', ''].forEach(h => {
        const th = document.createElement('th'); th.textContent = h; hdr.appendChild(th);
      });
      tbl.appendChild(hdr);
      opts.forEach(r => {
        const tr = document.createElement('tr');
        if (r.optimal) tr.style.background = '#0f2a1a';
        [r.runs, r.size + ' ' + material, fmt(r.ampsPerRun, 1), fmt(r.usableAmps, 1), '$' + r.costPerFt, r.optimal ? '✓ Best' : ''].forEach(v => {
          const td = document.createElement('td'); td.textContent = v;
          if (r.optimal) td.style.color = '#6ee7b7';
          tr.appendChild(td);
        });
        tbl.appendChild(tr);
      });
      resultEl.appendChild(document.createTextNode(side + ' side:'));
      resultEl.appendChild(tbl);
    }

    parallelTable(priParallel, 'Primary');
    parallelTable(secParallel, 'Secondary');
    note('✓ Optimal = lowest installed cost per foot considering all conductor runs.');

    if (egcObj) {
      section('▶ Equipment Grounding Conductor (EGC) — NEC 250.122', '#6ee7b7');
      row('EGC size', egcObj.size + ' ' + material, 'based on secondary OCPD ' + (secOcpd || '?') + ' A');
    }
    if (gecObj) {
      section('▶ Grounding Electrode Conductor (GEC) — NEC 250.30(A)', '#6ee7b7');
      row('GEC size', gecObj.size + ' ' + material.toUpperCase(), 'based on ' + secEquivalentCmil.toLocaleString() + ' cmil of derived secondary conductor(s)');
      note('NEC 250.30(A)(4) — GEC sized per Table 250.66, based on the size of the largest derived phase conductor.');
    }

    // Winding context note
    if (windObj) {
      section('▶ Winding Notes', '#94a3b8');
      note(windObj.context);
      note('Typical application: ' + windObj.typical);
    }

    /* ── Transformer SVG ── */
    if (xfmrSvgEl) {
      xfmrSvgEl.textContent = '';
      const svgParams = {
        kva, priV, secV, phase,
        typeName: typeObj ? typeObj.short : '',
        winding: windObj ? windObj.name : '',
        type: WZ.xfmrType,
        priConn, secConn,
      };
      xfmrSvgEl.appendChild(buildXfmrSvg(svgParams));
    }

    /* ── SLD ── */
    if (sldEl) {
      sldEl.textContent = '';
      const sldParams = {
        kva, priV, secV, phase,
        typeName: typeObj ? typeObj.short : '',
        winding: windObj ? windObj.name : '',
        priConn, secConn,
        priOcpd, secOcpd,
        priDisc: (priDisc || '—') + 'A DISC',
        material,
        priCond: priCond ? { size: priCond.size, runs: 1 } : null,
        secCond: secCond ? { size: secCond.size, runs: 1 } : null,
        priVd, secVd,
        egc: egcObj ? egcObj.size : null,
        gec: gecObj ? gecObj.size : null,
      };
      sldEl.appendChild(buildSldSvg(sldParams));
      if (priOptimal && priOptimal.runs > 1 || secOptimal && secOptimal.runs > 1) {
        note('SLD shows the single-run base design. The cost table identifies separate parallel alternatives; do not substitute an optimal parallel option without updating all conductors and grounding details.');
      }
    }
  };

  /* ── Init ── */
  document.addEventListener('DOMContentLoaded', function () {
    xwStep(1);
  });

})();
