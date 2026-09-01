import { Link } from "wouter";
import { ArrowUpRight, Orbit, Wrench, Zap } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { NautilusTrace } from "@/components/NautilusTrace";
import { PenroseCanvas } from "@/components/PenroseCanvas";
import { Starfield } from "@/components/Starfield";
import { BeckifyIcon } from "@/components/ui/icons/BeckifyIcon";
import { Nav } from "@/components/sections/Nav";
import { Footer } from "@/components/sections/Footer";
import { SITE } from "@/data/site-content";
import beckifyMark from "@/assets/beckify-mark-white.png";
import { SchemaHead } from "@/components/seo/SchemaHead";
import { MinimalAdUnit } from "@/components/ads/MinimalAdUnit";

/**
 * Home — Bento-style hub. Asymmetric multi-column grid on desktop,
 * single-column stack on mobile. Hero tile spans 2 columns / 2 rows;
 * content tiles fill the remaining cells with unique visual character.
 * All tile sizing is pure CSS grid — no JS layout logic.
 */
export default function Home() {
  return (
    <div className="relative min-h-[100dvh]">
      <SchemaHead
        title="Beckify | Engineering Tools, References & Builds"
        description="Beckify brings practical electrical engineering calculators, NEC references, field tools, hands-on builds, and browser games together in one fast resource."
        path="/"
      />
      <Starfield showPenrose={false} />
      <div className="relative z-10">
        <Nav />

        <main className="max-w-5xl mx-auto px-4 md:px-6 py-8 md:py-12">
          {/* ── Bento grid ──────────────────────────────────────────────── */}
          <div className="bento-grid">

            {/* ── HERO TILE (col-span-2 / row-span-2) ─────────────────── */}
            <FadeIn className="bento-hero">
              <div className="card-surface bento-card h-full flex flex-col justify-between min-h-[360px] md:min-h-[420px] relative overflow-hidden">
                {/* Subtle accent gradient wash behind content */}
                <div
                  className="absolute inset-0 pointer-events-none"
                  style={{
                    background:
                      "radial-gradient(ellipse at 20% 50%, rgba(139,123,255,0.08) 0%, transparent 65%)",
                  }}
                />
                <PenroseCanvas className="pointer-events-none absolute inset-0 h-full w-full opacity-50 md:opacity-20" />

                <div className="relative z-10 space-y-6">
                  {/* Brand mark */}
                  <div className="brand-mark" style={{ width: "4.5rem", height: "4.5rem" }}>
                    <span className="brand-ring" />
                    <span className="brand-ring" style={{ animationDelay: "1.4s" }} />
                    <span className="brand-ring" style={{ animationDelay: "2.8s" }} />
                    <div className="brand-mark-glow" />
                    <img src={beckifyMark} alt="Beckify" className="brand-mark-img" />
                    <div className="brand-frame">
                      <span className="frame-corner tl" />
                      <span className="frame-corner tr" />
                      <span className="frame-corner bl" />
                      <span className="frame-corner br" />
                    </div>
                  </div>

                  {/* text-center + the wrapper below keep the badge on its own
                      line. The badge is inline-flex and .brand-wordmark is
                      inline-block, so without a block-level parent they share a
                      line instead of stacking, and drift out of alignment with
                      the centred mark, underline and spiral. */}
                  {/* pt-2 clears the reticle frame, which is inset -25% and so
                      overhangs the mark's box. */}
                  <div className="space-y-2 text-center pt-2">
                    <div>
                      <span className="inline-flex items-center gap-2 text-[10px] font-semibold tracking-[0.22em] uppercase text-[var(--accent)] bg-[var(--accent-soft)] border border-[var(--accent)]/20 px-3 py-1 rounded-full">
                        <Orbit className="w-3 h-3" />
                        Engineering Resource
                      </span>
                    </div>
                    <h1 className="logo-text brand-wordmark text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight leading-[1.05]">
                      <span className="gradient-text">Beckify</span>
                    </h1>
                    <div className="brand-underline" />
                  </div>

                  <NautilusTrace className="block mx-auto h-44 w-44 md:h-56 md:w-56" />
                </div>

                {/* Profile chip */}
                <div className="relative z-10 flex items-center gap-3 mt-6">
                  <div
                    className="w-8 h-8 rounded-full flex items-center justify-center shrink-0"
                    style={{
                      background: "linear-gradient(135deg, var(--accent) 0%, var(--accent-2) 100%)",
                    }}
                  >
                    <img src={beckifyMark} alt="" className="w-4 h-4 object-contain" />
                  </div>
                  <div>
                    <p className="text-xs font-semibold text-[var(--foreground)]">{SITE.name}</p>
                    <p className="text-[10px] text-[var(--muted)]">{SITE.tagline}</p>
                  </div>
                </div>
              </div>
            </FadeIn>

            {/* ── EE TOOLBOX ──────────────────────────────────────────── */}
            <FadeIn delay={0.08} className="bento-cell">
              {/* Real navigation — the toolbox is a standalone app, not a React route. */}
              <a href="/toolbox/" className="card-surface bento-card group flex flex-col h-full min-h-[200px] relative overflow-hidden">
                <div
                  className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-300"
                  style={{
                    background: "radial-gradient(ellipse at 80% 20%, rgba(139,123,255,0.12) 0%, transparent 60%)",
                  }}
                />
                <div className="relative z-10 flex flex-col h-full">
                  <div className="flex items-start justify-between mb-auto">
                    <div
                      className="w-10 h-10 rounded-xl flex items-center justify-center"
                      style={{ background: "linear-gradient(135deg, rgba(139,123,255,0.25) 0%, rgba(79,139,255,0.15) 100%)" }}
                    >
                      <BeckifyIcon name="toolbox" className="w-4.5 h-4.5 text-[var(--accent)]" />
                    </div>
                    <ArrowUpRight className="w-4 h-4 text-[var(--muted)] group-hover:text-[var(--accent)] group-hover:-translate-y-0.5 group-hover:translate-x-0.5 transition-all duration-200" />
                  </div>
                  <div className="mt-4 space-y-1.5">
                    <div className="flex items-center gap-2">
                      <span className="w-1.5 h-1.5 rounded-full bg-[var(--accent)]" />
                      <span className="text-[10px] font-semibold tracking-[0.18em] uppercase text-[var(--accent)]">Live Tool</span>
                    </div>
                    <h2 className="font-display text-lg font-semibold text-[var(--foreground)]">EE Toolbox</h2>
                    <p className="text-xs text-[var(--muted)] leading-relaxed">
                      40 calculators and reference tables. Voltage drop, conduit fill, ampacity, transformer sizing, short circuit, harmonics, and TDR fault locating — all NEC-referenced.
                    </p>
                  </div>
                </div>
              </a>
            </FadeIn>

            {/* ── PROJECTS ──────────────────────────────────────────────── */}
            <FadeIn delay={0.13} className="bento-cell">
              <Link href="/projects" className="card-surface bento-card group flex flex-col h-full min-h-[200px] relative overflow-hidden">
                <div
                  className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-300"
                  style={{
                    background: "radial-gradient(ellipse at 80% 20%, rgba(79,139,255,0.12) 0%, transparent 60%)",
                  }}
                />
                <div className="relative z-10 flex flex-col h-full">
                  <div className="flex items-start justify-between mb-auto">
                    <div
                      className="w-10 h-10 rounded-xl flex items-center justify-center"
                      style={{ background: "linear-gradient(135deg, rgba(79,139,255,0.25) 0%, rgba(139,123,255,0.15) 100%)" }}
                    >
                      <BeckifyIcon name="projects" className="w-4.5 h-4.5 text-[var(--accent-2)]" />
                    </div>
                    <ArrowUpRight className="w-4 h-4 text-[var(--muted)] group-hover:text-[var(--accent-2)] group-hover:-translate-y-0.5 group-hover:translate-x-0.5 transition-all duration-200" />
                  </div>
                  <div className="mt-4 space-y-1.5">
                    <div className="flex items-center gap-2">
                      <Zap className="w-3 h-3 text-[var(--accent-2)]" />
                      <span className="text-[10px] font-semibold tracking-[0.18em] uppercase text-[var(--accent-2)]">Builds</span>
                    </div>
                    <h2 className="font-display text-lg font-semibold text-[var(--foreground)]">Projects</h2>
                    <p className="text-xs text-[var(--muted)] leading-relaxed">
                      Vespa EV conversion, Sniffmaster, and other hands-on builds.
                    </p>
                  </div>
                </div>
              </Link>
            </FadeIn>

            {/* ── GAMES ─────────────────────────────────────────────────── */}
            <FadeIn delay={0.18} className="bento-cell">
              <Link href="/games" className="card-surface bento-card group flex flex-col h-full min-h-[200px] relative overflow-hidden">
                <div
                  className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-300"
                  style={{
                    background: "radial-gradient(ellipse at 80% 80%, rgba(139,123,255,0.15) 0%, transparent 60%)",
                  }}
                />
                <div className="relative z-10 flex flex-col h-full">
                  <div className="flex items-start justify-between mb-auto">
                    <div
                      className="w-10 h-10 rounded-xl flex items-center justify-center"
                      style={{ background: "linear-gradient(135deg, rgba(139,123,255,0.2) 0%, rgba(139,123,255,0.08) 100%)" }}
                    >
                      <BeckifyIcon name="games" className="w-4.5 h-4.5 text-[var(--accent)]" />
                    </div>
                    <ArrowUpRight className="w-4 h-4 text-[var(--muted)] group-hover:text-[var(--accent)] group-hover:-translate-y-0.5 group-hover:translate-x-0.5 transition-all duration-200" />
                  </div>
                  <div className="mt-4 space-y-1.5">
                    <div className="flex items-center gap-2">
                      <span className="inline-flex items-center gap-1 text-[10px] font-semibold tracking-[0.18em] uppercase text-green-400">
                        <span className="w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse" />
                        Playable
                      </span>
                    </div>
                    <h2 className="font-display text-lg font-semibold text-[var(--foreground)]">Games</h2>
                    <p className="text-xs text-[var(--muted)] leading-relaxed">
                      Four arcade loops across shooters, runners, and launch simulation — no install, just play.
                    </p>
                  </div>
                </div>
              </Link>
            </FadeIn>

            {/* ── CONTROL SYSTEM TOOLBOX ───────────────────────────────── */}
            <FadeIn delay={0.23} className="bento-cell">
              <Link href="/control-systems" className="card-surface bento-card group flex flex-col h-full min-h-[200px] relative overflow-hidden">
                <div
                  className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-300"
                  style={{
                    background: "radial-gradient(ellipse at 20% 80%, rgba(79,139,255,0.14) 0%, transparent 60%)",
                  }}
                />
                <div className="relative z-10 flex flex-col h-full">
                  <div className="flex items-start justify-between mb-auto">
                    <div
                      className="w-10 h-10 rounded-xl flex items-center justify-center"
                      style={{ background: "linear-gradient(135deg, rgba(79,139,255,0.25) 0%, rgba(139,123,255,0.12) 100%)" }}
                    >
                      <Zap className="w-4.5 h-4.5 text-[var(--accent-2)]" />
                    </div>
                    <ArrowUpRight className="w-4 h-4 text-[var(--muted)] group-hover:text-[var(--accent-2)] group-hover:-translate-y-0.5 group-hover:translate-x-0.5 transition-all duration-200" />
                  </div>
                  <div className="mt-4 space-y-1.5">
                    <p className="text-[10px] font-semibold tracking-[0.18em] uppercase text-[var(--accent-2)]">Interactive design</p>
                    <h2 className="font-display text-lg font-semibold text-[var(--foreground)]">Control System Toolbox</h2>
                    <p className="text-xs text-[var(--muted)] leading-relaxed">
                      Model plants, inspect Bode and root-locus behavior, and compare PID, LQR, and MPC workflows.
                    </p>
                  </div>
                </div>
              </Link>
            </FadeIn>

            {/* ── RECOMMENDED GEAR ─────────────────────────────────────── */}
            <FadeIn delay={0.28} className="bento-cell">
              <div className="card-surface bento-card group flex flex-col h-full min-h-[200px] relative overflow-hidden">
                <div
                  className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-300"
                  style={{
                    background: "radial-gradient(ellipse at 20% 20%, rgba(79,139,255,0.12) 0%, transparent 60%)",
                  }}
                />
                <Link href="/gear" className="relative z-10 flex flex-col flex-1">
                  <div className="flex items-start justify-between mb-auto">
                    <div
                      className="w-10 h-10 rounded-xl flex items-center justify-center"
                      style={{ background: "linear-gradient(135deg, rgba(79,139,255,0.25) 0%, rgba(139,123,255,0.15) 100%)" }}
                    >
                      <Wrench className="w-4.5 h-4.5 text-[var(--accent-2)]" />
                    </div>
                    <ArrowUpRight className="w-4 h-4 text-[var(--muted)] group-hover:text-[var(--accent-2)] group-hover:-translate-y-0.5 group-hover:translate-x-0.5 transition-all duration-200" />
                  </div>
                  <div className="mt-4 space-y-1.5">
                    <p className="text-[10px] font-semibold tracking-[0.18em] uppercase text-[var(--accent-2)]">Field-tested</p>
                    <h2 className="font-display text-lg font-semibold text-[var(--foreground)]">Recommended Gear</h2>
                    <p className="text-xs text-[var(--muted)] leading-relaxed">
                      Model-specific tools, test equipment, and field power picks.
                    </p>
                  </div>
                </Link>
                <Link
                  href="/gear?filter=usa-made"
                  className="relative z-10 mt-4 inline-flex items-center gap-1.5 self-start rounded-full border border-[var(--border)] px-3 py-1.5 text-[11px] font-semibold text-[var(--muted)] transition hover:border-[var(--accent-2)] hover:text-[var(--accent-2)]"
                >
                  <span aria-hidden="true">🇺🇸</span> USA-made picks
                </Link>
              </div>
            </FadeIn>

          </div>

          <MinimalAdUnit type="adsense" placement="toolbox-sidebar" />
          <Footer />
        </main>
      </div>
    </div>
  );
}
