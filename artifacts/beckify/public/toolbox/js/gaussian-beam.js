/* ============================================================================
   GAUSSIAN BEAM — w(z), zR, R(z), confocal parameter
   ============================================================================
   Free-space TEM00 envelope. Not a thin-lens imager and not a double-slit
   interferometer (those live in the STEM toolkit).

   Citations (identities, not copied prose or figures):
     Bahaa E. A. Saleh and Malvin Carl Teich, Fundamentals of Photonics
     (Wiley). Drive filename has no edition — none is invented here.
     zR = π w0² / λ, w(z) = w0 √(1 + (z/zR)²), R(z) = z (1 + (zR/z)²),
     confocal parameter b = 2 zR. Far-field 1/e² half-angle θ = λ / (π w0).
   ============================================================================ */
(function (global) {
  'use strict';

  const LEN = { m: 1, mm: 1e-3, um: 1e-6, nm: 1e-9 };
  const WAVE = { nm: 1e-9, um: 1e-6, m: 1 };

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

  function rayleigh(w0, lambda) {
    if (!(w0 > 0) || !(lambda > 0)) return NaN;
    return Math.PI * w0 * w0 / lambda;
  }

  function spot(w0, z, zR) {
    if (!(w0 > 0) || !(zR > 0) || !isFinite(z)) return NaN;
    return w0 * Math.sqrt(1 + (z / zR) * (z / zR));
  }

  function curvature(z, zR) {
    if (!(zR > 0) || !isFinite(z)) return NaN;
    if (z === 0) return Infinity;
    return z * (1 + (zR / z) * (zR / z));
  }

  function confocal(zR) {
    if (!(zR > 0)) return NaN;
    return 2 * zR;
  }

  function divergence(lambda, w0) {
    if (!(lambda > 0) || !(w0 > 0)) return NaN;
    return lambda / (Math.PI * w0);
  }

  /** On-axis intensity ratio I(z)/I0 = (w0 / w(z))². */
  function onAxisIntensityRatio(w0, w) {
    if (!(w > 0) || !(w0 > 0)) return NaN;
    return (w0 / w) * (w0 / w);
  }

  function solveBeam(input) {
    const w0 = input.w0;
    const lambda = input.lambda;
    const z = input.z;
    const zR = rayleigh(w0, lambda);
    if (!isFinite(zR)) return { error: 'Waist w0 and wavelength λ must be greater than zero.' };
    const w = spot(w0, z, zR);
    const R = curvature(z, zR);
    const b = confocal(zR);
    const theta = divergence(lambda, w0);
    return {
      w0: w0, lambda: lambda, z: z,
      zR: zR, w: w, R: R, b: b, theta: theta,
      Iratio: onAxisIntensityRatio(w0, w)
    };
  }

  const GaussianBeam = {
    rayleigh: rayleigh,
    spot: spot,
    curvature: curvature,
    confocal: confocal,
    divergence: divergence,
    onAxisIntensityRatio: onAxisIntensityRatio,
    solveBeam: solveBeam,
    fmtEng: fmtEng
  };
  global.GaussianBeam = GaussianBeam;

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

  function drawBeam(result) {
    const host = el('gb_diagram');
    if (!host) return;
    host.innerHTML = '';
    const W = 520, H = 240, L = 40, R = 24, T = 24, B = 36;
    const svg = svgEl('svg', {
      viewBox: '0 0 ' + W + ' ' + H,
      role: 'img',
      'aria-label': 'Original Gaussian beam envelope with waist and Rayleigh marks.'
    });
    svg.appendChild(svgEl('rect', { x: 0, y: 0, width: W, height: H, fill: '#0d1117' }));
    const zR = result && result.zR > 0 ? result.zR : 1;
    const w0 = result && result.w0 > 0 ? result.w0 : 1;
    const zSpan = 3 * zR;
    const wMax = spot(w0, zSpan, zR);
    const xOf = function (z) { return L + ((z + zSpan) / (2 * zSpan)) * (W - L - R); };
    const yOf = function (w) { return H / 2 - (w / wMax) * ((H - T - B) / 2); };
    const yOfN = function (w) { return H / 2 + (w / wMax) * ((H - T - B) / 2); };
    svg.appendChild(svgEl('line', { x1: L, y1: H / 2, x2: W - R, y2: H / 2, stroke: '#30363d', 'stroke-width': '1' }));
    let dTop = '', dBot = '';
    const n = 80;
    for (let i = 0; i <= n; i++) {
      const z = -zSpan + (2 * zSpan * i) / n;
      const w = spot(w0, z, zR);
      dTop += (i ? ' L ' : 'M ') + xOf(z).toFixed(2) + ' ' + yOf(w).toFixed(2);
      dBot += (i ? ' L ' : 'M ') + xOf(z).toFixed(2) + ' ' + yOfN(w).toFixed(2);
    }
    svg.appendChild(svgEl('path', { d: dTop, fill: 'none', stroke: '#58a6ff', 'stroke-width': '2' }));
    svg.appendChild(svgEl('path', { d: dBot, fill: 'none', stroke: '#58a6ff', 'stroke-width': '2' }));
    svg.appendChild(svgEl('line', { x1: xOf(0), y1: yOf(w0), x2: xOf(0), y2: yOfN(w0), stroke: '#f0883e', 'stroke-width': '2' }));
    svg.appendChild(svgEl('line', { x1: xOf(zR), y1: T + 8, x2: xOf(zR), y2: H - B, stroke: '#3fb950', 'stroke-width': '1', 'stroke-dasharray': '4 3' }));
    svg.appendChild(svgEl('line', { x1: xOf(-zR), y1: T + 8, x2: xOf(-zR), y2: H - B, stroke: '#3fb950', 'stroke-width': '1', 'stroke-dasharray': '4 3' }));
    if (result && isFinite(result.z)) {
      const wz = spot(w0, result.z, zR);
      svg.appendChild(svgEl('circle', { cx: xOf(result.z), cy: yOf(wz), r: 3.5, fill: '#d2a8ff' }));
      svg.appendChild(svgEl('circle', { cx: xOf(result.z), cy: yOfN(wz), r: 3.5, fill: '#d2a8ff' }));
    }
    const w0L = svgEl('text', { x: xOf(0) + 6, y: yOf(w0) - 6, fill: '#f0883e', 'font-size': '11' });
    w0L.textContent = 'w0'; svg.appendChild(w0L);
    const zrL = svgEl('text', { x: xOf(zR) + 4, y: T + 14, fill: '#3fb950', 'font-size': '11' });
    zrL.textContent = '+zR'; svg.appendChild(zrL);
    const zmL = svgEl('text', { x: xOf(-zR) - 4, y: T + 14, fill: '#3fb950', 'font-size': '11', 'text-anchor': 'end' });
    zmL.textContent = '−zR'; svg.appendChild(zmL);
    const axis = svgEl('text', { x: (L + W - R) / 2, y: H - 10, fill: '#8b949e', 'font-size': '11', 'text-anchor': 'middle' });
    axis.textContent = 'z'; svg.appendChild(axis);
    host.appendChild(svg);
  }

  function calcGaussianBeam() {
    if (!el('sec-gaussian-beam')) return;
    const result = solveBeam({
      w0: convert(num('gb_w0'), LEN, sel('gb_w0_u') || 'um'),
      lambda: convert(num('gb_lam'), WAVE, sel('gb_lam_u') || 'nm'),
      z: convert(num('gb_z'), LEN, sel('gb_z_u') || 'mm')
    });
    if (result.error) {
      if (typeof showResult === 'function') showResult('gb_result', [['Error', result.error]]);
      drawBeam(null);
      return;
    }
    const rows = [
      ['Wavelength λ', fmtEng(result.lambda, 3, 'm')],
      ['Waist w0', fmtEng(result.w0, 3, 'm')],
      ['z', fmtEng(result.z, 3, 'm')],
      ['Rayleigh range zR = π w0² / λ', fmtEng(result.zR, 3, 'm')],
      ['Confocal parameter b = 2 zR', fmtEng(result.b, 3, 'm')],
      ['Spot w(z) = w0 √(1 + (z/zR)²)', fmtEng(result.w, 3, 'm')],
      ['Radius of curvature R(z)', isFinite(result.R) ? fmtEng(result.R, 3, 'm') : '∞ (plane at waist)'],
      ['Far-field half-angle θ = λ/(π w0)', fmtEng(result.theta, 3, 'rad') + '  (' + fmtEng(result.theta * 180 / Math.PI, 3, '°') + ')'],
      ['On-axis I(z)/I0 = (w0/w)²', fmtEng(result.Iratio, 4, '')]
    ];
    const notes = [
      'TEM00 free-space envelope. w is the 1/e² intensity radius. R(z) is infinite at the waist and ≈ z in the far field. This is not a thin-lens imager and not a double-slit interferometer.',
      'Bahaa E. A. Saleh and Malvin Carl Teich, Fundamentals of Photonics (Wiley). No edition is claimed here — the Drive filename does not carry one. zR = π w0² / λ, w(z), R(z), and b = 2 zR are standard identities.'
    ];
    showNotes('gb_result', rows, notes);
    drawBeam(result);
  }

  function loadGaussianExample() {
    setVal('gb_lam', '633');
    setVal('gb_lam_u', 'nm');
    setVal('gb_w0', '50');
    setVal('gb_w0_u', 'um');
    setVal('gb_z', '10');
    setVal('gb_z_u', 'mm');
    calcGaussianBeam();
  }

  function wireLive() {
    const section = el('sec-gaussian-beam');
    if (!section) return;
    const recalc = function () { calcGaussianBeam(); };
    section.querySelectorAll('input, select').forEach(function (field) {
      field.addEventListener('input', recalc);
      field.addEventListener('change', recalc);
    });
    calcGaussianBeam();
    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-gaussian-beam', 'gaussian-beam', calcGaussianBeam);
    }
    if (typeof registerReport === 'function') {
      registerReport('gb_result', {
        title: 'Gaussian Beam',
        formula: function () {
          return 'zR = π w0² / λ   |   w(z) = w0 √(1+(z/zR)²)   |   R(z) = z (1+(zR/z)²)   |   b = 2 zR';
        },
        codeRefs: function () {
          return [
            'Bahaa E. A. Saleh and Malvin Carl Teich, Fundamentals of Photonics (Wiley)',
            'zR = π w0² / λ, w(z) = w0 √(1 + (z/zR)²), R(z) = z (1 + (zR/z)²), b = 2 zR',
            'Far-field 1/e² half-angle θ = λ / (π w0)'
          ];
        }
      });
    }
  }

  global.calcGaussianBeam = calcGaussianBeam;
  global.loadGaussianExample = loadGaussianExample;

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', wireLive);
    else wireLive();
  }
})(typeof window !== 'undefined' ? window : globalThis);
