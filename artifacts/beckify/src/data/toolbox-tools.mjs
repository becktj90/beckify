/**
 * ============================================================================
 * TOOLBOX TOOL REGISTRY
 * ============================================================================
 * Single source of truth for every tool, category, and reference table in the
 * static toolbox at public/toolbox/index.html.
 *
 * Catalog rule: one sidebar / sitemap entry per job. Overlapping calculators
 * are modes of a family (see TOOL_FAMILIES). Transformer ratio/sizing/engine/
 * design share one entry; tap-changer stays its own tool. Old slugs stay in
 * TOOL_ALIASES so /toolbox/<slug>/ routes do not 404.
 *
 * Two independent consumers read this file:
 *   - scripts/generate-sitemap.mjs   builds sitemap.xml and per-tool static
 *                                     SEO routes (dist/public/toolbox/<slug>/)
 *   - src/lib/assistant/search.ts    builds the "Ask Beckify" search index
 *
 * Plain ESM (no TypeScript syntax): scripts/generate-sitemap.mjs runs under
 * plain `node`, not through Vite/tsc, so this file has to be valid there too.
 *
 * Each TOOLS tuple is [slug, title, description, sectionAnchor].
 *
 * Control-theory workbench lives at /control-systems (React page), not as
 * toolbox calculator slugs. Do not add pid / bode / locus TOOLS ids here.
 * ============================================================================
 */

/**
 * Job-sized families. One nav item each. Member sections stay in the DOM so
 * existing JS and bookmarked hashes keep working; toolbox-families.js paints
 * the mode tabs. Keep this list in step with public/toolbox/js/toolbox-families.js.
 */
export const TOOL_FAMILIES = [
  {
    id: "transformer",
    title: "Transformer",
    navLabel: "Transformer",
    defaultAnchor: "sec-xfmr-size",
    modes: [
      { id: "basics", label: "Ratio & current", slug: "transformer", anchor: "sec-xfmr" },
      { id: "sizing", label: "Sizing & 450.3", slug: "transformer-sizing", anchor: "sec-xfmr-size" },
      { id: "conductors", label: "Conductors / OCPD / VD", slug: "transformer-engine", anchor: "sec-xfmr-engine" },
      { id: "design", label: "Type & winding", slug: "transformer-design", anchor: "sec-xfmr-wizard" },
    ],
  },
  {
    id: "conductors",
    title: "Conductors",
    navLabel: "Conductors",
    defaultAnchor: "sec-wire-select",
    modes: [
      { id: "ampacity-cost", label: "Ampacity & cost", slug: "conductor-cost-optimizer", anchor: "sec-wire-select" },
      { id: "vd", label: "Voltage drop", slug: "voltage-drop", anchor: "sec-vdrop" },
      { id: "lighting", label: "Lighting run", slug: "lighting-voltage-drop", anchor: "sec-lighting-opt" },
      { id: "length", label: "Length from R", slug: "conductor-length-resistance", anchor: "sec-conductor-length" },
      { id: "mv", label: "MV cable", slug: "mv-cable", anchor: "sec-mv-cable" },
    ],
  },
  {
    id: "conduit",
    title: "Conduit Fill",
    navLabel: "Conduit Fill",
    defaultAnchor: "sec-conduit",
    modes: [
      { id: "same-size", label: "Same size", slug: "conduit-fill", anchor: "sec-conduit" },
      { id: "mixed", label: "Mixed sizes", slug: "conduit-fill-mixed", anchor: "sec-conduit-adv" },
    ],
  },
  {
    id: "power",
    title: "Power",
    navLabel: "Power",
    defaultAnchor: "sec-power-wizard",
    modes: [
      { id: "wizard", label: "DC / 1Ø / 3Ø", slug: "power-wizard", anchor: "sec-power-wizard" },
      { id: "dc", label: "DC identities", slug: "dc-power", anchor: "sec-power-dc" },
    ],
  },
  {
    id: "motor",
    title: "Motor",
    navLabel: "Motor",
    defaultAnchor: "sec-motor-ref",
    modes: [
      { id: "fla", label: "FLA tables", slug: "motor-ref", anchor: "sec-motor-ref" },
      { id: "formula", label: "HP / kW / amps", slug: "motor-calculations", anchor: "sec-motor" },
    ],
  },
  {
    id: "panel",
    title: "Panel Schedule",
    navLabel: "Panel Schedule",
    defaultAnchor: "sec-panel-schedule",
    modes: [
      { id: "load", label: "Load analyzer", slug: "panel-schedule-load-analyzer", anchor: "sec-panel-schedule" },
      { id: "study", label: "Power study", slug: "panel-power-study", anchor: "sec-panel-power-study" },
    ],
  },
  {
    id: "on-site-power",
    title: "On-site power",
    navLabel: "On-site power",
    defaultAnchor: "sec-ups",
    modes: [
      { id: "ups", label: "UPS", slug: "ups-sizing", anchor: "sec-ups" },
      { id: "generator", label: "Generator", slug: "generator-sizing", anchor: "sec-gen" },
      { id: "hybrid", label: "Hybrid", slug: "hybrid-generator", anchor: "sec-hybrid" },
      { id: "bess", label: "BESS", slug: "bess-peak-shave", anchor: "sec-bess" },
    ],
  },
  {
    id: "rlc",
    title: "Reactance & Resonance",
    navLabel: "Reactance & Resonance",
    defaultAnchor: "sec-reactance",
    modes: [
      { id: "xz", label: "X / Z", slug: "reactance-impedance", anchor: "sec-reactance" },
      { id: "resonance", label: "Resonance", slug: "resonance", anchor: "sec-resonance" },
    ],
  },
];

