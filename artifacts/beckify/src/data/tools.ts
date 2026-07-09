/**
 * ============================================================================
 * EE TOOLBOX — TOOL REGISTRY
 * ============================================================================
 * Comprehensive registry of all calculators and reference tools,
 * organized by category. Drives navigation, search, routing.
 * Each tool is either a declarative CalcSpec or a custom React component.
 * ============================================================================
 */

import {
  Zap,
  Waves,
  Cable,
  Plug,
  Lightbulb,
  AlertTriangle,
  BookOpen,
  Cog,
} from "lucide-react";
import type { Tool } from "@/lib/ee/types";
import {
  computeOhmsLaw,
  computeDcPower,
  computeAcPower1Ph,
  computeAcPower3Ph,
  computeReactanceImpedance,
  computeResonance,
  computePfc,
  computeCircularMils,
  computeUnitConversions,
} from "@/lib/ee/fundamentals";
import {
  computeVoltageDrop,
  computeMinWireSize,
  computeConduitFill,
  computeLightingVdOptimizer,
} from "@/lib/ee/conductors";
import {
  computeMotorHpFla,
  computeTransformerSizing,
  computeTapChanger,
} from "@/lib/ee/motors";
import {
  computeShortCircuit,
  computeUpsSizing,
  computeGeneratorSizing,
  computeBuildingLoadCalc,
  computeHarmonicsTHD,
  computeBessPeakShave,
} from "@/lib/ee/power-systems";
import {
  computeLuxFc,
  computeInverseSquare,
  computePhotometrics,
} from "@/lib/ee/lighting";
import {
  computeHazardousAreaLookup,
  computeIsLoopVerifier,
} from "@/lib/ee/hazardous";

// ============================================================================
// FUNDAMENTALS
// ============================================================================

