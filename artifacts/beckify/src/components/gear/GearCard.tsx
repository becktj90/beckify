import { useState } from "react";
import {
  BadgeCheck,
  BatteryCharging,
  ChevronDown,
  ExternalLink,
  Flag,
  Gauge,
  RadioTower,
  ShoppingBag,
  Sparkles,
  Wrench,
} from "lucide-react";
import type { Gear, GearCategory } from "@/data/gear-recommendations";

export function getGearIcon(category: GearCategory) {
  if (category === "Tools and supplies") return Wrench;
  if (category === "Test equipment") return Gauge;
  if (category === "Cable and fault location") return RadioTower;
  return BatteryCharging;
}

function gearHighlights(item: Gear) {
  const highlights = [item.model, item.bestFor];
  if (item.usaMade) highlights.push("American-made focus for sourcing and field durability");
  if (item.certification) highlights.push(item.certification);
  if (item.budget) highlights.push("Budget-friendly option without losing core utility");
  return highlights.slice(0, 3);
}

function whyBest(item: Gear) {
  if (item.category === "Test equipment")
    return `${item.name} stands out when repeatable measurements and dependable field troubleshooting matter more than gadget count. The recommendation prioritizes instruments that are trusted for day-to-day diagnostics and that reward disciplined test procedure.`;
  if (item.category === "Cable and fault location")
    return `${item.name} earns its spot because it reduces time spent guessing about cable paths, faults, or impedance behavior. In practice, that means faster isolation, clearer verification, and fewer unnecessary terminations or pulls.`;
  if (item.category === "Job comfort and power")
    return `${item.name} is a best-choice support tool because it improves endurance and work quality when the environment is the constraint. Better lighting, portable power, or heat management usually turns into fewer mistakes and more consistent output on long jobs.`;
  return `${item.name} is favored because it solves a core field task with durable, purpose-built hardware instead of a compromise tool. That matters when repeatability, tool life, and confidence at the bench or in the field outweigh novelty.`;
}

function practicalApplication(item: Gear) {
  return `Use it when ${item.bestFor.charAt(0).toLowerCase()}${item.bestFor.slice(1)} In real work, the practical value comes from pairing that strength with the caution that ${item.note.charAt(0).toLowerCase()}${item.note.slice(1)}`;
}

