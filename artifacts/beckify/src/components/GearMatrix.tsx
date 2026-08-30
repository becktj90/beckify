import { useState } from "react";
import {
  Activity,
  BadgeCheck,
  Cable,
  CheckCircle2,
  ExternalLink,
  Gauge,
  ImageOff,
  Search,
  ShieldCheck,
  ShoppingBag,
  Wrench,
} from "lucide-react";

type GearCategory =
  | "Aerospace Hand Tools"
  | "Wire Termination"
  | "Test Equipment"
  | "Bench Prototyping"
  | "Field Diagnostics";

type Gear = {
  category: GearCategory;
  name: string;
  model: string;
  justification: string;
  use: string;
  retailerQuery: string;
  manufacturerUrl: string;
  photoUrl?: string;
  stage?: string;
  checkpoint?: string;
};

// The public fallback keeps the tagged links working in GitHub Pages builds;
// the deployment variable can override it for a different Associates tracking ID.
const configuredAssociateTag = String(import.meta.env.VITE_AMAZON_ASSOCIATE_TAG ?? "").trim();
const AMAZON_ASSOCIATE_TAG = configuredAssociateTag || "beckify-20";
const hasAffiliateTag = AMAZON_ASSOCIATE_TAG.length > 0;

const amazonSearchUrl = (query: string) => {
  const url = new URL("https://www.amazon.com/s");
  url.searchParams.set("k", query);
  if (hasAffiliateTag) url.searchParams.set("tag", AMAZON_ASSOCIATE_TAG);
  return url.toString();
};

