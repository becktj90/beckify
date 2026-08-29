/* ============================================================================
   TRANSFORMER & CONDUCTOR SELECTION ENGINE
   ============================================================================
   Designs both sides of a transformer in one pass and shows its work:

     FLA        kVA x 1000 / V           (1-phase)
                kVA x 1000 / (sqrt3 x V) (3-phase)
     OCPD       NEC Table 450.3(B)
     Conductor  125% of FLA (215.2(A)/215.3), sized against Table 310.16 with
                ambient correction 310.15(B)(1) and bundling 310.15(C)(1),
                capped by the termination rating 110.14(C)
     EGC        Table 250.122, from the OCPD rating
     GEC        Table 250.66, from the derived secondary conductor (250.30(A)(5))
     Vd         Z = R cos(theta) + X sin(theta), Ch.9 Tables 8 and 9
     Conduit    Ch.9 Table 1 (40% fill) against Table 4 areas and Table 5
                conductor areas

   Every intermediate value is retained so the proof drawer can show the
   substitution rather than just the answer.
   ============================================================================ */

const XE_SQRT3 = Math.sqrt(3);

/** Thousands-separated integer. app.js's fmt() is decimal-oriented, and
    circular mils read better grouped. */
function xeInt(n) {
  return Math.round(n).toLocaleString('en-US');
}

/* Standard ANSI/NEMA dry-type ratings offered in the picker. */
const XE_STD_KVA = [15, 30, 45, 75, 112.5, 150, 225, 300, 500, 750, 1000, 1500, 2000, 2500];

/** Line current for a given kVA and voltage. */
function xeFla(kva, volts, phase) {
  const denom = phase === '3ph' ? XE_SQRT3 * volts : volts;
  return (kva * 1000) / denom;
}

/**
 * Smallest conductor whose derated ampacity carries `required` amps.
 * Returns the size plus every factor that shaped the decision.
 */
function xePickConductor(required, material, insulTemp, terminationTemp, ambientC, ccc) {
  const ambient = ambientCorrectionFactor(ambientC, insulTemp);
  const bundle = cccAdjustmentFactor(ccc);
  for (const size of WIRE_SIZE_ORDER) {
    const row = AMPACITY[material] && AMPACITY[material][size];
    if (!row) continue;
    const base = row[TEMP_COLUMN_INDEX[insulTemp]];
    const derated = base * ambient * bundle;
    const cap = row[TEMP_COLUMN_INDEX[terminationTemp]];
    const usable = Math.min(derated, cap);
    if (usable >= required) {
      return {
        size: size, base: base, ambient: ambient, bundle: bundle,
        derated: derated, terminationCap: cap, usable: usable,
        limitedBy: derated <= cap ? 'derating' : 'termination',
      };
    }
  }
  return null;
}

/** Effective impedance per 1000 ft at a given power factor. */
function xeImpedance(size, material, pf) {
  const r = DC_RESISTANCE[material] && DC_RESISTANCE[material][size];
  if (typeof r !== 'number') return null;
  const x = REACTANCE[size] || 0;
  return r * pf + x * Math.sqrt(Math.max(0, 1 - pf * pf));
}

/** Voltage drop volts and percent for one feeder. */
function xeVoltageDrop(size, material, phase, amps, lengthFt, pf, volts) {
  const z = xeImpedance(size, material, pf);
  if (z === null) return null;
  const mult = phase === '3ph' ? XE_SQRT3 : 2;
  const drop = (mult * amps * lengthFt * z) / 1000;
  return { z: z, volts: drop, percent: (drop / volts) * 100 };
}

