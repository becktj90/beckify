import { useEffect } from "react";
import { SITE_ORIGIN, toCanonicalUrl } from "@/lib/canonical-url.mjs";

const SITE_URL = SITE_ORIGIN;
const DEFAULT_IMAGE = `${SITE_URL}/opengraph.jpg`;

export interface SeoProps {
  title: string;
  description: string;
  path?: string;
  image?: string;
  type?: "website" | "article";
  schema?: Record<string, unknown> | Record<string, unknown>[];
  /**
   * Defaults to indexable. Pages that exist to catch a bad URL rather than
   * to be found — the not-found route, most obviously — should pass
   * "noindex,follow" so a broken inbound link doesn't get indexed as a
   * duplicate of whatever content this route happens to render.
   */
  robots?: string;
}

const upsertMeta = (selector: string, attributes: Record<string, string>, content: string) => {
  let element = document.head.querySelector<HTMLMetaElement>(selector);
  if (!element) {
    element = document.createElement("meta");
    element.dataset.beckifySeo = "true";
    document.head.appendChild(element);
  }
  Object.entries(attributes).forEach(([name, value]) => element?.setAttribute(name, value));
  element.setAttribute("content", content);
};

export function SchemaHead({ title, description, path = "/", image = DEFAULT_IMAGE, type = "website", schema, robots = "index,follow,max-image-preview:large" }: SeoProps) {
  useEffect(() => {
    const canonicalUrl = toCanonicalUrl(path);
    document.title = title;

    let canonical = document.head.querySelector<HTMLLinkElement>('link[rel="canonical"]');
    if (!canonical) {
      canonical = document.createElement("link");
      canonical.rel = "canonical";
      document.head.appendChild(canonical);
    }
    canonical.href = canonicalUrl;

    upsertMeta('meta[name="description"]', { name: "description" }, description);
    upsertMeta('meta[property="og:title"]', { property: "og:title" }, title);
    upsertMeta('meta[property="og:description"]', { property: "og:description" }, description);
    upsertMeta('meta[property="og:type"]', { property: "og:type" }, type);
    upsertMeta('meta[property="og:url"]', { property: "og:url" }, canonicalUrl);
    upsertMeta('meta[property="og:image"]', { property: "og:image" }, image);
    upsertMeta('meta[property="og:site_name"]', { property: "og:site_name" }, "Beckify");
    upsertMeta('meta[name="twitter:card"]', { name: "twitter:card" }, "summary_large_image");
    upsertMeta('meta[name="twitter:title"]', { name: "twitter:title" }, title);
    upsertMeta('meta[name="twitter:description"]', { name: "twitter:description" }, description);
    upsertMeta('meta[name="twitter:image"]', { name: "twitter:image" }, image);
    upsertMeta('meta[name="robots"]', { name: "robots" }, robots);

    document.head.querySelectorAll('script[data-beckify-schema="true"]').forEach((node) => node.remove());
    const schemas = [
      {
        "@context": "https://schema.org",
        "@type": "WebPage",
        name: title,
        description,
        url: canonicalUrl,
        isPartOf: { "@type": "WebSite", name: "Beckify", url: toCanonicalUrl("/") },
      },
      ...(schema ? (Array.isArray(schema) ? schema : [schema]) : []),
    ];
    schemas.forEach((value) => {
      const script = document.createElement("script");
      script.type = "application/ld+json";
      script.dataset.beckifySchema = "true";
      script.textContent = JSON.stringify(value);
      document.head.appendChild(script);
    });

    return () => {
      document.head.querySelectorAll('meta[data-beckify-seo="true"]').forEach((node) => node.remove());
      document.head.querySelectorAll('script[data-beckify-schema="true"]').forEach((node) => node.remove());
    };
  }, [description, image, path, robots, schema, title, type]);

  return null;
}

export const webApplicationSchema = (name: string, description: string, path: string) => ({
  "@context": "https://schema.org",
  "@type": ["SoftwareApplication", "WebApplication"],
  name,
  description,
  url: toCanonicalUrl(path),
  operatingSystem: "All",
  applicationCategory: "EngineeringApplication",
  isAccessibleForFree: true,
  publisher: { "@type": "Organization", name: "Beckify", url: toCanonicalUrl("/") },
});

export { SITE_URL, toCanonicalUrl };
