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
    't-fuel': snapshot.fuel,
    't-shield': snapshot.shield,
    't-stage': snapshot.stage,
    't-score': snapshot.score,
    't-best': snapshot.best,
    't-combo': snapshot.combo,
    't-radio': snapshot.radio,
    't-mission': snapshot.mission,
    't-payload': snapshot.payload,
    't-obj': snapshot.objective,
    't-clock': snapshot.clock,
  };
  for (const [id, value] of Object.entries(map)) {
    const node = el(id);
    if (node && value != null && node.textContent !== value) node.textContent = value;
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
  const hint = el('ng-hints');
  if (hint) {
    hint.hidden = !snapshot.hints;
    if (snapshot.hints) hint.textContent = snapshot.hints;
  }
  const phase = el('ng-phase');
  if (phase && snapshot.phase) {
    phase.hidden = false;
    phase.textContent = snapshot.phase;
  }
  const tip = el('ng-launch-tip');
  if (tip && snapshot.launchTip != null) tip.hidden = !snapshot.launchTip;
  renderTape(snapshot.tapeId);
}

export function renderTape(activeId) {
  document.querySelectorAll('#ng-tape [data-beat]').forEach((node) => {
    const id = node.getAttribute('data-beat');
    node.classList.toggle('is-now', id === activeId);
    node.classList.toggle('is-done', Boolean(activeId) && node.dataset.order < (document.querySelector(`#ng-tape [data-beat="${activeId}"]`)?.dataset.order || 0));
  });
}

export function setOverlay(id, open) {
  const node = el(id);
  if (!node) return;
  node.hidden = !open;
}

export function showScreen(id) {
  ['ng-menu', 'ng-missions', 'ng-settings', 'ng-howto', 'ng-pause', 'ng-summary'].forEach((key) => {
    const node = el(key);
    if (node) node.hidden = key !== id;
  });
}

export function hideScreens() {
  ['ng-menu', 'ng-missions', 'ng-settings', 'ng-howto', 'ng-pause', 'ng-summary'].forEach((key) => {
    const node = el(key);
    if (node) node.hidden = true;
  });
}

export function setSummaryCopy(title, body) {
  const heading = el('ng-summary-title');
  const text = el('ng-summary-body');
  if (heading) heading.textContent = title;
  if (text) text.textContent = body;
}

export function bindChrome(handlers) {
  const clicks = [
    ['arcade-mute-btn', handlers.toggleMute],
    ['arcade-pause-btn', handlers.togglePause],
    ['arcade-settings-btn', handlers.toggleSettings],
    ['arcade-fullscreen-btn', handlers.toggleFullscreen],
    ['arcade-reset-btn', handlers.resetRecord],
    ['ng-summary-continue', handlers.continueSummary],
    ['ng-play', handlers.play],
    ['ng-hold', handlers.hold],
    ['ng-open-missions', handlers.openMissions],
    ['ng-open-settings', handlers.toggleSettings],
    ['ng-open-howto', handlers.openHowto],
    ['ng-missions-back', handlers.backToMenu],
    ['ng-howto-back', handlers.backToMenu],
    ['ng-settings-back', handlers.closeSettings],
    ['ng-pause-resume', handlers.togglePause],
    ['ng-pause-restart', handlers.restart],
    ['ng-pause-settings', handlers.toggleSettings],
    ['ng-pause-howto', handlers.openHowto],
    ['ng-pause-abort', handlers.abortToMenu],
    ['ng-sum-next', handlers.nextFlight],
  ];
  clicks.forEach(([id, fn]) => {
    const node = el(id);
    if (node && fn) node.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
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

export function setMissionButtons(settings, onPick) {
  document.querySelectorAll('[data-mission]').forEach((btn) => {
    const id = btn.getAttribute('data-mission');
    const label = btn.getAttribute('data-label') || id;
    const unlocked = (settings.unlockedMissions || []).includes(id);
    const active = settings.currentMission === id;
    const best = settings.missionBests?.[id]?.score || 0;
    btn.disabled = false;
    const state = !unlocked ? 'LOCKED' : active ? 'SELECTED' : (best ? `PB ${best.toLocaleString()}` : 'READY');
    const name = btn.querySelector('.mf-name');
    const stateNode = btn.querySelector('.mf-state');
    const idNode = btn.querySelector('.mf-id');
    if (stateNode) {
      if (idNode) idNode.textContent = id;
      stateNode.textContent = state;
    } else {
      const bestBit = best ? ` · ${best.toLocaleString()}` : '';
      btn.textContent = unlocked ? `${label}${bestBit}` : `${id} · LOCKED`;
    }
    btn.setAttribute('aria-pressed', active ? 'true' : 'false');
    btn.setAttribute('aria-disabled', unlocked ? 'false' : 'true');
    btn.classList.toggle('is-active', active);
    btn.classList.toggle('is-locked', !unlocked);
    if (!btn._bound) {
      btn._bound = true;
      btn.addEventListener('click', (event) => {
        event.preventDefault();
        event.stopPropagation();
        onPick(id);
      });
    }
  });
}

export function setDifficultyButtons(active, onPick) {
  document.querySelectorAll('[data-diff]').forEach((btn) => {
    const mode = btn.getAttribute('data-diff');
    btn.setAttribute('aria-pressed', mode === active ? 'true' : 'false');
    btn.classList.toggle('is-active', mode === active);
    if (!btn._bound) {
      btn._bound = true;
      btn.addEventListener('click', (event) => {
        event.preventDefault();
        event.stopPropagation();
        onPick(mode);
      });
    }
  });
}

export function syncSettingsForm(settings) {
  const form = el('ng-settings');
  if (!form) return;
  form.querySelectorAll('[data-set]').forEach((input) => {
    const key = input.getAttribute('data-set');
    if (input.type === 'checkbox') {
      if (key === 'sound') input.checked = !settings.muted && settings.sound !== false;
      else if (key === 'muted') input.checked = Boolean(settings.muted);
      else input.checked = Boolean(settings[key]);
    }
    if (input.type === 'range') {
      const raw = Number(settings[key]);
      const value = Number.isFinite(raw) ? raw : 0.72;
      input.value = String(Math.round(value * 100));
    }
  });
}

export function readSettingsForm(settings) {
  const form = el('ng-settings');
  if (!form) return settings;
  form.querySelectorAll('[data-set]').forEach((input) => {
    const key = input.getAttribute('data-set');
    if (input.type === 'range') {
      settings[key] = Number(input.value) / 100;
    } else if (input.type === 'checkbox') {
      settings[key] = input.checked;
      if (key === 'sound') settings.muted = !input.checked;
      if (key === 'muted') settings.sound = !input.checked;
    }
  });
  return settings;
}

export function setSummaryBreakdown(ascent, jacklyn, delta, nextLabel) {
  const a = el('ng-sum-ascent');
  const j = el('ng-sum-jacklyn');
  const d = el('ng-sum-delta');
  const next = el('ng-sum-next');
  if (a) a.textContent = ascent || '';
  if (j) j.textContent = jacklyn || '';
  if (d) d.textContent = delta || '';
  if (next) {
    next.hidden = !nextLabel;
    if (nextLabel) next.textContent = nextLabel;
  }
}

export function setCardFlight(flight) {
  const title = el('ng-card-flight');
  const blurb = el('ng-card-blurb');
  if (title) title.textContent = `${flight.id} · ${flight.payload}`;
  if (blurb) blurb.textContent = flight.blurb || '';
}

export function isEmbedded() {
  try {
    return window.self !== window.top;
  } catch {
    return true;
  }
}
