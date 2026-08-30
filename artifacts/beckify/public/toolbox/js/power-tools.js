/* ============================================================================
   POWER & TRANSFORMER TOOLS
   ============================================================================
   1. Power & Current Converter — solve any one of Amps / kW / kVA / HP from
      the others, on DC, single-phase or three-phase. Every result names the
      formula it came from.

   2. Transformer Sizing & Protection — pick a standard kVA for a load, then
      size overcurrent protection per NEC Table 450.3(B).

   Results are built with DOM methods and textContent, never innerHTML.
   ============================================================================ */

const SQRT3 = Math.sqrt(3);

/* ---------------------------------------------------------------------------
   POWER WIZARD WAVEFORM
   ---------------------------------------------------------------------------
   This is a teaching plot, not a measurement trace: voltage is the reference
   sine wave and current is shifted by theta = acos(PF).  A lower PF therefore
   produces a visible lag instead of another generic result graphic.
   --------------------------------------------------------------------------- */
window.updatePowerWizardWave = function () {
  const voltagePath = document.getElementById('power_wave_voltage');
  const currentPath = document.getElementById('power_wave_current');
  const caption = document.getElementById('power_wave_caption');
  const angleLabel = document.getElementById('power_wave_angle');
  const systemEl = document.getElementById('pc_system');
  if (!voltagePath || !currentPath || !systemEl) return;

  const system = systemEl.value;
  const pfInput = Number(document.getElementById('pc_pf')?.value);
  const pf = Math.max(0.01, Math.min(1, (Number.isFinite(pfInput) ? pfInput : 100) / 100));
  const theta = system === 'dc' ? 0 : Math.acos(pf);
  const start = 48;
  const end = 690;
  const center = 92;
  const amplitude = 42;
  const cycles = 2;
  const span = end - start;
  const pathFor = (phase) => {
    const points = [];
    for (let x = start; x <= end; x += 5) {
      const t = ((x - start) / span) * Math.PI * 2 * cycles;
      const y = center - Math.sin(t - phase) * amplitude;
      points.push(`${x.toFixed(1)},${y.toFixed(1)}`);
    }
    return `M ${points.join(' L ')}`;
  };

  if (system === 'dc') {
    voltagePath.setAttribute('d', `M ${start} ${center - amplitude} L ${end} ${center - amplitude}`);
    currentPath.setAttribute('d', `M ${start} ${center + amplitude} L ${end} ${center + amplitude}`);
    if (caption) caption.textContent = 'DC has no phase angle: voltage and current are steady values.';
    if (angleLabel) angleLabel.textContent = 'DC · θ = 0°';
    return;
  }

  voltagePath.setAttribute('d', pathFor(0));
  currentPath.setAttribute('d', pathFor(theta));
  const degrees = Math.round(theta * 180 / Math.PI);
  const systemLabel = system === '3ph' ? 'three-phase' : 'single-phase';
  if (caption) caption.textContent = `${systemLabel} AC · current lags voltage by ${degrees}° at PF ${Math.round(pf * 100)}%.`;
  if (angleLabel) angleLabel.textContent = `θ = ${degrees}°`;
};

document.addEventListener('DOMContentLoaded', function () {
  window.updatePowerWizardWave();
});

/* ---------------------------------------------------------------------------
   1. POWER & CURRENT CONVERTER
   ---------------------------------------------------------------------------
   DC        S = V x I                     (no power factor)
   1-phase   S = V x I,        P = S x PF
   3-phase   S = sqrt(3) x VL x IL,  P = S x PF

   Horsepower is motor SHAFT OUTPUT, so the electrical input is
   HP x 746 / efficiency. Mixing those up is the usual source of a
   motor-sizing error, so the two are kept distinct throughout.
   --------------------------------------------------------------------------- */

function pcPhaseMultiplier(system) {
  return system === '3ph' ? SQRT3 : 1;
}

function pcPhaseLabel(system) {
  return system === '3ph' ? '3-phase' : system === '1ph' ? '1-phase' : 'DC';
}

