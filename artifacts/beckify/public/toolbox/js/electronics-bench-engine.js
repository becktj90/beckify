/* ============================================================================
   ELECTRONICS BENCH — engine (port of the iOS Electronics Lab, BeckifyMath)
   ============================================================================
   Ideal lumped teaching models, not SPICE. Each circuit returns one solution
   object that drives BOTH the schematic and the breadboard, like the app:
     { circuit, headline, elements, nodes, branches, quantities, steps, notes }
   Schematic coordinates live on a 100 x 80 canvas (same as the app).
   Breadboard layouts are illustrative solderless hookups of the same nodes,
   audited for shorts, opens, clashes, and off-board holes.
   ============================================================================ */
(function (global) {
  'use strict';

  class CalcError extends Error {}
  const missing = (name) => new CalcError('Need ' + name + '. Type a number — this tool will not guess a blank.');
  const nonPositive = (name) => new CalcError(name + ' must be greater than zero. Zero, negatives, and empty are not usable here.');
  const outOfRange = (msg) => new CalcError(msg);

  /* ---------- number parsing / formatting ---------- */
  const SUFFIX = { T: 1e12, G: 1e9, M: 1e6, k: 1e3, K: 1e3, m: 1e-3, u: 1e-6, 'µ': 1e-6, 'μ': 1e-6, n: 1e-9, p: 1e-12 };
  function parseEngineering(raw) {
    const s = String(raw == null ? '' : raw).trim().replace(/\u2212/g, '-');
    if (!s) return null;
    const plain = /^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/;
    if (plain.test(s)) { const v = Number(s); return isFinite(v) ? v : null; }
    const last = s.slice(-1);
    if (!(last in SUFFIX)) return null;
    const head = s.slice(0, -1).trim();
    if (!plain.test(head)) return null;
    const v = Number(head) * SUFFIX[last];
    return isFinite(v) ? v : null;
  }
  function prefixFor(decade) {
    return { 12: 'T', 9: 'G', 6: 'M', 3: 'k', 0: '', '-3': 'm', '-6': 'µ', '-9': 'n', '-12': 'p' }[decade] || '';
  }
  function eng(value) {
    if (!isFinite(value)) return '—';
    const sign = value < 0 ? '-' : '';
    const mag = Math.abs(value);
    if (mag === 0) return '0';
    const decade = Math.min(12, Math.max(-12, Math.floor(Math.log10(mag) / 3) * 3));
    const scaled = mag / Math.pow(10, decade);
    const digits = scaled >= 100 ? 0 : scaled >= 10 ? 1 : 2;
    return sign + scaled.toFixed(digits) + prefixFor(decade);
  }
  function si(value, unit) {
    if (!isFinite(value)) return '—';
    const u = String(unit || '').trim();
    if (!u) return eng(value);
    const base = { A: 'A', V: 'V', W: 'W', 'Ω': 'Ω', ohm: 'Ω', Ohms: 'Ω', F: 'F', H: 'H', s: 's', Hz: 'Hz' }[u];
    if (!base) return eng(value) + ' ' + u;
    const mag = Math.abs(value);
    if (mag === 0) return '0 ' + base;
    const decade = Math.min(12, Math.max(-12, Math.floor(Math.log10(mag) / 3) * 3));
    const scaled = mag / Math.pow(10, decade);
    const digits = scaled >= 100 ? 0 : scaled >= 10 ? 1 : 2;
    return (value < 0 ? '-' : '') + scaled.toFixed(digits) + ' ' + prefixFor(decade) + base;
  }
  /** `4.70k` -> `4.7k` (breadboard part labels). */
  function trim(value) {
    const raw = eng(value);
    const m = /^(-?\d+)(\.\d+)?(.*)$/.exec(raw);
    if (!m) return raw;
    let frac = (m[2] || '').replace(/0+$/, '');
    if (frac === '.') frac = '';
    return m[1] + frac + m[3];
  }

  /* ---------- input helpers ---------- */
  function num(inputs, key, name) {
    const v = parseEngineering(inputs[key]);
    if (v === null) throw missing(name);
    return v;
  }
  const pos = (i, k, n) => { const v = num(i, k, n); if (!(isFinite(v) && v > 0)) throw nonPositive(n); return v; };
  const nonNeg = (i, k, n) => { const v = num(i, k, n); if (v < 0) throw outOfRange(n + ' cannot be negative.'); return v; };
  const finite = (i, k, n) => num(i, k, n);
  function choice(inputs, key, allowed, fallback, name) {
    const raw = String(inputs[key] == null ? '' : inputs[key]).trim();
    const v = raw || fallback;
    if (allowed.indexOf(v) < 0) throw outOfRange(name + ' is not a choice this circuit knows.');
    return v;
  }
  const acSource = (inputs) => choice(inputs, 'source', ['ac', 'dc'], 'ac', 'Source') === 'ac';
  function posIfPresent(inputs, key, name, fallback) {
    if (inputs[key] === undefined) return fallback;
    if (String(inputs[key]).trim() === '') throw missing(name);
    return pos(inputs, key, name);
  }

  /* ---------- complex helpers ---------- */
  const CX = (r, i) => ({ r, i, mag: Math.hypot(r, i), deg: Math.atan2(i, r) * 180 / Math.PI });
  const cxDiv = (a, b) => { const d = b.r * b.r + b.i * b.i; return CX((a.r * b.r + a.i * b.i) / d, (a.i * b.r - a.r * b.i) / d); };

  /* ---------- schematic element builders (app LabKit) ---------- */
  const P = (x, y) => ({ x, y });
  const part = (id, kind, label, detail, x1, y1, x2, y2, flags) => ({ id, part: kind, label, detail, a: P(x1, y1), b: P(x2, y2), flags: flags || 0 });
  const wire = (id, x1, y1, x2, y2) => part(id, 'wire', '', '', x1, y1, x2, y2);
  const res = (id, l, d, ...c) => part(id, 'resistor', l, d, ...c);
  const cap = (id, l, d, ...c) => part(id, 'capacitor', l, d, ...c);
  const ind = (id, l, d, ...c) => part(id, 'inductor', l, d, ...c);
  const src = (id, l, d, x1, y1, x2, y2, flags) => part(id, 'voltageSource', l, d, x1, y1, x2, y2, flags);
  const dio = (id, l, d, ...c) => part(id, 'diode', l, d, ...c);
  const ledPart = (id, l, d, ...c) => part(id, 'led', l, d, ...c);
  const gnd = (id, x, y) => part(id, 'ground', '', '', x, y, x, y);
  const node = (id, name, value, unit, x, y) => ({ id, name, value, unit, at: P(x, y) });
  const branch = (id, name, value, unit, x1, y1, x2, y2) => ({ id, name, value, unit, a: P(x1, y1), b: P(x2, y2) });
  const q = (id, name, value, unit, emphasis) => ({ id, name, value, unit, emphasis: !!emphasis });
  const AC_FLAG = 1;
  function pack(circuit, o) {
    return {
      circuit, headline: o.headline, elements: o.elements, nodes: o.nodes, branches: o.branches,
      quantities: o.quantities, steps: o.steps, notes: o.notes.slice(0, 4), warning: o.warning || null,
    };
  }
  const badUnknown = () => outOfRange('That unknown is not on this circuit.');

  /* ---------- catalog ---------- */
  const FAMILIES = [
    ['passive', 'Passive DC'], ['transient', 'RC, RL, and RLC'], ['diode', 'Diodes'], ['bjt', 'BJT'],
    ['mosfet', 'MOSFET'], ['opamp', 'Op-amps'], ['timer', '555 timers'], ['digital', 'LED and display'],
    ['amplifier', 'Amplifiers'], ['power', 'Power basics'], ['mathTools', 'Complex and matching'],
  ].map(([id, title]) => ({ id, title }));

  const DC_HELP = 'DC source. Not an AC model.';
  const n = (id, title, unit, help, sourceMode) => ({ id, title, unit, help: help || '', choices: [], optional: false, sourceMode: sourceMode || null });
  const ch = (id, title, pairs, help) => ({ id, title, unit: '', help: help || '', choices: pairs.map(([i, t]) => ({ id: i, title: t })), optional: false, sourceMode: null });
  const sourceField = () => ch('source', 'Source', [['ac', 'AC sine'], ['dc', 'DC']], 'DC is a steady voltage. AC is an ideal sine.');
  const u = (id, title) => ({ id, title });

  const SPECS = [];
  const SOLVERS = {};
  const LAYOUTS = {};
  function spec(o) { SPECS.push(o); }

  spec({ id: 'seriesResistors', family: 'passive', title: 'Series resistors', blurb: 'One loop. Current is shared. Drops add to the source.',
    defaultUnknown: 'current', unknowns: [u('current', 'Current'), u('vs', 'Source'), u('r1', 'R1'), u('r2', 'R2')],
    fields: [n('vs', 'Vs', 'V', DC_HELP), n('r1', 'R1', 'Ω'), n('r2', 'R2', 'Ω'), n('i', 'I', 'A')],
    visible: { current: ['vs', 'r1', 'r2'], vs: ['i', 'r1', 'r2'], r1: ['vs', 'i', 'r2'], r2: ['vs', 'i', 'r1'] },
    defaults: { vs: '12', r1: '1000', r2: '2000', i: '0.004' } });
  spec({ id: 'parallelResistors', family: 'passive', title: 'Parallel resistors', blurb: 'Same voltage on each branch. Currents add at the source.',
    defaultUnknown: 'sourceCurrent', unknowns: [u('sourceCurrent', 'Source current'), u('vs', 'Source'), u('r1', 'R1'), u('r2', 'R2')],
    fields: [n('vs', 'Vs', 'V', DC_HELP), n('r1', 'R1', 'Ω'), n('r2', 'R2', 'Ω'), n('it', 'It', 'A'), n('i1', 'I1', 'A'), n('i2', 'I2', 'A')],
    visible: { sourceCurrent: ['vs', 'r1', 'r2'], vs: ['it', 'r1', 'r2'], r1: ['vs', 'i1', 'r2'], r2: ['vs', 'i2', 'r1'] },
    defaults: { vs: '12', r1: '1000', r2: '2000', it: '0.018', i1: '0.012', i2: '0.006' } });
  spec({ id: 'voltageDivider', family: 'passive', title: 'Voltage divider', blurb: 'Unloaded divider. R1 is the top resistor. R2 goes to ground.',
    defaultUnknown: 'vout', unknowns: [u('vout', 'Vout'), u('vin', 'Vin'), u('r1', 'R1'), u('r2', 'R2')],
    fields: [n('vin', 'Vin', 'V', DC_HELP), n('vout', 'Vout', 'V'), n('r1', 'R1 (top)', 'Ω'), n('r2', 'R2 (to GND)', 'Ω')],
    visible: { vout: ['vin', 'r1', 'r2'], vin: ['vout', 'r1', 'r2'], r1: ['vin', 'vout', 'r2'], r2: ['vin', 'vout', 'r1'] },
    defaults: { vin: '12', vout: '6', r1: '10000', r2: '10000' } });
  spec({ id: 'kirchhoffLoop', family: 'passive', title: 'Kirchhoff loop', blurb: 'Three series resistors. KVL: the drops sum to the source.',
    defaultUnknown: 'current', unknowns: [u('current', 'Current'), u('vs', 'Source'), u('r1', 'R1'), u('r2', 'R2'), u('r3', 'R3')],
    fields: [n('vs', 'Vs', 'V', DC_HELP), n('r1', 'R1', 'Ω'), n('r2', 'R2', 'Ω'), n('r3', 'R3', 'Ω'), n('i', 'I', 'A')],
    visible: { current: ['vs', 'r1', 'r2', 'r3'], vs: ['i', 'r1', 'r2', 'r3'], r1: ['vs', 'i', 'r2', 'r3'], r2: ['vs', 'i', 'r1', 'r3'], r3: ['vs', 'i', 'r1', 'r2'] },
    defaults: { vs: '12', r1: '100', r2: '200', r3: '300', i: '0.02' } });
  spec({ id: 'theveninNorton', family: 'passive', title: 'Thevenin and Norton', blurb: 'Divider seen from the load: Vth, Rth, and the Norton current.',
    defaultUnknown: 'load', unknowns: [u('load', 'Loaded output'), u('rl', 'Load R'), u('r2', 'R2 for Vth')],
    fields: [n('vs', 'Vs', 'V', DC_HELP), n('r1', 'R1 (series)', 'Ω'), n('r2', 'R2 (shunt)', 'Ω'), n('rl', 'RL', 'Ω'), n('vl', 'Target VL', 'V'), n('vth', 'Target Vth', 'V')],
    visible: { load: ['vs', 'r1', 'r2', 'rl'], rl: ['vs', 'r1', 'r2', 'vl'], r2: ['vs', 'r1', 'vth'] },
    defaults: { vs: '12', r1: '1000', r2: '1000', rl: '1000', vl: '4', vth: '6' } });
  spec({ id: 'rcStep', family: 'transient', title: 'RC step', blurb: 'Capacitor voltage on a first-order step. τ = RC.',
    defaultUnknown: 'voltage', unknowns: [u('voltage', 'v(t)'), u('time', 'Time'), u('r', 'R'), u('c', 'C')],
    fields: [n('r', 'R', 'Ω'), n('c', 'C', 'F'), n('v0', 'v(0)', 'V'), n('vinf', 'v(∞)', 'V'), n('t', 't', 's'), n('vt', 'v(t) target', 'V')],
    visible: { voltage: ['r', 'c', 'v0', 'vinf', 't'], time: ['r', 'c', 'v0', 'vinf', 'vt'], r: ['c', 'v0', 'vinf', 't', 'vt'], c: ['r', 'v0', 'vinf', 't', 'vt'] },
    defaults: { r: '10000', c: '0.000001', v0: '0', vinf: '5', t: '0.01', vt: '3.1606' } });
  spec({ id: 'rlStep', family: 'transient', title: 'RL step', blurb: 'Inductor current on a step. τ = L/R.',
    defaultUnknown: 'current', unknowns: [u('current', 'i(t)'), u('time', 'Time'), u('l', 'L')],
    fields: [n('vs', 'Vs', 'V', DC_HELP), n('r', 'R', 'Ω'), n('l', 'L', 'H'), n('i0', 'i(0)', 'A'), n('t', 't', 's'), n('it', 'i(t) target', 'A')],
    visible: { current: ['vs', 'r', 'l', 'i0', 't'], time: ['vs', 'r', 'l', 'i0', 'it'], l: ['vs', 'r', 'i0', 't', 'it'] },
    defaults: { vs: '10', r: '100', l: '0.1', i0: '0', t: '0.001', it: '0.0632' } });
  spec({ id: 'firstOrderFilter', family: 'transient', title: 'First-order filter', blurb: 'RC low-pass or high-pass. Drive it with DC or a sine peak.',
    defaultUnknown: 'cutoff', unknowns: [u('cutoff', 'Cutoff'), u('r', 'R'), u('c', 'C')],
    fields: [sourceField(), ch('kind', 'Response', [['lowpass', 'Low-pass'], ['highpass', 'High-pass']]),
      n('vp', 'Vp', 'V', 'Peak of the sine, not RMS.', 'ac'), n('vdc', 'Vdc', 'V', 'Steady volts. Not RMS.', 'dc'),
      n('r', 'R', 'Ω'), n('c', 'C', 'F'), n('f', 'f', 'Hz', 'Frequency of the sine.', 'ac'), n('fc', 'fc', 'Hz')],
    visible: { cutoff: ['source', 'kind', 'vp', 'vdc', 'r', 'c', 'f'], r: ['source', 'kind', 'vp', 'vdc', 'c', 'fc', 'f'], c: ['source', 'kind', 'vp', 'vdc', 'r', 'fc', 'f'] },
    defaults: { source: 'ac', kind: 'lowpass', vp: '1', vdc: '1', r: '10000', c: '0.00000001', f: '1000', fc: '1591.5' } });
  spec({ id: 'seriesRLC', family: 'transient', title: 'Series RLC', blurb: 'Resonance, Q, and impedance. Drive it with DC or a sine peak.',
    defaultUnknown: 'response', unknowns: [u('response', 'At this f'), u('l', 'L from f0'), u('c', 'C from f0'), u('r', 'R from Q')],
    fields: [sourceField(), n('vp', 'Vp', 'V', 'Peak of the sine, not RMS.', 'ac'), n('vdc', 'Vdc', 'V', 'Steady volts. Series C is open at DC.', 'dc'),
      n('r', 'R', 'Ω'), n('l', 'L', 'H'), n('c', 'C', 'F'), n('f', 'Drive f', 'Hz', 'Frequency of the sine.', 'ac'), n('f0', 'f0', 'Hz'), n('q', 'Q', '')],
    visible: { response: ['source', 'vp', 'vdc', 'r', 'l', 'c', 'f'], l: ['source', 'vp', 'vdc', 'r', 'c', 'f0', 'f'], c: ['source', 'vp', 'vdc', 'r', 'l', 'f0', 'f'], r: ['source', 'vp', 'vdc', 'l', 'c', 'q', 'f'] },
    defaults: { source: 'ac', vp: '1', vdc: '1', r: '10', l: '0.001', c: '0.0000001', f: '15915', f0: '15915', q: '10' } });
  spec({ id: 'ledSeries', family: 'digital', title: 'LED and series R', blurb: 'Size the resistor for a target LED current.',
    defaultUnknown: 'resistance', unknowns: [u('resistance', 'Resistor'), u('current', 'LED current'), u('supply', 'Supply')],
    fields: [n('vs', 'Vs', 'V', DC_HELP), n('vf', 'Vf', 'V', 'Forward drop you enter.'), n('if', 'If', 'A'), n('r', 'R', 'Ω')],
    visible: { resistance: ['vs', 'vf', 'if'], current: ['vs', 'vf', 'r'], supply: ['vf', 'if', 'r'] },
    defaults: { vs: '5', vf: '2', if: '0.02', r: '150' } });

  function visibleFields(id, unknown, inputs) {
    const s = specOf(id);
    const ids = s.visible[unknown] || s.visible[s.defaultUnknown] || [];
    const raw = String((inputs && inputs.source) || '').trim();
    const mode = raw === 'dc' || raw === 'ac' ? raw : 'ac';
    return ids.map((fid) => s.fields.find((f) => f.id === fid)).filter(Boolean).filter((f) => !f.sourceMode || f.sourceMode === mode);
  }
  function specOf(id) {
    const s = SPECS.find((x) => x.id === id);
    if (!s) throw new Error('Missing electronics bench spec for ' + id);
    return s;
  }

  /* ---------- solvers ---------- */
  function exponentialTime(v0, vinf, vt, tau) {
    const span = v0 - vinf;
    if (!(Math.abs(span) > 1e-15)) throw outOfRange('Start and final values are the same, so time is not defined.');
    const ratio = (vt - vinf) / span;
    if (!(ratio > 0 && ratio < 1)) throw outOfRange('The target has to sit strictly between the start value and the final value.');
    return -tau * Math.log(ratio);
  }
  function tauFromSample(v0, vinf, vt, t) {
    const span = v0 - vinf;
    if (!(Math.abs(span) > 1e-15)) throw outOfRange('Start and final values are the same.');
    const ratio = (vt - vinf) / span;
    if (!(ratio > 0 && ratio < 1)) throw outOfRange('The sample has to sit strictly between the start value and the final value.');
    return -t / Math.log(ratio);
  }

  SOLVERS.seriesResistors = (unknown, inp) => {
    let r1, r2, vs, i;
    switch (unknown) {
      case 'current': vs = pos(inp, 'vs', 'Vs'); r1 = pos(inp, 'r1', 'R1'); r2 = pos(inp, 'r2', 'R2'); i = vs / (r1 + r2); break;
      case 'vs': i = pos(inp, 'i', 'I'); r1 = pos(inp, 'r1', 'R1'); r2 = pos(inp, 'r2', 'R2'); vs = i * (r1 + r2); break;
      case 'r1': vs = pos(inp, 'vs', 'Vs'); i = pos(inp, 'i', 'I'); r2 = pos(inp, 'r2', 'R2'); r1 = vs / i - r2;
        if (!(r1 > 0)) throw outOfRange('R1 would not be positive. I is too large for Vs and R2.'); break;
      case 'r2': vs = pos(inp, 'vs', 'Vs'); i = pos(inp, 'i', 'I'); r1 = pos(inp, 'r1', 'R1'); r2 = vs / i - r1;
        if (!(r2 > 0)) throw outOfRange('R2 would not be positive. I is too large for Vs and R1.'); break;
      default: throw badUnknown();
    }
    const v1 = i * r1, v2 = i * r2;
    return pack('seriesResistors', {
      headline: 'I = ' + eng(i) + ' A',
      elements: [src('vs', 'Vs', eng(vs) + ' V', 16, 68, 16, 18), wire('w1', 16, 18, 34, 18), res('r1', 'R1', eng(r1) + ' Ω', 34, 18, 62, 18),
        res('r2', 'R2', eng(r2) + ' Ω', 62, 18, 86, 18), wire('w2', 86, 18, 86, 68), gnd('g', 86, 68), wire('w3', 16, 68, 86, 68)],
      nodes: [node('src', 'Vs', vs, 'V', 16, 18), node('mid', 'V1', v2, 'V', 62, 18), node('gnd', 'GND', 0, 'V', 86, 68)],
      branches: [branch('loop', 'I', i, 'A', 20, 18, 80, 18)],
      quantities: [q('vs', 'Vs', vs, 'V', unknown === 'vs'), q('r1', 'R1', r1, 'Ω', unknown === 'r1'), q('r2', 'R2', r2, 'Ω', unknown === 'r2'),
        q('current', 'I', i, 'A', unknown === 'current'), q('v1', 'Drop R1', v1, 'V'), q('v2', 'Drop R2', v2, 'V')],
      steps: ['Req = R1 + R2 = ' + eng(r1 + r2) + ' Ω', 'I = Vs / Req = ' + eng(i) + ' A', 'V1 = I·R1 = ' + eng(v1) + ' V,  V2 = I·R2 = ' + eng(v2) + ' V'],
      notes: ['One series loop. The same current passes through both resistors.', 'KVL: Vs = V1 + V2. The mid node sits at V2 above ground.', 'Ideal resistors. No source resistance and no meter loading.'],
    });
  };

  SOLVERS.parallelResistors = (unknown, inp) => {
    let vs, r1, r2;
    switch (unknown) {
      case 'sourceCurrent': vs = pos(inp, 'vs', 'Vs'); r1 = pos(inp, 'r1', 'R1'); r2 = pos(inp, 'r2', 'R2'); break;
      case 'vs': { const it0 = pos(inp, 'it', 'It'); r1 = pos(inp, 'r1', 'R1'); r2 = pos(inp, 'r2', 'R2'); vs = it0 / (1 / r1 + 1 / r2); break; }
      case 'r1': vs = pos(inp, 'vs', 'Vs'); { const i1 = pos(inp, 'i1', 'I1'); r2 = pos(inp, 'r2', 'R2'); r1 = vs / i1; } break;
      case 'r2': vs = pos(inp, 'vs', 'Vs'); r1 = pos(inp, 'r1', 'R1'); { const i2 = pos(inp, 'i2', 'I2'); r2 = vs / i2; } break;
      default: throw badUnknown();
    }
    const i1 = vs / r1, i2 = vs / r2, it = i1 + i2, req = vs / it;
    return pack('parallelResistors', {
      headline: 'It = ' + eng(it) + ' A',
      elements: [src('vs', 'Vs', eng(vs) + ' V', 18, 68, 18, 16), wire('top', 18, 16, 78, 16), res('r1', 'R1', eng(r1) + ' Ω', 40, 16, 40, 68),
        res('r2', 'R2', eng(r2) + ' Ω', 66, 16, 66, 68), wire('bot', 18, 68, 78, 68), gnd('g', 78, 68)],
      nodes: [node('top', 'Vs', vs, 'V', 18, 16), node('gnd', 'GND', 0, 'V', 78, 68)],
      branches: [branch('i1', 'I1', i1, 'A', 40, 20, 40, 60), branch('i2', 'I2', i2, 'A', 66, 20, 66, 60), branch('it', 'It', it, 'A', 18, 60, 18, 24)],
      quantities: [q('vs', 'Vs', vs, 'V', unknown === 'vs'), q('r1', 'R1', r1, 'Ω', unknown === 'r1'), q('r2', 'R2', r2, 'Ω', unknown === 'r2'),
        q('sourceCurrent', 'It', it, 'A', unknown === 'sourceCurrent'), q('i1', 'I1', i1, 'A'), q('i2', 'I2', i2, 'A'), q('req', 'Req', req, 'Ω')],
      steps: ['I1 = Vs / R1 = ' + eng(i1) + ' A', 'I2 = Vs / R2 = ' + eng(i2) + ' A', 'It = I1 + I2 = ' + eng(it) + ' A,  Req = ' + eng(req) + ' Ω'],
      notes: ['Both resistors see the full source voltage.', 'Branch currents add. Req is the parallel combination.', 'Ideal sources and resistors. No wiring resistance.'],
    });
  };

  SOLVERS.voltageDivider = (unknown, inp) => {
    let vin, vout, r1, r2, formula;
    const reqVin = (v) => { if (!(isFinite(v) && v > 0)) throw nonPositive('Vin'); };
    switch (unknown) {
      case 'vout': vin = pos(inp, 'vin', 'Vin'); r1 = pos(inp, 'r1', 'R1'); r2 = pos(inp, 'r2', 'R2'); vout = vin * r2 / (r1 + r2); formula = 'Vout = Vin × R2 / (R1 + R2)'; break;
      case 'r1': vin = pos(inp, 'vin', 'Vin'); vout = pos(inp, 'vout', 'Vout'); r2 = pos(inp, 'r2', 'R2');
        if (!(vout < vin)) throw outOfRange('Vout must be less than Vin for this divider.');
        r1 = r2 * (vin - vout) / vout; formula = 'R1 = R2 × (Vin − Vout) / Vout'; break;
      case 'r2': vin = pos(inp, 'vin', 'Vin'); vout = pos(inp, 'vout', 'Vout'); r1 = pos(inp, 'r1', 'R1');
        if (!(vout < vin)) throw outOfRange('Vout must be less than Vin for this divider.');
        r2 = vout * r1 / (vin - vout); formula = 'R2 = R1 × Vout / (Vin − Vout)'; break;
      case 'vin': vout = pos(inp, 'vout', 'Vout'); r1 = pos(inp, 'r1', 'R1'); r2 = pos(inp, 'r2', 'R2');
        vin = vout * (r1 + r2) / r2; reqVin(vin); vout = vin * r2 / (r1 + r2); formula = 'Vout = Vin × R2 / (R1 + R2)'; break;
      default: throw badUnknown();
    }
    const current = vin / (r1 + r2);
    return pack('voltageDivider', {
      headline: 'Vout = ' + eng(vout) + ' V',
      elements: [src('vin', 'Vin', eng(vin) + ' V', 18, 68, 18, 16), wire('w1', 18, 16, 40, 16), res('r1', 'R1', eng(r1) + ' Ω', 40, 16, 40, 40),
        res('r2', 'R2', eng(r2) + ' Ω', 40, 40, 40, 68), wire('wout', 40, 40, 78, 40), wire('bot', 18, 68, 40, 68), gnd('g', 40, 68)],
      nodes: [node('in', 'Vin', vin, 'V', 18, 16), node('out', 'Vout', vout, 'V', 78, 40), node('gnd', 'GND', 0, 'V', 40, 68)],
      branches: [branch('series', 'I', current, 'A', 40, 22, 40, 60)],
      quantities: [q('vin', 'Vin', vin, 'V', unknown === 'vin'), q('vout', 'Vout', vout, 'V', unknown === 'vout'), q('r1', 'R1', r1, 'Ω', unknown === 'r1'),
        q('r2', 'R2', r2, 'Ω', unknown === 'r2'), q('current', 'I', current, 'A')],
      steps: [formula, 'I = Vin / (R1 + R2) = ' + eng(current) + ' A'],
      notes: ['Unloaded divider. A load on Vout changes both the voltage and the current.', 'R1 is from Vin to the tap. R2 is from the tap to ground.', 'Ideal DC. Source resistance is not included.'],
    });
  };

  SOLVERS.kirchhoffLoop = (unknown, inp) => {
    let r1 = 0, r2 = 0, r3 = 0, vs = 0, i = 0;
    switch (unknown) {
      case 'current': vs = pos(inp, 'vs', 'Vs'); r1 = pos(inp, 'r1', 'R1'); r2 = pos(inp, 'r2', 'R2'); r3 = pos(inp, 'r3', 'R3'); i = vs / (r1 + r2 + r3); break;
      case 'vs': i = pos(inp, 'i', 'I'); r1 = pos(inp, 'r1', 'R1'); r2 = pos(inp, 'r2', 'R2'); r3 = pos(inp, 'r3', 'R3'); vs = i * (r1 + r2 + r3); break;
      case 'r1': case 'r2': case 'r3': {
        vs = pos(inp, 'vs', 'Vs'); i = pos(inp, 'i', 'I');
        if (unknown !== 'r1') r1 = pos(inp, 'r1', 'R1');
        if (unknown !== 'r2') r2 = pos(inp, 'r2', 'R2');
        if (unknown !== 'r3') r3 = pos(inp, 'r3', 'R3');
        const miss = vs / i - (r1 + r2 + r3);
        if (!(miss > 0)) throw outOfRange('The missing resistor would not be positive.');
        if (unknown === 'r1') r1 = miss; if (unknown === 'r2') r2 = miss; if (unknown === 'r3') r3 = miss;
        break; }
      default: throw badUnknown();
    }
    const d1 = i * r1, d2 = i * r2, d3 = i * r3;
    return pack('kirchhoffLoop', {
      headline: 'ΣV = ' + eng(d1 + d2 + d3) + ' V',
      elements: [src('vs', 'Vs', eng(vs) + ' V', 14, 68, 14, 16), wire('a', 14, 16, 30, 16), res('r1', 'R1', eng(r1) + ' Ω', 30, 16, 50, 16),
        res('r2', 'R2', eng(r2) + ' Ω', 50, 16, 70, 16), res('r3', 'R3', eng(r3) + ' Ω', 70, 16, 88, 16), wire('b', 88, 16, 88, 68), wire('c', 14, 68, 88, 68), gnd('g', 88, 68)],
      nodes: [node('src', 'Vs', vs, 'V', 14, 16), node('n1', 'After R1', vs - d1, 'V', 50, 16), node('n2', 'After R2', d3, 'V', 70, 16), node('gnd', 'GND', 0, 'V', 88, 68)],
      branches: [branch('loop', 'I', i, 'A', 18, 16, 84, 16)],
      quantities: [q('vs', 'Vs', vs, 'V', unknown === 'vs'), q('current', 'I', i, 'A', unknown === 'current'), q('r1', 'R1', r1, 'Ω', unknown === 'r1'),
        q('r2', 'R2', r2, 'Ω', unknown === 'r2'), q('r3', 'R3', r3, 'Ω', unknown === 'r3'), q('d1', 'V on R1', d1, 'V'), q('d2', 'V on R2', d2, 'V'), q('d3', 'V on R3', d3, 'V')],
      steps: ['KVL: Vs = I·(R1 + R2 + R3)', 'Drops ' + eng(d1) + ' + ' + eng(d2) + ' + ' + eng(d3) + ' = ' + eng(vs) + ' V'],
      notes: ['Walk the loop: leave the source and the resistor drops bring you back to zero.', 'Node voltages are measured to the bottom rail.', 'One independent current. A second source would need another equation.'],
    });
  };

  SOLVERS.theveninNorton = (unknown, inp) => {
    const vs = pos(inp, 'vs', 'Vs'), r1 = pos(inp, 'r1', 'R1');
    let r2 = 0, rl = 0;
    switch (unknown) {
      case 'load': r2 = pos(inp, 'r2', 'R2'); rl = pos(inp, 'rl', 'RL'); break;
      case 'rl': { r2 = pos(inp, 'r2', 'R2'); const vl0 = pos(inp, 'vl', 'VL'); const vth0 = vs * r2 / (r1 + r2);
        if (!(vl0 < vth0)) throw outOfRange('VL must sit below Vth. A passive load cannot raise it.');
        const rth0 = 1 / (1 / r1 + 1 / r2); rl = rth0 * vl0 / (vth0 - vl0); break; }
      case 'r2': { const vthT = pos(inp, 'vth', 'Vth');
        if (!(vthT < vs)) throw outOfRange('Vth is a fraction of Vs for this divider.');
        r2 = vthT * r1 / (vs - vthT); rl = r2; break; }
      default: throw badUnknown();
    }
    const vth = vs * r2 / (r1 + r2), rth = 1 / (1 / r1 + 1 / r2), norton = vth / rth;
    const open = unknown === 'r2';
    const vl = open ? vth : vth * rl / (rth + rl);
    const il = open ? 0 : vl / rl;
    const shownRL = open ? rth : rl;
    return pack('theveninNorton', {
      headline: 'Vth = ' + eng(vth) + ' V',
      elements: [src('vs', 'Vs', eng(vs) + ' V', 16, 68, 16, 16), wire('a', 16, 16, 36, 16), res('r1', 'R1', eng(r1) + ' Ω', 36, 16, 58, 16),
        res('r2', 'R2', eng(r2) + ' Ω', 58, 16, 58, 68), wire('b', 58, 40, 78, 40), res('rl', open ? 'Rth' : 'RL', eng(shownRL) + ' Ω', 78, 40, 78, 68),
        wire('c', 16, 68, 78, 68), gnd('g', 58, 68)],
      nodes: [node('src', 'Vs', vs, 'V', 16, 16), node('th', 'Vth node', vth, 'V', 58, 16), node('load', open ? 'Open' : 'VL', vl, 'V', 78, 40), node('gnd', 'GND', 0, 'V', 58, 68)],
      branches: [branch('i1', 'Through R1', (vs - (open ? vth : vl)) / r1, 'A', 40, 16, 54, 16), branch('il', 'Load', il, 'A', 78, 44, 78, 64)],
      quantities: [q('vs', 'Vs', vs, 'V'), q('r1', 'R1', r1, 'Ω'), q('r2', 'R2', r2, 'Ω'), q('vth', 'Vth', vth, 'V', open), q('rth', 'Rth', rth, 'Ω'),
        q('norton', 'In', norton, 'A'), q('rl', 'RL', open ? 0 : rl, 'Ω', unknown === 'rl'), q('vl', 'VL', vl, 'V'), q('il', 'IL', il, 'A')],
      steps: ['Vth = Vs · R2 / (R1 + R2) = ' + eng(vth) + ' V', 'Rth = R1 || R2 = ' + eng(rth) + ' Ω', 'In = Vth / Rth = ' + eng(norton) + ' A'],
      notes: ['Thevenin is the open-circuit voltage with R1 || R2 behind it.', 'Norton is that same Rth fed by In = Vth / Rth.', 'The R2-only solve leaves the port open. Load current is then zero.', 'Linear resistors only. A diode in this network needs a different model.'],
    });
  };

  SOLVERS.rcStep = (unknown, inp) => {
    const v0 = finite(inp, 'v0', 'v(0)'), vinf = finite(inp, 'vinf', 'v(∞)');
    let r = 0, c = 0, t = 0, vt = 0;
    switch (unknown) {
      case 'voltage': r = pos(inp, 'r', 'R'); c = pos(inp, 'c', 'C'); t = pos(inp, 't', 't'); vt = vinf + (v0 - vinf) * Math.exp(-t / (r * c)); break;
      case 'time': r = pos(inp, 'r', 'R'); c = pos(inp, 'c', 'C'); vt = finite(inp, 'vt', 'v(t)'); t = exponentialTime(v0, vinf, vt, r * c); break;
      case 'r': c = pos(inp, 'c', 'C'); t = pos(inp, 't', 't'); vt = finite(inp, 'vt', 'v(t)'); r = tauFromSample(v0, vinf, vt, t) / c; break;
      case 'c': r = pos(inp, 'r', 'R'); t = pos(inp, 't', 't'); vt = finite(inp, 'vt', 'v(t)'); c = tauFromSample(v0, vinf, vt, t) / r; break;
      default: throw badUnknown();
    }
    const tau = r * c, current = (vinf - vt) / r;
    return pack('rcStep', {
      headline: 'v(' + eng(t) + ' s) = ' + eng(vt) + ' V',
      elements: [src('vs', 'v∞', eng(vinf) + ' V', 18, 68, 18, 18), wire('a', 18, 18, 42, 18), res('r', 'R', eng(r) + ' Ω', 42, 18, 68, 18),
        wire('b', 68, 18, 68, 36), cap('c', 'C', eng(c) + ' F', 68, 36, 68, 68), wire('g', 18, 68, 68, 68), gnd('gnd', 68, 68)],
      nodes: [node('src', 'v∞', vinf, 'V', 18, 18), node('cap', 'vC', vt, 'V', 68, 36), node('gnd', 'GND', 0, 'V', 68, 68)],
      branches: [branch('i', 'i(t)', current, 'A', 46, 18, 64, 18)],
      quantities: [q('vt', 'v(t)', vt, 'V', unknown === 'voltage'), q('time', 't', t, 's', unknown === 'time'), q('r', 'R', r, 'Ω', unknown === 'r'),
        q('c', 'C', c, 'F', unknown === 'c'), q('tau', 'τ', tau, 's'), q('current', 'i(t)', current, 'A'), q('v0', 'v(0)', v0, 'V'), q('vinf', 'v(∞)', vinf, 'V')],
      steps: ['τ = RC = ' + eng(tau) + ' s', 'v(t) = v∞ + (v0 − v∞) e^(−t/τ)', 'i(t) = (v∞ − vC) / R = ' + eng(current) + ' A'],
      notes: ['First-order step. The capacitor voltage moves from v(0) toward v(∞).', 'Current is set by the resistor drop at that instant.', 'No ESR, no leakage, and the source is ideal.'],
    });
  };

  SOLVERS.rlStep = (unknown, inp) => {
    const vs = pos(inp, 'vs', 'Vs'), r = pos(inp, 'r', 'R'), i0 = finite(inp, 'i0', 'i(0)'), iInf = vs / r;
    let l = 0, t = 0, it = 0;
    switch (unknown) {
      case 'current': l = pos(inp, 'l', 'L'); t = pos(inp, 't', 't'); it = iInf + (i0 - iInf) * Math.exp(-t * r / l); break;
      case 'time': l = pos(inp, 'l', 'L'); it = finite(inp, 'it', 'i(t)'); t = exponentialTime(i0, iInf, it, l / r); break;
      case 'l': t = pos(inp, 't', 't'); it = finite(inp, 'it', 'i(t)'); l = tauFromSample(i0, iInf, it, t) * r; break;
      default: throw badUnknown();
    }
    const tau = l / r, vL = vs - it * r;
    return pack('rlStep', {
      headline: 'i(' + eng(t) + ' s) = ' + eng(it) + ' A',
      elements: [src('vs', 'Vs', eng(vs) + ' V', 18, 68, 18, 18), wire('a', 18, 18, 40, 18), res('r', 'R', eng(r) + ' Ω', 40, 18, 62, 18),
        ind('l', 'L', eng(l) + ' H', 62, 18, 86, 18), wire('b', 86, 18, 86, 68), wire('c', 18, 68, 86, 68), gnd('g', 86, 68)],
      nodes: [node('src', 'Vs', vs, 'V', 18, 18), node('l', 'vL', vL, 'V', 74, 18), node('gnd', 'GND', 0, 'V', 86, 68)],
      branches: [branch('i', 'i(t)', it, 'A', 22, 18, 80, 18)],
      quantities: [q('current', 'i(t)', it, 'A', unknown === 'current'), q('time', 't', t, 's', unknown === 'time'), q('l', 'L', l, 'H', unknown === 'l'),
        q('tau', 'τ', tau, 's'), q('vL', 'vL', vL, 'V'), q('iInf', 'i(∞)', iInf, 'A'), q('vs', 'Vs', vs, 'V'), q('i0', 'i(0)', i0, 'A'), q('r', 'R', r, 'Ω')],
      steps: ['τ = L/R = ' + eng(tau) + ' s,  i(∞) = Vs/R = ' + eng(iInf) + ' A', 'i(t) = i∞ + (i0 − i∞) e^(−t/τ)', 'vL = Vs − iR = ' + eng(vL) + ' V'],
      notes: ['The inductor current cannot step. It moves from i(0) toward Vs/R.', 'vL is the voltage left after the resistor drop.', 'Ideal L and R. No core saturation.'],
    });
  };

  SOLVERS.firstOrderFilter = (unknown, inp) => {
    const ac = acSource(inp);
    const kind = choice(inp, 'kind', ['lowpass', 'highpass'], 'lowpass', 'Response');
    const vp = ac ? posIfPresent(inp, 'vp', 'Vp', 1) : 0;
    const vdc = ac ? 0 : posIfPresent(inp, 'vdc', 'Vdc', 1);
    const f = ac ? pos(inp, 'f', 'f') : 0;
    let r = 0, c = 0, fc = 0;
    switch (unknown) {
      case 'cutoff': r = pos(inp, 'r', 'R'); c = pos(inp, 'c', 'C'); fc = 1 / (2 * Math.PI * r * c); break;
      case 'r': c = pos(inp, 'c', 'C'); fc = pos(inp, 'fc', 'fc'); r = 1 / (2 * Math.PI * fc * c); break;
      case 'c': r = pos(inp, 'r', 'R'); fc = pos(inp, 'fc', 'fc'); c = 1 / (2 * Math.PI * fc * r); break;
      default: throw badUnknown();
    }
    const low = kind === 'lowpass';
    let h, vout, current;
    if (ac) {
      const ratio = f / fc;
      h = low ? cxDiv(CX(1, 0), CX(1, ratio)) : cxDiv(CX(0, ratio), CX(1, ratio));
      vout = vp * h.mag;
      current = vout / (low ? 1 / (2 * Math.PI * f * c) : r);
    } else { h = CX(low ? 1 : 0, 0); vout = low ? vdc : 0; current = 0; }
    const drive = ac ? vp : vdc;
    const detail = ac ? eng(vp) + ' Vpk' : eng(vdc) + ' Vdc';
    const quantities = [q('fc', 'fc', fc, 'Hz', unknown === 'cutoff'), q('r', 'R', r, 'Ω', unknown === 'r'), q('c', 'C', c, 'F', unknown === 'c'),
      q('mag', '|H|', h.mag, ''), q('phase', 'Phase', h.deg, '°'), q('lowpass', 'Low-pass', low ? 1 : 0, ''), q('ac', 'AC sine', ac ? 1 : 0, '')];
    if (ac) quantities.push(q('vp', 'Vp', vp, 'V'), q('f', 'f', f, 'Hz')); else quantities.push(q('vdc', 'Vdc', vdc, 'V'));
    const magNote = ac ? 'Magnitude and phase are for a ' + eng(vp) + ' V peak sine, not RMS.'
      : (low ? 'At DC the capacitor is open. Vout equals Vdc and current is zero.' : 'At DC the capacitor is open. Vout is zero.');
    const hStep = ac ? (low ? 'H = 1 / (1 + j f/fc)' : 'H = j(f/fc) / (1 + j f/fc)') : (low ? 'At DC the capacitor is open. Vout = Vdc.' : 'At DC the capacitor is open. Vout = 0.');
    const readStep = ac ? '|H| = ' + h.mag.toFixed(4) + ',  ∠ ' + h.deg.toFixed(2) + '°' : (low ? 'I = 0 after the capacitor charges.' : 'I = 0. High-pass blocks DC.');
    return pack('firstOrderFilter', {
      headline: 'fc = ' + eng(fc) + ' Hz',
      elements: [src('in', 'Vin', detail, 16, 58, 16, 22, ac ? AC_FLAG : 0), wire('a', 16, 22, 40, 22),
        low ? res('r', 'R', eng(r) + ' Ω', 40, 22, 64, 22) : cap('c', 'C', eng(c) + ' F', 40, 22, 64, 22),
        wire('b', 64, 22, 64, 40), wire('out', 64, 40, 86, 40),
        low ? cap('c', 'C', eng(c) + ' F', 64, 40, 64, 68) : res('r', 'R', eng(r) + ' Ω', 64, 40, 64, 68),
        wire('g', 16, 68, 64, 68), gnd('gnd', 64, 68)],
      nodes: [node('in', ac ? 'Vp' : 'Vdc', drive, 'V', 16, 22), node('out', '|Vout|', vout, 'V', 86, 40), node('gnd', 'GND', 0, 'V', 64, 68)],
      branches: [branch('i', ac ? 'I at f' : 'I', current, 'A', 44, 22, 60, 22)],
      quantities,
      steps: ['fc = 1 / (2πRC) = ' + eng(fc) + ' Hz', hStep, readStep],
      notes: [low ? 'Low-pass: the capacitor shunts highs to ground.' : 'High-pass: the capacitor blocks DC and passes highs.', magNote, 'First-order only. No source resistance and no load.'],
    });
  };

  SOLVERS.seriesRLC = (unknown, inp) => {
    const ac = acSource(inp);
    const vp = ac ? posIfPresent(inp, 'vp', 'Vp', 1) : 0;
    const vdc = ac ? 0 : posIfPresent(inp, 'vdc', 'Vdc', 1);
    const f = ac ? pos(inp, 'f', 'Drive f') : 0;
    let r = 0, l = 0, c = 0;
    switch (unknown) {
      case 'response': r = pos(inp, 'r', 'R'); l = pos(inp, 'l', 'L'); c = pos(inp, 'c', 'C'); break;
      case 'l': { r = pos(inp, 'r', 'R'); c = pos(inp, 'c', 'C'); const f0 = pos(inp, 'f0', 'f0'); l = 1 / (Math.pow(2 * Math.PI * f0, 2) * c); break; }
      case 'c': { r = pos(inp, 'r', 'R'); l = pos(inp, 'l', 'L'); const f0 = pos(inp, 'f0', 'f0'); c = 1 / (Math.pow(2 * Math.PI * f0, 2) * l); break; }
      case 'r': { l = pos(inp, 'l', 'L'); c = pos(inp, 'c', 'C'); const qIn = pos(inp, 'q', 'Q'); r = (1 / Math.sqrt(l * c)) * l / qIn; break; }
      default: throw badUnknown();
    }
    const f0 = 1 / (2 * Math.PI * Math.sqrt(l * c));
    const qf = (2 * Math.PI * f0 * l) / r, bw = f0 / qf;
    const drive = ac ? vp : vdc;
    const detail = ac ? eng(vp) + ' Vpk ∠0' : eng(vdc) + ' Vdc';
    const nodes = [node('src', ac ? 'Vp' : 'Vdc', drive, 'V', 14, 22), node('gnd', 'GND', 0, 'V', 88, 68)];
    const quantities = [q('f0', 'f0', f0, 'Hz'), q('q', 'Q', qf, '', unknown === 'r'), q('bw', 'Bandwidth', bw, 'Hz'), q('r', 'R', r, 'Ω', unknown === 'r'),
      q('l', 'L', l, 'H', unknown === 'l'), q('c', 'C', c, 'F', unknown === 'c'), q('ac', 'AC sine', ac ? 1 : 0, '')];
    let iMag, zStep, driveNote;
    if (ac) {
      const w = 2 * Math.PI * f, x = w * l - 1 / (w * c), z = CX(r, x);
      iMag = vp / z.mag;
      nodes.splice(1, 0, node('z', '|Z|', z.mag, 'Ω', 48, 22));
      quantities.push(q('zMag', '|Z|', z.mag, 'Ω'), q('zAng', '∠Z', z.deg, '°'), q('x', 'X', x, 'Ω'), q('f', 'Drive', f, 'Hz'), q('vp', 'Vp', vp, 'V'));
      zStep = 'Z = R + j(ωL − 1/ωC) = ' + eng(z.r) + ' + j' + eng(z.i) + ' Ω';
      driveNote = 'The current arrow is the phasor magnitude for a ' + eng(vp) + ' V peak drive, not RMS.';
    } else {
      iMag = 0; quantities.push(q('vdc', 'Vdc', vdc, 'V'));
      zStep = 'At DC the series capacitor is open, so I = 0.';
      driveNote = 'Series C is an open circuit at DC. Steady current is zero. |Z| is not a finite DC number.';
    }
    return pack('seriesRLC', {
      headline: 'f0 = ' + eng(f0) + ' Hz',
      elements: [src('vs', 'Vs', detail, 14, 58, 14, 22, ac ? AC_FLAG : 0), wire('a', 14, 22, 30, 22), res('r', 'R', eng(r) + ' Ω', 30, 22, 48, 22),
        ind('l', 'L', eng(l) + ' H', 48, 22, 68, 22), cap('c', 'C', eng(c) + ' F', 68, 22, 88, 22), wire('b', 88, 22, 88, 68), wire('g', 14, 68, 88, 68), gnd('gnd', 88, 68)],
      nodes, branches: [branch('i', '|I|', iMag, 'A', 20, 22, 80, 22)], quantities,
      steps: ['f0 = 1 / (2π √(LC)) = ' + eng(f0) + ' Hz', 'Q = ω0 L / R = ' + qf.toFixed(3) + ',  BW = f0/Q', zStep],
      notes: ['Series resonance is where XL and XC cancel and |Z| = R.', driveNote, 'Ideal L and C. This is not a loaded tank or a crystal model.'],
    });
  };

  SOLVERS.ledSeries = (unknown, inp) => {
    let vs = 0, vf = 0, current = 0, r = 0;
    switch (unknown) {
      case 'resistance': vs = pos(inp, 'vs', 'Vs'); vf = nonNeg(inp, 'vf', 'Vf'); current = pos(inp, 'if', 'If');
        if (!(vs > vf)) throw outOfRange('Vs must be above Vf or the LED current is not positive.'); r = (vs - vf) / current; break;
      case 'current': vs = pos(inp, 'vs', 'Vs'); vf = nonNeg(inp, 'vf', 'Vf'); r = pos(inp, 'r', 'R');
        if (!(vs > vf)) throw outOfRange('Vs must be above Vf.'); current = (vs - vf) / r; break;
      case 'supply': vf = nonNeg(inp, 'vf', 'Vf'); current = pos(inp, 'if', 'If'); r = pos(inp, 'r', 'R'); vs = vf + current * r; break;
      default: throw badUnknown();
    }
    return pack('ledSeries', {
      headline: 'R = ' + eng(r) + ' Ω',
      elements: [src('vs', 'Vs', eng(vs) + ' V', 20, 66, 20, 22), wire('a', 20, 22, 42, 22), res('r', 'R', eng(r) + ' Ω', 42, 22, 66, 22),
        ledPart('led', 'LED', eng(vf) + ' V', 66, 22, 66, 58), wire('b', 20, 66, 66, 66), gnd('g', 66, 66)],
      nodes: [node('src', 'Vs', vs, 'V', 20, 22), node('led', 'Anode', vs - current * r, 'V', 66, 22), node('gnd', 'GND', 0, 'V', 66, 66)],
      branches: [branch('i', 'If', current, 'A', 46, 22, 62, 22)],
      quantities: [q('r', 'R', r, 'Ω', unknown === 'resistance'), q('current', 'If', current, 'A', unknown === 'current'), q('vs', 'Vs', vs, 'V', unknown === 'supply'),
        q('pr', 'P in R', current * current * r, 'W'), q('pled', 'P in LED', current * vf, 'W')],
      steps: ['R = (Vs − Vf) / If', 'If = ' + eng(current) + ' A,  resistor power = I²R'],
      notes: ['Vf is the drop you entered. It is not solved from a diode equation.', 'The LED is forward. Reverse voltage is not checked.', 'One LED, one resistor. Parallel strings need their own resistors.'],
    });
  };

  function solve(circuit, unknown, inputs) {
    const s = specOf(circuit);
    if (!s.unknowns.some((x) => x.id === unknown)) throw outOfRange('That unknown is not on this circuit.');
    const sol = SOLVERS[circuit](unknown, inputs || {});
    sol.layout = makeBreadboard(sol);
    return sol;
  }
  function solveSafe(circuit, unknown, inputs) {
    try { return { ok: true, solution: solve(circuit, unknown, inputs) }; }
    catch (e) { if (e instanceof CalcError) return { ok: false, error: e.message }; throw e; }
  }

  /* ---------- breadboard model ---------- */
  const BB_ROWS = ['topPlus', 'topMinus', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'botMinus', 'botPlus'];
  const ROW_Y = { topPlus: 0, topMinus: 1, a: 2.55, b: 3.55, c: 4.55, d: 5.55, e: 6.55, f: 8.85, g: 9.85, h: 10.85, i: 11.85, j: 12.85, botMinus: 14.4, botPlus: 15.4 };
  const isRail = (row) => row === 'topPlus' || row === 'topMinus' || row === 'botPlus' || row === 'botMinus';
  const BB_COLUMNS = 30;
  const DISCLOSURE = 'Breadboard is an illustrative solderless hookup of this circuit’s nodes. It is not a SPICE board file or a fabrication drawing.';

  function bbGroup(h) {
    switch (h.row) {
      case 'topPlus': return 'rail:top+';
      case 'topMinus': return 'rail:top-';
      case 'botPlus': return 'rail:bot+';
      case 'botMinus': return 'rail:bot-';
      case 'a': case 'b': case 'c': case 'd': case 'e': return 'top:' + h.column;
      default: return 'bot:' + h.column;
    }
  }
  function manhattan(a, b) {
    const s = { x: a.column, y: ROW_Y[a.row] }, e = { x: b.column, y: ROW_Y[b.row] };
    if (a.column === b.column || a.row === b.row) return [s, e];
    return [s, { x: e.x, y: s.y }, e];
  }
  function partFaults(c) {
    const L = c.leads, t = c.part.type;
    if (['resistor', 'ceramic', 'electrolytic', 'led', 'diode', 'inductor', 'source'].indexOf(t) >= 0) {
      if (L.length !== 2) return [c.id + ' needs two leads'];
      if (L[0].net === L[1].net) return [c.id + ' ties ' + L[0].net + ' to itself'];
      if (bbGroup(L[0].hole) === bbGroup(L[1].hole)) return [c.id + ' is shorted by one breadboard node'];
      return [];
    }
    if (t === 'npn' || t === 'nmos' || t === 'pmos') {
      if (L.length !== 3) return [c.id + ' needs three leads'];
      return new Set(L.map((x) => x.net)).size < 3 ? [c.id + ' leads are not three nodes'] : [];
    }
    if (t === 'dip8' || t === 'dip14' || t === 'display') {
      const pins = t === 'dip8' ? 4 : t === 'dip14' ? 7 : 5;
      if (L.length !== pins * 2) return [c.id + ' has the wrong pin count'];
      const out = [], origin = L[0].hole.column;
      for (let k = 0; k < pins; k++) {
        const top = L[k].hole, bot = L[2 * pins - 1 - k].hole;
        if (top.row !== 'e' || bot.row !== 'f' || top.column !== origin + k || bot.column !== origin + k) out.push(c.id + ' pin ' + (k + 1) + ' is not across the gutter');
      }
      return out;
    }
    return [];
  }
  function auditBoard(layout) {
    const shorts = [], opens = [], clashes = [], faults = [], used = new Map();
    const hk = (h) => h.column + h.row;
    const claim = (h, who) => {
      if (h.column < 1 || h.column > layout.columns) faults.push(who + ' is off the board');
      if (used.has(hk(h))) clashes.push(who + ' shares ' + hk(h) + ' with ' + used.get(hk(h))); else used.set(hk(h), who);
    };
    const touches = [];
    layout.components.forEach((c) => {
      c.leads.forEach((l, i) => {
        claim(l.hole, c.id + '#' + i);
        if (!l.net) { faults.push(c.id + ' lead ' + i + ' has no net'); return; }
        touches.push([bbGroup(l.hole), l.net]);
      });
      partFaults(c).forEach((f) => faults.push(f));
    });
    layout.supplies.forEach((s) => s.leads.forEach((l, i) => {
      claim(l.hole, s.id + '#' + i);
      if (!isRail(l.hole.row)) { faults.push(s.id + ' lead ' + i + ' is not on a rail'); return; }
      touches.push([bbGroup(l.hole), l.net]);
    }));
    const parent = {};
    const find = (g) => { if (parent[g] === undefined) parent[g] = g; if (parent[g] !== g) parent[g] = find(parent[g]); return parent[g]; };
    const unite = (a, b) => { const ra = find(a), rb = find(b); if (ra !== rb) parent[rb] = ra; };
    layout.jumpers.forEach((j) => {
      if (j.a.column === j.b.column && j.a.row === j.b.row) faults.push(j.id + ' starts and ends in one hole');
      claim(j.a, j.id); claim(j.b, j.id);
      if (!j.net) { faults.push(j.id + ' has no net'); return; }
      const ga = bbGroup(j.a), gb = bbGroup(j.b);
      unite(ga, gb); touches.push([ga, j.net], [gb, j.net]);
    });
    const netsByRoot = {}, rootsByNet = {};
    touches.forEach(([g, net]) => {
      const root = find(g);
      (netsByRoot[root] = netsByRoot[root] || new Set()).add(net);
      (rootsByNet[net] = rootsByNet[net] || new Set()).add(root);
    });
    Object.keys(netsByRoot).forEach((r) => { if (netsByRoot[r].size > 1) shorts.push(Array.from(netsByRoot[r]).sort().join(' + ') + ' share ' + r); });
    Object.keys(rootsByNet).forEach((nn) => { if (rootsByNet[nn].size > 1) opens.push(nn + ' is split across ' + rootsByNet[nn].size + ' nodes'); });
    return { ok: !shorts.length && !opens.length && !clashes.length && !faults.length, shorts: shorts.sort(), opens: opens.sort(), clashes: clashes.sort(), faults: faults.sort() };
  }

  const DIGIT = ['black', 'brown', 'red', 'orange', 'yellow', 'green', 'blue', 'violet', 'gray', 'white'];
  function fourBand(ohms) {
    if (!(isFinite(ohms) && ohms > 0)) return [];
    let mag = ohms, mult = 1;
    while (mag >= 99.5) { mag /= 10; mult *= 10; if (mult > 1e9) return []; }
    while (mag < 10 && mult > 0.01) { mag *= 10; mult /= 10; }
    let rounded = Math.round(mag);
    if (rounded < 1) return [];
    if (rounded >= 100) { rounded /= 10; mult *= 10; if (mult > 1e9) return []; }
    let multBand;
    const e = Math.round(Math.log10(mult));
    if (Math.abs(mult - Math.pow(10, e)) > mult * 1e-9) return [];
    if (e === -1) multBand = 'gold'; else if (e === -2) multBand = 'silver'; else if (e >= 0 && e <= 9) multBand = DIGIT[e]; else return [];
    return [DIGIT[Math.floor(rounded / 10)], DIGIT[rounded % 10], multBand, 'gold'];
  }

  class Builder {
    constructor(solution) {
      this.solution = solution; this.components = []; this.jumpers = []; this.supplies = []; this.railLabels = [];
    }
    qty(id) { const x = this.solution.quantities.find((k) => k.id === id); return x ? x.value : undefined; }
    hole(column, row, net) { return { hole: { column, row }, net }; }
    jumper(id, net, c1, r1, c2, r2, color) { this.jumpers.push({ id, net, a: { column: c1, row: r1 }, b: { column: c2, row: r2 }, color }); }
    resistor(id, name, ohms, a, b) {
      this.components.push({ id, part: { type: 'resistor', ohms, label: name + ' ' + trim(ohms) + 'Ω', bands: fourBand(ohms) }, leads: [a, b] });
    }
    capacitor(id, name, farads, pl, mi) {
      const label = name + ' ' + trim(farads) + 'F';
      this.components.push({ id, part: { type: farads >= 1e-6 ? 'electrolytic' : 'ceramic', farads, label }, leads: [pl, mi] });
    }
    inductor(id, name, henries, a, b) { this.components.push({ id, part: { type: 'inductor', henries, label: name + ' ' + trim(henries) + 'H' }, leads: [a, b] }); }
    diode(id, label, an, ca) { this.components.push({ id, part: { type: 'diode', label }, leads: [an, ca] }); }
    singleSupply(label, positive, negative) {
      this.supplies.push({ id: 'ps', label, leads: [this.hole(2, 'topPlus', positive), this.hole(2, 'topMinus', negative)] });
      this.jumper('tie+', positive, 30, 'topPlus', 30, 'botPlus', 'red');
      this.jumper('tie-', negative, 29, 'topMinus', 29, 'botMinus', 'black');
      this.railLabels = [{ row: 'topPlus', text: positive }, { row: 'botPlus', text: positive }, { row: 'topMinus', text: negative }, { row: 'botMinus', text: negative }];
    }
    caption(specific) { return specific + ' ' + DISCLOSURE + ' Color bands are the nearest 5% code. The part label is the solved value.'; }
    finish(caption) {
      const bare = { circuit: this.solution.circuit, components: this.components, jumpers: this.jumpers, supplies: this.supplies, railLabels: this.railLabels, caption, columns: BB_COLUMNS, meters: [] };
      bare.meters = makeMeters(this.solution, bare);
      bare.audit = auditBoard(bare);
      return bare;
    }
  }

  function makeMeters(solution, layout) {
    const holesByNet = {};
    const claim = (net, h) => { if (net) (holesByNet[net] = holesByNet[net] || []).push(h); };
    layout.components.forEach((c) => c.leads.forEach((l) => claim(l.net, l.hole)));
    layout.jumpers.forEach((j) => { claim(j.net, j.a); claim(j.net, j.b); });
    layout.supplies.forEach((s) => s.leads.forEach((l) => claim(l.net, l.hole)));
    const meters = [], usedHoles = new Set();
    const pick = (net) => { const c = holesByNet[net] || []; return c.find((h) => !isRail(h.row)) || c[0]; };
    const aliases = (nd) => {
      const names = [nd.name, nd.id, nd.name.replace(/ /g, '')];
      if (nd.name === 'Vth node') names.push('Vth');
      if (nd.name === 'Vpeak') names.push('Vpk', 'Vpeak');
      if (nd.name === 'Vrms') names.push('Vac', 'Vrms');
      if (nd.name === 'Open' || nd.name === 'VL') names.push('Vth');
      return names;
    };
    for (const nd of solution.nodes) {
      if (!(nd.unit === 'V' || nd.unit === '')) continue;
      let hole;
      for (const a of aliases(nd)) { hole = pick(a); if (hole) break; }
      if (!hole || usedHoles.has(hole.column + hole.row)) continue;
      usedHoles.add(hole.column + hole.row);
      meters.push({ id: 'v-' + nd.id, kind: 'voltage', title: nd.name, reading: si(nd.value, nd.unit || 'V'), hole });
      if (meters.filter((m) => m.kind === 'voltage').length >= 5) break;
    }
    solution.branches.filter((b) => b.unit === 'A').slice(0, 3).forEach((b) => {
      const first = layout.components.find((c) => c.leads.length >= 2);
      const anchorCol = first ? Math.min(layout.columns, first.leads[0].hole.column + 2) : 12;
      const column = Math.min(layout.columns, Math.max(1, anchorCol + meters.filter((m) => m.kind === 'current').length * 3));
      meters.push({ id: 'i-' + b.id, kind: 'current', title: b.name, reading: si(b.value, 'A'), hole: { column, row: 'topPlus' } });
    });
    return meters;
  }

  function makeBreadboard(sol) {
    const fn = LAYOUTS[sol.circuit];
    return fn ? fn(new Builder(sol)) : null;
  }

  /* ---------- breadboard layouts (rows/columns copied from the app) ---------- */
  LAYOUTS.seriesResistors = (b) => {
    const r1 = b.qty('r1'), r2 = b.qty('r2'), vs = b.qty('vs');
    b.singleSupply(trim(vs) + ' V', 'Vs', 'GND');
    b.resistor('r1', 'R1', r1, b.hole(6, 'c', 'Vs'), b.hole(14, 'c', 'V1'));
    b.resistor('r2', 'R2', r2, b.hole(14, 'a', 'V1'), b.hole(24, 'a', 'GND'));
    b.jumper('vs', 'Vs', 6, 'e', 6, 'topPlus', 'red'); b.jumper('mid', 'V1', 14, 'b', 14, 'e', 'yellow');
    b.jumper('probe', 'V1', 14, 'd', 22, 'd', 'yellow'); b.jumper('gnd', 'GND', 24, 'e', 24, 'topMinus', 'black'); b.jumper('gndb', 'GND', 24, 'b', 24, 'botMinus', 'black');
    return b.finish(b.caption('Series string along rows a–e. Vs is the red rail, ground is the blue rail, and the yellow jumpers mark V1 between R1 and R2.'));
  };
  LAYOUTS.parallelResistors = (b) => {
    const r1 = b.qty('r1'), r2 = b.qty('r2'), vs = b.qty('vs');
    b.singleSupply(trim(vs) + ' V', 'Vs', 'GND');
    b.resistor('r1', 'R1', r1, b.hole(8, 'e', 'Vs'), b.hole(8, 'f', 'GND'));
    b.resistor('r2', 'R2', r2, b.hole(16, 'e', 'Vs'), b.hole(16, 'f', 'GND'));
    b.jumper('vs1', 'Vs', 8, 'a', 8, 'topPlus', 'red'); b.jumper('vs2', 'Vs', 16, 'b', 16, 'topPlus', 'red');
    b.jumper('vbus', 'Vs', 8, 'c', 24, 'c', 'red'); b.jumper('vs3', 'Vs', 24, 'a', 24, 'topPlus', 'red');
    b.jumper('g1', 'GND', 8, 'j', 8, 'botMinus', 'black'); b.jumper('g2', 'GND', 16, 'i', 16, 'botMinus', 'black');
    b.jumper('gbus', 'GND', 8, 'h', 24, 'h', 'black'); b.jumper('g3', 'GND', 24, 'j', 24, 'botMinus', 'black');
    return b.finish(b.caption('Both resistors sit across the gutter, so each one sees the full source. Red and black buses tie the rails across the board.'));
  };
  LAYOUTS.voltageDivider = (b) => {
    const r1 = b.qty('r1'), r2 = b.qty('r2'), vin = b.qty('vin');
    b.singleSupply(trim(vin) + ' V', 'Vin', 'GND');
    b.resistor('r1', 'R1', r1, b.hole(6, 'c', 'Vin'), b.hole(14, 'c', 'Vout'));
    b.resistor('r2', 'R2', r2, b.hole(14, 'a', 'Vout'), b.hole(24, 'a', 'GND'));
    b.jumper('vin', 'Vin', 6, 'e', 6, 'topPlus', 'red'); b.jumper('gnd', 'GND', 24, 'e', 24, 'topMinus', 'black'); b.jumper('gndb', 'GND', 24, 'b', 24, 'botMinus', 'black');
    b.jumper('out', 'Vout', 14, 'b', 22, 'b', 'yellow'); b.jumper('tap', 'Vout', 22, 'e', 22, 'f', 'yellow');
    return b.finish(b.caption('R1 feeds the tap and R2 returns to the blue rail. The yellow jumpers are the unloaded tap brought across the gutter.'));
  };
  LAYOUTS.kirchhoffLoop = (b) => {
    const r1 = b.qty('r1'), r2 = b.qty('r2'), r3 = b.qty('r3'), vs = b.qty('vs');
    b.singleSupply(trim(vs) + ' V', 'Vs', 'GND');
    b.resistor('r1', 'R1', r1, b.hole(5, 'c', 'Vs'), b.hole(11, 'c', 'N1'));
    b.resistor('r2', 'R2', r2, b.hole(11, 'a', 'N1'), b.hole(18, 'a', 'N2'));
    b.resistor('r3', 'R3', r3, b.hole(18, 'e', 'N2'), b.hole(26, 'e', 'GND'));
    b.jumper('vs', 'Vs', 5, 'b', 5, 'topPlus', 'red'); b.jumper('n1', 'N1', 11, 'b', 11, 'e', 'orange'); b.jumper('n2', 'N2', 18, 'b', 18, 'd', 'yellow');
    b.jumper('gnd', 'GND', 26, 'b', 26, 'topMinus', 'black'); b.jumper('gndb', 'GND', 26, 'a', 26, 'botMinus', 'black');
    return b.finish(b.caption('One series loop. Orange marks N1 after R1 and yellow marks N2 after R2, both measured to the blue rail.'));
  };
  LAYOUTS.theveninNorton = (b) => {
    const r1 = b.qty('r1'), r2 = b.qty('r2'), vs = b.qty('vs');
    b.singleSupply(trim(vs) + ' V', 'Vs', 'GND');
    b.resistor('r1', 'R1', r1, b.hole(6, 'c', 'Vs'), b.hole(14, 'c', 'Vth'));
    b.resistor('r2', 'R2', r2, b.hole(14, 'e', 'Vth'), b.hole(14, 'f', 'GND'));
    b.jumper('vs', 'Vs', 6, 'a', 6, 'topPlus', 'red'); b.jumper('gnd', 'GND', 14, 'j', 14, 'botMinus', 'black'); b.jumper('tap', 'Vth', 14, 'b', 22, 'b', 'yellow');
    const rl = b.qty('rl');
    if (rl > 0) {
      b.resistor('rl', 'RL', rl, b.hole(22, 'e', 'Vth'), b.hole(22, 'f', 'GND'));
      b.jumper('lg', 'GND', 22, 'j', 22, 'botMinus', 'black');
      return b.finish(b.caption('Divider feeding RL. Yellow is the Thevenin node; R1 series, R2 shunt, RL across the gutter.'));
    }
    b.jumper('open', 'Vth', 22, 'e', 26, 'e', 'yellow');
    return b.finish(b.caption('Divider Thevenin port left open. Yellow marks the Vth node; Rth is R1 || R2 behind that tap.'));
  };
  LAYOUTS.rcStep = (b) => {
    const r = b.qty('r'), c = b.qty('c'), vinf = b.qty('vinf');
    b.singleSupply(trim(vinf) + ' V', 'Vinf', 'GND');
    b.resistor('r', 'R', r, b.hole(6, 'c', 'Vinf'), b.hole(16, 'c', 'Vc'));
    b.capacitor('c', 'C', c, b.hole(16, 'e', 'Vc'), b.hole(16, 'f', 'GND'));
    b.jumper('src', 'Vinf', 6, 'a', 6, 'topPlus', 'red'); b.jumper('probe', 'Vc', 16, 'b', 24, 'b', 'yellow');
    b.jumper('gnd', 'GND', 16, 'j', 16, 'botMinus', 'black'); b.jumper('gndb', 'GND', 24, 'j', 24, 'botMinus', 'black');
    return b.finish(b.caption('The capacitor’s positive lead is the Vc node; the yellow jumper is a probe point. At 1 µF and above it is an electrolytic; smaller values are ceramic discs.'));
  };
  LAYOUTS.rlStep = (b) => {
    const r = b.qty('r'), l = b.qty('l'), vs = b.qty('vs');
    b.singleSupply(trim(vs) + ' V', 'Vs', 'GND');
    b.resistor('r', 'R', r, b.hole(6, 'c', 'Vs'), b.hole(14, 'c', 'VL'));
    b.inductor('l', 'L', l, b.hole(14, 'a', 'VL'), b.hole(24, 'a', 'GND'));
    b.jumper('vs', 'Vs', 6, 'e', 6, 'topPlus', 'red'); b.jumper('mid', 'VL', 14, 'b', 14, 'e', 'yellow');
    b.jumper('gnd', 'GND', 24, 'e', 24, 'topMinus', 'black'); b.jumper('gndb', 'GND', 24, 'b', 24, 'botMinus', 'black');
    return b.finish(b.caption('Series RL along rows a–e. Yellow marks the inductor node. Ideal L — no core model.'));
  };
  LAYOUTS.firstOrderFilter = (b) => {
    const r = b.qty('r'), c = b.qty('c');
    const cEl = b.solution.elements.find((e) => e.id === 'c');
    const low = !cEl || Math.abs(cEl.a.x - cEl.b.x) + 0.01 < Math.abs(cEl.a.y - cEl.b.y);
    let chip;
    if ((b.qty('ac') === undefined ? 1 : b.qty('ac')) >= 0.5 && b.qty('vp') !== undefined) chip = trim(b.qty('vp')) + ' Vpk';
    else if (b.qty('vdc') !== undefined) chip = trim(b.qty('vdc')) + ' Vdc'; else chip = 'Vin';
    b.singleSupply(chip, 'Vin', 'GND');
    if (low) {
      b.resistor('r', 'R', r, b.hole(6, 'c', 'Vin'), b.hole(16, 'c', 'Vout'));
      b.capacitor('c', 'C', c, b.hole(16, 'e', 'Vout'), b.hole(16, 'f', 'GND'));
    } else {
      b.capacitor('c', 'C', c, b.hole(6, 'c', 'Vin'), b.hole(16, 'c', 'Vout'));
      b.resistor('r', 'R', r, b.hole(16, 'e', 'Vout'), b.hole(16, 'f', 'GND'));
    }
    b.jumper('vin', 'Vin', 6, 'a', 6, 'topPlus', 'red'); b.jumper('out', 'Vout', 16, 'b', 24, 'b', 'yellow');
    b.jumper('gnd', 'GND', 16, 'j', 16, 'botMinus', 'black'); b.jumper('gndb', 'GND', 24, 'j', 24, 'botMinus', 'black');
    const which = low ? 'Low-pass: R is in series and C shunts the output.' : 'High-pass: C is in series and R shunts the output.';
    return b.finish(b.caption(which + ' Yellow is the Vout probe. The red rail is the source lead, not a second supply.'));
  };
  LAYOUTS.seriesRLC = (b) => {
    const r = b.qty('r'), l = b.qty('l'), c = b.qty('c');
    const ac = (b.qty('ac') === undefined ? 1 : b.qty('ac')) >= 0.5;
    const label = ac ? trim(b.qty('vp')) + ' Vpk' : trim(b.qty('vdc')) + ' Vdc';
    const net = ac ? 'Vp' : 'Vdc';
    b.singleSupply(label, net, 'GND');
    b.resistor('r', 'R', r, b.hole(6, 'c', net), b.hole(12, 'c', 'N1'));
    b.inductor('l', 'L', l, b.hole(12, 'a', 'N1'), b.hole(18, 'a', 'N2'));
    b.capacitor('c', 'C', c, b.hole(18, 'e', 'N2'), b.hole(24, 'e', 'GND'));
    b.jumper('src', net, 6, 'e', 6, 'topPlus', 'red'); b.jumper('n1', 'N1', 12, 'b', 12, 'e', 'orange'); b.jumper('n2', 'N2', 18, 'b', 18, 'd', 'yellow');
    b.jumper('gnd', 'GND', 24, 'b', 24, 'topMinus', 'black'); b.jumper('gndb', 'GND', 24, 'a', 24, 'botMinus', 'black');
    const drive = ac ? 'AC peak on the red rail drives series R–L–C. At DC the capacitor is open — steady current is zero.'
      : 'DC on the red rail into series R–L–C. Series C is an open at DC, so steady current is zero.';
    return b.finish(b.caption(drive + ' Orange is after R; yellow is after L.'));
  };
  LAYOUTS.ledSeries = (b) => {
    const r = b.qty('r'), vs = b.qty('vs');
    b.singleSupply(trim(vs) + ' V', 'Vs', 'GND');
    b.resistor('r', 'R', r, b.hole(6, 'c', 'Vs'), b.hole(16, 'c', 'Van'));
    b.components.push({ id: 'led', part: { type: 'led', label: 'LED' }, leads: [b.hole(16, 'e', 'Van'), b.hole(16, 'f', 'GND')] });
    b.jumper('vs', 'Vs', 6, 'a', 6, 'topPlus', 'red'); b.jumper('anode', 'Van', 16, 'b', 22, 'b', 'orange');
    b.jumper('gnd', 'GND', 16, 'j', 16, 'botMinus', 'black'); b.jumper('gndb', 'GND', 22, 'j', 22, 'botMinus', 'black');
    return b.finish(b.caption('The flat side of the LED is the cathode, on the ground side of the gutter. Orange marks the anode node after the series resistor.'));
  };

  global.BeckifyBenchEngine = {
    CalcError, FAMILIES, SPECS, SOLVERS, LAYOUTS, ROW_Y, BB_ROWS, BB_COLUMNS, DISCLOSURE,
    parseEngineering, eng, si, trim, fourBand, visibleFields, specOf, solve, solveSafe,
    auditBoard, manhattan, bbGroup, isRail, makeMeters,
    circuits: () => SPECS.map((s) => s.id),
  };
  global.__benchEngineTestApi = global.BeckifyBenchEngine;
})(typeof window !== 'undefined' ? window : globalThis);
