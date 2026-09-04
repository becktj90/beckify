const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const arcade = fs.readFileSync(path.join(root, 'public/toolbox/js/arcade.js'), 'utf8');
const arcadeHtml = fs.readFileSync(path.join(root, 'public/arcade/new-glenn-runner/index.html'), 'utf8');
const reactIndex = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const host = fs.readFileSync(path.join(root, 'src/components/games/NewGlennRunner.tsx'), 'utf8');

assert.match(arcade, /const BOOST_COYOTE_SEC = 0\.14/);
assert.match(arcade, /const BOOST_BUFFER_SEC = 0\.18/);
assert.match(arcade, /function isBoosting\(/);
assert.match(arcade, /function consumeBoostTap\(/);
assert.match(arcade, /function updateInputFeel\(/);
assert.match(arcade, /function updateFlightHazards\(/);
assert.match(arcade, /if \(updateFlightHazards\(dt, 'maxq'\)\) return/);
assert.match(arcade, /if \(updateFlightHazards\(dt, 'ascent'\)\) return/);
assert.match(arcade, /const PICKUP_TYPES = \['shield', 'fuel', 'boost'\]/);
assert.match(arcade, /function tryAbsorbHit\(/);
assert.match(arcade, /function spawnPickup\(/);
assert.match(arcade, /hiArcadeScore/);
assert.match(arcade, /recordGameScore\('new-glenn-runner', points\)/);
assert.match(arcade, /Audio\.stopMusic\(\)/);
assert.match(arcade, /announce\(/);
assert.match(arcade, /arcade-live/);
assert.doesNotMatch(arcade, /"VT323"/);
assert.doesNotMatch(arcade, /Share Tech Mono/);
assert.match(arcade, /IBM Plex Mono/);
assert.match(arcade, /Exo 2/);
assert.match(arcade, /prefers-reduced-motion/);
assert.match(arcade, /e\.code === 'Escape'/);
assert.doesNotMatch(arcade, /temple run/i);
assert.doesNotMatch(arcade, /label:\s*"Apollo"/);
assert.doesNotMatch(arcade, /label:\s*"Rocco"/);

assert.match(arcadeHtml, /data-arcade-standalone/);
assert.match(arcadeHtml, /KID \/ CADET \/ PAD RAT/);
assert.match(arcadeHtml, /id="arcade-live"/);
assert.match(arcadeHtml, /aria-live="polite"/);
assert.match(arcadeHtml, /src="\/toolbox\/js\/arcade\.js"/);
assert.match(arcadeHtml, /src="\/toolbox\/js\/local-store\.js"/);
assert.match(arcadeHtml, /fonts\.googleapis\.com.*Exo\+2/);
assert.match(arcadeHtml, /IBM\+Plex\+Mono/);
assert.doesNotMatch(arcadeHtml, /cdn\.jsdelivr\.net/);

assert.match(reactIndex, /frame-src 'self'/);
assert.match(host, /arcade\/new-glenn-runner\/index\.html/);
assert.match(host, /title="New Glenn Runner"/);
assert.doesNotMatch(host, /sandbox=/);
assert.doesNotMatch(host, /scrolling=/);

console.log('New Glenn Runner play-pass systems and iframe host checks passed');
