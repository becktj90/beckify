import { useEffect, useState } from "react";
import { useParams } from "wouter";
import { Layout } from "@/components/Layout";
import { SchemaHead } from "@/components/seo/SchemaHead";

type ShareField = { label: string; value: string };
type ShareBody = { title: string; contractor: string; fields: ShareField[] };

const tokenPattern = /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/;

/**
 * Public snapshot for a Voltage Drop or Conduit Fill link. Not a calculator.
 * The token is verified by api.beckify.com; this page does not recompute the job.
 */
export default function SharePage() {
  const params = useParams<{ token: string }>();
  const token = params.token ?? "";
  const [state, setState] = useState<"loading" | "ready" | "missing">("loading");
  const [body, setBody] = useState<ShareBody | null>(null);

  useEffect(() => {
    if (!tokenPattern.test(token)) {
      setState("missing");
      setBody(null);
      return;
    }
    const controller = new AbortController();
    setState("loading");
    fetch(`https://api.beckify.com/api/share/${token}`, { signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error("missing");
        return (await response.json()) as ShareBody;
      })
      .then((payload) => {
        if (!payload?.contractor || !payload.title || !Array.isArray(payload.fields) || payload.fields.length === 0) {
          throw new Error("missing");
        }
        setBody(payload);
        setState("ready");
      })
      .catch((error: unknown) => {
        if (error instanceof DOMException && error.name === "AbortError") return;
        setBody(null);
        setState("missing");
      });
    return () => controller.abort();
  }, [token]);

  const title = body ? `${body.contractor} — ${body.title} | Beckify` : "Shared calculation | Beckify";

  return (
    <Layout showAds={false}>
      <SchemaHead
        title={title}
        description="A hosted calculation snapshot with the contractor name. Not a second calculator."
        path={token ? `/share/${token}` : "/share"}
        robots="noindex,nofollow"
      />
      <article className="mx-auto flex w-full max-w-xl flex-col gap-6 py-10">
        {state === "loading" ? (
          <p className="text-[var(--muted)]" role="status">
            Loading snapshot…
          </p>
        ) : null}
        {state === "missing" ? (
          <div>
            <h1 className="text-2xl font-bold text-[var(--foreground)]">Link not found</h1>
            <p className="mt-3 text-[var(--muted)]">This share link is missing or no longer valid.</p>
          </div>
        ) : null}
        {state === "ready" && body ? (
          <div>
            <p className="text-xs font-semibold tracking-[0.14em] text-[var(--muted)]">{body.title.toUpperCase()}</p>
            <h1 className="mt-2 text-3xl font-bold text-[var(--foreground)]">{body.contractor}</h1>
            <p className="mt-2 text-sm text-[var(--muted)]">Snapshot only. This page does not recalculate the job.</p>
            <dl className="mt-6 divide-y divide-[var(--border)] rounded-2xl border border-[var(--border)]">
              {body.fields.map((field, index) => (
                <div key={`${field.label}-${index}`} className="grid gap-1 px-4 py-3 sm:grid-cols-[12rem_1fr] sm:gap-4">
                  <dt className="text-sm text-[var(--muted)]">{field.label}</dt>
                  <dd className="text-sm font-medium text-[var(--foreground)]">{field.value}</dd>
                </div>
              ))}
            </dl>
            <p className="mt-4 text-xs text-[var(--muted)]">Design aid only — not a permit, a PE stamp, or a substitute for the applicable code.</p>
          </div>
        ) : null}
      </article>
    </Layout>
  );
}
