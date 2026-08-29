import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const html = await readFile(resolve(root, "public/toolbox/index.html"), "utf8");
const sectionIds = [...html.matchAll(/<section\s+id="(sec-[^"]+)"/g)].map((match) => match[1]);
const excluded = new Set(["sec-home", "sec-arcade", "sec-projects"]);
const urls = [
  ["/", "weekly", "1.0"],
  ["/about", "monthly", "0.7"],
  ["/games", "weekly", "0.7"],
  ["/projects", "weekly", "0.8"],
  ["/toolbox/", "weekly", "1.0"],
  ["/sitemap", "monthly", "0.7"],
  ...sectionIds
    .filter((id) => !excluded.has(id))
    .map((id) => [`/toolbox/#${id}`, id === "sec-tdr" ? "weekly" : "monthly", id === "sec-tdr" ? "0.9" : "0.8"]),
];
const uniqueUrls = [...new Map(urls.map((entry) => [entry[0], entry])).values()];
const escapeXml = (value) => value
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll('"', "&quot;")
  .replaceAll("'", "&apos;");
const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${uniqueUrls
  .map(([path, changefreq, priority]) => `  <url>\n    <loc>${escapeXml(`https://beckify.com${path}`)}</loc>\n    <changefreq>${changefreq}</changefreq>\n    <priority>${priority}</priority>\n  </url>`)
  .join("\n")}\n</urlset>\n`;
await mkdir(resolve(root, "public"), { recursive: true });
await writeFile(resolve(root, "public/sitemap.xml"), xml);
