/* ============================================================================
   WIRE & RACEWAY TOOLS
   ============================================================================
   Two calculators that read their tables from nec-data.js:

   1. Conduit Fill  — mixed conductor sizes/insulations in one raceway, any
      Chapter 9 raceway type, with the Table 1 fill limits and the nipple
      exception, and it recommends the smallest raceway that works.

   2. Wire Size Selector — picks the smallest conductor that satisfies BOTH
      ampacity (with ambient, bundling, continuous-load and termination-
      temperature limits applied) AND a voltage-drop ceiling, then prices the
      parallel-run options so a single large run can be compared against
      several smaller ones.

   Results are built with DOM methods and textContent, never innerHTML, so
   user input can never be interpreted as markup.
   ============================================================================ */

/* ---------------------------------------------------------------------------
   Rendering helpers — match the existing .result / .res-row card styling.
   --------------------------------------------------------------------------- */

function wtClear(id) {
  const el = document.getElementById(id);
  if (el) el.textContent = '';
  return el;
}

function wtRow(parent, label, value, opts) {
  const row = document.createElement('div');
  row.className = 'res-row';
  const l = document.createElement('span');
  l.className = 'res-label';
  l.textContent = label;
  const v = document.createElement('span');
  v.className = 'res-val';
  v.textContent = value;
  if (opts && opts.color) v.style.color = opts.color;
  if (opts && opts.bold) v.style.fontWeight = '700';
  row.appendChild(l);
  row.appendChild(v);
  parent.appendChild(row);
  return row;
}

function wtHeading(parent, text) {
  const h = document.createElement('div');
  h.className = 'res-row';
  h.style.borderBottom = '1px solid rgba(139,123,255,0.35)';
  h.style.marginTop = '0.6rem';
  const l = document.createElement('span');
  l.className = 'res-label';
  l.style.textTransform = 'uppercase';
  l.style.letterSpacing = '0.12em';
  l.style.fontSize = '0.72em';
  l.style.color = '#8b7bff';
  l.textContent = text;
  h.appendChild(l);
  parent.appendChild(h);
}

function wtNote(parent, text) {
  const p = document.createElement('p');
  p.style.margin = '0.5rem 0 0';
  p.style.fontSize = '0.78em';
  p.style.lineHeight = '1.5';
  p.style.opacity = '0.75';
  p.textContent = text;
  parent.appendChild(p);
}

const PASS_COLOR = '#6ee7b7';
const FAIL_COLOR = '#ff8a8a';
const WARN_COLOR = '#f5c451';

/* ============================================================================
   1. CONDUIT FILL — mixed conductors, any Chapter 9 raceway
   ============================================================================ */

let cfRowSeq = 0;

/** Adds one "qty × size × insulation" row to the conductor list. */
function addConduitRow(defaults) {
  const host = document.getElementById('cfa_rows');
  if (!host) return;
  const id = ++cfRowSeq;
  const d = defaults || {};

  const row = document.createElement('div');
  row.className = 'cfa-row';
  row.dataset.rowId = String(id);

  const qty = document.createElement('input');
  qty.type = 'number';
  qty.min = '1';
  qty.step = '1';
  qty.value = d.qty || '3';
  qty.className = 'cfa-qty';
  qty.setAttribute('aria-label', 'Quantity of conductors');

  const times = document.createElement('span');
  times.className = 'cfa-x';
  times.textContent = '×';

  const size = document.createElement('select');
  size.className = 'cfa-size';
  size.setAttribute('aria-label', 'Conductor size');
  WIRE_SIZE_ORDER.forEach((s) => {
    const o = document.createElement('option');
    o.value = s;
    o.textContent = wireSizeLabel(s);
    if (s === (d.size || '12')) o.selected = true;
    size.appendChild(o);
  });

  const insul = document.createElement('select');
  insul.className = 'cfa-insul';
  insul.setAttribute('aria-label', 'Insulation type');
  Object.keys(INSULATION_TYPES).forEach((key) => {
    const o = document.createElement('option');
    o.value = key;
    o.textContent = INSULATION_TYPES[key].label;
    if (key === (d.insul || 'THHN')) o.selected = true;
    insul.appendChild(o);
  });

  const del = document.createElement('button');
  del.type = 'button';
  del.className = 'cfa-del';
  del.textContent = '✕';
  del.title = 'Remove this row';
  del.setAttribute('aria-label', 'Remove conductor row');
  del.onclick = function () {
    row.remove();
  };

  row.appendChild(qty);
  row.appendChild(times);
  row.appendChild(size);
  row.appendChild(insul);
  row.appendChild(del);
  host.appendChild(row);
}
window.addConduitRow = addConduitRow;

