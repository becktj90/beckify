import Phaser from './phaser-global.js';
import {
  DIFFICULTY,
  FUEL_MAX,
  H,
  JACKLYN_BONUS,
  JACKLYN_SALVAGE,
  OVERDRIVE_SEC,
  PAD_ROCKET_X,
  PAD_ROCKET_Y,
  PICKUP_TYPES,
  RADIO,
  SHIELD_MAX,
  SPLASH_PENALTY,
  TIPS,
  W,
} from './config.js';
import AudioApi from './audio.js';
import {
  bindChrome,
  hideScreens,
  isEmbedded,
  readSettingsForm,
  renderHud,
  setBanner,
  setDifficultyButtons,
  setMissionButtons,
  setOverlay,
  setSummaryCopy,
  showScreen,
  syncSettingsForm,
} from './hud.js';
import { bindKeyboard, createInput, isBoosting, setBoostHeld, steerAxis } from './input.js';
import { FIRST_MISSION, getMission, isUnlocked, nextMissionId } from './missions.js';
import { beatsFor, currentBeat, formatClock, T0_LEAD } from './sequence.js';
import { loadSettings, recordMissionResult, resetRecord, saveSettings } from './storage.js';
import { installTextures } from './textures.js';

const CAT_ROCKET = 0x0001;
const CAT_WORLD = 0x0002;
const CAT_DECK = 0x0004;
const CAT_WATER = 0x0008;
const CAT_HAZARD = 0x0010;
const CAT_PICKUP = 0x0020;

function clamp(n, a, b) {
  return Math.max(a, Math.min(b, n));
}

function rand(a, b) {
  return a + Math.random() * (b - a);
}

function pick(list) {
  return list[Math.floor(Math.random() * list.length)];
}

export default class MissionScene extends Phaser.Scene {
  constructor() {
    super('mission');
  }

  preload() {
    AudioApi.preload(this);
  }

  create() {
    this.settings = loadSettings();
    AudioApi.attach(this);
    this.inputState = createInput();
    this.status = 'MENU';
    this.paused = false;
    this.pausedForSettings = false;
    this.settingsOpen = false;
    this.screen = 'menu';
    this.nowSec = 0;
    this.tip = pick(TIPS);
    this.qaBeat = new URLSearchParams(window.location.search).get('beat');
    const qaMission = new URLSearchParams(window.location.search).get('mission');
    if (qaMission && getMission(qaMission).id === qaMission) {
      if (!this.settings.unlockedMissions.includes(qaMission)) {
        this.settings.unlockedMissions.push(qaMission);
      }
      this.settings.currentMission = qaMission;
      saveSettings(this.settings);
    }

    installTextures(this);
    this.matter.world.setGravity(0, 0);
    this.matter.world.setBounds(0, -4000, W, 5200, 32, false, false, false, false);

    this.bgSky = this.add.image(W / 2, -1480, 'ascent-sky').setDepth(-1);
    this.bgPad = this.add.image(W / 2, H / 2, 'pad').setDepth(0);
    this.bgOcean = this.add.image(W / 2, H / 2, 'ocean').setVisible(false).setDepth(0);
    this.jacklyn = this.add.image(W / 2, 620, 'jacklyn').setVisible(false).setDepth(2);
    this.smokeBank = this.add.image(W / 2, 620, 'smoke-bank').setVisible(false).setDepth(7).setAlpha(0);
    this.bloomFlash = this.add.image(W / 2, 620, 'bloom').setVisible(false).setDepth(8).setBlendMode('ADD').setAlpha(0);
    this.deck = this.matter.add.image(-2400, 2400, 'deck-pad', null, {
      isStatic: true,
      isSensor: true,
      label: 'deck',
    });
    this.deck.setVisible(false);
    this.deck.setCollisionCategory(CAT_DECK);
    this.deck.setCollidesWith(CAT_ROCKET);

    this.water = this.matter.add.rectangle(-2400, 2600, W + 200, 80, {
      isStatic: true,
      isSensor: true,
      label: 'water',
    });
    this.water.collisionFilter = { category: CAT_WATER, mask: CAT_ROCKET };

    this.rocket = this.matter.add.image(PAD_ROCKET_X, PAD_ROCKET_Y, 'rocket', null, {
      label: 'rocket',
      frictionAir: 0.02,
      density: 0.002,
    });
    this.rocket.setScale(1.18);
    this.bindRocketBody();
    this.rocket.setIgnoreGravity(true);

    const noopEmitter = { emitParticleAt() {}, setDepth() { return this; } };
    try {
      this.plume = this.add.particles(0, 0, 'spark', {
        lifespan: 280,
        speed: { min: 40, max: 120 },
        scale: { start: 0.7, end: 0 },
        emitting: false,
        blendMode: 'ADD',
        frequency: 16,
        quantity: 2,
        angle: { min: 70, max: 110 },
      });
      this.plume.setDepth(6);
    } catch {
      this.plume = noopEmitter;
    }
    try {
      this.bloomFx = this.add.particles(0, 0, 'bloom', {
        lifespan: 520,
        speed: { min: 8, max: 70 },
        scale: { start: 1.1, end: 0.15 },
        emitting: false,
        blendMode: 'ADD',
        frequency: 12,
        quantity: 4,
        alpha: { start: 1, end: 0 },
      });
    } catch {
      this.bloomFx = noopEmitter;
    }
    try {
      this.rcsFx = this.add.particles(0, 0, 'rcs', {
        lifespan: 180,
        speed: { min: 20, max: 60 },
        scale: { start: 0.6, end: 0 },
        emitting: false,
        quantity: 1,
      });
    } catch {
      this.rcsFx = noopEmitter;
    }
    try {
      this.sootFx = this.add.particles(0, 0, 'soot', {
        lifespan: 1400,
        speed: { min: 12, max: 46 },
        scale: { start: 1.2, end: 3.4 },
        emitting: false,
        frequency: 18,
        quantity: 5,
        alpha: { start: 0.85, end: 0 },
      });
    } catch {
      this.sootFx = { emitParticleAt() {} };
    }
    try {
      this.steam = this.add.particles(0, 0, 'steam', {
        lifespan: 700,
        speed: { min: 10, max: 40 },
        scale: { start: 0.8, end: 1.6 },
        emitting: false,
        frequency: 40,
        quantity: 1,
        alpha: { start: 0.45, end: 0 },
      });
    } catch {
      this.steam = noopEmitter;
    }

    this.hazards = [];
    this.pickups = [];
    this.floaters = [];
    this.debrisBits = [];

    this.menuLayer = this.add.container(0, 0).setDepth(20);
    this.buildMenu();

    this.matter.world.on('collisionstart', (event) => this.onCollision(event));

    this.cameras.main.setBounds(0, -3600, W, 4800);
    this.cameras.main.centerOn(W / 2, H / 2);

    bindKeyboard(this.inputState, {
      now: () => this.nowSec,
      unlock: () => AudioApi.unlock(this.settings),
      togglePause: () => this.togglePause(),
      toggleMute: () => this.toggleMute(),
      toggleSettings: () => this.toggleSettings(),
      onBoostTap: () => this.onPrimary(),
    });

    bindChrome({
      toggleMute: () => this.toggleMute(),
      togglePause: () => this.togglePause(),
      toggleSettings: () => this.toggleSettings(),
      toggleFullscreen: () => this.toggleFullscreen(),
      resetRecord: () => this.resetMissionRecord(),
      continueSummary: () => this.onPrimary(),
      play: () => this.startMission(),
      openMissions: () => this.openScreen('missions'),
      openHowto: () => this.openScreen('howto'),
      backToMenu: () => this.backToMenu(),
      closeSettings: () => this.closeSettings(),
      abortToMenu: () => this.abortToMenu(),
      steer: (dir, down) => {
        if (dir < 0) this.inputState.left = down;
        if (dir > 0) this.inputState.right = down;
      },
      boost: (down) => {
        if (down) this.onPrimary();
        setBoostHeld(this.inputState, down, this.nowSec);
      },
    });

    setDifficultyButtons(this.settings.difficulty, (mode) => this.setDifficulty(mode));
    setMissionButtons(this.settings, (id) => this.setMission(id));
    syncSettingsForm(this.settings);
    const form = document.getElementById('ng-settings');
    if (form) {
      form.addEventListener('input', () => {
        readSettingsForm(this.settings);
        saveSettings(this.settings);
        AudioApi.setMute(this.settings);
        this.refreshHud();
      });
    }

    document.body.classList.add('is-cabinet');
    if (isEmbedded()) document.body.classList.add('is-embedded');

    this.input.on('pointerdown', (pointer) => {
      AudioApi.unlock(this.settings);
      if (this.status === 'SUMMARY') this.onPrimary();
      else if (this.status !== 'MENU') this.inputState.pointerX = pointer.worldX;
    });
    this.input.on('pointermove', (pointer) => {
      if (pointer.isDown) this.inputState.pointerX = pointer.worldX;
    });
    this.input.on('pointerup', () => {
      this.inputState.pointerX = null;
    });

    window.arcadeToggleMute = () => this.toggleMute();
    window.arcadeTogglePause = () => this.togglePause();
    window.arcadeToggleSettings = () => this.toggleSettings();
    window.arcadeFullscreen = () => this.toggleFullscreen();
    window.arcadeReset = () => this.resetMissionRecord();

    if (this.qaBeat === 'jacklyn') {
      this.session = this.freshSession();
      this.session.tClock = 36.5;
      for (const beat of this.session.beats) {
        if (beat.t < 36) this.session.fired[beat.id] = true;
      }
      this.paused = false;
      this.pausedForSettings = false;
      this.syncMatterPause();
      this.menuLayer.setVisible(false);
      hideScreens();
      this.enterJacklyn();
    }

    this.refreshMenuCopy();
    this.refreshHud();
  }

