import { WIRE_CM, WIRE_SIZES, sizeLabel } from "./constants.ts";

export type VoltageDropPhase = "dc" | "1ph" | "3ph";
export type VoltageDropLoadUnit = "a" | "kw" | "kva" | "hp";
export type VoltageDropDistanceUnit = "m" | "ft";
export type VoltageDropCableUnit = "mm2" | "awg";

export interface VoltageDropFormValues {
  phase: VoltageDropPhase;
  voltage: string;
  loadUnit: VoltageDropLoadUnit;
  loadValue: string;
  powerFactor: string;
  distance: string;
  distanceUnit: VoltageDropDistanceUnit;
  cableUnit: VoltageDropCableUnit;
  cableSize: string;
  limitPercent: string;
}

export interface VoltageDropBreakdownStep {
  label: string;
  expression: string;
  value: number;
  unit: string;
  note?: string;
}

export interface VoltageDropResult {
  formula: string;
  formulaSubstitution: string;
  currentA: number;
  voltageDropV: number;
  voltageDropPercent: number;
  receivingVoltageV: number;
  conductorValuePer1000: number;
  conductorValueLabel: "Rc" | "Zc";
  conductorUnitLabel: "Ω/km" | "Ω/kft";
  phaseLabel: string;
  cableLabel: string;
  areaMm2: number;
  resistancePerKm: number;
  impedancePerKm: number;
  limitPercent: number;
  limitExceeded: boolean;
  currentFormula: string;
  assumptions: string[];
  steps: VoltageDropBreakdownStep[];
}

export interface VoltageDropComputation {
  result?: VoltageDropResult;
  error?: string;
}

const COPPER_RESISTIVITY_OHM_MM2_PER_KM = 17.241;
const CIRCULAR_MILS_PER_MM2 = 1973.52524139;
const SQRT3 = Math.sqrt(3);

export const VOLTAGE_DROP_DEFAULTS: VoltageDropFormValues = {
  phase: "3ph",
  voltage: "480",
  loadUnit: "kw",
  loadValue: "30",
  powerFactor: "0.9",
  distance: "75",
  distanceUnit: "m",
  cableUnit: "mm2",
  cableSize: "35",
  limitPercent: "3",
};

export const VOLTAGE_DROP_MM2_OPTIONS = [
  "1.5",
  "2.5",
  "4",
  "6",
  "10",
  "16",
  "25",
  "35",
  "50",
  "70",
  "95",
  "120",
  "150",
  "185",
  "240",
  "300",
];

export const VOLTAGE_DROP_AWG_OPTIONS = WIRE_SIZES;

function toNumber(raw: string): number {
  if (raw.trim() === "") return Number.NaN;
  return Number(raw);
}

function isPositive(value: number): boolean {
  return Number.isFinite(value) && value > 0;
}

function round(value: number, precision = 6): number {
  const factor = 10 ** precision;
  return Math.round(value * factor) / factor;
}

function cableAreaMm2(cableUnit: VoltageDropCableUnit, cableSize: string): number | null {
  if (cableUnit === "mm2") {
    const area = Number(cableSize);
    return isPositive(area) ? area : null;
  }

  const circularMils = WIRE_CM[cableSize];
  if (!circularMils) {
    return null;
  }

  return circularMils / CIRCULAR_MILS_PER_MM2;
}

function calculateCurrent(
  phase: VoltageDropPhase,
  loadUnit: VoltageDropLoadUnit,
  loadValue: number,
  voltage: number,
  powerFactor: number
): { value?: number; formula?: string; error?: string } {
  if (loadUnit === "a") {
    return {
      value: loadValue,
      formula: `I = ${round(loadValue, 4)} A`,
    };
  }

  if (loadUnit === "kva") {
    if (phase === "3ph") {
      return {
        value: (loadValue * 1000) / (SQRT3 * voltage),
        formula: `I = (${round(loadValue, 4)} × 1000) / (√3 × ${round(voltage, 4)})`,
      };
    }

    return {
      value: (loadValue * 1000) / voltage,
      formula: `I = (${round(loadValue, 4)} × 1000) / ${round(voltage, 4)}`,
    };
  }

  if (!isPositive(powerFactor) || powerFactor > 1) {
    return { error: "Power factor must be between 0 and 1 for kW and hp loads" };
  }

  const watts = loadUnit === "kw" ? loadValue * 1000 : loadValue * 746;
  const unitLabel = loadUnit === "kw" ? "kW" : "hp";

  if (phase === "3ph") {
    return {
      value: watts / (SQRT3 * voltage * powerFactor),
      formula: `I = (${round(loadValue, 4)} ${unitLabel === "kW" ? "× 1000" : "× 746"}) / (√3 × ${round(voltage, 4)} × ${round(powerFactor, 4)})`,
    };
  }

  return {
    value: watts / (voltage * powerFactor),
    formula: `I = (${round(loadValue, 4)} ${unitLabel === "kW" ? "× 1000" : "× 746"}) / (${round(voltage, 4)} × ${round(powerFactor, 4)})`,
  };
}

