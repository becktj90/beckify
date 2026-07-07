/**
 * ============================================================================
 * EE TOOLBOX — POWER SYSTEMS CALCULATORS
 * ============================================================================
 * Short circuit, UPS/generator sizing, building load calculations,
 * harmonics/THD, and BESS peak shaving.
 * ============================================================================
 */

import { ok, err, num, fmt, fmtInt, isPos, isNum } from "./format";
import type { Values, ComputeResult } from "./types";

// ============================================================================
// SHORT CIRCUIT CALCULATION (Point-to-Point)
// ============================================================================
// Isc = (MVA × 1000) / (√3 × V_kV)

export function computeShortCircuit(v: Values): ComputeResult {
  const mva = num(v.mva);
  const baseVoltage = num(v.baseVoltage);

  if (!isPos(mva, baseVoltage)) {
    return err("System MVA and Base Voltage must be positive");
  }

  const SQRT3 = Math.sqrt(3);
  const isc = (mva * 1000) / (SQRT3 * baseVoltage);

  return ok([
    { label: "System MVA", value: fmt(mva), unit: "MVA" },
    { label: "Base Voltage", value: fmt(baseVoltage), unit: "kV" },
    { label: "Short Circuit Current", value: fmt(isc), unit: "A" },
    {
      label: "Symmetrical RMS",
      value: fmt(isc),
      unit: "A",
      note: "Peak SCC = Isc × 1.414",
    },
  ]);
}

// ============================================================================
// UPS SIZING
// ============================================================================
// UPS capacity (kVA) ≥ load, run time determines battery size

export function computeUpsSizing(v: Values): ComputeResult {
  const loadPower = num(v.loadPower);
  const runTime = num(v.runTime);

  if (!isPos(loadPower)) {
    return err("Load Power must be positive");
  }

  if (!isNum(runTime) || runTime < 1) {
    return err("Runtime must be at least 1 minute");
  }

  // Assume 0.8 power factor
  const pf = 0.8;
  const upsKva = loadPower / pf;
  const energyNeeded = (loadPower * runTime) / 60; // kWh

  // Rough battery sizing (assuming 48V nominal, usable 50%)
  const batteryCapacity = energyNeeded / 0.048 / 0.5; // Ah

  return ok([
    { label: "Load Power", value: fmt(loadPower), unit: "kW" },
    { label: "Runtime Required", value: fmt(runTime), unit: "min" },
    { label: "UPS Capacity (@ 0.8 PF)", value: fmt(upsKva), unit: "kVA" },
    { label: "Energy Required", value: fmt(energyNeeded), unit: "kWh" },
    {
      label: "Battery Capacity (est.)",
      value: fmtInt(batteryCapacity),
      unit: "Ah",
      note: "At 48V, 50% usable depth",
    },
  ]);
}

// ============================================================================
// GENERATOR SIZING
// ============================================================================
// Sz_gen ≥ Connected Load × Demand Factor + Start Loads

export function computeGeneratorSizing(v: Values): ComputeResult {
  const connectedLoad = num(v.connectedLoad);
  const demandFactor = num(v.demandFactor);

  if (!isPos(connectedLoad)) {
    return err("Connected Load must be positive");
  }

  if (!isNum(demandFactor) || demandFactor < 0 || demandFactor > 1) {
    return err("Demand Factor must be 0–1");
  }

  const demandLoad = connectedLoad * demandFactor;
  const startingAllowance = demandLoad * 0.25; // Rough +25% for motor starting
  const totalCapacity = demandLoad + startingAllowance;

  // Standard sizes
  const standardSizes = [5, 7.5, 10, 15, 20, 25, 30, 40, 50, 75, 100, 150];
  const recommendedSize = standardSizes.find((s) => s >= totalCapacity) || 200;

  return ok([
    { label: "Connected Load", value: fmt(connectedLoad), unit: "kW" },
    { label: "Demand Factor", value: fmt(demandFactor, 2), unit: "" },
    { label: "Demand Load", value: fmt(demandLoad), unit: "kW" },
    {
      label: "Motor Starting Allowance",
      value: fmt(startingAllowance),
      unit: "kW",
    },
    { label: "Total Capacity", value: fmt(totalCapacity), unit: "kW" },
    { label: "Recommended Size", value: fmt(recommendedSize), unit: "kW" },
  ]);
}