  buildMenu() {
    const shade = this.add.rectangle(W / 2, H / 2, W, H, 0x05060f, 0.18);
    this.menuLayer.add([shade]);
  }

  freshSession() {
    const beats = beatsFor(this.currentFlight());
    return {
      score: 0,
      combo: 0,
      bestCombo: 0,
      fuel: FUEL_MAX,
      throttle: 0,
      shield: 0,
      overdrive: 0,
      grace: DIFFICULTY[this.settings.difficulty].graceSec,
      altitudeKm: 0,
      velocity: 0,
      stage: 'PAD',
      charge: 0,
      radio: RADIO.PAD,
      failReason: '',
      recovered: false,
      splash: false,
      salvage: false,
      hits: 0,
      spawnAt: 1.8,
      flightTime: 0,
      landingLock: false,
      jacklynPhase: 'slide',
      jacklynReadyAt: 0,
      jacklynElapsed: 0,
      objectiveDone: false,
      comboReady: false,
      tClock: -T0_LEAD,
      beats,
      fired: Object.create(null),
      sepDone: false,
      upperDone: false,
      hintUntil: 3.2,
    };
  }

  startMission() {
    AudioApi.unlock(this.settings);
    this.session = this.freshSession();
    this.status = 'PRELAUNCH';
    this.session.stage = 'TERMINAL COUNT';
    this.paused = false;
    this.pausedForSettings = false;
    this.settingsOpen = false;
    this.screen = 'play';
    this.syncMatterPause();
    AudioApi.stopBeds();
    this.menuLayer.setVisible(false);
    hideScreens();
    this.clearActors();
    this.clearDebris();
    this.bgSky.setVisible(true);
    this.bgPad.setVisible(true);
    this.bgOcean.setVisible(false);
    this.jacklyn.setVisible(false);
    this.hideLandingFx();
    this.parkRecovery();
    this.applyRocketSkin();
    this.rocket.setPosition(PAD_ROCKET_X, PAD_ROCKET_Y);
    this.rocket.setVelocity(0, 0);
    this.rocket.setAngle(0);
    this.rocket.setFrictionAir(0.02);
    this.rocket.setIgnoreGravity(true);
    this.matter.world.setGravity(0, 0);
    this.cameras.main.stopFollow();
    this.cameras.main.setZoom(1);
    this.cameras.main.centerOn(W / 2, H / 2);
    this.bgOcean.clearTint();
    setBanner('TERMINAL COUNT — hold climb through ignition', 'info', 2400);
    AudioApi.play('countdown', this.settings);
    this.refreshHud();
  }

  onPrimary() {
    AudioApi.unlock(this.settings);
    if (this.status === 'MENU') {
      if (this.screen === 'menu' && !this.settingsOpen) this.startMission();
      return;
    }
    if (this.status === 'SUMMARY') {
      this.returnToMenu();
    }
  }

