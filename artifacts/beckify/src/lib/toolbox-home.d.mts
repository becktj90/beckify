import type { RegistryTool, ToolHomeArea, ToolShelf } from "../data/toolbox-tools.mjs";

export type { RegistryTool, ToolHomeArea, ToolShelf };

export const APP_STORE_URL: string;
export const CLASSIC_TOOLBOX_PATH: string;
export const PIN_STORAGE_KEY: string;
export const FAVORITE_STORAGE_KEY: string;
export const DEFAULT_PIN_IDS: string[];
export const TOOL_HOME_AREAS: ToolHomeArea[];
export const TOOL_SHELVES: ToolShelf[];
export const TOOL_REGISTRY: RegistryTool[];

export function shelfOf(tool: RegistryTool): ToolShelf | null;
export function areaOf(tool: RegistryTool): ToolHomeArea | null;
export function toolHref(tool: RegistryTool): string;
export function toolOpensAppStore(tool: RegistryTool): boolean;
export function toolBadge(tool: RegistryTool): string | null;
export function toolSearchText(tool: RegistryTool): string;
export function filterTools(tools: readonly RegistryTool[], query: string): RegistryTool[];
export function groupToolsByShelf(tools: readonly RegistryTool[]): { shelf: ToolShelf; tools: RegistryTool[] }[];
export function parseStoredIds(raw: string | null, validIds: readonly string[] | Set<string>): string[] | null;
export function toggleId(ids: readonly string[], id: string): string[];
export function pinsFromStorage(raw: string | null, validIds: readonly string[] | Set<string>): string[];
export function favoritesFromStorage(raw: string | null, validIds: readonly string[] | Set<string>): string[];
export function legacyToolboxRedirect(search: string, hash: string): string | null;
export function registryToolIds(): string[];
