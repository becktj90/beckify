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

type PhotoSize = "lookbook" | "featured";

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
  const frame = size === "featured" ? "h-44 p-6 md:h-48 md:p-7" : "h-48 p-7 md:h-56 md:p-8";
  const panel = item.imagePlaceholder || !item.imageUrl ? "bg-[#0b0e16]" : "bg-[#efece3]";

  if (item.imageUrl) {
    return (
      <figure className={`overflow-hidden rounded-2xl ${panel}`}>
        <div className={frame}>
          <img
            src={item.imageUrl}
            alt={`${item.name}, ${item.model}`}
            width={480}
            height={320}
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
      className={`relative mt-0 flex h-48 items-center overflow-hidden rounded-2xl p-5 md:h-56 ${panel}`}
      role="img"
      aria-label={`${item.name} product reference`}
    >
      <div className="relative flex items-center gap-4 p-5">
        <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl border border-white/10 bg-white/5">
          <Icon className="h-6 w-6 text-[var(--accent)]" aria-hidden="true" />
        </span>
        <span className="font-mono text-sm font-semibold text-[var(--foreground)]">{item.model}</span>
      </div>
    </div>
  );
}

function AmazonLink({ item }: { item: Gear }) {
  const href = httpUrl(item.amazonUrl);
  if (!href) return null;
  return (
    <a
      href={href}
      target="_blank"
      rel="sponsored noopener noreferrer"
      aria-label={`View ${item.name} on Amazon (paid link)`}
      className="inline-flex min-h-11 items-center justify-center gap-2 rounded-lg bg-[var(--accent)] px-4 py-2 text-sm font-semibold text-[var(--accent-foreground)] transition hover:bg-[var(--accent-2)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--accent)]"
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
      {budget ? (
        <span className="rounded-full bg-amber-300/10 px-2 py-0.5 text-amber-200">Budget alt</span>
      ) : item.budget && !role ? (
        <span className="rounded-full bg-amber-300/10 px-2 py-0.5 text-amber-200">Budget pick</span>
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
