/** Procedural Pier 7 / Kestrel Heavy / Haven sprites. Pad uses the service tower only. */
import { DEFAULT_LOADOUT, accentColor, paintSpec } from './loadout.js';
import { MISSIONS } from './missions.js';
import { todPalette } from './tod.js';

function canvas(w, h) {
  const cv = document.createElement('canvas');
  cv.width = w;
  cv.height = h;
  return cv;
}

function chevronMark(ctx, x, y, s, color) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(s, s);
  ctx.fillStyle = color || '#1a2430';
  ctx.beginPath();
  ctx.moveTo(0, -16);
  ctx.lineTo(11, 6);
  ctx.lineTo(4, 6);
  ctx.lineTo(0, -4);
  ctx.lineTo(-4, 6);
  ctx.lineTo(-11, 6);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

/** Solid black wing-strakes. Never lattice / grid fins. */
function drawStrakes(ctx, bodyHalf, deployed, forwardY, aftY, style = 'black') {
  ctx.fillStyle = '#0b0d12';
  const wide = style === 'wide' ? 1.28 : style === 'stub' ? 0.72 : 1;
  const fSpan = (deployed ? 22 : 16) * wide;
  const fH = (deployed ? 22 : 18) * (style === 'stub' ? 0.7 : 1);
  if (style !== 'aft') {
    [-1, 1].forEach((side) => {
      const tip = side * (bodyHalf + fSpan);
      ctx.beginPath();
      ctx.moveTo(side * bodyHalf, forwardY + 3);
      ctx.lineTo(tip, forwardY + 5);
      ctx.lineTo(tip, forwardY + fH);
      ctx.lineTo(side * bodyHalf, forwardY + fH - 4);
      ctx.closePath();
      ctx.fill();
    });
  }
  const aftSpan = (deployed ? 36 : 24) * wide;
  const aftH = (deployed ? 48 : 36) * (style === 'stub' ? 0.68 : 1);
  [-1, 1].forEach((side) => {
    const tip = side * (bodyHalf + aftSpan);
    ctx.beginPath();
    ctx.moveTo(side * bodyHalf, aftY);
    ctx.lineTo(tip, aftY + 10);
    ctx.lineTo(tip + side * (deployed ? 6 : 2), aftY + aftH);
    ctx.lineTo(side * bodyHalf, aftY + aftH - 10);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#1a1d24';
    ctx.fillRect(side < 0 ? tip + 2 : bodyHalf, aftY + 12, 3, aftH - 18);
    ctx.fillStyle = '#0b0d12';
    if (style === 'gold-edge') {
      ctx.strokeStyle = '#c48a2a';
      ctx.lineWidth = 1.4;
      ctx.stroke();
    }
  });
}

