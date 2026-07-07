/**
 * ============================================================================
 * RESULT CARD
 * ============================================================================
 * Display calculation results with label and large monospace value.
 * Supports multiple result rows with units.
 * ============================================================================
 */

import type { ComputeResult } from "@/lib/ee/types";

interface ResultCardProps {
  result: ComputeResult | null;
  error?: string;
}

export function ResultCard({ result, error }: ResultCardProps) {
  if (error) {
    return (
      <div className="p-4 rounded-lg border border-red-500/30 bg-red-500/5">
        <p className="text-sm text-red-600 font-medium">Error</p>
        <p className="text-xs text-red-500 mt-1">{error}</p>
      </div>
    );
  }

  if (!result || result.rows.length === 0) {
    return null;
  }

  return (
    <div className="space-y-3">
      {result.rows.map((row, idx) => (
        <div
          key={idx}
          className="p-4 rounded-lg border border-[var(--accent)]/20 bg-[var(--accent-soft)] space-y-1"
        >
          <p className="text-xs uppercase tracking-wider font-semibold text-[var(--accent)]">
            {row.label}
          </p>
          <div className="flex items-baseline gap-2">
            <p className="text-2xl md:text-3xl font-mono font-bold text-[var(--foreground)]">
              {row.value}
            </p>
            {row.unit && (
              <p className="text-sm font-medium text-[var(--muted)]">
                {row.unit}
              </p>
            )}
          </div>
          {row.note && (
            <p className="text-xs text-[var(--muted)] pt-2">{row.note}</p>
          )}
        </div>
      ))}
    </div>
  );
}