  returnToMenu() {
    this.status = 'MENU';
    this.screen = 'menu';
    this.paused = false;
    this.pausedForSettings = false;
    this.settingsOpen = false;
    this.syncMatterPause();
    this.menuLayer.setVisible(true);
    hideScreens();
    showScreen('ng-menu');
    this.tip = pick(TIPS);
    this.cameras.main.stopFollow();
    this.cameras.main.setZoom(1);
    this.cameras.main.centerOn(W / 2, H / 2);
    this.bgSky.setVisible(true);
    this.bgPad.setVisible(true);
    this.bgOcean.setVisible(false);
    this.bgOcean.clearTint();
    this.jacklyn.setVisible(false);
    this.hideLandingFx();
    this.parkRecovery();
    this.applyRocketSkin();
    this.rocket.setPosition(PAD_ROCKET_X, PAD_ROCKET_Y);
    this.rocket.setAngle(0);
    this.rocket.setVelocity(0, 0);
    this.refreshMenuCopy();
    this.refreshHud();
  }

  liftoff() {
    if (this.status === 'ASCENT') return;
    this.status = 'ASCENT';
    this.session.stage = 'LIFTOFF';
    this.session.radio = RADIO.LIFTOFF;
    this.session.throttle = 1;
    this.session.tClock = Math.max(this.session.tClock, 0);
    this.rocket.setIgnoreGravity(false);
    this.matter.world.setGravity(0, 0.22);
    if (this.session.grace > 1.2) this.time.delayedCall(360, () => this.spawnPickup());
    this.cameras.main.startFollow(this.rocket, true, 0.12, 0.16);
    this.cameras.main.setDeadzone(40, 24);
    this.cameras.main.setZoom(this.settings.reducedMotion ? 1 : 0.92);
    if (!this.settings.reducedMotion) this.cameras.main.shake(260, 0.007);
    AudioApi.play('liftoff', this.settings);
    AudioApi.setBed('roar', true, this.settings, 0.42);
    setBanner('LIFTOFF', 'go', 1500);
    this.vibrate(30);
    this.tickCombo(1, 'LIFTOFF');
  }

  enterJacklyn() {
    const flight = this.currentFlight();
    this.status = 'JACKLYN';
    this.session.stage = 'JACKLYN';
    this.session.radio = RADIO.JACKLYN;
    this.session.landingLock = false;
    this.session.jacklynPhase = 'slide';
    this.clearActors();
    this.bgSky.setVisible(false);
    this.bgPad.setVisible(false);
    this.bgOcean.setVisible(true);
    this.bgOcean.setTint(flight.seaTint || 0xffffff);
    this.jacklyn.setVisible(true);
    this.placeRecovery();
    this.hideLandingFx();
    this.rocket.setTexture('booster');
    this.bindRocketBody();
    this.rocket.setDepth(5);
    const side = flight.lzOffset >= 0 ? -1 : 1;
    this.session.jacklynReadyAt = this.nowSec + 0.85;
    this.session.jacklynElapsed = 0;
    this.rocket.setFrictionAir(0.045);
    this.rocket.setPosition(W / 2 + side * 520, 40);
    this.rocket.setVelocity(side * -3.4, 1.45);
    this.rocket.setAngle(side * -34);
    this.rocket.setIgnoreGravity(false);
    this.matter.world.setGravity(0, 0.28);
    this.cameras.main.stopFollow();
    this.cameras.main.setZoom(0.72);
    this.cameras.main.centerOn(W / 2, 260);
    if (flight.objective?.id === 'clean' && this.session.hits === 0) this.completeObjective();
    AudioApi.stopBeds();
    AudioApi.play('meco', this.settings);
    AudioApi.play('whoosh', this.settings);
    setBanner('JACKLYN — slide in, RCS straighten, brake the deck', 'warn', 2600);
  }

  update(_time, delta) {
    const dt = Math.min(0.033, delta / 1000);
    this.nowSec += dt;
    if (this.paused || this.settingsOpen) {
      this.refreshHud();
      return;
    }
    if (this.status === 'PRELAUNCH') this.updatePrelaunch(dt);
    else if (this.status === 'ASCENT') this.updateAscent(dt);
    else if (this.status === 'JACKLYN') this.updateJacklyn(dt);
    this.updateFloaters(dt);
    this.refreshHud();
  }

  updatePrelaunch(dt) {
    this.session.tClock += dt;
    this.fireDueBeats();
    const boosting = isBoosting(this.inputState, this.nowSec);
    this.session.charge = clamp(this.session.charge + (boosting ? dt * 0.7 : dt * 0.12), 0, 1);
    this.session.throttle = this.session.charge;
    this.rocket.setPosition(PAD_ROCKET_X, PAD_ROCKET_Y - this.session.charge * 6);
    this.rocket.setVelocity(0, 0);
    if (this.session.fired.deluge && this.steam) {
      this.steam.emitParticleAt(PAD_ROCKET_X, PAD_ROCKET_Y + 118, this.settings.reducedMotion ? 1 : 3);
    }
    if (this.session.fired.ignition) this.emitPlume(0.55);
    if (this.session.tClock >= 0 && this.session.fired.ignition) this.liftoff();
    else if (this.session.tClock >= 0.35) this.liftoff();
  }

  updateAscent(dt) {
    const mode = DIFFICULTY[this.settings.difficulty];
    this.session.flightTime += dt;
    this.session.grace = Math.max(0, this.session.grace - dt);
    this.session.overdrive = Math.max(0, this.session.overdrive - dt);
    this.session.tClock += dt;
    this.fireDueBeats();

    const boosting = isBoosting(this.inputState, this.nowSec);
    const kick = (this.session.overdrive > 0 ? 1.28 : 1) * (mode.thrust || 1);
    if (boosting && this.session.fuel > 0) {
      this.session.fuel = Math.max(0, this.session.fuel - mode.fuelDrain * 20 * dt);
      this.session.throttle = clamp(this.session.throttle + dt * 3.2, 0.28, 1);
    } else {
      this.session.throttle = clamp(this.session.throttle - dt * 1.4, 0, 0.12);
    }

    let axis = steerAxis(this.inputState);
    if (this.inputState.pointerX != null) {
      axis = clamp((this.inputState.pointerX - this.rocket.x) / 140, -1, 1);
    }
    const thrust = this.session.throttle * kick;
    if (thrust > 0.08 && this.session.fuel > 0) {
      this.rocket.applyForce({ x: axis * 0.02, y: -0.052 * thrust });
      const vy = this.rocket.body.velocity.y;
      if (vy > -1.35) this.rocket.setVelocityY(-1.35);
      if (vy < -6.4) this.rocket.setVelocityY(-6.4);
      this.emitPlume(thrust);
      AudioApi.rumble(0.35 + thrust * 0.4, this.settings);
    } else {
      this.rocket.applyForce({ x: axis * 0.006, y: 0.01 });
      if (this.rocket.body.velocity.y > 4.2) this.rocket.setVelocityY(4.2);
    }

    this.rocket.setAngularVelocity(0);
    this.rocket.setAngle(clamp(this.rocket.body.velocity.x * 4 + axis * 6, -18, 18));
    this.rocket.x = clamp(this.rocket.x, 80, W - 80);

    const vy = this.rocket.body.velocity.y;
    this.session.velocity = Math.max(0, Math.round((-vy) * 110 + this.session.tClock * 28));
    this.session.altitudeKm = clamp(this.session.tClock * 1.65, 0, 85);
    this.bgPad.setVisible(this.rocket.y > 80);
    this.session.score += Math.max(0, (-vy) * 26 * dt * (1 + this.session.combo * 0.1));

    this.session.spawnAt -= dt;
    if (this.session.spawnAt <= 0 && this.session.grace <= 0 && !this.session.fired.meco) {
      this.spawnHazard();
      if (Math.random() < 0.3 * mode.pickupMul) this.spawnPickup();
      this.session.spawnAt = rand(0.62, 1.2) / (mode.spawnMul * this.currentFlight().spawnMul);
    }
    this.advanceActors();

    if (this.session.fired.meco && !this.session.sepDone) {
      this.session.sepDone = true;
      this.playStageSep();
    }

    if (this.rocket.y > 620 && this.session.altitudeKm < 1.2 && this.session.flightTime > 2.4) {
      this.session.failReason = 'Lost the corridor — fell back toward the pad';
      this.session.radio = RADIO.RUD;
      AudioApi.play('rud', this.settings);
      setBanner(`RUD — ${this.session.failReason}`, 'fail', 0);
      this.endMission('rud');
    }
  }

