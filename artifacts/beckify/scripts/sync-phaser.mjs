#!/usr/bin/env node
/**
 * Copy the npm Phaser 4 build into the arcade vendor folder.
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

fs.mkdirSync(path.dirname(dest), { recursive: true });
fs.copyFileSync(src, dest);
console.log(`Synced Phaser from ${src} -> ${dest}`);
