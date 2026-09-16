/**
 * Honest overlap. Hazard sprites sit on a 48×48 canvas with a glow halo;
 * Matter's default rectangle used the whole frame, so near-misses INT-hit.
 * Bodies match the solid art plus a tiny graze pad — never a fat invisible pad.
 */

export const HAZARD_CANVAS = 48;

/** Solid visual radius at scale 1 (px), ignoring canvas padding / halo. */
export const HAZARD_RADIUS = {
  bird: 8,
  balloon: 10,
  ice: 10,
  debris: 9,
  clutter: 9,
};

/** Extra px beyond the solid art so a true edge clip still counts. */
export const GRAZE_PAD = 1.6;

/**
 * Unscaled Matter rectangle for the stack. Canvas is 92×268 (booster 124×268)
 * with empty padding; the painted cylinder is ~40px wide.
 */
export const ROCKET_HIT = { width: 42, height: 228 };
export const BOOSTER_HIT = { width: 38, height: 198 };

export function hazardRadius(kind) {
  return (HAZARD_RADIUS[kind] || HAZARD_RADIUS.debris) + GRAZE_PAD;
}

export function rocketHitSize(booster) {
  return booster ? BOOSTER_HIT : ROCKET_HIT;
}

/**
 * Circle vs axis-aligned box (centers). Used to reject fat default bodies.
 */
export function circleHitsAabb(cx, cy, radius, ax, ay, halfW, halfH) {
  const dx = Math.abs(Number(cx) - Number(ax));
  const dy = Math.abs(Number(cy) - Number(ay));
  const nx = Math.max(0, dx - halfW);
  const ny = Math.max(0, dy - halfH);
  return nx * nx + ny * ny <= radius * radius;
}

export function contactsHazard(rocket, hazard, kind, booster = false) {
  if (!rocket || !hazard) return false;
  const box = rocketHitSize(booster);
  const scale = Number(rocket.scaleX) || 1;
  return circleHitsAabb(
    hazard.x,
    hazard.y,
    hazardRadius(kind) * (Number(hazard.scaleX) || 1),
    rocket.x,
    rocket.y,
    (box.width * scale) / 2,
    (box.height * scale) / 2,
  );
}

/** True when the pair would have overlapped the old 48×48 padded body. */
export function isNearMiss(rocket, hazard, kind, booster = false) {
  if (!rocket || !hazard) return false;
  const scale = Number(hazard.scaleX) || 1;
  const fat = (HAZARD_CANVAS * scale) / 2;
  const box = rocketHitSize(booster);
  const rScale = Number(rocket.scaleX) || 1;
  const fatHit = circleHitsAabb(
    hazard.x,
    hazard.y,
    fat,
    rocket.x,
    rocket.y,
    (box.width * rScale) / 2 + 18,
    (box.height * rScale) / 2 + 12,
  );
  return fatHit && !contactsHazard(rocket, hazard, kind, booster);
}