// ============================================================================
// BUILDING LOAD CALCULATION (Simplified, NEC Article 220)
// ============================================================================

export function computeBuildingLoadCalc(v: Values): ComputeResult {
  const area = num(v.area);
  const occupancyType = v.occupancyType;

  if (!isPos(area)) {
    return err("Building Area must be positive");
  }

  if (!occupancyType) {
    return err("Select occupancy type");
  }

  // Simplified demand factors (VA/sq.ft)
  const demandFactors: Record<string, number> = {
    residential: 3,
    commercial: 5,
    industrial: 7,
  };

  const vaPerSqft = demandFactors[occupancyType];
  const totalDemand = area * vaPerSqft;
  const totalKva = totalDemand / 1000;

  return ok([
    { label: "Building Area", value: fmtInt(area), unit: "sq ft" },
    { label: "Occupancy Type", value: occupancyType, unit: "" },
    {
      label: "Demand Factor",
      value: fmt(vaPerSqft),
      unit: "VA/sq ft",
      note: "Simplified; see NEC 220 for exact values",
    },
    { label: "Total Demand", value: fmtInt(totalDemand), unit: "VA" },
    { label: "Total Demand", value: fmt(totalKva), unit: "kVA" },
  ]);
}

// ============================================================================
// HARMONICS & THD (Total Harmonic Distortion)
// ============================================================================
// THD% = √(Σ(I_n / I_1)²) × 100, where n > 1

export function computeHarmonicsTHD(v: Values): ComputeResult {
  const fundamental = num(v.fundamental);
  const harmonic3 = num(v.harmonic3) || 0;
  const harmonic5 = num(v.harmonic5) || 0;

  if (!isPos(fundamental)) {
    return err("Fundamental current must be positive");
  }

  if ((harmonic3 < 0 || harmonic5 < 0) || !isNum(harmonic3) || !isNum(harmonic5)) {
    return err("Harmonic currents must be non-negative");
  }

  const totalHarmonicSq =
    Math.pow(harmonic3 / fundamental, 2) + Math.pow(harmonic5 / fundamental, 2);
  const thd = Math.sqrt(totalHarmonicSq) * 100;

  const rmsValue = Math.sqrt(
    Math.pow(fundamental, 2) + Math.pow(harmonic3, 2) + Math.pow(harmonic5, 2)
  );

  return ok([
    { label: "Fundamental (60 Hz)", value: fmt(fundamental), unit: "A" },
    { label: "3rd Harmonic (180 Hz)", value: fmt(harmonic3), unit: "A" },
    { label: "5th Harmonic (300 Hz)", value: fmt(harmonic5), unit: "A" },
    {
      label: "Total Harmonic Distortion",
      value: fmt(thd, 2),
      unit: "%",
    },
    { label: "True RMS Current", value: fmt(rmsValue), unit: "A" },
    {
      label: "IEEE 519 Limit",
      value: "5% (industrial), 8% (other)",
      unit: "",
    },
  ]);
}

// ============================================================================
// BESS PEAK SHAVING
// ============================================================================
// Battery discharge = Demand × Duration

export function computeBessPeakShave(v: Values): ComputeResult {
  const peakDemand = num(v.peakDemand);
  const duration = num(v.duration);

  if (!isPos(peakDemand, duration)) {
    return err("Peak Demand and Duration must be positive");
  }

  const energyDischarge = peakDemand * duration;
  const chargeTime = duration; // Assume charge period = discharge
  const chargeRate = peakDemand;

  return ok([
    { label: "Peak Demand", value: fmt(peakDemand), unit: "kW" },
    { label: "Shaving Duration", value: fmt(duration), unit: "h" },
    { label: "Energy Discharged", value: fmt(energyDischarge), unit: "kWh" },
    { label: "Charge Rate (nominal)", value: fmt(chargeRate), unit: "kW" },
    {
      label: "Notes",
      value: "Add ~20% margin for efficiency/losses",
      unit: "",
    },
  ]);
}