function drawNose(ctx, kind, accent, payload) {
  const goldHi = accent === '#c48a2a' ? '#fff6d0' : accent;
  const goldMid = accent === '#c48a2a' ? '#f3d58a' : accent;
  if (kind === 'white-needle') {
    const g = ctx.createLinearGradient(0, 0, 0, 62);
    g.addColorStop(0, '#ffffff');
    g.addColorStop(0.5, '#e8eef6');
    g.addColorStop(1, goldMid);
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(0, -4);
    ctx.bezierCurveTo(12, 8, 18, 32, 18, 62);
    ctx.lineTo(-18, 62);
    ctx.bezierCurveTo(-18, 32, -12, 8, 0, -4);
    ctx.fill();
  } else if (kind === 'black-ogive') {
    const g = ctx.createLinearGradient(0, 0, 0, 62);
    g.addColorStop(0, '#1a1d24');
    g.addColorStop(0.7, '#2a3038');
    g.addColorStop(1, goldMid);
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.bezierCurveTo(17, 11, 22, 32, 21, 62);
    ctx.lineTo(-21, 62);
    ctx.bezierCurveTo(-22, 32, -17, 11, 0, 0);
    ctx.fill();
  } else if (kind === 'blunt-gold') {
    const g = ctx.createLinearGradient(0, 8, 0, 62);
    g.addColorStop(0, goldHi);
    g.addColorStop(0.45, goldMid);
    g.addColorStop(1, '#7a4e0e');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(0, 8);
    ctx.bezierCurveTo(18, 16, 22, 36, 21, 62);
    ctx.lineTo(-21, 62);
    ctx.bezierCurveTo(-22, 36, -18, 16, 0, 8);
    ctx.fill();
  } else if (kind === 'twin-mark') {
    const g = ctx.createLinearGradient(0, 0, 0, 62);
    g.addColorStop(0, goldHi);
    g.addColorStop(0.5, goldMid);
    g.addColorStop(1, '#7a4e0e');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.bezierCurveTo(17, 11, 22, 32, 21, 62);
    ctx.lineTo(-21, 62);
    ctx.bezierCurveTo(-22, 32, -17, 11, 0, 0);
    ctx.fill();
    ctx.fillStyle = '#1a1408';
    ctx.fillRect(-8, 18, 4, 28);
    ctx.fillRect(4, 18, 4, 28);
  } else {
    const g = ctx.createLinearGradient(0, 0, 0, 62);
    g.addColorStop(0, '#fff6d0');
    g.addColorStop(0.16, '#f3d58a');
    g.addColorStop(0.48, '#d4a43a');
    g.addColorStop(0.78, '#b47a18');
    g.addColorStop(1, '#7a4e0e');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.bezierCurveTo(17, 11, 22, 32, 21, 62);
    ctx.lineTo(-21, 62);
    ctx.bezierCurveTo(-22, 32, -17, 11, 0, 0);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,236,180,0.38)';
    ctx.beginPath();
    ctx.moveTo(-6, 8);
    ctx.bezierCurveTo(-14, 22, -16, 40, -14, 58);
    ctx.lineTo(-8, 58);
    ctx.bezierCurveTo(-10, 36, -8, 18, -2, 10);
    ctx.fill();
  }
  ctx.fillStyle = payload?.accent || accent;
  ctx.fillRect(-21, 60, 42, 5);
  if (payload?.mark) {
    ctx.fillStyle = '#1a1408';
    ctx.font = 'bold 9px "IBM Plex Mono", ui-monospace, monospace';
    ctx.textAlign = 'center';
    ctx.fillText(payload.mark, 0, 52);
  }
}

