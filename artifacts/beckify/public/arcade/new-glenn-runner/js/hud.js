/** Mission-control telemetry overlay — tabular, high contrast, aria-live banners. */

function el(id) {
  return document.getElementById(id);
}

export function announce(message) {
  const live = el('arcade-live');
  if (!live) return;
  live.textContent = '';
  window.requestAnimationFrame(() => {
    live.textContent = message;
  });
}

export function setBanner(text, kind = 'info', holdMs = 2200) {
  const banner = el('ng-banner');
  if (!banner) return;
  banner.hidden = !text;
  banner.textContent = text || '';
  banner.dataset.kind = kind;
  if (text) announce(text);
  if (banner._hide) window.clearTimeout(banner._hide);
  if (text && holdMs > 0) {
    banner._hide = window.setTimeout(() => {
      banner.hidden = true;
    }, holdMs);
  }
}

export function renderHud(snapshot) {
  const map = {
    't-alt': snapshot.alt,
    't-vel': snapshot.vel,
    't-thr': snapshot.throttle,
    't-stage': snapshot.stage,
    't-score': snapshot.score,
    't-best': snapshot.best,
    't-combo': snapshot.combo,
    't-radio': snapshot.radio,
  };
  for (const [id, value] of Object.entries(map)) {
    const node = el(id);
    if (node && node.textContent !== value) node.textContent = value;
  }
  const mute = el('arcade-mute-btn');
  if (mute) {
    mute.textContent = snapshot.muted ? '🔇' : '🔊';
    mute.setAttribute('aria-pressed', snapshot.muted ? 'true' : 'false');
  }
  const pause = el('arcade-pause-btn');
  if (pause) {
    pause.textContent = snapshot.paused ? '▶' : '⏸';
    pause.setAttribute('aria-pressed', snapshot.paused ? 'true' : 'false');
  }
  const climb = el('atb-boost');
  if (climb) climb.textContent = snapshot.boostLabel;
  const record = el('arcade-hi-score');
  if (record) record.textContent = snapshot.recordLine;
}

export function bindChrome(handlers) {
  const clicks = [
    ['arcade-mute-btn', handlers.toggleMute],
    ['arcade-pause-btn', handlers.togglePause],
    ['arcade-settings-btn', handlers.toggleSettings],
    ['arcade-fullscreen-btn', handlers.toggleFullscreen],
    ['arcade-reset-btn', handlers.resetRecord],
  ];
  clicks.forEach(([id, fn]) => {
    const node = el(id);
    if (node && fn) node.addEventListener('click', (event) => {
      event.preventDefault();
      fn();
    });
  });

  const hold = (id, down, up) => {
    const node = el(id);
    if (!node) return;
    const onDown = (event) => {
      event.preventDefault();
      if (node.setPointerCapture && event.pointerId !== undefined) {
        node.setPointerCapture(event.pointerId);
      }
      down();
    };
    const onUp = (event) => {
      event.preventDefault();
      up();
    };
    node.addEventListener('pointerdown', onDown, { passive: false });
    node.addEventListener('pointerup', onUp, { passive: false });
    node.addEventListener('pointercancel', onUp, { passive: false });
    node.addEventListener('pointerleave', onUp, { passive: false });
  };

  hold('atb-left', () => handlers.steer(-1, true), () => handlers.steer(-1, false));
  hold('atb-right', () => handlers.steer(1, true), () => handlers.steer(1, false));
  hold('atb-boost', () => handlers.boost(true), () => handlers.boost(false));
}

export function setDifficultyButtons(active, onPick) {
  document.querySelectorAll('[data-diff]').forEach((btn) => {
    const mode = btn.getAttribute('data-diff');
    btn.setAttribute('aria-pressed', mode === active ? 'true' : 'false');
    btn.classList.toggle('is-active', mode === active);
    if (!btn._bound) {
      btn._bound = true;
      btn.addEventListener('click', () => onPick(mode));
    }
  });
}

export function syncSettingsForm(settings) {
  const form = el('ng-settings');
  if (!form) return;
  form.querySelectorAll('[data-set]').forEach((input) => {
    const key = input.getAttribute('data-set');
    if (input.type === 'checkbox') input.checked = Boolean(settings[key]);
  });
}

export function isEmbedded() {
  try {
    return window.self !== window.top;
  } catch {
    return true;
  }
}
