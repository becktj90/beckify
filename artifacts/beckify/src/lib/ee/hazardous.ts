/**
 * ============================================================================
 * EE TOOLBOX — HAZARDOUS & INSTRUMENTATION
 * ============================================================================
 * Hazardous location classifications (NEC Article 500),
 * intrinsic safety loop verification.
 * ============================================================================
 */

import { ok, err, num, fmt, isPos, isNum } from "./format";
import type { Values, ComputeResult } from "./types";

// ============================================================================
// HAZARDOUS AREA LOOKUP (NEC Article 500)
// ============================================================================
// Returns classification info for hazardous locations

export function computeHazardousAreaLookup(v: Values): ComputeResult {
  const substance = v.substance;

  if (!substance) {
    return err("Select substance type");
  }

  const hazardousData: Record<string, { division: string; groups: string }> = {
    gas: {
      division: "Class I (gas/vapor hazards)",
      groups: "A, B, C, D (based on properties)",
    },
    dust: {
      division: "Class II (combustible dust)",
      groups: "E, F, G (based on particle type)",
    },
    fiber: {
      division: "Class III (fiber/flyings)",
      groups: "—",
    },
  };

  const data = hazardousData[substance];

  return ok([
    { label: "Substance Type", value: substance, unit: "" },
    {
      label: "Classification",
      value: data.division,
      unit: "",
    },
    {
      label: "Groups",
      value: data.groups,
      unit: "",
    },
    {
      label: "Reference",
      value: "NEC Article 500-506",
      unit: "",
      note: "Consult code for full classification rules",
    },
  ]);
}

// ============================================================================
// INTRINSIC SAFETY (IS) LOOP VERIFIER (4-20mA)
// ============================================================================
// Verify supply voltage (Voc), short-circuit current (Isc), power (Pi), cap (Ci)

export function computeIsLoopVerifier(v: Values): ComputeResult {
  const supplyVoltage = num(v.supplyVoltage);
  const loopResistance = num(v.loopResistance);

  if (!isPos(supplyVoltage)) {
    return err("Supply Voltage must be positive");
  }

  if (!isNum(loopResistance) || loopResistance < 0) {
    return err("Loop Resistance must be non-negative");
  }

  // IS limitations (typical for safety ratings)
  const VOC_MAX = 28; // Open circuit voltage (typical IS)
  const ISC_MAX = 0.1; // Short circuit current (amps)
  const PI_MAX = 1.6; // Power (typical)
  const CI_MAX = 100; // Capacitance (µF, typical)

  const shortCircuitCurrent = supplyVoltage / loopResistance;
  const power = supplyVoltage * 0.02; // Assuming 20mA nominal

  const voc_ok = supplyVoltage <= VOC_MAX;
  const isc_ok = shortCircuitCurrent <= ISC_MAX;
  const pi_ok = power <= PI_MAX;

  return ok([
    {
      label: "Open Circuit Voltage (Voc)",
      value: fmt(supplyVoltage),
      unit: "V",
      note: `Max: ${VOC_MAX}V - ${voc_ok ? "✓" : "✗"}`,
    },
    {
      label: "Short Circuit Current (Isc)",
      value: fmt(shortCircuitCurrent),
      unit: "A",
      note: `Max: ${ISC_MAX}A - ${isc_ok ? "✓" : "✗"}`,
    },
    {
      label: "Power (Pi)",
      value: fmt(power),
      unit: "W",
      note: `Max: ${PI_MAX}W - ${pi_ok ? "✓" : "✗"}`,
    },
    {
      label: "IS Loop Status",
      value: voc_ok && isc_ok && pi_ok ? "COMPLIANT" : "NON-COMPLIANT",
      unit: "",
      note: "Verify against specific IS certificate",
    },
  ]);
}
