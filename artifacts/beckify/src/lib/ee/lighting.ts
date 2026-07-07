/**
 * ============================================================================
 * EE TOOLBOX — LIGHTING CALCULATORS
 * ============================================================================
 * Lux/foot-candle conversion, inverse-square law, photometric calculations.
 * ============================================================================
 */

import { ok, err, num, fmt, isPos, isNum } from "./format";
import type { Values, ComputeResult } from "./types";

// ============================================================================
// LUX / FOOT-CANDLES CONVERSION
// ============================================================================
// 1 lux = 1 lumen per m²
// 1 foot-candle = 1 lumen per ft²
// 1 foot-candle ≈ 10.764 lux

export function computeLuxFc(v: Values): ComputeResult {
  const value = num(v.value);
  const fromUnit = v.fromUnit;

  if (!isNum(value) || value < 0) {
    return err("Value must be non-negative");
  }

  if (!fromUnit) {
    return err("Select unit");
  }

  const FC_TO_LUX = 10.764;

  let luxValue: number, fcValue: number;

  if (fromUnit === "lux") {
    luxValue = value;
    fcValue = value / FC_TO_LUX;
  } else {
    fcValue = value;
    luxValue = value * FC_TO_LUX;
  }

  return ok([
    { label: "Lux (lx)", value: fmt(luxValue), unit: "lx" },
    { label: "Foot-Candles (fc)", value: fmt(fcValue), unit: "fc" },
    {
      label: "Conversion Factor",
      value: fmt(FC_TO_LUX),
      unit: "lux/fc",
    },
  ]);
}

// ============================================================================
// INVERSE-SQUARE LAW
// ============================================================================
// E = I / d² where E = illuminance (lux), I = intensity (cd), d = distance

export function computeInverseSquare(v: Values): ComputeResult {
  const intensity = num(v.intensity);
  const distance = num(v.distance);

  if (!isPos(intensity, distance)) {
    return err("Intensity and Distance must be positive");
  }

  const illuminance = intensity / (distance * distance);
  const lumensToFloor = illuminance * (distance * distance) * Math.PI * 2; // Rough sphere

  return ok([
    { label: "Light Intensity", value: fmt(intensity), unit: "cd" },
    { label: "Distance", value: fmt(distance), unit: "ft" },
    { label: "Illuminance", value: fmt(illuminance), unit: "lux" },
    {
      label: "Illuminance (approx)",
      value: fmt(illuminance / 10.764),
      unit: "fc",
    },
  ]);
}

// ============================================================================
// PHOTOMETRICS
// ============================================================================
// Luminous efficiency = lumens / watts

export function computePhotometrics(v: Values): ComputeResult {
  const lumens = num(v.lumens);
  const watts = num(v.watts);

  if (!isPos(lumens, watts)) {
    return err("Lumens and Watts must be positive");
  }

  const efficiency = lumens / watts;

  let type = "Unknown";
  if (efficiency < 50) type = "Incandescent";
  else if (efficiency < 100) type = "Halogen/CFL";
  else type = "LED";

  return ok([
    { label: "Luminous Flux", value: fmt(lumens), unit: "lm" },
    { label: "Power", value: fmt(watts), unit: "W" },
    { label: "Luminous Efficiency", value: fmt(efficiency), unit: "lm/W" },
    { label: "Estimated Type", value: type, unit: "" },
  ]);
}