/** Reads the conductor rows into [{qty, size, insul, area}]. */
function readConduitRows() {
  const rows = [];
  document.querySelectorAll('#cfa_rows .cfa-row').forEach((row) => {
    const qty = parseInt(row.querySelector('.cfa-qty').value, 10);
    const size = row.querySelector('.cfa-size').value;
    const insul = row.querySelector('.cfa-insul').value;
    if (!Number.isFinite(qty) || qty < 1) return;
    const table = INSULATION_TYPES[insul];
    if (!table) return;
    const area = table.areas[size];
    if (typeof area !== 'number') return;
    rows.push({ qty: qty, size: size, insul: insul, area: area, insulLabel: table.label });
  });
  return rows;
}

/** NEC Ch.9 Table 1 — fill limit by conductor count, plus the nipple exception. */
function conduitFillLimit(totalConductors, isNipple) {
  if (isNipple) return { pct: 60, basis: 'Nipple ≤ 24 in — Ch.9 Table 1, Note 4' };
  if (totalConductors === 1) return { pct: 53, basis: '1 conductor — Ch.9 Table 1' };
  if (totalConductors === 2) return { pct: 31, basis: '2 conductors — Ch.9 Table 1' };
  return { pct: 40, basis: 'Over 2 conductors — Ch.9 Table 1' };
}

window.calcConduitFillAdvanced = function () {
  const el = wtClear('cfa_result');
  if (!el) return;
  el.className = 'result show';

  const type = document.getElementById('cfa_type').value;
  const chosenSize = document.getElementById('cfa_size').value;
  const isNipple = document.getElementById('cfa_nipple').checked;
  const conduit = CONDUIT_TYPES[type];

  if (!conduit) return showError('cfa_result', 'Select a raceway type.');

  const rows = readConduitRows();
  if (!rows.length) {
    return showError('cfa_result', 'Add at least one conductor row.');
  }

  const totalConductors = rows.reduce((n, r) => n + r.qty, 0);
  const totalArea = rows.reduce((a, r) => a + r.qty * r.area, 0);
  const limit = conduitFillLimit(totalConductors, isNipple);

  /* Smallest trade size of this type whose allowed area holds the bundle. */
  const available = CONDUIT_TRADE_ORDER.filter((t) => conduit.areas[t] !== undefined);
  const minSize = available.find((t) => conduit.areas[t] * (limit.pct / 100) >= totalArea);

  el.className = 'result show';

  wtHeading(el, 'Conductors');
  rows.forEach((r) => {
    wtRow(
      el,
      r.qty + ' × ' + wireSizeLabel(r.size) + ' ' + r.insulLabel,
      fmt(r.qty * r.area, 4) + ' sq in'
    );
  });
  wtRow(el, 'Total conductors', String(totalConductors));
  wtRow(el, 'Total conductor area', fmt(totalArea, 4) + ' sq in', { bold: true });

  wtHeading(el, 'Fill limit');
  wtRow(el, 'Maximum fill', limit.pct + ' %');
  wtRow(el, 'Basis', limit.basis);

  if (chosenSize === 'auto') {
    wtHeading(el, 'Recommended raceway');
    if (minSize) {
      const area = conduit.areas[minSize];
      const allowed = area * (limit.pct / 100);
      const fillPct = (totalArea / area) * 100;
      wtRow(el, 'Minimum size', minSize + '" ' + type, { bold: true, color: PASS_COLOR });
      wtRow(el, 'Internal area', fmt(area, 4) + ' sq in');
      wtRow(el, 'Allowable fill area', fmt(allowed, 4) + ' sq in');
      wtRow(el, 'Actual fill', fmt(fillPct, 2) + ' %');
      wtRow(el, 'Spare capacity', fmt(allowed - totalArea, 4) + ' sq in');
    } else {
      wtRow(el, 'Minimum size', 'Exceeds largest ' + type + ' size', { color: FAIL_COLOR, bold: true });
      wtNote(el, 'Split the run across multiple raceways, or choose a raceway type with larger trade sizes.');
    }
    appendCopyBtn(el);
    return;
  }

  const area = conduit.areas[chosenSize];
  if (typeof area !== 'number') {
    return showError('cfa_result', chosenSize + '" is not a trade size for ' + type + '.');
  }

  const allowed = area * (limit.pct / 100);
  const fillPct = (totalArea / area) * 100;
  const pass = totalArea <= allowed;

  wtHeading(el, chosenSize + '" ' + type);
  wtRow(el, 'Internal area', fmt(area, 4) + ' sq in');
  wtRow(el, 'Allowable fill area', fmt(allowed, 4) + ' sq in');
  wtRow(el, 'Actual fill', fmt(fillPct, 2) + ' %', { bold: true });
  wtRow(
    el,
    'Result',
    pass ? '✔ PASS — within NEC fill limit' : '✘ FAIL — exceeds NEC fill limit',
    { color: pass ? PASS_COLOR : FAIL_COLOR, bold: true }
  );
  wtRow(
    el,
    pass ? 'Spare capacity' : 'Over by',
    fmt(Math.abs(allowed - totalArea), 4) + ' sq in'
  );

  if (!pass) {
    wtHeading(el, 'Recommended raceway');
    if (minSize) {
      wtRow(el, 'Smallest that fits', minSize + '" ' + type, { bold: true, color: PASS_COLOR });
      wtRow(el, 'Fill at that size', fmt((totalArea / conduit.areas[minSize]) * 100, 2) + ' %');
    } else {
      wtRow(el, 'Smallest that fits', 'Exceeds largest ' + type + ' size', { color: FAIL_COLOR });
    }
  }

  appendCopyBtn(el);
};

