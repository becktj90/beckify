import Phaser from './phaser-global.js';
import {
  DIFFICULTY,
  FUEL_MAX,
  H,
  HAVEN,
  JACKLYN_BONUS,
  JACKLYN_SALVAGE,
  OVERDRIVE_SEC,
  PAD_ROCKET_X,
  PAD_ROCKET_Y,
  PACE,
  PICKUP_TYPES,
  RADIO,
  SEP,
  SHIELD_MAX,
  SPLASH_PENALTY,
  TIP_PENALTY,
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
  setCardFlight,
  setDifficultyButtons,
  setMissionButtons,
  setOverlay,
  setSummaryBreakdown,
  setSummaryCopy,
  showScreen,
  syncSettingsForm,
} from './hud.js';
import { bindKeyboard, clearFlightHolds, consumeBoostTap, createInput, isBoosting, setBoostHeld, steerAxis } from './input.js';
import { FIRST_MISSION, getMission, isUnlocked, nextMissionId } from './missions.js';
import { beatsFor, currentBeat, formatClock, phaseChip, T0_LEAD } from './sequence.js';
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

    this.padGlow = this.add.graphics().setDepth(5);
    this.bgWash = this.add.graphics().setDepth(-3);
    this.paintSkyWash(0);
    this.stars = this.add.image(W / 2, -2200, 'stars').setDepth(-2).setDisplaySize(W + 80, 2400).setAlpha(0);
    this.bgSky = this.add.image(W / 2, -1480, 'ascent-sky').setDepth(-1).setDisplaySize(W, 4400);
    this.cloudsFar = this.add.image(W / 2, 80, 'clouds-far').setDepth(-0.6).setDisplaySize(W + 120, 260).setAlpha(0.7);
    this.cloudsNear = this.add.image(W / 2, 220, 'clouds-near').setDepth(-0.4).setDisplaySize(W + 200, 280).setAlpha(0.55);
    this.hazeBand = this.add.image(W / 2, 360, 'haze').setDepth(-0.2).setDisplaySize(W + 40, 240).setAlpha(0.8);
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
        lifespan: { min: 260, max: 420 },
        speed: { min: 36, max: 150 },
        scale: { start: 0.85, end: 0 },
        emitting: false,
        blendMode: 'ADD',
        frequency: 12,
        quantity: 3,
        angle: { min: 68, max: 112 },
        alpha: { start: 0.95, end: 0 },
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
    this.syncCanvasInput();

    this.matter.world.on('collisionstart', (event) => this.onCollision(event));

    this.cameras.main.setBounds(-800, -4200, W + 1600, 5600);
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
      hold: () => this.holdStandby(),
      restart: () => this.restartMission(),
      nextFlight: () => this.flyNextMission(),
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
    if (isEmbedded()) {
      document.body.classList.add('is-embedded');
      const fsBtn = document.getElementById('arcade-fullscreen-btn');
      if (fsBtn) fsBtn.hidden = true;
    }

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

    if (this.isHavenQa()) {
      this.bootQaFlight(PACE.ENTRY - 0.2, () => this.enterJacklyn());
    } else if (this.qaBeat === 'sep') {
      this.bootQaFlight(PACE.MECO - 0.05, () => {
        this.rocket.setPosition(W / 2, 40);
        this.rocket.setVelocity(0, -0.4);
        this.enterSep();
      });
    }

    this.refreshMenuCopy();
    this.refreshHud();
  }

  buildMenu() {
    // HTML mission-control card is the only start UX. Never paint leftover
    // canvas start prompts — they read through the card and double the menu.
    const shade = this.add.rectangle(W / 2, H / 2, W, H, 0x05060f, 0.55);
    shade.setName('menu-scrim');
    this.menuLayer.add([shade]);
  }

  syncCanvasInput() {
    const menuUp = this.status === 'MENU' || this.status === 'SUMMARY' || this.settingsOpen || this.paused;
    if (this.input && 'enabled' in this.input) this.input.enabled = !menuUp;
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
      sepPhase: 'coast',
      sepElapsed: 0,
      sepAlignHold: 0,
      sepWide: false,
      upperDone: false,
      hintUntil: 4.4,
      ascentScore: 0,
      havenHomeX: W / 2,
      swellT: 0,
    };
  }

  isHavenQa() {
    return this.qaBeat === 'haven' || this.qaBeat === 'jacklyn';
  }

  bootQaFlight(tClock, enter) {
    this.session = this.freshSession();
    this.session.tClock = tClock;
    for (const beat of this.session.beats) {
      if (beat.t < tClock) this.session.fired[beat.id] = true;
    }
    this.paused = false;
    this.pausedForSettings = false;
    this.syncMatterPause();
    this.menuLayer.setVisible(false);
    hideScreens();
    enter();
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
    this.syncCanvasInput();
    hideScreens();
    this.clearActors();
    this.clearDebris();
    this.showAscentSky(true);
    this.bgPad.setVisible(true);
    this.bgOcean.setVisible(false);
    this.jacklyn.setVisible(false);
    this.hideLandingFx();
    this.parkRecovery();
    this.applyRocketSkin();
    this.rocket.setPosition(PAD_ROCKET_X, PAD_ROCKET_Y);
    this.rocket.setVelocity(0, 0);
    this.rocket.setAngle(0);
    this.rocket.setFrictionAir(0.025);
    this.rocket.setIgnoreGravity(true);
    this.matter.world.setGravity(0, 0);
    this.cameras.main.stopFollow();
    this.cameras.main.setZoom(1);
    this.cameras.main.centerOn(W / 2, H / 2);
    this.paintSkyWash(0);
    this.bgOcean.clearTint();
    if (!this.settings.launchTipSeen) {
      this.settings.launchTipSeen = true;
      saveSettings(this.settings);
    }
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
    this.showAscentSky(true);
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
    this.matter.world.setGravity(0, 0.145);
    if (this.session.grace > 1.2) this.time.delayedCall(360, () => this.spawnPickup());
    this.cameras.main.startFollow(this.rocket, true, 0.1, 0.13);
    this.cameras.main.setDeadzone(48, 32);
    this.cameras.main.setZoom(this.settings.reducedMotion ? 1 : 0.9);
    if (!this.settings.reducedMotion) this.cameras.main.shake(420, 0.012);
    this.flashPad(0.55);
    AudioApi.play('liftoff', this.settings);
    AudioApi.setBed('roar', true, this.settings, 0.42);
    setBanner('LIFTOFF', 'go', 1500);
    this.vibrate(30);
    this.tickCombo(1, 'LIFTOFF');
  }

  enterSep() {
    if (this.status === 'SEP' || this.status === 'JACKLYN') return;
    this.status = 'SEP';
    this.session.stage = 'MECO';
    this.session.radio = RADIO.MECO;
    this.session.sepPhase = 'coast';
    this.session.sepElapsed = 0;
    this.session.sepAlignHold = 0;
    this.session.sepWide = false;
    this.session.sepDone = false;
    this.session.ascentScore = Math.round(this.session.ascentScore || this.session.score);
    this.clearActors();
    this.rocket.setFrictionAir(0.034);
    this.rocket.setIgnoreGravity(false);
    this.matter.world.setGravity(0, 0.035);
    this.cameras.main.startFollow(this.rocket, true, 0.08, 0.1);
    this.cameras.main.setDeadzone(56, 40);
    if (!this.settings.reducedMotion) this.cameras.main.zoomTo(0.78, 700);
    AudioApi.stopBeds();
    if (this.qaBeat === 'sep') AudioApi.play('meco', this.settings);
    setBanner('MECO — hold attitude. Sep window incoming.', 'go', 2400);
  }

  enterJacklyn() {
    const flight = this.currentFlight();
    this.status = 'JACKLYN';
    this.session.ascentScore = Math.round(this.session.ascentScore || this.session.score);
    this.session.stage = 'HAVEN';
    this.session.radio = RADIO.JACKLYN;
    this.session.landingLock = false;
    this.session.jacklynPhase = 'slide';
    this.session.tClock = Math.max(this.session.tClock, PACE.ENTRY);
    this.session.swellT = 0;
    this.session.fuel = Math.min(FUEL_MAX, Math.max(this.session.fuel, HAVEN.landingFuel));
    this.clearActors();
    this.showAscentSky(false);
    this.bgPad.setVisible(false);
    this.bgOcean.setVisible(true);
    this.bgOcean.setTint(flight.seaTint || 0xffffff);
    this.jacklyn.setVisible(true);
    this.placeRecovery();
    this.session.havenHomeX = this.jacklyn.x;
    this.hideLandingFx();
    this.rocket.setTexture('booster');
    this.bindRocketBody();
    this.rocket.setDepth(5);
    const side = flight.lzOffset >= 0 ? -1 : 1;
    this.session.jacklynReadyAt = this.nowSec + 2.4;
    this.session.jacklynElapsed = 0;
    this.rocket.setFrictionAir(HAVEN.frictionAir);
    this.rocket.setPosition(this.session.havenHomeX + side * HAVEN.startLat, HAVEN.startY);
    this.rocket.setVelocity(side * -1.55, 0.82);
    this.rocket.setAngle(side * -28);
    this.rocket.setIgnoreGravity(false);
    this.matter.world.setGravity(0, HAVEN.gravity);
    this.cameras.main.stopFollow();
    const zoom = this.settings.reducedMotion ? 0.58 : HAVEN.zoomFar;
    this.cameras.main.setZoom(zoom);
    this.frameHavenCamera(1);
    if (flight.objective?.id === 'clean' && this.session.hits === 0) this.completeObjective();
    AudioApi.stopBeds();
    AudioApi.play('whoosh', this.settings);
    setBanner('HAVEN — long slide-in. RCS straighten. Brake the painted deck.', 'warn', 3200);
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
    else if (this.status === 'SEP') this.updateSep(dt);
    else if (this.status === 'JACKLYN') this.updateJacklyn(dt);
    this.updateSkyLayers();
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
      this.steam.emitParticleAt(PAD_ROCKET_X, PAD_ROCKET_Y + 118, this.settings.reducedMotion ? 2 : 8);
      this.steam.emitParticleAt(PAD_ROCKET_X - 36, PAD_ROCKET_Y + 124, this.settings.reducedMotion ? 1 : 5);
      this.steam.emitParticleAt(PAD_ROCKET_X + 36, PAD_ROCKET_Y + 124, this.settings.reducedMotion ? 1 : 5);
    }
    if (this.session.fired.ignition) {
      this.emitPlume(0.85);
      this.flashPad(0.28);
    }
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
      this.rocket.applyForce({ x: axis * 0.018, y: -0.044 * thrust });
      const vy = this.rocket.body.velocity.y;
      if (vy > -1.15) this.rocket.setVelocityY(-1.15);
      if (vy < -4.9) this.rocket.setVelocityY(-4.9);
      this.emitPlume(thrust);
      AudioApi.rumble(0.35 + thrust * 0.4, this.settings);
    } else {
      this.rocket.applyForce({ x: axis * 0.006, y: this.session.flightTime < 12 ? -0.008 : 0.005 });
      if (this.rocket.body.velocity.y > 1.4) this.rocket.setVelocityY(1.4);
      if (this.session.flightTime < 12 && this.rocket.body.velocity.y > -0.62) {
        this.rocket.setVelocityY(-0.62);
      }
    }
    this.rocket.y = Math.min(this.rocket.y, PAD_ROCKET_Y + 36);

    this.rocket.setAngularVelocity(0);
    this.rocket.setAngle(clamp(this.rocket.body.velocity.x * 4 + axis * 6, -18, 18));
    this.rocket.x = clamp(this.rocket.x, 80, W - 80);

    const vy = this.rocket.body.velocity.y;
    this.session.velocity = Math.max(0, Math.round((-vy) * 110 + this.session.tClock * 28));
    this.session.altitudeKm = clamp(this.session.tClock * 1.42, 0, 110);
    this.bgPad.setVisible(this.rocket.y > 80);
    const climbZoom = this.settings.reducedMotion ? 1 : clamp(0.9 - this.session.altitudeKm * 0.0032, 0.78, 0.9);
    this.cameras.main.setZoom(climbZoom);
    this.session.score += Math.max(0, (-vy) * 26 * dt * (1 + this.session.combo * 0.1));

    this.session.spawnAt -= dt;
    if (this.session.spawnAt <= 0 && this.session.grace <= 0 && !this.session.fired.meco) {
      this.spawnHazard();
      if (Math.random() < 0.3 * mode.pickupMul) this.spawnPickup();
      this.session.spawnAt = rand(0.62, 1.2) / (mode.spawnMul * this.currentFlight().spawnMul);
    }
    this.advanceActors();

    if (this.session.fired.meco) this.enterSep();

    if (this.rocket.y > 620 && this.session.altitudeKm < 1.2 && this.session.flightTime > 2.4) {
      this.session.failReason = 'Lost the corridor — fell back toward the pad';
      this.session.radio = RADIO.RUD;
      AudioApi.play('rud', this.settings);
      setBanner(`RUD — ${this.session.failReason}`, 'fail', 0);
      this.endMission('rud');
    }
  }

  updateSep(dt) {
    const mode = DIFFICULTY[this.settings.difficulty];
    this.session.sepElapsed = (this.session.sepElapsed || 0) + dt;
    this.session.tClock += dt;
    this.fireDueBeats();

    let axis = steerAxis(this.inputState);
    if (this.inputState.pointerX != null) {
      axis = clamp((this.inputState.pointerX - this.rocket.x) / 150, -1, 1);
    }
    if (mode.assist > 0 && this.session.sepPhase !== 'clear') {
      axis = clamp(axis - this.rocket.body.velocity.x * 0.18 * mode.assist, -1, 1);
    }

    const rcs = isBoosting(this.inputState, this.nowSec) && this.session.sepPhase === 'coast';
    this.rocket.applyForce({
      x: axis * (rcs ? 0.012 : 0.007),
      y: this.session.sepPhase === 'clear' ? 0.01 : -0.004,
    });
    this.rocket.setAngularVelocity(0);
    const want = clamp(this.rocket.body.velocity.x * 5 + axis * 7, -16, 16);
    const nowAngle = this.rocket.angle || 0;
    const nextAngle = nowAngle + (want - nowAngle) * Math.min(1, dt * 3.4);
    this.rocket.setAngle(nextAngle);
    if (Math.abs(nextAngle - nowAngle) > 0.7) this.emitRcs();
    this.rocket.x = clamp(this.rocket.x, 70, W - 70);
    if (this.rocket.body.velocity.y < -2.2) this.rocket.setVelocityY(-2.2);
    if (this.rocket.body.velocity.y > 2.8) this.rocket.setVelocityY(2.8);

    const aligned = Math.abs(this.rocket.angle) <= mode.sepAlignDeg
      && Math.abs(this.rocket.body.velocity.x) <= mode.sepAlignVx;
    this.session.sepAlignHold = aligned ? this.session.sepAlignHold + dt : 0;
    this.session.velocity = Math.round(this.rocket.body.velocity.x * 38);
    this.session.altitudeKm = clamp(this.session.altitudeKm, 48, 110);
    this.session.throttle = aligned ? 1 : 0.2;
    this.session.radio = this.session.sepPhase === 'clear'
      ? RADIO.SEP_CLEAR
      : (aligned ? 'ALIGN GREEN — tap climb to fire sep.' : RADIO.SEP);

    if (this.session.sepPhase === 'coast' && this.session.sepElapsed >= SEP.coastSec) {
      this.session.sepPhase = 'window';
      this.session.sepNeedRelease = this.inputState.boostHeld;
      this.inputState.boostBufferedUntil = 0;
      this.inputState.boostUntil = 0;
      this.session.stage = 'STAGE SEP';
      setBanner('STAGE SEP — ALIGN green, then TAP CLIMB', 'go', 2600);
    }

    if (this.session.sepPhase === 'window') {
      const windowLimit = mode.sepWindow || 5.8;
      const tap = this.session.sepNeedRelease ? false : consumeBoostTap(this.inputState, this.nowSec);
      if (this.session.sepNeedRelease && !this.inputState.boostHeld) this.session.sepNeedRelease = false;
      const autoKid = !mode.allowFail && this.session.sepAlignHold >= SEP.alignHold;
      if ((tap && this.session.sepAlignHold >= SEP.alignHold) || autoKid) {
        this.fireSep(true);
      } else if (tap) {
        this.fireSep(false);
      } else if (this.session.sepElapsed >= SEP.coastSec + windowLimit) {
        this.fireSep(false);
      }
    }

    if (this.session.sepPhase === 'clear') {
      this.advanceSepDebris(dt);
      if (this.upperStage?.active) {
        const dx = this.rocket.x - this.upperStage.x;
        const dy = this.rocket.y - this.upperStage.y;
        if (Math.hypot(dx, dy) < 78) this.sepContact();
      }
      if (this.session.sepElapsed >= SEP.clearSec) {
        this.enterJacklyn();
      }
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
    this.session.swellT = (this.session.swellT || 0) + dt;
    this.fireDueBeats();
    this.applyHavenDrift(dt, mode);

    const boosting = isBoosting(this.inputState, this.nowSec);
    let axis = steerAxis(this.inputState);
    if (this.inputState.pointerX != null) {
      axis = clamp((this.inputState.pointerX - this.rocket.x) / 210, -1, 1);
    }
    const deckX = this.deck.x;
    const assist = this.isHavenQa() ? Math.max(mode.assist, 0.42) : mode.assist;
    if (assist > 0) {
      const err = (deckX - this.rocket.x) / 340;
      axis = clamp(axis + err * assist * 0.72, -1, 1);
    }

    const alt = this.jacklyn.y - 50 - this.rocket.y;
    if (alt < 210 && this.session.jacklynPhase === 'slide') {
      this.session.jacklynPhase = 'straighten';
      this.emitRcs();
      setBanner('RCS — straighten for the painted deck', 'info', 1600);
    }
    if (alt < 95) this.session.jacklynPhase = 'settle';

    const wantAngle = this.session.jacklynPhase === 'slide'
      ? clamp(this.rocket.body.velocity.x * 3.1, -30, 30)
      : 0;
    const nowAngle = this.rocket.angle || 0;
    const slew = this.session.jacklynPhase === 'slide' ? 1.7 : 4.4;
    const nextAngle = nowAngle + (wantAngle - nowAngle) * Math.min(1, dt * slew);
    if (Math.abs(nextAngle - nowAngle) > 0.7) this.emitRcs();
    this.rocket.setAngularVelocity(0);
    this.rocket.setAngle(nextAngle);

    if (boosting && this.session.fuel > 0) {
      this.session.fuel = Math.max(0, this.session.fuel - mode.fuelDrain * 9 * dt);
      this.rocket.applyForce({ x: axis * 0.014, y: -0.032 });
      this.session.throttle = 1;
      this.emitPlume(0.85);
      if (alt < 240) this.emitBloom();
      AudioApi.setBed('burn', true, this.settings, 0.38);
      if (alt > 220 && this.rocket.body.velocity.y < 1.15) this.rocket.setVelocityY(1.15);
      else if (alt > 40 && this.rocket.body.velocity.y < 0.48) this.rocket.setVelocityY(0.48);
    } else {
      this.rocket.applyForce({ x: axis * 0.006 + (mode.wind || 0) * 0.0018, y: 0.006 });
      this.session.throttle = 0.12;
      AudioApi.setBed('burn', false, this.settings);
    }
    if (this.session.jacklynElapsed < HAVEN.earlySec && this.rocket.body.velocity.y > HAVEN.maxVyEarly) {
      this.rocket.setVelocityY(HAVEN.maxVyEarly);
    }
    if (this.rocket.body.velocity.y > HAVEN.maxVy) this.rocket.setVelocityY(HAVEN.maxVy);
    if (this.rocket.body.velocity.y < -0.85) this.rocket.setVelocityY(-0.85);
    this.rocket.x = clamp(this.rocket.x, -80, W + 80);
    this.session.velocity = Math.round(this.rocket.body.velocity.y * 36);
    this.session.altitudeKm = clamp(alt / 140, 0, 12);
    this.frameHavenCamera(dt);
    if (this.rocket.y > this.jacklyn.y + 90) this.resolveLanding('water');
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
    if (beat.juice === 'meco') {
      this.session.ascentScore = Math.round(this.session.score);
      AudioApi.play('meco', this.settings);
    }
    if (beat.juice === 'ignition') {
      AudioApi.play('liftoff', this.settings);
      if (!this.settings.reducedMotion) this.cameras.main.shake(280, 0.008);
      this.flashPad(0.4);
    }
    if (beat.juice === 'deluge' && this.steam) {
      this.steam.emitParticleAt(PAD_ROCKET_X, PAD_ROCKET_Y + 120, 16);
      this.flashPad(0.12);
    }
    if (beat.juice === 'fairing' && !this.session.sepDone) this.playFairingJettison();
    if (beat.juice === 'ses' && !this.session.sepDone) this.spawnUpperStage();
    if (beat.id !== 'liftoff' && beat.id !== 'touchdown') this.tickCombo(1, beat.banner);
    if (beat.id === 'deploy') this.session.upperDone = true;
  }

  playStageSep() {
    this.fireSep(true);
  }

  fireSep(clean) {
    if (this.session.sepDone) return;
    this.session.sepDone = true;
    this.session.sepPhase = 'clear';
    this.session.sepElapsed = 0;
    this.session.stage = 'STAGE SEP';
    this.session.radio = RADIO.SEP_CLEAR;
    this.rocket.setTexture('booster');
    this.bindRocketBody();
    this.spawnUpperStage();
    this.playFairingJettison();
    this.spawnSepDebris();
    this.rocket.setVelocity(this.rocket.body.velocity.x + (clean ? 0.15 : 1.1), 1.15);
    if (!clean) {
      this.session.sepWide = true;
      this.session.combo = 0;
      this.session.score = Math.max(0, this.session.score - SEP.widePenalty);
      setBanner('SEP WIDE — relative motion is hot. Clear the stack.', 'warn', 2400);
      if (this.settings.difficulty === 'PAD_RAT' && Math.abs(this.rocket.angle) > 18) {
        this.session.failReason = 'Sep collision geometry — stack fouled';
        this.session.radio = RADIO.RUD;
        AudioApi.play('rud', this.settings);
        setBanner(`RUD — ${this.session.failReason}`, 'fail', 0);
        this.endMission('rud');
        return;
      }
    } else {
      this.tickCombo(1, 'STAGE SEP');
      setBanner('SEP CONFIRMED — clear the stack, then Haven', 'go', 2200);
    }
    AudioApi.play('whoosh', this.settings);
    if (!this.settings.reducedMotion) this.cameras.main.shake(260, 0.007);
  }

  sepContact() {
    if (this.session.sepContacted) return;
    this.session.sepContacted = true;
    this.session.combo = 0;
    this.session.score = Math.max(0, this.session.score - SEP.contactPenalty);
    AudioApi.play('hit', this.settings);
    setBanner('STACK CONTACT — combo gone. Stay clear.', 'fail', 1800);
    this.rocket.setVelocity(this.rocket.body.velocity.x * -0.4, 1.4);
    if (this.settings.difficulty === 'PAD_RAT') {
      this.session.failReason = 'Recontact after sep';
      this.session.radio = RADIO.RUD;
      AudioApi.play('rud', this.settings);
      setBanner(`RUD — ${this.session.failReason}`, 'fail', 0);
      this.endMission('rud');
    }
  }

  spawnSepDebris() {
    const kinds = ['sep-ring', 'sep-strut', 'sep-plate', 'debris'];
    const n = this.settings.reducedMotion ? 3 : 7;
    for (let i = 0; i < n; i++) {
      const key = kinds[i % kinds.length];
      const bit = this.add.image(
        this.rocket.x + rand(-28, 28),
        this.rocket.y + rand(-40, 50),
        key,
      ).setDepth(4);
      bit.vx = rand(-1.6, 1.6);
      bit.vy = rand(0.4, 2.1);
      bit.spin = rand(-80, 80);
      this.debrisBits.push(bit);
    }
  }

  advanceSepDebris(dt) {
    for (let i = this.debrisBits.length - 1; i >= 0; i--) {
      const bit = this.debrisBits[i];
      if (!bit.active) {
        this.debrisBits.splice(i, 1);
        continue;
      }
      bit.x += (bit.vx || 0) * 60 * dt;
      bit.y += (bit.vy || 0) * 60 * dt;
      bit.angle += (bit.spin || 0) * dt;
      bit.vx *= 0.995;
      if (bit.y > this.rocket.y + 520) {
        bit.destroy();
        this.debrisBits.splice(i, 1);
      }
    }
  }

  spawnUpperStage() {
    if (this.upperStage && this.upperStage.active) return;
    const x = this.rocket.x;
    const y = this.rocket.y - 90;
    this.upperStage = this.add.image(x, y, 'upper-stage').setDepth(4);
    this.tweens.add({
      targets: this.upperStage,
      y: y - 640,
      x: x + 70,
      alpha: 0.22,
      duration: this.settings.reducedMotion ? 700 : 2400,
      onComplete: () => {
        this.upperStage?.destroy();
        this.upperStage = null;
      },
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
      x: x - 220,
      y: y + 120,
      angle: -70,
      alpha: 0,
      duration: this.settings.reducedMotion ? 360 : 1400,
      onComplete: () => left.destroy(),
    });
    this.tweens.add({
      targets: right,
      x: x + 220,
      y: y + 120,
      angle: 70,
      alpha: 0,
      duration: this.settings.reducedMotion ? 360 : 1400,
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
    const dx = Math.abs(this.rocket.x - this.jacklyn.x);
    const onPaint = kind === 'deck' && dx <= mode.landingTol + 22;
    const soft = vy <= mode.landingVy;
    const tipped = Math.abs(this.rocket.angle) > 14;
    this.rocket.setVelocity(0, 0);
    this.rocket.setIgnoreGravity(true);

    if (kind === 'deck' && onPaint && soft && !tipped) {
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
      this.session.tClock = Math.max(this.session.tClock, PACE.TOUCHDOWN);
      this.session.fired.touchdown = true;
      this.time.delayedCall(2400, () => this.finishUpper());
      return;
    }

    if (kind === 'deck') {
      this.session.salvage = true;
      this.session.score += JACKLYN_SALVAGE;
      if (tipped) {
        this.session.score = Math.max(0, this.session.score - TIP_PENALTY);
        this.session.radio = RADIO.TIP;
      } else {
        this.session.radio = RADIO.SALVAGE;
      }
      this.session.combo = 0;
      this.rocket.setPosition(this.jacklyn.x + clamp(this.rocket.x - this.jacklyn.x, -40, 40), this.jacklyn.y - 74);
      AudioApi.stopBeds();
      AudioApi.play('hit', this.settings);
      setBanner(tipped ? RADIO.TIP : this.currentFlight().jacklyn.salvage, 'warn', 2800);
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
    this.session.tClock = Math.max(this.session.tClock, PACE.SECO);
    this.fireDueBeats();
    this.time.delayedCall(900, () => {
      this.session.tClock = Math.max(this.session.tClock, PACE.DEPLOY);
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
      setBanner('CORE KICK', 'go', 900);
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

  flashPad(alpha) {
    if (!this.padGlow || this.settings.reducedFlashes) return;
    this.padGlow.clear();
    this.padGlow.fillStyle(0xff9a28, alpha);
    this.padGlow.fillEllipse(PAD_ROCKET_X, PAD_ROCKET_Y + 122, 220, 56);
    this.time.delayedCall(this.settings.reducedMotion ? 80 : 160, () => {
      if (this.padGlow) this.padGlow.clear();
    });
  }

  emitPlume(power) {
    if (this.settings.reducedMotion) return;
    const space = (this.session?.altitudeKm || 0) > 28;
    const n = power > 0.7 ? (space ? 10 : 12) : 4;
    this.plume.emitParticleAt(this.rocket.x, this.rocket.y + 108, n);
    if (this.steam && power > 0.4 && !space) {
      this.steam.emitParticleAt(this.rocket.x, this.rocket.y + 118, 3);
    }
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
    const prevBest = this.settings.missionBests?.[this.currentFlight().id]?.score || 0;
    recordMissionResult(this.settings, this.currentFlight().id, points, this.session.recovered);
    const nxt = reason === 'rud' ? null : nextMissionId(this.currentFlight().id);
    const unlockedNext = nxt && !this.settings.unlockedMissions.includes(nxt);
    if (unlockedNext) this.settings.unlockedMissions.push(nxt);
    saveSettings(this.settings);
    setMissionButtons(this.settings, (id) => this.setMission(id));
    if (typeof window.recordGameScore === 'function') {
      window.recordGameScore('kestrel-heavy', points);
    }
    const headline = reason === 'recovered'
      ? this.currentFlight().jacklyn.recovered
      : reason === 'splash'
        ? this.currentFlight().jacklyn.splash
        : reason === 'salvage'
          ? this.currentFlight().jacklyn.salvage
          : 'MISSION ABORT';
    const extra = unlockedNext ? `  ·  ${nxt} UNLOCKED` : '';
    const ascent = Math.round(this.session.ascentScore || (reason === 'rud' ? points : 0));
    const jacklynPts = points - ascent;
    const jacklynKind = reason === 'recovered'
      ? 'soft'
      : reason === 'salvage'
        ? 'salvage'
        : reason === 'splash'
          ? 'splash'
          : 'abort';
    const delta = points - prevBest;
    const deltaLine = prevBest
      ? `Best delta  ${delta >= 0 ? '+' : ''}${delta.toLocaleString()}  vs PB ${prevBest.toLocaleString()}`
      : `First flight on ${this.currentFlight().id}  ·  ${points.toLocaleString()} is the mark`;
    const nextFlight = nxt ? getMission(nxt) : null;
    AudioApi.stopBeds();
    AudioApi.play(reason === 'rud' ? 'rud' : 'success', this.settings);
    setBanner(`${this.currentFlight().id}  ${headline}   SCORE ${points.toLocaleString()}${extra}`, reason === 'rud' ? 'fail' : 'go', 0);
    setSummaryCopy(
      `${this.currentFlight().id}  ${headline}`,
      `${this.currentFlight().payload}\nScore ${points.toLocaleString()}  ·  Combo peak ×${this.session.bestCombo}${extra}\n${this.session.upperDone ? 'SECO + payload deploy — good flight.\n' : ''}Tap continue or press Space`,
    );
    setSummaryBreakdown(
      `Ascent  ${ascent.toLocaleString()}`,
      `Haven ${jacklynKind}  ${jacklynPts >= 0 ? '+' : ''}${jacklynPts.toLocaleString()}`,
      deltaLine,
      nextFlight ? `NEXT · ${nextFlight.id} ${nextFlight.mark}` : '',
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
    return this.status === 'PRELAUNCH' || this.status === 'ASCENT' || this.status === 'SEP' || this.status === 'JACKLYN';
  }

  paintSkyWash(spaceT) {
    if (!this.bgWash) return;
    this.bgWash.clear();
    const t = clamp(spaceT, 0, 1);
    this.bgWash.fillStyle(0x010208, 1);
    this.bgWash.fillRect(-200, -4200, W + 400, 2600);
    this.bgWash.fillStyle(t > 0.45 ? 0x061018 : 0x0a2040, 1);
    this.bgWash.fillRect(-200, -1600, W + 400, 1400);
    this.bgWash.fillStyle(t > 0.7 ? 0x0a2040 : 0x3a7eb4, 1);
    this.bgWash.fillRect(-200, -200, W + 400, 500);
    this.bgWash.fillStyle(0x6fb4e8, 1 - t * 0.65);
    this.bgWash.fillRect(-200, 300, W + 400, 500);
  }

  showAscentSky(on) {
    if (this.bgSky) this.bgSky.setVisible(on);
    if (this.stars) this.stars.setVisible(on);
    if (this.cloudsFar) this.cloudsFar.setVisible(on);
    if (this.cloudsNear) this.cloudsNear.setVisible(on);
    if (this.hazeBand) this.hazeBand.setVisible(on);
    if (this.bgWash) this.bgWash.setVisible(on);
  }

  updateSkyLayers() {
    if (!this.session || this.status === 'JACKLYN' || this.status === 'SUMMARY') return;
    const alt = this.session.altitudeKm || 0;
    const space = clamp((alt - 10) / 52, 0, 1);
    this.paintSkyWash(space);
    if (this.stars) {
      this.stars.setAlpha(space * 0.95);
      this.stars.y = -2200 + (this.rocket?.y || 0) * 0.04;
    }
    if (this.bgSky && this.rocket) {
      this.bgSky.y = -1480 + this.rocket.y * 0.06;
    }
    if (this.cloudsFar && this.rocket) {
      this.cloudsFar.y = 80 + this.rocket.y * 0.16;
      this.cloudsFar.x = W / 2 + Math.sin((this.nowSec || 0) * 0.08) * 18;
      this.cloudsFar.setAlpha((1 - space) * 0.72);
    }
    if (this.cloudsNear && this.rocket) {
      this.cloudsNear.y = 220 + this.rocket.y * 0.3;
      this.cloudsNear.x = W / 2 + Math.sin((this.nowSec || 0) * 0.14) * 28;
      this.cloudsNear.setAlpha((1 - space) * 0.58);
    }
    if (this.hazeBand && this.rocket) {
      this.hazeBand.y = 340 + this.rocket.y * 0.2;
      this.hazeBand.setAlpha((1 - space * 0.85) * 0.8);
    }
  }

  frameHavenCamera(dt) {
    if (!this.jacklyn || !this.rocket) return;
    const alt = this.jacklyn.y - this.rocket.y;
    const t = clamp(1 - alt / 1100, 0, 1);
    const want = this.settings.reducedMotion
      ? 0.58
      : HAVEN.zoomFar + (HAVEN.zoomNear - HAVEN.zoomFar) * t * t;
    const now = this.cameras.main.zoom;
    const zoom = now + (want - now) * Math.min(1, (typeof dt === 'number' ? dt : 0.016) * 1.6);
    this.cameras.main.setZoom(zoom);
    const midX = this.rocket.x * 0.42 + this.jacklyn.x * 0.58;
    const midY = this.rocket.y * 0.48 + this.jacklyn.y * 0.52 - 30;
    this.cameras.main.centerOn(midX, midY);
  }

  applyHavenDrift(dt, mode) {
    const wind = mode.wind || 0.28;
    const swell = Math.sin((this.session.swellT || 0) * 0.28) * HAVEN.swellAmp;
    const gust = Math.sin((this.session.swellT || 0) * 0.62) * wind;
    const x = (this.session.havenHomeX || W / 2) + swell;
    this.jacklyn.setPosition(x, this.jacklyn.y);
    this.deck.setPosition(x, this.jacklyn.y - 12);
    this.rocket.applyForce({ x: gust * 0.0034, y: 0 });
    if (this.bgOcean) {
      this.bgOcean.x = W / 2 + swell * 0.15;
    }
  }

  togglePause() {
    if (this.status === 'MENU' || this.status === 'SUMMARY') return;
    this.paused = !this.paused;
    this.pausedForSettings = false;
    this.syncMatterPause();
    AudioApi.setPaused(this.paused);
    if (this.paused) {
      clearFlightHolds(this.inputState);
      hideScreens();
      setOverlay('ng-pause', true);
    } else {
      clearFlightHolds(this.inputState);
      setOverlay('ng-pause', false);
      setOverlay('ng-howto', false);
    }
    setBanner(this.paused ? 'PAUSED' : 'RESUMED', 'info', 900);
    this.refreshHud();
  }

  toggleMute() {
    this.settings.muted = !this.settings.muted;
    this.settings.sound = !this.settings.muted;
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
        clearFlightHolds(this.inputState);
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
    clearFlightHolds(this.inputState);
    this.syncMatterPause();
    this.returnToMenu();
  }

  restartMission() {
    this.paused = false;
    this.pausedForSettings = false;
    this.settingsOpen = false;
    clearFlightHolds(this.inputState);
    this.syncMatterPause();
    AudioApi.setPaused(false);
    this.startMission();
  }

  holdStandby() {
    setBanner('HOLD — standing by on Pier 7', 'info', 1400);
  }

  flyNextMission() {
    const nxt = nextMissionId(this.currentFlight().id);
    if (nxt && isUnlocked(this.settings, nxt)) this.setMission(nxt);
    this.startMission();
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
    setCardFlight(flight);
    const blurb = document.getElementById('ng-menu-blurb');
    if (blurb) blurb.textContent = `${flight.id}  //  ${flight.payload} — ${flight.blurb}`;
  }

  setMission(id) {
    const flight = getMission(id);
    if (flight.id !== id) return;
    if (!isUnlocked(this.settings, id)) {
      setBanner(`Clear ${this.currentFlight().id} on Haven to unlock ${id}`, 'warn', 2200);
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
    this.jacklyn.setPosition(x, HAVEN.bargeY);
    this.deck.setPosition(x, HAVEN.bargeY - 12);
    this.water.position.x = W / 2;
    this.water.position.y = HAVEN.bargeY + 110;
  }

  hintLine() {
    if (!this.settings.controlHints || !this.session) return '';
    if (this.status === 'PRELAUNCH') return 'HOLD CLIMB through ignition';
    if (this.status === 'ASCENT' && this.session.flightTime < (this.session.hintUntil || 0)) {
      return 'HOLD CLIMB  ·  STEER A/D';
    }
    if (this.status === 'SEP') {
      if (this.session.sepPhase === 'window') return 'ALIGN GREEN  ·  TAP CLIMB to sep';
      if (this.session.sepPhase === 'clear') return 'CLEAR THE STACK  ·  hold attitude';
      return 'MECO  ·  HOLD ATTITUDE';
    }
    if (this.status === 'JACKLYN' && this.session.jacklynElapsed < 6.5) {
      return 'LONG SLIDE-IN  ·  HOLD BRAKE over the deck';
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
        : this.status === 'SEP'
          ? (s.sepPhase === 'clear' ? 'SEP CLEAR' : (s.throttle > 0.8 ? 'ALIGN OK' : 'ALIGN WIDE'))
          : `THR ${(s.throttle * 100).toFixed(0)}%`,
      fuel: `${s.fuel.toFixed(0)}`,
      shield: `${s.shield}/${SHIELD_MAX}`,
      stage: this.status === 'MENU' ? 'STANDBY' : (this.status === 'SUMMARY' ? 'SUMMARY' : (s.stage && s.stage !== 'MENU' ? s.stage : 'STANDBY')),
      score: Math.max(0, Math.round(s.score)).toLocaleString(),
      best: (missionBest || best).toLocaleString(),
      combo: `×${s.combo}`,
      radio: s.radio,
      mission: flight.id,
      payload: `${flight.mark}  ${flight.payload}`,
      objective: flight.objective?.label
        ? `${s.objectiveDone ? 'DONE · ' : 'OBJ · '}${flight.objective.label}`
        : '',
      clock: formatClock(s.tClock),
      tapeId: beat?.id || '',
      phase: this.status === 'MENU' ? 'STANDBY' : (this.status === 'SEP' ? (s.sepPhase === 'clear' ? 'STAGE SEP' : (s.sepPhase === 'window' ? 'STAGE SEP' : 'MECO')) : phaseChip(beat?.id)),
      muted: this.settings.muted,
      paused: this.paused,
      boostLabel: this.status === 'JACKLYN'
        ? 'HOLD TO BRAKE'
        : this.status === 'SEP' && s.sepPhase === 'window'
          ? 'TAP TO SEP'
          : 'HOLD TO CLIMB',
      hints: this.hintLine(),
      launchTip: this.status === 'MENU' && !this.settings.launchTipSeen,
      recordLine: best || last
        ? `${flight.id}  ${flight.payload}  ·  PB ${best.toLocaleString()}  ·  LAST ${last.toLocaleString()}  ·  ${this.settings.difficulty}`
        : `${flight.id}  ${flight.payload}  ·  NO MISSIONS FLOWN  ·  ${this.settings.difficulty}`,
    });
    AudioApi.applyMix(this.settings);
    document.body.dataset.phase = this.status === 'PRELAUNCH' ? 'PAD' : this.status;
    this.syncCanvasInput();
    if (boosting && this.status === 'ASCENT' && !this.settings.reducedMotion) {
      /* plume handled in update */
    }
  }
}
