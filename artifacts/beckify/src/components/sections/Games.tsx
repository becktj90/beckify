import { Play } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { GAMES } from "@/data/site-content";
import { PUBLIC_GAME_COUNT } from "@/data/site-stats";
import { Button } from "@/components/ui/button";
import { BeckifyIcon } from "@/components/ui/icons/BeckifyIcon";

const FEATURED = {
  mode: "Launch arcade",
  input: "Keyboard + touch",
  accent: "#8b7bff",
};

const ARCADE_FACTS = [
  `${PUBLIC_GAME_COUNT} ${PUBLIC_GAME_COUNT === 1 ? "game" : "games"}`,
  FEATURED.input,
  "No ads",
] as const;

/**
 * Public games hub. Beckify ships one playable title: Kestrel Heavy.
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
        <div className="card-surface space-y-4 p-5">
          <div>
            <p className="type-label text-[var(--accent)]">The arcade brief</p>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--muted)]">
              Kestrel Heavy is the public game on Beckify. Charge liftoff at Pier 7, steer the corridor, then land the booster on Haven. Chase a local best on this device.
            </p>
          </div>
          <ul className="flex flex-wrap gap-2" aria-label="Arcade at a glance">
            {ARCADE_FACTS.map((fact) => (
              <li
                key={fact}
                className="rounded-full border border-[var(--border)] bg-black/20 px-3 py-1.5 text-sm text-[var(--foreground)]"
              >
                {fact}
              </li>
            ))}
          </ul>
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
