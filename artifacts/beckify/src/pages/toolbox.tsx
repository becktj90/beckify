import { useEffect, useId, useMemo, useRef, useState } from "react";
import { Info, Pin, Search, Star, X } from "lucide-react";
import { Layout } from "@/components/Layout";
import { SchemaHead } from "@/components/seo/SchemaHead";
import { PAGE_SEO, homeToolboxLinks, toolboxPermalink } from "@/data/seo-copy.mjs";
import { PUBLIC_CALCULATOR_COUNT } from "@/data/toolbox-tools.mjs";
import {
  APP_STORE_URL,
  CLASSIC_TOOLBOX_PATH,
  FAVORITE_STORAGE_KEY,
  PIN_STORAGE_KEY,
  TOOL_HOME_AREAS,
  TOOL_REGISTRY,
  areaOf,
  favoritesFromStorage,
  filterTools,
  groupToolsByShelf,
  legacyToolboxRedirect,
  pinsFromStorage,
  registryToolIds,
  toggleId,
  toolBadge,
  toolHref,
  toolOpensAppStore,
  type RegistryTool,
} from "@/lib/toolbox-home.mjs";

type AreaId = "field" | "toolkit" | "favorites";

const TOOLS = TOOL_REGISTRY;
const VALID_IDS = registryToolIds();
const DISCLAIMER = "Design aid only. Not a code-compliance determination and not a PE stamp.";

function tileSources(tile: string) {
  const base = `/toolbox/tiles/${tile}`;
  return {
    src: `${base}.png`,
    srcSet: `${base}.png 64w, ${base}@2x.png 128w, ${base}@3x.png 192w`,
  };
}

function readStorage(key: string, favorites: boolean) {
  try {
    const raw = window.localStorage.getItem(key);
    return favorites ? favoritesFromStorage(raw, VALID_IDS) : pinsFromStorage(raw, VALID_IDS);
  } catch {
    return favorites ? [] : pinsFromStorage(null, VALID_IDS);
  }
}

function writeStorage(key: string, ids: string[]) {
  try {
    window.localStorage.setItem(key, JSON.stringify(ids));
  } catch {
    /* private mode and full disks still leave the in-memory strip usable */
  }
}

function ToolArt({ tile, eager }: { tile: string | null; eager: boolean }) {
  if (!tile) {
    return <span className="toolbox-art toolbox-art-fallback" aria-hidden="true" />;
  }
  const sources = tileSources(tile);
  return (
    <img
      className="toolbox-art"
      src={sources.src}
      srcSet={sources.srcSet}
      sizes="80px"
      width={80}
      height={80}
      alt=""
      decoding="async"
      loading={eager ? "eager" : "lazy"}
      fetchPriority={eager ? "high" : "auto"}
    />
  );
}

