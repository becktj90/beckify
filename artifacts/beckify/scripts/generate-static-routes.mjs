import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { toCanonicalPath, toCanonicalUrl } from "../src/lib/canonical-url.mjs";
import { STATIC_ROUTE_PATHS, seoForStaticRoute } from "../src/data/seo-copy.mjs";

const root = resolve(import.meta.dirname, "..");
const dist = resolve(root, "dist/public");
const shell = resolve(dist, "index.html");

const escapeHtml = (value) => value.replaceAll("&", "&amp;").replaceAll('"', "&quot;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const staticRoutes = STATIC_ROUTE_PATHS.map((route) => {
  const seo = seoForStaticRoute(route);
  if (!seo) throw new Error(`Missing PAGE_SEO for static route ${route}`);
  return [route, seo.title, seo.description];
});

// Legacy game slug: keep a directory so GitHub Pages 301s the no-slash URL,
// then immediately send crawlers to Kestrel Heavy. Do not list this in sitemap.xml.
const redirectRoutes = new Map([
  ["games/new-glenn-runner", "/games/kestrel-heavy/"],
]);

// The app sets page metadata after hydration, but route-specific static HTML
// lets crawlers and link previews identify the requested page before JavaScript.
const redirectShell = (targetPath, title) => {
  const canonicalUrl = toCanonicalUrl(targetPath);
  const localPath = toCanonicalPath(targetPath);
  const encodedTitle = escapeHtml(title);
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="0; url=${canonicalUrl}">
  <link rel="canonical" href="${canonicalUrl}">
  <meta name="robots" content="noindex,follow">
  <title>${encodedTitle}</title>
  <script>location.replace(${JSON.stringify(localPath)});</script>
</head>
<body>
  <p><a href="${canonicalUrl}">${encodedTitle}</a></p>
</body>
</html>
`;
};

const routeShell = (source, route, title, description) => {
  const canonicalUrl = toCanonicalUrl(`/${route}`);
  const encodedTitle = escapeHtml(title);
  const encodedDescription = escapeHtml(description);
  const schema = JSON.stringify({
    "@context": "https://schema.org",
    "@type": "WebPage",
    name: title,
    description,
    url: canonicalUrl,
    isPartOf: { "@type": "WebSite", name: "Beckify", url: "https://beckify.com/" },
  });
  return source
    .replace(/<title>[^<]*<\/title>/, `<title>${encodedTitle}</title>`)
    .replace(/<meta name="description" content="[^"]*"\s*\/>/, `<meta name="description" content="${encodedDescription}" />`)
    .replace(/<link rel="canonical" href="[^"]*"\s*\/>/, `<link rel="canonical" href="${canonicalUrl}" />`)
    .replace(/<meta property="og:title" content="[^"]*"\s*\/>/, `<meta property="og:title" content="${encodedTitle}" />`)
    .replace(/<meta property="og:description" content="[^"]*"\s*\/>/, `<meta property="og:description" content="${encodedDescription}" />`)
    .replace(/<meta property="og:url" content="[^"]*"\s*\/>/, `<meta property="og:url" content="${canonicalUrl}" />`)
    .replace(/<meta name="twitter:title" content="[^"]*"\s*\/>/, `<meta name="twitter:title" content="${encodedTitle}" />`)
    .replace(/<meta name="twitter:description" content="[^"]*"\s*\/>/, `<meta name="twitter:description" content="${encodedDescription}" />`)
    .replace("</head>", `<script type="application/ld+json">${schema}</script></head>`);
};

// GitHub Pages serves 404.html with a 404 status. Give every React route its
// own entry file so direct links return 200 while the client router selects
// the correct page after hydration.
const appShell = await readFile(shell, "utf8");
await Promise.all(staticRoutes.map(async ([route, title, description]) => {
  const directory = resolve(dist, route);
  await mkdir(directory, { recursive: true });
  const redirectTo = redirectRoutes.get(route);
  const html = redirectTo ? redirectShell(redirectTo, title) : routeShell(appShell, route, title, description);
  await writeFile(resolve(directory, "index.html"), html);
}));

// App Store Connect needs a public HTTPS policy that is readable even if a
// crawler does not execute JavaScript. Inject the markdown source as a
// noscript fallback on the privacy route only.
const privacyHtmlPath = resolve(dist, "privacy", "index.html");
const privacySource = await readFile(resolve(root, "../../ios/docs/PRIVACY.md"), "utf8");
const privacyHtml = await readFile(privacyHtmlPath, "utf8");
const privacyFallback = `<noscript><article id="privacy-policy" style="max-width:48rem;margin:2rem auto;padding:1.25rem;color:#eef0fa;font:16px/1.6 system-ui,sans-serif;white-space:pre-wrap">${escapeHtml(privacySource)}</article></noscript>`;
await writeFile(privacyHtmlPath, privacyHtml.replace("</body>", `${privacyFallback}</body>`));
