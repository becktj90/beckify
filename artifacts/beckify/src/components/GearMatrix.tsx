import { useState } from "react";
import { Activity, Cable, ExternalLink, Gauge, RadioTower, ShieldCheck, ShoppingBag, Wrench } from "lucide-react";
import gearHero from "@/assets/gear-hero.png";

type GearCategory = "Field diagnostics" | "Bench and lab" | "RF and cable";

type Gear = {
  category: GearCategory;
  name: string;
  model: string;
  bestFor: string;
  note: string;
  retailerQuery?: string;
  manufacturerUrl: string;
  purchasePath: "Amazon" | "Quote or rental";
};

const configuredAssociateTag = String(import.meta.env.VITE_AMAZON_ASSOCIATE_TAG ?? "").trim();
const AMAZON_ASSOCIATE_TAG = configuredAssociateTag || "beckify-20";
const amazonSearchUrl = (query: string) => {
  const url = new URL("https://www.amazon.com/s");
  url.searchParams.set("k", query);
  url.searchParams.set("tag", AMAZON_ASSOCIATE_TAG);
  return url.toString();
};

const gear: Gear[] = [
  { category: "Field diagnostics", name: "Fluke 87V Industrial Multimeter", model: "True-RMS handheld DMM", bestFor: "A rugged first meter for voltage, resistance, continuity, and current troubleshooting.", note: "Choose it for everyday field work; move to the Fluke 289 when recording intermittent measurements matters.", retailerQuery: "Fluke 87V Industrial Multimeter", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/digital-multimeters/fluke-87v", purchasePath: "Amazon" },
  { category: "Field diagnostics", name: "Fluke 1507 Insulation Resistance Tester", model: "50 V to 1000 V insulation tester", bestFor: "Approved insulation-resistance workflows on wiring and electrical equipment.", note: "Test voltage and isolation requirements must come from the applicable maintenance data, not this page.", retailerQuery: "Fluke 1507 Insulation Resistance Tester", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/insulation-testers/fluke-1507", purchasePath: "Amazon" },
  { category: "Field diagnostics", name: "Fluke 376 FC Clamp Meter with iFlex", model: "True-RMS AC/DC clamp meter", bestFor: "Current measurements around conductors that a fixed clamp jaw cannot reach.", note: "Useful for tight-access AC/DC troubleshooting, inrush capture, and non-linear loads.", retailerQuery: "Fluke 376 FC clamp meter", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/clamp-meters/fluke-376-fc", purchasePath: "Amazon" },
  { category: "Bench and lab", name: "RIGOL DHO804 Digital Oscilloscope", model: "Four-channel, 70 MHz oscilloscope", bestFor: "Accessible bench diagnostics for power rails, clocks, data, and control signals.", note: "Four channels are the practical advantage when comparing several signals at once.", retailerQuery: "RIGOL DHO804 digital oscilloscope", manufacturerUrl: "https://mall.rigol.com/shiboqi/dho804.html", purchasePath: "Amazon" },
  { category: "Bench and lab", name: "Fluke 8558A 8.5 Digit Multimeter", model: "Precision bench multimeter", bestFor: "Calibration-grade voltage and resistance measurement plus automated bench test.", note: "A lab procurement decision, not a replacement for a handheld field DMM.", manufacturerUrl: "https://www.fluke.com/en-us/product/calibration-tools/electrical-calibration/bench-multimeters/8558a", purchasePath: "Quote or rental" },
  { category: "Bench and lab", name: "Megger MIT1025/2", model: "10 kV insulation resistance tester", bestFor: "Advanced insulation-resistance workflows on wiring, cables, motors, and generators.", note: "Select test voltage only from the approved procedure and equipment documentation.", manufacturerUrl: "https://www.megger.com/en-us/products/advanced-5-kv-10-kv-and-15-kv-insulation-resistance-testers", purchasePath: "Quote or rental" },
  { category: "Bench and lab", name: "SCI Model 448", model: "AC/DC hipot, IR, and ground-bond tester", bestFor: "Production and lab electrical-safety validation where the test method requires a dedicated instrument.", note: "This is specialist test equipment; it should never be used as a substitute for the approved work instruction.", manufacturerUrl: "https://www.hipot.com/products-electrical-safety-tester-448.html", purchasePath: "Quote or rental" },
  { category: "Bench and lab", name: "Keysight Infiniium EXR104A", model: "1 GHz, four-channel oscilloscope", bestFor: "High-bandwidth power integrity, timing, bus, and electronics troubleshooting.", note: "The right step up when a value scope no longer has the bandwidth or analysis capability the bench needs.", manufacturerUrl: "https://www.keysight.com/us/en/product/EXR104A/infiniium-exr-series-oscilloscope-1-ghz-4-channels.html", purchasePath: "Quote or rental" },
  { category: "RF and cable", name: "RigExpert AA-230 ZOOM", model: "VHF antenna and cable analyzer", bestFor: "VHF coax, antenna, and connector/cable fault diagnostics up to 230 MHz.", note: "A practical retail tool for VHF work; it is not a general-purpose wiring tester.", retailerQuery: "RigExpert AA-230 ZOOM antenna cable analyzer", manufacturerUrl: "https://www.rigexpert.com/files/product_documentation/aa230zoom/AA-230-ZOOM_Antenna_and_Cable_Analyzer_Datasheet.EN.pdf", purchasePath: "Amazon" },
  { category: "RF and cable", name: "Anritsu Site Master S331L", model: "2 MHz to 4 GHz cable and antenna analyzer", bestFor: "Professional return loss, VSWR, cable loss, and distance-to-fault measurement.", note: "Anritsu lists aerospace and defense among its applications; use a quote or calibration-ready rental path.", manufacturerUrl: "https://www.anritsu.com/en-us/test-measurement/products/s331l", purchasePath: "Quote or rental" },
  { category: "RF and cable", name: "Fluke Networks MicroScanner PoE", model: "RJ45/RJ11 network cable verifier", bestFor: "Wiremap, length, distance-to-fault, port speed, and PoE checks in support infrastructure.", note: "It does not certify aircraft circular connectors or ARINC harnesses.", retailerQuery: "Fluke Networks MicroScanner PoE MS-POE", manufacturerUrl: "https://www.fluke.com/en-us/product/network-cable-testers/copper/ms-poe", purchasePath: "Amazon" },
];

const categories = ["All", "Field diagnostics", "Bench and lab", "RF and cable"] as const;

const categoryGuides = [
  { category: "Field diagnostics" as const, title: "Find the electrical fault", description: "Voltage, resistance, insulation, and current checks for practical field troubleshooting.", icon: Gauge, accent: "from-cyan-500/25 to-blue-500/5" },
  { category: "Bench and lab" as const, title: "See the behavior", description: "Bench instruments for waveforms, calibration-grade measurements, and controlled safety testing.", icon: Activity, accent: "from-violet-500/25 to-fuchsia-500/5" },
  { category: "RF and cable" as const, title: "Prove the signal path", description: "RF cable, antenna, connector, and network-cable diagnostics beyond basic continuity.", icon: RadioTower, accent: "from-amber-500/25 to-orange-500/5" },
];

function getGearIcon(category: GearCategory) {
  if (category === "Field diagnostics") return Gauge;
  if (category === "RF and cable") return RadioTower;
  return Activity;
}

export function GearMatrix() {
  const [category, setCategory] = useState<(typeof categories)[number]>("All");
  const visible = gear.filter((item) => category === "All" || item.category === category);

  return <section className="space-y-6" aria-labelledby="gear-title">
    <div className="grid overflow-hidden rounded-2xl border border-[var(--border)] bg-[var(--surface)] lg:grid-cols-[1.1fr_.9fr]">
      <div className="p-7 md:p-10">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Beckify gear guide</p>
        <h1 id="gear-title" className="mt-3 font-display text-4xl font-bold md:text-5xl">Recommended electrical test equipment for bench and field work.</h1>
        <p className="mt-5 max-w-2xl text-[var(--muted)]">A focused list of current, industry-recognized tools for diagnosing electrical, cable, and RF problems. Each pick identifies the job it fits, the important limit, and the correct purchase path.</p>
        <div className="mt-8 flex flex-wrap gap-3 text-xs font-semibold"><span className="rounded-full bg-[var(--accent-soft)] px-3 py-1.5 text-[var(--accent)]">11 curated tools</span><span className="rounded-full border border-[var(--border)] px-3 py-1.5 text-[var(--muted)]">Bench + field</span><span className="rounded-full border border-[var(--border)] px-3 py-1.5 text-[var(--muted)]">Manufacturer sources</span></div>
      </div>
      <div className="relative min-h-64 bg-slate-950"><img src={gearHero} alt="Electrical test instruments and wire harness on an engineering bench" className="absolute inset-0 h-full w-full object-cover" /><div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-slate-950/80 to-transparent p-6"><p className="text-xs font-semibold uppercase tracking-[0.16em] text-white/75">Tool selection starts with the failure mode</p></div></div>
    </div>

    <div className="grid gap-3 md:grid-cols-3" aria-label="Equipment selection principles">
      {[["Start with the fault", "Decide whether the task is measurement, insulation, waveform, current, or RF-path diagnosis."], ["Use the approved procedure", "Tool capability does not override aircraft, component, or manufacturer maintenance data."], ["Buy to the workflow", "Retail tools cover practical field and bench work; specialist instruments are quote, rental, and calibration decisions."]].map(([title, text], index) => <article className="card-surface p-5" key={title}><p className="text-xs font-bold uppercase tracking-[0.14em] text-[var(--accent)]">0{index + 1}</p><h2 className="mt-2 font-display text-lg font-bold">{title}</h2><p className="mt-2 text-sm leading-6 text-[var(--muted)]">{text}</p></article>)}
    </div>

    <section aria-labelledby="category-map-title"><div className="mb-4 flex items-end justify-between gap-4"><div><p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Choose a category</p><h2 id="category-map-title" className="mt-1 font-display text-2xl font-bold">Match the instrument to the diagnostic job.</h2></div><Cable className="hidden h-7 w-7 text-[var(--accent)] md:block" aria-hidden="true" /></div><div className="grid gap-3 md:grid-cols-3">{categoryGuides.map((guide) => { const Icon = guide.icon; return <button type="button" key={guide.category} onClick={() => setCategory(guide.category)} className={`group rounded-xl border border-[var(--border)] bg-gradient-to-br ${guide.accent} p-5 text-left transition hover:-translate-y-0.5 hover:border-[var(--accent)]/60`}><Icon className="h-8 w-8 text-[var(--accent)]" aria-hidden="true" /><h3 className="mt-7 font-display text-lg font-bold">{guide.title}</h3><p className="mt-2 text-sm leading-6 text-[var(--muted)]">{guide.description}</p><span className="mt-5 inline-flex items-center gap-1 text-xs font-semibold text-[var(--accent)]">View tools <ExternalLink className="h-3.5 w-3.5" /></span></button>; })}</div></section>

    <div className="flex gap-3 rounded-xl border border-amber-400/30 bg-amber-400/5 p-4 text-sm leading-6 text-[var(--muted)]"><ShieldCheck className="mt-0.5 h-5 w-5 shrink-0 text-amber-400" aria-hidden="true" /><p className="m-0"><strong className="text-[var(--foreground)]">Safety note:</strong> These are diagnostic and maintenance-support tools. They do not certify airworthiness or replace approved maintenance data, required calibration, or the tool manufacturer’s instructions.</p></div>

    <div className="card-surface flex flex-wrap gap-2 p-4" aria-label="Filter recommendations by category">
      {categories.map((item) => <button type="button" key={item} aria-pressed={category === item} onClick={() => setCategory(item)} className={`rounded-full border px-3 py-1.5 text-xs font-semibold transition-colors ${category === item ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--accent)]" : "border-[var(--border)] text-[var(--muted)] hover:text-[var(--foreground)]"}`}>{item}</button>)}
    </div>

    <p className="text-xs text-[var(--muted)]">Disclosure: As an Amazon Associate I earn from qualifying purchases. Amazon links are marked as paid links.</p>

    <div className="grid gap-4 md:grid-cols-2">
      {visible.map((item) => {
        const Icon = getGearIcon(item.category);
        return <article className="card-surface flex flex-col p-6" key={item.name}>
          <div className="flex items-start justify-between gap-4"><div className="rounded-xl bg-[var(--accent-soft)] p-3"><Icon className="h-5 w-5 text-[var(--accent)]" aria-hidden="true" /></div><span className="text-right text-[10px] font-bold uppercase tracking-[0.14em] text-[var(--muted)]">{item.category}</span></div>
          <h2 className="mt-5 font-display text-xl font-bold">{item.name}</h2><p className="mt-1 text-xs font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">{item.model}</p>
          <p className="mt-4 text-sm font-semibold leading-6">Best for: {item.bestFor}</p><p className="mt-3 text-sm leading-6 text-[var(--muted)]">{item.note}</p>
          <div className="mt-6 flex flex-wrap gap-x-5 gap-y-3 text-sm font-semibold"><a href={item.manufacturerUrl} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-2 text-[var(--accent)] hover:underline">Manufacturer details <ExternalLink className="h-3.5 w-3.5" /></a>{item.retailerQuery ? <a href={amazonSearchUrl(item.retailerQuery)} target="_blank" rel="sponsored noopener noreferrer" className="inline-flex items-center gap-2 text-[var(--accent)] hover:underline"><ShoppingBag className="h-4 w-4" /> Check availability <ExternalLink className="h-3.5 w-3.5" /></a> : <span className="inline-flex items-center gap-2 text-[var(--muted)]"><Wrench className="h-4 w-4" /> {item.purchasePath}</span>}</div>
        </article>;
      })}
    </div>
  </section>;
}
