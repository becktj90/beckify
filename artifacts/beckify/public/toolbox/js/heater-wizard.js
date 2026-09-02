/* ============================================================================
   HEATER DESIGN WIZARD
   ============================================================================
   Two connected calculators for resistive heating equipment:

   1. Electrical sizing — given a target power, line voltage, phase count and
      wye/delta wiring, derives every branch/leg/element voltage, current and
      resistance for a balanced resistive load (PF = 1), then recommends a
      branch-circuit conductor and OCPD using the same 125%-continuous-load
      practice and Table 310.16 selection already used by every other
      conductor calculator in this toolbox (xePickConductor, nextStandardOCPD
      from xfmr-engine.js / nec-data.js).

   2. Element design — given a target resistance and power (usually handed
      off from step 1), works out the bare resistance-wire length, diameter,
      current density and surface power density for a chosen alloy and AWG
      gauge, and — if a coil mandrel diameter is given — the turn count and
      wound coil length.

   What is exact vs. what is a starting point:

     - Three-phase wye/delta power relations (V_phase, R_leg, I_line) are
       closed-form AC circuit theory for a balanced resistive load. Exact.
     - The AWG wire diameter formula (d = 0.005 x 92^((36-n)/39) inches) is
       the literal definition of the American Wire Gauge standard. Exact for
       any gauge, not a lookup table that can drift from a transcription.
     - Alloy resistivity, maximum element temperature, and "typical" surface
       power-density ranges are commonly published reference figures, NOT
       measured constants this tool can vouch for. Every one of them is an
       editable input with a default, not a hidden constant, specifically so
       a wrong assumption never survives past the first screen — confirm
       against your wire supplier's own datasheet before fabricating a
       heating element.
   ============================================================================ */

const HW_SQRT3 = Math.sqrt(3);

/* ---------------------------------------------------------------------------
   Alloy reference data — see the caveat above. Values are typical published
   figures (resistivity in ohm.mm^2/m, i.e. the resistance of a 1 m length of
   1 mm^2 cross-section) and are always editable in the UI.
   --------------------------------------------------------------------------- */
const HW_ALLOYS = {
  nichrome80: { label: 'Nichrome 80 (80Ni-20Cr)', resistivity: 1.09, maxTemp: 1150 },
  nichrome60: { label: 'Nichrome 60 (60Ni-16Cr-24Fe)', resistivity: 1.12, maxTemp: 1050 },
  kanthalA1: { label: 'Kanthal A-1 (FeCrAl)', resistivity: 1.45, maxTemp: 1400 },
  kanthalD: { label: 'Kanthal D (FeCrAl)', resistivity: 1.35, maxTemp: 1300 },
  custom: { label: 'Custom alloy', resistivity: 1.10, maxTemp: 1200 },
};

/* Candidate gauges shown in the comparison table — the common range for wound
   resistance-heating elements. */
const HW_AWG_LIST = [8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40];

/* ---------------------------------------------------------------------------
   Pure math — AWG geometry
   --------------------------------------------------------------------------- */

/** Bare wire diameter in inches for any AWG size, including the 1/0-4/0
    range (n = 0, -1, -2, -3). This is the AWG standard's own definition, not
    a lookup table, so it is exact for every gauge, not just the ones a table
    happened to list. */
function hwAwgDiameterIn(awg) {
  return 0.005 * Math.pow(92, (36 - awg) / 39);
}

function hwAwgDiameterMm(awg) {
  return hwAwgDiameterIn(awg) * 25.4;
}

/** Cross-sectional area in mm^2, from the bare diameter. */
function hwAwgAreaMm2(awg) {
  const d = hwAwgDiameterMm(awg);
  return (Math.PI / 4) * d * d;
}

/** Cross-sectional area in circular mils (diameter in mils, squared — the
    circular mil is defined that way, not derived from the circle area). */
function hwAwgAreaCmil(awg) {
  const mils = hwAwgDiameterIn(awg) * 1000;
  return mils * mils;
}

/* ---------------------------------------------------------------------------
   Pure math — three-phase / single-phase resistive-load relations
   --------------------------------------------------------------------------- */

/** Line-to-neutral (phase) voltage seen by one wye leg, or the full line
    voltage seen by one delta leg. */
function hwPhaseVoltage(vll, phase, conn) {
  if (phase === '1ph') return vll;
  return conn === 'wye' ? vll / HW_SQRT3 : vll;
}

/** Equivalent resistance of one leg/branch (wye) or one line-line-connected
    branch (delta) that yields pTotal watts at vll volts, PF = 1.
      Wye:   P = 3 x V_phase^2 / R = V_LL^2 / R           -> R = V_LL^2 / P
      Delta: P = 3 x V_LL^2 / R                            -> R = 3 x V_LL^2 / P
    Both reduce to the same line current, only the internal branch voltage,
    current and resistance differ — delta legs need 3x the resistance of wye
    legs for the same total power and the same line voltage. */
function hwLegResistance(pTotal, vll, phase, conn) {
  if (phase === '1ph') return (vll * vll) / pTotal;
  return conn === 'wye' ? (vll * vll) / pTotal : (3 * vll * vll) / pTotal;
}

/** Line current for a balanced resistive load, PF = 1.
      3-phase: I_line = P / (sqrt(3) x V_LL)   (same formula regardless of
                wye/delta — the internal branch current differs, the line
                current does not)
      1-phase: I_line = P / V */
function hwLineCurrent(pTotal, vll, phase) {
  return phase === '1ph' ? pTotal / vll : pTotal / (HW_SQRT3 * vll);
}

/** Per-element resistance/current/power when n identical elements share one
    leg's resistance and current, either in series or in parallel. */