window.loadConduitFillExample = function () {
  var typeEl = document.getElementById('cfa_type');
  var sizeEl = document.getElementById('cfa_size');
  var nippleEl = document.getElementById('cfa_nipple');
  var rowsHost = document.getElementById('cfa_rows');
  if (typeEl) typeEl.value = 'EMT';
  if (sizeEl) sizeEl.value = 'auto';
  if (nippleEl) nippleEl.checked = false;
  if (rowsHost) rowsHost.textContent = '';
  cfRowSeq = 0;
  addConduitRow({ qty: '3', size: '3/0', insul: 'THHN' });
  addConduitRow({ qty: '1', size: '3/0', insul: 'THHN' });
  addConduitRow({ qty: '1', size: '6', insul: 'THHN' });
  window.calcConduitFillAdvanced();
};

/* ============================================================================
   2. WIRE SIZE SELECTOR — ampacity + voltage drop + parallel-run cost
   ============================================================================ */

/* Ballpark installed material prices. These move with the metals market, so
   they are starting points the user is expected to override — the form exposes
   a single multiplier so a whole estimate can be scaled at once. */
const CONDUCTOR_PRICE_PER_FT = {
  cu: {
    '14': 0.12, '12': 0.18, '10': 0.28, '8': 0.52, '6': 0.80, '4': 1.25,
    '3': 1.55, '2': 1.95, '1': 2.45, '1/0': 3.00, '2/0': 3.75, '3/0': 4.65,
    '4/0': 5.75, '250': 6.85, '300': 8.10, '350': 9.40, '400': 10.70,
    '500': 13.20, '600': 16.00, '700': 18.20, '750': 19.80, '800': 21.00,
    '900': 23.50, '1000': 26.00,
  },
  al: {
    '12': 0.09, '10': 0.13, '8': 0.20, '6': 0.30, '4': 0.42, '3': 0.50,
    '2': 0.60, '1': 0.72, '1/0': 0.88, '2/0': 1.05, '3/0': 1.28, '4/0': 1.55,
    '250': 1.85, '300': 2.15, '350': 2.45, '400': 2.75, '500': 3.40,
    '600': 4.05, '700': 4.70, '750': 5.00, '800': 5.30, '900': 5.90, '1000': 6.60,
  },
};

/* Manual entries begin with the same average allowance as the automatic
   price book. They are kept separately for copper and aluminum so changing
   material never silently discards a user's current takeoff pricing. */
const MANUAL_CONDUCTOR_PRICE_PER_FT = {
  cu: { ...CONDUCTOR_PRICE_PER_FT.cu },
  al: { ...CONDUCTOR_PRICE_PER_FT.al },
};

function wirePriceInputId(size) {
  return 'ws_price_' + String(size).replaceAll('/', '_');
}

