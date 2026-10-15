/**
 * Stack integrity. Shield still eats one hit. Remaining health is visible so
 * a RUD is never silent — graze vs lethal is named on the banner.
 */
import { DIFFICULTY } from './config.js';

export const HEALTH_MAX = {
  KID: 100,
  CADET: 100,
  PAD_RAT: 64,
};

/** Per-hazard integrity loss after the aero shield is gone. */
export const HAZARD_DAMAGE = {
  bird: 28,
  balloon: 16,
  ice: 36,
  debris: 42,
  clutter: 24,
};

export const CORRIDOR_SCRAPE_DPS = 14;

export function healthMaxFor(diff) {
  return HEALTH_MAX[diff] || HEALTH_MAX.CADET;
}

export function hazardDamage(kind, diff) {
  const base = HAZARD_DAMAGE[kind] || HAZARD_DAMAGE.debris;
  if (diff === 'PAD_RAT') return Math.round(base * 1.15);
  if (diff === 'KID') return Math.round(base * 0.55);
  return base;
}

/**
 * Apply a corridor hit.
 * @returns {{ health: number, shield: number, kind: 'grace'|'shield'|'graze'|'lethal'|'kid', damage: number, remaining: number }}
 */
export function applyHit(session, kind, diff) {
  const max = healthMaxFor(diff);
  const health = Number.isFinite(session.health) ? session.health : max;
  const shield = Number(session.shield) || 0;
  const mode = DIFFICULTY[diff] || DIFFICULTY.CADET;

  if ((session.grace || 0) > 0) {
    return { health, shield, kind: 'grace', damage: 0, remaining: health };
  }
  if (shield > 0) {
    return { health, shield: shield - 1, kind: 'shield', damage: 0, remaining: health };
  }

  const damage = hazardDamage(kind, diff);
  let next = Math.max(0, health - damage);
  if (!mode.allowFail) {
    next = Math.max(8, next);
    return { health: next, shield: 0, kind: 'kid', damage, remaining: next };
  }
  if (next <= 0) {
    return { health: 0, shield: 0, kind: 'lethal', damage, remaining: 0 };
  }
  return { health: next, shield: 0, kind: 'graze', damage, remaining: next };
}

export function applyScrape(session, dt, diff) {
  const max = healthMaxFor(diff);
  const health = Number.isFinite(session.health) ? session.health : max;
  const mode = DIFFICULTY[diff] || DIFFICULTY.CADET;
  if (!mode.allowFail) {
    return { health, kind: 'kid', remaining: health };
  }
  const next = Math.max(0, health - CORRIDOR_SCRAPE_DPS * dt);
  return {
    health: next,
    kind: next <= 0 ? 'lethal' : 'graze',
    remaining: next,
  };
}

export function healthKind(health, max) {
  const t = max > 0 ? health / max : 0;
  if (t <= 0) return 'fail';
  if (t <= 0.34) return 'warn';
  return 'ok';
}
