import { useState } from "react";
import { Activity, Play, Maximize2, Volume2, VolumeX, RotateCcw } from "lucide-react";
import "./_group.css";

/**
 * Usability hypothesis: EASE OF INTERACTION & AFFORDANCE VISIBILITY.
 *
 * Every interactive element looks unmistakably interactive before the user
 * has to guess: a big "click to play" overlay replaces a silently-loading
 * iframe, a persistent control bar exposes fullscreen/sound/restart with
 * icon+label pairs, hover/press states are exaggerated, and the whole
 * game frame has a glowing interactive border so it reads as "this is the
 * thing you touch" at a glance.
 *
 * Trade-off made explicit: chrome (buttons, borders, labels) takes up more
 * visual real estate than a minimal treatment would — the goal is that a
 * new visitor never has to hover-and-hope to find out what's clickable.
 */
export function AffordanceFirst() {
  const [started, setStarted] = useState(false);
  const [muted, setMuted] = useState(false);

  return (
    <div className="beckify-scope">
      <div className="max-w-2xl mx-auto px-6 py-12 space-y-6">
        <div className="flex items-center gap-2.5 text-[var(--accent)]">
          <div className="w-9 h-9 rounded-lg bg-[var(--accent-soft)] flex items-center justify-center">
            <Activity className="w-4.5 h-4.5" />
          </div>
          <h1 className="font-display text-2xl font-bold tracking-tight text-[var(--foreground)]">
            Games
          </h1>
        </div>
        <p className="text-base text-[var(--muted)] -mt-3">Finger Runner</p>

        <div className="card-surface p-4">
          <div
            className="relative rounded-[calc(var(--radius-card)-6px)] overflow-hidden border-2 transition-colors"
            style={{
              borderColor: started
                ? "color-mix(in srgb, var(--accent) 55%, var(--border))"
                : "var(--accent)",
              boxShadow: started ? "none" : "0 0 0 4px var(--accent-soft)",
            }}
          >
            {/* Persistent control bar — every action visible up front, icon + label */}
            <div className="flex items-center justify-between px-3 py-2 bg-black/40 border-b border-[var(--border)]">
              <span className="text-xs font-medium text-[var(--muted)]">
                {started ? "Now playing" : "Ready to play"}
              </span>
              <div className="flex items-center gap-1.5">
                <button
                  onClick={() => setMuted((m) => !m)}
                  className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-md text-xs font-medium text-[var(--foreground)] bg-white/5 hover:bg-white/15 active:scale-95 transition-all cursor-pointer"
                >
                  {muted ? <VolumeX className="w-3.5 h-3.5" /> : <Volume2 className="w-3.5 h-3.5" />}
                  {muted ? "Muted" : "Sound"}
                </button>
                <button
                  onClick={() => setStarted(false)}
                  className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-md text-xs font-medium text-[var(--foreground)] bg-white/5 hover:bg-white/15 active:scale-95 transition-all cursor-pointer"
                >
                  <RotateCcw className="w-3.5 h-3.5" />
                  Restart
                </button>
                <button className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-md text-xs font-medium text-[var(--foreground)] bg-white/5 hover:bg-white/15 active:scale-95 transition-all cursor-pointer">
                  <Maximize2 className="w-3.5 h-3.5" />
                  Fullscreen
                </button>
              </div>
            </div>

            {/* Big obvious "click to play" affordance instead of a silent embed */}
            <div className="relative h-[360px] bg-[color-mix(in_srgb,var(--surface)_100%,black_25%)] flex items-center justify-center">
              {!started ? (
                <button
                  onClick={() => setStarted(true)}
                  className="group flex flex-col items-center gap-3 cursor-pointer"
                >
                  <span
                    className="w-20 h-20 rounded-full flex items-center justify-center transition-transform group-hover:scale-110 group-active:scale-95"
                    style={{
                      background: "linear-gradient(135deg, var(--accent) 0%, var(--accent-2) 100%)",
                      boxShadow: "0 0 0 8px var(--accent-soft), 0 8px 30px -6px rgba(139,123,255,0.6)",
                    }}
                  >
                    <Play className="w-8 h-8 text-white ml-1" fill="white" />
                  </span>
                  <span className="text-sm font-semibold text-[var(--foreground)]">
                    Click to play
                  </span>
                  <span className="text-xs text-[var(--muted)]">Space or tap to jump once loaded</span>
                </button>
              ) : (
                <span className="text-sm text-[var(--muted)]">Game embed renders here</span>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