export function ProductVisual({ item }: { item: Gear }) {
  const Icon = getGearIcon(item.category);

  if (item.imageUrl) {
    return (
      <figure className="mt-4 overflow-hidden rounded-xl border border-[var(--border)] bg-white/95">
        <div className="h-36 p-3">
          <img src={item.imageUrl} alt={item.name} loading="lazy" className="h-full w-full object-contain" />
        </div>
        <figcaption className="border-t border-[var(--border)] px-3 py-1.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-slate-600">
          Official product photo
        </figcaption>
      </figure>
    );
  }

  return (
    <div
      className="relative mt-4 flex h-36 items-center overflow-hidden rounded-xl border border-cyan-300/15 bg-[#07101c] p-5"
      role="img"
      aria-label={`${item.name} product reference`}
    >
      <div
        className="absolute inset-0 opacity-40"
        style={{
          backgroundImage:
            "linear-gradient(rgba(88,142,185,.18) 1px, transparent 1px), linear-gradient(90deg, rgba(88,142,185,.18) 1px, transparent 1px)",
          backgroundSize: "20px 20px",
        }}
      />
      <svg viewBox="0 0 480 144" className="absolute inset-0 h-full w-full" aria-hidden="true">
        <path
          d="M0 104h88l24-25h72l24 25h88l25-25h159"
          fill="none"
          stroke="#5ed7ff"
          strokeOpacity=".42"
          strokeWidth="2"
        />
        <path
          d="M8 42h76l18 18h66l18-35h84l18 35h70l20-18h112"
          fill="none"
          stroke="#9d7cff"
          strokeOpacity=".38"
          strokeWidth="2"
        />
      </svg>
      <div className="relative flex items-center gap-4">
        <span className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl border border-cyan-200/30 bg-[#0a1b2c]">
          <Icon className="h-7 w-7 text-cyan-200" aria-hidden="true" />
        </span>
        <span>
          <span className="block text-[10px] font-bold uppercase tracking-[0.16em] text-cyan-200/70">
            Product reference
          </span>
          <span className="mt-1 block font-mono text-sm font-semibold leading-5 text-slate-100">{item.model}</span>
        </span>
      </div>
    </div>
  );
}

function GearBadges({ item, featured = false }: { item: Gear; featured?: boolean }) {
  return (
    <span className="flex flex-wrap justify-end gap-1.5 text-right text-[10px] font-bold uppercase tracking-[0.12em]">
      <span className="text-[var(--muted)]">{item.category}</span>
      {item.usaMade && (
        <span
          className={`inline-flex items-center gap-1 rounded-full px-2 py-1 ${featured ? "bg-blue-300/20 text-blue-100" : "bg-blue-300/10 text-blue-200"}`}
        >
          <Flag className="h-3 w-3" /> USA made
        </span>
      )}
      {item.budget && <span className="rounded-full bg-amber-300/10 px-2 py-1 text-amber-200">Budget pick</span>}
      {item.certification && (
        <span className="inline-flex items-center gap-1 rounded-full bg-emerald-300/10 px-2 py-1 text-emerald-200">
          <BadgeCheck className="h-3 w-3" /> {item.certification}
        </span>
      )}
    </span>
  );
}

export function GearCard({
  item,
  featured = false,
  showOrigin = false,
}: {
  item: Gear;
  featured?: boolean;
  showOrigin?: boolean;
}) {
  const [expanded, setExpanded] = useState(false);
  const Icon = getGearIcon(item.category);
  const detailsId = `${item.name.toLowerCase().replace(/[^a-z0-9]+/g, "-")}-details`;

  return (
    <article
      className={`card-surface flex flex-col p-5 ${featured ? "border-[var(--accent)]/40 bg-[linear-gradient(180deg,rgba(79,139,255,0.11),rgba(255,255,255,0.03))]" : ""}`}
    >
      <div className="flex items-start justify-between gap-4">
        <span className="rounded-xl bg-[var(--accent-soft)] p-3">
          <Icon className="h-5 w-5 text-[var(--accent)]" aria-hidden="true" />
        </span>
        <GearBadges item={item} featured={featured} />
      </div>
      <ProductVisual item={item} />
      <div className="mt-4">
        <h3 className="font-display text-xl font-bold">{item.name}</h3>
        <p className="mt-1 text-xs font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">{item.model}</p>
      </div>
      {showOrigin && item.usaMadeSource && (
        <p className="mt-3 rounded-xl border border-blue-300/20 bg-blue-300/5 px-3 py-2 text-sm leading-6 text-blue-100/90">
          {item.usaMadeSource}
        </p>
      )}
      <p className="mt-4 text-sm font-semibold leading-6">{item.bestFor}</p>
      <p className="mt-2 text-sm leading-6 text-[var(--muted)]">{item.note}</p>
      <button
        type="button"
        aria-expanded={expanded}
        aria-controls={detailsId}
        onClick={() => setExpanded((value) => !value)}
        className="mt-4 inline-flex items-center justify-between rounded-2xl border border-[var(--border)] bg-black/15 px-4 py-3 text-left text-sm font-semibold text-[var(--foreground)] transition hover:border-[var(--accent)]/60"
      >
        <span className="inline-flex items-center gap-2">
          <Sparkles className="h-4 w-4 text-[var(--accent)]" /> Expand analysis
        </span>
        <ChevronDown className={`h-4 w-4 transition ${expanded ? "rotate-180" : ""}`} />
      </button>
      <div id={detailsId} hidden={!expanded} className="mt-4 rounded-2xl border border-[var(--border)] bg-black/15 p-4">
        <div className="grid gap-4 lg:grid-cols-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Highlights</p>
            <ul className="mt-3 space-y-2 text-sm leading-6 text-[var(--muted)]">
              {gearHighlights(item).map((highlight) => (
                <li key={highlight} className="flex gap-2">
                  <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-[var(--accent)]" aria-hidden="true" />{" "}
                  <span>{highlight}</span>
                </li>
              ))}
            </ul>
          </div>
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">
              Why it’s the best choice
            </p>
            <p className="mt-3 text-sm leading-6 text-[var(--muted)]">{whyBest(item)}</p>
          </div>
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">
              Pros & practical application
            </p>
            <p className="mt-3 text-sm leading-6 text-[var(--muted)]">{practicalApplication(item)}</p>
          </div>
        </div>
      </div>
      <div className="mt-5 flex flex-wrap items-center gap-3 text-sm font-semibold">
        <a
          href={item.amazonUrl}
          target="_blank"
          rel="sponsored noopener noreferrer"
          aria-label={`View the exact ${item.name} model on Amazon (paid link)`}
          className="inline-flex items-center gap-2 rounded-lg bg-[var(--accent)] px-4 py-2.5 text-[var(--accent-foreground)] transition hover:bg-[var(--accent-2)]"
        >
          <ShoppingBag className="h-4 w-4" /> View exact model on Amazon <ExternalLink className="h-3.5 w-3.5" />
        </a>
        <a
          href={item.manufacturerUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-2 px-1 py-2 text-[var(--muted)] transition hover:text-[var(--accent)] hover:underline"
        >
          Manufacturer specs <ExternalLink className="h-3.5 w-3.5" />
        </a>
      </div>
    </article>
  );
}
