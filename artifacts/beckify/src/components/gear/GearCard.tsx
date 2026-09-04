import {
  BadgeCheck,
  BatteryCharging,
  ChevronDown,
  ExternalLink,
  Flag,
  Gauge,
  RadioTower,
  Wrench,
} from "lucide-react";
import type { Gear, GearCategory } from "@/data/gear-recommendations";

export function getGearIcon(category: GearCategory) {
  if (category === "Tools and supplies") return Wrench;
  if (category === "Test equipment") return Gauge;
  if (category === "Cable and fault location") return RadioTower;
  return BatteryCharging;
}

export function httpUrl(raw: string): string | undefined {
  try {
    const url = new URL(raw);
    if (url.protocol === "https:" || url.protocol === "http:") return url.href;
  } catch {
    /* ignore malformed */
  }
  return undefined;
}

function gearHighlights(item: Gear) {
  const highlights = [item.model, item.bestFor];
  if (item.usaMade) highlights.push("American-made focus for sourcing and field durability");
  if (item.certification) highlights.push(item.certification);
  if (item.budget) highlights.push("Budget-friendly option without losing core utility");
  return highlights.slice(0, 3);
}

type PhotoSize = "lookbook" | "lead" | "row" | "featured";

export function ProductVisual({
  item,
  size = "lookbook",
  priority = false,
}: {
  item: Gear;
  size?: PhotoSize;
  priority?: boolean;
}) {
  const Icon = getGearIcon(item.category);
  const frame =
    size === "row"
      ? "h-14 w-14 p-1.5"
      : size === "lead"
        ? "h-44 p-6 md:h-full md:min-h-52 md:p-8"
        : size === "featured"
          ? "h-44 p-6 md:h-48 md:p-7"
          : "h-48 p-7 md:h-56 md:p-8";
  const panel = item.imagePlaceholder || !item.imageUrl ? "bg-[#0b0e16]" : "bg-[#efece3]";

  if (item.imageUrl) {
    return (
      <figure className={`overflow-hidden ${panel} ${size === "row" ? "rounded-lg" : "rounded-2xl"}`}>
        <div className={frame}>
          <img
            src={item.imageUrl}
            alt={`${item.name}, ${item.model}`}
            width={size === "row" ? 56 : 480}
            height={size === "row" ? 56 : 320}
            loading={priority ? "eager" : "lazy"}
            fetchPriority={priority ? "high" : "auto"}
            decoding="async"
            className="h-full w-full object-contain motion-safe:transition-transform motion-safe:duration-500 motion-safe:group-hover:scale-[1.03]"
          />
        </div>
      </figure>
    );
  }

  return (
    <div
      className={`relative flex items-center overflow-hidden ${panel} ${size === "row" ? "h-14 w-14 rounded-lg" : "mt-0 h-48 rounded-2xl p-5 md:h-56"}`}
      role="img"
      aria-label={`${item.name} product reference`}
    >
      <div className={`relative flex items-center ${size === "row" ? "justify-center w-full" : "gap-4 p-5"}`}>
        <span className={`flex shrink-0 items-center justify-center rounded-xl border border-white/10 bg-white/5 ${size === "row" ? "h-8 w-8" : "h-12 w-12"}`}>
          <Icon className={size === "row" ? "h-4 w-4 text-[var(--accent)]" : "h-6 w-6 text-[var(--accent)]"} aria-hidden="true" />
        </span>
        {size !== "row" && (
          <span className="font-mono text-sm font-semibold text-[var(--foreground)]">{item.model}</span>
        )}
      </div>
    </div>
  );
}

function AmazonLink({
  item,
  compact = false,
}: {
  item: Gear;
  compact?: boolean;
}) {
  const href = httpUrl(item.amazonUrl);
  if (!href) return null;
  return (
    <a
      href={href}
      target="_blank"
      rel="sponsored noopener noreferrer"
      aria-label={`View ${item.name} on Amazon (paid link)`}
      className={
        compact
          ? "inline-flex min-h-11 min-w-11 items-center justify-center gap-1.5 rounded-lg px-2.5 text-sm font-semibold text-[var(--accent)] transition hover:text-[var(--accent-2)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--accent)]"
          : "inline-flex min-h-11 items-center justify-center gap-2 rounded-lg bg-[var(--accent)] px-4 py-2 text-sm font-semibold text-[var(--accent-foreground)] transition hover:bg-[var(--accent-2)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--accent)]"
      }
    >
      View on Amazon
      <ExternalLink className="h-3.5 w-3.5" aria-hidden="true" />
    </a>
  );
}

function ManufacturerLink({ item }: { item: Gear }) {
  const href = httpUrl(item.manufacturerUrl);
  if (!href) return null;
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex min-h-11 items-center gap-1.5 text-sm text-[var(--muted)] transition hover:text-[var(--foreground)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--accent)]"
    >
      Specs
      <ExternalLink className="h-3.5 w-3.5" aria-hidden="true" />
    </a>
  );
}

