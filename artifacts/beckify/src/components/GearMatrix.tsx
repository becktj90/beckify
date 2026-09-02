import { useEffect, useMemo, useRef, useState } from "react";
import { Link } from "wouter";
import {
  BatteryCharging,
  Cable,
  ChevronRight,
  Factory,
  Gauge,
  ShieldCheck,
  Wrench,
} from "lucide-react";
import { GearCard } from "@/components/gear/GearCard";
import { GEAR_RECOMMENDATIONS } from "@/data/gear-recommendations";
import type { GearCategory } from "@/data/gear-recommendations";

export { GEAR_RECOMMENDATIONS } from "@/data/gear-recommendations";

type GearFilter = "All" | GearCategory | "USA made";

const categoryGuides: { filter: GearFilter; label: string; description: string; icon: typeof Wrench }[] = [
  { filter: "All", label: "All gear", description: "Every recommendation", icon: Wrench },
  { filter: "Tools and supplies", label: "Tools & supplies", description: "Cut, strip, torque, tape", icon: Wrench },
  { filter: "Test equipment", label: "Test equipment", description: "Measure and diagnose", icon: Gauge },
  { filter: "Cable and fault location", label: "Cable & fault location", description: "Trace, verify, and locate", icon: Cable },
  { filter: "Job comfort and power", label: "Job comfort & power", description: "Light, power, cool, and store", icon: BatteryCharging },
  { filter: "USA made", label: "USA made", description: "Manufacturer-identified U.S. products", icon: ShieldCheck },
];

function initialFilterFromUrl(): GearFilter {
  if (typeof window === "undefined") return "All";
  return new URLSearchParams(window.location.search).get("filter") === "usa-made" ? "USA made" : "All";
}

export function GearMatrix() {
  const [filter, setFilter] = useState<GearFilter>(initialFilterFromUrl);
  const catalogRef = useRef<HTMLDivElement>(null);
  const featuredUsaMade = useMemo(() => GEAR_RECOMMENDATIONS.filter((item) => item.usaMade), []);
  const visible = useMemo(
    () =>
      GEAR_RECOMMENDATIONS.filter(
        (item) =>
          filter === "All" || (filter === "USA made" ? item.usaMade : item.category === filter),
      ).sort((left, right) => Number(Boolean(right.usaMade)) - Number(Boolean(left.usaMade))),
    [filter],
  );

  useEffect(() => {
    if (initialFilterFromUrl() === "USA made") catalogRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, []);

  const selectCategory = (nextFilter: GearFilter) => {
    setFilter(nextFilter);
    requestAnimationFrame(() => catalogRef.current?.scrollIntoView({ behavior: "smooth", block: "start" }));
  };

  const countFor = (nextFilter: GearFilter) =>
    GEAR_RECOMMENDATIONS.filter(
      (item) => nextFilter === "All" || (nextFilter === "USA made" ? item.usaMade : item.category === nextFilter),
    ).length;
  const title = filter === "All" ? "All recommended gear" : filter;

  return (
    <section className="space-y-7" aria-labelledby="gear-title">
      <header className="border-b border-[var(--border)] pb-7">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Recommended gear</p>
        <h1 id="gear-title" className="mt-2 max-w-3xl font-display text-4xl font-bold md:text-5xl">
          Tools, supplies, and field gear worth buying.
        </h1>
        <p className="mt-4 max-w-2xl text-[var(--muted)]">
          Industry-standard picks for electrical work, cable troubleshooting, field power, and job comfort.
          American-made favorites are featured first, and every card expands with practical field context.
        </p>
        <p className="mt-4 max-w-2xl text-xs leading-6 text-[var(--muted)]">
          As an Amazon Associate I earn from qualifying purchases. Amazon buttons are paid links.
        </p>
      </header>

      <section
        aria-labelledby="usa-made-title"
        className="rounded-3xl border border-[var(--accent)]/30 bg-[linear-gradient(180deg,rgba(79,139,255,0.12),rgba(255,255,255,0.03))] p-5 md:p-6"
      >
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-blue-200">Featured first</p>
            <h2 id="usa-made-title" className="mt-1 font-display text-2xl font-bold text-[var(--foreground)]">
              American-made gear worth prioritizing
            </h2>
            <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--muted)]">
              These picks rise to the top for domestic sourcing, proven craftsmanship, and dependable day-to-day use
              in the field and on the bench.
            </p>
          </div>
          <Link
            href="/made-in-america"
            className="inline-flex items-center gap-2 rounded-full border border-blue-300/30 px-4 py-2 text-sm font-semibold text-blue-100 transition hover:border-blue-200 hover:text-white"
          >
            <Factory className="h-4 w-4" /> View made-in-America guide
          </Link>
        </div>
        <div className="mt-5 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {featuredUsaMade.map((item) => (
            <GearCard key={`featured-${item.name}`} item={item} featured />
          ))}
        </div>
      </section>

      <section aria-labelledby="category-map-title">
        <div className="mb-4">
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Shop by category</p>
          <h2 id="category-map-title" className="mt-1 font-display text-2xl font-bold">
            Choose what you need.
          </h2>
        </div>
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {categoryGuides.map((guide) => {
            const Icon = guide.icon;
            const active = filter === guide.filter;
            return (
              <button
                key={guide.filter}
                type="button"
                aria-pressed={active}
                onClick={() => selectCategory(guide.filter)}
                className={`group flex items-center gap-3 rounded-xl border p-4 text-left transition ${active ? "border-[var(--accent)] bg-[var(--accent-soft)]" : "border-[var(--border)] bg-[var(--surface)] hover:border-[var(--accent)]/60 hover:bg-white/[0.025]"}`}
              >
                <span className="rounded-lg bg-[var(--accent-soft)] p-2">
                  <Icon className="h-5 w-5 text-[var(--accent)]" aria-hidden="true" />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block font-display text-base font-bold text-[var(--foreground)]">{guide.label}</span>
                  <span className="mt-0.5 block text-xs text-[var(--muted)]">
                    {guide.description} · {countFor(guide.filter)}
                  </span>
                </span>
                <ChevronRight
                  className="h-4 w-4 shrink-0 text-[var(--accent)] transition group-hover:translate-x-0.5"
                  aria-hidden="true"
                />
              </button>
            );
          })}
        </div>
      </section>

      <div className="flex gap-3 border-l-2 border-amber-400/70 bg-amber-400/5 px-4 py-3 text-sm leading-6 text-[var(--muted)]">
        <ShieldCheck className="mt-0.5 h-5 w-5 shrink-0 text-amber-300" aria-hidden="true" />
        <p className="m-0">
          Use approved procedures, ratings, and calibration requirements. These recommendations support the work; they
          do not replace them.
        </p>
      </div>

      <div ref={catalogRef} className="scroll-mt-6">
        <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Product list</p>
            <h2 className="mt-1 font-display text-2xl font-bold">{title}</h2>
          </div>
          {filter !== "All" && (
            <button
              type="button"
              onClick={() => setFilter("All")}
              className="rounded-full border border-[var(--border)] px-3 py-1.5 text-xs font-semibold text-[var(--muted)] transition hover:border-[var(--accent)] hover:text-[var(--accent)]"
            >
              Show all {GEAR_RECOMMENDATIONS.length} products
            </button>
          )}
        </div>
        <div className="grid gap-4 md:grid-cols-2">
          {visible.map((item) => (
            <GearCard key={item.name} item={item} />
          ))}
        </div>
      </div>
    </section>
  );
}
