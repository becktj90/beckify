import { BOOST_BUFFER_SEC, BOOST_COYOTE_SEC } from './config.js';

export function createInput() {
  return {
    left: false,
    right: false,
    boostHeld: false,
    boostUntil: 0,
    boostBufferedUntil: 0,
    pointerX: null,
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
  window.addEventListener('keydown', down);
  window.addEventListener('keyup', up);
  return () => {
    window.removeEventListener('keydown', down);
    window.removeEventListener('keyup', up);
  };
}