window.calcPowerConvert = function () {
  const el = wtClear('pc_result');
  if (!el) return;

  const system = document.getElementById('pc_system').value;
  const known = document.getElementById('pc_known').value;
  const value = val('pc_value');
  const voltage = val('pc_voltage');
  const pf = system === 'dc' ? 1 : val('pc_pf') / 100;
  const eff = val('pc_eff') / 100;

  if (!isPos(value)) return showError('pc_result', 'Enter a value greater than zero.');
  if (!isPos(voltage)) return showError('pc_result', 'Enter a voltage greater than zero.');
  if (system !== 'dc' && (!isPos(pf) || pf > 1)) {
    return showError('pc_result', 'Power factor must be between 1 and 100 %.');
  }
  if (known === 'hp' || document.getElementById('pc_eff').value !== '') {
    if (!isPos(eff) || eff > 1) {
      return showError('pc_result', 'Efficiency must be between 1 and 100 %.');
    }
  }

  const mult = pcPhaseMultiplier(system);
  const multText = system === '3ph' ? '√3 × ' : '';
  const phase = pcPhaseLabel(system);

  /* Everything is derived from apparent power (kVA) and real power (kW). */
  let amps, kva, kw, hp;
  let formula;

  if (known === 'a') {
    amps = value;
    kva = (mult * voltage * amps) / 1000;
    kw = kva * pf;
    formula = `kVA = ${multText}V × I ÷ 1000`;
  } else if (known === 'kva') {
    kva = value;
    amps = (kva * 1000) / (mult * voltage);
    kw = kva * pf;
    formula = `I = kVA × 1000 ÷ (${multText}V)`;
  } else if (known === 'kw') {
    kw = value;
    kva = kw / pf;
    amps = (kw * 1000) / (mult * voltage * pf);
    formula = `I = kW × 1000 ÷ (${multText}V × PF)`;
  } else {
    hp = value;
    // Shaft output -> electrical input.
    kw = (hp * 746) / (eff * 1000);
    kva = kw / pf;
    amps = (kw * 1000) / (mult * voltage * pf);
    formula = `I = HP × 746 ÷ (${multText}V × PF × Eff)`;
  }

  if (hp === undefined) hp = (kw * 1000 * eff) / 746;
  const kvar = Math.sqrt(Math.max(0, kva * kva - kw * kw));
  const theta = deg(Math.acos(Math.min(1, pf)));

  el.className = 'result show';

  wtHeading(el, 'Given');
  wtRow(el, 'System', phase + (system === 'dc' ? '' : `, PF ${fmt(pf * 100, 1)} %`));
  wtRow(el, 'Voltage', fmt(voltage) + ' V' + (system === '3ph' ? '  (line-to-line)' : ''));
  wtRow(el, 'Known value',
    fmt(value) + ' ' + (known === 'a' ? 'A' : known === 'kw' ? 'kW' : known === 'kva' ? 'kVA' : 'HP'));

  wtHeading(el, 'Results');
  wtRow(el, 'Current', fmt(amps, 2) + ' A', { bold: true, color: PASS_COLOR });
  wtRow(el, 'Apparent power', fmt(kva, 3) + ' kVA');
  wtRow(el, 'Real power', fmt(kw, 3) + ' kW');
  if (system !== 'dc') {
    wtRow(el, 'Reactive power', fmt(kvar, 3) + ' kVAR');
    wtRow(el, 'Phase angle θ', fmt(theta, 1) + '°');
  }
  wtRow(el, 'Motor horsepower', fmt(hp, 2) + ' HP' +
    (eff < 1 ? `  (shaft output at ${fmt(eff * 100, 0)} % eff)` : ''));

  wtHeading(el, 'Formula used');
  wtRow(el, 'Solved with', formula);
  wtRow(el, 'Apparent power', `kVA = ${multText}V × I ÷ 1000`);
  wtRow(el, 'Real power', 'kW = kVA × PF');
  wtRow(el, 'Horsepower', 'HP = kW × 1000 × Eff ÷ 746');

  wtNote(el,
    system === '3ph'
      ? 'Three-phase voltage is line-to-line and current is line current. Horsepower is shaft ' +
        'output, so efficiency converts between electrical input and mechanical output — for ' +
        'conductor sizing use the NEC Table 430.250 value, not a calculated FLA (NEC 430.6(A)(1)).'
      : 'Horsepower is shaft output, so efficiency converts between electrical input and ' +
        'mechanical output. For motor conductor sizing the NEC requires the table FLC from ' +
        'Article 430, not a calculated current (NEC 430.6(A)(1)).');

  appendCopyBtn(el);
};

