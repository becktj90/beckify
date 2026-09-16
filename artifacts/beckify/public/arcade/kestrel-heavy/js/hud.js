/** Mission-control telemetry overlay — tabular, high contrast, aria-live banners. */

import { climbArmedFromLabel, paintThumbSteer, peekTouchSteer, TOUCH_STEER_DEAD_PX } from './input.js';

function el(id) {
  return document.getElementById(id);
}

let lastAnnounce = '';
let lastAnnounceAt = 0;

export function announce(message) {
  const live = el('arcade-live');
  if (!live || !message) return;
  const now = Date.now();
  if (message === lastAnnounce && now - lastAnnounceAt < 1400) return;
  lastAnnounce = message;
  lastAnnounceAt = now;
  live.textContent = '';
  window.requestAnimationFrame(() => {
    live.textContent = message;
  });
}

export function setBanner(text, kind = 'info', holdMs = 2200) {
  const banner = el('ng-banner');
  if (!banner) return;
  const same = Boolean(text) && banner.textContent === text && !banner.hidden;
  banner.hidden = !text;
  banner.textContent = text || '';
  banner.dataset.kind = kind;
  if (text && !same) announce(text);
  if (banner._hide) window.clearTimeout(banner._hide);
  if (text && holdMs > 0) {
    banner._hide = window.setTimeout(() => {
      banner.hidden = true;
    }, holdMs);
  }
}

export function flashIgnite() {
  const climb = el('atb-boost');
  if (!climb) return;
  climb.classList.remove('is-flash');
  void climb.offsetWidth;
  climb.classList.add('is-flash');
  window.setTimeout(() => climb.classList.remove('is-flash'), 340);
}

export function renderHud(snapshot) {
  const map = {
    't-alt': snapshot.alt,
    't-vel': snapshot.vel,
    't-thr': snapshot.throttle,
    't-fuel': snapshot.fuel,
    't-shield': snapshot.shield,
    't-health': snapshot.health,
    't-stage': snapshot.stage,
    't-score': snapshot.score,
    't-best': snapshot.best,
    't-combo': snapshot.combo,
    't-radio': snapshot.radio,
    't-mission': snapshot.mission,
    't-payload': snapshot.payload,
    't-obj': snapshot.objective,
    't-next': snapshot.next,
    't-clock': snapshot.clock,
    't-mach': snapshot.mach,
    't-q': snapshot.q,
    't-acc': snapshot.acc,
    't-twr': snapshot.twr,
    't-fpa': snapshot.fpa,
    't-sci': snapshot.sci,
  };
  for (const [id, value] of Object.entries(map)) {
    const node = el(id);
    if (node && value != null && node.textContent !== value) node.textContent = value;
  }
  const mute = el('arcade-mute-btn');
  if (mute) {
    mute.textContent = snapshot.muted ? 'MUTED' : 'SOUND';
    mute.setAttribute('aria-pressed', snapshot.muted ? 'true' : 'false');
  }
  const pause = el('arcade-pause-btn');
  if (pause) {
    pause.textContent = snapshot.paused ? 'RESUME' : 'PAUSE';
    pause.setAttribute('aria-pressed', snapshot.paused ? 'true' : 'false');
  }
  const climb = el('atb-boost');
  if (climb && snapshot.boostLabel) {
    climb.dataset.label = snapshot.boostLabel;
    climb.dataset.climb = climbArmedFromLabel(snapshot.boostLabel) ? 'on' : 'off';
    climb.classList.toggle('is-held', Boolean(snapshot.boostHeld || snapshot.thumbHeld));
    climb.classList.toggle('is-burn', Boolean(snapshot.burnReady));
    if (climb.style?.setProperty) {
      climb.style.setProperty('--kh-hold', String(Math.max(0, Math.min(1, Number(snapshot.boostHold) || 0))));
    }
    paintThumbSteer(climb, snapshot.touchSteer);
    if (climb._syncClimb) climb._syncClimb();
    climb.setAttribute(
      'aria-label',
      snapshot.boostLabel === 'HOLD TO BURN'
        ? 'Hold to fire the landing burn, drag left or right to steer'
        : snapshot.boostLabel === 'GLIDE'
          ? 'Drag to steer the glide — do not burn yet'
          : snapshot.boostLabel === 'SEPARATE'
            ? 'Press to separate stages'
            : 'Hold to climb, drag left or right to steer',
    );
  }
  const sepBtn = el('ng-sep-btn');
  if (sepBtn) {
    const show = Boolean(snapshot.sepReady || snapshot.sepArmed);
    sepBtn.hidden = !show;
    sepBtn.classList.toggle('is-ready', Boolean(snapshot.sepReady));
    sepBtn.setAttribute('aria-disabled', snapshot.sepReady ? 'false' : 'true');
  }
  const record = el('arcade-hi-score');
  if (record) record.textContent = snapshot.recordLine;
  const next = el('t-next');
  if (next) {
    next.hidden = !snapshot.next;
    if (snapshot.next) next.textContent = snapshot.next;
  }
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
  const pauseHint = el('ng-pause-hint');
  if (pauseHint && snapshot.pauseHint) pauseHint.textContent = snapshot.pauseHint;
  if (snapshot.diff) document.body.dataset.diff = snapshot.diff;
  document.body.classList.toggle('is-kid', snapshot.diff === 'KID');
  renderTape(snapshot.tapeId, snapshot.nextTapeId);
  renderHealth(snapshot);
}

