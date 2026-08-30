import { useState } from "react";
import { Activity, Cable, ExternalLink, Gauge, ShieldCheck, ShoppingBag, Wrench } from "lucide-react";
import gearHero from "@/assets/gear-hero.png";

type GearCategory = "Precision hand tools" | "Field diagnostics" | "Bench and lab";

type Gear = {
  category: GearCategory;
  name: string;
  model: string;
  bestFor: string;
  note: string;
  amazonUrl: string;
  manufacturerUrl: string;
};

const gear: Gear[] = [
  { category: "Precision hand tools", name: "Daniels Manufacturing AF8", model: "M22520/1-01 / AS22520/1 crimp frame", bestFor: "Qualified machined-contact crimping when paired with the correct approved turret or positioner.", note: "The frame alone is not a universal crimp solution; the contact family, turret, setting, and work instruction control the finished result.", amazonUrl: "https://www.amazon.com/dp/B09CV54JPN?tag=beckify-20", manufacturerUrl: "https://dmctools.com/af8-af8" },
  { category: "Precision hand tools", name: "KNIPEX EvoStrip", model: "Automatic wire stripper", bestFor: "Repeatable wire preparation for solid, stranded, and finely stranded conductors within its specified range.", note: "Confirm conductor size, insulation type, and strip length against the work package before relying on an automatic setting.", amazonUrl: "https://www.amazon.com/dp/B000R895YM?tag=beckify-20", manufacturerUrl: "https://www.knipex.com/evostrip" },
  { category: "Field diagnostics", name: "Fluke 87V Industrial Multimeter", model: "True-RMS handheld DMM", bestFor: "A rugged first meter for voltage, resistance, continuity, and current troubleshooting.", note: "Choose it for everyday field work; move to the Fluke 289 when recording intermittent measurements matters.", amazonUrl: "https://www.amazon.com/Fluke-FLUKE-87-V-Digital-Multimeter/dp/B0002YFD1K?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/digital-multimeters/fluke-87v" },
  { category: "Field diagnostics", name: "Fluke 1507 Insulation Resistance Tester", model: "50 V to 1000 V insulation tester", bestFor: "Approved insulation-resistance workflows on wiring and electrical equipment.", note: "Test voltage and isolation requirements must come from the applicable maintenance data, not this page.", amazonUrl: "https://www.amazon.com/dp/B000X4O9WI?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/insulation-testers/fluke-1507" },
  { category: "Field diagnostics", name: "Fluke 376 FC Clamp Meter with iFlex", model: "True-RMS AC/DC clamp meter", bestFor: "Current measurements around conductors that a fixed clamp jaw cannot reach.", note: "Useful for tight-access AC/DC troubleshooting, inrush capture, and non-linear loads.", amazonUrl: "https://www.amazon.com/dp/B017OVC2QM?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/clamp-meters/fluke-376-fc" },
  { category: "Bench and lab", name: "RIGOL DHO804 Digital Oscilloscope", model: "Four-channel, 70 MHz oscilloscope", bestFor: "Accessible bench diagnostics for power rails, clocks, data, and control signals.", note: "Four channels are the practical advantage when comparing several signals at once.", amazonUrl: "https://www.amazon.com/dp/B0CGHQHQN7?tag=beckify-20", manufacturerUrl: "https://mall.rigol.com/shiboqi/dho804.html" },
];

const categories = ["All", "Precision hand tools", "Field diagnostics", "Bench and lab"] as const;

const categoryGuides = [
  { category: "Precision hand tools" as const, title: "Terminate conductors", description: "Crimp, strip, and torque tools for repeatable connection work.", icon: Wrench, accent: "from-emerald-500/25 to-teal-500/5" },
  { category: "Field diagnostics" as const, title: "Diagnose electrical systems", description: "Measure voltage, resistance, insulation, and current in the field.", icon: Gauge, accent: "from-cyan-500/25 to-blue-500/5" },
  { category: "Bench and lab" as const, title: "Characterize circuits", description: "Observe waveforms, verify precision measurements, and validate test setups.", icon: Activity, accent: "from-violet-500/25 to-fuchsia-500/5" },
];

function getGearIcon(category: GearCategory) {
  if (category === "Precision hand tools") return Wrench;
  if (category === "Field diagnostics") return Gauge;
  return Activity;
}

