import { useRef } from "react";
import { Maximize2, Minimize2 } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";

const RUNNER_SRC = `${import.meta.env.BASE_URL}arcade/new-glenn-runner/index.html`.replace(/([^:]\/)\/+/g, "$1");

export function NewGlennRunner() {
  const stageRef = useRef<HTMLDivElement>(null);
  const { immersive, toggleFullscreen, exitFullscreen } = useGameFullscreen();

  return (
    <section className="space-y-6" aria-labelledby="new-glenn-title">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--accent)]">Launch arcade</p>
          <h1 id="new-glenn-title" className="font-display text-3xl font-bold tracking-tight">New Glenn Runner</h1>
          <p className="mt-2 max-w-2xl text-sm text-[var(--muted)]">
            Phaser 4 flights from LC-36: pick an NG-n stack with its own payload, charge liftoff on the Integrated Launch Tower, steer the corridor, then slide first stage onto barge Jacklyn. Keyboard and touch. Difficulty stays on the cabinet — KID, CADET, or PAD RAT.
          </p>
        </div>
        <button
          type="button"
          className="game-icon-button rounded-md border border-[var(--border)] p-2"
          onClick={() => toggleFullscreen(stageRef.current)}
          aria-label={immersive ? "Exit fullscreen" : "Play fullscreen"}
        >
          {immersive ? <Minimize2 size={16} /> : <Maximize2 size={16} />}
        </button>
      </div>

      <div
        ref={stageRef}
        className={`game-stage relative mx-auto overflow-hidden bg-[#05050d] shadow-[0_20px_60px_rgba(0,0,0,.35)] ${immersive ? "fixed inset-0 z-[70] rounded-none border-0" : "w-full min-w-0 aspect-video min-h-[min(360px,56dvh)] max-w-[1280px] rounded-2xl border border-[#b7abff]/40"}`}
      >
        <iframe
          src={RUNNER_SRC}
          title="New Glenn Runner"
          className="block h-full min-h-[min(360px,56dvh)] w-full border-0 bg-black"
          allow="fullscreen; gamepad; autoplay"
        />
        {immersive ? (
          <button
            type="button"
            className="absolute right-4 top-4 z-10 rounded-full border border-white/30 bg-[#0a0f24]/90 p-3 text-white shadow-lg"
            onClick={exitFullscreen}
            aria-label="Exit fullscreen"
          >
            <Minimize2 size={18} />
          </button>
        ) : null}
      </div>

      <div className="mx-auto max-w-[1280px] text-sm leading-6 text-[var(--muted)]">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--accent)]">How to fly</p>
        <ul className="mt-2 list-disc space-y-1 pl-5">
          <li>Keyboard: A/D or arrows steer, Space holds boost (brake on Jacklyn), P or Escape pauses, M mutes.</li>
          <li>Touch: hold CLIMB / BRAKE, tap ◀ ▶, or drag on the canvas. Same-origin iframe — it plays embedded on beckify.com.</li>
          <li>Missions are NG-1 through NG-5, each with a named payload on the fairing and HUD. Finish Jacklyn to unlock the next flight. Soft deck = BOOSTER RECOVERED bonus. Splash costs score, not the whole run. Personal bests stay in this browser.</li>
        </ul>
      </div>
    </section>
  );
}

export default NewGlennRunner;
