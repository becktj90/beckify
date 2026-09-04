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

const glenn = nonImmersiveStage(fs.readFileSync(path.join(gamesDir, 'NewGlennRunner.tsx'), 'utf8'));

assert.match(glenn, /\bw-full\b/);
assert.match(glenn, /\bmin-w-0\b/);
assert.doesNotMatch(glenn, /min-h-\[480px\]/);

assert.match(css, /\.game-stage \{[^}]*min-width:\s*0/s);
assert.doesNotMatch(css, /minmax\(280px,\s*540px\)/, 'old Cosmic Cadet column min-width overflowed phones');
assert.doesNotMatch(css, /minmax\(360px,\s*550px\)/);

console.log('New Glenn game-stage mobile overflow guards passed');
