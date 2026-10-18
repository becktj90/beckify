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

  spec({ id: 'halfWave', family: 'diode', title: 'Half-wave rectifier', blurb: 'One diode. AC sine (RMS) or a steady DC source. Ripple sizing is for the sine.',
    defaultUnknown: 'report', unknowns: [u('report', 'Readings'), u('c', 'C for ripple')],
    fields: [sourceField(), n('vrms', 'Vrms', 'V', 'RMS of the sine. Peak is Vrms·√2, before diode drops.', 'ac'), n('vdc', 'Vdc', 'V', 'Steady volts, forward polarity. Not RMS.', 'dc'),
      n('vf', 'Vf', 'V'), n('f', 'f', 'Hz', 'Line frequency of the sine.', 'ac'), n('c', 'C', 'F'), n('rload', 'Rload', 'Ω'), n('ripple', 'Ripple target', 'V')],
    visible: { report: ['source', 'vrms', 'vdc', 'vf', 'f', 'c', 'rload'], c: ['source', 'vrms', 'vdc', 'vf', 'f', 'rload', 'ripple'] },
    defaults: { source: 'ac', vrms: '12', vdc: '12', vf: '0.7', f: '60', c: '0.0001', rload: '100', ripple: '1' } });
  spec({ id: 'fullBridge', family: 'diode', title: 'Full-wave bridge', blurb: 'Four diodes, two drops. AC uses 2/π and ripple at 2f. DC is a steady source.',
    defaultUnknown: 'report', unknowns: [u('report', 'Readings'), u('c', 'C for ripple')],
    fields: [sourceField(), n('vrms', 'Vrms', 'V', 'RMS of the sine. Peak is Vrms·√2, before diode drops.', 'ac'), n('vdc', 'Vdc', 'V', 'Steady volts, forward polarity. Not RMS.', 'dc'),
      n('vf', 'Vf each', 'V'), n('f', 'Line f', 'Hz', 'Line frequency of the sine.', 'ac'), n('c', 'C', 'F'), n('rload', 'Rload', 'Ω'), n('ripple', 'Ripple target', 'V')],
    visible: { report: ['source', 'vrms', 'vdc', 'vf', 'f', 'c', 'rload'], c: ['source', 'vrms', 'vdc', 'vf', 'f', 'rload', 'ripple'] },
    defaults: { source: 'ac', vrms: '12', vdc: '12', vf: '0.7', f: '60', c: '0.0001', rload: '100', ripple: '0.5' } });
  spec({ id: 'shuntClipper', family: 'diode', title: 'Shunt clipper', blurb: 'Series resistor, diode shunt. The source is a DC level or a sine peak.',
    defaultUnknown: 'report', unknowns: [u('report', 'Clipped peak'), u('r', 'R for Ipeak')],
    fields: [sourceField(), n('vp', 'Vp', 'V', 'Peak of the sine, not RMS.', 'ac'), n('vdc', 'Vdc', 'V', 'Steady volts. Not RMS.', 'dc'), n('f', 'f', 'Hz', 'Frequency of the sketch sine.', 'ac'),
      n('r', 'R series', 'Ω'), n('vf', 'Vf', 'V'), n('vbias', 'Bias under diode', 'V', '0 V clips near Vf above ground.'), n('ipeak', 'Ipeak limit', 'A')],
    visible: { report: ['source', 'vp', 'vdc', 'f', 'r', 'vf', 'vbias'], r: ['source', 'vp', 'vdc', 'f', 'vf', 'vbias', 'ipeak'] },
    defaults: { source: 'ac', vp: '10', vdc: '10', f: '1000', r: '1000', vf: '0.7', vbias: '0', ipeak: '0.01' } });
  spec({ id: 'clamper', family: 'diode', title: 'Diode clamper', blurb: 'Series capacitor and a diode to ground. The sine shifts; the swing stays.',
    defaultUnknown: 'report', unknowns: [u('report', 'Shifted peaks')],
    fields: [n('vp', 'Vp', 'V', 'Peak of the AC sine. This clamp is not a DC model.'), n('vf', 'Vf', 'V')],
    visible: { report: ['vp', 'vf'] }, defaults: { vp: '10', vf: '0.7' } });

  spec({ id: 'bjtBias', family: 'bjt', title: 'Divider bias', blurb: 'Four-resistor NPN bias. Vbe is 0.7 V. β is constant.',
    defaultUnknown: 'point', unknowns: [u('point', 'Q point'), u('re', 'Re for Ic'), u('rc', 'Rc for Vc')],
    fields: [n('vcc', 'Vcc', 'V'), n('r1', 'R1 (base top)', 'Ω'), n('r2', 'R2 (base bottom)', 'Ω'), n('rc', 'Rc', 'Ω'), n('re', 'Re', 'Ω'), n('beta', 'β', ''), n('ic', 'Target Ic', 'A'), n('vc', 'Target Vc', 'V')],
    visible: { point: ['vcc', 'r1', 'r2', 'rc', 're', 'beta'], re: ['vcc', 'r1', 'r2', 'rc', 'beta', 'ic'], rc: ['vcc', 'r1', 'r2', 're', 'beta', 'vc'] },
    defaults: { vcc: '12', r1: '47000', r2: '10000', rc: '2200', re: '1000', beta: '100', ic: '0.001', vc: '9' } });
  spec({ id: 'ceAmp', family: 'bjt', title: 'Common-emitter amp', blurb: 'Same bias, plus a midband gain estimate. Vt = 26 mV.',
    defaultUnknown: 'gain', unknowns: [u('gain', 'Gain'), u('rc', 'Rc for |Av|')],
    fields: [n('vcc', 'Vcc', 'V'), n('r1', 'R1', 'Ω'), n('r2', 'R2', 'Ω'), n('rc', 'Rc', 'Ω'), n('re', 'Re', 'Ω'), n('beta', 'β', ''), n('rl', 'RL (AC)', 'Ω'),
      ch('bypass', 'Emitter', [['bypassed', 'Bypassed'], ['open', 'Unbypassed']]), n('av', 'Target |Av|', '')],
    visible: { gain: ['vcc', 'r1', 'r2', 'rc', 're', 'beta', 'rl', 'bypass'], rc: ['vcc', 'r1', 'r2', 're', 'beta', 'rl', 'bypass', 'av'] },
    defaults: { vcc: '12', r1: '47000', r2: '10000', rc: '2200', re: '1000', beta: '100', rl: '10000', bypass: 'bypassed', av: '10' } });
  spec({ id: 'bjtSwitch', family: 'bjt', title: 'BJT switch', blurb: 'Low-side NPN. Saturated when forced β is under the device β.',
    defaultUnknown: 'state', unknowns: [u('state', 'On or off'), u('rb', 'Rb to saturate')],
    fields: [n('vcc', 'Vcc', 'V'), n('rc', 'Rc (load)', 'Ω'), n('rb', 'Rb', 'Ω'), n('beta', 'β', ''), n('vin', 'Vin high', 'V')],
    visible: { state: ['vcc', 'rc', 'rb', 'beta', 'vin'], rb: ['vcc', 'rc', 'beta', 'vin'] },
    defaults: { vcc: '12', rc: '1000', rb: '10000', beta: '100', vin: '5' } });
  spec({ id: 'csAmp', family: 'mosfet', title: 'Common-source amp', blurb: 'NMOS square law. kn is µCox·W/L in A/V². Rs = 0 is a pure CS stage.',
    defaultUnknown: 'point', unknowns: [u('point', 'Q point'), u('rd', 'Rd for |Av|')],
    fields: [n('vdd', 'Vdd', 'V'), n('vg', 'Vg', 'V'), n('rd', 'Rd', 'Ω'), n('rs', 'Rs', 'Ω'), n('kn', 'kn', 'A/V²', 'Square-law parameter, not a SPICE model card.'), n('vt', 'Vt', 'V'), n('av', 'Target |Av|', '')],
    visible: { point: ['vdd', 'vg', 'rd', 'rs', 'kn', 'vt'], rd: ['vdd', 'vg', 'rs', 'kn', 'vt', 'av'] },
    defaults: { vdd: '12', vg: '2', rd: '200', rs: '0', kn: '0.02', vt: '1', av: '4' } });
  spec({ id: 'mosSwitch', family: 'mosfet', title: 'MOSFET switch', blurb: 'Low-side NMOS. On-state uses the Rds(on) you enter, not the square law.',
    defaultUnknown: 'state', unknowns: [u('state', 'On or off'), u('rdson', 'Rds(on) max')],
    fields: [n('vdd', 'Vdd', 'V'), n('rd', 'Rd (load)', 'Ω'), n('vgs', 'Vgs', 'V'), n('vt', 'Vt', 'V'), n('rdson', 'Rds(on)', 'Ω'), n('vdslimit', 'Vds limit', 'V')],
    visible: { state: ['vdd', 'rd', 'vgs', 'vt', 'rdson'], rdson: ['vdd', 'rd', 'vgs', 'vt', 'vdslimit'] },
    defaults: { vdd: '12', rd: '100', vgs: '5', vt: '2', rdson: '0.05', vdslimit: '0.1' } });
  spec({ id: 'cmosInverter', family: 'mosfet', title: 'CMOS inverter', blurb: 'Matched-strength threshold and an ideal rail-to-rail logic level.',
    defaultUnknown: 'threshold', unknowns: [u('threshold', 'Threshold'), u('vout', 'Logic level')],
    fields: [n('vdd', 'Vdd', 'V'), n('vtn', 'Vtn', 'V'), n('vtp', '|Vtp|', 'V'), n('vin', 'Vin', 'V')],
    visible: { threshold: ['vdd', 'vtn', 'vtp'], vout: ['vdd', 'vtn', 'vtp', 'vin'] },
    defaults: { vdd: '5', vtn: '0.7', vtp: '0.7', vin: '1' } });

  spec({ id: 'invertingAmp', family: 'opamp', title: 'Inverting amp', blurb: 'Ideal op-amp. The inverting input sits at 0 V.',
    defaultUnknown: 'gain', unknowns: [u('gain', 'Vout'), u('rf', 'Rf'), u('vin', 'Vin')],
    fields: [n('vin', 'Vin', 'V'), n('rin', 'Rin', 'Ω'), n('rf', 'Rf', 'Ω'), n('vsat', 'Swing limit', 'V', 'Magnitude of the largest |Vout| you will accept.'), n('av', 'Target |Av|', ''), n('voutmag', 'Target |Vout|', 'V')],
    visible: { gain: ['vin', 'rin', 'rf', 'vsat'], rf: ['vin', 'rin', 'vsat', 'av'], vin: ['rin', 'rf', 'vsat', 'voutmag'] },
    defaults: { vin: '0.2', rin: '10000', rf: '100000', vsat: '12', av: '10', voutmag: '2' } });
  spec({ id: 'nonInvertingAmp', family: 'opamp', title: 'Non-inverting amp', blurb: 'Gain is 1 + Rf/Rg. Both inputs sit at Vin.',
    defaultUnknown: 'gain', unknowns: [u('gain', 'Vout'), u('rf', 'Rf'), u('rg', 'Rg')],
    fields: [n('vin', 'Vin', 'V'), n('rg', 'Rg', 'Ω'), n('rf', 'Rf', 'Ω'), n('vsat', 'Swing limit', 'V'), n('av', 'Target Av', '')],
    visible: { gain: ['vin', 'rg', 'rf', 'vsat'], rf: ['vin', 'rg', 'vsat', 'av'], rg: ['vin', 'rf', 'vsat', 'av'] },
    defaults: { vin: '0.2', rg: '10000', rf: '90000', vsat: '12', av: '10' } });
  spec({ id: 'summingAmp', family: 'opamp', title: 'Summing amp', blurb: 'Two-input inverting summer. The summing node is a virtual ground.',
    defaultUnknown: 'output', unknowns: [u('output', 'Vout'), u('rf', 'Rf')],
    fields: [n('v1', 'V1', 'V'), n('r1', 'R1', 'Ω'), n('v2', 'V2', 'V'), n('r2', 'R2', 'Ω'), n('rf', 'Rf', 'Ω'), n('vsat', 'Swing limit', 'V'), n('vout', 'Target |Vout|', 'V')],
    visible: { output: ['v1', 'r1', 'v2', 'r2', 'rf', 'vsat'], rf: ['v1', 'r1', 'v2', 'r2', 'vsat', 'vout'] },
    defaults: { v1: '1', r1: '10000', v2: '1', r2: '10000', rf: '10000', vsat: '12', vout: '2' } });
  spec({ id: 'diffAmp', family: 'opamp', title: 'Difference amp', blurb: 'Matched pairs. Vout = (Rf/R1)·(V2 − V1).',
    defaultUnknown: 'output', unknowns: [u('output', 'Vout'), u('rf', 'Rf')],
    fields: [n('v1', 'V1', 'V'), n('v2', 'V2', 'V'), n('r1', 'Rin', 'Ω'), n('rf', 'Rf', 'Ω'), n('vsat', 'Swing limit', 'V'), n('gain', 'Target gain', '')],
    visible: { output: ['v1', 'v2', 'r1', 'rf', 'vsat'], rf: ['v1', 'v2', 'r1', 'vsat', 'gain'] },
    defaults: { v1: '1', v2: '1.2', r1: '10000', rf: '10000', vsat: '12', gain: '1' } });
  spec({ id: 'integrator', family: 'opamp', title: 'Integrator', blurb: 'Constant input makes a ramp. Ideal, no practical reset resistor.',
    defaultUnknown: 'ramp', unknowns: [u('ramp', 'v(t)'), u('time', 'Time'), u('c', 'C')],
    fields: [n('r', 'R', 'Ω'), n('c', 'C', 'F'), n('vin', 'Vin', 'V'), n('t', 't', 's'), n('v0', 'v(0)', 'V'), n('vt', 'Target v', 'V'), n('vsat', 'Swing limit', 'V')],
    visible: { ramp: ['r', 'c', 'vin', 't', 'v0', 'vsat'], time: ['r', 'c', 'vin', 'v0', 'vt', 'vsat'], c: ['r', 'vin', 't', 'v0', 'vt', 'vsat'] },
    defaults: { r: '100000', c: '0.000001', vin: '1', t: '0.1', v0: '0', vt: '-1', vsat: '12' } });
  spec({ id: 'differentiator', family: 'opamp', title: 'Differentiator', blurb: 'A constant slope in gives a constant voltage out. Ideal, no high-frequency roll-off.',
    defaultUnknown: 'output', unknowns: [u('output', 'Vout'), u('r', 'R'), u('c', 'C')],
    fields: [n('r', 'R', 'Ω'), n('c', 'C', 'F'), n('slope', 'Slope', 'V/s'), n('vout', 'Target Vout', 'V'), n('vsat', 'Swing limit', 'V')],
    visible: { output: ['r', 'c', 'slope', 'vsat'], r: ['c', 'slope', 'vout', 'vsat'], c: ['r', 'slope', 'vout', 'vsat'] },
    defaults: { r: '10000', c: '0.000001', slope: '100', vout: '-1', vsat: '12' } });
  spec({ id: 'comparator', family: 'opamp', title: 'Comparator', blurb: 'Open loop. Output sits on one rail or the other. No linear gain.',
    defaultUnknown: 'output', unknowns: [u('output', 'Rail')],
    fields: [n('vin', 'Vin', 'V'), n('vref', 'Vref', 'V'), n('voh', 'High rail', 'V'), n('vol', 'Low rail', 'V')],
    visible: { output: ['vin', 'vref', 'voh', 'vol'] }, defaults: { vin: '2', vref: '1.5', voh: '5', vol: '0' } });

  spec({ id: 'astable555', family: 'timer', title: '555 astable', blurb: 'Free-running timer. Duty of a plain astable stays above 50%.',
    defaultUnknown: 'frequency', unknowns: [u('frequency', 'Frequency'), u('c', 'C'), u('r1', 'R1'), u('r2', 'R2'), u('resistors', 'R1 and R2')],
    fields: [n('vcc', 'Vcc', 'V'), n('r1', 'R1 (Vcc side)', 'Ω'), n('r2', 'R2 (cap side)', 'Ω'), n('c', 'C', 'F'), n('frequency', 'f', 'Hz'), n('duty', 'Duty', '%')],
    visible: { frequency: ['vcc', 'r1', 'r2', 'c'], c: ['vcc', 'r1', 'r2', 'frequency'], r1: ['vcc', 'r2', 'c', 'frequency'], r2: ['vcc', 'r1', 'c', 'frequency'], resistors: ['vcc', 'c', 'frequency', 'duty'] },
    defaults: { vcc: '5', r1: '1000', r2: '1000', c: '0.000001', frequency: '481', duty: '67' } });
  spec({ id: 'monostable555', family: 'timer', title: '555 monostable', blurb: 'One-shot. Pulse width is ln(3)·R·C.',
    defaultUnknown: 'width', unknowns: [u('width', 'Pulse width'), u('r', 'R'), u('c', 'C')],
    fields: [n('vcc', 'Vcc', 'V'), n('r', 'R', 'Ω'), n('c', 'C', 'F'), n('width', 't', 's')],
    visible: { width: ['vcc', 'r', 'c'], r: ['vcc', 'c', 'width'], c: ['vcc', 'r', 'width'] },
    defaults: { vcc: '5', r: '10000', c: '0.000001', width: '0.011' } });
  spec({ id: 'ledFlasher', family: 'digital', title: 'LED flasher', blurb: '555 astable with an LED and its resistor on the output.',
    defaultUnknown: 'rate', unknowns: [u('rate', 'Flash rate'), u('c', 'C'), u('rled', 'LED resistor')],
    fields: [n('vcc', 'Vcc', 'V'), n('r1', 'R1', 'Ω'), n('r2', 'R2', 'Ω'), n('c', 'C', 'F'), n('vf', 'LED Vf', 'V'), n('rled', 'Rled', 'Ω'), n('frequency', 'f', 'Hz'), n('iled', 'LED current', 'A')],
    visible: { rate: ['vcc', 'r1', 'r2', 'c', 'vf', 'rled'], c: ['vcc', 'r1', 'r2', 'frequency', 'vf', 'rled'], rled: ['vcc', 'r1', 'r2', 'c', 'vf', 'iled'] },
    defaults: { vcc: '5', r1: '10000', r2: '100000', c: '0.000001', vf: '2', rled: '330', frequency: '6.86', iled: '0.009' } });
  spec({ id: 'sevenSegment', family: 'digital', title: '7-segment drive', blurb: 'Common-cathode digit. One resistor per lit segment. BCD pattern is the usual map.',
    defaultUnknown: 'map', unknowns: [u('map', 'Segments and current'), u('r', 'R per segment')],
    fields: [ch('digit', 'Digit', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map((d) => [String(d), String(d)])), n('vcc', 'Vcc', 'V'), n('vf', 'Vf', 'V'), n('r', 'R each', 'Ω'), n('iseg', 'I per segment', 'A')],
    visible: { map: ['digit', 'vcc', 'vf', 'r'], r: ['digit', 'vcc', 'vf', 'iseg'] },
    defaults: { digit: '8', vcc: '5', vf: '2', r: '330', iseg: '0.009' } });

  spec({ id: 'classOverview', family: 'amplifier', title: 'Class overview', blurb: 'Ideal class efficiencies used as a planning sketch, not a measured amplifier.',
    defaultUnknown: 'dissipation', unknowns: [u('dissipation', 'Supply and heat')],
    fields: [ch('ampClass', 'Class', [['A', 'A'], ['B', 'B'], ['AB', 'AB'], ['D', 'D']]), n('pout', 'Pout', 'W'), n('vsupply', 'Supply', 'V'), Object.assign(n('eta', 'Efficiency override', '%', 'Leave blank to use the ideal class figure.'), { optional: true })],
    visible: { dissipation: ['ampClass', 'pout', 'vsupply', 'eta'] }, defaults: { ampClass: 'B', pout: '10', vsupply: '24', eta: '' } });
  spec({ id: 'discretePower', family: 'amplifier', title: 'Discrete CE stage', blurb: 'Class-A CE stage. Quiescent transistor power and resistor power from the bias point.',
    defaultUnknown: 'power', unknowns: [u('power', 'Quiescent power')],
    fields: [n('vcc', 'Vcc', 'V'), n('r1', 'R1', 'Ω'), n('r2', 'R2', 'Ω'), n('rc', 'Rc', 'Ω'), n('re', 'Re', 'Ω'), n('beta', 'β', '')],
    visible: { power: ['vcc', 'r1', 'r2', 'rc', 're', 'beta'] }, defaults: { vcc: '12', r1: '47000', r2: '10000', rc: '2200', re: '1000', beta: '100' } });
  spec({ id: 'opAmpPower', family: 'amplifier', title: 'Op-amp load amp', blurb: 'Non-inverting stage into a resistive load. Ideal output current.',
    defaultUnknown: 'load', unknowns: [u('load', 'Load power'), u('rf', 'Rf')],
    fields: [n('vin', 'Vin', 'V'), n('rg', 'Rg', 'Ω'), n('rf', 'Rf', 'Ω'), n('rl', 'RL', 'Ω'), n('vsat', 'Swing limit', 'V'), n('av', 'Target Av', '')],
    visible: { load: ['vin', 'rg', 'rf', 'rl', 'vsat'], rf: ['vin', 'rg', 'rl', 'vsat', 'av'] }, defaults: { vin: '0.5', rg: '10000', rf: '10000', rl: '8', vsat: '12', av: '2' } });
  spec({ id: 'linearDrop', family: 'power', title: 'Linear regulator drop', blurb: 'Pass element drops Vin − Vout. Heat is that drop times load current.',
    defaultUnknown: 'drop', unknowns: [u('drop', 'Drop and heat'), u('iload', 'Max current'), u('vin', 'Min Vin')],
    fields: [n('vin', 'Vin', 'V'), n('vout', 'Vout', 'V'), n('iload', 'Iload', 'A'), n('pdmax', 'Pd max', 'W'), n('dropout', 'Dropout', 'V')],
    visible: { drop: ['vin', 'vout', 'iload'], iload: ['vin', 'vout', 'pdmax'], vin: ['vout', 'iload', 'dropout'] }, defaults: { vin: '12', vout: '5', iload: '0.5', pdmax: '2', dropout: '2' } });
  spec({ id: 'idealBuck', family: 'power', title: 'Ideal buck', blurb: 'Lossless step-down. Duty is Vout/Vin. Input current follows power balance.',
    defaultUnknown: 'duty', unknowns: [u('duty', 'Duty and Iin'), u('vout', 'Vout'), u('iin', 'Iin')],
    fields: [n('vin', 'Vin', 'V'), n('vout', 'Vout', 'V'), n('iout', 'Iout', 'A'), n('duty', 'Duty', '')],
    visible: { duty: ['vin', 'vout', 'iout'], vout: ['vin', 'duty', 'iout'], iin: ['vin', 'vout', 'iout'] }, defaults: { vin: '12', vout: '5', iout: '2', duty: '0.4167' } });

  spec({ id: 'complexConvert', family: 'mathTools', title: 'Complex convert', blurb: 'Rectangular, polar, and exponential forms of one complex value.',
    defaultUnknown: 'polar', unknowns: [u('polar', 'To polar'), u('rect', 'To rectangular')],
    fields: [n('x', 'Real', ''), n('y', 'Imag', ''), n('magnitude', 'Magnitude', ''), n('angleDeg', 'Angle', '°')],
    visible: { polar: ['x', 'y'], rect: ['magnitude', 'angleDeg'] }, defaults: { x: '3', y: '4', magnitude: '5', angleDeg: '53.1301' } });
  spec({ id: 'impedanceCombo', family: 'mathTools', title: 'Series / parallel Z', blurb: 'Two impedances, each R + jX, combined in series or in parallel.',
    defaultUnknown: 'result', unknowns: [u('result', 'Combined Z')],
    fields: [ch('combo', 'Connection', [['series', 'Series'], ['parallel', 'Parallel']]), n('r1', 'R1', 'Ω'), n('x1', 'X1', 'Ω'), n('r2', 'R2', 'Ω'), n('x2', 'X2', 'Ω')],
    visible: { result: ['combo', 'r1', 'x1', 'r2', 'x2'] }, defaults: { combo: 'series', r1: '50', x1: '20', r2: '10', x2: '-5' } });
  spec({ id: 'lMatch', family: 'mathTools', title: 'L-section match', blurb: 'Lossless L-network between two real resistances at one frequency.',
    defaultUnknown: 'parts', unknowns: [u('parts', 'L and C')],
    fields: [n('rs', 'Rs', 'Ω'), n('rl', 'RL', 'Ω'), n('f', 'f', 'Hz'), ch('topology', 'Shape', [['lowpass', 'Low-pass'], ['highpass', 'High-pass']])],
    visible: { parts: ['rs', 'rl', 'f', 'topology'] }, defaults: { rs: '50', rl: '200', f: '1000000', topology: 'lowpass' } });
  spec({ id: 'quarterWave', family: 'mathTools', title: 'Quarter-wave match', blurb: 'Real Z0 = √(Zin·Zload). Length is λ/4 on an ideal line.',
    defaultUnknown: 'z0', unknowns: [u('z0', 'Line Z0'), u('zload', 'Load')],
    fields: [n('zLoad', 'Zload', 'Ω'), n('zIn', 'Zin wanted', 'Ω'), n('z0', 'Z0', 'Ω'), n('f', 'f', 'Hz'), n('vf', 'Velocity factor', '')],
    visible: { z0: ['zLoad', 'zIn', 'f', 'vf'], zload: ['z0', 'zIn', 'f', 'vf'] }, defaults: { zLoad: '200', zIn: '50', z0: '100', f: '100000000', vf: '1' } });
  spec({ id: 'stubCancel', family: 'mathTools', title: 'Stub length', blurb: 'Shorted or open ideal stub that presents a reactance, or cancels one.',
    defaultUnknown: 'length', unknowns: [u('length', 'Length')],
    fields: [n('x', 'Reactance', 'Ω', 'Ohms of X. Cancel mode builds the stub for the opposite sign.'), n('z0', 'Z0', 'Ω'), n('f', 'f', 'Hz'), n('vf', 'Velocity factor', ''),
      ch('kind', 'Stub', [['shorted', 'Shorted'], ['open', 'Open']]), ch('goal', 'Goal', [['present', 'Present this X'], ['cancel', 'Cancel this X']])],
    visible: { length: ['x', 'z0', 'f', 'vf', 'kind', 'goal'] }, defaults: { x: '50', z0: '50', f: '300000000', vf: '1', kind: 'shorted', goal: 'present' } });

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

  function rectifier(unknown, inp, bridge) {
    const ac = acSource(inp);
    const vf = nonNeg(inp, 'vf', 'Vf');
    const rload = pos(inp, 'rload', 'Rload');
    const drops = bridge ? 2 : 1;
    const k = bridge ? 2 : 1;
    let vrms, vdcIn, f, vpk, vdcAvg, vdcCap, iCap, c, ripple;
    if (ac) {
      vrms = pos(inp, 'vrms', 'Vrms'); vdcIn = 0; f = pos(inp, 'f', 'f');
      const peak = vrms * Math.SQRT2 - drops * vf;
      if (!(peak > 0)) throw outOfRange('The peak never clears the diode drop. Raise Vrms or lower Vf.');
      vpk = peak; vdcAvg = k * vpk / Math.PI; vdcCap = vpk; iCap = vdcCap / rload;
      if (unknown === 'c') { const target = pos(inp, 'ripple', 'Ripple'); c = iCap / (k * f * target); }
      else if (unknown === 'report') c = pos(inp, 'c', 'C');
      else throw badUnknown();
      ripple = iCap / (k * f * c);
    } else {
      if (unknown === 'c') throw outOfRange('Ripple is zero on a DC source, so C is not set by a ripple target. Switch the source to AC sine to size C.');
      if (unknown !== 'report') throw badUnknown();
      vdcIn = posIfPresent(inp, 'vdc', 'Vdc', 12); vrms = 0; f = 0;
      const held = Math.max(vdcIn - drops * vf, 0);
      vpk = held; vdcAvg = held; vdcCap = held; iCap = held / rload; c = pos(inp, 'c', 'C'); ripple = 0;
    }
    const sourceName = ac ? 'Vac' : 'Vdc';
    const sourceDetail = ac ? eng(vrms) + ' Vrms' : eng(vdcIn) + ' Vdc';
    const elements = [src('ac', sourceName, sourceDetail, 14, 58, 14, 24, ac ? AC_FLAG : 0)];
    if (bridge) {
      elements.push(wire('a', 14, 24, 36, 24), dio('d1', 'D1', eng(vf) + ' V', 36, 24, 52, 16), dio('d2', 'D2', eng(vf) + ' V', 52, 16, 68, 24),
        dio('d3', 'D3', eng(vf) + ' V', 36, 48, 52, 36), dio('d4', 'D4', eng(vf) + ' V', 52, 36, 68, 48),
        wire('m1', 36, 24, 36, 48), wire('m2', 68, 24, 68, 48), wire('out', 52, 16, 84, 16),
        cap('c', 'C', eng(c) + ' F', 84, 16, 84, 62), res('rl', 'RL', eng(rload) + ' Ω', 72, 16, 72, 62), wire('bot', 14, 62, 84, 62), gnd('g', 84, 62));
    } else {
      elements.push(wire('a', 14, 24, 36, 24), dio('d', 'D', eng(vf) + ' V', 36, 24, 58, 24), wire('b', 58, 24, 78, 24),
        cap('c', 'C', eng(c) + ' F', 78, 24, 78, 64), res('rl', 'RL', eng(rload) + ' Ω', 64, 24, 64, 64), wire('bot', 14, 64, 78, 64), gnd('g', 78, 64));
    }
    const quantities = [q('vpk', ac ? 'Vpeak out' : 'Vout', vpk, 'V'), q('vdcAvg', ac ? 'Vdc average' : 'Vdc out', vdcAvg, 'V'), q('vdcCap', 'Vdc with C', vdcCap, 'V'),
      q('ripple', 'Ripple', ripple, 'V', unknown === 'c'), q('c', 'C', c, 'F', unknown === 'c'), q('iload', 'Iload', iCap, 'A'), q('rload', 'Rload', rload, 'Ω'),
      q('vf', 'Vf', vf, 'V'), q('ac', 'AC sine', ac ? 1 : 0, ''), q('bridge', 'Bridge', bridge ? 1 : 0, '')];
    if (ac) quantities.push(q('f', 'f', f, 'Hz'), q('vrms', 'Vrms', vrms, 'V'), q('vsrcpk', 'Source peak', vrms * Math.SQRT2, 'V'));
    else quantities.push(q('vdc', 'Vdc', vdcIn, 'V'));
    const steps = ac
      ? ['Vp = Vrms·√2 − ' + drops + '·Vf = ' + eng(vpk) + ' V', bridge ? 'No-cap average = 2·Vp/π' : 'No-cap average = Vp/π', 'Cap-input ripple ≈ I / (' + (bridge ? '2f' : 'f') + '·C) = ' + eng(ripple) + ' V']
      : ['Vout = Vdc − ' + drops + '·Vf = ' + eng(vpk) + ' V', 'Forward polarity. This model does not conduct a reverse DC source.', 'Ripple is 0. The capacitor does not set the DC level.'];
    const notes = ac
      ? [bridge ? 'Bridge: two diodes conduct each half cycle.' : 'Half-wave: the diode conducts on one half cycle.', 'The capacitor estimate assumes light load and a peak near Vp minus the drops.', 'Ripple is the ideal I/(fC) sketch, not a simulated waveform.']
      : [bridge ? 'Bridge: two diode drops in series with the DC source.' : 'Half-wave: one diode drop in series with the DC source.', 'Steady DC, forward polarity. Not an RMS or peak sine.', 'Ripple is zero. Switch to AC sine to size C from a ripple target.'];
    return pack(bridge ? 'fullBridge' : 'halfWave', {
      headline: (ac ? 'Vpeak out = ' : 'Vout = ') + eng(vpk) + ' V', elements,
      nodes: [node('ac', ac ? 'Vrms' : 'Vdc', ac ? vrms : vdcIn, 'V', 14, 24), node('out', ac ? 'Vpeak' : 'Vout', vpk, 'V', bridge ? 84 : 78, bridge ? 16 : 24), node('gnd', 'GND', 0, 'V', bridge ? 84 : 78, bridge ? 62 : 64)],
      branches: [branch('i', 'Iload (cap)', iCap, 'A', bridge ? 72 : 64, 28, bridge ? 72 : 64, 56)],
      quantities, steps, notes,
    });
  }
  SOLVERS.halfWave = (u2, inp) => rectifier(u2, inp, false);
  SOLVERS.fullBridge = (u2, inp) => rectifier(u2, inp, true);

  SOLVERS.shuntClipper = (unknown, inp) => {
    const ac = acSource(inp);
    const drive = ac ? pos(inp, 'vp', 'Vp') : posIfPresent(inp, 'vdc', 'Vdc', 10);
    const f = ac ? posIfPresent(inp, 'f', 'f', 1000) : 0;
    const vf = nonNeg(inp, 'vf', 'Vf');
    const vbias = finite(inp, 'vbias', 'Bias');
    const vclip = vbias + vf;
    let r, ipeak;
    if (unknown === 'r') {
      ipeak = pos(inp, 'ipeak', 'Ipeak');
      if (!(drive > vclip)) throw outOfRange('The source never reaches the clip level, so R is not set by that current.');
      r = (drive - vclip) / ipeak;
    } else if (unknown === 'report') {
      r = pos(inp, 'r', 'R'); ipeak = drive > vclip ? (drive - vclip) / r : 0;
    } else throw badUnknown();
    const vout = Math.min(drive, vclip);
    const sourceName = ac ? 'Vp' : 'Vdc';
    const quantities = [q('vout', ac ? 'Vout peak' : 'Vout', vout, 'V'), q('vclip', 'Clip level', vclip, 'V'), q('ipeak', ac ? 'Ipeak' : 'I', ipeak, 'A'),
      q('r', 'R', r, 'Ω', unknown === 'r'), q('vf', 'Vf', vf, 'V'), q('vbias', 'Vbias', vbias, 'V'), q('ac', 'AC sine', ac ? 1 : 0, '')];
    if (ac) quantities.push(q('vp', 'Vp', drive, 'V'), q('f', 'f', f, 'Hz')); else quantities.push(q('vdc', 'Vdc', drive, 'V'));
    return pack('shuntClipper', {
      headline: (ac ? 'Vout peak = ' : 'Vout = ') + eng(vout) + ' V',
      elements: [src('vs', sourceName, eng(drive) + (ac ? ' Vpk' : ' Vdc'), 16, 60, 16, 22, ac ? AC_FLAG : 0), wire('a', 16, 22, 40, 22), res('r', 'R', eng(r) + ' Ω', 40, 22, 64, 22),
        wire('b', 64, 22, 82, 22), dio('d', 'D', eng(vf) + ' V', 70, 22, 70, 64), src('vb', 'Vb', eng(vbias) + ' V', 70, 64, 70, 72), wire('g', 16, 72, 70, 72), gnd('gnd', 82, 72)],
      nodes: [node('in', sourceName, drive, 'V', 16, 22), node('out', 'Vout', vout, 'V', 82, 22), node('gnd', 'GND', 0, 'V', 82, 72)],
      branches: [branch('i', ac ? 'Ipeak' : 'I', ipeak, 'A', 44, 22, 60, 22)], quantities,
      steps: ['Clip level = Vbias + Vf = ' + eng(vclip) + ' V',
        drive > vclip ? (ac ? 'Ipeak = (Vp − Vclip) / R' : 'I = (Vdc − Vclip) / R') : (ac ? 'Peak stays under the clip. Diode current is 0.' : 'DC stays under the clip. Diode current is 0.')],
      notes: ['Shunt clipper. The diode conducts only after the output tries to pass the clip level.',
        ac ? 'Below the clip, this ideal model ignores the diode and passes the peak.' : 'On DC the output is Vdc until that level passes the clip, then it holds.',
        'A real diode is not a perfect threshold. Softness is not modeled.'],
    });
  };

  SOLVERS.clamper = (unknown, inp) => {
    if (unknown !== 'report') throw badUnknown();
    const vp = pos(inp, 'vp', 'Vp');
    const vf = nonNeg(inp, 'vf', 'Vf');
    const vmin = -vf, vmax = 2 * vp - vf;
    return pack('clamper', {
      headline: 'Vmax = ' + eng(vmax) + ' V',
      elements: [src('vs', 'Vp', eng(vp) + ' Vpk', 16, 58, 16, 28, AC_FLAG), wire('a', 16, 28, 36, 28), cap('c', 'C', 'DC block', 36, 28, 58, 28), wire('b', 58, 28, 84, 28),
        dio('d', 'D', eng(vf) + ' V', 68, 28, 68, 64), gnd('g', 68, 64)],
      nodes: [node('in', 'Vp', vp, 'V', 16, 28), node('hi', 'Vmax', vmax, 'V', 84, 28), node('lo', 'Vmin', vmin, 'V', 84, 48), node('gnd', 'GND', 0, 'V', 68, 64)],
      branches: [branch('i', 'Steady current', 0, 'A', 40, 28, 54, 28)],
      quantities: [q('vmax', 'Vmax', vmax, 'V'), q('vmin', 'Vmin', vmin, 'V'), q('swing', 'Swing', vmax - vmin, 'V'), q('vp', 'Vp', vp, 'V'), q('vf', 'Vf', vf, 'V')],
      steps: ['Negative peak clamps near −Vf.', 'Positive peak ≈ 2·Vp − Vf.', 'Peak-to-peak swing stays about 2·Vp.'],
      notes: ['Series capacitor, diode cathode toward the output, anode at ground.', 'After a few cycles the capacitor holds a DC shift. This is that steady picture.', 'Ideal diode and a stiff source. Load bleed is not included.'],
    });
  };

  const VBE = 0.7, VCESAT = 0.2, VT = 0.026;
  const npnPart = (id, l, x, y) => part(id, 'npn', l, '', x, y, x, y);
  const nmosPart = (id, l, x, y, sc) => Object.assign(part(id, 'nmos', l, '', x, y, x, y), sc ? { scale: sc } : {});
  const pmosPart = (id, l, x, y, sc) => Object.assign(part(id, 'pmos', l, '', x, y, x, y), sc ? { scale: sc } : {});

  function bjtBiasCalc(vcc, r1, r2, rc, re, beta) {
    const vbb = vcc * r2 / (r1 + r2), rb = 1 / (1 / r1 + 1 / r2);
    const ieActive = (vbb - VBE) / (re + rb / (beta + 1));
    if (ieActive <= 0) return { vbb, rb, ib: 0, ic: 0, ie: 0, vb: vbb, vc: vcc, ve: 0, vce: vcc, saturated: false, cutoff: true, iR1: (vcc - vbb) / r1, iR2: vbb / r2 };
    const icA = ieActive * beta / (beta + 1), veA = ieActive * re, vcA = vcc - icA * rc, vceA = vcA - veA;
    if (vceA < VCESAT) {
      const ic = (vcc - VCESAT) / (rc + re), ie = ic, ve = ie * re, vc = ve + VCESAT, vb = ve + VBE;
      const iR1 = Math.max(0, (vcc - vb) / r1), iR2 = Math.max(0, vb / r2);
      return { vbb, rb, ib: Math.max(0, iR1 - iR2), ic, ie, vb, vc, ve, vce: VCESAT, saturated: true, cutoff: false, iR1, iR2 };
    }
    const vb = veA + VBE;
    return { vbb, rb, ib: icA / beta, ic: icA, ie: ieActive, vb, vc: vcA, ve: veA, vce: vceA, saturated: false, cutoff: false, iR1: (vcc - vb) / r1, iR2: vb / r2 };
  }
  function bjtElements(vcc, r1, r2, rc, re) {
    return [npnPart('npn', 'Q', 52, 44), wire('railL', 18, 14, 72, 14), res('r1', 'R1', eng(r1) + ' Ω', 28, 14, 28, 40), res('r2', 'R2', eng(r2) + ' Ω', 28, 40, 28, 70),
      wire('base', 28, 40, 36, 44), res('rc', 'Rc', eng(rc) + ' Ω', 70, 14, 70, 32), wire('col', 70, 32, 62, 28), res('re', 'Re', eng(re) + ' Ω', 62, 60, 62, 70),
      wire('gndw', 28, 70, 70, 70), gnd('g', 70, 70), src('vcc', 'Vcc', eng(vcc) + ' V', 18, 70, 18, 14)];
  }
  const bjtNodes = (b, vcc) => [node('vcc', 'Vcc', vcc, 'V', 18, 14), node('b', 'Vb', b.vb, 'V', 28, 40), node('c', 'Vc', b.vc, 'V', 70, 32), node('e', 'Ve', b.ve, 'V', 62, 60), node('gnd', 'GND', 0, 'V', 70, 70)];
  const bjtBranches = (b) => [branch('ir1', 'IR1', b.iR1, 'A', 28, 18, 28, 36), branch('ic', 'Ic', b.ic, 'A', 70, 18, 70, 30), branch('ie', 'Ie', b.ie, 'A', 62, 62, 62, 68)];

  SOLVERS.bjtBias = (unknown, inp) => {
    const vcc = pos(inp, 'vcc', 'Vcc'), r1 = pos(inp, 'r1', 'R1'), r2 = pos(inp, 'r2', 'R2'), beta = pos(inp, 'beta', 'β');
    let rc = 0, re = 0;
    if (unknown === 'point') { rc = pos(inp, 'rc', 'Rc'); re = pos(inp, 're', 'Re'); }
    else if (unknown === 're') {
      rc = pos(inp, 'rc', 'Rc'); const icT = pos(inp, 'ic', 'Ic');
      const vbb = vcc * r2 / (r1 + r2), rb = 1 / (1 / r1 + 1 / r2);
      if (!(vbb > VBE)) throw outOfRange('The base divider sits at or below 0.7 V, so this β model is cut off.');
      const ie = icT * (beta + 1) / beta;
      re = (vbb - VBE) / ie - rb / (beta + 1);
      if (!(re > 0)) throw outOfRange('That Ic is too high for the base divider. Re would not be positive.');
    } else if (unknown === 'rc') {
      re = pos(inp, 're', 'Re'); const vcT = finite(inp, 'vc', 'Vc');
      const pre = bjtBiasCalc(vcc, r1, r2, 1, re, beta);
      if (pre.cutoff || !(pre.ic > 0)) throw outOfRange('The transistor is cut off, so Rc does not set Vc.');
      if (!(vcT < vcc)) throw outOfRange('Vc has to be below Vcc.');
      rc = (vcc - vcT) / pre.ic;
      if (!(rc > 0)) throw outOfRange('Rc would not be positive.');
    } else throw badUnknown();
    const bias = bjtBiasCalc(vcc, r1, r2, rc, re, beta);
    let warning = null;
    if (bias.cutoff) warning = 'Vbb is below 0.7 V. This model says the transistor is cut off.';
    if (bias.saturated) warning = 'Active-region β put Vce under 0.2 V. Nodes use a saturation sketch with Vce fixed at 0.2 V.';
    return pack('bjtBias', { headline: 'Ic = ' + eng(bias.ic) + ' A', elements: bjtElements(vcc, r1, r2, rc, re), nodes: bjtNodes(bias, vcc), branches: bjtBranches(bias),
      quantities: [q('ic', 'Ic', bias.ic, 'A', unknown === 're'), q('ib', 'Ib', bias.ib, 'A'), q('ie', 'Ie', bias.ie, 'A'), q('vb', 'Vb', bias.vb, 'V'), q('vc', 'Vc', bias.vc, 'V', unknown === 'rc'),
        q('ve', 'Ve', bias.ve, 'V'), q('vce', 'Vce', bias.vce, 'V'), q('re', 'Re', re, 'Ω', unknown === 're'), q('rc', 'Rc', rc, 'Ω', unknown === 'rc'), q('r1', 'R1', r1, 'Ω'), q('r2', 'R2', r2, 'Ω'), q('vcc', 'Vcc', vcc, 'V')],
      steps: ['Vbb = Vcc·R2/(R1+R2) = ' + eng(bias.vbb) + ' V', 'Ie = (Vbb − 0.7) / (Re + Rb/(β+1))', 'Vc = Vcc − Ic·Rc,  Vce = Vc − Ve'],
      notes: ['Vbe is fixed at 0.7 V. β does not change with current.', 'Base loading is in the Thevenin term Rb/(β+1).', 'Not a Gummel–Poon model. Early effect is ignored.'], warning });
  };

  SOLVERS.ceAmp = (unknown, inp) => {
    const vcc = pos(inp, 'vcc', 'Vcc'), r1 = pos(inp, 'r1', 'R1'), r2 = pos(inp, 'r2', 'R2'), re = pos(inp, 're', 'Re'), beta = pos(inp, 'beta', 'β'), rl = pos(inp, 'rl', 'RL');
    const bypass = choice(inp, 'bypass', ['bypassed', 'open'], 'bypassed', 'Emitter');
    const seed = bjtBiasCalc(vcc, r1, r2, 1, re, beta);
    if (seed.cutoff || !(seed.ic > 0)) throw outOfRange('Cut off. There is no small-signal gm.');
    const gm0 = seed.ic / VT, denom = bypass === 'bypassed' ? 1 : (1 + gm0 * re);
    let rc = 0;
    if (unknown === 'rc') {
      const av = pos(inp, 'av', '|Av|'), k = av * denom / gm0;
      if (!(rl > k)) throw outOfRange('RL is too small to reach that gain with Rc || RL.');
      rc = k * rl / (rl - k);
    } else if (unknown === 'gain') rc = pos(inp, 'rc', 'Rc'); else throw badUnknown();
    const bias = bjtBiasCalc(vcc, r1, r2, rc, re, beta);
    const gm = bias.ic / VT, denomU = bypass === 'bypassed' ? 1 : (1 + gm * re), rac = 1 / (1 / rc + 1 / rl);
    const av = bias.saturated || bias.cutoff ? 0 : -gm * rac / denomU;
    const rpi = beta / gm, rinBase = bypass === 'bypassed' ? rpi : (rpi + (beta + 1) * re), rin = 1 / (1 / r1 + 1 / r2 + 1 / rinBase);
    return pack('ceAmp', { headline: 'Av = ' + av.toFixed(2), elements: bjtElements(vcc, r1, r2, rc, re).concat([cap('cc', 'Cc', 'AC', 70, 32, 86, 32), res('rl', 'RL', eng(rl) + ' Ω', 86, 32, 86, 70)]),
      nodes: bjtNodes(bias, vcc), branches: bjtBranches(bias),
      quantities: [q('av', 'Av', av, '', unknown === 'gain' || unknown === 'rc'), q('gm', 'gm', gm, 'S'), q('rin', 'Rin', rin, 'Ω'), q('rout', 'Rout', rc, 'Ω'), q('rc', 'Rc', rc, 'Ω', unknown === 'rc'),
        q('ic', 'Ic', bias.ic, 'A'), q('vce', 'Vce', bias.vce, 'V'), q('vc', 'Vc', bias.vc, 'V'), q('vb', 'Vb', bias.vb, 'V'), q('vcc', 'Vcc', vcc, 'V'), q('r1', 'R1', r1, 'Ω'), q('r2', 'R2', r2, 'Ω'), q('re', 'Re', re, 'Ω'), q('rl', 'RL', rl, 'Ω')],
      steps: ['gm = Ic / 26 mV = ' + eng(gm) + ' S', bypass === 'bypassed' ? 'Av ≈ −gm · (Rc || RL)' : 'Av ≈ −gm · (Rc || RL) / (1 + gm·Re)', 'Rin ≈ R1 || R2 || rπ (plus (β+1)Re if Re is unbypassed)'],
      notes: ['Midband estimate. Coupling and bypass capacitors are shorts for the signal.', 'Vt is 26 mV, a room-temperature value.', 'Rout is about Rc. The load is AC-coupled and does not move the DC point.'],
      warning: bias.saturated ? 'The DC point is saturated, so the gain number is not meaningful. It is reported as 0.' : null });
  };

  SOLVERS.bjtSwitch = (unknown, inp) => {
    const vcc = pos(inp, 'vcc', 'Vcc'), rc = pos(inp, 'rc', 'Rc'), beta = pos(inp, 'beta', 'β'), vin = pos(inp, 'vin', 'Vin');
    if (!(vin > VBE)) throw outOfRange('Vin has to be above 0.7 V to forward-bias the base.');
    if (!(vcc > VCESAT)) throw outOfRange('Vcc has to be above 0.2 V.');
    const icSat = (vcc - VCESAT) / rc, ibNeed = icSat / beta;
    let rb;
    if (unknown === 'rb') rb = (vin - VBE) / ibNeed; else if (unknown === 'state') rb = pos(inp, 'rb', 'Rb'); else throw badUnknown();
    const ib = (vin - VBE) / rb, saturated = ib >= ibNeed;
    const ic = saturated ? icSat : Math.min(beta * ib, icSat), vc = saturated ? VCESAT : (vcc - ic * rc), forced = ic / ib;
    return pack('bjtSwitch', { headline: saturated ? 'Saturated' : 'Not saturated',
      elements: [src('vin', 'Vin', eng(vin) + ' V', 16, 62, 16, 36), res('rb', 'Rb', eng(rb) + ' Ω', 16, 36, 40, 36), npnPart('q', 'Q', 50, 40), wire('crail', 62, 14, 62, 28),
        res('rc', 'Rc', eng(rc) + ' Ω', 62, 14, 78, 14), src('vcc', 'Vcc', eng(vcc) + ' V', 86, 62, 86, 14), wire('top', 78, 14, 86, 14), wire('base', 40, 36, 34, 40),
        wire('ecol', 62, 28, 60, 24), wire('emitter', 60, 56, 60, 62), wire('bot', 16, 62, 86, 62), gnd('g', 50, 62)],
      nodes: [node('in', 'Vin', vin, 'V', 16, 36), node('b', 'Vb', VBE, 'V', 40, 36), node('c', 'Vc', vc, 'V', 62, 28), node('e', 'Ve', 0, 'V', 60, 56), node('vcc', 'Vcc', vcc, 'V', 86, 14)],
      branches: [branch('ib', 'Ib', ib, 'A', 22, 36, 38, 36), branch('ic', 'Ic', ic, 'A', 64, 14, 76, 14)],
      quantities: [q('rb', 'Rb', rb, 'Ω', unknown === 'rb'), q('rc', 'Rc', rc, 'Ω'), q('vin', 'Vin', vin, 'V'), q('ib', 'Ib', ib, 'A'), q('ic', 'Ic', ic, 'A'), q('vc', 'Vc', vc, 'V'),
        q('forced', 'β forced', forced, ''), q('state', saturated ? 'Saturated' : 'Active', saturated ? 1 : 0, ''), q('vcc', 'Vcc', vcc, 'V')],
      steps: ['Ic(sat) = (Vcc − 0.2) / Rc = ' + eng(icSat) + ' A', 'Ib = (Vin − 0.7) / Rb = ' + eng(ib) + ' A', saturated ? 'Ib is enough. Vc sits near 0.2 V.' : 'Ib is short of Ic(sat)/β. The device stays active.'],
      notes: ['Saturation test: forced β = Ic/Ib is below the device β.', 'Vce(sat) is taken as 0.2 V. Vbe is 0.7 V.', 'The emitter is at ground. This is a low-side switch, not a level shifter.'] });
  };

  function mosOverdrive(vg, rs, kn, vt) {
    if (rs === 0) { const x = vg - vt; return x > 0 ? x : null; }
    const a = 0.5 * kn * rs, c = vt - vg, disc = 1 - 4 * a * c;
    if (disc < 0) return null;
    const x = (-1 + Math.sqrt(disc)) / (2 * a);
    return x > 0 ? x : null;
  }
  SOLVERS.csAmp = (unknown, inp) => {
    const vdd = pos(inp, 'vdd', 'Vdd'), vg = finite(inp, 'vg', 'Vg'), rs = nonNeg(inp, 'rs', 'Rs'), kn = pos(inp, 'kn', 'kn'), vt = finite(inp, 'vt', 'Vt');
    const over = mosOverdrive(vg, rs, kn, vt);
    let rd = 0;
    if (unknown === 'rd') {
      const av = pos(inp, 'av', '|Av|');
      if (!(over > 0)) throw outOfRange('The MOSFET is off, so Rd does not set gain.');
      const gm = kn * over; rd = av * (1 + gm * rs) / gm;
    } else if (unknown === 'point') rd = pos(inp, 'rd', 'Rd'); else throw badUnknown();
    let id, vgs, vs;
    if (over > 0) { id = 0.5 * kn * over * over; vgs = vt + over; vs = id * rs; } else { id = 0; vgs = vg; vs = 0; }
    const vd = vdd - id * rd, vds = vd - vs, vov = Math.max(0, vgs - vt);
    let note = null;
    if (id === 0) note = 'Vgs is not above Vt. Id = 0 in this square-law model.';
    else if (vds < vov) note = 'Vds is below Vov, so the device is not in saturation. The square law overstates Id.';
    const gm = id > 0 ? kn * vov : 0, av = (id > 0 && gm > 0) ? -gm * rd / (1 + gm * rs) : 0;
    return pack('csAmp', { headline: 'Id = ' + eng(id) + ' A',
      elements: [src('vdd', 'Vdd', eng(vdd) + ' V', 78, 68, 78, 14), wire('rail', 40, 14, 78, 14), res('rd', 'Rd', eng(rd) + ' Ω', 62, 14, 62, 34), nmosPart('m', 'M', 50, 44), wire('d', 62, 34, 62, 26),
        res('rs', 'Rs', eng(rs) + ' Ω', 58, 62, 58, 68), src('vg', 'Vg', eng(vg) + ' V', 18, 68, 18, 44), wire('g', 18, 44, 32, 44), wire('bot', 18, 68, 78, 68), gnd('gnd', 50, 68)],
      nodes: [node('g', 'Vg', vg, 'V', 18, 44), node('d', 'Vd', vd, 'V', 62, 34), node('s', 'Vs', vs, 'V', 58, 62), node('vdd', 'Vdd', vdd, 'V', 78, 14), node('gnd', 'GND', 0, 'V', 50, 68)],
      branches: [branch('id', 'Id', id, 'A', 62, 18, 62, 32)],
      quantities: [q('id', 'Id', id, 'A'), q('vgs', 'Vgs', vgs, 'V'), q('vd', 'Vd', vd, 'V'), q('vs', 'Vs', vs, 'V'), q('vds', 'Vds', vds, 'V'), q('gm', 'gm', gm, 'S'), q('av', 'Av', av, '', true),
        q('rd', 'Rd', rd, 'Ω', unknown === 'rd'), q('vdd', 'Vdd', vdd, 'V'), q('vg', 'Vg', vg, 'V'), q('rs', 'Rs', rs, 'Ω')],
      steps: ['Id = (kn/2)·(Vgs − Vt)²', 'gm = kn·(Vgs − Vt)', 'Av = −gm·Rd / (1 + gm·Rs)'],
      notes: ['Square law, long-channel, no channel-length modulation.', 'kn is µCox·W/L in A/V². Rs = 0 is an undegenerated CS stage.', 'Gain assumes the MOSFET is saturated (Vds > Vov).'], warning: note });
  };

  SOLVERS.mosSwitch = (unknown, inp) => {
    const vdd = pos(inp, 'vdd', 'Vdd'), rd = pos(inp, 'rd', 'Rd'), vgs = finite(inp, 'vgs', 'Vgs'), vt = finite(inp, 'vt', 'Vt'), on = vgs > vt;
    let rdson;
    if (unknown === 'rdson') {
      if (!on) throw outOfRange('Vgs is not above Vt, so the switch stays off and Rds(on) does not set Vds.');
      const limit = pos(inp, 'vdslimit', 'Vds limit');
      if (!(limit < vdd)) throw outOfRange('The Vds limit has to be below Vdd.');
      rdson = rd * limit / (vdd - limit);
    } else if (unknown === 'state') rdson = nonNeg(inp, 'rdson', 'Rds(on)'); else throw badUnknown();
    const id = on ? vdd / (rd + rdson) : 0, vds = on ? id * rdson : vdd;
    return pack('mosSwitch', { headline: on ? 'On, Vds = ' + eng(vds) + ' V' : 'Off',
      elements: [src('vdd', 'Vdd', eng(vdd) + ' V', 76, 68, 76, 16), wire('t', 40, 16, 76, 16), res('rd', 'Rd', eng(rd) + ' Ω', 58, 16, 58, 36), nmosPart('m', 'M', 48, 46), wire('d', 58, 36, 60, 28),
        wire('s', 56, 64, 56, 68), src('vg', 'Vgs', eng(vgs) + ' V', 16, 68, 16, 46), wire('g', 16, 46, 30, 46), wire('b', 16, 68, 76, 68), gnd('gnd', 48, 68)],
      nodes: [node('g', 'Vgs', vgs, 'V', 16, 46), node('d', 'Vds', vds, 'V', 58, 36), node('s', 'Vs', 0, 'V', 56, 64), node('vdd', 'Vdd', vdd, 'V', 76, 16)],
      branches: [branch('id', 'Id', id, 'A', 58, 20, 58, 34)],
      quantities: [q('id', 'Id', id, 'A'), q('vds', 'Vds', vds, 'V'), q('rdson', 'Rds(on)', rdson, 'Ω', unknown === 'rdson'), q('rd', 'Rd', rd, 'Ω'), q('vgs', 'Vgs', vgs, 'V'), q('state', on ? 'On' : 'Off', on ? 1 : 0, ''), q('vdd', 'Vdd', vdd, 'V')],
      steps: [on ? 'Id = Vdd / (Rd + Rds(on))' : 'Vgs ≤ Vt, so Id = 0 and the drain sits at Vdd.', 'Vds = Id · Rds(on)'],
      notes: ['The on-state uses the Rds(on) you type. The square law is not used here.', 'Off means Vgs is not above Vt. Leakage is taken as zero.', 'A logic FET still needs a rated Vgs. This screen does not check the absolute maximum.'] });
  };

  SOLVERS.cmosInverter = (unknown, inp) => {
    const vdd = pos(inp, 'vdd', 'Vdd'), vtn = nonNeg(inp, 'vtn', 'Vtn'), vtp = nonNeg(inp, 'vtp', '|Vtp|'), vm = (vdd - vtp + vtn) / 2;
    let vin, vout;
    if (unknown === 'vout') { vin = finite(inp, 'vin', 'Vin'); vout = vin < vm ? vdd : (vin > vm ? 0 : vm); }
    else if (unknown === 'threshold') { vin = vm; vout = vm; } else throw badUnknown();
    return pack('cmosInverter', { headline: 'Vm = ' + eng(vm) + ' V',
      elements: [src('vdd', 'Vdd', eng(vdd) + ' V', 70, 70, 70, 12), pmosPart('p', 'P', 46, 26, 0.6), nmosPart('n', 'N', 46, 54, 0.6),
        wire('rail', 53.2, 15.2, 53.2, 12), wire('rail2', 53.2, 12, 70, 12), wire('pd', 50.8, 36.8, 50.8, 40), wire('pn', 50.8, 40, 53.2, 40), wire('nd', 53.2, 43.2, 53.2, 40), wire('out', 53.2, 40, 84, 40),
        wire('ns', 50.8, 64.8, 50.8, 70), wire('in', 16, 40, 26, 40), wire('gp', 26, 26, 26, 54), wire('gp2', 26, 26, 35.2, 26), wire('gn2', 26, 54, 35.2, 54), src('vin', 'Vin', eng(vin) + ' V', 16, 70, 16, 40), wire('bot', 16, 70, 70, 70), gnd('g', 50.8, 70)],
      nodes: [node('in', 'Vin', vin, 'V', 16, 40), node('out', 'Vout', vout, 'V', 84, 40), node('vm', 'Vm', vm, 'V', 53, 40), node('vdd', 'Vdd', vdd, 'V', 70, 12), node('gnd', 'GND', 0, 'V', 50.8, 70)],
      branches: [branch('i', 'Istatic', 0, 'A', 62, 20, 62, 36)],
      quantities: [q('vm', 'Vm', vm, 'V', unknown === 'threshold'), q('vout', 'Vout', vout, 'V', unknown === 'vout'), q('vin', 'Vin', vin, 'V'), q('nml', 'NM sketch', Math.max(0, vm - vtn), 'V'), q('vdd', 'Vdd', vdd, 'V')],
      steps: ['Vm = (Vdd − |Vtp| + Vtn) / 2 = ' + eng(vm) + ' V', 'Ideal rails: Vin below Vm drives Vout to Vdd.'],
      notes: ['Matched kn = kp. The threshold is the usual long-channel estimate.', 'The logic level is an ideal step. A real transfer curve is not vertical.', 'Static current is taken as zero. Shoot-through during the edge is not modeled.'] });
  };

  const clampSwing = (ideal, limit) => { const cap = Math.abs(limit); return ideal > cap ? { shown: cap, clipped: true } : (ideal < -cap ? { shown: -cap, clipped: true } : { shown: ideal, clipped: false }); };
  const opAmpPart = (id, x, y, flip) => part(id, 'opAmp', '', '', x, y, x, y, flip ? 1 : 0);
  const clipWarn = (sw, what) => (sw.clipped ? what : null);

  SOLVERS.invertingAmp = (unknown, inp) => {
    const rin = pos(inp, 'rin', 'Rin'), vsat = pos(inp, 'vsat', 'Swing limit');
    let vin = 0, rf = 0;
    if (unknown === 'gain') { vin = finite(inp, 'vin', 'Vin'); rf = pos(inp, 'rf', 'Rf'); }
    else if (unknown === 'rf') { vin = finite(inp, 'vin', 'Vin'); rf = pos(inp, 'av', '|Av|') * rin; }
    else if (unknown === 'vin') { rf = pos(inp, 'rf', 'Rf'); vin = pos(inp, 'voutmag', '|Vout|') * rin / rf; }
    else throw badUnknown();
    const ideal = -rf / rin * vin, sw = clampSwing(ideal, vsat), i = vin / rin;
    return pack('invertingAmp', { headline: 'Vout = ' + eng(sw.shown) + ' V', elements: [src('in', 'Vin', eng(vin) + ' V', 14, 62, 14, 36.8), res('rin', 'Rin', eng(rin) + ' Ω', 14, 36.8, 34, 36.8), wire('w1', 34, 36.8, 53, 36.8), opAmpPart('oa', 60, 40, true), wire('fa', 44, 36.8, 44, 20), res('rf', 'Rf', eng(rf) + ' Ω', 44, 20, 78, 20), wire('fb', 78, 20, 78, 40), wire('o', 69, 40, 92, 40), wire('pa', 53, 43.2, 48, 43.2), wire('pb', 48, 43.2, 48, 54), gnd('g', 48, 54), gnd('g0', 14, 62)],
      nodes: [node('in', 'Vin', vin, 'V', 14, 36.8), node('sum', 'V−', 0, 'V', 44, 36.8), node('out', 'Vout', sw.shown, 'V', 92, 40), node('gnd', 'GND', 0, 'V', 48, 54)],
      branches: [branch('i', 'Iin', i, 'A', 20, 36.8, 28, 36.8)],
      quantities: [q('vout', 'Vout', sw.shown, 'V', true), q('ideal', 'Ideal Vout', ideal, 'V'), q('av', 'Av', -rf / rin, '', unknown === 'rf'), q('rf', 'Rf', rf, 'Ω', unknown === 'rf'), q('rin', 'Rin', rin, 'Ω'), q('vin', 'Vin', vin, 'V', unknown === 'vin'), q('iin', 'Iin', i, 'A')],
      steps: ['Av = −Rf / Rin = ' + (-rf / rin).toFixed(3), 'V− = 0 (virtual ground),  I = Vin / Rin'],
      notes: ['Ideal op-amp. Input current is zero and the differential input is zero.', 'The non-inverting input is grounded.', 'Past the swing limit, the node shows the clip and the ideal value stays in the table.'],
      warning: clipWarn(sw, 'Ideal gain exceeds the swing limit. The output node is clipped.') });
  };
  SOLVERS.nonInvertingAmp = (unknown, inp) => {
    const vin = finite(inp, 'vin', 'Vin'), vsat = pos(inp, 'vsat', 'Swing limit');
    let rg = 0, rf = 0;
    if (unknown === 'gain') { rg = pos(inp, 'rg', 'Rg'); rf = pos(inp, 'rf', 'Rf'); }
    else if (unknown === 'rf') { rg = pos(inp, 'rg', 'Rg'); const av = pos(inp, 'av', 'Av'); if (!(av > 1)) throw outOfRange('A non-inverting gain with this divider is greater than 1.'); rf = rg * (av - 1); }
    else if (unknown === 'rg') { rf = pos(inp, 'rf', 'Rf'); const av = pos(inp, 'av', 'Av'); if (!(av > 1)) throw outOfRange('A non-inverting gain with this divider is greater than 1.'); rg = rf / (av - 1); }
    else throw badUnknown();
    const av = 1 + rf / rg, ideal = av * vin, sw = clampSwing(ideal, vsat);
    return pack('nonInvertingAmp', { headline: 'Vout = ' + eng(sw.shown) + ' V',
      elements: [src('vin', 'Vin', eng(vin) + ' V', 14, 62, 14, 36.8), wire('p', 14, 36.8, 53, 36.8), opAmpPart('oa', 60, 40, false), wire('m', 53, 43.2, 40, 43.2), wire('m2', 40, 43.2, 40, 54), res('rg', 'Rg', eng(rg) + ' Ω', 40, 54, 40, 70), gnd('g', 40, 70), res('rf', 'Rf', eng(rf) + ' Ω', 40, 54, 78, 54), wire('fb', 78, 54, 78, 40), wire('o', 69, 40, 92, 40), gnd('g0', 14, 62)],
      nodes: [node('in', 'V+', vin, 'V', 14, 36.8), node('fb', 'V−', vin, 'V', 40, 43.2), node('out', 'Vout', sw.shown, 'V', 92, 40), node('gnd', 'GND', 0, 'V', 40, 70)],
      branches: [branch('i', 'If', (sw.shown - vin) / rf, 'A', 66, 54, 56, 54)],
      quantities: [q('vout', 'Vout', sw.shown, 'V', true), q('av', 'Av', av, '', unknown !== 'gain'), q('rf', 'Rf', rf, 'Ω', unknown === 'rf'), q('rg', 'Rg', rg, 'Ω', unknown === 'rg'), q('vin', 'Vin', vin, 'V')],
      steps: ['Av = 1 + Rf/Rg = ' + av.toFixed(3), 'V+ = V− = Vin'],
      notes: ['Ideal non-inverting stage. Both inputs sit at Vin.', 'Rg is from the inverting input to ground. Rf is the feedback.', 'Output current into a load is not included on this screen.'],
      warning: clipWarn(sw, 'Ideal gain exceeds the swing limit. The output node is clipped.') });
  };
  SOLVERS.summingAmp = (unknown, inp) => {
    const v1 = finite(inp, 'v1', 'V1'), r1 = pos(inp, 'r1', 'R1'), v2 = finite(inp, 'v2', 'V2'), r2 = pos(inp, 'r2', 'R2'), vsat = pos(inp, 'vsat', 'Swing limit');
    let rf;
    if (unknown === 'rf') {
      const mag = pos(inp, 'vout', '|Vout|'), sum = v1 / r1 + v2 / r2;
      if (!(Math.abs(sum) > 1e-15)) throw outOfRange('Both input currents are zero, so Rf is not determined.');
      rf = mag / Math.abs(sum);
    } else if (unknown === 'output') rf = pos(inp, 'rf', 'Rf'); else throw badUnknown();
    const ideal = -rf * (v1 / r1 + v2 / r2), sw = clampSwing(ideal, vsat);
    return pack('summingAmp', { headline: 'Vout = ' + eng(sw.shown) + ' V', elements: [src('v1', 'V1', eng(v1) + ' V', 2, 12, 20, 12), res('r1', 'R1', eng(r1) + ' Ω', 20, 12, 38, 12), wire('a1', 38, 12, 44, 12), src('v2', 'V2', eng(v2) + ' V', 2, 26, 20, 26), res('r2', 'R2', eng(r2) + ' Ω', 20, 26, 38, 26), wire('a2', 38, 26, 44, 26), wire('bus', 44, 12, 44, 36.8), wire('w1', 44, 36.8, 53, 36.8), opAmpPart('oa', 60, 40, true), wire('fa', 48, 36.8, 48, 4), res('rf', 'Rf', eng(rf) + ' Ω', 48, 4, 78, 4), wire('fb', 78, 4, 78, 40), wire('o', 69, 40, 92, 40), wire('pa', 53, 43.2, 50, 43.2), wire('pb', 50, 43.2, 50, 54), gnd('g', 50, 54), gnd('g1', 2, 12), gnd('g2', 2, 26)],
      nodes: [node('v1', 'V1', v1, 'V', 20, 12), node('v2', 'V2', v2, 'V', 20, 26), node('sum', 'V−', 0, 'V', 44, 36.8), node('out', 'Vout', sw.shown, 'V', 92, 40)],
      branches: [branch('i1', 'I1', v1 / r1, 'A', 26, 12, 33, 12), branch('i2', 'I2', v2 / r2, 'A', 26, 26, 33, 26)],
      quantities: [q('vout', 'Vout', sw.shown, 'V', true), q('rf', 'Rf', rf, 'Ω', unknown === 'rf'), q('i1', 'I1', v1 / r1, 'A'), q('i2', 'I2', v2 / r2, 'A'), q('v1', 'V1', v1, 'V'), q('r1', 'R1', r1, 'Ω'), q('v2', 'V2', v2, 'V'), q('r2', 'R2', r2, 'Ω')],
      steps: ['Vout = −Rf · (V1/R1 + V2/R2)', 'The summing node is a virtual ground.'],
      notes: ['Two-input inverting summer. More inputs add the same way.', 'Each input current is V/R and does not depend on the other input.', 'Ideal op-amp. The swing limit clips the drawn output.'],
      warning: clipWarn(sw, 'Ideal sum exceeds the swing limit. The output node is clipped.') });
  };
  SOLVERS.diffAmp = (unknown, inp) => {
    const v1 = finite(inp, 'v1', 'V1'), v2 = finite(inp, 'v2', 'V2'), r1 = pos(inp, 'r1', 'Rin'), vsat = pos(inp, 'vsat', 'Swing limit');
    let rf;
    if (unknown === 'rf') rf = pos(inp, 'gain', 'Gain') * r1; else if (unknown === 'output') rf = pos(inp, 'rf', 'Rf'); else throw badUnknown();
    const ideal = (rf / r1) * (v2 - v1), sw = clampSwing(ideal, vsat), vp = v2 * rf / (r1 + rf);
    return pack('diffAmp', { headline: 'Vout = ' + eng(sw.shown) + ' V',
      elements: [src('v1', 'V1', eng(v1) + ' V', 2, 12, 20, 12), res('r1', 'R1', eng(r1) + ' Ω', 20, 12, 38, 12), wire('a1', 38, 12, 44, 12), wire('bus', 44, 12, 44, 36.8), wire('w1', 44, 36.8, 53, 36.8), opAmpPart('oa', 60, 40, true), wire('fa', 48, 36.8, 48, 4), res('rf', 'Rf', eng(rf) + ' Ω', 48, 4, 78, 4), wire('fb', 78, 4, 78, 40), wire('o', 69, 40, 92, 40),
        src('v2', 'V2', eng(v2) + ' V', 2, 60, 20, 60), res('r2', 'R2', eng(r1) + ' Ω', 20, 60, 38, 60), wire('b2', 38, 60, 46, 60), wire('p1', 53, 43.2, 46, 43.2), wire('p2', 46, 43.2, 46, 60), res('rg', 'Rf', eng(rf) + ' Ω', 46, 60, 46, 74), gnd('g', 46, 74), gnd('g1', 2, 12), gnd('g2', 2, 60)],
      nodes: [node('v1', 'V1', v1, 'V', 20, 12), node('v2', 'V2', v2, 'V', 20, 60), node('p', 'V+', vp, 'V', 46, 43.2), node('out', 'Vout', sw.shown, 'V', 92, 40)],
      branches: [branch('i', 'I through R1', (v1 - sw.shown) / (r1 + rf), 'A', 26, 12, 33, 12)],
      quantities: [q('vout', 'Vout', sw.shown, 'V', true), q('gain', 'Gain', rf / r1, '', unknown === 'rf'), q('rf', 'Rf', rf, 'Ω', unknown === 'rf'), q('vp', 'V+', vp, 'V'), q('v1', 'V1', v1, 'V'), q('v2', 'V2', v2, 'V'), q('r1', 'Rin', r1, 'Ω')],
      steps: ['Matched pairs: Vout = (Rf/Rin)·(V2 − V1)', 'V+ = V2 · Rf / (Rin + Rf)'],
      notes: ['All four resistors use two values: both inputs see Rin, both feedbacks are Rf.', 'A mismatch would add a common-mode term. This screen assumes a match.', 'Ideal op-amp. Not an instrumentation amplifier.'],
      warning: clipWarn(sw, 'Ideal difference exceeds the swing limit. The output node is clipped.') });
  };
  SOLVERS.integrator = (unknown, inp) => {
    const r = pos(inp, 'r', 'R'), vin = finite(inp, 'vin', 'Vin'), v0 = finite(inp, 'v0', 'v(0)'), vsat = pos(inp, 'vsat', 'Swing limit');
    let c = 0, t = 0, vt = 0;
    if (unknown === 'ramp') { c = pos(inp, 'c', 'C'); t = pos(inp, 't', 't'); vt = v0 - (vin / (r * c)) * t; }
    else if (unknown === 'time') {
      c = pos(inp, 'c', 'C'); vt = finite(inp, 'vt', 'v');
      if (!(Math.abs(vin) > 1e-15)) throw outOfRange('Vin is zero, so the ramp never reaches a new voltage.');
      t = (v0 - vt) * r * c / vin;
      if (!(t > 0)) throw outOfRange('That target is behind the ramp direction. Time would not be positive.');
    } else if (unknown === 'c') {
      t = pos(inp, 't', 't'); vt = finite(inp, 'vt', 'v'); const delta = v0 - vt;
      if (!(Math.abs(vin) > 1e-15 && Math.abs(delta) > 1e-15)) throw outOfRange('Need a nonzero Vin and a voltage change to solve C.');
      c = vin * t / (r * delta);
      if (!(c > 0)) throw outOfRange('C would not be positive for that ramp direction.');
    } else throw badUnknown();
    const sw = clampSwing(vt, vsat);
    return pack('integrator', { headline: 'v(t) = ' + eng(sw.shown) + ' V',
      elements: [src('in', 'Vin', eng(vin) + ' V', 14, 62, 14, 36.8), res('r', 'R', eng(r) + ' Ω', 14, 36.8, 34, 36.8), wire('w1', 34, 36.8, 53, 36.8), opAmpPart('oa', 60, 40, true), wire('fa', 44, 36.8, 44, 20), cap('c', 'C', eng(c) + ' F', 44, 20, 78, 20), wire('fb', 78, 20, 78, 40), wire('o', 69, 40, 92, 40), wire('pa', 53, 43.2, 48, 43.2), wire('pb', 48, 43.2, 48, 54), gnd('g', 48, 54), gnd('g0', 14, 62)],
      nodes: [node('in', 'Vin', vin, 'V', 14, 36.8), node('sum', 'V−', 0, 'V', 44, 36.8), node('out', 'Vout', sw.shown, 'V', 92, 40), node('gnd', 'GND', 0, 'V', 48, 54)],
      branches: [branch('i', 'I', vin / r, 'A', 20, 36.8, 28, 36.8)],
      quantities: [q('vt', 'v(t)', sw.shown, 'V', unknown === 'ramp'), q('ideal', 'Ideal v(t)', vt, 'V'), q('time', 't', t, 's', unknown === 'time'), q('c', 'C', c, 'F', unknown === 'c'), q('unity', 'Unity f', 1 / (2 * Math.PI * r * c), 'Hz'), q('vin', 'Vin', vin, 'V'), q('v0', 'v(0)', v0, 'V'), q('r', 'R', r, 'Ω')],
      steps: ['v(t) = v(0) − (Vin /(RC)) · t', 'I = Vin / R is constant while Vin is constant.'],
      notes: ['Ideal integrator. There is no reset resistor, so DC error integrates forever.', 'The non-inverting input is grounded.', 'Unity-gain frequency is 1/(2πRC), where |Av| = 1 for a sine.'],
      warning: clipWarn(sw, 'The ramp passed the swing limit. The output node is clipped.') });
  };
  SOLVERS.differentiator = (unknown, inp) => {
    const slope = finite(inp, 'slope', 'Slope'), vsat = pos(inp, 'vsat', 'Swing limit');
    let r = 0, c = 0;
    if (unknown === 'output') { r = pos(inp, 'r', 'R'); c = pos(inp, 'c', 'C'); }
    else if (unknown === 'r') {
      c = pos(inp, 'c', 'C'); const target = finite(inp, 'vout', 'Vout');
      if (!(Math.abs(slope) > 1e-15 && Math.abs(c * slope) > 1e-18)) throw outOfRange('Slope is zero, so R is not set by Vout.');
      r = -target / (c * slope);
      if (!(r > 0)) throw outOfRange('R would not be positive. Check the sign of Vout against the slope.');
    } else if (unknown === 'c') {
      r = pos(inp, 'r', 'R'); const target = finite(inp, 'vout', 'Vout');
      if (!(Math.abs(slope) > 1e-15)) throw outOfRange('Slope is zero, so C is not set by Vout.');
      c = -target / (r * slope);
      if (!(c > 0)) throw outOfRange('C would not be positive. Check the sign of Vout against the slope.');
    } else throw badUnknown();
    const ideal = -r * c * slope, sw = clampSwing(ideal, vsat);
    return pack('differentiator', { headline: 'Vout = ' + eng(sw.shown) + ' V',
      elements: [src('in', 'Vin', eng(slope) + ' V/s', 14, 62, 14, 36.8), cap('c', 'C', eng(c) + ' F', 14, 36.8, 34, 36.8), wire('w1', 34, 36.8, 53, 36.8), opAmpPart('oa', 60, 40, true), wire('fa', 44, 36.8, 44, 20), res('r', 'R', eng(r) + ' Ω', 44, 20, 78, 20), wire('fb', 78, 20, 78, 40), wire('o', 69, 40, 92, 40), wire('pa', 53, 43.2, 48, 43.2), wire('pb', 48, 43.2, 48, 54), gnd('g', 48, 54), gnd('g0', 14, 62)],
      nodes: [node('in', 'Slope', slope, 'V/s', 14, 36.8), node('sum', 'V−', 0, 'V', 44, 36.8), node('out', 'Vout', sw.shown, 'V', 92, 40), node('gnd', 'GND', 0, 'V', 48, 54)],
      branches: [branch('i', 'I', c * slope, 'A', 20, 36.8, 28, 36.8)],
      quantities: [q('vout', 'Vout', sw.shown, 'V', true), q('ideal', 'Ideal Vout', ideal, 'V'), q('r', 'R', r, 'Ω', unknown === 'r'), q('c', 'C', c, 'F', unknown === 'c'), q('slope', 'Slope', slope, 'V/s')],
      steps: ['Vout = −RC · (dv/dt)', 'I = C · slope'],
      notes: ['A constant slope in gives a constant voltage out.', 'Ideal differentiator. Real ones add a series resistor so they do not gain noise forever.', 'The non-inverting input is grounded.'],
      warning: clipWarn(sw, 'Ideal output exceeds the swing limit. The node is clipped.') });
  };
  SOLVERS.comparator = (unknown, inp) => {
    if (unknown !== 'output') throw badUnknown();
    const vin = finite(inp, 'vin', 'Vin'), vref = finite(inp, 'vref', 'Vref'), voh = finite(inp, 'voh', 'High rail'), vol = finite(inp, 'vol', 'Low rail');
    const high = vin >= vref, vout = high ? voh : vol;
    return pack('comparator', { headline: high ? 'Output high' : 'Output low',
      elements: [src('vin', 'Vin', eng(vin) + ' V', 14, 62, 14, 36.8), wire('p', 14, 36.8, 53, 36.8), src('vr', 'Vref', eng(vref) + ' V', 32, 66, 32, 43.2), wire('m', 32, 43.2, 53, 43.2), opAmpPart('oa', 60, 40, false), wire('o', 69, 40, 92, 40), gnd('g0', 14, 62), gnd('g1', 32, 66)],
      nodes: [node('in', 'Vin', vin, 'V', 14, 36.8), node('ref', 'Vref', vref, 'V', 32, 43.2), node('out', 'Vout', vout, 'V', 92, 40)],
      branches: [branch('i', 'Iin', 0, 'A', 30, 36.8, 40, 36.8)],
      quantities: [q('vout', 'Vout', vout, 'V', true), q('high', high ? 'High' : 'Low', high ? 1 : 0, ''), q('vin', 'Vin', vin, 'V'), q('vref', 'Vref', vref, 'V'), q('voh', 'High rail', voh, 'V'), q('vol', 'Low rail', vol, 'V')],
      steps: ['No feedback. If Vin ≥ Vref, Vout = high rail.', 'Otherwise Vout = low rail.'],
      notes: ['Open-loop comparator. There is no linear gain to solve.', 'The threshold is the reference you enter. Hysteresis is not added.', 'Input current is taken as zero.'] });
  };

  const LN2 = Math.LN2, LN3 = Math.log(3);
  function astableTiming(r1, r2, c) {
    const th = LN2 * (r1 + r2) * c, tl = LN2 * r2 * c, per = th + tl;
    return { th, tl, per, freq: 1 / per, duty: th / per * 100 };
  }
  const SEG_MASK = [0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f];
  const segNames = (mask) => ['a', 'b', 'c', 'd', 'e', 'f', 'g'].filter((_, i) => mask & (1 << i)).join(' ');
  const timerPart = (id, x, y) => part(id, 'timer555', '555', '', x, y, x, y);
  const timerBox = (vcc, r1, r2, c) => [timerPart('u', 70, 42), src('vcc', 'Vcc', eng(vcc) + ' V', 48, 74, 48, 14), wire('rail', 48, 14, 78, 14),
    res('r1', 'R1', eng(r1) + ' Ω', 62, 14, 62, 32), res('r2', 'R2', eng(r2) + ' Ω', 62, 32, 62, 50), cap('c', 'C', eng(c) + ' F', 48, 50, 48, 74), wire('th', 62, 50, 48, 50), gnd('g', 48, 74)];

  SOLVERS.astable555 = (unknown, inp) => {
    const vcc = pos(inp, 'vcc', 'Vcc');
    let r1 = 0, r2 = 0, c = 0;
    if (unknown === 'frequency') { r1 = pos(inp, 'r1', 'R1'); r2 = pos(inp, 'r2', 'R2'); c = pos(inp, 'c', 'C'); }
    else if (unknown === 'c') { r1 = pos(inp, 'r1', 'R1'); r2 = pos(inp, 'r2', 'R2'); c = 1 / (pos(inp, 'frequency', 'f') * LN2 * (r1 + 2 * r2)); }
    else if (unknown === 'r1') {
      r2 = pos(inp, 'r2', 'R2'); c = pos(inp, 'c', 'C'); r1 = 1 / (pos(inp, 'frequency', 'f') * LN2 * c) - 2 * r2;
      if (!(r1 > 0)) throw outOfRange('R1 would not be positive. Frequency is too low for R2 and C.');
    } else if (unknown === 'r2') {
      r1 = pos(inp, 'r1', 'R1'); c = pos(inp, 'c', 'C'); r2 = (1 / (pos(inp, 'frequency', 'f') * LN2 * c) - r1) / 2;
      if (!(r2 > 0)) throw outOfRange('R2 would not be positive. Frequency is too low for R1 and C.');
    } else if (unknown === 'resistors') {
      c = pos(inp, 'c', 'C'); const f = pos(inp, 'frequency', 'f'), duty = pos(inp, 'duty', 'Duty') / 100;
      if (!(duty > 0.5 && duty < 1)) throw outOfRange('A plain 555 astable duty is above 50% and below 100%. A steering diode is a different circuit.');
      const k = (1 - duty) / (2 * duty - 1), sum = 1 / (f * LN2 * c);
      r1 = sum / (1 + 2 * k); r2 = k * r1;
    } else throw badUnknown();
    const t = astableTiming(r1, r2, c), iCharge = (vcc - vcc / 3) / (r1 + r2), iDis = (2 * vcc / 3) / r2;
    return pack('astable555', { headline: 'f = ' + eng(t.freq) + ' Hz', elements: timerBox(vcc, r1, r2, c),
      nodes: [node('vcc', 'Vcc', vcc, 'V', 70, 14), node('ctrl', 'CTRL', 2 * vcc / 3, 'V', 78, 36), node('cap', 'C trip', vcc / 3, 'V', 48, 62), node('out', 'OUT high', vcc, 'V', 88, 40), node('gnd', 'GND', 0, 'V', 48, 74)],
      branches: [branch('chg', 'Charge @ 1/3', iCharge, 'A', 62, 18, 62, 34), branch('dis', 'Discharge @ 2/3', iDis, 'A', 48, 40, 48, 56)],
      quantities: [q('frequency', 'f', t.freq, 'Hz', unknown === 'frequency'), q('duty', 'Duty', t.duty, '%', unknown === 'resistors'), q('thigh', 't high', t.th, 's'), q('tlow', 't low', t.tl, 's'),
        q('r1', 'R1', r1, 'Ω', unknown === 'r1' || unknown === 'resistors'), q('r2', 'R2', r2, 'Ω', unknown === 'r2' || unknown === 'resistors'), q('c', 'C', c, 'F', unknown === 'c'), q('vcc', 'Vcc', vcc, 'V')],
      steps: ['tH = ln(2)·(R1+R2)·C,  tL = ln(2)·R2·C', 'f = 1 / (ln(2)·(R1+2·R2)·C) = ' + eng(t.freq) + ' Hz', 'Duty = (R1+R2)/(R1+2·R2) = ' + t.duty.toFixed(2) + '%'],
      notes: ['Plain astable: output high while C charges through R1+R2, low while it discharges through R2.', 'CTRL is the internal 2/3 Vcc tap. Threshold trips are 1/3 and 2/3 Vcc.', 'Ideal pins. A real 555 output high is about 1.5 V under Vcc and is not modeled.', 'OUT is drawn at the high rail. It spends the low time near ground.'] });
  };
  SOLVERS.monostable555 = (unknown, inp) => {
    const vcc = pos(inp, 'vcc', 'Vcc');
    let r = 0, c = 0;
    if (unknown === 'width') { r = pos(inp, 'r', 'R'); c = pos(inp, 'c', 'C'); }
    else if (unknown === 'r') { c = pos(inp, 'c', 'C'); r = pos(inp, 'width', 't') / (LN3 * c); }
    else if (unknown === 'c') { r = pos(inp, 'r', 'R'); c = pos(inp, 'width', 't') / (LN3 * r); }
    else throw badUnknown();
    const w = LN3 * r * c;
    return pack('monostable555', { headline: 't = ' + eng(w) + ' s',
      elements: [timerPart('u', 58, 40), res('r', 'R', eng(r) + ' Ω', 36, 16, 36, 36), cap('c', 'C', eng(c) + ' F', 36, 36, 36, 68), src('vcc', 'Vcc', eng(vcc) + ' V', 78, 68, 78, 14), wire('t', 36, 16, 78, 16), gnd('g', 36, 68)],
      nodes: [node('vcc', 'Vcc', vcc, 'V', 78, 14), node('out', 'OUT', vcc, 'V', 86, 40), node('cap', 'C end', 2 * vcc / 3, 'V', 36, 36), node('gnd', 'GND', 0, 'V', 36, 68)],
      branches: [branch('i', 'I at start', vcc / r, 'A', 36, 20, 36, 32)],
      quantities: [q('width', 't', w, 's', unknown === 'width'), q('r', 'R', r, 'Ω', unknown === 'r'), q('c', 'C', c, 'F', unknown === 'c'), q('retrigger', 'Max rate', 1 / w, 'Hz'), q('vcc', 'Vcc', vcc, 'V')],
      steps: ['t = ln(3)·R·C ≈ 1.1·R·C', 'The cap charges from 0 toward Vcc and the pulse ends at 2/3 Vcc.'],
      notes: ['One-shot. Trigger is a brief low. Retriggering during the pulse is not modeled.', 'Initial timing current is about Vcc/R, then it falls.', 'Ideal 555. Output high during the pulse is drawn at Vcc.'] });
  };
  SOLVERS.ledFlasher = (unknown, inp) => {
    const vcc = pos(inp, 'vcc', 'Vcc'), r1 = pos(inp, 'r1', 'R1'), r2 = pos(inp, 'r2', 'R2'), vf = nonNeg(inp, 'vf', 'Vf');
    if (!(vcc > vf)) throw outOfRange('Vcc must be above the LED Vf.');
    let c = 0, rled = 0;
    if (unknown === 'rate') { c = pos(inp, 'c', 'C'); rled = pos(inp, 'rled', 'Rled'); }
    else if (unknown === 'c') { rled = pos(inp, 'rled', 'Rled'); c = 1 / (pos(inp, 'frequency', 'f') * LN2 * (r1 + 2 * r2)); }
    else if (unknown === 'rled') { c = pos(inp, 'c', 'C'); rled = (vcc - vf) / pos(inp, 'iled', 'LED current'); }
    else throw badUnknown();
    const t = astableTiming(r1, r2, c), iled = (vcc - vf) / rled;
    return pack('ledFlasher', { headline: 'f = ' + eng(t.freq) + ' Hz',
      elements: timerBox(vcc, r1, r2, c).concat([res('rled', 'Rled', eng(rled) + ' Ω', 88, 40, 88, 56), ledPart('led', 'LED', eng(vf) + ' V', 88, 56, 88, 70)]),
      nodes: [node('vcc', 'Vcc', vcc, 'V', 70, 14), node('out', 'OUT high', vcc, 'V', 88, 40), node('led', 'LED', vf, 'V', 88, 56), node('gnd', 'GND', 0, 'V', 48, 74)],
      branches: [branch('led', 'ILED high', iled, 'A', 88, 44, 88, 66)],
      quantities: [q('frequency', 'f', t.freq, 'Hz', unknown === 'rate'), q('duty', 'Duty', t.duty, '%'), q('c', 'C', c, 'F', unknown === 'c'), q('rled', 'Rled', rled, 'Ω', unknown === 'rled'), q('r1', 'R1', r1, 'Ω'), q('r2', 'R2', r2, 'Ω'), q('vcc', 'Vcc', vcc, 'V'), q('iled', 'ILED high', iled, 'A'), q('iavg', 'ILED average', iled * t.duty / 100, 'A')],
      steps: ['Flash rate uses the same astable identity as the 555 screen.', 'While OUT is high, ILED = (Vcc − Vf) / Rled.'],
      notes: ['The LED is on during the output-high time. Average current is duty times that.', 'Ideal rail-to-rail output. A real 555 high is lower, so the LED current is a bit less.', 'R1 and R2 set the rate. Rled sets the brightness, not the rate.'] });
  };
  SOLVERS.sevenSegment = (unknown, inp) => {
    const digit = parseInt(choice(inp, 'digit', ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'], '8', 'Digit'), 10);
    const vcc = pos(inp, 'vcc', 'Vcc'), vf = nonNeg(inp, 'vf', 'Vf');
    if (!(vcc > vf)) throw outOfRange('Vcc must be above the segment Vf.');
    const mask = SEG_MASK[digit];
    let count = 0; for (let i = 0; i < 7; i++) if (mask & (1 << i)) count++;
    let r, iseg;
    if (unknown === 'r') { iseg = pos(inp, 'iseg', 'I per segment'); r = (vcc - vf) / iseg; }
    else if (unknown === 'map') { r = pos(inp, 'r', 'R'); iseg = (vcc - vf) / r; }
    else throw badUnknown();
    const total = count * iseg;
    return pack('sevenSegment', { headline: 'Digit ' + digit + ': ' + segNames(mask),
      elements: [src('vcc', 'Vcc', eng(vcc) + ' V', 16, 64, 16, 18), res('r', 'R×' + count, eng(r) + ' Ω', 16, 18, 40, 18), part('seg', 'sevenSegment', String(digit), segNames(mask), 62, 40, 62, 40, mask), gnd('g', 62, 70)],
      nodes: [node('vcc', 'Vcc', vcc, 'V', 16, 18), node('seg', 'Segment', vf, 'V', 46, 40), node('gnd', 'Cathode', 0, 'V', 62, 70)],
      branches: [branch('it', 'Itotal', total, 'A', 20, 18, 36, 18)],
      quantities: [q('count', 'Segments on', count, ''), q('iseg', 'I each', iseg, 'A'), q('itotal', 'I total', total, 'A'), q('r', 'R each', r, 'Ω', unknown === 'r'), q('digit', 'Digit', digit, ''), q('vcc', 'Vcc', vcc, 'V')],
      steps: ['Common cathode. Each lit segment has its own resistor.', 'I = (Vcc − Vf) / R,  total = (segments on) · I'],
      notes: ['Segment map is the usual common-cathode pattern: 0 lights a–f, 1 lights b and c, 8 lights all.', 'Blank segments draw no current in this model.', 'A decoder chip is not simulated. You pick the digit and the map is shown.'] });
  };

  const zBlock = (id, label, detail, x1, y1, x2, y2) => part(id, 'zBlock', label, detail, x1, y1, x2, y2);
  SOLVERS.classOverview = (unknown, inp) => {
    if (unknown !== 'dissipation') throw badUnknown();
    const kind = choice(inp, 'ampClass', ['A', 'B', 'AB', 'D'], 'B', 'Class'), pout = pos(inp, 'pout', 'Pout'), vsupply = pos(inp, 'vsupply', 'Supply');
    const ideals = { A: [0.25, 'Class A into a resistor, ideal maximum 25%.'], B: [Math.PI / 4, 'Class B push-pull, ideal maximum π/4.'], AB: [0.6, 'Class AB planning figure 60%, between A and B. Not a measurement.'], D: [0.9, 'Class D planning figure 90% for an ideal switch. Not a measurement.'] };
    let eta = ideals[kind][0];
    const raw = String(inp.eta == null ? '' : inp.eta).trim();
    if (raw !== '') { const pct = num(inp, 'eta', 'Efficiency'); if (!(pct > 0 && pct <= 100)) throw outOfRange('Efficiency has to be above 0% and at most 100%.'); eta = pct / 100; }
    const pdc = pout / eta, pd = pdc - pout, isup = pdc / vsupply;
    return pack('classOverview', { headline: 'Pd = ' + eng(pd) + ' W',
      elements: [src('vs', 'Vs', eng(vsupply) + ' V', 18, 64, 18, 24), zBlock('dev', 'Class ' + kind, Math.round(eta * 100) + '%', 40, 24, 68, 24), res('rl', 'Load', eng(pout) + ' W', 68, 24, 86, 50), gnd('g', 86, 64), wire('b', 18, 64, 86, 64)],
      nodes: [node('s', 'Supply', vsupply, 'V', 18, 24), node('o', 'Pout', pout, 'W', 86, 50), node('gnd', 'GND', 0, 'V', 86, 64)],
      branches: [branch('is', 'Isupply', isup, 'A', 18, 50, 18, 30)],
      quantities: [q('eta', 'η', eta * 100, '%', true), q('pdc', 'From supply', pdc, 'W'), q('pd', 'Heat', pd, 'W'), q('is', 'Isupply', isup, 'A'), q('pout', 'Pout', pout, 'W')],
      steps: [ideals[kind][1], 'Psupply = Pout / η,  heat = Psupply − Pout'],
      notes: ['Efficiencies are ideal class figures, or the override you typed.', 'Class A here is the resistively loaded 25% case, not a transformer-coupled 50% case.', 'Not a heatsink design and not a measured amplifier.'] });
  };
  SOLVERS.discretePower = (unknown, inp) => {
    if (unknown !== 'power') throw badUnknown();
    const vcc = pos(inp, 'vcc', 'Vcc'), r1 = pos(inp, 'r1', 'R1'), r2 = pos(inp, 'r2', 'R2'), rc = pos(inp, 'rc', 'Rc'), re = pos(inp, 're', 'Re'), beta = pos(inp, 'beta', 'β');
    const b = bjtBiasCalc(vcc, r1, r2, rc, re, beta), pq = b.ic * b.vce, psup = vcc * (b.ic + b.iR1);
    return pack('discretePower', { headline: 'Pq = ' + eng(pq) + ' W', elements: bjtElements(vcc, r1, r2, rc, re), nodes: bjtNodes(b, vcc), branches: bjtBranches(b),
      quantities: [q('pq', 'P in Q', pq, 'W', true), q('prc', 'P in Rc', b.ic * b.ic * rc, 'W'), q('pre', 'P in Re', b.ie * b.ie * re, 'W'), q('psup', 'From Vcc', psup, 'W'), q('ic', 'Ic', b.ic, 'A'), q('vce', 'Vce', b.vce, 'V'), q('vc', 'Vc', b.vc, 'V'), q('vb', 'Vb', b.vb, 'V'), q('vcc', 'Vcc', vcc, 'V'), q('rc', 'Rc', rc, 'Ω'), q('r1', 'R1', r1, 'Ω'), q('r2', 'R2', r2, 'Ω'), q('re', 'Re', re, 'Ω')],
      steps: ['Same divider-bias point as the BJT screen.', 'Pq ≈ Ic·Vce. Resistor power is I²R.'],
      notes: ['Quiescent class-A sketch. Signal swing would move the instantaneous power.', 'Supply power counts collector current plus the base-divider current.', 'Vbe = 0.7 V, constant β. Not a thermal design.'],
      warning: b.saturated ? 'The point is saturated, so this is not a linear class-A bias.' : (b.cutoff ? 'The transistor is cut off, so quiescent power in Q is about zero.' : null) });
  };
  SOLVERS.opAmpPower = (unknown, inp) => {
    const vin = finite(inp, 'vin', 'Vin'), rg = pos(inp, 'rg', 'Rg'), rl = pos(inp, 'rl', 'RL'), vsat = pos(inp, 'vsat', 'Swing limit');
    let rf;
    if (unknown === 'rf') { const a = pos(inp, 'av', 'Av'); if (!(a > 1)) throw outOfRange('This non-inverting stage needs Av > 1.'); rf = rg * (a - 1); }
    else if (unknown === 'load') rf = pos(inp, 'rf', 'Rf'); else throw badUnknown();
    const av = 1 + rf / rg, sw = clampSwing(av * vin, vsat), iout = sw.shown / rl, pl = sw.shown * iout;
    return pack('opAmpPower', { headline: 'Pload = ' + eng(pl) + ' W',
      elements: [src('vin', 'Vin', eng(vin) + ' V', 14, 62, 14, 36.8), wire('p', 14, 36.8, 53, 36.8), opAmpPart('oa', 60, 40, false), wire('m', 53, 43.2, 40, 43.2), wire('m2', 40, 43.2, 40, 54), res('rg', 'Rg', eng(rg) + ' Ω', 40, 54, 40, 70), gnd('g', 40, 70), res('rf', 'Rf', eng(rf) + ' Ω', 40, 54, 78, 54), wire('fb', 78, 54, 78, 40), wire('o', 69, 40, 86, 40), res('rl', 'RL', eng(rl) + ' Ω', 86, 40, 86, 66), gnd('g2', 86, 66), gnd('g0', 14, 62)],
      nodes: [node('in', 'Vin', vin, 'V', 14, 36.8), node('out', 'Vout', sw.shown, 'V', 86, 40), node('gnd', 'GND', 0, 'V', 86, 66)],
      branches: [branch('iout', 'Iout', iout, 'A', 86, 46, 86, 62)],
      quantities: [q('vout', 'Vout', sw.shown, 'V'), q('iout', 'Iout', iout, 'A'), q('pload', 'Pload', pl, 'W', true), q('av', 'Av', av, ''), q('rf', 'Rf', rf, 'Ω', unknown === 'rf')],
      steps: ['Av = 1 + Rf/Rg', 'Iout = Vout / RL,  Pload = Vout · Iout'],
      notes: ['Teaching power stage: an ideal op-amp into a resistor.', 'Supply current is about the load current. Quiescent current is omitted.', 'A real op-amp has a short-circuit current limit this screen does not apply.'],
      warning: sw.clipped ? 'The ideal output is past the swing limit, so load power uses the clipped voltage.' : null });
  };
  SOLVERS.linearDrop = (unknown, inp) => {
    let vin = 0, vout = 0, iload = 0;
    if (unknown === 'drop') { vin = pos(inp, 'vin', 'Vin'); vout = pos(inp, 'vout', 'Vout'); iload = pos(inp, 'iload', 'Iload'); if (!(vin > vout)) throw outOfRange('Vin has to be above Vout. A linear pass element cannot boost.'); }
    else if (unknown === 'iload') { vin = pos(inp, 'vin', 'Vin'); vout = pos(inp, 'vout', 'Vout'); const pd = pos(inp, 'pdmax', 'Pd max'); if (!(vin > vout)) throw outOfRange('Vin has to be above Vout.'); iload = pd / (vin - vout); }
    else if (unknown === 'vin') { vout = pos(inp, 'vout', 'Vout'); iload = pos(inp, 'iload', 'Iload'); vin = vout + pos(inp, 'dropout', 'Dropout'); }
    else throw badUnknown();
    const drop = vin - vout, pd = drop * iload;
    return pack('linearDrop', { headline: 'Pd = ' + eng(pd) + ' W',
      elements: [src('vin', 'Vin', eng(vin) + ' V', 16, 64, 16, 22), zBlock('pass', 'Pass', eng(drop) + ' V', 36, 22, 62, 22), res('rl', 'Load', eng(vout) + ' V', 74, 22, 74, 64), wire('a', 16, 22, 36, 22), wire('b', 62, 22, 74, 22), wire('g', 16, 64, 74, 64), gnd('gnd', 74, 64)],
      nodes: [node('in', 'Vin', vin, 'V', 16, 22), node('out', 'Vout', vout, 'V', 74, 22), node('gnd', 'GND', 0, 'V', 74, 64)],
      branches: [branch('i', 'Iload', iload, 'A', 40, 22, 58, 22)],
      quantities: [q('drop', 'Vdrop', drop, 'V', unknown === 'drop'), q('pd', 'Pd', pd, 'W'), q('eta', 'η', vout / vin * 100, '%'), q('iload', 'Iload', iload, 'A', unknown === 'iload'), q('vin', 'Vin', vin, 'V', unknown === 'vin'), q('vout', 'Vout', vout, 'V'), q('pload', 'Pload', vout * iload, 'W')],
      steps: ['Vdrop = Vin − Vout', 'Pd = Vdrop · Iload,  η = Vout / Vin'],
      notes: ['Linear drop only. The pass element burns the difference.', 'No quiescent current, no ripple rejection, no adjust pin.', 'Min Vin is Vout plus the dropout you enter.'] });
  };
  SOLVERS.idealBuck = (unknown, inp) => {
    const vin = pos(inp, 'vin', 'Vin'), iout = pos(inp, 'iout', 'Iout');
    let vout = 0, duty = 0;
    if (unknown === 'duty' || unknown === 'iin') { vout = pos(inp, 'vout', 'Vout'); if (!(vout < vin)) throw outOfRange('An ideal buck only steps down. Vout must be below Vin.'); duty = vout / vin; }
    else if (unknown === 'vout') { duty = pos(inp, 'duty', 'Duty'); if (!(duty < 1)) throw outOfRange('Duty for a buck is below 1.'); vout = duty * vin; }
    else throw badUnknown();
    const iin = iout * duty;
    return pack('idealBuck', { headline: 'D = ' + duty.toFixed(3),
      elements: [src('vin', 'Vin', eng(vin) + ' V', 14, 64, 14, 20), zBlock('sw', 'Switch', 'D=' + duty.toFixed(2), 32, 20, 52, 20), ind('l', 'L', 'ideal', 52, 20, 74, 20), cap('c', 'C', 'ideal', 80, 20, 80, 64), res('rl', 'Load', eng(iout) + ' A', 68, 36, 68, 64), wire('g', 14, 64, 80, 64), gnd('gnd', 80, 64)],
      nodes: [node('in', 'Vin', vin, 'V', 14, 20), node('sw', 'Switch avg', vout, 'V', 52, 20), node('out', 'Vout', vout, 'V', 80, 20), node('gnd', 'GND', 0, 'V', 80, 64)],
      branches: [branch('iin', 'Iin', iin, 'A', 18, 48, 18, 26), branch('il', 'IL', iout, 'A', 56, 20, 70, 20)],
      quantities: [q('duty', 'Duty', duty, '', unknown === 'duty'), q('vout', 'Vout', vout, 'V', unknown === 'vout'), q('iin', 'Iin', iin, 'A', unknown === 'iin'), q('pout', 'Pout', vout * iout, 'W')],
      steps: ['D = Vout / Vin', 'Iin = Iout · D  (lossless power balance)'],
      notes: ['Ideal continuous buck. Efficiency is 100% in this sketch.', 'Switch-node average equals Vout. Ripple current is not computed.', 'Not a controller design. No diode drop, no MOSFET, no compensation.'] });
  };

  const C_LIGHT = 299792458;
  const cx = (r, i) => ({ r, i, mag: Math.hypot(r, i), rad: Math.atan2(i, r), deg: Math.atan2(i, r) * 180 / Math.PI });
  const cmul = (a, b) => cx(a.r * b.r - a.i * b.i, a.r * b.i + a.i * b.r);
  const cdiv = (a, b) => { const d = b.r * b.r + b.i * b.i; return cx((a.r * b.r + a.i * b.i) / d, (a.i * b.r - a.r * b.i) / d); };
  const phasorTip = (x, y) => { const mag = Math.hypot(x, y); if (mag < 1e-15) return { x: 52, y: 58 }; const k = 24 / mag; return { x: 52 + x * k, y: 58 - y * k }; };
  const linePart = (id, l, d, x1, y1, x2, y2) => part(id, 'line', l, d, x1, y1, x2, y2);
  const f2s = (v, d) => v.toFixed(d);
  function stubFraction(x, z0, shorted) {
    if (Math.abs(x) < 1e-9) { if (shorted) return 0; throw outOfRange('An open stub cannot present 0 Ω. Use a shorted stub for a short.'); }
    const th = shorted ? Math.atan(x / z0) : Math.atan(-z0 / x), w = th <= 0 ? th + Math.PI : th;
    return w / (2 * Math.PI);
  }
  SOLVERS.complexConvert = (unknown, inp) => {
    let x, y;
    if (unknown === 'polar') { x = finite(inp, 'x', 'Real'); y = finite(inp, 'y', 'Imag'); }
    else if (unknown === 'rect') { const mag = nonNeg(inp, 'magnitude', 'Magnitude'), rad = finite(inp, 'angleDeg', 'Angle') * Math.PI / 180; x = mag * Math.cos(rad); y = mag * Math.sin(rad); }
    else throw badUnknown();
    const z = cx(x, y), tip = phasorTip(x, y);
    return pack('complexConvert', { headline: eng(z.mag) + ' ∠ ' + f2s(z.deg, 2) + '°',
      elements: [wire('re', 18, 58, 86, 58), wire('im', 52, 70, 52, 16), wire('ph', 52, 58, tip.x, tip.y)],
      nodes: [node('origin', '0', 0, '', 52, 58), node('tip', 'Tip', z.mag, '∠', tip.x, tip.y)],
      branches: [branch('phasor', 'Phasor', z.mag, '', 52, 58, tip.x, tip.y)],
      quantities: [q('x', 'Real', z.r, '', unknown === 'rect'), q('y', 'Imag', z.i, '', unknown === 'rect'), q('magnitude', 'Magnitude', z.mag, '', unknown === 'polar'), q('angleDeg', 'Angle', z.deg, '°', unknown === 'polar'), q('angleRad', 'Radians', z.rad, 'rad')],
      steps: ['r = √(x² + y²),  θ = atan2(y, x)', 'x = r cos θ,  y = r sin θ', 'Exponential: ' + eng(z.mag) + ' e^(j ' + f2s(z.rad, 4) + ' rad)'],
      notes: ['Angle is measured from the positive real axis, counter-clockwise.', 'Polar, rectangular, and exponential forms are the same value.', 'A magnitude of zero has angle 0 by convention.'] });
  };
  SOLVERS.impedanceCombo = (unknown, inp) => {
    if (unknown !== 'result') throw badUnknown();
    const combo = choice(inp, 'combo', ['series', 'parallel'], 'series', 'Connection');
    const z1 = cx(finite(inp, 'r1', 'R1'), finite(inp, 'x1', 'X1')), z2 = cx(finite(inp, 'r2', 'R2'), finite(inp, 'x2', 'X2'));
    let z;
    if (combo === 'series') z = cx(z1.r + z2.r, z1.i + z2.i);
    else { const den = cx(z1.r + z2.r, z1.i + z2.i); if (!(den.mag > 1e-12)) throw outOfRange('The two impedances cancel. Parallel combination is not finite.'); z = cdiv(cmul(z1, z2), den); }
    return pack('impedanceCombo', { headline: eng(z.r) + ' + j' + eng(z.i) + ' Ω',
      elements: [zBlock('z1', 'Z1', eng(z1.r) + '+j' + eng(z1.i), 22, 28, 46, 28), zBlock('z2', 'Z2', eng(z2.r) + '+j' + eng(z2.i), 58, 28, 82, 28), wire('join', 46, 28, 58, 28)],
      nodes: [node('a', 'Zin', z.mag, 'Ω', 22, 28), node('b', 'Right', 0, 'Ω', 82, 28)],
      branches: [branch('i', '|I| for 1 V', 1 / Math.max(z.mag, 1e-12), 'A', 30, 28, 74, 28)],
      quantities: [q('r', 'R', z.r, 'Ω', true), q('x', 'X', z.i, 'Ω', true), q('mag', '|Z|', z.mag, 'Ω'), q('ang', '∠Z', z.deg, '°')],
      steps: [combo === 'series' ? 'Z = Z1 + Z2' : 'Z = Z1·Z2 / (Z1 + Z2)', 'Rectangular ' + eng(z.r) + ' + j' + eng(z.i) + ',  polar ' + eng(z.mag) + ' ∠ ' + f2s(z.deg, 2) + '°'],
      notes: ['Each block is R + jX. Positive X is inductive, negative X is capacitive.', 'Series adds. Parallel uses the product over the sum.', 'The current arrow is |1 V / Z|.'] });
  };
  SOLVERS.lMatch = (unknown, inp) => {
    if (unknown !== 'parts') throw badUnknown();
    const rs = pos(inp, 'rs', 'Rs'), rl = pos(inp, 'rl', 'RL'), f = pos(inp, 'f', 'f'), top = choice(inp, 'topology', ['lowpass', 'highpass'], 'lowpass', 'Shape');
    if (!(Math.abs(rs - rl) / Math.max(rs, rl) > 0.01)) throw outOfRange('The two resistances already match within 1%. An L-section is not required.');
    const rHi = Math.max(rs, rl), rLo = Math.min(rs, rl), Q = Math.sqrt(rHi / rLo - 1), xs = Q * rLo, xp = rHi / Q, w = 2 * Math.PI * f;
    const l = (top === 'lowpass' ? xs : xp) / w, c = 1 / (w * (top === 'lowpass' ? xp : xs)), sOnS = rs < rl;
    const sx1 = sOnS ? 36 : 58, sx2 = sOnS ? 54 : 76, px = sOnS ? 70 : 40;
    return pack('lMatch', { headline: 'Q = ' + f2s(Q, 3),
      elements: [res('rs', 'Rs', eng(rs) + ' Ω', 12, 36, 28, 36), top === 'lowpass' ? ind('xs', 'L', eng(l) + ' H', sx1, 36, sx2, 36) : cap('xs', 'C', eng(c) + ' F', sx1, 36, sx2, 36),
        top === 'lowpass' ? cap('xp', 'C', eng(c) + ' F', px, 36, px, 64) : ind('xp', 'L', eng(l) + ' H', px, 36, px, 64), res('rl', 'RL', eng(rl) + ' Ω', 78, 36, 92, 36), wire('w1', 28, 36, sx1, 36), wire('w2', sx2, 36, 78, 36), gnd('g', px, 64)],
      nodes: [node('s', 'Rs', rs, 'Ω', 12, 36), node('l', 'RL', rl, 'Ω', 92, 36), node('mid', 'Q node', Q, '', 54, 36)],
      branches: [branch('i', 'Match', 1, 'A', 16, 36, 84, 36)],
      quantities: [q('q', 'Q', Q, '', true), q('xs', 'Series |X|', xs, 'Ω'), q('xp', 'Shunt |X|', xp, 'Ω'), q('l', 'L', l, 'H'), q('c', 'C', c, 'F'), q('f', 'f', f, 'Hz'), q('lowpass', 'Low-pass', top === 'lowpass' ? 1 : 0, '')],
      steps: ['Q = √(Rhi/Rlo − 1) = ' + f2s(Q, 4), 'Series |X| = Q·Rlo,  shunt |X| = Rhi/Q', top === 'lowpass' ? 'Low-pass: series L, shunt C.' : 'High-pass: series C, shunt L.'],
      notes: ['Lossless L-section between two real resistances.', 'The series arm sits with the smaller resistance. The shunt arm sits across the larger one.', 'One frequency. A different f needs different L and C.'] });
  };
  SOLVERS.quarterWave = (unknown, inp) => {
    const f = pos(inp, 'f', 'f'), vf = pos(inp, 'vf', 'Velocity factor');
    if (!(vf <= 1)) throw outOfRange('Velocity factor is from just above 0 to 1.');
    const zIn = pos(inp, 'zIn', 'Zin');
    let z0, zLoad;
    if (unknown === 'z0') { zLoad = pos(inp, 'zLoad', 'Zload'); z0 = Math.sqrt(zIn * zLoad); }
    else if (unknown === 'zload') { z0 = pos(inp, 'z0', 'Z0'); zLoad = z0 * z0 / zIn; }
    else throw badUnknown();
    const len = vf * C_LIGHT / (4 * f);
    return pack('quarterWave', { headline: 'Z0 = ' + eng(z0) + ' Ω',
      elements: [res('zin', 'Zin', eng(zIn) + ' Ω', 10, 36, 28, 36), linePart('line', 'λ/4', eng(z0) + ' Ω', 32, 36, 72, 36), res('zl', 'ZL', eng(zLoad) + ' Ω', 76, 36, 92, 36)],
      nodes: [node('in', 'Zin', zIn, 'Ω', 10, 36), node('load', 'Zload', zLoad, 'Ω', 92, 36)],
      branches: [branch('i', 'Forward', 1, 'A', 36, 36, 68, 36)],
      quantities: [q('z0', 'Z0', z0, 'Ω', unknown === 'z0'), q('zload', 'Zload', zLoad, 'Ω', unknown === 'zload'), q('lengthM', 'Length', len, 'm'), q('lengthMm', 'Length', len * 1000, 'mm'), q('f', 'f', f, 'Hz'), q('vf', 'vf', vf, '')],
      steps: ['Z0 = √(Zin · Zload)', 'Length = vf · c / (4f) = ' + eng(len) + ' m'],
      notes: ['Both ends are real resistances. A reactive load is a different problem.', 'The line is ideal and exactly 90° long at this frequency.', 'Velocity factor scales the physical length. 1 is free space.'] });
  };
  SOLVERS.stubCancel = (unknown, inp) => {
    if (unknown !== 'length') throw badUnknown();
    const xIn = finite(inp, 'x', 'Reactance'), z0 = pos(inp, 'z0', 'Z0'), f = pos(inp, 'f', 'f'), vf = pos(inp, 'vf', 'Velocity factor');
    if (!(vf <= 1)) throw outOfRange('Velocity factor is from just above 0 to 1.');
    const kind = choice(inp, 'kind', ['shorted', 'open'], 'shorted', 'Stub'), goal = choice(inp, 'goal', ['present', 'cancel'], 'present', 'Goal');
    const xs = goal === 'cancel' ? -xIn : xIn, frac = stubFraction(xs, z0, kind === 'shorted'), lambda = vf * C_LIGHT / f, len = frac * lambda, deg = frac * 360;
    return pack('stubCancel', { headline: 'l = ' + eng(len) + ' m',
      elements: [linePart('line', 'Z0', eng(z0) + ' Ω', 16, 28, 78, 28), wire('tee', 52, 28, 52, 46), linePart('stub', kind === 'shorted' ? 'Short' : 'Open', f2s(deg, 2) + '°', 52, 46, 52, 68), kind === 'shorted' ? wire('end', 44, 68, 60, 68) : wire('end', 48, 68, 56, 68)],
      nodes: [node('tee', 'Stub X', xs, 'Ω', 52, 28), node('end', kind === 'shorted' ? 'Short' : 'Open', 0, 'Ω', 52, 68)],
      branches: [branch('i', 'On the stub', 1, 'A', 52, 32, 52, 60)],
      quantities: [q('lengthM', 'Length', len, 'm', true), q('fraction', 'l/λ', frac, ''), q('degrees', 'Electrical', deg, '°'), q('xStub', 'Stub X', xs, 'Ω'), q('lambda', 'λ', lambda, 'm'), q('f', 'f', f, 'Hz'), q('z0', 'Z0', z0, 'Ω'), q('vf', 'vf', vf, ''), q('shorted', 'Shorted', kind === 'shorted' ? 1 : 0, '')],
      steps: [kind === 'shorted' ? 'Shorted: jX = j Z0 tan(βl)' : 'Open: jX = −j Z0 cot(βl)', 'Shortest positive length is ' + f2s(frac, 4) + ' λ', 'Physical length = (l/λ) · vf · c / f'],
      notes: ['Ideal lossless line. The length is the shortest positive stub.', 'Cancel mode asks the stub for the opposite reactance.', 'This does not place the stub along a mismatched line. It only builds the X.'] });
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
    dualSupply() {
      this.supplies.push({ id: 'ps', label: '±V', leads: [this.hole(2, 'topPlus', '+V'), this.hole(2, 'topMinus', 'GND'), this.hole(3, 'botMinus', '−V')] });
      this.jumper('tie+', '+V', 30, 'topPlus', 30, 'botPlus', 'red');
      this.railLabels = [{ row: 'topPlus', text: '+V' }, { row: 'botPlus', text: '+V' }, { row: 'topMinus', text: 'GND' }, { row: 'botMinus', text: '−V' }];
    }
    dip(id, name, origin, pins) {
      const half = pins.length / 2, leads = [];
      for (let k = 0; k < half; k++) leads.push(this.hole(origin + k, 'e', pins[k][1]));
      for (let k = 0; k < half; k++) leads.push(this.hole(origin + half - 1 - k, 'f', pins[half + k][1]));
      this.components.push({ id, part: { type: pins.length === 14 ? 'dip14' : 'dip8', name, label: name, pins: pins.map((p) => p[0]) }, leads });
    }
    placeOpAmp(sumNet, plusNet) {
      this.dip('u', '741', 12, [['OA1', 'NC1'], ['−', sumNet], ['+', plusNet], ['V−', '−V'], ['OA5', 'NC5'], ['OUT', 'Vout'], ['V+', '+V'], ['NC', 'NC8']]);
      this.jumper('vplus', '+V', 13, 'j', 13, 'botPlus', 'red'); this.jumper('vminusA', '−V', 15, 'b', 20, 'b', 'blue');
      this.jumper('vminusB', '−V', 20, 'e', 20, 'f', 'blue'); this.jumper('vminusC', '−V', 20, 'j', 20, 'botMinus', 'blue');
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

  function acNet(b, vKey) {
    const ac = (b.qty('ac') === undefined ? 1 : b.qty('ac')) >= 0.5;
    if (ac) { const v = b.qty(vKey); return { ac, label: trim(v) + (vKey === 'vrms' ? ' Vrms' : ' Vpk'), net: vKey === 'vrms' ? 'Vac' : 'Vp' }; }
    return { ac, label: trim(b.qty('vdc')) + ' Vdc', net: 'Vdc' };
  }
  LAYOUTS.halfWave = (b) => {
    const c = b.qty('c'), rload = b.qty('rload');
    const s = acNet(b, 'vrms');
    b.singleSupply(s.label, s.net, 'GND');
    b.diode('d', 'D', b.hole(8, 'c', s.net), b.hole(16, 'c', 'Vpk'));
    b.resistor('rl', 'RL', rload, b.hole(16, 'e', 'Vpk'), b.hole(16, 'f', 'GND'));
    b.capacitor('c', 'C', c, b.hole(22, 'e', 'Vpk'), b.hole(22, 'f', 'GND'));
    b.jumper('ac', s.net, 8, 'a', 8, 'topPlus', 'red'); b.jumper('out', 'Vpk', 16, 'b', 22, 'b', 'yellow');
    b.jumper('g1', 'GND', 16, 'j', 16, 'botMinus', 'black'); b.jumper('g2', 'GND', 22, 'j', 22, 'botMinus', 'black');
    return b.finish(b.caption(s.ac
      ? 'Half-wave: diode anode on the red rail (AC source stand-in), cathode to the filter node. RL and C share Vpeak across the gutter. Banded end is the cathode.'
      : 'Half-wave on a DC source: diode anode on the red rail, cathode to the filter node. RL and C share that node. Banded end is the cathode.'));
  };
  LAYOUTS.shuntClipper = (b) => {
    const r = b.qty('r');
    const ac = (b.qty('ac') === undefined ? 1 : b.qty('ac')) >= 0.5;
    const label = ac ? trim(b.qty('vp')) + ' Vpk' : trim(b.qty('vdc')) + ' Vdc';
    const net = ac ? 'Vp' : 'Vdc';
    const vbias = b.qty('vbias') || 0;
    b.singleSupply(label, net, 'GND');
    b.resistor('r', 'R', r, b.hole(6, 'c', net), b.hole(16, 'c', 'Vout'));
    if (Math.abs(vbias) < 1e-12) {
      b.diode('d', 'D', b.hole(16, 'e', 'Vout'), b.hole(16, 'f', 'GND'));
      b.jumper('dk', 'GND', 16, 'j', 16, 'botMinus', 'black');
    } else {
      b.diode('d', 'D', b.hole(16, 'e', 'Vout'), b.hole(16, 'f', 'Vb'));
      b.components.push({ id: 'vb', part: { type: 'source', label: 'Vb ' + trim(vbias) + ' V' }, leads: [b.hole(22, 'f', 'Vb'), b.hole(22, 'e', 'GND')] });
      b.jumper('bias', 'Vb', 16, 'i', 22, 'i', 'blue'); b.jumper('bg', 'GND', 22, 'a', 22, 'topMinus', 'black');
    }
    b.jumper('src', net, 6, 'a', 6, 'topPlus', 'red'); b.jumper('tap', 'Vout', 16, 'b', 24, 'b', 'yellow'); b.jumper('gnd', 'GND', 24, 'j', 24, 'botMinus', 'black');
    return b.finish(b.caption('Series R into a shunt diode. The banded cathode sits toward the bias/ground side. Yellow is the clipped output node.'));
  };
  LAYOUTS.clamper = (b) => {
    const vp = b.qty('vp');
    b.singleSupply(trim(vp) + ' Vpk', 'Vp', 'GND');
    b.capacitor('c', 'C', 1e-6, b.hole(8, 'c', 'Vp'), b.hole(16, 'c', 'Vout'));
    b.diode('d', 'D', b.hole(16, 'f', 'GND'), b.hole(16, 'e', 'Vout'));
    b.jumper('src', 'Vp', 8, 'a', 8, 'topPlus', 'red'); b.jumper('out', 'Vout', 16, 'b', 24, 'b', 'yellow');
    b.jumper('gnd', 'GND', 16, 'j', 16, 'botMinus', 'black'); b.jumper('gndb', 'GND', 24, 'j', 24, 'botMinus', 'black');
    return b.finish(b.caption('Series C with a diode to the blue rail. Banded cathode is on the output node (positive clamp). C is illustrative — the solve only shifts the peaks.'));
  };
  LAYOUTS.fullBridge = (b) => {
    const c = b.qty('c'), rload = b.qty('rload');
    const ac = (b.qty('ac') === undefined ? 1 : b.qty('ac')) >= 0.5;
    if (ac) {
      b.singleSupply('Vpk', 'Vpk', 'GND');
      b.components.push({ id: 'ac', part: { type: 'source', label: trim(b.qty('vrms')) + ' Vrms' }, leads: [b.hole(5, 'e', 'VacA'), b.hole(5, 'f', 'VacB')] });
      b.diode('d1', 'D1', b.hole(8, 'c', 'VacA'), b.hole(14, 'c', 'Vpk'));
      b.diode('d2', 'D2', b.hole(10, 'j', 'VacB'), b.hole(14, 'j', 'Vpk'));
      b.diode('d3', 'D3', b.hole(7, 'f', 'GND'), b.hole(8, 'i', 'VacA'));
      b.diode('d4', 'D4', b.hole(9, 'f', 'GND'), b.hole(10, 'h', 'VacB'));
      b.jumper('aBus', 'VacA', 5, 'c', 8, 'a', 'yellow'); b.jumper('aCross', 'VacA', 8, 'e', 8, 'f', 'yellow');
      b.jumper('bBus', 'VacB', 5, 'j', 10, 'g', 'violet'); b.jumper('vpkCross', 'Vpk', 14, 'e', 14, 'f', 'red');
      b.jumper('plus', 'Vpk', 14, 'a', 14, 'topPlus', 'red'); b.jumper('plusb', 'Vpk', 14, 'd', 20, 'd', 'red');
      b.jumper('g3', 'GND', 7, 'j', 7, 'botMinus', 'black'); b.jumper('g4', 'GND', 9, 'j', 9, 'botMinus', 'black');
      b.resistor('rl', 'RL', rload, b.hole(20, 'e', 'Vpk'), b.hole(20, 'f', 'GND'));
      b.capacitor('c', 'C', c, b.hole(24, 'e', 'Vpk'), b.hole(24, 'f', 'GND'));
      b.jumper('out', 'Vpk', 20, 'b', 24, 'b', 'red'); b.jumper('lg', 'GND', 20, 'j', 20, 'botMinus', 'black'); b.jumper('cg', 'GND', 24, 'j', 24, 'botMinus', 'black');
      return b.finish(b.caption('Full-wave bridge: AC secondary between VacA and VacB (not the DC rails). D1/D2 cathodes feed Vpk on the red rail; D3/D4 anodes sit on the blue rail. RL and C share Vpeak. Banded ends are cathodes. Illustrative — not a transformer pinout.'));
    }
    b.singleSupply(trim(b.qty('vdc')) + ' Vdc', 'Vdc', 'GND');
    b.diode('d1', 'D1', b.hole(6, 'c', 'Vdc'), b.hole(12, 'c', 'Mid'));
    b.diode('d2', 'D2', b.hole(12, 'a', 'Mid'), b.hole(18, 'a', 'Vpk'));
    b.resistor('rl', 'RL', rload, b.hole(18, 'e', 'Vpk'), b.hole(18, 'f', 'GND'));
    b.capacitor('c', 'C', c, b.hole(24, 'e', 'Vpk'), b.hole(24, 'f', 'GND'));
    b.jumper('src', 'Vdc', 6, 'a', 6, 'topPlus', 'red'); b.jumper('mid', 'Mid', 12, 'b', 12, 'e', 'orange');
    b.jumper('out', 'Vpk', 18, 'b', 24, 'b', 'yellow'); b.jumper('g1', 'GND', 18, 'j', 18, 'botMinus', 'black'); b.jumper('g2', 'GND', 24, 'j', 24, 'botMinus', 'black');
    return b.finish(b.caption('Bridge on a DC source is two forward drops in series (D1 then D2) into RL || C. Ripple is zero on DC — switch to AC sine to size C from a ripple target.'));
  };

  function transistor(b, npn, emitterNet) {
    const leads = [b.hole(16, 'f', emitterNet || (npn ? 'Ve' : 'GND')), b.hole(17, 'f', npn ? 'Vb' : 'Vgs'), b.hole(18, 'f', npn ? 'Vc' : 'Vd')];
    b.components.push(npn ? { id: 'q', part: { type: 'npn', name: '2N3904', label: '2N3904' }, leads } : { id: 'm', part: { type: 'nmos', name: '2N7000', label: '2N7000' }, leads });
  }
  LAYOUTS.bjtBias = (b) => {
    const r1 = b.qty('r1'), r2 = b.qty('r2'), rc = b.qty('rc'), re = b.qty('re'), vcc = b.qty('vcc');
    b.singleSupply(trim(vcc) + ' V', 'Vcc', 'GND'); transistor(b, true);
    b.resistor('r1', 'R1', r1, b.hole(11, 'i', 'Vcc'), b.hole(17, 'i', 'Vb')); b.resistor('r2', 'R2', r2, b.hole(17, 'j', 'Vb'), b.hole(22, 'j', 'GND'));
    b.resistor('rc', 'Rc', rc, b.hole(18, 'g', 'Vc'), b.hole(24, 'g', 'Vcc')); b.resistor('re', 'Re', re, b.hole(16, 'j', 'Ve'), b.hole(12, 'j', 'GND'));
    b.jumper('v1', 'Vcc', 11, 'g', 11, 'botPlus', 'red'); b.jumper('v2', 'Vcc', 24, 'j', 24, 'botPlus', 'red');
    b.jumper('g1', 'GND', 22, 'g', 22, 'botMinus', 'black'); b.jumper('g2', 'GND', 12, 'h', 12, 'botMinus', 'black');
    return b.finish(b.caption('2N3904 with its flat face toward you, leads E B C left to right. R1 and R2 set the base. Rc and Re are the collector and emitter resistors.'));
  };
  LAYOUTS.ceAmp = (b) => {
    const r1 = b.qty('r1'), r2 = b.qty('r2'), rc = b.qty('rc'), re = b.qty('re'), vcc = b.qty('vcc'), rl = b.qty('rl');
    b.singleSupply(trim(vcc) + ' V', 'Vcc', 'GND'); transistor(b, true);
    b.resistor('r1', 'R1', r1, b.hole(11, 'i', 'Vcc'), b.hole(17, 'i', 'Vb')); b.resistor('r2', 'R2', r2, b.hole(17, 'j', 'Vb'), b.hole(22, 'j', 'GND'));
    b.resistor('rc', 'Rc', rc, b.hole(18, 'g', 'Vc'), b.hole(24, 'g', 'Vcc')); b.resistor('re', 'Re', re, b.hole(16, 'j', 'Ve'), b.hole(12, 'j', 'GND'));
    b.capacitor('cc', 'Cc', 1e-6, b.hole(20, 'c', 'Vc'), b.hole(26, 'c', 'Vout')); b.resistor('rl', 'RL', rl, b.hole(26, 'e', 'Vout'), b.hole(26, 'f', 'GND'));
    b.jumper('v1', 'Vcc', 11, 'g', 11, 'botPlus', 'red'); b.jumper('v2', 'Vcc', 24, 'j', 24, 'botPlus', 'red');
    b.jumper('g1', 'GND', 22, 'g', 22, 'botMinus', 'black'); b.jumper('g2', 'GND', 12, 'h', 12, 'botMinus', 'black');
    b.jumper('col', 'Vc', 18, 'i', 20, 'e', 'orange'); b.jumper('loadg', 'GND', 26, 'j', 26, 'botMinus', 'black');
    if (!b.solution.steps.some((x) => x.indexOf('/ (1 + gm·Re)') >= 0)) { b.capacitor('ce', 'Ce', 10e-6, b.hole(16, 'h', 'Ve'), b.hole(14, 'h', 'GND')); b.jumper('ceg', 'GND', 14, 'j', 14, 'botMinus', 'black'); }
    return b.finish(b.caption('CE stage on a 2N3904 (E B C). Bias matches the BJT bias board; Cc couples the collector into RL. Ce is illustrative when the emitter is bypassed for midband gain. Coupling/bypass are AC shorts in the solve — not a SPICE transient.'));
  };
  LAYOUTS.bjtSwitch = (b) => {
    const rb = b.qty('rb'), rc = b.qty('rc'), vcc = b.qty('vcc'), vin = b.qty('vin');
    b.singleSupply(trim(vcc) + ' V', 'Vcc', 'GND'); transistor(b, true, 'GND');
    b.components.push({ id: 'vin', part: { type: 'source', label: 'Vin ' + trim(vin) + ' V' }, leads: [b.hole(6, 'e', 'Vin'), b.hole(6, 'f', 'GND')] });
    b.resistor('rb', 'Rb', rb, b.hole(6, 'b', 'Vin'), b.hole(14, 'b', 'Vb')); b.resistor('rc', 'Rc', rc, b.hole(18, 'i', 'Vc'), b.hole(24, 'i', 'Vcc'));
    b.jumper('base', 'Vb', 14, 'd', 17, 'i', 'yellow'); b.jumper('emit', 'GND', 16, 'j', 16, 'botMinus', 'black');
    b.jumper('srcg', 'GND', 6, 'j', 6, 'botMinus', 'black'); b.jumper('vcc', 'Vcc', 24, 'g', 24, 'botPlus', 'red');
    return b.finish(b.caption('Low-side 2N3904 switch, E B C left to right. Vin is its own source referenced to the blue rail. The emitter jumper is the ground lead.'));
  };
  LAYOUTS.csAmp = (b) => {
    const rd = b.qty('rd'), vdd = b.qty('vdd'), vg = b.qty('vg'), rs = b.qty('rs') || 0;
    b.singleSupply(trim(vdd) + ' V', 'Vdd', 'GND');
    b.components.push({ id: 'm', part: { type: 'nmos', name: '2N7000', label: '2N7000' }, leads: [b.hole(16, 'f', rs > 1e-12 ? 'Vs' : 'GND'), b.hole(17, 'f', 'Vg'), b.hole(18, 'f', 'Vd')] });
    b.components.push({ id: 'vg', part: { type: 'source', label: 'Vg ' + trim(vg) + ' V' }, leads: [b.hole(6, 'e', 'Vg'), b.hole(6, 'f', 'GND')] });
    b.resistor('rd', 'Rd', rd, b.hole(18, 'i', 'Vd'), b.hole(24, 'i', 'Vdd'));
    if (rs > 1e-12) { b.resistor('rs', 'Rs', rs, b.hole(16, 'j', 'Vs'), b.hole(12, 'j', 'GND')); b.jumper('rsg', 'GND', 12, 'h', 12, 'botMinus', 'black'); }
    else b.jumper('src', 'GND', 16, 'j', 16, 'botMinus', 'black');
    b.jumper('gate', 'Vg', 6, 'c', 17, 'i', 'yellow'); b.jumper('srcg', 'GND', 6, 'j', 6, 'botMinus', 'black'); b.jumper('vdd', 'Vdd', 24, 'g', 24, 'botPlus', 'red');
    return b.finish(b.caption('CS stage on a 2N7000 (S G D). Rd is the drain load. Rs is present only when degeneration is non-zero; Rs = 0 ties the source to the blue rail. Square-law bias — not a SPICE model card.'));
  };
  LAYOUTS.mosSwitch = (b) => {
    const rd = b.qty('rd'), vdd = b.qty('vdd'), vgs = b.qty('vgs');
    b.singleSupply(trim(vdd) + ' V', 'Vdd', 'GND'); transistor(b, false);
    b.components.push({ id: 'vgs', part: { type: 'source', label: 'Vgs ' + trim(vgs) + ' V' }, leads: [b.hole(6, 'e', 'Vgs'), b.hole(6, 'f', 'GND')] });
    b.resistor('rd', 'Rd', rd, b.hole(18, 'i', 'Vd'), b.hole(24, 'i', 'Vdd'));
    b.jumper('gate', 'Vgs', 6, 'c', 17, 'i', 'yellow'); b.jumper('src', 'GND', 16, 'j', 16, 'botMinus', 'black');
    b.jumper('srcg', 'GND', 6, 'j', 6, 'botMinus', 'black'); b.jumper('vdd', 'Vdd', 24, 'g', 24, 'botPlus', 'red');
    return b.finish(b.caption('2N7000 with its flat face toward you, leads S G D left to right. Rd is the load. Rds(on) is inside the MOSFET, not a second part.'));
  };
  LAYOUTS.cmosInverter = (b) => {
    const vdd = b.qty('vdd'), vin = b.qty('vin') !== undefined ? b.qty('vin') : (b.qty('vm') !== undefined ? b.qty('vm') : vdd / 2);
    b.singleSupply(trim(vdd) + ' V', 'Vdd', 'GND');
    b.components.push({ id: 'p', part: { type: 'pmos', name: 'PMOS', label: 'PMOS' }, leads: [b.hole(18, 'c', 'Vdd'), b.hole(17, 'c', 'Vin'), b.hole(16, 'c', 'Vout')] });
    b.components.push({ id: 'n', part: { type: 'nmos', name: 'NMOS', label: 'NMOS' }, leads: [b.hole(14, 'f', 'GND'), b.hole(15, 'f', 'Vin'), b.hole(16, 'f', 'Vout')] });
    b.components.push({ id: 'vin', part: { type: 'source', label: 'Vin ' + trim(vin) + ' V' }, leads: [b.hole(6, 'e', 'Vin'), b.hole(6, 'f', 'GND')] });
    b.jumper('out', 'Vout', 16, 'e', 16, 'g', 'green'); b.jumper('gatep', 'Vin', 6, 'c', 17, 'a', 'yellow'); b.jumper('gaten', 'Vin', 15, 'i', 17, 'e', 'yellow');
    b.jumper('ps', 'Vdd', 18, 'a', 18, 'topPlus', 'red'); b.jumper('ns', 'GND', 14, 'j', 14, 'botMinus', 'black'); b.jumper('srcg', 'GND', 6, 'j', 6, 'botMinus', 'black');
    b.jumper('probe', 'Vout', 16, 'b', 24, 'b', 'green'); b.jumper('pgnd', 'GND', 24, 'j', 24, 'botMinus', 'black');
    return b.finish(b.caption('CMOS inverter sketch: discrete PMOS (rows a–e) and NMOS (rows f–j) sharing Vin and Vout across the gutter. Ideal rail-to-rail logic — static current is zero in the solve. Not a matched IC process or a SPICE deck.'));
  };

  const srcPart = (id, label, a, b) => ({ id, part: { type: 'source', label }, leads: [a, b] });
  const feedbackTie = (b) => { b.jumper('plus', 'GND', 14, 'c', 14, 'topMinus', 'black'); b.jumper('cross', 'Vout', 9, 'e', 9, 'f', 'green'); b.jumper('fb', 'Vout', 9, 'j', 14, 'i', 'green'); };
  LAYOUTS.invertingAmp = (b) => {
    const rin = b.qty('rin'), rf = b.qty('rf');
    b.placeOpAmp('SUM', 'GND'); b.dualSupply();
    b.components.push(srcPart('vin', 'Vin', b.hole(7, 'd', 'Vin'), b.hole(4, 'd', 'GND')));
    b.resistor('rin', 'Rin', rin, b.hole(7, 'b', 'Vin'), b.hole(13, 'b', 'SUM')); b.resistor('rf', 'Rf', rf, b.hole(13, 'a', 'SUM'), b.hole(9, 'a', 'Vout'));
    b.jumper('gndsrc', 'GND', 4, 'b', 4, 'topMinus', 'black'); feedbackTie(b);
    return b.finish(b.caption('741 in the DIP-8 straddling the gutter, notch to the left, pin 1 at the lower left. Rin and Rf meet at pin 2. Pin 3 is the blue ground rail. Pin 7 is +V and pin 4 is −V. The ideal model does not solve supply current.'));
  };
  LAYOUTS.nonInvertingAmp = (b) => {
    const rg = b.qty('rg'), rf = b.qty('rf');
    b.placeOpAmp('SUM', 'Vin'); b.dualSupply();
    b.components.push(srcPart('vin', 'Vin', b.hole(7, 'd', 'Vin'), b.hole(4, 'd', 'GND')));
    b.resistor('rg', 'Rg', rg, b.hole(13, 'c', 'SUM'), b.hole(9, 'c', 'GND')); b.resistor('rf', 'Rf', rf, b.hole(13, 'a', 'SUM'), b.hole(18, 'a', 'Vout'));
    b.jumper('gndsrc', 'GND', 4, 'b', 4, 'topMinus', 'black'); b.jumper('in', 'Vin', 7, 'b', 14, 'b', 'yellow'); b.jumper('rgg', 'GND', 9, 'a', 9, 'topMinus', 'black');
    b.jumper('cross', 'Vout', 18, 'e', 18, 'f', 'green'); b.jumper('fb', 'Vout', 18, 'j', 14, 'i', 'green');
    return b.finish(b.caption('741 pinout. Vin drives pin 3. Rg returns pin 2 to the blue rail and Rf feeds back from pin 6. Pin 7 is +V and pin 4 is −V. Supply current is not in the ideal model.'));
  };
  LAYOUTS.summingAmp = (b) => {
    const r1 = b.qty('r1'), r2 = b.qty('r2'), rf = b.qty('rf');
    b.placeOpAmp('SUM', 'GND'); b.dualSupply();
    b.components.push(srcPart('v1', 'V1', b.hole(5, 'd', 'V1'), b.hole(3, 'd', 'GND')), srcPart('v2', 'V2', b.hole(7, 'd', 'V2'), b.hole(3, 'e', 'GND')));
    b.resistor('r1', 'R1', r1, b.hole(5, 'b', 'V1'), b.hole(13, 'b', 'SUM')); b.resistor('r2', 'R2', r2, b.hole(7, 'a', 'V2'), b.hole(13, 'a', 'SUM')); b.resistor('rf', 'Rf', rf, b.hole(13, 'c', 'SUM'), b.hole(9, 'c', 'Vout'));
    b.jumper('gndsrc', 'GND', 3, 'b', 3, 'topMinus', 'black'); feedbackTie(b);
    return b.finish(b.caption('741 summing amp. R1 and R2 meet Rin at pin 2 (virtual ground). Rf feeds back from pin 6. Pin 3 is on the blue rail.'));
  };
  LAYOUTS.diffAmp = (b) => {
    const r1 = b.qty('r1'), rf = b.qty('rf');
    b.placeOpAmp('SUM', 'PLUS'); b.dualSupply();
    b.components.push(srcPart('v1', 'V1', b.hole(5, 'd', 'V1'), b.hole(3, 'd', 'GND')), srcPart('v2', 'V2', b.hole(7, 'd', 'V2'), b.hole(3, 'e', 'GND')));
    b.resistor('r1a', 'R1', r1, b.hole(5, 'b', 'V1'), b.hole(13, 'b', 'SUM')); b.resistor('rf', 'Rf', rf, b.hole(13, 'a', 'SUM'), b.hole(9, 'a', 'Vout'));
    b.resistor('r1b', 'R1', r1, b.hole(7, 'c', 'V2'), b.hole(14, 'c', 'PLUS')); b.resistor('rg', 'Rf', rf, b.hole(14, 'b', 'PLUS'), b.hole(18, 'b', 'GND'));
    b.jumper('gndsrc', 'GND', 3, 'b', 3, 'topMinus', 'black'); b.jumper('rgnd', 'GND', 18, 'a', 18, 'topMinus', 'black');
    b.jumper('cross', 'Vout', 9, 'e', 9, 'f', 'green'); b.jumper('fb', 'Vout', 9, 'j', 14, 'i', 'green');
    return b.finish(b.caption('Matched difference amp on a 741. Rin/Rf pairs on both inputs. Ideal matched resistors — mismatch CMRR is not modeled.'));
  };
  LAYOUTS.integrator = (b) => {
    const r = b.qty('r'), c = b.qty('c');
    b.placeOpAmp('SUM', 'GND'); b.dualSupply();
    b.components.push(srcPart('vin', 'Vin', b.hole(6, 'd', 'Vin'), b.hole(4, 'd', 'GND')));
    b.resistor('r', 'R', r, b.hole(6, 'b', 'Vin'), b.hole(13, 'b', 'SUM')); b.capacitor('c', 'C', c, b.hole(13, 'a', 'SUM'), b.hole(9, 'a', 'Vout'));
    b.jumper('gndsrc', 'GND', 4, 'b', 4, 'topMinus', 'black'); feedbackTie(b);
    return b.finish(b.caption('Ideal integrator: R into pin 2, C in the feedback. No reset resistor is drawn — DC error integrates forever in the model.'));
  };
  LAYOUTS.differentiator = (b) => {
    const r = b.qty('r'), c = b.qty('c');
    b.placeOpAmp('SUM', 'GND'); b.dualSupply();
    b.components.push(srcPart('vin', 'Vin', b.hole(6, 'd', 'Vin'), b.hole(4, 'd', 'GND')));
    b.capacitor('c', 'C', c, b.hole(6, 'b', 'Vin'), b.hole(13, 'b', 'SUM')); b.resistor('r', 'R', r, b.hole(13, 'a', 'SUM'), b.hole(9, 'a', 'Vout'));
    b.jumper('gndsrc', 'GND', 4, 'b', 4, 'topMinus', 'black'); feedbackTie(b);
    return b.finish(b.caption('Ideal differentiator: C into pin 2, R in the feedback. No high-frequency roll-off is modeled.'));
  };
  LAYOUTS.comparator = (b) => {
    b.placeOpAmp('Vin', 'Vref'); b.dualSupply();
    b.components.push(srcPart('vin', 'Vin', b.hole(6, 'd', 'Vin'), b.hole(4, 'd', 'GND')), srcPart('vref', 'Vref', b.hole(8, 'd', 'Vref'), b.hole(4, 'e', 'GND')));
    b.jumper('gndsrc', 'GND', 4, 'b', 4, 'topMinus', 'black'); b.jumper('in', 'Vin', 6, 'b', 13, 'b', 'yellow'); b.jumper('ref', 'Vref', 8, 'c', 14, 'c', 'orange');
    b.jumper('out', 'Vout', 14, 'i', 24, 'i', 'green'); b.jumper('cross', 'Vout', 24, 'e', 24, 'f', 'green');
    return b.finish(b.caption('Open-loop 741 as a comparator. Yellow is Vin on pin 2, orange is Vref on pin 3. Output sits on a rail — no feedback.'));
  };

  function astableBoard(b, withLed) {
    const r1 = b.qty('r1'), r2 = b.qty('r2'), c = b.qty('c'), vcc = b.qty('vcc');
    b.singleSupply(trim(vcc) + ' V', 'Vcc', 'GND');
    b.dip('u', '555', 11, [['GND', 'GND'], ['TRIG', 'TIME'], ['OUT', 'OUT'], ['RST', 'Vcc'], ['CTRL', 'CTRL'], ['THR', 'TIME'], ['DIS', 'DIS'], ['VCC', 'Vcc']]);
    b.jumper('gnd', 'GND', 11, 'a', 11, 'topMinus', 'black'); b.jumper('vcc', 'Vcc', 11, 'j', 11, 'botPlus', 'red'); b.jumper('rst', 'Vcc', 14, 'b', 14, 'topPlus', 'red');
    b.resistor('r1', 'R1', r1, b.hole(12, 'j', 'DIS'), b.hole(18, 'j', 'Vcc')); b.jumper('r1v', 'Vcc', 18, 'h', 18, 'botPlus', 'red');
    b.resistor('r2', 'R2', r2, b.hole(12, 'h', 'DIS'), b.hole(20, 'h', 'TIME'));
    b.jumper('thr', 'TIME', 13, 'i', 20, 'i', 'yellow'); b.jumper('bridge', 'TIME', 20, 'e', 20, 'f', 'yellow'); b.jumper('trig', 'TIME', 12, 'b', 20, 'b', 'yellow'); b.jumper('capj', 'TIME', 20, 'c', 22, 'c', 'yellow');
    b.capacitor('c', 'C', c, b.hole(22, 'e', 'TIME'), b.hole(22, 'f', 'GND')); b.jumper('cg', 'GND', 22, 'j', 22, 'botMinus', 'black');
    if (withLed) {
      b.resistor('rled', 'Rled', b.qty('rled'), b.hole(13, 'c', 'OUT'), b.hole(8, 'c', 'LED'));
      b.components.push({ id: 'led', part: { type: 'led', label: 'LED' }, leads: [b.hole(8, 'e', 'LED'), b.hole(8, 'f', 'GND')] });
      b.jumper('ledk', 'GND', 8, 'j', 8, 'botMinus', 'black');
    } else b.jumper('out', 'OUT', 13, 'c', 8, 'c', 'green');
    const extra = withLed ? 'The LED and Rled hang on pin 3 and return to the blue rail, so the LED is on while the output is high.' : 'Pin 3 is brought out on the green jumper. No load is added.';
    return b.finish(b.caption('NE555, notch to the left and pin 1 at the lower left, counting counter-clockwise like the real package. Reset is held on the red rail. R1 feeds discharge, R2 feeds the timing node, and pins 2 and 6 share the capacitor. Pin 5 is open. ' + extra));
  }
  LAYOUTS.astable555 = (b) => astableBoard(b, false);
  LAYOUTS.ledFlasher = (b) => astableBoard(b, true);
  LAYOUTS.monostable555 = (b) => {
    const r = b.qty('r'), c = b.qty('c'), vcc = b.qty('vcc');
    b.singleSupply(trim(vcc) + ' V', 'Vcc', 'GND');
    b.dip('u', '555', 11, [['GND', 'GND'], ['TRIG', 'TRIG'], ['OUT', 'OUT'], ['RST', 'Vcc'], ['CTRL', 'CTRL'], ['THR', 'RC'], ['DIS', 'RC'], ['VCC', 'Vcc']]);
    b.jumper('gnd', 'GND', 11, 'a', 11, 'topMinus', 'black'); b.jumper('vcc', 'Vcc', 11, 'j', 11, 'botPlus', 'red'); b.jumper('rst', 'Vcc', 14, 'b', 14, 'topPlus', 'red');
    b.resistor('r', 'R', r, b.hole(12, 'j', 'RC'), b.hole(18, 'j', 'Vcc')); b.jumper('rv', 'Vcc', 18, 'h', 18, 'botPlus', 'red');
    b.jumper('tie67', 'RC', 13, 'i', 12, 'i', 'orange'); b.jumper('torow', 'RC', 12, 'g', 16, 'g', 'orange'); b.jumper('bridge', 'RC', 16, 'e', 16, 'f', 'orange'); b.jumper('tocap', 'RC', 16, 'c', 20, 'c', 'orange');
    b.capacitor('c', 'C', c, b.hole(20, 'e', 'RC'), b.hole(20, 'f', 'GND')); b.jumper('cg', 'GND', 20, 'j', 20, 'botMinus', 'black');
    b.jumper('trig', 'TRIG', 12, 'b', 8, 'b', 'violet'); b.jumper('out', 'OUT', 13, 'c', 9, 'c', 'green');
    return b.finish(b.caption('NE555 one-shot. R and C set the width, with threshold and discharge tied. The violet jumper is the trigger input. A brief low there starts the pulse. No extra trigger network is drawn. Pin 5 is open.'));
  };
  LAYOUTS.sevenSegment = (b) => {
    const r = b.qty('r'), digit = Math.round(b.qty('digit')), vcc = b.qty('vcc'), mask = SEG_MASK[digit];
    b.singleSupply(trim(vcc) + ' V', 'Vcc', 'GND');
    const pins = ['e', 'd', 'CC', 'c', 'DP', 'b', 'a', 'CC', 'f', 'g'], nets = ['Se', 'Sd', 'GND', 'Sc', 'DP', 'Sb', 'Sa', 'GND', 'Sf', 'Sg'], leads = [], origin = 20;
    for (let i = 0; i < 5; i++) leads.push(b.hole(origin + i, 'e', nets[i]));
    for (let i = 0; i < 5; i++) leads.push(b.hole(origin + 4 - i, 'f', nets[5 + i]));
    b.components.push({ id: 'seg', part: { type: 'display', name: '5161AS', digit, mask, pins }, leads });
    b.jumper('cc1', 'GND', 22, 'b', 22, 'topMinus', 'black'); b.jumper('cc2', 'GND', 22, 'j', 22, 'botMinus', 'black');
    [[0, 'Sa', 14, 23, 'i', false], [1, 'Sb', 15, 24, 'g', false], [2, 'Sc', 12, 23, 'c', true], [3, 'Sd', 9, 21, 'b', true], [4, 'Se', 8, 20, 'd', true], [5, 'Sf', 11, 21, 'h', false], [6, 'Sg', 10, 20, 'j', false]].forEach((p) => {
      if (!(mask & (1 << p[0]))) return;
      b.resistor('r' + p[1], 'R' + p[1].slice(1), r, b.hole(p[2], p[4], 'Vcc'), b.hole(p[3], p[4], p[1]));
      if (p[5]) b.jumper('v' + p[1], 'Vcc', p[2], 'a', p[2], 'topPlus', 'red'); else b.jumper('v' + p[1], 'Vcc', p[2], p[4] === 'j' ? 'g' : 'j', p[2], 'botPlus', 'red');
    });
    return b.finish(b.caption('Common-cathode 5161AS. Pins 3 and 8 are the cathode, on the blue rail. Each lit segment has its own resistor from the red rail. Dark segments are open. DP is unused.'));
  };

  LAYOUTS.discretePower = (b) => { const bd = LAYOUTS.bjtBias(b); bd.caption = b.caption('Class-A common-emitter stage on a 2N3904 with its flat face toward you, leads E B C left to right. R1 and R2 set the base, Rc is the collector load, and Re sets the emitter. Quiescent power in the transistor is Ic × Vce. Add a heatsink and check the bias before you rely on it for real power.'); return bd; };
  LAYOUTS.opAmpPower = (b) => {
    const rf = b.qty('rf'), av = b.qty('av'), rg = rf / (av - 1), vout = b.qty('vout') || 0, iout = b.qty('iout') || 0, rl = (Math.abs(vout) > 1e-12 && Math.abs(iout) > 1e-12) ? Math.abs(vout / iout) : 1000;
    b.placeOpAmp('SUM', 'Vin'); b.dualSupply();
    b.components.push(srcPart('vin', 'Vin', b.hole(7, 'd', 'Vin'), b.hole(4, 'd', 'GND')));
    b.resistor('rg', 'Rg', rg, b.hole(13, 'c', 'SUM'), b.hole(9, 'c', 'GND')); b.resistor('rf', 'Rf', rf, b.hole(13, 'a', 'SUM'), b.hole(18, 'a', 'Vout')); b.resistor('rl', 'RL', rl, b.hole(18, 'c', 'Vout'), b.hole(22, 'c', 'GND'));
    b.jumper('gndsrc', 'GND', 4, 'b', 4, 'topMinus', 'black'); b.jumper('in', 'Vin', 7, 'b', 14, 'b', 'yellow'); b.jumper('rgg', 'GND', 9, 'a', 9, 'topMinus', 'black'); b.jumper('rlg', 'GND', 22, 'a', 22, 'topMinus', 'black');
    b.jumper('cross', 'Vout', 18, 'e', 18, 'f', 'green'); b.jumper('fb', 'Vout', 18, 'j', 14, 'i', 'green');
    return b.finish(b.caption('741 pinout. Vin drives pin 3, Rg and Rf set the gain, and RL is the load from Vout to the ground rail. Pin 7 is +V and pin 4 is −V. A 741 cannot source much current, so keep RL large on the real part. The ideal model does not limit output current.'));
  };
  LAYOUTS.linearDrop = (b) => {
    const vin = b.qty('vin'), vout = b.qty('vout'), iload = b.qty('iload'), drop = Math.max(vin - vout, 1e-9), rpass = drop / Math.max(iload, 1e-9), rload = vout / Math.max(iload, 1e-9);
    b.singleSupply(trim(vin) + ' V', 'Vin', 'GND');
    b.resistor('pass', 'Pass', rpass, b.hole(6, 'c', 'Vin'), b.hole(16, 'c', 'Vout')); b.resistor('rl', 'Load', rload, b.hole(16, 'e', 'Vout'), b.hole(16, 'f', 'GND'));
    b.jumper('vin', 'Vin', 6, 'a', 6, 'topPlus', 'red'); b.jumper('out', 'Vout', 16, 'b', 24, 'b', 'yellow'); b.jumper('gnd', 'GND', 16, 'j', 16, 'botMinus', 'black'); b.jumper('gndb', 'GND', 24, 'j', 24, 'botMinus', 'black');
    return b.finish(b.caption('Linear drop sketched as a series pass resistance and the load. Heat is (Vin − Vout)·Iload. Not a real regulator pinout.'));
  };

  global.BeckifyBenchEngine = {
    CalcError, FAMILIES, SPECS, SOLVERS, LAYOUTS, ROW_Y, BB_ROWS, BB_COLUMNS, DISCLOSURE,
    parseEngineering, eng, si, trim, fourBand, visibleFields, specOf, solve, solveSafe,
    auditBoard, manhattan, bbGroup, isRail, makeMeters,
    circuits: () => SPECS.map((s) => s.id),
  };
  global.__benchEngineTestApi = global.BeckifyBenchEngine;
})(typeof window !== 'undefined' ? window : globalThis);
