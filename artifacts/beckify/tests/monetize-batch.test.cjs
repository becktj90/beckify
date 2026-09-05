/* Monetize-without-wrecking-quality batch: photos, affiliate tags, counts, Kestrel Heavy route. */
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const vespaSrc = fs.readFileSync(path.join(root, "src/components/VespaPartsCatalog.tsx"), "utf8");
const siteContent = fs.readFileSync(path.join(root, "src/data/site-content.ts"), "utf8");
const siteStats = fs.readFileSync(path.join(root, "src/data/site-stats.ts"), "utf8");
const homeSrc = fs.readFileSync(path.join(root, "src/pages/home.tsx"), "utf8");
const sitemapSrc = fs.readFileSync(path.join(root, "src/pages/sitemap.tsx"), "utf8");
const footerSrc = fs.readFileSync(path.join(root, "src/components/sections/Footer.tsx"), "utf8");
const houseAds = fs.readFileSync(path.join(root, "src/components/ads/MinimalAdUnit.tsx"), "utf8");
const sitemapGen = fs.readFileSync(path.join(root, "scripts/generate-sitemap.mjs"), "utf8");
const staticRoutes = fs.readFileSync(path.join(root, "scripts/generate-static-routes.mjs"), "utf8");
const toolboxHtml = fs.readFileSync(path.join(root, "public/toolbox/index.html"), "utf8");
const arcadeHtml = fs.readFileSync(path.join(root, "public/arcade/kestrel-heavy/index.html"), "utf8");
const appSrc = fs.readFileSync(path.join(root, "src/App.tsx"), "utf8");

let failures = 0;
function ok(name, condition, detail) {
  if (!condition) failures += 1;
  console.log((condition ? "  PASS  " : "  FAIL  ") + name + (detail ? " — " + detail : ""));
}