const fundamentalsTools: Tool[] = [
  {
    id: "ohms-law",
    name: "Ohm's Law",
    category: "Fundamentals",
    icon: Zap,
    kind: "calc",
    description: "Calculate voltage, current, or resistance using Ohm's Law (V = I × R)",
    keywords: ["ohm", "volt", "ampere", "resistance"],
    fields: [
      {
        id: "voltage",
        label: "Voltage",
        type: "number",
        unit: "V",
        placeholder: "Enter voltage",
      },
      {
        id: "current",
        label: "Current",
        type: "number",
        unit: "A",
        placeholder: "Enter current",
      },
      {
        id: "resistance",
        label: "Resistance",
        type: "number",
        unit: "Ω",
        placeholder: "Enter resistance",
      },
    ],
    compute: computeOhmsLaw,
    formula: "V = I × R",
    reference: "Ohm's Law",
  },
  {
    id: "dc-power",
    name: "DC Power",
    category: "Fundamentals",
    icon: Zap,
    kind: "calc",
    description: "Calculate power, voltage, current, or resistance in DC circuits",
    keywords: ["power", "watt", "volt", "ampere", "dc"],
    fields: [
      {
        id: "voltage",
        label: "Voltage",
        type: "number",
        unit: "V",
      },
      {
        id: "current",
        label: "Current",
        type: "number",
        unit: "A",
      },
      {
        id: "power",
        label: "Power",
        type: "number",
        unit: "W",
      },
      {
        id: "resistance",
        label: "Resistance",
        type: "number",
        unit: "Ω",
      },
    ],
    compute: computeDcPower,
    formula: "P = V × I = I² × R = V² / R",
  },
  {
    id: "ac-power-1ph",
    name: "AC Power (Single Phase)",
    category: "Fundamentals",
    icon: Waves,
    kind: "calc",
    description: "Solve for voltage, current, power factor, or real power in single-phase AC circuits. Enter any 2+ values to solve for the rest.",
    keywords: ["ac", "power", "watt", "var", "volt ampere", "pf", "current"],
    fields: [
      {
        id: "voltage",
        label: "Voltage",
        type: "number",
        unit: "V",
      },
      {
        id: "current",
        label: "Current",
        type: "number",
        unit: "A",
      },
      {
        id: "pf",
        label: "Power Factor",
        type: "number",
        placeholder: "0.85",
        min: 0,
        step: "0.01",
      },
      {
        id: "realPower",
        label: "Real Power",
        type: "number",
        unit: "W",
      },
    ],
    compute: computeAcPower1Ph,
    formula: "P = V × I × PF  |  I = P / (V × PF)  |  V = P / (I × PF)",
  },
  {
    id: "ac-power-3ph",
    name: "AC Power (Three Phase)",
    category: "Fundamentals",
    icon: Waves,
    kind: "calc",
    description: "Solve for line voltage, current, power factor, or real power in three-phase AC circuits. Enter any 2+ values to solve for the rest.",
    keywords: ["ac", "three phase", "3ph", "power", "watt", "pf", "current"],
    fields: [
      {
        id: "voltage",
        label: "Line Voltage",
        type: "number",
        unit: "V",
      },
      {
        id: "current",
        label: "Line Current",
        type: "number",
        unit: "A",
      },
      {
        id: "pf",
        label: "Power Factor",
        type: "number",
        placeholder: "0.85",
        step: "0.01",
      },
      {
        id: "realPower",
        label: "Real Power",
        type: "number",
        unit: "W",
      },
    ],
    compute: computeAcPower3Ph,
    formula: "P = √3 × V × I × PF  |  I = P / (√3 × V × PF)  |  V = P / (√3 × I × PF)",
  },
  {
    id: "reactance-impedance",
    name: "Reactance & Impedance",
    category: "Fundamentals",
    icon: Waves,
    kind: "calc",
    description:
      "Calculate inductive reactance (XL), capacitive reactance (XC), impedance (Z)",
    keywords: ["reactance", "inductance", "capacitance", "impedance", "frequency"],
    fields: [
      {
        id: "frequency",
        label: "Frequency",
        type: "number",
        unit: "Hz",
        default: "60",
      },
      {
        id: "inductance",
        label: "Inductance",
        type: "number",
        unit: "H",
      },
      {
        id: "capacitance",
        label: "Capacitance",
        type: "number",
        unit: "F",
      },
      {
        id: "resistance",
        label: "Resistance",
        type: "number",
        unit: "Ω",
      },
    ],
    compute: computeReactanceImpedance,
    formula: "XL = 2πfL, XC = 1/(2πfC), Z = √(R² + X²)",
  },
  {
    id: "resonance",
    name: "Resonance Frequency",
    category: "Fundamentals",
    icon: Waves,
    kind: "calc",
    description: "Calculate resonant frequency of LC circuits",
    keywords: ["resonance", "frequency", "inductance", "capacitance"],
    fields: [
      {
        id: "inductance",
        label: "Inductance",
        type: "number",
        unit: "H",
      },
      {
        id: "capacitance",
        label: "Capacitance",
        type: "number",
        unit: "F",
      },
    ],
    compute: computeResonance,
    formula: "f = 1 / (2π√(LC))",
  },
  {
    id: "pfc",
    name: "Power Factor Correction",
    category: "Fundamentals",
    icon: Zap,
    kind: "calc",
    description: "Calculate capacitor size needed to correct power factor",
    keywords: ["power factor", "correction", "capacitor", "reactive power"],
    fields: [
      {
        id: "realPower",
        label: "Real Power",
        type: "number",
        unit: "kW",
      },
      {
        id: "currentPf",
        label: "Current PF",
        type: "number",
        placeholder: "0.75",
        step: "0.01",
      },
      {
        id: "targetPf",
        label: "Target PF",
        type: "number",
        placeholder: "0.95",
        step: "0.01",
      },
    ],
    compute: computePfc,
  },
  {
    id: "circular-mils",
    name: "Circular Mils / Wire Area",
    category: "Fundamentals",
    icon: Cable,
    kind: "calc",
    description: "Convert between wire gauge and circular mil area",
    keywords: ["circular mil", "wire gauge", "awg", "area"],
    fields: [
      {
        id: "size",
        label: "Wire Size",
        type: "select",
        options: [
          { value: "14", label: "14 AWG" },
          { value: "12", label: "12 AWG" },
          { value: "10", label: "10 AWG" },
          { value: "8", label: "8 AWG" },
          { value: "6", label: "6 AWG" },
        ],
      },
    ],
    compute: computeCircularMils,
  },
  {
    id: "unit-conversions",
    name: "Unit Conversions",
    category: "Fundamentals",
    icon: Cog,
    kind: "calc",
    description:
      "Convert between common electrical units (V, A, Ω, W, VA, VAR, etc.)",
    keywords: ["conversion", "unit", "voltage", "current", "power"],
    fields: [
      {
        id: "value",
        label: "Value",
        type: "number",
      },
      {
        id: "fromUnit",
        label: "From",
        type: "select",
        options: [
          { value: "v", label: "Volt (V)" },
          { value: "a", label: "Ampere (A)" },
          { value: "w", label: "Watt (W)" },
          { value: "va", label: "Volt-Ampere (VA)" },
        ],
      },
      {
        id: "toUnit",
        label: "To",
        type: "select",
        options: [
          { value: "v", label: "Volt (V)" },
          { value: "a", label: "Ampere (A)" },
          { value: "w", label: "Watt (W)" },
          { value: "va", label: "Volt-Ampere (VA)" },
        ],
      },
    ],
    compute: computeUnitConversions,
  },
];