export function getCableLabel(cableUnit: VoltageDropCableUnit, cableSize: string): string {
  return cableUnit === "awg" ? sizeLabel(cableSize) : `${cableSize} mm²`;
}

export function computeVoltageDrop(values: VoltageDropFormValues): VoltageDropComputation {
  const voltage = toNumber(values.voltage);
  const loadValue = toNumber(values.loadValue);
  const powerFactor = values.phase === "dc" ? 1 : toNumber(values.powerFactor);
  const distance = toNumber(values.distance);
  const limitPercent = toNumber(values.limitPercent);

  if (!isPositive(voltage)) {
    return { error: "Supply voltage must be greater than zero" };
  }

  if (!isPositive(loadValue)) {
    return { error: "Load must be greater than zero" };
  }

  if (!isPositive(distance)) {
    return { error: "Distance must be greater than zero" };
  }

  if (!isPositive(limitPercent)) {
    return { error: "Voltage-drop limit must be greater than zero" };
  }

  const areaMm2 = cableAreaMm2(values.cableUnit, values.cableSize);
  if (!areaMm2) {
    return { error: "Select a valid cable size" };
  }

  const currentCalc = calculateCurrent(
    values.phase,
    values.loadUnit,
    loadValue,
    voltage,
    powerFactor
  );

  if (currentCalc.error || !currentCalc.value || !currentCalc.formula) {
    return { error: currentCalc.error ?? "Unable to calculate load current" };
  }

  const resistancePerKm = COPPER_RESISTIVITY_OHM_MM2_PER_KM / areaMm2;
  const impedancePerKm = resistancePerKm;
  const conductorValuePer1000 =
    values.distanceUnit === "m"
      ? values.phase === "dc"
        ? resistancePerKm
        : impedancePerKm
      : (values.phase === "dc" ? resistancePerKm : impedancePerKm) * 0.3048;
  const conductorUnitLabel = values.distanceUnit === "m" ? "Ω/km" : "Ω/kft";
  const conductorValueLabel = values.phase === "dc" ? "Rc" : "Zc";
  const distanceFactor = values.phase === "3ph" ? SQRT3 : 2;
  const voltageDropV =
    (currentCalc.value * distance * distanceFactor * conductorValuePer1000) / 1000;
  const voltageDropPercent = (voltageDropV / voltage) * 100;
  const receivingVoltageV = voltage - voltageDropV;
  const phaseLabel =
    values.phase === "3ph"
      ? "3-Phase AC"
      : values.phase === "1ph"
        ? "1-Phase AC"
        : "DC";
  const cableLabel = getCableLabel(values.cableUnit, values.cableSize);
  const formula =
    values.phase === "3ph"
      ? "ΔV = (I × L × √3 × Zc) / 1000"
      : values.phase === "1ph"
        ? "ΔV = (I × L × 2 × Zc) / 1000"
        : "ΔV = (I × L × 2 × Rc) / 1000";
  const formulaSubstitution =
    values.phase === "3ph"
      ? `ΔV = (${round(currentCalc.value, 4)} × ${round(distance, 4)} × √3 × ${round(conductorValuePer1000, 6)}) / 1000`
      : `ΔV = (${round(currentCalc.value, 4)} × ${round(distance, 4)} × 2 × ${round(conductorValuePer1000, 6)}) / 1000`;

  return {
    result: {
      formula,
      formulaSubstitution,
      currentA: currentCalc.value,
      voltageDropV,
      voltageDropPercent,
      receivingVoltageV,
      conductorValuePer1000,
      conductorValueLabel,
      conductorUnitLabel,
      phaseLabel,
      cableLabel,
      areaMm2,
      resistancePerKm,
      impedancePerKm,
      limitPercent,
      limitExceeded: voltageDropPercent > limitPercent,
      currentFormula: currentCalc.formula,
      assumptions: [
        "Copper conductor resistance is derived from cross-sectional area.",
        "AC impedance is approximated with conductor resistance for fast planning.",
        "Distance is treated as one-way length per the displayed formula.",
      ],
      steps: [
        {
          label: "Load current",
          expression: currentCalc.formula,
          value: currentCalc.value,
          unit: "A",
        },
        {
          label: `${conductorValueLabel} from cable area`,
          expression: `${conductorValueLabel} = 17.241 / ${round(areaMm2, 4)}`,
          value: values.phase === "dc" ? resistancePerKm : impedancePerKm,
          unit: "Ω/km",
          note: `${cableLabel} = ${round(areaMm2, 4)} mm²`,
        },
        {
          label: "Voltage drop",
          expression: formulaSubstitution,
          value: voltageDropV,
          unit: "V",
        },
        {
          label: "Voltage-drop percentage",
          expression: `%ΔV = (${round(voltageDropV, 6)} / ${round(voltage, 4)}) × 100`,
          value: voltageDropPercent,
          unit: "%",
        },
        {
          label: "Receiving voltage",
          expression: `Vload = ${round(voltage, 4)} - ${round(voltageDropV, 6)}`,
          value: receivingVoltageV,
          unit: "V",
        },
      ],
    },
  };
}