/* ---------------------------------------------------------------------------
   2. TRANSFORMER SIZING & PROTECTION
   ---------------------------------------------------------------------------
   NEC Table 450.3(B) — maximum overcurrent protection for transformers rated
   1000 V or less. Two permitted methods:

   Primary protection only
     primary current >= 9 A ............ 125 %
     primary current 2 A to under 9 A .. 167 %
     primary current under 2 A ......... 300 %

   Primary and secondary protection
     primary ........................... 250 %
     secondary >= 9 A .................. 125 %
     secondary under 9 A ............... 167 %

   Note 1 permits the next higher standard rating from 240.6(A) where 125 %
   does not land on a standard size. That allowance applies to the 125 % rows,
   not to the 167 %/300 % rows, which are already ceilings.
   --------------------------------------------------------------------------- */

/* ANSI/NEMA standard dry-type ratings. */
const STD_XFMR_KVA = [
  1, 1.5, 2, 3, 5, 7.5, 10, 15, 25, 30, 37.5, 45, 50, 75, 100, 112.5, 150, 167,
  200, 225, 250, 300, 333, 400, 500, 750, 1000, 1500, 2000, 2500, 3000,
];

function xfmrPrimaryOnlyLimit(primaryAmps) {
  if (primaryAmps >= 9) return { pct: 125, note: 'Primary ≥ 9 A', roundUp: true };
  if (primaryAmps >= 2) return { pct: 167, note: 'Primary 2 A to under 9 A', roundUp: false };
  return { pct: 300, note: 'Primary under 2 A', roundUp: false };
}

function xfmrSecondaryLimit(secondaryAmps) {
  if (secondaryAmps >= 9) return { pct: 125, note: 'Secondary ≥ 9 A', roundUp: true };
  return { pct: 167, note: 'Secondary under 9 A', roundUp: false };
}

/** Largest standard OCPD at or below a ceiling. */
function largestStandardAtOrBelow(amps) {
  let best = null;
  for (const r of STD_OCPD_RATINGS) {
    if (r <= amps) best = r;
    else break;
  }
  return best;
}