function hwElementFromLeg(rLeg, phaseCurrent, phaseVoltage, legPower, n, arrangement) {
  if (arrangement === 'parallel') {
    return {
      resistance: rLeg * n,
      current: phaseCurrent / n,
      voltage: phaseVoltage,
      power: legPower / n,
    };
  }
  // series (default): current is unchanged, voltage and resistance divide
  return {
    resistance: rLeg / n,
    current: phaseCurrent,
    voltage: phaseVoltage / n,
    power: legPower / n,
  };
}

/* ---------------------------------------------------------------------------
   Pure math — custom element design
   --------------------------------------------------------------------------- */

/**
 * Everything derivable from a target resistance, a target power, an alloy
 * resistivity and a wire gauge.
 */
function hwElementDesign(targetR, targetP, resistivityOhmMm2PerM, awg) {
  const diameterMm = hwAwgDiameterMm(awg);
  const areaMm2 = hwAwgAreaMm2(awg);
  const resPerMeter = resistivityOhmMm2PerM / areaMm2; // ohm/m
  const resPerFoot = resPerMeter * 0.3048;
  const lengthM = targetR / resPerMeter;
  const lengthFt = lengthM / 0.3048;
  const current = Math.sqrt(targetP / targetR);
  const voltage = current * targetR;
  const currentDensity = current / areaMm2; // A/mm^2
  const surfaceAreaMm2 = Math.PI * diameterMm * (lengthM * 1000);
  const surfaceAreaIn2 = surfaceAreaMm2 / 645.16;
  const surfaceAreaCm2 = surfaceAreaMm2 / 100;
  const powerDensityWIn2 = targetP / surfaceAreaIn2;
  const powerDensityWCm2 = targetP / surfaceAreaCm2;
  return {
    awg, diameterMm, diameterIn: diameterMm / 25.4, areaMm2,
    areaCmil: hwAwgAreaCmil(awg), resPerMeter, resPerFoot,
    lengthM, lengthFt, current, voltage, currentDensity,
    surfaceAreaIn2, surfaceAreaCm2, powerDensityWIn2, powerDensityWCm2,
  };
}

/** Turns and wound length for a close-wound (or fixed-pitch) coil on a
    mandrel of a given outer diameter. Mean coil diameter is approximated as
    the mandrel diameter plus one wire diameter (the wire's centerline sits
    half a diameter off the mandrel surface) — the standard approximation for
    a close-wound helical coil. */
function hwCoilGeometry(lengthM, diameterMm, mandrelMm, pitchMm) {
  const meanCoilDiameterMm = mandrelMm + diameterMm;
  const circumferenceMm = Math.PI * meanCoilDiameterMm;
  const lengthMm = lengthM * 1000;
  const turns = lengthMm / circumferenceMm;
  const effectivePitch = pitchMm && pitchMm > 0 ? pitchMm : diameterMm;
  const coilLengthMm = turns * effectivePitch;
  return { meanCoilDiameterMm, turns, coilLengthMm, pitchMm: effectivePitch };
}

/* ---------------------------------------------------------------------------
   SVG — wye / delta electrical diagram
   --------------------------------------------------------------------------- */
