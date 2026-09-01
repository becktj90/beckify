/* ============================================================================
   555 TIMER CALCULATOR
   ============================================================================
   Astable (free-running oscillator) and monostable (one-shot) modes.

   The 555 charges the timing capacitor toward Vcc and switches at two internal
   comparator thresholds set by its resistor divider: 2/3 Vcc (upper) and
   1/3 Vcc (lower). The RC interval between those thresholds is
   ln(2) = 0.6931 time constants, which is where every coefficient below comes
   from — the familiar 1.1 and 0.693 are not empirical fudge factors.

   Astable:    charge through R1+R2, discharge through R2 alone
                 t_high = ln(2) x (R1 + R2) x C
                 t_low  = ln(2) x R2 x C
   Monostable: one charge interval through R
                 t      = ln(2) x ... no: the one-shot runs 0 -> 2/3 Vcc,
                          which is ln(3) = 1.0986 time constants
                 t      = 1.1 x R x C
   ============================================================================ */

const LN2 = Math.LN2;         // 0.693147 — astable threshold-to-threshold
const LN3 = Math.log(3);      // 1.098612 — monostable 0 to 2/3 Vcc

/* Unit multipliers to base ohms / farads. */
const R_UNITS = { ohm: 1, k: 1e3, M: 1e6 };
const C_UNITS = { uF: 1e-6, nF: 1e-9, pF: 1e-12 };

/** Human-readable time with an appropriate unit. */
function fmtTime(seconds) {
  if (!isFinite(seconds) || seconds <= 0) return '—';
  if (seconds >= 1) return fmt(seconds, 4) + ' s';
  if (seconds >= 1e-3) return fmt(seconds * 1e3, 4) + ' ms';
  if (seconds >= 1e-6) return fmt(seconds * 1e6, 4) + ' µs';
  return fmt(seconds * 1e9, 4) + ' ns';
}

/** Human-readable frequency. */
function fmtFreq(hz) {
  if (!isFinite(hz) || hz <= 0) return '—';
  if (hz >= 1e6) return fmt(hz / 1e6, 4) + ' MHz';
  if (hz >= 1e3) return fmt(hz / 1e3, 4) + ' kHz';
  return fmt(hz, 4) + ' Hz';
}

function readR(valueId, unitId) {
  const v = val(valueId);
  const u = document.getElementById(unitId);
  const mult = R_UNITS[u ? u.value : 'k'] || 1;
  return v * mult;
}

function readC(valueId, unitId) {
  const v = val(valueId);
  const u = document.getElementById(unitId);
  const mult = C_UNITS[u ? u.value : 'uF'] || 1e-6;
  return v * mult;
}

/* ---------------------------------------------------------------------------
   Waveform — output pulse train over the capacitor's charge/discharge ramp
   --------------------------------------------------------------------------- */