window.calcXfmrSizing = function () {
  const el = wtClear('xs_result');
  if (!el) return;

  const phase = document.getElementById('xs_phase').value;
  const loadUnit = document.getElementById('xs_load_unit').value;
  const loadValue = val('xs_load');
  const vp = val('xs_vp');
  const vs = val('xs_vs');
  const continuous = document.getElementById('xs_continuous').checked;

  if (!isPos(loadValue)) return showError('xs_result', 'Enter a load greater than zero.');
  if (!isPos(vp)) return showError('xs_result', 'Enter a primary voltage greater than zero.');
  if (!isPos(vs)) return showError('xs_result', 'Enter a secondary voltage greater than zero.');

  const mult = phase === '3ph' ? SQRT3 : 1;
  const multText = phase === '3ph' ? '√3 × ' : '';

  /* Load in kVA. */
  let loadKva, loadBasis;
  if (loadUnit === 'kva') {
    loadKva = loadValue;
    loadBasis = 'Entered as kVA';
  } else if (loadUnit === 'kw') {
    const pf = val('xs_pf') / 100;
    if (!isPos(pf) || pf > 1) return showError('xs_result', 'Power factor must be between 1 and 100 %.');
    loadKva = loadValue / pf;
    loadBasis = `kVA = kW ÷ PF = ${fmt(loadValue)} ÷ ${fmt(pf, 2)}`;
  } else {
    loadKva = (mult * vs * loadValue) / 1000;
    loadBasis = `kVA = ${multText}V × I ÷ 1000`;
  }

  /* Continuous loads are sized at 125 % (NEC 210.19(A)/215.2(A)). */
  const designKva = continuous ? loadKva * 1.25 : loadKva;
  const selected = STD_XFMR_KVA.find((k) => k >= designKva);

  if (!selected) {
    return showError('xs_result',
      `A ${fmt(designKva, 1)} kVA load exceeds the largest standard rating in this list ` +
      `(${STD_XFMR_KVA[STD_XFMR_KVA.length - 1]} kVA). Use multiple units or a custom rating.`);
  }

  const ip = (selected * 1000) / (mult * vp);
  const is = (selected * 1000) / (mult * vs);

  /* Method 1 — primary protection only. */
  const p1 = xfmrPrimaryOnlyLimit(ip);
  const p1Ceiling = ip * (p1.pct / 100);
  const p1Device = p1.roundUp
    ? nextStandardOCPD(p1Ceiling)
    : largestStandardAtOrBelow(p1Ceiling);

  /* Method 2 — primary and secondary protection. */
  const p2Ceiling = ip * 2.5;
  const p2Device = largestStandardAtOrBelow(p2Ceiling);
  const s2 = xfmrSecondaryLimit(is);
  const s2Ceiling = is * (s2.pct / 100);
  const s2Device = s2.roundUp
    ? nextStandardOCPD(s2Ceiling)
    : largestStandardAtOrBelow(s2Ceiling);

  el.className = 'result show';

  wtHeading(el, 'Load');
  wtRow(el, 'Connected load', fmt(loadKva, 2) + ' kVA');
  wtRow(el, 'Basis', loadBasis);
  if (continuous) wtRow(el, 'Continuous ×1.25', fmt(designKva, 2) + ' kVA', { bold: true });

  wtHeading(el, 'Transformer');
  wtRow(el, 'Standard rating', selected + ' kVA', { bold: true, color: PASS_COLOR });
  wtRow(el, 'Spare capacity',
    fmt(((selected - designKva) / selected) * 100, 1) + ' %  (' + fmt(selected - designKva, 2) + ' kVA)');
  wtRow(el, 'Connection', pcPhaseLabel(phase) + ', ' + fmt(vp) + ' V → ' + fmt(vs) + ' V');
  wtRow(el, 'Primary FLA', fmt(ip, 2) + ' A', { bold: true });
  wtRow(el, 'Secondary FLA', fmt(is, 2) + ' A', { bold: true });
  wtRow(el, 'Turns ratio', fmt(vp / vs, 3) + ' : 1');

  wtHeading(el, 'Method 1 — primary protection only');
  wtRow(el, 'Table 450.3(B) limit', p1.pct + ' %  (' + p1.note + ')');
  wtRow(el, 'Calculated ceiling', fmt(p1Ceiling, 1) + ' A');
  wtRow(el, 'Primary OCPD',
    p1Device ? p1Device + ' A' : 'No standard rating fits',
    { bold: true, color: p1Device ? PASS_COLOR : FAIL_COLOR });
  wtRow(el, 'Rounding', p1.roundUp
    ? 'Next standard size up permitted — 450.3(B) Note 1'
    : 'Must not exceed the ceiling — no round-up at this tier');

  wtHeading(el, 'Method 2 — primary and secondary protection');
  wtRow(el, 'Primary limit', '250 %  →  ceiling ' + fmt(p2Ceiling, 1) + ' A');
  wtRow(el, 'Primary OCPD', p2Device ? p2Device + ' A' : 'No standard rating fits',
    { bold: true, color: p2Device ? PASS_COLOR : FAIL_COLOR });
  wtRow(el, 'Secondary limit', s2.pct + ' %  (' + s2.note + ')  →  ceiling ' + fmt(s2Ceiling, 1) + ' A');
  wtRow(el, 'Secondary OCPD', s2Device ? s2Device + ' A' : 'No standard rating fits',
    { bold: true, color: s2Device ? PASS_COLOR : FAIL_COLOR });

  wtHeading(el, 'Conductor minimum ampacity');
  wtRow(el, 'Primary conductors', fmt(ip * 1.25, 1) + ' A  (125 % of primary FLA)');
  wtRow(el, 'Secondary conductors', fmt(is * 1.25, 1) + ' A  (125 % of secondary FLA)');

  wtNote(el,
    'Overcurrent limits are the maxima in NEC Table 450.3(B) for transformers rated 1000 V ' +
    'or less, and they protect the transformer only — conductors still need their own ' +
    'protection under Article 240, and secondary conductors under 240.21(C). Method 2 lets ' +
    'the primary device go to 250 % because the secondary device provides the closer ' +
    'protection. Overcurrent protection is not the same as short-circuit and ground-fault ' +
    'protection, and inrush may require a device with a suitable time-current curve.');

  appendCopyBtn(el);
};
