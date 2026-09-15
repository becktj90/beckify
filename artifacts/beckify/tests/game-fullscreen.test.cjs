const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const hook = fs.readFileSync(path.join(root, 'src/hooks/use-game-fullscreen.ts'), 'utf8');
const lib = fs.readFileSync(path.join(root, 'src/lib/game-fullscreen.ts'), 'utf8');
const css = fs.readFileSync(path.join(root, 'src/index.css'), 'utf8');
const host = fs.readFileSync(path.join(root, 'src/components/games/KestrelHeavy.tsx'), 'utf8');
const arcadeFs = fs.readFileSync(path.join(root, 'public/arcade/kestrel-heavy/js/fullscreen.js'), 'utf8');
const reactIndex = fs.readFileSync(path.join(root, 'index.html'), 'utf8');

function isIosPhone(userAgent) {
  return /iPhone|iPod/.test(userAgent);
}

function shouldAttemptNativeFullscreen(options) {
  if (isIosPhone(options.userAgent)) return false;
  return options.fullscreenEnabled;
}

function isLetterboxedRect(rect, viewport) {
  if (viewport.width <= 0 || viewport.height <= 0) return false;
  const cover = (rect.width * rect.height) / (viewport.width * viewport.height);
  return cover < 0.88 || viewport.width - rect.width > 48 || viewport.height - rect.height > 48;
}

assert.equal(isIosPhone('Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)'), true);
assert.equal(isIosPhone('Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X)'), false);
assert.equal(isIosPhone('Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120'), false);

assert.equal(
  shouldAttemptNativeFullscreen({
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)',
    fullscreenEnabled: true,
  }),
  false,
  'iPhone must skip native FS even when fullscreenEnabled is true',
);
assert.equal(
  shouldAttemptNativeFullscreen({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120',
    fullscreenEnabled: true,
  }),
  true,
);
assert.equal(
  shouldAttemptNativeFullscreen({
    userAgent: 'Mozilla/5.0 (Linux; Android 14) Chrome/120',
    fullscreenEnabled: true,
  }),
  true,
);

assert.equal(
  isLetterboxedRect({ width: 390, height: 220 }, { width: 390, height: 720 }),
  true,
  '16:9 cabinet in a tall phone viewport is letterboxed',
);
assert.equal(
  isLetterboxedRect({ width: 1920, height: 1080 }, { width: 1920, height: 1080 }),
  false,
  'edge-to-edge native fullscreen is not letterboxed',
);

function usableViewportHeight(visualHeight, layoutHeight, width, screenHeight = 0) {
  const vis = Math.round(Math.max(0, visualHeight));
  const layout = Math.round(Math.max(0, layoutHeight));
  const screen = Math.round(Math.max(0, screenHeight));
  const letterboxH = Math.max(1, width) * (9 / 16);
  let height = vis || layout;
  if (height <= letterboxH + 24 && layout > letterboxH + 48) height = layout;
  if (height <= letterboxH + 24 && screen > letterboxH + 48) height = screen;
  return Math.max(1, Math.round(height));
}

assert.equal(
  usableViewportHeight(220, 720, 390),
  720,
  '16:9 visual height on a tall phone must not drive pseudo-fullscreen',
);
assert.equal(
  usableViewportHeight(670, 844, 390),
  670,
  'URL-bar-adjusted visualViewport height is kept',
);
assert.equal(
  usableViewportHeight(220, 220, 390, 844),
  844,
  'screen height is the last resort when both visual and layout are letterboxed',
);

assert.match(lib, /iPhone\|iPod/);
assert.match(lib, /cover < 0\.88/);
assert.match(lib, /viewport-fit=cover/);
assert.match(lib, /--game-vv-height/);
assert.match(lib, /usableViewportHeight/);
assert.match(lib, /syncEmbeddedArcadeViewport/);
assert.match(lib, /beckify-kestrel-viewport/);
assert.match(hook, /shouldAttemptNativeFullscreen/);
assert.match(hook, /isLetterboxedElement/);
assert.match(hook, /setCssImmersive\(true\)/);
assert.match(hook, /game-immersive-open/);
assert.match(hook, /cssImmersive \|\| nativeOn/);
assert.match(hook, /applyVisualViewportVars\(document\.documentElement, true\)/);
assert.match(css, /html\.game-immersive-open/);
assert.match(css, /--game-vv-width/);
assert.match(css, /env\(safe-area-inset-top/);
assert.match(css, /\.game-stage\.is-immersive iframe/);
assert.match(css, /aspect-ratio:\s*unset/);
assert.match(css, /min-height:\s*var\(--game-vv-height/);
assert.match(css, /\.game-stage\.is-immersive iframe[\s\S]*width:\s*100%\s*!important/);
assert.match(css, /\.game-stage\.is-immersive iframe[\s\S]*height:\s*100%\s*!important/);
assert.doesNotMatch(css, /\.game-stage\.is-immersive iframe[\s\S]*width:\s*auto/);
assert.match(host, /aria-pressed=\{immersive\}/);
assert.match(host, /immersive \? "EXIT" : "FULL"/);
assert.match(host, /is-immersive/);
assert.match(host, /syncEmbeddedArcadeViewport/);
assert.match(host, /ARCADE_ASSET_VERSION = "kestrel-7"/);
assert.match(arcadeFs, /iPhone\|iPod/);
assert.match(arcadeFs, /textContent = active \? 'EXIT' : 'FULL'/);
assert.match(arcadeFs, /applyHostViewportMessage/);
assert.match(arcadeFs, /usableViewportHeight/);
assert.match(reactIndex, /viewport-fit=cover/);

assert.doesNotMatch(
  hook,
  /if \(element\.requestFullscreen\) \{\s*await element\.requestFullscreen\(\);\s*return;/,
  'must not treat a resolving requestFullscreen as success without a fill check',
);

console.log('Kestrel Heavy fullscreen fallback and label-state checks passed');
