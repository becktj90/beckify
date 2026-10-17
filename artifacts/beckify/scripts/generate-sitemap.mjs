import { execFileSync } from "node:child_process";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { TOOLS as tools, CATEGORIES as categories, TOOL_ALIASES as aliases, resolveToolSlug } from "../src/data/toolbox-tools.mjs";
import { SITE_ORIGIN, toCanonicalPath, toCanonicalUrl } from "../src/lib/canonical-url.mjs";
import { ABOUT_DISCLAIMER, RELATED_TOOLS, TOOL_ABOUT_COPY } from "../src/data/tool-about-copy.mjs";
import {
  FEATURED_TOOLS,
  FEATURED_TOOL_SLUGS,
  categoryDocumentTitle,
  toolDocumentDescription,
  toolDocumentTitle,
  toolboxPermalink,
} from "../src/data/seo-copy.mjs";

const root = resolve(import.meta.dirname, "..");
const siteUrl = SITE_ORIGIN;

const escapeXml = (value) => value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&apos;");
const featuredLinks = (currentSlug) => FEATURED_TOOLS
  .filter((tool) => tool.slug !== currentSlug)
  .map((tool) => `<a href="${toolboxPermalink(tool.slug)}">${escapeXml(tool.label)}</a>`)
  .join("");
