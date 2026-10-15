const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const dir = path.join(root, 'public/arcade/kestrel-heavy');
const host = fs.readFileSync(path.join(root, 'src/components/games/KestrelHeavy.tsx'), 'utf8');

assert.ok(fs.existsSync(path.join(dir, 'index.html')), 'Unity WebGL index.html must exist');
assert.ok(fs.existsSync(path.join(dir, 'VENDORED.md')));
assert.ok(!fs.existsSync(path.join(root, 'public/arcade/kestrel-heavy-classic')), 'classic Phaser copy is archived in git tag, not shipped');
assert.match(host, /ARCADE_ASSET_VERSION = "unity-1"/);
assert.match(host, /arcade\/kestrel-heavy\/index\.html\?v=\$\{ARCADE_ASSET_VERSION\}/);
console.log('kestrel-heavy-unity: ok');