function renderManualWirePrices() {
  const host = document.getElementById('ws_manual_price_rows');
  const materialField = document.getElementById('ws_material');
  if (!host || !materialField) return;
  const material = materialField.value;
  const prices = MANUAL_CONDUCTOR_PRICE_PER_FT[material];
  host.textContent = '';
  WIRE_SIZE_ORDER.filter((size) => typeof prices[size] === 'number').forEach((size) => {
    const row = document.createElement('div');
    row.className = 'manual-price-row';
    const label = document.createElement('label');
    const id = wirePriceInputId(size);
    label.htmlFor = id;
    label.textContent = wireSizeLabel(size);
    const input = document.createElement('input');
    input.type = 'number'; input.id = id; input.min = '0.01'; input.step = '0.01';
    input.value = prices[size].toFixed(2);
    input.setAttribute('aria-label', wireSizeLabel(size) + ' ' + (material === 'cu' ? 'copper' : 'aluminum') + ' price per foot');
    input.addEventListener('input', function () {
      const next = Number(input.value);
      if (Number.isFinite(next) && next > 0) prices[size] = next;
    });
    row.append(label, input); host.appendChild(row);
  });
}

window.setWirePriceMode = function () {
  const mode = document.getElementById('ws_price_mode')?.value || 'average';
  const manual = document.getElementById('ws_manual_prices');
  const market = document.getElementById('ws_market_adjust');
  const help = document.getElementById('ws_price_help');
  if (manual) manual.hidden = mode !== 'manual';
  if (market) market.hidden = mode === 'manual';
  if (help) help.textContent = mode === 'manual'
    ? 'Manual prices are used exactly as entered. EMT remains a default material allowance.'
    : 'Average prices are a planning baseline, not a live quote. Use 1.00 for the default allowance.';
  if (mode === 'manual') renderManualWirePrices();
};

function activeConductorPriceBook(material) {
  const mode = document.getElementById('ws_price_mode')?.value || 'average';
  if (mode !== 'manual') return { prices: CONDUCTOR_PRICE_PER_FT[material], multiplier: val('ws_price_mult'), label: 'average material allowance' };
  const prices = MANUAL_CONDUCTOR_PRICE_PER_FT[material];
  Object.keys(prices).forEach((size) => {
    const field = document.getElementById(wirePriceInputId(size));
    if (field) prices[size] = Number(field.value);
  });
  const invalid = Object.keys(prices).some((size) => !Number.isFinite(prices[size]) || prices[size] <= 0);
  if (invalid) return null;
  return { prices: prices, multiplier: 1, label: 'manual conductor price book' };
}

const CONDUIT_PRICE_PER_FT = {
  '1/2': 1.10, '3/4': 1.60, '1': 2.60, '1-1/4': 3.80, '1-1/2': 4.70, '2': 6.10,
  '2-1/2': 11.50, '3': 14.50, '3-1/2': 18.00, '4': 21.00, '5': 32.00, '6': 42.00,
};

/**
 * Derated ampacity of one conductor.
 * Ambient correction and the >3-CCC adjustment both apply to the conductor's
 * own insulation column (310.15), but the result is then capped by the
 * termination temperature rating per 110.14(C).
 */
function deratedAmpacity(size, material, insulTemp, terminationTemp, ambientC, ccc) {
  const row = AMPACITY[material] && AMPACITY[material][size];
  if (!row) return null;

  const baseAtInsul = row[TEMP_COLUMN_INDEX[insulTemp]];
  const ambient = ambientCorrectionFactor(ambientC, insulTemp);
  const bundle = cccAdjustmentFactor(ccc);
  const derated = baseAtInsul * ambient * bundle;

  /* 110.14(C): the conductor may not be loaded above the ampacity shown in the
     column matching the equipment's termination rating. */
  const terminationCap = row[TEMP_COLUMN_INDEX[terminationTemp]];

  return {
    base: baseAtInsul,
    ambientFactor: ambient,
    bundleFactor: bundle,
    derated: derated,
    terminationCap: terminationCap,
    usable: Math.min(derated, terminationCap),
  };
}

/** Effective per-1000-ft impedance, Z = R·cosθ + X·sinθ. */
function effectiveImpedance(size, material, powerFactor) {
  const r = DC_RESISTANCE[material] && DC_RESISTANCE[material][size];
  if (typeof r !== 'number') return null;
  const x = REACTANCE[size];
  const sinTheta = Math.sqrt(Math.max(0, 1 - powerFactor * powerFactor));
  return r * powerFactor + x * sinTheta;
}

