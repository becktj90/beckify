/* Tile-home registry: shelves, search, pins, favorites, and classic deep links. */
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const { pathToFileURL } = require("node:url");

const root = path.join(__dirname, "..");
const classicHtml = fs.readFileSync(path.join(root, "public/toolbox/classic/index.html"), "utf8");

const IOS_ONLY = [
  "wifiStatus",
  "cellularStatus",
  "bluetoothScan",
  "acousticImager",
  "magnetometer",
  "barometer",
  "deviceHealth",
];

async function main() {
  const home = await import(pathToFileURL(path.join(root, "src/lib/toolbox-home.mjs")).href);
  const registry = await import(pathToFileURL(path.join(root, "src/data/toolbox-tools.mjs")).href);
  const seo = await import(pathToFileURL(path.join(root, "src/data/seo-copy.mjs")).href);
  const tools = home.TOOL_REGISTRY;
  const ids = tools.map((tool) => tool.toolId);
  const shelves = new Set(home.TOOL_SHELVES.map((shelf) => shelf.id));

  assert.equal(new Set(ids).size, ids.length, "tool ids are unique");
  assert.ok(!ids.includes("breathFlute"), "retired breath flute stays off the grid");
  assert.ok(tools.length > 90, "the app catalog is on the grid");
  assert.deepEqual(
    home.TOOL_HOME_AREAS.map((area) => area.id),
    ["field", "toolkit"],
  );
  assert.deepEqual(
    tools.filter((tool) => tool.availability === "ios-only").map((tool) => tool.toolId).sort(),
    [...IOS_ONLY].sort(),
  );
  for (const tool of tools) {
    assert.ok(shelves.has(tool.shelf), `${tool.toolId} shelf`);
    assert.ok(tool.title && tool.subtitle, `${tool.toolId} copy`);
    if (tool.tile) {
      for (const suffix of ["", "@2x", "@3x"]) {
        const file = path.join(root, "public/toolbox/tiles", `${tool.tile}${suffix}.png`);
        assert.ok(fs.existsSync(file), file);
      }
    }
    if (tool.availability === "web" && tool.anchor && !String(tool.href || "").startsWith("/control")) {
      assert.ok(classicHtml.includes(`id="${tool.anchor}"`), `${tool.toolId} anchor ${tool.anchor}`);
    }
    if (tool.availability === "ios-only") {
      assert.equal(home.toolBadge(tool), "iOS app only");
      assert.equal(home.toolHref(tool), home.APP_STORE_URL);
    }
  }

  const ohms = tools.find((tool) => tool.toolId === "ohmsLaw");
  assert.equal(ohms.shelf, "basics");
  assert.equal(ohms.tile, "ohmsLaw");
  assert.equal(home.toolHref(ohms), "/toolbox/classic/#sec-ohm");
  assert.equal(home.areaOf(ohms).id, "toolkit");

  const drop = tools.find((tool) => tool.toolId === "voltageDrop");
  assert.equal(drop.shelf, "jobsite");
  assert.equal(home.areaOf(drop).id, "field");
  const found = home.filterTools(tools, "k-factor feeder");
  assert.ok(found.some((tool) => tool.toolId === "voltageDrop"));
  assert.deepEqual(home.filterTools(tools, "   "), tools);
  assert.equal(home.filterTools(tools, "zzzz-not-a-tool").length, 0);

  const groups = home.groupToolsByShelf(tools.filter((tool) => tool.shelf === "basics"));
  assert.equal(groups.length, 1);
  assert.equal(groups[0].shelf.id, "basics");
  assert.ok(groups[0].tools[0].toolId === "ohmsLaw");

  assert.deepEqual(home.toggleId(["a"], "b"), ["a", "b"]);
  assert.deepEqual(home.toggleId(["a", "b"], "a"), ["b"]);
  assert.equal(home.parseStoredIds(null, ids), null);
  assert.deepEqual(home.parseStoredIds("nope", ids), []);
  assert.deepEqual(home.parseStoredIds(JSON.stringify(["ohmsLaw", "nope", "ohmsLaw"]), ids), ["ohmsLaw"]);
  assert.deepEqual(home.pinsFromStorage(null, ids), home.DEFAULT_PIN_IDS);
  assert.deepEqual(home.pinsFromStorage("[]", ids), []);
  assert.deepEqual(home.favoritesFromStorage(null, ids), []);

  assert.equal(home.legacyToolboxRedirect("", ""), null);
  assert.equal(home.legacyToolboxRedirect("", "#sec-ohm"), "/toolbox/classic/#sec-ohm");
  assert.equal(home.legacyToolboxRedirect("?t=wire-select&voltage=480", "#sec-wire-select"), "/toolbox/classic/?t=wire-select&voltage=480#sec-wire-select");
  assert.equal(home.legacyToolboxRedirect("t=ohm", ""), "/toolbox/classic/?t=ohm");

  assert.equal(registry.TOOL_REGISTRY, home.TOOL_REGISTRY);
  assert.ok(registry.PUBLIC_CALCULATOR_COUNT > 50);
  assert.match(fs.readFileSync(path.join(root, "public/toolbox/sw.js"), "utf8"), /CACHE_VERSION = 'v63'/);
  assert.match(classicHtml, /<base href="\/toolbox\/">/);
  assert.match(classicHtml, /register\('\/toolbox\/sw\.js'/);
  assert.equal(seo.seoForStaticRoute("toolbox")?.title, seo.PAGE_SEO["/toolbox/"].title);
  assert.ok(seo.STATIC_ROUTE_PATHS.includes("toolbox"));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
