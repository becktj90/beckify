/* ============================================================================
   TRANSIENT CIRCUIT LAB — lumped first- and second-order homework
   ============================================================================
   Closed-form RC, RL, series RLC, and parallel RLC responses for a DC source
   step or a source-free initial-condition dump. Time-domain only: this is not
   the resonance (f0 / Q / BW) calculator and not the MNA circuit simulator.

   Identities (standard circuit theory, not a specific PDF):
     First-order RC:  vC(t) = Vf + (vC(0) − Vf) e^{−t/τ},  τ = RC
     First-order RL:  iL(t) = If + (iL(0) − If) e^{−t/τ},  τ = L/R
     Series RLC:      α = R/(2L),  ω0 = 1/√(LC),  s² + 2αs + ω0² = 0
     Parallel RLC:    α = 1/(2RC), ω0 = 1/√(LC)
     Damping: over α>ω0, critical α=ω0, under α<ω0 with ωd = √(ω0² − α²)
   ============================================================================ */
(function (global) {
  'use strict';

  const R_UNITS = { ohm: 1, k: 1e3, M: 1e6 };
  const L_UNITS = { H: 1, mH: 1e-3, uH: 1e-6 };
  const C_UNITS = { F: 1, uF: 1e-6, nF: 1e-9, pF: 1e-12 };
  const T_UNITS = { s: 1, ms: 1e-3, us: 1e-6 };
  const CRIT_REL = 1e-9;

  function convert(value, table, unit) {
    const factor = table[unit];
    if (!isFinite(value) || factor == null) return NaN;
    return value * factor;
  }

  function dampingCase(alpha, omega0) {
    if (!(alpha >= 0) || !(omega0 > 0)) return 'invalid';
    const rel = Math.abs(alpha - omega0) / omega0;
    if (rel <= CRIT_REL) return 'critical';
    if (alpha > omega0) return 'over';
    return 'under';
  }

  function firstOrder(finalValue, initial, tau, t) {
    if (!(tau > 0) || !isFinite(finalValue) || !isFinite(initial) || !isFinite(t)) return NaN;
    return finalValue + (initial - finalValue) * Math.exp(-t / tau);
  }

  function firstOrderDerivative(finalValue, initial, tau, t) {
    if (!(tau > 0)) return NaN;
    return -((initial - finalValue) / tau) * Math.exp(-t / tau);
  }

  function rise1090(tau) {
    if (!(tau > 0)) return { t10: NaN, t90: NaN, tr: NaN };
    return { t10: -tau * Math.log(0.9), t90: -tau * Math.log(0.1), tr: tau * Math.log(9) };
  }

  function settle2pct(tau) {
    if (!(tau > 0)) return NaN;
    return tau * Math.log(50);
  }

  /**
   * Natural + forced second-order: y = yf + yn,
   * yn(0) = y0 − yf, yn'(0) = dy0.
   * Characteristic equation s² + 2α s + ω0² = 0.
   */
  function secondOrderParams(alpha, omega0, y0, dy0, yf) {
    const kind = dampingCase(alpha, omega0);
    const yN0 = y0 - yf;
    if (kind === 'invalid') return { kind: kind };
    if (kind === 'over') {
      const disc = Math.sqrt(alpha * alpha - omega0 * omega0);
      const s1 = -alpha + disc;
      const s2 = -alpha - disc;
      const A2 = (dy0 - s1 * yN0) / (s2 - s1);
      const A1 = yN0 - A2;
      return { kind: kind, alpha: alpha, omega0: omega0, s1: s1, s2: s2, A1: A1, A2: A2, yf: yf, y0: y0, dy0: dy0 };
    }
    if (kind === 'critical') {
      const A1 = yN0;
      const A2 = dy0 + alpha * yN0;
      return { kind: kind, alpha: alpha, omega0: omega0, A1: A1, A2: A2, yf: yf, y0: y0, dy0: dy0 };
    }
    const omegad = Math.sqrt(Math.max(0, omega0 * omega0 - alpha * alpha));
    const B1 = yN0;
    const B2 = omegad > 0 ? (dy0 + alpha * yN0) / omegad : 0;
    return { kind: kind, alpha: alpha, omega0: omega0, omegad: omegad, A1: B1, A2: B2, yf: yf, y0: y0, dy0: dy0 };
  }

  function evalSecondOrder(p, t) {
    if (!p || p.kind === 'invalid' || !isFinite(t)) return NaN;
    if (p.kind === 'over') return p.yf + p.A1 * Math.exp(p.s1 * t) + p.A2 * Math.exp(p.s2 * t);
    if (p.kind === 'critical') return p.yf + (p.A1 + p.A2 * t) * Math.exp(-p.alpha * t);
    return p.yf + Math.exp(-p.alpha * t) * (p.A1 * Math.cos(p.omegad * t) + p.A2 * Math.sin(p.omegad * t));
  }

  function evalSecondOrderDeriv(p, t) {
    if (!p || p.kind === 'invalid' || !isFinite(t)) return NaN;
    if (p.kind === 'over') return p.A1 * p.s1 * Math.exp(p.s1 * t) + p.A2 * p.s2 * Math.exp(p.s2 * t);
    if (p.kind === 'critical') {
      const e = Math.exp(-p.alpha * t);
      return e * (p.A2 - p.alpha * (p.A1 + p.A2 * t));
    }
    const e = Math.exp(-p.alpha * t);
    const c = Math.cos(p.omegad * t);
    const s = Math.sin(p.omegad * t);
    return e * ((-p.alpha * p.A1 + p.omegad * p.A2) * c + (-p.alpha * p.A2 - p.omegad * p.A1) * s);
  }

  function closedFormText(p, symbol) {
    const y = symbol || 'y';
    if (!p || p.kind === 'invalid') return y + '(t) unavailable';
    const yf = p.yf;
    const forced = Math.abs(yf) < 1e-18 ? '' : yf.toPrecision(4) + ' + ';
    if (p.kind === 'over') {
      return y + '(t) = ' + forced + p.A1.toPrecision(4) + ' e^{(' + p.s1.toPrecision(4) + ') t} + ' +
        p.A2.toPrecision(4) + ' e^{(' + p.s2.toPrecision(4) + ') t}';
    }
    if (p.kind === 'critical') {
      return y + '(t) = ' + forced + '(' + p.A1.toPrecision(4) + ' + ' + p.A2.toPrecision(4) +
        ' t) e^{−' + p.alpha.toPrecision(4) + ' t}';
    }
    return y + '(t) = ' + forced + 'e^{−' + p.alpha.toPrecision(4) + ' t} (' +
      p.A1.toPrecision(4) + ' cos(' + p.omegad.toPrecision(4) + ' t) + ' +
      p.A2.toPrecision(4) + ' sin(' + p.omegad.toPrecision(4) + ' t))';
  }

  function solveRC(R, C, Vs, v0, sourceFree) {
    if (!(R > 0) || !(C > 0)) return { error: 'R and C must be greater than zero.' };
    const tau = R * C;
    const Vf = sourceFree ? 0 : Vs;
    if (!isFinite(Vf) || !isFinite(v0)) return { error: 'Enter a source value and vC(0).' };
    return {
      type: 'rc',
      tau: tau,
      Vf: Vf,
      v0: v0,
      yf: Vf,
      y0: v0,
      rise: rise1090(tau),
      ts: settle2pct(tau),
      vAt: function (t) { return firstOrder(Vf, v0, tau, t); },
      iAt: function (t) { return C * firstOrderDerivative(Vf, v0, tau, t); },
      form: 'vC(t) = ' + Vf + ' + (' + v0 + ' − ' + Vf + ') e^{−t/' + tau + '}'
    };
  }

  function solveRL(R, L, Vs, i0, sourceFree) {
    if (!(R > 0) || !(L > 0)) return { error: 'R and L must be greater than zero.' };
    const tau = L / R;
    const If = sourceFree ? 0 : Vs / R;
    if (!isFinite(If) || !isFinite(i0)) return { error: 'Enter a source value and iL(0).' };
    return {
      type: 'rl',
      tau: tau,
      If: If,
      i0: i0,
      yf: If,
      y0: i0,
      rise: rise1090(tau),
      ts: settle2pct(tau),
      iAt: function (t) { return firstOrder(If, i0, tau, t); },
      vAt: function (t) { return L * firstOrderDerivative(If, i0, tau, t); },
      form: 'iL(t) = ' + If + ' + (' + i0 + ' − ' + If + ') e^{−t/' + tau + '}'
    };
  }

  function solveSeriesRLC(R, L, C, Vs, v0, i0, sourceFree) {
    if (!(L > 0) || !(C > 0)) return { error: 'L and C must be greater than zero.' };
    if (!(R >= 0) || !isFinite(R)) return { error: 'R must be zero or positive.' };
    const alpha = R / (2 * L);
    const omega0 = 1 / Math.sqrt(L * C);
    const Vf = sourceFree ? 0 : Vs;
    if (!isFinite(Vf) || !isFinite(v0) || !isFinite(i0)) return { error: 'Enter Vs (or 0 for source-free), vC(0), and iL(0).' };
    const dy0 = i0 / C;
    const p = secondOrderParams(alpha, omega0, v0, dy0, Vf);
    const ts = alpha > 0 ? Math.log(50) / alpha : NaN;
    return {
      type: 'series-rlc',
      alpha: alpha,
      omega0: omega0,
      omegad: p.omegad,
      s1: p.s1,
      s2: p.s2,
      kind: p.kind,
      tau: alpha > 0 ? 1 / alpha : Infinity,
      yf: Vf,
      y0: v0,
      ts: ts,
      params: p,
      vAt: function (t) { return evalSecondOrder(p, t); },
      iAt: function (t) { return C * evalSecondOrderDeriv(p, t); },
      form: closedFormText(p, 'vC')
    };
  }

  function solveParallelRLC(R, L, C, Is, v0, i0, sourceFree) {
    if (!(L > 0) || !(C > 0)) return { error: 'L and C must be greater than zero.' };
    if (!(R > 0)) return { error: 'R must be greater than zero for a parallel RLC.' };
    const alpha = 1 / (2 * R * C);
    const omega0 = 1 / Math.sqrt(L * C);
    const isrc = sourceFree ? 0 : Is;
    if (!isFinite(isrc) || !isFinite(v0) || !isFinite(i0)) return { error: 'Enter Is (or 0 for source-free), vC(0), and iL(0).' };
    const Vf = 0;
    const dy0 = (isrc - v0 / R - i0) / C;
    const p = secondOrderParams(alpha, omega0, v0, dy0, Vf);
    const ts = alpha > 0 ? Math.log(50) / alpha : NaN;
    return {
      type: 'parallel-rlc',
      alpha: alpha,
      omega0: omega0,
      omegad: p.omegad,
      s1: p.s1,
      s2: p.s2,
      kind: p.kind,
      tau: alpha > 0 ? 1 / alpha : Infinity,
      yf: Vf,
      y0: v0,
      iLss: isrc,
      ts: ts,
      params: p,
      vAt: function (t) { return evalSecondOrder(p, t); },
      iAt: function (t) {
        /* iL'(t) = v(t)/L with v(∞)=0, so iL(t) = i0 + (1/L) ∫_0^t v(τ) dτ. */
        if (p.kind === 'over') {
          const I1 = p.A1 / (p.s1 * L);
          const I2 = p.A2 / (p.s2 * L);
          return i0 + I1 * (Math.exp(p.s1 * t) - 1) + I2 * (Math.exp(p.s2 * t) - 1);
        }
        if (p.kind === 'critical') {
          const a = p.alpha;
          const A1 = p.A1, A2 = p.A2;
          const e = Math.exp(-a * t);
          const int0 = -(A1 / a) - (A2 / (a * a));
          const intt = e * (-(A1 + A2 * t) / a - A2 / (a * a));
          return i0 + (intt - int0) / L;
        }
        const a = p.alpha, w = p.omegad, B1 = p.A1, B2 = p.A2;
        const den = a * a + w * w;
        const e = Math.exp(-a * t);
        const c = Math.cos(w * t);
        const s = Math.sin(w * t);
        const F = function (ee, cc, ss) { return ee * (-a * cc + w * ss) / den; };
        const G = function (ee, cc, ss) { return ee * (-a * ss - w * cc) / den; };
        const integ = B1 * (F(e, c, s) - F(1, 1, 0)) + B2 * (G(e, c, s) - G(1, 1, 0));
        return i0 + integ / L;
      },
      form: closedFormText(p, 'v')
    };
  }

  function crossingTimes(fn, tEnd, y0, yf) {
    const span = Math.abs(yf - y0);
    if (!(span > 0) || !(tEnd > 0)) return { t10: NaN, t90: NaN, tr: NaN, ts: NaN };
    const y10 = y0 + 0.1 * (yf - y0);
    const y90 = y0 + 0.9 * (yf - y0);
    const band = 0.02 * span;
    const n = 800;
    let t10 = NaN, t90 = NaN, ts = NaN;
    let prev = fn(0);
    for (let i = 1; i <= n; i++) {
      const t = (i / n) * tEnd;
      const y = fn(t);
      if (!isFinite(t10) && ((prev - y10) * (y - y10) <= 0)) t10 = t;
      if (!isFinite(t90) && ((prev - y90) * (y - y90) <= 0)) t90 = t;
      prev = y;
    }
    for (let i = 0; i <= n; i++) {
      const t = (i / n) * tEnd;
      if (Math.abs(fn(t) - yf) <= band) {
        let ok = true;
        for (let j = i; j <= n; j++) {
          const tj = (j / n) * tEnd;
          if (Math.abs(fn(tj) - yf) > band) { ok = false; break; }
        }
        if (ok) { ts = t; break; }
      }
    }
    return { t10: t10, t90: t90, tr: (isFinite(t10) && isFinite(t90)) ? t90 - t10 : NaN, ts: ts };
  }

  const TransientCircuits = {
    R_UNITS: R_UNITS,
    L_UNITS: L_UNITS,
    C_UNITS: C_UNITS,
    T_UNITS: T_UNITS,
    convert: convert,
    dampingCase: dampingCase,
    firstOrder: firstOrder,
    firstOrderDerivative: firstOrderDerivative,
    rise1090: rise1090,
    settle2pct: settle2pct,
    secondOrderParams: secondOrderParams,
    evalSecondOrder: evalSecondOrder,
    evalSecondOrderDeriv: evalSecondOrderDeriv,
    solveRC: solveRC,
    solveRL: solveRL,
    solveSeriesRLC: solveSeriesRLC,
    solveParallelRLC: solveParallelRLC,
    crossingTimes: crossingTimes,
    closedFormText: closedFormText
  };
  global.TransientCircuits = TransientCircuits;

  function el(id) { return document.getElementById(id); }
  function num(id) {
    const node = el(id);
    if (!node) return NaN;
    const v = parseFloat(node.value);
    return isFinite(v) ? v : NaN;
  }
  function sel(id) {
    const node = el(id);
    return node ? node.value : '';
  }
  function setVal(id, value) {
    const node = el(id);
    if (node) node.value = value;
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

  function readCircuit() {
    const type = sel('tc_type') || 'rc';
    const drive = sel('tc_drive') || 'step';
    const sourceFree = drive === 'free';
    const R = convert(num('tc_r'), R_UNITS, sel('tc_r_u') || 'ohm');
    const L = convert(num('tc_l'), L_UNITS, sel('tc_l_u') || 'mH');
    const C = convert(num('tc_c'), C_UNITS, sel('tc_c_u') || 'uF');
    const src = num('tc_src');
    const v0 = num('tc_v0');
    const i0 = num('tc_i0');
    const t0 = convert(num('tc_t0'), T_UNITS, sel('tc_t_u') || 'ms');
    const t1 = convert(num('tc_t1'), T_UNITS, sel('tc_t_u') || 'ms');
    return { type: type, sourceFree: sourceFree, R: R, L: L, C: C, src: src, v0: v0, i0: i0, t0: t0, t1: t1 };
  }

  function solveFromForm(f) {
    if (f.type === 'rc') return solveRC(f.R, f.C, f.src, f.v0, f.sourceFree);
    if (f.type === 'rl') return solveRL(f.R, f.L, f.src, f.i0, f.sourceFree);
    if (f.type === 'series') return solveSeriesRLC(f.R, f.L, f.C, f.src, f.v0, f.i0, f.sourceFree);
    return solveParallelRLC(f.R, f.L, f.C, f.src, f.v0, f.i0, f.sourceFree);
  }

  function primaryFn(sol) {
    if (!sol) return function () { return NaN; };
    if (sol.type === 'rl') return sol.iAt;
    return sol.vAt;
  }

  function defaultTEnd(sol) {
    if (!sol || sol.error) return 0.01;
    if (sol.type === 'rc' || sol.type === 'rl') return 5 * sol.tau;
    if (sol.kind === 'under' && sol.omegad > 0) return Math.max(5 / Math.max(sol.alpha, 1e-9), 3 * 2 * Math.PI / sol.omegad);
    if (sol.alpha > 0) return 6 / sol.alpha;
    return 0.01;
  }

  function updateFieldVisibility() {
    const type = sel('tc_type') || 'rc';
    const drive = sel('tc_drive') || 'step';
    const needL = type !== 'rc';
    const needC = type !== 'rl';
    const needR = true;
    const Lwrap = el('tc_l_wrap');
    const Cwrap = el('tc_c_wrap');
    const Rwrap = el('tc_r_wrap');
    if (Lwrap) Lwrap.hidden = !needL;
    if (Cwrap) Cwrap.hidden = !needC;
    if (Rwrap) Rwrap.hidden = !needR;
    const srcLab = el('tc_src_label');
    if (srcLab) {
      srcLab.textContent = type === 'parallel' ? 'Current step Is (A)' : 'Voltage step Vs (V)';
    }
    const srcWrap = el('tc_src_wrap');
    if (srcWrap) srcWrap.hidden = drive === 'free';
    const v0wrap = el('tc_v0_wrap');
    const i0wrap = el('tc_i0_wrap');
    if (v0wrap) v0wrap.hidden = type === 'rl';
    if (i0wrap) i0wrap.hidden = type === 'rc';
  }

  function drawWave(sol, t0, t1, markers) {
    const host = el('tc_wave');
    if (!host) return;
    host.textContent = '';
    if (!sol || sol.error) return;
    const fn = primaryFn(sol);
    const tStart = isFinite(t0) ? t0 : 0;
    let tEnd = isFinite(t1) && t1 > tStart ? t1 : tStart + defaultTEnd(sol);
    if (!(tEnd > tStart)) tEnd = tStart + defaultTEnd(sol);
    const N = 240;
    const samples = [];
    let yMin = Infinity, yMax = -Infinity;
    for (let i = 0; i <= N; i++) {
      const t = tStart + (i / N) * (tEnd - tStart);
      const y = fn(t);
      samples.push({ t: t, y: y });
      if (isFinite(y)) {
        if (y < yMin) yMin = y;
        if (y > yMax) yMax = y;
      }
    }
    if (!isFinite(yMin) || !isFinite(yMax)) return;
    if (yMin === yMax) { yMin -= 1; yMax += 1; }
    const pad = 0.08 * (yMax - yMin);
    yMin -= pad; yMax += pad;

    const W = 640, H = 240, padL = 52, padR = 16, padT = 18, padB = 36;
    const x = function (t) { return padL + ((t - tStart) / (tEnd - tStart)) * (W - padL - padR); };
    const y = function (v) { return padT + (1 - (v - yMin) / (yMax - yMin)) * (H - padT - padB); };
    const svg = svgEl('svg', {
      viewBox: '0 0 ' + W + ' ' + H,
      width: '100%',
      role: 'img',
      'aria-label': 'Transient waveform of the solved circuit versus time.'
    });
    svg.appendChild(svgEl('rect', { x: 1, y: 1, width: W - 2, height: H - 2, fill: '#0d1117', stroke: '#30304a' }));
    svg.appendChild(svgEl('line', { x1: padL, y1: padT, x2: padL, y2: H - padB, stroke: '#334155' }));
    svg.appendChild(svgEl('line', { x1: padL, y1: H - padB, x2: W - padR, y2: H - padB, stroke: '#334155' }));
    if (yMin < 0 && yMax > 0) {
      svg.appendChild(svgEl('line', {
        x1: padL, y1: y(0), x2: W - padR, y2: y(0),
        stroke: '#334155', 'stroke-dasharray': '3 4'
      }));
    }

    let d = '';
    samples.forEach(function (s, i) {
      if (!isFinite(s.y)) return;
      d += (i ? ' L ' : 'M ') + x(s.t).toFixed(1) + ' ' + y(s.y).toFixed(1);
    });
    svg.appendChild(svgEl('path', { d: d, fill: 'none', stroke: '#6ee7b7', 'stroke-width': '2' }));

    function mark(t, color, label) {
      if (!isFinite(t) || t < tStart || t > tEnd) return;
      svg.appendChild(svgEl('line', {
        x1: x(t), y1: padT, x2: x(t), y2: H - padB,
        stroke: color, 'stroke-dasharray': '3 3', 'stroke-width': '1'
      }));
      const tx = svgEl('text', {
        x: x(t) + 3, y: padT + 11, fill: color, 'font-size': '9',
        'font-family': 'ui-monospace,monospace'
      });
      tx.textContent = label;
      svg.appendChild(tx);
    }
    if (markers) {
      mark(markers.t10, '#60a5fa', '10%');
      mark(markers.t90, '#60a5fa', '90%');
      mark(markers.ts, '#f5c451', '2%');
    }

    const xlab = svgEl('text', {
      x: W / 2, y: H - 10, fill: '#9497b8', 'font-size': '10', 'text-anchor': 'middle',
      'font-family': 'ui-sans-serif,sans-serif'
    });
    xlab.textContent = 't  (' + fmtEng(tEnd - tStart, 3, 's') + ' span)   green = ' +
      (sol.type === 'rl' ? 'iL(t)' : (sol.type === 'parallel-rlc' ? 'v(t)' : 'vC(t)'));
    svg.appendChild(xlab);
    const y0lab = svgEl('text', {
      x: 6, y: y(yMax) + 4, fill: '#9497b8', 'font-size': '9',
      'font-family': 'ui-monospace,monospace'
    });
    y0lab.textContent = fmtEng(yMax, 2, sol.type === 'rl' ? 'A' : 'V');
    svg.appendChild(y0lab);
    const y1lab = svgEl('text', {
      x: 6, y: y(yMin) + 4, fill: '#9497b8', 'font-size': '9',
      'font-family': 'ui-monospace,monospace'
    });
    y1lab.textContent = fmtEng(yMin, 2, sol.type === 'rl' ? 'A' : 'V');
    svg.appendChild(y1lab);
    host.appendChild(svg);
  }

  function calcTransientCircuits() {
    updateFieldVisibility();
    const f = readCircuit();
    const sol = solveFromForm(f);
    if (sol.error) {
      const wave = el('tc_wave');
      if (wave) wave.textContent = '';
      if (typeof showError === 'function') showError('tc_result', sol.error);
      return;
    }

    const t0 = isFinite(f.t0) ? f.t0 : 0;
    const t1 = isFinite(f.t1) && f.t1 > t0 ? f.t1 : t0 + defaultTEnd(sol);
    const fn = primaryFn(sol);
    let markers;
    if (sol.type === 'rc' || sol.type === 'rl') {
      const r = sol.rise;
      markers = { t10: r.t10, t90: r.t90, tr: r.tr, ts: sol.ts };
    } else {
      markers = crossingTimes(fn, t1, sol.y0, sol.yf);
      if (!isFinite(markers.ts) && isFinite(sol.ts)) markers.ts = sol.ts;
    }

    const rows = [];
    if (sol.type === 'rc') {
      rows.push(['Circuit', 'First-order RC']);
      rows.push(['Time constant τ = RC', fmtEng(sol.tau, 3, 's')]);
      rows.push(['vC(∞)', fmtEng(sol.Vf, 3, 'V')]);
      rows.push(['vC(τ)', fmtEng(sol.vAt(sol.tau), 3, 'V')]);
    } else if (sol.type === 'rl') {
      rows.push(['Circuit', 'First-order RL']);
      rows.push(['Time constant τ = L/R', fmtEng(sol.tau, 3, 's')]);
      rows.push(['iL(∞)', fmtEng(sol.If, 3, 'A')]);
      rows.push(['iL(τ)', fmtEng(sol.iAt(sol.tau), 3, 'A')]);
    } else {
      rows.push(['Circuit', sol.type === 'series-rlc' ? 'Series RLC' : 'Parallel RLC']);
      rows.push(['Damping', sol.kind === 'over' ? 'overdamped' : sol.kind === 'critical' ? 'critically damped' : 'underdamped']);
      rows.push(['α', fmtEng(sol.alpha, 3, '1/s')]);
      rows.push(['ω0', fmtEng(sol.omega0, 3, 'rad/s')]);
      if (sol.kind === 'under') rows.push(['ωd = √(ω0² − α²)', fmtEng(sol.omegad, 3, 'rad/s')]);
      if (sol.kind === 'over') {
        rows.push(['s1', fmtEng(sol.s1, 4, '1/s')]);
        rows.push(['s2', fmtEng(sol.s2, 4, '1/s')]);
      }
      rows.push(['Envelope time 1/α', fmtEng(sol.tau, 3, 's')]);
    }
    rows.push(['Closed form', sol.form]);
    if (isFinite(markers.tr)) rows.push(['10–90% rise', fmtEng(markers.tr, 3, 's')]);
    if (isFinite(markers.t10)) rows.push(['10% time', fmtEng(markers.t10, 3, 's')]);
    if (isFinite(markers.t90)) rows.push(['90% time', fmtEng(markers.t90, 3, 's')]);
    if (isFinite(markers.ts)) rows.push(['~2% settling', fmtEng(markers.ts, 3, 's')]);
    rows.push(['Value at t start', fmtEng(fn(t0), 3, sol.type === 'rl' ? 'A' : 'V')]);
    rows.push(['Value at t end', fmtEng(fn(t1), 3, sol.type === 'rl' ? 'A' : 'V')]);

    const notes = [
      'Lumped-element circuit theory. First-order: one energy-storage element. Second-order: the characteristic equation s² + 2αs + ω0² = 0. This is not a frequency-domain resonance calculator and not an MNA netlist solver.',
      '10–90% markers are exact for a first-order step (tr = τ ln 9). For RLC they are read off the waveform. The 2% settling line is τ ln 50 (first-order) or ln(50)/α (second-order envelope).',
      'Source-step assumes a DC source applied at t = 0 with the entered initial capacitor voltage and inductor current. Source-free sets the forced response to zero and lets the stored energy ring out.'
    ];
    showNotes('tc_result', rows, notes);
    drawWave(sol, t0, t1, markers);
  }

  function loadTransientExample() {
    setVal('tc_type', 'series');
    setVal('tc_drive', 'step');
    setVal('tc_r', '10');
    setVal('tc_r_u', 'ohm');
    setVal('tc_l', '10');
    setVal('tc_l_u', 'mH');
    setVal('tc_c', '1');
    setVal('tc_c_u', 'uF');
    setVal('tc_src', '10');
    setVal('tc_v0', '0');
    setVal('tc_i0', '0');
    setVal('tc_t0', '0');
    setVal('tc_t1', '2');
    setVal('tc_t_u', 'ms');
    updateFieldVisibility();
    calcTransientCircuits();
  }

  function wireLive() {
    const section = el('sec-transient-circuits');
    if (!section) return;
    const recalc = function () { calcTransientCircuits(); };
    section.querySelectorAll('input, select').forEach(function (field) {
      field.addEventListener('input', recalc);
      field.addEventListener('change', recalc);
    });
    updateFieldVisibility();
    calcTransientCircuits();
    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-transient-circuits', 'transient-circuits', calcTransientCircuits);
    }
    if (typeof registerReport === 'function') {
      registerReport('tc_result', {
        title: 'Transient Circuit Lab',
        formula: function () {
          return 'RC: τ=RC   |   RL: τ=L/R   |   series RLC: α=R/(2L), ω0=1/√(LC)   |   parallel RLC: α=1/(2RC)';
        },
        codeRefs: function () {
          return [
            'First-order exponential: y(t) = yf + (y(0)−yf) e^{−t/τ}',
            'Second-order characteristic equation s² + 2αs + ω0² = 0',
            'Over / critical / under damping by α vs ω0; ωd = √(ω0² − α²)',
            'Lumped circuit theory identities (not a distributed-line or MNA tool)'
          ];
        }
      });
    }
  }

  global.calcTransientCircuits = calcTransientCircuits;
  global.loadTransientExample = loadTransientExample;

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', wireLive);
    else wireLive();
  }
})(typeof window !== 'undefined' ? window : globalThis);
