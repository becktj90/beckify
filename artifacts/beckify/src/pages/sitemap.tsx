import { Link } from "wouter";
import { ArrowUpRight, Gamepad2, MapIcon, Orbit, Rocket, Shield, Terminal, Wrench, Zap } from "lucide-react";
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
  { href: "/privacy", label: "Privacy", description: "Privacy policy for the Beckify iOS and iPadOS app.", icon: Shield, hue: HUES.violet },
  { href: "/toolbox/", label: "Toolbox", description: `${PUBLIC_CALCULATOR_COUNT} native EE calculators, organized by category.`, icon: Wrench, hue: HUES.aqua },
  { href: "/control-systems", label: "Control System Toolbox", description: "Plant modeling, open- vs closed-loop P, root locus, lead, PID with Ziegler–Nichols and anti-windup, Bode GM/PM/ωb, pole placement.", icon: Zap, hue: HUES.violet },
  { href: "/projects", label: "Projects", description: "Vespa EV conversion, Sniffmaster, and other builds.", icon: Rocket, hue: HUES.yellow },
  { href: "/projects/vespa-p200e", label: "Vespa P200E EV Conversion", description: "A first-person 72V electric Vespa build log.", icon: Rocket, hue: HUES.orange },
  { href: "/projects/honda-xr650r", label: "Honda XR650R Electric Conversion", description: "Build in progress — 76 V XR650R mid-drive conversion workshop journal.", icon: Rocket, hue: HUES.red },
  { href: "/gear", label: "Recommended Electrical Test Equipment", description: "Model-specific hand tools, electrical testers, bench instruments, RF gear, and budget picks.", icon: Wrench, hue: HUES.aqua },
  { href: "/made-in-america", label: "American-Made Electrical Tools", description: "Verified U.S.-made hand tools and supplies with exact model numbers and sourcing notes.", icon: Wrench, hue: HUES.green },
  { href: "/games", label: "Games", description: "Cosmic Cadet, Pup Planet, Finger Runner, Toot Troopers, Booty Butt Scooter, Apollo & Rocco Run, and New Glenn Runner.", icon: Gamepad2, hue: HUES.magenta },
];

/**
 * The toolbox is a standalone app under /toolbox/, so this mirrors its actual
 * sidebar groups and deep-links into each one. It is a hand-maintained list
 * rather than a generated one — the toolbox is not a React module, so there is
 * nothing to import. Keep it in step with the sidebar in
 * public/toolbox/index.html.
 */
interface ToolboxTool {
  name: string;
  /** Section id in the toolbox app, linked as /toolbox/#<anchor>. */
  anchor: string;
}

interface ToolboxCategory {
  label: string;
  hue: string;
  /** Section id in the toolbox app, linked as /toolbox/#<anchor>. */
  anchor: string;
  tools: ToolboxTool[];
}

const t = (name: string, anchor: string): ToolboxTool => ({ name, anchor });