function drawEngineBells(ctx, kind, y) {
  const count = kind === 'slim' ? 9 : kind === 'dual' ? 7 : 7;
  const spread = kind === 'clustered' ? 4.4 : kind === 'slim' ? 4.2 : 5.4;
  const rx = kind === 'bell-wide' ? 4.2 : kind === 'slim' ? 2.2 : 3;
  const ry = kind === 'bell-wide' ? 8.5 : 7;
  const start = -((count - 1) * spread) / 2;
  for (let i = 0; i < count; i++) {
    const x = start + i * spread;
    const fat = kind === 'dual' && (i === 0 || i === count - 1);
    ctx.fillStyle = '#2b3038';
    ctx.beginPath();
    ctx.ellipse(x, y, fat ? 5 : rx, fat ? 9 : ry, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#6d7380';
    ctx.beginPath();
    ctx.ellipse(x, y - 2, (fat ? 5 : rx) * 0.5, (fat ? 9 : ry) * 0.42, 0, 0, Math.PI * 2);
    ctx.fill();
  }
}

export function makeRocket(fairing, payload, loadout) {
  const kit = { ...DEFAULT_LOADOUT, ...(loadout || {}) };
  const paint = paintSpec(kit.paint);
  const accent = accentColor(kit.accent);
  const cv = canvas(92, 268);
  const ctx = cv.getContext('2d');
  ctx.translate(46, 8);

  if (fairing) {
    drawNose(ctx, kit.nose, accent, payload);
  } else {
    ctx.fillStyle = paint.hi;
    ctx.fillRect(-16, 32, 32, 30);
    ctx.fillStyle = '#c5ced8';
    ctx.fillRect(-11, 28, 22, 8);
  }

  const goldTop = ctx.createLinearGradient(-21, 65, 21, 84);
  goldTop.addColorStop(0, accent);
  goldTop.addColorStop(0.45, accent);
  goldTop.addColorStop(1, '#8a5a12');
  ctx.fillStyle = goldTop;
  ctx.fillRect(-21, 65, 42, 16);

  const body = ctx.createLinearGradient(-20, 80, 20, 80);
  body.addColorStop(0, paint.lo);
  body.addColorStop(0.22, paint.hi);
  body.addColorStop(0.55, paint.mid);
  body.addColorStop(1, paint.lo);
  ctx.fillStyle = body;
  ctx.fillRect(-20, 80, 40, 118);
  ctx.fillStyle = 'rgba(20,28,40,0.08)';
  for (let y = 88; y < 188; y += 13) ctx.fillRect(-18, y, 36, 1);

  if (kit.body === 'stripe') {
    ctx.fillStyle = 'rgba(20,28,40,0.42)';
    ctx.fillRect(-3, 84, 6, 108);
  } else if (kit.body === 'ringed') {
    ctx.fillStyle = accent;
    ctx.fillRect(-20, 108, 40, 3);
    ctx.fillRect(-20, 148, 40, 3);
  } else if (kit.body === 'cargo') {
    ctx.fillStyle = 'rgba(20,28,40,0.35)';
    ctx.fillRect(-20, 118, 40, 28);
  } else if (kit.body === 'long-window') {
    ctx.fillStyle = '#8ce0ff';
    ctx.globalAlpha = 0.55;
    ctx.fillRect(-14, 100, 8, 36);
    ctx.fillRect(6, 100, 8, 36);
    ctx.globalAlpha = 1;
  }

  chevronMark(ctx, 0, 136, kit.body === 'chevron' ? 0.86 : 0.62, '#1c2834');

  ctx.fillStyle = '#fff';
  ctx.fillRect(8, 98, 10, 6);
  ctx.fillStyle = '#b22234';
  ctx.fillRect(8, 98, 10, 2);
  ctx.fillRect(8, 102, 10, 2);
  ctx.fillStyle = '#3c3b6e';
  ctx.fillRect(8, 98, 4, 6);

  drawStrakes(ctx, 20, false, 92, 176, kit.strakes);

  const copper = ctx.createLinearGradient(-22, 210, 22, 238);
  copper.addColorStop(0, accent);
  copper.addColorStop(0.35, '#c48a2a');
  copper.addColorStop(0.7, '#8a4e12');
  copper.addColorStop(1, '#5a320c');
  ctx.fillStyle = copper;
  ctx.fillRect(-22, 210, 44, 22);

  drawEngineBells(ctx, kit.engines, 246);

  ctx.strokeStyle = 'rgba(20,28,40,0.16)';
  ctx.strokeRect(-20, 80, 40, 118);
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
  const cv = canvas(44, 78);
  const ctx = cv.getContext('2d');
  const g = ctx.createLinearGradient(side < 0 ? 8 : 36, 0, side < 0 ? 40 : 4, 0);
  g.addColorStop(0, '#8a5a12');
  g.addColorStop(0.28, '#f3d58a');
  g.addColorStop(0.55, '#d4a43a');
  g.addColorStop(0.82, '#b47a18');
  g.addColorStop(1, '#7a4e0e');
  ctx.fillStyle = g;
  ctx.beginPath();
  if (side < 0) {
    ctx.moveTo(40, 3);
    ctx.bezierCurveTo(10, 10, 5, 32, 7, 74);
    ctx.lineTo(40, 74);
  } else {
    ctx.moveTo(4, 3);
    ctx.bezierCurveTo(34, 10, 39, 32, 37, 74);
    ctx.lineTo(4, 74);
  }
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = 'rgba(8,10,14,0.55)';
  ctx.lineWidth = 1.4;
  ctx.stroke();
  ctx.fillStyle = '#c48a2a';
  ctx.fillRect(side < 0 ? 8 : 6, 70, 30, 4);
  return cv;
}

/** Interstage ring + strut shards — readable silhouettes, not clutter. */
export function makeSepShard(kind) {
  const cv = canvas(36, 28);
  const ctx = cv.getContext('2d');
  ctx.translate(18, 14);
  if (kind === 'ring') {
    ctx.strokeStyle = '#c5ced6';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.ellipse(0, 0, 14, 6, 0.2, 0, Math.PI * 2);
    ctx.stroke();
    ctx.strokeStyle = '#2b3038';
    ctx.lineWidth = 1.2;
    ctx.stroke();
  } else if (kind === 'strut') {
    ctx.fillStyle = '#1a1d24';
    ctx.rotate(-0.4);
    ctx.fillRect(-12, -3, 24, 6);
    ctx.fillStyle = '#c48a2a';
    ctx.fillRect(-12, -1, 24, 2);
  } else {
    ctx.fillStyle = '#9aa3aa';
    ctx.beginPath();
    ctx.moveTo(-10, -6);
    ctx.lineTo(12, -4);
    ctx.lineTo(8, 8);
    ctx.lineTo(-8, 6);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = 'rgba(8,10,14,0.5)';
    ctx.stroke();
  }
  return cv;
}

export function makePad(todId) {
  const tod = todPalette(todId);
  const w = 1280;
  const h = 720;
  const cv = canvas(w, h);
  const ctx = cv.getContext('2d');

  const sky = ctx.createLinearGradient(0, 0, 0, 430);
  const stops = tod.padSky || ['#1a3a68', '#3a6ea8', '#7aa8c8', '#e8b070', '#f0c090', '#c0a878'];
  stops.forEach((color, i) => sky.addColorStop(i / Math.max(1, stops.length - 1), color));
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h);

  const sun = ctx.createRadialGradient(tod.sun.x, tod.sun.y, 8, tod.sun.x, tod.sun.y, 260);
  sun.addColorStop(0, tod.sun.inner);
  sun.addColorStop(0.12, tod.sun.mid);
  sun.addColorStop(0.4, tod.sun.mid);
  sun.addColorStop(1, tod.sun.outer);
  ctx.fillStyle = sun;
  ctx.fillRect(Math.max(0, tod.sun.x - 280), 0, 560, 360);

  ctx.fillStyle = 'rgba(255,210,160,0.12)';
  for (let i = 0; i < 7; i++) {
    ctx.beginPath();
    ctx.moveTo(tod.sun.x, tod.sun.y);
    ctx.lineTo(640 + i * 90, 360);
    ctx.lineTo(700 + i * 90, 360);
    ctx.fill();
  }

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
  const oc = tod.ocean || ['#1a5580', '#247094', '#1a5a78', '#123e58'];
  ocean.addColorStop(0, oc[0]);
  ocean.addColorStop(0.28, oc[1]);
  ocean.addColorStop(0.7, oc[2]);
  ocean.addColorStop(1, oc[3]);
  ctx.fillStyle = ocean;
  ctx.fillRect(0, 352, w, 126);
  ctx.fillStyle = 'rgba(255,255,255,0.12)';
  for (let x = 0; x < w; x += 16) {
    ctx.fillRect(x, 372 + Math.sin(x * 0.05) * 5, 10, 1.5);
    ctx.fillRect(x + 6, 398 + Math.sin(x * 0.033) * 4, 14, 1.2);
    ctx.fillRect(x + 3, 428 + Math.sin(x * 0.02) * 3, 9, 1);
  }
  ctx.fillStyle = 'rgba(255,220,160,0.14)';
  ctx.fillRect(0, 354, w, 6);

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

  ctx.fillStyle = 'rgba(255, 214, 140, 0.16)';
  ctx.beginPath();
  ctx.moveTo(742, 140);
  ctx.lineTo(508, 430);
  ctx.lineTo(620, 430);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = 'rgba(255, 236, 190, 0.35)';
  ctx.beginPath();
  ctx.arc(748, 148, 10, 0, Math.PI * 2);
  ctx.fill();

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
  ctx.fillText('PIER 7', 40, 572);
  ctx.font = '11px "IBM Plex Mono", ui-monospace, monospace';
  ctx.fillText('COASTAL COMPLEX', 40, 588);

  if (tod.stars > 0.3) {
    ctx.fillStyle = '#fff';
    for (let i = 0; i < 90; i++) {
      ctx.globalAlpha = 0.2 + (i % 5) * 0.12;
      ctx.fillRect((i * 137) % w, (i * 53) % 280, 1 + (i % 9 === 0 ? 1 : 0), 1);
    }
    ctx.globalAlpha = 1;
  }
  const flood = ctx.createRadialGradient(742, 280, 8, 742, 280, 180);
  flood.addColorStop(0, `rgba(255,220,160,${0.18 + tod.stars * 0.2})`);
  flood.addColorStop(1, 'rgba(255,180,80,0)');
  ctx.fillStyle = flood;
  ctx.fillRect(560, 120, 360, 360);

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
 * vehicle, matching the Pier 7 service-tower photo.
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
 * Kestrel Heavy recovery silhouette (hard constraint):
 * metallic gold upper ring, four LARGE solid black strakes just below it,
 * tall white cylinder, optional KESTREL mark.
 * REJECT Falcon cues: lattice grid fins, A-frame landing legs,
 * 3-1 landing-burn language, ASDS circle-X droneship.
 */
export function makeBooster(deployed = false, loadout) {
  const kit = { ...DEFAULT_LOADOUT, ...(loadout || {}) };
  const paint = paintSpec(kit.paint);
  const accent = accentColor(kit.accent);
  const cv = canvas(124, 268);
  const ctx = cv.getContext('2d');
  ctx.translate(62, 10);

  const gold = ctx.createLinearGradient(-22, 0, 22, 48);
  gold.addColorStop(0, accent);
  gold.addColorStop(0.35, '#d4a43a');
  gold.addColorStop(0.7, '#b47a18');
  gold.addColorStop(1, '#7a4e0e');
  ctx.fillStyle = gold;
  ctx.fillRect(-22, 0, 44, 46);
  ctx.fillStyle = 'rgba(255,236,180,0.35)';
  ctx.fillRect(-20, 4, 10, 38);

  const body = ctx.createLinearGradient(-20, 46, 20, 46);
  body.addColorStop(0, paint.lo);
  body.addColorStop(0.28, paint.hi);
  body.addColorStop(0.62, paint.mid);
  body.addColorStop(1, paint.lo);
  ctx.fillStyle = body;
  ctx.fillRect(-20, 46, 40, 154);
  ctx.fillStyle = 'rgba(20,28,40,0.08)';
  for (let y = 56; y < 188; y += 16) ctx.fillRect(-18, y, 36, 1);

  drawStrakes(ctx, 20, deployed, 54, 150, kit.strakes);

  ctx.fillStyle = '#0b0d12';
  ctx.font = 'bold 9px "IBM Plex Mono", ui-monospace, monospace';
  ctx.save();
  ctx.translate(-6, 142);
  ctx.rotate(-Math.PI / 2);
  ctx.fillText('KESTREL', 0, 0);
  ctx.restore();

  const copper = ctx.createLinearGradient(-22, 198, 22, 226);
  copper.addColorStop(0, accent);
  copper.addColorStop(0.4, '#c48a2a');
  copper.addColorStop(1, '#6a3a0e');
  ctx.fillStyle = copper;
  ctx.fillRect(-22, 198, 44, 18);

  drawEngineBells(ctx, kit.engines, 232);
  return cv;
}

/** Haven: dark deck between white multi-story bow/stern bookends. Not an ASDS circle-X droneship. */
export function makeHaven() {
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
  ctx.fillText('HAVEN', 320, 184);
  return cv;
}

/** Climb backdrop. Keep the canvas small — software WebGL maxes out near 2048. */
export function makeAscentSky(todId) {
  const tod = todPalette(todId);
  const w = 640;
  const h = 1024;
  const cv = canvas(w, h);
  const ctx = cv.getContext('2d');
  const sky = ctx.createLinearGradient(0, 0, 0, h);
  tod.sky.forEach(([t, color]) => sky.addColorStop(t, color));
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h);

  const limb = ctx.createLinearGradient(0, h * 0.34, 0, h * 0.5);
  limb.addColorStop(0, tod.limb[0]);
  limb.addColorStop(0.45, tod.limb[1]);
  limb.addColorStop(0.7, tod.limb[2]);
  limb.addColorStop(1, tod.limb[3]);
  ctx.fillStyle = limb;
  ctx.fillRect(0, h * 0.34, w, h * 0.18);

  ctx.fillStyle = '#fff';
  const starN = 280 + Math.round(tod.stars * 220);
  for (let i = 0; i < starN; i++) {
    const y = (i * 97) % Math.floor(h * 0.58);
    const size = 1 + (i % 9 === 0 ? 1.8 : 0);
    ctx.globalAlpha = (0.2 + (i % 6) * 0.12) * (0.35 + tod.stars);
    ctx.fillRect((i * 137) % w, y, size, size);
  }
  ctx.globalAlpha = 1;

  ctx.fillStyle = tod.cloud;
  for (let i = 0; i < 10; i++) {
    ctx.beginPath();
    ctx.ellipse((i * 190 + 80) % w, h * 0.78 + (i % 3) * 28, 78, 13, 0.04 * (i % 2 ? 1 : -1), 0, Math.PI * 2);
    ctx.fill();
  }
  return cv;
}

