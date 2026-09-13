/** Standalone cabinet fullscreen — same iPhone letterbox rules as the React host. */

export function isIosPhone(userAgent = navigator.userAgent) {
  return /iPhone|iPod/.test(userAgent);
}

export function nativeFullscreenElement() {
  return document.fullscreenElement || document.webkitFullscreenElement || null;
}

export function shouldAttemptNativeFullscreen(userAgent = navigator.userAgent) {
  if (isIosPhone(userAgent)) return false;
  return Boolean(document.fullscreenEnabled || document.webkitFullscreenEnabled);
}

export function isLetterboxed(element) {
  const vv = window.visualViewport;
  const vw = vv?.width ?? window.innerWidth;
  const vh = vv?.height ?? window.innerHeight;
  if (vw <= 0 || vh <= 0) return false;
  const r = element.getBoundingClientRect();
  const cover = (r.width * r.height) / (vw * vh);
  return cover < 0.88 || vw - r.width > 48 || vh - r.height > 48;
}

export function syncFullscreenButton(active) {
  const button = document.getElementById('arcade-fullscreen-btn');
  if (!button) return;
  button.textContent = active ? 'EXIT' : 'FULL';
  button.title = active ? 'Exit fullscreen' : 'Play fullscreen';
  button.setAttribute('aria-label', button.title);
  button.setAttribute('aria-pressed', active ? 'true' : 'false');
}

function applyVisualViewportVars(active) {
  const root = document.documentElement;
  if (!active) {
    root.style.removeProperty('--game-vv-top');
    root.style.removeProperty('--game-vv-left');
    root.style.removeProperty('--game-vv-width');
    root.style.removeProperty('--game-vv-height');
    return;
  }
  const vv = window.visualViewport;
  root.style.setProperty('--game-vv-top', `${vv?.offsetTop ?? 0}px`);
  root.style.setProperty('--game-vv-left', `${vv?.offsetLeft ?? 0}px`);
  root.style.setProperty('--game-vv-width', `${Math.round(vv?.width ?? window.innerWidth)}px`);
  root.style.setProperty('--game-vv-height', `${Math.round(vv?.height ?? window.innerHeight)}px`);
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
  const sync = () => {
    const nativeOn = nativeFullscreenElement() === wrap;
    const cssOn = wrap.classList.contains('arcade-immersive');
    if (!nativeOn && !cssOn) applyVisualViewportVars(false);
    syncFullscreenButton(nativeOn || cssOn);
    onChange?.();
  };
  document.addEventListener('fullscreenchange', sync);
  document.addEventListener('webkitfullscreenchange', sync);
  const vv = window.visualViewport;
  const syncVv = () => {
    if (wrap.classList.contains('arcade-immersive')) applyVisualViewportVars(true);
  };
  vv?.addEventListener('resize', syncVv);
  vv?.addEventListener('scroll', syncVv);
  window.addEventListener('resize', syncVv);
  syncFullscreenButton(false);
}
