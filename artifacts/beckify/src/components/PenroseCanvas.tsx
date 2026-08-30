import { useEffect, useRef } from "react";

/**
 * A small, complete Penrose P3 patch. The two Robinson triangles below are
 * deflated using the same golden-ratio construction as public/penrose.svg.
 * Unlike the old decorative quads, every piece has a precise final neighbour.
 */
type Point = { x: number; y: number };
type RobinsonTriangle = { thin: boolean; a: Point; b: Point; c: Point };
type Tile = RobinsonTriangle & { order: number; driftX: number; driftY: number; hue: number };

const PHI = (1 + Math.sqrt(5)) / 2;
const TAU = Math.PI * 2;

const toward = (from: Point, to: Point, amount: number): Point => ({
  x: from.x + (to.x - from.x) * amount,
  y: from.y + (to.y - from.y) * amount,
});

function deflate(triangles: RobinsonTriangle[]) {
  return triangles.flatMap(({ thin, a, b, c }) => {
    if (thin) {
      const p = toward(a, b, 1 / PHI);
      return [
        { thin: true, a: c, b: p, c: b },
        { thin: false, a: p, b: c, c: a },
      ];
    }
    const q = toward(b, a, 1 / PHI);
    const r = toward(b, c, 1 / PHI);
    return [
      { thin: false, a: r, b: c, c: a },
      { thin: false, a: q, b: r, c: b },
      { thin: true, a: r, b: q, c: a },
    ];
  });
}

function seeded(n: number) {
  return Math.abs(Math.sin(n * 78.233) * 43758.5453) % 1;
}

function buildPatch(width: number, height: number) {
  const origin = { x: 0, y: 0 };
  let triangles: RobinsonTriangle[] = [];

  // A ten-triangle sun is a legal Penrose seed. Alternating orientation lets
  // the paired Robinson triangles read as the familiar kite-and-dart field.
  for (let i = 0; i < 10; i += 1) {
    const b = { x: Math.cos(((2 * i - 1) * Math.PI) / 10), y: Math.sin(((2 * i - 1) * Math.PI) / 10) };
    const c = { x: Math.cos(((2 * i + 1) * Math.PI) / 10), y: Math.sin(((2 * i + 1) * Math.PI) / 10) };
    triangles.push(i % 2 === 0 ? { thin: false, a: origin, b: c, c: b } : { thin: false, a: origin, b, c });
  }
  for (let i = 0; i < 4; i += 1) triangles = deflate(triangles);

  const scale = Math.min(width, height) * 0.64;
  const center = { x: width * 0.7, y: height * 0.5 };
  const project = (p: Point): Point => ({ x: center.x + p.x * scale, y: center.y + p.y * scale });

  return triangles.map((triangle, index): Tile => {
    const a = project(triangle.a);
    const b = project(triangle.b);
    const c = project(triangle.c);
    const midpoint = { x: (a.x + b.x + c.x) / 3, y: (a.y + b.y + c.y) / 3 };
    const dx = midpoint.x - center.x;
    const dy = midpoint.y - center.y;
    const distance = Math.hypot(dx, dy) / scale;
    const angle = Math.atan2(dy, dx) + (seeded(index + 9) - 0.5) * 0.72;
    const drift = scale * (0.25 + seeded(index + 17) * 0.28);
    return {
      ...triangle,
      a,
      b,
      c,
      // Build from the centre out: the star establishes itself first, then
      // each ring keys into the previous one like a physical puzzle.
      order: distance * 1180 + seeded(index) * 220,
      driftX: Math.cos(angle) * drift,
      driftY: Math.sin(angle) * drift,
      hue: seeded(index + 3),
    };
  }).sort((left, right) => left.order - right.order);
}

function easeOutCubic(value: number) {
  return 1 - Math.pow(1 - value, 3);
}

function paintTriangle(context: CanvasRenderingContext2D, tile: Tile, progress: number, elapsed: number) {
  const settle = easeOutCubic(progress);
  const drift = 1 - settle;
  const a = { x: tile.a.x + tile.driftX * drift, y: tile.a.y + tile.driftY * drift };
  const b = { x: tile.b.x + tile.driftX * drift, y: tile.b.y + tile.driftY * drift };
  const c = { x: tile.c.x + tile.driftX * drift, y: tile.c.y + tile.driftY * drift };
  const colors = ["#5fe3ed", "#638eff", "#a776ff", "#f1b78f"];
  const color = colors[Math.floor(tile.hue * colors.length) % colors.length];
  const glint = 0.04 + (Math.sin(elapsed / 2400 + tile.hue * TAU) + 1) * 0.015;

  context.save();
  context.beginPath();
  context.moveTo(a.x, a.y);
  context.lineTo(b.x, b.y);
  context.lineTo(c.x, c.y);
  context.closePath();

  // Most of the field is linework; occasional panes borrow the restrained
  // aurora palette from the selected visual without becoming a foreground art
  // object. Thin and thick Robinson triangles get slightly different weight.
  context.globalAlpha = settle * (tile.hue > 0.67 ? 0.18 + glint : 0.035);
  context.fillStyle = color;
  context.fill();
  context.globalAlpha = settle * 0.68;
  context.strokeStyle = tile.thin ? "#d8c9ee" : "#f5d8e3";
  context.lineWidth = tile.thin ? 0.58 : 0.82;
  context.stroke();
  context.restore();
}

export function PenroseCanvas({ className = "" }: { className?: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    const context = canvas?.getContext("2d");
    if (!canvas || !context) return;

    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    let frame = 0;
    let start = performance.now();
    let tiles: Tile[] = [];
    let width = 0;
    let height = 0;

    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      const ratio = Math.min(window.devicePixelRatio || 1, 2);
      width = Math.max(1, rect.width);
      height = Math.max(1, rect.height);
      canvas.width = Math.floor(width * ratio);
      canvas.height = Math.floor(height * ratio);
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
      tiles = buildPatch(width, height);
      start = performance.now();
    };

    const draw = (now: number) => {
      const elapsed = reducedMotion ? 4800 : now - start;
      context.clearRect(0, 0, width, height);
      for (const tile of tiles) {
        const progress = Math.max(0, Math.min(1, (elapsed - tile.order) / 760));
        if (progress > 0) paintTriangle(context, tile, progress, elapsed);
      }
      // Assemble once, then only allow an extremely slow aurora glint. No
      // random restart: the field remains a coherent, finished tiling.
      if (!reducedMotion || elapsed < 4800) frame = requestAnimationFrame(draw);
    };

    resize();
    const observer = new ResizeObserver(resize);
    observer.observe(canvas);
    frame = requestAnimationFrame(draw);
    return () => {
      cancelAnimationFrame(frame);
      observer.disconnect();
    };
  }, []);

  return <canvas ref={canvasRef} className={className} aria-hidden="true" />;
}

export default PenroseCanvas;