export function setSummaryWhy(text) {
  const node = el('ng-sum-why');
  if (!node) return;
  node.hidden = !text;
  node.textContent = text || '';
}

export function renderTape(activeId, nextId) {
  const nodes = [...document.querySelectorAll('#ng-tape [data-beat]')];
  const active = nodes.find((node) => node.getAttribute('data-beat') === activeId);
  const activeOrder = Number(active?.dataset.order || 0);
  nodes.forEach((node) => {
    const id = node.getAttribute('data-beat');
    const order = Number(node.dataset.order || 0);
    const isNow = id === activeId;
    const isNext = Boolean(nextId) ? id === nextId : Boolean(activeId) && order === activeOrder + 1;
    node.classList.toggle('is-now', isNow);
    node.classList.toggle('is-next', isNext);
    node.classList.toggle('is-done', Boolean(activeId) && order < activeOrder);
    if (isNow) node.setAttribute('aria-current', 'step');
    else node.removeAttribute('aria-current');
  });
}

const SHEET_IDS = ['ng-menu', 'ng-missions', 'ng-hangar', 'ng-settings', 'ng-howto', 'ng-pause', 'ng-summary'];

export function syncPlayfieldPointers() {
  const sheetOpen = SHEET_IDS.some((id) => {
    const node = el(id);
    return Boolean(node) && !node.hidden;
  });
  document.body.classList.toggle('is-sheet-open', sheetOpen);
}

export function setOverlay(id, open) {
  const node = el(id);
  if (!node) return;
  node.hidden = !open;
  syncPlayfieldPointers();
}

export function showScreen(id) {
  SHEET_IDS.forEach((key) => {
    const node = el(key);
    if (node) node.hidden = key !== id;
  });
  syncPlayfieldPointers();
}

export function hideScreens() {
  SHEET_IDS.forEach((key) => {
    const node = el(key);
    if (node) node.hidden = true;
  });
  syncPlayfieldPointers();
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
    ['ng-open-hangar', handlers.openHangar],
    ['ng-open-settings', handlers.toggleSettings],
    ['ng-open-howto', handlers.openHowto],
    ['ng-missions-back', handlers.backToMenu],
    ['ng-hangar-back', handlers.backToMenu],
    ['ng-howto-back', handlers.backToMenu],
    ['ng-settings-back', handlers.closeSettings],
    ['ng-pause-resume', handlers.togglePause],
    ['ng-pause-restart', handlers.restart],
    ['ng-pause-settings', handlers.toggleSettings],
    ['ng-pause-howto', handlers.openHowto],
    ['ng-pause-abort', handlers.abortToMenu],
    ['ng-sum-next', handlers.nextFlight],
    ['ng-sep-btn', handlers.separate],
  ];
  clicks.forEach(([id, fn]) => {
    const node = el(id);
    if (node && fn)     node.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
      event.stopImmediatePropagation();
      fn();
    });
  });

  const clientXOf = (event) => {
    if (typeof event.clientX === 'number') return event.clientX;
    const touch = event.changedTouches?.[0] || event.touches?.[0];
    return touch ? touch.clientX : null;
  };

  const suppressCallout = (event) => {
    event.preventDefault();
  };

  const bindHoldGuards = (node) => {
    node.addEventListener('contextmenu', suppressCallout);
    node.addEventListener('selectstart', suppressCallout);
    // iOS Safari starts the text magnifier / scroll from the native touch.
    node.addEventListener('touchstart', suppressCallout, { passive: false });
    node.addEventListener('touchmove', suppressCallout, { passive: false });
  };

  const hold = (id, down, up) => {
    const node = el(id);
    if (!node) return;
    let held = false;
    const onDown = (event) => {
      event.preventDefault();
      if (event.button != null && event.button !== 0) return;
      if (held) return;
      held = true;
      if (node.setPointerCapture && event.pointerId !== undefined) {
        node.setPointerCapture(event.pointerId);
      }
      down();
    };
    const onUp = (event) => {
      event.preventDefault();
      if (!held) return;
      held = false;
      up();
    };
    node.addEventListener('pointerdown', onDown, { passive: false });
    node.addEventListener('pointerup', onUp, { passive: false });
    node.addEventListener('pointercancel', onUp, { passive: false });
    node.addEventListener('pointerleave', onUp, { passive: false });
    node.addEventListener('lostpointercapture', onUp, { passive: false });
    node.addEventListener('touchstart', onDown, { passive: false });
    node.addEventListener('touchend', onUp, { passive: false });
    node.addEventListener('touchcancel', onUp, { passive: false });
    bindHoldGuards(node);
  };

  /**
   * Primary one-thumb path: hold = climb/burn, drag horizontally = analog steer.
   * Do not release on pointerleave — capture keeps the same finger after the pad.
   * ◀ ▶ stay as optional second-finger pads.
   */
  const holdClimb = (id) => {
    const node = el(id);
    if (!node) return;
    let held = false;
    let originX = 0;
    let armed = false;
    const climbArmed = () => node.dataset.climb !== 'off';
    const endHold = () => {
      if (!held) return;
      held = false;
      armed = false;
      originX = 0;
      handlers.thumb?.(false);
      if (handlers.steerDrag) handlers.steerDrag(null);
      handlers.boost(false);
      paintThumbSteer(node, 0);
    };
    const onDown = (event) => {
      event.preventDefault();
      if (event.button != null && event.button !== 0) return;
      if (held) return;
      const x = clientXOf(event);
      if (x == null) return;
      held = true;
      armed = false;
      originX = x;
      if (node.setPointerCapture && event.pointerId !== undefined) {
        node.setPointerCapture(event.pointerId);
      }
      handlers.thumb?.(true);
      if (handlers.steerDrag) handlers.steerDrag(null);
      handlers.boost(climbArmed());
      paintThumbSteer(node, 0);
    };
    const onMove = (event) => {
      if (!held) return;
      event.preventDefault();
      const x = clientXOf(event);
      if (x == null || !handlers.steerDrag) return;
      const dx = x - originX;
      handlers.steerDrag(dx);
      if (!armed && Math.abs(dx) >= TOUCH_STEER_DEAD_PX) armed = true;
      paintThumbSteer(node, peekTouchSteer(dx, armed));
    };
    node._syncClimb = () => {
      if (!held) return;
      handlers.boost(climbArmed());
    };
    const onUp = (event) => {
      event.preventDefault();
      endHold();
    };
    node.addEventListener('pointerdown', onDown, { passive: false });
    node.addEventListener('pointermove', onMove, { passive: false });
    node.addEventListener('pointerup', onUp, { passive: false });
    node.addEventListener('pointercancel', onUp, { passive: false });
    node.addEventListener('lostpointercapture', onUp, { passive: false });
    node.addEventListener('touchstart', onDown, { passive: false });
    node.addEventListener('touchmove', onMove, { passive: false });
    node.addEventListener('touchend', onUp, { passive: false });
    node.addEventListener('touchcancel', onUp, { passive: false });
    bindHoldGuards(node);
  };

  hold('atb-left', () => handlers.steer(-1, true), () => handlers.steer(-1, false));
  hold('atb-right', () => handlers.steer(1, true), () => handlers.steer(1, false));
  holdClimb('atb-boost');
  syncPlayfieldPointers();
}

