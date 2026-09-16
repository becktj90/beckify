import { useCallback, useEffect, useRef } from "react";
import { Maximize2, Minimize2 } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";
import { KESTREL_VIEWPORT_SOURCE, isArcadeViewportMessage, syncEmbeddedArcadeViewport } from "@/lib/game-fullscreen";

const ARCADE_ASSET_VERSION = "kestrel-16";
const RUNNER_SRC = `${import.meta.env.BASE_URL}arcade/kestrel-heavy/index.html?v=${ARCADE_ASSET_VERSION}`.replace(/([^:]\/)\/+/g, "$1");

export function KestrelHeavy() {
  const stageRef = useRef<HTMLDivElement>(null);
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const { immersive, toggleFullscreen, exitFullscreen, viewportTick } = useGameFullscreen();

  const pushViewport = useCallback(() => {
    const iframe = iframeRef.current;
    if (!iframe) return;
    syncEmbeddedArcadeViewport(iframe, immersive);
  }, [immersive]);

  useEffect(() => {
    const iframe = iframeRef.current;
    const onMessage = (event: MessageEvent) => {
      if (event.origin !== window.location.origin) return;
      if (!isArcadeViewportMessage(event.data)) return;
      if (event.data.type === "request") pushViewport();
    };
    iframe?.addEventListener("load", pushViewport);
    window.addEventListener("message", onMessage);
    return () => {
      iframe?.removeEventListener("load", pushViewport);
      window.removeEventListener("message", onMessage);
    };
  }, [pushViewport]);

  useEffect(() => {
    pushViewport();
  }, [pushViewport, viewportTick]);

  return (
    <section className="flex min-h-0 flex-1 flex-col" aria-labelledby="kestrel-heavy-title">
      <h1 id="kestrel-heavy-title" className="sr-only">Kestrel Heavy</h1>
      <div
        ref={stageRef}
        className={`game-stage ng-playfield relative mx-auto overflow-hidden bg-[#05050d] shadow-[0_20px_60px_rgba(0,0,0,.35)] ${immersive ? "fixed inset-0 z-[80] is-immersive rounded-none border-0" : "w-full min-w-0 aspect-video max-w-[1280px] rounded-2xl border border-[#b7abff]/40"}`}
      >
        <iframe
          ref={iframeRef}
          src={RUNNER_SRC}
          title="Kestrel Heavy"
          className="absolute inset-0 block h-full w-full border-0 bg-black"
          allow="fullscreen; gamepad; autoplay"
          data-viewport-source={KESTREL_VIEWPORT_SOURCE}
        />
        <button
          type="button"
          className="game-fs-toggle absolute right-3 top-3 z-10 inline-flex min-h-11 items-center rounded-md border border-white/40 bg-[#0a0f24]/90 px-3 text-xs font-bold tracking-wide text-white shadow-lg"
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

export default KestrelHeavy;
