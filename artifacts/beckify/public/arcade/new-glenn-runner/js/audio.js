/**
 * Phaser Sound Manager mix for New Glenn Runner.
 * Web Audio preferred. Unlock on first gesture. Mute button is authoritative —
 * prefers-reduced-motion never mutes on its own.
 *
 * NASA trims live in ./audio/ (see ATTRIBUTION.md). Procedural tones are fallback only.
 */
const KEYS = {
  roar: { file: 'roar-loop', loop: true, vol: 0.36 },
  burn: { file: 'burn-loop', loop: true, vol: 0.32 },
  liftoff: { file: 'liftoff', vol: 0.72 },
  maxq: { file: 'maxq', vol: 0.58 },
  meco: { file: 'meco', vol: 0.52 },
  whoosh: { file: 'whoosh', vol: 0.5 },
  touchdown: { file: 'touchdown', vol: 0.58 },
  recovered: { file: 'recovered', vol: 0.64 },
  splash: { file: 'splash', vol: 0.56 },
  ui: { file: 'quindar', vol: 0.34 },
  countdown: { file: 'quindar', vol: 0.28 },
  pickup: { file: 'pickup', vol: 0.46 },
  fuel: { file: 'pickup', vol: 0.4 },
  shield: { file: 'pickup', vol: 0.4 },
  overdrive: { file: 'maxq', vol: 0.34 },
  hit: { file: 'hit', vol: 0.5 },
  rud: { file: 'rud', vol: 0.62 },
  success: { file: 'recovered', vol: 0.56 },
};

const BEDS = new Set(['roar', 'burn']);

