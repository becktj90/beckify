import { useEffect, useRef } from "react";

type Tile = { x: number; y: number; radius: number; angle: number; thin: boolean; depth: number };
type Palette = { ink: string; lines: string[]; glow: string };

const GOLDEN = (1 + Math.sqrt(5)) / 2;
const palettes: Palette[] = [
  { ink: "#08131d", lines: ["#7de2d1", "#8b7bff", "#f2b880", "#dce8ff"], glow: "#35d2bd" },
  { ink: "#0e1116", lines: ["#d7dbe2", "#8f9baa", "#b9c7d8", "#eef2f4"], glow: "#b9c7d8" },
  { ink: "#17100b", lines: ["#f0a35b", "#c7773d", "#f2d39b", "#fff1c7"], glow: "#f0a35b" },
  { ink: "#0f0b18", lines: ["#ef77c8", "#8b7bff", "#5fd7ff", "#f4f0ff"], glow: "#ef77c8" },
];

function inflate(tile: Tile, result: Tile[]) {
  if (tile.depth <= 0) { result.push(tile); return; }
  const childRadius = tile.radius / GOLDEN;
  const spread = tile.thin ? 0.31 : 0.48;
  inflate({ ...tile, x: tile.x + Math.cos(tile.angle - spread) * childRadius, y: tile.y + Math.sin(tile.angle - spread) * childRadius, radius: childRadius, angle: tile.angle - 0.22, thin: !tile.thin, depth: tile.depth - 1 }, result);
  inflate({ ...tile, x: tile.x + Math.cos(tile.angle + spread) * childRadius, y: tile.y + Math.sin(tile.angle + spread) * childRadius, radius: childRadius * 0.98, angle: tile.angle + 0.22, thin: tile.thin, depth: tile.depth - 1 }, result);
}

function makeTiles(width: number, height: number, seed: number) {
  const size = Math.min(width, height) * 0.44;
  const center = { x: width / 2, y: height / 2 };
  const tiles: Tile[] = [];
  for (let i = 0; i < 10; i += 1) inflate({ x: center.x + Math.cos(i * Math.PI / 5 + seed) * size * 0.28, y: center.y + Math.sin(i * Math.PI / 5 + seed) * size * 0.28, radius: size, angle: i * Math.PI / 5 + seed, thin: i % 2 === 0, depth: 4 }, tiles);
  return tiles.sort((a, b) => Math.hypot(a.x - center.x, a.y - center.y) - Math.hypot(b.x - center.x, b.y - center.y));
}

function drawTile(ctx: CanvasRenderingContext2D, tile: Tile, palette: Palette, index: number) {
  const sides = tile.thin ? 4 : 4;
  const angle = tile.angle + (tile.thin ? 0.18 : -0.12);
  ctx.beginPath();
  for (let i = 0; i < sides; i += 1) {
    const a = angle + i * Math.PI / 2;
    const stretch = i % 2 === 0 ? 1 : (tile.thin ? 0.68 : 1.16);
    const x = tile.x + Math.cos(a) * tile.radius * stretch;
    const y = tile.y + Math.sin(a) * tile.radius * stretch;
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  }
  ctx.closePath();
  ctx.fillStyle = palette.ink;
  ctx.fill();
  ctx.strokeStyle = palette.lines[index % palette.lines.length];
  ctx.globalAlpha = 0.45;
  ctx.lineWidth = tile.thin ? 0.7 : 1;
  ctx.stroke();
  ctx.globalAlpha = 0.24;
  ctx.beginPath();
  ctx.moveTo(tile.x, tile.y);
  ctx.lineTo(tile.x + Math.cos(angle) * tile.radius * 0.68, tile.y + Math.sin(angle) * tile.radius * 0.68);
  ctx.strokeStyle = palette.lines[(index + 1) % palette.lines.length];
  ctx.stroke();
  ctx.globalAlpha = 1;
}

export function PenroseCanvas({ className = "" }: { className?: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext("2d");
    if (!context) return;
    let frame = 0;
    let start = performance.now();
    let tiles: Tile[] = [];
    let palette = palettes[0];
    let stopped = false;
    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      const ratio = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = Math.max(1, Math.floor(rect.width * ratio));
      canvas.height = Math.max(1, Math.floor(rect.height * ratio));
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
      tiles = makeTiles(rect.width, rect.height, Math.random() * Math.PI * 2);
    };
    const restart = () => { const rect = canvas.getBoundingClientRect(); palette = palettes[Math.floor(Math.random() * palettes.length)]; tiles = makeTiles(rect.width, rect.height, Math.random() * Math.PI * 2); start = performance.now(); };
    resize();
    const observer = new ResizeObserver(resize);
    observer.observe(canvas);
    const draw = (now: number) => {
      if (stopped) return;
      const elapsed = now - start;
      const rect = canvas.getBoundingClientRect();
      context.clearRect(0, 0, rect.width, rect.height);
      const reveal = Math.min(tiles.length, Math.floor((elapsed / 1700) * tiles.length));
      for (let i = 0; i < reveal; i += 1) drawTile(context, tiles[i], palette, i);
      context.fillStyle = palette.glow;
      context.globalAlpha = 0.18;
      context.beginPath();
      context.arc(rect.width / 2, rect.height / 2, Math.min(rect.width, rect.height) * 0.19, 0, Math.PI * 2);
      context.fill();
      context.globalAlpha = 1;
      if (elapsed > 2700) restart();
      frame = requestAnimationFrame(draw);
    };
    frame = requestAnimationFrame(draw);
    return () => { stopped = true; cancelAnimationFrame(frame); observer.disconnect(); };
  }, []);
  return <canvas ref={canvasRef} className={className} aria-hidden="true" />;
}

export default PenroseCanvas;