/** Canonical jobs: one sitemap / search primary per remaining tool. */
export const TOOLS = [
  ["ohms-law", "Ohm's Law Calculator", "Solve voltage, current, resistance, and power relationships for DC and resistive AC circuits.", "sec-ohm"],
  ["magnetic-circuit", "Magnetic Circuit Workbench", "Homework magnetostatics: series or parallel reluctance, optional air-gap fringing, flux Φ = NI / Rtot, B, H, and MMF drops around the Ampere loop.", "sec-magnetic-circuit"],
  ["transient-circuits", "Transient Circuit Lab", "Closed-form first-order RC/RL and second-order series or parallel RLC transients for source-step and source-free cases, with a live waveform.", "sec-transient-circuits"],
  ["phasor-diagram", "Phasor Diagram Workbench", "Interactive series or parallel R-L-C phasors with a live voltage or current triangle, polar RMS, power factor, and balanced Δ-Y impedance conversion.", "sec-phasor-diagram"],
  ["power-wizard", "Power", "Solve real power, reactive power, apparent power, current, and motor horsepower for DC, single-phase, and three-phase systems. DC identities (P=VI, I²R, V²/R) are a mode.", "sec-power-wizard"],
  ["reactance-impedance", "Reactance & Resonance", "Calculate XL, XC, and series impedance, or series/parallel LC resonant frequency, Q, and bandwidth.", "sec-reactance"],
  ["power-factor-correction", "Power Factor Correction Calculator", "Estimate correction capacitance and improved power factor for AC loads.", "sec-pfc"],
  ["series-parallel", "Series and Parallel Calculator", "Combine resistance, capacitance, or inductance values in series and parallel networks.", "sec-sp"],
  ["transformer", "Transformer", "One transformer job: ratio and current, NEC Table 450.3(B) sizing (primary-only or primary+secondary, Note 1, continuous 125%), conductors/OCPD/VD/EGC/GEC, and type/winding/SLD. Tap-changer is a separate tool.", "sec-xfmr-size"],
  ["tap-changer", "Tap-Changer Calculator", "De-energized tap changer for common MV/LV pairs (23 kV/480 V and others). Not a general transformer sizer.", "sec-tap"],
  ["conductors", "Conductors", "Select LV conductors for ampacity, voltage drop, and modeled material plus I²R energy cost; size a lighting run; estimate length from measured resistance; or select MV cable (Art. 311 / 310.60 series) with a written wire-type string.", "sec-wire-select"],
  ["cable-schedule", "Cable Schedule Generator", "Build a power, control, instrumentation, and communication cable schedule from a type catalog, quantity cart, and sequential Cable IDs, then export CSV, XLSX, or JSON.", "sec-cable-schedule"],
  ["conduit-fill", "Conduit Fill Calculator", "Check raceway fill for one size or mixed conductor sizes using Chapter 9 areas and Table 1 limits.", "sec-conduit"],
  ["motor", "Motor", "NEC Tables 430.248 and 430.250 full-load current (the field table values) plus a formula HP/kW/amps mode. 430.6(A)(1) requires the table, not a calculated current, for conductor and OCPD sizing.", "sec-motor-ref"],
  ["motor-nameplate", "Motor Nameplate Analyzer", "Read a motor nameplate photo on this device, review HP, FLA, and code letter, then estimate overload, branch-circuit SCPD, and conductor size from NEC 430.32, Table 430.52, and 430.22.", "sec-motor-nameplate"],
  ["short-circuit", "Short-Circuit Current Calculator", "Estimate available fault current from user-entered transformer kVA, voltage, and %Z. Not a %Z calculator and not an inrush tool.", "sec-sc"],
  ["on-site-power", "On-site Power", "Size UPS, generator, hybrid generator-and-battery, or BESS peak-shave from connected loads. One family — four modes.", "sec-ups"],
  ["ebike-drivetrain", "E-Bike Drivetrain Calculator", "Calculate e-bike torque, RPM, sprocket ratios, wheel speed, and range, plus a visual battery pack designer that paints cells into series/parallel groups.", "sec-ebike-tools"],
  ["nec-circuit", "NEC Circuit Calculator", "Size branch-circuit conductors and overcurrent protection using practical NEC-based inputs.", "sec-nec"],
  ["building-load", "Load Calculation Worksheet", "Row-based NEC 220 feeder/service worksheet: lighting, receptacle, kitchen, HVAC, motor, and other loads with visible demand factors, phase amps, and a spare adder. Design aid — not a PE service calculation.", "sec-bldg-load"],
  ["load-factors-capacity", "Load Factors and Capacity Calculator", "Calculate demand, diversity, coincidence, load, and capacity-utilization factors from known electrical load data. Companion to the Load Calculation Worksheet — not a third peer.", "sec-load-factors"],
  ["torque-lookup", "Torque Lookup", "Typical terminal/lug tightening torque from UL 486A-B (NEC Annex I reprint) plus SAE/metric fastener handbook values. Manufacturer marking wins. Not a calibrated torque-tool substitute.", "sec-torque-lookup"],
  ["lsi-breaker", "LSI Breaker Visualizer", "Explore long-time, short-time, and instantaneous breaker protection settings visually.", "sec-lsi"],
  ["harmonics", "Harmonics Tool", "Review harmonic distortion and practical electrical power-quality relationships.", "sec-harmonics"],
  ["hazardous-area", "Hazardous Area Lookup", "Reference hazardous-area classifications and equipment selection concepts for electrical work.", "sec-haz"],
  ["intrinsically-safe-loop", "Intrinsic Safety Loop Verifier", "Check intrinsic-safety loop inputs and identify common instrumentation constraints.", "sec-isloop"],
  ["io-list-generator", "I/O List Generator", "Scaffold a PLC I/O list from a brand catalog, generic channel counts, or a typed instrument takeoff: numbered slots, 26-column workbook (optional zone / sample rate / tag suffix columns), type colors, and analog raw ranges. Design aid — not a PE stamp.", "sec-io-list-generator"],
  ["signal-scaling", "Process Value / Signal Scaling Calculator", "Linear or square-root (DP flow) scaling between raw instrument signals (4–20 mA, 0–10 V, ADC counts, Pt100) and engineering units, both directions, with a live formula. Design aid — not a transmitter download.", "sec-signal-scaling"],
  ["ebus-budget", "E-bus / Rack Current Budget", "Running remaining rack or E-bus current: signed module milliamps, power-refresh reset, and flags when remaining is negative or below a reserve. Beckhoff seed figures; other brands enter datasheet mA.", "sec-ebus-budget"],
  ["modbus-address", "Modbus Address Converter", "Convert Modbus coils and registers among function code, 0-based PDU offset, 1-based number, 5-digit 40001 addressing, and 6-digit 400001 long addressing. Shows wire/PDU bytes. Not a slave simulator.", "sec-modbus-address"],
  ["plc-timer-preset", "PLC Timer Preset", "TON/TOF/RTO preset counts from a desired time at 1 ms, 10 ms, 100 ms, 1 s, custom, or scan-time timebases — and the reverse. Visible math. Not a timing-chart IDE.", "sec-plc-timer-preset"],
  ["pitch-hum-identifier", "Pitch / Hum Frequency Identifier", "Electrical diagnostic helper (not a music tuner): autocorrelation fundamental of an audible hum plus 50/60/100/120 Hz associations. Worth investigating — never a confirmed cause. Phone mic, on-device only.", "sec-pitch-hum"],
  ["audio-spectrum-analyzer", "FFT / Audio Spectrum Analyzer", "Real-time Hann-windowed audio spectrum for transformer buzz, motor harmonics, and noise characterization. Linear/log axis, averaging, peak-hold, PNG/CSV export of bins. No raw audio leaves the device.", "sec-audio-spectrum"],
  ["sound-level-meter", "Sound Level Meter", "Relative dBFS meter with optional A-weighting approximation, running peak, Leq-style average, and one-point calibration. Not a calibrated SPL meter. On-device audio only.", "sec-sound-level"],
  ["lux-light-meter", "Lux / Light Level Meter", "Camera-based relative light-level estimate with center-weighted sampling, PWM smoothing, optional one-point lux calibration, and a frame-rate-limited flicker FFT. Not a photometer. On-device camera only.", "sec-lux-meter"],
  ["555-timer", "555 Timer Calculator", "Calculate astable frequency, duty cycle, monostable pulse width, and timing values.", "sec-555"],
  ["unit-conversions", "Electrical Unit Conversions", "Convert common electrical engineering units quickly in the field.", "sec-convert"],
  ["circular-mils", "Circular Mils Calculator", "Calculate conductor area and compare circular-mil values for electrical sizing work.", "sec-cm"],
  ["photometrics", "Photometrics Calculator", "Estimate lighting levels and photometric relationships for practical design checks.", "sec-photometrics"],
  ["fiber-link", "Fiber Link / NA", "Numerical aperture NA = √(n1² − n2²), acceptance angle, and a first-order optical link budget (source dBm minus fiber, connector, and splice loss versus receiver sensitivity).", "sec-fiber-link"],
  ["gaussian-beam", "Gaussian Beam", "TEM00 envelope: Rayleigh range zR = π w0² / λ, spot w(z), curvature R(z), and confocal parameter b = 2 zR.", "sec-gaussian-beam"],
  ["digital-logic-workbench", "Digital Logic Workbench", "Build combinational logic diagrams, simulate gate outputs, generate truth tables, and convert Boolean expressions to and from gate diagrams.", "sec-digital"],
  ["analog-design-workbench", "Analog Design Workbench", "Calculate common op-amp stages, a generic analog-computer lead network Gc=(Ts+1)/(αTs+1) from R/C, and design RC, RLC, Sallen-Key, state-variable, notch, band-pass, and all-pass filters with a live response plot.", "sec-analog-design"],
  ["semiconductor-iv", "Semiconductor Device I-V", "Shockley diode with optional series Rs, npn β-forced Q-point, and long-channel NMOS cutoff / triode / saturation with a live I-V plot.", "sec-semiconductor-iv"],
  ["battery-build-designer", "Battery Build Designer", "Plan 18650 series-parallel battery packs, C-rate, grid or honeycomb layouts, and nickel-strip cross-section current estimates.", "sec-battery-build"],
  ["battery-bank", "Battery Bank Calculator", "Size a battery bank from load and backup duration, or reverse-solve runtime from series/parallel strings, with chemistry presets and a continuous C-rate flag.", "sec-battery-bank"],
  ["panel-schedule", "Panel Schedule", "Read a panel schedule image and estimate circuit demand, breaker layout, diversity, panel FLA, and remaining expansion capacity. Load-analyzer and power-study modes.", "sec-panel-schedule"],
  ["megger-tdr-analyzer", "Megger TDR Trace Analyzer", "Analyze a Megger TDR500 screen image for velocity factor, range, impedance, and cable fault reflections.", "sec-tdr"],
  ["look-check", "Look Check", "Upload any photo for a playful good-or-bad look verdict. Entertainment only — not medical or dating advice. Photos upload only when you click Analyze Look.", "sec-look-check"],
  ["smith-chart", "Smith Chart Tool", "Explore transmission-line impedance matching, reflection coefficient, VSWR, and return loss.", "sec-smith-chart"],
  ["emp-emc-shielding", "EMP / EMC Shielding Calculator", "Educational Faraday-loop, aperture-leakage, and skin-depth estimates for cages, seams, and cable-entry protection. Protection-side physics only — not a pulse-source designer.", "sec-emp-emc"],
  ["heater-wizard", "Heater Design Wizard", "Size industrial resistive heaters across voltage, phase, and wye or delta wiring, and design custom Nichrome or Kanthal heating elements by wire gauge and length.", "sec-heater-wizard"],
  ["solar-wizard", "Solar Design Wizard", "Size PV arrays from residential rooftops to utility facilities, aim panels with phone orientation sensors, and optionally size battery energy storage for autonomy, peak-shave, or self-consumption.", "sec-solar-wizard"],
  ["lp-optimizer", "Linear Programming Optimizer", "Solve a small linear program: maximize or minimize c·x subject to Ax ≤ / ≥ / = b with x ≥ 0, using two-phase simplex, a 2-variable feasible-region plot, and labelled slack. Homework simplex — not a conductor cost estimator.", "sec-lp-optimizer"],
  ["number-base-converter", "Number-Base Converter", "Convert among hexadecimal, decimal, octal, and binary with 8/16/32/64-bit wrap, optional two’s-complement signed decimal, place-value chips, and a grouped bit field.", "sec-base-converter"],
];

