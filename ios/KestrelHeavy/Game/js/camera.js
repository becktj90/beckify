/**
 * Playfield / camera helpers — keep the live stack on-screen after ENVELOP crop.
 * Portrait phones and every tablet crop the 1280×720 world to a strip; zoom
 * and follow must compensate so the corridor and Haven vehicle stay in that strip.
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
 * Peek toward Haven on every playfield, including the portrait strip.
 * Far glide still locks mostly on the booster; close approach shares the frame.
 */
export function havenPeekAmount(range, viewW) {
  const dist = Math.max(0, Number(range) || 0);
  const span = Math.max(160, Number(viewW) || 1);
  if (dist < 36) return 0.04;
  if (dist > span * 2.1) return 0.28;
  if (dist > span * 0.85) return 0.4;
  return 0.48;
}

/**
 * Camera look point: keep the booster framed, walk Haven's paint into view
 * when the cropped strip can hold both.
 */
export function havenLookPoint(rocketX, rocketY, bargeX, bargeY, viewW, viewH, peek) {
  const dx = bargeX - rocketX;
  const dy = bargeY - rocketY;
  const range = Math.hypot(dx, dy);
  const amount = peek == null ? havenPeekAmount(range, viewW) : peek;
  const maxX = Math.max(24, viewW * 0.36);
  const maxY = Math.max(24, viewH * 0.3);
  const peekX = clamp(dx * amount, -maxX, maxX);
  const peekY = clamp(dy * (amount * 0.62), -maxY, maxY);
  const cx = rocketX + peekX;
  const cy = rocketY + peekY;
  if (!vehicleInView(rocketX, rocketY, cx, cy, viewW, viewH, 88)) {
    const safeX = clamp(dx * 0.16, -viewW * 0.2, viewW * 0.2);
    const safeY = clamp(dy * 0.12, -viewH * 0.16, viewH * 0.16);
    return { cx: rocketX + safeX, cy: rocketY + safeY };
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

/** True when the live stage-1 is outside the ENVELOP-cropped frame. */
export function shouldSnapVehicle(rx, ry, cx, cy, viewW, viewH, pad = 80) {
  return !vehicleInView(rx, ry, cx, cy, viewW, viewH, pad);
}

/**
 * Approach stays wide so the paint can enter the strip. Burn only tightens
 * when the deck is already close — never crop Haven out of a portrait phone.
 */
export function havenZoomWant({
  alt = 900,
  pulling = false,
  reduced = false,
  parentW = W,
  parentH = H,
  dx = 0,
} = {}) {
  if (reduced) return CAM.reduced;
  const portrait = isPortraitPlayfield(parentW, parentH);
  const far = portrait ? HAVEN.zoomFarPortrait : HAVEN.zoomFar;
  const near = portrait ? HAVEN.zoomNearPortrait : HAVEN.zoomNear;
  const floor = portrait ? HAVEN.zoomFloorPortrait : HAVEN.zoomFloor;
  const vis1 = envelopVisibleWorld(parentW, parentH, W, H, 1);
  const spanX = Math.abs(Number(dx) || 0) + 240;
  const spanY = Math.max(260, Math.abs(Number(alt) || 0) + 200);
  const fit = Math.min(vis1.w / Math.max(spanX, 1), vis1.h / Math.max(spanY, 1));
  const t = pulling
    ? clamp(1 - Math.abs(alt) / 420, 0, 1)
    : clamp(1 - Math.abs(alt) / 1700, 0, 0.28);
  const want = far + (near - far) * t * t;
  return clamp(Math.min(want, Math.max(fit, floor)), floor, near);
}

export function expandedHavenBounds() {
  return {
    x: CAM.havenBoundsX,
    y: CAM.worldTop,
    width: CAM.havenBoundsW,
    height: CAM.worldHeight,
  };
}

/** Screen-edge cue when Haven's paint is outside the cropped world view. */
export function havenEdgeCue(rocketX, rocketY, bargeX, bargeY, cx, cy, viewW, viewH, pad = 72) {
  const inView = vehicleInView(bargeX, bargeY, cx, cy, viewW, viewH, pad);
  const hw = Math.max(1, viewW) / 2 - pad;
  const hh = Math.max(1, viewH) / 2 - pad;
  const x = clamp(bargeX, cx - hw, cx + hw);
  const y = clamp(bargeY, cy - hh, cy + hh);
  const ang = Math.atan2(bargeY - rocketY, bargeX - rocketX);
  return {
    inView,
    x,
    y,
    ang,
    dx: bargeX - rocketX,
    dy: bargeY - rocketY,
  };
}

/** Device sizes Trevor actually flies — iPhone + every iPad class. */
export const FILL_PLAYFIELDS = [
  { name: 'iphone-portrait', w: 390, h: 844 },
  { name: 'iphone-landscape', w: 844, h: 390 },
  { name: 'ipad-mini-portrait', w: 768, h: 1024 },
  { name: 'ipad-mini-landscape', w: 1024, h: 768 },
  { name: 'ipad-air-portrait', w: 820, h: 1180 },
  { name: 'ipad-air-landscape', w: 1180, h: 820 },
  { name: 'ipad-pro-portrait', w: 1024, h: 1366 },
  { name: 'ipad-pro-landscape', w: 1366, h: 1024 },
];
