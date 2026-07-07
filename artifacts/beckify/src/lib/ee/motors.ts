/**
 * ============================================================================
 * EE TOOLBOX — MOTORS & TRANSFORMERS
 * ============================================================================
 * Motor FLA lookup, transformer sizing, tap-changer calculations.
 * All references NEC Tables 430.248, 430.250, and standard transformer math.
 * ============================================================================
 */

import { ok, err, num, fmt, fmtInt, isPos, isNum } from "./format";
import type { Values, ComputeResult } from "./types";

// Simplified motor FLA table — would expand to full NEC 430.248/430.250
// { hp: [1ph_115V, 1ph_230V, 3ph_115V, 3ph_208V, 3ph_230V, 3ph_460V] }
const MOTOR_FLA_TABLE: Record<number, Record<string, number>> = {
  1: {
    "1ph-115": 8,
    "1ph-230": 4,
    "3ph-115": 6.1,
    "3ph-208": 3.5,
    "3ph-230": 3.2,
    "3ph-460": 1.6,
  },
  2: {
    "1ph-115": 14,
    "1ph-230": 7,
    "3ph-115": 11,
    "3ph-208": 6.3,
    "3ph-230": 5.8,
    "3ph-460": 2.9,
  },
  3: {
    "1ph-115": 20,
    "1ph-230": 10,
    "3ph-115": 16,
    "3ph-208": 9.2,
    "3ph-230": 8.4,
    "3ph-460": 4.2,
  },
  5: {
    "1ph-115": 32,
    "1ph-230": 16,
    "3ph-115": 27.2,
    "3ph-208": 15.7,
    "3ph-230": 14.2,
    "3ph-460": 7.1,
  },
};

// ============================================================================
// MOTOR HP / FLA LOOKUP (NEC 430.248 / 430.250)
// ============================================================================

export function computeMotorHpFla(v: Values): ComputeResult {
  const hp = num(v.hp);
  const voltage = v.voltage;
  const phase = v.phase;

  if (!isPos(hp)) {
    return err("Horsepower must be positive");
  }

  if (!voltage || !phase) {
    return err("Select voltage and phase");
  }

  const hpKey = Math.round(hp);
  if (!MOTOR_FLA_TABLE[hpKey]) {
    return err(`FLA data not available for ${hp} HP`);
  }

  const key =
    phase === "1ph"
      ? `1ph-${voltage}`
      : `3ph-${voltage}`;

  const fla = MOTOR_FLA_TABLE[hpKey][key];

  if (!fla) {
    return err(`No data for ${hp}HP ${phase} @ ${voltage}V`);
  }

  // Branch circuit and feeder protection sizing (rough)
  const branchCircuitMax = fla * 1.25;
  const overloadDeviceMax = fla * 1.15;

  return ok([
    { label: "Motor Horsepower", value: fmt(hp), unit: "HP" },
    { label: "Voltage", value: voltage, unit: "V" },
    { label: "Phase", value: phase === "1ph" ? "Single Phase" : "Three Phase", unit: "" },
    { label: "Full Load Amperes (FLA)", value: fmt(fla), unit: "A" },
    {
      label: "Branch Circuit Max",
      value: fmt(branchCircuitMax),
      unit: "A",
      note: "NEC 430.52",
    },
    {
      label: "Overload Device Max",
      value: fmt(overloadDeviceMax),
      unit: "A",
      note: "NEC 430.32",
    },
  ]);
}

// ============================================================================
// TRANSFORMER SIZING & kVA
// ============================================================================
// 1φ: S = V × I / 1000
// 3φ: S = √3 × V × I / 1000

export function computeTransformerSizing(v: Values): ComputeResult {
  const voltage = num(v.voltage);
  const current = num(v.current);
  const phase = v.phase;

  if (!isPos(voltage, current)) {
    return err("Voltage and Current must be positive");
  }

  if (!phase) {
    return err("Select single or three phase");
  }

  let kva: number;

  if (phase === "1ph") {
    kva = (voltage * current) / 1000;
  } else {
    const SQRT3 = Math.sqrt(3);
    kva = (SQRT3 * voltage * current) / 1000;
  }

  // Standard transformer sizes (kVA)
  const standardSizes = [5, 10, 15, 25, 37.5, 50, 75, 100, 150, 200, 300];
  let recommendedSize = standardSizes.find((s) => s >= kva) || 500;

  return ok([
    { label: "Primary Voltage", value: fmt(voltage), unit: "V" },
    { label: "Primary Current", value: fmt(current), unit: "A" },
    { label: "Phase", value: phase === "1ph" ? "Single Phase" : "Three Phase", unit: "" },
    { label: "Calculated kVA", value: fmt(kva), unit: "kVA" },
    { label: "Recommended Size", value: fmt(recommendedSize), unit: "kVA" },
    {
      label: "Note",
      value: "Select next standard size",
      unit: "",
    },
  ]);
}

// ============================================================================
// TAP-CHANGER CALCULATOR
// ============================================================================
// Output voltage = Nominal × (1 + tap%)

export function computeTapChanger(v: Values): ComputeResult {
  const nominalVoltage = num(v.nominalVoltage);
  const tapPosition = num(v.tapPosition);

  if (!isPos(nominalVoltage)) {
    return err("Nominal voltage must be positive");
  }

  if (!isNum(tapPosition)) {
    return err("Invalid tap position");
  }

  const outputVoltage = nominalVoltage * (1 + tapPosition / 100);
  const change = outputVoltage - nominalVoltage;

  return ok([
    { label: "Nominal Voltage", value: fmt(nominalVoltage), unit: "V" },
    { label: "Tap Position", value: fmt(tapPosition), unit: "%" },
    { label: "Output Voltage", value: fmt(outputVoltage), unit: "V" },
    { label: "Voltage Change", value: fmt(change), unit: "V" },
  ]);
}
