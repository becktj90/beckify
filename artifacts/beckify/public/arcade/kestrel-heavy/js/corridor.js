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
};

function clamp(n, a, b) {
  return Math.max(a, Math.min(b, n));
}

export function corridorBounds(y) {
  const t = clamp((PAD_ROCKET_Y - Number(y || 0)) / CORRIDOR.rise, 0, 1);
  return {
    left: CORRIDOR.padLeft + (CORRIDOR.highLeft - CORRIDOR.padLeft) * t,
    right: CORRIDOR.padRight + (CORRIDOR.highRight - CORRIDOR.padRight) * t,
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
  return { y0: y + 420, y1: y - 980 };
}

export function clampToCorridor(x, y) {
  const { left, right } = corridorBounds(y);
  return clamp(x, left + 10, right - 10);
}

export function corridorFitsPlayfield() {
  return CORRIDOR.highLeft > 80 && CORRIDOR.highRight < W - 80;
}
