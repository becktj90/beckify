/**
 * ============================================================================
 * CALC FORM
 * ============================================================================
 * Render a calculator form from a CalcSpec: input fields, compute button,
 * results display. Handles form state and validation.
 * ============================================================================
 */

import { useState, useCallback } from "react";
import { Button } from "@/components/ui/button";
import { NumberField, SelectField } from "./NumberField";
import { ResultCard } from "./ResultCard";
import type { CalcSpec, Values, FieldType } from "@/lib/ee/types";

interface CalcFormProps {
  spec: CalcSpec;
}

export function CalcForm({ spec }: CalcFormProps) {
  const [values, setValues] = useState<Values>(
    Object.fromEntries(spec.fields.map((f) => [f.id, f.default || ""]))
  );
  const [result, setResult] = useState(spec.compute(values));
  const [error, setError] = useState<string>();

  const handleFieldChange = useCallback((fieldId: string, value: string) => {
    setValues((prev) => ({ ...prev, [fieldId]: value }));
  }, []);

  const handleCompute = useCallback(() => {
    try {
      setError(undefined);
      const newResult = spec.compute(values);
      setResult(newResult);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Calculation error");
      setResult(null);
    }
  }, [spec, values]);

  // Auto-compute if all required fields are filled
  const visibleFields = spec.fields.filter(
    (f) => !f.showIf || f.showIf(values)
  );
  const isComplete = visibleFields.every(
    (f) => values[f.id] !== undefined && values[f.id] !== ""
  );

  return (
    <div className="space-y-6">
      <form
        onSubmit={(e) => {
          e.preventDefault();
          handleCompute();
        }}
        className="space-y-4"
      >
        <div
          className={`grid gap-4 ${
            visibleFields.some((f) => f.full) ? "grid-cols-1" : "grid-cols-1 sm:grid-cols-2"
          }`}
        >
          {visibleFields.map((field) => (
            <div
              key={field.id}
              className={field.full ? "col-span-full" : ""}
            >
              {field.type === "select" ? (
                <SelectField
                  field={field}
                  value={values[field.id] || ""}
                  onChange={(v) => handleFieldChange(field.id, v)}
                />
              ) : (
                <NumberField
                  field={field}
                  value={values[field.id] || ""}
                  onChange={(v) => handleFieldChange(field.id, v)}
                />
              )}
            </div>
          ))}
        </div>

        {spec.formula && (
          <div className="p-3 rounded-lg bg-[var(--surface)] border border-[var(--border)]">
            <p className="text-xs uppercase tracking-wider font-semibold text-[var(--muted)] mb-1">
              Formula
            </p>
            <p className="font-mono text-sm text-[var(--foreground)]">
              {spec.formula}
            </p>
          </div>
        )}

        <Button
          type="submit"
          disabled={!isComplete}
          className="w-full"
        >
          {spec.cta || "Calculate"}
        </Button>
      </form>

      {result && <ResultCard result={result} error={error} />}
    </div>
  );
}