const renderAbout = (slug, description, subject) => {
  const sections = TOOL_ABOUT_COPY[slug];
  const p = (text) => `<p>${escapeXml(text)}</p>`;
  const body = sections
    ? sections.map((section) => `<h3>${escapeXml(section.heading)}</h3>${(section.paragraphs ?? []).map(p).join("")}${section.code ? `<pre><code>${section.code.map(escapeXml).join("\n")}</code></pre>` : ""}${section.bullets ? `<ul>${section.bullets.map((item) => `<li>${escapeXml(item)}</li>`).join("")}</ul>` : ""}${(section.after ?? []).map(p).join("")}${section.faqs ? section.faqs.map((item) => `<h4>${escapeXml(item.q)}</h4>${p(item.a)}`).join("") : ""}`).join("")
    : p(description);
  const related = RELATED_TOOLS[slug];
  const relatedHtml = related
    ? `<h3>${escapeXml(related.heading)}</h3><ul>${related.links.map((link) => `<li><a href="${toolboxPermalink(link.slug)}">${escapeXml(link.label)}</a></li>`).join("")}</ul>`
    : "";
  return `<h2 id="about-tool">About this ${subject}</h2>${body}${relatedHtml}<p><em>${escapeXml(ABOUT_DISCLAIMER)}</em></p>`;
};
const faqsFor = (slug) => (TOOL_ABOUT_COPY[slug] ?? []).flatMap((section) => section.faqs ?? []);
const page = ({ title, description, path, toolPath, slug, eyebrow = "Electrical engineering toolbox", showAds = true, kind = "tool" }) => {
  const canonicalUrl = toCanonicalUrl(path);
  const documentTitle = kind === "category" ? categoryDocumentTitle(slug, title) : toolDocumentTitle(slug, title);
  const metaDescription = kind === "tool" ? toolDocumentDescription(slug, description) : description;
  const faqs = kind === "tool" ? faqsFor(slug) : [];
  const schema = [
    {
      "@context": "https://schema.org",
      "@type": kind === "tool" ? ["SoftwareApplication", "WebApplication"] : "CollectionPage",
      name: documentTitle,
      description: metaDescription,
      url: canonicalUrl,
      ...(kind === "tool" ? {
        operatingSystem: "All",
        applicationCategory: "EngineeringApplication",
        isAccessibleForFree: true,
      } : {}),
      publisher: { "@type": "Organization", name: "Beckify", url: `${siteUrl}/` },
    },
    ...(faqs.length
      ? [{
          "@context": "https://schema.org",
          "@type": "FAQPage",
          mainEntity: faqs.map((item) => ({
            "@type": "Question",
            name: item.q,
            acceptedAnswer: { "@type": "Answer", text: item.a },
          })),
        }]
      : []),
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "Beckify", item: `${siteUrl}/` },
        { "@type": "ListItem", position: 2, name: "Toolbox", item: `${siteUrl}/toolbox/` },
        { "@type": "ListItem", position: 3, name: title, item: canonicalUrl },
      ],
    },
  ];
  const subject = kind === "tool" ? "calculator" : "tool collection";
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="strict-origin-when-cross-origin">
<title>${escapeXml(documentTitle)}</title><meta name="description" content="${escapeXml(metaDescription)}"><meta name="robots" content="index,follow">
<link rel="canonical" href="${canonicalUrl}"><meta property="og:title" content="${escapeXml(documentTitle)}"><meta property="og:description" content="${escapeXml(metaDescription)}"><meta property="og:type" content="website"><meta property="og:site_name" content="Beckify"><meta property="og:url" content="${canonicalUrl}"><meta property="og:image" content="${siteUrl}/opengraph.jpg"><meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="${escapeXml(documentTitle)}"><meta name="twitter:description" content="${escapeXml(metaDescription)}"><meta name="twitter:image" content="${siteUrl}/opengraph.jpg">
${showAds ? `<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-5333275222472637" crossorigin="anonymous"></script>` : ""}
<script async src="https://www.googletagmanager.com/gtag/js?id=G-ZVFZ9X595E"></script><script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','G-ZVFZ9X595E');</script>
<script type="application/ld+json">${JSON.stringify(schema)}</script>
<style>body{margin:0;background:#080b10;color:#e8eef5;font:16px/1.6 system-ui,sans-serif}main{max-width:860px;margin:auto;padding:32px 22px 48px}a{color:#40bad6}h1{font-size:clamp(2rem,5vw,3.5rem);line-height:1.1;margin:.35rem 0 1.1rem}h2{font-size:1.15rem;margin:0 0 .45rem}h3{font-size:1rem;margin:1.1rem 0 .3rem}h4{font-size:.95rem;margin:.9rem 0 .2rem}.panel ul{margin:.4rem 0;padding-left:1.2rem;color:#b7bad2;max-width:720px}pre{background:#080b10;border:1px solid rgba(255,255,255,.12);border-radius:8px;padding:10px 14px;overflow-x:auto;color:#d5d7e8}.eyebrow{color:#40bad6;text-transform:uppercase;letter-spacing:.12em;font-size:.75rem;font-weight:700}.crumbs{font-size:.86rem;margin-bottom:2.5rem}.intro{font-size:1.12rem;color:#d5d7e8;max-width:720px}.panel{background:#12161e;border:1px solid rgba(255,255,255,.12);border-radius:14px;padding:20px 22px;margin:24px 0}.panel p{margin:.4rem 0;color:#b7bad2;max-width:720px}.cta{display:inline-block;margin:4px 0 0;padding:12px 18px;border-radius:9px;background:#40bad6;color:#080b10;text-decoration:none;font-weight:700}.links{display:flex;gap:18px;flex-wrap:wrap;margin-top:14px;font-size:.93rem}iframe{width:100%;height:720px;border:1px solid rgba(255,255,255,.12);border-radius:14px;margin-top:22px;background:#12161e}</style></head>
<body><main><nav class="crumbs" aria-label="Breadcrumb"><a href="/">Beckify</a> / <a href="/toolbox/">Toolbox</a> / ${escapeXml(title)}</nav><div class="eyebrow">${escapeXml(eyebrow)}</div><h1>${escapeXml(title)}</h1><p class="intro">${escapeXml(metaDescription)}</p><section class="panel" aria-labelledby="about-tool">${renderAbout(slug, metaDescription, subject)}<a class="cta" href="${toolPath}">Open the interactive ${kind === "tool" ? "tool" : "collection"}</a><div class="links"><a href="/toolbox/">Browse all electrical tools</a>${featuredLinks(slug)}<a href="/sitemap/">Browse the Beckify site map</a></div></section><iframe src="${toolPath.includes("#") ? `/toolbox/classic/index.html#${toolPath.split("#")[1]}` : toolPath}" title="${escapeXml(title)}" loading="lazy"></iframe></main></body></html>`;
};

