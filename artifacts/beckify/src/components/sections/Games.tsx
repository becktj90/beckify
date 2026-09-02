import { Play } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { GAMES } from "@/data/site-content";
import { PUBLIC_GAME_COUNT } from "@/data/site-stats";
import { Button } from "@/components/ui/button";
import { BeckifyIcon } from "@/components/ui/icons/BeckifyIcon";

const GAME_DETAILS: Record<string, { mode: string; input: string; accent: string }> = {
  "Cosmic Cadet": { mode: "Wave shooter", input: "Keyboard + touch", accent: "#55e6cb" },
  "Booty Butt Scooter": { mode: "Crossy hopper", input: "Tap + keyboard", accent: "#ffb84a" },
  "New Glenn Runner": { mode: "Launch arcade", input: "Keyboard + drag", accent: "#8b7bff" },
  "Finger Runner": { mode: "One-button runner", input: "Tap + Space", accent: "#ff6b8a" },
  "Toot Troopers": { mode: "Fart-flap flight", input: "Tap + Space", accent: "#6df0df" },
  "Pup Planet": { mode: "First-person WebGL", input: "Touch + WASD", accent: "#6df0df" },
  HexGL: { mode: "WebGL racer", input: "Keyboard + mouse", accent: "#55e6cb" },
};

/**
 * Arcade games collection. Display all available games with launch cards.
 */
export const Games = () => (
  <section id="games" className="space-y-8 scroll-mt-24">
    <FadeIn>
      <SectionHeader
        title="Games"
        level="h1"
        subtitle="Browser games with readable controls — including a first-person voxel world and a full WebGL racer."
        icon={(props: { className?: string }) => <BeckifyIcon name="games" {...props} />}
      />
    </FadeIn>

    <FadeIn delay={0.06}>
      <div className="card-surface grid gap-5 p-5 md:grid-cols-[1fr_auto] md:items-center">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">The arcade brief</p>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--muted)]">Quick arcade loops plus two WebGL worlds. Local scores and saves stay in this browser.</p>
        </div>
        <div className="grid grid-cols-3 gap-3 text-center" aria-label="Arcade collection summary">
          {[{ label: "Games", value: String(PUBLIC_GAME_COUNT).padStart(2, "0"), width: "100%" }, { label: "Input", value: "3", width: "76%" }, { label: "Ads", value: "0", width: "18%" }].map((stat) => <div key={stat.label} className="min-w-20"><p className="font-display text-xl font-bold text-[var(--foreground)]">{stat.value}</p><div className="mt-2 h-1 overflow-hidden rounded-full bg-white/10"><div className="h-full rounded-full bg-[var(--accent)]" style={{ width: stat.width }} /></div><p className="mt-1 text-[10px] uppercase tracking-[0.16em] text-[var(--muted)]">{stat.label}</p></div>)}
        </div>
      </div>
    </FadeIn>

    <FadeIn delay={0.1}>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {GAMES.map((game, idx) => (
          <div
            key={game.name}
            className="group relative p-6 rounded-xl border border-[var(--border)] bg-[var(--surface)] hover:border-[var(--accent)]/50 hover:shadow-lg transition-all duration-200"
            style={{ animationDelay: `${idx * 0.1}s` }}
          >
            <div className="space-y-4">
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1">
                  <h2 className="text-lg font-semibold text-[var(--foreground)] group-hover:text-[var(--accent)] transition-colors">
                    {game.name}
                  </h2>
                </div>
                <BeckifyIcon name="games" className="w-5 h-5 shrink-0" style={{ color: GAME_DETAILS[game.name]?.accent ?? "var(--accent)" }} />
              </div>

              <p className="text-sm text-[var(--muted)] leading-relaxed">
                {game.description}
              </p>

              <div className="flex flex-wrap gap-2 text-[10px] font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">
                <span className="rounded-full border border-[var(--border)] px-2.5 py-1">{GAME_DETAILS[game.name]?.mode ?? "Arcade"}</span>
                <span className="rounded-full border border-[var(--border)] px-2.5 py-1">{GAME_DETAILS[game.name]?.input ?? "Pointer"}</span>
                <span className="rounded-full border border-[var(--border)] px-2.5 py-1">On-site</span>
              </div>

              <Button
                asChild
                variant="outline"
                size="sm"
                className="w-full"
                disabled={game.url === "#"}
              >
                {game.url === "#" ? (
                  <span className="inline-flex items-center gap-2">
                    Coming Soon
                  </span>
                ) : (
                  <a
                    href={game.url}
                    className="inline-flex items-center gap-2"
                  >
                    <span>Play Now</span>
                    <Play className="w-4 h-4" />
                  </a>
                )}
              </Button>
            </div>
          </div>
        ))}
      </div>
    </FadeIn>
  </section>
);