function hwBuildWiringSvg(opts) {
  const ns = 'http://www.w3.org/2000/svg';
  const W = 360, H = 260;
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
  svg.setAttribute('role', 'img');
  svg.setAttribute('style', 'max-width:360px;background:#0d1117;border-radius:8px;display:block;margin:0 auto');

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
  function resistor(x1, y1, x2, y2, color) {
    // Zig-zag resistor symbol drawn along the line from (x1,y1) to (x2,y2).
    const dx = x2 - x1, dy = y2 - y1;
    const len = Math.hypot(dx, dy);
    const ux = dx / len, uy = dy / len;
    const nx = -uy, ny = ux;
    const zigLen = len * 0.5;
    const start = len * 0.25;
    const zigs = 6;
    let d = `M ${x1} ${y1} L ${x1 + ux * start} ${y1 + uy * start}`;
    for (let i = 0; i <= zigs; i++) {
      const t = start + (zigLen * i) / zigs;
      const side = i % 2 === 0 ? 0 : (i % 4 === 1 ? 1 : -1);
      const px = x1 + ux * t + nx * side * 7;
      const py = y1 + uy * t + ny * side * 7;
      d += ` L ${px} ${py}`;
    }
    d += ` L ${x1 + ux * (start + zigLen)} ${y1 + uy * (start + zigLen)} L ${x2} ${y2}`;
    return el('path', { d, fill: 'none', stroke: color, 'stroke-width': 2 });
  }

  svg.appendChild(el('rect', { x: 0, y: 0, width: W, height: H, fill: '#0d1117' }));
  svg.appendChild(el('rect', { x: 5, y: 5, width: W - 10, height: H - 10, fill: 'none', stroke: '#1e293b', 'stroke-width': 1, rx: 6 }));

  const color = '#f59e0b';
  const cx = W / 2, cy = H / 2;

  if (opts.phase === '1ph') {
    const y = cy;
    svg.appendChild(el('line', { x1: 30, y1: y - 30, x2: 30, y2: y + 30, stroke: '#8b7bff', 'stroke-width': 2 }));
    svg.appendChild(el('line', { x1: 30, y1: y - 30, x2: cx - 60, y2: y - 30, stroke: '#8b7bff', 'stroke-width': 2 }));
    svg.appendChild(el('line', { x1: 30, y1: y + 30, x2: cx - 60, y2: y + 30, stroke: '#8b7bff', 'stroke-width': 2 }));
    svg.appendChild(resistor(cx - 60, y - 30, cx + 60, y - 30, color));
    svg.appendChild(el('line', { x1: cx + 60, y1: y - 30, x2: W - 30, y2: y - 30, stroke: '#8b7bff', 'stroke-width': 2 }));
    svg.appendChild(el('line', { x1: cx + 60, y1: y + 30, x2: W - 30, y2: y + 30, stroke: '#8b7bff', 'stroke-width': 2 }));
    svg.appendChild(el('line', { x1: W - 30, y1: y - 30, x2: W - 30, y2: y + 30, stroke: '#8b7bff', 'stroke-width': 2 }));
    svg.appendChild(text(`V = ${opts.vFmt}`, cx, y - 42, { fill: '#e2e8f0', size: 11, weight: 700 }));
    svg.appendChild(text(`I = ${opts.iFmt}`, cx, y + 46, { fill: color, size: 11, weight: 700 }));
    svg.appendChild(text(`R = ${opts.rFmt}`, cx, H - 20, { fill: '#94a3b8', size: 10 }));
    return svg;
  }

  const isWye = opts.conn === 'wye';
  const legs = [
    { angle: -90, label: 'A' },
    { angle: 30, label: 'B' },
    { angle: 150, label: 'C' },
  ];
  const R = 82;
  const pts = legs.map((l) => {
    const rad = (l.angle * Math.PI) / 180;
    return { x: cx + R * Math.cos(rad), y: cy + R * Math.sin(rad), label: l.label };
  });

  if (isWye) {
    // Star point at center, one resistor per leg out to each vertex.
    pts.forEach((p) => {
      svg.appendChild(resistor(cx, cy, p.x, p.y, color));
      const lx = cx + (p.x - cx) * 1.28, ly = cy + (p.y - cy) * 1.28;
      svg.appendChild(text(`L${p.label}`, lx, ly, { fill: '#e2e8f0', size: 11, weight: 700 }));
    });
    svg.appendChild(el('circle', { cx, cy, r: 3, fill: '#6ee7b7' }));
    svg.appendChild(text('N', cx + 10, cy - 6, { fill: '#6ee7b7', size: 10, anchor: 'start' }));
    svg.appendChild(text(`V_phase = ${opts.vFmt}`, cx, H - 34, { fill: '#e2e8f0', size: 10 }));
  } else {
    // Delta: one resistor along each side of the triangle.
    for (let i = 0; i < 3; i++) {
      const a = pts[i], b = pts[(i + 1) % 3];
      svg.appendChild(resistor(a.x, a.y, b.x, b.y, color));
    }
    pts.forEach((p) => {
      const lx = cx + (p.x - cx) * 1.28, ly = cy + (p.y - cy) * 1.28;
      svg.appendChild(text(`L${p.label}`, lx, ly, { fill: '#e2e8f0', size: 11, weight: 700 }));
    });
    svg.appendChild(text(`V_leg = ${opts.vFmt}`, cx, H - 34, { fill: '#e2e8f0', size: 10 }));
  }
  svg.appendChild(text(`I_line = ${opts.iFmt}`, cx, H - 20, { fill: color, size: 11, weight: 700 }));
  svg.setAttribute('aria-label', `${isWye ? 'Wye' : 'Delta'}-connected three-phase heater with line current ${opts.iFmt} and leg voltage ${opts.vFmt}.`);
  return svg;
}

/* ---------------------------------------------------------------------------
   SVG — coil winding diagram
   --------------------------------------------------------------------------- */
function hwBuildCoilSvg(geom) {
  const ns = 'http://www.w3.org/2000/svg';
  const W = 360, H = 160;
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
  svg.setAttribute('role', 'img');
  svg.setAttribute('aria-label', `Coil of ${geom.turns.toFixed(1)} turns, ${(geom.coilLengthMm / 25.4).toFixed(2)} inches long, wound on a ${geom.meanCoilDiameterMm.toFixed(1)} millimeter mean diameter mandrel.`);
  svg.setAttribute('style', 'max-width:360px;background:#0d1117;border-radius:8px;display:block;margin:0 auto');
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
    return t;
  }
  svg.appendChild(el('rect', { x: 0, y: 0, width: W, height: H, fill: '#0d1117' }));
  svg.appendChild(el('rect', { x: 5, y: 5, width: W - 10, height: H - 10, fill: 'none', stroke: '#1e293b', 'stroke-width': 1, rx: 6 }));

  // Mandrel (dashed centerline rod) with a fixed number of drawn coil turns
  // (visual only — an illustration, not literally the true turn count for
  // long coils, which is stated numerically alongside it).
  const y0 = 40, y1 = 110, x0 = 40, x1 = W - 40;
  svg.appendChild(el('line', { x1: x0 - 15, y1: (y0 + y1) / 2, x2: x1 + 15, y2: (y0 + y1) / 2, stroke: '#475569', 'stroke-width': 1, 'stroke-dasharray': '4 3' }));
  const drawnTurns = Math.min(14, Math.max(4, Math.round(geom.turns)));
  const step = (x1 - x0) / drawnTurns;
  let path = `M ${x0} ${y1}`;
  for (let i = 0; i <= drawnTurns; i++) {
    const x = x0 + i * step;
    path += ` Q ${x + step / 2} ${i % 2 === 0 ? y0 : y1} ${x + step} ${i % 2 === 0 ? y1 : y0}`;
  }
  svg.appendChild(el('path', { d: path, fill: 'none', stroke: '#f59e0b', 'stroke-width': 2.5, 'stroke-linecap': 'round' }));
  svg.appendChild(text(`${geom.turns.toFixed(1)} turns`, W / 2, 22, { fill: '#e2e8f0', size: 12 }));
  svg.appendChild(text(`coil length ${(geom.coilLengthMm / 25.4).toFixed(2)} in (${geom.coilLengthMm.toFixed(1)} mm)`, W / 2, H - 12, { fill: '#94a3b8', size: 10 }));
  svg.appendChild(text(`mean Ø ${geom.meanCoilDiameterMm.toFixed(1)} mm`, W / 2, H - 26, { fill: '#94a3b8', size: 10 }));
  return svg;
}

