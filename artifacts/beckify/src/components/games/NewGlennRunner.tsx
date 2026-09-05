import { useRef } from "react";
import { Maximize2, Minimize2 } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";

const RUNNER_SRC = `${import.meta.env.BASE_URL}arcade/new-glenn-runner/index.html`.replace(/([^:]\/)\/+/g, "$1");

export function NewGlennRunner() {
  const stageRef = useRef<HTMLDivElement>(null);
  const { immersive, toggleFullscreen, exitFullscreen } = useGameFullscreen();

  return (
    <section className="flex min-h-0 flex-1 flex-col gap-2" aria-labelledby="new-glenn-title">
      <div className="flex flex-wrap items-center justify-between gap-2 px-1">
        <div className="min-w-0">
          <p className="text-[0.65rem] font-semibold uppercase tracking-[0.2em] text-[var(--accent)]">Launch arcade</p>
          <h1 id="new-glenn-title" className="font-display text-xl font-bold tracking-tight sm:text-2xl">New Glenn Runner</h1>
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
        className={`game-stage ng-playfield relative mx-auto overflow-hidden bg-[#05050d] shadow-[0_20px_60px_rgba(0,0,0,.35)] ${immersive ? "fixed inset-0 z-[70] is-immersive rounded-none border-0" : "w-full min-w-0 aspect-video max-w-[1280px] rounded-2xl border border-[#b7abff]/40"}`}
      >
        <iframe
          src={RUNNER_SRC}
          title="New Glenn Runner"
          className="absolute inset-0 block h-full w-full border-0 bg-black"
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
    </section>
  );
}

export default NewGlennRunner;
