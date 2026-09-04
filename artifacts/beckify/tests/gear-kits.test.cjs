/* Kit curation must resolve to real catalog SKUs, stay de-duplicated
   inside a kit, and keep comfort gear out of the featured chapters. */
const fs = require("node:fs");
const path = require("node:path");
const ts = require("typescript");
const { test } = require("node:test");
const assert = require("node:assert/strict");

const sourcePath = path.join(__dirname, "..", "src", "data", "gear-recommendations.ts");
const source = fs.readFileSync(sourcePath, "utf8");
const { outputText } = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
});
const mod = { exports: {} };
const compiled = new Function("exports", "module", outputText);
compiled(mod.exports, mod);

const {
  GEAR_RECOMMENDATIONS,
  GEAR_KITS,
  JOBSITE_SUPPORT_NAMES,
  CATALOG_LEADS,
  findGear,
  kitEntries,
} = mod.exports;

const COMFORT_ONLY = ["TORRAS COOLiFY 2S", "BougeRV 23 Quart Portable Fridge"];

test("every catalog item has a working Amazon affiliate URL", () => {
  for (const item of GEAR_RECOMMENDATIONS) {
    assert.match(item.amazonUrl, /amazon\.com\/dp\/.+tag=beckify-20/);
  }
});

test("kits resolve to catalog SKUs and stay unique inside a chapter", () => {
  assert.equal(GEAR_KITS.length, 4);
  for (const kit of GEAR_KITS) {
    const names = kit.slots.map((slot) => slot.name);
    assert.equal(new Set(names).size, names.length, `${kit.id} has duplicate SKUs`);
    const budgetRoles = kit.slots.filter((slot) => slot.budget).map((slot) => slot.role);
    assert.ok(budgetRoles.length <= kit.slots.length);
    for (const slot of kit.slots) {
      assert.equal(findGear(slot.name).name, slot.name);
    }
    assert.ok(kitEntries(kit).length >= 3);
    assert.ok(kitEntries(kit).length <= 6);
  }
});

test("comfort gadgets stay out of featured kits", () => {
  const featured = new Set(GEAR_KITS.flatMap((kit) => kit.slots.map((slot) => slot.name)));
  for (const name of COMFORT_ONLY) {
    assert.ok(GEAR_RECOMMENDATIONS.some((item) => item.name === name), `${name} remains in the catalog`);
    assert.ok(!featured.has(name), `${name} must not lead a kit`);
  }
});

test("jobsite support strip is a short optional appendix", () => {
  assert.ok(JOBSITE_SUPPORT_NAMES.length >= 2 && JOBSITE_SUPPORT_NAMES.length <= 3);
  for (const name of JOBSITE_SUPPORT_NAMES) {
    assert.equal(findGear(name).category, "Job comfort and power");
  }
});

test("catalog leads exist in their section", () => {
  for (const [category, name] of Object.entries(CATALOG_LEADS)) {
    assert.equal(findGear(name).category, category);
  }
});