function ToolTile({
  tool,
  eager,
  favorite,
  onToggleFavorite,
  onDetails,
}: {
  tool: RegistryTool;
  eager: boolean;
  favorite: boolean;
  onToggleFavorite: (id: string) => void;
  onDetails: (tool: RegistryTool) => void;
}) {
  const href = toolHref(tool) as string;
  const external = toolOpensAppStore(tool);
  const badge = toolBadge(tool) as string | null;
  return (
    <li className="toolbox-tile">
      <div className="toolbox-tile-actions">
        <button
          type="button"
          className="toolbox-icon-btn"
          aria-pressed={favorite}
          aria-label={favorite ? `Remove ${tool.title} from favorites` : `Add ${tool.title} to favorites`}
          onClick={() => onToggleFavorite(tool.toolId)}
        >
          <Star aria-hidden="true" className={favorite ? "fill-current" : ""} />
        </button>
        <button type="button" className="toolbox-icon-btn" aria-label={`How ${tool.title} works`} onClick={() => onDetails(tool)}>
          <Info aria-hidden="true" />
        </button>
      </div>
      <a
        className="toolbox-tile-link"
        href={href}
        {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
      >
        <ToolArt tile={tool.tile} eager={eager} />
        <span className="toolbox-tile-title">{tool.title}</span>
        {badge ? <span className="toolbox-badge">{badge}</span> : null}
        {external ? <span className="sr-only"> Opens the App Store.</span> : null}
      </a>
    </li>
  );
}

function ToolDialog({
  tool,
  pinned,
  onTogglePin,
  onClose,
}: {
  tool: RegistryTool | null;
  pinned: boolean;
  onTogglePin: (id: string) => void;
  onClose: () => void;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (tool && !dialog.open) dialog.showModal();
    if (!tool && dialog.open) dialog.close();
  }, [tool]);

  const href = tool ? (toolHref(tool) as string) : CLASSIC_TOOLBOX_PATH;
  const external = tool ? toolOpensAppStore(tool) : false;
  const badge = tool ? (toolBadge(tool) as string | null) : null;

  return (
    <dialog ref={ref} className="toolbox-dialog" aria-labelledby="toolbox-dialog-title" onClose={onClose}>
      {tool ? (
        <div className="toolbox-dialog-body">
          <div className="flex items-start gap-4">
            <ToolArt tile={tool.tile} eager />
            <div className="min-w-0 flex-1">
              <p className="type-label text-[var(--accent)]">How it works</p>
              <h2 id="toolbox-dialog-title" className="font-display text-xl font-semibold text-[var(--foreground)]">
                {tool.title}
              </h2>
              {badge ? <p className="toolbox-badge mt-2">{badge}</p> : null}
            </div>
          </div>
          <p className="mt-4 text-sm leading-relaxed text-[var(--foreground)]">{tool.subtitle}</p>
          {tool.availability === "ios-only" ? (
            <p className="mt-3 text-sm leading-relaxed text-[var(--muted)]">
              This instrument needs phone hardware a browser cannot provide, so it stays in the Beckify iOS app.
            </p>
          ) : null}
          {tool.availability === "ios" ? (
            <p className="mt-3 text-sm leading-relaxed text-[var(--muted)]">
              This one is in the Beckify iOS app. The web calculator is not on this site yet.
            </p>
          ) : null}
          <p className="mt-3 text-sm leading-relaxed text-[var(--muted)]">{DISCLAIMER}</p>
          <div className="mt-5 flex flex-wrap gap-2">
            <a
              className="toolbox-primary"
              href={href}
              {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
            >
              {external ? "Open in the iOS app" : "Open tool"}
            </a>
            <button type="button" className="toolbox-secondary" aria-pressed={pinned} onClick={() => onTogglePin(tool.toolId)}>
              <Pin aria-hidden="true" className="h-4 w-4" />
              {pinned ? "Unpin" : "Pin"}
            </button>
            <button type="button" className="toolbox-secondary" onClick={onClose}>
              Close
            </button>
          </div>
        </div>
      ) : null}
    </dialog>
  );
}

export default function ToolboxPage() {
  const [redirect, setRedirect] = useState<string | null>(() =>
    legacyToolboxRedirect(window.location.search, window.location.hash) as string | null,
  );
  useEffect(() => {
    const sync = () => {
      const next = legacyToolboxRedirect(window.location.search, window.location.hash) as string | null;
      setRedirect(next);
      if (next) window.location.replace(next);
    };
    window.addEventListener("hashchange", sync);
    if (redirect) window.location.replace(redirect);
    return () => window.removeEventListener("hashchange", sync);
  }, [redirect]);
  if (redirect) {
    return (
      <Layout showAds={false}>
        <p role="status">Opening the calculator…</p>
      </Layout>
    );
  }
  return <ToolboxHome />;
}

function ToolboxHome() {
  const searchId = useId();
  const searchRef = useRef<HTMLInputElement>(null);
  const [area, setArea] = useState<AreaId>("field");
  const [query, setQuery] = useState("");
  const [pins, setPins] = useState<string[]>(() => pinsFromStorage(null, VALID_IDS) as string[]);
  const [favorites, setFavorites] = useState<string[]>([]);
  const [ready, setReady] = useState(false);
  const [details, setDetails] = useState<RegistryTool | null>(null);

  useEffect(() => {
    setPins(readStorage(PIN_STORAGE_KEY, false) as string[]);
    setFavorites(readStorage(FAVORITE_STORAGE_KEY, true) as string[]);
    setReady(true);
  }, []);

  useEffect(() => {
    if (!ready) return;
    writeStorage(PIN_STORAGE_KEY, pins);
  }, [pins, ready]);

  useEffect(() => {
    if (!ready) return;
    writeStorage(FAVORITE_STORAGE_KEY, favorites);
  }, [favorites, ready]);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key !== "/" || event.metaKey || event.ctrlKey || event.altKey) return;
      const target = event.target;
      if (target instanceof HTMLElement && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable)) return;
      event.preventDefault();
      searchRef.current?.focus();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const favoriteSet = useMemo(() => new Set(favorites), [favorites]);
  const pinSet = useMemo(() => new Set(pins), [pins]);

  const pool = useMemo(() => {
    if (query.trim()) {
      const base = area === "favorites" ? TOOLS.filter((tool) => favoriteSet.has(tool.toolId)) : TOOLS;
      return filterTools(base, query) as RegistryTool[];
    }
    if (area === "favorites") return TOOLS.filter((tool) => favoriteSet.has(tool.toolId));
    return TOOLS.filter((tool) => (areaOf(tool) as { id: string } | null)?.id === area);
  }, [area, favoriteSet, query]);

  const groups = useMemo(() => groupToolsByShelf(pool) as { shelf: { id: string; area: string; title: string }; tools: RegistryTool[] }[], [pool]);
  const pinnedTools = pins.map((id) => TOOLS.find((tool) => tool.toolId === id)).filter((tool): tool is RegistryTool => Boolean(tool));
  const showPins = !query.trim() && area !== "favorites" && pinnedTools.length > 0;
  const seo = PAGE_SEO["/toolbox/"] as { title: string; description: string };

  const onToggleFavorite = (id: string) => setFavorites((current) => toggleId(current, id) as string[]);
  const onTogglePin = (id: string) => setPins((current) => toggleId(current, id) as string[]);

  let eagerBudget = 8;

  return (
    <Layout showAds mainClassName="toolbox-page mx-auto w-full max-w-6xl px-4 py-6 md:px-6 md:py-10">
      <SchemaHead title={seo.title} description={seo.description} path="/toolbox" />
      <a className="toolbox-skip" href="#toolbox-shelves">
        Skip to tools
      </a>
      <header className="toolbox-hero">
        <p className="type-label text-[var(--copper)]">Field EE toolbox</p>
        <h1 className="font-display text-3xl font-semibold tracking-[-0.02em] text-[var(--foreground)] md:text-4xl">Toolbox</h1>
        <p className="max-w-2xl text-sm leading-relaxed text-[var(--muted)] md:text-base">
          {PUBLIC_CALCULATOR_COUNT} web calculators, plus the iOS instruments that need the phone. Same shelves as the app. Stars and pins stay on this device.
        </p>
        <nav className="mt-2 flex flex-wrap gap-2" aria-label="Calculators people search for">
          {homeToolboxLinks().map(({ slug, label }) => (
            <a
              key={slug}
              href={toolboxPermalink(slug)}
              className="rounded-full border border-[var(--border)] bg-[#12161e] px-3 py-1.5 text-xs font-semibold text-[var(--foreground)] no-underline hover:border-[var(--accent)]"
            >
              {label}
            </a>
          ))}
        </nav>
        <p className="text-sm text-[var(--muted)]">
          <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={CLASSIC_TOOLBOX_PATH}>
            Open the classic list
          </a>
          <span aria-hidden="true"> · </span>
          <a className="text-[var(--accent)] underline-offset-4 hover:underline" href={APP_STORE_URL} target="_blank" rel="noopener noreferrer">
            Beckify for iPhone and iPad
          </a>
        </p>
      </header>

      <div className="toolbox-toolbar">
        <div className="toolbox-areas" role="group" aria-label="Toolbox areas">
          {TOOL_HOME_AREAS.map((item: { id: AreaId; title: string }) => (
            <button key={item.id} type="button" className="toolbox-area" aria-pressed={area === item.id} onClick={() => setArea(item.id)}>
              {item.title}
            </button>
          ))}
          <button type="button" className="toolbox-area" aria-pressed={area === "favorites"} onClick={() => setArea("favorites")}>
            Favorites
            <span className="toolbox-count">{favorites.length}</span>
          </button>
        </div>
        <div className="toolbox-search">
          <label className="sr-only" htmlFor={searchId}>
            Search tools
          </label>
          <Search aria-hidden="true" className="toolbox-search-icon" />
          <input
            ref={searchRef}
            id={searchId}
            type="search"
            value={query}
            placeholder="Search voltage drop, conduit, 555…"
            autoComplete="off"
            enterKeyHint="search"
            onChange={(event) => setQuery(event.target.value)}
          />
          {query ? (
            <button type="button" className="toolbox-icon-btn" aria-label="Clear search" onClick={() => setQuery("")}>
              <X aria-hidden="true" />
            </button>
          ) : (
            <kbd className="toolbox-kbd" aria-hidden="true">
              /
            </kbd>
          )}
        </div>
      </div>

      <p className="sr-only" aria-live="polite">
        {pool.length} {pool.length === 1 ? "tool" : "tools"}
        {query.trim() ? ` matching ${query.trim()}` : ""}
        {area === "favorites" ? " in favorites" : ""}
      </p>

      {showPins ? (
        <section className="toolbox-pinned" aria-labelledby="toolbox-pinned-title">
          <h2 id="toolbox-pinned-title" className="toolbox-shelf-title">
            Pinned
          </h2>
          <ul className="toolbox-pin-row" role="list">
            {pinnedTools.map((tool) => {
              const href = toolHref(tool) as string;
              const external = toolOpensAppStore(tool);
              return (
                <li key={tool.toolId} className="toolbox-pin">
                  <a href={href} {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}>
                    <ToolArt tile={tool.tile} eager={false} />
                    <span>{tool.title}</span>
                  </a>
                  <button type="button" className="toolbox-icon-btn" aria-label={`Unpin ${tool.title}`} onClick={() => onTogglePin(tool.toolId)}>
                    <Pin aria-hidden="true" className="fill-current" />
                  </button>
                </li>
              );
            })}
          </ul>
        </section>
      ) : null}

      <div id="toolbox-shelves" tabIndex={-1} className="toolbox-shelves">
        {groups.length === 0 ? (
          <div className="toolbox-empty" role="status">
            <p className="font-display text-lg text-[var(--foreground)]">
              {area === "favorites" && !query.trim() ? "No favorites yet" : "No matching tools"}
            </p>
            <p className="mt-2 text-sm text-[var(--muted)]">
              {area === "favorites" && !query.trim()
                ? "Star a tool and it stays on this device."
                : "Try a shorter name, or switch shelves. Search looks at titles and the words electricians actually use."}
            </p>
            {query ? (
              <button type="button" className="toolbox-secondary mt-4" onClick={() => setQuery("")}>
                Clear search
              </button>
            ) : null}
          </div>
        ) : (
          groups.map((group, index) => (
            <section
              key={group.shelf.id}
              className={index > 0 ? "toolbox-shelf toolbox-shelf-deferred" : "toolbox-shelf"}
              aria-labelledby={`shelf-${group.shelf.id}`}
            >
              <h2 id={`shelf-${group.shelf.id}`} className="toolbox-shelf-title">
                {group.shelf.title}
              </h2>
              <ul className="toolbox-grid" role="list">
                {group.tools.map((tool) => {
                  const eager = eagerBudget > 0;
                  if (eager) eagerBudget -= 1;
                  return (
                    <ToolTile
                      key={tool.toolId}
                      tool={tool}
                      eager={eager}
                      favorite={favoriteSet.has(tool.toolId)}
                      onToggleFavorite={onToggleFavorite}
                      onDetails={setDetails}
                    />
                  );
                })}
              </ul>
            </section>
          ))
        )}
      </div>

      <ToolDialog
        tool={details}
        pinned={details ? pinSet.has(details.toolId) : false}
        onTogglePin={onTogglePin}
        onClose={() => setDetails(null)}
      />
    </Layout>
  );
}
