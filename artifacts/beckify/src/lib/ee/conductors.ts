/**
 * ============================================================================
 * EE TOOLBOX — CONDUCTORS & RACEWAY CALCULATORS
 * ============================================================================
 * Voltage drop, wire sizing, conduit fill, and raceway calculations.
 * All calculations reference NEC Articles 210, 250, and Chapter 9.
 * ============================================================================
 */

import { ok, err, num, fmt, fmtInt, isPos, isNum } from "./format.ts";
import type { Values, ComputeResult } from "./types.ts";
import {
  K_CU,
  K_AL,
  WIRE_CM,
  NEC_CONDUCTORS,
  sizeLabel,
  WIRE_SIZES,
  EMT_SIZES,
  THHN_AREAS,
} from "./constants.ts";

// ============================================================================
// VOLTAGE DROP (NEC Article 210)
// ============================================================================
// 1φ: VD = (2 × K × I × L) / CM
// 3φ: VD = (√3 × K × I × L) / CM
// DC: same as 1φ

/**
 * `distance` is the ONE-WAY run length. The return path is already accounted
 * for by the 2 in the single-phase/DC formula and by the √3 in the three-phase
 * formula — doubling the distance as well would count it twice.
 *
 * The result is in volts directly: K is Ω·cmil/ft, so
 * (Ω·cmil/ft × A × ft) / cmil = V. It is a voltage, not a ratio, so the
 * percentage is drop ÷ supply voltage.
 */
export function computeVoltageDrop(v: Values): ComputeResult {
  const phase = v.phase;
  const voltage = num(v.voltage);
  const current = num(v.current);
  const distance = num(v.distance);
  const wireSize = v.wireSize;
  const k = v.material === "al" ? K_AL : K_CU;

  if (!isPos(voltage, current, distance)) {
    return err("Voltage, Current, and Distance must be positive");
  }

  if (!wireSize || !WIRE_CM[wireSize]) {
    return err("Invalid wire size");
  }

  const cm = WIRE_CM[wireSize];

  let voltageDrop: number;
  if (phase === "3ph") {
    voltageDrop = (Math.sqrt(3) * k * current * distance) / cm;
  } else if (phase === "1ph" || phase === "dc") {
    voltageDrop = (2 * k * current * distance) / cm;
  } else {
    return err("Invalid phase selection");
  }

  const vdPercent = (voltageDrop / voltage) * 100;

  return ok([
    { label: "Voltage Drop", value: fmt(voltageDrop), unit: "V" },
    { label: "Voltage Drop %", value: vdPercent.toFixed(2), unit: "%" },
    { label: "Voltage at Load", value: fmt(voltage - voltageDrop), unit: "V" },
    { label: "Wire Size", value: sizeLabel(wireSize), unit: "" },
    {
      label: "NEC Limit (branch/feeder)",
      value: "3% / 5%",
      unit: "",
      note:
        vdPercent > 3
          ? "Exceeds the 3% branch-circuit guidance"
          : "Within the 3% branch-circuit guidance",
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

/**
 * NEC Ch.9 Table 1 fill limits: 53% for one conductor, 31% for two, 40% for
 * more than two. The two-conductor case is the tightest because two round
 * conductors in a round raceway waste the most space.
 *
 * EMT_SIZES.area is the FULL internal area from Ch.9 Table 4; the fill
 * percentage is applied to it here. (EMT_SIZES.fill40 is the pre-computed 40%
 * column and must not be discounted a second time.)
 */
export function computeConduitFill(v: Values): ComputeResult {
  const conductorCount = num(v.conductorCount);
  const conduitSize = v.conduitSize;
  const wireSize = v.wireSize;

  if (!isNum(conductorCount) || conductorCount < 1) {
    return err("Number of conductors must be at least 1");
  }

  const conduit = EMT_SIZES.find((c) => c.size === conduitSize);
  if (!conduit) {
    return err("Select a conduit size");
  }

  const conductorArea = wireSize ? THHN_AREAS[wireSize] : undefined;
  if (typeof conductorArea !== "number") {
    return err("Select a conductor size");
  }

  const fillPercent = conductorCount === 1 ? 53 : conductorCount === 2 ? 31 : 40;
  const allowedFillArea = (conduit.area * fillPercent) / 100;
  const usedArea = conductorCount * conductorArea;
  const actualPercent = (usedArea / conduit.area) * 100;
  const pass = usedArea <= allowedFillArea;

  const minSize = EMT_SIZES.find((c) => (c.area * fillPercent) / 100 >= usedArea);

  return ok([
    {
      label: "Conductors",
      value: `${conductorCount} × ${sizeLabel(wireSize)} THHN`,
      unit: "",
    },
    { label: "Total Conductor Area", value: fmt(usedArea, 4), unit: "in²" },
    { label: `Conduit Area (${conduit.size}" EMT)`, value: fmt(conduit.area), unit: "in²" },
    { label: "Fill Limit", value: `${fillPercent}%`, unit: "" },
    { label: "Allowable Fill Area", value: fmt(allowedFillArea, 4), unit: "in²" },
    { label: "Actual Fill", value: fmt(actualPercent, 2), unit: "%" },
    {
      label: "Result",
      value: pass ? "PASS — within NEC fill limit" : "FAIL — exceeds NEC fill limit",
      unit: "",
      note: pass
        ? `Spare capacity ${fmt(allowedFillArea - usedArea, 4)} in²`
        : minSize
          ? `Smallest EMT that fits: ${minSize.size}"`
          : "Exceeds the largest EMT trade size",
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

  // Power factor = 1.0; lighting branch circuits are treated as resistive here.
  const current = totalWattage / voltage;
  const allowedVdVolts = (voltage * maxVd) / 100;

  // Single-phase branch circuit: VD = 2·K·I·L / CM, with L the one-way length.
  const k = K_CU;
  let recommendedSize: string | null = null;
  let achievedVdPercent = 0;

  for (const size of WIRE_SIZES) {
    const cm = WIRE_CM[size];
    const vdVolts = (2 * k * current * distance) / cm;
    const vdPercent = (vdVolts / voltage) * 100;

    if (vdPercent <= maxVd) {
      recommendedSize = size;
      achievedVdPercent = vdPercent;
      break;
    }
  }

  if (!recommendedSize) {
    return err(
      `No size up to ${sizeLabel(WIRE_SIZES[WIRE_SIZES.length - 1])} holds the drop ` +
        `under ${maxVd}% at ${fmt(current)} A over ${fmt(distance)} ft — split the ` +
        `circuit or raise the voltage.`,
    );
  }

  return ok([
    { label: "Load Current", value: fmt(current), unit: "A" },
    { label: "Max Allowed VD", value: fmt(allowedVdVolts), unit: "V" },
    { label: "Recommended Wire Size", value: sizeLabel(recommendedSize), unit: "" },
    { label: "Voltage Drop at That Size", value: fmt(achievedVdPercent, 2), unit: "%" },
    {
      label: "Note",
      value: "Sized for voltage drop only — confirm ampacity separately",
      unit: "",
    },
  ]);
}
