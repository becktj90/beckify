/**
 * ============================================================================
 * EE TOOLBOX — CONDUCTORS & RACEWAY CALCULATORS
 * ============================================================================
 * Voltage drop, wire sizing, conduit fill, and raceway calculations.
 * All calculations reference NEC Articles 210, 250, and Chapter 9.
 * ============================================================================
 */

import { ok, err, num, fmt, fmtInt, isPos, isNum } from "./format";
import type { Values, ComputeResult } from "./types";
import { K_CU, K_AL, WIRE_CM, NEC_CONDUCTORS, sizeLabel, WIRE_SIZES } from "./constants";

// ============================================================================
// VOLTAGE DROP (NEC Article 210)
// ============================================================================
// 1φ: VD = (2 × K × I × L) / CM
// 3φ: VD = (√3 × K × I × L) / CM
// DC: same as 1φ

export function computeVoltageDrop(v: Values): ComputeResult {
  const phase = v.phase;
  const voltage = num(v.voltage);
  const current = num(v.current);
  const distance = num(v.distance);
  const wireSize = v.wireSize;

  if (!isPos(voltage, current, distance)) {
    return err("Voltage, Current, and Distance must be positive");
  }

  if (!wireSize || !WIRE_CM[wireSize]) {
    return err("Invalid wire size");
  }

  const cm = WIRE_CM[wireSize];
  const k = K_CU; // Assume copper at 75°C

  let totalDistance = distance * 2; // Round-trip
  let vdRatio: number;

  if (phase === "dc") {
    vdRatio = (2 * k * current * totalDistance) / cm;
  } else if (phase === "1ph") {
    vdRatio = (2 * k * current * totalDistance) / cm;
  } else if (phase === "3ph") {
    const SQRT3 = Math.sqrt(3);
    vdRatio = (SQRT3 * k * current * totalDistance) / cm;
  } else {
    return err("Invalid phase selection");
  }

  const voltageDrop = voltage * vdRatio;
  const vdPercent = (vdRatio * 100).toFixed(2);

  return ok([
    { label: "Voltage Drop", value: fmt(voltageDrop), unit: "V" },
    { label: "Voltage Drop %", value: vdPercent, unit: "%" },
    { label: "Remaining Voltage", value: fmt(voltage - voltageDrop), unit: "V" },
    { label: "Wire Size", value: sizeLabel(wireSize), unit: "" },
    {
      label: "NEC Limit (branch/feeder)",
      value: "3% / 5%",
      unit: "",
      note: vdPercent > "3%" ? "Exceeds recommended limit" : "Within NEC recommendations",
    },
  ]);
}

// ============================================================================
// MINIMUM WIRE SIZE (for Ampacity, NEC Table 310.16)
// ============================================================================

export function computeMinWireSize(v: Values): ComputeResult {
  const current = num(v.current);
  const material = v.material;
  const insulation = v.insulation;

  if (!isPos(current)) {
    return err("Current must be positive");
  }

  if (!material || !insulation) {
    return err("Select material and insulation type");
  }

  // Find the minimum wire size that supports this amperage
  let foundSize: (typeof NEC_CONDUCTORS)[0] | null = null;

  for (const conductor of NEC_CONDUCTORS) {
    if (material === "cu" && conductor.cu >= current) {
      foundSize = conductor;
      break;
    } else if (material === "al" && conductor.al !== null && conductor.al >= current) {
      foundSize = conductor;
      break;
    }
  }

  if (!foundSize) {
    return err(`No conductor found for ${current}A @ 75°C`);
  }

  return ok([
    { label: "Minimum Wire Size", value: sizeLabel(foundSize.size), unit: "" },
    {
      label: `${material === "cu" ? "Copper" : "Aluminum"} Ampacity`,
      value: fmtInt(material === "cu" ? foundSize.cu : foundSize.al || 0),
      unit: "A",
    },
    { label: "Cross-Section Area", value: fmt(foundSize.area), unit: "in²" },
    {
      label: "Circular Mil Area",
      value: fmtInt(foundSize.cm),
      unit: "cmil",
    },
  ]);
}

// ============================================================================
// CONDUIT FILL (NEC Ch.9 Table 1)
// ============================================================================
// 40% for ≤2 conductors, 31% for 3 conductors, 40% for ≥4 conductors

export function computeConduitFill(v: Values): ComputeResult {
  const conductorCount = num(v.conductorCount);
  const conduitSize = v.conduitSize;

  if (!isNum(conductorCount) || conductorCount < 1) {
    return err("Number of conductors must be at least 1");
  }

  if (!conduitSize) {
    return err("Select conduit size");
  }

  // Simplified conduit areas (in²) — would expand with full NEC Ch.9 Table 4
  const conduitAreas: Record<string, number> = {
    "0.5": 0.122,
    "0.75": 0.219,
    "1": 0.389,
    "1.25": 0.6,
    "1.5": 0.863,
    "2": 1.363,
  };

  if (!conduitAreas[conduitSize]) {
    return err("Invalid conduit size");
  }

  const totalArea = conduitAreas[conduitSize];
  let fillPercent = 40;

  if (conductorCount === 2) {
    fillPercent = 31;
  } else if (conductorCount >= 3) {
    fillPercent = 31;
  }

  const allowedFillArea = (totalArea * fillPercent) / 100;

  return ok([
    { label: "Conduit Size", value: conduitSize + '"', unit: "" },
    { label: "Total Area", value: fmt(totalArea), unit: "in²" },
    { label: "Fill Limit", value: fillPercent + "%", unit: "" },
    {
      label: "Available Fill Area",
      value: fmt(allowedFillArea),
      unit: "in²",
    },
    {
      label: "Conductor Limit",
      value: "Per NEC Ch.9 Table 5",
      unit: "",
    },
  ]);
}

// ============================================================================
// LIGHTING VOLTAGE DROP OPTIMIZER
// ============================================================================
// Find optimal wire size for lighting circuits with max allowable VD

export function computeLightingVdOptimizer(v: Values): ComputeResult {
  const totalWattage = num(v.totalWattage);
  const voltage = num(v.voltage);
  const maxVd = num(v.maxVd);
  const distance = num(v.distance);

  if (!isPos(totalWattage, voltage, distance)) {
    return err("Wattage, Voltage, and Distance must be positive");
  }

  if (!isNum(maxVd) || maxVd < 0 || maxVd > 10) {
    return err("Max VD % must be 0–10%");
  }

  // Assume power factor = 1.0 for resistive loads
  const current = totalWattage / voltage;

  // Find wire size that keeps VD under max
  const k = K_CU;
  const totalDistance = distance * 2;
  let recommendedSize = "Cannot fit";

  for (const size of WIRE_SIZES) {
    const cm = WIRE_CM[size];
    const vdCalc = (2 * k * current * totalDistance) / cm;
    const vdPercent = (vdCalc * 100) / voltage;

    if (vdPercent <= maxVd) {
      recommendedSize = sizeLabel(size);
      break;
    }
  }

  const currentCalc = totalWattage / voltage;
  const allowedVdVolts = (voltage * maxVd) / 100;

  return ok([
    { label: "Load Current", value: fmt(currentCalc), unit: "A" },
    { label: "Max Allowed VD", value: fmt(allowedVdVolts), unit: "V" },
    { label: "Recommended Wire Size", value: recommendedSize, unit: "" },
    {
      label: "Note",
      value: "Select next larger size if not available",
      unit: "",
    },
  ]);
}