  updateJacklyn(dt) {
    if (this.session.landingLock) {
      this.session.tClock += dt;
      this.fireDueBeats();
      return;
    }
    const mode = DIFFICULTY[this.settings.difficulty];
    this.session.jacklynElapsed = (this.session.jacklynElapsed || 0) + dt;
    this.session.tClock += dt;
    this.fireDueBeats();
    const boosting = isBoosting(this.inputState, this.nowSec);
    let axis = steerAxis(this.inputState);
    if (this.inputState.pointerX != null) {
      axis = clamp((this.inputState.pointerX - this.rocket.x) / 160, -1, 1);
    }
    const deckX = this.deck.x;
    const assist = this.qaBeat === 'jacklyn' ? Math.max(mode.assist, 0.5) : mode.assist;
    if (assist > 0) {
      const err = (deckX - this.rocket.x) / 220;
      axis = clamp(axis + err * assist, -1, 1);
    }

    const alt = this.jacklyn.y - 50 - this.rocket.y;
    if (alt < 95 && this.session.jacklynPhase === 'slide') {
      this.session.jacklynPhase = 'straighten';
      this.emitRcs();
      setBanner('RCS — straighten for the deck', 'info', 1400);
    }
    if (alt < 55) this.session.jacklynPhase = 'settle';

    const wantAngle = this.session.jacklynPhase === 'slide'
      ? clamp(this.rocket.body.velocity.x * 2.6, -34, 34)
      : 0;
    const nowAngle = this.rocket.angle || 0;
    const slew = this.session.jacklynPhase === 'slide' ? 2.2 : 5.2;
    const nextAngle = nowAngle + (wantAngle - nowAngle) * Math.min(1, dt * slew);
    if (Math.abs(nextAngle - nowAngle) > 0.8) this.emitRcs();
    this.rocket.setAngularVelocity(0);
    this.rocket.setAngle(nextAngle);

    if (boosting && this.session.fuel > 0) {
      this.session.fuel = Math.max(0, this.session.fuel - mode.fuelDrain * 16 * dt);
      this.rocket.applyForce({ x: axis * 0.022, y: -0.05 });
      this.session.throttle = 1;
      this.emitPlume(1);
      if (alt < 180) this.emitBloom();
      AudioApi.setBed('burn', true, this.settings, 0.38);
      if (alt > 110 && this.rocket.body.velocity.y < 2.2) this.rocket.setVelocityY(2.2);
      else if (alt > 18 && this.rocket.body.velocity.y < 0.75) this.rocket.setVelocityY(0.75);
    } else {
      this.rocket.applyForce({ x: axis * 0.01, y: 0.008 });
      this.session.throttle = 0.12;
      AudioApi.setBed('burn', false, this.settings);
    }
    if (this.session.jacklynElapsed < 1.6 && this.rocket.body.velocity.y > 3.4) {
      this.rocket.setVelocityY(3.4);
    }
    if (this.rocket.body.velocity.y > 8.4) this.rocket.setVelocityY(8.4);
    if (this.rocket.body.velocity.y < -1.1) this.rocket.setVelocityY(-1.1);
    this.rocket.x = clamp(this.rocket.x, 80, W - 80);
    this.session.velocity = Math.round(this.rocket.body.velocity.y * 42);
    this.session.altitudeKm = clamp(alt / 90, 0, 8);
    if (this.rocket.y > 720) this.resolveLanding('water');
  }

  fireDueBeats() {
    if (!this.session?.beats) return;
    for (const beat of this.session.beats) {
      if (this.session.fired[beat.id]) continue;
      if (this.session.tClock + 0.02 < beat.t) continue;
      if (beat.id === 'liftoff' && this.status === 'PRELAUNCH') continue;
      if (beat.id === 'touchdown' && !this.session.landingLock) continue;
      if ((beat.id === 'seco' || beat.id === 'deploy') && !this.session.landingLock) continue;
      this.session.fired[beat.id] = true;
      this.onBeat(beat);
    }
  }

  onBeat(beat) {
    this.session.stage = beat.stage;
    this.session.radio = beat.radio;
    if (beat.id !== 'touchdown') {
      setBanner(beat.banner, beat.kind, beat.id === 'deploy' ? 2800 : 1600);
    }
    if (beat.juice === 'maxq') AudioApi.play('maxq', this.settings);
    if (beat.juice === 'meco') AudioApi.play('meco', this.settings);
    if (beat.juice === 'ignition') {
      AudioApi.play('liftoff', this.settings);
      if (!this.settings.reducedMotion) this.cameras.main.shake(180, 0.004);
    }
    if (beat.juice === 'deluge' && this.steam) {
      this.steam.emitParticleAt(PAD_ROCKET_X, PAD_ROCKET_Y + 120, 8);
    }
    if (beat.juice === 'fairing') this.playFairingJettison();
    if (beat.juice === 'ses') this.spawnUpperStage();
    if (beat.id !== 'liftoff' && beat.id !== 'touchdown') this.tickCombo(1, beat.banner);
    if (beat.id === 'deploy') this.session.upperDone = true;
  }

