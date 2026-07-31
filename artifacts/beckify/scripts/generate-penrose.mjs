/**
 * Generates public/penrose.svg — the aperiodic P3 tiling used as a page texture.
 *
 * Robinson-triangle deflation: start with a wheel of ten "thick" half-rhombs
 * around the origin, then repeatedly subdivide using the golden ratio. The
 * result never repeats, which is exactly why it works as a background — there
 * is no tile seam to spot.
 *
 * Each half-rhomb emits the two edges meeting at its apex and skips the shared
 * diagonal, so the output reads as rhombus outlines rather than triangles.
 *
 * One committed asset shared by the React app and the standalone /toolbox app.
 * Re-run with:  node scripts/generate-penrose.mjs
 */
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const PHI = (1 + Math.sqrt(5)) / 2;
const DEPTH = 5;
const EXTENT = 1000;
const STROKE = "#8b7bff";

const towards = (from, to, t) => ({
  x: from.x + (to.x - from.x) * t,
  y: from.y + (to.y - from.y) * t,
});

const subdivide = (triangles) => {
  const next = [];
  for (const { thin, a, b, c } of triangles) {
    if (thin) {
      const p = towards(a, b, 1 / PHI);
      next.push({ thin: true, a: c, b: p, c: b }, { thin: false, a: p, b: c, c: a });
    } else {
      const q = towards(b, a, 1 / PHI);
      const r = towards(b, c, 1 / PHI);
      next.push(
        { thin: false, a: r, b: c, c: a },
        { thin: false, a: q, b: r, c: b },
        { thin: true, a: r, b: q, c: a },
      );
    }
  }
  return next;
};

const origin = { x: 0, y: 0 };
let triangles = [];
for (let i = 0; i < 10; i++) {
  const b = { x: Math.cos(((2 * i - 1) * Math.PI) / 10), y: Math.sin(((2 * i - 1) * Math.PI) / 10) };
  const c = { x: Math.cos(((2 * i + 1) * Math.PI) / 10), y: Math.sin(((2 * i + 1) * Math.PI) / 10) };
  triangles.push(i % 2 === 0 ? { thin: false, a: origin, b: c, c: b } : { thin: false, a: origin, b, c });
}
for (let i = 0; i < DEPTH; i++) triangles = subdivide(triangles);

const at = (p) => `${(p.x * EXTENT).toFixed(1)} ${(p.y * EXTENT).toFixed(1)}`;
const d = triangles.map((t) => `M${at(t.a)}L${at(t.b)}L${at(t.c)}`).join("");

const svg =
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${-EXTENT} ${-EXTENT} ${EXTENT * 2} ${EXTENT * 2}" ` +
  `preserveAspectRatio="xMidYMid slice">` +
  `<path d="${d}" fill="none" stroke="${STROKE}" stroke-width="1.6" stroke-linejoin="round"/>` +
  `</svg>\n`;

const out = join(dirname(fileURLToPath(import.meta.url)), "..", "public", "penrose.svg");
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, svg);
console.log(`penrose.svg — ${triangles.length} half-rhombs, ${(svg.length / 1024).toFixed(1)} kB`);
