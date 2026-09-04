import { Play } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { GAMES } from "@/data/site-content";
import { PUBLIC_GAME_COUNT } from "@/data/site-stats";
import { Button } from "@/components/ui/button";
import { BeckifyIcon } from "@/components/ui/icons/BeckifyIcon";

const FEATURED = {
  mode: "Launch arcade",
  input: "Keyboard + drag",
  accent: "#8b7bff",
};

/**
 * Public games hub. Beckify ships one playable title: New Glenn Runner.
 */
export const Games = () => {
  const game = GAMES[0];

  return (
    <section id="games" className="space-y-8 scroll-mt-24">
      <FadeIn>
        <SectionHeader
          title="Games"
          level="h1"
          subtitle="One on-site launch arcade — readable on a phone, no ads, local scores in this browser."
          icon={(props: { className?: string }) => <BeckifyIcon name="games" {...props} />}
        />
      </FadeIn>

      <FadeIn delay={0.06}>
        <div className="card-surface grid gap-5 p-5 md:grid-cols-[1fr_auto] md:items-center">
          <div>
            <p className="type-label text-[var(--accent)]">The arcade brief</p>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--muted)]">
              New Glenn Runner is the public game on Beckify. Charge liftoff, steer the corridor, and chase a local best on this device.
            </p>
          </div>
          <div className="grid grid-cols-3 gap-3 text-center" aria-label="Arcade collection summary">
            {[{ label: "Games", value: String(PUBLIC_GAME_COUNT).padStart(2, "0"), width: "100%" }, { label: "Input", value: "2", width: "76%" }, { label: "Ads", value: "0", width: "18%" }].map((stat) => (
              <div key={stat.label} className="min-w-20">
                <p className="font-display text-xl font-bold text-[var(--foreground)]">{stat.value}</p>
                <div className="mt-2 h-1 overflow-hidden rounded-full bg-white/10">
                  <div className="h-full rounded-full bg-[var(--accent)]" style={{ width: stat.width }} />
                </div>
                <p className="mt-1 text-[10px] uppercase tracking-[0.16em] text-[var(--muted)]">{stat.label}</p>
              </div>
            ))}
          </div>
        </div>
      </FadeIn>

      <FadeIn delay={0.1}>
        <div className="mx-auto max-w-xl">
          <div className="group relative overflow-hidden rounded-2xl border border-[var(--border)] bg-[var(--surface)] hover:border-[var(--accent)]/50 hover:shadow-lg transition-all duration-200">
            <div className="game-card-art" style={{ background: `linear-gradient(135deg, ${FEATURED.accent}44, #0b1224)` }} aria-hidden>
              <span className="game-card-glyph">▲</span>
            </div>
            <div className="space-y-4 p-6 pt-4">
              <div className="flex items-start justify-between gap-4">
                <h2 className="text-lg font-semibold text-[var(--foreground)] group-hover:text-[var(--accent)] transition-colors">
                  {game.name}
                </h2>
                <BeckifyIcon name="games" className="w-5 h-5 shrink-0" style={{ color: FEATURED.accent }} />
              </div>

              <p className="text-sm text-[var(--muted)] leading-relaxed">
                {game.description}
              </p>

              <div className="flex flex-wrap gap-2 text-[10px] font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">
                <span className="rounded-full border border-[var(--border)] px-2.5 py-1">{FEATURED.mode}</span>
                <span className="rounded-full border border-[var(--border)] px-2.5 py-1">{FEATURED.input}</span>
                <span className="rounded-full border border-[var(--border)] px-2.5 py-1">On-site</span>
              </div>

              <Button asChild variant="outline" size="sm" className="w-full">
                <a href={game.url} className="inline-flex items-center gap-2">
                  <span>Play Now</span>
                  <Play className="w-4 h-4" />
                </a>
              </Button>
            </div>
          </div>
        </div>
      </FadeIn>
    </section>
  );
};
