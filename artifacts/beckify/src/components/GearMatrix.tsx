import { useEffect, useMemo, useRef, useState } from "react";
import { Link } from "wouter";
import { Search, ShieldCheck } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { GearCard, GearLeadCard, GearRow } from "@/components/gear/GearCard";
import {
  CATALOG_LEADS,
  CATALOG_SECTIONS,
  GEAR_KITS,
  GEAR_RECOMMENDATIONS,
  JOBSITE_SUPPORT_NAMES,
  findGear,
  kitEntries,
  type Gear,
  type GearCategory,
} from "@/data/gear-recommendations";

export { GEAR_RECOMMENDATIONS } from "@/data/gear-recommendations";

type CatalogChip = "All" | GearCategory | "USA made";

const CHIPS: { id: CatalogChip; label: string }[] = [
  { id: "All", label: "All" },
  ...CATALOG_SECTIONS.map((section) => ({ id: section.category as CatalogChip, label: section.chip })),
  { id: "USA made", label: "USA" },
];

function initialChipFromUrl(): CatalogChip {
  if (typeof window === "undefined") return "All";
  return new URLSearchParams(window.location.search).get("filter") === "usa-made" ? "USA made" : "All";
}

function matchesQuery(item: Gear, query: string) {
  if (!query) return true;
  const haystack = [item.name, item.model, item.bestFor, item.note, item.category, item.certification ?? ""]
    .join(" ")
    .toLowerCase();
  return query
    .toLowerCase()
    .split(/\s+/)
    .filter(Boolean)
    .every((term) => haystack.includes(term));
}

function sectionLead(items: Gear[], category: GearCategory) {
  const preferred = items.find((item) => item.name === CATALOG_LEADS[category]);
  return preferred ?? items[0];
}

