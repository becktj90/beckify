/**
 * Native Fullscreen API is useful on desktop and Android Chrome.
 * iPhone Safari (and every iOS browser — all WebKit) either lacks it or
 * "succeeds" with a letterboxed overlay that leaves Safari chrome up and
 * the playfield smaller than the visual viewport. Treat that as failure
 * and use CSS pseudo-fullscreen instead.
 *
 * A second iOS trap: expanding the host stage to EXIT still leaves the
 * nested Phaser iframe's layout viewport at the original 16:9 cabinet
 * (innerHeight/dvh stay ~width*9/16). Explicit iframe pixel size + a
 * same-origin viewport postMessage force the cabinet and Scale Manager
 * to the visual viewport.
 */

export type RectSize = { width: number; height: number };

export type ViewportBox = RectSize & { top: number; left: number };

export const KESTREL_VIEWPORT_SOURCE = "beckify-kestrel-viewport";

export type ArcadeViewportMessage = {
  source: typeof KESTREL_VIEWPORT_SOURCE;
  type?: "viewport" | "request";
  immersive: boolean;
  width: number;
  height: number;
};

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

/**
 * If the reported visual height is the 16:9 cabinet letterbox while the
 * layout (or screen) viewport is a tall phone, prefer the taller metric.
 * A genuine visualViewport (~URL-bar-adjusted) on a phone is much taller
 * than width*9/16, so it is left alone.
 */
export function usableViewportHeight(
  visualHeight: number,
  layoutHeight: number,
  width: number,
  screenHeight = 0,
): number {
  const vis = Math.round(Math.max(0, visualHeight));
  const layout = Math.round(Math.max(0, layoutHeight));
  const screen = Math.round(Math.max(0, screenHeight));
  const letterboxH = Math.max(1, width) * (9 / 16);
  let height = vis || layout;
  if (height <= letterboxH + 24 && layout > letterboxH + 48) height = layout;
  if (height <= letterboxH + 24 && screen > letterboxH + 48) height = screen;
  return Math.max(1, Math.round(height));
}

export function visualViewportBox(): ViewportBox {
  const vv = window.visualViewport;
  const layoutW = Math.max(window.innerWidth || 0, document.documentElement?.clientWidth || 0);
  const layoutH = Math.max(window.innerHeight || 0, document.documentElement?.clientHeight || 0);
  const width = Math.round(Math.max(1, vv?.width ?? layoutW));
  const height = usableViewportHeight(
    vv?.height ?? layoutH,
    layoutH,
    width,
    window.screen?.height || 0,
  );
  return {
    top: Math.round(vv?.offsetTop ?? 0),
    left: Math.round(vv?.offsetLeft ?? 0),
    width,
    height,
  };
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
  const box = visualViewportBox();
  return { width: box.width, height: box.height };
}

export function isLetterboxedElement(element: HTMLElement): boolean {
  const rect = element.getBoundingClientRect();
  return isLetterboxedRect({ width: rect.width, height: rect.height }, viewportSize());
}

const VV_PROPS = ["--game-vv-top", "--game-vv-left", "--game-vv-width", "--game-vv-height"] as const;

export function applyVisualViewportVars(root: HTMLElement, active: boolean): ViewportBox | null {
  if (!active) {
    for (const prop of VV_PROPS) root.style.removeProperty(prop);
    return null;
  }
  const box = visualViewportBox();
  root.style.setProperty("--game-vv-top", `${box.top}px`);
  root.style.setProperty("--game-vv-left", `${box.left}px`);
  root.style.setProperty("--game-vv-width", `${box.width}px`);
  root.style.setProperty("--game-vv-height", `${box.height}px`);
  return box;
}

export function isArcadeViewportMessage(data: unknown): data is ArcadeViewportMessage {
  if (!data || typeof data !== "object") return false;
  const msg = data as ArcadeViewportMessage;
  return msg.source === KESTREL_VIEWPORT_SOURCE;
}

/**
 * iOS Safari often keeps an iframe's inner layout viewport at the size the
 * frame had when it first loaded (the 16:9 cabinet). Setting CSS width/height
 * in pixels and posting those numbers in is the reliable resize.
 */
export function syncEmbeddedArcadeViewport(iframe: HTMLIFrameElement, immersive: boolean): void {
  const box = visualViewportBox();
  const host = iframe.parentElement;
  const hostRect = host?.getBoundingClientRect();
  const frameRect = iframe.getBoundingClientRect();
  const width = Math.round(
    immersive ? box.width : (hostRect?.width || frameRect.width || box.width),
  );
  const height = Math.round(
    immersive ? box.height : (hostRect?.height || frameRect.height || box.height),
  );
  // iOS Safari / WKWebView keep the iframe layout viewport at the first
  // 16:9 cabinet size unless width/height are explicit pixels every time.
  iframe.style.width = `${width}px`;
  iframe.style.height = `${height}px`;
  iframe.setAttribute("width", String(width));
  iframe.setAttribute("height", String(height));
  const win = iframe.contentWindow;
  if (!win) return;
  const payload: ArcadeViewportMessage = {
    source: KESTREL_VIEWPORT_SOURCE,
    type: "viewport",
    immersive,
    width,
    height,
  };
  try {
    win.postMessage(payload, window.location.origin);
  } catch {
    /* iframe not same-origin yet */
  }
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
