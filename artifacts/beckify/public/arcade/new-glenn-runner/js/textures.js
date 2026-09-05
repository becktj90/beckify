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
  const cv = canvas(78, 236);
  const ctx = cv.getContext('2d');
  ctx.translate(39, 16);

  if (fairing) {
    const g = ctx.createLinearGradient(0, 0, 0, 58);
    g.addColorStop(0, '#ffffff');
    g.addColorStop(0.55, '#f4f7fb');
    g.addColorStop(1, '#e4ebf2');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.bezierCurveTo(18, 10, 23, 30, 22, 58);
    ctx.lineTo(-22, 58);
    ctx.bezierCurveTo(-23, 30, -18, 10, 0, 0);
    ctx.fill();
    ctx.fillStyle = payload?.accent || '#d5dde6';
    ctx.fillRect(-22, 56, 44, 5);
    if (payload?.mark) {
      ctx.fillStyle = payload.accent || '#3ec6ff';
      ctx.font = 'bold 9px "IBM Plex Mono", ui-monospace, monospace';
      ctx.textAlign = 'center';
      ctx.fillText(payload.mark, 0, 50);
    }
  } else {
    ctx.fillStyle = '#f4f7fb';
    ctx.fillRect(-18, 30, 36, 28);
    ctx.fillStyle = '#c5ced8';
    ctx.fillRect(-12, 26, 24, 8);
  }

  ctx.fillStyle = '#f7fbff';
  ctx.fillRect(-20, 61, 40, 28);

  const goldTop = ctx.createLinearGradient(-22, 88, 22, 102);
  goldTop.addColorStop(0, '#e8c36a');
  goldTop.addColorStop(0.45, '#c48a2a');
  goldTop.addColorStop(1, '#8a5a12');
  ctx.fillStyle = goldTop;
  ctx.fillRect(-21, 88, 42, 12);

  const body = ctx.createLinearGradient(-21, 100, 21, 100);
  body.addColorStop(0, '#c5ced6');
  body.addColorStop(0.22, '#f7fbff');
  body.addColorStop(0.55, '#e8eef4');
  body.addColorStop(1, '#9aa3aa');
  ctx.fillStyle = body;
  ctx.fillRect(-21, 100, 42, 86);
  ctx.fillStyle = 'rgba(20,28,40,0.08)';
  for (let y = 108; y < 180; y += 14) ctx.fillRect(-19, y, 38, 1);

  featherPath(ctx, 0, 142, 0.78);

  ctx.fillStyle = '#fff';
  ctx.fillRect(9, 112, 11, 7);
  ctx.fillStyle = '#b22234';
  ctx.fillRect(9, 112, 11, 2);
  ctx.fillRect(9, 117, 11, 2);
  ctx.fillStyle = '#3c3b6e';
  ctx.fillRect(9, 112, 4, 7);

  const goldBase = ctx.createLinearGradient(-24, 186, 24, 206);
  goldBase.addColorStop(0, '#e0b85a');
  goldBase.addColorStop(0.5, '#c48a2a');
  goldBase.addColorStop(1, '#7a4e0e');
  ctx.fillStyle = goldBase;
  ctx.fillRect(-23, 186, 46, 16);

  ctx.fillStyle = '#0b0d12';
  [[-34, 196], [22, 196], [-32, 208], [20, 208]].forEach(([x, y], i) => {
    ctx.beginPath();
    ctx.moveTo(x < 0 ? -21 : 21, y);
    ctx.lineTo(x, y + 3);
    ctx.lineTo(x, y + (i < 2 ? 16 : 12));
    ctx.lineTo(x < 0 ? -21 : 21, y + (i < 2 ? 12 : 8));
    ctx.closePath();
    ctx.fill();
  });

  for (let i = 0; i < 7; i++) {
    const x = -18 + i * 6;
    ctx.fillStyle = '#2b3038';
    ctx.beginPath();
    ctx.ellipse(x, 214, 3.2, 6, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#6d7380';
    ctx.beginPath();
    ctx.ellipse(x, 212, 1.6, 3, 0, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.strokeStyle = 'rgba(20,28,40,0.16)';
  ctx.strokeRect(-21, 100, 42, 86);
  return cv;
}

export function makeUpperStage() {
  const cv = canvas(64, 120);
  const ctx = cv.getContext('2d');
  ctx.translate(32, 8);
  const g = ctx.createLinearGradient(0, 0, 0, 40);
  g.addColorStop(0, '#ffffff');
  g.addColorStop(1, '#e8eef6');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.bezierCurveTo(14, 8, 18, 22, 18, 40);
  ctx.lineTo(-18, 40);
  ctx.bezierCurveTo(-18, 22, -14, 8, 0, 0);
  ctx.fill();
  ctx.fillStyle = '#f4f7fb';
  ctx.fillRect(-18, 40, 36, 56);
  ctx.fillStyle = '#c48a2a';
  ctx.fillRect(-18, 88, 36, 8);
  ctx.fillStyle = '#2b3038';
  ctx.fillRect(-8, 96, 6, 12);
  ctx.fillRect(2, 96, 6, 12);
  return cv;
}

export function makeFairingHalf(side) {
  const cv = canvas(40, 70);
  const ctx = cv.getContext('2d');
  ctx.fillStyle = '#f4f7fb';
  ctx.beginPath();
  if (side < 0) {
    ctx.moveTo(38, 4);
    ctx.bezierCurveTo(8, 10, 4, 30, 6, 66);
    ctx.lineTo(38, 66);
  } else {
    ctx.moveTo(2, 4);
    ctx.bezierCurveTo(32, 10, 36, 30, 34, 66);
    ctx.lineTo(2, 66);
  }
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = 'rgba(20,28,40,0.2)';
  ctx.stroke();
  return cv;
}

export function makePad() {
  const w = 1280;
  const h = 720;
  const cv = canvas(w, h);
  const ctx = cv.getContext('2d');

  const sky = ctx.createLinearGradient(0, 0, 0, 420);
  sky.addColorStop(0, '#3a7eb8');
  sky.addColorStop(0.22, '#6aa8d4');
  sky.addColorStop(0.42, '#b8c4c0');
  sky.addColorStop(0.58, '#e8c890');
  sky.addColorStop(0.78, '#f0d4a0');
  sky.addColorStop(1, '#c8b890');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h);

  const sun = ctx.createRadialGradient(1080, 92, 8, 1080, 92, 220);
  sun.addColorStop(0, 'rgba(255,236,190,0.95)');
  sun.addColorStop(0.18, 'rgba(255,210,140,0.45)');
  sun.addColorStop(1, 'rgba(255,180,80,0)');
  ctx.fillStyle = sun;
  ctx.fillRect(820, 0, 460, 280);

  ctx.fillStyle = 'rgba(255,255,255,0.62)';
  ctx.beginPath();
  ctx.ellipse(160, 78, 120, 18, -0.18, 0, Math.PI * 2);
  ctx.ellipse(300, 64, 90, 14, 0.08, 0, Math.PI * 2);
  ctx.ellipse(440, 82, 70, 12, -0.06, 0, Math.PI * 2);
  ctx.ellipse(960, 70, 130, 16, 0.04, 0, Math.PI * 2);
  ctx.fill();

  const haze = ctx.createLinearGradient(0, 300, 0, 470);
  haze.addColorStop(0, 'rgba(220,200,160,0)');
  haze.addColorStop(1, 'rgba(200,180,140,0.28)');
  ctx.fillStyle = haze;
  ctx.fillRect(0, 300, w, 170);

  const ocean = ctx.createLinearGradient(0, 352, 0, 478);
  ocean.addColorStop(0, '#1a5580');
  ocean.addColorStop(0.28, '#247094');
  ocean.addColorStop(0.7, '#1a5a78');
  ocean.addColorStop(1, '#123e58');
  ctx.fillStyle = ocean;
  ctx.fillRect(0, 352, w, 126);
  ctx.fillStyle = 'rgba(255,255,255,0.16)';
  for (let x = 0; x < w; x += 22) {
    ctx.fillRect(x, 378 + Math.sin(x * 0.045) * 4, 14, 1.4);
    ctx.fillRect(x + 8, 410 + Math.sin(x * 0.03) * 3, 18, 1.2);
  }

  ctx.fillStyle = '#5a7040';
  ctx.beginPath();
  ctx.moveTo(0, 458);
  for (let x = 0; x <= w; x += 12) {
    ctx.lineTo(x, 452 + Math.sin(x * 0.03) * 8 + ((x * 17) % 23 === 0 ? 6 : 0));
  }
  ctx.lineTo(w, 548);
  ctx.lineTo(0, 548);
  ctx.fill();
  ctx.fillStyle = '#6e8648';
  ctx.beginPath();
  ctx.moveTo(0, 478);
  for (let x = 0; x <= w; x += 10) {
    ctx.lineTo(x, 472 + Math.sin(x * 0.05) * 5);
  }
  ctx.lineTo(w, 548);
  ctx.lineTo(0, 548);
  ctx.fill();
  ctx.fillStyle = '#7a8f52';
  for (let i = 0; i < 110; i++) {
    const x = (i * 29 + 9) % w;
    ctx.fillRect(x, 488 + (i % 9) * 4, 2 + (i % 3), 10 + (i % 6));
  }
  ctx.fillStyle = '#4a6034';
  for (let i = 0; i < 28; i++) {
    const x = (i * 47 + 14) % (w - 20);
    ctx.beginPath();
    ctx.moveTo(x, 520);
    ctx.lineTo(x + 6, 500);
    ctx.lineTo(x + 12, 520);
    ctx.fill();
  }
  ctx.fillStyle = '#8a6a3a';
  for (let i = 0; i < 22; i++) {
    ctx.fillRect((i * 67 + 18) % (w - 40), 508 + (i % 5) * 5, 6, 3);
  }

  const pad = ctx.createLinearGradient(0, 528, 0, h);
  pad.addColorStop(0, '#9aa2a8');
  pad.addColorStop(0.2, '#868e94');
  pad.addColorStop(1, '#6e767c');
  ctx.fillStyle = pad;
  ctx.fillRect(0, 528, w, 192);
  ctx.fillStyle = '#7a8288';
  ctx.fillRect(0, 528, w, 8);
  ctx.fillStyle = 'rgba(255,255,255,0.08)';
  ctx.fillRect(0, 528, w, 3);
  ctx.fillStyle = '#5c646a';
  for (let y = 552; y < h; y += 28) ctx.fillRect(0, y, w, 2);
  for (let x = 0; x < w; x += 40) ctx.fillRect(x, 528, 2, 192);
  ctx.fillStyle = '#4a5258';
  ctx.fillRect(110, 540, 10, 168);
  ctx.fillRect(188, 540, 10, 168);
  ctx.fillRect(348, 540, 8, 168);
  ctx.fillRect(900, 540, 10, 168);
  ctx.fillStyle = 'rgba(20,16,10,0.22)';
  ctx.fillRect(90, 620, 200, 18);
  ctx.fillRect(400, 534, 220, 16);
  ctx.fillRect(680, 534, 140, 20);

  drawGse(ctx, 214, 536);
  drawLaunchTable(ctx, 508, 536);
  drawIlt(ctx, 742, 536);

  ctx.fillStyle = 'rgba(8,12,18,0.18)';
  ctx.beginPath();
  ctx.ellipse(508, 548, 70, 10, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.ellipse(742, 548, 56, 9, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#d5dce2';
  ctx.fillRect(28, 620, 86, 32);
  ctx.fillRect(118, 630, 44, 22);
  ctx.fillStyle = '#2a3138';
  ctx.beginPath();
  ctx.arc(50, 654, 8, 0, Math.PI * 2);
  ctx.arc(92, 654, 8, 0, Math.PI * 2);
  ctx.arc(132, 654, 7, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#c48a2a';
  ctx.fillRect(40, 624, 10, 10);

  ctx.fillStyle = 'rgba(8,12,18,0.55)';
  ctx.font = 'bold 13px "IBM Plex Mono", ui-monospace, monospace';
  ctx.fillText('LC-36', 40, 572);
  ctx.font = '11px "IBM Plex Mono", ui-monospace, monospace';
  ctx.fillText('CAPE CANAVERAL', 40, 588);

  return cv;
}

function drawLaunchTable(ctx, x, groundY) {
  ctx.save();
  ctx.translate(x, groundY);
  ctx.fillStyle = '#2a3038';
  ctx.fillRect(-88, 4, 176, 14);
  ctx.fillStyle = '#1a1e24';
  ctx.fillRect(-40, 8, 80, 22);
  ctx.fillStyle = '#3d444c';
  ctx.fillRect(-78, 0, 22, 18);
  ctx.fillRect(56, 0, 22, 18);
  ctx.fillRect(-18, 0, 36, 18);
  ctx.strokeStyle = '#1c2128';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(-70, -38);
  ctx.lineTo(-56, 0);
  ctx.moveTo(70, -38);
  ctx.lineTo(56, 0);
  ctx.moveTo(-28, -38);
  ctx.lineTo(-18, 0);
  ctx.moveTo(28, -38);
  ctx.lineTo(18, 0);
  ctx.stroke();
  const deck = ctx.createLinearGradient(0, -44, 0, -8);
  deck.addColorStop(0, '#8a929a');
  deck.addColorStop(1, '#4a5158');
  ctx.fillStyle = '#5c636b';
  ctx.fillRect(-96, -18, 192, 18);
  ctx.fillStyle = deck;
  ctx.fillRect(-80, -38, 160, 22);
  ctx.strokeStyle = '#1c2128';
  ctx.lineWidth = 2;
  ctx.strokeRect(-80, -38, 160, 22);
  ctx.fillStyle = '#c5ced6';
  ctx.fillRect(-80, -44, 160, 6);
  ctx.fillStyle = '#2a3038';
  ctx.fillRect(-86, -52, 6, 20);
  ctx.fillRect(80, -52, 6, 20);
  ctx.fillRect(-86, -52, 172, 4);
  ctx.fillStyle = '#2a3038';
  ctx.fillRect(-30, -8, 60, 8);
  ctx.fillStyle = 'rgba(255,160,40,0.16)';
  ctx.fillRect(-36, -6, 72, 10);
  ctx.restore();
}

function drawGse(ctx, x, groundY) {
  ctx.save();
  ctx.translate(x, groundY);
  ctx.fillStyle = '#3a4048';
  ctx.fillRect(-118, -14, 248, 10);
  const tanks = [
    { x: -96, y: -40, w: 100, h: 38 },
    { x: 12, y: -38, w: 92, h: 36 },
    { x: -48, y: -78, w: 84, h: 30 },
    { x: -20, y: -108, w: 54, h: 22 },
  ];
  tanks.forEach((t) => {
    const g = ctx.createLinearGradient(t.x, t.y, t.x, t.y + t.h);
    g.addColorStop(0, '#f7fbff');
    g.addColorStop(0.45, '#dce3ea');
    g.addColorStop(1, '#a8b2ba');
    ctx.fillStyle = g;
    ctx.beginPath();
    if (typeof ctx.roundRect === 'function') ctx.roundRect(t.x, t.y, t.w, t.h, t.h / 2);
    else ctx.rect(t.x, t.y, t.w, t.h);
    ctx.fill();
    ctx.strokeStyle = '#7a828a';
    ctx.stroke();
    ctx.fillStyle = 'rgba(255,255,255,0.35)';
    ctx.fillRect(t.x + 8, t.y + 4, t.w * 0.28, t.h - 8);
    ctx.fillStyle = '#c48a2a';
    ctx.fillRect(t.x + 12, t.y + 6, 8, t.h - 12);
  });
  ctx.strokeStyle = '#6d767e';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(-10, -78);
  ctx.lineTo(40, -40);
  ctx.lineTo(120, -40);
  ctx.stroke();
  ctx.fillStyle = '#4a5158';
  ctx.fillRect(100, -96, 58, 96);
  ctx.fillStyle = '#3a4046';
  ctx.fillRect(96, -104, 66, 10);
  ctx.fillStyle = '#2f353c';
  for (let y = -88; y < -16; y += 16) ctx.fillRect(108, y, 14, 8);
  ctx.fillStyle = '#2f353c';
  ctx.fillRect(-118, -52, 16, 52);
  ctx.fillStyle = '#c9a227';
  ctx.fillRect(124, -116, 8, 12);
  ctx.restore();
}

/**
 * Integrated Launch Tower only. No separate lightning-protection towers
 * on the pad. White fully enclosed service platforms extend toward the
 * vehicle, matching the LC-36 ILT photo.
 */
function drawIlt(ctx, x, groundY) {
  const height = 400;
  ctx.save();
  ctx.translate(x, groundY);
  ctx.fillStyle = 'rgba(12,16,22,0.22)';
  ctx.beginPath();
  ctx.moveTo(-58, 0);
  ctx.lineTo(-34, -height);
  ctx.lineTo(34, -height);
  ctx.lineTo(58, 0);
  ctx.fill();
  ctx.strokeStyle = '#2f353c';
  ctx.lineWidth = 8;
  ctx.beginPath();
  ctx.moveTo(-50, 0);
  ctx.lineTo(-30, -height);
  ctx.moveTo(50, 0);
  ctx.lineTo(32, -height);
  ctx.stroke();
  ctx.strokeStyle = '#1e242a';
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(-10, 0);
  ctx.lineTo(-5, -height);
  ctx.moveTo(10, 0);
  ctx.lineTo(5, -height);
  ctx.stroke();
  ctx.strokeStyle = '#5a626a';
  ctx.lineWidth = 2;
  for (let y = -14; y > -height + 6; y -= 16) {
    const taper = 12 * (1 + y / height);
    ctx.beginPath();
    ctx.moveTo(-48 + taper, y);
    ctx.lineTo(48 - taper, y - 10);
    ctx.moveTo(48 - taper, y);
    ctx.lineTo(-48 + taper, y - 10);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(-48 + taper, y);
    ctx.lineTo(48 - taper, y);
    ctx.stroke();
  }

  const platforms = [
    { y: -84, w: 176, h: 42, extend: -86 },
    { y: -168, w: 184, h: 46, extend: -98 },
    { y: -252, w: 168, h: 38, extend: -80 },
  ];
  platforms.forEach((p) => {
    const left = -p.w * 0.18 + p.extend;
    const shell = ctx.createLinearGradient(left, p.y, left, p.y + p.h);
    shell.addColorStop(0, '#f4f7fb');
    shell.addColorStop(1, '#c5ced6');
    ctx.fillStyle = shell;
    ctx.fillRect(left, p.y, p.w, p.h);
    ctx.fillStyle = '#a8b2ba';
    ctx.fillRect(left + 6, p.y + 6, p.w - 12, p.h - 12);
    ctx.fillStyle = '#f7fbff';
    ctx.fillRect(left + 10, p.y + 9, p.w * 0.4, p.h - 18);
    ctx.fillStyle = '#2a3850';
    for (let i = 0; i < 6; i++) {
      ctx.fillRect(left + 16 + i * 22, p.y + 12, 10, 10);
    }
    ctx.strokeStyle = '#5c636b';
    ctx.lineWidth = 2;
    ctx.strokeRect(left, p.y, p.w, p.h);
    ctx.fillStyle = '#3a4048';
    ctx.fillRect(left, p.y + p.h - 7, p.w + 22, 7);
    ctx.fillStyle = '#c9a227';
    ctx.fillRect(left + p.w - 14, p.y + 6, 6, 6);
  });

  ctx.fillStyle = '#3a4048';
  ctx.fillRect(-40, -height - 12, 80, 16);
  ctx.fillStyle = '#c9a227';
  ctx.fillRect(-6, -height - 22, 12, 10);
  ctx.strokeStyle = '#2b3036';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(0, -height);
  ctx.lineTo(0, -height - 30);
  ctx.stroke();
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

  const body = ctx.createLinearGradient(-22, 50, 22, 50);
  body.addColorStop(0, '#c5ced6');
  body.addColorStop(0.28, '#f7fbff');
  body.addColorStop(0.62, '#e4ebf2');
  body.addColorStop(1, '#9aa3aa');
  ctx.fillStyle = body;
  ctx.fillRect(-22, 50, 44, 168);
  ctx.fillStyle = 'rgba(20,28,40,0.08)';
  for (let y = 62; y < 200; y += 16) ctx.fillRect(-20, y, 40, 1);

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

/** Climb backdrop. Keep the canvas small — software WebGL maxes out near 2048. */
export function makeAscentSky() {
  const w = 640;
  const h = 1024;
  const cv = canvas(w, h);
  const ctx = cv.getContext('2d');
  const sky = ctx.createLinearGradient(0, 0, 0, h);
  sky.addColorStop(0, '#02060c');
  sky.addColorStop(0.28, '#061018');
  sky.addColorStop(0.48, '#0a2040');
  sky.addColorStop(0.66, '#163a68');
  sky.addColorStop(0.8, '#3a7eb4');
  sky.addColorStop(0.9, '#6fb4e8');
  sky.addColorStop(1, '#8ec6e6');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h);
  ctx.fillStyle = 'rgba(255,255,255,0.85)';
  for (let i = 0; i < 160; i++) {
    const y = (i * 97) % Math.floor(h * 0.72);
    ctx.globalAlpha = 0.25 + (i % 5) * 0.12;
    ctx.fillRect((i * 137) % w, y, 2, 2);
  }
  ctx.globalAlpha = 1;
  ctx.fillStyle = 'rgba(255,255,255,0.16)';
  for (let i = 0; i < 8; i++) {
    ctx.beginPath();
    ctx.ellipse((i * 190 + 80) % w, h * 0.78 + (i % 3) * 28, 70, 12, 0, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.strokeStyle = 'rgba(255,207,93,0.18)';
  ctx.setLineDash([8, 14]);
  ctx.beginPath();
  ctx.moveTo(w * 0.28, h * 0.12);
  ctx.lineTo(w * 0.34, h);
  ctx.moveTo(w * 0.72, h * 0.12);
  ctx.lineTo(w * 0.66, h);
  ctx.stroke();
  ctx.setLineDash([]);
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
  ctx.fillStyle = 'rgba(220,200,140,0.12)';
  ctx.fillRect(0, 404, 1280, 6);
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
  add('upper-stage', makeUpperStage());
  add('fairing-l', makeFairingHalf(-1));
  add('fairing-r', makeFairingHalf(1));
  add('bloom', makeBloom());
  add('rcs', makeDot('#f4fbff', 16, 16));
  add('soot', makeDot('#6a3a18', 36, 36));
  add('smoke-bank', makeSmokeBank());
  MISSIONS.forEach((mission) => {
    add(`rocket-${mission.id}`, makeRocket(true, mission));
  });
  add('pad', makePad());
  add('ascent-sky', makeAscentSky());
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
  add('deck-pad', canvas(280, 32));
}
