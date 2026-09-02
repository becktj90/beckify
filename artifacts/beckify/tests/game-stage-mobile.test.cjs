const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const gamesDir = path.join(__dirname, '..', 'src', 'components', 'games');
const cssPath = path.join(__dirname, '..', 'src', 'index.css');
const css = fs.readFileSync(cssPath, 'utf8');

const nonImmersiveStage = (source) => {
  const match = source.match(/game-stage[\s\S]*?immersive \? "[^"]+" : "([^"]+)"/);
  assert.ok(match, 'expected a game-stage immersive / non-immersive class pair');
  return match[1];
};

const pup = nonImmersiveStage(fs.readFileSync(path.join(gamesDir, 'PupPlanet.tsx'), 'utf8'));
const hex = nonImmersiveStage(fs.readFileSync(path.join(gamesDir, 'HexGL.tsx'), 'utf8'));

assert.match(pup, /\bw-full\b/);
assert.match(pup, /\bmin-w-0\b/);
assert.doesNotMatch(pup, /min-h-\[480px\]/, 'Pup Planet min-height + aspect-ratio forced a 640px stage');
assert.doesNotMatch(pup, /min-h-\[640px\]/);

assert.match(hex, /\bw-full\b/);
assert.match(hex, /\bmin-w-0\b/);
assert.doesNotMatch(hex, /min-h-\[480px\]/, 'HexGL min-height + 16/9 aspect forced an 853px stage');
assert.doesNotMatch(hex, /min-h-\[620px\]/);

assert.match(css, /\.game-stage \{[^}]*min-width:\s*0/s);
assert.match(css, /\.cosmic-canvas-actions button[^}]*min-width:\s*44px/s);
assert.match(css, /grid-template-columns:\s*minmax\(0,\s*540px\)/);
assert.doesNotMatch(css, /minmax\(280px,\s*540px\)/, 'Cosmic Cadet column min-width overflowed phones');
assert.doesNotMatch(css, /minmax\(360px,\s*550px\)/);

const widthFromMinHeight = (minHeight, ratioW, ratioH) => minHeight * (ratioW / ratioH);
assert.ok(widthFromMinHeight(480, 4, 3) === 640, 'documents the old Pup Planet overflow math');
assert.ok(Math.abs(widthFromMinHeight(480, 16, 9) - 853.333) < 0.01, 'documents the old HexGL overflow math');

console.log('Game-stage mobile overflow guards passed');
