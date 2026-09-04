/** Procedural LC-36 / New Glenn / Jacklyn sprites. Pad uses the ILT only. */
import { MISSIONS } from './missions.js';

function canvas(w, h) {
  const cv = document.createElement('canvas');
  cv.width = w;
  cv.height = h;
  return cv;
}

function featherPath(ctx, x, y, s) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(s, s);
  ctx.fillStyle = '#0055c8';
  ctx.beginPath();
  ctx.moveTo(0, -18);
  ctx.bezierCurveTo(10, -10, 14, 2, 6, 18);
  ctx.bezierCurveTo(4, 8, 2, 0, 0, -4);
  ctx.bezierCurveTo(-2, 0, -4, 8, -6, 18);
  ctx.bezierCurveTo(-14, 2, -10, -10, 0, -18);
  ctx.fill();
  ctx.restore();
}

export function makeRocket(fairing, payload) {
  const cv = canvas(72, 220);
  const ctx = cv.getContext('2d');
  ctx.translate(36, 18);

  if (fairing) {
    const g = ctx.createLinearGradient(0, 0, 0, 52);
    g.addColorStop(0, '#ffffff');
    g.addColorStop(1, '#e8eef6');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.bezierCurveTo(16, 8, 20, 28, 20, 52);
    ctx.lineTo(-20, 52);
    ctx.bezierCurveTo(-20, 28, -16, 8, 0, 0);
    ctx.fill();
    ctx.fillStyle = payload?.accent || '#d5dde6';
    ctx.fillRect(-20, 50, 40, 5);
    if (payload?.mark) {
      ctx.fillStyle = payload.accent || '#3ec6ff';
      ctx.font = 'bold 9px "IBM Plex Mono", ui-monospace, monospace';
      ctx.textAlign = 'center';
      ctx.fillText(payload.mark, 0, 44);
    }
  } else {
    ctx.fillStyle = '#f4f7fb';
    ctx.fillRect(-16, 28, 32, 26);
    ctx.fillStyle = '#c5ced8';
    ctx.fillRect(-10, 24, 20, 8);
  }

  ctx.fillStyle = '#f7fbff';
  ctx.fillRect(-20, 54, 40, 118);

  ctx.fillStyle = '#c48a2a';
  ctx.fillRect(-20, 96, 40, 10);
  ctx.fillStyle = '#a56b16';
  ctx.fillRect(-20, 148, 40, 14);

  ctx.fillStyle = '#e8eef4';
  ctx.fillRect(-22, 160, 44, 18);
  ctx.fillStyle = '#c48a2a';
  ctx.fillRect(-24, 176, 48, 10);

  featherPath(ctx, 0, 128, 0.72);

  ctx.fillStyle = '#fff';
  ctx.fillRect(10, 72, 10, 6);
  ctx.fillStyle = '#b22234';
  ctx.fillRect(10, 72, 10, 2);
  ctx.fillRect(10, 76, 10, 2);
  ctx.fillStyle = '#3c3b6e';
  ctx.fillRect(10, 72, 4, 6);

  for (let i = 0; i < 7; i++) {
    const x = -18 + i * 6;
    ctx.fillStyle = '#2b3038';
    ctx.beginPath();
    ctx.ellipse(x, 196, 3.2, 6, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#6d7380';
    ctx.beginPath();
    ctx.ellipse(x, 194, 1.6, 3, 0, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.strokeStyle = 'rgba(20,28,40,0.18)';
  ctx.strokeRect(-20, 54, 40, 118);
  return cv;
}

export function makePad() {
  const w = 1280;
  const h = 720;
  const cv = canvas(w, h);
  const ctx = cv.getContext('2d');

  const sky = ctx.createLinearGradient(0, 0, 0, h);
  sky.addColorStop(0, '#6fb4e8');
  sky.addColorStop(0.42, '#8ec6e6');
  sky.addColorStop(0.62, '#c5d8c4');
  sky.addColorStop(0.78, '#d7c9a4');
  sky.addColorStop(1, '#b9c3b0');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h);

  ctx.fillStyle = '#1d5f8a';
  ctx.fillRect(0, 430, w, 80);
  const ocean = ctx.createLinearGradient(0, 430, 0, 510);
  ocean.addColorStop(0, '#2a7aaa');
  ocean.addColorStop(1, '#164862');
  ctx.fillStyle = ocean;
  ctx.fillRect(0, 448, w, 62);

  ctx.fillStyle = '#5d7a48';
  ctx.beginPath();
  ctx.moveTo(0, 508);
  for (let x = 0; x <= w; x += 18) {
    ctx.lineTo(x, 500 + Math.sin(x * 0.04) * 6 + (x % 36 === 0 ? 4 : 0));
  }
  ctx.lineTo(w, 560);
  ctx.lineTo(0, 560);
  ctx.fill();
  ctx.fillStyle = '#6e8a52';
  for (let i = 0; i < 40; i++) {
    const x = (i * 37) % w;
    ctx.fillRect(x, 512 + (i % 5) * 3, 3, 10);
  }

  ctx.fillStyle = '#9aa3a8';
  ctx.fillRect(0, 548, w, 172);
  ctx.fillStyle = '#8b9499';
  for (let y = 560; y < h; y += 36) ctx.fillRect(0, y, w, 2);
  for (let x = 0; x < w; x += 48) ctx.fillRect(x, 548, 2, 172);
  ctx.fillStyle = '#7e868c';
  ctx.fillRect(0, 548, w, 8);

  drawGse(ctx, 210, 548);
  drawLaunchTable(ctx, 560, 548);
  drawIlt(ctx, 760, 548);

  ctx.fillStyle = 'rgba(12,16,22,0.35)';
  ctx.fillRect(430, 536, 260, 14);

  ctx.fillStyle = '#cfd6dc';
  ctx.fillRect(40, 620, 70, 28);
  ctx.fillRect(118, 628, 36, 18);
  ctx.fillStyle = '#2a3138';
  ctx.beginPath();
  ctx.arc(62, 650, 7, 0, Math.PI * 2);
  ctx.arc(98, 650, 7, 0, Math.PI * 2);
  ctx.fill();

  return cv;
}

function drawLaunchTable(ctx, x, groundY) {
  ctx.save();
  ctx.translate(x, groundY);
  ctx.fillStyle = '#5c636b';
  ctx.fillRect(-90, -18, 180, 18);
  ctx.fillStyle = '#3d444c';
  ctx.fillRect(-70, -34, 140, 16);
  ctx.strokeStyle = '#1c2128';
  ctx.lineWidth = 3;
  ctx.strokeRect(-70, -34, 140, 16);
  ctx.beginPath();
  ctx.moveTo(-70, -34);
  ctx.lineTo(-50, -18);
  ctx.moveTo(70, -34);
  ctx.lineTo(50, -18);
  ctx.stroke();
  ctx.fillStyle = '#2a3038';
  ctx.fillRect(-28, -8, 56, 8);
  ctx.restore();
}

function drawGse(ctx, x, groundY) {
  ctx.save();
  ctx.translate(x, groundY);
  ctx.fillStyle = '#4a5158';
  ctx.fillRect(-70, -118, 150, 118);
  ctx.fillStyle = '#3a4046';
  ctx.fillRect(-78, -128, 166, 14);
  ctx.strokeStyle = '#1e242b';
  ctx.lineWidth = 2;
  for (let y = -108; y < 0; y += 16) {
    ctx.beginPath();
    ctx.moveTo(-66, y);
    ctx.lineTo(76, y);
    ctx.stroke();
  }
  ctx.fillStyle = '#2f353c';
  ctx.fillRect(-86, -70, 22, 70);
  ctx.fillRect(86, -88, 18, 88);
  ctx.fillStyle = '#c9a227';
  ctx.fillRect(-8, -142, 10, 14);
  ctx.restore();
}

function drawIlt(ctx, x, groundY) {
  const height = 430;
  ctx.save();
  ctx.translate(x, groundY);
  ctx.strokeStyle = '#2b3036';
  ctx.lineWidth = 5;
  ctx.beginPath();
  ctx.moveTo(-42, 0);
  ctx.lineTo(-28, -height);
  ctx.moveTo(42, 0);
  ctx.lineTo(28, -height);
  ctx.moveTo(0, 0);
  ctx.lineTo(0, -height);
  ctx.stroke();
  ctx.strokeStyle = '#3a4048';
  ctx.lineWidth = 2;
  for (let y = -18; y > -height + 10; y -= 22) {
    const taper = 8 * (1 + y / height);
    ctx.beginPath();
    ctx.moveTo(-38 + taper, y);
    ctx.lineTo(38 - taper, y - 14);
    ctx.moveTo(38 - taper, y);
    ctx.lineTo(-38 + taper, y - 14);
    ctx.stroke();
  }
  const platforms = [
    { y: -90, w: 118, h: 36 },
    { y: -190, w: 110, h: 34 },
    { y: -286, w: 102, h: 32 },
    { y: -368, w: 88, h: 28 },
  ];
  platforms.forEach((p) => {
    ctx.fillStyle = '#1a1e24';
    ctx.fillRect(-p.w * 0.55, p.y, p.w, p.h);
    ctx.fillStyle = '#2a3038';
    ctx.fillRect(-p.w * 0.55 + 4, p.y + 4, p.w - 8, p.h - 8);
    ctx.strokeStyle = '#0d1014';
    ctx.strokeRect(-p.w * 0.55, p.y, p.w, p.h);
    ctx.fillStyle = '#6d767e';
    ctx.fillRect(-p.w * 0.55, p.y + p.h - 5, p.w + 36, 5);
    ctx.fillStyle = '#11151b';
    ctx.fillRect(p.w * 0.12, p.y + 6, 22, p.h - 12);
  });
  ctx.strokeStyle = '#2b3036';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(0, -height);
  ctx.lineTo(0, -height - 46);
  ctx.stroke();
  ctx.fillStyle = '#d24a4a';
  ctx.beginPath();
  ctx.arc(0, -height - 48, 3, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

/**
 * Authentic New Glenn recovery silhouette (hard constraint):
 * metallic gold upper ring, four LARGE solid black strakes just below it,
 * tall white cylinder, optional BLUE ORIGIN.
 * REJECT Falcon cues: lattice grid fins, A-frame landing legs,
 * 3-1 landing-burn language, ASDS circle-X droneship.
 */
export function makeBooster() {
  const cv = canvas(96, 268);
  const ctx = cv.getContext('2d');
  ctx.translate(48, 10);

  const gold = ctx.createLinearGradient(-24, 0, 24, 52);
  gold.addColorStop(0, '#f3d58a');
  gold.addColorStop(0.35, '#d4a43a');
  gold.addColorStop(0.7, '#b47a18');
  gold.addColorStop(1, '#7a4e0e');
  ctx.fillStyle = gold;
  ctx.fillRect(-24, 0, 48, 50);
  ctx.fillStyle = 'rgba(255,236,180,0.35)';
  ctx.fillRect(-22, 4, 10, 42);

  ctx.fillStyle = '#f4f7fb';
  ctx.fillRect(-22, 50, 44, 168);

  ctx.fillStyle = '#0b0d12';
  [[-38, 52], [22, 52], [-36, 86], [20, 86]].forEach(([x, y], i) => {
    const h = i < 2 ? 30 : 26;
    ctx.beginPath();
    ctx.moveTo(x < 0 ? -22 : 22, y + 4);
    ctx.lineTo(x, y + 8);
    ctx.lineTo(x, y + h);
    ctx.lineTo(x < 0 ? -22 : 22, y + h - 8);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#1a1d24';
    ctx.fillRect(x < 0 ? x + 2 : 22, y + 10, 3, h - 14);
    ctx.fillStyle = '#0b0d12';
  });

  ctx.fillStyle = '#0b0d12';
  ctx.font = 'bold 9px "IBM Plex Mono", ui-monospace, monospace';
  ctx.save();
  ctx.translate(-7, 148);
  ctx.rotate(-Math.PI / 2);
  ctx.fillText('BLUE ORIGIN', 0, 0);
  ctx.restore();

  ctx.fillStyle = '#c48a2a';
  ctx.fillRect(-24, 206, 48, 12);

  for (let i = 0; i < 7; i++) {
    const x = -18 + i * 6;
    ctx.fillStyle = '#2b3038';
    ctx.beginPath();
    ctx.ellipse(x, 232, 3.2, 7, 0, 0, Math.PI * 2);
    ctx.fill();
  }
  return cv;
}

/** Jacklyn: dark deck between white multi-story bow/stern bookends. Not an ASDS circle-X droneship. */
export function makeJacklyn() {
  const cv = canvas(640, 220);
  const ctx = cv.getContext('2d');
  ctx.fillStyle = '#063044';
  ctx.fillRect(0, 188, 640, 32);
  ctx.fillStyle = '#12181e';
  ctx.fillRect(118, 142, 404, 50);
  ctx.fillStyle = '#1a222a';
  ctx.fillRect(132, 128, 376, 18);

  const bookend = (x, w, h, roof) => {
    ctx.fillStyle = '#f4f7fb';
    ctx.fillRect(x, roof, w, h);
    ctx.fillStyle = '#dfe6ee';
    ctx.fillRect(x + 8, roof + 10, w - 16, 26);
    ctx.fillStyle = '#9aa6b2';
    for (let row = 0; row < 4; row++) {
      for (let col = 0; col < 3; col++) {
        ctx.fillRect(x + 12 + col * 18, roof + 44 + row * 18, 10, 10);
      }
    }
  };
  bookend(16, 108, 148, 44);
  bookend(516, 108, 156, 36);

  ctx.fillStyle = '#c5ced6';
  ctx.beginPath();
  ctx.arc(70, 36, 18, 0, Math.PI * 2);
  ctx.arc(570, 28, 20, 0, Math.PI * 2);
  ctx.arc(94, 30, 10, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = '#ffcf5d';
  ctx.lineWidth = 3;
  ctx.setLineDash([10, 7]);
  ctx.strokeRect(246, 132, 148, 20);
  ctx.setLineDash([]);

  ctx.fillStyle = '#0b0d12';
  ctx.font = 'bold 26px "IBM Plex Mono", ui-monospace, monospace';
  ctx.textAlign = 'center';
  ctx.fillText('JACKLYN', 320, 184);
  return cv;
}

export function makeOcean() {
  const cv = canvas(1280, 720);
  const ctx = cv.getContext('2d');
  const sky = ctx.createLinearGradient(0, 0, 0, 720);
  sky.addColorStop(0, '#061018');
  sky.addColorStop(0.4, '#0c2438');
  sky.addColorStop(0.68, '#0e3a55');
  sky.addColorStop(1, '#072838');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, 1280, 720);
  const sea = ctx.createLinearGradient(0, 410, 0, 720);
  sea.addColorStop(0, '#0a3a52');
  sea.addColorStop(0.45, '#072c40');
  sea.addColorStop(1, '#041c2a');
  ctx.fillStyle = sea;
  ctx.fillRect(0, 410, 1280, 310);
  ctx.fillStyle = 'rgba(180,220,240,0.06)';
  for (let y = 430; y < 700; y += 22) {
    ctx.fillRect(0, y, 1280, 2);
  }
  ctx.fillStyle = 'rgba(255,255,255,0.5)';
  for (let i = 0; i < 36; i++) {
    ctx.fillRect((i * 97) % 1280, (i * 53) % 380, 2, 2);
  }
  return cv;
}

/** Blinding landing bloom — orange/yellow, ADD-blended. */
export function makeBloom() {
  const cv = canvas(220, 220);
  const ctx = cv.getContext('2d');
  const g = ctx.createRadialGradient(110, 110, 8, 110, 110, 108);
  g.addColorStop(0, '#fff6c8');
  g.addColorStop(0.18, '#ffe056');
  g.addColorStop(0.45, '#ff9a18');
  g.addColorStop(0.75, 'rgba(255,80,0,0.45)');
  g.addColorStop(1, 'rgba(120,20,0,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 220, 220);
  return cv;
}

/** Thick brownish-orange smoke bank that hides ship + lower booster. */
export function makeSmokeBank() {
  const cv = canvas(460, 210);
  const ctx = cv.getContext('2d');
  const blobs = [
    [80, 130, 90, '#5a3010'],
    [180, 120, 110, '#6e3a14'],
    [280, 124, 100, '#4a240c'],
    [360, 132, 88, '#7a4218'],
    [230, 150, 120, '#3d1c0a'],
    [140, 160, 80, '#8a4a1c'],
    [320, 168, 86, '#5c2c10'],
  ];
  blobs.forEach(([x, y, r, color]) => {
    const g = ctx.createRadialGradient(x, y, 8, x, y, r);
    g.addColorStop(0, color);
    g.addColorStop(0.55, color);
    g.addColorStop(1, 'rgba(40,16,4,0)');
    ctx.fillStyle = g;
    ctx.globalAlpha = 0.88;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
  });
  ctx.globalAlpha = 1;
  return cv;
}

export function makeDot(color, w = 18, h = 18) {
  const cv = canvas(w, h);
  const ctx = cv.getContext('2d');
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.ellipse(w / 2, h / 2, w / 2 - 1, h / 2 - 1, 0, 0, Math.PI * 2);
  ctx.fill();
  return cv;
}

export function makeHazard(kind) {
  const cv = canvas(40, 40);
  const ctx = cv.getContext('2d');
  ctx.translate(20, 20);
  if (kind === 'bird') {
    ctx.strokeStyle = '#1e2430';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(-14, 0);
    ctx.quadraticCurveTo(-6, -10, 0, 0);
    ctx.quadraticCurveTo(6, -10, 14, 0);
    ctx.stroke();
  } else if (kind === 'balloon') {
    ctx.fillStyle = '#e85d4c';
    ctx.beginPath();
    ctx.ellipse(0, -4, 10, 13, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#c9d0d6';
    ctx.beginPath();
    ctx.moveTo(0, 9);
    ctx.lineTo(0, 16);
    ctx.stroke();
  } else if (kind === 'ice') {
    ctx.fillStyle = '#d7f3ff';
    ctx.strokeStyle = '#8ec8e0';
    ctx.beginPath();
    ctx.moveTo(0, -12);
    ctx.lineTo(12, 2);
    ctx.lineTo(4, 12);
    ctx.lineTo(-10, 8);
    ctx.lineTo(-8, -6);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
  } else {
    ctx.fillStyle = '#8a9098';
    ctx.fillRect(-10, -6, 20, 12);
    ctx.fillStyle = '#c48a2a';
    ctx.fillRect(-10, -2, 20, 4);
  }
  return cv;
}

export function makePickup(kind) {
  const cv = canvas(36, 36);
  const ctx = cv.getContext('2d');
  ctx.translate(18, 18);
  if (kind === 'shield') {
    ctx.fillStyle = '#8ce0ff';
    ctx.beginPath();
    ctx.moveTo(0, -12);
    ctx.lineTo(12, -4);
    ctx.lineTo(8, 12);
    ctx.lineTo(-8, 12);
    ctx.lineTo(-12, -4);
    ctx.closePath();
    ctx.fill();
  } else if (kind === 'fuel') {
    ctx.fillStyle = '#9df6bf';
    ctx.fillRect(-7, -12, 14, 24);
    ctx.fillStyle = '#146a3a';
    ctx.fillText('LOX', -10, 4);
  } else {
    ctx.fillStyle = '#ffcf5d';
    ctx.beginPath();
    ctx.moveTo(0, -12);
    ctx.lineTo(10, 12);
    ctx.lineTo(-10, 12);
    ctx.closePath();
    ctx.fill();
  }
  return cv;
}

export function makeSpark() {
  return makeDot('#ffb24a', 10, 10);
}

export function installTextures(scene) {
  const add = (key, cv) => {
    if (scene.textures.exists(key)) scene.textures.remove(key);
    scene.textures.addCanvas(key, cv);
  };
  add('rocket', makeRocket(true));
  add('booster', makeBooster());
  add('bloom', makeBloom());
  add('rcs', makeDot('#f4fbff', 16, 16));
  add('soot', makeDot('#6a3a18', 36, 36));
  add('smoke-bank', makeSmokeBank());
  MISSIONS.forEach((mission) => {
    add(`rocket-${mission.id}`, makeRocket(true, mission));
  });
  add('pad', makePad());
  add('ocean', makeOcean());
  add('jacklyn', makeJacklyn());
  add('bird', makeHazard('bird'));
  add('balloon', makeHazard('balloon'));
  add('ice', makeHazard('ice'));
  add('debris', makeHazard('debris'));
  add('pickup-shield', makePickup('shield'));
  add('pickup-fuel', makePickup('fuel'));
  add('pickup-boost', makePickup('boost'));
  add('spark', makeSpark());
  add('steam', makeDot('rgba(230,240,255,0.9)', 16, 16));
  add('deck-pad', canvas(168, 28));
}