// lastmod: git commit date of the source that renders the URL, falling back
// to the build date when history is unavailable (no git, or a path with none).
const buildDate = new Date().toISOString().slice(0, 10);
const lastChange = (...files) => {
  const dates = files.map((file) => {
    try {
      return execFileSync("git", ["log", "-1", "--format=%cs", "--", file], { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
    } catch {
      return "";
    }
  }).filter(Boolean);
  return dates.sort().at(-1) ?? buildDate;
};
const toolboxLastmod = lastChange("src/data/toolbox-tools.mjs", "public/toolbox/classic/index.html");

// Tiers: 1.0 home; 0.9 toolbox hub + money pages; 0.7 other calculators and
// hubs; 0.5 journals, arcade, legal, and section aliases.
const MONEY_PAGE_SLUGS = new Set(["voltage-drop", "conduit-fill", "wire-size-ampacity", "transformer", "transformer-sizing", "photometrics", "motor"]);
const toolEntry = (slug, { alias = false } = {}) => {
  const money = MONEY_PAGE_SLUGS.has(slug);
  return [`/toolbox/${slug}/`, "monthly", money ? "0.9" : alias ? "0.5" : "0.7", toolboxLastmod];
};
const urls = [
  ["/", "weekly", "1.0", lastChange("src/pages/home.tsx", "index.html")],
  ["/about", "yearly", "0.5", lastChange("src/pages/about.tsx")],
  ["/privacy", "yearly", "0.5", lastChange("src/pages/privacy.tsx")],
  ["/contact", "yearly", "0.5", lastChange("src/pages/contact.tsx")],
  ["/apps", "monthly", "0.6", lastChange("src/pages/apps.tsx")],
  ["/games", "monthly", "0.5", lastChange("src/pages/games.tsx")],
  ["/games/kestrel-heavy", "monthly", "0.5", lastChange("src/pages/kestrel-heavy.tsx")],
  ["/projects", "monthly", "0.5", lastChange("src/pages/projects.tsx")],
  ["/projects/vespa-p200e", "yearly", "0.5", lastChange("src/pages/vespa-p200e.tsx")],
  ["/projects/honda-xr650r", "yearly", "0.5", lastChange("src/pages/honda-xr650r.tsx")],
  ["/control-systems", "monthly", "0.7", lastChange("src/pages/control-systems.tsx")],
  ["/toolbox/", "weekly", "0.9", toolboxLastmod],
  ["/sitemap", "monthly", "0.5", lastChange("src/pages/sitemap.tsx")],
  ...categories.map(([slug]) => [`/toolbox/category/${slug}/`, "monthly", "0.7", toolboxLastmod]),
  ...tools.map(([slug]) => toolEntry(slug)),
  ...aliases.map(([slug]) => toolEntry(slug, { alias: true })),
];
const seen = new Set();
const uniqueUrls = [];
for (const [path, changefreq, priority, lastmod] of urls) {
  const canonicalPath = toCanonicalPath(path);
  if (seen.has(canonicalPath)) continue;
  seen.add(canonicalPath);
  uniqueUrls.push([canonicalPath, changefreq, priority, lastmod]);
}
const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${uniqueUrls.map(([path, changefreq, priority, lastmod]) => `  <url>\n    <loc>${escapeXml(toCanonicalUrl(path))}</loc>\n    <lastmod>${lastmod}</lastmod>\n    <changefreq>${changefreq}</changefreq>\n    <priority>${priority}</priority>\n  </url>`).join("\n")}\n</urlset>\n`;
await writeFile(resolve(root, "public/sitemap.xml"), xml);

const permalinkEntries = [...tools, ...aliases].map(([slug]) => {
  const resolved = resolveToolSlug(slug);
  return resolved ? [slug, resolved.anchor] : null;
}).filter(Boolean);
const permalinkMap = `/* Generated by scripts/generate-sitemap.mjs — do not edit. */\nwindow.BECKIFY_TOOL_PERMALINKS = ${JSON.stringify(Object.fromEntries(permalinkEntries))};\n`;
await writeFile(resolve(root, "public/toolbox/js/permalink-map.js"), permalinkMap);

if (process.argv.includes("--dist")) {
  const output = resolve(root, "dist/public");
  await writeFile(resolve(output, "sitemap.xml"), xml);
  await mkdir(resolve(output, "toolbox/js"), { recursive: true });
  await writeFile(resolve(output, "toolbox/js/permalink-map.js"), permalinkMap);
  for (const [slug, title, description, anchor] of [...tools, ...aliases]) {
    const directory = resolve(output, "toolbox", slug);
    await mkdir(directory, { recursive: true });
    await writeFile(resolve(directory, "index.html"), page({ title, description, path: `/toolbox/${slug}/`, toolPath: slug === "switchgear-logic-lab" ? "/toolbox/switchgear-logic-lab.html" : `/toolbox/classic/#${anchor}`, slug, showAds: !["smith-chart", "lsi-breaker"].includes(slug) }));
  }
  for (const [slug, title, description, anchor] of categories) {
    const directory = resolve(output, "toolbox/category", slug);
    await mkdir(directory, { recursive: true });
    await writeFile(resolve(directory, "index.html"), page({ title, description, path: `/toolbox/category/${slug}/`, toolPath: `/toolbox/classic/#${anchor}`, slug, eyebrow: "Toolbox category", kind: "category" }));
  }
}
