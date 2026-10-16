/**
 * Pure helpers for the /toolbox tile home. No DOM, so node:test can import
 * this file directly. Shelf membership lives in toolbox-registry.mjs.
 */
import {
  DEFAULT_PIN_IDS,
  TOOL_HOME_AREAS,
  TOOL_REGISTRY,
  TOOL_SHELVES,
} from "../data/toolbox-registry.mjs";

export const APP_STORE_URL = "https://apps.apple.com/app/id6807908745";
export const CLASSIC_TOOLBOX_PATH = "/toolbox/classic/";
export const PIN_STORAGE_KEY = "beckify-toolbox-pins";
export const FAVORITE_STORAGE_KEY = "beckify-toolbox-favorites";

const SHELF_BY_ID = new Map(TOOL_SHELVES.map((shelf) => [shelf.id, shelf]));
const AREA_BY_ID = new Map(TOOL_HOME_AREAS.map((area) => [area.id, area]));

export function shelfOf(tool) {
  return SHELF_BY_ID.get(tool.shelf) ?? null;
}

export function areaOf(tool) {
  const shelf = shelfOf(tool);
  return shelf ? AREA_BY_ID.get(shelf.area) ?? null : null;
}

/** Where a tile goes. Hardware-only and not-yet-ported tools open the App Store. */
export function toolHref(tool) {
  if (tool.href) return tool.href;
  if (tool.availability === "ios" || tool.availability === "ios-only") return APP_STORE_URL;
  if (tool.anchor) return `${CLASSIC_TOOLBOX_PATH}#${tool.anchor}`;
  return CLASSIC_TOOLBOX_PATH;
}

export function toolOpensAppStore(tool) {
  return toolHref(tool) === APP_STORE_URL;
}

/** Visible status that is also text, never color alone. */
export function toolBadge(tool) {
  if (tool.availability === "ios-only") return "iOS app only";
  if (tool.availability === "ios") return "iOS app";
  return null;
}

export function toolSearchText(tool) {
  const shelf = shelfOf(tool);
  const area = areaOf(tool);
  return [tool.title, tool.subtitle, tool.toolId, tool.slug, shelf?.title, area?.title, toolBadge(tool), ...(tool.synonyms ?? [])]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();
}

/** Every whitespace-separated term must match. Empty query returns the input list. */
export function filterTools(tools, query) {
  const terms = String(query ?? "")
    .trim()
    .toLowerCase()
    .split(/\s+/)
    .filter(Boolean);
  if (!terms.length) return tools.slice();
  return tools.filter((tool) => {
    const blob = toolSearchText(tool);
    return terms.every((term) => blob.includes(term));
  });
}

export function groupToolsByShelf(tools) {
  const buckets = new Map(TOOL_SHELVES.map((shelf) => [shelf.id, []]));
  for (const tool of tools) {
    const bucket = buckets.get(tool.shelf);
    if (bucket) bucket.push(tool);
  }
  return TOOL_SHELVES.map((shelf) => ({ shelf, tools: buckets.get(shelf.id) ?? [] })).filter((group) => group.tools.length > 0);
}

/**
 * Parse a localStorage JSON array of tool ids.
 * `null` raw means the key was absent (caller picks the default).
 * Invalid JSON or a non-array becomes an empty list, never a throw.
 */
export function parseStoredIds(raw, validIds) {
  if (raw == null) return null;
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return [];
  }
  if (!Array.isArray(parsed)) return [];
  const allow = validIds instanceof Set ? validIds : new Set(validIds);
  const seen = new Set();
  const ids = [];
  for (const value of parsed) {
    if (typeof value !== "string" || !allow.has(value) || seen.has(value)) continue;
    seen.add(value);
    ids.push(value);
  }
  return ids;
}

export function toggleId(ids, id) {
  return ids.includes(id) ? ids.filter((item) => item !== id) : [...ids, id];
}

export function pinsFromStorage(raw, validIds) {
  const parsed = parseStoredIds(raw, validIds);
  if (parsed == null) {
    const allow = validIds instanceof Set ? validIds : new Set(validIds);
    return DEFAULT_PIN_IDS.filter((id) => allow.has(id));
  }
  return parsed;
}

export function favoritesFromStorage(raw, validIds) {
  return parseStoredIds(raw, validIds) ?? [];
}

/**
 * Old bookmarks to /toolbox/#sec-… and /toolbox/?t=…#sec-… still open the
 * classic calculator. The tile home owns /toolbox/ with no hash and no `t`.
 * Returns a same-origin path, or null when the request should stay on the grid.
 */
export function legacyToolboxRedirect(search, hash) {
  const params = new URLSearchParams(search.startsWith("?") ? search.slice(1) : search);
  const fragment = hash && hash !== "#" ? hash : "";
  if (!fragment && !params.has("t")) return null;
  const query = params.toString();
  return `${CLASSIC_TOOLBOX_PATH}${query ? `?${query}` : ""}${fragment}`;
}

export function registryToolIds() {
  return TOOL_REGISTRY.map((tool) => tool.toolId);
}

export { DEFAULT_PIN_IDS, TOOL_HOME_AREAS, TOOL_REGISTRY, TOOL_SHELVES };