/* ---------------------------------------------------------------------------
   SVG — gauge comparison bar chart (power density by AWG)
   --------------------------------------------------------------------------- */
function hwBuildGaugeChart(rows, selectedAwg) {
  const ns = 'http://www.w3.org/2000/svg';
  const make = (name, attrs, label) => {
    const e = document.createElementNS(ns, name);
    Object.entries(attrs || {}).forEach(([k, v]) => e.setAttribute(k, v));
    if (label != null) e.textContent = label;
    return e;
  };
  const finite = rows.filter((r) => Number.isFinite(r.powerDensityWIn2));
  if (!finite.length) return null;
  const maxVal = Math.max(...finite.map((r) => r.powerDensityWIn2)) * 1.12 || 1;
  const x0 = 60, y0 = 14, width = 520, barGap = 6;
  const barH = Math.min(22, (150 - barGap * finite.length) / finite.length);
  const rowH = barH + barGap;
  const height = rowH * finite.length;
  const svg = make('svg', {
    viewBox: `0 0 ${x0 + width + 60} ${y0 + height + 10}`,
    role: 'img',
    'aria-label': `Power density by wire gauge, from ${finite[0].awg} AWG at ${finite[0].powerDensityWIn2.toFixed(1)} watts per square inch to ${finite[finite.length - 1].awg} AWG at ${finite[finite.length - 1].powerDensityWIn2.toFixed(1)} watts per square inch.`,
  });
  finite.forEach((r, i) => {
    const y = y0 + i * rowH;
    const w = (r.powerDensityWIn2 / maxVal) * width;
    const isSel = r.awg === selectedAwg;
    svg.append(make('text', { x: x0 - 8, y: y + barH * 0.72, fill: isSel ? '#f59e0b' : '#aeb5c4', 'font-size': 10, 'text-anchor': 'end', 'font-weight': isSel ? 700 : 400 }, `${r.awg} AWG`));
    svg.append(make('rect', { x: x0, y, width: Math.max(1, w), height: barH, rx: 3, fill: isSel ? '#f59e0b' : '#8b7bff', opacity: isSel ? 1 : 0.65 }));
    svg.append(make('text', { x: x0 + w + 6, y: y + barH * 0.72, fill: '#e2e8f0', 'font-size': 10 }, `${r.powerDensityWIn2.toFixed(1)} W/in²`));
  });
  return svg;
}

/* ---------------------------------------------------------------------------
   Main entry point — Electrical sizing
   --------------------------------------------------------------------------- */
let hwLastElectrical = null;

