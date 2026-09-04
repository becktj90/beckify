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

/** First-stage booster: gold crown + four solid black strakes. No grid fins. */
export function makeBooster() {
  const cv = canvas(80, 240);
  const ctx = cv.getContext('2d');
  ctx.translate(40, 12);
  const gold = ctx.createLinearGradient(-22, 0, 22, 36);
  gold.addColorStop(0, '#e8c36a');
  gold.addColorStop(0.5, '#c48a2a');
  gold.addColorStop(1, '#8a5a12');
  ctx.fillStyle = gold;
  ctx.fillRect(-22, 0, 44, 34);
  ctx.fillStyle = '#f4f7fb';
  ctx.fillRect(-20, 34, 40, 150);
  ctx.fillStyle = '#111318';
  [[-28, 46], [16, 46], [-28, 78], [16, 78]].forEach(([x, y]) => {
    ctx.beginPath();
    ctx.moveTo(x < 0 ? -20 : 20, y);
    ctx.lineTo(x, y + 8);
    ctx.lineTo(x, y + 26);
    ctx.lineTo(x < 0 ? -20 : 20, y + 18);
    ctx.closePath();
    ctx.fill();
  });
  ctx.fillStyle = '#0b0d12';
  ctx.font = 'bold 8px "IBM Plex Mono", ui-monospace, monospace';
  ctx.save();
  ctx.translate(-6, 120);
  ctx.rotate(-Math.PI / 2);
  ctx.fillText('BLUE ORIGIN', 0, 0);
  ctx.restore();
  ctx.fillStyle = '#c48a2a';
  ctx.fillRect(-22, 176, 44, 12);
  for (let i = 0; i < 7; i++) {
    const x = -18 + i * 6;
    ctx.fillStyle = '#2b3038';
    ctx.beginPath();
    ctx.ellipse(x, 202, 3.2, 7, 0, 0, Math.PI * 2);
    ctx.fill();
  }
  return cv;
}

/** Jacklyn: dark deck between white bow/stern bookends. No ASDS circle-X. */
export function makeJacklyn() {
  const cv = canvas(560, 180);
  const ctx = cv.getContext('2d');
  ctx.fillStyle = '#0a2a3c';
  ctx.fillRect(0, 150, 560, 30);
  ctx.fillStyle = '#141a20';
  ctx.fillRect(86, 108, 388, 44);
  ctx.fillStyle = '#1c242c';
  ctx.fillRect(100, 96, 360, 16);
  ctx.fillStyle = '#f4f7fb';
  ctx.fillRect(12, 48, 86, 106);
  ctx.fillRect(462, 40, 86, 114);
  ctx.fillStyle = '#dfe6ee';
  ctx.fillRect(20, 56, 70, 28);
  ctx.fillRect(470, 48, 70, 28);
  ctx.fillStyle = '#c5ced6';
  ctx.beginPath();
  ctx.arc(55, 44, 16, 0, Math.PI * 2);
  ctx.arc(505, 36, 18, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#ffcf5d';
  ctx.lineWidth = 3;
  ctx.setLineDash([8, 6]);
  ctx.strokeRect(210, 98, 140, 18);
  ctx.setLineDash([]);
  ctx.beginPath();
  ctx.moveTo(250, 114);
  ctx.lineTo(280, 98);
  ctx.lineTo(310, 114);
  ctx.stroke();
  ctx.fillStyle = '#0b0d12';
  ctx.font = 'bold 22px "IBM Plex Mono", ui-monospace, monospace';
  ctx.textAlign = 'center';
  ctx.fillText('JACKLYN', 280, 148);
  return cv;
}

export function makeOcean() {
  const cv = canvas(1280, 720);
  const ctx = cv.getContext('2d');
  const sky = ctx.createLinearGradient(0, 0, 0, 720);
  sky.addColorStop(0, '#0a1020');
  sky.addColorStop(0.45, '#16324a');
  sky.addColorStop(0.7, '#1b5a78');
  sky.addColorStop(1, '#0d3a4e');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, 1280, 720);
  ctx.fillStyle = '#0a2a3a';
  ctx.fillRect(0, 430, 1280, 290);
  ctx.fillStyle = 'rgba(255,255,255,0.08)';
  for (let y = 450; y < 700; y += 16) {
    ctx.fillRect(0, y + Math.sin(y) * 2, 1280, 2);
  }
  ctx.fillStyle = 'rgba(255,255,255,0.55)';
  for (let i = 0; i < 40; i++) {
    ctx.fillRect((i * 97) % 1280, (i * 53) % 380, 2, 2);
  }
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
  add('bloom', makeDot('#ffb020', 80, 80));
  add('rcs', makeDot('#f4fbff', 12, 12));
  add('soot', makeDot('#6a3a18', 22, 22));
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
