import { BOOST_BUFFER_SEC, BOOST_COYOTE_SEC } from './config.js';

/** Pixels of thumb travel before climb-pad drag arms analog steer. */
export const TOUCH_STEER_DEAD_PX = 14;
/** Horizontal drag that maps to full analog deflection. */
export const TOUCH_STEER_FULL_PX = 110;

export function createInput() {
  return {
    left: false,
    right: false,
    boostHeld: false,
    boostUntil: 0,
    boostBufferedUntil: 0,
    pointerX: null,
    touchSteer: null,
    touchSteerArmed: false,
  };
}

export function setBoostHeld(input, held, now) {
  input.boostHeld = held;
  if (held) {
    input.boostUntil = now + BOOST_COYOTE_SEC;
    input.boostBufferedUntil = now + BOOST_BUFFER_SEC;
  }
}

export function isBoosting(input, now) {
  return input.boostHeld || now < input.boostUntil;
}

export function consumeBoostTap(input, now) {
  if (input.boostHeld || now < input.boostBufferedUntil || now < input.boostUntil) {
    input.boostBufferedUntil = 0;
    return true;
  }
  return false;
}

export function steerAxis(input) {
  return (input.right ? 1 : 0) - (input.left ? 1 : 0);
}

/**
 * One-thumb climb pad: hold still does not steal ◀ ▶ / canvas analog.
 * Past the deadzone, horizontal drag is analog steer in [-1, 1].
 */
export function setTouchSteer(input, dxPx) {
  if (dxPx == null || !Number.isFinite(dxPx)) {
    input.touchSteer = null;
    input.touchSteerArmed = false;
    return;
  }
  if (!input.touchSteerArmed && Math.abs(dxPx) < TOUCH_STEER_DEAD_PX) return;
  input.touchSteerArmed = true;
  const span = TOUCH_STEER_FULL_PX;
  input.touchSteer = Math.max(-1, Math.min(1, dxPx / span));
}

/**
 * Steer source of truth: climb-pad drag, then canvas pointerX, then A/D pads.
 */
export function flightAxis(input, rocketX, analogScale) {
  if (input.touchSteer != null) return input.touchSteer;
  if (input.pointerX != null) {
    const span = analogScale || 140;
    return Math.max(-1, Math.min(1, (input.pointerX - rocketX) / span));
  }
  return steerAxis(input);
}

export function clearFlightHolds(input) {
  input.left = false;
  input.right = false;
  input.boostHeld = false;
  input.boostUntil = 0;
  input.boostBufferedUntil = 0;
  input.pointerX = null;
  input.touchSteer = null;
  input.touchSteerArmed = false;
}

export function bindKeyboard(input, hooks) {
  const down = (event) => {
    hooks.unlock();
    if (event.code === 'ArrowLeft' || event.code === 'KeyA') {
      event.preventDefault();
      input.left = true;
    }
    if (event.code === 'ArrowRight' || event.code === 'KeyD') {
      event.preventDefault();
      input.right = true;
    }
    if (event.code === 'Space') {
      event.preventDefault();
      if (event.repeat) {
        setBoostHeld(input, true, hooks.now());
        return;
      }
      if (hooks.onBoostTap) hooks.onBoostTap();
      setBoostHeld(input, true, hooks.now());
    }
    if (event.code === 'KeyP' || event.code === 'Escape') {
      event.preventDefault();
      hooks.togglePause();
    }
    if (event.code === 'KeyM') {
      event.preventDefault();
      hooks.toggleMute();
    }
    if (event.code === 'KeyO') {
      event.preventDefault();
      hooks.toggleSettings();
    }
  };
  const up = (event) => {
    if (event.code === 'ArrowLeft' || event.code === 'KeyA') input.left = false;
    if (event.code === 'ArrowRight' || event.code === 'KeyD') input.right = false;
    if (event.code === 'Space') setBoostHeld(input, false, hooks.now());
  };
  const loseFocus = () => {
    clearFlightHolds(input);
  };
  const onVisibility = () => {
    if (document.hidden) loseFocus();
  };
  window.addEventListener('keydown', down);
  window.addEventListener('keyup', up);
  window.addEventListener('blur', loseFocus);
  document.addEventListener('visibilitychange', onVisibility);
  return () => {
    window.removeEventListener('keydown', down);
    window.removeEventListener('keyup', up);
    window.removeEventListener('blur', loseFocus);
    document.removeEventListener('visibilitychange', onVisibility);
  };
}