window.calcHeaterElectrical = function () {
  const el = wtClear('hw_elec_result');
  if (!el) return;
  const proof = document.getElementById('hw_elec_proof_body');
  if (proof) proof.textContent = '';

  const phase = document.getElementById('hw_phase').value;
  const conn = document.getElementById('hw_conn').value;
  const vll = val('hw_volts');
  const pKw = val('hw_power_kw');
  const n = Math.max(1, Math.round(val('hw_elements')) || 1);
  const arrangement = document.getElementById('hw_arrangement').value;
  const material = document.getElementById('hw_material').value;
  const insulation = document.getElementById('hw_insulation').value;
  const ambientC = val('hw_ambient');
  const ccc = parseInt(document.getElementById('hw_ccc').value, 10);
  const terminationTemp = parseInt(document.getElementById('hw_term').value, 10);

  if (!isPos(vll)) return showError('hw_elec_result', 'Enter a line voltage greater than zero.');
  if (!isPos(pKw)) return showError('hw_elec_result', 'Enter a heater power greater than zero.');
  if (!isNum(ambientC)) return showError('hw_elec_result', 'Enter an ambient temperature.');

  const pTotal = pKw * 1000;
  const phaseVoltage = hwPhaseVoltage(vll, phase, conn);
  const legR = hwLegResistance(pTotal, vll, phase, conn);
  const lineCurrent = hwLineCurrent(pTotal, vll, phase);
  const legPower = phase === '1ph' ? pTotal : pTotal / 3;
  const legCurrent = phase === '1ph' ? lineCurrent : (conn === 'wye' ? lineCurrent : lineCurrent / HW_SQRT3);
  const elementInfo = hwElementFromLeg(legR, legCurrent, phaseVoltage, legPower, n, arrangement);

  const insulTemp = INSULATION_TYPES[insulation] ? INSULATION_TYPES[insulation].tempRating : 90;
  const required = lineCurrent * 1.25;
  const cond = xePickConductor(required, material, insulTemp, terminationTemp, ambientC, ccc);
  const ocpd = nextStandardOCPD(required);

  hwLastElectrical = {
    phase, conn, vll, pKw, n, arrangement, phaseVoltage, legR, lineCurrent,
    legPower, legCurrent, elementInfo,
  };

  el.className = 'result show';
  const matLabel = material === 'al' ? 'Al' : 'Cu';

  wtHeading(el, 'System');
  wtRow(el, 'Total power', fmt(pKw, 2) + ' kW (' + fmt(pKw, 2) + ' kVA, PF ≈ 1.0 resistive)', { bold: true, color: PASS_COLOR });
  wtRow(el, 'Configuration', (phase === '1ph' ? '1Ø' : '3Ø') + (phase === '1ph' ? '' : ' ' + (conn === 'wye' ? 'Wye' : 'Delta')) + ', ' + fmt(vll, 0) + ' V line');
  wtRow(el, 'Line current', fmt(lineCurrent, 2) + ' A', { bold: true });
  if (phase !== '1ph') {
    wtRow(el, phase === '1ph' ? 'Voltage' : (conn === 'wye' ? 'Phase voltage (L-N)' : 'Leg voltage (L-L)'), fmt(phaseVoltage, 2) + ' V');
    wtRow(el, 'Per-leg current', fmt(legCurrent, 2) + ' A');
    wtRow(el, 'Per-leg resistance', fmt(legR, 4) + ' Ω');
    wtRow(el, 'Per-leg power', fmt(legPower, 0) + ' W');
  }

  wtHeading(el, n > 1 ? 'Per element (' + n + ' ' + arrangement + ' per leg)' : 'Element');
  wtRow(el, 'Resistance', fmt(elementInfo.resistance, 4) + ' Ω', { bold: true, color: PASS_COLOR });
  wtRow(el, 'Voltage', fmt(elementInfo.voltage, 2) + ' V');
  wtRow(el, 'Current', fmt(elementInfo.current, 2) + ' A');
  wtRow(el, 'Power', fmt(elementInfo.power, 0) + ' W');

  wtHeading(el, 'Branch circuit (this leg)');
  wtRow(el, 'Continuous-load requirement', fmt(lineCurrent, 2) + ' A × 1.25 = ' + fmt(required, 2) + ' A');
  if (cond) {
    wtRow(el, 'Conductor', wireSizeLabel(cond.size) + ' ' + matLabel, { bold: true });
    wtRow(el, 'Usable ampacity', fmt(cond.usable, 1) + ' A');
  } else {
    wtRow(el, 'Conductor', 'No standard size up to 1000 kcmil carries ' + fmt(required, 1) + ' A under these conditions.', { color: FAIL_COLOR });
  }
  wtRow(el, 'OCPD', ocpd ? ocpd + ' A' : '—', { bold: true });

  const svgWrap = document.createElement('div');
  svgWrap.className = 'calculation-visual';
  const svgTitle = document.createElement('p');
  svgTitle.className = 'visual-title';
  svgTitle.textContent = phase === '1ph' ? 'Circuit' : (conn === 'wye' ? 'Wye connection' : 'Delta connection');
  svgWrap.appendChild(svgTitle);
  svgWrap.appendChild(hwBuildWiringSvg({
    phase, conn,
    vFmt: fmt(phaseVoltage, 1) + ' V',
    iFmt: fmt(lineCurrent, 1) + ' A',
    rFmt: fmt(legR, 3) + ' Ω',
  }));
  el.appendChild(svgWrap);

  wtNote(el, 'Assumes a balanced resistive load (PF ≈ 1.0) — SCR phase-angle firing or other non-linear control changes the effective RMS relationships and is not modeled here. Sizing shown is the general 125%-continuous-load branch-circuit practice (NEC 210.19(A)(1)/210.20(A), 422.10(A) for utilization equipment). If this heater is specifically "fixed electric space-heating equipment," also check NEC Article 424 Part III for its own branch-circuit and overcurrent provisions, which can differ from the general rule used here.');

  buildElectricalProof({
    phase, conn, vll, pTotal, phaseVoltage, legR, lineCurrent, legPower, legCurrent,
    n, arrangement, elementInfo, required, cond, ocpd, matLabel, insulTemp,
    terminationTemp, ambientC, ccc,
  });

  if (typeof writeUrlState === 'function') writeUrlState('sec-heater-wizard');
  appendCopyBtn(el);
};

