/**
 * ============================================================================
 * TOOLBOX PAGE — INTEGRATED TOOLS SYSTEM
 * ============================================================================
 * New React-based toolbox replacing legacy standalone app.
 * Combines ToolLayout navigation with individual calculator components.
 * ============================================================================
 */

import { useState } from "react";
import { ToolLayout } from "./ToolLayout";
import { CalcForm } from "./CalcForm";
import { TOOLS_BY_ID } from "@/data/tools";
import type { CalcSpec, CustomTool } from "@/lib/ee/types";

export function ToolboxPage() {
  const [selectedToolId, setSelectedToolId] = useState<string>("ohms-law");

  const selectedTool = TOOLS_BY_ID.get(selectedToolId);

  return (
    <div className="min-h-screen bg-[var(--background)] text-[var(--foreground)]">
      <div className="flex flex-col md:flex-row min-h-screen">
        {/* Navigation sidebar + search (moves above content on mobile) */}
        <div className="w-full md:w-80 md:min-h-screen border-b md:border-b-0 md:border-r border-[var(--border)] overflow-y-auto">
          <ToolLayout
            selectedToolId={selectedToolId}
            onSelectTool={setSelectedToolId}
          />
        </div>

        {/* Tool content area */}
        <div className="flex-1 overflow-y-auto p-6 md:p-8">
          {selectedTool ? (
            <div className="max-w-2xl mx-auto space-y-8">
              {/* Header */}
              <div className="space-y-3">
                <div className="flex items-center gap-3">
                  {selectedTool.icon && (
                    <div className="p-2 rounded-lg bg-[var(--accent-soft)]">
                      <selectedTool.icon className="w-6 h-6 text-[var(--accent)]" />
                    </div>
                  )}
                  <div>
                    <h1 className="text-3xl font-bold text-[var(--foreground)]">
                      {selectedTool.name}
                    </h1>
                    <p className="text-sm text-[var(--muted)]">
                      {selectedTool.category}
                    </p>
                  </div>
                </div>
                <p className="text-base text-[var(--muted)]">
                  {selectedTool.description}
                </p>
              </div>

              {/* Tool content */}
              {selectedTool.kind === "calc" ? (
                <CalcForm spec={selectedTool as CalcSpec} />
              ) : (
                <div className="p-8 rounded-lg border border-[var(--border)] bg-[var(--surface)] text-center">
                  <p className="text-[var(--muted)]">
                    Custom tool: {(selectedTool as CustomTool).custom}
                  </p>
                  <p className="text-sm text-[var(--muted)] mt-2">
                    (Coming soon)
                  </p>
                </div>
              )}

              {/* Reference info */}
              {selectedTool.kind === "calc" && (selectedTool as CalcSpec).reference && (
                <div className="p-4 rounded-lg bg-[var(--surface)] border border-[var(--border)]">
                  <p className="text-xs uppercase tracking-wider font-semibold text-[var(--muted)] mb-1">
                    Reference
                  </p>
                  <p className="text-sm text-[var(--foreground)]">
                    {(selectedTool as CalcSpec).reference}
                  </p>
                </div>
              )}
            </div>
          ) : (
            <div className="flex items-center justify-center min-h-[500px]">
              <p className="text-[var(--muted)]">Tool not found</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
