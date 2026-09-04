/** Lightweight Web Audio bed — unlocks on first gesture, honors mute. */
const AudioApi = {
  ctx: null,
  master: null,
  unlocked: false,
  mood: 'idle',
  nodes: [],

  now() {
    return this.ctx ? this.ctx.currentTime : 0;
  },

  ensure(settings) {
    if (settings && settings.muted) return false;
    if (this.ctx) return true;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return false;
    this.ctx = new AC();
    this.master = this.ctx.createGain();
    this.master.gain.value = 0.16;
    this.master.connect(this.ctx.destination);
    return true;
  },

  unlock(settings) {
    if (settings && settings.muted) return false;
    if (!this.ensure(settings)) return false;
    if (this.ctx.state === 'suspended') this.ctx.resume();
    this.unlocked = true;
    return true;
  },

  setMute(settings) {
    if (!this.ensure(settings) || !this.master) return;
    this.master.gain.setTargetAtTime(settings.muted ? 0.0001 : 0.16, this.now(), 0.04);
  },

  tone(freq, dur, type, gain, slide) {
    if (!this.ctx || !this.master) return;
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

  play(name, settings) {
    if (!settings || !settings.sound || settings.muted) return;
    if (!this.unlock(settings)) return;
    switch (name) {
      case 'ui':
        this.tone(520, 0.06, 'square', 0.03);
        break;
      case 'boost':
        this.tone(90, 0.16, 'sawtooth', 0.05, 60);
        break;
      case 'pickup':
        this.tone(660, 0.1, 'triangle', 0.04, 880);
        break;
      case 'shield':
        this.tone(420, 0.12, 'sine', 0.04, 280);
        break;
      case 'fuel':
        this.tone(240, 0.14, 'triangle', 0.035, 360);
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
        this.tone(140, 0.22, 'triangle', 0.04, 90);
        break;
      case 'touchdown':
        this.tone(220, 0.28, 'sine', 0.05, 110);
        this.tone(330, 0.2, 'triangle', 0.03);
        break;
      case 'splash':
        this.tone(90, 0.3, 'sine', 0.05, 40);
        break;
      case 'rud':
        this.tone(48, 0.45, 'sawtooth', 0.07, 30);
        break;
      case 'success':
        this.tone(440, 0.12, 'triangle', 0.04);
        this.tone(660, 0.16, 'triangle', 0.035);
        break;
      case 'countdown':
        this.tone(880, 0.05, 'square', 0.03);
        break;
      default:
        this.tone(400, 0.06, 'sine', 0.025);
    }
  },

  rumble(level, settings) {
    if (!settings || !settings.sound || settings.muted || !this.ctx) return;
    if (level <= 0.02) return;
    this.tone(48 + level * 20, 0.05, 'sawtooth', 0.012 * level);
  },
};

export default AudioApi;
