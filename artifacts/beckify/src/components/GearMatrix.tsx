import { useRef, useState } from "react";
import { Activity, ArrowDown, Cable, ExternalLink, Gauge, RadioTower, ShieldCheck, ShoppingBag, Wrench } from "lucide-react";

type GearCategory = "Hand tools" | "Electrical troubleshooting" | "Insulation and safety" | "Current and process" | "Bench and electronics" | "Cable and RF";

type Gear = {
  category: GearCategory;
  name: string;
  model: string;
  bestFor: string;
  note: string;
  amazonUrl: string;
  manufacturerUrl: string;
  imageUrl?: string;
  budget?: boolean;
};

export const GEAR_RECOMMENDATIONS: Gear[] = [
  { category: "Hand tools", name: "Daniels Manufacturing AF8", model: "M22520/1-01 crimp frame", bestFor: "Qualified machined-contact crimping with the approved turret or positioner.", note: "The frame is not universal: the contact family, setting, locator, and procedure control the termination.", amazonUrl: "https://www.amazon.com/dp/B09CV54JPN?tag=beckify-20", manufacturerUrl: "https://dmctools.com/af8-af8" },
  { category: "Hand tools", name: "KNIPEX EvoStrip", model: "Automatic wire stripper", bestFor: "Repeatable preparation of solid, stranded, and fine-stranded conductors in its specified range.", note: "Confirm conductor size, insulation type, and strip length against the work package.", amazonUrl: "https://www.amazon.com/dp/B000R895YM?tag=beckify-20", manufacturerUrl: "https://www.knipex.com/evostrip" },
  { category: "Hand tools", name: "Klein Tools 11055", model: "Wire stripper and cutter", bestFor: "Stripping and cutting common copper conductors during panel, equipment, and field service work.", note: "This is a general wiring tool, not a replacement for qualified contact-crimp tooling.", amazonUrl: "https://www.amazon.com/dp/B00080DPNQ?tag=beckify-20", manufacturerUrl: "https://www.kleintools.com/catalog/wire-strippers-cutters-and-crimpers/wire-stripper-and-cutter-self-opening", budget: true },
  { category: "Hand tools", name: "Klein Tools 63050", model: "High-leverage cable cutter", bestFor: "Clean cuts on copper, aluminum, and communications cable before termination.", note: "Verify the conductor construction and tool capacity; do not use it on energized cable.", amazonUrl: "https://www.amazon.com/dp/B0000302X1?tag=beckify-20", manufacturerUrl: "https://www.kleintools.com/catalog/cable-cutters/high-leverage-cable-cutter" },
  { category: "Hand tools", name: "Wiha TorqueVario-S 28506", model: "Adjustable 10-50 in-lb torque driver", bestFor: "Controlled low-torque fastening on enclosures, terminals, and electronics hardware.", note: "Set torque from the approved assembly data and use a compatible bit or blade system.", amazonUrl: "https://www.amazon.com/dp/B002QV0FCY?tag=beckify-20", manufacturerUrl: "https://www.wihatools.com/products/adjustable-torquevario-10-50-in-lbs", imageUrl: "https://www.wihatools.com/cdn/shop/files/xj95dmdb06vc5pvonoun_165x.jpg?v=1776759870" },
  { category: "Electrical troubleshooting", name: "Fluke 87V", model: "True-RMS industrial multimeter", bestFor: "Primary voltage, resistance, continuity, and frequency troubleshooting in harsh field work.", note: "Prove the meter on a known source before and after a critical absence-of-voltage test.", amazonUrl: "https://www.amazon.com/dp/B0002YFD1K?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/digital-multimeters/fluke-87v", imageUrl: "https://media.fluke.com/2725d18d-633b-40b2-b09b-b108002e4d59_product_slideshow_main.jpg" },
  { category: "Electrical troubleshooting", name: "Fluke 117", model: "Electrician's True-RMS multimeter", bestFor: "Routine building electrical measurements where LoZ helps reduce ghost-voltage confusion.", note: "Use the meter and leads only within their marked measurement category and voltage rating.", amazonUrl: "https://www.amazon.com/dp/B000O3LUEI?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/digital-multimeters/fluke-117", imageUrl: "https://media.fluke.com/e55511c8-92e6-46b2-b9ae-b108002dd7fa_product_slideshow_main.jpg" },
  { category: "Electrical troubleshooting", name: "Klein Tools MM400", model: "Auto-ranging 600 V digital multimeter", bestFor: "Cost-conscious general electrical measurement on systems within its marked CAT III 600 V rating.", note: "Confirm the supplied leads, fuses, measurement category, and the job procedure before using any meter on energized equipment.", amazonUrl: "https://www.amazon.com/dp/B018EXZO8M?tag=beckify-20", manufacturerUrl: "https://www.kleintools.com/catalog/multimeters/digital-multimeter-auto-ranging-600v", budget: true },
  { category: "Electrical troubleshooting", name: "Fluke T6-1000", model: "FieldSense electrical tester", bestFor: "Fast AC voltage and current checks at distribution equipment and larger conductors.", note: "Treat FieldSense as one method in the approved test process, not a substitute for procedure.", amazonUrl: "https://www.amazon.com/dp/B076DYBHCW?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/basic-testers/fluke-t6-1000" },
  { category: "Electrical troubleshooting", name: "Fluke 2AC Alert", model: "90-1000 V AC non-contact voltage tester", bestFor: "A quick preliminary indication of AC voltage presence in cords, outlets, and panels.", note: "A non-contact tester cannot establish an absence of voltage on its own.", amazonUrl: "https://www.amazon.com/dp/B004I9J4DI?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/voltage-detectors/fluke-2ac" },
  { category: "Electrical troubleshooting", name: "Klein Tools NCVT2P", model: "Dual-range non-contact voltage tester", bestFor: "Checking low and standard-voltage AC presence before a more complete test.", note: "Verify operation on a known live source and follow the manufacturer warnings before use.", amazonUrl: "https://www.amazon.com/dp/B07L5N8ZWS?tag=beckify-20", manufacturerUrl: "https://www.kleintools.com/catalog/electrical-testers/non-contact-voltage-tester-pen-dual-range-12-1000v-ac-or-48-1000v-ac" },
  { category: "Electrical troubleshooting", name: "Klein Tools ET310", model: "Circuit-breaker finder with GFCI tester", bestFor: "Locating a 90-120 V branch-circuit breaker and checking a grounded receptacle.", note: "It is limited to the specified low-voltage branch circuits, not switchgear fault investigation.", amazonUrl: "https://www.amazon.com/dp/B07QNMCVWP?tag=beckify-20", manufacturerUrl: "https://www.kleintools.com/catalog/electrical-testers/digital-circuit-breaker-finder-gfci-outlet-tester", budget: true },
  { category: "Electrical troubleshooting", name: "Fluke 62 MAX+", model: "Dual-laser IR thermometer", bestFor: "Non-contact screening for abnormal temperatures on energized electrical and mechanical assets.", note: "Correct emissivity, distance-to-spot ratio, load condition, and follow-up measurement determine whether a finding is meaningful.", amazonUrl: "https://www.amazon.com/dp/B0089N2ZH6?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/temperature-measurement/ir-thermometers/fluke-62-max-plus" },
  { category: "Electrical troubleshooting", name: "FLIR C5", model: "160 x 120 compact thermal camera", bestFor: "Documenting thermal anomalies on panels, terminations, motors, and equipment under load.", note: "Thermal images indicate a condition to investigate; they do not establish the root cause by themselves.", amazonUrl: "https://www.amazon.com/dp/B0892MZZT1?tag=beckify-20", manufacturerUrl: "https://www.flir.com/products/c5/" },
  { category: "Insulation and safety", name: "Fluke 1507", model: "50 V to 1000 V insulation resistance tester", bestFor: "Specified insulation-resistance workflows on wiring and electrical equipment.", note: "Test voltage, isolation, discharge time, and acceptance criteria must come from the applicable procedure.", amazonUrl: "https://www.amazon.com/dp/B000X4O9WI?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/insulation-testers/fluke-1507", imageUrl: "https://media.fluke.com/2882fbd6-a477-4823-8210-b108002ddc22_product_slideshow_main.jpg" },
  { category: "Insulation and safety", name: "Klein Tools ET600", model: "1000 V insulation resistance tester", bestFor: "Insulation, continuity, and voltage measurements in electrical maintenance workflows.", note: "Never perform insulation-resistance testing on an energized circuit.", amazonUrl: "https://www.amazon.com/dp/B07ZZX5TK8?tag=beckify-20", manufacturerUrl: "https://www.kleintools.com/catalog/multimeters/insulation-resistance-tester" },
  { category: "Current and process", name: "Fluke 376 FC", model: "True-RMS AC/DC clamp meter with iFlex", bestFor: "Current checks around conductors where a fixed clamp jaw cannot reach.", note: "Confirm the measurement method, conductor placement, and rating before interpreting the result.", amazonUrl: "https://www.amazon.com/dp/B017OVC2QM?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/clamp-meters/fluke-376-fc", imageUrl: "https://media.fluke.com/2349e539-9d7a-457b-b8ea-b108002e1bc3_product_slideshow_main.jpg" },
  { category: "Current and process", name: "Klein Tools CL120", model: "400 A AC auto-ranging clamp meter", bestFor: "Cost-conscious AC-current, voltage, resistance, and continuity checks on systems within its marked rating.", note: "This clamp measures AC current only. Verify the function, lead condition, and measurement category before connecting to a circuit.", amazonUrl: "https://www.amazon.com/dp/B08CP6GL49?tag=beckify-20", manufacturerUrl: "https://www.kleintools.com/catalog/clamp-meters/digital-clamp-meter-ac-auto-ranging-400-amp", budget: true },
  { category: "Current and process", name: "Fluke 323", model: "True-RMS 400 A AC clamp meter", bestFor: "Basic AC-current, voltage, and resistance checks in commercial and industrial electrical work.", note: "This model measures AC current, not DC current; choose the instrument to match the circuit.", amazonUrl: "https://www.amazon.com/dp/B00AQKIEXY?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/clamp-meters/fluke-323" },
  { category: "Current and process", name: "Fluke 771", model: "Milliamp process clamp meter", bestFor: "Measuring 4-20 mA process signals without opening the control loop.", note: "Confirm the loop configuration and access requirements before clamping any conductor.", amazonUrl: "https://www.amazon.com/dp/B000R81ARM?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/process-calibration-tools/loop-calibrators/fluke-771" },
  { category: "Bench and electronics", name: "RIGOL DHO804", model: "Four-channel 70 MHz digital oscilloscope", bestFor: "Bench diagnostics for power rails, clocks, data, and control signals.", note: "Four channels help compare several signals at once; probe selection and grounding still matter.", amazonUrl: "https://www.amazon.com/dp/B0CGHQHQN7?tag=beckify-20", manufacturerUrl: "https://mall.rigol.com/shiboqi/dho804.html" },
  { category: "Bench and electronics", name: "RIGOL DS1054Z", model: "Four-channel 50 MHz digital oscilloscope", bestFor: "General embedded, control, and low-to-mid-speed electronics waveform troubleshooting.", note: "Do not defeat probe safety ratings or connect a grounded scope probe where it would create a fault path.", amazonUrl: "https://www.amazon.com/dp/B012938E76?tag=beckify-20", manufacturerUrl: "https://www.rigolna.com/products/digital-oscilloscopes/ds1000z/", budget: true },
  { category: "Bench and electronics", name: "SIGLENT SDS1104X-E", model: "Four-channel 100 MHz digital oscilloscope", bestFor: "Electronics troubleshooting that benefits from more bandwidth, capture depth, and signal comparison.", note: "Scope bandwidth is not the only criterion: verify probe compensation, attenuation, and ground reference first.", amazonUrl: "https://www.amazon.com/dp/B0771N1ZF9?tag=beckify-20", manufacturerUrl: "https://siglentna.com/product/sds1104x-e-100-mhz/" },
  { category: "Bench and electronics", name: "Fluke 289", model: "True-RMS logging multimeter with TrendCapture", bestFor: "Finding intermittent electrical behavior through logged measurements instead of one-time readings.", note: "Use its logging capability to support a documented diagnostic plan, not to replace a calibrated bench instrument where one is required.", amazonUrl: "https://www.amazon.com/dp/B0012B51HI?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/digital-multimeters/fluke-289", imageUrl: "https://media.fluke.com/754f67ca-87e2-4668-bbff-b108002c0c74_product_slideshow_main.jpg" },
  { category: "Cable and RF", name: "Klein Tools Scout Pro 3", model: "VDV501-851 cable tester kit", bestFor: "Identifying and mapping Ethernet, telephone, and coaxial cable runs.", note: "It verifies compatible cable systems; it is not a certification instrument or an aircraft-harness tester.", amazonUrl: "https://www.amazon.com/dp/B085LPN71C?tag=beckify-20", manufacturerUrl: "https://www.kleintools.com/catalog/cable-testers/scout-pro-3-tester-kit" },
  { category: "Cable and RF", name: "Fluke Networks MicroScanner PoE", model: "MS-POE copper cable verifier", bestFor: "PoE, wiremap, length, switch capability, and distance-to-fault checks on Ethernet infrastructure.", note: "Use it for supported copper Ethernet systems, not as a substitute for a specialized RF or harness analyzer.", amazonUrl: "https://www.amazon.com/dp/B07NJMKG9L?tag=beckify-20", manufacturerUrl: "https://www.fluke.com/en-us/product/network-cable-testers/copper/ms-poe" },
  { category: "Cable and RF", name: "AURSINC NanoVNA-H4", model: "9 kHz to 1.5 GHz portable vector network analyzer", bestFor: "Practical antenna, coax, impedance, and return-loss investigation in RF and electronics work.", note: "A capable field tool, but not a calibrated replacement for a professional VNA where traceability is required.", amazonUrl: "https://www.amazon.com/dp/B07T6LXNTV?tag=beckify-20", manufacturerUrl: "https://nanovna.com/", budget: true },
];

