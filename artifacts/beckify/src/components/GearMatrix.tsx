import { useState } from "react";
import {
  BadgeCheck,
  Cable,
  CheckCircle2,
  ExternalLink,
  Gauge,
  Search,
  ShoppingBag,
  Wrench,
} from "lucide-react";

type GearCategory = "Wire Termination" | "Bench Prototyping" | "Field Diagnostics";

type Gear = {
  category: GearCategory;
  name: string;
  model: string;
  justification: string;
  use: string;
  retailerQuery: string;
  manufacturerUrl: string;
};

const AMAZON_ASSOCIATE_TAG = String(import.meta.env.VITE_AMAZON_ASSOCIATE_TAG ?? "").trim();
const hasAffiliateTag = AMAZON_ASSOCIATE_TAG.length > 0;

const amazonSearchUrl = (query: string) => {
  const url = new URL("https://www.amazon.com/s");
  url.searchParams.set("k", query);
  if (hasAffiliateTag) url.searchParams.set("tag", AMAZON_ASSOCIATE_TAG);
  return url.toString();
};

const gear: Gear[] = [
  {
    category: "Wire Termination",
    name: "Phoenix Contact CRIMPFOX 4 IN 1",
    model: "Part 1200101",
    justification: "A pressure-locked ferrule tool that combines cutting, stripping, twisting, and crimping for DIN 46228-4 ferrules.",
    use: "Fast control-panel wiring with 0.5 to 2.5 mm² ferrules",
    retailerQuery: "Phoenix Contact CRIMPFOX 4 IN 1 1200101",
    manufacturerUrl: "https://www.phoenixcontact.com/en-us/products/hand-tools/crimping-tools",
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
    category: "Bench Prototyping",
    name: "Fluke 87V Industrial Multimeter",
    model: "True-RMS DMM",
    justification: "True-RMS measurement and a low-pass filter make it a strong fit for VFDs, motor drives, plant automation, and other non-linear signals.",
    use: "Industrial troubleshooting and intermittent fault capture",
    retailerQuery: "Fluke 87V Industrial Multimeter",
    manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/digital-multimeters/fluke-87v",
  },
  {
    category: "Field Diagnostics",
    name: "Megger MIT420/2 Insulation Tester",
    model: "50 to 1000 V test range",
    justification: "A dedicated insulation tester applies a defined DC test voltage and measures leakage that a continuity beep cannot reveal.",
    use: "Cable insulation, motor winding, PI/DAR, and live-circuit checks",
    retailerQuery: "Megger MIT420/2 insulation resistance tester",
    manufacturerUrl: "https://www.megger.com/en-us/products/mit400/2-series",
  },
  {
    category: "Field Diagnostics",
    name: "Fluke 325 True-RMS Clamp Meter",
    model: "CAT III 600 V / CAT IV 300 V",
    justification: "True-RMS AC/DC current and voltage readings cover common non-linear loads without opening the circuit to insert a current meter.",
    use: "Live load checks, startup investigations, frequency, and temperature",
    retailerQuery: "Fluke 325 True RMS Clamp Meter",
    manufacturerUrl: "https://www.fluke.com/en-us/product/electrical-testing/clamp-meters/fluke-325",
  },
];

const categories = ["All", "Wire Termination", "Bench Prototyping", "Field Diagnostics"] as const;

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
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Field kit</p>
        <h1 id="gear-title" className="mt-2 font-display text-4xl font-bold">Recommended tools, chosen for the work.</h1>
        <p className="mt-4 max-w-2xl text-[var(--muted)]">
          Specific models for building, terminating, and diagnosing electrical systems. Selection notes explain the engineering fit, not just the logo.
        </p>
      </div>

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
            const Icon = item.category === "Wire Termination" ? Cable : item.category === "Bench Prototyping" ? Wrench : Gauge;
            const retailerUrl = amazonSearchUrl(item.retailerQuery);
            return (
              <article className="card-surface flex flex-col p-6" key={item.name}>
                <div className="flex items-start justify-between gap-4">
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
        {hasAffiliateTag ? " Amazon Associates tracking is active for retailer links in this build." : " Retailer tracking is not active in this build; configure VITE_AMAZON_ASSOCIATE_TAG after joining a retailer program to activate it."}
      </div>
    </section>
  );
}
