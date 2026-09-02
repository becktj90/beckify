import { Link } from "wouter";
import { ArrowUpRight, Gamepad2, MapIcon, Orbit, Rocket, Terminal, Wrench, Zap } from "lucide-react";
import { Layout } from "@/components/Layout";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { SchemaHead } from "@/components/seo/SchemaHead";
import { PUBLIC_CALCULATOR_COUNT } from "@/data/site-stats";

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
  // #008300 measured 3.69:1 against its own badge background — below the
  // 4.5:1 WCAG AA small-text minimum. This is brighter but still reads
  // clearly as "green" next to the palette's other hues.
  green: "#2ea043",
  violet: "#9085e9",
  red: "#e66767",
} as const;

const PAGES: { href: string; label: string; description: string; icon: typeof Terminal; hue: string }[] = [
  { href: "/", label: "Home", description: "Hub page — hero and links to everything below.", icon: Orbit, hue: HUES.blue },
  { href: "/about", label: "About", description: "Bio, background, and contact links.", icon: Terminal, hue: HUES.orange },
  { href: "/toolbox/", label: "Toolbox", description: `${PUBLIC_CALCULATOR_COUNT} native EE calculators, organized by category.`, icon: Wrench, hue: HUES.aqua },
  { href: "/control-systems", label: "Control System Toolbox", description: "Interactive modeling, Bode plots, PID tuning, LQR/LQG, and MPC visualizers.", icon: Zap, hue: HUES.violet },
  { href: "/projects", label: "Projects", description: "Vespa EV conversion, Sniffmaster, and other builds.", icon: Rocket, hue: HUES.yellow },
  { href: "/projects/vespa-p200e", label: "Vespa P200E EV Conversion", description: "A first-person 72V electric Vespa build log.", icon: Rocket, hue: HUES.orange },
  { href: "/gear", label: "Recommended Electrical Test Equipment", description: "Model-specific hand tools, electrical testers, bench instruments, RF gear, and budget picks.", icon: Wrench, hue: HUES.aqua },
  { href: "/made-in-america", label: "American-Made Electrical Tools", description: "Verified U.S.-made hand tools and supplies with exact model numbers and sourcing notes.", icon: Wrench, hue: HUES.green },
  { href: "/games", label: "Games", description: "Cosmic Cadet, Pup Planet, HexGL, Finger Runner, Toot Troopers, Booty Butt Scooter, and New Glenn Runner.", icon: Gamepad2, hue: HUES.magenta },
];

/**
 * The toolbox is a standalone app under /toolbox/, so this mirrors its actual
 * sidebar groups and deep-links into each one. It is a hand-maintained list
 * rather than a generated one — the toolbox is not a React module, so there is
 * nothing to import. Keep it in step with the sidebar in
 * public/toolbox/index.html.
 */
interface ToolboxCategory {
  label: string;
  hue: string;
  /** Section id in the toolbox app, linked as /toolbox/#<anchor>. */
  anchor: string;
  tools: string[];
}

const TOOLBOX_CATEGORIES: ToolboxCategory[] = [
  {
    label: "Fundamentals", hue: HUES.blue, anchor: "sec-ohm",
    tools: ["Ohm's Law", "DC Power", "Power & Current Converter", "AC Power"],
  },
  {
    label: "AC Circuits", hue: HUES.orange, anchor: "sec-reactance",
    tools: ["Reactance & Impedance", "Resonance", "Power Factor Correction"],
  },
  {
    label: "Series / Parallel", hue: HUES.violet, anchor: "sec-sp",
    tools: ["Resistance, C, L"],
  },
  {
    label: "Distribution", hue: HUES.aqua, anchor: "sec-vdrop",
    tools: [
      "Voltage Drop", "Conductor Length by Resistance", "Motor Calculations", "Transformer", "Transformer Engine",
      "Transformer Sizing", "Conduit Fill", "Conduit Fill (Mixed)",
      "Wire Size & Ampacity", "Short Circuit",
      "Load Factors & Capacity",
    ],
  },
  {
    label: "Power Systems", hue: HUES.yellow, anchor: "sec-ups",
    tools: ["UPS Sizing", "Generator Sizing", "Hybrid Generator"],
  },
  {
    label: "E-Bike Build", hue: HUES.green, anchor: "sec-ebike-tools",
    tools: ["Torque/RPM Calculator", "Sprocket Ratio Calculator", "E-Bike Range Planner"],
  },
  {
    label: "NEC Calculations", hue: HUES.magenta, anchor: "sec-nec",
    tools: ["NEC Circuit Calculator"],
  },
  {
    label: "NEC Specialized", hue: HUES.violet, anchor: "sec-lighting-opt",
    tools: ["Lighting VD Optimizer", "Building Load Calculator"],
  },
  {
    label: "Advanced", hue: HUES.blue, anchor: "sec-lsi",
    tools: ["LSI Breaker Visualizer", "BESS Peak-Shave", "Tap-Changer Calc", "Harmonics Tool"],
  },
  {
    label: "Hazardous & Safety", hue: HUES.red, anchor: "sec-haz",
    tools: ["Hazardous Area Lookup", "IS Loop Verifier"],
  },
  {
    label: "Tools", hue: HUES.orange, anchor: "sec-convert",
    tools: ["555 Timer", "Unit Conversions", "Circular Mils", "Photometrics", "Panel Schedule Load Analyzer", "Panel Schedule Power Study"],
  },
  {
    label: "Reference Tables", hue: HUES.violet, anchor: "sec-wire-ref",
    tools: [
      "Conductor Reference", "Motor FLA Tables", "Conduit Fill Tables",
      "IP Rating Chart", "NEMA Enclosures", "NEC Code Tables",
    ],
  },
  {
    label: "Workspace", hue: HUES.aqua, anchor: "sec-projects",
    tools: ["Saved Jobs & Settings"],
  },
];

const TOOLBOX_TOOL_COUNT = PUBLIC_CALCULATOR_COUNT;

export default function SiteMapPage() {

  return (
    <Layout>
      <SchemaHead
        title="Beckify Site Map | Engineering Tools and Projects"
        description="Browse every Beckify page, electrical engineering calculator, reference table, field test tool, project, and game."
        path="/sitemap"
      />
      <FadeIn>
        <SectionHeader
          title="Site Map"
          level="h1"
          subtitle="Every page and every calculator on Beckify, in one place."
          icon={MapIcon}
        />
      </FadeIn>

      <FadeIn delay={0.05}>
        <h2 className="font-display text-xl font-bold tracking-tight text-[var(--foreground)] mb-4">
          All pages
        </h2>
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
            {TOOLBOX_TOOL_COUNT} calculators in the public toolbox — open any group directly.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {TOOLBOX_CATEGORIES.map(({ label, hue, anchor, tools }) => (
            /* The toolbox is a separate app, so this is a real navigation
               rather than a client-side route. */
            <a
              key={label}
              href={`/toolbox/#${anchor}`}
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
                  <h3 className="font-display text-sm font-semibold text-[var(--foreground)]">{label}</h3>
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
                    key={tool}
                    className="text-[11px] px-2 py-1 rounded-md bg-[var(--surface)] border border-[var(--border)] text-[var(--muted)]"
                  >
                    {tool}
                  </span>
                ))}
              </div>
            </a>
          ))}
        </div>
      </FadeIn>
    </Layout>
  );
}