const gear = GEAR_RECOMMENDATIONS;

export const GEAR_FAQS = [
  {
    question: "What electrical test equipment should I buy first?",
    answer: "Start with a properly rated multimeter and sound test leads for the voltage, category, and procedure involved. Add a clamp meter, insulation tester, thermal imager, oscilloscope, cable tester, or RF analyzer only when the task requires that measurement.",
  },
  {
    question: "Can a non-contact voltage tester prove a circuit is de-energized?",
    answer: "No. A non-contact tester can provide a preliminary indication of voltage presence, but it does not establish absence of voltage. Follow the approved absence-of-voltage and meter-verification process for the equipment and work.",
  },
  {
    question: "How should I evaluate the budget picks?",
    answer: "Budget pick means a lower-cost, purpose-specific option in this guide, not a lower standard for safety. Check the exact model, rating, leads, accessories, calibration requirements, and your work procedure before purchase or use.",
  },
] as const;

const categories = ["All", "Hand tools", "Electrical troubleshooting", "Insulation and safety", "Current and process", "Bench and electronics", "Cable and RF"] as const;

const categoryGuides = [
  { category: "Hand tools" as const, label: "Hand tools", icon: Wrench },
  { category: "Electrical troubleshooting" as const, label: "Electrical testing", icon: Gauge },
  { category: "Insulation and safety" as const, label: "Insulation and safety", icon: ShieldCheck },
  { category: "Current and process" as const, label: "Current and process", icon: Cable },
  { category: "Bench and electronics" as const, label: "Bench and electronics", icon: Activity },
  { category: "Cable and RF" as const, label: "Cable and RF", icon: RadioTower },
];

