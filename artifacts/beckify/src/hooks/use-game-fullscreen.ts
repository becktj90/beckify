import { useCallback, useEffect, useState } from "react";
import {
  activeFullscreenElement,
  applyVisualViewportVars,
  ensureViewportFitCover,
  exitNativeFullscreen,
  isLetterboxedElement,
  nativeFullscreenEnabled,
  requestNativeFullscreen,
  shouldAttemptNativeFullscreen,
  waitAnimationFrames,
} from "@/lib/game-fullscreen";

/**
 * Desktop / Android: native Fullscreen API.
 * iPhone (and any native-FS letterbox): CSS pseudo-fullscreen that fills
 * the visual viewport, hides site nav, and only then labels the control EXIT.
 */
export function useGameFullscreen() {
  const [cssImmersive, setCssImmersive] = useState(false);
  const [nativeOn, setNativeOn] = useState(false);
  const immersive = cssImmersive || nativeOn;

  useEffect(() => {
    const sync = () => setNativeOn(Boolean(activeFullscreenElement()));
    sync();
    document.addEventListener("fullscreenchange", sync);
    document.addEventListener("webkitfullscreenchange", sync);
    return () => {
      document.removeEventListener("fullscreenchange", sync);
      document.removeEventListener("webkitfullscreenchange", sync);
    };
  }, []);

  useEffect(() => {
    const root = document.documentElement;
    root.classList.toggle("game-immersive-open", immersive);
    if (immersive) ensureViewportFitCover();
    const syncVv = () => applyVisualViewportVars(root, immersive);
    syncVv();
    const vv = window.visualViewport;
    vv?.addEventListener("resize", syncVv);
    vv?.addEventListener("scroll", syncVv);
    window.addEventListener("resize", syncVv);
    window.addEventListener("orientationchange", syncVv);
    return () => {
      root.classList.remove("game-immersive-open");
      applyVisualViewportVars(root, false);
      vv?.removeEventListener("resize", syncVv);
      vv?.removeEventListener("scroll", syncVv);
      window.removeEventListener("resize", syncVv);
      window.removeEventListener("orientationchange", syncVv);
    };
  }, [immersive]);

  const exitFullscreen = useCallback(async () => {
    try {
      await exitNativeFullscreen();
    } catch {
      /* ignore rejected exit */
    }
    setCssImmersive(false);
  }, []);

  const toggleFullscreen = useCallback(
    async (element: HTMLElement | null) => {
      if (!element) return;

      if (cssImmersive || nativeOn || activeFullscreenElement()) {
        await exitFullscreen();
        return;
      }

      if (
        shouldAttemptNativeFullscreen({
          userAgent: navigator.userAgent,
          fullscreenEnabled: nativeFullscreenEnabled(),
        })
      ) {
        try {
          await requestNativeFullscreen(element);
          await waitAnimationFrames(2);
          if (activeFullscreenElement() && !isLetterboxedElement(element)) {
            return;
          }
          await exitNativeFullscreen();
        } catch {
          // iPad / desktop rejection → CSS fallback.
        }
      }

      setCssImmersive(true);
    },
    [cssImmersive, exitFullscreen, nativeOn],
  );

  return { immersive, cssImmersive, toggleFullscreen, exitFullscreen };
}
