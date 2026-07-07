import { Link } from "wouter";
import { ArrowUpRight, Orbit, Wrench, Rocket, Gamepad2, Terminal, Zap } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { Starfield } from "@/components/Starfield";
import { Nav } from "@/components/sections/Nav";
import { Footer } from "@/components/sections/Footer";
import { PROFILE } from "@/data/site-content";
import beckifyMark from "@/assets/beckify-mark-white.png";

/**
 * Home — Bento-style hub. Asymmetric multi-column grid on desktop,
 * single-column stack on mobile. Hero tile spans 2 columns / 2 rows;
 * content tiles fill the remaining cells with unique visual character.
 * All tile sizing is pure CSS grid — no JS layout logic.
 */
export default function Home() {
  return (
    <div className="relative min-h-[100dvh]">
      <Starfield />
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

                  <div className="space-y-2">
                    <div className="inline-flex items-center gap-2 text-[10px] font-semibold tracking-[0.22em] uppercase text-[var(--accent)] bg-[var(--accent-soft)] border border-[var(--accent)]/20 px-3 py-1 rounded-full">
                      <Orbit className="w-3 h-3" />
                      Engineering Resource
                    </div>
                    <h1 className="logo-text brand-wordmark text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight leading-[1.05]">
                      <span className="gradient-text">Beckify</span>
                    </h1>
                    <div className="brand-underline" />
                  </div>

                  <p className="text-sm md:text-base text-[var(--muted)] leading-relaxed max-w-sm">
                    Native React calculators. Aerospace engineering. Open-source builds.
                    All in one place, all rigorously verified.
                  </p>
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
                    <p className="text-xs font-semibold text-[var(--foreground)]">{PROFILE.name}</p>
                    <p className="text-[10px] text-[var(--muted)]">{PROFILE.title}</p>
                  </div>
                </div>
              </div>
            </FadeIn>

            {/* ── EE TOOLBOX ──────────────────────────────────────────── */}
            <FadeIn delay={0.08} className="bento-cell">
              <Link href="/toolbox" className="card-surface bento-card group flex flex-col h-full min-h-[200px] relative overflow-hidden">
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
                      <Wrench className="w-4.5 h-4.5 text-[var(--accent)]" />
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
                      24+ native React calculators. Voltage drop, motor FLA, short circuit, power factor, harmonics, and everything NEC-verified.
                    </p>
                  </div>
                </div>
              </Link>
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
                      <Rocket className="w-4.5 h-4.5 text-[var(--accent-2)]" />
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
                      <Gamepad2 className="w-4.5 h-4.5 text-[var(--accent)]" />
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
                      Finger Runner and arcade extras — no install, just play.
                    </p>
                  </div>
                </div>
              </Link>
            </FadeIn>

            {/* ── ABOUT ME ──────────────────────────────────────────────── */}
            <FadeIn delay={0.23} className="bento-cell">
              <Link href="/about" className="card-surface bento-card group flex flex-col h-full min-h-[200px] relative overflow-hidden">
                <div
                  className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-300"
                  style={{
                    background: "radial-gradient(ellipse at 20% 80%, rgba(139,123,255,0.1) 0%, transparent 60%)",
                  }}
                />
                <div className="relative z-10 flex flex-col h-full">
                  <div className="flex items-start justify-between mb-auto">
                    <div
                      className="w-10 h-10 rounded-xl flex items-center justify-center"
                      style={{ background: "rgba(255,255,255,0.06)" }}
                    >
                      <Terminal className="w-4.5 h-4.5 text-[var(--muted)]" />
                    </div>
                    <ArrowUpRight className="w-4 h-4 text-[var(--muted)] group-hover:text-[var(--foreground)] group-hover:-translate-y-0.5 group-hover:translate-x-0.5 transition-all duration-200" />
                  </div>
                  <div className="mt-4 space-y-1.5">
                    <p className="text-[10px] font-semibold tracking-[0.18em] uppercase text-[var(--muted)]">Profile</p>
                    <h2 className="font-display text-lg font-semibold text-[var(--foreground)]">About Me</h2>
                    <p className="text-xs text-[var(--muted)] leading-relaxed">
                      Bio, background, family, and how to get in touch.
                    </p>
                  </div>
                </div>
              </Link>
            </FadeIn>

          </div>

          <Footer />
        </main>
      </div>
    </div>
  );
}
