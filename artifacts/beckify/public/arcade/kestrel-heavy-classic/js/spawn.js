/**
 * Hazard / pickup spawn math. Hazards must enter from off-screen *above*
 * the camera, never pop in already inside the playable corridor.
 *
 * Phaser Y grows downward. Camera follow offset (lookAheadY) sits the
 * camera *below* the stack so more corridor is on-screen above the rocket.
 */
import { CAM, H } from './config.js';

export const SPAWN = {
  /** Pixels above cameras.main.worldView.top (smaller Y). */
  leadMin: 200,
  leadMax: 380,
  /** Ahead of the stack, still inside the camera — not a pinprick at sky-top. */
  pickupAheadMin: 110,
  pickupAheadMax: 220,
};

/**
 * World Y of the top edge of the camera.
 * @param {number} rocketY
 * @param {number} zoom
 * @param {number} [lookAheadY]
 * @param {number} [viewH]
 */
export function cameraTopY(rocketY, zoom, lookAheadY = CAM.lookAheadY, viewH = H) {
  const z = Math.max(0.2, Number(zoom) || 1);
  const camCenterY = Number(rocketY) + Number(lookAheadY || 0);
  return camCenterY - (viewH * 0.5) / z;
}

/**
 * World Y for a sprite that starts fully above the camera.
 * @param {number} camTop  worldView.top
 * @param {number} [leadMin]
 * @param {number} [leadMax]
 * @param {() => number} [random]
 */
export function spawnYAboveCamera(
  camTop,
  leadMin = SPAWN.leadMin,
  leadMax = SPAWN.leadMax,
  random = Math.random,
) {
  const span = Math.max(0, leadMax - leadMin);
  const lead = leadMin + random() * span;
  return Number(camTop) - lead;
}

export function spawnIsAheadOfCamera(spawnY, camTop) {
  return Number(spawnY) < Number(camTop);
}

/**
 * Pickup Y in the readable corridor: above the stack, below the camera top.
 */
export function spawnYInView(
  rocketY,
  camTop,
  minAhead = SPAWN.pickupAheadMin,
  maxAhead = SPAWN.pickupAheadMax,
  random = Math.random,
) {
  const ahead = minAhead + random() * Math.max(0, maxAhead - minAhead);
  const want = Number(rocketY) - ahead;
  const floor = Number(camTop) + 48;
  return Math.max(want, floor);
}

/** Resolve cam top from a live Phaser camera, falling back to the formula. */
export function liveCameraTop(cam, rocketY, lookAheadY = CAM.lookAheadY) {
  const view = cam?.worldView;
  if (view && Number.isFinite(view.top)) return view.top;
  return cameraTopY(rocketY, cam?.zoom || 1, lookAheadY);
}
