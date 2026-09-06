/* Sitemap and canonical URLs must match GitHub Pages trailing-slash directories. */
const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

const root = path.join(__dirname, "..");

let failures = 0;
function ok(name, condition, detail) {
  if (!condition) failures += 1;
  console.log((condition ? "  PASS  " : "  FAIL  ") + name + (detail ? " — " + detail : ""));
}

async function main() {
  const { toCanonicalPath, toCanonicalUrl } = await import(pathToFileURL(path.join(root, "src/lib/canonical-url.mjs")).href);

  console.log("\n--- Canonical helper ---");
  ok("root path stays /", toCanonicalPath("/") === "/");
  ok("root URL is https://beckify.com/", toCanonicalUrl("/") === "https://beckify.com/");
  ok("about gains a trailing slash", toCanonicalPath("/about") === "/about/");
  ok("already-slashed toolbox is unchanged", toCanonicalPath("/toolbox/") === "/toolbox/");
  ok("file-like paths stay unsuffixed", toCanonicalPath("/sitemap.xml") === "/sitemap.xml");
  ok("absolute tool URL is slashed", toCanonicalUrl("/toolbox/ohms-law") === "https://beckify.com/toolbox/ohms-law/");

  execFileSync(process.execPath, [path.join(root, "scripts/generate-sitemap.mjs")], { cwd: root });
  const xml = fs.readFileSync(path.join(root, "public/sitemap.xml"), "utf8");
  const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1]);
  const unique = new Set(locs);

  console.log("\n--- Generated sitemap.xml ---");
  ok("sitemap has loc entries", locs.length > 10, String(locs.length));
  ok("homepage is https://beckify.com/", locs.includes("https://beckify.com/"));
  ok("every loc ends with /", locs.every((loc) => loc.endsWith("/")), locs.filter((loc) => !loc.endsWith("/")).join(", "));
  ok("no duplicate loc values", unique.size === locs.length);
  ok(
    "no slash / no-slash pairs",
    locs.every((loc) => loc === "https://beckify.com/" || !unique.has(loc.replace(/\/$/, ""))),
  );
  ok("privacy uses trailing slash", locs.includes("https://beckify.com/privacy/"));
  ok("kestrel-heavy uses trailing slash", locs.includes("https://beckify.com/games/kestrel-heavy/"));
  ok("legacy new-glenn-runner is not sitemapped", !/new-glenn/i.test(xml));
  ok("no-slash /about is not listed", !locs.includes("https://beckify.com/about"));

  const staticRoutes = fs.readFileSync(path.join(root, "scripts/generate-static-routes.mjs"), "utf8");
  console.log("\n--- Static route canonicals ---");
  ok("static route shells use toCanonicalUrl", staticRoutes.includes("toCanonicalUrl(`/${route}`)"));
  ok("new-glenn-runner stays a static directory", staticRoutes.includes('["games/new-glenn-runner"'));
  ok("new-glenn-runner redirects to kestrel-heavy/", staticRoutes.includes('["games/new-glenn-runner", "/games/kestrel-heavy/"]'));

  const schemaHead = fs.readFileSync(path.join(root, "src/components/seo/SchemaHead.tsx"), "utf8");
  ok("SchemaHead canonicals go through toCanonicalUrl", schemaHead.includes("const canonicalUrl = toCanonicalUrl(path);"));

  const arcade = fs.readFileSync(path.join(root, "public/arcade/index.html"), "utf8");
  ok("arcade stub canonical is slashed", arcade.includes('href="https://beckify.com/games/kestrel-heavy/"'));

  process.exitCode = failures ? 1 : 0;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
