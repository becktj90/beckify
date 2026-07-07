/**
 * ============================================================================
 * EE TOOLBOX — STATIC REFERENCE DATA
 * ============================================================================
 * Lookup content for the hazardous-area, harmonics, IP-rating and NEMA
 * enclosure tools. Sourced from NEC 500, IEEE 519, IEC 60529 and NEMA 250.
 * ============================================================================
 */

export interface HazSubstance {
  key: string;
  name: string;
  class: string;
  division: string;
  group: string;
  tcode: string;
  notes: string;
}

export const HAZ_DATA: HazSubstance[] = [
  {
    key: "hydrogen",
    name: "Hydrogen (H\u2082)",
    class: "Class I",
    division: "Div 1 (near release points) / Div 2 (general area)",
    group: "Group B",
    tcode: "T1 (AIT 500\u00b0C \u2014 max surface temp \u2264 450\u00b0C)",
    notes:
      "Most stringent gas group. Requires Group B listed equipment. Very wide flammability range (4\u201375% in air). Used as LH\u2082 propellant. Venting areas are typically Class I, Div 1 within a defined radius.",
  },
  {
    key: "rp1",
    name: "RP-1 Kerosene (Rocket Propellant-1)",
    class: "Class I",
    division: "Div 1 (fueling) / Div 2 (storage/handling)",
    group: "Group D",
    tcode: "T3 (AIT 210\u00b0C \u2014 max surface temp \u2264 200\u00b0C)",
    notes:
      "Petroleum-based fuel similar to kerosene. Flash point ~43\u201372\u00b0C. Group D applies to most petroleum distillates. Division 1 applies during active fueling; Division 2 for storage areas.",
  },
  {
    key: "methane",
    name: "Methane (CH\u2084) / LNG / Natural Gas",
    class: "Class I",
    division: "Div 1 (near release points) / Div 2 (general storage)",
    group: "Group D",
    tcode: "T1 (AIT 537\u00b0C \u2014 max surface temp \u2264 450\u00b0C)",
    notes:
      "Natural gas and LNG are primarily methane. Lighter than air \u2014 accumulates at ceiling level. Flammability range 5\u201315% in air. Used as Methox (CH\u2084/LOX) propellant. Group D per NEC 500.6.",
  },
  {
    key: "ammonia",
    name: "Ammonia (NH\u2083)",
    class: "Class I",
    division: "Div 1 (near release points) / Div 2 (storage/handling)",
    group: "Group D",
    tcode: "T1 (AIT 651\u00b0C \u2014 max surface temp \u2264 450\u00b0C)",
    notes:
      "Group D per NEC 500.6(A)(4). Flammability range 15\u201328% in air. Also a toxic gas \u2014 TLV-TWA 25 ppm. NH\u2083 refrigeration machine rooms require Class I, Div 2 classification.",
  },
  {
    key: "lox",
    name: "LOX Venting / Oxygen-Enriched Atmosphere",
    class: "Not a flammable gas (oxidizer)",
    division: "N/A \u2014 oxygen is not classified under NEC 500",
    group: "N/A",
    tcode: "N/A \u2014 OEA lowers ignition energy of all other materials",
    notes:
      "Liquid oxygen and oxygen-enriched atmospheres are oxidizers, not flammables. However OEA dramatically lowers the ignition energy of adjacent materials. Areas with LOX venting need O\u2082 monitoring and strict material controls. Consult NFPA 50B.",
  },
  {
    key: "nitrogen",
    name: "Nitrogen (N\u2082) / Inert Purge Gas",
    class: "Non-flammable / Non-classified",
    division: "N/A \u2014 no NEC 500 classification applies",
    group: "N/A",
    tcode: "N/A",
    notes:
      "Pure nitrogen is inert. N\u2082 purge systems don't create NEC 500 areas by themselves, but nitrogen is an asphyxiant \u2014 confined-space procedures and O\u2082 monitoring required. Purging can eliminate a previously classified flammable atmosphere.",
  },
];

export interface HarmonicLoad {
  key: string;
  name: string;
  orders: string;
  dominant: string;
  typicalTHD: string;
  filter: string;
  note: string;
}

