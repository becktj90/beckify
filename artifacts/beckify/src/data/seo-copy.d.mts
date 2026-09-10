/**
 * Type declarations for seo-copy.mjs (plain ESM for Node scripts).
 */
export type SeoCopy = { title: string; description: string };
export type FeaturedTool = { slug: string; label: string };

export const FEATURED_TOOLS: FeaturedTool[];
export const HOME_TOOLBOX_EXTRAS: FeaturedTool[];
export const VESPA_RELATED_TOOLS: FeaturedTool[];
export const FEATURED_TOOL_SLUGS: Set<string>;
export const PAGE_SEO: Record<string, SeoCopy>;
export const STATIC_ROUTE_PATHS: string[];
export const TOOL_SEO_TITLES: Record<string, string>;
export const CATEGORY_SEO_TITLES: Record<string, string>;

export function pageSeo(path: string): SeoCopy | null;
export function seoForStaticRoute(route: string): SeoCopy | null;
export function toolDocumentTitle(slug: string, fallbackTitle: string): string;
export function categoryDocumentTitle(slug: string, fallbackTitle: string): string;
export function toolboxPermalink(slug: string): string;
export function homeToolboxLinks(): FeaturedTool[];
