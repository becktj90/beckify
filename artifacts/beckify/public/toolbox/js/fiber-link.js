/* ============================================================================
   FIBER LINK / NA — numerical aperture, acceptance angle, simple link budget
   ============================================================================
   Homework fiber geometry and a first-order optical power budget. Not a
   photometrics lumens tool and not a TDR copper-fault locator.

   Citations (identities, not copied prose or figures):
     Joseph C. Palais, Fiber Optic Communications, 4th ed., Prentice Hall,
     1998 (reference for NA / link-budget topics — not a copy source).
     NA = √(n1² − n2²) = n1 √(2Δ) with Δ = (n1 − n2)/n1 in the weakly-guiding
     limit. Acceptance angle θa = arcsin(NA) in air. Attenuation in dB is α L.
   ============================================================================ */
(function (global) {
  'use strict';

  const LEN = { m: 1, km: 1e3, ft: 0.3048 };

  function convert(value, table, unit) {
    const factor = table[unit];
    if (!isFinite(value) || factor == null) return NaN;
    return value * factor;
  }

  function fmtEng(n, digits, unit) {
    if (!isFinite(n)) return '—';
    const d = digits == null ? 3 : digits;
    const abs = Math.abs(n);
    const u = unit || '';
    if (abs === 0) return u ? '0 ' + u : '0';
    const prefixes = [
      [1e-12, 'p'], [1e-9, 'n'], [1e-6, 'µ'], [1e-3, 'm'],
      [1, ''], [1e3, 'k'], [1e6, 'M'], [1e9, 'G']
    ];
    let scale = 1;
    let prefix = '';
    for (let i = prefixes.length - 1; i >= 0; i--) {
      if (abs >= prefixes[i][0]) {
        scale = prefixes[i][0];
        prefix = prefixes[i][1];
        break;
      }
    }
    const scaled = n / scale;
    const text = Math.abs(scaled) >= 100 ? scaled.toFixed(1) : Math.abs(scaled) >= 10 ? scaled.toFixed(2) : scaled.toFixed(d);
    const body = parseFloat(text).toString();
    if (!prefix) return u ? body + ' ' + u : body;
    return u ? body + ' ' + prefix + u : body + ' ' + prefix;
  }

  function fmtFixed(n, digits, unit) {
    if (!isFinite(n)) return '—';
    const body = Number(n).toFixed(digits == null ? 3 : digits);
    return unit ? body + ' ' + unit : body;
  }

  /** Exact NA from core and cladding indices. */
  function numericalAperture(n1, n2) {
    if (!(n1 > 0) || !(n2 > 0)) return NaN;
    if (!(n1 > n2)) return NaN;
    return Math.sqrt(n1 * n1 - n2 * n2);
  }

  /** Relative index difference Δ = (n1 − n2) / n1. */
  function deltaRel(n1, n2) {
    if (!(n1 > 0) || !(n2 > 0) || !(n1 > n2)) return NaN;
    return (n1 - n2) / n1;
  }

  /** Weakly-guiding NA ≈ n1 √(2Δ). */
  function naFromDelta(n1, delta) {
    if (!(n1 > 0) || !(delta > 0)) return NaN;
    return n1 * Math.sqrt(2 * delta);
  }

  function acceptanceAngleRad(na) {
    if (!(na >= 0)) return NaN;
    if (na > 1) return NaN;
    return Math.asin(na);
  }

  function criticalAngleRad(n1, n2) {
    if (!(n1 > 0) || !(n2 > 0) || n2 / n1 > 1) return NaN;
    return Math.asin(n2 / n1);
  }

  /**
   * Link budget in dB: Pout = Pin − α L − Nconn Lconn − Nsplice Lsplice.
   * Length is converted to km to match α in dB/km.
   */
  function linkBudget(input) {
    const pin = input.pinDbm;
    const alpha = input.alphaDbPerKm;
    const lengthM = input.lengthM;
    const nConn = input.nConnectors || 0;
    const lConn = input.lossPerConnectorDb || 0;
    const nSplice = input.nSplices || 0;
    const lSplice = input.lossPerSpliceDb || 0;
    const sens = input.sensitivityDbm;
    if (!isFinite(pin) || !isFinite(alpha) || !(lengthM >= 0)) {
      return { error: 'Source power, attenuation, and length must be finite. Length cannot be negative.' };
    }
    const lengthKm = lengthM / 1000;
    const fiberDb = alpha * lengthKm;
    const connDb = Math.max(nConn, 0) * lConn;
    const spliceDb = Math.max(nSplice, 0) * lSplice;
    const totalDb = fiberDb + connDb + spliceDb;
    const pout = pin - totalDb;
    const margin = isFinite(sens) ? pout - sens : NaN;
    return {
      pinDbm: pin,
      lengthKm: lengthKm,
      fiberDb: fiberDb,
      connDb: connDb,
      spliceDb: spliceDb,
      totalDb: totalDb,
      poutDbm: pout,
      sensitivityDbm: sens,
      marginDb: margin,
      closes: isFinite(margin) ? margin >= 0 : null
    };
  }

  function solveFiber(input) {
    const n1 = input.n1;
    const n2 = input.n2;
    const na = numericalAperture(n1, n2);
    if (!isFinite(na)) {
      return { error: 'Need n1 > n2 > 0. Air is ~1.0003, silica cores sit near 1.45–1.48.' };
    }
    const dlt = deltaRel(n1, n2);
    const naWeak = naFromDelta(n1, dlt);
    const thetaA = acceptanceAngleRad(na);
    const thetaC = criticalAngleRad(n1, n2);
    const budget = linkBudget(input);
    if (budget.error) return budget;
    return {
      n1: n1, n2: n2,
      NA: na,
      delta: dlt,
      naWeak: naWeak,
      thetaA: thetaA,
      thetaC: thetaC,
      budget: budget
    };
  }

  const FiberLink = {
    numericalAperture: numericalAperture,
    deltaRel: deltaRel,
    naFromDelta: naFromDelta,
    acceptanceAngleRad: acceptanceAngleRad,
    criticalAngleRad: criticalAngleRad,
    linkBudget: linkBudget,
    solveFiber: solveFiber,
    fmtEng: fmtEng
  };
  global.FiberLink = FiberLink;

  function el(id) { return document.getElementById(id); }
  function num(id) {
    const node = el(id);
    if (!node) return NaN;
    const v = parseFloat(node.value);
    return isFinite(v) ? v : NaN;
  }
  function sel(id) { const node = el(id); return node ? node.value : ''; }
  function setVal(id, value) { const node = el(id); if (node) node.value = value; }

  function showNotes(id, rows, notes) {
    if (typeof showResult !== 'function') return;
    showResult(id, rows);
    const host = el(id);
    if (!host || !notes || !notes.length) return;
    notes.forEach(function (text) {
      const note = document.createElement('div');
      note.className = 'note';
      note.style.marginTop = '10px';
      note.textContent = text;
      host.appendChild(note);
    });
  }

  function svgEl(tag, attrs) {
    const node = document.createElementNS('http://www.w3.org/2000/svg', tag);
    Object.keys(attrs || {}).forEach(function (key) { node.setAttribute(key, attrs[key]); });
    return node;
  }

  function drawFiber(result) {
    const host = el('fl_diagram');
    if (!host) return;
    host.innerHTML = '';
    const svg = svgEl('svg', {
      viewBox: '0 0 520 220',
      role: 'img',
      'aria-label': 'Original step-index fiber with core, cladding, and acceptance cone.'
    });
    svg.appendChild(svgEl('rect', { x: 0, y: 0, width: 520, height: 220, fill: '#0d1117' }));
    svg.appendChild(svgEl('rect', { x: 160, y: 40, width: 330, height: 140, rx: 70, fill: '#161b22', stroke: '#30363d', 'stroke-width': '2' }));
    svg.appendChild(svgEl('rect', { x: 200, y: 78, width: 290, height: 64, rx: 32, fill: '#1f3b5a', stroke: '#58a6ff', 'stroke-width': '2' }));
    const clad = svgEl('text', { x: 250, y: 58, fill: '#8b949e', 'font-size': '11' });
    clad.textContent = 'cladding n2'; svg.appendChild(clad);
    const core = svgEl('text', { x: 250, y: 114, fill: '#79c0ff', 'font-size': '11' });
    core.textContent = 'core n1'; svg.appendChild(core);
    const na = isFinite(result && result.NA) ? result.NA : 0.2;
    const ang = isFinite(result && result.thetaA) ? result.thetaA : Math.asin(Math.min(na, 0.99));
    const cx = 200, cy = 110;
    const reach = 150;
    const dy = reach * Math.tan(Math.min(ang, 0.9));
    svg.appendChild(svgEl('line', { x1: cx - reach, y1: cy - dy, x2: cx, y2: cy, stroke: '#f0883e', 'stroke-width': '1.6', 'stroke-dasharray': '4 3' }));
    svg.appendChild(svgEl('line', { x1: cx - reach, y1: cy + dy, x2: cx, y2: cy, stroke: '#f0883e', 'stroke-width': '1.6', 'stroke-dasharray': '4 3' }));
    svg.appendChild(svgEl('line', { x1: cx - reach, y1: cy, x2: 490, y2: cy, stroke: '#3fb950', 'stroke-width': '1.4' }));
    const air = svgEl('text', { x: 40, y: 36, fill: '#8b949e', 'font-size': '11' });
    air.textContent = 'air'; svg.appendChild(air);
    const naL = svgEl('text', { x: 40, y: cy - dy - 8, fill: '#f0883e', 'font-size': '11' });
    naL.textContent = 'θa  NA cone'; svg.appendChild(naL);
    const guided = svgEl('text', { x: 330, y: 200, fill: '#3fb950', 'font-size': '11' });
    guided.textContent = 'guided ray'; svg.appendChild(guided);
    host.appendChild(svg);
  }

  function calcFiberLink() {
    if (!el('sec-fiber-link')) return;
    const lengthM = convert(num('fl_len'), LEN, sel('fl_len_u') || 'km');
    const result = solveFiber({
      n1: num('fl_n1'),
      n2: num('fl_n2'),
      pinDbm: num('fl_pin'),
      alphaDbPerKm: num('fl_alpha'),
      lengthM: lengthM,
      nConnectors: num('fl_nconn'),
      lossPerConnectorDb: num('fl_lconn'),
      nSplices: num('fl_nspl'),
      lossPerSpliceDb: num('fl_lspl'),
      sensitivityDbm: num('fl_sens')
    });
    if (result.error) {
      if (typeof showResult === 'function') showResult('fl_result', [['Error', result.error]]);
      drawFiber(null);
      return;
    }
    const b = result.budget;
    const rows = [
      ['NA = √(n1² − n2²)', fmtFixed(result.NA, 4, '')],
      ['Δ = (n1 − n2)/n1', fmtFixed(result.delta, 5, '')],
      ['n1 √(2Δ) (weakly guiding)', fmtFixed(result.naWeak, 4, '')],
      ['Acceptance angle θa = arcsin(NA)', isFinite(result.thetaA) ? fmtFixed(result.thetaA * 180 / Math.PI, 2, '°') : 'NA > 1 (not a free-space cone)'],
      ['Core-cladding critical angle', fmtFixed(result.thetaC * 180 / Math.PI, 2, '°')],
      ['Fiber length', fmtEng(b.lengthKm, 3, 'km')],
      ['Fiber loss αL', fmtFixed(b.fiberDb, 2, 'dB')],
      ['Connector loss', fmtFixed(b.connDb, 2, 'dB')],
      ['Splice loss', fmtFixed(b.spliceDb, 2, 'dB')],
      ['Total path loss', fmtFixed(b.totalDb, 2, 'dB')],
      ['Pout = Pin − losses', fmtFixed(b.poutDbm, 2, 'dBm')],
      ['Receiver sensitivity', fmtFixed(b.sensitivityDbm, 2, 'dBm')],
      ['Margin', fmtFixed(b.marginDb, 2, 'dB') + (b.closes ? '  (closes)' : '  (short)')]
    ];
    const notes = [
      'NA = √(n1² − n2²). In the weakly-guiding limit Δ ≪ 1 and NA ≈ n1 √(2Δ). θa is the half-angle in air; it is undefined as a real arcsin when NA > 1.',
      'The budget is a first-order dB sum: fiber αL plus connector and splice lumps. Dispersion, modal noise, and BER are out of scope. This is not photometrics and not a TDR.',
      'Joseph C. Palais, Fiber Optic Communications, 4th ed., Prentice Hall, 1998 (NA / link-budget topics — identities only, not a copy source).'
    ];
    showNotes('fl_result', rows, notes);
    drawFiber(result);
  }

  function loadFiberExample() {
    setVal('fl_n1', '1.48');
    setVal('fl_n2', '1.46');
    setVal('fl_len', '2');
    setVal('fl_len_u', 'km');
    setVal('fl_alpha', '0.3');
    setVal('fl_pin', '0');
    setVal('fl_nconn', '2');
    setVal('fl_lconn', '0.3');
    setVal('fl_nspl', '1');
    setVal('fl_lspl', '0.1');
    setVal('fl_sens', '-20');
    calcFiberLink();
  }

  function wireLive() {
    const section = el('sec-fiber-link');
    if (!section) return;
    const recalc = function () { calcFiberLink(); };
    section.querySelectorAll('input, select').forEach(function (field) {
      field.addEventListener('input', recalc);
      field.addEventListener('change', recalc);
    });
    calcFiberLink();
    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-fiber-link', 'fiber-link', calcFiberLink);
    }
    if (typeof registerReport === 'function') {
      registerReport('fl_result', {
        title: 'Fiber Link / NA',
        formula: function () {
          return 'NA = √(n1² − n2²) ≈ n1 √(2Δ)   |   θa = arcsin(NA)   |   Pout = Pin − αL − connectors − splices';
        },
        codeRefs: function () {
          return [
            'Joseph C. Palais, Fiber Optic Communications, 4th ed., Prentice Hall, 1998 (NA / link-budget topics)',
            'NA = √(n1² − n2²) = n1 √(2Δ) with Δ = (n1 − n2)/n1 in the weakly-guiding limit',
            'Acceptance angle θa = arcsin(NA) in air; path loss in dB is α L plus connector/splice lumps'
          ];
        }
      });
    }
  }

  global.calcFiberLink = calcFiberLink;
  global.loadFiberExample = loadFiberExample;

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', wireLive);
    else wireLive();
  }
})(typeof window !== 'undefined' ? window : globalThis);
