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

// Desktop: landscape windows get an undistorted 3:4 (iPad-shaped) stage at full height with side panels; iframe must allow fullscreen.
const fsPath = require('node:path');
const runner = require('node:fs').readFileSync(fsPath.join(__dirname, '../public/arcade/kestrel-heavy/index.html'), 'utf8');
assert.match(runner, /@media \(min-aspect-ratio: 1\/1\)\s*\{\s*#stage\s*\{[^}]*100dvh \* 3 \/ 4/);
assert.doesNotMatch(runner, /#stage \{ top: 0; left: 0; transform: none; width: 100vw/);
assert.match(host, /allowFullScreen/);