function drawAstableWave(tHigh, tLow) {
  const host = document.getElementById('t555_wave');
  if (!host) return;
  host.textContent = '';

  const W = 560, H = 190, padL = 44, padR = 12, padT = 14, padB = 26;
  const plotW = W - padL - padR;
  const period = tHigh + tLow;
  if (!isFinite(period) || period <= 0) return;

  // Show two full cycles so the duty cycle is visually obvious.
  const cycles = 2;
  const total = period * cycles;
  const x = (t) => padL + (t / total) * plotW;

  const NS = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
  svg.setAttribute('width', '100%');
  svg.setAttribute('role', 'img');
  svg.setAttribute('aria-label',
    'Output waveform: ' + fmtTime(tHigh) + ' high, ' + fmtTime(tLow) + ' low, ' +
    'duty cycle ' + fmt((tHigh / period) * 100, 1) + ' percent.');

  const mk = (tag, attrs) => {
    const e = document.createElementNS(NS, tag);
    for (const k in attrs) e.setAttribute(k, attrs[k]);
    return e;
  };

  // Bands: output (top) and capacitor voltage (bottom)
  const outTop = padT, outBot = padT + 54;
  const capTop = padT + 78, capBot = H - padB;

  svg.appendChild(mk('text', { x: 4, y: outTop + 14, fill: '#9497b8', 'font-size': '9' }));
  svg.lastChild.textContent = 'OUT';
  svg.appendChild(mk('text', { x: 4, y: capTop + 14, fill: '#9497b8', 'font-size': '9' }));
  svg.lastChild.textContent = 'Vc';

  // Threshold guides at 1/3 and 2/3 Vcc
  const vAt = (frac) => capBot - frac * (capBot - capTop);
  [[2 / 3, '2/3 Vcc'], [1 / 3, '1/3 Vcc']].forEach(function (g) {
    const yy = vAt(g[0]);
    svg.appendChild(mk('line', {
      x1: padL, y1: yy, x2: W - padR, y2: yy,
      stroke: '#4f8bff', 'stroke-width': '0.8', 'stroke-dasharray': '3 3', opacity: '0.55',
    }));
    const t = mk('text', { x: W - padR - 2, y: yy - 3, fill: '#4f8bff', 'font-size': '8', 'text-anchor': 'end' });
    t.textContent = g[1];
    svg.appendChild(t);
  });

  // Output square wave + capacitor ramp
  let outD = 'M ' + padL + ' ' + outBot;
  let capD = '';
  for (let c = 0; c < cycles; c++) {
    const t0 = c * period;
    const xa = x(t0), xb = x(t0 + tHigh), xc = x(t0 + period);
    // OUT: high for tHigh, low for tLow
    outD += ' L ' + xa + ' ' + outTop + ' L ' + xb + ' ' + outTop +
            ' L ' + xb + ' ' + outBot + ' L ' + xc + ' ' + outBot;
    // Vc: exponential charge 1/3 -> 2/3 while high, discharge 2/3 -> 1/3 while low
    const STEPS = 26;
    for (let i = 0; i <= STEPS; i++) {
      const f = i / STEPS;
      const v = 1 / 3 + (2 / 3 - 1 / 3) * (1 - Math.exp(-LN2 * f)) / (1 - Math.exp(-LN2));
      const px = xa + (xb - xa) * f;
      capD += (capD ? ' L ' : 'M ') + px + ' ' + vAt(v);
    }
    for (let i = 0; i <= STEPS; i++) {
      const f = i / STEPS;
      const v = 2 / 3 - (2 / 3 - 1 / 3) * (1 - Math.exp(-LN2 * f)) / (1 - Math.exp(-LN2));
      const px = xb + (xc - xb) * f;
      capD += ' L ' + px + ' ' + vAt(v);
    }
  }

  svg.appendChild(mk('path', { d: capD, fill: 'none', stroke: '#f5c451', 'stroke-width': '1.6' }));
  svg.appendChild(mk('path', { d: outD, fill: 'none', stroke: '#6ee7b7', 'stroke-width': '2' }));

  // Interval brackets on the first cycle
  const label = (x1, x2, text, colour) => {
    const yy = H - padB + 12;
    svg.appendChild(mk('line', { x1: x1, y1: yy - 5, x2: x1, y2: yy, stroke: colour, 'stroke-width': '1' }));
    svg.appendChild(mk('line', { x1: x2, y1: yy - 5, x2: x2, y2: yy, stroke: colour, 'stroke-width': '1' }));
    svg.appendChild(mk('line', { x1: x1, y1: yy, x2: x2, y2: yy, stroke: colour, 'stroke-width': '1' }));
    const t = mk('text', { x: (x1 + x2) / 2, y: yy - 7, fill: colour, 'font-size': '8', 'text-anchor': 'middle' });
    t.textContent = text;
    svg.appendChild(t);
  };
  label(x(0), x(tHigh), 't1 ' + fmtTime(tHigh), '#6ee7b7');
  label(x(tHigh), x(period), 't2 ' + fmtTime(tLow), '#f5c451');

  host.appendChild(svg);
}

/* ---------------------------------------------------------------------------
   Astable
   --------------------------------------------------------------------------- */