  playStageSep() {
    this.spawnUpperStage();
    this.playFairingJettison();
    this.time.delayedCall(420, () => {
      if (this.status === 'ASCENT') this.enterJacklyn();
    });
  }

  spawnUpperStage() {
    if (this.upperStage && this.upperStage.active) return;
    const x = this.rocket.x;
    const y = this.rocket.y - 90;
    this.upperStage = this.add.image(x, y, 'upper-stage').setDepth(4);
    this.tweens.add({
      targets: this.upperStage,
      y: y - 420,
      x: x + 40,
      alpha: 0.15,
      duration: this.settings.reducedMotion ? 400 : 1100,
      onComplete: () => this.upperStage?.destroy(),
    });
  }

  playFairingJettison() {
    const x = this.rocket.x;
    const y = this.rocket.y - 70;
    const left = this.add.image(x - 8, y, 'fairing-l').setDepth(5);
    const right = this.add.image(x + 8, y, 'fairing-r').setDepth(5);
    this.debrisBits.push(left, right);
    this.tweens.add({
      targets: left,
      x: x - 160,
      y: y + 80,
      angle: -50,
      alpha: 0,
      duration: this.settings.reducedMotion ? 280 : 900,
      onComplete: () => left.destroy(),
    });
    this.tweens.add({
      targets: right,
      x: x + 160,
      y: y + 80,
      angle: 50,
      alpha: 0,
      duration: this.settings.reducedMotion ? 280 : 900,
      onComplete: () => right.destroy(),
    });
    AudioApi.play('whoosh', this.settings);
  }

  onCollision(event) {
    if (this.session && this.session.landingLock) return;
    event.pairs.forEach((pair) => {
      const labels = [pair.bodyA.label, pair.bodyB.label];
      const other = pair.bodyA.label === 'rocket' ? pair.bodyB : pair.bodyA;
      if (!labels.includes('rocket')) return;
      if (other.label === 'deck' && this.status === 'JACKLYN') {
        this.resolveLanding('deck');
      } else if (other.label === 'water' && this.status === 'JACKLYN') {
        this.resolveLanding('water');
      } else if (other.label && other.label.startsWith('hazard')) {
        this.hitHazard(other.gameObject);
      } else if (other.label && other.label.startsWith('pickup')) {
        this.collectPickup(other.gameObject);
      }
    });
  }

  resolveLanding(kind) {
    if (this.session.landingLock) return;
    if (kind === 'deck' && this.nowSec < (this.session.jacklynReadyAt || 0)) return;
    this.session.landingLock = true;
    const mode = DIFFICULTY[this.settings.difficulty];
    const vy = Math.abs(this.rocket.body.velocity.y);
    const onPaint = kind === 'deck';
    const soft = vy <= mode.landingVy;
    this.rocket.setVelocity(0, 0);
    this.rocket.setIgnoreGravity(true);

    if (kind === 'deck' && onPaint && soft) {
      this.session.recovered = true;
      this.session.score += JACKLYN_BONUS;
      if (this.currentFlight().objective?.id === 'recover') this.completeObjective();
      if (this.currentFlight().objective?.id === 'recover-combo' && this.session.comboReady) this.completeObjective();
      this.session.combo += 2;
      this.session.bestCombo = Math.max(this.session.bestCombo, this.session.combo);
      this.session.radio = RADIO.RECOVERED;
      this.rocket.setPosition(this.jacklyn.x, this.jacklyn.y - 118);
      this.rocket.setAngle(0);
      this.playRecoveredSpectacle();
      AudioApi.stopBeds();
      AudioApi.play('touchdown', this.settings);
      AudioApi.play('recovered', this.settings);
      setBanner(`BOOSTER RECOVERED — ${this.currentFlight().jacklyn.recovered}`, 'go', 3600);
      this.vibrate([40, 30, 40]);
      this.session.tClock = Math.max(this.session.tClock, 51.5);
      this.session.fired.touchdown = true;
      this.time.delayedCall(2400, () => this.finishUpper());
      return;
    }

    if (kind === 'deck') {
      this.session.salvage = true;
      this.session.score += JACKLYN_SALVAGE;
      this.session.combo = 0;
      this.session.radio = RADIO.SALVAGE;
      this.rocket.setPosition(this.jacklyn.x + clamp(this.rocket.x - this.jacklyn.x, -40, 40), this.jacklyn.y - 74);
      AudioApi.stopBeds();
      AudioApi.play('hit', this.settings);
      setBanner(this.currentFlight().jacklyn.salvage, 'warn', 2800);
      this.time.delayedCall(1400, () => this.finishUpper());
      return;
    }

    this.session.splash = true;
    this.session.score = Math.max(0, this.session.score - SPLASH_PENALTY);
    this.session.combo = 0;
    this.session.radio = RADIO.SPLASH;
    AudioApi.stopBeds();
    AudioApi.play('splash', this.settings);
    setBanner(this.currentFlight().jacklyn.splash, 'fail', 2800);
    this.time.delayedCall(1300, () => this.finishUpper());
  }

  finishUpper() {
    if (this.status === 'SUMMARY') return;
    this.session.tClock = Math.max(this.session.tClock, 54);
    this.fireDueBeats();
    this.time.delayedCall(900, () => {
      this.session.tClock = Math.max(this.session.tClock, 57.4);
      this.fireDueBeats();
      const reason = this.session.recovered ? 'recovered' : this.session.salvage ? 'salvage' : 'splash';
      this.time.delayedCall(700, () => this.endMission(reason));
    });
  }

  spawnHazard() {
    const mode = DIFFICULTY[this.settings.difficulty];
    const mix = this.currentFlight().hazards || ['bird', 'balloon', 'ice'];
    const kind = this.session.altitudeKm < 8 ? pick(['bird', 'balloon', mix[0]]) : pick(mix);
    const x = clamp(this.rocket.x + rand(-220, 220), 70, W - 70);
    const y = this.rocket.y - rand(280, 420);
    const img = this.matter.add.image(x, y, kind, null, {
      isSensor: true,
      label: `hazard-${kind}`,
    });
    img.setCollisionCategory(CAT_HAZARD);
    img.setCollidesWith(CAT_ROCKET);
    img.setIgnoreGravity(true);
    img.setVelocity(rand(-0.4, 0.4), rand(0.6, 1.6));
    img.setScale(mode.hitboxScale + 0.35);
    this.hazards.push(img);
  }

