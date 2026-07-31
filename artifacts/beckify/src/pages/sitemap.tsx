import { Link } from "wouter";
import { ArrowUpRight, MapIcon, Terminal, Wrench, Rocket, Gamepad2, Orbit } from "lucide-react";
import { Layout } from "@/components/Layout";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { ALL_TOOLS } from "@/data/tools";
import type { ToolCategory } from "@/lib/ee/types";

/**
 * Fixed-order categorical palette (validated for CVD-safety + contrast on
 * the site's dark surface — see dataviz skill palette.md). Each section
 * below assigns from slot 1 independently; reused across sections is
 * intentional, not a cycle within one dimension.
 */
const HUES = {
  blue: "#3987e5",
  orange: "#d95926",
  aqua: "#199e70",
  yellow: "#c98500",
  magenta: "#d55181",
  green: "#008300",
  violet: "#9085e9",
  red: "#e66767",
} as const;

const PAGES: { href: string; label: string; description: string; icon: typeof Terminal; hue: string }[] = [
  { href: "/", label: "Home", description: "Hub page — hero and links to everything below.", icon: Orbit, hue: HUES.blue },
  { href: "/about", label: "About", description: "Bio, background, and contact links.", icon: Terminal, hue: HUES.orange },
  { href: "/toolbox", label: "Toolbox", description: "26+ native EE calculators, organized by category.", icon: Wrench, hue: HUES.aqua },
  { href: "/projects", label: "Projects", description: "Vespa EV conversion, Sniffmaster, and other builds.", icon: Rocket, hue: HUES.yellow },
  { href: "/games", label: "Games", description: "Finger Runner and arcade extras.", icon: Gamepad2, hue: HUES.magenta },
];

const CATEGORY_HUES: Record<ToolCategory, string> = {
  "Fundamentals": HUES.blue,
  "Conductors & Raceway": HUES.orange,
  "Motors & Transformers": HUES.aqua,
  "Power Systems": HUES.yellow,
  "Lighting & Power Quality": HUES.magenta,
  "Hazardous & Instrumentation": HUES.red,
  "Reference": HUES.violet,
};

const CATEGORY_ORDER: ToolCategory[] = [
  "Fundamentals",
  "Conductors & Raceway",
  "Motors & Transformers",
  "Power Systems",
  "Lighting & Power Quality",
  "Hazardous & Instrumentation",
  "Reference",
];

export default function SiteMapPage() {
  const toolsByCategory = new Map<ToolCategory, typeof ALL_TOOLS>();
  for (const tool of ALL_TOOLS) {
    const list = toolsByCategory.get(tool.category) ?? [];
    list.push(tool);
    toolsByCategory.set(tool.category, list);
  }

  return (
    <Layout>
      <FadeIn>
        <SectionHeader
          title="Site Map"
          subtitle="Every page and every calculator on Beckify, in one place."
          icon={MapIcon}
        />
      </FadeIn>

      <FadeIn delay={0.05}>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
          {PAGES.map(({ href, label, description, icon: Icon, hue }) => (
            <Link
              key={href}
              href={href}
              className="card-surface group flex flex-col gap-3 p-5 rounded-2xl relative overflow-hidden"
              style={{ borderColor: `color-mix(in srgb, ${hue} 30%, var(--border))` }}
            >
              <div
                className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-300"
                style={{ background: `radial-gradient(ellipse at 30% 0%, ${hue}22 0%, transparent 65%)` }}
              />
              <div className="relative z-10 flex items-start justify-between">
                <div
                  className="w-10 h-10 rounded-xl flex items-center justify-center"
                  style={{ background: `${hue}26` }}
                >
                  <Icon className="w-4.5 h-4.5" style={{ color: hue }} />
                </div>
                <ArrowUpRight className="w-4 h-4 text-[var(--muted)] group-hover:-translate-y-0.5 group-hover:translate-x-0.5 transition-transform duration-200" style={{ color: hue }} />
              </div>
              <div className="relative z-10">
                <h3 className="font-display text-base font-semibold text-[var(--foreground)]">{label}</h3>
                <p className="text-xs text-[var(--muted)] leading-relaxed mt-1">{description}</p>
              </div>
            </Link>
          ))}
        </div>
      </FadeIn>

      <FadeIn delay={0.1}>
        <div className="mb-8">
          <h2 className="font-display text-xl font-bold tracking-tight text-[var(--foreground)] mb-1">
            Toolbox categories
          </h2>
          <p className="text-sm text-[var(--muted)]">
            {ALL_TOOLS.length} calculators across {CATEGORY_ORDER.length} categories — click any card to open the toolbox.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {CATEGORY_ORDER.map((category) => {
            const tools = toolsByCategory.get(category) ?? [];
            const hue = CATEGORY_HUES[category];
            return (
              <Link
                key={category}
                href="/toolbox"
                className="card-surface group p-5 rounded-2xl relative overflow-hidden block"
                style={{ borderColor: `color-mix(in srgb, ${hue} 30%, var(--border))` }}
              >
                <div
                  className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-300"
                  style={{ background: `radial-gradient(ellipse at 90% 0%, ${hue}1a 0%, transparent 60%)` }}
                />
                <div className="relative z-10 flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2.5">
                    <span className="w-2.5 h-2.5 rounded-full" style={{ background: hue }} />
                    <h3 className="font-display text-sm font-semibold text-[var(--foreground)]">{category}</h3>
                  </div>
                  <span
                    className="text-[10px] font-semibold tracking-[0.1em] uppercase px-2 py-0.5 rounded-full"
                    style={{ background: `${hue}26`, color: hue }}
                  >
                    {tools.length} tool{tools.length === 1 ? "" : "s"}
                  </span>
                </div>
                <div className="relative z-10 flex flex-wrap gap-1.5">
                  {tools.map((tool) => (
                    <span
                      key={tool.id}
                      className="text-[11px] px-2 py-1 rounded-md bg-[var(--surface)] border border-[var(--border)] text-[var(--muted)]"
                    >
                      {tool.name}
                    </span>
                  ))}
                </div>
              </Link>
            );
          })}
        </div>
      </FadeIn>
    </Layout>
  );
}
