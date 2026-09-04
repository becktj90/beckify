import Phaser from './phaser-global.js';
import {
  ASCENT_TARGET_KM,
  DIFFICULTY,
  FUEL_MAX,
  H,
  JACKLYN_BONUS,
  JACKLYN_SALVAGE,
  OVERDRIVE_SEC,
  PICKUP_TYPES,
  RADIO,
  SHIELD_MAX,
  SPLASH_PENALTY,
  TIPS,
  W,
} from './config.js';
import AudioApi from './audio.js';
import { bindChrome, isEmbedded, renderHud, setBanner, setDifficultyButtons, syncSettingsForm } from './hud.js';
import { bindKeyboard, consumeBoostTap, createInput, isBoosting, setBoostHeld, steerAxis } from './input.js';
import { loadSettings, resetRecord, saveSettings } from './storage.js';
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

  create() {
    this.settings = loadSettings();
    this.inputState = createInput();
    this.status = 'MENU';
    this.paused = false;
    this.settingsOpen = false;
    this.nowSec = 0;
    this.tip = pick(TIPS);
    this.qaBeat = new URLSearchParams(window.location.search).get('beat');

    installTextures(this);
    this.matter.world.setGravity(0, 0);
    this.matter.world.setBounds(0, -4000, W, 5200, 32, false, false, false, false);

    this.bgPad = this.add.image(W / 2, H / 2, 'pad').setDepth(0);
    this.bgOcean = this.add.image(W / 2, H / 2, 'ocean').setVisible(false).setDepth(0);
    this.jacklyn = this.matter.add.image(W / 2, 620, 'jacklyn', null, {
      isStatic: true,
      label: 'deck',
    });
    this.jacklyn.setCollisionCategory(CAT_DECK);
    this.jacklyn.setCollidesWith(CAT_ROCKET);
    this.jacklyn.setVisible(false);
    this.jacklyn.setSensor(true);
    this.jacklyn.setPosition(-2400, 2400);

    this.water = this.matter.add.rectangle(-2400, 2600, W + 200, 80, {
      isStatic: true,
      isSensor: true,
      label: 'water',
    });
    this.water.collisionFilter = { category: CAT_WATER, mask: CAT_ROCKET };

    this.rocket = this.matter.add.image(560, 430, 'rocket', null, {
      label: 'rocket',
      frictionAir: 0.035,
      density: 0.002,
    });
    this.rocket.setCollisionCategory(CAT_ROCKET);
    this.rocket.setCollidesWith(CAT_DECK | CAT_WATER | CAT_HAZARD | CAT_PICKUP);
    this.rocket.setFixedRotation();
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
    syncSettingsForm(this.settings);
    const form = document.getElementById('ng-settings');
    if (form) {
      form.addEventListener('change', () => {
        form.querySelectorAll('[data-set]').forEach((input) => {
          this.settings[input.getAttribute('data-set')] = input.checked;
        });
        saveSettings(this.settings);
        AudioApi.setMute(this.settings);
      });
    }

    if (isEmbedded()) {
      document.body.classList.add('is-embedded');
    }

    this.input.on('pointerdown', (pointer) => {
      AudioApi.unlock(this.settings);
      if (this.status === 'MENU' || this.status === 'SUMMARY') this.onPrimary();
      else this.inputState.pointerX = pointer.worldX;
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
      this.startMission();
      this.enterJacklyn();
    }

    this.refreshHud();
  }

  buildMenu() {
    const shade = this.add.rectangle(W / 2, H / 2, W, H, 0x05060f, 0.42);
    const title = this.add.text(W / 2, 78, 'NEW GLENN  //  FLIGHT MISSION', {
      fontFamily: '"Exo 2", system-ui, sans-serif',
      fontSize: '36px',
      fontStyle: 'bold',
      color: '#e8fff4',
    }).setOrigin(0.5);
    const sub = this.add.text(W / 2, 122, 'LC-36 INTEGRATED LAUNCH TOWER  ·  Gradatim Ferociter', {
      fontFamily: '"IBM Plex Mono", ui-monospace, monospace',
      fontSize: '16px',
      color: '#8ce0ff',
    }).setOrigin(0.5);
    const tip = this.add.text(W / 2, 162, this.tip, {
      fontFamily: '"IBM Plex Mono", ui-monospace, monospace',
      fontSize: '15px',
      color: '#ffcf5d',
    }).setOrigin(0.5);
    const start = this.add.text(W / 2, 220, 'TAP OR PRESS SPACE TO START PREFLIGHT', {
      fontFamily: '"IBM Plex Mono", ui-monospace, monospace',
      fontSize: '20px',
      fontStyle: 'bold',
      color: '#041014',
      backgroundColor: '#ffcf5d',
      padding: { x: 16, y: 10 },
    }).setOrigin(0.5);
    const help = this.add.text(W / 2, 278, 'Hold boost to climb. A/D or ◀ ▶ steer. Land the booster on Jacklyn.', {
      fontFamily: '"IBM Plex Mono", ui-monospace, monospace',
      fontSize: '15px',
      color: '#d5def0',
    }).setOrigin(0.5);
    this.menuLayer.add([shade, title, sub, tip, start, help]);
  }

  freshSession() {
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
      spawnAt: 1.6,
      flightTime: 0,
      landingLock: false,
    };
  }

  startMission() {
    this.session = this.freshSession();
    this.status = 'PAD';
    this.paused = false;
    this.menuLayer.setVisible(false);
    this.clearActors();
    this.bgPad.setVisible(true);
    this.bgOcean.setVisible(false);
    this.jacklyn.setVisible(false);
    this.parkRecovery();
    this.rocket.setTexture('rocket');
    this.rocket.setPosition(560, 430);
    this.rocket.setVelocity(0, 0);
    this.rocket.setIgnoreGravity(true);
    this.matter.world.setGravity(0, 0);
    this.cameras.main.stopFollow();
    this.cameras.main.centerOn(W / 2, H / 2);
    setBanner('PREFLIGHT — hold boost to charge', 'info', 2600);
    AudioApi.play('ui', this.settings);
    this.refreshHud();
  }

  onPrimary() {
    AudioApi.unlock(this.settings);
    if (this.status === 'MENU') {
      this.startMission();
      return;
    }
    if (this.status === 'SUMMARY') {
      this.status = 'MENU';
      this.menuLayer.setVisible(true);
      this.tip = pick(TIPS);
      this.refreshHud();
      return;
    }
    if (this.status === 'PAD' && this.session.charge >= 0.92) {
      this.liftoff();
    }
  }

  liftoff() {
    this.status = 'ASCENT';
    this.session.stage = 'ASCENT';
    this.session.radio = RADIO.LIFTOFF;
    this.session.throttle = 1;
    this.rocket.setIgnoreGravity(false);
    this.matter.world.setGravity(0, 0.22);
    this.cameras.main.startFollow(this.rocket, true, 0.08, 0.1);
    this.cameras.main.setDeadzone(80, 40);
    if (!this.settings.reducedMotion) this.cameras.main.shake(220, 0.006);
    AudioApi.play('liftoff', this.settings);
    setBanner('LIFTOFF', 'go', 1600);
    this.vibrate(30);
  }

  enterJacklyn() {
    this.status = 'JACKLYN';
    this.session.stage = 'JACKLYN';
    this.session.radio = RADIO.JACKLYN;
    this.session.landingLock = false;
    this.clearActors();
    this.bgPad.setVisible(false);
    this.bgOcean.setVisible(true);
    this.jacklyn.setVisible(true);
    this.placeRecovery();
    this.rocket.setTexture('booster');
    this.rocket.setPosition(W / 2 + rand(-40, 40), 90);
    this.rocket.setVelocity(rand(-0.6, 0.6), 1.4);
    this.rocket.setIgnoreGravity(false);
    this.matter.world.setGravity(0, 0.95);
    this.cameras.main.stopFollow();
    this.cameras.main.centerOn(W / 2, H / 2);
    AudioApi.play('meco', this.settings);
    setBanner('JACKLYN — hold boost to brake, steer the deck', 'warn', 2800);
  }

  update(_time, delta) {
    const dt = Math.min(0.033, delta / 1000);
    this.nowSec += dt;
    if (this.paused || this.settingsOpen) {
      this.refreshHud();
      return;
    }
    if (this.status === 'PAD') this.updatePad(dt);
    else if (this.status === 'ASCENT') this.updateAscent(dt);
    else if (this.status === 'JACKLYN') this.updateJacklyn(dt);
    this.updateFloaters(dt);
    this.refreshHud();
  }

  updatePad(dt) {
    const boosting = isBoosting(this.inputState, this.nowSec);
    this.session.charge = clamp(
      this.session.charge + (boosting ? dt * 0.55 : -dt * 0.22),
      0,
      1,
    );
    this.session.throttle = this.session.charge;
    this.rocket.setPosition(560, 430 - this.session.charge * 8);
    this.rocket.setVelocity(0, 0);
    if (boosting) this.emitPlume(0.35);
    if (this.session.charge >= 1) this.liftoff();
  }

  updateAscent(dt) {
    const mode = DIFFICULTY[this.settings.difficulty];
    this.session.flightTime += dt;
    this.session.grace = Math.max(0, this.session.grace - dt);
    this.session.overdrive = Math.max(0, this.session.overdrive - dt);

    const boosting = isBoosting(this.inputState, this.nowSec);
    if (boosting && this.session.fuel > 0) {
      this.session.fuel = Math.max(0, this.session.fuel - mode.fuelDrain * 22 * dt);
      this.session.throttle = clamp(this.session.throttle + dt * 2.4, 0.2, 1);
    } else {
      this.session.throttle = clamp(this.session.throttle - dt * 1.1, 0, 0.15);
    }

    let axis = steerAxis(this.inputState);
    if (this.inputState.pointerX != null) {
      axis = clamp((this.inputState.pointerX - this.rocket.x) / 140, -1, 1);
    }
    const kick = this.session.overdrive > 0 ? 1.28 : 1;
    const thrust = this.session.throttle * kick;
    if (thrust > 0.08 && this.session.fuel > 0) {
      this.rocket.applyForce({ x: axis * 0.0011, y: -0.0028 * thrust });
      this.emitPlume(thrust);
      AudioApi.rumble(0.35 + thrust * 0.4, this.settings);
    } else {
      this.rocket.applyForce({ x: axis * 0.00025, y: 0.0004 });
    }

    this.rocket.setAngularVelocity(0);
    this.rocket.setAngle(clamp(this.rocket.body.velocity.x * 4 + axis * 6, -18, 18));
    this.rocket.x = clamp(this.rocket.x, 80, W - 80);

    const vy = this.rocket.body.velocity.y;
    this.session.velocity = Math.max(0, Math.round((-vy) * 90 + this.session.altitudeKm * 18));
    this.session.altitudeKm = clamp((430 - this.rocket.y) / 80, 0, 80);
    this.session.score += Math.max(0, (-vy) * 22 * dt * (1 + this.session.combo * 0.08));

    if (this.session.altitudeKm > 12 && this.session.stage === 'ASCENT') {
      this.session.stage = 'MAX-Q';
      this.session.radio = RADIO.MAXQ;
      setBanner('MAX-Q', 'warn', 1400);
    }

    this.session.spawnAt -= dt;
    if (this.session.spawnAt <= 0 && this.session.grace <= 0) {
      this.spawnHazard();
      if (Math.random() < 0.28 * mode.pickupMul) this.spawnPickup();
      this.session.spawnAt = rand(0.7, 1.35) / mode.spawnMul;
    }
    this.advanceActors(dt, 1);

    if (this.session.altitudeKm >= ASCENT_TARGET_KM) {
      this.session.radio = RADIO.MECO;
      setBanner('MECO — booster RTLS', 'go', 1600);
      this.enterJacklyn();
    }
  }

  updateJacklyn(dt) {
    if (this.session.landingLock) return;
    const mode = DIFFICULTY[this.settings.difficulty];
    const boosting = isBoosting(this.inputState, this.nowSec);
    let axis = steerAxis(this.inputState);
    if (this.inputState.pointerX != null) {
      axis = clamp((this.inputState.pointerX - this.rocket.x) / 160, -1, 1);
    }
    if (mode.assist > 0) {
      const err = (this.jacklyn.x - this.rocket.x) / 200;
      axis = clamp(axis + err * mode.assist, -1, 1);
    }
    if (boosting && this.session.fuel > 0) {
      this.session.fuel = Math.max(0, this.session.fuel - mode.fuelDrain * 18 * dt);
      this.rocket.applyForce({ x: axis * 0.0014, y: -0.0036 });
      this.session.throttle = 1;
      this.emitPlume(0.9);
    } else {
      this.rocket.applyForce({ x: axis * 0.0005, y: 0 });
      this.session.throttle = 0.1;
    }
    this.rocket.setAngularVelocity(0);
    this.rocket.setAngle(clamp(this.rocket.body.velocity.x * 5, -16, 16));
    this.rocket.x = clamp(this.rocket.x, 70, W - 70);
    this.session.velocity = Math.round(this.rocket.body.velocity.y * 42);
    this.session.altitudeKm = clamp((this.jacklyn.y - 40 - this.rocket.y) / 90, 0, 8);

    if (this.rocket.y > 700) this.resolveLanding('water');
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
    this.session.landingLock = true;
    const mode = DIFFICULTY[this.settings.difficulty];
    const vy = Math.abs(this.rocket.body.velocity.y);
    const dx = Math.abs(this.rocket.x - this.jacklyn.x);
    const onPaint = dx <= mode.landingTol;
    const soft = vy <= mode.landingVy;
    this.rocket.setVelocity(0, 0);
    this.rocket.setIgnoreGravity(true);

    if (kind === 'deck' && onPaint && soft) {
      this.session.recovered = true;
      this.session.score += JACKLYN_BONUS;
      this.session.combo += 2;
      this.session.radio = RADIO.RECOVERED;
      this.rocket.setPosition(this.jacklyn.x, this.jacklyn.y - 78);
      if (!this.settings.reducedMotion) {
        this.cameras.main.shake(180, 0.004);
        this.time.timeScale = 0.55;
        this.time.delayedCall(400, () => { this.time.timeScale = 1; });
      }
      this.steam.emitParticleAt(this.rocket.x, this.jacklyn.y - 20, 16);
      AudioApi.play('touchdown', this.settings);
      setBanner('BOOSTER RECOVERED — JACKLYN', 'go', 3200);
      this.vibrate([40, 30, 40]);
      this.time.delayedCall(1400, () => this.endMission('recovered'));
      return;
    }

    if (kind === 'deck') {
      this.session.salvage = true;
      this.session.score += JACKLYN_SALVAGE;
      this.session.combo = 0;
      this.session.radio = RADIO.SALVAGE;
      this.rocket.setPosition(this.jacklyn.x + clamp(this.rocket.x - this.jacklyn.x, -40, 40), this.jacklyn.y - 74);
      AudioApi.play('hit', this.settings);
      setBanner('HARD CATCH — salvage, combo reset', 'warn', 2800);
      this.time.delayedCall(1300, () => this.endMission('salvage'));
      return;
    }

    this.session.splash = true;
    this.session.score = Math.max(0, this.session.score - SPLASH_PENALTY);
    this.session.combo = 0;
    this.session.radio = RADIO.SPLASH;
    AudioApi.play('splash', this.settings);
    setBanner('SPLASH — score hit, mission continues', 'fail', 2800);
    this.time.delayedCall(1200, () => this.endMission('splash'));
  }

  spawnHazard() {
    const mode = DIFFICULTY[this.settings.difficulty];
    const kinds = this.session.altitudeKm < 8
      ? ['bird', 'bird', 'balloon']
      : this.session.altitudeKm < 22
        ? ['balloon', 'ice', 'bird']
        : ['ice', 'debris', 'debris'];
    const kind = pick(kinds);
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
      setBanner('CLOSE CALL', 'warn', 900);
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
    obj.destroy();
    this.session.combo += 1;
    this.session.bestCombo = Math.max(this.session.bestCombo, this.session.combo);
    this.session.score += 180 * this.session.combo;
    if (kind === 'shield') {
      this.session.shield = Math.min(SHIELD_MAX, this.session.shield + 1);
      AudioApi.play('shield', this.settings);
      setBanner('AERO SHIELD', 'info', 900);
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

  emitPlume(power) {
    if (this.settings.reducedMotion) return;
    const n = power > 0.7 ? 3 : 1;
    this.plume.emitParticleAt(this.rocket.x, this.rocket.y + 88, n);
  }

  updateFloaters() {}

  clearActors() {
    [...this.hazards, ...this.pickups].forEach((item) => item.destroy());
    this.hazards = [];
    this.pickups = [];
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
    };
    saveSettings(this.settings);
    if (typeof window.recordGameScore === 'function') {
      window.recordGameScore('new-glenn-runner', points);
    }
    const headline = reason === 'recovered'
      ? 'BOOSTER RECOVERED'
      : reason === 'splash'
        ? 'SPLASHDOWN — FLY AGAIN'
        : reason === 'salvage'
          ? 'HARD CATCH ON JACKLYN'
          : 'MISSION ABORT';
    AudioApi.play(reason === 'rud' ? 'rud' : 'success', this.settings);
    setBanner(`${headline}   SCORE ${points.toLocaleString()}`, reason === 'rud' ? 'fail' : 'go', 0);
    this.refreshHud();
  }

  togglePause() {
    if (this.status === 'MENU' || this.status === 'SUMMARY') return;
    this.paused = !this.paused;
    if (this.paused) this.matter.world.pause();
    else this.matter.world.resume();
    setBanner(this.paused ? 'PAUSED' : 'RESUMED', 'info', 900);
    this.refreshHud();
  }

  toggleMute() {
    this.settings.muted = !this.settings.muted;
    AudioApi.setMute(this.settings);
    saveSettings(this.settings);
    this.refreshHud();
  }

  toggleSettings() {
    this.settingsOpen = !this.settingsOpen;
    const panel = document.getElementById('ng-settings');
    if (panel) panel.hidden = !this.settingsOpen;
    if (this.settingsOpen) syncSettingsForm(this.settings);
  }

  toggleFullscreen() {
    const wrap = document.getElementById('arcade-fs-wrapper');
    if (!wrap) return;
    const active = document.fullscreenElement === wrap;
    if (active) document.exitFullscreen?.();
    else wrap.requestFullscreen?.();
    wrap.classList.toggle('arcade-immersive', !active);
    document.documentElement.classList.toggle('arcade-immersive-open', !active);
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
    this.refreshHud();
  }

  vibrate(pattern) {
    if (!this.settings.haptics || !('vibrate' in navigator)) return;
    try { navigator.vibrate(pattern); } catch { /* ignore */ }
  }

  parkRecovery() {
    this.jacklyn.setPosition(-2400, 2400);
    this.water.position.x = -2400;
    this.water.position.y = 2600;
  }

  placeRecovery() {
    this.jacklyn.setPosition(W / 2, 620);
    this.water.position.x = W / 2;
    this.water.position.y = 780;
  }

  refreshHud() {
    const s = this.session || this.freshSession();
    const boosting = isBoosting(this.inputState, this.nowSec);
    const best = this.settings.hiArcadeScore || 0;
    const last = this.settings.lastArcadeScore || 0;
    renderHud({
      alt: `${s.altitudeKm.toFixed(1)} km`,
      vel: `${Math.round(s.velocity)} m/s`,
      throttle: this.status === 'PAD'
        ? `CHG ${(s.charge * 100).toFixed(0)}%`
        : `THR ${(s.throttle * 100).toFixed(0)}%  FUEL ${s.fuel.toFixed(0)}`,
      stage: s.stage,
      score: Math.max(0, Math.round(s.score)).toLocaleString(),
      best: best.toLocaleString(),
      combo: `×${s.combo}  SHLD ${s.shield}`,
      radio: s.radio,
      muted: this.settings.muted,
      paused: this.paused,
      boostLabel: this.status === 'JACKLYN' ? 'HOLD TO BRAKE' : 'HOLD TO CLIMB',
      recordLine: best || last
        ? `PB ${best.toLocaleString()}  ·  LAST ${last.toLocaleString()}  ·  ${this.settings.difficulty}`
        : `NO MISSIONS FLOWN  ·  ${this.settings.difficulty}`,
    });
    document.body.dataset.phase = this.status;
    if (boosting && this.status === 'ASCENT' && !this.settings.reducedMotion) {
      /* plume handled in update */
    }
  }
}