  spawnPickup() {
    const kind = pick(PICKUP_TYPES);
    const x = clamp(this.rocket.x + rand(-180, 180), 80, W - 80);
    const y = this.rocket.y - rand(240, 380);
    const img = this.matter.add.image(x, y, `pickup-${kind}`, null, {
      isSensor: true,
      label: `pickup-${kind}`,
    });
    img.setCollisionCategory(CAT_PICKUP);
    img.setCollidesWith(CAT_ROCKET);
    img.setIgnoreGravity(true);
    img.setVelocity(0, 0.7);
    img.pickupKind = kind;
    this.pickups.push(img);
  }

  advanceActors() {
    const prune = (list) => {
      for (let i = list.length - 1; i >= 0; i--) {
        const item = list[i];
        if (!item.active || item.y > this.rocket.y + 520) {
          item.destroy();
          list.splice(i, 1);
        }
      }
    };
    prune(this.hazards);
    prune(this.pickups);
  }

  hitHazard(obj) {
    if (!obj || this.status !== 'ASCENT') return;
    const mode = DIFFICULTY[this.settings.difficulty];
    if (this.session.grace > 0) {
      obj.destroy();
      return;
    }
    if (this.session.shield > 0) {
      this.session.shield -= 1;
      obj.destroy();
      AudioApi.play('shield', this.settings);
      setBanner('AERO SHIELD ABSORBED THE HIT', 'info', 1400);
      this.session.combo = 0;
      return;
    }
    if (!mode.allowFail) {
      obj.destroy();
      this.session.combo = 0;
      AudioApi.play('hit', this.settings);
      setBanner('CLOSE CALL — KID mode keeps you flying', 'warn', 900);
      return;
    }
    this.session.hits += 1;
    obj.destroy();
    if (!this.settings.reducedFlashes && !this.settings.reducedMotion) {
      this.cameras.main.flash(80, 40, 8, 8);
    }
    AudioApi.play('hit', this.settings);
    if (this.session.hits >= (this.settings.difficulty === 'PAD_RAT' ? 1 : 2)) {
      this.session.failReason = 'Corridor impact — vehicle lost';
      this.session.radio = RADIO.RUD;
      AudioApi.play('rud', this.settings);
      setBanner(`RUD — ${this.session.failReason}`, 'fail', 0);
      this.endMission('rud');
    } else {
      this.session.combo = 0;
      setBanner('STRUCTURAL HIT — one more and it is RUD', 'fail', 1600);
    }
  }

  collectPickup(obj) {
    if (!obj) return;
    const kind = obj.pickupKind || 'fuel';
    const x = obj.x;
    const y = obj.y;
    obj.destroy();
    this.tickCombo(1, 'COMBO');
    this.session.score += 180 * this.session.combo;
    this.addFloater(x, y, `+${180 * this.session.combo}`, '#ffcf5d');
    const objectiveId = this.currentFlight().objective?.id;
    if (objectiveId === 'combo4' && this.session.combo >= 4) this.completeObjective();
    if (objectiveId === 'recover-combo' && this.session.combo >= 3) this.session.comboReady = true;
    if (kind === 'shield') {
      this.session.shield = Math.min(SHIELD_MAX, this.session.shield + 1);
      AudioApi.play('shield', this.settings);
      setBanner('AERO SHIELD', 'info', 900);
      if (this.currentFlight().objective?.id === 'shield') this.completeObjective();
    } else if (kind === 'fuel') {
      this.session.fuel = Math.min(FUEL_MAX, this.session.fuel + 28);
      AudioApi.play('fuel', this.settings);
      setBanner('LOX TOP-OFF', 'info', 900);
    } else {
      this.session.overdrive = OVERDRIVE_SEC;
      AudioApi.play('overdrive', this.settings);
      setBanner('BE-4 KICK', 'go', 900);
    }
  }

  tickCombo(n, label) {
    this.session.combo += n;
    this.session.bestCombo = Math.max(this.session.bestCombo, this.session.combo);
    this.session.score += 80 * this.session.combo;
    if (this.session.combo === 1 && label === 'COMBO') {
      setBanner('COMBO — stay clean and keep the tape green', 'info', 1200);
    }
  }

  addFloater(x, y, text, color) {
    const node = this.add.text(x, y, text, {
      fontFamily: '"IBM Plex Mono", ui-monospace, monospace',
      fontSize: '16px',
      fontStyle: 'bold',
      color,
    }).setOrigin(0.5).setDepth(12);
    this.floaters.push(node);
    this.tweens.add({
      targets: node,
      y: y - 46,
      alpha: 0,
      duration: this.settings.reducedMotion ? 240 : 700,
      onComplete: () => node.destroy(),
    });
  }

  emitPlume(power) {
    if (this.settings.reducedMotion) return;
    const n = power > 0.7 ? 4 : 1;
    this.plume.emitParticleAt(this.rocket.x, this.rocket.y + 108, n);
  }

  emitRcs() {
    if (this.settings.reducedMotion || !this.rcsFx) return;
    this.rcsFx.emitParticleAt(this.rocket.x + 22, this.rocket.y - 96, 3);
    this.rcsFx.emitParticleAt(this.rocket.x - 22, this.rocket.y - 96, 3);
  }

  emitBloom() {
    if (!this.bloomFx) return;
    const n = this.settings.reducedMotion ? 3 : 14;
    this.bloomFx.emitParticleAt(this.rocket.x, this.rocket.y + 90, n);
    if (this.sootFx) this.sootFx.emitParticleAt(this.jacklyn.x, this.jacklyn.y - 8, this.settings.reducedMotion ? 6 : 22);
  }

  hideLandingFx() {
    if (this.smokeBank) {
      this.smokeBank.setVisible(false).setAlpha(0);
    }
    if (this.bloomFlash) {
      this.bloomFlash.setVisible(false).setAlpha(0).setScale(1);
    }
  }