export function GearMatrix() {
  const [category, setCategory] = useState<(typeof categories)[number]>("All");
  const visible = gear.filter((item) => category === "All" || item.category === category);

  return <section className="space-y-6" aria-labelledby="gear-title">
    <div className="grid overflow-hidden rounded-2xl border border-[var(--border)] bg-[var(--surface)] lg:grid-cols-[1.1fr_.9fr]">
      <div className="p-7 md:p-10">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Beckify gear guide</p>
        <h1 id="gear-title" className="mt-3 font-display text-4xl font-bold md:text-5xl">Recommended tools for high-consequence electrical work.</h1>
        <p className="mt-5 max-w-2xl text-[var(--muted)]">A focused list for maintenance electricians, commissioning teams, field technicians, and engineers who need dependable hand tools and measurement equipment. RF and electronics tools are included where the work requires them.</p>
        <div className="mt-8 flex flex-wrap gap-3 text-xs font-semibold"><span className="rounded-full bg-[var(--accent-soft)] px-3 py-1.5 text-[var(--accent)]">6 curated tools</span><span className="rounded-full border border-[var(--border)] px-3 py-1.5 text-[var(--muted)]">Field + bench</span><span className="rounded-full border border-[var(--border)] px-3 py-1.5 text-[var(--muted)]">Direct product links</span></div>
      </div>
      <div className="relative min-h-64 bg-slate-950"><img src={gearHero} alt="Electrical test instruments and wire harness on an engineering bench" className="absolute inset-0 h-full w-full object-cover" /><div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-slate-950/80 to-transparent p-6"><p className="text-xs font-semibold uppercase tracking-[0.16em] text-white/75">Tools selected for real work, not a shopping checklist</p></div></div>
    </div>

    <div className="card-surface grid gap-5 p-5 md:grid-cols-[auto_1fr_1fr_1fr] md:items-center" aria-label="How to use this guide"><span className="rounded-full bg-[var(--accent-soft)] px-3 py-1 text-xs font-bold text-[var(--accent)]">Start here</span><p className="m-0 text-sm leading-6 text-[var(--muted)]"><strong className="text-[var(--foreground)]">1. Define the task.</strong> Start with the connection, measurement, or signal path you need to verify.</p><p className="m-0 text-sm leading-6 text-[var(--muted)]"><strong className="text-[var(--foreground)]">2. Follow the procedure.</strong> The work instruction and safety process determine the acceptable method.</p><p className="m-0 text-sm leading-6 text-[var(--muted)]"><strong className="text-[var(--foreground)]">3. Choose the tool level.</strong> Buy retail for routine work; quote or rent specialist equipment.</p></div>

    <section aria-labelledby="category-map-title"><div className="mb-4 flex items-end justify-between gap-4"><div><p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Browse by work type</p><h2 id="category-map-title" className="mt-1 font-display text-2xl font-bold">What are you trying to do?</h2></div><Cable className="hidden h-7 w-7 text-[var(--accent)] md:block" aria-hidden="true" /></div><div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">{categoryGuides.map((guide) => { const Icon = guide.icon; return <button type="button" key={guide.category} onClick={() => setCategory(guide.category)} className={`group rounded-xl border border-[var(--border)] bg-gradient-to-br ${guide.accent} p-5 text-left transition hover:-translate-y-0.5 hover:border-[var(--accent)]/60`}><Icon className="h-8 w-8 text-[var(--accent)]" aria-hidden="true" /><h3 className="mt-7 font-display text-lg font-bold">{guide.title}</h3><p className="mt-2 text-sm leading-6 text-[var(--muted)]">{guide.description}</p><span className="mt-5 inline-flex items-center gap-1 text-xs font-semibold text-[var(--accent)]">Show recommendations <ExternalLink className="h-3.5 w-3.5" /></span></button>; })}</div></section>

    <div className="flex gap-3 rounded-xl border border-amber-400/30 bg-amber-400/5 p-4 text-sm leading-6 text-[var(--muted)]"><ShieldCheck className="mt-0.5 h-5 w-5 shrink-0 text-amber-400" aria-hidden="true" /><p className="m-0"><strong className="text-[var(--foreground)]">Safety note:</strong> These are diagnostic and maintenance-support tools. They do not certify airworthiness or replace approved maintenance data, required calibration, or the tool manufacturer’s instructions.</p></div>

    <div className="card-surface flex flex-wrap gap-2 p-4" aria-label="Filter recommendations by category">
      {categories.map((item) => <button type="button" key={item} aria-pressed={category === item} onClick={() => setCategory(item)} className={`rounded-full border px-3 py-1.5 text-xs font-semibold transition-colors ${category === item ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--accent)]" : "border-[var(--border)] text-[var(--muted)] hover:text-[var(--foreground)]"}`}>{item}</button>)}
    </div>

    <p className="text-xs text-[var(--muted)]">Disclosure: As an Amazon Associate I earn from qualifying purchases. "View on Amazon" links are paid links.</p>

    <div className="grid gap-4 md:grid-cols-2">
      {visible.map((item) => {
        const Icon = getGearIcon(item.category);
        return <article className="card-surface flex flex-col p-6" key={item.name}>
          <div className="flex items-start justify-between gap-4"><div className="rounded-xl bg-[var(--accent-soft)] p-3"><Icon className="h-5 w-5 text-[var(--accent)]" aria-hidden="true" /></div><span className="text-right text-[10px] font-bold uppercase tracking-[0.14em] text-[var(--muted)]">{item.category}</span></div>
          <h2 className="mt-5 font-display text-xl font-bold">{item.name}</h2><p className="mt-1 text-xs font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">{item.model}</p>
          <p className="mt-4 text-sm font-semibold leading-6">Best for: {item.bestFor}</p><p className="mt-3 text-sm leading-6 text-[var(--muted)]">{item.note}</p>
          <div className="mt-6 flex flex-wrap gap-x-5 gap-y-3 text-sm font-semibold"><a href={item.manufacturerUrl} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-2 text-[var(--accent)] hover:underline">Manufacturer details <ExternalLink className="h-3.5 w-3.5" /></a><a href={item.amazonUrl} target="_blank" rel="sponsored noopener noreferrer" className="inline-flex items-center gap-2 text-[var(--accent)] hover:underline"><ShoppingBag className="h-4 w-4" /> View on Amazon <span className="text-[10px] font-medium">(paid link)</span><ExternalLink className="h-3.5 w-3.5" /></a></div>
        </article>;
      })}
    </div>
  </section>;
}
