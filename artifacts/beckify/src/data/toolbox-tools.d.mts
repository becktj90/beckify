/**
 * Type declarations for toolbox-tools.mjs, which is plain ESM JavaScript
 * (no TypeScript syntax) because scripts/generate-sitemap.mjs imports it
 * directly under plain `node`, not through Vite/tsc.
 */
export type ToolTuple = readonly [slug: string, title: string, description: string, sectionAnchor: string];
export type AliasTuple = readonly [slug: string, title: string, description: string, sectionAnchor: string, familyId: string | null, modeId: string | null];
export type FamilyMode = { id: string; label: string; slug: string; anchor: string };
export type ToolFamily = {
  id: string;
  title: string;
  navLabel: string;
  defaultAnchor: string;
  modes: FamilyMode[];
};

export const TOOL_FAMILIES: ToolFamily[];
export const TOOLS: ToolTuple[];
export const TOOL_ALIASES: AliasTuple[];
export const CATEGORIES: ToolTuple[];
export const REFERENCE_TABLES: ToolTuple[];
export const PUBLIC_CALCULATOR_COUNT: number;
export const ALL_TOOL_SLUGS: string[];

export type ToolAvailability = "web" | "ios" | "ios-only";
export type ToolHomeArea = { id: "field" | "toolkit"; title: string; blurb: string };
export type ToolShelf = { id: string; area: "field" | "toolkit"; title: string };
export type RegistryTool = {
  toolId: string;
  shelf: string;
  tile: string | null;
  availability: ToolAvailability;
  slug: string | null;
  anchor: string | null;
  href: string | null;
  title: string;
  subtitle: string;
  synonyms: string[];
};

export const TOOL_HOME_AREAS: ToolHomeArea[];
export const TOOL_SHELVES: ToolShelf[];
export const TOOL_REGISTRY: RegistryTool[];
export const DEFAULT_PIN_IDS: string[];
export function resolveToolSlug(slug: string): {
  slug: string;
  title: string;
  description: string;
  anchor: string;
  familyId: string | null;
  modeId: string | null;
  alias: boolean;
} | null;
