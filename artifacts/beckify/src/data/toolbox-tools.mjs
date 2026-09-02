/**
 * ============================================================================
 * TOOLBOX TOOL REGISTRY
 * ============================================================================
 * Single source of truth for every tool, category, and reference table in the
 * static toolbox at public/toolbox/index.html.
 *
 * Two independent consumers read this file:
 *   - scripts/generate-sitemap.mjs   builds sitemap.xml and per-tool static
 *                                     SEO routes (dist/public/toolbox/<slug>/)
 *   - src/lib/assistant/search.ts    builds the "Ask Beckify" search index
 *
 * Before this file existed, search.ts hand-maintained its own list that had
 * drifted to 8 of 44 real tools — "smith chart", "555 timer", "harmonics",
 * and "resonance" all returned nothing despite being real, linked tools.
 * Editing a tool's title/description here now updates both the sitemap and
 * search in one place; adding a tool to TOOLS makes it searchable and gives
 * it a static SEO page without any further wiring.
 *
 * Plain ESM (no TypeScript syntax): scripts/generate-sitemap.mjs runs under
 * plain `node`, not through Vite/tsc, so this file has to be valid there too.
 *
 * Each tuple is [slug, title, description, sectionAnchor].
 * ============================================================================
 */

export const TOOLS = [
  ["voltage-drop", "Voltage Drop Calculator", "Calculate feeder and branch-circuit voltage drop for single-phase and three-phase electrical runs.", "sec-vdrop"],
  ["transformer-sizing", "Transformer Sizing Calculator", "Select transformer size, primary and secondary protection, and practical conductor options for electrical loads.", "sec-xfmr-size"],
  ["conductor-length-resistance", "Conductor Length by Resistance", "Estimate conductor length from measured resistance with copper and aluminum temperature compensation.", "sec-conductor-length"],
  ["ohms-law", "Ohm's Law Calculator", "Solve voltage, current, resistance, and power relationships for DC and resistive AC circuits.", "sec-ohm"],
  ["dc-power", "DC Power Calculator", "Calculate voltage, current, resistance, and watts for a direct-current electrical circuit.", "sec-power-dc"],
  ["power-wizard", "AC and DC Power Wizard", "Solve real power, reactive power, apparent power, current, and motor horsepower for DC, single-phase, and three-phase systems.", "sec-power-wizard"],
  ["reactance-impedance", "Reactance and Impedance Calculator", "Calculate capacitive reactance, inductive reactance, and impedance for AC circuits.", "sec-reactance"],
  ["resonance", "RLC Resonance Calculator", "Find resonant frequency and related values for series and parallel LC circuits.", "sec-resonance"],
  ["power-factor-correction", "Power Factor Correction Calculator", "Estimate correction capacitance and improved power factor for AC loads.", "sec-pfc"],
  ["series-parallel", "Series and Parallel Calculator", "Combine resistance, capacitance, or inductance values in series and parallel networks.", "sec-sp"],
  ["motor-calculations", "Motor Calculations", "Estimate motor current, horsepower, efficiency, and power relationships for field calculations.", "sec-motor"],
  ["transformer", "Transformer Calculator", "Calculate transformer current, turns ratio, and voltage relationships for common configurations.", "sec-xfmr"],
  ["transformer-engine", "Transformer Conductor Selection Engine", "Work through transformer conductors, OCPD, grounding, voltage drop, and conduit selection.", "sec-xfmr-engine"],
  ["conduit-fill", "Conduit Fill Calculator", "Check conductor count and raceway fill using electrical conductor and conduit areas.", "sec-conduit"],
  ["conduit-fill-mixed", "Mixed Conduit Fill Calculator", "Calculate raceway fill for mixed conductor sizes and common EMT, PVC, IMC, and RMC systems.", "sec-conduit-adv"],
  ["wire-size-ampacity", "Wire Size and Ampacity Calculator", "Select conductors using ampacity, derating, termination temperature, and voltage drop constraints.", "sec-wire-select"],
  ["conductor-cost-optimizer", "Conductor Cost Optimizer", "Compare compliant conductor sizes and parallel runs using average or manual material pricing to find the lowest modeled cost.", "sec-wire-select"],
  ["short-circuit", "Short-Circuit Current Calculator", "Estimate available fault current and interrupting requirements for electrical distribution systems.", "sec-sc"],
  ["ups-sizing", "UPS Sizing Calculator", "Estimate UPS capacity and runtime requirements from connected electrical loads.", "sec-ups"],
  ["generator-sizing", "Generator Sizing Calculator", "Estimate generator capacity from motor, continuous, and mixed electrical loads.", "sec-gen"],
  ["hybrid-generator", "Hybrid Generator Calculator", "Explore generator and battery load-sharing options for resilient power systems.", "sec-hybrid"],
  ["ebike-drivetrain", "E-Bike Drivetrain Calculator", "Calculate e-bike torque, RPM, sprocket ratios, wheel speed, and drivetrain performance.", "sec-ebike-tools"],
  ["nec-circuit", "NEC Circuit Calculator", "Size branch-circuit conductors and overcurrent protection using practical NEC-based inputs.", "sec-nec"],
  ["lighting-voltage-drop", "Lighting Voltage Drop Optimizer", "Compare conductor options and voltage drop for lighting circuits and long branch runs.", "sec-lighting-opt"],
  ["building-load", "Building Load Calculator", "Estimate building electrical load from connected, continuous, and demand load inputs.", "sec-bldg-load"],
  ["load-factors-capacity", "Load Factors and Capacity Calculator", "Calculate demand, diversity, coincidence, load, and capacity-utilization factors from known electrical load data.", "sec-load-factors"],
  ["lsi-breaker", "LSI Breaker Visualizer", "Explore long-time, short-time, and instantaneous breaker protection settings visually.", "sec-lsi"],
  ["bess-peak-shave", "BESS Peak-Shave Calculator", "Model battery energy storage peak shaving and demand reduction for facility loads.", "sec-bess"],
  ["tap-changer", "Tap-Changer Calculator", "Calculate transformer tap changes and resulting secondary voltage adjustments.", "sec-tap"],
  ["harmonics", "Harmonics Tool", "Review harmonic distortion and practical electrical power-quality relationships.", "sec-harmonics"],
  ["hazardous-area", "Hazardous Area Lookup", "Reference hazardous-area classifications and equipment selection concepts for electrical work.", "sec-haz"],
  ["intrinsically-safe-loop", "Intrinsic Safety Loop Verifier", "Check intrinsic-safety loop inputs and identify common instrumentation constraints.", "sec-isloop"],
  ["555-timer", "555 Timer Calculator", "Calculate astable frequency, duty cycle, monostable pulse width, and timing values.", "sec-555"],
  ["unit-conversions", "Electrical Unit Conversions", "Convert common electrical engineering units quickly in the field.", "sec-convert"],
  ["circular-mils", "Circular Mils Calculator", "Calculate conductor area and compare circular-mil values for electrical sizing work.", "sec-cm"],
  ["photometrics", "Photometrics Calculator", "Estimate lighting levels and photometric relationships for practical design checks.", "sec-photometrics"],
  ["digital-logic-workbench", "Digital Logic Workbench", "Build combinational logic diagrams, simulate gate outputs, generate truth tables, and convert Boolean expressions to and from gate diagrams.", "sec-digital"],
  ["analog-design-workbench", "Analog Design Workbench", "Calculate common op-amp stages and design RC, RLC, Sallen-Key, state-variable, notch, band-pass, and all-pass filters with a live response plot.", "sec-analog-design"],
  ["battery-build-designer", "Battery Build Designer", "Plan 18650 series-parallel battery packs, C-rate, grid or honeycomb layouts, and nickel-strip cross-section current estimates.", "sec-battery-build"],
  ["panel-schedule-load-analyzer", "Panel Schedule Load Analyzer", "Extract an editable panel schedule from a photo and estimate circuit demand, panel current, diversity, and capacity.", "sec-panel-schedule"],
  ["panel-power-study", "Panel Schedule Power Study", "Read a panel schedule image, review breaker sizes, poles, and circuit classes, then calculate connected load, demand and diversity factors, panel FLA, and remaining expansion capacity.", "sec-panel-power-study"],
  ["megger-tdr-analyzer", "Megger TDR Trace Analyzer", "Analyze a Megger TDR500 screen image for velocity factor, range, impedance, and cable fault reflections.", "sec-tdr"],
  ["smith-chart", "Smith Chart Tool", "Explore transmission-line impedance matching, reflection coefficient, VSWR, and return loss.", "sec-smith-chart"],
  ["emp-emc-shielding", "EMP / EMC Shielding Calculator", "Educational Faraday-loop, aperture-leakage, and skin-depth estimates for cages, seams, and cable-entry protection. Protection-side physics only — not a pulse-source designer.", "sec-emp-emc"],
  ["transformer-design", "Transformer Design Wizard", "Work through transformer type, kVA, winding, protection, and conductor design choices.", "sec-xfmr-wizard"],
  ["heater-wizard", "Heater Design Wizard", "Size industrial resistive heaters across voltage, phase, and wye or delta wiring, and design custom Nichrome or Kanthal heating elements by wire gauge and length.", "sec-heater-wizard"],
];

