import React from "react";
import type { LucideIcon } from "lucide-react";
import { Terminal } from "lucide-react";

/**
 * Standard heading used at the top of every page section.
 * Pass a title and (optionally) a subtitle/icon.
 * Display face: Exo 2 — scientific / aerospace hierarchy.
 */
export const SectionHeader = ({
  title,
  subtitle,
  icon: Icon = Terminal,
  level = "h2",
}: {
  title: string;
  subtitle?: string;
  icon?: LucideIcon | React.ComponentType<{ className?: string }>;
  /**
   * This same component renders both a page's actual title (Projects,
   * Games, Sitemap, Control Systems each have no other heading above it)
   * and a secondary section title within a page that already has its own
   * h1 (e.g. the Contact section on the About page). Defaults to h2; pass
   * "h1" at the former call sites so each page has exactly one.
   */
  level?: "h1" | "h2";
}) => {
  const Heading = level;
  return (
    <div className="mb-8">
      <div className="inline-flex items-center gap-2.5 text-[var(--accent)] mb-3">
        <div className="w-9 h-9 rounded-lg bg-[var(--accent-soft)] flex items-center justify-center">
          <Icon className="w-4.5 h-4.5" />
        </div>
        <Heading className="font-display text-2xl md:text-3xl font-bold tracking-[-0.015em] text-[var(--foreground)] leading-[1.12]">
          {title}
        </Heading>
      </div>
      {subtitle && (
        <p className="text-base text-[var(--muted)] leading-[1.65] tracking-[0.01em] max-w-2xl">
          {subtitle}
        </p>
      )}
    </div>
  );
};
