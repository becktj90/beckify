import { useEffect, useState } from "react";

/**
 * The Fullscreen API is not available for arbitrary elements in iOS Safari.
 * When it is unavailable (or rejected), use an app-owned immersive mode so
 * every game still has a reliable full-screen control on phones.
 */
export function useGameFullscreen() {
  const [immersive, setImmersive] = useState(false);

  useEffect(() => {
    const sync = () => setImmersive(Boolean(document.fullscreenElement));
    document.addEventListener("fullscreenchange", sync);
    return () => document.removeEventListener("fullscreenchange", sync);
  }, []);

  const toggleFullscreen = async (element: HTMLElement | null) => {
    if (!element) return;

    if (document.fullscreenElement) {
      await document.exitFullscreen?.();
      return;
    }

    try {
      if (element.requestFullscreen) {
        await element.requestFullscreen();
        return;
      }
    } catch {
      // Safari on iPhone rejects this for non-video elements. Fall through.
    }

    setImmersive((current) => !current);
  };

  const exitFullscreen = async () => {
    if (document.fullscreenElement) await document.exitFullscreen?.();
    setImmersive(false);
  };

  return { immersive, toggleFullscreen, exitFullscreen };
}
