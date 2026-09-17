/**
 * Playfield / camera helpers — keep the live stack on-screen after ENVELOP crop.
 * Portrait phones crop the 1280×720 world to a vertical strip; zoom and follow
 * must compensate so the corridor and Haven vehicle stay in that strip.
 */
import { CAM, HAVEN, H, W } from './config.js';
import { CORRIDOR } from './corridor.js';

export function clamp(n, a, b) {
  return Math.max(a, Math.min(b, n));
}

/** Visible world size after Phaser.Scale.ENVELOP crop at a given zoom. */
export function envelopVisibleWorld(parentW, parentH, gameW = W, gameH = H, zoom = 1) {
  const pw = Math.max(1, Number(parentW) || 1);
  const ph = Math.max(1, Number(parentH) || 1);
  const gw = Math.max(1, Number(gameW) || W);
  const gh = Math.max(1, Number(gameH) || H);
  const z = Math.max(0.05, Number(zoom) || 1);
  const scale = Math.max(pw / gw, ph / gh);
  return {
    w: (pw / scale) / z,
    h: (ph / scale) / z,
  };
}

export function isPortraitPlayfield(parentW, parentH) {
  return Number(parentH) > Number(parentW) * 1.05;
}

export function corridorNeedWidth() {
  return (CORRIDOR.padRight - CORRIDOR.padLeft) + 140;
}

/** Pad / climb zoom that keeps the dotted rails inside the cropped viewport. */
export function padZoomForPlayfield(parentW, parentH, reduced = false) {
  if (reduced) return CAM.reduced;
  const vis = envelopVisibleWorld(parentW, parentH, W, H, 1);
  const need = corridorNeedWidth();
  if (vis.w >= need) return CAM.pad;
  return clamp(vis.w / need, CAM.portraitMin, CAM.pad);
}

export function ascentZoomForPlayfield(parentW, parentH, altitudeKm, reduced = false) {
  if (reduced) return CAM.reduced;
  const start = padZoomForPlayfield(parentW, parentH, false);
  const high = Math.min(CAM.ascentHigh, start);
  return clamp(start - (Number(altitudeKm) || 0) * 0.0014, high, start);
}

export function vehicleInView(rx, ry, cx, cy, viewW, viewH, pad = 48) {
  const hw = Math.max(1, viewW) / 2;
  const hh = Math.max(1, viewH) / 2;
  return (
    rx >= cx - hw + pad
    && rx <= cx + hw - pad
    && ry >= cy - hh + pad
    && ry <= cy + hh - pad
  );
}

/**
 * Camera look point: lock on the booster, peek toward Haven only if the
 * vehicle stays inside the cropped frame. Same class of fix as sep follow.
 */
export function havenLookPoint(rocketX, rocketY, bargeX, bargeY, viewW, viewH, peek = 0.16) {
  const maxX = Math.max(24, viewW * 0.2);
  const maxY = Math.max(24, viewH * 0.16);
  const peekX = clamp((bargeX - rocketX) * peek, -maxX, maxX);
  const peekY = clamp((bargeY - rocketY) * (peek * 0.75), -maxY, maxY);
  const cx = rocketX + peekX;
  const cy = rocketY + peekY;
  if (!vehicleInView(rocketX, rocketY, cx, cy, viewW, viewH, 64)) {
    return { cx: rocketX, cy: rocketY };
  }
  return { cx, cy };
}

export function havenFollowOffset(rocketX, rocketY, bargeX, bargeY, viewW, viewH) {
  const look = havenLookPoint(rocketX, rocketY, bargeX, bargeY, viewW, viewH);
  return {
    x: rocketX - look.cx,
    y: rocketY - look.cy,
  };
}

export function havenZoomWant({
  alt = 900,
  pulling = false,
  reduced = false,
  parentW = W,
  parentH = H,
} = {}) {
  if (reduced) return CAM.reduced;
  const portrait = isPortraitPlayfield(parentW, parentH);
  const far = portrait ? HAVEN.zoomFarPortrait : HAVEN.zoomFar;
  const near = portrait ? HAVEN.zoomNearPortrait : HAVEN.zoomNear;
  const t = pulling ? clamp(1 - alt / 900, 0, 1) : 0;
  return far + (near - far) * t * t;
}

export function expandedHavenBounds() {
  return {
    x: CAM.havenBoundsX,
    y: CAM.worldTop,
    width: CAM.havenBoundsW,
    height: CAM.worldHeight,
  };
}