const TOOLBOX_CATEGORIES: ToolboxCategory[] = [
  {
    label: "Fundamentals", hue: HUES.blue, anchor: "sec-ohm",
    tools: [
      t("Ohm's Law", "sec-ohm"),
      t("Magnetic Circuit Workbench", "sec-magnetic-circuit"),
      t("Power", "sec-power-wizard"),
    ],
  },
  {
    label: "AC Circuits", hue: HUES.orange, anchor: "sec-reactance",
    tools: [
      t("Reactance & Resonance", "sec-reactance"),
      t("Phasor Diagram Workbench", "sec-phasor-diagram"),
      t("Transient Circuit Lab", "sec-transient-circuits"),
      t("Power Factor Correction", "sec-pfc"),
    ],
  },
  {
    label: "Series / Parallel", hue: HUES.violet, anchor: "sec-sp",
    tools: [t("Resistance, C, L", "sec-sp")],
  },
  {
    label: "Distribution", hue: HUES.aqua, anchor: "sec-vdrop",
    tools: [
      t("Conductors", "sec-wire-select"),
      t("Cable Schedule Generator", "sec-cable-schedule"),
      t("Motor", "sec-motor-ref"),
      t("Motor Nameplate Analyzer", "sec-motor-nameplate"),
      t("Transformer", "sec-xfmr-size"),
      t("Tap-Changer Calc", "sec-tap"),
      t("Conduit Fill", "sec-conduit"),
      t("Short Circuit", "sec-sc"),
      t("Load Factors & Capacity", "sec-load-factors"),
      t("Torque Lookup", "sec-torque-lookup"),
    ],
  },
  {
    label: "Power Systems", hue: HUES.yellow, anchor: "sec-ups",
    tools: [
      t("On-site Power", "sec-ups"),
      t("Solar Design Wizard", "sec-solar-wizard"),
      t("Battery Bank Calculator", "sec-battery-bank"),
    ],
  },
  {
    label: "E-Bike Build", hue: HUES.green, anchor: "sec-ebike-tools",
    tools: [
      t("Torque/RPM Calculator", "sec-ebike-tools"),
      t("Sprocket Ratio Calculator", "sec-ebike-tools"),
      t("E-Bike Range Planner", "sec-ebike-tools"),
      t("Battery Pack Designer", "sec-ebike-tools"),
    ],
  },
  {
    label: "NEC Calculations", hue: HUES.magenta, anchor: "sec-nec",
    tools: [t("NEC Circuit Calculator", "sec-nec")],
  },
  {
    label: "NEC Specialized", hue: HUES.violet, anchor: "sec-lighting-opt",
    tools: [
      t("Load Calculation Worksheet", "sec-bldg-load"),
    ],
  },
  {
    label: "Advanced", hue: HUES.blue, anchor: "sec-lsi",
    tools: [
      t("LSI Breaker Visualizer", "sec-lsi"),
      t("Tap-Changer Calc", "sec-tap"),
      t("Harmonics Tool", "sec-harmonics"),
      t("EMP / EMC Shielding", "sec-emp-emc"),
    ],
  },
  {
    label: "Hazardous & Safety", hue: HUES.red, anchor: "sec-haz",
    tools: [
      t("Hazardous Area Lookup", "sec-haz"),
      t("IS Loop Verifier", "sec-isloop"),
      t("I/O List Generator", "sec-io-list-generator"),
      t("Process Value / Signal Scaling", "sec-signal-scaling"),
      t("E-bus / Rack Current Budget", "sec-ebus-budget"),
      t("Modbus Address Converter", "sec-modbus-address"),
      t("PLC Timer Preset", "sec-plc-timer-preset"),
    ],
  },
  {
    label: "Phone sensors", hue: HUES.yellow, anchor: "sec-lux-meter",
    tools: [
      t("Pitch / Hum Identifier", "sec-pitch-hum"),
      t("FFT / Audio Spectrum", "sec-audio-spectrum"),
      t("Sound Level Meter", "sec-sound-level"),
      t("Lux / Light Meter", "sec-lux-meter"),
    ],
  },
  {
    label: "Tools", hue: HUES.orange, anchor: "sec-convert",
    tools: [
      t("555 Timer", "sec-555"),
      t("Unit Conversions", "sec-convert"),
      t("Number-Base Converter", "sec-base-converter"),
      t("Circular Mils", "sec-cm"),
      t("Photometrics", "sec-photometrics"),
      t("Semiconductor Device I-V", "sec-semiconductor-iv"),
      t("Fiber Link / NA", "sec-fiber-link"),
      t("Gaussian Beam", "sec-gaussian-beam"),
      t("Linear Programming Optimizer", "sec-lp-optimizer"),
      t("I/O List Generator", "sec-io-list-generator"),
      t("Process Value / Signal Scaling", "sec-signal-scaling"),
      t("E-bus / Rack Current Budget", "sec-ebus-budget"),
      t("Modbus Address Converter", "sec-modbus-address"),
      t("PLC Timer Preset", "sec-plc-timer-preset"),
      t("Pitch / Hum Identifier", "sec-pitch-hum"),
      t("FFT / Audio Spectrum", "sec-audio-spectrum"),
      t("Sound Level Meter", "sec-sound-level"),
      t("Lux / Light Meter", "sec-lux-meter"),
      t("Panel Schedule", "sec-panel-schedule"),
      t("Look Check", "sec-look-check"),
    ],
  },
  {
    label: "Reference Tables", hue: HUES.violet, anchor: "sec-wire-ref",
    tools: [
      t("Conductor Reference", "sec-wire-ref"),
      t("Motor FLA Tables (Motor tool)", "sec-motor-ref"),
      t("Conduit Fill Tables", "sec-conduit-ref"),
      t("IP Rating Chart", "sec-ip-rating"),
      t("NEMA Enclosures", "sec-nema-class"),
      t("NEMA Wiring & Color Codes", "sec-nema-wiring"),
      t("Wire colors (NEC / UL 508A)", "sec-wire-colors"),
      t("NEC Code Tables", "sec-nec-tables"),
    ],
  },
  {
    label: "Workspace", hue: HUES.aqua, anchor: "sec-projects",
    tools: [t("Saved Jobs & Settings", "sec-projects")],
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
            /* The toolbox is a separate app, so these are real navigations
               rather than client-side routes. The card is not a single link
               so each calculator can deep-link without nested anchors. */
            <div
              key={label}
              className="card-surface group p-5 rounded-2xl relative overflow-hidden"
              style={{ borderColor: `color-mix(in srgb, ${hue} 30%, var(--border))` }}
            >
              <div
                className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-300"
                style={{ background: `radial-gradient(ellipse at 90% 0%, ${hue}1a 0%, transparent 60%)` }}
              />
              <div className="relative z-10 flex items-center justify-between mb-3">
                <a href={`/toolbox/#${anchor}`} className="flex items-center gap-2.5 min-w-0">
                  <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ background: hue }} />
                  <h3 className="font-display text-sm font-semibold text-[var(--foreground)]">{label}</h3>
                </a>
                <span
                  className="text-[10px] font-semibold tracking-[0.1em] uppercase px-2 py-0.5 rounded-full"
                  style={{ background: `${hue}26`, color: hue }}
                >
                  {tools.length} tool{tools.length === 1 ? "" : "s"}
                </span>
              </div>
              <div className="relative z-10 flex flex-wrap gap-1.5">
                {tools.map((tool) => (
                  <a
                    key={`${tool.anchor}-${tool.name}`}
                    href={`/toolbox/#${tool.anchor}`}
                    className="text-[11px] px-2 py-1 rounded-md bg-[var(--surface)] border border-[var(--border)] text-[var(--muted)] transition hover:border-[var(--accent)]/50 hover:text-[var(--foreground)]"
                  >
                    {tool.name}
                  </a>
                ))}
              </div>
            </div>
          ))}
        </div>
      </FadeIn>
    </Layout>
  );
}
