/**
 * Honest overlap. Hazard sprites sit on a 48×48 canvas with a glow halo;
 * Matter's default rectangle used the whole frame, so near-misses INT-hit.
 * Bodies match the solid art plus a tiny graze pad — never a fat invisible pad.
 *
 * Phaser Matter setCircle / setRectangle replace the body and drop label to
 * the Matter default "Body". Always restamp label (and filters) after reshape.
 */

export const HAZARD_CANVAS = 48;

/** Solid visual radius at scale 1 (px), ignoring canvas padding / halo. */
export const HAZARD_RADIUS = {
  bird: 14,
  balloon: 13,
  ice: 13,
  debris: 12,
  clutter: 12,
};

/** Extra px beyond the solid art so a true edge clip still counts. */
export const GRAZE_PAD = 2;

/**
 * Unscaled Matter rectangle for the stack. Canvas is 92×268 (booster 124×268)
 * with empty padding; the painted cylinder is ~40px wide.
 */
export const ROCKET_HIT = { width: 42, height: 228 };
export const BOOSTER_HIT = { width: 38, height: 198 };
/** Matter density for the unscaled 42×228 (or booster) box. */
export const ROCKET_DENSITY = 0.002;

export function hazardRadius(kind) {
  return (HAZARD_RADIUS[kind] || HAZARD_RADIUS.debris) + GRAZE_PAD;
}

export function rocketHitSize(booster) {
  return booster ? BOOSTER_HIT : ROCKET_HIT;
}

/** Density so a sprite-scaled Matter box keeps the unscaled mass. */
export function rocketBodyDensity(scale = 1) {
  const s = Number(scale) || 1;
  return ROCKET_DENSITY / (s * s);
}

/** Options to pass into Matter setCircle / setRectangle so labels survive. */
export function matterLabelOptions(label, extra = {}) {
  return { label, ...extra };
}

export function stampBodyLabel(gameObject, label) {
  if (gameObject?.body) gameObject.body.label = label;
  return gameObject;
}

export function isRocketBody(body, rocket) {
  if (!body) return false;
  if (rocket && (body === rocket.body || body.gameObject === rocket)) return true;
  return body.label === 'rocket';
}

/** The non-rocket body in a Matter collision pair, or null. */
export function otherBody(pair, rocket) {
  if (!pair) return null;
  if (isRocketBody(pair.bodyA, rocket)) return pair.bodyB;
  if (isRocketBody(pair.bodyB, rocket)) return pair.bodyA;
  return null;
}

export function hazardKindOf(obj, label) {
  if (obj && obj.hazardKind) return String(obj.hazardKind);
  const raw = String(label || obj?.body?.label || obj?.label || '');
  return raw.startsWith('hazard-') ? raw.slice(7) : raw;
}

/**
 * Circle vs axis-aligned box (centers). Used to reject fat default bodies
 * and as a software overlap scan when Matter labels are missing.
 */
export function circleHitsAabb(cx, cy, radius, ax, ay, halfW, halfH) {
  const dx = Math.abs(Number(cx) - Number(ax));
  const dy = Math.abs(Number(cy) - Number(ay));
  const nx = Math.max(0, dx - halfW);
  const ny = Math.max(0, dy - halfH);
  return nx * nx + ny * ny <= radius * radius;
}

/**
 * Circle vs the rocket's rotated box. Phaser angle is clockwise degrees, Y down.
 */
export function circleHitsRotatedAabb(cx, cy, radius, ax, ay, halfW, halfH, angleDeg) {
  const rad = ((Number(angleDeg) || 0) * Math.PI) / 180;
  const dx = Number(cx) - Number(ax);
  const dy = Number(cy) - Number(ay);
  const c = Math.cos(rad);
  const s = Math.sin(rad);
  const lx = c * dx + s * dy;
  const ly = -s * dx + c * dy;
  return circleHitsAabb(lx, ly, radius, 0, 0, halfW, halfH);
}

export function contactsHazard(rocket, hazard, kind, booster = false) {
  if (!rocket || !hazard) return false;
  const box = rocketHitSize(booster);
  const scale = Number(rocket.scaleX) || 1;
  const resolved = hazardKindOf(hazard, kind);
  return circleHitsRotatedAabb(
    hazard.x,
    hazard.y,
    hazardRadius(resolved) * (Number(hazard.scaleX) || 1),
    rocket.x,
    rocket.y,
    (box.width * scale) / 2,
    (box.height * scale) / 2,
    rocket.angle,
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