const AudioApi = {
  scene: null,
  beds: { roar: null, burn: null },
  unlocked: false,
  ctx: null,
  master: null,

  preload(scene) {
    const files = [...new Set(Object.values(KEYS).map((spec) => spec.file))];
    files.forEach((file) => {
      scene.load.audio(`ng-${file}`, [`./audio/${file}.ogg`, `./audio/${file}.mp3`]);
    });
  },

  attach(scene) {
    this.scene = scene;
    this.applyMix(scene.settings);
  },

  masterVolume(settings) {
    const value = Number(settings?.volume);
    return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0.72;
  },

  silenced(settings) {
    return Boolean(settings?.muted) || settings?.sound === false;
  },

  bedsAllowed(settings) {
    return !this.silenced(settings) && settings?.music !== false;
  },

  unlock(settings) {
    const sound = this.scene?.sound;
    if (sound) {
      if (sound.locked) sound.unlock();
      this.unlocked = true;
      this.applyMix(settings);
      return true;
    }
    return this.ensureFallback();
  },

  applyMix(settings) {
    const sound = this.scene?.sound;
    if (!sound) return;
    sound.setMute(this.silenced(settings));
    sound.setVolume(this.masterVolume(settings));
    if (!this.bedsAllowed(settings)) this.stopBeds();
  },

  setMute(settings) {
    this.applyMix(settings);
    if (this.master) {
      this.master.gain.setTargetAtTime(
        this.silenced(settings) ? 0.0001 : 0.16 * this.masterVolume(settings),
        this.now(),
        0.04,
      );
    }
  },

  setPaused(paused) {
    Object.values(this.beds).forEach((bed) => {
      if (!bed) return;
      if (paused) bed.pause();
      else if (bed.isPaused) bed.resume();
    });
  },

  play(name, settings) {
    if (!settings || this.silenced(settings)) return;
    this.unlock(settings);
    const spec = KEYS[name];
    const sound = this.scene?.sound;
    const key = spec ? `ng-${spec.file}` : null;
    if (spec && sound && this.scene.cache?.audio?.exists(key)) {
      try {
        sound.play(key, { volume: spec.vol, loop: false });
        return;
      } catch {
        /* fallback */
      }
    }
    this.toneFor(name);
  },

  setBed(name, on, settings, volume) {
    if (!BEDS.has(name)) return;
    if (!on || !this.bedsAllowed(settings)) {
      this.stopBed(name);
      return;
    }
    this.unlock(settings);
    const spec = KEYS[name];
    const sound = this.scene?.sound;
    const key = `ng-${spec.file}`;
    if (!sound || !this.scene.cache?.audio?.exists(key)) {
      this.toneFor(name === 'roar' ? 'boost' : 'whoosh');
      return;
    }
    let bed = this.beds[name];
    const target = volume == null ? spec.vol : volume;
    if (bed?.isPlaying || bed?.isPaused) {
      if (bed.isPaused) bed.resume();
      if (typeof bed.setVolume === 'function') bed.setVolume(target);
      return;
    }
    try {
      bed = sound.add(key, { loop: true, volume: target });
      this.beds[name] = bed;
      bed.play();
    } catch {
      this.toneFor('boost');
    }
  },

  stopBed(name) {
    const bed = this.beds[name];
    if (!bed) return;
    try { bed.stop(); } catch { /* ignore */ }
    try { bed.destroy(); } catch { /* ignore */ }
    this.beds[name] = null;
  },

  stopBeds() {
    this.stopBed('roar');
    this.stopBed('burn');
  },

  rumble(level, settings) {
    if (!settings || this.silenced(settings)) return;
    this.setBed('roar', level > 0.02, settings, 0.14 + Math.min(0.32, level * 0.28));
  },

  now() {
    return this.ctx ? this.ctx.currentTime : 0;
  },

  ensureFallback() {
    if (this.ctx) return true;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return false;
    this.ctx = new AC();
    this.master = this.ctx.createGain();
    this.master.gain.value = 0.16;
    this.master.connect(this.ctx.destination);
    if (this.ctx.state === 'suspended') this.ctx.resume();
    this.unlocked = true;
    return true;
  },

  tone(freq, dur, type, gain, slide) {
    if (!this.ensureFallback() || !this.master) return;
    const t = this.now();
    const osc = this.ctx.createOscillator();
    const g = this.ctx.createGain();
    osc.type = type || 'sine';
    osc.frequency.setValueAtTime(freq, t);
    if (slide) osc.frequency.exponentialRampToValueAtTime(Math.max(40, slide), t + dur);
    g.gain.setValueAtTime(gain || 0.04, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    osc.connect(g);
    g.connect(this.master);
    osc.start(t);
    osc.stop(t + dur + 0.02);
  },

  toneFor(name) {
    switch (name) {
      case 'ui':
      case 'countdown':
        this.tone(2525, 0.08, 'sine', 0.03);
        break;
      case 'boost':
      case 'roar':
        this.tone(90, 0.16, 'sawtooth', 0.05, 60);
        break;
      case 'pickup':
      case 'fuel':
      case 'shield':
        this.tone(660, 0.1, 'triangle', 0.04, 880);
        break;
      case 'overdrive':
        this.tone(180, 0.2, 'sawtooth', 0.05, 420);
        break;
      case 'hit':
        this.tone(70, 0.18, 'square', 0.06, 40);
        break;
      case 'liftoff':
        this.tone(55, 0.4, 'sawtooth', 0.07, 140);
        break;
      case 'meco':
      case 'whoosh':
        this.tone(140, 0.22, 'triangle', 0.04, 90);
        break;
      case 'touchdown':
      case 'success':
      case 'recovered':
        this.tone(220, 0.28, 'sine', 0.05, 110);
        this.tone(330, 0.2, 'triangle', 0.03);
        break;
      case 'splash':
        this.tone(90, 0.3, 'sine', 0.05, 40);
        break;
      case 'rud':
        this.tone(48, 0.45, 'sawtooth', 0.07, 30);
        break;
      case 'maxq':
        this.tone(160, 0.18, 'sawtooth', 0.05, 220);
        break;
      default:
        this.tone(400, 0.06, 'sine', 0.025);
    }
  },
};

export default AudioApi;
