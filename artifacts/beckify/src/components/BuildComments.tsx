import { useEffect, useRef, useState, type FormEvent } from "react";

/**
 * Reader comments for build pages. One line to add to a new build page:
 *   <BuildComments pageKey="my-build" />
 * pageKey: lowercase letters, digits and hyphens (matches the page slug).
 *
 * The comment feature sets no cookies, needs no accounts and adds no analytics. Comments are held until the site
 * owner approves them. All text is rendered as plain text (never HTML).
 */
const API = "https://api.beckify.com/api/comments";
const MAX_BODY = 1000;
const MAX_NAME = 40;

interface PublicComment { id: string; name: string; body: string; ts: number }

export function BuildComments({ pageKey }: { pageKey: string }) {
  const [comments, setComments] = useState<PublicComment[] | null>(null);
  const [enabled, setEnabled] = useState(true);
  const [failed, setFailed] = useState(false);
  const [token, setToken] = useState("");
  const [name, setName] = useState("");
  const [body, setBody] = useState("");
  const [status, setStatus] = useState<{ kind: "ok" | "err"; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const honeypot = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const ctl = new AbortController();
    fetch(`${API}?page=${encodeURIComponent(pageKey)}`, { signal: ctl.signal, credentials: "omit" })
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error("bad"))))
      .then((j: { comments: PublicComment[]; token: string; enabled: boolean }) => {
        setComments(j.comments);
        setToken(j.token);
        setEnabled(j.enabled !== false);
      })
      .catch((e) => { if (e?.name !== "AbortError") setFailed(true); });
    return () => ctl.abort();
  }, [pageKey]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (busy) return;
    setBusy(true);
    setStatus(null);
    try {
      const r = await fetch(API, {
        method: "POST",
        credentials: "omit",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ page: pageKey, name, body, token, website: honeypot.current?.value ?? "" }),
      });
      const j = (await r.json().catch(() => ({}))) as { message?: string; error?: string };
      if (r.ok) {
        setStatus({ kind: "ok", text: j.message ?? "Thanks! Your comment will appear after review." });
        setBody("");
        // Fetch a fresh timing token for a possible next comment.
        fetch(`${API}?page=${encodeURIComponent(pageKey)}`, { credentials: "omit" })
          .then((x) => x.json()).then((x: { token: string }) => setToken(x.token)).catch(() => {});
      } else {
        setStatus({ kind: "err", text: j.error ?? "Could not send your comment." });
      }
    } catch {
      setStatus({ kind: "err", text: "Network error. Please try again." });
    } finally {
      setBusy(false);
    }
  }

  const field =
    "w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-base text-[var(--foreground)] placeholder:text-[var(--muted)] focus:outline-none focus:ring-2 focus:ring-[var(--accent)]";

  return (
    <section className="build-comments mx-auto my-12 w-full max-w-3xl px-4 text-[var(--foreground)]" aria-labelledby={`bc-h-${pageKey}`}>
      <h2 id={`bc-h-${pageKey}`} className="font-display text-2xl font-bold tracking-tight">Comments</h2>
      <p className="mt-1 text-sm text-[var(--muted)]">
        No account needed. Comments appear after review. The comment box itself sets no cookies; see the{" "}
        <a className="text-[var(--accent)] underline-offset-4 hover:underline" href="/privacy/#website-comments">privacy note</a>.
      </p>

      <div className="mt-6 space-y-4" aria-live="polite">
        {comments === null && !failed && <p className="text-sm text-[var(--muted)]">Loading comments…</p>}
        {failed && <p className="text-sm text-[var(--muted)]">Comments couldn’t be loaded right now.</p>}
        {comments?.length === 0 && <p className="text-sm text-[var(--muted)]">No comments yet. Be the first.</p>}
        {comments?.map((c) => (
          <article key={c.id} className="rounded-xl border border-[var(--border)] bg-[var(--surface)] p-4">
            <header className="flex flex-wrap items-baseline gap-x-3 text-sm">
              <strong>{c.name || "Anonymous"}</strong>
              <time className="text-[var(--muted)]" dateTime={new Date(c.ts).toISOString()}>
                {new Date(c.ts).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
              </time>
            </header>
            {/* Plain text only: React escapes it; never dangerouslySetInnerHTML. */}
            <p className="mt-2 whitespace-pre-wrap break-words text-base leading-relaxed">{c.body}</p>
          </article>
        ))}
      </div>

      {enabled && !failed && (
        <form onSubmit={submit} className="mt-8 space-y-3" noValidate>
          <label className="block text-sm font-medium" htmlFor={`bc-name-${pageKey}`}>
            Name <span className="font-normal text-[var(--muted)]">(optional, shown publicly)</span>
          </label>
          <input id={`bc-name-${pageKey}`} className={field} value={name} maxLength={MAX_NAME} autoComplete="off"
            onChange={(e) => setName(e.target.value)} />
          <label className="block text-sm font-medium" htmlFor={`bc-body-${pageKey}`}>Comment</label>
          <textarea id={`bc-body-${pageKey}`} className={field} rows={5} value={body} maxLength={MAX_BODY} required
            onChange={(e) => setBody(e.target.value)} />
          <div className="text-xs text-[var(--muted)]">{body.length}/{MAX_BODY} · plain text · at most one link</div>
          {/* Honeypot: hidden from people and assistive tech. */}
          <div aria-hidden="true" style={{ position: "absolute", left: "-10000px", width: 1, height: 1, overflow: "hidden" }}>
            <label>Website<input ref={honeypot} type="text" tabIndex={-1} autoComplete="off" defaultValue="" /></label>
          </div>
          <button type="submit" disabled={busy || body.trim().length < 3 || !token}
            className="min-h-[44px] rounded-lg bg-[var(--accent)] px-5 py-2 font-semibold text-[var(--accent-foreground)] disabled:opacity-50">
            {busy ? "Sending…" : "Post comment"}
          </button>
          {status && (
            <p role="status" className={status.kind === "ok" ? "text-sm text-[var(--accent)]" : "text-sm text-[var(--copper,#e09c56)]"}>
              {status.text}
            </p>
          )}
        </form>
      )}
      {!enabled && <p className="mt-6 text-sm text-[var(--muted)]">New comments are turned off for now.</p>}
    </section>
  );
}