export const CATEGORIES = [
  ["fundamentals", "Electrical Fundamentals", "Start with voltage, current, power, resistance, and core circuit relationships.", "sec-ohm"],
  ["ac-circuits", "AC Circuits", "Analyze reactance, impedance, resonance, and power factor in AC networks.", "sec-reactance"],
  ["distribution", "Power Distribution", "Size conductors, transformers, conduit, and protection for electrical distribution systems.", "sec-vdrop"],
  ["power-systems", "Power Systems", "Estimate UPS, generator, hybrid power, and facility load requirements.", "sec-ups"],
  ["nec-calculations", "NEC Calculations", "Use field-focused NEC reference calculators for circuits, ampacity, grounding, and raceway fill.", "sec-nec"],
  ["field-test-fault-locating", "Field Test and Fault Locating", "Use field tools for panel OCR and Megger TDR cable fault locating.", "sec-tdr"],
  ["reference-tables", "Electrical Reference Tables", "Browse conductor, motor, conduit, enclosure, IP rating, and NEC reference information.", "sec-wire-ref"],
];

/**
 * Static reference tables in the toolbox. These are not interactive
 * calculators, so they are not part of the sitemap's per-tool static-route
 * registry (TOOLS above) — but they are real, linkable content, and belong
 * in search just as much as a calculator does.
 */
export const REFERENCE_TABLES = [
  ["wire-ref", "Conductor Reference Table", "NEC Table 310.16 copper and aluminum ampacity at 75°C for up to three current-carrying conductors in a raceway or cable.", "sec-wire-ref"],
  ["motor-ref", "Motor FLA Reference Tables", "NEC Table 430.248 single-phase and NEC Table 430.250 three-phase squirrel-cage motor full-load current tables.", "sec-motor-ref"],
  ["conduit-ref", "Conduit Fill Reference Tables", "EMT internal dimensions and maximum conductor counts from NEC Annex C, Table C.1.", "sec-conduit-ref"],
  ["nec-tables", "NEC Code Tables", "Key National Electrical Code reference tables for conductor sizing, derating, protection, and conduit fill.", "sec-nec-tables"],
  ["ip-rating", "IP Rating Chart (IEC 60529)", "Ingress Protection ratings for electrical enclosures covering solid-particle and liquid protection.", "sec-ip-rating"],
  ["nema-class", "NEMA Enclosure Types (NEMA 250)", "NEMA enclosure ratings for electrical equipment environmental and safety protection levels.", "sec-nema-class"],
];
