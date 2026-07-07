import { Activity, Gamepad2, Info } from "lucide-react";
import "./_group.css";

/**
 * Usability hypothesis: CLARITY OF INFORMATION HIERARCHY.
 *
 * The page is restructured into clear, ordered tiers so a visitor always
 * knows "where am I / what is this / what do I do":
 *   1. Page context (breadcrumb-style eyebrow)
 *   2. Primary title (largest, boldest element on the page)
 *   3. What this game is (one-line description, not just a name)
 *   4. Meta strip (status + controls) — visually secondary, grouped together
 *   5. The game itself, framed as the clear focal point
 *
 * Trade-off made explicit: extra vertical space is spent on structure and
 * labeling rather than maximizing game size — the goal is that a first-time
 * visitor never has to guess what they're looking at.
 */
export function InformationHierarchy() {
  return (
    <div className="beckify-scope">
      <div className="max-w-2xl mx-auto px-6 py-12 space-y-6">
        {/* Tier 1 — page context */}
        <div className="text-xs font-medium tracking-[0.18em] uppercase text-[var(--muted)]">
          Beckify / Games
        </div>

        {/* Tier 2 — primary title, unmistakably the biggest thing on screen */}
        <div className="flex items-center gap-3">
          <div className="w-11 h-11 rounded-xl bg-[var(--accent-soft)] flex items-center justify-center shrink-0">
            <Activity className="w-5 h-5 text-[var(--accent)]" />
          </div>
          <h1 className="font-display text-4xl font-bold tracking-tight text-[var(--foreground)]">
            Games
          </h1>
        </div>

        {/* Tier 3 — what this specific thing is, in plain language */}
        <div className="pl-1">
          <div className="flex items-center gap-2 text-lg font-semibold text-[var(--foreground)]">
            <Gamepad2 className="w-4.5 h-4.5 text-[var(--accent)]" />
            Finger Runner
          </div>
          <p className="text-sm text-[var(--muted)] mt-1 max-w-md leading-relaxed">
            A quick browser reflex game — dodge obstacles and beat your best
            distance. No install, just play.
          </p>
        </div>

        {/* Tier 4 — secondary meta, visually demoted (smaller, muted, grouped) */}
        <div className="flex items-center gap-4 text-xs text-[var(--muted)] pl-1 pb-1 border-b border-[var(--border)]">
          <span className="inline-flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-green-400" />
            Live
          </span>
          <span>·</span>
          <span>Runs in this window</span>
          <span>·</span>
          <span className="inline-flex items-center gap-1">
            <Info className="w-3 h-3" />
            Tap / space to jump
          </span>
        </div>

        {/* Tier 5 — the game, the clear focal point after everything above it */}
        <div className="card-surface p-4">
          <div className="card-surface overflow-hidden">
            <div className="w-full h-[380px] flex items-center justify-center bg-[color-mix(in_srgb,var(--surface)_100%,black_20%)] text-[var(--muted)] text-sm">
              Game embed renders here
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
