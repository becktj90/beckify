(function () {
  'use strict';

  var SIZE = 500;
  var CX = 250;
  var CY = 250;
  var RADIUS = 200;
  var EPS = 1e-12;

  var COLORS = {
    bg: '#0d1117',
    grid: 'rgba(139,123,255,0.3)',
    resistance: '#8b7bff',
    reactance: '#4f8bff',
    point: '#ff8a8a',
    pointAlt: '#ffd166',
    vswr: '#6ee7b7',
    axis: 'rgba(255,255,255,0.18)',
    text: '#e6edf3',
    muted: '#9fb0c0',
    boundary: 'rgba(255,255,255,0.7)',
    rotation: '#f5c451',
    selected: '#ff6b6b',
  };

  var RESISTANCE_VALUES = [0, 0.2, 0.5, 1, 2, 5, 10];
  var REACTANCE_VALUES = [0.2, 0.5, 1, 2, 5];

  var state = {
    z0: 50,
    canvas: null,
    ctx: null,
    points: [],
    nextId: 1,
    selectedId: null,
    rotationOverlay: null,
    exampleNotes: [],
    infoMessage: '',
    initialized: false,
    clickBound: false,
  };

  function getDoc() {
    return typeof document !== 'undefined' ? document : null;
  }

  function getEl(candidates) {
    var doc = getDoc();
    var list = Array.isArray(candidates) ? candidates : [candidates];
    var i;
    var el;
    if (!doc) return null;
    for (i = 0; i < list.length; i += 1) {
      el = doc.getElementById(list[i]);
      if (el) return el;
    }
    for (i = 0; i < list.length; i += 1) {
      el = doc.querySelector('[name="' + list[i] + '"]');
      if (el) return el;
    }
    return null;
  }

  function readNumber(candidates, fallback) {
    var el = getEl(candidates);
    var raw;
    var text;
    if (!el) return fallback;
    raw = typeof el.value === 'string' ? el.value.trim() : '';
    if (!raw) return fallback;
    text = raw.toLowerCase();
    if (text === 'inf' || text === '+inf' || text === 'infinity' || text === '+infinity' || text === '∞') {
      return Infinity;
    }
    if (text === '-inf' || text === '-infinity') return -Infinity;
    var num = Number(raw);
    return isFinite(num) || num === Infinity || num === -Infinity ? num : fallback;
  }

  function readText(candidates, fallback) {
    var el = getEl(candidates);
    if (!el || typeof el.value !== 'string') return fallback || '';
    return el.value.trim();
  }

  function setField(candidates, value) {
    var el = getEl(candidates);
    if (el) el.value = value;
  }

  function create(tag, text, className) {
    var el = getDoc().createElement(tag);
    if (className) el.className = className;
    if (text !== undefined && text !== null) el.textContent = text;
    return el;
  }

  function clearChildren(el) {
    while (el && el.firstChild) el.removeChild(el.firstChild);
  }

  function fmt(value, digits) {
    if (value === Infinity) return '∞';
    if (value === -Infinity) return '−∞';
    if (!isFinite(value)) return '—';
    var abs = Math.abs(value);
    var places = typeof digits === 'number' ? digits : (abs >= 100 ? 1 : abs >= 10 ? 2 : 3);
    return value.toFixed(places).replace(/\.?0+$/, '');
  }

  function fmtSigned(value, digits) {
    if (value === Infinity) return '+∞';
    if (value === -Infinity) return '−∞';
    if (!isFinite(value)) return '—';
    return (value >= 0 ? '+' : '−') + fmt(Math.abs(value), digits);
  }

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  function deg(rad) {
    return rad * 180 / Math.PI;
  }

  function rad(degrees) {
    return degrees * Math.PI / 180;
  }

  function normalizeAngleDeg(angle) {
    var out = angle % 360;
    return out < 0 ? out + 360 : out;
  }

  function positiveClockwiseDelta(startDeg, endDeg) {
    return normalizeAngleDeg(startDeg - endDeg);
  }

  function complex(re, im) {
    return { re: re, im: im };
  }

  function cAdd(a, b) {
    return complex(a.re + b.re, a.im + b.im);
  }

  function cSub(a, b) {
    return complex(a.re - b.re, a.im - b.im);
  }

  function cMul(a, b) {
    return complex(a.re * b.re - a.im * b.im, a.re * b.im + a.im * b.re);
  }

  function cDiv(a, b) {
    var den = b.re * b.re + b.im * b.im;
    if (den < EPS) return complex(Infinity, Infinity);
    return complex((a.re * b.re + a.im * b.im) / den, (a.im * b.re - a.re * b.im) / den);
  }

  function cScale(a, s) {
    return complex(a.re * s, a.im * s);
  }

  function cMag(a) {
    return Math.sqrt(a.re * a.re + a.im * a.im);
  }

  function cArgDeg(a) {
    return deg(Math.atan2(a.im, a.re));
  }

  function cFromPolar(mag, angleDeg) {
    var ang = rad(angleDeg);
    return complex(mag * Math.cos(ang), mag * Math.sin(ang));
  }

  function gammaToCanvas(gamma) {
    return {
      x: CX + gamma.re * RADIUS,
      y: CY - gamma.im * RADIUS,
    };
  }

  function canvasToGamma(x, y) {
    return complex((x - CX) / RADIUS, (CY - y) / RADIUS);
  }

  function isInsideSmith(gamma) {
    return cMag(gamma) <= 1 + 1e-6;
  }

  function gammaFromNormalizedZ(z) {
    return cDiv(cSub(z, complex(1, 0)), cAdd(z, complex(1, 0)));
  }

  function normalizedZFromGamma(gamma) {
    var den = cSub(complex(1, 0), gamma);
    if (den.re * den.re + den.im * den.im < EPS) {
      return complex(Infinity, Infinity);
    }
    return cDiv(cAdd(complex(1, 0), gamma), den);
  }

  function gammaFromImpedance(realOhms, imagOhms, z0) {
    if (!isFinite(realOhms) || !isFinite(imagOhms)) {
      if (realOhms === Infinity || imagOhms === Infinity) return complex(1, 0);
    }
    if (Math.abs(realOhms) < EPS && Math.abs(imagOhms) < EPS) return complex(-1, 0);
    return gammaFromNormalizedZ(complex(realOhms / z0, imagOhms / z0));
  }

  function regionFromNormalized(z) {
    if (!isFinite(z.im)) return 'resistive';
    if (Math.abs(z.im) < 1e-9) return 'resistive';
    return z.im > 0 ? 'inductive' : 'capacitive';
  }

  function metricsFromGamma(gamma, z0) {
    var rho = clamp(cMag(gamma), 0, 1);
    var angle = cArgDeg(gamma);
    var z = normalizedZFromGamma(gamma);
    var Z;
    if (!isFinite(z.re) || !isFinite(z.im)) {
      Z = complex(Infinity, Infinity);
    } else {
      Z = cScale(z, z0);
    }
    return {
      gamma: gamma,
      gammaMag: rho,
      gammaAngleDeg: angle,
      z: z,
      Z: Z,
      vswr: rho >= 1 - 1e-9 ? Infinity : (1 + rho) / (1 - rho),
      returnLoss: rho < EPS ? Infinity : -20 * Math.log(rho) / Math.LN10,
      region: regionFromNormalized(z),
    };
  }

  function resolvePoint(point) {
    var gamma;
    if (point.kind === 'gamma') {
      gamma = complex(point.gamma.re, point.gamma.im);
    } else if (point.kind === 'open') {
      gamma = complex(1, 0);
    } else if (point.kind === 'short') {
      gamma = complex(-1, 0);
    } else {
      gamma = gammaFromImpedance(point.Z.re, point.Z.im, state.z0);
    }
    point.current = metricsFromGamma(gamma, state.z0);
    return point.current;
  }

  function lastPoint() {
    return state.points.length ? state.points[state.points.length - 1] : null;
  }

  function setMessage(text) {
    state.infoMessage = text || '';
  }

  function drawBackground() {
    var ctx = state.ctx;
    ctx.clearRect(0, 0, SIZE, SIZE);
    ctx.fillStyle = COLORS.bg;
    ctx.fillRect(0, 0, SIZE, SIZE);
  }

  function drawOuterCircle() {
    var ctx = state.ctx;
    ctx.save();
    ctx.strokeStyle = COLORS.boundary;
    ctx.lineWidth = 1.8;
    ctx.beginPath();
    ctx.arc(CX, CY, RADIUS, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  function drawAxes() {
    var ctx = state.ctx;
    ctx.save();
    ctx.strokeStyle = COLORS.axis;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(CX - RADIUS, CY);
    ctx.lineTo(CX + RADIUS, CY);
    ctx.moveTo(CX, CY - RADIUS);
    ctx.lineTo(CX, CY + RADIUS);
    ctx.stroke();
    ctx.restore();
  }

  function drawResistanceCircles() {
    var ctx = state.ctx;
    var i;
    var center;
    var radius;
    ctx.save();
    ctx.strokeStyle = COLORS.resistance;
    ctx.lineWidth = 1.1;
    for (i = 0; i < RESISTANCE_VALUES.length; i += 1) {
      center = RESISTANCE_VALUES[i] / (RESISTANCE_VALUES[i] + 1);
      radius = 1 / (RESISTANCE_VALUES[i] + 1);
      ctx.beginPath();
      ctx.arc(CX + center * RADIUS, CY, radius * RADIUS, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawReactanceCircles() {
    var ctx = state.ctx;
    var values = REACTANCE_VALUES;
    var i;
    var sign;
    var x;
    var cy;
    var radius;
    ctx.save();
    ctx.beginPath();
    ctx.arc(CX, CY, RADIUS, 0, Math.PI * 2);
    ctx.clip();
    ctx.strokeStyle = COLORS.reactance;
    ctx.lineWidth = 1.1;
    for (i = 0; i < values.length; i += 1) {
      for (sign = -1; sign <= 1; sign += 2) {
        x = values[i] * sign;
        cy = (1 / x) * RADIUS;
        radius = Math.abs(1 / x) * RADIUS;
        ctx.beginPath();
        ctx.arc(CX + RADIUS, CY - cy, radius, 0, Math.PI * 2);
        ctx.stroke();
      }
    }
    ctx.restore();
  }

  function drawRimLabels() {
    var ctx = state.ctx;
    var i;
    var z;
    var gamma;
    var p;
    ctx.save();
    ctx.fillStyle = COLORS.muted;
    ctx.font = '12px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    for (i = 0; i < RESISTANCE_VALUES.length; i += 1) {
      gamma = gammaFromNormalizedZ(complex(RESISTANCE_VALUES[i], 0));
      p = gammaToCanvas(gamma);
      ctx.fillText(String(RESISTANCE_VALUES[i]), p.x, p.y - 12);
    }

    for (i = 0; i < REACTANCE_VALUES.length; i += 1) {
      z = complex(0, REACTANCE_VALUES[i]);
      gamma = gammaFromNormalizedZ(z);
      p = gammaToCanvas(complex(gamma.re * 1.08, gamma.im * 1.08));
      ctx.fillText('j' + REACTANCE_VALUES[i], p.x, p.y);

      z = complex(0, -REACTANCE_VALUES[i]);
      gamma = gammaFromNormalizedZ(z);
      p = gammaToCanvas(complex(gamma.re * 1.08, gamma.im * 1.08));
      ctx.fillText('−j' + REACTANCE_VALUES[i], p.x, p.y);
    }

    ctx.fillText('Γ = 1', CX + RADIUS + 18, CY);
    ctx.fillText('r', CX + 12, CY - RADIUS - 14);
    ctx.fillText('x', CX + RADIUS - 8, CY - 16);
    ctx.restore();
  }

  function drawVswrCircle(point) {
    var ctx = state.ctx;
    var rho = point.current.gammaMag;
    if (rho < EPS) return;
    ctx.save();
    ctx.strokeStyle = COLORS.vswr;
    ctx.lineWidth = 1.3;
    ctx.setLineDash([6, 4]);
    ctx.beginPath();
    ctx.arc(CX, CY, rho * RADIUS, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  function drawRotationOverlay() {
    var ctx = state.ctx;
    var overlay = state.rotationOverlay;
    var steps;
    var i;
    var frac;
    var theta;
    var g;
    var p;
    if (!overlay) return;
    steps = Math.max(24, Math.ceil(Math.abs(overlay.thetaDeg) / 4));
    ctx.save();
    ctx.strokeStyle = COLORS.rotation;
    ctx.lineWidth = 2;
    ctx.beginPath();
    for (i = 0; i <= steps; i += 1) {
      frac = i / steps;
      theta = overlay.direction === 'generator' ? -overlay.thetaDeg * frac : overlay.thetaDeg * frac;
      g = cMul(overlay.startGamma, cFromPolar(1, theta));
      p = gammaToCanvas(g);
      if (i === 0) ctx.moveTo(p.x, p.y);
      else ctx.lineTo(p.x, p.y);
    }
    ctx.stroke();
    ctx.restore();
  }

  function drawPoints() {
    var ctx = state.ctx;
    var i;
    var point;
    var p;
    var color;

    for (i = 0; i < state.points.length; i += 1) {
      point = state.points[i];
      resolvePoint(point);
    }

    point = lastPoint();
    if (point) drawVswrCircle(point);
    drawRotationOverlay();

    ctx.save();
    ctx.font = '12px system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    for (i = 0; i < state.points.length; i += 1) {
      point = state.points[i];
      p = gammaToCanvas(point.current.gamma);
      color = point.id === state.selectedId ? COLORS.selected : COLORS.point;
      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.arc(p.x, p.y, point.id === state.selectedId ? 5 : 4, 0, Math.PI * 2);
      ctx.fill();

      ctx.strokeStyle = 'rgba(0,0,0,0.55)';
      ctx.lineWidth = 1;
      ctx.stroke();

      ctx.fillStyle = point.id === state.selectedId ? COLORS.pointAlt : COLORS.text;
      ctx.fillText(String(i + 1), p.x + 8, p.y - 10);
    }
    ctx.restore();
  }

  function redraw() {
    if (!state.ctx) return;
    drawBackground();
    drawAxes();
    drawResistanceCircles();
    drawReactanceCircles();
    drawOuterCircle();
    drawRimLabels();
    drawPoints();
  }

  function addPoint(point) {
    state.infoMessage = '';
    point.id = state.nextId;
    state.nextId += 1;
    state.points.push(point);
    state.selectedId = point.id;
    resolvePoint(point);
    redraw();
    renderResults();
    return point;
  }

  function appendMetricRow(host, label, value) {
    var row = create('div');
    var strong = create('strong', label + ': ');
    var span = create('span', value);
    row.appendChild(strong);
    row.appendChild(span);
    host.appendChild(row);
  }

  function pointHeading(point, index) {
    var label = point.label ? point.label : 'Point ' + (index + 1);
    if (point.noteShort) label += ' — ' + point.noteShort;
    return label;
  }

  function formatImpedance(Z) {
    if (!isFinite(Z.re) || !isFinite(Z.im)) return '∞';
    return fmt(Z.re, 3) + ' ' + (Z.im < 0 ? '−' : '+') + ' j' + fmt(Math.abs(Z.im), 3);
  }

  function formatNormalized(z) {
    if (!isFinite(z.re) || !isFinite(z.im)) return '∞';
    return fmt(z.re, 4) + ' ' + (z.im < 0 ? '−' : '+') + ' j' + fmt(Math.abs(z.im), 4);
  }

  function formatGamma(gamma) {
    return fmt(gamma.re, 4) + ' ' + (gamma.im < 0 ? '−' : '+') + ' j' + fmt(Math.abs(gamma.im), 4);
  }

  function renderResults() {
    var panel = getEl('sc-result');
    var i;
    var block;
    var point;
    var metrics;
    var notes;
    if (!panel) return;

    clearChildren(panel);

    if (state.exampleNotes.length) {
      block = create('div');
      block.appendChild(create('h3', 'Example notes'));
      for (i = 0; i < state.exampleNotes.length; i += 1) {
        block.appendChild(create('p', state.exampleNotes[i]));
      }
      panel.appendChild(block);
    }

    if (state.infoMessage) {
      panel.appendChild(create('p', state.infoMessage));
    }

    if (!state.points.length) {
      panel.appendChild(create('p',
        'Click the chart or enter Z and press Plot. The last point shows its VSWR circle.'));
      return;
    }

    block = create('div');
    block.appendChild(create('h3', 'Points list'));
    panel.appendChild(block);

    for (i = 0; i < state.points.length; i += 1) {
      point = state.points[i];
      metrics = resolvePoint(point);
      notes = create('div');
      notes.style.marginBottom = '12px';
      notes.style.paddingBottom = '12px';
      notes.style.borderBottom = '1px solid rgba(255,255,255,0.12)';
      notes.appendChild(create('h4', pointHeading(point, i)));
      appendMetricRow(notes, 'Z', formatImpedance(metrics.Z) + ' Ω');
      appendMetricRow(notes, 'z', formatNormalized(metrics.z));
      appendMetricRow(notes, 'Γ',
        formatGamma(metrics.gamma) +
        ',  |Γ| = ' + fmt(metrics.gammaMag, 3) +
        ',  ∠Γ = ' + fmt(metrics.gammaAngleDeg, 1) + '°');
      appendMetricRow(notes, 'VSWR', metrics.vswr === Infinity ? '∞' : fmt(metrics.vswr, 2));
      appendMetricRow(notes, 'Return Loss', metrics.returnLoss === Infinity ? '∞ dB' : fmt(metrics.returnLoss, 1) + ' dB');
      appendMetricRow(notes, 'Region', metrics.region);
      if (point.frequencyText) appendMetricRow(notes, 'Frequency', point.frequencyText);
      if (point.extraText) notes.appendChild(create('p', point.extraText));
      panel.appendChild(notes);
    }
  }

  function readZ0() {
    var z0 = readNumber(['sc-z0', 'sc_z0', 'Z0', 'z0'], state.z0);
    if (!isFinite(z0) || z0 <= 0) return state.z0;
    return z0;
  }

  function clearRotation() {
    state.rotationOverlay = null;
  }

  function plotImpedance(realOhms, imagOhms, label, extraText) {
    state.z0 = readZ0();
    setField(['sc-z0', 'sc_z0', 'Z0', 'z0'], state.z0);
    clearRotation();
    return addPoint({
      kind: 'impedance',
      Z: complex(realOhms, imagOhms),
      label: label || 'Plotted load',
      extraText: extraText || '',
      frequencyText: readText(['sc-frequency', 'sc_frequency', 'Frequency', 'frequency'], ''),
    });
  }

  function plotGamma(gamma, label, extraText) {
    clearRotation();
    return addPoint({
      kind: 'gamma',
      gamma: complex(gamma.re, gamma.im),
      label: label || 'Clicked point',
      extraText: extraText || '',
      frequencyText: readText(['sc-frequency', 'sc_frequency', 'Frequency', 'frequency'], ''),
    });
  }

  function nearestPointLabel() {
    return 'Point ' + (state.points.length + 1);
  }

  function handleCanvasClick(ev) {
    var rect;
    var x;
    var y;
    var gamma;
    if (!state.canvas) return;
    rect = state.canvas.getBoundingClientRect();
    x = (ev.clientX - rect.left) * (state.canvas.width / rect.width);
    y = (ev.clientY - rect.top) * (state.canvas.height / rect.height);
    gamma = canvasToGamma(x, y);
    if (!isInsideSmith(gamma)) return;
    plotGamma(gamma, nearestPointLabel(), 'Added from a Smith chart click.');
  }

  function ensureCanvas() {
    var canvas = getEl('sc-canvas');
    if (!canvas) {
      setMessage('Canvas #sc-canvas not found.');
      return false;
    }
    canvas.width = SIZE;
    canvas.height = SIZE;
    state.canvas = canvas;
    state.ctx = canvas.getContext('2d');
    if (!state.clickBound) {
      canvas.addEventListener('click', handleCanvasClick);
      state.clickBound = true;
    }
    return true;
  }

  function scInit() {
    state.z0 = readZ0();
    if (!ensureCanvas()) return;
    redraw();
    renderResults();
    state.initialized = true;
  }

  function scPlotPoint() {
    var zr = readNumber(['sc-z-real', 'sc_z_real', 'Z_real', 'z_real'], NaN);
    var zi = readNumber(['sc-z-imag', 'sc_z_imag', 'Z_imag', 'z_imag'], NaN);
    var gamma;
    if (!ensureCanvas()) return;
    state.exampleNotes = [];
    state.z0 = readZ0();
    if (!isFinite(zr) || !isFinite(zi)) {
      setMessage('Enter valid real and imaginary impedance values before plotting.');
      redraw();
      renderResults();
      return;
    }
    gamma = gammaFromImpedance(zr, zi, state.z0);
    if (!isInsideSmith(gamma)) {
      setMessage('This impedance maps outside |Γ| ≤ 1. The Smith chart only shows passive points.');
      redraw();
      renderResults();
      return;
    }
    plotImpedance(zr, zi, 'Entered load', 'Computed from the input impedance and current Z₀ reference.');
  }

  function scClearPoints() {
    state.points = [];
    state.selectedId = null;
    state.rotationOverlay = null;
    state.exampleNotes = [];
    state.infoMessage = '';
    redraw();
    renderResults();
  }

  function chooseR1Intersection(loadGamma) {
    var rho = cMag(loadGamma);
    var base;
    var candidates;
    var i;
    var cw;
    var best = null;
    if (rho < EPS || rho >= 1 - 1e-9) return null;
    base = 2 * rho / Math.sqrt(Math.max(EPS, 1 - rho * rho));
    candidates = [base, -base];
    for (i = 0; i < candidates.length; i += 1) {
      var z = complex(1, candidates[i]);
      var gamma = gammaFromNormalizedZ(z);
      var loadAng = normalizeAngleDeg(cArgDeg(loadGamma));
      var candAng = normalizeAngleDeg(cArgDeg(gamma));
      cw = positiveClockwiseDelta(loadAng, candAng);
      if (!best || cw < best.thetaDeg) {
        best = {
          gamma: gamma,
          z: z,
          thetaDeg: cw,
        };
      }
    }
    return best;
  }

  function scLoadExample(n) {
    var load;
    var intersection;
    var rotatedPoint;
    if (!ensureCanvas()) return;
    state.exampleNotes = [];
    scClearPoints();

    if (n === 1) {
      state.z0 = 50;
      setField(['sc-z0', 'sc_z0', 'Z0', 'z0'], '50');
      setField(['sc-z-real', 'sc_z_real', 'Z_real', 'z_real'], '50');
      setField(['sc-z-imag', 'sc_z_imag', 'Z_imag', 'z_imag'], '0');
      state.exampleNotes.push('Perfectly matched — no reflection.');
      plotImpedance(50, 0, 'Matched load', 'Z = 50 + j0 Ω gives Γ = 0 at the center of the chart.');
      return;
    }

    if (n === 2) {
      state.z0 = 50;
      setField(['sc-z0', 'sc_z0', 'Z0', 'z0'], '50');
      state.exampleNotes.push('Open circuit: Γ = 1 on the right edge and VSWR = ∞.');
      addPoint({
        kind: 'open',
        label: 'Open circuit',
        extraText: 'An open termination reflects all incident power with zero phase shift.',
      });
      return;
    }

    if (n === 3) {
      state.z0 = 50;
      setField(['sc-z0', 'sc_z0', 'Z0', 'z0'], '50');
      state.exampleNotes.push('Short circuit: Γ = −1 on the left edge and VSWR = ∞.');
      addPoint({
        kind: 'short',
        label: 'Short circuit',
        extraText: 'A short reflects all incident power with a 180° reflection coefficient angle.',
      });
      return;
    }

    if (n === 4) {
      state.z0 = 50;
      setField(['sc-z0', 'sc_z0', 'Z0', 'z0'], '50');
      setField(['sc-z-real', 'sc_z_real', 'Z_real', 'z_real'], '50');
      setField(['sc-z-imag', 'sc_z_imag', 'Z_imag', 'z_imag'], '-50');
      state.exampleNotes.push('Capacitive load: z = 1 − j1 sits in the lower half of the Smith chart.');
      state.exampleNotes.push('Because the point is capacitive, an equal inductive reactance is a natural matching correction.');
      plotImpedance(50, -50, 'Capacitive load', 'Example: add an inductive element or stub to cancel the negative reactance.');
      return;
    }

    if (n === 5) {
      state.z0 = 50;
      setField(['sc-z0', 'sc_z0', 'Z0', 'z0'], '50');
      setField(['sc-z-real', 'sc_z_real', 'Z_real', 'z_real'], '25');
      setField(['sc-z-imag', 'sc_z_imag', 'Z_imag', 'z_imag'], '30');
      load = plotImpedance(25, 30, 'Load ZL', 'Step 1: plot the load ZL = 25 + j30 Ω.');
      intersection = chooseR1Intersection(load.current.gamma);
      if (intersection) {
        state.rotationOverlay = {
          startGamma: complex(load.current.gamma.re, load.current.gamma.im),
          thetaDeg: intersection.thetaDeg,
          direction: 'generator',
        };
        rotatedPoint = addPoint({
          kind: 'gamma',
          gamma: intersection.gamma,
          label: 'r = 1 intersection',
          noteShort: 'toward generator',
          extraText:
            'Step 2: move clockwise along the constant-VSWR circle until the r = 1 circle. ' +
            'Step 3: at z = 1 ' + (intersection.z.im < 0 ? '−' : '+') + ' j' + fmt(Math.abs(intersection.z.im), 3) +
            ', add a series reactance of ' + fmt(-intersection.z.im * state.z0, 2) +
            ' Ω to cancel the imaginary part.',
        });
        state.selectedId = rotatedPoint.id;
        state.exampleNotes.push('Matching network design example for ZL = 25 + j30 Ω, Z₀ = 50 Ω.');
        state.exampleNotes.push(
          'From the load, rotate toward the generator by ' + fmt(intersection.thetaDeg, 1) +
          ' electrical degrees in the Γ plane until the r = 1 circle.'
        );
        state.exampleNotes.push(
          'At that point the normalized impedance is ' + formatNormalized(intersection.z) +
          ', so the required series reactance is ' + fmt(-intersection.z.im * state.z0, 2) + ' Ω.'
        );
        redraw();
        renderResults();
      }
    }
  }

  function scApplyTL() {
    var point = lastPoint();
    var thetaDeg = readNumber(['sc-tl-deg', 'sc_tl_deg', 'TL Length', 'tl_deg', 'sc-length-deg'], NaN);
    var dirRaw = readText(['sc-tl-dir', 'sc_tl_dir', 'tl_dir', 'sc-direction'], 'generator').toLowerCase();
    var direction = dirRaw === 'load' ? 'load' : 'generator';
    var factor;
    var gammaRot;
    if (!point) {
      setMessage('Plot or click a point before applying transmission-line rotation.');
      renderResults();
      return;
    }
    if (!isFinite(thetaDeg)) {
      setMessage('Enter a TL rotation in electrical degrees.');
      renderResults();
      return;
    }
    resolvePoint(point);
    factor = cFromPolar(1, direction === 'generator' ? -thetaDeg : thetaDeg);
    gammaRot = cMul(point.current.gamma, factor);
    clearRotation();
    state.rotationOverlay = {
      startGamma: complex(point.current.gamma.re, point.current.gamma.im),
      thetaDeg: thetaDeg,
      direction: direction,
    };
    addPoint({
      kind: 'gamma',
      gamma: gammaRot,
      label: 'TL-rotated point',
      noteShort: direction === 'generator' ? 'toward generator' : 'toward load',
      extraText:
        'Rotation by ' + fmt(thetaDeg, 1) + ' electrical degrees ' +
        (direction === 'generator' ? 'clockwise toward the generator.' : 'counterclockwise toward the load.'),
    });
  }

  function scSetZ0() {
    var newZ0 = readZ0();
    if (!isFinite(newZ0) || newZ0 <= 0) {
      setMessage('Z₀ must be greater than zero.');
      renderResults();
      return;
    }
    state.z0 = newZ0;
    redraw();
    renderResults();
  }

  window.scInit = scInit;
  window.scPlotPoint = scPlotPoint;
  window.scClearPoints = scClearPoints;
  window.scLoadExample = scLoadExample;
  window.scApplyTL = scApplyTL;
  window.scSetZ0 = scSetZ0;

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', scInit);
    } else {
      scInit();
    }
  }
})();