function buildElectricalProof(d) {
  const host = document.getElementById('hw_elec_proof_body');
  if (!host) return;
  host.textContent = '';
  const step = function (n, title, lines, ref) {
    const wrap = document.createElement('div');
    wrap.className = 'xe-step';
    const h = document.createElement('div');
    h.className = 'xe-step-head';
    h.textContent = n + '. ' + title;
    wrap.appendChild(h);
    lines.forEach(function (l) {
      const p = document.createElement('div');
      p.className = 'xe-step-line';
      p.textContent = l;
      wrap.appendChild(p);
    });
    if (ref) {
      const r = document.createElement('div');
      r.className = 'xe-step-ref';
      r.textContent = ref;
      wrap.appendChild(r);
    }
    host.appendChild(wrap);
  };

  if (d.phase === '1ph') {
    step(1, 'Resistance and current', [
      'R = V² / P = ' + fmt(d.vll, 0) + '² / ' + fmt(d.pTotal, 0) + ' = ' + fmt(d.legR, 4) + ' Ω',
      'I = P / V = ' + fmt(d.pTotal, 0) + ' / ' + fmt(d.vll, 0) + ' = ' + fmt(d.lineCurrent, 3) + ' A',
    ], 'Ohm\'s law / P = VI for a resistive load');
  } else {
    step(1, 'Phase voltage', [
      d.conn === 'wye'
        ? 'Wye: V_phase = V_LL / √3 = ' + fmt(d.vll, 0) + ' / 1.732 = ' + fmt(d.phaseVoltage, 2) + ' V'
        : 'Delta: V_leg = V_LL = ' + fmt(d.phaseVoltage, 2) + ' V',
    ]);
    step(2, 'Leg resistance for ' + fmt(d.pTotal / 1000, 2) + ' kW total', [
      d.conn === 'wye'
        ? 'R_leg = V_LL² / P_total = ' + fmt(d.vll, 0) + '² / ' + fmt(d.pTotal, 0) + ' = ' + fmt(d.legR, 4) + ' Ω'
        : 'R_leg = 3 × V_LL² / P_total = 3 × ' + fmt(d.vll, 0) + '² / ' + fmt(d.pTotal, 0) + ' = ' + fmt(d.legR, 4) + ' Ω',
    ], 'Balanced 3-phase resistive load, PF = 1');
    step(3, 'Line current', [
      'I_line = P_total / (√3 × V_LL) = ' + fmt(d.pTotal, 0) + ' / (1.732 × ' + fmt(d.vll, 0) + ') = ' + fmt(d.lineCurrent, 3) + ' A',
      '(identical formula for wye or delta — only the internal leg voltage/current split differs)',
    ]);
  }
  if (d.n > 1) {
    step(4, 'Per-element split (' + d.n + ' ' + d.arrangement + ')', [
      d.arrangement === 'series'
        ? 'Series: R_element = R_leg / n = ' + fmt(d.legR, 4) + ' / ' + d.n + ' = ' + fmt(d.elementInfo.resistance, 4) + ' Ω, current unchanged'
        : 'Parallel: R_element = R_leg × n = ' + fmt(d.legR, 4) + ' × ' + d.n + ' = ' + fmt(d.elementInfo.resistance, 4) + ' Ω, voltage unchanged',
    ]);
  }
  step(5, 'Branch-circuit conductor', [
    'Required ampacity = ' + fmt(d.lineCurrent, 3) + ' A × 1.25 = ' + fmt(d.required, 3) + ' A',
    d.cond
      ? 'Selected: ' + wireSizeLabel(d.cond.size) + ' ' + d.matLabel + ' — Table 310.16 at ' + d.insulTemp + '°C = ' + d.cond.base +
        ' A, × ambient ' + d.cond.ambient.toFixed(2) + ' × bundling ' + d.cond.bundle.toFixed(2) +
        ' = ' + fmt(d.cond.derated, 2) + ' A, capped at ' + d.terminationTemp + '°C termination = ' + fmt(d.cond.usable, 2) + ' A'
      : 'No standard conductor up to 1000 kcmil satisfies this ampacity under the stated conditions.',
    'OCPD: next standard rating ≥ ' + fmt(d.required, 2) + ' A = ' + (d.ocpd || '—') + ' A',
  ], 'NEC 210.19(A)(1)/210.20(A) and 422.10(A) — 125% of a continuous load; Table 310.16, 310.15(B)(1), 310.15(C)(1), 110.14(C); 240.6(A) standard ratings');
}

window.toggleHwElecProof = function () {
  const body = document.getElementById('hw_elec_proof');
  const btn = document.getElementById('hw_elec_proof_btn');
  if (!body) return;
  const open = body.hasAttribute('hidden');
  if (open) body.removeAttribute('hidden'); else body.setAttribute('hidden', '');
  if (btn) {
    btn.setAttribute('aria-expanded', String(open));
    btn.textContent = open ? '▾ Hide step-by-step proof' : '▸ Show step-by-step proof';
  }
};

/* ---------------------------------------------------------------------------
   Main entry point — Element design
   --------------------------------------------------------------------------- */
