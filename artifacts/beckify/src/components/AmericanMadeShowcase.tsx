import { Link } from "wouter";
import { ArrowRight, CheckCircle2, Factory, Flag, SearchCheck, ShieldCheck } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { GearCard } from "@/components/gear/GearCard";
import {
  GEAR_RECOMMENDATIONS,
  MADE_IN_AMERICA_FAQ,
  USA_MADE_BRANDS,
  USA_MADE_GEAR,
} from "@/data/gear-recommendations";

export function AmericanMadeShowcase() {
  const categoryCount = new Set(USA_MADE_GEAR.map((item) => item.category)).size;

  return (
    <section className="space-y-10" aria-labelledby="made-in-america-title">
      <FadeIn>
        <header className="relative overflow-hidden rounded-3xl border border-[var(--accent)]/25 bg-[linear-gradient(135deg,rgba(79,139,255,0.14),rgba(139,123,255,0.08)_45%,rgba(255,255,255,0.02))] p-6 md:p-10">
          <div
            className="pointer-events-none absolute inset-0 opacity-60"
            style={{
              background:
                "radial-gradient(ellipse at 85% 15%, rgba(79,139,255,0.18) 0%, transparent 55%), radial-gradient(ellipse at 10% 80%, rgba(139,123,255,0.12) 0%, transparent 50%)",
            }}
          />
          <div className="relative z-10 max-w-3xl">
            <p className="inline-flex items-center gap-2 text-[10px] font-semibold uppercase tracking-[0.2em] text-blue-200">
              <Flag className="h-3.5 w-3.5" aria-hidden="true" />
              Made in America
            </p>
            <h1 id="made-in-america-title" className="mt-3 font-display text-4xl font-bold leading-tight md:text-5xl">
              American-made electrical tools you can actually verify.
            </h1>
            <p className="mt-4 text-base leading-7 text-[var(--muted)] md:text-lg">
              A curated guide for electricians, technicians, and field engineers searching for tools made in the USA.
              Every pick links to the exact model and includes how we confirmed U.S. manufacturing — no vague
              &ldquo;assembled in America&rdquo; claims.
            </p>
            <p className="mt-4 text-xs leading-6 text-[var(--muted)]">
              As an Amazon Associate I earn from qualifying purchases. Amazon buttons are paid links.
            </p>
            <div className="mt-6 flex flex-wrap gap-3">
              <a
                href="#verified-picks"
                className="inline-flex items-center gap-2 rounded-full bg-[var(--accent)] px-5 py-2.5 text-sm font-semibold text-[var(--accent-foreground)] transition hover:bg-[var(--accent-2)]"
              >
                Browse verified picks <ArrowRight className="h-4 w-4" />
              </a>
              <Link
                href="/gear"
                className="inline-flex items-center gap-2 rounded-full border border-[var(--border)] px-5 py-2.5 text-sm font-semibold text-[var(--foreground)] transition hover:border-[var(--accent)]/60"
              >
                Full gear catalog
              </Link>
            </div>
          </div>
          <dl className="relative z-10 mt-8 grid gap-3 sm:grid-cols-3">
            {[
              { label: "Verified picks", value: String(USA_MADE_GEAR.length) },
              { label: "Categories covered", value: String(categoryCount) },
              { label: "Total catalog", value: String(GEAR_RECOMMENDATIONS.length) },
            ].map((stat) => (
              <div key={stat.label} className="rounded-2xl border border-white/10 bg-black/20 px-4 py-3">
                <dt className="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--muted)]">
                  {stat.label}
                </dt>
                <dd className="mt-1 font-display text-2xl font-bold text-[var(--foreground)]">{stat.value}</dd>
              </div>
            ))}
          </dl>
        </header>
      </FadeIn>

      <FadeIn delay={0.06}>
        <section aria-labelledby="brands-title" className="card-surface p-5 md:p-6">
          <div className="mb-4">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Trusted makers</p>
            <h2 id="brands-title" className="mt-1 font-display text-2xl font-bold">
              Brands behind these picks
            </h2>
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            {USA_MADE_BRANDS.map((brand) => (
              <div
                key={brand.name}
                className="rounded-xl border border-[var(--border)] bg-black/10 px-4 py-3"
              >
                <p className="font-display text-base font-bold text-[var(--foreground)]">{brand.name}</p>
                <p className="mt-1 text-sm leading-6 text-[var(--muted)]">{brand.note}</p>
              </div>
            ))}
          </div>
        </section>
      </FadeIn>

      <FadeIn delay={0.1}>
        <section
          id="verified-picks"
          aria-labelledby="verified-picks-title"
          className="scroll-mt-24 space-y-5"
        >
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Verified catalog</p>
            <h2 id="verified-picks-title" className="mt-1 font-display text-2xl font-bold md:text-3xl">
              Model-specific American-made tools
            </h2>
            <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--muted)]">
              Hand tools, supplies, and consumables electricians reach for daily. Each card shows the exact model,
              manufacturer source, and field context.
            </p>
          </div>
          <div className="grid gap-4 md:grid-cols-2">
            {USA_MADE_GEAR.map((item) => (
              <GearCard key={item.name} item={item} featured showOrigin />
            ))}
          </div>
        </section>
      </FadeIn>

      <FadeIn delay={0.14}>
        <section
          aria-labelledby="verification-title"
          className="rounded-3xl border border-amber-400/25 bg-amber-400/5 p-5 md:p-6"
        >
          <div className="flex flex-wrap items-start gap-4">
            <span className="rounded-xl bg-amber-400/10 p-3">
              <SearchCheck className="h-5 w-5 text-amber-200" aria-hidden="true" />
            </span>
            <div className="max-w-3xl">
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-amber-200">How we verify</p>
              <h2 id="verification-title" className="mt-1 font-display text-2xl font-bold">
                Conservative sourcing, on purpose
              </h2>
              <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
                &ldquo;Made in America&rdquo; marketing is often misleading. We only add a product when the manufacturer
                identifies U.S. manufacturing for that product line — not just because the brand is American.
              </p>
              <ul className="mt-4 space-y-2 text-sm leading-6 text-[var(--muted)]">
                {[
                  "Check the manufacturer's product page and American manufacturing statement",
                  "Confirm the exact model number — origin can vary within a brand",
                  "Read the country-of-origin label on packaging when the purchase arrives",
                  "Skip items where only \"designed in USA\" or vague assembly claims appear",
                ].map((step) => (
                  <li key={step} className="flex gap-2">
                    <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-amber-200" aria-hidden="true" />
                    <span>{step}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </section>
      </FadeIn>

      <FadeIn delay={0.18}>
        <section aria-labelledby="faq-title" className="card-surface p-5 md:p-6">
          <div className="mb-5">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Common questions</p>
            <h2 id="faq-title" className="mt-1 font-display text-2xl font-bold">
              Made in America FAQ
            </h2>
          </div>
          <div className="space-y-4">
            {MADE_IN_AMERICA_FAQ.map((item) => (
              <details
                key={item.question}
                className="group rounded-2xl border border-[var(--border)] bg-black/10 px-4 py-3 open:border-[var(--accent)]/40"
              >
                <summary className="cursor-pointer list-none font-semibold text-[var(--foreground)] marker:content-none">
                  {item.question}
                </summary>
                <p className="mt-3 text-sm leading-6 text-[var(--muted)]">{item.answer}</p>
              </details>
            ))}
          </div>
        </section>
      </FadeIn>

      <FadeIn delay={0.22}>
        <section
          aria-labelledby="expand-title"
          className="flex flex-col gap-4 rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5 md:flex-row md:items-center md:justify-between md:p-6"
        >
          <div className="max-w-2xl">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Should we expand?</p>
            <h2 id="expand-title" className="mt-1 font-display text-xl font-bold">
              Quality over quantity
            </h2>
            <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
              This list stays small on purpose. A short, verified catalog is more useful than hundreds of unverified
              listings. The full gear page covers test equipment, cable tools, and field power — we only badge items
              here when origin is clear.
            </p>
          </div>
          <Link
            href="/gear"
            className="inline-flex shrink-0 items-center gap-2 rounded-full border border-[var(--accent)]/40 bg-[var(--accent-soft)] px-5 py-2.5 text-sm font-semibold text-[var(--foreground)] transition hover:border-[var(--accent)]"
          >
            <Factory className="h-4 w-4 text-[var(--accent)]" />
            Browse all {GEAR_RECOMMENDATIONS.length} gear picks
          </Link>
        </section>
      </FadeIn>

      <div className="flex gap-3 border-l-2 border-amber-400/70 bg-amber-400/5 px-4 py-3 text-sm leading-6 text-[var(--muted)]">
        <ShieldCheck className="mt-0.5 h-5 w-5 shrink-0 text-amber-300" aria-hidden="true" />
        <p className="m-0">
          Use approved procedures, ratings, and calibration requirements. These recommendations support the work; they
          do not replace them.
        </p>
      </div>
    </section>
  );
}