/** Voltage drop in volts for one candidate. */
function voltageDropVolts(size, material, phase, current, lengthFt, powerFactor, runs) {
  const z = effectiveImpedance(size, material, powerFactor);
  if (z === null) return null;
  const multiplier = phase === '3ph' ? Math.sqrt(3) : 2;
  /* Paralleling divides the current between runs, so the effective impedance
     of the set falls by the same factor. */
  return (multiplier * current * lengthFt * z) / (1000 * runs);
}

window.calcWireSelection = function () {
  const el = wtClear('ws_result');
  if (!el) return;

  const phase = document.getElementById('ws_phase').value;
  const voltage = val('ws_voltage');
  const loadUnit = document.getElementById('ws_load_unit').value;
  const loadValue = val('ws_load');
  const powerFactor = val('ws_pf');
  const lengthFt = val('ws_length');
  const maxVdPct = val('ws_maxvd');
  const material = document.getElementById('ws_material').value;
  const insulTemp = parseInt(document.getElementById('ws_insul').value, 10);
  const terminationTemp = parseInt(document.getElementById('ws_term').value, 10);
  const ambientC = val('ws_ambient');
  const ccc = parseInt(document.getElementById('ws_ccc').value, 10);
  const continuous = document.getElementById('ws_continuous').checked;
  const maxRuns = parseInt(document.getElementById('ws_maxruns').value, 10) || 1;
  const priceBook = activeConductorPriceBook(material);

  if (!isPos(voltage)) return showError('ws_result', 'Supply voltage must be greater than zero.');
  if (!isPos(loadValue)) return showError('ws_result', 'Load must be greater than zero.');
  if (!isPos(lengthFt)) return showError('ws_result', 'One-way length must be greater than zero.');
  if (!isPos(maxVdPct)) return showError('ws_result', 'Maximum voltage drop must be greater than zero.');
  if (!isNum(ambientC)) return showError('ws_result', 'Enter an ambient temperature.');
  if (!isPos(powerFactor) || powerFactor > 1) {
    return showError('ws_result', 'Power factor must be between 0 and 1.');
  }
  if (terminationTemp > insulTemp) {
    return showError('ws_result', 'Termination rating cannot exceed the conductor insulation rating.');
  }
  if (!priceBook || !isPos(priceBook.multiplier)) {
    return showError('ws_result', 'Enter a positive price for every conductor size and a positive market adjustment.');
  }

  /* ---- Load current ---- */
  let current;
  let currentBasis;
  const sqrt3 = Math.sqrt(3);
  if (loadUnit === 'a') {
    current = loadValue;
    currentBasis = 'Entered directly';
  } else if (loadUnit === 'kva') {
    current = phase === '3ph'
      ? (loadValue * 1000) / (sqrt3 * voltage)
      : (loadValue * 1000) / voltage;
    currentBasis = phase === '3ph'
      ? 'I = kVA×1000 / (√3 × V)'
      : 'I = kVA×1000 / V';
  } else if (loadUnit === 'kw') {
    current = phase === '3ph'
      ? (loadValue * 1000) / (sqrt3 * voltage * powerFactor)
      : (loadValue * 1000) / (voltage * powerFactor);
    currentBasis = phase === '3ph'
      ? 'I = kW×1000 / (√3 × V × PF)'
      : 'I = kW×1000 / (V × PF)';
  } else {
    const watts = loadValue * 746;
    current = phase === '3ph'
      ? watts / (sqrt3 * voltage * powerFactor)
      : watts / (voltage * powerFactor);
    currentBasis = phase === '3ph'
      ? 'I = hp×746 / (√3 × V × PF)'
      : 'I = hp×746 / (V × PF)';
  }

  /* 210.19(A)/215.2(A): size for 125% of a continuous load. */
  const designCurrent = continuous ? current * 1.25 : current;
  const maxVdVolts = (voltage * maxVdPct) / 100;

  /* ---- Evaluate every size at every run count ---- */
  const options = [];
  for (let runs = 1; runs <= maxRuns; runs++) {
    const perRunCurrent = designCurrent / runs;
    for (const size of WIRE_SIZE_ORDER) {
      if (runs > 1 && WIRE_CMIL[size] < MIN_PARALLEL_SIZE_CMIL) continue; // 310.10(G)
      const amp = deratedAmpacity(size, material, insulTemp, terminationTemp, ambientC, ccc);
      if (!amp || amp.usable <= 0) continue;
      if (amp.usable < perRunCurrent) continue;

      const vd = voltageDropVolts(size, material, phase, current, lengthFt, powerFactor, runs);
      if (vd === null) continue;
      const vdPct = (vd / voltage) * 100;
      if (vdPct > maxVdPct) continue;

      /* Conduit sized for this run: phase conductors + neutral + EGC, THHN. */
      const perRunConductors = phase === '3ph' ? 4 : phase === '1ph' ? 3 : 2;
      const condArea = INSULATION_TYPES.THHN.areas[size];
      const bundleArea = condArea * perRunConductors;
      const emt = CONDUIT_TYPES.EMT;
      const tradeSize = CONDUIT_TRADE_ORDER
        .filter((t) => emt.areas[t] !== undefined)
        .find((t) => emt.areas[t] * 0.4 >= bundleArea);

      const wirePrice = priceBook.prices[size];
      if (typeof wirePrice !== 'number') continue;
      const conduitPrice = tradeSize ? CONDUIT_PRICE_PER_FT[tradeSize] : null;

      const conductorCost = wirePrice * lengthFt * perRunConductors * runs * priceBook.multiplier;
      const conduitCost = conduitPrice ? conduitPrice * lengthFt * runs * priceBook.multiplier : 0;

      options.push({
        runs: runs,
        size: size,
        perRunCurrent: perRunCurrent,
        amp: amp,
        vd: vd,
        vdPct: vdPct,
        tradeSize: tradeSize,
        perRunConductors: perRunConductors,
        conductorCost: conductorCost,
        conduitCost: conduitCost,
        totalCost: conductorCost + conduitCost,
      });
    }
  }

  if (!options.length) {
    return showError(
      'ws_result',
      'No conductor from 14 AWG to 1000 kcmil satisfies both ampacity and the ' +
        maxVdPct + '% voltage-drop limit, up to ' + maxRuns + ' parallel run(s). ' +
        'Increase the allowed runs or relax the voltage-drop limit.'
    );
  }

  const ranked = options.slice().sort((a, b) => a.totalCost - b.totalCost || a.runs - b.runs || WIRE_CMIL[a.size] - WIRE_CMIL[b.size]);
  const cheapest = ranked[0];
  const single = ranked.find((o) => o.runs === 1);
  const recommended = cheapest;

  el.className = 'result show';

  /* ---- Load ---- */
  wtHeading(el, 'Load');
  wtRow(el, 'Load current', fmt(current, 2) + ' A');
  wtRow(el, 'Basis', currentBasis);
  if (continuous) {
    wtRow(el, 'Continuous load ×1.25', fmt(designCurrent, 2) + ' A', { bold: true });
  }
  wtRow(el, 'Max allowable drop', fmt(maxVdVolts, 2) + ' V  (' + fmt(maxVdPct, 2) + ' %)');

  /* ---- Derating ---- */
  const refAmp = recommended.amp;
  wtHeading(el, 'Ampacity derating');
  wtRow(el, 'Ambient correction', '×' + refAmp.ambientFactor.toFixed(2) +
    '  (' + fmt(ambientC, 0) + '°C, ' + insulTemp + '°C insulation)');
  wtRow(el, 'Bundling adjustment', '×' + refAmp.bundleFactor.toFixed(2) +
    '  (' + ccc + ' current-carrying)');
  wtRow(el, 'Termination limit', insulTemp === terminationTemp
    ? 'Not limiting'
    : terminationTemp + '°C column — NEC 110.14(C)');

  /* ---- Recommendation ---- */
  wtHeading(el, 'Lowest modeled material cost');
  el.lastElementChild.classList.add('cost-optimum');
  wtRow(el, 'Conductor', recommended.runs + ' run' + (recommended.runs > 1 ? 's' : '') +
    ' × ' + wireSizeLabel(recommended.size) + ' ' + (material === 'cu' ? 'Cu' : 'Al'),
    { bold: true, color: PASS_COLOR });
  wtRow(el, 'Usable ampacity per run', fmt(refAmp.usable, 1) + ' A' +
    '  (need ' + fmt(recommended.perRunCurrent, 1) + ' A)');
  wtRow(el, 'Voltage drop', fmt(recommended.vd, 2) + ' V  (' + fmt(recommended.vdPct, 2) + ' %)');
  wtRow(el, 'Voltage at load', fmt(voltage - recommended.vd, 1) + ' V');
  if (recommended.tradeSize) {
    wtRow(el, 'Conduit per run', recommended.tradeSize + '" EMT  (' +
      recommended.perRunConductors + ' conductors)');
  }
  wtRow(el, 'Modeled material cost', '$' + recommended.totalCost.toLocaleString('en-US', { maximumFractionDigits: 0 }), { bold: true, color: PASS_COLOR });
  wtRow(el, 'Price source', priceBook.label + (priceBook.multiplier !== 1 ? ' × ' + fmt(priceBook.multiplier, 2) : ''));

  const ocpd = nextStandardOCPD(designCurrent);
  if (ocpd) {
    const smallCap = SMALL_CONDUCTOR_MAX_OCPD[recommended.size];
    const finalOcpd = smallCap ? Math.min(ocpd, smallCap) : ocpd;
    wtRow(el, 'Next standard OCPD', finalOcpd + ' A' +
      (smallCap && smallCap < ocpd ? '  (capped by 240.4(D))' : ''));
  }

  /* ---- Parallel-run comparison ---- */
  wtHeading(el, 'Lowest-cost compliant options');
  ranked.slice(0, 8).forEach((o) => {
    const isCheapest = o === cheapest;
    wtRow(
      el,
      o.runs + ' × ' + wireSizeLabel(o.size) +
        (o.tradeSize ? '  in ' + o.tradeSize + '" EMT' : ''),
      '$' + o.totalCost.toLocaleString('en-US', { maximumFractionDigits: 0 }) +
        (isCheapest ? '  ← lowest' : ''),
      isCheapest ? { color: PASS_COLOR, bold: true } : undefined
    );
  });

  if (single && cheapest !== single) {
    const saving = single.totalCost - cheapest.totalCost;
    wtRow(el, 'Saving vs lowest single run',
      '$' + saving.toLocaleString('en-US', { maximumFractionDigits: 0 }) +
      '  (' + fmt((saving / single.totalCost) * 100, 1) + ' %)',
      { color: PASS_COLOR });
  }

  wtNote(el,
    'Costs cover conductor and EMT material only — no labour, fittings, terminations or ' +
    'boxes — and automatic prices are averages, so treat them as a relative comparison ' +
    'rather than a quote. Each parallel set must be the same length, size and material, ' +
    'and terminate identically (NEC 310.10(G)).');

  appendCopyBtn(el);
};