window.calcHeaterElement = function () {
  const el = wtClear('hw_elem_result');
  if (!el) return;
  const proof = document.getElementById('hw_elem_proof_body');
  if (proof) proof.textContent = '';

  const targetR = val('hw_target_r');
  const targetP = val('hw_target_p');
  const resistivity = val('hw_resistivity');
  const awg = Math.round(val('hw_awg'));
  const mandrelMm = val('hw_mandrel');
  const pitchMm = val('hw_pitch_mm');

  if (!isPos(targetR)) return showError('hw_elem_result', 'Enter a target resistance greater than zero.');
  if (!isPos(targetP)) return showError('hw_elem_result', 'Enter a target power greater than zero.');
  if (!isPos(resistivity)) return showError('hw_elem_result', 'Enter an alloy resistivity greater than zero.');
  if (!isNum(awg)) return showError('hw_elem_result', 'Enter a wire gauge (AWG).');

  const design = hwElementDesign(targetR, targetP, resistivity, awg);

  el.className = 'result show';
  wtHeading(el, 'Wire');
  wtRow(el, 'Gauge', awg + ' AWG', { bold: true });
  wtRow(el, 'Diameter', fmt(design.diameterIn, 4) + ' in (' + fmt(design.diameterMm, 3) + ' mm)');
  wtRow(el, 'Cross-section', fmt(design.areaMm2, 4) + ' mm² (' + fmt(design.areaCmil, 0) + ' cmil)');
  wtRow(el, 'Resistance per length', fmt(design.resPerFoot, 4) + ' Ω/ft (' + fmt(design.resPerMeter, 4) + ' Ω/m)');

  wtHeading(el, 'Required length for ' + fmt(targetR, 3) + ' Ω');
  wtRow(el, 'Length', fmt(design.lengthFt, 2) + ' ft (' + fmt(design.lengthM, 3) + ' m)', { bold: true, color: PASS_COLOR });

  wtHeading(el, 'Operating point at ' + fmt(targetP, 0) + ' W');
  wtRow(el, 'Current', fmt(design.current, 3) + ' A');
  wtRow(el, 'Voltage', fmt(design.voltage, 2) + ' V');
  wtRow(el, 'Current density', fmt(design.currentDensity, 3) + ' A/mm²');
  wtRow(el, 'Wire surface area', fmt(design.surfaceAreaIn2, 2) + ' in² (' + fmt(design.surfaceAreaCm2, 1) + ' cm²)');
  wtRow(el, 'Surface power density', fmt(design.powerDensityWIn2, 2) + ' W/in² (' + fmt(design.powerDensityWCm2, 2) + ' W/cm²)', { bold: true });

  let geom = null;
  if (isPos(mandrelMm)) {
    geom = hwCoilGeometry(design.lengthM, design.diameterMm, mandrelMm, pitchMm);
    wtHeading(el, 'Coil on a ' + fmt(mandrelMm, 1) + ' mm mandrel');
    wtRow(el, 'Turns', fmt(geom.turns, 1));
    wtRow(el, 'Wound length', fmt(geom.coilLengthMm / 25.4, 2) + ' in (' + fmt(geom.coilLengthMm, 1) + ' mm)');
  }

  const gaugeRows = HW_AWG_LIST.map((g) => hwElementDesign(targetR, targetP, resistivity, g));
  wtHeading(el, 'Gauge comparison at the same resistance and power');
  const table = document.createElement('div');
  table.className = 'parts-table-wrap';
  table.setAttribute('tabIndex', '0');
  table.setAttribute('role', 'region');
  table.setAttribute('aria-label', 'Wire gauge comparison table');
  const tbl = document.createElement('table');
  tbl.className = 'ref-table';
  const head = document.createElement('tr');
  ['AWG', 'Diameter (in)', 'Length (ft)', 'Current density (A/mm²)', 'Power density (W/in²)'].forEach((h) => {
    const th = document.createElement('th');
    th.textContent = h;
    head.appendChild(th);
  });
  tbl.appendChild(head);
  gaugeRows.forEach((r) => {
    const tr = document.createElement('tr');
    if (r.awg === awg) tr.style.color = '#f59e0b';
    [r.awg + (r.awg === awg ? ' ←' : ''), fmt(r.diameterIn, 4), fmt(r.lengthFt, 1), fmt(r.currentDensity, 3), fmt(r.powerDensityWIn2, 2)].forEach((v) => {
      const td = document.createElement('td');
      td.textContent = String(v);
      tr.appendChild(td);
    });
    tbl.appendChild(tr);
  });
  table.appendChild(tbl);
  el.appendChild(table);

  const chart = hwBuildGaugeChart(gaugeRows, awg);
  if (chart) {
    const chartWrap = document.createElement('div');
    chartWrap.className = 'calculation-visual';
    const title = document.createElement('p');
    title.className = 'visual-title';
    title.textContent = 'Surface power density by gauge';
    chartWrap.appendChild(title);
    chartWrap.appendChild(chart);
    el.appendChild(chartWrap);
  }

  if (geom) {
    const coilWrap = document.createElement('div');
    coilWrap.className = 'calculation-visual';
    const title = document.createElement('p');
    title.className = 'visual-title';
    title.textContent = 'Coil winding';
    coilWrap.appendChild(title);
    coilWrap.appendChild(hwBuildCoilSvg(geom));
    el.appendChild(coilWrap);
  }

  wtNote(el, 'Resistivity, maximum element temperature and any power-density guidance are typical published figures for reference, not measured properties of a specific spool of wire — alloy composition, temper and manufacturer vary. Confirm the resistance-per-length figure against your wire supplier\'s own datasheet before fabricating a heating element, especially for safety-critical or high-power applications. Reasonable open-air surface loading for wound elements is commonly cited in roughly the 5-15 W/in² range in still air and higher with forced convection — this varies enormously with application, ambient temperature, alloy and duty cycle and is not a pass/fail check here.');

  buildElementProof({ targetR, targetP, resistivity, awg, design, geom, mandrelMm });

  if (typeof writeUrlState === 'function') writeUrlState('sec-heater-wizard');
  appendCopyBtn(el);
};

function buildElementProof(d) {
  const host = document.getElementById('hw_elem_proof_body');
  if (!host) return;
  host.textContent = '';
  const step = function (n, title, lines, ref) {
    const wrap = document.createElement('div');
    wrap.className = 'xe-step';
    const h = document.createElement('div');
    h.className = 'xe-step-head';
    h.textContent = n + '. ' + title;
    wrap.appendChild(h);
    lines.forEach(function (l) {
      const p = document.createElement('div');
      p.className = 'xe-step-line';
      p.textContent = l;
      wrap.appendChild(p);
    });
    if (ref) {
      const r = document.createElement('div');
      r.className = 'xe-step-ref';
      r.textContent = ref;
      wrap.appendChild(r);
    }
    host.appendChild(wrap);
  };
  step(1, 'Wire geometry (AWG ' + d.awg + ')', [
    'd = 0.005 × 92^((36 − ' + d.awg + ') / 39) = ' + fmt(d.design.diameterIn, 5) + ' in = ' + fmt(d.design.diameterMm, 4) + ' mm',
    'A = (π/4) × d² = ' + fmt(d.design.areaMm2, 5) + ' mm²',
  ], 'American Wire Gauge standard definition');
  step(2, 'Resistance per length', [
    'R\' = ρ / A = ' + fmt(d.resistivity, 3) + ' / ' + fmt(d.design.areaMm2, 5) + ' = ' + fmt(d.design.resPerMeter, 4) + ' Ω/m',
  ], 'ρ in Ω·mm²/m — the resistance of a 1 m length of 1 mm² cross-section');
  step(3, 'Length for ' + fmt(d.targetR, 3) + ' Ω', [
    'L = R / R\' = ' + fmt(d.targetR, 3) + ' / ' + fmt(d.design.resPerMeter, 4) + ' = ' + fmt(d.design.lengthM, 3) + ' m = ' + fmt(d.design.lengthFt, 2) + ' ft',
  ]);
  step(4, 'Operating point at ' + fmt(d.targetP, 0) + ' W', [
    'I = √(P / R) = √(' + fmt(d.targetP, 0) + ' / ' + fmt(d.targetR, 3) + ') = ' + fmt(d.design.current, 3) + ' A',
    'V = I × R = ' + fmt(d.design.voltage, 2) + ' V',
    'Surface area = π × d × L = ' + fmt(d.design.surfaceAreaIn2, 2) + ' in²',
    'Power density = P / area = ' + fmt(d.design.powerDensityWIn2, 2) + ' W/in²',
  ]);
  if (d.geom) {
    step(5, 'Coil geometry', [
      'Mean coil Ø = mandrel Ø + wire Ø = ' + fmt(d.mandrelMm, 1) + ' + ' + fmt(d.design.diameterMm, 3) + ' = ' + fmt(d.geom.meanCoilDiameterMm, 2) + ' mm',
      'Turns = L / (π × mean Ø) = ' + fmt(d.design.lengthM * 1000, 1) + ' / (π × ' + fmt(d.geom.meanCoilDiameterMm, 2) + ') = ' + fmt(d.geom.turns, 2),
    ]);
  }
}