// ============================================================================
// CONDUCTORS & RACEWAY
// ============================================================================

const conductorsTools: Tool[] = [
  {
    id: "voltage-drop",
    name: "Voltage Drop",
    category: "Conductors & Raceway",
    icon: Cable,
    kind: "calc",
    description:
      "Reactive AC/DC voltage drop calculator with kW, kVA, A, or hp load entry",
    keywords: ["voltage drop", "vd", "ac", "dc", "conductor", "wire", "distance"],
    fields: [
      {
        id: "phase",
        label: "Circuit Type",
        type: "select",
        options: [
          { value: "dc", label: "DC" },
          { value: "1ph", label: "1-Phase AC" },
          { value: "3ph", label: "3-Phase AC" },
        ],
      },
      {
        id: "voltage",
        label: "Voltage",
        type: "number",
        unit: "V",
      },
      {
        id: "current",
        label: "Current",
        type: "number",
        unit: "A",
      },
      {
        id: "distance",
        label: "Distance (one-way)",
        type: "number",
        unit: "ft",
      },
      {
        id: "wireSize",
        label: "Wire Size",
        type: "select",
        options: [
          { value: "14", label: "14 AWG" },
          { value: "12", label: "12 AWG" },
          { value: "10", label: "10 AWG" },
        ],
      },
    ],
    compute: computeVoltageDrop,
    formula: "VD = (2 × K × I × L) / CM",
  },
  {
    id: "min-wire-size",
    name: "Minimum Wire Size",
    category: "Conductors & Raceway",
    icon: Cable,
    kind: "calc",
    description:
      "Find minimum wire size for a given current or maximum voltage drop",
    keywords: ["wire size", "ampacity", "conductor", "nec"],
    fields: [
      {
        id: "current",
        label: "Current",
        type: "number",
        unit: "A",
      },
      {
        id: "material",
        label: "Material",
        type: "select",
        options: [
          { value: "cu", label: "Copper" },
          { value: "al", label: "Aluminum" },
        ],
      },
      {
        id: "insulation",
        label: "Insulation Type",
        type: "select",
        options: [
          { value: "thhn", label: "THHN" },
          { value: "thw", label: "THW" },
        ],
      },
    ],
    compute: computeMinWireSize,
    reference: "NEC Table 310.16",
  },
  {
    id: "conduit-fill",
    name: "Conduit Fill",
    category: "Conductors & Raceway",
    icon: Cable,
    kind: "calc",
    description: "Calculate conduit fill percentage per NEC Ch. 9 Table 1",
    keywords: ["conduit", "fill", "conductor", "nec"],
    fields: [
      {
        id: "conductorCount",
        label: "Number of Conductors",
        type: "number",
      },
      {
        id: "conduitSize",
        label: "Conduit Size",
        type: "select",
        options: [
          { value: "0.5", label: "1/2\"" },
          { value: "0.75", label: "3/4\"" },
          { value: "1", label: "1\"" },
        ],
      },
    ],
    compute: computeConduitFill,
    reference: "NEC Chapter 9, Table 1",
  },
  {
    id: "lighting-vd-optimizer",
    name: "Lighting Voltage Drop Optimizer",
    category: "Conductors & Raceway",
    icon: Lightbulb,
    kind: "calc",
    description: "Find optimal wire size for lighting circuits with max VD",
    keywords: ["lighting", "voltage drop", "wire size"],
    fields: [
      {
        id: "totalWattage",
        label: "Total Wattage",
        type: "number",
        unit: "W",
      },
      {
        id: "voltage",
        label: "Voltage",
        type: "number",
        unit: "V",
      },
      {
        id: "maxVd",
        label: "Max Voltage Drop %",
        type: "number",
        placeholder: "3",
        step: "0.1",
      },
      {
        id: "distance",
        label: "Distance",
        type: "number",
        unit: "ft",
      },
    ],
    compute: computeLightingVdOptimizer,
  },
];