/**
 * Old slugs that must keep resolving. Each tuple is
 * [slug, title, description, sectionAnchor, familyId, modeId].
 * familyId is null when the slug is a synonym of a standalone tool.
 */
export const TOOL_ALIASES = [
  ["transformer-sizing", "Transformer Sizing Calculator", "Select a standard kVA and apply NEC Table 450.3(B): primary-only or primary+secondary protection, Note 1 next-size-up on or off, optional continuous 125%.", "sec-xfmr-size", "transformer", "sizing"],
  ["transformer-engine", "Transformer Conductor Selection Engine", "Work through transformer conductors, OCPD, EGC/GEC, voltage drop, conduit, copper or aluminum, insulation temperature, and optional parallel runs.", "sec-xfmr-engine", "transformer", "conductors"],
  ["transformer-design", "Transformer Design Wizard", "Guided type (dry / cast / liquid / FR3), winding, protection, and single-line diagram.", "sec-xfmr-wizard", "transformer", "design"],
  ["voltage-drop", "Voltage Drop Calculator", "Calculate feeder and branch-circuit voltage drop for single-phase and three-phase electrical runs.", "sec-vdrop", "conductors", "vd"],
  ["wire-size-ampacity", "Wire Size and Ampacity Calculator", "Select conductors using ampacity, derating, termination temperature, and voltage drop constraints.", "sec-wire-select", "conductors", "ampacity-cost"],
  ["conductor-cost-optimizer", "Conductor Cost Optimizer", "Compare compliant conductor sizes and parallel runs using a user-overridable planning allowance and optional I²R energy cost.", "sec-wire-select", "conductors", "ampacity-cost"],
  ["lighting-voltage-drop", "Lighting Voltage Drop Optimizer", "K-factor voltage drop for a lighting run from fixture count and wattage. Not a cost optimizer.", "sec-lighting-opt", "conductors", "lighting"],
  ["conductor-length-resistance", "Conductor Length by Resistance", "Estimate conductor length from measured resistance with copper and aluminum temperature compensation.", "sec-conductor-length", "conductors", "length"],
  ["mv-cable", "MV Cable", "Medium-voltage feeder: class, insulation level, construction, Art. 311 / 310.60 series ampacity, and voltage drop. Distinct from LV Table 310.16.", "sec-mv-cable", "conductors", "mv"],
  ["conduit-fill-mixed", "Mixed Conduit Fill Calculator", "Calculate raceway fill for mixed conductor sizes and common EMT, PVC, IMC, and RMC systems.", "sec-conduit-adv", "conduit", "mixed"],
  ["dc-power", "DC Power Calculator", "Calculate voltage, current, resistance, and watts for a direct-current electrical circuit.", "sec-power-dc", "power", "dc"],
  ["motor-calculations", "Motor Calculations", "Estimate motor current, horsepower, efficiency, and power relationships. For NEC conductor and OCPD sizing use the FLA tables mode (430.6(A)(1)).", "sec-motor", "motor", "formula"],
  ["ups-sizing", "UPS Sizing Calculator", "Estimate UPS capacity and runtime requirements from connected electrical loads.", "sec-ups", "on-site-power", "ups"],
  ["generator-sizing", "Generator Sizing Calculator", "Estimate generator capacity from motor, continuous, and mixed electrical loads.", "sec-gen", "on-site-power", "generator"],
  ["hybrid-generator", "Hybrid Generator Calculator", "Explore generator and battery load-sharing options for resilient power systems.", "sec-hybrid", "on-site-power", "hybrid"],
  ["bess-peak-shave", "BESS Peak-Shave Calculator", "Model battery energy storage peak shaving and demand reduction for facility loads.", "sec-bess", "on-site-power", "bess"],
  ["resonance", "RLC Resonance Calculator", "Find resonant frequency and related values for series and parallel LC circuits.", "sec-resonance", "rlc", "resonance"],
  ["panel-schedule-load-analyzer", "Panel Schedule Load Analyzer", "Extract an editable panel schedule from a photo and estimate circuit demand, panel current, diversity, and capacity.", "sec-panel-schedule", "panel", "load"],
  ["panel-power-study", "Panel Schedule Power Study", "Read a panel schedule image, review breaker sizes, poles, and circuit classes, then calculate connected load, demand and diversity factors, panel FLA, and remaining expansion capacity.", "sec-panel-power-study", "panel", "study"],
  ["load-calculation-worksheet", "Load Calculation Worksheet", "Alias of building-load. Row-based NEC 220 worksheet with 220.42 / 220.52 / 220.53 / 220.54 / 220.82 factors you can see and edit.", "sec-bldg-load", null, null],
];

