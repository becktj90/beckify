/* Monetize-without-wrecking-quality batch: photos, affiliate tags, counts, New Glenn route. */
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const gearSrc = fs.readFileSync(path.join(root, "src/data/gear-recommendations.ts"), "utf8");
const gearMatrix = fs.readFileSync(path.join(root, "src/components/GearMatrix.tsx"), "utf8");
const gearCard = fs.readFileSync(path.join(root, "src/components/gear/GearCard.tsx"), "utf8");
const vespaSrc = fs.readFileSync(path.join(root, "src/components/VespaPartsCatalog.tsx"), "utf8");
const siteContent = fs.readFileSync(path.join(root, "src/data/site-content.ts"), "utf8");
const siteStats = fs.readFileSync(path.join(root, "src/data/site-stats.ts"), "utf8");
const homeSrc = fs.readFileSync(path.join(root, "src/pages/home.tsx"), "utf8");
const sitemapSrc = fs.readFileSync(path.join(root, "src/pages/sitemap.tsx"), "utf8");
const toolboxHtml = fs.readFileSync(path.join(root, "public/toolbox/index.html"), "utf8");
const arcadeHtml = fs.readFileSync(path.join(root, "public/arcade/new-glenn-runner/index.html"), "utf8");
const appSrc = fs.readFileSync(path.join(root, "src/App.tsx"), "utf8");

let failures = 0;
function ok(name, condition, detail) {
  if (!condition) failures += 1;
  console.log((condition ? "  PASS  " : "  FAIL  ") + name + (detail ? " — " + detail : ""));
}

console.log("\n--- Gear photos ---");
const imageUrls = [...gearSrc.matchAll(/imageUrl:\s*"([^"]+)"/g)].map((m) => m[1]);
ok("every gear card has an imageUrl", imageUrls.length >= 35, String(imageUrls.length));
ok("gear images are same-origin", imageUrls.every((url) => url.startsWith("/images/gear/")), imageUrls.filter((u) => !u.startsWith("/images/gear/")).join(", "));
ok("no third-party hotlinks remain in gear data", !/imageUrl:\s*"https?:\/\//.test(gearSrc));
const missingFiles = imageUrls.filter((url) => !fs.existsSync(path.join(root, "public", url)));
ok("every gear image file exists", missingFiles.length === 0, missingFiles.join(", "));
ok("affiliate disclosure appears before featured USA-made cards", gearMatrix.indexOf("As an Amazon Associate") < gearMatrix.indexOf("American-made gear worth prioritizing"));
ok("amazon affiliate tag kept", /tag=beckify-20/.test(gearSrc));
ok("amazon buttons stay rel=sponsored", /rel="sponsored noopener noreferrer"/.test(gearCard));

console.log("\n--- Vespa BOM ---");
const amazonHrefs = [...vespaSrc.matchAll(/href:\s*"(https:\/\/www\.amazon\.com[^"]+)"/g)].map((m) => m[1]);
ok("vespa has Amazon product links", amazonHrefs.length >= 20, String(amazonHrefs.length));
ok("every Amazon URL uses tag=beckify-20", amazonHrefs.every((url) => url.includes("tag=beckify-20")));
ok("Amazon URLs are clean /dp/ paths", amazonHrefs.every((url) => /amazon\.com\/dp\/[A-Z0-9]{10}\?tag=beckify-20$/.test(url)), amazonHrefs.filter((u) => !/amazon\.com\/dp\/[A-Z0-9]{10}\?tag=beckify-20$/.test(u)).join("\n"));
ok("order-history ref params removed", !/ppx_od|ppx_yo|gp\/product/.test(vespaSrc));
ok("BOM disclosure sits above the parts table", vespaSrc.indexOf("As an Amazon Associate") < vespaSrc.indexOf("Bill of materials table"));
ok("Amazon table links keep rel=sponsored", vespaSrc.includes('part.href.includes("amazon.com") ? "sponsored noopener noreferrer"'));
ok("QS motor row is linked", vespaSrc.includes("qs-motor.com/product/10inch-4000w-v3-type-e-scooter-hub-motor"));
ok("VOTOL controller row is linked", vespaSrc.includes("qsmotor.com/product/votol-controller-em-100"));
ok("Daly BMS row is linked to manufacturer", vespaSrc.includes("dalybms.com"));
ok("eBay-only rows stay Not linked rather than guessed ASINs", vespaSrc.includes("25mm three-wire twist throttle") && vespaSrc.includes("LED headlight") && !/name: "25mm three-wire twist throttle"[\s\S]{0,180}href:/.test(vespaSrc));

console.log("\n--- Counts ---");
ok("calculator count constant is 47", /PUBLIC_CALCULATOR_COUNT = 47/.test(siteStats));
ok("game count constant is 7", /PUBLIC_GAME_COUNT = 7/.test(siteStats));
ok("home toolbox copy uses the calculator constant", homeSrc.includes("PUBLIC_CALCULATOR_COUNT") && homeSrc.includes("calculators"));
ok("home games copy uses the game constant", homeSrc.includes("PUBLIC_GAME_COUNT") && homeSrc.includes("browser games"));
ok("toolbox header uses 47", toolboxHtml.includes("47 calculators plus reference tables"));
ok("sitemap uses PUBLIC_CALCULATOR_COUNT", sitemapSrc.includes("PUBLIC_CALCULATOR_COUNT"));
ok("sitemap games line includes Toot Troopers", sitemapSrc.includes("Toot Troopers"));
const gameNames = [...siteContent.matchAll(/name: "([^"]+)"/g)].map((m) => m[1]).filter((name) => ["Cosmic Cadet", "Booty Butt Scooter", "New Glenn Runner", "Finger Runner", "Toot Troopers", "Pup Planet", "HexGL"].includes(name));
ok("site-content lists 7 games", gameNames.length === 7, gameNames.join(", "));

console.log("\n--- New Glenn route ---");
ok("hub Play Now points at /games/new-glenn-runner", /name: "New Glenn Runner"[\s\S]{0,400}url: "\/games\/new-glenn-runner"/.test(siteContent));
ok("React route exists", appSrc.includes('path="/games/new-glenn-runner"'));
ok("standalone arcade page exists", arcadeHtml.includes("arcadeCanvas") && arcadeHtml.includes("data-arcade-standalone"));
ok("standalone page keeps difficulty copy", arcadeHtml.includes("KID / CADET / PAD RAT"));
ok("toolbox no longer embeds the full arcade canvas", !/id="arcadeCanvas"/.test(toolboxHtml));
ok("toolbox keeps a games-page link", toolboxHtml.includes("/games/new-glenn-runner/"));
ok("toolbox no longer loads arcade.js", !/src="js\/arcade\.js"/.test(toolboxHtml));

process.exitCode = failures ? 1 : 0;