/** Smallest trade size of `type` holding the bundle at 40% fill. */
function xeConduit(type, conductorCount, phaseSize, egcSize, insulation) {
  const table = INSULATION_TYPES[insulation] || INSULATION_TYPES.THHN;
  const phaseArea = table.areas[phaseSize];
  const egcArea = table.areas[egcSize];
  if (typeof phaseArea !== 'number' || typeof egcArea !== 'number') return null;
  const total = phaseArea * conductorCount + egcArea;
  const conduit = CONDUIT_TYPES[type];
  if (!conduit) return null;
  const order = CONDUIT_TRADE_ORDER.filter((t) => conduit.areas[t] !== undefined);
  const size = order.find((t) => conduit.areas[t] * 0.4 >= total);
  return {
    size: size || null,
    totalArea: total,
    conductorCount: conductorCount + 1,
    fillPercent: size ? (total / conduit.areas[size]) * 100 : null,
    conduitArea: size ? conduit.areas[size] : null,
  };
}

/** Conductors carried per run: ungrounded + neutral, EGC counted separately. */
function xeConductorsPerRun(phase, connection) {
  if (phase === '1ph') return 2;                 // 2 ungrounded, or line + neutral
  return connection === 'delta' ? 3 : 4;         // wye adds a neutral
}

/**
 * Designs one side of the transformer.
 * `ocpd` is the protective device ahead of these conductors, which sets the EGC.
 */
function xeDesignSide(opts) {
  const fla = xeFla(opts.kva, opts.volts, opts.phase);
  const required = fla * 1.25; // 215.2(A)(1) — 125% of the continuous load
  const cond = xePickConductor(required, opts.material, opts.insulTemp,
    opts.terminationTemp, opts.ambientC, opts.ccc);
  if (!cond) return { fla: fla, required: required, error: 'No conductor up to 1000 kcmil carries ' + fmt(required, 1) + ' A under these conditions.' };

  const vd = xeVoltageDrop(cond.size, opts.material, opts.phase, fla, opts.lengthFt, opts.pf, opts.volts);
  const egc = egcForOCPD(opts.ocpd, opts.material);
  const perRun = xeConductorsPerRun(opts.phase, opts.connection);
  const conduit = egc ? xeConduit(opts.conduitType, perRun, cond.size, egc.size, opts.insulation) : null;

  return {
    fla: fla,
    required: required,
    conductor: cond,
    vd: vd,
    egc: egc,
    conduit: conduit,
    conductorsPerRun: perRun,
  };
}

/* ---------------------------------------------------------------------------
   Main entry point
   --------------------------------------------------------------------------- */
