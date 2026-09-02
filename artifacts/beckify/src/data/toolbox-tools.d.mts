/**
 * Type declarations for toolbox-tools.mjs, which is plain ESM JavaScript
 * (no TypeScript syntax) because scripts/generate-sitemap.mjs imports it
 * directly under plain `node`, not through Vite/tsc.
 */
export type ToolTuple = readonly [slug: string, title: string, description: string, sectionAnchor: string];

export const TOOLS: ToolTuple[];
export const CATEGORIES: ToolTuple[];
export const REFERENCE_TABLES: ToolTuple[];