console.log("\n--- Removed product catalogs ---");
const catalogPath = /(?:["'`])\/(?:gear|made-in-america)(?:["'`/])/;
const publicSurface = [homeSrc, siteContent, sitemapSrc, footerSrc, houseAds].join("\n");
ok("removed /gear and /made-in-america from public links", !catalogPath.test(publicSurface));
ok("removed catalog routes from the React router", !/path=["']\/(?:gear|made-in-america)["']/.test(appSrc) && !/pages\/(?:gear|made-in-america)/.test(appSrc));
ok("removed catalog URLs from the XML sitemap generator", !catalogPath.test(sitemapGen));
const publicSitemap = fs.readFileSync(path.join(root, "public/sitemap.xml"), "utf8");
ok(
  "removed catalog URLs from the published sitemap.xml",
  !/beckify\.com\/(?:gear|made-in-america)(?:\/|<|\?|#|$)/.test(publicSitemap),
);
ok("removed catalog paths from static route shells", !/\["(?:gear|made-in-america)"/.test(staticRoutes));
ok("catalog page modules are gone", !fs.existsSync(path.join(root, "src/pages/gear.tsx")) && !fs.existsSync(path.join(root, "src/pages/made-in-america.tsx")));
ok("lookbook data and GearCard are gone", !fs.existsSync(path.join(root, "src/data/gear-recommendations.ts")) && !fs.existsSync(path.join(root, "src/components/gear/GearCard.tsx")));

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
const { PUBLIC_CALCULATOR_COUNT } = require(path.join(root, "src/data/toolbox-tools.mjs"));
const navTargets = [...toolboxHtml.matchAll(/<button class="nav-btn"[^>]*data-target="([^"]+)"/g)].map((m) => m[1]);
const excludedNav = new Set([
  "sec-wire-ref", "sec-conduit-ref", "sec-conduit-guide",
  "sec-ip-rating", "sec-nema-class", "sec-nema-wiring", "sec-wire-colors", "sec-nec-tables", "sec-projects",
]);
const liveCalculatorCount = new Set(navTargets.filter((id) => !excludedNav.has(id))).size;
ok("calculator count is derived from toolbox-tools", /from "\.\/toolbox-tools\.mjs"/.test(siteStats));
ok("game count constant is 1", /PUBLIC_GAME_COUNT = 1/.test(siteStats));
ok("calculator count matches live toolbox nav", PUBLIC_CALCULATOR_COUNT === liveCalculatorCount, `${PUBLIC_CALCULATOR_COUNT} vs nav ${liveCalculatorCount}`);
ok("home toolbox copy uses the calculator constant", homeSrc.includes("PUBLIC_CALCULATOR_COUNT") && homeSrc.includes("calculators"));
ok("home names EMP/EMC, homework EE, LP, and number-base", /EMP\/EMC/.test(homeSrc) && /homework EE/.test(homeSrc) && /linear-programming optimizer/.test(homeSrc) && /number-base converter/.test(homeSrc));
ok("home deep-links EMP, homework EE, LP, and number-base", [
  "/toolbox/#sec-emp-emc",
  "/toolbox/#sec-magnetic-circuit",
  "/toolbox/#sec-transient-circuits",
  "/toolbox/#sec-phasor-diagram",
  "/toolbox/#sec-semiconductor-iv",
  "/toolbox/#sec-fiber-link",
  "/toolbox/#sec-gaussian-beam",
  "/toolbox/#sec-lp-optimizer",
  "/toolbox/#sec-base-converter",
  "/toolbox/#sec-pitch-hum",
  "/toolbox/#sec-audio-spectrum",
  "/toolbox/#sec-sound-level",
  "/toolbox/#sec-lux-meter",
].every((href) => homeSrc.includes(`href: "${href}"`)));
ok("sitemap chips deep-link via /toolbox/#", sitemapSrc.includes("href={`/toolbox/#${tool.anchor}`}"));
ok("home games copy uses the game constant", homeSrc.includes("PUBLIC_GAME_COUNT") && homeSrc.includes("browser game"));
ok("toolbox header uses the shared calculator count", toolboxHtml.includes(`${PUBLIC_CALCULATOR_COUNT} calculators plus reference tables`));
ok("sitemap uses PUBLIC_CALCULATOR_COUNT", sitemapSrc.includes("PUBLIC_CALCULATOR_COUNT"));
ok("sitemap games line includes Kestrel Heavy", sitemapSrc.includes("Kestrel Heavy") && !sitemapSrc.includes("Toot Troopers"));
ok("sitemap lists EMP/EMC with a working hash link", sitemapSrc.includes('t("EMP / EMC Shielding", "sec-emp-emc")'));
ok("sitemap lists LP optimizer with a working hash link", sitemapSrc.includes('t("Linear Programming Optimizer", "sec-lp-optimizer")'));
ok("sitemap lists phone sensor field tools", [
  't("Pitch / Hum Identifier", "sec-pitch-hum")',
  't("FFT / Audio Spectrum", "sec-audio-spectrum")',
  't("Sound Level Meter", "sec-sound-level")',
  't("Lux / Light Meter", "sec-lux-meter")',
].every((entry) => sitemapSrc.includes(entry)));
ok("sitemap lists cable schedule with a working hash link", sitemapSrc.includes('t("Cable Schedule Generator", "sec-cable-schedule")'));
ok("sitemap lists battery bank with a working hash link", sitemapSrc.includes('t("Battery Bank Calculator", "sec-battery-bank")'));
ok("sitemap lists Battery Pack Designer in the e-bike group", sitemapSrc.includes('t("Battery Pack Designer", "sec-ebike-tools")'));
ok("sitemap lists motor nameplate with a working hash link", sitemapSrc.includes('t("Motor Nameplate Analyzer", "sec-motor-nameplate")'));
ok("sitemap lists Look Check with a working hash link", sitemapSrc.includes('t("Look Check", "sec-look-check")'));
ok("sitemap lists NEMA wiring with a working hash link", sitemapSrc.includes('t("NEMA Wiring & Color Codes", "sec-nema-wiring")'));
ok("sitemap lists the homework EE set", [
  't("Magnetic Circuit Workbench", "sec-magnetic-circuit")',
  't("Phasor Diagram Workbench", "sec-phasor-diagram")',
  't("Transient Circuit Lab", "sec-transient-circuits")',
  't("Semiconductor Device I-V", "sec-semiconductor-iv")',
  't("Fiber Link / NA", "sec-fiber-link")',
  't("Gaussian Beam", "sec-gaussian-beam")',
].every((entry) => sitemapSrc.includes(entry)));
const gameNames = [...siteContent.matchAll(/name: "([^"]+)"/g)].map((m) => m[1]).filter((name) => ["Kestrel Heavy"].includes(name));
ok("site-content lists 1 game", gameNames.length === 1, gameNames.join(", "));
ok("removed titles are not listed", !["Cosmic Cadet", "Booty Butt Scooter", "Finger Runner", "Toot Troopers", "Apollo & Rocco Run", "Pup Planet"].some((name) => siteContent.includes(`name: "${name}"`)));
ok("HexGL is not listed", !/name: "HexGL"/.test(siteContent));

console.log("\n--- Kestrel Heavy route ---");
ok("hub Play Now points at /games/kestrel-heavy", /name: "Kestrel Heavy"[\s\S]{0,400}url: "\/games\/kestrel-heavy"/.test(siteContent));
ok("React route exists", appSrc.includes('path="/games/kestrel-heavy"'));
ok("standalone arcade page exists", arcadeHtml.includes("ng-phaser-root") && arcadeHtml.includes("data-arcade-standalone"));
ok("standalone page keeps difficulty copy", arcadeHtml.includes("KID / CADET / PAD RAT"));
ok("toolbox no longer embeds the full arcade canvas", !/id="arcadeCanvas"/.test(toolboxHtml));
ok("toolbox keeps a games-page link", toolboxHtml.includes("/games/kestrel-heavy/"));
ok("toolbox no longer loads arcade.js", !/src="js\/arcade\.js"/.test(toolboxHtml));

console.log("\n--- E-bike Battery Pack Designer ---");
ok("e-bike home category lists Battery Pack Designer", /E-Bike Build[\s\S]{0,600}Battery Pack Designer/.test(toolboxHtml));
ok("e-bike section has a Battery Pack Designer canvas", /id="eb-battery-designer"/.test(toolboxHtml) && /id="ebd_canvas"/.test(toolboxHtml));
ok("pack designer includes a 3D inspect canvas", /id="ebd_canvas_3d"/.test(toolboxHtml) && /id="ebd_view_3d"/.test(toolboxHtml));
ok("toolbox loads the pack designer script", /src="js\/ebike-battery-designer\.js"/.test(toolboxHtml));
ok("no external batterydesigner.com launch CTA", !/href="https:\/\/batterydesigner\.com"/.test(toolboxHtml));
ok("home chip deep-links e-bike tools", homeSrc.includes('href: "/toolbox/#sec-ebike-tools"'));

process.exitCode = failures ? 1 : 0;