export const HARMONIC_LOADS: HarmonicLoad[] = [
  {
    key: "vfd6",
    name: "VFD / 6-Pulse Rectifier",
    orders: "5th, 7th, 11th, 13th, 17th, 19th\u2026 (6k\u00b11)",
    dominant: "5th (300 Hz) and 7th (420 Hz)",
    typicalTHD: "25\u201340% at full load",
    filter: "Passive 5th-harmonic filter, 12-pulse transformer, or Active Harmonic Filter (AHF)",
    note: "Most common harmonic source in industrial facilities. 5th harmonic is negative-sequence \u2014 causes motor heating and torque pulsation.",
  },
  {
    key: "vfd12",
    name: "12-Pulse Rectifier Drive",
    orders: "11th, 13th, 23rd, 25th\u2026 (12k\u00b11)",
    dominant: "11th (660 Hz) and 13th (780 Hz)",
    typicalTHD: "8\u201315% at full load",
    filter: "Passive 11th/13th filter or AHF if needed. 5th/7th already cancelled.",
    note: "Phase-shifting transformer (30\u00b0 shift) cancels 5th and 7th harmonics. Requires matched transformer.",
  },
  {
    key: "smps",
    name: "Switch-Mode Power Supply (PC/UPS/Charger)",
    orders: "3rd, 5th, 7th, 9th, 11th\u2026 (all odd)",
    dominant: "3rd (180 Hz) \u2014 zero-sequence, accumulates in neutral",
    typicalTHD: "60\u2013150% (high for single-phase SMPS)",
    filter: "Active harmonic filter or zero-sequence blocking transformer (ZSB). Size neutral at 200% for SMPS-heavy loads.",
    note: "Single-phase SMPS creates large triplen harmonics. In 3\u00d8 4-wire systems neutral current can exceed phase current by 173%.",
  },
  {
    key: "fluor",
    name: "Fluorescent / LED Driver (Electronic Ballast)",
    orders: "3rd, 5th, 7th (odd harmonics)",
    dominant: "3rd (180 Hz) in older ballasts; modern LED drivers <20% THD",
    typicalTHD: "15\u201330% (magnetic), 5\u201320% (electronic), <20% (LED)",
    filter: "Typically no filter needed if %THD < 20%. For large lighting loads, ZSB transformer or derating neutral.",
    note: "LED drivers with power-factor correction have much lower harmonic content. Specify THD < 20% for procurement.",
  },
  {
    key: "arc",
    name: "Arc Furnace / Arc Welder",
    orders: "2nd\u20139th broadband (all orders); highly variable",
    dominant: "Broadband \u2014 random variation due to arc instability",
    typicalTHD: "20\u201350%; flicker is also a significant concern",
    filter: "Static VAR compensator (SVC) or STATCOM for flicker. Active filter for harmonics. Dedicated supply recommended.",
    note: "Arc loads are non-periodic \u2014 stochastic harmonic generation. Also produces voltage flicker (IEC 61000-3-7). Best served from a dedicated HV supply.",
  },
  {
    key: "ups1ph",
    name: "Single-Phase UPS",
    orders: "3rd, 9th, 15th\u2026 (triplen \u2014 zero-sequence)",
    dominant: "3rd harmonic \u2014 zero-sequence, adds in neutral",
    typicalTHD: "25\u201340%",
    filter: "Online double-conversion UPS with input PFC reduces input THD. ZSB transformer at feeder level.",
    note: "Triplen harmonics are zero-sequence and don't cancel in balanced 3\u00d8 systems \u2014 they add in the neutral. Size neutral conductors to 200% for UPS-heavy circuits.",
  },
  {
    key: "motor",
    name: "Linear Load (Motor / Resistive Heater)",
    orders: "None significant (linear load)",
    dominant: "Fundamental only (60 Hz)",
    typicalTHD: "< 3% (negligible)",
    filter: "No harmonic filtering required.",
    note: "Induction motors and resistive heaters are essentially linear and generate minimal harmonic content \u2014 but are victims of harmonics from other loads.",
  },
];

/* IEC 60529 — first digit (solid particle protection) */
export const IP_SOLID = [
  { digit: "0", level: "None", desc: "No protection" },
  { digit: "1", level: ">50 mm", desc: "Large body parts (back of hand)" },
  { digit: "2", level: ">12.5 mm", desc: "Fingers or similar objects" },
  { digit: "3", level: ">2.5 mm", desc: "Tools, thick wires" },
  { digit: "4", level: ">1 mm", desc: "Most wires, screws" },
  { digit: "5", level: "Dust-protected", desc: "Dust ingress limited (no harmful deposit)" },
  { digit: "6", level: "Dust-tight", desc: "No dust ingress whatsoever" },
];