export function resolveToolSlug(slug) {
  const primary = TOOLS.find((tool) => tool[0] === slug);
  if (primary) {
    return { slug: primary[0], title: primary[1], description: primary[2], anchor: primary[3], familyId: null, modeId: null, alias: false };
  }
  const alias = TOOL_ALIASES.find((tool) => tool[0] === slug);
  if (!alias) return null;
  return { slug: alias[0], title: alias[1], description: alias[2], anchor: alias[3], familyId: alias[4], modeId: alias[5], alias: true };
}

export const ALL_TOOL_SLUGS = [...TOOLS.map((tool) => tool[0]), ...TOOL_ALIASES.map((tool) => tool[0])];

/**
 * Live sidebar calculators that exist in public/toolbox/index.html but are
 * not first-class TOOLS SEO entries (no /toolbox/<slug>/ route yet).
 * Counted in the visitor-facing total so homepage/sitemap stay honest.
 */
const LIVE_NAV_CALCULATORS_OUTSIDE_REGISTRY = ["sec-circuit-sim", "sec-stem-tools"];

/**
 * Public calculator count: unique remaining jobs (canonical TOOLS anchors)
 * plus the live-nav extras. Aliases do not count. Keep in step with the
 * toolbox sidebar (nav-btn targets excluding reference tables, the fittings
 * guide, and Saved Jobs).
 */
