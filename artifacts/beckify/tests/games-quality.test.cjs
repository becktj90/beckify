const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('typescript');

const root = path.join(__dirname, '..');
const gamesDir = path.join(root, 'src', 'components', 'games');

const walk = (dir) => {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const next = path.join(dir, entry.name);
    if (entry.isDirectory()) files.push(...walk(next));
    else files.push(next);
  }
  return files;
};

const siteFiles = [
  path.join(root, 'src/App.tsx'),
  path.join(root, 'src/data/site-content.ts'),
  path.join(root, 'src/data/site-stats.ts'),
  path.join(root, 'src/lib/assistant/search.ts'),
  path.join(root, 'src/pages/sitemap.tsx'),
  path.join(root, 'src/components/sections/Games.tsx'),
  path.join(root, 'scripts/generate-sitemap.mjs'),
  path.join(root, 'scripts/generate-static-routes.mjs'),
];

for (const file of siteFiles) {
  const text = fs.readFileSync(file, 'utf8');
  assert.doesNotMatch(text, /hexgl/i, `${path.relative(root, file)} still mentions HexGL`);
}

assert.equal(fs.existsSync(path.join(root, 'public/vendor/hexgl')), false, 'vendor HexGL tree must be gone');
assert.equal(fs.existsSync(path.join(gamesDir, 'HexGL.tsx')), false);
assert.equal(fs.existsSync(path.join(root, 'src/pages/hexgl.tsx')), false);
assert.ok(fs.existsSync(path.join(root, 'public/games/kids/apollo.png')), 'Apollo portrait missing');
assert.ok(fs.existsSync(path.join(root, 'public/games/kids/rocco.png')), 'Rocco portrait missing');

const siteStats = fs.readFileSync(path.join(root, 'src/data/site-stats.ts'), 'utf8');
assert.match(siteStats, /PUBLIC_GAME_COUNT = 7/);

const artSource = fs.readFileSync(path.join(gamesDir, 'characterArt.ts'), 'utf8');
const { outputText } = ts.transpileModule(artSource, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
});
const generated = new Module('characterArt');
generated._compile(outputText, path.join(__dirname, 'characterArt.generated.js'));
const art = generated.exports;
assert.equal(art.kidSrc('apollo', '/'), '/games/kids/apollo.png');
assert.equal(art.kidSrc('rocco', '/'), '/games/kids/rocco.png');
assert.equal(art.KIDS.apollo.prop.includes('orange'), true);
assert.equal(art.KIDS.rocco.prop.includes('pink'), true);
assert.equal(art.kidSrc('apollo', '/site/'), '/site/games/kids/apollo.png');

const gameSources = walk(gamesDir).filter((file) => /\.(tsx|ts)$/.test(file)).map((file) => fs.readFileSync(file, 'utf8')).join('\n');
assert.match(gameSources, /games\/kids\/apollo\.png/);
assert.match(gameSources, /games\/kids\/rocco\.png/);
assert.doesNotMatch(gameSources, /temple run/i);
assert.doesNotMatch(gameSources, /imangi/i);
assert.match(fs.readFileSync(path.join(gamesDir, 'ApolloRoccoRun.tsx'), 'utf8'), /game-playfield/);
assert.match(fs.readFileSync(path.join(root, 'src/index.css'), 'utf8'), /\.game-stage\.is-immersive/);

console.log('HexGL removal and kid portrait helpers passed');