export function makeStarfield() {
  const w = 720;
  const h = 900;
  const cv = canvas(w, h);
  const ctx = cv.getContext('2d');
  ctx.fillStyle = '#010105';
  ctx.fillRect(0, 0, w, h);
  for (let i = 0; i < 1100; i++) {
    const x = (i * 131 + 17) % w;
    const y = (i * 89 + 9) % h;
    const s = i % 13 === 0 ? 2.4 : i % 4 === 0 ? 1.5 : 1;
    ctx.fillStyle = i % 11 === 0 ? '#c8dcff' : i % 17 === 0 ? '#ffe8c8' : i % 23 === 0 ? '#c8a8ff' : '#fff';
    ctx.globalAlpha = 0.28 + (i % 7) * 0.1;
    ctx.fillRect(x, y, s, s);
  }
  ctx.globalAlpha = 0.7;
  ctx.fillStyle = '#dce8ff';
  ctx.fillRect(80, 40, 2.4, 2.4);
  ctx.fillRect(410, 120, 2.4, 2.4);
  ctx.fillRect(520, 300, 3.2, 3.2);
  ctx.fillRect(200, 510, 2.6, 2.6);
  ctx.globalAlpha = 1;
  return cv;
}

/** Soft galactic band. One canvas — no per-star sprites. */
export function makeMilkyWay() {
  const w = 720;
  const h = 640;
  const cv = canvas(w, h);
  const ctx = cv.getContext('2d');
  ctx.translate(w / 2, h / 2);
  ctx.rotate(-0.42);
  const band = ctx.createLinearGradient(0, -90, 0, 90);
  band.addColorStop(0, 'rgba(180,200,255,0)');
  band.addColorStop(0.35, 'rgba(200,210,255,0.16)');
  band.addColorStop(0.5, 'rgba(255,236,220,0.28)');
  band.addColorStop(0.65, 'rgba(180,160,255,0.16)');
  band.addColorStop(1, 'rgba(180,200,255,0)');
  ctx.fillStyle = band;
  ctx.fillRect(-w, -90, w * 2, 180);
  ctx.fillStyle = '#fff';
  for (let i = 0; i < 240; i++) {
    ctx.globalAlpha = 0.12 + (i % 6) * 0.08;
    ctx.fillRect((i * 47) % (w + 80) - w / 2, ((i * 13) % 70) - 35, 1.4, 1.4);
  }
  ctx.globalAlpha = 1;
  return cv;
}