/* IEC 60529 — second digit (liquid ingress protection) */
export const IP_LIQUID = [
  { digit: "0", level: "None", desc: "No protection" },
  { digit: "1", level: "Dripping water", desc: "Vertical drips (1 mm/min)" },
  { digit: "2", level: "Dripping (15\u00b0)", desc: "Drips up to 15\u00b0 tilt" },
  { digit: "3", level: "Spraying water", desc: "Up to 60\u00b0 from vertical" },
  { digit: "4", level: "Splashing", desc: "All directions" },
  { digit: "5", level: "Water jets", desc: "6.3 mm nozzle, any direction" },
  { digit: "6", level: "Powerful jets", desc: "12.5 mm nozzle, any direction" },
  { digit: "7", level: "Immersion (1 m)", desc: "Up to 1 m depth, 30 min" },
  { digit: "8", level: "Immersion (deep)", desc: "Manufacturer-specified depth >1 m" },
  { digit: "9K", level: "High-pressure steam", desc: "Close-range high-pressure/high-temp jets" },
];

/* Common facilities IP ratings mapped to approximate NEMA equivalents */
export const IP_COMMON = [
  { ip: "IP20", app: "Indoor, clean environments (panelboards)", nema: "NEMA 1" },
  { ip: "IP44", app: "Outdoor, splash-protected", nema: "NEMA 3" },
  { ip: "IP54", app: "Dusty/splash environments (HVAC)", nema: "NEMA 3S" },
  { ip: "IP55", app: "General outdoor (motors, drives)", nema: "NEMA 3R (close)" },
  { ip: "IP65", app: "Dust-tight + water jets (washdown)", nema: "NEMA 4 (close)" },
  { ip: "IP66", app: "Heavy water jets (outdoor panels)", nema: "NEMA 4" },
  { ip: "IP67", app: "Temporary immersion (portable equip)", nema: "NEMA 6" },
  { ip: "IP68", app: "Continuous submersion", nema: "NEMA 6P" },
  { ip: "IP69K", app: "High-pressure steam cleaning (food mfg)", nema: "\u2014" },
];

/* NEMA 250 enclosure types */
export const NEMA_TYPES = [
  { type: "1", loc: "Indoor", desc: "General purpose \u2014 dirt, light dust, indirect contact", corr: "No", ip: "IP20" },
  { type: "2", loc: "Indoor", desc: "Type 1 + drip-proof (limited condensate)", corr: "No", ip: "IP31" },
  { type: "3", loc: "Outdoor", desc: "Rainproof, sleet-resistant, windblown dust", corr: "No", ip: "IP54" },
  { type: "3R", loc: "Outdoor", desc: "Rain/sleet resistant (no dust protection)", corr: "No", ip: "IP32" },
  { type: "3S", loc: "Outdoor", desc: "Type 3 + external ice formation on mechanism", corr: "No", ip: "IP54" },
  { type: "3X", loc: "Outdoor", desc: "Type 3 + corrosion resistant", corr: "Yes", ip: "IP54" },
  { type: "4", loc: "In/Out", desc: "Watertight \u2014 hosedown, windblown rain/dust/sleet", corr: "No", ip: "IP66" },
  { type: "4X", loc: "In/Out", desc: "Type 4 + corrosion resistant (SS/FRP)", corr: "Yes", ip: "IP66" },
  { type: "5", loc: "Indoor", desc: "Dust-tight (lint, fibers), drip-proof", corr: "No", ip: "IP52" },
  { type: "6", loc: "In/Out", desc: "Submersible \u2014 temporary, occasional", corr: "No", ip: "IP67" },
  { type: "6P", loc: "In/Out", desc: "Submersible \u2014 prolonged depth", corr: "Yes", ip: "IP68" },
  { type: "7", loc: "Indoor", desc: "Class I, Div 1, Groups A\u2013D (explosion-proof)", corr: "No", ip: "\u2014" },
  { type: "9", loc: "Indoor", desc: "Class II, Div 1, Groups E, F, G (dust-ignitionproof)", corr: "No", ip: "\u2014" },
  { type: "12", loc: "Indoor", desc: "Industrial \u2014 dust, dripping non-corrosive liquids", corr: "No", ip: "IP54" },
  { type: "12K", loc: "Indoor", desc: "Type 12 with knockouts", corr: "No", ip: "IP54" },
  { type: "13", loc: "Indoor", desc: "Oil-tight, dust-tight \u2014 oil mist, lint, seepage", corr: "No", ip: "IP54" },
];
