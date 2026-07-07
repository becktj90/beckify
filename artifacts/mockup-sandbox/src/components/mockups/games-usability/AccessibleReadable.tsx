import { Activity, Keyboard } from "lucide-react";
import "./_group.css";

/**
 * Usability hypothesis: ACCESSIBILITY & READABILITY.
 *
 * Optimized for people using assistive tech, low vision, or keyboard-only
 * navigation: larger base type size, higher-contrast text on surfaces
 * (foreground instead of muted for anything load-bearing), a visible
 * skip-link, semantic landmarks (header/main/section), explicit
 * `aria-label`s on the game region, large focusable targets with a visible
 * focus ring, and instructions written out in full sentences instead of
 * icon-only shorthand.
 *
 * Trade-off made explicit: the layout is less visually dense and slightly
 * less "designed" than the other variants — text is larger, spacing is
 * looser, and everything that conveys information is legible on its own,
 * without relying on color, icon meaning, or hover state.
 */
export function AccessibleReadable() {
  return (
    <div className="beckify-scope">
      <a
        href="#game-region"
        className="sr-only focus:not-sr-only focus:absolute focus:top-3 focus:left-3 focus:z-50 focus:px-4 focus:py-2 focus:rounded-md focus:bg-[var(--accent)] focus:text-white focus:text-sm focus:font-semibold"
      >
        Skip to game
      </a>

      <div className="max-w-2xl mx-auto px-6 py-12 space-y-8">
        <header>
          <div className="flex items-center gap-3 mb-3">
            <div
              className="w-11 h-11 rounded-xl flex items-center justify-center shrink-0"
              style={{ backgroundColor: "var(--accent)" }}
              aria-hidden="true"
            >
              <Activity className="w-5 h-5 text-white" />
            </div>
            <h1 className="font-display text-3xl font-bold tracking-tight text-[var(--foreground)]">
              Games
            </h1>
          </div>
          <p className="text-lg text-[var(--foreground)] leading-relaxed max-w-xl">
            Play <strong>Finger Runner</strong>, a browser reflex game, directly
            on this page.
          </p>
        </header>

        <main>
          <section
            id="game-region"
            aria-label="Finger Runner game"
            className="card-surface p-5 space-y-4"
          >
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Finger Runner
            </h2>

            <div
              className="flex items-start gap-3 rounded-lg p-4 text-base leading-relaxed"
              style={{ backgroundColor: "var(--accent-soft)", color: "var(--foreground)" }}
            >
              <Keyboard className="w-5 h-5 mt-0.5 shrink-0" aria-hidden="true" />
              <p>
                Press the <kbd className="px-1.5 py-0.5 rounded border border-[var(--border)] bg-black/30 font-mono text-sm">Space</kbd> key,
                or tap the screen on a touch device, to jump over obstacles.
                The game area below can also be reached using the Tab key.
              </p>
            </div>

            <div
              tabIndex={0}
              role="group"
              aria-label="Game display area"
              className="w-full h-[380px] rounded-lg border-2 border-[var(--border)] flex items-center justify-center text-base text-[var(--foreground)] bg-[color-mix(in_srgb,var(--surface)_100%,black_20%)] focus:outline-none focus-visible:ring-4"
              style={{ ["--tw-ring-color" as string]: "var(--accent)" }}
            >
              Game embed renders here
            </div>

            <p className="text-base text-[var(--foreground)]/90">
              Having trouble viewing the game? It works best in an up-to-date
              browser with JavaScript enabled.
            </p>
          </section>
        </main>
      </div>
    </div>
  );
}
