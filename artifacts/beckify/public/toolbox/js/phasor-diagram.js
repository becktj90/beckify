/* ============================================================================
   PHASOR DIAGRAM WORKBENCH — series/parallel R-L-C plus a source
   ============================================================================
   Steady-state AC phasors: I, VR, VL, VC as RMS and polar, live voltage or
   current triangle, θ / PF / S-P-Q, lead vs lag. A balanced Δ-Y panel sits
   beside it (ZΔ = 3 Zy). Not a three-phase kVA sizer.

   Citations: standard EE phasor analysis (time-harmonic steady state,
   jω impedances, S = V I*). Optional secondary: Magdy F. Iskander,
   Electromagnetic Fields and Waves, 2nd ed., Waveland Press, 2013
   (time-harmonic / phasor-fields chapter) — identities only, not a copy source.
   ============================================================================ */
(function (global) {
  'use strict';

  const R_UNITS = { ohm: 1, k: 1e3, M: 1e6 };
  const L_UNITS = { H: 1, mH: 1e-3, uH: 1e-6 };
  const C_UNITS = { F: 1, uF: 1e-6, nF: 1e-9, pF: 1e-12 };
  const F_UNITS = { Hz: 1, kHz: 1e3, MHz: 1e6 };

  function c(re, im) { return { re: re, im: im || 0 }; }
  function cadd(a, b) { return c(a.re + b.re, a.im + b.im); }
  function csub(a, b) { return c(a.re - b.re, a.im - b.im); }
  function cmul(a, b) { return c(a.re * b.re - a.im * b.im, a.re * b.im + a.im * b.re); }
  function cdiv(a, b) {
    const d = b.re * b.re + b.im * b.im;
    if (!(d > 0)) return c(NaN, NaN);
    return c((a.re * b.re + a.im * b.im) / d, (a.im * b.re - a.re * b.im) / d);
  }
  function cmag(a) { return Math.hypot(a.re, a.im); }
  function carg(a) { return Math.atan2(a.im, a.re); }
  function cconj(a) { return c(a.re, -a.im); }
  function cscale(a, k) { return c(a.re * k, a.im * k); }
  function fromPolar(mag, rad) { return c(mag * Math.cos(rad), mag * Math.sin(rad)); }

  function convert(value, table, unit) {
    const factor = table[unit];
    if (!isFinite(value) || factor == null) return NaN;
    return value * factor;
  }

  function jwL(omega, L) { return c(0, omega * L); }
  function invJwC(omega, C) {
    if (!(omega > 0) || !(C > 0)) return c(NaN, NaN);
    return c(0, -1 / (omega * C));
  }

  function polarText(z, unit) {
    const mag = cmag(z);
    const deg = carg(z) * 180 / Math.PI;
    const u = unit || '';
    return fmtEng(mag, 3, u) + ' ∠ ' + (isFinite(deg) ? deg.toFixed(2) : '—') + '°';
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

  function rectText(z, unit) {
    const sign = z.im < 0 ? ' − j' : ' + j';
    return fmtEng(z.re, 3, '') + sign + fmtEng(Math.abs(z.im), 3, '') + (unit ? ' ' + unit : '');
  }

  /** Balanced Δ-Y: ZΔ = 3 Zy. Works for complex Z. */
  function deltaFromWye(zy) { return cscale(zy, 3); }
  function wyeFromDelta(zd) { return cscale(zd, 1 / 3); }

  function extraZ(omega, extra) {
    if (!extra || !extra.on) return c(0, 0);
    if (extra.kind === 'R') return c(extra.R > 0 ? extra.R : 0, 0);
    if (extra.kind === 'L') return extra.L > 0 ? jwL(omega, extra.L) : c(0, 0);
    if (extra.kind === 'C') return extra.C > 0 ? invJwC(omega, extra.C) : c(0, 0);
    return c(0, 0);
  }

  function solvePhasors(input) {
    const f = input.freqHz;
    if (!(f > 0)) return { error: 'Frequency must be greater than zero.' };
    const omega = 2 * Math.PI * f;
    const R = input.R;
    const L = input.L;
    const C = input.C;
    if (!(R >= 0) || !isFinite(R)) return { error: 'R must be zero or positive.' };
    if (!(L >= 0) || !isFinite(L)) return { error: 'L must be zero or positive.' };
    if (!(C >= 0) || !isFinite(C)) return { error: 'C must be zero or positive.' };

    let vsPeak = input.vs;
    if (!isFinite(vsPeak) || !(vsPeak >= 0)) return { error: 'Source voltage must be zero or positive.' };
    if (input.vsMode === 'rms') vsPeak = vsPeak * Math.SQRT2;
    const vsRms = vsPeak / Math.SQRT2;
    const Vs = c(vsRms, 0);

    const ZR = c(R, 0);
    const ZL = L > 0 ? jwL(omega, L) : c(0, 0);
    const ZC = C > 0 ? invJwC(omega, C) : c(Infinity, Infinity);
    const XC = C > 0 ? -1 / (omega * C) : -Infinity;
    const XL = omega * L;
    const Zextra = extraZ(omega, input.extra);
    const topology = input.topology === 'parallel' ? 'parallel' : 'series';

    let I, VR, VL, VC, IR, IL, IC, Zeq, Iextra;

    if (topology === 'series') {
      if (!(C > 0) && input.requireC) return { error: 'Series C must be greater than zero, or set C unused by leaving it 0 and using R-L only.' };
      let Z = ZR;
      Z = cadd(Z, ZL);
      if (C > 0) Z = cadd(Z, invJwC(omega, C));
      Z = cadd(Z, Zextra);
      if (!(cmag(Z) > 0) || !isFinite(cmag(Z))) return { error: 'Series impedance is zero or undefined. Add R, L, or C.' };
      Zeq = Z;
      I = cdiv(Vs, Z);
      VR = cmul(I, ZR);
      VL = cmul(I, ZL);
      VC = C > 0 ? cmul(I, invJwC(omega, C)) : c(0, 0);
      Iextra = I;
      IR = I; IL = I; IC = I;
    } else {
      if (!(R > 0) && !(L > 0) && !(C > 0) && !(input.extra && input.extra.on)) {
        return { error: 'Parallel network needs at least one branch.' };
      }
      let Y = c(0, 0);
      if (R > 0) Y = cadd(Y, c(1 / R, 0));
      if (L > 0) Y = cadd(Y, cdiv(c(1, 0), ZL));
      if (C > 0) Y = cadd(Y, c(0, omega * C));
      if (input.extra && input.extra.on && cmag(Zextra) > 0) Y = cadd(Y, cdiv(c(1, 0), Zextra));
      if (!(cmag(Y) > 0) || !isFinite(cmag(Y))) return { error: 'Parallel admittance is undefined.' };
      Zeq = cdiv(c(1, 0), Y);
      I = cmul(Vs, Y);
      VR = Vs;
      VL = Vs;
      VC = Vs;
      IR = R > 0 ? cdiv(Vs, ZR) : c(0, 0);
      IL = L > 0 ? cdiv(Vs, ZL) : c(0, 0);
      IC = C > 0 ? cmul(Vs, c(0, omega * C)) : c(0, 0);
      Iextra = (input.extra && input.extra.on && cmag(Zextra) > 0) ? cdiv(Vs, Zextra) : c(0, 0);
    }

    const S = cmul(Vs, cconj(I)); /* VA, RMS convention */
    const P = S.re;
    const Q = S.im;
    const theta = carg(I) - carg(Vs);
    const pf = Math.cos(theta);
    let leadLag = 'unity / resistive';
    if (Q > 1e-9) leadLag = 'lagging (inductive — current lags voltage)';
    else if (Q < -1e-9) leadLag = 'leading (capacitive — current leads voltage)';

    return {
      topology: topology,
      omega: omega,
      freqHz: f,
      vsPeak: vsPeak,
      vsRms: vsRms,
      Vs: Vs,
      Zeq: Zeq,
      XL: XL,
      XC: XC,
      I: I,
      VR: VR,
      VL: VL,
      VC: VC,
      IR: IR,
      IL: IL,
      IC: IC,
      Iextra: Iextra,
      S: S,
      P: P,
      Q: Q,
      theta: theta,
      pf: pf,
      leadLag: leadLag,
      extraOn: !!(input.extra && input.extra.on)
    };
  }

  const PhasorDiagram = {
    R_UNITS: R_UNITS,
    L_UNITS: L_UNITS,
    C_UNITS: C_UNITS,
    F_UNITS: F_UNITS,
    c: c, cadd: cadd, csub: csub, cmul: cmul, cdiv: cdiv,
    cmag: cmag, carg: carg, cconj: cconj, cscale: cscale, fromPolar: fromPolar,
    convert: convert,
    jwL: jwL,
    invJwC: invJwC,
    deltaFromWye: deltaFromWye,
    wyeFromDelta: wyeFromDelta,
    solvePhasors: solvePhasors,
    polarText: polarText,
    fmtEng: fmtEng
  };
  global.PhasorDiagram = PhasorDiagram;

  function el(id) { return document.getElementById(id); }
  function num(id) {
    const node = el(id);
    if (!node) return NaN;
    const v = parseFloat(node.value);
    return isFinite(v) ? v : NaN;
  }
  function sel(id) { const node = el(id); return node ? node.value : ''; }
  function checked(id) { const node = el(id); return !!(node && node.checked); }
  function setVal(id, value) { const node = el(id); if (node) node.value = value; }
  function setChecked(id, on) { const node = el(id); if (node) node.checked = !!on; }

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

  function readInputs() {
    return {
      topology: sel('pd_top'),
      freqHz: convert(num('pd_f'), F_UNITS, sel('pd_f_u') || 'Hz'),
      R: convert(num('pd_r'), R_UNITS, sel('pd_r_u') || 'ohm'),
      L: convert(num('pd_l'), L_UNITS, sel('pd_l_u') || 'mH'),
      C: convert(num('pd_c'), C_UNITS, sel('pd_c_u') || 'uF'),
      vs: num('pd_vs'),
      vsMode: sel('pd_vs_mode') || 'rms',
      extra: {
        on: checked('pd_extra_on'),
        kind: sel('pd_extra_kind') || 'R',
        R: convert(num('pd_extra_r'), R_UNITS, sel('pd_extra_r_u') || 'ohm'),
        L: convert(num('pd_extra_l'), L_UNITS, sel('pd_extra_l_u') || 'mH'),
        C: convert(num('pd_extra_c'), C_UNITS, sel('pd_extra_c_u') || 'uF')
      }
    };
  }

  function updateExtraFields() {
    const on = checked('pd_extra_on');
    const box = el('pd_extra_fields');
    if (box) box.hidden = !on;
    const kind = sel('pd_extra_kind') || 'R';
    const r = el('pd_extra_r_wrap');
    const l = el('pd_extra_l_wrap');
    const cwrap = el('pd_extra_c_wrap');
    if (r) r.hidden = !on || kind !== 'R';
    if (l) l.hidden = !on || kind !== 'L';
    if (cwrap) cwrap.hidden = !on || kind !== 'C';
  }

  function arrow(svg, x0, y0, x1, y1, color, label, lx, ly) {
    svg.appendChild(svgEl('line', {
      x1: x0, y1: y0, x2: x1, y2: y1,
      stroke: color, 'stroke-width': '2.2'
    }));
    const ang = Math.atan2(y1 - y0, x1 - x0);
    const ah = 8;
    const p1x = x1 - ah * Math.cos(ang - 0.4);
    const p1y = y1 - ah * Math.sin(ang - 0.4);
    const p2x = x1 - ah * Math.cos(ang + 0.4);
    const p2y = y1 - ah * Math.sin(ang + 0.4);
    svg.appendChild(svgEl('polygon', {
      points: x1 + ',' + y1 + ' ' + p1x + ',' + p1y + ' ' + p2x + ',' + p2y,
      fill: color
    }));
    if (label) {
      const t = svgEl('text', {
        x: lx, y: ly, fill: color, 'font-size': '11',
        'font-family': 'ui-monospace,monospace'
      });
      t.textContent = label;
      svg.appendChild(t);
    }
  }

  function drawPhasors(result) {
    const host = el('pd_diagram');
    if (!host) return;
    host.textContent = '';
    if (!result || result.error) return;
    const W = 360, H = 360, cx = 180, cy = 180;
    const svg = svgEl('svg', {
      viewBox: '0 0 ' + W + ' ' + H,
      width: '100%',
      role: 'img',
      'aria-label': result.topology === 'series'
        ? 'Voltage phasor triangle for the series R-L-C circuit.'
        : 'Current phasor triangle for the parallel R-L-C circuit.'
    });
    svg.appendChild(svgEl('rect', { x: 1, y: 1, width: W - 2, height: H - 2, fill: '#0d1117', stroke: '#30304a' }));
    svg.appendChild(svgEl('line', { x1: 24, y1: cy, x2: W - 24, y2: cy, stroke: '#334155' }));
    svg.appendChild(svgEl('line', { x1: cx, y1: 24, x2: cx, y2: H - 24, stroke: '#334155' }));
    const xLab = svgEl('text', { x: W - 28, y: cy - 6, fill: '#9497b8', 'font-size': '10', 'text-anchor': 'end', 'font-family': 'ui-monospace,monospace' });
    xLab.textContent = 'Re';
    svg.appendChild(xLab);
    const yLab = svgEl('text', { x: cx + 6, y: 22, fill: '#9497b8', 'font-size': '10', 'font-family': 'ui-monospace,monospace' });
    yLab.textContent = 'Im';
    svg.appendChild(yLab);

    const vecs = result.topology === 'series'
      ? [
          { z: result.VR, color: '#6ee7b7', label: 'VR' },
          { z: result.VL, color: '#60a5fa', label: 'VL' },
          { z: result.VC, color: '#f5c451', label: 'VC' },
          { z: result.Vs, color: '#eef0fa', label: 'Vs' }
        ]
      : [
          { z: result.IR, color: '#6ee7b7', label: 'IR' },
          { z: result.IL, color: '#60a5fa', label: 'IL' },
          { z: result.IC, color: '#f5c451', label: 'IC' },
          { z: result.I, color: '#eef0fa', label: 'I' }
        ];
    let maxMag = 0;
    vecs.forEach(function (v) { const m = cmag(v.z); if (m > maxMag) maxMag = m; });
    if (!(maxMag > 0)) maxMag = 1;
    const scale = 130 / maxMag;
    vecs.forEach(function (v) {
      const x1 = cx + v.z.re * scale;
      const y1 = cy - v.z.im * scale;
      if (cmag(v.z) < maxMag * 0.02) return;
      arrow(svg, cx, cy, x1, y1, v.color, v.label, x1 + 6, y1 - 6);
    });
    const cap = svgEl('text', {
      x: cx, y: H - 12, fill: '#9497b8', 'font-size': '10', 'text-anchor': 'middle',
      'font-family': 'ui-sans-serif,sans-serif'
    });
    cap.textContent = result.topology === 'series'
      ? 'Voltage triangle — Vs reference at 0°. I is at θ.'
      : 'Current triangle — Vs reference at 0°. Branch currents shown.';
    svg.appendChild(cap);
    host.appendChild(svg);
  }

  function drawDeltaY() {
    const host = el('pd_dy_diagram');
    if (!host) return;
    host.textContent = '';
    const svg = svgEl('svg', {
      viewBox: '0 0 340 160',
      width: '100%',
      role: 'img',
      'aria-label': 'Original sketch of a balanced delta mesh and a wye star of three impedances.'
    });
    svg.appendChild(svgEl('rect', { x: 1, y: 1, width: 338, height: 158, fill: '#0d1117', stroke: '#30304a' }));
    svg.appendChild(svgEl('polygon', {
      points: '70,28 130,132 10,132',
      fill: 'none', stroke: '#8b7bff', 'stroke-width': '2.2'
    }));
    [['ZΔ', 70, 22], ['ZΔ', 138, 120], ['ZΔ', 4, 120]].forEach(function (lab) {
      const t = svgEl('text', {
        x: lab[1], y: lab[2], fill: '#8b7bff', 'font-size': '10',
        'font-family': 'ui-monospace,monospace'
      });
      t.textContent = lab[0];
      svg.appendChild(t);
    });
    const titleD = svgEl('text', {
      x: 70, y: 150, fill: '#9497b8', 'font-size': '10', 'text-anchor': 'middle',
      'font-family': 'ui-sans-serif,sans-serif'
    });
    titleD.textContent = 'Delta';
    svg.appendChild(titleD);

    svg.appendChild(svgEl('circle', { cx: 250, cy: 88, r: 4, fill: '#6ee7b7' }));
    [[250, 88, 250, 28], [250, 88, 196, 132], [250, 88, 304, 132]].forEach(function (ln) {
      svg.appendChild(svgEl('line', {
        x1: ln[0], y1: ln[1], x2: ln[2], y2: ln[3],
        stroke: '#6ee7b7', 'stroke-width': '2.2'
      }));
    });
    [[250, 22, 'Zy'], [178, 138, 'Zy'], [308, 138, 'Zy']].forEach(function (lab) {
      const t = svgEl('text', {
        x: lab[0], y: lab[1], fill: '#6ee7b7', 'font-size': '10',
        'font-family': 'ui-monospace,monospace'
      });
      t.textContent = lab[2];
      svg.appendChild(t);
    });
    const titleY = svgEl('text', {
      x: 250, y: 150, fill: '#9497b8', 'font-size': '10', 'text-anchor': 'middle',
      'font-family': 'ui-sans-serif,sans-serif'
    });
    titleY.textContent = 'Wye';
    svg.appendChild(titleY);

    const eq = svgEl('text', {
      x: 170, y: 88, fill: '#f5c451', 'font-size': '12', 'text-anchor': 'middle',
      'font-family': 'ui-monospace,monospace'
    });
    eq.textContent = 'ZΔ = 3 Zy';
    svg.appendChild(eq);
    host.appendChild(svg);
  }

  function calcPhasorDiagram() {
    updateExtraFields();
    const result = solvePhasors(readInputs());
    if (result.error) {
      if (typeof showError === 'function') showError('pd_result', result.error);
      return;
    }
    const rows = [
      ['Topology', result.topology === 'series' ? 'Series R-L-C' : 'Parallel R-L-C'],
      ['ω = 2πf', fmtEng(result.omega, 3, 'rad/s')],
      ['XL = ωL', fmtEng(result.XL, 3, 'Ω')],
      ['XC = 1/(ωC)', isFinite(result.XC) ? fmtEng(result.XC, 3, 'Ω') : 'open (no C)'],
      ['Zeq rectangular', rectText(result.Zeq, 'Ω')],
      ['Zeq polar', polarText(result.Zeq, 'Ω')],
      ['Vs RMS', fmtEng(result.vsRms, 3, 'V') + '  (peak ' + fmtEng(result.vsPeak, 3, 'V') + ')'],
      ['I RMS polar', polarText(result.I, 'A')],
      ['VR RMS polar', polarText(result.VR, 'V')],
      ['VL RMS polar', polarText(result.VL, 'V')],
      ['VC RMS polar', polarText(result.VC, 'V')]
    ];
    if (result.topology === 'parallel') {
      rows.push(['IR RMS polar', polarText(result.IR, 'A')]);
      rows.push(['IL RMS polar', polarText(result.IL, 'A')]);
      rows.push(['IC RMS polar', polarText(result.IC, 'A')]);
    }
    rows.push(['θ (I vs V)', (result.theta * 180 / Math.PI).toFixed(2) + '°']);
    rows.push(['Power factor cos θ', result.pf.toFixed(4) + '  —  ' + result.leadLag]);
    rows.push(['S = V I*', rectText(result.S, 'VA')]);
    rows.push(['P = Re(S)', fmtEng(result.P, 3, 'W')]);
    rows.push(['Q = Im(S)', fmtEng(result.Q, 3, 'VAR')]);

    showNotes('pd_result', rows, [
      'Phasors are RMS. Peak = RMS × √2. Source Vs sits on the real axis. θ is arg(I) − arg(V): negative θ is lagging current.',
      'S = Vrms Irms* so P is average real power and Q is reactive. This is a single-phase homework diagram, not the three-phase kVA wizard.',
      'Magdy F. Iskander, Electromagnetic Fields and Waves, 2nd ed., Waveland Press, 2013 (time-harmonic / phasor fields) — optional secondary citation. Working identities are the jω circuit laws.'
    ]);
    drawPhasors(result);
  }

  function calcDeltaY() {
    const re = num('pd_dy_re');
    const im = num('pd_dy_im');
    const dir = sel('pd_dy_dir') || 'wye-to-delta';
    if (!isFinite(re) || !isFinite(im)) {
      if (typeof showError === 'function') showError('pd_dy_result', 'Enter the real and imaginary parts of the known impedance.');
      return;
    }
    const z = c(re, im);
    const out = dir === 'wye-to-delta' ? deltaFromWye(z) : wyeFromDelta(z);
    const rows = [
      ['Known', dir === 'wye-to-delta' ? 'Zy (wye leg)' : 'ZΔ (delta leg)'],
      ['Known rectangular', rectText(z, 'Ω')],
      ['Known polar', polarText(z, 'Ω')],
      ['Converted', dir === 'wye-to-delta' ? 'ZΔ = 3 Zy' : 'Zy = ZΔ / 3'],
      ['Result rectangular', rectText(out, 'Ω')],
      ['Result polar', polarText(out, 'Ω')]
    ];
    showNotes('pd_dy_result', rows, [
      'Balanced conversion only: ZΔ = 3 Zy. Unbalanced meshes need the full Δ-Y matrix, which this panel does not do. This is impedance conversion, not a 3-phase power kVA calculator.'
    ]);
    drawDeltaY();
  }

  function calcAll() {
    calcPhasorDiagram();
    calcDeltaY();
  }

  function loadPhasorExample() {
    setVal('pd_top', 'series');
    setVal('pd_f', '60');
    setVal('pd_f_u', 'Hz');
    setVal('pd_r', '10');
    setVal('pd_r_u', 'ohm');
    setVal('pd_l', '10');
    setVal('pd_l_u', 'mH');
    setVal('pd_c', '100');
    setVal('pd_c_u', 'uF');
    setVal('pd_vs', '120');
    setVal('pd_vs_mode', 'rms');
    setChecked('pd_extra_on', false);
    setVal('pd_dy_re', '10');
    setVal('pd_dy_im', '4');
    setVal('pd_dy_dir', 'wye-to-delta');
    updateExtraFields();
    calcAll();
  }

  function wireLive() {
    const section = el('sec-phasor-diagram');
    if (!section) return;
    const recalc = function () { calcAll(); };
    section.querySelectorAll('input, select').forEach(function (field) {
      field.addEventListener('input', recalc);
      field.addEventListener('change', recalc);
    });
    updateExtraFields();
    drawDeltaY();
    calcAll();
    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-phasor-diagram', 'phasor-diagram', calcAll);
    }
    if (typeof registerReport === 'function') {
      registerReport('pd_result', {
        title: 'Phasor Diagram Workbench',
        formula: function () {
          return 'Z = R + jωL + 1/(jωC)   |   I = Vs / Z   |   S = V I*   |   PF = cos θ   |   ZΔ = 3 Zy';
        },
        codeRefs: function () {
          return [
            'Steady-state phasor analysis, jω impedances',
            'S = Vrms Irms* (average P, reactive Q)',
            'Balanced Δ-Y: ZΔ = 3 Zy',
            'Magdy F. Iskander, Electromagnetic Fields and Waves, 2nd ed., Waveland Press, 2013 (time-harmonic / phasor fields, optional)'
          ];
        }
      });
    }
  }

  global.calcPhasorDiagram = calcPhasorDiagram;
  global.calcDeltaY = calcDeltaY;
  global.loadPhasorExample = loadPhasorExample;

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', wireLive);
    else wireLive();
  }
})(typeof window !== 'undefined' ? window : globalThis);
