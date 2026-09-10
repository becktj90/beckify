/* Unique titles, JSON-LD helpers, featured crawl paths, trailing-slash sitemap. */
const fs = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { execFileSync } = require("node:child_process");

const root = path.join(__dirname, "..");

let failures = 0;
function ok(name, condition, detail) {
  if (!condition) failures += 1;
  console.log((condition ? "  PASS  " : "  FAIL  ") + name + (detail ? " — " + detail : ""));
}

async function main() {
  const seo = await import(pathToFileURL(path.join(root, "src/data/seo-copy.mjs")).href);

  console.log("\n--- Unique hub titles ---");
  const hubTitles = Object.entries(seo.PAGE_SEO).map(([route, copy]) => [route, copy.title]);
  const titleSet = new Set(hubTitles.map(([, title]) => title));
  ok("every hub title is unique", titleSet.size === hubTitles.length, `${titleSet.size}/${hubTitles.length}`);
  ok(
    "hub titles are not a cloned '| Beckify' template",
    hubTitles.every(([, title]) => !title.endsWith("| Beckify")),
  );
  ok("home title names calculators and builds", /calculator/i.test(seo.PAGE_SEO["/"].title) && /build/i.test(seo.PAGE_SEO["/"].title));
  ok("toolbox title names Ohm's Law and voltage drop", /Ohm's Law/i.test(seo.PAGE_SEO["/toolbox/"].title) && /voltage drop/i.test(seo.PAGE_SEO["/toolbox/"].title));
  ok("privacy copy keeps Look Check and bundle ID", /Look Check/.test(seo.PAGE_SEO["/privacy"].description) && /com\.beckify\.toolbox/.test(seo.PAGE_SEO["/privacy"].description));
  ok("privacy copy does not invent analytics", /No analytics/.test(seo.PAGE_SEO["/privacy"].description));

  console.log("\n--- Featured tool titles ---");
  const featuredTitles = seo.FEATURED_TOOLS.map((tool) => seo.toolDocumentTitle(tool.slug, tool.label));
  ok("featured titles are unique", new Set(featuredTitles).size === featuredTitles.length);
  ok(
    "featured titles are not '| Beckify' clones",
    featuredTitles.every((title) => !title.includes("| Beckify") && !title.startsWith("Beckify —")),
  );
  ok("Ohm's Law title mentions V/I/R or power", /voltage|current|resistance|power/i.test(seo.toolDocumentTitle("ohms-law", "Ohm's Law")));
  ok("ampacity title cites 310.16", /310\.16/.test(seo.toolDocumentTitle("wire-size-ampacity", "ampacity")));

  console.log("\n--- JSON-LD helpers ---");
  const schemaHead = fs.readFileSync(path.join(root, "src/components/seo/SchemaHead.tsx"), "utf8");
  ok("SchemaHead exports Organization + WebSite helpers", schemaHead.includes("export const organizationSchema") && schemaHead.includes("export const websiteSchema"));
  ok("SchemaHead exports VideoGame + TechArticle + BreadcrumbList", schemaHead.includes("videoGameSchema") && schemaHead.includes("techArticleSchema") && schemaHead.includes("breadcrumbListSchema"));
  const indexHtml = fs.readFileSync(path.join(root, "index.html"), "utf8");
  ok("home HTML has Organization and WebSite JSON-LD", indexHtml.includes('"@type": "Organization"') && indexHtml.includes('"@type": "WebSite"'));
  const toolboxHtml = fs.readFileSync(path.join(root, "public/toolbox/index.html"), "utf8");
  ok("toolbox hub keeps SoftwareApplication / WebApplication", toolboxHtml.includes("SoftwareApplication") && toolboxHtml.includes("WebApplication"));
  ok("toolbox hub publisher URL is trailing-slash canonical", toolboxHtml.includes('"url": "https://beckify.com/"'));
  const vespa = fs.readFileSync(path.join(root, "src/pages/vespa-p200e.tsx"), "utf8");
  ok("Vespa uses TechArticle and HowTo with real steps", vespa.includes("techArticleSchema") && vespa.includes('"@type": "HowTo"') && vespa.includes("#battery"));
  ok("Vespa HowTo is not an empty type-only blob", vespa.includes("HowToStep") && vespa.includes("20S10P"));
  const projects = fs.readFileSync(path.join(root, "src/pages/projects.tsx"), "utf8");
  ok("projects hub is CollectionPage, not a fake HowTo", projects.includes("CollectionPage") && !projects.includes("HowTo"));
  const kestrel = fs.readFileSync(path.join(root, "src/pages/kestrel-heavy.tsx"), "utf8");
  ok("Kestrel Heavy declares VideoGame schema", kestrel.includes("videoGameSchema"));

  console.log("\n--- Internal crawl paths ---");
  const home = fs.readFileSync(path.join(root, "src/pages/home.tsx"), "utf8");
  ok(
    "home featured chips use canonical tool permalinks",
    home.includes("homeToolboxLinks") && home.includes("toolboxPermalink") && seo.homeToolboxLinks().every((tool) => tool.slug && tool.label),
  );
  ok(
    "home toolbox links include every featured slug",
    seo.FEATURED_TOOLS.every((tool) => seo.homeToolboxLinks().some((link) => link.slug === tool.slug && seo.toolboxPermalink(tool.slug).startsWith(`/toolbox/${tool.slug}/`))),
  );
  ok(
    "featured permalinks keep a section hash for offline SW fallback",
    seo.FEATURED_TOOLS.every((tool) => /#sec-/.test(seo.toolboxPermalink(tool.slug))),
  );
  ok("toolbox hub has a featured row", toolboxHtml.includes("home-featured") && toolboxHtml.includes("/toolbox/ohms-law/"));
  ok("toolbox hub featured Ohm's Law keeps its section hash", toolboxHtml.includes("/toolbox/ohms-law/#sec-ohm"));
  const appJs = fs.readFileSync(path.join(root, "public/toolbox/js/app.js"), "utf8");
  ok("toolbox router reads permalink slugs when hash is missing", appJs.includes("getPathnameSectionId") && appJs.includes("BECKIFY_TOOL_PERMALINKS"));
  ok("Vespa links related calculators", vespa.includes("VESPA_RELATED_TOOLS") && vespa.includes("toolboxPermalink"));
  ok("noindex is not applied to toolbox tools", !toolboxHtml.includes("noindex") && !fs.readFileSync(path.join(root, "scripts/generate-sitemap.mjs"), "utf8").includes("noindex"));

  console.log("\n--- Sitemap still trailing-slash only ---");
  execFileSync(process.execPath, [path.join(root, "scripts/generate-sitemap.mjs")], { cwd: root });
  const permalinkMap = fs.readFileSync(path.join(root, "public/toolbox/js/permalink-map.js"), "utf8");
  ok(
    "permalink map covers featured slugs",
    seo.FEATURED_TOOLS.every((tool) => permalinkMap.includes(`"${tool.slug}"`)),
  );
  const xml = fs.readFileSync(path.join(root, "public/sitemap.xml"), "utf8");
  const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1]);
  ok("every loc ends with /", locs.every((loc) => loc.endsWith("/")));
  ok("featured tool URLs are sitemapped", seo.FEATURED_TOOLS.every((tool) => locs.includes(`https://beckify.com/toolbox/${tool.slug}/`)));
  ok("robots still allows all and points at the sitemap", (() => {
    const robots = fs.readFileSync(path.join(root, "public/robots.txt"), "utf8");
    return /Allow: \//.test(robots) && robots.includes("https://beckify.com/sitemap.xml") && !/Disallow:/i.test(robots);
  })());

  const generator = fs.readFileSync(path.join(root, "scripts/generate-sitemap.mjs"), "utf8");
  ok("generated tool pages use unique document titles", generator.includes("toolDocumentTitle") && !generator.includes("${title} | Beckify"));

  process.exitCode = failures ? 1 : 0;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