window.calcXfmrEngine = function () {
  const el = wtClear('xe_result');
  if (!el) return;
  const proof = document.getElementById('xe_proof_body');
  if (proof) proof.textContent = '';

  const kvaSel = document.getElementById('xe_kva').value;
  const kva = kvaSel === 'custom' ? val('xe_kva_custom') : parseFloat(kvaSel);

  const priPhase = document.getElementById('xe_pri_phase').value;
  const priVolts = val('xe_pri_v');
  const priConn = document.getElementById('xe_pri_conn').value;
  const priLen = val('xe_pri_len');

  const secPhase = document.getElementById('xe_sec_phase').value;
  const secVolts = val('xe_sec_v');
  const secConn = document.getElementById('xe_sec_conn').value;
  const secLen = val('xe_sec_len');

  const material = document.getElementById('xe_material').value;
  const insulation = document.getElementById('xe_insulation').value;
  const conduitType = document.getElementById('xe_conduit').value;
  const ambientC = val('xe_ambient');
  const ccc = parseInt(document.getElementById('xe_ccc').value, 10);
  const pf = val('xe_pf') / 100;
  const insulTemp = INSULATION_TYPES[insulation] ? INSULATION_TYPES[insulation].tempRating : 90;
  const terminationTemp = parseInt(document.getElementById('xe_term').value, 10);
  const secondaryProtected = document.getElementById('xe_sec_protected').checked;

  if (!isPos(kva)) return showError('xe_result', 'Enter a transformer kVA greater than zero.');
  if (!isPos(priVolts)) return showError('xe_result', 'Enter a primary voltage greater than zero.');
  if (!isPos(secVolts)) return showError('xe_result', 'Enter a secondary voltage greater than zero.');
  if (!isPos(priLen) || !isPos(secLen)) return showError('xe_result', 'Enter both feeder lengths.');
  if (!isNum(ambientC)) return showError('xe_result', 'Enter an ambient temperature.');
  if (!isPos(pf) || pf > 1) return showError('xe_result', 'Power factor must be between 1 and 100 %.');

  /* ── Full load amps ── */
  const priFla = xeFla(kva, priVolts, priPhase);
  const secFla = xeFla(kva, secVolts, secPhase);

  /* ── Overcurrent protection, NEC Table 450.3(B) ──
     Primary-only protection is the stricter rule. Adding a secondary device
     lets the primary go to 250%, because the secondary device provides the
     closer protection. */
  let priTier, priCeiling, priOcpd, priRounding;
  if (secondaryProtected) {
    priTier = { pct: 250, note: 'Primary with secondary protection' };
    priCeiling = priFla * 2.5;
    priOcpd = STD_OCPD_RATINGS.filter((r) => r <= priCeiling).pop() || null;
    priRounding = 'Must not exceed the 250% ceiling';
  } else {
    priTier = xfmrPrimaryOnlyLimit(priFla);
    priCeiling = priFla * (priTier.pct / 100);
    priOcpd = priTier.roundUp
      ? nextStandardOCPD(priCeiling)
      : (STD_OCPD_RATINGS.filter((r) => r <= priCeiling).pop() || null);
    priRounding = priTier.roundUp
      ? 'Next standard size up permitted — 450.3(B) Note 1'
      : 'Ceiling, no round-up at this tier';
  }

  let secTier = null, secCeiling = null, secOcpd = null;
  if (secondaryProtected) {
    secTier = xfmrSecondaryLimit(secFla);
    secCeiling = secFla * (secTier.pct / 100);
    secOcpd = secTier.roundUp
      ? nextStandardOCPD(secCeiling)
      : (STD_OCPD_RATINGS.filter((r) => r <= secCeiling).pop() || null);
  }

  if (!priOcpd) {
    return showError('xe_result',
      'No standard overcurrent rating fits the ' + priTier.pct + '% primary ceiling of ' +
      fmt(priCeiling, 1) + ' A. Check the kVA and primary voltage.');
  }

  /* The secondary conductors are protected by the secondary device when there
     is one; otherwise the primary device is the only protection, so it sets
     the secondary EGC too. */
  const secProtectiveDevice = secOcpd || priOcpd;

  const common = {
    kva: kva, material: material, insulation: insulation, insulTemp: insulTemp,
    terminationTemp: terminationTemp, ambientC: ambientC, ccc: ccc, pf: pf,
    conduitType: conduitType,
  };

  const pri = xeDesignSide(Object.assign({}, common, {
    volts: priVolts, phase: priPhase, connection: priConn,
    lengthFt: priLen, ocpd: priOcpd,
  }));
  const sec = xeDesignSide(Object.assign({}, common, {
    volts: secVolts, phase: secPhase, connection: secConn,
    lengthFt: secLen, ocpd: secProtectiveDevice,
  }));

  if (pri.error) return showError('xe_result', 'Primary: ' + pri.error);
  if (sec.error) return showError('xe_result', 'Secondary: ' + sec.error);

  /* ── GEC for the separately derived system, Table 250.66 via 250.30(A)(5) ── */
  const secCmil = WIRE_CMIL[sec.conductor.size] || 0;
  const gec = gecForConductor(secCmil, material);

  /* ── Dashboard ── */
  el.className = 'result show';
  const matLabel = material === 'al' ? 'Al' : 'Cu';

  wtHeading(el, 'Transformer');
  wtRow(el, 'Rating', fmt(kva, 1) + ' kVA', { bold: true, color: PASS_COLOR });
  wtRow(el, 'Primary', fmt(priVolts) + ' V ' + (priPhase === '3ph' ? '3Ø' : '1Ø') + ' ' + priConn);
  wtRow(el, 'Secondary', fmt(secVolts) + ' V ' + (secPhase === '3ph' ? '3Ø' : '1Ø') + ' ' + secConn);
  wtRow(el, 'Turns ratio', fmt(priVolts / secVolts, 3) + ' : 1');
  wtRow(el, 'Protection method', secondaryProtected
    ? 'Primary + secondary — 450.3(B)'
    : 'Primary only — 450.3(B)');

  /* Side-by-side comparison table */
  const compare = [
    ['Full load amps', fmt(pri.fla, 1) + ' A', fmt(sec.fla, 1) + ' A'],
    ['Conductor @125%', fmt(pri.required, 1) + ' A', fmt(sec.required, 1) + ' A'],
    ['OCPD', priOcpd + ' A', secOcpd ? secOcpd + ' A' : 'none (primary only)'],
    ['Phase conductor', wireSizeLabel(pri.conductor.size) + ' ' + matLabel,
      wireSizeLabel(sec.conductor.size) + ' ' + matLabel],
    ['Usable ampacity', fmt(pri.conductor.usable, 1) + ' A', fmt(sec.conductor.usable, 1) + ' A'],
    ['EGC (250.122)', pri.egc ? wireSizeLabel(pri.egc.size) + ' ' + matLabel : '—',
      sec.egc ? wireSizeLabel(sec.egc.size) + ' ' + matLabel : '—'],
    ['Conduit (40% fill)',
      pri.conduit && pri.conduit.size ? pri.conduit.size + '" ' + conduitType : 'over 6"',
      sec.conduit && sec.conduit.size ? sec.conduit.size + '" ' + conduitType : 'over 6"'],
    ['Voltage drop', fmt(pri.vd.volts, 2) + ' V (' + fmt(pri.vd.percent, 2) + ' %)',
      fmt(sec.vd.volts, 2) + ' V (' + fmt(sec.vd.percent, 2) + ' %)'],
  ];

  wtHeading(el, 'Primary feed  vs  Secondary feed');
  compare.forEach(function (row) {
    const r = document.createElement('div');
    r.className = 'res-row xe-compare';
    const l = document.createElement('span');
    l.className = 'res-label';
    l.textContent = row[0];
    const a = document.createElement('span');
    a.className = 'res-val xe-pri';
    a.textContent = row[1];
    const bv = document.createElement('span');
    bv.className = 'res-val xe-sec';
    bv.textContent = row[2];
    r.appendChild(l); r.appendChild(a); r.appendChild(bv);
    el.appendChild(r);
  });

  wtHeading(el, 'Grounding');
  wtRow(el, 'GEC (250.66 via 250.30(A)(5))',
    gec ? wireSizeLabel(gec.size) + ' ' + matLabel : '—', { bold: true });
  wtRow(el, 'Sized from', 'Derived secondary conductor ' + wireSizeLabel(sec.conductor.size) +
    ' (' + xeInt(secCmil) + ' cmil)');

  /* Voltage-drop verdicts against the 3% / 5% informational guidance */
  const totalVd = pri.vd.percent + sec.vd.percent;
  wtHeading(el, 'Voltage drop check');
  wtRow(el, 'Primary feeder', fmt(pri.vd.percent, 2) + ' %',
    { color: pri.vd.percent <= 3 ? PASS_COLOR : WARN_COLOR });
  wtRow(el, 'Secondary feeder', fmt(sec.vd.percent, 2) + ' %',
    { color: sec.vd.percent <= 3 ? PASS_COLOR : WARN_COLOR });
  wtRow(el, 'Combined', fmt(totalVd, 2) + ' %',
    { bold: true, color: totalVd <= 5 ? PASS_COLOR : FAIL_COLOR });
  wtRow(el, 'Guidance', '3% per feeder, 5% total — 210.19(A) and 215.2(A) informational notes');

  /* Connection-specific cautions worth surfacing */
  const cautions = [];
  if (secConn === 'highleg') {
    cautions.push('High-leg delta: the B phase sits about 208 V to neutral on a 240 V system. ' +
      'It must be marked orange and cannot serve 120 V loads — NEC 110.15 and 230.56.');
  }
  if (secConn === 'corner') {
    cautions.push('Corner-grounded delta: one phase conductor is grounded, so overcurrent ' +
      'devices and disconnects must be arranged per 240.85, and that conductor is not switched.');
  }
  if (secConn === 'delta' && secPhase === '3ph') {
    cautions.push('An ungrounded or delta secondary has no neutral, so line-to-neutral loads ' +
      'are not available and ground detection should be considered.');
  }
  if (!secondaryProtected && secFla > priFla) {
    cautions.push('With primary-only protection the primary device must also protect the ' +
      'secondary conductors, which is only permitted under the conditions in 240.21(C) — ' +
      'check the secondary conductor rules before relying on it.');
  }
  if (cautions.length) {
    wtHeading(el, 'Design cautions');
    cautions.forEach(function (c) { wtNote(el, c); });
  }

  wtNote(el, 'Overcurrent limits from Table 450.3(B) protect the transformer. Conductors ' +
    'still need protection under Article 240, and secondary conductors under 240.21(C). ' +
    'Inrush may require a device with a suitable time-current curve.');

  buildProof({
    kva: kva, priVolts: priVolts, secVolts: secVolts, priPhase: priPhase, secPhase: secPhase,
    priFla: priFla, secFla: secFla, priTier: priTier, priCeiling: priCeiling, priOcpd: priOcpd,
    priRounding: priRounding, secTier: secTier, secCeiling: secCeiling, secOcpd: secOcpd,
    pri: pri, sec: sec, gec: gec, secCmil: secCmil, material: material, matLabel: matLabel,
    ambientC: ambientC, ccc: ccc, pf: pf, priLen: priLen, secLen: secLen,
    insulTemp: insulTemp, terminationTemp: terminationTemp, conduitType: conduitType,
    secondaryProtected: secondaryProtected, insulation: insulation,
  });

  if (typeof writeUrlState === 'function') writeUrlState('sec-xfmr-engine');

  appendCopyBtn(el);
};