export function renderHealth(snapshot) {
  const bar = el('ng-health');
  const fill = el('ng-health-fill');
  const label = el('t-health');
  if (!bar) return;
  const max = Math.max(1, Number(snapshot.healthMax) || 100);
  const hp = Math.max(0, Math.min(max, Number(snapshot.health) || 0));
  const pct = Math.round((hp / max) * 100);
  bar.setAttribute('aria-valuenow', String(pct));
  bar.setAttribute('aria-valuemax', '100');
  bar.dataset.kind = snapshot.healthKind || (pct <= 0 ? 'fail' : pct <= 34 ? 'warn' : 'ok');
  bar.hidden = snapshot.hideHealth === true;
  if (fill) fill.style.width = `${pct}%`;
  if (label && snapshot.healthText != null) label.textContent = snapshot.healthText;
  const chip = el('t-health-chip');
  if (chip) chip.textContent = snapshot.healthText || `${Math.round(pct)}`;
}

export function setHangar(settings, catalog, combo, onEquip) {
  const count = el('ng-hangar-count');
  if (count) count.textContent = `${Number(combo || 0).toLocaleString()} combinations`;
  catalog.LOADOUT_CATS.forEach((cat) => {
    const row = el(`hangar-${cat}`);
    if (!row) return;
    const unlocks = settings.unlockedParts?.[cat] || [];
    const equipped = settings.loadout?.[cat];
    row.querySelectorAll('[data-part]').forEach((btn) => {
      const id = btn.getAttribute('data-part');
      const open = unlocks.includes(id);
      btn.classList.toggle('is-active', equipped === id);
      btn.classList.toggle('is-locked', !open);
      btn.setAttribute('aria-pressed', equipped === id ? 'true' : 'false');
      btn.setAttribute('aria-disabled', open ? 'false' : 'true');
      if (!btn._bound) {
        btn._bound = true;
        btn.addEventListener('click', (event) => {
          event.preventDefault();
          event.stopPropagation();
          onEquip(cat, id);
        });
      }
    });
  });
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
  const tod = el('ng-card-tod');
  if (title) title.textContent = `${flight.id} · ${flight.payload}`;
  if (blurb) blurb.textContent = flight.blurb || '';
  if (tod) {
    const label = flight.todLabel || flight.tod || '';
    tod.textContent = label ? `Pier 7 · ${label}` : '';
    tod.hidden = !label;
  }
}

export function isEmbedded() {
  try {
    return window.self !== window.top;
  } catch {
    return true;
  }
}
