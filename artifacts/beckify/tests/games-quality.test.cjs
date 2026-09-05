const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const gamesDir = path.join(root, 'src', 'components', 'games');

const walk = (dir) => {
  if (!fs.existsSync(dir)) return [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const next = path.join(dir, entry.name);
    if (entry.isDirectory()) files.push(...walk(next));
    else files.push(next);
  }
  return files;
};

const REMOVED_GAMES = [
  'cosmic-cadet',
  'booty-butt-scooter',
  'finger-runner',
  'toot-troopers',
  'apollo-rocco-run',
  'pup-planet',
  'hexgl',
];
const REMOVED_TITLES = [
  'Cosmic Cadet',
  'Booty Butt Scooter',
  'Finger Runner',
  'Toot Troopers',
  'Apollo & Rocco Run',
  'Pup Planet',
  'HexGL',
];

const siteFiles = [
  path.join(root, 'src/App.tsx'),
  path.join(root, 'src/data/site-content.ts'),
  path.join(root, 'src/data/site-stats.ts'),
  path.join(root, 'src/lib/assistant/search.ts'),
  path.join(root, 'src/pages/sitemap.tsx'),
  path.join(root, 'src/pages/games.tsx'),
  path.join(root, 'src/pages/home.tsx'),
  path.join(root, 'src/components/sections/Games.tsx'),
  path.join(root, 'scripts/generate-sitemap.mjs'),
  path.join(root, 'scripts/generate-static-routes.mjs'),
];

for (const file of siteFiles) {
  const text = fs.readFileSync(file, 'utf8');
  assert.doesNotMatch(text, /hexgl/i, `${path.relative(root, file)} still mentions HexGL`);
  for (const slug of REMOVED_GAMES) {
    assert.doesNotMatch(text, new RegExp(slug, 'i'), `${path.relative(root, file)} still mentions ${slug}`);
  }
  for (const title of REMOVED_TITLES) {
    assert.equal(text.includes(title), false, `${path.relative(root, file)} still mentions ${title}`);
  }
}

assert.equal(fs.existsSync(path.join(root, 'public/vendor/hexgl')), false, 'vendor HexGL tree must be gone');
assert.equal(fs.existsSync(path.join(gamesDir, 'HexGL.tsx')), false);
assert.equal(fs.existsSync(path.join(root, 'src/pages/hexgl.tsx')), false);
assert.ok(fs.existsSync(path.join(root, 'public/games/kids/apollo.png')), 'Apollo avatar file must stay on disk');
assert.ok(fs.existsSync(path.join(root, 'public/games/kids/rocco.png')), 'Rocco avatar file must stay on disk');

const remainingGameFiles = [
  'KidsSpaceShooter.tsx',
  'cosmicCadet.ts',
  'BootyButtScooter.tsx',
  'FingerRunner.tsx',
  'TootTroopers.tsx',
  'ApolloRoccoRun.tsx',
  'apolloRoccoRun.ts',
  'PupPlanet.tsx',
  'characterArt.ts',
];
for (const name of remainingGameFiles) {
  assert.equal(fs.existsSync(path.join(gamesDir, name)), false, `${name} must be deleted`);
}
for (const slug of ['cosmic-cadet', 'booty-butt-scooter', 'finger-runner', 'toot-troopers', 'apollo-rocco-run', 'pup-planet']) {
  assert.equal(fs.existsSync(path.join(root, 'src/pages', `${slug}.tsx`)), false, `${slug} page must be deleted`);
}

assert.ok(fs.existsSync(path.join(gamesDir, 'KestrelHeavy.tsx')), 'Kestrel Heavy component must stay');
assert.ok(fs.existsSync(path.join(root, 'src/pages/kestrel-heavy.tsx')), 'Kestrel Heavy page must stay');
assert.ok(fs.existsSync(path.join(root, 'public/arcade/kestrel-heavy/index.html')), 'Kestrel Heavy arcade assets must stay');

const siteStats = fs.readFileSync(path.join(root, 'src/data/site-stats.ts'), 'utf8');
assert.match(siteStats, /PUBLIC_GAME_COUNT = 1/);

const siteContent = fs.readFileSync(path.join(root, 'src/data/site-content.ts'), 'utf8');
assert.match(siteContent, /name: "Kestrel Heavy"/);
assert.match(siteContent, /url: "\/games\/kestrel-heavy"/);
const gameNames = [...siteContent.matchAll(/name: "([^"]+)"/g)]
  .map((m) => m[1])
  .filter((name) => name === 'Kestrel Heavy');
assert.equal(gameNames.length, 1, 'site-content must list only Kestrel Heavy');

const appSrc = fs.readFileSync(path.join(root, 'src/App.tsx'), 'utf8');
assert.match(appSrc, /path="\/games\/kestrel-heavy"/);
assert.match(appSrc, /path="\/games\/kestrel-heavy\/"/);
assert.match(appSrc, /path="\/games\/new-glenn-runner\/"/);
assert.doesNotMatch(appSrc, /path="\/games\/(?!kestrel-heavy|new-glenn-runner)/);

const gameSources = walk(gamesDir).filter((file) => /\.(tsx|ts)$/.test(file)).map((file) => fs.readFileSync(file, 'utf8')).join('\n');
assert.doesNotMatch(gameSources, /games\/kids\/apollo\.png/);
assert.doesNotMatch(gameSources, /games\/kids\/rocco\.png/);
assert.doesNotMatch(gameSources, /kidSrc\s*\(/);
assert.doesNotMatch(gameSources, /drawKidPortrait/);
assert.doesNotMatch(gameSources, /drawCartoonHero/);
assert.doesNotMatch(gameSources, /label:\s*"Apollo"/);
assert.doesNotMatch(gameSources, /label:\s*"Rocco"/);
assert.doesNotMatch(gameSources, /temple run/i);
assert.doesNotMatch(gameSources, /imangi/i);
assert.match(gameSources, /Kestrel Heavy/);
assert.match(fs.readFileSync(path.join(root, 'src/index.css'), 'utf8'), /\.game-stage\.is-immersive/);
assert.doesNotMatch(fs.readFileSync(path.join(root, 'src/index.css'), 'utf8'), /\.cosmic-cadet|\.kid-hud/);

const hubCopy = [
  path.join(root, 'src/data/site-content.ts'),
  path.join(root, 'src/components/sections/Games.tsx'),
  path.join(root, 'src/lib/assistant/search.ts'),
  path.join(root, 'src/pages/games.tsx'),
  path.join(root, 'scripts/generate-static-routes.mjs'),
].map((file) => fs.readFileSync(file, 'utf8')).join('\n');
assert.doesNotMatch(hubCopy, /starring Apollo/);
assert.doesNotMatch(hubCopy, /Play as Apollo/);
assert.doesNotMatch(hubCopy, /pick Apollo or Rocco/i);
assert.doesNotMatch(hubCopy, /seven original/i);
assert.doesNotMatch(hubCopy, /Seven on-site/);
assert.match(hubCopy, /Kestrel Heavy/);

console.log('Kestrel Heavy is the sole public game; HexGL and kid-photo playables stay gone');