window.calc555Astable = function () {
  const el = wtClear('t555_a_result');
  if (!el) return;

  const R1 = readR('t555_r1', 't555_r1_u');
  const R2 = readR('t555_r2', 't555_r2_u');
  const C = readC('t555_c', 't555_c_u');
  const useDiode = document.getElementById('t555_diode').checked;

  if (!isPos(R1)) return showError('t555_a_result', 'R1 must be greater than zero.');
  if (!isPos(R2)) return showError('t555_a_result', 'R2 must be greater than zero.');
  if (!isPos(C)) return showError('t555_a_result', 'C must be greater than zero.');

  /* With the classic bipolar 555, the capacitor charges through R1+R2 but
     discharges through R2 only, so t_high can never be shorter than t_low and
     the duty cycle is stuck above 50%. Bridging R2 with a diode lets the
     capacitor charge through R1 alone, which unlocks the sub-50% range. */
  const tHigh = useDiode ? LN2 * R1 * C : LN2 * (R1 + R2) * C;
  const tLow = LN2 * R2 * C;
  const period = tHigh + tLow;
  const freq = 1 / period;
  const duty = (tHigh / period) * 100;

  el.className = 'result show';

  wtHeading(el, 'Timing');
  wtRow(el, 'Time high (t1)', fmtTime(tHigh), { bold: true, color: '#6ee7b7' });
  wtRow(el, 'Time low (t2)', fmtTime(tLow), { bold: true, color: '#f5c451' });
  wtRow(el, 'Period (T = t1 + t2)', fmtTime(period));
  wtRow(el, 'Frequency (f = 1/T)', fmtFreq(freq), { bold: true, color: PASS_COLOR });
  wtRow(el, 'Duty cycle', fmt(duty, 2) + ' %', { bold: true });

  wtHeading(el, 'Formula used');
  wtRow(el, 't1 (high)', useDiode ? 't1 = ln(2) × R1 × C' : 't1 = ln(2) × (R1 + R2) × C');
  wtRow(el, 't2 (low)', 't2 = ln(2) × R2 × C');
  wtRow(el, 'Frequency', 'f = 1.44 / ((R1 + 2·R2) × C)');
  wtRow(el, 'Duty cycle', useDiode ? 'D = R1 / (R1 + R2)' : 'D = (R1 + R2) / (R1 + 2·R2)');

  /* ── Sanity checks ── */
  const notes = [];
  if (!useDiode && duty <= 50.0001) {
    notes.push('Duty cycle cannot reach 50% or below in the standard configuration — ' +
      'the capacitor charges through R1+R2 but discharges through R2 alone, so t1 > t2 always.');
  }
  if (!useDiode && duty < 55) {
    notes.push('A duty cycle this close to 50% needs R1 much smaller than R2, which ' +
      'pushes R1 toward the discharge transistor’s limit. Tick the diode option to ' +
      'decouple charge and discharge paths instead.');
  }
  if (useDiode) {
    notes.push('Diode across R2: charge path is R1 only, discharge is R2 only, so any ' +
      'duty cycle from near 0% to near 100% is reachable. Allow for the diode’s ' +
      '~0.6 V drop, which lengthens t1 slightly versus the ideal figure above.');
  }
  const totalR = R1 + R2;
  if (totalR < 1000) {
    notes.push('R1 + R2 below 1 kΩ draws heavy current through the discharge transistor. ' +
      'Most datasheets call for R1 ≥ 1 kΩ.');
  }
  if (totalR > 10e6) {
    notes.push('Above about 10 MΩ the timing is dominated by the trigger/threshold bias ' +
      'currents and capacitor leakage, so the real period will drift from the calculation.');
  }
  if (C < 1e-9) {
    notes.push('Below roughly 1 nF, stray board capacitance becomes a significant ' +
      'fraction of C and the frequency will read high.');
  }
  if (freq > 500e3) {
    notes.push('Beyond a few hundred kHz the standard bipolar NE555 loses accuracy; ' +
      'a CMOS part (7555/TLC555) holds up better.');
  }

  if (notes.length) {
    wtHeading(el, 'Design notes');
    notes.forEach(function (n) { wtNote(el, n); });
  }

  drawAstableWave(tHigh, tLow);
  appendCopyBtn(el);
};

