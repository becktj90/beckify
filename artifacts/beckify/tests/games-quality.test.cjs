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
assert.ok(fs.existsSync(path.join(root, 'public/games/kids/apollo.png')), 'Apollo avatar file must stay on disk');
assert.ok(fs.existsSync(path.join(root, 'public/games/kids/rocco.png')), 'Rocco avatar file must stay on disk');

const siteStats = fs.readFileSync(path.join(root, 'src/data/site-stats.ts'), 'utf8');
assert.match(siteStats, /PUBLIC_GAME_COUNT = 7/);

const artSource = fs.readFileSync(path.join(gamesDir, 'characterArt.ts'), 'utf8');
const { outputText } = ts.transpileModule(artSource, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
});
const generated = new Module('characterArt');
generated._compile(outputText, path.join(__dirname, 'characterArt.generated.js'));
const art = generated.exports;
assert.deepEqual([...art.HERO_IDS], ['blaze', 'spark']);
assert.equal(art.HEROES.blaze.label, 'Blaze');
assert.equal(art.HEROES.spark.label, 'Spark');
assert.equal(art.HEROES.blaze.prop.includes('orange'), true);
assert.equal(art.HEROES.spark.prop.includes('pink'), true);
assert.equal(typeof art.drawCartoonHero, 'function');
assert.match(art.cartoonHeroSrc('blaze'), /^data:image\/svg\+xml/);
assert.match(art.cartoonHeroSrc('spark'), /^data:image\/svg\+xml/);
assert.doesNotMatch(artSource, /games\/kids\/(apollo|rocco)\.png/);
assert.equal(art.kidSrc, undefined);

const gameSources = walk(gamesDir).filter((file) => /\.(tsx|ts)$/.test(file)).map((file) => fs.readFileSync(file, 'utf8')).join('\n');
assert.doesNotMatch(gameSources, /games\/kids\/apollo\.png/);
assert.doesNotMatch(gameSources, /games\/kids\/rocco\.png/);
assert.doesNotMatch(gameSources, /kidSrc\s*\(/);
assert.doesNotMatch(gameSources, /drawKidPortrait/);
assert.doesNotMatch(gameSources, /label:\s*"Apollo"/);
assert.doesNotMatch(gameSources, /label:\s*"Rocco"/);
assert.match(gameSources, /drawCartoonHero/);
assert.doesNotMatch(gameSources, /temple run/i);
assert.doesNotMatch(gameSources, /imangi/i);
assert.match(fs.readFileSync(path.join(gamesDir, 'ApolloRoccoRun.tsx'), 'utf8'), /game-playfield/);
assert.match(fs.readFileSync(path.join(root, 'src/index.css'), 'utf8'), /\.game-stage\.is-immersive/);

const hubCopy = [
  path.join(root, 'src/data/site-content.ts'),
  path.join(root, 'src/components/sections/Games.tsx'),
  path.join(root, 'src/lib/assistant/search.ts'),
  path.join(root, 'src/pages/booty-butt-scooter.tsx'),
  path.join(root, 'src/pages/apollo-rocco-run.tsx'),
  path.join(root, 'src/pages/toot-troopers.tsx'),
  path.join(root, 'src/pages/pup-planet.tsx'),
  path.join(root, 'scripts/generate-static-routes.mjs'),
].map((file) => fs.readFileSync(file, 'utf8')).join('\n');
assert.doesNotMatch(hubCopy, /starring Apollo/);
assert.doesNotMatch(hubCopy, /Play as Apollo/);
assert.doesNotMatch(hubCopy, /pick Apollo or Rocco/i);

console.log('HexGL removal and cartoon hero helpers passed');
