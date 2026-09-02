/* ============================================================================
   SEMICONDUCTOR DEVICE I-V — diode, BJT Q-point, long-channel NMOS
   ============================================================================
   Homework device curves, not an op-amp / filter workbench and not a SPICE
   deck. Shockley diode with optional series Rs, β-forced BJT Q-point plus a
   simple Early-effect family, and long-channel NMOS cutoff / triode / sat.

   Citations (identities and topic pick, not copied notes or figures):
     Shockley diode I = Is (e^{vD/(η VT)} − 1), VT = kT/q.
     Long-channel MOSFET square-law with optional λ (channel-length modulation).
     BJT: Ic = β Ib in forward-active; saturation when Vce would fall below
     Vce,sat. Cal Poly semiconductor-device course topics used only to pick
     this device set — notes are not reproduced.
   ============================================================================ */
(function (global) {
  'use strict';

  const K_B = 1.380649e-23;
  const Q_E = 1.602176634e-19;
  const I_UNITS = { A: 1, mA: 1e-3, uA: 1e-6, nA: 1e-9, pA: 1e-12 };
  const V_UNITS = { V: 1, mV: 1e-3 };
  const L_UNITS = { m: 1, um: 1e-6, nm: 1e-9 };
  const R_UNITS = { ohm: 1, k: 1e3, M: 1e6 };

  function convert(value, table, unit) {
    const factor = table[unit];
    if (!isFinite(value) || factor == null) return NaN;
    return value * factor;
  }

  function thermalVoltage(tempK) {
    if (!(tempK > 0)) return NaN;
    return K_B * tempK / Q_E;
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

  /** Ideal Shockley current at junction voltage vD. */
  function shockley(vD, Is, eta, VT) {
    if (!(Is > 0) || !(eta > 0) || !(VT > 0) || !isFinite(vD)) return NaN;
    const arg = vD / (eta * VT);
    if (arg > 80) return Infinity;
    if (arg < -80) return -Is;
    return Is * (Math.exp(arg) - 1);
  }

  /**
   * Terminal I–V with optional series Rs: V = vD + I Rs.
   * Newton on f(vD) = vD + Is Rs (e^{vD/(η VT)} − 1) − V.
   */
  function diodeSolve(V, Is, eta, VT, Rs) {
    if (!(Is > 0) || !(eta > 0) || !(VT > 0) || !isFinite(V)) {
      return { error: 'Is, η, T, and the applied voltage must be finite and greater than zero where required.' };
    }
    if (!(Rs > 0)) {
      const I = shockley(V, Is, eta, VT);
      return { V: V, vD: V, I: I, vRs: 0, Rs: 0 };
    }
    let vD = Math.min(Math.max(V, -1), 0.9);
    for (let i = 0; i < 50; i++) {
      const I = shockley(vD, Is, eta, VT);
      if (!isFinite(I)) break;
      const f = vD + I * Rs - V;
      const dI = (Is / (eta * VT)) * Math.exp(Math.min(vD / (eta * VT), 80));
      const df = 1 + dI * Rs;
      if (!(Math.abs(df) > 0)) break;
      const step = f / df;
      vD -= step;
      if (Math.abs(step) < 1e-12) break;
    }
    const I = shockley(vD, Is, eta, VT);
    return { V: V, vD: vD, I: I, vRs: I * Rs, Rs: Rs };
  }

  /**
   * Common-emitter β-forced Q-point. Saturation when β Ib would pull Vce
   * below Vce,sat; then Ic is set by the collector resistor.
   */
  function bjtQPoint(input) {
    const Vcc = input.Vcc;
    const Rc = input.Rc;
    const Rb = input.Rb;
    const Vbeon = isFinite(input.Vbeon) ? input.Vbeon : 0.7;
    const beta = input.beta;
    const Vcesat = isFinite(input.Vcesat) ? input.Vcesat : 0.2;
    if (!(Vcc > 0) || !(Rc > 0) || !(Rb > 0) || !(beta > 0)) {
      return { error: 'Vcc, Rc, Rb, and β must be greater than zero.' };
    }
    const Ib = (Vcc - Vbeon) / Rb;
    if (!(Ib > 0)) return { error: 'Ib came out ≤ 0. Vcc must sit above Vbe,on.' };
    const IcActive = beta * Ib;
    const IcSat = Math.max((Vcc - Vcesat) / Rc, 0);
    if (IcActive >= IcSat) {
      const Ic = IcSat;
      return {
        region: 'saturation',
        Ib: Ib, Ic: Ic, Ie: Ic + Ib,
        Vce: Vcesat, Vbe: Vbeon,
        betaForced: Ib > 0 ? Ic / Ib : NaN,
        beta: beta, Vcc: Vcc, Rc: Rc, Rb: Rb
      };
    }
    const Vce = Vcc - IcActive * Rc;
    return {
      region: 'forward-active',
      Ib: Ib, Ic: IcActive, Ie: IcActive + Ib,
      Vce: Vce, Vbe: Vbeon,
      betaForced: beta, beta: beta, Vcc: Vcc, Rc: Rc, Rb: Rb
    };
  }

  /** Ic vs Vce with optional Early voltage: Ic = β Ib (1 + Vce / Va). */
  function bjtFamily(IbList, beta, Va, VceMax, n) {
    const samples = n || 80;
    const curves = [];
    for (let k = 0; k < IbList.length; k++) {
      const Ib = IbList[k];
      const pts = [];
      for (let i = 0; i <= samples; i++) {
        const Vce = (VceMax * i) / samples;
        const early = (Va > 0) ? (1 + Vce / Va) : 1;
        pts.push({ Vce: Vce, Ic: beta * Ib * early });
      }
      curves.push({ Ib: Ib, pts: pts });
    }
    return curves;
  }

  /**
   * Long-channel NMOS. kn = μCox · W/L.
   * Cutoff Vgs < Vt; triode Vds < Vov; sat otherwise.
   * Optional λ: multiply by (1 + λ Vds).
   */
  function nmosId(Vgs, Vds, kn, Vt, lambda) {
    if (!(kn > 0) || !isFinite(Vt) || !isFinite(Vgs) || !isFinite(Vds)) {
      return { error: 'μCox, W, L, Vt, Vgs, and Vds must be finite; kn = μCox W/L must be > 0.' };
    }
    const Vov = Vgs - Vt;
    const lam = lambda > 0 ? lambda : 0;
    const ch = (1 + lam * Math.max(Vds, 0));
    if (Vov <= 0) return { Id: 0, region: 'cutoff', Vov: Vov, kn: kn };
    if (Vds < Vov) {
      const Id = kn * (Vov * Vds - 0.5 * Vds * Vds) * ch;
      return { Id: Id, region: 'triode', Vov: Vov, kn: kn };
    }
    const Id = 0.5 * kn * Vov * Vov * ch;
    return { Id: Id, region: 'saturation', Vov: Vov, kn: kn };
  }

  function nmosKn(muCox, W, L) {
    if (!(muCox > 0) || !(W > 0) || !(L > 0)) return NaN;
    return muCox * (W / L);
  }

  const SemiconductorIV = {
    K_B: K_B,
    Q_E: Q_E,
    thermalVoltage: thermalVoltage,
    shockley: shockley,
    diodeSolve: diodeSolve,
    bjtQPoint: bjtQPoint,
    bjtFamily: bjtFamily,
    nmosId: nmosId,
    nmosKn: nmosKn,
    fmtEng: fmtEng
  };
  global.SemiconductorIV = SemiconductorIV;

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

  function applyDevicePanel(which) {
    ['diode', 'bjt', 'mosfet'].forEach(function (name) {
      const panel = el('sd_panel_' + name);
      const btn = el('sd_tab_' + name);
      if (panel) panel.hidden = name !== which;
      if (btn) btn.classList.toggle('active', name === which);
    });
  }

  function showDevice(which) {
    setVal('sd_device', which);
    applyDevicePanel(which);
    calcSemiconductorIV();
    if (typeof writeUrlState === 'function') writeUrlState('sec-semiconductor-iv');
  }

  function plotXY(hostId, series, xLabel, yLabel, aria) {
    const host = el(hostId);
    if (!host) return;
    host.innerHTML = '';
    const W = 520, H = 280, L = 52, R = 16, T = 16, B = 40;
    const svg = svgEl('svg', { viewBox: '0 0 ' + W + ' ' + H, role: 'img', 'aria-label': aria || '' });
    svg.appendChild(svgEl('rect', { x: 0, y: 0, width: W, height: H, fill: '#0d1117' }));
    let xMax = 0, yMax = 0;
    series.forEach(function (s) {
      s.pts.forEach(function (p) {
        if (p.x > xMax) xMax = p.x;
        if (p.y > yMax) yMax = p.y;
      });
    });
    if (!(xMax > 0)) xMax = 1;
    if (!(yMax > 0)) yMax = 1;
    yMax *= 1.08;
    const xOf = function (x) { return L + (x / xMax) * (W - L - R); };
    const yOf = function (y) { return H - B - (y / yMax) * (H - T - B); };
    svg.appendChild(svgEl('line', { x1: L, y1: H - B, x2: W - R, y2: H - B, stroke: '#30363d', 'stroke-width': '1' }));
    svg.appendChild(svgEl('line', { x1: L, y1: T, x2: L, y2: H - B, stroke: '#30363d', 'stroke-width': '1' }));
    const xlab = svgEl('text', { x: (L + W - R) / 2, y: H - 10, fill: '#8b949e', 'font-size': '11', 'text-anchor': 'middle' });
    xlab.textContent = xLabel;
    svg.appendChild(xlab);
    const ylab = svgEl('text', { x: 14, y: (T + H - B) / 2, fill: '#8b949e', 'font-size': '11', 'text-anchor': 'middle', transform: 'rotate(-90 14 ' + ((T + H - B) / 2) + ')' });
    ylab.textContent = yLabel;
    svg.appendChild(ylab);
    const xmaxL = svgEl('text', { x: W - R, y: H - B + 14, fill: '#8b949e', 'font-size': '10', 'text-anchor': 'end' });
    xmaxL.textContent = fmtEng(xMax, 2, '');
    svg.appendChild(xmaxL);
    const ymaxL = svgEl('text', { x: L - 6, y: T + 10, fill: '#8b949e', 'font-size': '10', 'text-anchor': 'end' });
    ymaxL.textContent = fmtEng(yMax, 2, '');
    svg.appendChild(ymaxL);
    const colors = ['#58a6ff', '#3fb950', '#d2a8ff', '#f0883e', '#ff7b72'];
    series.forEach(function (s, si) {
      const color = s.color || colors[si % colors.length];
      let d = '';
      s.pts.forEach(function (p, i) {
        d += (i ? ' L ' : 'M ') + xOf(p.x).toFixed(2) + ' ' + yOf(p.y).toFixed(2);
      });
      svg.appendChild(svgEl('path', { d: d, fill: 'none', stroke: color, 'stroke-width': '2' }));
      if (s.label) {
        const last = s.pts[s.pts.length - 1];
        const t = svgEl('text', { x: xOf(last.x) - 4, y: yOf(last.y) - 6, fill: color, 'font-size': '10', 'text-anchor': 'end' });
        t.textContent = s.label;
        svg.appendChild(t);
      }
    });
    host.appendChild(svg);
  }

  function drawDeviceGlyph(device) {
    const host = el('sd_glyph');
    if (!host) return;
    host.innerHTML = '';
    const svg = svgEl('svg', { viewBox: '0 0 280 160', role: 'img', 'aria-label': 'Original device glyph for ' + device });
    svg.appendChild(svgEl('rect', { x: 0, y: 0, width: 280, height: 160, fill: '#0d1117' }));
    if (device === 'diode') {
      svg.appendChild(svgEl('line', { x1: 40, y1: 80, x2: 110, y2: 80, stroke: '#58a6ff', 'stroke-width': '3' }));
      svg.appendChild(svgEl('polygon', { points: '110,50 110,110 160,80', fill: 'none', stroke: '#58a6ff', 'stroke-width': '3' }));
      svg.appendChild(svgEl('line', { x1: 160, y1: 50, x2: 160, y2: 110, stroke: '#f0883e', 'stroke-width': '3' }));
      svg.appendChild(svgEl('line', { x1: 160, y1: 80, x2: 240, y2: 80, stroke: '#58a6ff', 'stroke-width': '3' }));
      const a = svgEl('text', { x: 50, y: 70, fill: '#8b949e', 'font-size': '12' }); a.textContent = 'A'; svg.appendChild(a);
      const k = svgEl('text', { x: 220, y: 70, fill: '#8b949e', 'font-size': '12' }); k.textContent = 'K'; svg.appendChild(k);
      const rs = svgEl('text', { x: 140, y: 140, fill: '#8b949e', 'font-size': '11', 'text-anchor': 'middle' });
      rs.textContent = 'optional Rs in series'; svg.appendChild(rs);
    } else if (device === 'bjt') {
      svg.appendChild(svgEl('circle', { cx: 140, cy: 80, r: 36, fill: 'none', stroke: '#3fb950', 'stroke-width': '2' }));
      svg.appendChild(svgEl('line', { x1: 122, y1: 58, x2: 122, y2: 102, stroke: '#3fb950', 'stroke-width': '3' }));
      svg.appendChild(svgEl('line', { x1: 40, y1: 80, x2: 122, y2: 80, stroke: '#58a6ff', 'stroke-width': '3' }));
      svg.appendChild(svgEl('line', { x1: 122, y1: 68, x2: 168, y2: 42, stroke: '#58a6ff', 'stroke-width': '3' }));
      svg.appendChild(svgEl('line', { x1: 122, y1: 92, x2: 168, y2: 118, stroke: '#58a6ff', 'stroke-width': '3' }));
      svg.appendChild(svgEl('line', { x1: 168, y1: 42, x2: 168, y2: 24, stroke: '#58a6ff', 'stroke-width': '3' }));
      svg.appendChild(svgEl('line', { x1: 168, y1: 118, x2: 168, y2: 136, stroke: '#58a6ff', 'stroke-width': '3' }));
      const b = svgEl('text', { x: 44, y: 72, fill: '#8b949e', 'font-size': '12' }); b.textContent = 'B'; svg.appendChild(b);
      const c = svgEl('text', { x: 176, y: 28, fill: '#8b949e', 'font-size': '12' }); c.textContent = 'C'; svg.appendChild(c);
      const e = svgEl('text', { x: 176, y: 148, fill: '#8b949e', 'font-size': '12' }); e.textContent = 'E'; svg.appendChild(e);
      const npn = svgEl('text', { x: 140, y: 20, fill: '#8b949e', 'font-size': '11', 'text-anchor': 'middle' });
      npn.textContent = 'npn  ·  β-forced Q-point'; svg.appendChild(npn);
    } else {
      svg.appendChild(svgEl('line', { x1: 130, y1: 40, x2: 130, y2: 120, stroke: '#d2a8ff', 'stroke-width': '3' }));
      svg.appendChild(svgEl('line', { x1: 142, y1: 48, x2: 142, y2: 112, stroke: '#d2a8ff', 'stroke-width': '2' }));
      svg.appendChild(svgEl('line', { x1: 70, y1: 80, x2: 130, y2: 80, stroke: '#58a6ff', 'stroke-width': '3' }));
      svg.appendChild(svgEl('line', { x1: 142, y1: 56, x2: 200, y2: 36, stroke: '#58a6ff', 'stroke-width': '3' }));
      svg.appendChild(svgEl('line', { x1: 142, y1: 104, x2: 200, y2: 124, stroke: '#58a6ff', 'stroke-width': '3' }));
      const g = svgEl('text', { x: 48, y: 76, fill: '#8b949e', 'font-size': '12' }); g.textContent = 'G'; svg.appendChild(g);
      const d = svgEl('text', { x: 206, y: 34, fill: '#8b949e', 'font-size': '12' }); d.textContent = 'D'; svg.appendChild(d);
      const s = svgEl('text', { x: 206, y: 136, fill: '#8b949e', 'font-size': '12' }); s.textContent = 'S'; svg.appendChild(s);
      const m = svgEl('text', { x: 140, y: 20, fill: '#8b949e', 'font-size': '11', 'text-anchor': 'middle' });
      m.textContent = 'NMOS  ·  long-channel'; svg.appendChild(m);
    }
    host.appendChild(svg);
  }

  function calcDiode() {
    const T = num('sd_d_t');
    const VT = thermalVoltage(T);
    const Is = convert(num('sd_d_is'), I_UNITS, sel('sd_d_is_u') || 'nA');
    const eta = num('sd_d_n');
    const Rs = convert(num('sd_d_rs'), R_UNITS, sel('sd_d_rs_u') || 'ohm');
    const Vop = convert(num('sd_d_v'), V_UNITS, sel('sd_d_v_u') || 'V');
    const Vmax = convert(num('sd_d_vmax'), V_UNITS, sel('sd_d_vmax_u') || 'V');
    const sol = diodeSolve(Vop, Is, eta, VT, Rs > 0 ? Rs : 0);
    if (sol.error) {
      if (typeof showResult === 'function') showResult('sd_result', [['Error', sol.error]]);
      return;
    }
    const rows = [
      ['T', fmtEng(T, 3, 'K')],
      ['VT = kT/q', fmtEng(VT, 3, 'V')],
      ['Is', fmtEng(Is, 3, 'A')],
      ['η', fmtEng(eta, 3, '')],
      ['Rs', Rs > 0 ? fmtEng(Rs, 3, 'Ω') : '0 (ideal junction)'],
      ['Applied V', fmtEng(Vop, 3, 'V')],
      ['Junction vD', fmtEng(sol.vD, 4, 'V')],
      ['I = Is (e^{vD/(η VT)} − 1)', fmtEng(sol.I, 4, 'A')],
      ['I Rs', fmtEng(sol.vRs, 4, 'V')]
    ];
    const notes = [
      'Shockley diode: I = Is (e^{vD/(η VT)} − 1) with VT = kT/q. Optional Rs is solved so the terminal voltage is vD + I Rs. Reverse breakdown, charge storage, and temperature coefficients of Is are not modeled.',
      'This is not the Analog Design Workbench (op-amps / filters) and not a SPICE .model card.',
      'Standard device-physics identities. Cal Poly semiconductor-device course topics used only to pick the device set — notes are not reproduced.'
    ];
    showNotes('sd_result', rows, notes);
    const vmax = Vmax > 0 ? Vmax : Math.max(Vop, 0.8);
    const pts = [];
    const n = 80;
    for (let i = 0; i <= n; i++) {
      const v = (vmax * i) / n;
      const s = diodeSolve(v, Is, eta, VT, Rs > 0 ? Rs : 0);
      pts.push({ x: v, y: isFinite(s.I) ? Math.max(s.I, 0) : 0 });
    }
    plotXY('sd_plot', [{ pts: pts, color: '#58a6ff', label: 'I(V)' }], 'V (V)', 'I (A)', 'Diode I-V curve');
    drawDeviceGlyph('diode');
  }

  function calcBjt() {
    const q = bjtQPoint({
      Vcc: num('sd_b_vcc'),
      Rc: convert(num('sd_b_rc'), R_UNITS, sel('sd_b_rc_u') || 'k'),
      Rb: convert(num('sd_b_rb'), R_UNITS, sel('sd_b_rb_u') || 'k'),
      Vbeon: num('sd_b_vbe'),
      beta: num('sd_b_beta'),
      Vcesat: num('sd_b_vcesat')
    });
    if (q.error) {
      if (typeof showResult === 'function') showResult('sd_result', [['Error', q.error]]);
      return;
    }
    const Va = num('sd_b_va');
    const rows = [
      ['Region', q.region],
      ['Ib = (Vcc − Vbe,on) / Rb', fmtEng(q.Ib, 4, 'A')],
      ['Ic', fmtEng(q.Ic, 4, 'A')],
      ['Ie = Ic + Ib', fmtEng(q.Ie, 4, 'A')],
      ['Vce', fmtEng(q.Vce, 3, 'V')],
      ['Forced β = Ic / Ib', fmtEng(q.betaForced, 3, '')],
      ['Spec β', fmtEng(q.beta, 3, '')]
    ];
    const notes = [
      'β-forced Q-point: Ib = (Vcc − Vbe,on)/Rb, Ic = β Ib until the collector resistor would pull Vce below Vce,sat. That is saturation, and Ic is then (Vcc − Vce,sat)/Rc.',
      'The family plot is Ic = β Ib (1 + Vce/Va) when Va is set — a first-order Early sketch, not a Gummel-Poon model.',
      'Standard device-physics identities. Cal Poly semiconductor-device course topics used only to pick the device set — notes are not reproduced.'
    ];
    showNotes('sd_result', rows, notes);
    const IbList = [0.5 * q.Ib, q.Ib, 1.5 * q.Ib].filter(function (x) { return x > 0; });
    const fam = bjtFamily(IbList, q.beta, Va > 0 ? Va : 0, Math.max(q.Vcc, 1), 80);
    const series = fam.map(function (c, i) {
      return {
        pts: c.pts.map(function (p) { return { x: p.Vce, y: p.Ic }; }),
        label: 'Ib ' + fmtEng(c.Ib, 2, 'A'),
        color: ['#3fb950', '#58a6ff', '#d2a8ff'][i]
      };
    });
    plotXY('sd_plot', series, 'Vce (V)', 'Ic (A)', 'BJT collector family');
    drawDeviceGlyph('bjt');
  }

  function calcMosfet() {
    const muCox = num('sd_m_k') * 1e-6;
    const W = convert(num('sd_m_w'), L_UNITS, sel('sd_m_w_u') || 'um');
    const L = convert(num('sd_m_l'), L_UNITS, sel('sd_m_l_u') || 'um');
    const kn = nmosKn(muCox, W, L);
    const Vt = num('sd_m_vt');
    const lambda = num('sd_m_lam');
    const Vgs = num('sd_m_vgs');
    const VdsOp = num('sd_m_vds');
    const VdsMax = num('sd_m_vdsmax');
    const op = nmosId(Vgs, VdsOp, kn, Vt, lambda);
    if (op.error) {
      if (typeof showResult === 'function') showResult('sd_result', [['Error', op.error]]);
      return;
    }
    const rows = [
      ['kn = μCox W/L', fmtEng(kn, 4, 'A/V²')],
      ['W/L', fmtEng(W / L, 3, '')],
      ['Vt', fmtEng(Vt, 3, 'V')],
      ['Vov = Vgs − Vt', fmtEng(op.Vov, 3, 'V')],
      ['Vgs', fmtEng(Vgs, 3, 'V')],
      ['Vds', fmtEng(VdsOp, 3, 'V')],
      ['Region', op.region],
      ['Id', fmtEng(op.Id, 4, 'A')],
      ['λ', lambda > 0 ? fmtEng(lambda, 3, '1/V') : '0 (no CLM)']
    ];
    const notes = [
      'Long-channel NMOS: cutoff if Vgs < Vt; triode if Vds < Vov with Id = kn [(Vgs−Vt)Vds − Vds²/2]; saturation Id = (1/2) kn Vov². Optional λ multiplies by (1 + λ Vds). Short-channel, velocity sat, and subthreshold are out of scope.',
      'μCox is entered in µA/V², the usual homework unit. This is not a process-recipe or foundry deck.',
      'Standard device-physics identities. Cal Poly semiconductor-device course topics used only to pick the device set — notes are not reproduced.'
    ];
    showNotes('sd_result', rows, notes);
    const vmax = VdsMax > 0 ? VdsMax : Math.max(VdsOp, 2 * Math.max(op.Vov, 0.5));
    const vgsList = [Vt + 0.2, Vgs, Vgs + 0.4].filter(function (v) { return v > Vt; });
    const unique = [];
    vgsList.forEach(function (v) {
      if (!unique.some(function (u) { return Math.abs(u - v) < 1e-9; })) unique.push(v);
    });
    const series = unique.map(function (vg, i) {
      const pts = [];
      const n = 80;
      for (let k = 0; k <= n; k++) {
        const vds = (vmax * k) / n;
        const s = nmosId(vg, vds, kn, Vt, lambda);
        pts.push({ x: vds, y: Math.max(s.Id || 0, 0) });
      }
      return { pts: pts, label: 'Vgs ' + fmtEng(vg, 2, 'V'), color: ['#d2a8ff', '#58a6ff', '#3fb950'][i] };
    });
    plotXY('sd_plot', series, 'Vds (V)', 'Id (A)', 'NMOS Id-Vds family');
    drawDeviceGlyph('mosfet');
  }

  function calcSemiconductorIV() {
    if (!el('sec-semiconductor-iv')) return;
    const which = sel('sd_device') || 'diode';
    applyDevicePanel(which);
    if (which === 'bjt') calcBjt();
    else if (which === 'mosfet') calcMosfet();
    else calcDiode();
  }

  function loadSemiconductorExample() {
    setVal('sd_device', 'diode');
    setVal('sd_d_is', '1');
    setVal('sd_d_is_u', 'nA');
    setVal('sd_d_n', '1.8');
    setVal('sd_d_t', '300');
    setVal('sd_d_rs', '0');
    setVal('sd_d_v', '0.60');
    setVal('sd_d_vmax', '0.75');
    setVal('sd_b_vcc', '5');
    setVal('sd_b_rc', '1');
    setVal('sd_b_rc_u', 'k');
    setVal('sd_b_rb', '100');
    setVal('sd_b_rb_u', 'k');
    setVal('sd_b_beta', '100');
    setVal('sd_b_vbe', '0.7');
    setVal('sd_b_vcesat', '0.2');
    setVal('sd_b_va', '50');
    setVal('sd_m_k', '200');
    setVal('sd_m_w', '10');
    setVal('sd_m_w_u', 'um');
    setVal('sd_m_l', '1');
    setVal('sd_m_l_u', 'um');
    setVal('sd_m_vt', '0.7');
    setVal('sd_m_lam', '0');
    setVal('sd_m_vgs', '2');
    setVal('sd_m_vds', '3');
    setVal('sd_m_vdsmax', '5');
    showDevice('diode');
  }

  function wireLive() {
    const section = el('sec-semiconductor-iv');
    if (!section) return;
    const recalc = function () { calcSemiconductorIV(); };
    section.querySelectorAll('input, select').forEach(function (field) {
      field.addEventListener('input', recalc);
      field.addEventListener('change', recalc);
    });
    ['diode', 'bjt', 'mosfet'].forEach(function (name) {
      const btn = el('sd_tab_' + name);
      if (!btn) return;
      btn.addEventListener('click', function () { showDevice(name); });
    });
    calcSemiconductorIV();
    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-semiconductor-iv', 'semiconductor-iv', calcSemiconductorIV);
    }
    if (typeof registerReport === 'function') {
      registerReport('sd_result', {
        title: 'Semiconductor Device I-V',
        formula: function () {
          return 'I = Is (e^{vD/(η VT)} − 1)   |   Ic = β Ib   |   NMOS long-channel square law';
        },
        codeRefs: function () {
          return [
            'Shockley diode I = Is (e^{vD/(η VT)} − 1), VT = kT/q',
            'BJT β-forced Q-point; saturation when Vce would fall below Vce,sat',
            'Long-channel NMOS cutoff / triode / saturation with optional λ',
            'Cal Poly semiconductor-device course topics used only to pick the device set'
          ];
        }
      });
    }
  }

  global.calcSemiconductorIV = calcSemiconductorIV;
  global.loadSemiconductorExample = loadSemiconductorExample;
  global.showSemiconductorDevice = showDevice;

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', wireLive);
    else wireLive();
  }
})(typeof window !== 'undefined' ? window : globalThis);
