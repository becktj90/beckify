import { useRef } from "react";
import { Maximize2, Minimize2 } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";

const HEXGL_SRC = `${import.meta.env.BASE_URL}vendor/hexgl/index.html`.replace(/([^:]\/)\/+/g, "$1");

export function HexGL() {
  const stageRef = useRef<HTMLDivElement>(null);
  const { immersive, toggleFullscreen, exitFullscreen } = useGameFullscreen();

  return (
    <section className="space-y-6" aria-labelledby="hexgl-title">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--accent)]">WebGL / Futuristic racing</p>
          <h1 id="hexgl-title" className="font-display text-3xl font-bold tracking-tight">HexGL</h1>
          <p className="mt-2 max-w-2xl text-sm text-[var(--muted)]">
            A full WebGL racer by Thibaut Despoulain (BKcore), hosted here under the MIT License. Keyboard to drive, mouse to look, fullscreen for the track.
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
        className={`game-stage relative mx-auto overflow-hidden bg-black shadow-[0_20px_60px_rgba(0,0,0,.35)] ${immersive ? "fixed inset-0 z-[70] rounded-none border-0" : "w-full min-w-0 aspect-[4/3] sm:aspect-video max-w-[1180px] rounded-2xl border border-[#2e5d86]"}`}
      >
        <iframe
          src={HEXGL_SRC}
          title="HexGL by BKcore"
          className="block h-full w-full border-0 bg-black"
          allow="fullscreen; gamepad; pointer-lock; autoplay"
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

      <p className="text-xs text-[var(--muted)]">
        HexGL by Thibaut Despoulain / BKcore. MIT License. Arrow keys or WASD to race. Original source:{" "}
        <a className="underline decoration-[var(--accent)] underline-offset-2" href="https://github.com/BKcore/HexGL" rel="noreferrer">github.com/BKcore/HexGL</a>
        . License text is kept with the game at{" "}
        <a className="underline decoration-[var(--accent)] underline-offset-2" href="/vendor/hexgl/LICENSE">/vendor/hexgl/LICENSE</a>.
      </p>
    </section>
  );
}

export default HexGL;