  playRecoveredSpectacle() {
    this.emitBloom();
    if (this.bloomFlash) {
      this.bloomFlash.setPosition(this.jacklyn.x, this.jacklyn.y - 20);
      this.bloomFlash.setVisible(true).setAlpha(1).setScale(2.4);
      this.tweens.add({
        targets: this.bloomFlash,
        alpha: 0,
        scale: 3.2,
        duration: this.settings.reducedMotion ? 280 : 700,
        onComplete: () => this.bloomFlash.setVisible(false),
      });
    }
    if (this.smokeBank) {
      this.smokeBank.setPosition(this.jacklyn.x, this.jacklyn.y - 28);
      this.smokeBank.setVisible(true).setAlpha(0).setScale(1.05);
      this.tweens.add({
        targets: this.smokeBank,
        alpha: this.settings.reducedMotion ? 0.55 : 0.96,
        scale: 1.18,
        duration: 220,
      });
    }
    if (this.sootFx) this.sootFx.emitParticleAt(this.jacklyn.x, this.jacklyn.y - 10, 28);
    if (!this.settings.reducedMotion) {
      this.cameras.main.shake(220, 0.005);
      this.time.timeScale = 0.55;
      this.time.delayedCall(360, () => { this.time.timeScale = 1; });
    }
    this.time.delayedCall(900, () => {
      if (!this.settings.reducedMotion) this.cameras.main.zoomTo(1.16, 640);
      if (this.smokeBank) {
        this.tweens.add({
          targets: this.smokeBank,
          alpha: 0.42,
          duration: 700,
        });
      }
    });
  }

  completeObjective() {
    if (this.session.objectiveDone) return;
    this.session.objectiveDone = true;
    this.session.score += 400;
    setBanner(`SECONDARY — ${this.currentFlight().objective.label}`, 'go', 1600);
  }

  updateFloaters() {
    this.floaters = this.floaters.filter((node) => node.active);
  }

  clearActors() {
    [...this.hazards, ...this.pickups].forEach((item) => item.destroy());
    this.hazards = [];
    this.pickups = [];
  }

  clearDebris() {
    this.debrisBits.forEach((bit) => bit.destroy());
    this.debrisBits = [];
    if (this.upperStage) {
      this.upperStage.destroy();
      this.upperStage = null;
    }
  }

  endMission(reason) {
    if (this.status === 'SUMMARY') return;
    this.status = 'SUMMARY';
    this.session.stage = 'SUMMARY';
    this.rocket.setVelocity(0, 0);
    this.rocket.setIgnoreGravity(true);
    const points = Math.max(0, Math.round(this.session.score));
    this.settings.lastArcadeScore = points;
    if (!this.settings.hiArcadeScore || points >= this.settings.hiArcadeScore) {
      this.settings.hiArcadeScore = points;
    }
    this.settings.missionCount += 1;
    this.settings.bestFlight = {
      score: points,
      arcade: points,
      recovered: this.session.recovered,
      reason,
      difficulty: this.settings.difficulty,
      mission: this.currentFlight().id,
      payload: this.currentFlight().payload,
    };
    recordMissionResult(this.settings, this.currentFlight().id, points, this.session.recovered);
    const nxt = reason === 'rud' ? null : nextMissionId(this.currentFlight().id);
    const unlockedNext = nxt && !this.settings.unlockedMissions.includes(nxt);
    if (unlockedNext) this.settings.unlockedMissions.push(nxt);
    saveSettings(this.settings);
    setMissionButtons(this.settings, (id) => this.setMission(id));
    if (typeof window.recordGameScore === 'function') {
      window.recordGameScore('new-glenn-runner', points);
    }
    const headline = reason === 'recovered'
      ? this.currentFlight().jacklyn.recovered
      : reason === 'splash'
        ? this.currentFlight().jacklyn.splash
        : reason === 'salvage'
          ? this.currentFlight().jacklyn.salvage
          : 'MISSION ABORT';
    const extra = unlockedNext ? `  ·  ${nxt} UNLOCKED` : '';
    AudioApi.stopBeds();
    AudioApi.play(reason === 'rud' ? 'rud' : 'success', this.settings);
    setBanner(`${this.currentFlight().id}  ${headline}   SCORE ${points.toLocaleString()}${extra}`, reason === 'rud' ? 'fail' : 'go', 0);
    setSummaryCopy(
      `${this.currentFlight().id}  ${headline}`,
      `${this.currentFlight().payload}\nScore ${points.toLocaleString()}  ·  Combo peak ×${this.session.bestCombo}${extra}\n${this.session.upperDone ? 'SECO + payload deploy — good flight.\n' : ''}Tap continue or press Space`,
    );
    hideScreens();
    setOverlay('ng-summary', true);
    this.cameras.main.stopFollow();
    this.refreshHud();
  }

  /**
   * Phaser MatterPhysics.pause/resume → world.enabled.
   * Physics stops only when paused === true (settings mid-flight sets that flag).
   */
  syncMatterPause() {
    if (this.paused === true) this.matter.pause();
    else this.matter.resume();
  }

  /**
   * setBody / setRectangle wipe mass, friction, and collision filters.
   * Re-apply after any reshape. Positions are center-of-mass.
   */
  bindRocketBody() {
    this.rocket.setFrictionAir(0.02);
    this.rocket.setCollisionCategory(CAT_ROCKET);
    this.rocket.setCollidesWith(CAT_DECK | CAT_WATER | CAT_HAZARD | CAT_PICKUP);
    this.rocket.setFixedRotation();
  }

  inFlight() {
    return this.status === 'PRELAUNCH' || this.status === 'ASCENT' || this.status === 'JACKLYN';
  }

  togglePause() {
    if (this.status === 'MENU' || this.status === 'SUMMARY') return;
    this.paused = !this.paused;
    this.pausedForSettings = false;
    this.syncMatterPause();
    AudioApi.setPaused(this.paused);
    if (this.paused) {
      hideScreens();
      setOverlay('ng-pause', true);
    } else {
      setOverlay('ng-pause', false);
      setOverlay('ng-howto', false);
    }
    setBanner(this.paused ? 'PAUSED' : 'RESUMED', 'info', 900);
    this.refreshHud();
  }

  toggleMute() {
    this.settings.muted = !this.settings.muted;
    AudioApi.setMute(this.settings);
    saveSettings(this.settings);
    syncSettingsForm(this.settings);
    this.refreshHud();
  }

  toggleSettings() {
    this.settingsOpen = !this.settingsOpen;
    if (this.settingsOpen) {
      syncSettingsForm(this.settings);
      setOverlay('ng-settings', true);
      if (this.inFlight() && this.paused !== true) {
        this.paused = true;
        this.pausedForSettings = true;
        this.syncMatterPause();
        AudioApi.setPaused(true);
      }
    } else {
      this.closeSettings();
    }
  }

  closeSettings() {
    this.settingsOpen = false;
    setOverlay('ng-settings', false);
    if (this.pausedForSettings) {
      this.pausedForSettings = false;
      this.paused = false;
      this.syncMatterPause();
      AudioApi.setPaused(false);
      setOverlay('ng-pause', false);
    } else if (this.status === 'MENU') {
      showScreen(this.screen === 'missions' ? 'ng-missions' : this.screen === 'howto' ? 'ng-howto' : 'ng-menu');
    } else if (this.paused) {
      setOverlay('ng-pause', true);
    }
  }

