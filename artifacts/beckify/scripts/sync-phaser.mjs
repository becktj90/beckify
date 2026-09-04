#!/usr/bin/env node
/**
 * Copy Phaser 4.2.1 full UMD (Matter included) into the arcade vendor folder.
 * Same file as jsDelivr phaser@4.2.1/dist/phaser.min.js.
 * Never copy phaser-arcade-physics — New Glenn Runner uses built-in Matter.
 * Keeps the iframe on a same-origin script (CSP + no CDN in the game HTML).
 */
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const here = path.dirname(fileURLToPath(import.meta.url));
const dest = path.resolve(here, '../public/arcade/new-glenn-runner/vendor/phaser.min.js');

const candidates = [
  () => require.resolve('phaser/dist/phaser.min.js'),
  () => path.resolve(here, '../node_modules/phaser/dist/phaser.min.js'),
  () => path.resolve(here, '../../node_modules/phaser/dist/phaser.min.js'),
];

let src = null;
for (const find of candidates) {
  try {
    const next = find();
    if (fs.existsSync(next)) {
      src = next;
      break;
    }
  } catch {
    /* try next */
  }
}

if (!src) {
  if (fs.existsSync(dest)) {
    console.log('Phaser npm package not installed; keeping existing vendor build.');
    process.exit(0);
  }
  throw new Error('phaser@4.2.x is not installed and vendor/phaser.min.js is missing.');
}

if (src.includes('phaser-arcade-physics')) {
  throw new Error('Refusing arcade-physics-only Phaser. New Glenn Runner needs the full 4.2.1 Matter build.');
}

fs.mkdirSync(path.dirname(dest), { recursive: true });
fs.copyFileSync(src, dest);

const copied = fs.readFileSync(dest, 'utf8');
if (!copied.includes('Matter') || copied.length < 800000) {
  throw new Error('Vendor Phaser build looks incomplete — expected the full 4.2.1 bundle with Matter.');
}

console.log(`Synced Phaser 4.2.1 (full Matter) from ${src} -> ${dest}`);