const gear: Gear[] = [
  {
    category: "Aerospace Hand Tools",
    name: "Daniels Manufacturing AF8",
    model: "M22520/1-01 / AS22520/1",
    justification: "The adjustable eight-indent frame is a common aerospace connector-tooling reference for machined contacts, but it must be paired with the correct turret or positioner for the contact family.",
    use: "Qualified 12 to 26 AWG machined-contact crimps",
    retailerQuery: "Daniels Manufacturing AF8 M22520/1-01 crimp tool",
    manufacturerUrl: "https://dmctools.com/af8-af8",
  },
  {
    category: "Aerospace Hand Tools",
    name: "Daniels Manufacturing HX4",
    model: "M22520/5-01 / AS22520/5",
    justification: "An open-frame, positive-ratchet tool with interchangeable Y dies gives a maintenance team a flexible path across machined contacts, coax, shielding ferrules, terminals, and splices.",
    use: "Mil-spec coax, shield terminations, contacts, and interchangeable-die work",
    retailerQuery: "Daniels Manufacturing HX4 M22520/5-01 crimp tool",
    manufacturerUrl: "https://dmctools.com/hx4",
  },
  {
    category: "Aerospace Hand Tools",
    name: "TE Connectivity CERTI-CRIMP II",
    model: "Part 2217755-1",
    justification: "A fixed-die, ratcheting hand tool with a manufacturer certificate is a sensible choice when the contact and tooling combination is explicitly called out by the work instruction.",
    use: "Repeatable fixed-die connector and contact crimping",
    retailerQuery: "TE Connectivity CERTI-CRIMP II 2217755-1",
    manufacturerUrl: "https://www.te.com/en/product-2217755-1.html",
    photoUrl: "https://www.te.com/content/dam/te-com/catalog/part/000/915/051/91505-1-t1.jpg/jcr%3Acontent/renditions/product-high-res.png",
  },
  {
    category: "Aerospace Hand Tools",
    name: "Wera 1460 ESD Kraftform Micro",
    model: "Preset 0.02 to 0.11 Nm",
    justification: "ESD-safe micro torque control helps protect small connector hardware and avionics assemblies from both over-torque and static discharge.",
    use: "Fine connector, electronics, and avionics fastener work",
    retailerQuery: "Wera 1460 ESD Kraftform Micro torque screwdriver",
    manufacturerUrl: "https://www.wera.de/en/tools/1460-esd-kraftform-micro-torque-screwdrivers-with-factory-pre-set-value-002-011-nm-and-quick-release-chuck",
  },
  {
    category: "Aerospace Hand Tools",
    name: "KNIPEX EvoStrip",
    model: "Automatic wire stripper",
    justification: "A one-hand automatic stripper speeds harness preparation while keeping the recommendation tied to the conductor type and insulation range specified by the work package.",
    use: "Solid, stranded, and finely stranded harness preparation",
    retailerQuery: "KNIPEX EvoStrip automatic wire stripper",
    manufacturerUrl: "https://www.knipex.com/evostrip",
  },
  {
    category: "Wire Termination",
    name: "Phoenix Contact CRIMPFOX 4 IN 1",
    model: "Part 1200101",
    justification: "A pressure-locked ferrule tool that combines cutting, stripping, twisting, and crimping for DIN 46228-4 ferrules.",
    use: "Fast control-panel wiring with 0.5 to 2.5 mm² ferrules",
    retailerQuery: "Phoenix Contact CRIMPFOX 4 IN 1 1200101",
    manufacturerUrl: "https://www.phoenixcontact.com/en-us/products/hand-tools/crimping-tools",
    photoUrl: "https://caas.phoenixcontact.com/caas/v1/stable/media/77022/1x1/408?format=jpg",
  },
  {
    category: "Wire Termination",
    name: "Molex PremiumGrade Hand Crimp Tool",
    model: "Part 63819-2300",
    justification: "A manufacturer-matched hand tool is the safer recommendation for connector work because crimp qualification depends on the terminal and tooling combination.",
    use: "Molex iGrid female terminals on 26 to 22 AWG wire",
    retailerQuery: "Molex 63819-2300 PremiumGrade hand crimp tool",
    manufacturerUrl: "https://www.molex.com/en-us/products/part-detail/0638192300",
  },
  {
    category: "Bench Prototyping",
    name: "Keysight E36313A Triple-Output Supply",
    model: "160 W bench supply",
    justification: "Independent current limits on three outputs make first power-up controlled and repeatable instead of turning a wiring mistake into a smoke test.",
    use: "Embedded bring-up, fault isolation, and multi-rail load checks",
    retailerQuery: "Keysight E36313A 160W triple output power supply",
    manufacturerUrl: "https://www.keysight.com/gb/en/support/E36313A/160w-triple-output-power-supply-6v-10a-25v-2a-25v-2a.html",
  },
  {
    category: "Test Equipment",
    name: "Fluke 87V Industrial Multimeter",
    model: "True-RMS DMM",
    justification: "True-RMS measurement, a low-pass filter, and Peak Capture make it a strong fit for industrial troubleshooting and intermittent fault capture.",
    use: "Industrial troubleshooting, VFD work, and intermittent faults",
    retailerQuery: "Fluke 87V Industrial Multimeter",
    manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/digital-multimeters/fluke-87v",
    photoUrl: "https://media.fluke.com/2725d18d-633b-40b2-b09b-b108002e4d59_product_slideshow_main.jpg",
  },
  {
    category: "Test Equipment",
    name: "Fluke 1587 FC Insulation Multimeter",
    model: "FLK-1587-FC / 50 to 1000 V tests",
    justification: "The combined insulation tester and True-RMS DMM helps separate leakage and insulation degradation from a simple open or continuity failure.",
    use: "Harness insulation, leakage, PI/DAR, and preventive maintenance",
    retailerQuery: "Fluke 1587 FC Insulation Multimeter",
    manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/insulation-testers/fluke-1587-fc",
    photoUrl: "https://media.fluke.com/f3f6cb73-bfe4-4c3b-b1d0-b2cd01711d60_product_slideshow_main.jpg",
  },
  {
    category: "Test Equipment",
    name: "Megger MIT420/2 Insulation Tester",
    model: "50 to 1000 V test range",
    justification: "A dedicated insulation tester applies a defined DC test voltage and measures leakage that a continuity beep cannot reveal.",
    use: "Cable insulation, motor winding, PI/DAR, and live-circuit checks",
    retailerQuery: "Megger MIT420/2 insulation resistance tester",
    manufacturerUrl: "https://www.megger.com/en-us/products/mit400/2-series",
    photoUrl: "https://www.megger.com/sites/g/files/utfabz201/files/styles/megger_square/public/acquiadam_assets/2022-11/product-migration-mit4002-series-image-1-531.png.webp?itok=kwr1e1L4",
  },
  {
    category: "Test Equipment",
    name: "Tektronix 2 Series MSO",
    model: "MSO22 / MSO24 portable oscilloscope",
    justification: "A portable mixed-signal scope brings waveform, digital timing, protocol, and power-rail debugging into the lab or field without a full-size bench footprint.",
    use: "Avionics electronics, embedded buses, power rails, and signal integrity",
    retailerQuery: "Tektronix 2 Series MSO MSO24 oscilloscope",
    manufacturerUrl: "https://www.tek.com/en/products/oscilloscopes/2-series-mso-portable-oscilloscope",
    photoUrl: "https://www.tek.com/-/media/images/product-series/2-series-mso/mso24_embedded_v2_202-540x300.png?h=300&iar=0&w=540",
  },
  {
    category: "Field Diagnostics",
    name: "Megger TDR500/3 Handheld Time Domain Reflectometer",
    model: "Item 1002-227 · VF 0.20–0.99 · up to 5 km / 15,000 ft",
    justification: "A compact single-channel TDR for locating faults on metallic cable pairs, with selectable 25/50/75/100 ohm output, trace hold, and automatic gain and pulse-width selection. Verify cable type, seller condition, and included leads before purchase.",
    use: "Distance-to-fault work, open/short reflection training, metallic pair testing, and TDR trace comparison",
    retailerQuery: "Megger TDR500 TDR500/3 handheld time domain reflectometer cable fault locator",
    manufacturerUrl: "https://www.megger.com/en-us/products/tdr500/3",
    stage: "Days 61–90",
    checkpoint: "Practice identifying open, short, and impedance-change reflections on known cable lengths before relying on a field trace.",
  },
  {
    category: "Field Diagnostics",
    name: "Megger TDR2050 Cable Fault Locator",
    model: "Two-channel handheld TDR",
    justification: "AutoFind, FindEnd, distance-dependent gain, and CAT IV 600 V input protection make it a practical field instrument for locating cable faults and ends.",
    use: "Power-cable fault location, near-end faults, and trace comparison",
    retailerQuery: "Megger TDR2050 cable fault locator",
    manufacturerUrl: "https://www.megger.com/en/products/tdr2050",
    photoUrl: "https://www.megger.com/sites/g/files/utfabz201/files/styles/megger_square/public/acquiadam_assets/2022-11/product-migration-tdr2050-image-1-464.png.webp?itok=x4TPjSH-",
  },
  {
    category: "Field Diagnostics",
    name: "Fluke DS703 FC Diagnostic Borescope",
    model: "FLK-DS703FC / 8.5 mm probe",
    justification: "A rugged videoscope can inspect connector backshells, clamps, routing, and tight cavities before disassembly turns an inspection into a repair.",
    use: "Hard-to-reach harness, connector, and enclosure inspection",
    retailerQuery: "Fluke DS703 FC Diagnostic Video Borescope",
    manufacturerUrl: "https://www.fluke.com/en-us/product/industrial-imaging/fluke-ds703-fc",
    photoUrl: "https://media.fluke.com/1efb6a28-9e79-47cd-940a-b108002e6a80_product_slideshow_main.jpg",
  },
  {
    category: "Field Diagnostics",
    name: "Fluke 325 True-RMS Clamp Meter",
    model: "CAT III 600 V / CAT IV 300 V",
    justification: "True-RMS AC/DC current and voltage readings cover common non-linear loads without opening the circuit to insert a current meter.",
    use: "Live load checks, startup investigations, frequency, and temperature",
    retailerQuery: "Fluke 325 True RMS Clamp Meter",
    manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/clamp-meters/fluke-325",
    photoUrl: "https://media.fluke.com/f713fa00-6533-4029-96ce-b108002e0aa5_product_slideshow_main.jpg",
  },
];

