import { Play } from "lucide-react";
import { FadeIn } from "@/components/FadeIn";
import { SectionHeader } from "@/components/SectionHeader";
import { GAMES } from "@/data/site-content";
import { PUBLIC_GAME_COUNT } from "@/data/site-stats";
import { Button } from "@/components/ui/button";
import { BeckifyIcon } from "@/components/ui/icons/BeckifyIcon";
import { KIDS, kidSrc } from "@/components/games/characterArt";

const GAME_DETAILS: Record<string, { mode: string; input: string; accent: string; art?: "apollo" | "rocco" | "both" | "cadet" | "rocket" | "runner" | "planet" }> = {
  "Cosmic Cadet": { mode: "Wave shooter", input: "Drag + BLAST pad", accent: "#35cfff", art: "cadet" },
  "Booty Butt Scooter": { mode: "Crossy hopper", input: "Tap + keyboard", accent: "#ff7a2d", art: "both" },
  "New Glenn Runner": { mode: "Launch arcade", input: "Keyboard + drag", accent: "#8b7bff", art: "rocket" },
  "Finger Runner": { mode: "One-button runner", input: "Tap + Space", accent: "#ff6b8a", art: "runner" },
  "Toot Troopers": { mode: "Fart-flap flight", input: "Tap + Space", accent: "#6df0df", art: "both" },
  "Apollo & Rocco Run": { mode: "Backyard runner", input: "On-canvas pads", accent: "#ff7a2d", art: "both" },
  "Pup Planet": { mode: "First-person WebGL", input: "Touch + WASD", accent: "#6df0df", art: "planet" },
};

function CardArt({ name }: { name: string }) {
  const detail = GAME_DETAILS[name];
  const accent = detail?.accent ?? "var(--accent)";
  const base = import.meta.env.BASE_URL;
  const portraits = detail?.art === "runner" ? (["apollo"] as const) : detail?.art === "both" || detail?.art === "planet" ? (["apollo", "rocco"] as const) : null;
  if (portraits) {
    return (
      <div className="game-card-art" style={{ background: `linear-gradient(135deg, ${accent}33, #12203a)` }}>
        {portraits.map((id) => (
          <img key={id} src={kidSrc(id, base)} alt="" width={72} height={72} />
        ))}
      </div>
    );
  }
  return (
    <div className="game-card-art" style={{ background: `linear-gradient(135deg, ${accent}44, #0b1224)` }} aria-hidden>
      {detail?.art === "cadet" ? <span className="game-card-glyph">✦</span> : null}
      {detail?.art === "rocket" ? <span className="game-card-glyph">▲</span> : null}
    </div>
  );
}

/**
 * Arcade games collection. Display all available games with launch cards.
 */
export const Games = () => (
  <section id="games" className="space-y-8 scroll-mt-24">
    <FadeIn>
      <SectionHeader
        title="Games"
        level="h1"
        subtitle="Original Beckify arcade — readable on a phone, no ads, local scores in this browser."
        icon={(props: { className?: string }) => <BeckifyIcon name="games" {...props} />}
      />
    </FadeIn>

    <FadeIn delay={0.06}>
      <div className="card-surface grid gap-5 p-5 md:grid-cols-[1fr_auto] md:items-center">
        <div>
          <p className="type-label text-[var(--accent)]">The arcade brief</p>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--muted)]">
            Seven on-site games, including Apollo ({KIDS.apollo.prop}) and Rocco ({KIDS.rocco.prop}). Local scores stay in this browser.
          </p>
        </div>
        <div className="grid grid-cols-3 gap-3 text-center" aria-label="Arcade collection summary">
          {[{ label: "Games", value: String(PUBLIC_GAME_COUNT).padStart(2, "0"), width: "100%" }, { label: "Input", value: "3", width: "76%" }, { label: "Ads", value: "0", width: "18%" }].map((stat) => (
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
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {GAMES.map((game, idx) => (
          <div
            key={game.name}
            className="group relative overflow-hidden rounded-2xl border border-[var(--border)] bg-[var(--surface)] hover:border-[var(--accent)]/50 hover:shadow-lg transition-all duration-200"
            style={{ animationDelay: `${idx * 0.1}s` }}
          >
            <CardArt name={game.name} />
            <div className="space-y-4 p-6 pt-4">
              <div className="flex items-start justify-between gap-4">
                <h2 className="text-lg font-semibold text-[var(--foreground)] group-hover:text-[var(--accent)] transition-colors">
                  {game.name}
                </h2>
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

              <Button asChild variant="outline" size="sm" className="w-full" disabled={game.url === "#"}>
                {game.url === "#" ? (
                  <span className="inline-flex items-center gap-2">Coming Soon</span>
                ) : (
                  <a href={game.url} className="inline-flex items-center gap-2">
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
