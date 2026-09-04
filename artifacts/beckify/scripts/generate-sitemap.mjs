import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { TOOLS as tools, CATEGORIES as categories, TOOL_ALIASES as aliases } from "../src/data/toolbox-tools.mjs";

const root = resolve(import.meta.dirname, "..");
const siteUrl = "https://beckify.com";

const escapeXml = (value) => value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&apos;");
const page = ({ title, description, path, toolPath, eyebrow = "Beckify Electrical Engineering Toolbox", showAds = true, kind = "tool" }) => {
  const canonicalUrl = `${siteUrl}${path}`;
  const schema = [
    {
      "@context": "https://schema.org",
      "@type": kind === "tool" ? ["SoftwareApplication", "WebApplication"] : "CollectionPage",
      name: title,
      description,
      url: canonicalUrl,
      ...(kind === "tool" ? {
        operatingSystem: "All",
        applicationCategory: "EngineeringApplication",
        isAccessibleForFree: true,
      } : {}),
      publisher: { "@type": "Organization", name: "Beckify", url: siteUrl },
    },
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "Beckify", item: siteUrl },
        { "@type": "ListItem", position: 2, name: "Toolbox", item: `${siteUrl}/toolbox/` },
        { "@type": "ListItem", position: 3, name: title, item: canonicalUrl },
      ],
    },
  ];
  const subject = kind === "tool" ? "calculator" : "tool collection";
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="strict-origin-when-cross-origin">
<title>${escapeXml(`${title} | Beckify`)}</title><meta name="description" content="${escapeXml(description)}"><meta name="robots" content="index,follow">
<link rel="canonical" href="${canonicalUrl}"><meta property="og:title" content="${escapeXml(`${title} | Beckify`)}"><meta property="og:description" content="${escapeXml(description)}"><meta property="og:type" content="website"><meta property="og:site_name" content="Beckify"><meta property="og:url" content="${canonicalUrl}"><meta property="og:image" content="${siteUrl}/opengraph.jpg"><meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="${escapeXml(`${title} | Beckify`)}"><meta name="twitter:description" content="${escapeXml(description)}"><meta name="twitter:image" content="${siteUrl}/opengraph.jpg">
${showAds ? `<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-5333275222472637" crossorigin="anonymous"></script>` : ""}
<script async src="https://www.googletagmanager.com/gtag/js?id=G-ZVFZ9X595E"></script><script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','G-ZVFZ9X595E');</script>
<script type="application/ld+json">${JSON.stringify(schema)}</script>
<style>body{margin:0;background:#05060f;color:#eef0fa;font:16px/1.6 system-ui,sans-serif}main{max-width:860px;margin:auto;padding:32px 22px 48px}a{color:#b7abff}h1{font-size:clamp(2rem,5vw,3.5rem);line-height:1.1;margin:.35rem 0 1.1rem}h2{font-size:1.15rem;margin:0 0 .45rem}.eyebrow{color:#9b8cff;text-transform:uppercase;letter-spacing:.12em;font-size:.75rem;font-weight:700}.crumbs{font-size:.86rem;margin-bottom:2.5rem}.intro{font-size:1.12rem;color:#d5d7e8;max-width:720px}.panel{background:#111326;border:1px solid #30304a;border-radius:14px;padding:20px 22px;margin:24px 0}.panel p{margin:.4rem 0;color:#b7bad2;max-width:720px}.cta{display:inline-block;margin:4px 0 0;padding:12px 18px;border-radius:9px;background:#8b7bff;color:#fff;text-decoration:none;font-weight:700}.links{display:flex;gap:18px;flex-wrap:wrap;margin-top:14px;font-size:.93rem}iframe{width:100%;height:720px;border:1px solid #30304a;border-radius:14px;margin-top:22px;background:#111326}</style></head>
<body><main><nav class="crumbs" aria-label="Breadcrumb"><a href="/">Beckify</a> / <a href="/toolbox/">Toolbox</a> / ${escapeXml(title)}</nav><div class="eyebrow">${escapeXml(eyebrow)}</div><h1>${escapeXml(title)}</h1><p class="intro">${escapeXml(description)}</p><section class="panel" aria-labelledby="about-tool"><h2 id="about-tool">About this ${subject}</h2><p>Use this free browser-based ${subject} to work through the relevant electrical inputs, review the result, and compare it with field conditions.</p><p>For design, installation, or safety decisions, verify assumptions against the applicable code edition, equipment documentation, and site requirements.</p><a class="cta" href="${toolPath}">Open the interactive ${kind === "tool" ? "tool" : "collection"}</a><div class="links"><a href="/toolbox/">Browse all electrical tools</a><a href="/sitemap">Browse the Beckify site map</a></div></section><iframe src="/toolbox/index.html#${toolPath.split("#")[1]}" title="${escapeXml(title)}" loading="lazy"></iframe></main></body></html>`;
};

const urls = [
  ["/", "weekly", "1.0"], ["/about", "monthly", "0.7"], ["/privacy", "monthly", "0.7"], ["/games", "weekly", "0.7"], ["/games/new-glenn-runner", "monthly", "0.7"], ["/projects", "weekly", "0.8"], ["/projects/vespa-p200e", "monthly", "0.8"], ["/projects/honda-xr650r", "monthly", "0.8"], ["/made-in-america", "weekly", "0.9"], ["/control-systems", "weekly", "0.9"], ["/toolbox/", "weekly", "1.0"], ["/sitemap", "monthly", "0.7"],
  ...categories.map(([slug], index) => [`/toolbox/category/${slug}/`, index === 5 ? "weekly" : "monthly", "0.8"]),
  ...tools.map(([slug]) => [`/toolbox/${slug}/`, slug === "digital-logic-workbench" ? "weekly" : "monthly", slug === "digital-logic-workbench" ? "0.9" : "0.8"]),
  ...aliases.map(([slug]) => [`/toolbox/${slug}/`, "monthly", "0.5"]),
];
const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.map(([path, changefreq, priority]) => `  <url>\n    <loc>${escapeXml(`${siteUrl}${path}`)}</loc>\n    <changefreq>${changefreq}</changefreq>\n    <priority>${priority}</priority>\n  </url>`).join("\n")}\n</urlset>\n`;
await writeFile(resolve(root, "public/sitemap.xml"), xml);

if (process.argv.includes("--dist")) {
  const output = resolve(root, "dist/public");
  await writeFile(resolve(output, "sitemap.xml"), xml);
  for (const [slug, title, description, anchor] of [...tools, ...aliases]) {
    const directory = resolve(output, "toolbox", slug);
    await mkdir(directory, { recursive: true });
    await writeFile(resolve(directory, "index.html"), page({ title, description, path: `/toolbox/${slug}/`, toolPath: `/toolbox/#${anchor}`, showAds: !["smith-chart", "lsi-breaker"].includes(slug) }));
  }
  for (const [slug, title, description, anchor] of categories) {
    const directory = resolve(output, "toolbox/category", slug);
    await mkdir(directory, { recursive: true });
    await writeFile(resolve(directory, "index.html"), page({ title, description, path: `/toolbox/category/${slug}/`, toolPath: `/toolbox/#${anchor}`, eyebrow: "Beckify Toolbox Category", kind: "category" }));
  }
}
