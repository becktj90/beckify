import { Play } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { GAMES } from "@/data/site-content";
import { PUBLIC_GAME_COUNT } from "@/data/site-stats";
import { Button } from "@/components/ui/button";
import { BeckifyIcon } from "@/components/ui/icons/BeckifyIcon";

interface GameMeta {
  mode: string;
  input: string;
  accent: string;
  glyph: string;
}

const GAME_META: Record<string, GameMeta> = {
  "/games/kestrel-heavy": {
    mode: "Launch arcade",
    input: "Keyboard + touch",
    accent: "#40bad6",
    glyph: "▲",
  },
  "/games/number-blocks": {
    mode: "Kids' math game",
    input: "Touch + voices",
    accent: "#f59e0b",
    glyph: "123",
  },
};

const DEFAULT_META: GameMeta = {
  mode: "On-site game",
  input: "Touch",
  accent: "#40bad6",
  glyph: "▶",
};

const GAME_FACTS = [
  `${PUBLIC_GAME_COUNT} ${PUBLIC_GAME_COUNT === 1 ? "game" : "games"}`,
  "No ads",
  "No install",
] as const;

/**
 * Public games hub. Beckify's on-site games: Kestrel Heavy and Cube Squad.
 */
export const Games = () => {
  return (
    <section id="games" className="space-y-8 scroll-mt-24">
      <FadeIn>
        <SectionHeader
          title="Games"
          level="h1"
          subtitle="On-site games — a launch arcade and a kids' math game, no ads, no install."
          icon={(props: { className?: string }) => <BeckifyIcon name="games" {...props} />}
        />
      </FadeIn>

      <FadeIn delay={0.06}>
        <div className="card-surface space-y-4 p-5">
          <div>
            <p className="type-label text-[var(--accent)]">The games brief</p>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--muted)]">
              Beckify's on-site games: Kestrel Heavy, the Pier 7 launch arcade, and Cube Squad, a talking cube math game for kids. Play in the browser — no install, no ads.
            </p>
          </div>
          <ul className="flex flex-wrap gap-2" aria-label="Games at a glance">
            {GAME_FACTS.map((fact) => (
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
        <div className="grid gap-6 md:grid-cols-2">
          {GAMES.map((game) => {
            const meta = GAME_META[game.url] ?? DEFAULT_META;
            return (
              <div key={game.url} className="group relative overflow-hidden rounded-2xl border border-[var(--border)] bg-[var(--surface)] hover:border-[var(--accent)]/50 hover:shadow-lg transition-all duration-200">
                <div className="game-card-art" style={{ background: `linear-gradient(135deg, ${meta.accent}44, #0b1224)` }} aria-hidden>
                  <span className="game-card-glyph">{meta.glyph}</span>
                </div>
                <div className="space-y-4 p-6 pt-4">
                  <div className="flex items-start justify-between gap-4">
                    <h2 className="text-lg font-semibold text-[var(--foreground)] group-hover:text-[var(--accent)] transition-colors">
                      {game.name}
                    </h2>
                    <BeckifyIcon name="games" className="w-5 h-5 shrink-0" style={{ color: meta.accent }} />
                  </div>

                  <p className="text-sm text-[var(--muted)] leading-relaxed">
                    {game.description}
                  </p>

                  <div className="flex flex-wrap gap-2 text-[10px] font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">
                    <span className="rounded-full border border-[var(--border)] px-2.5 py-1">{meta.mode}</span>
                    <span className="rounded-full border border-[var(--border)] px-2.5 py-1">{meta.input}</span>
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
            );
          })}
        </div>
      </FadeIn>
    </section>
  );
};