  openScreen(name) {
    AudioApi.unlock(this.settings);
    this.screen = name;
    if (name === 'howto' && this.inFlight()) {
      if (this.paused !== true) {
        this.paused = true;
        this.pausedForSettings = false;
        this.syncMatterPause();
        AudioApi.setPaused(true);
      }
      hideScreens();
      setOverlay('ng-howto', true);
      return;
    }
    if (name === 'missions') showScreen('ng-missions');
    else if (name === 'howto') showScreen('ng-howto');
    else showScreen('ng-menu');
  }

  backToMenu() {
    if (this.inFlight()) {
      setOverlay('ng-howto', false);
      setOverlay('ng-pause', true);
      return;
    }
    this.screen = 'menu';
    showScreen('ng-menu');
  }

  abortToMenu() {
    AudioApi.stopBeds();
    this.paused = false;
    this.pausedForSettings = false;
    this.settingsOpen = false;
    this.syncMatterPause();
    this.returnToMenu();
  }

  toggleFullscreen() {
    const wrap = document.getElementById('arcade-fs-wrapper');
    if (!wrap) return;
    const active = document.fullscreenElement === wrap;
    if (active) document.exitFullscreen?.();
    else wrap.requestFullscreen?.();
    wrap.classList.toggle('arcade-immersive', !active);
    document.documentElement.classList.toggle('arcade-immersive-open', !active);
    this.time.delayedCall(80, () => this.scale.refresh());
  }

  currentFlight() {
    return getMission(this.settings.currentMission || FIRST_MISSION);
  }

  applyRocketSkin() {
    const key = `rocket-${this.currentFlight().id}`;
    this.rocket.setTexture(this.textures.exists(key) ? key : 'rocket');
    this.bindRocketBody();
  }

  refreshMenuCopy() {
    const flight = this.currentFlight();
    const blurb = document.getElementById('ng-menu-blurb');
    if (blurb) blurb.textContent = `${flight.id}  //  ${flight.payload} — ${flight.blurb}`;
  }

  setMission(id) {
    const flight = getMission(id);
    if (flight.id !== id) return;
    if (!isUnlocked(this.settings, id)) {
      setBanner(`Clear ${this.currentFlight().id} on Jacklyn to unlock ${id}`, 'warn', 2200);
      return;
    }
    this.settings.currentMission = id;
    saveSettings(this.settings);
    setMissionButtons(this.settings, (next) => this.setMission(next));
    this.applyRocketSkin();
    this.refreshMenuCopy();
    AudioApi.play('ui', this.settings);
    this.refreshHud();
  }

  setDifficulty(mode) {
    if (!DIFFICULTY[mode]) return;
    this.settings.difficulty = mode;
    saveSettings(this.settings);
    setDifficultyButtons(mode, (next) => this.setDifficulty(next));
    AudioApi.play('ui', this.settings);
    this.refreshHud();
  }

  resetMissionRecord() {
    resetRecord(this.settings);
    setMissionButtons(this.settings, (id) => this.setMission(id));
    this.applyRocketSkin();
    this.refreshMenuCopy();
    this.refreshHud();
  }

  vibrate(pattern) {
    if (!this.settings.haptics || !('vibrate' in navigator)) return;
    try { navigator.vibrate(pattern); } catch { /* ignore */ }
  }

  parkRecovery() {
    this.jacklyn.setPosition(-2400, 2400);
    this.deck.setPosition(-2400, 2400);
    this.water.position.x = -2400;
    this.water.position.y = 2600;
  }

  placeRecovery() {
    const x = W / 2 + (this.currentFlight().lzOffset || 0);
    this.jacklyn.setPosition(x, 600);
    this.deck.setPosition(x, 588);
    this.water.position.x = W / 2;
    this.water.position.y = 780;
  }

  hintLine() {
    if (!this.settings.controlHints || !this.session) return '';
    if (this.status === 'PRELAUNCH') return 'HOLD CLIMB through ignition';
    if (this.status === 'ASCENT' && this.session.flightTime < (this.session.hintUntil || 0)) {
      return 'HOLD CLIMB  ·  STEER A/D';
    }
    if (this.status === 'JACKLYN' && this.session.jacklynElapsed < 3.2) {
      return 'SLIDE IN  ·  HOLD BRAKE over the deck';
    }
    return '';
  }

  refreshHud() {
    const s = this.session || this.freshSession();
    const boosting = isBoosting(this.inputState, this.nowSec);
    const best = this.settings.hiArcadeScore || 0;
    const last = this.settings.lastArcadeScore || 0;
    const flight = this.currentFlight();
    const missionBest = this.settings.missionBests?.[flight.id]?.score || 0;
    const beat = currentBeat(s.beats || beatsFor(flight), s.tClock);
    renderHud({
      alt: `${s.altitudeKm.toFixed(1)} km`,
      vel: `${Math.round(s.velocity)} m/s`,
      throttle: this.status === 'PRELAUNCH'
        ? `CHG ${(s.charge * 100).toFixed(0)}%`
        : `THR ${(s.throttle * 100).toFixed(0)}%`,
      fuel: `${s.fuel.toFixed(0)}`,
      stage: s.stage,
      score: Math.max(0, Math.round(s.score)).toLocaleString(),
      best: (missionBest || best).toLocaleString(),
      combo: `×${s.combo}  SHLD ${s.shield}`,
      radio: s.radio,
      mission: flight.id,
      payload: `${flight.mark}  ${flight.payload}`,
      objective: flight.objective?.label
        ? `${s.objectiveDone ? 'DONE · ' : 'OBJ · '}${flight.objective.label}`
        : '',
      clock: formatClock(s.tClock),
      tapeId: beat?.id || '',
      muted: this.settings.muted,
      paused: this.paused,
      boostLabel: this.status === 'JACKLYN' ? 'HOLD TO BRAKE' : 'HOLD TO CLIMB',
      hints: this.hintLine(),
      recordLine: best || last
        ? `${flight.id}  ${flight.payload}  ·  PB ${best.toLocaleString()}  ·  LAST ${last.toLocaleString()}  ·  ${this.settings.difficulty}`
        : `${flight.id}  ${flight.payload}  ·  NO MISSIONS FLOWN  ·  ${this.settings.difficulty}`,
    });
    AudioApi.applyMix(this.settings);
    document.body.dataset.phase = this.status === 'PRELAUNCH' ? 'PAD' : this.status;
    if (boosting && this.status === 'ASCENT' && !this.settings.reducedMotion) {
      /* plume handled in update */
    }
  }
}