/* ---------------------------------------------------------------------------
   Step-by-step proof
   --------------------------------------------------------------------------- */
function buildProof(d) {
  const host = document.getElementById('xe_proof_body');
  if (!host) return;
  host.textContent = '';

  const step = function (n, title, lines, ref) {
    const wrap = document.createElement('div');
    wrap.className = 'xe-step';
    const h = document.createElement('div');
    h.className = 'xe-step-head';
    h.textContent = n + '. ' + title;
    wrap.appendChild(h);
    lines.forEach(function (l) {
      const p = document.createElement('div');
      p.className = 'xe-step-line';
      p.textContent = l;
      wrap.appendChild(p);
    });
    if (ref) {
      const r = document.createElement('div');
      r.className = 'xe-step-ref';
      r.textContent = ref;
      wrap.appendChild(r);
    }
    host.appendChild(wrap);
  };

  const priDen = d.priPhase === '3ph' ? '√3 × ' + fmt(d.priVolts) : fmt(d.priVolts);
  const secDen = d.secPhase === '3ph' ? '√3 × ' + fmt(d.secVolts) : fmt(d.secVolts);

  step(1, 'Full load amps', [
    'Primary:   I = (' + fmt(d.kva, 1) + ' × 1000) / (' + priDen + ') = ' + fmt(d.priFla, 2) + ' A',
    'Secondary: I = (' + fmt(d.kva, 1) + ' × 1000) / (' + secDen + ') = ' + fmt(d.secFla, 2) + ' A',
  ], 'Transformer full-load current');

  const priOcpdLines = [
    'Tier: ' + d.priTier.pct + '% (' + d.priTier.note + ')',
    'Ceiling: ' + fmt(d.priFla, 2) + ' A × ' + (d.priTier.pct / 100) + ' = ' + fmt(d.priCeiling, 2) + ' A',
    'Device: ' + d.priOcpd + ' A — ' + d.priRounding,
  ];
  if (d.secondaryProtected && d.secTier) {
    priOcpdLines.push('Secondary tier: ' + d.secTier.pct + '% (' + d.secTier.note + ')');
    priOcpdLines.push('Secondary ceiling: ' + fmt(d.secFla, 2) + ' A × ' + (d.secTier.pct / 100) +
      ' = ' + fmt(d.secCeiling, 2) + ' A → ' + d.secOcpd + ' A');
  }
  step(2, 'Overcurrent protection', priOcpdLines, 'NEC Table 450.3(B), Note 1 for the round-up');

  step(3, 'Conductor ampacity required', [
    'Primary:   ' + fmt(d.pri.fla, 2) + ' A × 1.25 = ' + fmt(d.pri.required, 2) + ' A',
    'Secondary: ' + fmt(d.sec.fla, 2) + ' A × 1.25 = ' + fmt(d.sec.required, 2) + ' A',
  ], 'NEC 215.2(A)(1) — 125% of the continuous load');

  [['Primary', d.pri], ['Secondary', d.sec]].forEach(function (pair, i) {
    const side = pair[1];
    const c = side.conductor;
    step(4 + i, pair[0] + ' conductor selection', [
      'Trial size: ' + wireSizeLabel(c.size) + ' ' + d.matLabel,
      'Table 310.16 at ' + d.insulTemp + '°C: ' + c.base + ' A',
      'Ambient correction (' + fmt(d.ambientC, 0) + '°C): × ' + c.ambient.toFixed(2),
      'Bundling (' + d.ccc + ' current-carrying): × ' + c.bundle.toFixed(2),
      'Derated: ' + c.base + ' × ' + c.ambient.toFixed(2) + ' × ' + c.bundle.toFixed(2) +
        ' = ' + fmt(c.derated, 2) + ' A',
      'Termination cap at ' + d.terminationTemp + '°C: ' + c.terminationCap + ' A',
      'Usable = min(derated, cap) = ' + fmt(c.usable, 2) + ' A ≥ ' + fmt(side.required, 2) + ' A ✔',
      'Governed by: ' + (c.limitedBy === 'termination' ? 'the termination rating' : 'the derating factors'),
    ], 'NEC Table 310.16, 310.15(B)(1), 310.15(C)(1), 110.14(C)');
  });

  step(6, 'Equipment grounding conductors', [
    'Primary EGC from ' + d.priOcpd + ' A device: ' +
      (d.pri.egc ? wireSizeLabel(d.pri.egc.size) + ' ' + d.matLabel : '—'),
    'Secondary EGC from ' + (d.secOcpd || d.priOcpd) + ' A device: ' +
      (d.sec.egc ? wireSizeLabel(d.sec.egc.size) + ' ' + d.matLabel : '—'),
    'The EGC is sized from the overcurrent device ahead of the circuit, not from the phase conductor.',
  ], 'NEC Table 250.122');

  step(7, 'Grounding electrode conductor', [
    'Derived secondary conductor: ' + wireSizeLabel(d.sec.conductor.size) +
      ' = ' + xeInt(d.secCmil) + ' circular mils',
    'GEC: ' + (d.gec ? wireSizeLabel(d.gec.size) + ' ' + d.matLabel : '—'),
    'A transformer secondary is a separately derived system, so the GEC is sized ' +
      'from the derived ungrounded conductors.',
  ], 'NEC Table 250.66 via 250.30(A)(5)');

  [['Primary', d.pri, d.priLen, d.priVolts, d.priPhase],
   ['Secondary', d.sec, d.secLen, d.secVolts, d.secPhase]].forEach(function (pair, i) {
    const side = pair[1];
    const mult = pair[4] === '3ph' ? '√3' : '2';
    step(8 + i, pair[0] + ' voltage drop', [
      'Z = R·cosθ + X·sinθ = ' + fmt(side.vd.z, 5) + ' Ω per 1000 ft at PF ' + fmt(d.pf, 2),
      'ΔV = ' + mult + ' × ' + fmt(side.fla, 2) + ' A × ' + fmt(pair[2], 0) + ' ft × ' +
        fmt(side.vd.z, 5) + ' / 1000 = ' + fmt(side.vd.volts, 3) + ' V',
      '%ΔV = ' + fmt(side.vd.volts, 3) + ' / ' + fmt(pair[3], 0) + ' × 100 = ' +
        fmt(side.vd.percent, 2) + ' %',
    ], 'NEC Ch.9 Table 8 (resistance) and Table 9 (reactance)');
  });

  [['Primary', d.pri], ['Secondary', d.sec]].forEach(function (pair, i) {
    const cd = pair[1].conduit;
    if (!cd) return;
    step(10 + i, pair[0] + ' conduit', [
      pair[1].conductorsPerRun + ' phase/neutral conductors + 1 EGC = ' + cd.conductorCount + ' conductors',
      'Total area: ' + fmt(cd.totalArea, 4) + ' in² (Table 5, ' +
        (INSULATION_TYPES[d.insulation] || INSULATION_TYPES.THHN).label + ')',
      cd.size
        ? cd.size + '" ' + d.conduitType + ' internal area ' + fmt(cd.conduitArea, 3) +
          ' in², 40% allows ' + fmt(cd.conduitArea * 0.4, 4) + ' in² — actual fill ' +
          fmt(cd.fillPercent, 1) + ' %'
        : 'Exceeds the largest trade size in this raceway type',
    ], 'NEC Ch.9 Table 1 (40% for over 2 conductors), Table 4, Table 5');
  });
}