// ============================================================================
// MOTORS & TRANSFORMERS
// ============================================================================

const motorsTools: Tool[] = [
  {
    id: "motor-hp-fla",
    name: "Motor HP / FLA",
    category: "Motors & Transformers",
    icon: Plug,
    kind: "calc",
    description: "Look up Full Load Amperes for AC motors by HP and voltage",
    keywords: ["motor", "horsepower", "fla", "flc", "full load current", "amperes", "nec"],
    fields: [
      {
        id: "hp",
        label: "Motor Horsepower",
        type: "number",
        placeholder: "5",
      },
      {
        id: "voltage",
        label: "Voltage",
        type: "select",
        options: [
          { value: "115", label: "115V" },
          { value: "208", label: "208V" },
          { value: "230", label: "230V" },
          { value: "460", label: "460V" },
        ],
      },
      {
        id: "phase",
        label: "Phase",
        type: "select",
        options: [
          { value: "1ph", label: "Single Phase" },
          { value: "3ph", label: "Three Phase" },
        ],
      },
    ],
    compute: computeMotorHpFla,
    reference: "NEC Table 430.248 / 430.250",
  },
  {
    id: "transformer-sizing",
    name: "Transformer Sizing & kVA",
    category: "Motors & Transformers",
    icon: Plug,
    kind: "calc",
    description: "Calculate transformer kVA and FLA for 1φ or 3φ",
    keywords: ["transformer", "kva", "sizing", "load"],
    fields: [
      {
        id: "voltage",
        label: "Primary Voltage",
        type: "number",
        unit: "V",
      },
      {
        id: "current",
        label: "Current",
        type: "number",
        unit: "A",
      },
      {
        id: "phase",
        label: "Phase",
        type: "select",
        options: [
          { value: "1ph", label: "Single Phase" },
          { value: "3ph", label: "Three Phase" },
        ],
      },
    ],
    compute: computeTransformerSizing,
    formula: "kVA = (V × I) / 1000",
  },
  {
    id: "tap-changer",
    name: "Tap-Changer Calculator",
    category: "Motors & Transformers",
    icon: Plug,
    kind: "calc",
    description: "Calculate output voltage when using transformer tap positions",
    keywords: ["tap", "changer", "transformer", "voltage"],
    fields: [
      {
        id: "nominalVoltage",
        label: "Nominal Voltage",
        type: "number",
        unit: "V",
      },
      {
        id: "tapPosition",
        label: "Tap Position",
        type: "select",
        options: [
          { value: "-5", label: "-5%" },
          { value: "-2.5", label: "-2.5%" },
          { value: "0", label: "0% (nominal)" },
          { value: "2.5", label: "+2.5%" },
          { value: "5", label: "+5%" },
        ],
      },
    ],
    compute: computeTapChanger,
  },
];

// ============================================================================
// POWER SYSTEMS
// ============================================================================

