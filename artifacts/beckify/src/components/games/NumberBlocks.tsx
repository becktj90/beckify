import { useRef } from "react";
import { Maximize2, Minimize2 } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";

const GAME_SRC = `${import.meta.env.BASE_URL}games/number-blocks/game.html`.replace(/([^:]\/)\/+/g, "$1");

export function NumberBlocks() {
  const stageRef = useRef<HTMLDivElement>(null);
  const { immersive, toggleFullscreen, exitFullscreen } = useGameFullscreen();

  return (
    <section className="fixed inset-0 z-[60] h-[100dvh] w-full bg-[#05050d]" aria-labelledby="number-blocks-title">
      <h1 id="number-blocks-title" className="sr-only">Number Blocks</h1>
      <div
        ref={stageRef}
        className={`game-stage relative overflow-hidden bg-[#05050d] ${immersive ? "fixed inset-0 z-[80] is-immersive rounded-none border-0" : "h-full w-full min-w-0"}`}
      >
        <iframe
          src={GAME_SRC}
          title="Number Blocks"
          className="absolute inset-0 block h-full w-full border-0 bg-black"
          allow="fullscreen; autoplay"
          allowFullScreen
        />
        {!immersive && (
          <a
            href={`${import.meta.env.BASE_URL}games`}
            className="kh-back-link absolute bottom-[max(0.25rem,env(safe-area-inset-bottom))] left-2 z-10 inline-flex h-9 items-center rounded-md border border-white/30 bg-[#0a0f24]/70 px-2.5 text-xs font-bold tracking-wide text-white/80 backdrop-blur"
            aria-label="Back to Beckify games"
          >
            &larr; BECKIFY
          </a>
        )}
        <button
          type="button"
          className="game-fs-toggle absolute right-2 top-[max(0.5rem,env(safe-area-inset-top))] z-10 inline-flex min-h-11 items-center rounded-md border border-white/40 bg-[#0a0f24]/90 px-3 text-xs font-bold tracking-wide text-white shadow-lg"
          onClick={() => (immersive ? exitFullscreen() : toggleFullscreen(stageRef.current))}
          aria-label={immersive ? "Exit fullscreen" : "Play fullscreen"}
          aria-pressed={immersive}
        >
          {immersive ? <Minimize2 size={16} /> : <Maximize2 size={16} />}
          <span className="ml-1.5">{immersive ? "EXIT" : "FULL"}</span>
        </button>
      </div>
    </section>
  );
}

export default NumberBlocks;
