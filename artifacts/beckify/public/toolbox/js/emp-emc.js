/* ============================================================================
   EMP / EMC SHIELDING — protection-side educational calculator
   ============================================================================
   Faraday-loop coupling, aperture leakage, skin-depth / barrier estimates, and
   published incident *environments* a shield or SPD is specified against.

   This file is a shielding and victim-circuit education tool. It does not
   design pulse sources or weapons. Do not add source-side circuitry or
   targeting examples here.
   ============================================================================ */
(function (global) {
  'use strict';

  const MU0 = 4 * Math.PI * 1e-7;
  const C0 = 299792458;
  const SIGMA_CU = 5.80e7;

  const LEN = { m: 1, km: 1000, cm: 0.01, mm: 0.001, in: 0.0254, ft: 0.3048, mil: 2.54e-5 };
  const AREA = { m2: 1, cm2: 1e-4, mm2: 1e-6, in2: 6.4516e-4, ft2: 0.09290304 };
  const BUNIT = { T: 1, mT: 1e-3, uT: 1e-6, nT: 1e-9, G: 1e-4 };
  const TIME = { s: 1, ms: 1e-3, us: 1e-6, ns: 1e-9 };
  const FREQ = { Hz: 1, kHz: 1e3, MHz: 1e6, GHz: 1e9 };
  const DBDT = { 'T/s': 1, 'T/ms': 1e3, 'T/us': 1e6, 'mT/us': 1e3 };

  const MATERIALS = {
    cu: {
      id: 'cu',
      name: 'Copper',
      sigma: 5.80e7,
      muR: 1,
      note: 'Annealed copper near 20 °C (standard EE / CRC order of magnitude).'
    },
    al: {
      id: 'al',
      name: 'Aluminum',
      sigma: 3.77e7,
      muR: 1,
      note: 'Commercial aluminum near 20 °C.'
    },
    'steel-lf': {
      id: 'steel-lf',
      name: 'Mild steel (low-frequency μr)',
      sigma: 1.0e7,
      muR: 200,
      note: 'Typical annealed mild-steel order of magnitude. μr varies (≈50–1000) and saturates. Optimistic at RF if μr has already collapsed.'
    },
    'steel-rf': {
      id: 'steel-rf',
      name: 'Mild steel (RF, μr collapsed)',
      sigma: 1.0e7,
      muR: 1,
      note: 'Pessimistic RF bound: same conductivity, μr ≈ 1 after permeability collapse. Use this when the low-frequency μr case looks too good.'
    }
  };

  /* Published incident environments a cage, bond, or SPD is designed against.
     Values are open-literature summaries, not a classified waveform library
     and not instructions for producing the field. */
  const ENVIRONMENTS = {
    esd: {
      id: 'esd',
      name: 'ESD contact discharge',
      citation: 'IEC 61000-4-2, Level 4 contact (8 kV)',
      kind: 'current',
      coupling: 'none',
      peakI: 30,
      riseS: 0.8e-9,
      durationS: 60e-9,
      note: 'Published immunity-test current into a defined target. Coupling is local and geometry-specific; this tool reports bandwidth and skin depth, not a free-space plane-wave voltage.'
    },
    surge: {
      id: 'surge',
      name: 'Combination-wave surge (SPD test)',
      citation: 'IEC 61000-4-5; lightning-related impulse family also used with IEC 62305 SPD coordination',
      kind: 'surge',
      coupling: 'none',
      riseS: 1.2e-6,
      durationS: 50e-6,
      currentRiseS: 8e-6,
      currentDurationS: 20e-6,
      note: 'Laboratory combination wave used to specify surge-protective devices (1.2/50 μs open-circuit voltage, 8/20 μs short-circuit current). Not a radiated-field model.'
    },
    lightning: {
      id: 'lightning',
      name: 'Lightning first short stroke (downconductor)',
      citation: 'IEC 62305-1 LPL I first short stroke (100 kA, 10/350 μs)',
      kind: 'current',
      coupling: 'line',
      peakI: 100e3,
      riseS: 10e-6,
      durationS: 350e-6,
      note: 'Published lightning-protection current for bonding, SPD selection, and loop-area control near a downconductor (IEC 62305-4). Quasi-static B ≈ μ₀ I / (2π r) when the loop is electrically small.'
    },
    lightning_sub: {
      id: 'lightning_sub',
      name: 'Lightning subsequent stroke (downconductor)',
      citation: 'IEC 62305-1 subsequent short stroke (50 kA, 0.25/100 μs)',
      kind: 'current',
      coupling: 'line',
      peakI: 50e3,
      riseS: 0.25e-6,
      durationS: 100e-6,
      note: 'Faster front than the first stroke, so induced voltage in a nearby victim loop is often larger even though the peak current is smaller.'
    },
    hemp_e1: {
      id: 'hemp_e1',
      name: 'HEMP E1 (early-time, published waveform family)',
      citation: 'IEC 61000-2-9 early-time HEMP; IEC 61000-4-25 immunity taxonomy (open summaries)',
      kind: 'efield',
      coupling: 'plane',
      peakE: 50e3,
      riseS: 2.5e-9,
      durationS: 23e-9,
      note: 'Published incident-field environment used to specify shields, filters, and cable-entry protection. This tool applies Faraday’s law to a victim loop in that incident field. It does not address sources.'
    },
    hemp_e2: {
      id: 'hemp_e2',
      name: 'HEMP E2 (intermediate, lightning-like family)',
      citation: 'IEC 61000-2-9 intermediate-time HEMP (open summaries)',
      kind: 'efield',
      coupling: 'plane',
      peakE: 100,
      riseS: 1e-6,
      durationS: 1e-3,
      note: 'Open-literature intermediate-time family: much lower peak E than E1, longer duration, often compared with nearby-lightning E-fields for SPD and bonding practice. Representative values, not a test-lab library.'
    },
    solar: {
      id: 'solar',
      name: 'Solar GMD / HEMP E3-like geoelectric',
      citation: 'NERC TPL-007 planning order-of-magnitude; IEC 61000-2-9 late-time (E3) taxonomy',
      kind: 'geoelectric',
      coupling: 'line-e',
      peakE: 0.01,
      riseS: 60,
      durationS: 600,
      note: 'Quasi-DC geoelectric field on long conductors (volts per kilometre). Thin Faraday cages do not address geomagnetically induced currents on utility or long-grounded paths. Series capacitors, GIC blocking, and transformer thermal margins are the usual protection discussion.'
    }
  };

  function convert(value, table, unit) {
    const factor = table[unit];
    if (!isFinite(value) || factor == null) return NaN;
    return value * factor;
  }

  function skinDepth(sigma, muR, freqHz) {
    if (!(sigma > 0) || !(muR > 0) || !(freqHz > 0)) return NaN;
    return 1 / Math.sqrt(Math.PI * freqHz * MU0 * muR * sigma);
  }

  function absorptionDb(thicknessM, deltaM) {
    if (!(thicknessM > 0) || !(deltaM > 0)) return NaN;
    return 8.686 * (thicknessM / deltaM);
  }

  function planeWaveReflectionDb(sigma, muR, freqHz) {
    if (!(sigma > 0) || !(muR > 0) || !(freqHz > 0)) return NaN;
    const sigmaR = sigma / SIGMA_CU;
    return 168.2 + 10 * Math.log10(sigmaR / (muR * freqHz));
  }

  function multipleReflectionDb(tOverDelta) {
    if (!(tOverDelta > 0)) return NaN;
    if (tOverDelta >= 1) return 0;
    const x = Math.exp(-2 * tOverDelta);
    if (!(x < 1)) return -Infinity;
    return 20 * Math.log10(1 - x);
  }

  function shieldEstimate(sigma, muR, thicknessM, freqHz) {
    const delta = skinDepth(sigma, muR, freqHz);
    const tOver = thicknessM / delta;
    const A = absorptionDb(thicknessM, delta);
    const R = planeWaveReflectionDb(sigma, muR, freqHz);
    const B = multipleReflectionDb(tOver);
    return { delta: delta, tOver: tOver, A: A, R: R, B: B, SE: A + R + B };
  }

  function loopAreaM2(shape, dim1, dim2) {
    if (shape === 'area') return dim1 > 0 ? dim1 : NaN;
    if (shape === 'rect') return dim1 > 0 && dim2 > 0 ? dim1 * dim2 : NaN;
    if (shape === 'circle') return dim1 > 0 ? Math.PI * dim1 * dim1 : NaN;
    return NaN;
  }

  function dBdtFromDeltaB(deltaB, riseS) {
    if (!(riseS > 0) || !isFinite(deltaB)) return NaN;
    return Math.abs(deltaB) / riseS;
  }

  function inducedVoltage(turns, areaM2, dBdt) {
    if (!(turns > 0) || !(areaM2 > 0) || !isFinite(dBdt)) return NaN;
    return turns * areaM2 * Math.abs(dBdt);
  }

  function equivFreqFromRise(riseS) {
    if (!(riseS > 0)) return NaN;
    return 0.35 / riseS;
  }

  function wavelength(freqHz) {
    if (!(freqHz > 0)) return NaN;
    return C0 / freqHz;
  }

  function apertureSE(slotM, freqHz, depthM) {
    const lambda = wavelength(freqHz);
    const halfWave = lambda / 2;
    if (!(slotM > 0) || !(lambda > 0)) {
      return { lambda: NaN, halfWave: NaN, SE: NaN, extraDb: 0, totalDb: NaN, regime: 'invalid' };
    }
    let SE = 0;
    let regime = 'half-wave or longer — treat as an open aperture at this frequency';
    if (slotM < halfWave) {
      SE = 20 * Math.log10(halfWave / slotM);
      regime = slotM > lambda / 10
        ? 'electrically noticeable slot (ℓ > λ/10); shielding is already reduced'
        : 'electrically small slot (ℓ < λ/10); this term is only the slot penalty, not a complete cage';
    }
    let extraDb = 0;
    const fc = C0 / (2 * slotM);
    if (depthM > 0 && freqHz < fc) {
      extraDb = 27.3 * (depthM / slotM) * Math.sqrt(1 - (freqHz / fc) * (freqHz / fc));
    }
    return { lambda: lambda, halfWave: halfWave, SE: SE, extraDb: extraDb, totalDb: SE + extraDb, regime: regime, fc: fc };
  }

  function bFromEPlaneWave(eVm) {
    if (!isFinite(eVm)) return NaN;
    return eVm / C0;
  }

  function bFromLineCurrent(iA, rM) {
    if (!(rM > 0) || !isFinite(iA)) return NaN;
    return MU0 * iA / (2 * Math.PI * rM);
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

  function fmtArea(m2) {
    if (!isFinite(m2)) return '—';
    if (Math.abs(m2) >= 0.01) return parseFloat(m2.toFixed(4)).toString() + ' m²';
    if (Math.abs(m2) >= 1e-6) return parseFloat((m2 * 1e4).toFixed(3)).toString() + ' cm²';
    return m2.toExponential(3) + ' m²';
  }

  function fmtDb(n) {
    if (!isFinite(n)) return '—';
    return n.toFixed(1) + ' dB';
  }

  const EmpEmc = {
    MU0: MU0,
    C0: C0,
    SIGMA_CU: SIGMA_CU,
    LEN: LEN,
    AREA: AREA,
    BUNIT: BUNIT,
    TIME: TIME,
    FREQ: FREQ,
    DBDT: DBDT,
    MATERIALS: MATERIALS,
    ENVIRONMENTS: ENVIRONMENTS,
    convert: convert,
    skinDepth: skinDepth,
    absorptionDb: absorptionDb,
    planeWaveReflectionDb: planeWaveReflectionDb,
    multipleReflectionDb: multipleReflectionDb,
    shieldEstimate: shieldEstimate,
    loopAreaM2: loopAreaM2,
    dBdtFromDeltaB: dBdtFromDeltaB,
    inducedVoltage: inducedVoltage,
    equivFreqFromRise: equivFreqFromRise,
    wavelength: wavelength,
    apertureSE: apertureSE,
    bFromEPlaneWave: bFromEPlaneWave,
    bFromLineCurrent: bFromLineCurrent,
    fmtEng: fmtEng,
    fmtArea: fmtArea,
    fmtDb: fmtDb
  };

  global.EmpEmc = EmpEmc;

  function el(id) {
    return document.getElementById(id);
  }

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

  function setVal(id, value) {
    const node = el(id);
    if (node) node.value = value;
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

  function toggle(id, on) {
    const node = el(id);
    if (!node) return;
    node.hidden = !on;
  }

  function activePane() {
    const section = el('sec-emp-emc');
    if (!section) return '';
    const pane = section.querySelector('.tab-pane.active');
    return pane ? pane.id : 'tab-emp-loop';
  }

  function updateLoopFields() {
    const shape = sel('emp_loop_shape');
    toggle('emp_loop_dim2_wrap', shape === 'rect');
    const a = el('emp_loop_a_label');
    const unit = el('emp_loop_len_unit_wrap');
    const areaUnit = el('emp_loop_area_unit_wrap');
    if (a) {
      a.textContent = shape === 'area' ? 'Loop area' : shape === 'circle' ? 'Loop radius' : 'Width';
    }
    if (unit) unit.hidden = shape === 'area';
    if (areaUnit) areaUnit.hidden = shape !== 'area';
    const mode = sel('emp_loop_mode');
    toggle('emp_loop_dbdt_fields', mode === 'dbdt');
    toggle('emp_loop_deltab_fields', mode === 'deltab');
  }

  function updateApertureFields() {
    const mode = sel('emp_ap_mode');
    toggle('emp_ap_freq_fields', mode === 'freq');
    toggle('emp_ap_rise_fields', mode === 'rise');
  }

  function updateSkinFields() {
    const mode = sel('emp_sk_mode');
    toggle('emp_sk_freq_fields', mode === 'freq');
    toggle('emp_sk_rise_fields', mode === 'rise');
  }

  function updateEnvFields() {
    const env = ENVIRONMENTS[sel('emp_env_id')] || ENVIRONMENTS.hemp_e1;
    toggle('emp_env_dist_wrap', env.coupling === 'line');
    toggle('emp_env_line_wrap', env.coupling === 'line-e');
    toggle('emp_env_loop_wrap', env.coupling === 'plane' || env.coupling === 'line');
  }

  function loopAreaFromForm() {
    const shape = sel('emp_loop_shape');
    if (shape === 'area') return convert(num('emp_loop_a'), AREA, sel('emp_loop_area_unit'));
    const d1 = convert(num('emp_loop_a'), LEN, sel('emp_loop_len_unit'));
    const d2 = convert(num('emp_loop_b'), LEN, sel('emp_loop_len_unit'));
    return loopAreaM2(shape, d1, d2);
  }

  function calcLoop() {
    updateLoopFields();
    const area = loopAreaFromForm();
    const turns = num('emp_loop_n');
    const mode = sel('emp_loop_mode');
    let dBdt = NaN;
    let deltaB = NaN;
    let rise = NaN;
    if (mode === 'dbdt') {
      dBdt = convert(num('emp_loop_dbdt'), DBDT, sel('emp_loop_dbdt_unit'));
    } else {
      deltaB = convert(num('emp_loop_db'), BUNIT, sel('emp_loop_db_unit'));
      rise = convert(num('emp_loop_tr'), TIME, sel('emp_loop_tr_unit'));
      dBdt = dBdtFromDeltaB(deltaB, rise);
    }
    if (!(area > 0)) return showError('emp_loop_result', 'Enter a victim-loop area greater than zero.');
    if (!(turns > 0)) return showError('emp_loop_result', 'Turns must be greater than zero.');
    if (!(dBdt > 0)) return showError('emp_loop_result', 'Enter a positive dB/dt, or a ΔB with a positive rise time.');
    const volts = inducedVoltage(turns, area, dBdt);
    const rLoop = num('emp_loop_r');
    const rows = [
      ['Victim loop area', fmtArea(area)],
      ['|dB/dt|', fmtEng(dBdt, 3, 'T/s')],
      ['Induced |V| = N A |dB/dt|', fmtEng(volts, 3, 'V')]
    ];
    if (mode === 'deltab') {
      rows.splice(1, 0, ['|ΔB|', fmtEng(deltaB, 3, 'T')]);
      rows.splice(2, 0, ['Rise time', fmtEng(rise, 3, 's')]);
      rows.splice(3, 0, ['Equivalent bandwidth ≈ 0.35 / t_r', fmtEng(equivFreqFromRise(rise), 3, 'Hz')]);
    }
    const notes = [
      'Faraday’s law for a uniform field normal to the loop: V = −N dΦ/dt, Φ = B A. Sign is omitted; the magnitude is what a protection check uses.',
      'This is a victim-circuit estimate for an existing loop. It does not design a pulsed source.'
    ];
    if (rLoop > 0) {
      rows.push(['Resistive |I| ≈ V / R (L ignored)', fmtEng(volts / rLoop, 3, 'A')]);
      notes.push('Current ignores loop inductance. For a fast front, L di/dt usually limits the current; V/R is only a long-pulse / DC upper bound.');
    } else {
      notes.push('Optional loop resistance yields a rough I = V/R. Leave it blank if you only need induced voltage.');
    }
    showNotes('emp_loop_result', rows, notes);
  }

  function apertureFrequency() {
    if (sel('emp_ap_mode') === 'freq') return convert(num('emp_ap_freq'), FREQ, sel('emp_ap_freq_unit'));
    return equivFreqFromRise(convert(num('emp_ap_tr'), TIME, sel('emp_ap_tr_unit')));
  }

  function calcAperture() {
    updateApertureFields();
    const slot = convert(num('emp_ap_len'), LEN, sel('emp_ap_len_unit'));
    const freq = apertureFrequency();
    const depth = convert(num('emp_ap_thick'), LEN, sel('emp_ap_thick_unit'));
    if (!(slot > 0)) return showError('emp_ap_result', 'Enter the longest slot or seam dimension.');
    if (!(freq > 0)) return showError('emp_ap_result', 'Enter a frequency or a positive rise time.');
    const result = apertureSE(slot, freq, isFinite(depth) && depth > 0 ? depth : 0);
    const rows = [
      ['Longest opening ℓ', fmtEng(slot, 3, 'm')],
      ['Frequency used', fmtEng(freq, 3, 'Hz')],
      ['Wavelength λ = c / f', fmtEng(result.lambda, 3, 'm')],
      ['Half-wave length λ/2', fmtEng(result.halfWave, 3, 'm')],
      ['ℓ / (λ/2)', (slot / result.halfWave).toFixed(3)],
      ['Slot term 20 log₁₀((λ/2)/ℓ)', result.SE <= 0 ? '0 dB (at or above half-wave)' : fmtDb(result.SE)]
    ];
    if (result.extraDb > 0) {
      rows.push(['Waveguide-below-cutoff extra (depth)', fmtDb(result.extraDb)]);
      rows.push(['Combined opening estimate', fmtDb(result.totalDb)]);
      rows.push(['Cutoff f_c ≈ c / (2ℓ)', fmtEng(result.fc, 3, 'Hz')]);
    }
    showNotes('emp_ap_result', rows, [
      result.regime + '.',
      'Assumptions: one rectangular slot in an otherwise continuous conducting wall, far-field / worst-dimension rule of thumb (Ott / White / NASA RP-1368 style). Gaskets, multiple seams, transfer impedance, and cable entries are not included and usually dominate a real enclosure.',
      'A rise time is converted with f ≈ 0.35 / t_r (10–90% bandwidth rule of thumb). That is a spectral-content estimate for the victim environment, not a source-design formula.'
    ]);
  }

  function skinFrequency() {
    if (sel('emp_sk_mode') === 'freq') return convert(num('emp_sk_freq'), FREQ, sel('emp_sk_freq_unit'));
    return equivFreqFromRise(convert(num('emp_sk_tr'), TIME, sel('emp_sk_tr_unit')));
  }

  function calcSkin() {
    updateSkinFields();
    const mat = MATERIALS[sel('emp_sk_mat')] || MATERIALS.cu;
    const thick = convert(num('emp_sk_t'), LEN, sel('emp_sk_t_unit'));
    const freq = skinFrequency();
    if (!(thick > 0)) return showError('emp_sk_result', 'Enter a barrier thickness greater than zero.');
    if (!(freq > 0)) return showError('emp_sk_result', 'Enter a frequency or a positive rise time.');
    const est = shieldEstimate(mat.sigma, mat.muR, thick, freq);
    const rows = [
      ['Material', mat.name],
      ['σ', fmtEng(mat.sigma, 3, 'S/m')],
      ['μr', String(mat.muR)],
      ['Frequency', fmtEng(freq, 3, 'Hz')],
      ['Skin depth δ = 1 / √(π f μ σ)', fmtEng(est.delta, 3, 'm')],
      ['t / δ', est.tOver.toFixed(3)],
      ['Absorption A ≈ 8.686 t/δ', fmtDb(est.A)],
      ['Plane-wave reflection R (far-field)', fmtDb(est.R)],
      ['Thin-sheet correction B', est.tOver >= 1 ? '0 dB (t ≥ δ)' : fmtDb(est.B)],
      ['Sheet SE ≈ A + R + B', fmtDb(est.SE)]
    ];
    showNotes('emp_sk_result', rows, [
      mat.note,
      'Schelkunoff infinite-sheet estimate for a good conductor in a far-field (plane-wave) wave. Near-field magnetic (low-Z) shielding is much weaker, especially in non-magnetic metals. Apertures, seams, and cable-entry transfer impedance usually set the real enclosure number.',
      'This is an educational design aid, not an IEEE 299 / MIL-STD chamber measurement and not a PE stamp.'
    ]);
  }

  function calcEnv() {
    updateEnvFields();
    const env = ENVIRONMENTS[sel('emp_env_id')];
    if (!env) return showError('emp_env_result', 'Choose a published environment name.');
    const freq = equivFreqFromRise(env.riseS);
    const rows = [
      ['Environment (shield / SPD target)', env.name],
      ['Citation', env.citation]
    ];
    if (env.kind === 'efield') {
      rows.push(['Published peak E (incident)', fmtEng(env.peakE, 3, 'V/m')]);
      rows.push(['Far-field B = E / c', fmtEng(bFromEPlaneWave(env.peakE), 3, 'T')]);
    }
    if (env.kind === 'current') {
      rows.push(['Published peak current', fmtEng(env.peakI, 3, 'A')]);
    }
    if (env.kind === 'surge') {
      rows.push(['Open-circuit voltage front / tail', '1.2 / 50 μs']);
      rows.push(['Short-circuit current front / tail', '8 / 20 μs']);
    }
    if (env.kind === 'geoelectric') {
      rows.push(['Representative geoelectric E', fmtEng(env.peakE, 3, 'V/m') + ' (' + fmtEng(env.peakE * 1000, 3, 'V/km') + ')']);
    }
    rows.push(['Characteristic rise time', fmtEng(env.riseS, 3, 's')]);
    if (env.durationS) rows.push(['Characteristic duration', fmtEng(env.durationS, 3, 's')]);
    rows.push(['Equivalent bandwidth ≈ 0.35 / t_r', fmtEng(freq, 3, 'Hz')]);
    const cuDelta = skinDepth(MATERIALS.cu.sigma, 1, freq);
    if (cuDelta > 0) rows.push(['Copper skin depth at that f', fmtEng(cuDelta, 3, 'm')]);

    const notes = [
      env.note,
      'These numbers describe an incident environment a shield, bond, or SPD is designed against. They are not a recipe for producing the field.'
    ];

    if (env.coupling === 'plane') {
      const area = convert(num('emp_env_area'), AREA, sel('emp_env_area_unit'));
      const turns = num('emp_env_n') > 0 ? num('emp_env_n') : 1;
      if (area > 0) {
        const B = bFromEPlaneWave(env.peakE);
        const dBdt = dBdtFromDeltaB(B, env.riseS);
        const volts = inducedVoltage(turns, area, dBdt);
        rows.push(['Victim loop area', fmtArea(area)]);
        rows.push(['|dB/dt| ≈ B / t_r', fmtEng(dBdt, 3, 'T/s')]);
        rows.push(['Unshielded loop |V|', fmtEng(volts, 3, 'V')]);
        notes.push('Plane-wave conversion B = E/c assumes a far-field TEM wave in free space, uniform over the loop, and no enclosure. Use it to size loop area and decide whether a cage / filter is required — not to design a source.');
      }
    } else if (env.coupling === 'line') {
      const area = convert(num('emp_env_area'), AREA, sel('emp_env_area_unit'));
      const turns = num('emp_env_n') > 0 ? num('emp_env_n') : 1;
      const dist = convert(num('emp_env_dist'), LEN, sel('emp_env_dist_unit'));
      if (area > 0 && dist > 0) {
        const B = bFromLineCurrent(env.peakI, dist);
        const dBdt = dBdtFromDeltaB(B, env.riseS);
        const volts = inducedVoltage(turns, area, dBdt);
        rows.push(['Loop-to-downconductor distance', fmtEng(dist, 3, 'm')]);
        rows.push(['Quasi-static |B| = μ₀ I / (2π r)', fmtEng(B, 3, 'T')]);
        rows.push(['|dB/dt| ≈ B / t_r', fmtEng(dBdt, 3, 'T/s')]);
        rows.push(['Victim loop |V|', fmtEng(volts, 3, 'V')]);
        notes.push('Valid only while the loop is electrically small and r is not so small that the wire radius or channel physics matter. IEC 62305-4 uses this class of estimate to keep bonding loops small near downconductors.');
      } else {
        notes.push('Enter a victim-loop area and the distance from the loop to the downconductor to estimate induced voltage. Distance is a bonding/layout input, not a targeting range.');
      }
    } else if (env.coupling === 'line-e') {
      const length = convert(num('emp_env_line'), LEN, sel('emp_env_line_unit'));
      if (length > 0) {
        rows.push(['Long-conductor length', fmtEng(length, 3, 'm')]);
        rows.push(['Induced |V| ≈ E × length', fmtEng(env.peakE * length, 3, 'V')]);
        notes.push('This is a long-line geoelectric product, not a small Faraday loop. A room-size cage does not remove GICs from a grounded utility path that leaves the building.');
      }
    }

    showNotes('emp_env_result', rows, notes);
  }

  function calcEmpEmc() {
    const pane = activePane();
    if (pane === 'tab-emp-aperture') return calcAperture();
    if (pane === 'tab-emp-skin') return calcSkin();
    if (pane === 'tab-emp-env') return calcEnv();
    return calcLoop();
  }

  function loadEmpEmcExample() {
    setVal('emp_loop_shape', 'rect');
    setVal('emp_loop_a', '10');
    setVal('emp_loop_b', '10');
    setVal('emp_loop_len_unit', 'cm');
    setVal('emp_loop_n', '1');
    setVal('emp_loop_mode', 'deltab');
    setVal('emp_loop_db', '1');
    setVal('emp_loop_db_unit', 'mT');
    setVal('emp_loop_tr', '1');
    setVal('emp_loop_tr_unit', 'us');
    setVal('emp_loop_r', '10');
    const loopTab = document.querySelector('#sec-emp-emc [data-tab="tab-emp-loop"]');
    if (loopTab) loopTab.click();
    updateLoopFields();
    calcLoop();
  }

  function wireLive() {
    const section = el('sec-emp-emc');
    if (!section) return;
    const recalc = function () { calcEmpEmc(); };
    section.querySelectorAll('input, select').forEach(function (field) {
      field.addEventListener('input', recalc);
      field.addEventListener('change', recalc);
    });
    section.addEventListener('click', function (event) {
      if (event.target.closest('.tab-btn')) recalc();
    });
    ['emp_loop_shape', 'emp_loop_mode'].forEach(function (id) {
      const node = el(id);
      if (node) node.addEventListener('change', updateLoopFields);
    });
    const apMode = el('emp_ap_mode');
    if (apMode) apMode.addEventListener('change', updateApertureFields);
    const skMode = el('emp_sk_mode');
    if (skMode) skMode.addEventListener('change', updateSkinFields);
    const envId = el('emp_env_id');
    if (envId) envId.addEventListener('change', updateEnvFields);
    updateLoopFields();
    updateApertureFields();
    updateSkinFields();
    updateEnvFields();
    calcEmpEmc();
  }

  global.calcEmpEmc = calcEmpEmc;
  global.calcEmpLoop = calcLoop;
  global.calcEmpAperture = calcAperture;
  global.calcEmpSkin = calcSkin;
  global.calcEmpEnv = calcEnv;
  global.loadEmpEmcExample = loadEmpEmcExample;
  global.updateEmpLoopFields = updateLoopFields;

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', wireLive);
    else wireLive();
  }
})(typeof window !== 'undefined' ? window : globalThis);
