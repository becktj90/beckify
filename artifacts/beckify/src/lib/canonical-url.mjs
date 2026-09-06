/**
 * GitHub Pages serves directory indexes at trailing-slash URLs and 301s the
 * no-slash form (`/privacy` → `/privacy/`). Sitemap <loc> values and
 * <link rel="canonical"> must match that so Google does not crawl redirects.
 *
 * Root stays `https://beckify.com/`. File-like last segments (`.xml`, `.jpg`,
 * `.html`) are left unchanged — those are real files, not directories.
 */
export const SITE_ORIGIN = "https://beckify.com";

export function toCanonicalPath(path = "/") {
  const raw = String(path ?? "").trim() || "/";
  const pathname = raw.startsWith("/") ? raw : `/${raw}`;
  if (pathname === "/") return "/";
  if (/\.[a-zA-Z0-9]+$/.test(pathname)) return pathname;
  return pathname.endsWith("/") ? pathname : `${pathname}/`;
}

export function toCanonicalUrl(path = "/") {
  return `${SITE_ORIGIN}${toCanonicalPath(path)}`;
}