window.toggleXeProof = function () {
  const body = document.getElementById('xe_proof');
  const btn = document.getElementById('xe_proof_btn');
  if (!body) return;
  const open = body.hasAttribute('hidden');
  if (open) body.removeAttribute('hidden'); else body.setAttribute('hidden', '');
  if (btn) {
    btn.setAttribute('aria-expanded', String(open));
    btn.textContent = open ? '▾ Hide step-by-step proof' : '▸ Show step-by-step proof';
  }
};

/* URL state is handled by the shared binder in url-state.js, which mirrors
   every field of every calculator. Keeping a second bespoke implementation
   here would mean two writers racing over history.replaceState. */

window.toggleCustomKva = function toggleCustomKva() {
  const sel = document.getElementById('xe_kva');
  const wrap = document.getElementById('xe_kva_custom_wrap');
  if (!sel || !wrap) return;
  wrap.style.display = sel.value === 'custom' ? '' : 'none';
};

document.addEventListener('DOMContentLoaded', function () {
  if (!document.getElementById('xe_result')) return;
  toggleCustomKva();
  const sel = document.getElementById('xe_kva');
  if (sel) sel.addEventListener('change', toggleCustomKva);

  if (typeof registerReport === 'function') {
    registerReport('xe_result', {
      title: 'Transformer & Conductor Selection',
      formula: function () {
        return 'FLA = kVA x 1000 / (sqrt3 x V) for 3-phase, kVA x 1000 / V for 1-phase   |   ' +
          'Conductor = 125% of FLA against Table 310.16, x ambient x bundling, capped at the ' +
          'termination column   |   Vd: Z = R cos(theta) + X sin(theta)   |   Conduit at 40% fill';
      },
      codeRefs: function () {
        return [
          'NEC Table 450.3(B) — transformer overcurrent protection, 1000 V and less',
          'NEC 450.3(B) Note 1 — next standard size up where 125% is not a standard rating',
          'NEC 215.2(A)(1) — feeder conductors at 125% of the continuous load',
          'NEC Table 310.16 — allowable ampacity',
          'NEC 310.15(B)(1) — ambient temperature correction',
          'NEC 310.15(C)(1) — adjustment for more than three current-carrying conductors',
          'NEC 110.14(C) — termination temperature limitation',
          'NEC Table 250.122 — equipment grounding conductor sizing',
          'NEC Table 250.66 and 250.30(A)(5) — grounding electrode conductor for a separately derived system',
          'NEC Ch.9 Table 8 and Table 9 — conductor resistance and reactance',
          'NEC Ch.9 Tables 1, 4 and 5 — raceway fill',
          'NEC 240.21(C) — secondary conductor protection',
        ];
      },
    });
  }
});