/* Seed the conduit-fill rows once the DOM is ready. */
document.addEventListener('DOMContentLoaded', function () {
  if (document.getElementById('cfa_rows')) {
    addConduitRow({ qty: '3', size: '12', insul: 'THHN' });
    addConduitRow({ qty: '1', size: '12', insul: 'THHN' });
  }
  if (document.getElementById('ws_price_mode')) {
    document.getElementById('ws_material').addEventListener('change', function () {
      if (document.getElementById('ws_price_mode').value === 'manual') renderManualWirePrices();
    });
    window.setWirePriceMode();
  }
});

/* Callable ampacity / voltage-drop helpers for other toolbox pages.
   Reuses NEC Table 310.16 and Ch.9 Tables 8–9 from nec-data.js — do not
   copy those tables elsewhere. */
window.BeckifyWireMath = {
  ampacity75: function (size, material) {
    var key = String(size || '').replace(/\s*(AWG|kcmil)\s*/ig, '').trim();
    var row = AMPACITY[material || 'cu'] && AMPACITY[material || 'cu'][key];
    if (!row) return null;
    return row[TEMP_COLUMN_INDEX[75]];
  },
  deratedAmpacity: deratedAmpacity,
  voltageDropVolts: voltageDropVolts,
  suggestSizeForFla: function (fla, material) {
    var need = Number(fla) * 1.25;
    if (!Number.isFinite(need) || need <= 0) return null;
    var mat = material || 'cu';
    for (var i = 0; i < WIRE_SIZE_ORDER.length; i++) {
      var size = WIRE_SIZE_ORDER[i];
      var row = AMPACITY[mat] && AMPACITY[mat][size];
      if (row && row[TEMP_COLUMN_INDEX[75]] >= need) {
        return { size: size, ampacity: row[TEMP_COLUMN_INDEX[75]], required: need, article: 'NEC 430.22', material: mat };
      }
    }
    return null;
  },
};
