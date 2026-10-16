/* Click-worthy tool titles, FAQ schema inputs, and retired URLs that used to 404. */
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const { pathToFileURL } = require("node:url");

const root = path.join(__dirname, "..");

async function main() {
  const seo = await import(pathToFileURL(path.join(root, "src/data/seo-copy.mjs")).href);
  const about = await import(pathToFileURL(path.join(root, "src/data/tool-about-copy.mjs")).href);
  const generator = fs.readFileSync(path.join(root, "scripts/generate-sitemap.mjs"), "utf8");
  const routes = fs.readFileSync(path.join(root, "scripts/generate-static-routes.mjs"), "utf8");

  const demand = ["wire-size-ampacity", "conduit-fill", "transformer-sizing", "photometrics"];
  for (const slug of demand) {
    const title = seo.toolDocumentTitle(slug, slug);
    const description = seo.toolDocumentDescription(slug, "");
    assert.match(title, /calculator|sizing/i, slug);
    assert.ok(description.length > 40 && description.length <= 180, `${slug} description length ${description.length}`);
    assert.match(description, /free/i, slug);
    assert.match(description, /no signup/i, slug);
    const faqs = (about.TOOL_ABOUT_COPY[slug] ?? []).flatMap((section) => section.faqs ?? []);
    assert.ok(faqs.length >= 1, `${slug} faq`);
    assert.ok(faqs.every((item) => item.q && item.a), `${slug} faq text`);
  }
  assert.match(seo.toolDocumentTitle("wire-size-ampacity", ""), /Ampacity calculator/);
  assert.match(seo.toolDocumentTitle("conduit-fill", ""), /Conduit fill calculator/);
  assert.match(seo.toolDocumentTitle("transformer-sizing", ""), /primary fuse and breaker/);
  assert.match(seo.toolDocumentTitle("photometrics", ""), /Photometric calculator/);
  assert.match(seo.TOOL_SEO_DESCRIPTIONS["transformer-sizing"], /450\.3\(B\)/);
  assert.match(seo.TOOL_SEO_DESCRIPTIONS["wire-size-ampacity"], /310\.16/);
  assert.match(seo.TOOL_SEO_DESCRIPTIONS["conduit-fill"], /Chapter 9/);

  assert.match(generator, /FAQPage/);
  assert.match(generator, /toolDocumentDescription/);
  assert.equal(seo.RETIRED_REDIRECTS.length, 9);
  for (const [from, to] of seo.RETIRED_REDIRECTS) {
    assert.ok(seo.STATIC_ROUTE_PATHS.includes(from), from);
    assert.ok(routes.includes("RETIRED_REDIRECTS"), "static routes use the retired list");
    assert.ok(to.startsWith("/"), to);
  }
  const sitemap = fs.readFileSync(path.join(root, "public/sitemap.xml"), "utf8");
  for (const [from] of seo.RETIRED_REDIRECTS) {
    assert.ok(!sitemap.includes(`https://beckify.com/${from}`), `${from} stays out of the sitemap`);
  }

  const intentionalNoindex = [
    ["public/404.html", /noindex/i],
    ["public/demos/lc9-34/index.html", /noindex/i],
    ["public/toolbox/tests/switchgear-tests.html", /noindex/i],
    ["scripts/generate-static-routes.mjs", /noindex,follow/],
  ];
  for (const [file, pattern] of intentionalNoindex) {
    assert.match(fs.readFileSync(path.join(root, file), "utf8"), pattern, file);
  }
  const honda = fs.readFileSync(path.join(root, "src/pages/honda-xr650r.tsx"), "utf8");
  assert.ok(!/robots="noindex/.test(honda), "honda journal stays indexable");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
