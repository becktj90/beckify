/** Standalone cabinet fullscreen — same iPhone letterbox rules as the React host. */

export const KESTREL_VIEWPORT_SOURCE = 'beckify-kestrel-viewport';

export function isIosPhone(userAgent = navigator.userAgent) {
  return /iPhone|iPod/.test(userAgent);
}

/** Standalone cabinet or iOS WKWebView — fill the usable visual viewport ourselves. */
export function shouldSelfFillViewport() {
  if (document.body?.classList?.contains('is-ios-app')) return true;
  if (document.body?.classList?.contains('is-embedded')) return false;
  return document.body?.getAttribute('data-arcade-standalone') === 'true';
}

export function nativeFullscreenElement() {
  return document.fullscreenElement || document.webkitFullscreenElement || null;
}

export function shouldAttemptNativeFullscreen(userAgent = navigator.userAgent) {
  if (isIosPhone(userAgent)) return false;
  return Boolean(document.fullscreenEnabled || document.webkitFullscreenEnabled);
}

export function usableViewportHeight(visualHeight, layoutHeight, width, screenHeight = 0) {
  const vis = Math.round(Math.max(0, visualHeight));
  const layout = Math.round(Math.max(0, layoutHeight));
  const screen = Math.round(Math.max(0, screenHeight));
  const letterboxH = Math.max(1, width) * (9 / 16);
  let height = vis || layout;
  if (height <= letterboxH + 24 && layout > letterboxH + 48) height = layout;
  if (height <= letterboxH + 24 && screen > letterboxH + 48) height = screen;
  return Math.max(1, Math.round(height));
}

export function visualViewportBox() {
  const vv = window.visualViewport;
  const layoutW = Math.max(window.innerWidth || 0, document.documentElement.clientWidth || 0);
  const layoutH = Math.max(window.innerHeight || 0, document.documentElement.clientHeight || 0);
  const width = Math.round(Math.max(1, vv?.width ?? layoutW));
  const height = usableViewportHeight(vv?.height ?? layoutH, layoutH, width, window.screen?.height || 0);
  return {
    top: Math.round(vv?.offsetTop ?? 0),
    left: Math.round(vv?.offsetLeft ?? 0),
    width,
    height,
  };
}

export function isLetterboxed(element) {
  const box = visualViewportBox();
  if (box.width <= 0 || box.height <= 0) return false;
  const r = element.getBoundingClientRect();
  const cover = (r.width * r.height) / (box.width * box.height);
  return cover < 0.88 || box.width - r.width > 48 || box.height - r.height > 48;
}

export function syncFullscreenButton(active) {
  const button = document.getElementById('arcade-fullscreen-btn');
  if (!button) return;
  button.textContent = active ? 'EXIT' : 'FULL';
  button.title = active ? 'Exit fullscreen' : 'Play fullscreen';
  button.setAttribute('aria-label', button.title);
  button.setAttribute('aria-pressed', active ? 'true' : 'false');
}

function applyExplicitCabinetSize(width, height) {
  const root = document.documentElement;
  const cabinet = document.querySelector('.cabinet');
  const wrap = document.getElementById('arcade-fs-wrapper');
  const clear = !width || !height;
  const w = clear ? '' : `${Math.round(width)}px`;
  const h = clear ? '' : `${Math.round(height)}px`;
  for (const node of [root, document.body, cabinet, wrap]) {
    if (!node) continue;
    if (clear) {
      node.style.removeProperty('width');
      node.style.removeProperty('height');
      node.style.removeProperty('min-height');
      node.style.removeProperty('max-height');
    } else {
      node.style.width = w;
      node.style.height = h;
      node.style.minHeight = h;
      node.style.maxHeight = 'none';
    }
  }
}

function applyVisualViewportVars(active, box) {
  const root = document.documentElement;
  if (!active) {
    root.style.removeProperty('--game-vv-top');
    root.style.removeProperty('--game-vv-left');
    root.style.removeProperty('--game-vv-width');
    root.style.removeProperty('--game-vv-height');
    applyExplicitCabinetSize(0, 0);
    return;
  }
  const next = box || visualViewportBox();
  root.style.setProperty('--game-vv-top', `${next.top}px`);
  root.style.setProperty('--game-vv-left', `${next.left}px`);
  root.style.setProperty('--game-vv-width', `${next.width}px`);
  root.style.setProperty('--game-vv-height', `${next.height}px`);
  applyExplicitCabinetSize(next.width, next.height);
}

export function applyHostViewportMessage(data) {
  if (!data || data.source !== KESTREL_VIEWPORT_SOURCE) return false;
  if (data.type === 'request') return false;
  const sized = Number(data.width) > 0 && Number(data.height) > 0;
  const immersive = Boolean(data.immersive && sized);
  document.body.classList.toggle('arcade-host-fill', sized);
  if (!sized) {
    applyVisualViewportVars(false);
    return true;
  }
  applyVisualViewportVars(true, {
    top: 0,
    left: 0,
    width: Math.round(data.width),
    height: Math.round(data.height),
  });
  return true;
}

export function requestHostViewport() {
  if (window.parent === window) return;
  try {
    window.parent.postMessage(
      { source: KESTREL_VIEWPORT_SOURCE, type: 'request', immersive: false, width: 0, height: 0 },
      window.location.origin,
    );
  } catch {
    /* ignore */
  }
}

export function setArcadeCssImmersive(wrap, active) {
  wrap.classList.toggle('arcade-immersive', active);
  document.documentElement.classList.toggle('arcade-immersive-open', active);
  applyVisualViewportVars(active);
  syncFullscreenButton(active || Boolean(nativeFullscreenElement()));
}

export async function requestNativeFullscreen(element) {
  const req = element.requestFullscreen || element.webkitRequestFullscreen;
  if (!req) throw new Error('Fullscreen API unavailable');
  return req.call(element, { navigationUI: 'hide' });
}

export async function exitNativeFullscreen() {
  if (!nativeFullscreenElement()) return;
  const exit = document.exitFullscreen || document.webkitExitFullscreen;
  if (exit) await exit.call(document);
}

export function bindFullscreenChrome(wrap, onChange) {
  const syncFill = () => {
    const nativeOn = nativeFullscreenElement() === wrap;
    const cssOn = wrap.classList.contains('arcade-immersive');
    const hostFill = document.body.classList.contains('arcade-host-fill');
    if (cssOn || shouldSelfFillViewport()) applyVisualViewportVars(true);
    else if (!nativeOn && !hostFill) applyVisualViewportVars(false);
    syncFullscreenButton(nativeOn || cssOn);
    onChange?.();
  };
  document.addEventListener('fullscreenchange', syncFill);
  document.addEventListener('webkitfullscreenchange', syncFill);
  const vv = window.visualViewport;
  const syncVv = () => {
    if (wrap.classList.contains('arcade-immersive') || shouldSelfFillViewport()) {
      applyVisualViewportVars(true);
    }
    onChange?.();
  };
  vv?.addEventListener('resize', syncVv);
  vv?.addEventListener('scroll', syncVv);
  window.addEventListener('resize', syncVv);
  window.addEventListener('orientationchange', syncVv);
  window.addEventListener('message', (event) => {
    if (event.origin !== window.location.origin) return;
    if (applyHostViewportMessage(event.data)) {
      requestAnimationFrame(() => requestAnimationFrame(() => onChange?.()));
    }
  });
  requestHostViewport();
  syncFill();
}