export const PUBLIC_CALCULATOR_COUNT = new Set([
  ...TOOLS.map((tool) => tool[3]),
  ...LIVE_NAV_CALCULATORS_OUTSIDE_REGISTRY,
]).size;

export const CATEGORIES = [
  ["fundamentals", "Electrical Fundamentals", "Start with voltage, current, power, resistance, magnetic circuits, and core circuit relationships.", "sec-ohm"],
  ["ac-circuits", "AC Circuits", "Analyze reactance, impedance, resonance, transients, phasors, and power factor in AC networks.", "sec-reactance"],
  ["distribution", "Power Distribution", "Size conductors, transformers, conduit, and protection for electrical distribution systems.", "sec-vdrop"],
  ["power-systems", "Power Systems", "Estimate UPS, generator, hybrid power, solar PV, and facility load requirements.", "sec-ups"],
  ["nec-calculations", "NEC Calculations", "Use field-focused NEC reference calculators for circuits, ampacity, grounding, and raceway fill.", "sec-nec"],
  ["field-test-fault-locating", "Field Test and Fault Locating", "Use field tools for panel-directory OCR, motor nameplates, cable schedules, Megger TDR, Look Check, PLC I/O lists, scaling, Modbus addressing, timer presets, and phone-sensor meters (lux, hum, spectrum, sound level).", "sec-tdr"],
  ["reference-tables", "Electrical Reference Tables", "Browse conductor, motor, conduit, enclosure, IP rating, and NEC reference information.", "sec-wire-ref"],
];