const categories = [
  "All",
  "Aerospace Hand Tools",
  "Wire Termination",
  "Test Equipment",
  "Bench Prototyping",
  "Field Diagnostics",
] as const;

const launchPlan = [
  gear.find((item) => item.name === "Daniels Manufacturing AF8"),
  gear.find((item) => item.name === "Megger TDR500/3 Handheld Time Domain Reflectometer"),
  gear.find((item) => item.name === "Fluke 325 True-RMS Clamp Meter"),
].filter((item): item is Gear => Boolean(item));

function getGearIcon(category: GearCategory) {
  if (category === "Aerospace Hand Tools") return ShieldCheck;
  if (category === "Wire Termination") return Cable;
  if (category === "Test Equipment") return Activity;
  if (category === "Bench Prototyping") return Wrench;
  return Gauge;
}

function ToolPhoto({ item, Icon }: { item: Gear; Icon: typeof Wrench }) {
  const [imageFailed, setImageFailed] = useState(false);

  return (
    <div className="relative flex aspect-[16/9] items-center justify-center overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--background)]">
      {item.photoUrl && !imageFailed ? (
        <img
          src={item.photoUrl}
          alt={`${item.name} product photo`}
          className="h-full w-full object-contain p-5"
          loading="lazy"
          decoding="async"
          onError={() => setImageFailed(true)}
        />
      ) : (
        <div className="flex flex-col items-center gap-2 px-4 text-center text-[var(--muted)]">
          {imageFailed ? <ImageOff className="h-7 w-7" aria-hidden="true" /> : <Icon className="h-8 w-8 text-[var(--accent)]" aria-hidden="true" />}
          <span className="text-[10px] font-semibold uppercase tracking-[0.14em]">
            {imageFailed ? "Photo unavailable" : "Manufacturer page linked below"}
          </span>
        </div>
      )}
    </div>
  );
}

