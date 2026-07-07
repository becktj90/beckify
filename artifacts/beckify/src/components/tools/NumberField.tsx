/**
 * ============================================================================
 * NUMBER FIELD
 * ============================================================================
 * Labeled input for numeric values in calculators, with optional unit display.
 * ============================================================================
 */

import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { Field } from "@/lib/ee/types";

interface NumberFieldProps {
  field: Field;
  value: string;
  onChange: (value: string) => void;
  error?: string;
}

export function NumberField({
  field,
  value,
  onChange,
  error,
}: NumberFieldProps) {
  const { label, unit, placeholder, step, min, help } = field;

  return (
    <div className="space-y-2">
      <div className="flex items-baseline justify-between gap-2">
        <Label htmlFor={field.id} className="text-sm font-medium">
          {label}
        </Label>
        {unit && (
          <span className="text-xs text-[var(--muted)] font-mono">{unit}</span>
        )}
      </div>
      <Input
        id={field.id}
        type="number"
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        step={step || "any"}
        min={min}
        className={error ? "border-red-500 focus:border-red-500" : ""}
      />
      {help && (
        <p className="text-xs text-[var(--muted)]">{help}</p>
      )}
      {error && <p className="text-xs text-red-500">{error}</p>}
    </div>
  );
}

interface SelectFieldProps {
  field: Field;
  value: string;
  onChange: (value: string) => void;
}

export function SelectField({
  field,
  value,
  onChange,
}: SelectFieldProps) {
  const { label, options = [] } = field;

  return (
    <div className="space-y-2">
      <Label htmlFor={field.id} className="text-sm font-medium">
        {label}
      </Label>
      <select
        id={field.id}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full px-3 py-2 rounded-lg border border-[var(--border)] bg-[var(--background)] text-[var(--foreground)] focus:outline-none focus:ring-2 focus:ring-[var(--accent)] transition-colors"
      >
        <option value="">Select...</option>
        {options.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
    </div>
  );
}
