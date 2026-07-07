/**
 * ============================================================================
 * EE TOOLBOX — TOOL FRAMEWORK TYPES
 * ============================================================================
 * Most calculators are "inputs → compute → result rows", so they're defined
 * declaratively as a `CalcSpec`. A handful of richer tools (dynamic rows, a
 * TCC chart, an OCR panel-schedule builder, reference tables) render a custom
 * React component instead, keyed by `custom`.
 * ============================================================================
 */

import type { LucideIcon } from "lucide-react";
import type { ComputeResult, ResultRow } from "./format";

export type Values = Record<string, string>;

export type FieldType = "number" | "select";

export interface SelectOption {
  value: string;
  label: string;
}

export interface Field {
  id: string;
  label: string;
  type?: FieldType; // defaults to "number"
  unit?: string;
  placeholder?: string;
  default?: string;
  step?: string;
  min?: number;
  options?: SelectOption[]; // for selects
  help?: string;
  /** Only render this field when the predicate over current values is true. */
  showIf?: (v: Values) => boolean;
  /** Layout hint — full-width row inside the form grid. */
  full?: boolean;
}

export type ToolCategory =
  | "Fundamentals"
  | "Conductors & Raceway"
  | "Motors & Transformers"
  | "Power Systems"
  | "Lighting & Power Quality"
  | "Hazardous & Instrumentation"
  | "Reference";

export interface BaseTool {
  id: string;
  name: string;
  category: ToolCategory;
  icon: LucideIcon;
  description: string;
  keywords: string[];
}

/** A declarative calculator: form fields + a pure compute function. */
export interface CalcSpec extends BaseTool {
  kind: "calc";
  fields: Field[];
  compute: (v: Values) => ComputeResult;
  formula?: string;
  reference?: string;
  cta?: string; // button label, defaults to "Calculate"
}

/** A tool that renders a bespoke React component (keyed by `custom`). */
export interface CustomTool extends BaseTool {
  kind: "custom";
  custom: string;
}

export type Tool = CalcSpec | CustomTool;

export type { ComputeResult, ResultRow } from "./format";