/**
 * Static reference tables in the toolbox. These are not interactive
 * calculators, so they are not part of the sitemap's per-tool static-route
 * registry (TOOLS above) — but they are real, linkable content, and belong
 * in search just as much as a calculator does.
 *
 * Motor FLA tables are a mode of the Motor tool; the slug stays here so
 * existing /toolbox/#sec-motor-ref links and search keep working.
 */
export const REFERENCE_TABLES = [
  ["wire-ref", "Conductor Reference Table", "NEC Table 310.16 copper and aluminum ampacity at 75°C for up to three current-carrying conductors in a raceway or cable.", "sec-wire-ref"],
  ["motor-ref", "Motor FLA Reference Tables", "NEC Table 430.248 single-phase and NEC Table 430.250 three-phase squirrel-cage motor full-load current tables. Mode of the Motor tool.", "sec-motor-ref"],
  ["conduit-ref", "Conduit Fill Reference Tables", "EMT internal dimensions and maximum conductor counts from NEC Annex C, Table C.1.", "sec-conduit-ref"],
  ["nec-tables", "NEC Code Tables", "Key National Electrical Code reference tables for conductor sizing, derating, protection, and conduit fill.", "sec-nec-tables"],
  ["ip-rating", "IP Rating Chart (IEC 60529)", "Ingress Protection ratings for electrical enclosures covering solid-particle and liquid protection.", "sec-ip-rating"],
  ["nema-class", "NEMA Enclosure Types (NEMA 250)", "NEMA enclosure ratings for electrical equipment environmental and safety protection levels.", "sec-nema-class"],
  ["nema-wiring", "NEMA Wiring Configurations & Color Code Reference", "SVG receptacle-face diagrams for common NEMA straight-blade and locking devices, plus US color-code notes. Neutral and EGC colors cite NEC 200.6 and 250.119; hot colors are industry convention.", "sec-nema-wiring"],
  ["wire-colors", "Wire colors (NEC / UL 508A)", "NEC grounded/EGC/high-leg identification versus industry-convention hot colors, plus UL 508A industrial control-panel internal wiring colors (66.5 / 66.9). Not a substitute for the adopted code or standard.", "sec-wire-colors"],
];
