/**
 * Native Fullscreen API is useful on desktop and Android Chrome.
 * iPhone Safari (and every iOS browser — all WebKit) either lacks it or
 * "succeeds" with a letterboxed overlay that leaves Safari chrome up and
 * the playfield smaller than the visual viewport. Treat that as failure
 * and use CSS pseudo-fullscreen instead.
 */

export type RectSize = { width: number; height: number };

export function isIosPhone(userAgent: string): boolean {
  return /iPhone|iPod/.test(userAgent);
}

export function shouldAttemptNativeFullscreen(options: {
  userAgent: string;
  fullscreenEnabled: boolean;
}): boolean {
  if (isIosPhone(options.userAgent)) return false;
  return options.fullscreenEnabled;
}

/** True when a "fullscreen" element still leaves large unused viewport. */
export function isLetterboxedRect(rect: RectSize, viewport: RectSize): boolean {
  if (viewport.width <= 0 || viewport.height <= 0) return false;
  const cover = (rect.width * rect.height) / (viewport.width * viewport.height);
  return cover < 0.88 || viewport.width - rect.width > 48 || viewport.height - rect.height > 48;
}

export function activeFullscreenElement(): Element | null {
  const doc = document as Document & { webkitFullscreenElement?: Element | null };
  return document.fullscreenElement || doc.webkitFullscreenElement || null;
}

export function nativeFullscreenEnabled(): boolean {
  const doc = document as Document & { webkitFullscreenEnabled?: boolean };
  return Boolean(document.fullscreenEnabled || doc.webkitFullscreenEnabled);
}

export async function requestNativeFullscreen(element: HTMLElement): Promise<void> {
  const el = element as HTMLElement & {
    webkitRequestFullscreen?: (options?: FullscreenOptions) => Promise<void> | void;
  };
  const req = element.requestFullscreen || el.webkitRequestFullscreen;
  if (!req) throw new Error("Fullscreen API unavailable");
  await req.call(element, { navigationUI: "hide" });
}

export async function exitNativeFullscreen(): Promise<void> {
  if (!activeFullscreenElement()) return;
  const doc = document as Document & { webkitExitFullscreen?: () => Promise<void> | void };
  const exit = document.exitFullscreen || doc.webkitExitFullscreen;
  if (exit) await exit.call(document);
}

export function viewportSize(): RectSize {
  const vv = window.visualViewport;
  return {
    width: vv?.width ?? window.innerWidth,
    height: vv?.height ?? window.innerHeight,
  };
}

export function isLetterboxedElement(element: HTMLElement): boolean {
  const rect = element.getBoundingClientRect();
  return isLetterboxedRect({ width: rect.width, height: rect.height }, viewportSize());
}

const VV_PROPS = ["--game-vv-top", "--game-vv-left", "--game-vv-width", "--game-vv-height"] as const;

export function applyVisualViewportVars(root: HTMLElement, active: boolean): void {
  if (!active) {
    for (const prop of VV_PROPS) root.style.removeProperty(prop);
    return;
  }
  const vv = window.visualViewport;
  root.style.setProperty("--game-vv-top", `${vv?.offsetTop ?? 0}px`);
  root.style.setProperty("--game-vv-left", `${vv?.offsetLeft ?? 0}px`);
  root.style.setProperty("--game-vv-width", `${Math.round(vv?.width ?? window.innerWidth)}px`);
  root.style.setProperty("--game-vv-height", `${Math.round(vv?.height ?? window.innerHeight)}px`);
}

export function ensureViewportFitCover(): void {
  const meta = document.querySelector('meta[name="viewport"]');
  if (!meta) return;
  const content = meta.getAttribute("content") || "";
  if (!content.includes("viewport-fit=cover")) {
    meta.setAttribute("content", `${content.replace(/,?\s*$/, "")}, viewport-fit=cover`);
  }
}

export function waitAnimationFrames(count: number): Promise<void> {
  return new Promise((resolve) => {
    const step = (left: number) => {
      if (left <= 0) resolve();
      else requestAnimationFrame(() => step(left - 1));
    };
    step(count);
  });
}
