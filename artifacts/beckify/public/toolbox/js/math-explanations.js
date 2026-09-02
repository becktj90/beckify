/* Shared teaching and documentation layer for the static toolbox. */
(function () {
  'use strict';

  const LESSONS = {
    'sec-ohm': ['Think of a circuit as a water slide', 'V = I R', 'Voltage is the push, resistance is the narrowness of the slide, and current is how much charge gets through each second. Change any one and the other two have to balance.'],
    'sec-magnetic-circuit': ['Flux is current for magnetics', '\\Phi = \\frac{NI}{R} \\quad R = \\frac{\\ell}{\\mu A}', 'Ampere’s loop is an MMF budget: turns times amps have to cover every H·ℓ drop. Reluctance is the magnetic analog of resistance, and an air gap usually dominates the sum.'],
    'sec-transient-circuits': ['Energy storage makes time', '\\tau = RC \\quad \\text{or} \\quad L/R', 'A capacitor cannot jump voltage and an inductor cannot jump current. First-order circuits forget exponentially; add the second storage element and you get over, critical, or underdamped ringing.'],
    'sec-phasor-diagram': ['Sine waves become arrows', 'Z = R + j\\omega L + 1/(j\\omega C)', 'In steady-state AC every derivative is a ninety-degree rotation. Draw the arrows, read θ off the diagram, and power factor is just cos θ.'],
    'sec-semiconductor-iv': ['A junction is an exponential valve', 'I = I_s(e^{v/\\eta V_T}-1)', 'A diode barely conducts until the exponential wakes up. MOSFETs switch by inverting a channel; BJTs set collector current from a much smaller base current.'],
    'sec-fiber-link': ['A fiber is a light pipe with a cone', 'NA = \\sqrt{n_1^2-n_2^2}', 'Rays steeper than the core-cladding critical angle leak. From air, that cone is the numerical aperture. Loss in dB just adds.'],
    'sec-gaussian-beam': ['A laser beam has a waist', 'z_R = \\pi w_0^2/\\lambda', 'The 1/e² radius is smallest at the waist and flares as a hyperbola. One Rayleigh range later the spot is √2 wider and the wavefronts are most curved.'],
    'sec-stem-tools': ['STEM tools are stories about change', "y' = \\frac{dy}{dt} \\quad \\text{and} \\quad \\Delta x \\approx v\\,\\Delta t", 'A derivative is a speedometer for a quantity. Each solver takes a small step, asks what the world is doing right now, and uses that local answer to predict the next step.'],
    'sec-circuit-sim': ['Kirchhoff is the traffic rule', '\\sum I_{in} = \\sum I_{out}', 'Charge cannot pile up at an ordinary node. The solver adjusts node voltages until every junction has balanced traffic.'],
    'sec-555': ['A capacitor is a bucket for charge', 'I = C\\frac{dV}{dt}', 'A capacitor resists sudden voltage changes because its stored charge must arrive through a finite current. That is why RC circuits make time.'],
    'sec-tdr': ['A TDR is radar for copper', 'd = \\frac{VF\\,c\\,t}{2}', 'The pulse travels out, notices a change in the cable, and returns. The divide-by-two matters because the measured time includes both trips.'],
    'sec-emp-emc': ['A changing field writes a voltage on a loop', 'V = -N\\,d\\Phi/dt', 'Faraday’s law is why a cable loop inside a changing B field picks up a transient. Shrink the loop, close the slots, bond the cage, and filter the cable entry. This tool sizes protection — it does not design a source.'],
    'sec-lp-optimizer': ['A linear program is a hill inside a fence', '\\max\\, c\\cdot x \\quad \\text{s.t.} \\quad Ax \\le b,\\, x \\ge 0', 'Each inequality is a fence. The simplex method walks the corners of the fenced yard until the objective cannot climb any further — or reports that the yard is empty or has no highest point.'],
    'sec-base-converter': ['Every integer is a weighted pile of digits', 'n = \\sum d_i b^i', 'Hex, decimal, octal, and binary are the same integer written with different digit alphabets. Two’s complement just rereads the high bit as a minus sign.']
  };

  const DOCS = {
    'sec-smith-chart': {
      overview: 'The Smith Chart is a graphical calculator used to design and analyze High Frequency (RF) transmission lines and antenna matching networks. Instead of calculating complex impedance math (Z = R + jX) by hand, it visualizes input impedance, standing wave ratios (SWR), and power reflection coefficients (Γ) on a normalized circular grid.',
      steps: [
        'Normalize system impedance: divide the target load impedance (ZL) by the characteristic impedance Z0, usually 50 Ω or 75 Ω.',
        'Plot the load point using normalized resistance on the horizontal axis and normalized reactance on the upper or lower arcs.',
        'Read reflection coefficient Γ, VSWR, and return loss from the plotted distance to the chart center.',
        'Apply matching components and rotate toward the center point (1 + j0) to approach a perfect match.'
      ],
      examples: ['System impedance (Z0): 50 Ω', 'Load resistance (R): 25 Ω', 'Load reactance (X): +j50 Ω (inductive)', 'Normalized impedance: 0.5 + j1.0'],
      button: { label: 'Load Example Values', action: 'loadSmithChartDocExample' }
    },
    'sec-vdrop': {
      overview: 'Electric current moving through a conductor encounters internal resistance, causing a loss in voltage between the power source and the load. This calculator determines the total voltage lost across a run so you can stay inside NEC recommendations of 3% branch-circuit drop and 5% combined feeder plus branch drop.',
      steps: [
        'Select the system type and supply voltage for a single-phase or three-phase circuit.',
        'Enter the current and one-way conductor length for the run.',
        'Choose the conductor material and wire size so the tool can apply the correct conductor constants.',
        'Review voltage drop, percentage drop, and remaining terminal voltage before accepting the design.'
      ],
      examples: ['System: 3-Phase, 480 V', 'Load current: 45 A', 'One-way conductor length: 250 ft', 'Conductor: #4 AWG Copper in PVC conduit'],
      button: { label: 'Load Example Values', action: 'loadVoltageDropExample' }
    },
    'sec-conduit': {
      overview: 'Overcrowding electrical raceways leads to heat buildup and damaged insulation. This guide compares the total conductor area against conduit interior area so you can stay inside NEC fill limits, especially the common 40% ceiling for three or more conductors.',
      steps: [
        'Choose the raceway or conduit type that matches the installation.',
        'Add conductors with the correct size, insulation type, and quantity, including the equipment grounding conductor.',
        'Let the tool sum conductor areas and compare them against the selected trade size or recommend the smallest size that works.',
        'Check the resulting fill percentage and verify it stays at or below the allowed limit.'
      ],
      examples: ['Raceway type: EMT', 'Conductors: 3× #3/0 AWG THHN (phase) + 1× #3/0 AWG THHN (neutral) + 1× #6 AWG THHN (ground)', 'Target limit: ≤ 40% maximum fill'],
      button: { label: 'Load Example Values', action: 'loadConduitFillExample' }
    },
    'sec-xfmr-size': {
      overview: 'Step-down transformers must be sized to handle connected continuous and non-continuous loads without thermal overload. This engine converts connected load into kVA demand, applies continuous-load factors, and compares the result with standard transformer ratings.',
      steps: [
        'Enter the primary and secondary voltages for the transformer.',
        'Choose whether the connected load is entered in kVA, kW, or secondary amperes.',
        'Apply the continuous-load multiplier when appropriate so the demand reflects NEC sizing practice.',
        'Compare the calculated load against standard transformer sizes and review the resulting FLA and overcurrent options.'
      ],
      examples: ['Primary voltage: 480 V AC (3-Phase)', 'Secondary voltage: 208Y/120 V AC (3-Phase)', 'Connected load: 38 kW continuous at 0.9 power factor (42.2 kVA)', 'Recommended standard size: 45 kVA'],
      button: { label: 'Load Example Values', action: 'loadTransformerSizingExample' }
    },
    'sec-bess': {
      overview: 'Commercial BESS units shave peak utility demand charges by discharging stored energy during high-consumption windows and recharging during off-peak periods. The quick sizer estimates required kWh from shaved kW and peak-window duration, while the optimizer below still helps allocate limited battery and solar power across critical loads.',
      steps: [
        'Enter the facility peak demand and the demand ceiling you want to hold.',
        'Set the peak-window duration and the target depth of discharge for usable battery energy.',
        'Review the required usable and installed battery capacity from the quick sizer.',
        'Optionally use the optimizer below to decide which loads to keep energized when total battery and solar power are constrained.'
      ],
      examples: ['Facility peak demand: 450 kW', 'Target demand limit: 300 kW', 'Peak window duration: 3 hours', 'Target DoD: 80%', 'Sized BESS capacity: 562.5 kWh total (450 kWh usable)'],
      button: { label: 'Load Example Values', action: 'loadBessPeakShaveExample' }
    },
    'sec-lsi': {
      overview: 'Selective coordination helps the protective device closest to a fault open first so the rest of the facility stays energized. This LSI visualizer turns long-time, short-time, and instantaneous settings into an easy-to-read time-current curve.',
      steps: [
        'Set the breaker frame or sensor rating as your reference current.',
        'Enter long-time pickup and delay to represent the overload region.',
        'Enter short-time pickup and delay so you can visualize coordination with upstream devices.',
        'Set the instantaneous pickup and review how the curve clears high-magnitude faults.'
      ],
      examples: ['Breaker frame rating: 800 A', 'Long-time pickup: 800 A, delay: 10 s', 'Short-time pickup: 3200 A, delay: 0.2 s', 'Instantaneous pickup: 6400 A'],
      button: { label: 'Load Example Values', action: 'loadLsiExample' }
    },
    'sec-555': {
      overview: 'The 555 Timer IC is a foundational timing building block for oscillators and one-shot pulses. This calculator turns resistor and capacitor values into output frequency, pulse width, and duty cycle for both astable and monostable modes.',
      steps: [
        'Choose astable mode for a repeating waveform or monostable mode for a one-shot pulse.',
        'Enter timing resistor and capacitor values with the correct units.',
        'Run the calculation to read high time, low time, pulse width, period, frequency, and duty cycle.',
        'Compare the numeric results with the waveform sketch to confirm the timing behavior looks reasonable.'
      ],
      examples: ['Astable example: R1 = 10 kΩ', 'R2 = 47 kΩ', 'C1 = 0.1 µF', 'Calculated output: f ≈ 138.4 Hz, duty cycle ≈ 54.8%'],
      button: { label: 'Load Example Values', action: 'load555DocExample' }
    },
    'sec-emp-emc': {
      overview: 'A changing magnetic field through any existing loop of wire writes an induced voltage. Enclosures leak at their longest slot, and a metal wall only looks thick compared with skin depth at the frequencies that matter. This calculator is a protection-side teaching aid: Faraday’s law for a victim loop, a worst-dimension aperture term, a Schelkunoff sheet estimate, and published incident environments (ESD, surge, lightning, solar GMD, HEMP E1/E2/E3 taxonomy) used to specify cages and SPDs.',
      steps: [
        'Start with Induced voltage. Enter the victim-loop area, turns, and either ΔB with rise time or dB/dt. Read |V| = N A |dB/dt|.',
        'Use Aperture leakage to compare the longest slot with λ/2. If the slot is half-wave or longer at the frequency of interest, treat that wall as open.',
        'Use Skin depth / barrier for a seamless-sheet upper bound. Real cabinets are almost always aperture- and cable-limited.',
        'Optionally pick a published environment name to see the incident-field or current a shield or SPD is designed against, then apply Faraday’s law to your loop where that model is valid.'
      ],
      examples: ['Victim loop: 10 cm × 10 cm, 1 turn', 'ΔB = 1 mT, rise time = 1 µs', 'Induced |V| = 10 V', 'Optional R = 10 Ω → long-pulse |I| ≈ 1 A (inductance ignored)'],
      button: { label: 'Load Example Values', action: 'loadEmpEmcExample' }
    },
    'sec-lp-optimizer': {
      overview: 'Linear programming finds the best feasible point of a linear objective over linear constraints. This educational optimizer uses two-phase simplex on ordinary operations-research models (product mix, blending, graphical 2-variable LPs). It is not related to EMP sources or shielding.',
      steps: [
        'Choose Maximize or Minimize and set the number of variables and constraints.',
        'Enter objective coefficients, optional upper bounds, and each constraint row A_i x {≤, ≥, =} b.',
        'Watch the formulation statement update as you type — the solver recomputes live.',
        'For two variables, read the feasible-region plot (vertices, constraint lines, optimum). For n variables, read the labelled status, z*, x*, and slack.'
      ],
      examples: ['Maximize 5 x1 + 4 x2', '6 x1 + 4 x2 ≤ 24', 'x1 + 2 x2 ≤ 6', 'x1, x2 ≥ 0', 'Optimum (3, 1.5), z* = 21'],
      button: { label: 'Load Graphical Example', action: 'loadLpOptimizerExample' }
    },
    'sec-base-converter': {
      overview: 'Hexadecimal, decimal, octal, and binary are the same integer in four alphabets. Place-value chips show n = Σ d_i b^i, and the bit field groups bits into nibbles and bytes. Optional two’s-complement signed decimal rereads the high bit as sign.',
      steps: [
        'Pick a bit width (8, 16, 32, or 64) and optionally enable two’s-complement signed decimal.',
        'Type a value in any base — the other three fields update immediately, wrapping at 2^w.',
        'Read the identity line and the place-value chips for the base you last edited.',
        'Use the bit field to flip individual bits; changed bits are highlighted.'
      ],
      examples: ['8-bit two’s complement', 'Hex FF', 'Unsigned decimal 255', 'Signed decimal −1', 'Binary 1111 1111'],
      button: { label: 'Load Signed Example (FF = −1)', action: 'loadBaseConverterExample' }
    },
    'sec-magnetic-circuit': {
      overview: 'A magnetic circuit turns Ampere’s loop into an Ohm’s-law analog: MMF F = N I, flux Φ, and reluctance R = ℓ / (μ A). This workbench is homework magnetostatics for a gapped laminated core — not a transformer kVA sizer.',
      steps: [
        'Enter the core length, area, and μr (or μ). Pick series or parallel for extra steel paths.',
        'Optionally enable the air gap. Fringing uses A_eff = (√A + k ℓg)² with k yours to edit.',
        'Set turns N and winding current I. Read Rtot, Φ = NI / Rtot, B, H, and the MMF drop on each leg.',
        'Check that the MMF drops sum to N I (Ampere). Treat Bsat as a warning — saturation is not modeled.'
      ],
      examples: ['Core: ℓ = 20 cm, A = 4 cm², μr = 4000', 'Gap: 1 mm, same area, fringing k = 1', 'N = 200, I = 2 A', 'Φ = NI / (Rsteel + Rgap), B = Φ / A'],
      button: { label: 'Load Example Values', action: 'loadMagneticCircuitExample' }
    },
    'sec-transient-circuits': {
      overview: 'Lumped first-order RC/RL and second-order RLC transients in closed form. Source-step or source-free. This is time-domain homework, not the resonance (f0/Q/BW) calculator and not the MNA circuit simulator.',
      steps: [
        'Pick RC, RL, series RLC, or parallel RLC, then source-step or source-free.',
        'Enter R, L, C with SI prefixes, the source value, and vC(0) / iL(0).',
        'Read τ or α, ω0, ωd, the damping case, and the closed-form v(t) or i(t).',
        'Use the waveform markers for 10–90% rise and ~2% settling. Change the t range to zoom.'
      ],
      examples: ['Series RLC step: R = 10 Ω, L = 10 mH, C = 1 µF, Vs = 10 V', 'vC(0) = 0, iL(0) = 0', 'α = R/(2L) = 500 /s, ω0 = 10 krad/s → underdamped', 'Waveform drawn from the closed form, not a captured scope shot'],
      button: { label: 'Load Example Values', action: 'loadTransientExample' }
    },
    'sec-phasor-diagram': {
      overview: 'Steady-state AC phasors for a series or parallel R-L-C plus a source. Live voltage or current triangle, polar RMS, θ, PF, and S = V I*. A balanced Δ-Y panel converts ZΔ ↔ Zy with ZΔ = 3 Zy.',
      steps: [
        'Choose series or parallel. Enter frequency, R, L, C, and Vs as RMS or peak.',
        'Read I, VR, VL, VC in RMS polar, then θ, PF, and S/P/Q. Lead vs lag follows the sign of Q.',
        'The SVG diagram keeps Vs on the real axis so the triangle is the homework sketch.',
        'Use the Δ-Y panel for balanced impedance conversion only — not the three-phase kVA wizard.'
      ],
      examples: ['Series: 60 Hz, R = 10 Ω, L = 10 mH, C = 100 µF, Vs = 120 V RMS', 'Z = R + jωL + 1/(jωC)', 'S = Vrms Irms*', 'Balanced Δ-Y: ZΔ = 3 Zy'],
      button: { label: 'Load Example Values', action: 'loadPhasorExample' }
    },
    'sec-semiconductor-iv': {
      overview: 'Homework device curves: Shockley diode with optional series Rs, npn β-forced Q-point, and long-channel NMOS cutoff / triode / sat. Not the op-amp / filter workbench and not a SPICE deck.',
      steps: [
        'Pick Diode, BJT, or NMOS. Enter Is, η, T and optional Rs — or Vcc/Rc/Rb/β — or μCox, W/L, Vt.',
        'The I-V SVG redraws as you type. Read the operating point and the region name.',
        'Treat saturation, Early voltage, and λ as first-order sketches, not a process card.'
      ],
      examples: ['Diode: Is = 1 nA, η = 1, T = 300 K, V = 0.65 V', 'BJT: Vcc = 5 V, Rc = 1 kΩ, Rb = 100 kΩ, β = 100', 'NMOS: μCox = 200 µA/V², W/L = 10, Vt = 0.7 V'],
      button: { label: 'Load Example Values', action: 'loadSemiconductorExample' }
    },
    'sec-fiber-link': {
      overview: 'Step-index NA, acceptance angle, and a first-order optical power budget. Not photometrics and not a TDR.',
      steps: [
        'Enter core n1 and cladding n2 (n1 > n2). Read NA, Δ, and θa.',
        'Set length, α in dB/km, source dBm, connector/splice lumps, and receiver sensitivity.',
        'Margin ≥ 0 dB means the first-order budget closes.'
      ],
      examples: ['n1 = 1.48, n2 = 1.46', '2 km at 0.3 dB/km', 'Pin = 0 dBm, two 0.3 dB connectors, one 0.1 dB splice', 'Sensitivity −20 dBm'],
      button: { label: 'Load Example Values', action: 'loadFiberExample' }
    },
    'sec-gaussian-beam': {
      overview: 'TEM00 free-space envelope: Rayleigh range, spot, curvature, confocal parameter. Not a thin-lens imager and not a double-slit.',
      steps: [
        'Enter λ and waist w0 with SI prefixes, then the observation z.',
        'Read zR = π w0² / λ, w(z), R(z), b = 2 zR, and the far-field half-angle.',
        'The SVG is an original envelope with waist and ±zR marks — not a traced publisher figure.'
      ],
      examples: ['HeNe-ish: λ = 633 nm, w0 = 50 µm', 'z = 10 mm', 'zR = π w0² / λ'],
      button: { label: 'Load Example Values', action: 'loadGaussianExample' }
    }
  };

  function texFallback(tex) {
    const esc = (value) => String(value).replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
    let html = esc(tex.trim());
    html = html.replace(/\\frac\{([^{}]+)\}\{([^{}]+)\}/g, '<span class="tex-frac"><span>$1</span><span>$2</span></span>');
    html = html.replace(/\\text\{([^{}]+)\}/g, '<span class="tex-text">$1</span>');
    html = html.replace(/\\quad/g, '<span class="tex-space"></span>');
    html = html.replace(/\\,/g, '<span class="tex-thin-space"></span>');
    html = html.replace(/\\Delta/g, '&Delta;').replace(/\\sum/g, '&sum;');
    html = html.replace(/\\max/g, 'max');
    html = html.replace(/\\cdot/g, '&middot;');
    html = html.replace(/\\le/g, '&le;');
    html = html.replace(/\\ge/g, '&ge;');
    return html;
  }

  function renderFormula(formula) {
    const tex = formula.dataset.tex || formula.textContent.replace(/^\$\$|\$\$$/g, '').trim();
    formula.dataset.tex = tex;
    formula.innerHTML = texFallback(tex);
    if (window.MathJax && typeof window.MathJax.typesetPromise === 'function') {
      formula.textContent = '$$' + tex + '$$';
      window.MathJax.typesetPromise([formula]).catch(() => {});
    }
  }

  function loadMathJax() {
    if (document.querySelector('script[data-beckify-mathjax]')) return;
    window.MathJax = { tex: { inlineMath: [['$', '$']], displayMath: [['$$', '$$']] }, startup: { typeset: false } };
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js';
    script.async = true;
    script.dataset.beckifyMathjax = '1';
    script.onload = () => document.querySelectorAll('.feynman-formula').forEach(renderFormula);
    script.onerror = () => {};
    document.head.appendChild(script);
  }

  function addLesson(section) {
    const lesson = LESSONS[section.id];
    if (!lesson || section.querySelector('.feynman-lesson')) return;
    const card = document.createElement('aside');
    card.className = 'feynman-lesson';
    const title = document.createElement('div');
    title.className = 'feynman-lesson-title';
    title.textContent = lesson[0];
    const formula = document.createElement('div');
    formula.className = 'feynman-formula';
    formula.textContent = '$$' + lesson[1] + '$$';
    renderFormula(formula);
    const body = document.createElement('p');
    body.className = 'feynman-lesson-body';
    body.textContent = lesson[2];
    card.append(title, formula, body);
    (section.querySelector('.section-header, .home-header') || section.firstElementChild)?.after(card);
  }

  function addDocumentation(section) {
    const doc = DOCS[section.id];
    if (!doc || section.querySelector('.tool-doc-card')) return;
    const card = document.createElement('aside');
    card.className = 'tool-doc-card';

    const overviewTitle = document.createElement('div');
    overviewTitle.className = 'tool-doc-title';
    overviewTitle.textContent = 'Simple Overview';
    const overview = document.createElement('p');
    overview.className = 'tool-doc-copy';
    overview.textContent = doc.overview;

    const stepsTitle = document.createElement('div');
    stepsTitle.className = 'tool-doc-title';
    stepsTitle.textContent = 'Step-by-Step Guide';
    const steps = document.createElement('ol');
    steps.className = 'tool-doc-list';
    doc.steps.forEach((step) => {
      const item = document.createElement('li');
      item.textContent = step;
      steps.appendChild(item);
    });

    const exampleTitle = document.createElement('div');
    exampleTitle.className = 'tool-doc-title';
    exampleTitle.textContent = 'Example Values & Presets';
    const examples = document.createElement('ul');
    examples.className = 'tool-doc-list tool-doc-example-list';
    doc.examples.forEach((entry) => {
      const item = document.createElement('li');
      item.textContent = entry;
      examples.appendChild(item);
    });

    const grid = document.createElement('div');
    grid.className = 'tool-doc-grid';
    const overviewWrap = document.createElement('div');
    overviewWrap.append(overviewTitle, overview);
    const stepsWrap = document.createElement('div');
    stepsWrap.append(stepsTitle, steps);
    const exampleWrap = document.createElement('div');
    exampleWrap.append(exampleTitle, examples);
    if (doc.button && typeof window[doc.button.action] === 'function') {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'tool-doc-btn';
      button.textContent = doc.button.label;
      button.onclick = function () { window[doc.button.action](); };
      exampleWrap.appendChild(button);
    }
    grid.append(overviewWrap, stepsWrap, exampleWrap);
    card.appendChild(grid);
    (section.querySelector('.section-header, .home-header') || section.firstElementChild)?.after(card);
  }

  function initLessons() {
    Object.keys(LESSONS).forEach((id) => {
      const section = document.getElementById(id);
      if (section) addLesson(section);
    });
    Object.keys(DOCS).forEach((id) => {
      const section = document.getElementById(id);
      if (section) addDocumentation(section);
    });
  }

  function registerWebMcp() {
    const context = document.modelContext;
    if (!context?.registerTool) return;
    const lifecycle = new AbortController();
    const explain = {
      name: 'beckify_explain_concept',
      title: 'Explain an engineering concept',
      description: 'Return a plain-language explanation and formula for a Beckify toolbox concept.',
      inputSchema: { type: 'object', properties: { concept: { type: 'string' } }, required: ['concept'], additionalProperties: false },
      annotations: { readOnlyHint: true },
      execute(input) {
        const query = String(input?.concept || '').toLowerCase();
        const match = Object.entries(LESSONS).find(([id, lesson]) => id.includes(query) || lesson[0].toLowerCase().includes(query));
        return match ? { ok: true, section: match[0], title: match[1][0], formula: match[1][1], explanation: match[1][2] } : { ok: false, error: 'No matching lesson found.' };
      }
    };
    Promise.resolve(context.registerTool(explain, { signal: lifecycle.signal })).catch(() => {});
    window.addEventListener('pagehide', () => lifecycle.abort(), { once: true });
  }

  window.addEventListener('DOMContentLoaded', () => { initLessons(); registerWebMcp(); loadMathJax(); });
  if (document.readyState !== 'loading') { initLessons(); registerWebMcp(); }
})();