export function GearMatrix() {
  const [chip, setChip] = useState<CatalogChip>(initialChipFromUrl);
  const [query, setQuery] = useState("");
  const catalogRef = useRef<HTMLDivElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const openUsaOnLoad = initialChipFromUrl() === "USA made";

  useEffect(() => {
    if (openUsaOnLoad) catalogRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [openUsaOnLoad]);

  const filtered = useMemo(
    () =>
      GEAR_RECOMMENDATIONS.filter((item) => {
        if (chip === "USA made" && !item.usaMade) return false;
        if (chip !== "All" && chip !== "USA made" && item.category !== chip) return false;
        return matchesQuery(item, query);
      }),
    [chip, query],
  );

  const sections = useMemo(() => {
    const visibleCategories =
      chip !== "All" && chip !== "USA made"
        ? CATALOG_SECTIONS.filter((section) => section.category === chip)
        : CATALOG_SECTIONS;
    return visibleCategories
      .map((section) => {
        const items = filtered.filter((item) => item.category === section.category);
        const lead = items.length ? sectionLead(items, section.category) : undefined;
        const rest = lead ? items.filter((item) => item.name !== lead.name) : [];
        return { ...section, lead, rest };
      })
      .filter((section) => section.lead);
  }, [chip, filtered]);

  const selectChip = (next: CatalogChip) => {
    setChip(next);
    const params = new URLSearchParams(window.location.search);
    if (next === "USA made") params.set("filter", "usa-made");
    else params.delete("filter");
    const nextUrl = `${window.location.pathname}${params.toString() ? `?${params}` : ""}${window.location.hash}`;
    window.history.replaceState(null, "", nextUrl);
  };

  return (
    <section className="space-y-16 md:space-y-24" aria-labelledby="gear-title">
      <header className="relative overflow-hidden pb-2 pt-2 md:pt-6">
        <div
          className="pointer-events-none absolute inset-x-0 -top-8 h-64 opacity-70"
          style={{
            background:
              "radial-gradient(ellipse 80% 70% at 0% 0%, rgba(139,123,255,0.16), transparent 60%)",
          }}
        />
        <div className="relative">
          <p className="type-label text-[var(--accent)]">Field kit</p>
          <h1 id="gear-title" className="mt-4 max-w-3xl font-display text-4xl font-extrabold tracking-tight text-pretty md:text-6xl">
            Gear we actually trust on the job.
          </h1>
          <p className="mt-5 max-w-xl text-base leading-7 text-[var(--muted)] md:text-lg">
            Model-specific picks for electrical field work. Not a gadget dump — a short list of what earns a spot in
            the bag.
          </p>
          <p className="mt-4 max-w-xl text-xs leading-5 text-[var(--muted)]/80">
            As an Amazon Associate I earn from qualifying purchases. Amazon buttons are paid links.
          </p>
          <div className="mt-8 flex flex-wrap items-center gap-x-5 gap-y-2 text-sm font-semibold">
            <a
              href="#kits"
              className="text-[var(--foreground)] underline-offset-4 transition hover:text-[var(--accent)] hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--accent)]"
            >
              Jump to kits
            </a>
            <a
              href="#catalog"
              className="text-[var(--muted)] underline-offset-4 transition hover:text-[var(--foreground)] hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--accent)]"
            >
              Browse all
            </a>
          </div>
        </div>
      </header>

      <nav aria-label="Field kits" className="flex flex-wrap gap-x-6 gap-y-2 border-y border-[var(--border)] py-4 text-sm">
        {GEAR_KITS.map((kit) => (
          <a
            key={kit.id}
            href={`#${kit.id}`}
            className="font-medium text-[var(--muted)] transition hover:text-[var(--foreground)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--accent)]"
          >
            <span className="mr-2 font-mono text-[11px] text-[var(--accent)]">{kit.index}</span>
            {kit.name}
          </a>
        ))}
      </nav>

      <div className="flex gap-3 text-sm leading-6 text-[var(--muted)]">
        <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-[var(--accent)]" aria-hidden="true" />
        <p className="m-0">
          Use approved procedures, ratings, and calibration. These picks support the work; they do not replace it.
        </p>
      </div>

      <div id="kits" className="scroll-mt-28 space-y-20 md:space-y-28">
        {GEAR_KITS.map((kit, kitIndex) => {
          const entries = kitEntries(kit);
          return (
            <FadeIn key={kit.id}>
              <section id={kit.id} aria-labelledby={`${kit.id}-title`} className="scroll-mt-28">
                <header className="max-w-2xl">
                  <p className="font-mono text-xs tracking-[0.18em] text-[var(--accent)]">{kit.index}</p>
                  <h2 id={`${kit.id}-title`} className="mt-2 font-display text-3xl font-bold tracking-tight md:text-4xl">
                    {kit.name}
                  </h2>
                  <p className="mt-3 text-[var(--muted)]">{kit.job}</p>
                </header>
                <div className="mt-8 grid gap-x-8 gap-y-12 sm:grid-cols-2">
                  {entries.map((entry, index) => (
                    <GearCard
                      key={`${kit.id}-${entry.item.name}`}
                      item={entry.item}
                      role={entry.role}
                      budget={entry.budget}
                      priority={kitIndex === 0 && index === 0}
                    />
                  ))}
                </div>
              </section>
            </FadeIn>
          );
        })}
      </div>

      <FadeIn>
        <section
          id="jobsite-support"
          aria-labelledby="jobsite-support-title"
          className="scroll-mt-28 border-t border-[var(--border)] pt-12"
        >
          <p className="type-label text-[var(--muted)]">Optional</p>
          <h2 id="jobsite-support-title" className="mt-2 font-display text-2xl font-bold tracking-tight">
            Jobsite support
          </h2>
          <p className="mt-2 max-w-xl text-sm text-[var(--muted)]">
            Power and light when the site is the constraint — not part of the core electrical kit.
          </p>
          <div className="mt-6 divide-y divide-[var(--border)]">
            {JOBSITE_SUPPORT_NAMES.map((name) => (
              <GearRow key={name} item={findGear(name)} />
            ))}
          </div>
        </section>
      </FadeIn>

      <div ref={catalogRef} id="catalog" className="scroll-mt-28">
        <div className="mb-6">
          <p className="type-label text-[var(--accent)]">Index</p>
          <h2 className="mt-2 font-display text-3xl font-bold tracking-tight">Browse all</h2>
        </div>

        <div className="sticky top-[5.75rem] z-30 -mx-2 mb-10 rounded-2xl border border-[var(--border)] bg-[color-mix(in_oklab,var(--background)_82%,transparent)] px-2 py-2 backdrop-blur-md md:-mx-0 md:px-3">
          <div className="flex flex-col gap-3 md:flex-row md:items-center">
            <label className="relative block min-w-0 flex-1">
              <span className="sr-only">Search gear</span>
              <Search className="pointer-events-none absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-[var(--muted)]" aria-hidden="true" />
              <input
                ref={searchRef}
                type="search"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Search model, maker, or job"
                className="h-11 w-full rounded-xl border-0 bg-transparent pr-3 pl-10 text-sm text-[var(--foreground)] placeholder:text-[var(--muted)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--accent)]"
              />
            </label>
            <div role="toolbar" aria-label="Catalog filters" className="flex flex-wrap gap-1">
              {CHIPS.map((entry) => {
                const active = chip === entry.id;
                return (
                  <button
                    key={entry.id}
                    type="button"
                    aria-pressed={active}
                    onClick={() => selectChip(entry.id)}
                    className={`min-h-11 rounded-full px-3.5 text-sm font-medium transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--accent)] ${
                      active
                        ? "bg-[var(--accent)] text-[var(--accent-foreground)]"
                        : "text-[var(--muted)] hover:bg-white/5 hover:text-[var(--foreground)]"
                    }`}
                  >
                    {entry.label}
                  </button>
                );
              })}
            </div>
          </div>
        </div>

        {query.trim() ? (
          <p className="mb-6 text-xs text-[var(--muted)]" aria-live="polite">
            {filtered.length === 0 ? "No matches" : `${filtered.length} match${filtered.length === 1 ? "" : "es"}`}
          </p>
        ) : null}

        {sections.length === 0 ? (
          <div className="py-16 text-center">
            <p className="font-display text-xl font-semibold">Nothing matches.</p>
            <p className="mt-2 text-sm text-[var(--muted)]">Try Fluke, TDR, or stripper — or clear the search.</p>
            <button
              type="button"
              onClick={() => {
                setQuery("");
                setChip("All");
                searchRef.current?.focus();
              }}
              className="mt-5 min-h-11 rounded-lg px-4 text-sm font-semibold text-[var(--accent)] transition hover:text-[var(--accent-2)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--accent)]"
            >
              Clear filters
            </button>
          </div>
        ) : (
          <div className="space-y-16">
            {sections.map((section) => (
              <section
                key={section.category}
                aria-labelledby={`${section.category.replace(/\s+/g, "-").toLowerCase()}-title`}
                style={{ contentVisibility: "auto", containIntrinsicBlockSize: "auto 480px" }}
              >
                <div className="mb-6 flex items-end justify-between gap-4">
                  <h3
                    id={`${section.category.replace(/\s+/g, "-").toLowerCase()}-title`}
                    className="font-display text-2xl font-bold tracking-tight"
                  >
                    {section.label}
                  </h3>
                  {section.category === "Tools and supplies" ? (
                    <Link
                      href="/made-in-america"
                      className="shrink-0 text-xs font-medium text-[var(--muted)] underline-offset-4 hover:text-[var(--foreground)] hover:underline"
                    >
                      USA-made guide
                    </Link>
                  ) : null}
                </div>
                {section.lead ? <GearLeadCard item={section.lead} /> : null}
                {section.rest.length > 0 ? (
                  <div className="mt-6 divide-y divide-[var(--border)] border-t border-[var(--border)]">
                    {section.rest.map((item) => (
                      <GearRow key={item.name} item={item} />
                    ))}
                  </div>
                ) : null}
              </section>
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
