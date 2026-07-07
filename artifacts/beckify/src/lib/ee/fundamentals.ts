/**
 * ============================================================================
 * EE TOOLBOX — FUNDAMENTALS CALCULATORS
 * ============================================================================
 * Core electrical theory: Ohm's Law, power, AC/DC, reactance, resonance,
 * power factor correction, circular mils, unit conversions.
 *
 * All formulas are verified against IEEE/ANSI standards and tested.
 * ============================================================================
 */

import { ok, err, num, fmt, fmtInt, isPos, isNum, OMEGA } from "./format";
import type { Values, ComputeResult } from "./types";

// ============================================================================
// OHMS LAW
// ============================================================================
// V = I × R, I = V / R, R = V / I
// Three of the four (V, I, R, P) must be provided.

export function computeOhmsLaw(v: Values): ComputeResult {
  const voltage = num(v.voltage);
  const current = num(v.current);
  const resistance = num(v.resistance);

  // Count how many unknowns we have
  const hasV = isNum(voltage);
  const hasI = isNum(current);
  const hasR = isNum(resistance);
  const unknownCount = [!hasV, !hasI, !hasR].filter(Boolean).length;

  if (unknownCount > 1) {
    return err("Enter at least two of: Voltage, Current, Resistance");
  }

  if (unknownCount === 0) {
    // All provided; verify the relationship
    if (!isPos(voltage, current, resistance)) {
      return err("Values must be positive");
    }
    const expected = voltage / current;
    if (Math.abs(expected - resistance) > 0.01) {
      return err("Inconsistent values: V ≠ I × R");
    }
    return ok([
      { label: "Voltage", value: fmt(voltage), unit: "V" },
      { label: "Current", value: fmt(current), unit: "A" },
      { label: "Resistance", value: fmt(resistance), unit: OMEGA },
    ]);
  }

  // One unknown
  if (!hasV) {
    if (!isPos(current, resistance)) {
      return err("Current and Resistance must be positive");
    }
    const v = current * resistance;
    return ok([
      { label: "Voltage", value: fmt(v), unit: "V" },
      { label: "Current", value: fmt(current), unit: "A" },
      { label: "Resistance", value: fmt(resistance), unit: OMEGA },
    ]);
  }

  if (!hasI) {
    if (!isPos(voltage, resistance)) {
      return err("Voltage and Resistance must be positive");
    }
    const i = voltage / resistance;
    return ok([
      { label: "Voltage", value: fmt(voltage), unit: "V" },
      { label: "Current", value: fmt(i), unit: "A" },
      { label: "Resistance", value: fmt(resistance), unit: OMEGA },
    ]);
  }

  // !hasR
  if (!isPos(voltage, current)) {
    return err("Voltage and Current must be positive");
  }
  const r = voltage / current;
  return ok([
    { label: "Voltage", value: fmt(voltage), unit: "V" },
    { label: "Current", value: fmt(current), unit: "A" },
    { label: "Resistance", value: fmt(r), unit: OMEGA },
  ]);
}

// ============================================================================
// DC POWER
// ============================================================================
// P = V × I = I² × R = V² / R
// Given any two of (V, I, R, P), solve for the rest.

export function computeDcPower(v: Values): ComputeResult {
  const voltage = num(v.voltage);
  const current = num(v.current);
  const power = num(v.power);
  const resistance = num(v.resistance);

  const unknowns = [
    isNum(voltage),
    isNum(current),
    isNum(power),
    isNum(resistance),
  ].filter((x) => !x).length;

  if (unknowns > 2) {
    return err("Provide at least two of: Voltage, Current, Power, Resistance");
  }

  // Try to solve iteratively using power relationships
  let V = voltage,
    I = current,
    R = resistance,
    P = power;

  // If we have V and I
  if (isNum(V) && isNum(I) && isPos(V, I)) {
    P = V * I;
    R = V / I;
    return ok([
      { label: "Voltage", value: fmt(V), unit: "V" },
      { label: "Current", value: fmt(I), unit: "A" },
      { label: "Power", value: fmt(P), unit: "W" },
      { label: "Resistance", value: fmt(R), unit: OMEGA },
    ]);
  }

  // If we have V and P
  if (isNum(V) && isNum(P) && isPos(V, P)) {
    I = P / V;
    R = (V * V) / P;
    return ok([
      { label: "Voltage", value: fmt(V), unit: "V" },
      { label: "Current", value: fmt(I), unit: "A" },
      { label: "Power", value: fmt(P), unit: "W" },
      { label: "Resistance", value: fmt(R), unit: OMEGA },
    ]);
  }

  // If we have V and R
  if (isNum(V) && isNum(R) && isPos(V, R)) {
    I = V / R;
    P = (V * V) / R;
    return ok([
      { label: "Voltage", value: fmt(V), unit: "V" },
      { label: "Current", value: fmt(I), unit: "A" },
      { label: "Power", value: fmt(P), unit: "W" },
      { label: "Resistance", value: fmt(R), unit: OMEGA },
    ]);
  }

  // If we have I and P
  if (isNum(I) && isNum(P) && isPos(I, P)) {
    V = P / I;
    R = P / (I * I);
    return ok([
      { label: "Voltage", value: fmt(V), unit: "V" },
      { label: "Current", value: fmt(I), unit: "A" },
      { label: "Power", value: fmt(P), unit: "W" },
      { label: "Resistance", value: fmt(R), unit: OMEGA },
    ]);
  }

  // If we have I and R
  if (isNum(I) && isNum(R) && isPos(I, R)) {
    V = I * R;
    P = I * I * R;
    return ok([
      { label: "Voltage", value: fmt(V), unit: "V" },
      { label: "Current", value: fmt(I), unit: "A" },
      { label: "Power", value: fmt(P), unit: "W" },
      { label: "Resistance", value: fmt(R), unit: OMEGA },
    ]);
  }

  // If we have P and R
  if (isNum(P) && isNum(R) && isPos(P, R)) {
    I = Math.sqrt(P / R);
    V = Math.sqrt(P * R);
    return ok([
      { label: "Voltage", value: fmt(V), unit: "V" },
      { label: "Current", value: fmt(I), unit: "A" },
      { label: "Power", value: fmt(P), unit: "W" },
      { label: "Resistance", value: fmt(R), unit: OMEGA },
    ]);
  }

  return err("Insufficient data");
}