function getGearIcon(category: GearCategory) {
  if (category === "Hand tools") return Wrench;
  if (category === "Electrical troubleshooting") return Gauge;
  if (category === "Insulation and safety") return ShieldCheck;
  if (category === "Current and process") return Cable;
  if (category === "Cable and RF") return RadioTower;
  return Activity;
}

function ProductVisual({ item }: { item: Gear }) {
  const Icon = getGearIcon(item.category);

  if (item.imageUrl) {
    return <figure className="mt-5 overflow-hidden rounded-xl border border-[var(--border)] bg-white/95">
      <div className="h-40 p-3"><img src={item.imageUrl} alt={item.name} loading="lazy" className="h-full w-full object-contain" /></div>
      <figcaption className="border-t border-[var(--border)] px-3 py-1.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-slate-500">Official product photo</figcaption>
    </figure>;
  }

  return <figure className="relative mt-5 overflow-hidden rounded-xl border border-cyan-300/15 bg-[#07101c]" role="img" aria-label={`${item.name} instrument profile`}>
    <div className="absolute inset-0 opacity-40" style={{ backgroundImage: "linear-gradient(rgba(88, 142, 185, 0.18) 1px, transparent 1px), linear-gradient(90deg, rgba(88, 142, 185, 0.18) 1px, transparent 1px)", backgroundSize: "20px 20px" }} />
    <svg viewBox="0 0 480 160" className="absolute inset-0 h-full w-full" aria-hidden="true">
      <path d="M0 114H92l24-26h72l24 26h90l24-26h174" fill="none" stroke="#5ed7ff" strokeOpacity="0.45" strokeWidth="2" />
      <path d="M8 48h78l17 18h64l18-36h86l18 36h68l20-18h113" fill="none" stroke="#9d7cff" strokeOpacity="0.4" strokeWidth="2" />
      <circle cx="116" cy="88" r="5" fill="#8cf0c2" /><circle cx="306" cy="88" r="5" fill="#f8b94f" />
    </svg>
    <div className="relative flex h-40 items-center gap-4 p-5">
      <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl border border-cyan-200/30 bg-[#0a1b2c] shadow-[0_0_28px_rgba(94,215,255,0.16)]"><Icon className="h-8 w-8 text-cyan-200" aria-hidden="true" /></div>
      <div className="min-w-0"><p className="text-[10px] font-bold uppercase tracking-[0.16em] text-cyan-200/70">Product reference</p><p className="mt-1 font-mono text-sm font-semibold leading-5 text-slate-100">{item.model}</p></div>
    </div>
    <figcaption className="relative border-t border-white/10 bg-[#07101c]/90 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-slate-400">Instrument profile</figcaption>
  </figure>;
}

function InstrumentGraphic() {
  return <div className="relative min-h-64 overflow-hidden bg-[#07101c]" role="img" aria-label="Technical diagram showing measurement inputs, a multimeter, oscilloscope, cable path, and verified output">
    <div className="absolute inset-0 opacity-30" style={{ backgroundImage: "linear-gradient(rgba(112, 144, 180, 0.16) 1px, transparent 1px), linear-gradient(90deg, rgba(112, 144, 180, 0.16) 1px, transparent 1px)", backgroundSize: "24px 24px" }} />
    <svg viewBox="0 0 640 400" className="absolute inset-0 h-full w-full" aria-hidden="true">
      <defs>
        <linearGradient id="signal" x1="0" y1="0" x2="1" y2="0"><stop stopColor="#65d7ff" /><stop offset="1" stopColor="#9d7cff" /></linearGradient>
        <filter id="softGlow" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="4" result="blur" /><feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge></filter>
      </defs>
      <g fill="none" stroke="#29425e" strokeWidth="1"><path d="M0 68H640M0 132H640M0 196H640M0 260H640M0 324H640" /><path d="M64 0V400M160 0V400M256 0V400M352 0V400M448 0V400M544 0V400" /></g>
      <path d="M30 244H86L105 224H139" stroke="#f8b94f" strokeWidth="3" /><circle cx="30" cy="244" r="6" fill="#f8b94f" /><text x="24" y="275" fill="#91a4b9" fontSize="12" letterSpacing="2">INPUT</text>
      <rect x="139" y="96" width="146" height="200" rx="12" fill="#102239" stroke="#5e7c9a" strokeWidth="2" />
      <rect x="164" y="120" width="96" height="48" rx="5" fill="#04111d" stroke="#365673" /><text x="180" y="151" fill="#8cf0c2" fontSize="23" fontFamily="monospace">238.7</text>
      <circle cx="212" cy="220" r="29" fill="#0a1624" stroke="#7893ad" strokeWidth="3" /><path d="M212 193v11M230 201l-8 8M239 220h-11M230 239l-8-8M212 247v-11M194 239l8-8M185 220h11M194 201l8 8" stroke="#f8b94f" strokeWidth="3" strokeLinecap="round" />
      <circle cx="174" cy="268" r="5" fill="#e8526b" /><circle cx="249" cy="268" r="5" fill="#101d2d" stroke="#7893ad" /><text x="160" y="318" fill="#9fb2c6" fontSize="12" letterSpacing="2">METER</text>
      <path d="M285 196H344" stroke="url(#signal)" strokeWidth="4" filter="url(#softGlow)" /><circle cx="344" cy="196" r="6" fill="#9d7cff" />
      <rect x="367" y="83" width="220" height="178" rx="12" fill="#102239" stroke="#5e7c9a" strokeWidth="2" />
      <rect x="385" y="103" width="184" height="104" rx="4" fill="#051420" stroke="#365673" />
      <g stroke="#23435d" strokeWidth="1"><path d="M385 129H569M385 155H569M385 181H569" /><path d="M415 103V207M446 103V207M477 103V207M508 103V207M539 103V207" /></g>
      <path d="M390 168c12 0 12-48 24-48s12 68 24 68 12-85 24-85 12 64 24 64 12-27 24-27 12 22 24 22 12-46 24-46 12 52 24 52" fill="none" stroke="url(#signal)" strokeWidth="3" filter="url(#softGlow)" />
      <g fill="#6f8ca5"><circle cx="409" cy="233" r="5" /><circle cx="432" cy="233" r="5" /><circle cx="455" cy="233" r="5" /><circle cx="478" cy="233" r="5" /></g><text x="394" y="286" fill="#9fb2c6" fontSize="12" letterSpacing="2">SIGNAL VIEW</text>
      <path d="M587 172H623" stroke="#8cf0c2" strokeWidth="3" /><circle cx="624" cy="172" r="7" fill="#8cf0c2" filter="url(#softGlow)" /><text x="535" y="326" fill="#8cf0c2" fontSize="12" letterSpacing="2">VERIFY</text>
    </svg>
    <div className="absolute inset-x-0 bottom-0 flex items-center justify-between border-t border-white/10 bg-[#07101c]/90 px-6 py-4 text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-300"><span>Electrical test workflow</span><span className="text-cyan-200">Input &rarr; measure &rarr; verify</span></div>
  </div>;
}

export function GearMatrix() {
  const [category, setCategory] = useState<(typeof categories)[number]>("All");
  const catalogRef = useRef<HTMLDivElement>(null);
  const visible = gear.filter((item) => category === "All" || item.category === category);
  const budgetGear = gear.filter((item) => item.budget);
  const selectCategory = (nextCategory: GearCategory) => {
    setCategory(nextCategory);
    requestAnimationFrame(() => catalogRef.current?.scrollIntoView({ behavior: "smooth", block: "start" }));
  };

  return <section className="space-y-6" aria-labelledby="gear-title">
    <div className="grid overflow-hidden rounded-2xl border border-[var(--border)] bg-[var(--surface)] lg:grid-cols-[1.1fr_.9fr]">
      <div className="p-7 md:p-10">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Beckify gear guide</p>
        <h1 id="gear-title" className="mt-3 font-display text-4xl font-bold md:text-5xl">Recommended tools for high-consequence electrical work.</h1>
        <p className="mt-5 max-w-2xl text-[var(--muted)]">A practical library for maintenance electricians, commissioning teams, field technicians, and engineers who need dependable hand tools and measurement equipment. Every recommendation uses a direct link to the exact Amazon model, plus a manufacturer source for checking specifications.</p>
        <div className="mt-8 flex flex-wrap gap-3 text-xs font-semibold"><span className="rounded-full bg-[var(--accent-soft)] px-3 py-1.5 text-[var(--accent)]">{gear.length} curated tools</span><span className="rounded-full border border-[var(--border)] px-3 py-1.5 text-[var(--muted)]">Field + bench</span><span className="rounded-full border border-[var(--border)] px-3 py-1.5 text-[var(--muted)]">Direct model links</span><span className="rounded-full border border-amber-300/30 bg-amber-300/5 px-3 py-1.5 text-amber-200">{budgetGear.length} budget picks</span></div>
      </div>
      <InstrumentGraphic />
    </div>

    <section className="card-surface overflow-hidden" aria-labelledby="budget-picks-title">
      <div className="flex flex-wrap items-end justify-between gap-3 border-b border-[var(--border)] px-5 py-5 md:px-6"><div><p className="text-xs font-semibold uppercase tracking-[0.18em] text-amber-200">Cost-conscious choices</p><h2 id="budget-picks-title" className="mt-1 font-display text-2xl font-bold">Budget picks that still fit a defined job.</h2></div><p className="max-w-xl text-sm leading-6 text-[var(--muted)]">Lower-cost does not mean lower safety. Confirm the exact model, rating, accessories, and procedure before purchase or use.</p></div>
      <div className="grid divide-y divide-[var(--border)] md:grid-cols-2 md:divide-x md:divide-y-0 xl:grid-cols-3">{budgetGear.map((item) => { const Icon = getGearIcon(item.category); return <a key={item.name} href={item.amazonUrl} target="_blank" rel="sponsored noopener noreferrer" className="group flex gap-3 p-5 transition hover:bg-white/[0.035]"><span className="mt-0.5 rounded-lg bg-amber-300/10 p-2"><Icon className="h-4 w-4 text-amber-200" aria-hidden="true" /></span><span className="min-w-0"><span className="block text-[10px] font-bold uppercase tracking-[0.14em] text-[var(--muted)]">{item.category}</span><span className="mt-1 block font-display font-bold text-[var(--foreground)]">{item.name}</span><span className="mt-2 inline-flex items-center gap-1.5 text-xs font-semibold text-amber-200 group-hover:underline">View exact model on Amazon <ExternalLink className="h-3.5 w-3.5" /></span></span></a>; })}</div>
    </section>

    <div className="card-surface grid gap-5 p-5 md:grid-cols-[auto_1fr_1fr_1fr] md:items-center" aria-label="How to use this guide"><span className="rounded-full bg-[var(--accent-soft)] px-3 py-1 text-xs font-bold text-[var(--accent)]">Start here</span><p className="m-0 text-sm leading-6 text-[var(--muted)]"><strong className="text-[var(--foreground)]">1. Define the task.</strong> Start with the connection, measurement, or signal path you need to verify.</p><p className="m-0 text-sm leading-6 text-[var(--muted)]"><strong className="text-[var(--foreground)]">2. Follow the procedure.</strong> The work instruction and safety process determine the acceptable method.</p><p className="m-0 text-sm leading-6 text-[var(--muted)]"><strong className="text-[var(--foreground)]">3. Match the instrument.</strong> Select the required function, category rating, and accuracy before buying or testing.</p></div>

    <section aria-labelledby="category-map-title"><div className="mb-4 flex items-end justify-between gap-4"><div><p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Browse equipment</p><h2 id="category-map-title" className="mt-1 font-display text-2xl font-bold">Choose a category</h2><p className="mt-2 text-sm text-[var(--muted)]">Select a category to filter the product list below.</p></div><Cable className="hidden h-7 w-7 text-[var(--accent)] md:block" aria-hidden="true" /></div><div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">{categoryGuides.map((guide) => { const Icon = guide.icon; const count = gear.filter((item) => item.category === guide.category).length; const isActive = category === guide.category; return <button type="button" key={guide.category} aria-pressed={isActive} onClick={() => selectCategory(guide.category)} className={`flex items-center gap-3 rounded-xl border p-4 text-left transition ${isActive ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--accent)]" : "border-[var(--border)] bg-[var(--surface)] hover:border-[var(--accent)]/60"}`}><span className="rounded-lg bg-[var(--accent-soft)] p-2"><Icon className="h-5 w-5 text-[var(--accent)]" aria-hidden="true" /></span><span className="min-w-0 flex-1"><span className="block font-display text-base font-bold text-[var(--foreground)]">{guide.label}</span><span className="mt-0.5 block text-xs text-[var(--muted)]">{count} recommendations</span></span><ArrowDown className="h-4 w-4 shrink-0 text-[var(--accent)]" aria-hidden="true" /></button>; })}</div></section>

    <div className="flex gap-3 rounded-xl border border-amber-400/30 bg-amber-400/5 p-4 text-sm leading-6 text-[var(--muted)]"><ShieldCheck className="mt-0.5 h-5 w-5 shrink-0 text-amber-400" aria-hidden="true" /><p className="m-0"><strong className="text-[var(--foreground)]">Safety note:</strong> These are diagnostic and maintenance-support tools. They do not replace lockout/tagout, an approved work procedure, required calibration, meter verification, or the tool manufacturer’s instructions.</p></div>

    <p className="text-xs text-[var(--muted)]">Disclosure: As an Amazon Associate I earn from qualifying purchases. Amazon buttons are paid links.</p>

    <div ref={catalogRef} className="scroll-mt-6"><div className="mb-4 flex flex-wrap items-end justify-between gap-3"><div><p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Product list</p><h2 className="mt-1 font-display text-2xl font-bold">{category === "All" ? "All recommended gear" : category}</h2></div>{category !== "All" && <button type="button" onClick={() => setCategory("All")} className="rounded-full border border-[var(--border)] px-3 py-1.5 text-xs font-semibold text-[var(--muted)] transition hover:border-[var(--accent)] hover:text-[var(--accent)]">Show all {gear.length} tools</button>}</div><div className="grid gap-4 md:grid-cols-2">
      {visible.map((item) => {
        const Icon = getGearIcon(item.category);
        return <article className="card-surface flex flex-col p-6" key={item.name}>
          <div className="flex items-start justify-between gap-4"><div className="rounded-xl bg-[var(--accent-soft)] p-3"><Icon className="h-5 w-5 text-[var(--accent)]" aria-hidden="true" /></div><div className="flex flex-col items-end gap-1.5"><span className="text-right text-[10px] font-bold uppercase tracking-[0.14em] text-[var(--muted)]">{item.category}</span>{item.budget && <span className="rounded-full bg-amber-300/10 px-2 py-1 text-[10px] font-bold uppercase tracking-[0.12em] text-amber-200">Budget pick</span>}</div></div>
          <ProductVisual item={item} />
          <h2 className="mt-5 font-display text-xl font-bold">{item.name}</h2><p className="mt-1 text-xs font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">{item.model}</p>
          <p className="mt-4 text-sm font-semibold leading-6">Best for: {item.bestFor}</p><p className="mt-3 text-sm leading-6 text-[var(--muted)]">{item.note}</p>
          <div className="mt-6 flex flex-wrap items-center gap-3 text-sm font-semibold"><a href={item.amazonUrl} target="_blank" rel="sponsored noopener noreferrer" aria-label={`View the exact ${item.name} model on Amazon (paid link)`} className="inline-flex items-center gap-2 rounded-lg bg-[var(--accent)] px-4 py-2.5 text-[var(--accent-foreground)] shadow-[0_8px_22px_rgba(139,123,255,0.2)] transition hover:bg-[var(--accent-2)]"><ShoppingBag className="h-4 w-4" /> View exact model on Amazon <ExternalLink className="h-3.5 w-3.5" /></a><a href={item.manufacturerUrl} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-2 px-1 py-2 text-[var(--muted)] transition hover:text-[var(--accent)] hover:underline">Check manufacturer specs <ExternalLink className="h-3.5 w-3.5" /></a></div>
        </article>;
      })}
    </div></div>

    <section className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-6 md:p-8" aria-labelledby="gear-faq-title"><p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Buying guidance</p><h2 id="gear-faq-title" className="mt-2 font-display text-2xl font-bold">Before you buy or test</h2><div className="mt-5 divide-y divide-[var(--border)]">{GEAR_FAQS.map((item) => <details key={item.question} className="group py-4"><summary className="cursor-pointer list-none pr-8 font-display font-bold text-[var(--foreground)] marker:hidden">{item.question}<span className="float-right text-xl leading-none text-[var(--accent)] transition group-open:rotate-45">+</span></summary><p className="mt-3 max-w-3xl text-sm leading-6 text-[var(--muted)]">{item.answer}</p></details>)}</div></section>
  </section>;
}
