import Phaser from './phaser-global.js';
import { H, W } from './config.js';
import MissionScene from './mission.js';

const parent = document.getElementById('ng-phaser-root');
const debug = new URLSearchParams(window.location.search).get('debug') === '1';

const game = new Phaser.Game({
  type: Phaser.WEBGL,
  parent,
  width: W,
  height: H,
  backgroundColor: '#071018',
  banner: false,
  audio: { disableWebAudio: false },
  physics: {
    default: 'matter',
    matter: {
      gravity: { x: 0, y: 0.85 },
      enableSleeping: true,
      debug,
    },
  },
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    parent,
    width: W,
    height: H,
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

window.NEW_GLENN_ENGINE = 'phaser4';
window.__ngGame = game;
