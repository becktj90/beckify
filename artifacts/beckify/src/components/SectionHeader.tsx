import React from "react";
import type { LucideIcon } from "lucide-react";
import { Terminal } from "lucide-react";

/**
 * Standard heading used at the top of every page section.
 * Pass a title and (optionally) a subtitle/icon.
 */
export const SectionHeader = ({
  title,
  subtitle,
  icon: Icon = Terminal,
}: {
  title: string;
  subtitle?: string;
  icon?: LucideIcon;
}) => (
  <div className="mb-8">
    <div className="inline-flex items-center gap-2.5 text-[var(--accent)] mb-3">
      <div className="w-9 h-9 rounded-lg bg-[var(--accent-soft)] flex items-center justify-center">
        <Icon className="w-4.5 h-4.5" />
      </div>
      <h2 className="font-display text-2xl md:text-3xl font-bold tracking-tight text-[var(--foreground)]">
        {title}
      </h2>
    </div>
    {subtitle && (
      <p className="text-base text-[var(--muted)] leading-relaxed max-w-2xl">{subtitle}</p>
    )}
  </div>
);