window.toggleHwElemProof = function () {
  const body = document.getElementById('hw_elem_proof');
  const btn = document.getElementById('hw_elem_proof_btn');
  if (!body) return;
  const open = body.hasAttribute('hidden');
  if (open) body.removeAttribute('hidden'); else body.setAttribute('hidden', '');
  if (btn) {
    btn.setAttribute('aria-expanded', String(open));
    btn.textContent = open ? '▾ Hide step-by-step proof' : '▸ Show step-by-step proof';
  }
};

/* ---------------------------------------------------------------------------
   UI glue
   --------------------------------------------------------------------------- */
window.hwOnPhaseChange = function () {
  const phase = document.getElementById('hw_phase').value;
  const wrap = document.getElementById('hw_conn_wrap');
  if (wrap) wrap.style.display = phase === '1ph' ? 'none' : '';
};

window.hwOnAlloyChange = function () {
  const key = document.getElementById('hw_alloy').value;
  const alloy = HW_ALLOYS[key];
  if (!alloy) return;
  const rEl = document.getElementById('hw_resistivity');
  const tEl = document.getElementById('hw_maxtemp');
  if (rEl) rEl.value = alloy.resistivity;
  if (tEl) tEl.value = alloy.maxTemp;
};

/** Copies the just-computed per-element resistance and power from the
    electrical sizing calculator into the element designer's inputs. */
window.hwUseElectricalForElement = function () {
  if (!hwLastElectrical) {
    showError('hw_elem_result', 'Run the electrical sizing calculator above first.');
    return;
  }
  const r = document.getElementById('hw_target_r');
  const p = document.getElementById('hw_target_p');
  if (r) r.value = hwLastElectrical.elementInfo.resistance.toFixed(4);
  if (p) p.value = Math.round(hwLastElectrical.elementInfo.power);
  const section = document.getElementById('hw_element_card');
  if (section && section.scrollIntoView) section.scrollIntoView({ behavior: 'smooth', block: 'start' });
};

document.addEventListener('DOMContentLoaded', function () {
  if (!document.getElementById('hw_elec_result')) return;
  hwOnPhaseChange();
  hwOnAlloyChange();
  const phaseSel = document.getElementById('hw_phase');
  if (phaseSel) phaseSel.addEventListener('change', hwOnPhaseChange);
  const alloySel = document.getElementById('hw_alloy');
  if (alloySel) alloySel.addEventListener('change', hwOnAlloyChange);

  if (typeof registerUrlState === 'function') {
    registerUrlState('sec-heater-wizard', 'heater-wizard', function () {
      try { calcHeaterElectrical(); } catch (e) { /* fields not ready */ }
      try { calcHeaterElement(); } catch (e) { /* fields not ready */ }
    });
  }

  if (typeof registerReport === 'function') {
    registerReport('hw_elec_result', {
      title: 'Heater Electrical Sizing',
      formula: function () {
        return 'Wye: R_leg = V_LL² / P   |   Delta: R_leg = 3 × V_LL² / P   |   ' +
          'I_line = P / (√3 × V_LL) for 3-phase, P / V for 1-phase   |   Conductor at 125% of I_line';
      },
      codeRefs: function () {
        return [
          'Balanced three-phase resistive load relations (PF = 1)',
          'NEC 210.19(A)(1) / 210.20(A) — 125% of a continuous load',
          'NEC 422.10(A) — branch-circuit conductors for utilization equipment at 125% of connected load',
          'NEC Article 424 Part III — check separately if this is fixed electric space-heating equipment',
          'NEC Table 310.16, 310.15(B)(1), 310.15(C)(1), 110.14(C) — conductor selection',
          'NEC 240.6(A) — standard overcurrent device ratings',
        ];
      },
    });
    registerReport('hw_elem_result', {
      title: 'Custom Heating Element Design',
      formula: function () {
        return 'd = 0.005 × 92^((36 − AWG) / 39) in   |   R\' = ρ / A   |   L = R / R\'   |   ' +
          'I = √(P / R)   |   Power density = P / (π × d × L)';
      },
      codeRefs: function () {
        return [
          'American Wire Gauge standard definition (ANSI/ASTM B258)',
          'ρ (alloy resistivity) is a typical published reference value — confirm against the wire manufacturer\'s datasheet',
          'Ohm\'s law and P = I²R = V²/R for a resistive element',
        ];
      },
    });
  }
});

if (typeof window !== 'undefined' && window.__ENABLE_HEATER_WIZARD_TEST_API__) {
  window.__heaterWizardTestApi = {
    hwAwgDiameterIn, hwAwgDiameterMm, hwAwgAreaMm2, hwAwgAreaCmil,
    hwPhaseVoltage, hwLegResistance, hwLineCurrent, hwElementFromLeg,
    hwElementDesign, hwCoilGeometry, HW_ALLOYS, HW_AWG_LIST,
  };
}
