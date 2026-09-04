/* Privacy policy page for App Store Connect (https://beckify.com/privacy). */
const fs = require("node:fs");
const path = require("node:path");

const siteRoot = path.join(__dirname, "..");
const repoRoot = path.join(siteRoot, "..", "..");
const privacyMd = fs.readFileSync(path.join(repoRoot, "ios/docs/PRIVACY.md"), "utf8");
const appStoreMd = fs.readFileSync(path.join(repoRoot, "ios/docs/APP_STORE.md"), "utf8");
const privacyPage = fs.readFileSync(path.join(siteRoot, "src/pages/privacy.tsx"), "utf8");
const appSrc = fs.readFileSync(path.join(siteRoot, "src/App.tsx"), "utf8");
const sitemapSrc = fs.readFileSync(path.join(siteRoot, "src/pages/sitemap.tsx"), "utf8");
const footerSrc = fs.readFileSync(path.join(siteRoot, "src/components/sections/Footer.tsx"), "utf8");
const staticRoutes = fs.readFileSync(path.join(siteRoot, "scripts/generate-static-routes.mjs"), "utf8");
const sitemapGen = fs.readFileSync(path.join(siteRoot, "scripts/generate-sitemap.mjs"), "utf8");

let failures = 0;
function ok(name, condition, detail) {
  if (!condition) failures += 1;
  console.log((condition ? "  PASS  " : "  FAIL  ") + name + (detail ? " — " + detail : ""));
}

console.log("\n--- Privacy policy ---");
ok("live policy is not a draft", !/Status:\s*Draft/i.test(privacyMd) && !/not published on https:\/\/beckify.com/i.test(privacyMd));
ok("policy names Trevor Beck and contact email", /Trevor Beck/.test(privacyMd) && /trevorjohnbeck@gmail.com/.test(privacyMd));
ok("policy URL is https://beckify.com/privacy", /https:\/\/beckify.com\/privacy/.test(privacyMd));
ok("nutrition label documents Look Check photo upload", /Analyze Look/.test(privacyMd) && /Photos/.test(privacyMd) && /not used for tracking/.test(privacyMd));
ok("sensors and Saved Jobs stay on device", /Saved Jobs stay on the device/.test(privacyMd));
ok("no analytics, ads, tracking, or accounts", /No analytics/.test(privacyMd) && /No ads/.test(privacyMd) && /no tracking/.test(privacyMd) && /No user accounts/.test(privacyMd));
ok("permissions only when tools are used", /only when the related tool is used/.test(privacyMd));
ok("Wi-Fi uses public 0–1 signalStrength, not dBm", /signalStrength/.test(privacyMd) && /does \*\*not\*\* give third-party apps Wi-Fi RSSI in dBm/.test(privacyMd));
ok("App Store listing URL is https://beckify.com/privacy", /\*\*Privacy Policy URL:\*\* https:\/\/beckify.com\/privacy/.test(appStoreMd));
ok("Apple Developer Program noted as signed up on 2026-09-02", /2026-09-02/.test(appStoreMd) && /Apple Developer Program/.test(appStoreMd));
ok("remaining Mac steps still listed", /Archive in Xcode/.test(appStoreMd) && /Attach screenshots/.test(appStoreMd) && /set \*\*Team\*\*/.test(appStoreMd) && /Create the app record/.test(appStoreMd));
ok("bundle ID, name, devices, price, age stay honest", /com\.beckify\.toolbox/.test(appStoreMd) && /\*\*Name:\*\* Beckify/.test(appStoreMd) && /iPhone and iPad/.test(appStoreMd) && /no in-app purchases, no ads/.test(appStoreMd) && /4\+/.test(appStoreMd));
ok("support and marketing URLs are beckify.com", /\*\*Support URL:\*\* https:\/\/beckify.com/.test(appStoreMd) && /\*\*Marketing URL:\*\* https:\/\/beckify.com/.test(appStoreMd));
ok("React privacy page is a live policy", /Analyze Look/.test(privacyPage) && /com.beckify.toolbox/.test(privacyPage) && !/not published/.test(privacyPage));
ok("React routes cover /privacy and /privacy/", appSrc.includes('path="/privacy"') && appSrc.includes('path="/privacy/"'));
ok("sitemap All pages lists Privacy", /href: "\/privacy", label: "Privacy"/.test(sitemapSrc));
ok("footer links Privacy", footerSrc.includes('href="/privacy"') && footerSrc.includes("Privacy"));
ok("static route generator includes privacy", staticRoutes.includes('["privacy", "Privacy Policy | Beckify iOS"'));
ok("xml sitemap generator includes /privacy", sitemapGen.includes('["/privacy", "monthly", "0.7"]'));
ok("privacy page keeps the remaining game listed", sitemapSrc.includes("New Glenn Runner") && !sitemapSrc.includes("Cosmic Cadet") && !sitemapSrc.includes("Apollo & Rocco Run"));
ok("HexGL stays off the sitemap and routes", !/hexgl/i.test(sitemapSrc) && !appSrc.includes('path="/games/hexgl"') && !/hexgl/i.test(sitemapGen));
ok(
  "website toolbox privacy documents optional VLM upload",
  /Website toolbox photos/.test(privacyPage) &&
    /Enhance with AI/.test(privacyPage) &&
    /does not upload/.test(privacyPage) &&
    /analyze-nameplate/.test(privacyPage) &&
    /analyze-panel/.test(privacyPage) &&
    /analyze-tdr/.test(privacyPage) &&
    /analyze-look/.test(privacyPage) &&
    /OpenAI/.test(privacyPage) &&
    /Anthropic/.test(privacyPage),
);

process.exitCode = failures ? 1 : 0;