/* ---------------------------------------------------------------------------
   Monostable
   --------------------------------------------------------------------------- */
window.calc555Monostable = function () {
  const el = wtClear('t555_m_result');
  if (!el) return;

  const R = readR('t555_mr', 't555_mr_u');
  const C = readC('t555_mc', 't555_mc_u');

  if (!isPos(R)) return showError('t555_m_result', 'R must be greater than zero.');
  if (!isPos(C)) return showError('t555_m_result', 'C must be greater than zero.');

  // One-shot: the capacitor runs from 0 to 2/3 Vcc, which is ln(3) = 1.0986 RC.
  const t = LN3 * R * C;

  el.className = 'result show';
  wtHeading(el, 'Output pulse');
  wtRow(el, 'Pulse width (t)', fmtTime(t), { bold: true, color: PASS_COLOR });
  wtRow(el, 'Maximum retrigger rate', fmtFreq(1 / t) + '  (one pulse per period)');

  wtHeading(el, 'Formula used');
  wtRow(el, 'Pulse width', 't = 1.1 × R × C');
  wtRow(el, 'Where 1.1 comes from', 'ln(3) = 1.0986 — the capacitor runs 0 → 2/3 Vcc');

  const notes = [];
  if (R < 1000) notes.push('R below 1 kΩ overloads the discharge transistor; most datasheets call for R ≥ 1 kΩ.');
  if (R > 10e6) notes.push('Above about 10 MΩ, bias currents and capacitor leakage dominate and the pulse will run short.');
  if (C >= 1e-5) notes.push('Large electrolytics have wide tolerance and significant leakage — expect the real pulse to differ noticeably from the calculated value.');
  notes.push('The trigger pulse must be shorter than the output pulse, and the trigger input has to return above 1/3 Vcc before the period ends or the output stays high.');
  wtHeading(el, 'Design notes');
  notes.forEach(function (n) { wtNote(el, n); });

  appendCopyBtn(el);
};

window.load555DocExample = function () {
  var astable = {
    t555_r1: '10',
    t555_r1_u: 'k',
    t555_r2: '47',
    t555_r2_u: 'k',
    t555_c: '0.1',
    t555_c_u: 'uF'
  };
  Object.keys(astable).forEach(function (id) {
    var el = document.getElementById(id);
    if (el) el.value = astable[id];
  });
  var diode = document.getElementById('t555_diode');
  if (diode) diode.checked = false;
  window.calc555Astable();
};

/* Register richer report metadata than the generic scraper can infer. */
document.addEventListener('DOMContentLoaded', function () {
  if (typeof registerReport !== 'function') return;
  registerReport('t555_a_result', {
    title: '555 Timer — Astable',
    formula: function () {
      const d = document.getElementById('t555_diode');
      return (d && d.checked)
        ? 't1 = ln(2) x R1 x C   |   t2 = ln(2) x R2 x C   |   D = R1 / (R1 + R2)'
        : 't1 = ln(2) x (R1 + R2) x C   |   t2 = ln(2) x R2 x C   |   ' +
          'f = 1.44 / ((R1 + 2R2) x C)   |   D = (R1 + R2) / (R1 + 2R2)';
    },
    codeRefs: function () {
      return [
        'ln(2) = 0.6931 — interval between the 1/3 Vcc and 2/3 Vcc comparator thresholds',
        'Texas Instruments NE555 / LM555 datasheet, astable operation',
        'Standard configuration cannot reach 50% duty cycle or below without a diode across R2',
      ];
    },
  });
  registerReport('t555_m_result', {
    title: '555 Timer — Monostable',
    formula: function () { return 't = 1.1 x R x C   (1.1 = ln(3), the 0 to 2/3 Vcc charge interval)'; },
    codeRefs: function () {
      return [
        'ln(3) = 1.0986 — capacitor charge interval from 0 to the 2/3 Vcc threshold',
        'Texas Instruments NE555 / LM555 datasheet, monostable operation',
      ];
    },
  });
});