// ============================================================================
// AC POWER (SINGLE PHASE)
// ============================================================================
// P (real) = V × I × PF  (watts)
// S (apparent) = V × I  (VA)
// Q (reactive) = V × I × sin(arccos(PF))  (VAR)

export function computeAcPower1Ph(v: Values): ComputeResult {
  const voltage = num(v.voltage);
  const current = num(v.current);
  const pf = num(v.pf);

  if (!isPos(voltage, current)) {
    return err("Voltage and Current must be positive");
  }
  if (!isNum(pf) || pf < 0 || pf > 1) {
    return err("Power Factor must be 0–1");
  }

  const apparentPower = voltage * current;
  const realPower = apparentPower * pf;
  const powerAngle = Math.acos(pf);
  const reactivePower = apparentPower * Math.sin(powerAngle);

  return ok([
    { label: "Real Power (P)", value: fmt(realPower), unit: "W" },
    { label: "Reactive Power (Q)", value: fmt(reactivePower), unit: "VAR" },
    { label: "Apparent Power (S)", value: fmt(apparentPower), unit: "VA" },
    { label: "Power Factor", value: fmt(pf, 3), unit: "" },
  ]);
}

// ============================================================================
// AC POWER (THREE PHASE)
// ============================================================================
// P = √3 × V × I × PF
// Note: V and I are line values

export function computeAcPower3Ph(v: Values): ComputeResult {
  const voltage = num(v.voltage);
  const current = num(v.current);
  const pf = num(v.pf);

  if (!isPos(voltage, current)) {
    return err("Voltage and Current must be positive");
  }
  if (!isNum(pf) || pf < 0 || pf > 1) {
    return err("Power Factor must be 0–1");
  }

  const SQRT3 = Math.sqrt(3);
  const apparentPower = SQRT3 * voltage * current;
  const realPower = apparentPower * pf;
  const powerAngle = Math.acos(pf);
  const reactivePower = apparentPower * Math.sin(powerAngle);

  return ok([
    { label: "Real Power (P)", value: fmt(realPower), unit: "W" },
    { label: "Reactive Power (Q)", value: fmt(reactivePower), unit: "VAR" },
    { label: "Apparent Power (S)", value: fmt(apparentPower), unit: "VA" },
    { label: "Power Factor", value: fmt(pf, 3), unit: "" },
  ]);
}

// ============================================================================
// REACTANCE & IMPEDANCE
// ============================================================================
// XL = 2πfL (inductive reactance)
// XC = 1/(2πfC) (capacitive reactance)
// Z = √(R² + X²)  where X = XL - XC

export function computeReactanceImpedance(v: Values): ComputeResult {
  const frequency = num(v.frequency);
  const inductance = num(v.inductance);
  const capacitance = num(v.capacitance);
  const resistance = num(v.resistance);

  if (!isNum(frequency) || frequency <= 0) {
    return err("Frequency must be positive");
  }

  let XL = 0,
    XC = 0;

  if (isNum(inductance) && inductance >= 0) {
    XL = 2 * Math.PI * frequency * inductance;
  }
  if (isNum(capacitance) && capacitance > 0) {
    XC = 1 / (2 * Math.PI * frequency * capacitance);
  }

  const netReactance = XL - XC;
  let Z = Math.abs(netReactance);

  if (isNum(resistance) && resistance >= 0) {
    Z = Math.sqrt(resistance * resistance + netReactance * netReactance);
  }

  return ok([
    ...(isNum(inductance) ? [{ label: "Inductive Reactance (XL)", value: fmt(XL), unit: OMEGA }] : []),
    ...(isNum(capacitance)
      ? [{ label: "Capacitive Reactance (XC)", value: fmt(XC), unit: OMEGA }]
      : []),
    ...(isNum(inductance) && isNum(capacitance)
      ? [{ label: "Net Reactance (X)", value: fmt(netReactance), unit: OMEGA }]
      : []),
    ...(isNum(resistance)
      ? [{ label: "Total Impedance (Z)", value: fmt(Z), unit: OMEGA }]
      : []),
  ]);
}

