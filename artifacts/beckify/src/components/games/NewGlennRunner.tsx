import { useRef } from "react";
import { Maximize2, Minimize2 } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";

const ARCADE_ASSET_VERSION = "ios-hold-1";
const RUNNER_SRC = `${import.meta.env.BASE_URL}arcade/new-glenn-runner/index.html?v=${ARCADE_ASSET_VERSION}`.replace(/([^:]\/)\/+/g, "$1");

export function NewGlennRunner() {
  const stageRef = useRef<HTMLDivElement>(null);
  const { immersive, toggleFullscreen, exitFullscreen } = useGameFullscreen();

  return (
    <section className="flex min-h-0 flex-1 flex-col" aria-labelledby="new-glenn-title">
      <h1 id="new-glenn-title" className="sr-only">New Glenn Runner</h1>
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
        <button
          type="button"
          className="absolute right-3 top-3 z-10 min-h-11 rounded-md border border-white/40 bg-[#0a0f24]/90 px-3 text-xs font-bold tracking-wide text-white shadow-lg"
          onClick={() => (immersive ? exitFullscreen() : toggleFullscreen(stageRef.current))}
          aria-label={immersive ? "Exit fullscreen" : "Play fullscreen"}
        >
          {immersive ? <Minimize2 size={16} /> : <Maximize2 size={16} />}
          <span className="ml-1.5">{immersive ? "EXIT" : "FULL"}</span>
        </button>
      </div>
    </section>
  );
}

export default NewGlennRunner;