/** Cosmic dust / nebula. Fades in with altitude. */
export function makeNebula() {
  const w = 640;
  const h = 480;
  const cv = canvas(w, h);
  const ctx = cv.getContext('2d');
  const blobs = [
    [180, 160, 160, 'rgba(90,40,140,0.42)'],
    [380, 220, 180, 'rgba(40,70,140,0.38)'],
    [280, 280, 140, 'rgba(160,60,90,0.28)'],
    [120, 300, 110, 'rgba(40,100,120,0.3)'],
  ];
  blobs.forEach(([x, y, r, color]) => {
    const g = ctx.createRadialGradient(x, y, 8, x, y, r);
    g.addColorStop(0, color);
    g.addColorStop(1, 'rgba(10,8,20,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
  });
  return cv;
}

export function makeHeat() {
  const cv = canvas(48, 72);
  const ctx = cv.getContext('2d');
  const g = ctx.createRadialGradient(24, 56, 4, 24, 28, 34);
  g.addColorStop(0, 'rgba(255,240,180,0.55)');
  g.addColorStop(0.4, 'rgba(255,140,40,0.22)');
  g.addColorStop(1, 'rgba(255,80,0,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 48, 72);
  return cv;
}

export function makeWindDash() {
  const cv = canvas(28, 6);
  const ctx = cv.getContext('2d');
  ctx.strokeStyle = 'rgba(220,236,255,0.85)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(2, 3);
  ctx.lineTo(24, 3);
  ctx.stroke();
  return cv;
}

export function makeCloudSheet(seed = 1, todId) {
  const tod = todPalette(todId);
  const w = 640;
  const h = 220;
  const cv = canvas(w, h);
  const ctx = cv.getContext('2d');
  ctx.fillStyle = tod.cloud || 'rgba(255,255,255,0.18)';
  for (let i = 0; i < 14; i++) {
    const x = (i * 97 * seed + 40) % w;
    const y = 40 + (i * 37 * seed) % 120;
    ctx.beginPath();
    ctx.ellipse(x, y, 70 + (i % 5) * 12, 12 + (i % 3) * 4, -0.08 + (i % 4) * 0.05, 0, Math.PI * 2);
    ctx.fill();
  }
  return cv;
}

export function makeHazeBand(todId) {
  const tod = todPalette(todId);
  const w = 640;
  const h = 180;
  const cv = canvas(w, h);
  const ctx = cv.getContext('2d');
  const g = ctx.createLinearGradient(0, 0, 0, h);
  g.addColorStop(0, tod.haze[0]);
  g.addColorStop(0.45, tod.haze[1]);
  g.addColorStop(1, tod.haze[2]);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);
  return cv;
}

export function makeOcean(todId) {
  const tod = todPalette(todId);
  const cv = canvas(1280, 720);
  const ctx = cv.getContext('2d');
  const sky = ctx.createLinearGradient(0, 0, 0, 720);
  tod.sky.forEach(([t, color]) => sky.addColorStop(Math.min(1, t * 0.7 + 0.05), color));
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, 1280, 720);
  ctx.fillStyle = 'rgba(255,255,255,0.5)';
  const starN = 40 + Math.round(tod.stars * 80);
  for (let i = 0; i < starN; i++) {
    ctx.globalAlpha = 0.22 + (i % 5) * 0.12;
    ctx.fillRect((i * 97) % 1280, (i * 53) % 360, 2, 2);
  }
  ctx.globalAlpha = 1;
  const moon = ctx.createRadialGradient(tod.sun.x * 0.9, tod.sun.y, 4, tod.sun.x * 0.9, tod.sun.y, 90);
  moon.addColorStop(0, tod.sun.inner);
  moon.addColorStop(1, tod.sun.outer);
  ctx.fillStyle = moon;
  ctx.fillRect(Math.max(0, tod.sun.x * 0.9 - 120), 0, 240, 220);
  const sea = ctx.createLinearGradient(0, 400, 0, 720);
  const oc = tod.ocean;
  sea.addColorStop(0, oc[0]);
  sea.addColorStop(0.2, oc[1]);
  sea.addColorStop(0.55, oc[2]);
  sea.addColorStop(1, oc[3]);
  ctx.fillStyle = sea;
  ctx.fillRect(0, 400, 1280, 320);
  ctx.fillStyle = 'rgba(180,220,240,0.07)';
  for (let y = 418; y < 700; y += 16) {
    ctx.fillRect(0, y + ((y * 3) % 5), 1280, 1.4);
  }
  ctx.fillStyle = 'rgba(220,236,248,0.12)';
  for (let i = 0; i < 22; i++) {
    ctx.fillRect((i * 113) % 1280, 430 + (i % 7) * 28, 40 + (i % 5) * 10, 1.6);
  }
  ctx.fillStyle = 'rgba(220,200,140,0.16)';
  ctx.fillRect(0, 398, 1280, 5);
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
  const cv = canvas(48, 48);
  const ctx = cv.getContext('2d');
  ctx.translate(24, 24);
  // Thin amber ring so dark birds read on night sky — not a fat glow pad.
  ctx.save();
  ctx.strokeStyle = 'rgba(255, 207, 93, 0.7)';
  ctx.lineWidth = 1.6;
  ctx.beginPath();
  ctx.arc(0, 0, kind === 'balloon' ? 15 : 13, 0, Math.PI * 2);
  ctx.stroke();
  if (kind === 'bird') {
    ctx.strokeStyle = '#ffcf5d';
    ctx.lineWidth = 5;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(-16, 2);
    ctx.quadraticCurveTo(-6, -12, 0, 1);
    ctx.quadraticCurveTo(6, -12, 16, 2);
    ctx.stroke();
    ctx.shadowBlur = 0;
    ctx.strokeStyle = '#1e2430';
    ctx.lineWidth = 2.2;
    ctx.stroke();
  } else if (kind === 'balloon') {
    ctx.fillStyle = '#ff6a55';
    ctx.beginPath();
    ctx.ellipse(0, -4, 11, 14, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.strokeStyle = '#ffe7a8';
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.strokeStyle = '#c9d0d6';
    ctx.beginPath();
    ctx.moveTo(0, 10);
    ctx.lineTo(0, 17);
    ctx.stroke();
  } else if (kind === 'ice') {
    ctx.fillStyle = '#e8fbff';
    ctx.strokeStyle = '#8ce0ff';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(0, -13);
    ctx.lineTo(13, 2);
    ctx.lineTo(5, 13);
    ctx.lineTo(-11, 9);
    ctx.lineTo(-9, -6);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
  } else {
    ctx.fillStyle = '#9aa3b4';
    ctx.beginPath();
    ctx.moveTo(-13, -6);
    ctx.lineTo(12, -8);
    ctx.lineTo(11, 8);
    ctx.lineTo(-11, 7);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#ffcf5d';
    ctx.fillRect(-11, -1, 22, 3);
    ctx.shadowBlur = 0;
    ctx.strokeStyle = '#041014';
    ctx.lineWidth = 1.5;
    ctx.stroke();
  }
  ctx.restore();
  return cv;
}

export function makePickup(kind) {
  const cv = canvas(64, 64);
  const ctx = cv.getContext('2d');
  ctx.translate(32, 32);
  ctx.strokeStyle = kind === 'shield' ? 'rgba(140, 224, 255, 0.95)' : 'rgba(255, 207, 93, 0.85)';
  ctx.lineWidth = 2.4;
  ctx.beginPath();
  ctx.arc(0, 0, 28, 0, Math.PI * 2);
  ctx.stroke();
  if (kind === 'shield') {
    ctx.fillStyle = '#8ce0ff';
    ctx.beginPath();
    ctx.moveTo(0, -18);
    ctx.lineTo(16, -6);
    ctx.lineTo(11, 16);
    ctx.lineTo(-11, 16);
    ctx.lineTo(-16, -6);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = '#f4fbff';
    ctx.lineWidth = 2;
    ctx.stroke();
  } else if (kind === 'fuel') {
    ctx.fillStyle = '#9df6bf';
    ctx.fillRect(-10, -16, 20, 32);
    ctx.fillStyle = '#146a3a';
    ctx.font = '700 11px sans-serif';
    ctx.fillText('LOX', -12, 4);
  } else {
    ctx.fillStyle = '#ffcf5d';
    ctx.beginPath();
    ctx.moveTo(0, -18);
    ctx.lineTo(14, 16);
    ctx.lineTo(-14, 16);
    ctx.closePath();
    ctx.fill();
  }
  return cv;
}

export function makeSpark() {
  return makeDot('#ffb24a', 10, 10);
}

export function installTextures(scene, todId = 'dawn', loadout) {
  const add = (key, cv) => {
    if (scene.textures.exists(key)) scene.textures.remove(key);
    scene.textures.addCanvas(key, cv);
  };
  add('rocket', makeRocket(true, null, loadout));
  add('booster', makeBooster(false, loadout));
  add('booster-glide', makeBooster(true, loadout));
  add('upper-stage', makeUpperStage());
  add('fairing-l', makeFairingHalf(-1));
  add('fairing-r', makeFairingHalf(1));
  add('bloom', makeBloom());
  add('rcs', makeDot('#f4fbff', 16, 16));
  add('soot', makeDot('#6a3a18', 36, 36));
  add('smoke-bank', makeSmokeBank());
  MISSIONS.forEach((mission) => {
    add(`rocket-${mission.id}`, makeRocket(true, mission, loadout));
  });
  add('rocket-equipped', makeRocket(true, null, loadout));
  add('pad', makePad(todId));
  add('ascent-sky', makeAscentSky(todId));
  add('stars', makeStarfield());
  add('milky', makeMilkyWay());
  add('nebula', makeNebula());
  add('clouds-far', makeCloudSheet(1, todId));
  add('clouds-near', makeCloudSheet(2, todId));
  add('haze', makeHazeBand(todId));
  add('sep-ring', makeSepShard('ring'));
  add('sep-strut', makeSepShard('strut'));
  add('sep-plate', makeSepShard('plate'));
  add('ocean', makeOcean(todId));
  add('jacklyn', makeHaven());
  add('bird', makeHazard('bird'));
  add('balloon', makeHazard('balloon'));
  add('ice', makeHazard('ice'));
  add('debris', makeHazard('debris'));
  add('pickup-shield', makePickup('shield'));
  add('pickup-fuel', makePickup('fuel'));
  add('pickup-boost', makePickup('boost'));
  add('spark', makeSpark());
  add('steam', makeDot('rgba(230,240,255,0.9)', 16, 16));
  add('heat', makeHeat());
  add('wind', makeWindDash());
  add('deck-pad', canvas(280, 32));
}

export function refreshTodTextures(scene, todId) {
  const add = (key, cv) => {
    if (scene.textures.exists(key)) scene.textures.remove(key);
    scene.textures.addCanvas(key, cv);
  };
  add('pad', makePad(todId));
  add('ascent-sky', makeAscentSky(todId));
  add('clouds-far', makeCloudSheet(1, todId));
  add('clouds-near', makeCloudSheet(2, todId));
  add('haze', makeHazeBand(todId));
  add('ocean', makeOcean(todId));
}

export function refreshLoadoutTextures(scene, loadout, payload) {
  const add = (key, cv) => {
    if (scene.textures.exists(key)) scene.textures.remove(key);
    scene.textures.addCanvas(key, cv);
  };
  add('rocket', makeRocket(true, payload, loadout));
  add('rocket-equipped', makeRocket(true, payload, loadout));
  add('booster', makeBooster(false, loadout));
  add('booster-glide', makeBooster(true, loadout));
}
