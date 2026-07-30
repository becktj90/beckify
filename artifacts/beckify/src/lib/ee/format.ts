/**
 * ============================================================================
 * EE TOOLBOX — SHARED FORMATTING + RESULT TYPES
 * ============================================================================
 * Pure, dependency-free helpers used by every calculator in `lib/ee`.
 * Keeping these separate makes the calculation functions easy to unit-test
 * and audit against NEC / IEEE references.
 * ============================================================================
 */

/** One line in a result panel. `kind` drives styling (header / warn / pass…). */
export interface ResultRow {
  label: string;
  value: string;
  unit?: string;
  note?: string;
  kind?: "normal" | "header" | "warn" | "pass" | "fail" | "note";
}

/** A calculator produces result rows, with an optional error message. */
export interface ComputeResult {
  rows: ResultRow[];
  error?: string;
}

export const ok = (rows: ResultRow[]): ComputeResult => ({ rows });
export const err = (error: string): ComputeResult => ({ rows: [], error });

/** Parse a raw string input into a number (NaN if empty/invalid). */
export function num(v: string | number | undefined): number {
  if (v === undefined || v === null || v === "") return NaN;
  return typeof v === "number" ? v : parseFloat(v);
}

/** True when every argument is a finite number greater than zero. */
export function isPos(...args: number[]): boolean {
  return args.every((v) => isFinite(v) && v > 0);
}

/** True when every argument is a finite number. */
export function isNum(...args: number[]): boolean {
  return args.every((v) => isFinite(v));
}

export function deg(rad: number): number {
  return (rad * 180) / Math.PI;
}

/**
 * Engineering-friendly number formatting. Large numbers get thousands
 * separators / M / G suffixes; very small values use scientific notation.
 */
export function fmt(n: number, decimals = 4): string {
  if (!isFinite(n)) return "—";
  const abs = Math.abs(n);
  if (abs >= 1e9) return (n / 1e9).toFixed(2) + "G";
  if (abs >= 1e6) return (n / 1e6).toFixed(2) + "M";
  if (abs >= 1000) return n.toLocaleString("en-US", { maximumFractionDigits: 2 });
  if (abs !== 0 && abs < 0.001) return n.toExponential(3);
  return parseFloat(n.toFixed(decimals)).toString();
}

/** Format a whole number with thousands separators. */
export function fmtInt(n: number): string {
  if (!isFinite(n)) return "—";
  return Math.round(n).toLocaleString("en-US");
}

export const OMEGA = "\u03a9"; // Ω
export const THETA = "\u03b8"; // θ
export const PASS = "\u2714"; // ✔
export const FAIL = "\u2718"; // ✘