const powerSystemsTools: Tool[] = [
  {
    id: "short-circuit",
    name: "Short Circuit Calculation",
    category: "Power Systems",
    icon: Zap,
    kind: "calc",
    description: "Calculate short circuit current at a point in the system",
    keywords: ["short circuit", "fault current", "scc", "isc", "available fault current"],
    fields: [
      {
        id: "mva",
        label: "System MVA",
        type: "number",
        placeholder: "100",
      },
      {
        id: "baseVoltage",
        label: "Base Voltage",
        type: "number",
        unit: "kV",
      },
    ],
    compute: computeShortCircuit,
  },
  {
    id: "ups-sizing",
    name: "UPS Sizing",
    category: "Power Systems",
    icon: Zap,
    kind: "calc",
    description: "Size an uninterruptible power supply for critical loads",
    keywords: ["ups", "sizing", "backup power", "battery"],
    fields: [
      {
        id: "loadPower",
        label: "Load Power",
        type: "number",
        unit: "kW",
      },
      {
        id: "runTime",
        label: "Runtime Required",
        type: "number",
        unit: "minutes",
      },
    ],
    compute: computeUpsSizing,
  },
  {
    id: "generator-sizing",
    name: "Generator Sizing",
    category: "Power Systems",
    icon: Zap,
    kind: "calc",
    description: "Size a standby generator based on total connected load",
    keywords: ["generator", "sizing", "kw", "standby"],
    fields: [
      {
        id: "connectedLoad",
        label: "Connected Load",
        type: "number",
        unit: "kW",
      },
      {
        id: "demandFactor",
        label: "Demand Factor",
        type: "number",
        placeholder: "0.75",
        step: "0.05",
      },
    ],
    compute: computeGeneratorSizing,
  },
  {
    id: "building-load-calc",
    name: "Building Load Calculation",
    category: "Power Systems",
    icon: Zap,
    kind: "calc",
    description: "Calculate building electrical demand per NEC Article 220",
    keywords: ["load", "demand", "nec", "building"],
    fields: [
      {
        id: "area",
        label: "Building Area",
        type: "number",
        unit: "sq ft",
      },
      {
        id: "occupancyType",
        label: "Occupancy Type",
        type: "select",
        options: [
          { value: "residential", label: "Residential" },
          { value: "commercial", label: "Commercial" },
          { value: "industrial", label: "Industrial" },
        ],
      },
    ],
    compute: computeBuildingLoadCalc,
    reference: "NEC Article 220",
  },
  {
    id: "harmonics-thd",
    name: "Harmonics & THD",
    category: "Power Systems",
    icon: Waves,
    kind: "calc",
    description: "Calculate Total Harmonic Distortion (THD)",
    keywords: ["harmonic", "thd", "distortion", "power quality"],
    fields: [
      {
        id: "fundamental",
        label: "Fundamental (60 Hz)",
        type: "number",
        unit: "A",
      },
      {
        id: "harmonic3",
        label: "3rd Harmonic",
        type: "number",
        unit: "A",
      },
      {
        id: "harmonic5",
        label: "5th Harmonic",
        type: "number",
        unit: "A",
      },
    ],
    compute: computeHarmonicsTHD,
  },
  {
    id: "bess-peak-shave",
    name: "BESS Peak Shaving",
    category: "Power Systems",
    icon: Zap,
    kind: "calc",
    description:
      "Calculate battery energy storage sizing for peak demand shaving",
    keywords: ["battery", "energy storage", "peak shave", "demand"],
    fields: [
      {
        id: "peakDemand",
        label: "Peak Demand",
        type: "number",
        unit: "kW",
      },
      {
        id: "duration",
        label: "Duration",
        type: "number",
        unit: "hours",
        placeholder: "1",
      },
    ],
    compute: computeBessPeakShave,
  },
  {
    id: "lsi-breaker",
    name: "Low-Side Impedance (TCC Curves)",
    category: "Power Systems",
    icon: Zap,
    kind: "custom",
    custom: "lsi-breaker-tcc",
    description:
      "TCC (Time-Current Characteristic) curve visualizer for breaker coordination",
    keywords: ["breaker", "tcc", "coordination", "overcurrent"],
  },
];

// ============================================================================
// LIGHTING & POWER QUALITY
// ============================================================================