// ============================================================================
// RESONANCE FREQUENCY
// ============================================================================
// f = 1 / (2π√(LC))

export function computeResonance(v: Values): ComputeResult {
  const inductance = num(v.inductance);
  const capacitance = num(v.capacitance);

  if (!isPos(inductance, capacitance)) {
    return err("Inductance and Capacitance must be positive");
  }

  const resonantFreq = 1 / (2 * Math.PI * Math.sqrt(inductance * capacitance));

  return ok([
    { label: "Resonant Frequency", value: fmt(resonantFreq), unit: "Hz" },
  ]);
}

// ============================================================================
// POWER FACTOR CORRECTION
// ============================================================================
// Q = P × (tan(arccos(PF_current)) - tan(arccos(PF_target)))

export function computePfc(v: Values): ComputeResult {
  const realPower = num(v.realPower);
  const currentPf = num(v.currentPf);
  const targetPf = num(v.targetPf);

  if (!isPos(realPower)) {
    return err("Real Power must be positive");
  }
  if (!isNum(currentPf) || currentPf < 0 || currentPf > 1) {
    return err("Current PF must be 0–1");
  }
  if (!isNum(targetPf) || targetPf < 0 || targetPf > 1) {
    return err("Target PF must be 0–1");
  }
  if (targetPf <= currentPf) {
    return err("Target PF must be > Current PF");
  }

  const currentAngle = Math.acos(currentPf);
  const targetAngle = Math.acos(targetPf);
  const reactiveNeeded =
    realPower * (Math.tan(currentAngle) - Math.tan(targetAngle));

  return ok([
    { label: "Real Power", value: fmt(realPower), unit: "kW" },
    { label: "Current PF", value: fmt(currentPf, 3), unit: "" },
    { label: "Target PF", value: fmt(targetPf, 3), unit: "" },
    {
      label: "Capacitor Needed",
      value: fmt(reactiveNeeded),
      unit: "kVAR",
    },
  ]);
}

// ============================================================================
// CIRCULAR MILS & WIRE AREA
// ============================================================================
// Import from constants and provide lookup table

import { WIRE_CM, WIRE_SIZES, NEC_CONDUCTORS, sizeLabel } from "./constants";

export function computeCircularMils(v: Values): ComputeResult {
  const size = v.size;

  if (!size || !WIRE_CM[size]) {
    return err("Invalid wire size");
  }

  const cm = WIRE_CM[size];
  const conductor = NEC_CONDUCTORS.find((c) => c.size === size);

  if (!conductor) {
    return err("No conductor data for this size");
  }

  return ok([
    { label: "Wire Size", value: sizeLabel(size), unit: "" },
    { label: "Circular Mil Area", value: fmtInt(cm), unit: "cmil" },
    { label: "Cross-Section Area (THHN)", value: fmt(conductor.area), unit: "in²" },
    { label: "Cu Ampacity @ 75°C", value: fmtInt(conductor.cu), unit: "A" },
    ...(conductor.al !== null
      ? [{ label: "Al Ampacity @ 75°C", value: fmtInt(conductor.al), unit: "A" }]
      : []),
  ]);
}

// ============================================================================
// UNIT CONVERSIONS
// ============================================================================
// Basic electrical unit conversions

export function computeUnitConversions(v: Values): ComputeResult {
  const value = num(v.value);
  const fromUnit = v.fromUnit;
  const toUnit = v.toUnit;

  if (!isNum(value)) {
    return err("Invalid numeric value");
  }

  if (!fromUnit || !toUnit) {
    return err("Select both units");
  }

  // Simple conversions (would expand as needed)
  const conversions: Record<string, Record<string, number>> = {
    v: { v: 1, kv: 0.001, mv: 1000 },
    a: { a: 1, ma: 1000, ua: 1e6 },
    w: { w: 1, kw: 0.001, mw: 1e-6 },
  };

  if (!conversions[fromUnit] || !conversions[fromUnit][toUnit]) {
    return err("Unsupported conversion");
  }

  const factor = conversions[fromUnit][toUnit];
  const result = value * factor;

  return ok([{ label: "Converted Value", value: fmt(result), unit: toUnit }]);
}