function FieldNotes({ item, extra }: { item: Gear; extra?: string }) {
  return (
    <details className="group/notes mt-3">
      <summary className="flex min-h-11 cursor-pointer list-none items-center gap-1.5 text-xs font-medium text-[var(--muted)] transition hover:text-[var(--foreground)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--accent)] [&::-webkit-details-marker]:hidden">
        Field notes
        <ChevronDown className="h-3.5 w-3.5 transition group-open/notes:rotate-180" aria-hidden="true" />
      </summary>
      <div className="mt-2 space-y-2 text-sm leading-6 text-[var(--muted)]">
        <p>{item.note}</p>
        {extra ? <p>{extra}</p> : null}
        {item.usaMadeSource ? <p>{item.usaMadeSource}</p> : null}
      </div>
    </details>
  );
}

function StatusChips({
  item,
  role,
  budget,
}: {
  item: Gear;
  role?: string;
  budget?: boolean;
}) {
  return (
    <span className="flex flex-wrap items-center gap-1.5 text-[10px] font-semibold uppercase tracking-[0.14em] text-[var(--muted)]">
      {role ? <span className="text-[var(--foreground)]/70">{role}</span> : null}
      {budget || item.budget ? (
        <span className="rounded-full bg-amber-300/10 px-2 py-0.5 text-amber-200">Budget alt</span>
      ) : null}
      {item.usaMade ? (
        <span className="inline-flex items-center gap-1 rounded-full bg-blue-300/10 px-2 py-0.5 text-blue-100">
          <Flag className="h-3 w-3" aria-hidden="true" /> USA made
        </span>
      ) : null}
      {item.certification ? (
        <span className="inline-flex items-center gap-1 rounded-full bg-emerald-300/10 px-2 py-0.5 text-emerald-200">
          <BadgeCheck className="h-3 w-3" aria-hidden="true" /> {item.certification}
        </span>
      ) : null}
    </span>
  );
}

export function GearCard({
  item,
  featured = false,
  showOrigin = false,
  role,
  budget,
  priority = false,
}: {
  item: Gear;
  featured?: boolean;
  showOrigin?: boolean;
  role?: string;
  budget?: boolean;
  priority?: boolean;
}) {
  return (
    <article className={`group flex flex-col ${featured ? "rounded-2xl border border-[var(--accent)]/25 p-4 md:p-5" : ""}`}>
      <ProductVisual item={item} size={featured ? "featured" : "lookbook"} priority={priority} />
      <div className="mt-4 flex flex-1 flex-col">
        <StatusChips item={item} role={role} budget={budget} />
        <h3 className="mt-2 font-display text-xl font-bold tracking-tight text-pretty">{item.name}</h3>
        <p className="mt-1 font-mono text-xs text-[var(--muted)]">{item.model}</p>
        <p className="mt-3 text-sm leading-6 text-[var(--foreground)]/90">{item.bestFor}</p>
        {showOrigin && item.usaMadeSource ? (
          <p className="mt-3 text-sm leading-6 text-blue-100/85">{item.usaMadeSource}</p>
        ) : null}
        <div className="mt-auto pt-4">
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
            <AmazonLink item={item} />
            <ManufacturerLink item={item} />
          </div>
          <FieldNotes
            item={item}
            extra={featured ? gearHighlights(item).filter((line) => line !== item.model && line !== item.bestFor).join(" · ") : undefined}
          />
        </div>
      </div>
    </article>
  );
}

export function GearLeadCard({ item, priority = false }: { item: Gear; priority?: boolean }) {
  return (
    <article className="group grid gap-5 md:grid-cols-[minmax(0,14rem)_minmax(0,1fr)] md:items-center">
      <ProductVisual item={item} size="lead" priority={priority} />
      <div className="min-w-0">
        <StatusChips item={item} />
        <h3 className="mt-2 font-display text-2xl font-bold tracking-tight text-pretty">{item.name}</h3>
        <p className="mt-1 font-mono text-xs text-[var(--muted)]">{item.model}</p>
        <p className="mt-3 max-w-xl text-sm leading-6 text-[var(--foreground)]/90">{item.bestFor}</p>
        <div className="mt-4 flex flex-wrap items-center gap-x-3 gap-y-1">
          <AmazonLink item={item} />
          <ManufacturerLink item={item} />
        </div>
        <FieldNotes item={item} />
      </div>
    </article>
  );
}

export function GearRow({ item }: { item: Gear }) {
  return (
    <article className="group grid grid-cols-[3.5rem_minmax(0,1fr)] items-center gap-3 py-3 md:grid-cols-[3.5rem_minmax(0,1fr)_auto] md:gap-4">
      <ProductVisual item={item} size="row" />
      <div className="min-w-0">
        <div className="flex flex-wrap items-baseline gap-x-2 gap-y-1">
          <h3 className="font-display text-base font-semibold tracking-tight">{item.name}</h3>
          {item.usaMade ? (
            <span className="text-[10px] font-semibold uppercase tracking-[0.14em] text-blue-100">USA</span>
          ) : null}
          {item.budget ? (
            <span className="text-[10px] font-semibold uppercase tracking-[0.14em] text-amber-200">Budget</span>
          ) : null}
        </div>
        <p className="mt-0.5 truncate font-mono text-xs text-[var(--muted)]">{item.model}</p>
        <p className="mt-1 line-clamp-2 text-sm leading-5 text-[var(--muted)] md:line-clamp-1">{item.bestFor}</p>
      </div>
      <div className="col-span-2 flex flex-wrap items-center gap-x-2 md:col-span-1 md:justify-end">
        <AmazonLink item={item} compact />
        <ManufacturerLink item={item} />
      </div>
    </article>
  );
}
