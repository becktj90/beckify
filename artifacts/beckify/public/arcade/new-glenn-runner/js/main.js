/**
 * New Glenn Runner — Phaser 4.2.1 full build + built-in Matter.
 * Vendor file is vendor/phaser.min.js (same as jsDelivr phaser@4.2.1/dist/phaser.min.js).
 * Never swap in phaser-arcade-physics or a standalone Matter.Engine.
 */
import Phaser from './phaser-global.js';
import { H, W } from './config.js';
import MissionScene from './mission.js';

const parent = document.getElementById('ng-phaser-root');
const debug = new URLSearchParams(window.location.search).get('debug') === '1';

function preferWebGL() {
  try {
    const canvas = document.createElement('canvas');
    return Boolean(
      canvas.getContext('webgl2')
      || canvas.getContext('webgl')
      || canvas.getContext('experimental-webgl'),
    );
  } catch {
    return false;
  }
}

const game = new Phaser.Game({
  type: preferWebGL() ? Phaser.WEBGL : Phaser.AUTO, // WEBGL required; AUTO only if the device has no WebGL
  parent,
  width: W,
  height: H,
  backgroundColor: '#071018',
  banner: false,
  audio: { disableWebAudio: false },
  physics: {
    default: 'matter',
    matter: {
      gravity: { x: 0, y: 0.85 }, // arcade-tuned (Matter units, not px/s²)
      enableSleeping: true, // prefer true for settled deck / pad bodies
      debug, // true only behind ?debug=1
    },
  },
  scale: {
    // Design world is 16:9. Phaser.Scale.FIT letterboxes on 16:10/DevTools
    // parents; ENVELOP covers the cabinet (crops edges) so the playfield fills.
    // RESIZE would stretch Matter space — do not use it.
    mode: Phaser.Scale.ENVELOP,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    parent,
    width: W,
    height: H,
    expandParent: false,
  },
  input: {
    activePointers: 3,
  },
  render: {
    antialias: true,
    powerPreference: 'high-performance',
  },
  scene: [MissionScene],
});

let scaleLock = false;
function refreshScale() {
  if (scaleLock || !game.scale) return;
  scaleLock = true;
  try {
    game.scale.refresh();
  } catch {
    /* game not ready */
  }
  window.setTimeout(() => { scaleLock = false; }, 0);
}

window.addEventListener('resize', refreshScale);
window.addEventListener('orientationchange', refreshScale);
document.addEventListener('fullscreenchange', refreshScale);

window.NEW_GLENN_ENGINE = 'phaser4';
window.__ngGame = game;