const lightingTools: Tool[] = [
  {
    id: "lux-fc",
    name: "Lux / Foot-Candles",
    category: "Lighting & Power Quality",
    icon: Lightbulb,
    kind: "calc",
    description: "Convert between lux and foot-candles; calculate illuminance",
    keywords: ["lux", "foot candle", "illuminance", "lighting"],
    fields: [
      {
        id: "value",
        label: "Value",
        type: "number",
      },
      {
        id: "fromUnit",
        label: "From",
        type: "select",
        options: [
          { value: "lux", label: "Lux (lx)" },
          { value: "fc", label: "Foot-Candles (fc)" },
        ],
      },
    ],
    compute: computeLuxFc,
  },
  {
    id: "inverse-square",
    name: "Inverse-Square Law",
    category: "Lighting & Power Quality",
    icon: Lightbulb,
    kind: "calc",
    description: "Calculate illuminance at a distance from a point light source",
    keywords: ["inverse square", "illuminance", "distance", "intensity"],
    fields: [
      {
        id: "intensity",
        label: "Light Intensity",
        type: "number",
        unit: "cd",
      },
      {
        id: "distance",
        label: "Distance",
        type: "number",
        unit: "ft",
      },
    ],
    compute: computeInverseSquare,
    formula: "E = I / d²",
  },
  {
    id: "photometrics",
    name: "Photometrics",
    category: "Lighting & Power Quality",
    icon: Lightbulb,
    kind: "calc",
    description:
      "Reference data: luminous flux (lm), intensity (cd), efficiency",
    keywords: ["photometric", "lumen", "candela", "efficiency"],
    fields: [
      {
        id: "lumens",
        label: "Lumens",
        type: "number",
        unit: "lm",
      },
      {
        id: "watts",
        label: "Watts",
        type: "number",
        unit: "W",
      },
    ],
    compute: computePhotometrics,
  },
];

// ============================================================================
// HAZARDOUS & INSTRUMENTATION
// ============================================================================

const hazardousTools: Tool[] = [
  {
    id: "hazardous-area-lookup",
    name: "Hazardous Area Lookup",
    category: "Hazardous & Instrumentation",
    icon: AlertTriangle,
    kind: "calc",
    description:
      "Reference NEC Article 500 hazardous location classifications",
    keywords: ["hazardous", "classified", "division", "group"],
    fields: [
      {
        id: "substance",
        label: "Substance Type",
        type: "select",
        options: [
          { value: "gas", label: "Gas / Vapor" },
          { value: "dust", label: "Dust" },
          { value: "fiber", label: "Fiber / Flyings" },
        ],
      },
    ],
    compute: computeHazardousAreaLookup,
    reference: "NEC Article 500",
  },
  {
    id: "is-loop-verifier",
    name: "Intrinsic Safety (IS) Loop Verifier",
    category: "Hazardous & Instrumentation",
    icon: AlertTriangle,
    kind: "calc",
    description:
      "Verify 4-20mA sensor loop for IS compliance (Voc, Isc, Pi, Ci)",
    keywords: ["intrinsic safety", "4-20ma", "is", "loop", "sensor"],
    fields: [
      {
        id: "supplyVoltage",
        label: "Supply Voltage",
        type: "number",
        unit: "V",
      },
      {
        id: "loopResistance",
        label: "Loop Resistance",
        type: "number",
        unit: "Ω",
      },
    ],
    compute: computeIsLoopVerifier,
  },
];

// ============================================================================
// REFERENCE TABLES & SPECIAL
// ============================================================================

