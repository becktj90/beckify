// Conduit cross-section geometry + the same-size calculator's extended wire range.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const dir = path.join(__dirname, "..", "public", "toolbox", "js");
const sandbox = { console, window: {}, document: { addEventListener() {}, getElementById: () => null } };
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const f of ["nec-data.js", "conduit-viz.js"]) {
  vm.runInContext(fs.readFileSync(path.join(dir, f), "utf8"), sandbox, { filename: f });
}
const viz = sandbox.ConduitViz;

let failures = 0;
function ok(name, cond, extra) {
  if (cond) console.log("  PASS ", name);
  else { failures++; console.log("  FAIL ", name, extra || ""); }
}

// Bore area derived from the ID must agree with Table 4 areas in nec-data.js.
const types = vm.runInContext("CONDUIT_TYPES", sandbox);
let worst = 0;
for (const [type, def] of Object.entries(types)) {
  for (const [trade, area] of Object.entries(def.areas)) {
    const b = viz.bore(type, trade);
    if (!b) { ok(`bore ${type} ${trade}`, false, "missing"); continue; }
    const derived = Math.PI * (b.id / 2) ** 2;
    worst = Math.max(worst, Math.abs(derived - area) / area);
  }
}
ok("bore IDs agree with Table 4 areas within 0.5%", worst < 0.005, `worst ${(worst * 100).toFixed(3)}%`);

// 3 x 1000 kcmil THHN fits a 4 in RMC without overlap; 1000 kcmil metal diameter is 1.000 in.
ok("1000 kcmil metal diameter is 1 in", Math.abs(viz.metalDiameter("1000") - 1) < 1e-9);
const ins = vm.runInContext("INSULATION_TYPES", sandbox);
const r = viz.overallDiameter(ins.THHN.areas["1000"]) / 2;
const packed = viz.pack([r, r, r], viz.bore("RMC", "4").id / 2);
ok("3 x 1000 kcmil in 4 in RMC packs without overlap", packed.every((d) => !d.overlaps));
// 40% fill of a 2 in EMT with 4 x 12 AWG packs without overlap
const r12 = viz.overallDiameter(ins.THHN.areas["12"]) / 2;
ok("4 x 12 AWG in 3/4 EMT packs without overlap", viz.pack([r12, r12, r12, r12], viz.bore("EMT", "3/4").id / 2).every((d) => !d.overlaps));
// A bundle that cannot fit is flagged
const big = viz.overallDiameter(ins.THHN.areas["1000"]) / 2;
ok("oversized bundle is flagged as overlapping", viz.pack([big, big, big, big], viz.bore("EMT", "1")?.id / 2).some((d) => d.overlaps));

// Every Table 5 size through 1000 kcmil is selectable in the same-size card.
const html = fs.readFileSync(path.join(dir, "..", "classic", "index.html"), "utf8");
const awgSelect = html.match(/<select id="cf_awg">([\s\S]*?)<\/select>/)[1];
for (const size of Object.keys(ins.THHN.areas)) {
  if (!awgSelect.includes(`value="${size}"`)) ok(`cf_awg has ${size}`, false);
}
ok("same-size card reaches 1000 kcmil", awgSelect.includes('value="1000"'));
ok("conduit-viz.js is precached", /conduit-viz\.js/.test(fs.readFileSync(path.join(dir, "..", "sw.js"), "utf8")));

// The same-size drawing sits at the top of its card, above the inputs, and the
// guide card no longer pushes the calculator down the page.
const cardHtml = html.slice(html.indexOf('id="sec-conduit"'));
ok("cf_viz host precedes the same-size inputs", cardHtml.indexOf('id="cf_viz"') > 0 && cardHtml.indexOf('id="cf_viz"') < cardHtml.indexOf('id="cf_type"'));
const mx = fs.readFileSync(path.join(dir, "math-explanations.js"), "utf8");
ok("conduit guide renders after the calculator grid", /sec-conduit-adv'\)[\s\S]{0,120}\.card-grid/.test(mx));

// Drawing renders for the largest sizes and the packing cap keeps huge counts fast.
const drawSrc = fs.readFileSync(path.join(dir, "conduit-viz.js"), "utf8");
ok("draw() caps packing for very many conductors", /MAX_DRAWN\s*=\s*200/.test(drawSrc) && /tooMany/.test(drawSrc));
ok("draw() lays out the iOS status row, fill bar and callout tiles", /Free area/.test(drawSrc) && /Wire OD/.test(drawSrc) && /PASS/.test(drawSrc));
for (const [type, def] of Object.entries(types)) {
  for (const trade of Object.keys(def.areas)) {
    const b = viz.bore(type, trade);
    if (!b || !(b.id > 0)) ok(`bore ${type} ${trade} has a positive ID`, false);
  }
}
ok("PVC80 6 in and RMC 6 in have a bore", viz.bore("PVC80", "6") && viz.bore("RMC", "6"));
const t0 = Date.now();
viz.pack(Array(200).fill(viz.overallDiameter(ins.THHN.areas["14"]) / 2), viz.bore("PVC40", "6").id / 2);
ok("200 conductors pack quickly (< 5 s)", Date.now() - t0 < 5000, `${Date.now() - t0} ms`);
const sitemapGen = fs.readFileSync(path.join(dir, "..", "..", "..", "scripts", "generate-sitemap.mjs"), "utf8");
ok("tool landing pages put the calculator frame above the about panel", sitemapGen.indexOf('class="intro"') < sitemapGen.indexOf("<iframe") && sitemapGen.indexOf("<iframe") < sitemapGen.indexOf('class="panel"'));

if (failures) { console.log(`\n${failures} failure(s)`); process.exit(1); }
console.log("\nAll conduit viz checks passed");
