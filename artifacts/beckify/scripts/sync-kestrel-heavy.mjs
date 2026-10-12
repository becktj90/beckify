#!/usr/bin/env node
// Refresh public/arcade/kestrel-heavy from a tagged release of becktj90/kestrel-heavy.
// The game's source of truth is that repo's web/ folder; this is a vendored built copy.
// Usage: node artifacts/beckify/scripts/sync-kestrel-heavy.mjs <tag>   (e.g. web-v1)
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, cpSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const tag = process.argv[2];
if (!tag) { console.error('usage: sync-kestrel-heavy.mjs <tag>'); process.exit(1); }
const here = path.dirname(fileURLToPath(import.meta.url));
const dest = path.join(here, '..', 'public', 'arcade', 'kestrel-heavy');
const tmp = mkdtempSync(path.join(tmpdir(), 'kh-'));
try {
  execFileSync('git', ['clone', '--quiet', '--depth', '1', '--branch', tag,
    'https://github.com/becktj90/kestrel-heavy.git', tmp], { stdio: 'inherit' });
  rmSync(dest, { recursive: true, force: true });
  cpSync(path.join(tmp, 'web'), dest, { recursive: true });
  writeFileSync(path.join(dest, 'VENDORED.md'),
    `Vendored from https://github.com/becktj90/kestrel-heavy/tree/${tag}/web\n` +
    `Do not edit here. Change kestrel-heavy, tag it, then rerun scripts/sync-kestrel-heavy.mjs.\n`);
  console.log(`Synced kestrel-heavy ${tag} -> ${dest}`);
} finally { rmSync(tmp, { recursive: true, force: true }); }
