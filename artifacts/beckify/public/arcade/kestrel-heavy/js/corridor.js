/**
 * Ascent flight corridor — the dotted rails are play bounds, not decoration.
 * World X stays between the rails or the stack aborts (KID is bounced back).
 */
import { PAD_ROCKET_Y, W } from './config.js';

export const CORRIDOR = {
  padLeft: 392,
  padRight: 888,
  highLeft: 308,
  highRight: 972,
  rise: 2200,
  warnFrac: 0.16,
  abortHold: {
    KID: 0,
    CADET: 1.35,
    PAD_RAT: 0.62,
  },
  /** Extra px per side for the active flight (KH-1 teaches the rails wider). */
  widen: 0,
};

/**
 * Forgiving first flight. Until a player has caught Haven on KH-1, the first
 * drifts past the rails are a soft warning with recovery time and a gentle
 * push back in — no scrape, no abort. After that the rails hold like a wall
 * for the rest of that flight, and the first lethal hazard hit is survived
 * once (saveHealth INT), so new players reach the barge.
 */
export const FIRST_FLIGHT = {
  mission: 'KH-1',
  widen: 72,
  graces: 2,
  graceSec: 3.2,
  assist: 0.55,
  /** Hazard damage multiplier and one-time lethal save on the first flight. */
  damageMul: 0.6,
  saveHealth: 18,
};

/**
 * Soften a hazard hit on the first flight: less INT loss, and the first
 * lethal hit leaves the stack at saveHealth instead of a RUD.
 * @returns {{ health:number, kind:string, saved:boolean }}
 */
export function softenFirstFlightHit(grace, prevHealth, result) {
  if (!grace?.enabled || !result) return { health: result?.health, kind: result?.kind, saved: false };
  if (result.kind !== 'graze' && result.kind !== 'lethal') return { health: result.health, kind: result.kind, saved: false };
  const prev = Number(prevHealth) || 0;
  const lost = Math.max(0, prev - (Number(result.health) || 0)) * FIRST_FLIGHT.damageMul;
  const next = prev - lost;
  if (result.kind === 'graze' && next > 0) return { health: next, kind: 'graze', saved: false };
  if (!grace.saved) {
    grace.saved = true;
    return { health: FIRST_FLIGHT.saveHealth, kind: 'graze', saved: true };
  }
  return { health: 0, kind: 'lethal', saved: false };
}

export function setCorridorWiden(px) {
  CORRIDOR.widen = Math.max(0, Number(px) || 0);
  return CORRIDOR.widen;
}

export function corridorWidenFor(mission) {
  return Math.max(0, Number(mission?.corridorWiden) || 0);
}

/** True while the player has never recovered on KH-1 (fresh install). */
export function isFirstFlightGrace(missionId, settings) {
  if (missionId !== FIRST_FLIGHT.mission) return false;
  return !settings?.missionBests?.[FIRST_FLIGHT.mission]?.recovered;
}

export function freshCorridorGrace(enabled) {
  return { enabled: Boolean(enabled), left: enabled ? FIRST_FLIGHT.graces : 0, timer: 0, active: false, used: 0 };
}

/**
 * Step the soft-warning state for one frame. Returns 'soft' while a grace
 * window is open (caller warns + nudges, no damage), 'wall' once the first
 * flight's graces are spent (rails hold like KID — still no abort), 'ok'
 * when inside, else 'enforce' (normal scrape/abort rules).
 */
export function stepCorridorGrace(grace, edgeState, dt) {
  if (!grace) return 'enforce';
  if (grace.active) {
    grace.timer -= dt;
    if (edgeState !== 'out' || grace.timer <= 0) {
      grace.active = false;
      if (edgeState !== 'out') return 'ok';
      return grace.enabled ? 'wall' : 'enforce';
    }
    return 'soft';
  }
  if (edgeState !== 'out') return 'ok';
  if (grace.left > 0) {
    grace.left -= 1;
    grace.used += 1;
    grace.active = true;
    grace.timer = FIRST_FLIGHT.graceSec;
    return 'soft';
  }
  return grace.enabled ? 'wall' : 'enforce';
}

function clamp(n, a, b) {
  return Math.max(a, Math.min(b, n));
}

export function corridorBounds(y) {
  const t = clamp((PAD_ROCKET_Y - Number(y || 0)) / CORRIDOR.rise, 0, 1);
  const wide = CORRIDOR.widen || 0;
  return {
    left: CORRIDOR.padLeft + (CORRIDOR.highLeft - CORRIDOR.padLeft) * t - wide,
    right: CORRIDOR.padRight + (CORRIDOR.highRight - CORRIDOR.padRight) * t + wide,
  };
}

export function corridorEdge(x, y) {
  const { left, right } = corridorBounds(y);
  const span = Math.max(48, right - left);
  const warn = span * CORRIDOR.warnFrac;
  const inward = Math.min(x - left, right - x);
  let state = 'ok';
  if (inward < 0) state = 'out';
  else if (inward < warn) state = 'warn';
  return {
    left,
    right,
    state,
    inward,
    t: state === 'ok' ? 0 : clamp(1 - inward / warn, 0, 1),
  };
}

export function abortHoldFor(diff) {
  return CORRIDOR.abortHold[diff] ?? CORRIDOR.abortHold.CADET;
}

export function dashRail(graphics, x, y0, y1, dash = 16, gap = 12) {
  const top = Math.min(y0, y1);
  const bot = Math.max(y0, y1);
  for (let y = top; y < bot; y += dash + gap) {
    const yb = Math.min(bot, y + dash);
    if (typeof graphics.lineBetween === 'function') {
      graphics.lineBetween(x, y, x, yb);
    } else {
      graphics.beginPath();
      graphics.moveTo(x, y);
      graphics.lineTo(x, yb);
      graphics.strokePath();
    }
  }
}

export function corridorVisibleSpan(rocketY) {
  const y = Number(rocketY) || PAD_ROCKET_Y;
  return { y0: y + 420, y1: y - 1280 };
}

export function clampToCorridor(x, y) {
  const { left, right } = corridorBounds(y);
  return clamp(x, left + 10, right - 10);
}

export function corridorFitsPlayfield() {
  return CORRIDOR.highLeft - FIRST_FLIGHT.widen > 80 && CORRIDOR.highRight + FIRST_FLIGHT.widen < W - 80;
}