const referenceTools: Tool[] = [
  {
    id: "nec-circuit-calc",
    name: "NEC Circuit Calculator",
    category: "Reference",
    icon: BookOpen,
    kind: "custom",
    custom: "nec-circuit-calc",
    description:
      "Interactive NEC Article 210 calculator for branch circuits and outlets",
    keywords: ["nec", "branch circuit", "outlet", "code"],
  },
  {
    id: "conductor-reference",
    name: "Conductor Reference Table",
    category: "Reference",
    icon: BookOpen,
    kind: "custom",
    custom: "conductor-reference",
    description: "NEC Table 310.16: Ampacity and area by size and material",
    keywords: ["conductor", "ampacity", "awg", "nec", "reference"],
  },
  {
    id: "motor-fla-tables",
    name: "Motor FLA Tables",
    category: "Reference",
    icon: BookOpen,
    kind: "custom",
    custom: "motor-fla-tables",
    description: "NEC Table 430.248 / 430.250: Motor Full Load Amperes",
    keywords: ["motor", "fla", "amperes", "nec", "table"],
  },
  {
    id: "conduit-fill-tables",
    name: "Conduit Fill Tables",
    category: "Reference",
    icon: BookOpen,
    kind: "custom",
    custom: "conduit-fill-tables",
    description: "NEC Chapter 9, Table 1 & 5: Conduit fill percentages",
    keywords: ["conduit", "fill", "nec", "table"],
  },
  {
    id: "ip-rating-chart",
    name: "IP Rating Chart",
    category: "Reference",
    icon: BookOpen,
    kind: "custom",
    custom: "ip-rating-chart",
    description: "IEC 60529: Enclosure protection ratings (dust, moisture)",
    keywords: ["ip rating", "enclosure", "protection", "nema"],
  },
  {
    id: "nema-enclosures",
    name: "NEMA Enclosure Types",
    category: "Reference",
    icon: BookOpen,
    kind: "custom",
    custom: "nema-enclosures",
    description: "NEMA 250: Standard enclosure classifications and uses",
    keywords: ["nema", "enclosure", "type", "rating"],
  },
  {
    id: "panel-schedule-ocr",
    name: "Panel Schedule (OCR)",
    category: "Reference",
    icon: AlertTriangle,
    kind: "custom",
    custom: "panel-schedule-ocr",
    description:
      "Upload an image → OCR panel labels → edit circuits → print/export",
    keywords: ["panel", "schedule", "ocr", "image", "circuit"],
  },
];

// ============================================================================
// EXPORT ALL TOOLS
// ============================================================================

export const ALL_TOOLS: Tool[] = [
  ...fundamentalsTools,
  ...conductorsTools,
  ...motorsTools,
  ...powerSystemsTools,
  ...lightingTools,
  ...hazardousTools,
  ...referenceTools,
];

export type { Tool };

// ============================================================================
// QUICK LOOKUP
// ============================================================================

export const TOOLS_BY_ID = new Map(ALL_TOOLS.map((t) => [t.id, t]));

export const TOOLS_BY_CATEGORY = new Map<string, Tool[]>();
ALL_TOOLS.forEach((tool) => {
  const key = tool.category;
  if (!TOOLS_BY_CATEGORY.has(key)) {
    TOOLS_BY_CATEGORY.set(key, []);
  }
  TOOLS_BY_CATEGORY.get(key)!.push(tool);
});

function normalizeSearchValue(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "");
}

function isFuzzyMatch(query: string, target: string): boolean {
  let qIndex = 0;
  for (let tIndex = 0; tIndex < target.length && qIndex < query.length; tIndex += 1) {
    if (target[tIndex] === query[qIndex]) {
      qIndex += 1;
    }
  }
  return qIndex === query.length;
}

function scoreTool(tool: Tool, query: string): number {
  const haystacks = [tool.name, tool.description, ...tool.keywords];
  let bestScore = 0;

  haystacks.forEach((entry) => {
    const lower = entry.toLowerCase();
    const normalized = normalizeSearchValue(entry);

    if (lower === query || normalized === query) {
      bestScore = Math.max(bestScore, 120);
    } else if (normalized.startsWith(query)) {
      bestScore = Math.max(bestScore, 95);
    } else if (normalized.includes(query) || lower.includes(query)) {
      bestScore = Math.max(bestScore, 80);
    } else if (isFuzzyMatch(query, normalized)) {
      bestScore = Math.max(bestScore, 60);
    }
  });

  return bestScore;
}

export function searchTools(query: string): Tool[] {
  const normalizedQuery = normalizeSearchValue(query);
  if (!normalizedQuery) {
    return ALL_TOOLS;
  }

  return ALL_TOOLS
    .map((tool) => ({
      tool,
      score: scoreTool(tool, normalizedQuery),
      sortName: tool.name.toLowerCase(),
    }))
    .filter((entry) => entry.score > 0)
    .sort((left, right) => right.score - left.score || left.sortName.localeCompare(right.sortName))
    .map((entry) => entry.tool);
}
