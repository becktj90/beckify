export interface SitemapEntry {
  path: string;
  changefreq: "weekly" | "monthly" | "yearly";
  priority: "1.0" | "0.9" | "0.8" | "0.7";
}

export const TOOLBOX_CATEGORIES = [
  "sec-ohm", "sec-reactance", "sec-sp", "sec-vdrop", "sec-ups", "sec-ebike-tools",
  "sec-nec", "sec-lighting-opt", "sec-lsi", "sec-haz", "sec-convert", "sec-wire-ref",
  "sec-projects", "sec-tdr", "sec-circuit-sim",
];

// These are the public deep links for the standalone toolbox sections. The
// hash is intentional: the toolbox is a single offline-capable HTML app.
export const TOOLBOX_CALCULATORS = [
  "sec-ohm", "sec-power-dc", "sec-power-convert", "sec-power-ac", "sec-reactance",
  "sec-resonance", "sec-pfc", "sec-sp", "sec-vdrop", "sec-conductor-length", "sec-motor",
  "sec-xfmr", "sec-xfmr-engine", "sec-xfmr-size", "sec-conduit", "sec-conduit-adv",
  "sec-wire-select", "sec-sc", "sec-ups", "sec-gen", "sec-hybrid", "sec-ebike-tools",
  "sec-nec", "sec-lighting-opt", "sec-bldg-load", "sec-lsi", "sec-bess", "sec-tap",
  "sec-harmonics", "sec-haz", "sec-isloop", "sec-555", "sec-convert", "sec-cm",
  "sec-photometrics", "sec-panel-schedule", "sec-tdr", "sec-smith-chart", "sec-xfmr-wizard",
];

export function generateSitemapXml(entries: SitemapEntry[], siteUrl = "https://beckify.com") {
  const body = entries.map(({ path, changefreq, priority }) => `  <url>\n    <loc>${siteUrl}${path}</loc>\n    <changefreq>${changefreq}</changefreq>\n    <priority>${priority}</priority>\n  </url>`).join("\n");
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${body}\n</urlset>\n`;
}
