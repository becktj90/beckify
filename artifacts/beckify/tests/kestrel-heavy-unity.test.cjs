const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const dir = path.join(root, 'public/arcade/kestrel-heavy');
const host = fs.readFileSync(path.join(root, 'src/components/games/KestrelHeavy.tsx'), 'utf8');

assert.ok(fs.existsSync(path.join(dir, 'index.html')), 'Unity WebGL index.html must exist');
assert.ok(fs.existsSync(path.join(dir, 'VENDORED.md')));
assert.ok(!fs.existsSync(path.join(root, 'public/arcade/kestrel-heavy-classic')), 'classic Phaser copy is archived in git tag, not shipped');
assert.match(host, /ARCADE_ASSET_VERSION = "unity-4"/);
assert.match(host, /arcade\/kestrel-heavy\/index\.html\?v=\$\{ARCADE_ASSET_VERSION\}/);
console.log('kestrel-heavy-unity: ok');

// Runner is the artifact's own full-viewport template (no fixed 3:4 stage) and speaks the host viewport protocol.
const runner = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');
assert.match(runner, /#stage \{ position: fixed; inset: 0;/);
assert.doesNotMatch(runner, /100dvh \* 3 \/ 4/);
assert.match(runner, /beckify-kestrel-viewport/);
assert.match(runner, /type: "chrome"/);
assert.match(runner, /type: "fullscreen"/);
assert.match(runner, /id="fs"/);
assert.match(host, /allowFullScreen/);
assert.match(host, /type === "chrome"/);
assert.match(host, /type === "fullscreen"/);
assert.match(host, /runnerHasChrome/);
console.log('kestrel-heavy-unity runner protocol: ok');

// Full-bleed: no host card/border/padding/nav chrome around the iframe; a small back link remains.
const page = fs.readFileSync(path.join(root, 'src/pages/kestrel-heavy.tsx'), 'utf8');
assert.doesNotMatch(page, /Layout/);
assert.match(host, /fixed inset-0[^"]*h-\[100dvh\]/);
assert.doesNotMatch(host, /rounded-2xl|kh-stage-fill|shadow-\[0_20px/);
assert.match(host, /kh-back-link/);
assert.match(host, /env\(safe-area-inset-top\)/);
console.log('kestrel-heavy full-bleed host: ok');
