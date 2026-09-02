/* ============================================================================
   MAGNETIC CIRCUIT WORKBENCH — homework magnetostatics
   ============================================================================
   Reluctance network for a gapped laminated core: R = ℓ / (μ A), Φ = NI / Rtot,
   B = Φ / A, H = B / μ. Optional air-gap fringing uses a square-equivalent
   first-order area correction the user can edit.

   This is not a transformer kVA sizer. Saturation is a warning only — B vs NI
   stays linear. Ampere’s law around the loop closes the MMF budget.

   Citations (identities and discussion, not copied prose or figures):
     Magdy F. Iskander, Electromagnetic Fields and Waves, 2nd ed.,
     Waveland Press, 2013 (magnetic circuits discussion).
     Ampere’s law: ∮ H · dℓ = NI. Faraday: v = N dΦ/dt (noted, not solved here).
     Reluctance definition R = ℓ / (μ A). Generic EE machines-course practice
     for series/parallel reluctance networks and a simple gap-fringing area
     correction A_eff = (√A + k ℓ_g)².
   ============================================================================ */
(function (global) {
  'use strict';

  const MU0 = 4 * Math.PI * 1e-7;
  const LEN = { m: 1, cm: 0.01, mm: 0.001, in: 0.0254 };
  const AREA = { m2: 1, cm2: 1e-4, mm2: 1e-6, in2: 6.4516e-4 };

  function convert(value, table, unit) {
    const factor = table[unit];
    if (!isFinite(value) || factor == null) return NaN;
    return value * factor;
  }

  function permeability(mode, ur, mu) {
    if (mode === 'mu') return mu > 0 ? mu : NaN;
    if (!(ur > 0)) return NaN;
    return ur * MU0;
  }

  /** Reluctance of a uniform leg. R = ℓ / (μ A). */
  function reluctance(lengthM, areaM2, mu) {
    if (!(lengthM > 0) || !(areaM2 > 0) || !(mu > 0)) return NaN;
    return lengthM / (mu * areaM2);
  }

  /**
   * Square-equivalent first-order fringing: grow each side of √A by k·ℓ_g.
   * k = 1 is the usual homework starting point (A_eff = (√A + ℓ_g)²).
   * k is editable so a published geometry factor can be dropped in.
   */
  function fringeArea(areaM2, gapM, k) {
    if (!(areaM2 > 0)) return NaN;
    if (!(gapM > 0) || !(k >= 0)) return areaM2;
    const side = Math.sqrt(areaM2);
    const grown = side + k * gapM;
    return grown * grown;
  }

  function seriesReluctance(values) {
    let sum = 0;
    for (let i = 0; i < values.length; i++) {
      if (!(values[i] > 0) && values[i] !== 0) return NaN;
      sum += values[i];
    }
    return sum;
  }

  function parallelReluctance(values) {
    let acc = 0;
    let n = 0;
    for (let i = 0; i < values.length; i++) {
      if (!(values[i] > 0)) continue;
      acc += 1 / values[i];
      n += 1;
    }
    if (!n || !(acc > 0)) return NaN;
    return 1 / acc;
  }

  /**
   * Steel legs in series or parallel, optional air gap always in series with
   * that steel network (gapped-core model). Flux Φ = F / Rtot, F = N I.
   */
  function solveMagneticCircuit(input) {
    const steel = input.steel || [];
    const steelR = [];
    const steelLegs = [];
    for (let i = 0; i < steel.length; i++) {
      const leg = steel[i];
      if (!leg || !leg.on) continue;
      const mu = permeability(leg.muMode || 'ur', leg.ur, leg.mu);
      const R = reluctance(leg.lengthM, leg.areaM2, mu);
      if (!(R > 0)) continue;
      steelLegs.push({
        id: leg.id || ('steel-' + i),
        label: leg.label || ('Steel ' + (i + 1)),
        kind: 'steel',
        lengthM: leg.lengthM,
        areaM2: leg.areaM2,
        mu: mu,
        ur: mu / MU0,
        R: R
      });
      steelR.push(R);
    }
    if (!steelLegs.length) {
      return { error: 'Enter at least one steel path with length, area, and μ (or μr) greater than zero.' };
    }

    const net = input.network === 'parallel' ? 'parallel' : 'series';
    const Rsteel = net === 'parallel' ? parallelReluctance(steelR) : seriesReluctance(steelR);
    if (!(Rsteel > 0)) return { error: 'Steel-path reluctance did not come out finite. Check the lengths and areas.' };

    let gap = null;
    let Rgap = 0;
    if (input.gap && input.gap.on) {
      const g = input.gap;
      if (!(g.lengthM > 0)) return { error: 'Air-gap length must be greater than zero when the gap is enabled.' };
      const Ageom = g.areaM2 > 0 ? g.areaM2 : steelLegs[0].areaM2;
      if (!(Ageom > 0)) return { error: 'Air-gap area must be greater than zero (or match the core area).' };
      const k = g.fringing ? (isFinite(g.k) && g.k >= 0 ? g.k : 1) : 0;
      const Aeff = g.fringing ? fringeArea(Ageom, g.lengthM, k) : Ageom;
      Rgap = reluctance(g.lengthM, Aeff, MU0);
      if (!(Rgap > 0)) return { error: 'Air-gap reluctance did not come out finite.' };
      gap = {
        id: 'gap',
        label: 'Air gap',
        kind: 'gap',
        lengthM: g.lengthM,
        areaM2: Ageom,
        areaEffM2: Aeff,
        fringing: !!g.fringing,
        k: k,
        mu: MU0,
        ur: 1,
        R: Rgap
      };
    }

    const Rtot = Rsteel + Rgap;
    const F = (input.turns > 0 ? input.turns : 0) * (isFinite(input.amps) ? input.amps : 0);
    if (!(input.turns > 0)) return { error: 'Turns N must be greater than zero.' };
    if (!isFinite(input.amps)) return { error: 'Winding current I must be a number (zero is allowed).' };
    if (!(Rtot > 0)) return { error: 'Total reluctance is not finite.' };

    const flux = F / Rtot;
    const bsat = input.bsat > 0 ? input.bsat : 1.5;

    const drops = [];
    if (net === 'series') {
      steelLegs.forEach(function (leg) {
        const phi = flux;
        const B = phi / leg.areaM2;
        const H = B / leg.mu;
        const mmf = phi * leg.R;
        drops.push(Object.assign({}, leg, { flux: phi, B: B, H: H, mmf: mmf, saturated: Math.abs(B) > bsat }));
      });
    } else {
      steelLegs.forEach(function (leg) {
        /* Parallel steel around a shared series gap: Φ_i = Φ_total × (Rsteel / R_i). */
        const phiBranch = flux * (Rsteel / leg.R);
        const B = phiBranch / leg.areaM2;
        const H = B / leg.mu;
        const mmf = phiBranch * leg.R;
        drops.push(Object.assign({}, leg, { flux: phiBranch, B: B, H: H, mmf: mmf, saturated: Math.abs(B) > bsat }));
      });
    }

    if (gap) {
      const Bgap = flux / gap.areaEffM2;
      const Hgap = Bgap / MU0;
      drops.push(Object.assign({}, gap, {
        flux: flux,
        B: Bgap,
        H: Hgap,
        mmf: flux * gap.R,
        saturated: false
      }));
    }

    let coreB = 0;
    let saturated = false;
    for (let i = 0; i < drops.length; i++) {
      const drop = drops[i];
      if (drop.kind !== 'steel') continue;
      const absB = Math.abs(drop.B);
      if (absB > coreB) coreB = absB;
      if (drop.saturated) saturated = true;
    }
    return {
      network: net,
      mu0: MU0,
      F: F,
      turns: input.turns,
      amps: input.amps,
      Rsteel: Rsteel,
      Rgap: Rgap,
      Rtot: Rtot,
      flux: flux,
      drops: drops,
      bsat: bsat,
      coreB: coreB,
      saturated: saturated,
      steelCount: steelLegs.length
    };
  }

  /** Linear B(NI) samples for the first steel leg. Saturation is a marker, not a model. */
  function bVsNI(result, points) {
    if (!result || !result.drops || !result.drops.length || !(result.Rtot > 0)) return [];
    const n = points || 25;
    const nImax = Math.max(Math.abs(result.F) * 2, 1);
    const area = result.drops[0].areaM2;
    const samples = [];
    for (let i = 0; i <= n; i++) {
      const ni = (i / n) * nImax;
      const phi = ni / result.Rtot;
      samples.push({ ni: ni, B: phi / area });
    }
    return samples;
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

  const MagneticCircuit = {
    MU0: MU0,
    LEN: LEN,
    AREA: AREA,
    convert: convert,
    permeability: permeability,
    reluctance: reluctance,
    fringeArea: fringeArea,
    seriesReluctance: seriesReluctance,
    parallelReluctance: parallelReluctance,
    solveMagneticCircuit: solveMagneticCircuit,
    bVsNI: bVsNI,
    fmtEng: fmtEng
  };
  global.MagneticCircuit = MagneticCircuit;

  function el(id) { return document.getElementById(id); }
  function num(id) {
    const node = el(id);
    if (!node) return NaN;
    const value = parseFloat(node.value);
    return isFinite(value) ? value : NaN;
  }
  function sel(id) {
    const node = el(id);
    return node ? node.value : '';
  }
  function checked(id) {
    const node = el(id);
    return !!(node && node.checked);
  }
  function setVal(id, value) {
    const node = el(id);
    if (node) node.value = value;
  }
  function setChecked(id, on) {
    const node = el(id);
    if (node) node.checked = !!on;
  }

  function svgEl(tag, attrs) {
    const node = document.createElementNS('http://www.w3.org/2000/svg', tag);
    Object.keys(attrs || {}).forEach(function (key) {
      node.setAttribute(key, attrs[key]);
    });
    return node;
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

  function readSteelLeg(prefix, label) {
    const on = prefix === 'mc_core' ? true : checked(prefix + '_on');
    if (!on) return null;
    const lengthM = convert(num(prefix + '_l'), LEN, sel(prefix + '_l_u') || 'm');
    const areaM2 = convert(num(prefix + '_a'), AREA, sel(prefix + '_a_u') || 'cm2');
    const muMode = sel(prefix + '_mu_mode') || 'ur';
    return {
      id: prefix,
      label: label,
      on: true,
      lengthM: lengthM,
      areaM2: areaM2,
      muMode: muMode,
      ur: num(prefix + '_ur'),
      mu: num(prefix + '_mu')
    };
  }

  function readInputs() {
    const steel = [
      readSteelLeg('mc_core', 'Core'),
      readSteelLeg('mc_x1', 'Extra path 1'),
      readSteelLeg('mc_x2', 'Extra path 2')
    ].filter(Boolean);

    const sameA = checked('mc_gap_same_a');
    const core = steel[0];
    const gapArea = sameA && core ? core.areaM2 : convert(num('mc_gap_a'), AREA, sel('mc_gap_a_u') || 'cm2');

    return {
      network: sel('mc_net') === 'parallel' ? 'parallel' : 'series',
      steel: steel,
      gap: {
        on: checked('mc_gap_on'),
        lengthM: convert(num('mc_gap_l'), LEN, sel('mc_gap_l_u') || 'mm'),
        areaM2: gapArea,
        fringing: checked('mc_gap_fringe'),
        k: num('mc_gap_k')
      },
      turns: num('mc_n'),
      amps: num('mc_i'),
      bsat: num('mc_bsat')
    };
  }

  function updateMuFields() {
    ['mc_core', 'mc_x1', 'mc_x2'].forEach(function (prefix) {
      const mode = sel(prefix + '_mu_mode') || 'ur';
      const urWrap = el(prefix + '_ur_wrap');
      const muWrap = el(prefix + '_mu_wrap');
      if (urWrap) urWrap.hidden = mode !== 'ur';
      if (muWrap) muWrap.hidden = mode !== 'mu';
    });
    const gapOn = checked('mc_gap_on');
    const gapFields = el('mc_gap_fields');
    if (gapFields) gapFields.hidden = !gapOn;
    const sameA = checked('mc_gap_same_a');
    const gapAreaWrap = el('mc_gap_area_wrap');
    if (gapAreaWrap) gapAreaWrap.hidden = !gapOn || sameA;
    const fringeOn = checked('mc_gap_fringe');
    const kWrap = el('mc_gap_k_wrap');
    if (kWrap) kWrap.hidden = !gapOn || !fringeOn;
    const x1 = el('mc_x1_fields');
    const x2 = el('mc_x2_fields');
    if (x1) x1.hidden = !checked('mc_x1_on');
    if (x2) x2.hidden = !checked('mc_x2_on');
  }

  function drawCoreDiagram(result) {
    const host = el('mc_diagram');
    if (!host) return;
    host.textContent = '';
    const svg = svgEl('svg', {
      viewBox: '0 0 360 220',
      width: '100%',
      role: 'img',
      'aria-label': 'Laminated magnetic core with an air gap and a flux loop labeled N I.'
    });
    svg.appendChild(svgEl('rect', { x: 1, y: 1, width: 358, height: 218, fill: '#0d1117', stroke: '#30304a' }));

    const gapped = result && result.Rgap > 0;
    const core = [
      [70, 48, 220, 28],
      [70, 48, 28, 124],
      [70, 144, 220, 28],
      [262, 48, 28, 42],
      [262, 118, 28, 54]
    ];
    core.forEach(function (r) {
      const rect = svgEl('rect', {
        x: r[0], y: r[1], width: r[2], height: r[3],
        fill: '#1b2236', stroke: '#8b7bff', 'stroke-width': '2'
      });
      svg.appendChild(rect);
    });
    for (let i = 0; i < 7; i++) {
      svg.appendChild(svgEl('line', {
        x1: 76, y1: 54 + i * 16, x2: 92, y2: 54 + i * 16,
        stroke: '#4f8bff', 'stroke-width': '1', opacity: '0.55'
      }));
    }
    if (gapped) {
      svg.appendChild(svgEl('rect', {
        x: 258, y: 90, width: 36, height: 28, fill: '#0d1117', stroke: '#f5c451', 'stroke-width': '2'
      }));
      const gapLabel = svgEl('text', {
        x: 320, y: 108, fill: '#f5c451', 'font-size': '11', 'font-family': 'ui-monospace,monospace'
      });
      gapLabel.textContent = 'gap';
      svg.appendChild(gapLabel);
    } else {
      svg.appendChild(svgEl('rect', {
        x: 262, y: 90, width: 28, height: 28, fill: '#1b2236', stroke: '#8b7bff', 'stroke-width': '2'
      }));
    }

    svg.appendChild(svgEl('path', {
      d: 'M 92 62 H 248 V 158 H 92 Z',
      fill: 'none', stroke: '#60a5fa', 'stroke-width': '1.6', 'stroke-dasharray': '5 4'
    }));
    svg.appendChild(svgEl('polygon', { points: '248,58 256,62 248,66', fill: '#60a5fa' }));
    const flux = svgEl('text', {
      x: 170, y: 40, fill: '#60a5fa', 'font-size': '11', 'text-anchor': 'middle',
      'font-family': 'ui-monospace,monospace'
    });
    flux.textContent = 'Φ';
    svg.appendChild(flux);

    svg.appendChild(svgEl('rect', { x: 36, y: 78, width: 22, height: 64, fill: '#111326', stroke: '#6ee7b7', 'stroke-width': '1.6' }));
    for (let t = 0; t < 5; t++) {
      svg.appendChild(svgEl('ellipse', {
        cx: 47, cy: 88 + t * 11, rx: 14, ry: 5,
        fill: 'none', stroke: '#6ee7b7', 'stroke-width': '1.2'
      }));
    }
    const ni = svgEl('text', {
      x: 47, y: 158, fill: '#6ee7b7', 'font-size': '11', 'text-anchor': 'middle',
      'font-family': 'ui-monospace,monospace'
    });
    ni.textContent = 'N I';
    svg.appendChild(ni);

    const caption = svgEl('text', {
      x: 180, y: 204, fill: '#9497b8', 'font-size': '10', 'text-anchor': 'middle',
      'font-family': 'ui-sans-serif,sans-serif'
    });
    caption.textContent = gapped
      ? 'Laminated core, air gap, flux loop. Ampere: ∮ H·dℓ = NI'
      : 'Laminated core, closed steel loop. Ampere: ∮ H·dℓ = NI';
    svg.appendChild(caption);
    host.appendChild(svg);
  }

  function drawBPlot(result) {
    const host = el('mc_plot');
    if (!host) return;
    host.textContent = '';
    const samples = bVsNI(result, 40);
    if (!samples.length) return;
    const W = 360, H = 200, padL = 46, padR = 14, padT = 16, padB = 36;
    const svg = svgEl('svg', {
      viewBox: '0 0 ' + W + ' ' + H,
      width: '100%',
      role: 'img',
      'aria-label': 'Flux density versus NI. Linear because saturation is not modeled.'
    });
    svg.appendChild(svgEl('rect', { x: 1, y: 1, width: W - 2, height: H - 2, fill: '#0d1117', stroke: '#30304a' }));
    const nImax = samples[samples.length - 1].ni;
    const bMax = Math.max(result.bsat * 1.15, samples[samples.length - 1].B * 1.1, 0.2);
    const x = function (ni) { return padL + (ni / nImax) * (W - padL - padR); };
    const y = function (B) { return padT + (1 - B / bMax) * (H - padT - padB); };

    svg.appendChild(svgEl('line', { x1: padL, y1: padT, x2: padL, y2: H - padB, stroke: '#334155' }));
    svg.appendChild(svgEl('line', { x1: padL, y1: H - padB, x2: W - padR, y2: H - padB, stroke: '#334155' }));

    if (result.bsat > 0 && result.bsat < bMax) {
      svg.appendChild(svgEl('line', {
        x1: padL, y1: y(result.bsat), x2: W - padR, y2: y(result.bsat),
        stroke: '#ff8a8a', 'stroke-dasharray': '4 3', 'stroke-width': '1.2'
      }));
      const sat = svgEl('text', {
        x: W - padR - 2, y: y(result.bsat) - 4, fill: '#ff8a8a', 'font-size': '9',
        'text-anchor': 'end', 'font-family': 'ui-monospace,monospace'
      });
      sat.textContent = 'Bsat ' + fmtEng(result.bsat, 2, 'T');
      svg.appendChild(sat);
    }

    let d = '';
    samples.forEach(function (s, i) {
      d += (i ? ' L ' : 'M ') + x(s.ni).toFixed(1) + ' ' + y(s.B).toFixed(1);
    });
    svg.appendChild(svgEl('path', { d: d, fill: 'none', stroke: '#6ee7b7', 'stroke-width': '2' }));

    const op = svgEl('circle', {
      cx: x(Math.abs(result.F)).toFixed(1),
      cy: y(result.coreB).toFixed(1),
      r: 4, fill: '#f5c451', stroke: '#0d1117'
    });
    svg.appendChild(op);

    const xlab = svgEl('text', {
      x: W / 2, y: H - 8, fill: '#9497b8', 'font-size': '10', 'text-anchor': 'middle',
      'font-family': 'ui-sans-serif,sans-serif'
    });
    xlab.textContent = 'NI (A·t)  —  linear; saturation is a warning, not a B–H curve';
    svg.appendChild(xlab);
    const ylab = svgEl('text', {
      x: 12, y: 14, fill: '#9497b8', 'font-size': '10',
      'font-family': 'ui-monospace,monospace'
    });
    ylab.textContent = 'B (T)';
    svg.appendChild(ylab);
    host.appendChild(svg);
  }

  function calcMagneticCircuit() {
    updateMuFields();
    const input = readInputs();
    const result = solveMagneticCircuit(input);
    drawCoreDiagram(result && !result.error ? result : { Rgap: input.gap && input.gap.on ? 1 : 0 });
    if (result.error) {
      const plot = el('mc_plot');
      if (plot) plot.textContent = '';
      if (typeof showError === 'function') showError('mc_result', result.error);
      return;
    }

    const rows = [
      ['Network', result.network === 'parallel' ? 'Steel paths in parallel; gap in series' : 'Steel paths in series; gap in series'],
      ['MMF F = N I', fmtEng(result.F, 3, 'A·t')],
      ['Steel reluctance', fmtEng(result.Rsteel, 3, 'A·t/Wb')],
      ['Gap reluctance', result.Rgap > 0 ? fmtEng(result.Rgap, 3, 'A·t/Wb') : 'none'],
      ['Total reluctance Rtot', fmtEng(result.Rtot, 3, 'A·t/Wb')],
      ['Flux Φ = F / Rtot', fmtEng(result.flux, 3, 'Wb')]
    ];
    result.drops.forEach(function (leg) {
      rows.push([leg.label + ' — R', fmtEng(leg.R, 3, 'A·t/Wb')]);
      rows.push([leg.label + ' — Φ', fmtEng(leg.flux, 3, 'Wb')]);
      rows.push([leg.label + ' — B = Φ/A', fmtEng(leg.B, 3, 'T') + (leg.saturated ? '  (above Bsat)' : '')]);
      rows.push([leg.label + ' — H = B/μ', fmtEng(leg.H, 3, 'A/m')]);
      rows.push([leg.label + ' — MMF drop Φ R', fmtEng(leg.mmf, 3, 'A·t')]);
      if (leg.kind === 'gap' && leg.fringing) {
        rows.push(['Gap A_eff = (√A + k ℓ_g)²', fmtEng(leg.areaEffM2, 3, 'm²') + '  (k = ' + fmtEng(leg.k, 3, '') + ')']);
      }
    });
    const mmfLoop = result.network === 'series'
      ? result.drops.reduce(function (s, leg) { return s + leg.mmf; }, 0)
      : (function () {
          const steelDrop = result.drops.find(function (d) { return d.kind === 'steel'; });
          const gapDrop = result.drops.find(function (d) { return d.kind === 'gap'; });
          return (steelDrop ? steelDrop.mmf : 0) + (gapDrop ? gapDrop.mmf : 0);
        }());
    rows.push(['Ampere loop (one path + gap) Σ Hℓ', fmtEng(mmfLoop, 3, 'A·t')]);

    const notes = [
      'R = ℓ / (μ A), Φ = F / Rtot, B = Φ / A, H = B / μ. Ampere’s law around the loop: the MMF drops should sum to N I.',
      'Saturation is not modeled. If |B| exceeds the editable Bsat warning, the linear Φ = NI / R answer is no longer honest — use a B–H curve or a finite-element tool.',
      'Magdy F. Iskander, Electromagnetic Fields and Waves, 2nd ed., Waveland Press, 2013 (magnetic circuits discussion). Reluctance R = ℓ/(μA) and Ampere ∮ H·dℓ = NI are standard identities. Gap fringing uses A_eff = (√A + k ℓ_g)² with k yours to edit.'
    ];
    if (result.saturated) {
      notes.unshift('Core |B| is above Bsat = ' + fmtEng(result.bsat, 2, 'T') + '. Treat the numbers as a linear upper bound, not a saturated operating point.');
    }
    showNotes('mc_result', rows, notes);
    drawBPlot(result);
  }

  function loadMagneticCircuitExample() {
    setVal('mc_net', 'series');
    setVal('mc_core_l', '20');
    setVal('mc_core_l_u', 'cm');
    setVal('mc_core_a', '4');
    setVal('mc_core_a_u', 'cm2');
    setVal('mc_core_mu_mode', 'ur');
    setVal('mc_core_ur', '4000');
    setChecked('mc_gap_on', true);
    setVal('mc_gap_l', '1');
    setVal('mc_gap_l_u', 'mm');
    setChecked('mc_gap_same_a', true);
    setChecked('mc_gap_fringe', true);
    setVal('mc_gap_k', '1');
    setChecked('mc_x1_on', false);
    setChecked('mc_x2_on', false);
    setVal('mc_n', '200');
    setVal('mc_i', '2');
    setVal('mc_bsat', '1.5');
    updateMuFields();
    calcMagneticCircuit();
  }

  function wireLive() {
    const section = el('sec-magnetic-circuit');
    if (!section) return;
    const recalc = function () { calcMagneticCircuit(); };
    section.querySelectorAll('input, select').forEach(function (field) {
      field.addEventListener('input', recalc);
      field.addEventListener('change', recalc);
    });
    updateMuFields();
    calcMagneticCircuit();
    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-magnetic-circuit', 'magnetic-circuit', calcMagneticCircuit);
    }
    if (typeof registerReport === 'function') {
      registerReport('mc_result', {
        title: 'Magnetic Circuit Workbench',
        formula: function () {
          return 'R = ℓ / (μ A)   |   Φ = NI / Rtot   |   B = Φ / A   |   H = B / μ   |   Ampere: ∮ H·dℓ = NI';
        },
        codeRefs: function () {
          return [
            'Magdy F. Iskander, Electromagnetic Fields and Waves, 2nd ed., Waveland Press, 2013 (magnetic circuits discussion)',
            'Ampere’s law ∮ H · dℓ = NI',
            'Reluctance identity R = ℓ / (μ A)',
            'Gap fringing A_eff = (√A + k ℓ_g)² (editable k; saturation not modeled)'
          ];
        }
      });
    }
  }

  global.calcMagneticCircuit = calcMagneticCircuit;
  global.loadMagneticCircuitExample = loadMagneticCircuitExample;
  global.updateMagneticCircuitFields = updateMuFields;

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', wireLive);
    else wireLive();
  }
})(typeof window !== 'undefined' ? window : globalThis);