export function GearMatrix() {
  const [category, setCategory] = useState<(typeof categories)[number]>("All");
  const [query, setQuery] = useState("");
  const normalizedQuery = query.trim().toLowerCase();
  const visible = gear.filter((item) => {
    const matchesCategory = category === "All" || item.category === category;
    const searchableText = `${item.name} ${item.model} ${item.justification} ${item.use}`.toLowerCase();
    return matchesCategory && searchableText.includes(normalizedQuery);
  });

  return (
    <section className="space-y-6" aria-labelledby="gear-title">
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Expert electrical gear matrix</p>
        <h1 id="gear-title" className="mt-2 font-display text-4xl font-bold">Field and aerospace tools, chosen for the work.</h1>
        <p className="mt-4 max-w-2xl text-[var(--muted)]">
          Specific models for aerospace harness work, field diagnostics, electrical test, and TDR fault locating. Every recommendation explains the engineering fit and the real task it supports.
        </p>
      </div>

      <div className="grid gap-3 md:grid-cols-3" aria-label="Tool selection milestones">
        {(["Define the task", "Choose the instrument", "Document the result"] as const).map((time, index) => (
          <div className="card-surface p-5" key={time}>
            <p className="text-xs font-bold uppercase tracking-[0.14em] text-[var(--accent)]">{time}</p>
            <h2 className="mt-2 font-display text-lg font-bold">{["Start with the failure mode", "Match specs to the job", "Keep evidence of the test"][index]}</h2>
            <p className="mt-2 text-sm leading-6 text-[var(--muted)]">{["Identify whether you need measurement, termination, inspection, or fault location.", "Compare safety category, range, accuracy, connector family, and environment.", "Record the setup, readings, photos, and manufacturer references with the result."][index]}</p>
          </div>
        ))}
      </div>

      <div className="rounded-xl border border-amber-400/30 bg-amber-400/5 p-4 text-sm leading-6 text-[var(--muted)]">
        <strong className="text-[var(--foreground)]">Important:</strong> These products cannot guarantee a license, certification, employment outcome, or Amazon Associates approval. This is an expert product-selection guide, not a promise that three qualifying sales will occur.
      </div>

      <section className="card-surface overflow-hidden" aria-labelledby="affiliate-goal-title">
        <div className="border-b border-[var(--border)] bg-[var(--accent-soft)]/40 p-5 md:p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Affiliate activation plan</p>
              <h2 id="affiliate-goal-title" className="mt-2 font-display text-2xl font-bold">Three useful purchases. One 180-day window.</h2>
            </div>
            <div className="rounded-full border border-[var(--accent)]/30 px-3 py-1 text-xs font-bold text-[var(--accent)]">3 qualifying sales / 180 days</div>
          </div>
          <p className="mt-3 max-w-3xl text-sm leading-6 text-[var(--muted)]">For Beckify’s Amazon Associates milestone, create helpful task-specific content around products people already need. Link only when the recommendation solves the reader’s problem; purchasing any particular item is never required. Amazon says qualifying sales must be attributed through the Associates links within the initial 180-day window.</p>
        </div>
        <div className="grid gap-px bg-[var(--border)] md:grid-cols-3">
          {launchPlan.map((item, index) => (
            <article className="bg-[var(--surface)] p-5" key={item.name}>
              <div className="flex items-center justify-between text-xs font-bold uppercase tracking-[0.14em] text-[var(--muted)]"><span>Priority {index + 1}</span><span className="text-[var(--accent)]">{item.stage ?? "Use-case fit"}</span></div>
              <h3 className="mt-3 font-display text-lg font-bold">{item.name}</h3>
              <p className="mt-2 text-sm leading-6 text-[var(--muted)]">{item.use}</p>
              <a href={amazonSearchUrl(item.retailerQuery)} target="_blank" rel={hasAffiliateTag ? "sponsored noopener noreferrer" : "noopener noreferrer"} className="mt-4 inline-flex items-center gap-2 text-sm font-semibold text-[var(--accent)] hover:underline"><ShoppingBag className="h-4 w-4" aria-hidden="true" /> View current availability <ExternalLink className="h-3.5 w-3.5" aria-hidden="true" /></a>
            </article>
          ))}
        </div>
        <div className="border-t border-[var(--border)] p-5 text-xs leading-5 text-[var(--muted)]">Do not offer rewards, ask people to buy through your links, or imply that a purchase supports a cause. Keep the content useful and disclose the relationship before the shopping links.</div>
      </section>

      <div className="card-surface flex flex-col gap-4 p-4 md:flex-row md:items-center md:justify-between">
        <div className="flex flex-wrap gap-2" aria-label="Filter gear by category">
          {categories.map((item) => (
            <button
              type="button"
              key={item}
              aria-pressed={category === item}
              onClick={() => setCategory(item)}
              className={`rounded-full border px-3 py-1.5 text-xs font-semibold transition-colors ${category === item ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--accent)]" : "border-[var(--border)] text-[var(--muted)] hover:text-[var(--foreground)]"}`}
            >
              {item}
            </button>
          ))}
        </div>
        <label className="flex items-center gap-2 rounded-lg border border-[var(--border)] px-3 py-2">
          <Search className="h-4 w-4 text-[var(--muted)]" aria-hidden="true" />
          <span className="sr-only">Filter recommended tools</span>
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Filter tools"
            className="w-full bg-transparent text-sm outline-none placeholder:text-[var(--muted)] md:w-48"
            aria-label="Filter recommended tools"
          />
        </label>
      </div>

      <p className="text-sm text-[var(--muted)]" aria-live="polite">
        Showing {visible.length} of {gear.length} recommendations
      </p>

      {visible.length > 0 ? (
        <div className="grid gap-4 md:grid-cols-2">
          {visible.map((item) => {
            const Icon = getGearIcon(item.category);
            const retailerUrl = amazonSearchUrl(item.retailerQuery);
            return (
              <article className="card-surface flex flex-col p-6" key={item.name}>
                <ToolPhoto item={item} Icon={Icon} />
                <div className="mt-5 flex items-start justify-between gap-4">
                  <div className="rounded-xl bg-[var(--accent-soft)] p-3">
                    <Icon className="h-5 w-5 text-[var(--accent)]" aria-hidden="true" />
                  </div>
                  <span className="text-right text-[10px] font-bold uppercase tracking-[0.14em] text-[var(--muted)]">{item.category}</span>
                </div>
                <h2 className="mt-5 font-display text-xl font-bold">{item.name}</h2>
                <p className="mt-1 text-xs font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">{item.model}</p>
                <p className="mt-3 text-sm leading-6 text-[var(--muted)]">{item.justification}</p>
                <div className="mt-4 flex items-start gap-2 text-xs text-[var(--foreground)]">
                  <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-[var(--accent)]" aria-hidden="true" />
                  <span>{item.use}</span>
                </div>
                {item.checkpoint ? <div className="mt-4 rounded-lg border border-[var(--border)] bg-black/10 p-3 text-xs leading-5 text-[var(--muted)]"><span className="font-semibold text-[var(--foreground)]">Checkpoint:</span> {item.checkpoint}</div> : null}
                <div className="mt-6 flex flex-wrap gap-x-4 gap-y-2 text-sm font-semibold">
                  <a
                    href={retailerUrl}
                    target="_blank"
                    rel={hasAffiliateTag ? "sponsored noopener noreferrer" : "noopener noreferrer"}
                    className="inline-flex items-center gap-2 text-[var(--accent)] hover:underline"
                    aria-label={`${hasAffiliateTag ? "Shop" : "Search for"} ${item.name} on Amazon, opens in a new tab`}
                  >
                    <ShoppingBag className="h-4 w-4" aria-hidden="true" />
                    {hasAffiliateTag ? "Shop via Amazon" : "Search Amazon"}
                    <ExternalLink className="h-3.5 w-3.5" aria-hidden="true" />
                  </a>
                  <a
                    href={item.manufacturerUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2 text-[var(--muted)] hover:text-[var(--foreground)] hover:underline"
                    aria-label={`View ${item.name} manufacturer details, opens in a new tab`}
                  >
                    <BadgeCheck className="h-4 w-4" aria-hidden="true" />
                    Manufacturer specs
                    <ExternalLink className="h-3.5 w-3.5" aria-hidden="true" />
                  </a>
                </div>
              </article>
            );
          })}
        </div>
      ) : (
        <div className="card-surface p-8 text-center">
          <p className="font-display text-lg font-bold">No tools match that filter.</p>
          <button type="button" onClick={() => { setCategory("All"); setQuery(""); }} className="mt-3 text-sm font-semibold text-[var(--accent)] hover:underline">
            Clear filters
          </button>
        </div>
      )}

      <div id="affiliate-disclosure" className="rounded-xl border border-[var(--border)] bg-black/15 p-4 text-xs leading-5 text-[var(--muted)]">
        <strong className="text-[var(--foreground)]">Affiliate disclosure:</strong> Some retailer links may be affiliate links. If you purchase through one, Beckify may earn a commission at no extra cost to you. Recommendations are based on technical fit and field use, not commission amount.
        {hasAffiliateTag ? " As an Amazon Associate I earn from qualifying purchases. Amazon Associates tracking is active for retailer links in this build." : " Retailer tracking is not active in this build; configure VITE_AMAZON_ASSOCIATE_TAG after joining a retailer program to activate it."}
      </div>
    </section>
  );
}
