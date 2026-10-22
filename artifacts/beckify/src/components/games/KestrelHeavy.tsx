import { useCallback, useEffect, useRef, useState } from "react";
import { Maximize2, Minimize2 } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";
import { KESTREL_VIEWPORT_SOURCE, isArcadeViewportMessage, syncEmbeddedArcadeViewport } from "@/lib/game-fullscreen";

const ARCADE_ASSET_VERSION = "unity-15";
const RUNNER_SRC = `${import.meta.env.BASE_URL}arcade/kestrel-heavy/index.html?v=${ARCADE_ASSET_VERSION}`.replace(/([^:]\/)\/+/g, "$1");

export function KestrelHeavy() {
  const stageRef = useRef<HTMLDivElement>(null);
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const { immersive, toggleFullscreen, exitFullscreen, viewportTick } = useGameFullscreen();
  // The Unity runner page draws its own FULL/EXIT button and announces it with a "chrome" message;
  // once it does, the host hides its duplicate and handles the runner's "fullscreen" requests instead.
  const [runnerHasChrome, setRunnerHasChrome] = useState(false);
  const immersiveRef = useRef(immersive);
  immersiveRef.current = immersive;

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
      if (event.source !== iframeRef.current?.contentWindow) return;
      const type = event.data.type;
      if (type === "chrome") {
        setRunnerHasChrome(true);
        pushViewport();
      } else if (type === "request") {
        pushViewport();
      } else if (type === "fullscreen") {
        const want = event.data.enter === true;
        if (want !== immersiveRef.current) {
          if (want) void toggleFullscreen(stageRef.current);
          else void exitFullscreen();
        }
      }
    };
    iframe?.addEventListener("load", pushViewport);
    window.addEventListener("message", onMessage);
    return () => {
      iframe?.removeEventListener("load", pushViewport);
      window.removeEventListener("message", onMessage);
    };
  }, [pushViewport, toggleFullscreen, exitFullscreen]);

  useEffect(() => {
    pushViewport();
  }, [pushViewport, viewportTick]);

  useEffect(() => {
    const sync = () => pushViewport();
    sync();
    const vv = window.visualViewport;
    vv?.addEventListener("resize", sync);
    vv?.addEventListener("scroll", sync);
    window.addEventListener("resize", sync);
    window.addEventListener("orientationchange", sync);
    return () => {
      vv?.removeEventListener("resize", sync);
      vv?.removeEventListener("scroll", sync);
      window.removeEventListener("resize", sync);
      window.removeEventListener("orientationchange", sync);
    };
  }, [pushViewport]);

  return (
    <section className="fixed inset-0 z-[60] h-[100dvh] w-full bg-[#05050d]" aria-labelledby="kestrel-heavy-title">
      <h1 id="kestrel-heavy-title" className="sr-only">Kestrel Heavy</h1>
      <div
        ref={stageRef}
        className={`game-stage relative overflow-hidden bg-[#05050d] ${immersive ? "fixed inset-0 z-[80] is-immersive rounded-none border-0" : "h-full w-full min-w-0"}`}
      >
        <iframe
          ref={iframeRef}
          src={RUNNER_SRC}
          title="Kestrel Heavy"
          className="absolute inset-0 block h-full w-full border-0 bg-black"
          allow="fullscreen; gamepad; autoplay"
          allowFullScreen
          data-viewport-source={KESTREL_VIEWPORT_SOURCE}
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
        {!runnerHasChrome && (
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
        )}
      </div>
    </section>
  );
}

export default KestrelHeavy;
