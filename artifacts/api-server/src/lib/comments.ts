import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";

/**
 * Build-page comments: validation, spam defenses and storage.
 *
 * Privacy: no cookies, no accounts, no emails. Raw IPs are never stored or
 * logged; the per-IP rate limit keeps only an in-memory HMAC of the IP with a
 * salt that rotates daily and lives only in process memory.
 */

export const MAX_BODY = 1000;
export const MIN_BODY = 3;
export const MAX_NAME = 40;
export const MIN_SUBMIT_MS = 4_000;
export const MAX_FORM_AGE_MS = 24 * 3600_000;
export const MAX_LINKS = 1;
export const MAX_PENDING_TOTAL = 300;
export const MAX_PAGE_KEYS = 25;
export const PER_IP_WINDOW_MS = 3600_000;
export const PER_IP_MAX = 3;
export const PAGE_KEY_RE = /^[a-z0-9][a-z0-9-]{1,58}[a-z0-9]$/;

export type CommentStatus = "pending" | "approved";
export interface Comment {
  id: string;
  page: string;
  name: string;
  body: string;
  ts: number;
  status: CommentStatus;
  h: string;
}
export interface CommentsData {
  comments: Comment[];
}

const BAD_WORDS = [
  "fuck", "shit", "bitch", "asshole", "cunt", "nigger", "faggot", "retard",
  "viagra", "cialis", "casino", "porn", "xxx", "crypto giveaway", "forex",
  "whatsapp", "telegram", "seo service", "backlink",
];
const URL_RE = /(https?:\/\/|www\.|\b[a-z0-9-]+\.(com|net|org|io|ru|cn|xyz|top|biz|info|shop|click|site|online|live|link)\b)/gi;

/** Strip control/bidi characters and collapse noisy whitespace. */
export function cleanText(input: string, multiline: boolean): string {
  let s = input.normalize("NFKC");
  // eslint-disable-next-line no-control-regex
  s = s.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff]/g, "");
  s = s.replace(/\r\n?/g, "\n");
  if (multiline) s = s.replace(/[ \t]+/g, " ").replace(/\n{3,}/g, "\n\n");
  else s = s.replace(/\s+/g, " ");
  return s.trim();
}

export function countLinks(text: string): number {
  return (text.match(URL_RE) ?? []).length;
}

export function hasBadWord(text: string): boolean {
  const lower = text.toLowerCase().replace(/[^a-z0-9 ]/g, "");
  return BAD_WORDS.some((w) => lower.includes(w));
}

export type Validated =
  | { ok: true; name: string; body: string }
  | { ok: false; status: number; error: string };

export function validateSubmission(raw: unknown): Validated {
  const bad = (error: string, status = 400): Validated => ({ ok: false, status, error });
  if (!raw || typeof raw !== "object") return bad("Invalid request.");
  const r = raw as Record<string, unknown>;
  if (typeof r["body"] !== "string") return bad("Please write a comment.");
  if (r["name"] !== undefined && r["name"] !== null && typeof r["name"] !== "string") return bad("Invalid name.");
  const name = cleanText(String(r["name"] ?? ""), false);
  const body = cleanText(r["body"], true);
  if (body.length < MIN_BODY) return bad("Comment is too short.");
  if (body.length > MAX_BODY) return bad(`Comment is too long (max ${MAX_BODY} characters).`);
  if (name.length > MAX_NAME) return bad(`Name is too long (max ${MAX_NAME} characters).`);
  if (countLinks(body) + countLinks(name) > MAX_LINKS) return bad("Please include at most one link.");
  if (countLinks(name) > 0) return bad("Names can't contain links.");
  if (hasBadWord(body) || hasBadWord(name)) return bad("That comment can't be accepted. Please rephrase it.");
  if (/(.)\1{14,}/.test(body)) return bad("That comment looks like spam.");
  const letters = body.replace(/[^\p{L}]/gu, "");
  if (letters.length < 2) return bad("Please write a few words.");
  return { ok: true, name, body };
}

export function sanitizePageKey(v: unknown): string | null {
  return typeof v === "string" && PAGE_KEY_RE.test(v) ? v : null;
}

export function bodyHash(page: string, body: string): string {
  return createHash("sha256").update(`${page}\n${body.toLowerCase()}`).digest("hex").slice(0, 24);
}

/** Public shape: never exposes hash or status internals. */
export function publicComment(c: Comment) {
  return { id: c.id, name: c.name, body: c.body, ts: c.ts };
}

export function safeEqual(a: string, b: string): boolean {
  const ha = createHash("sha256").update(a).digest();
  const hb = createHash("sha256").update(b).digest();
  return timingSafeEqual(ha, hb);
}

/* ---------- form token (time-to-submit) ---------- */

const processSecret = randomBytes(32).toString("hex");
function formSecret(): string {
  return process.env["COMMENTS_ADMIN_TOKEN"] || process.env["SHARE_HMAC_SECRET"] || processSecret;
}
export function issueFormToken(page: string, now = Date.now()): string {
  const sig = createHmac("sha256", formSecret()).update(`${page}.${now}`).digest("hex").slice(0, 32);
  return `${now}.${sig}`;
}
export function checkFormToken(token: unknown, page: string, now = Date.now()): { ok: true } | { ok: false; error: string } {
  if (typeof token !== "string") return { ok: false, error: "Please reload the page and try again." };
  const [tsStr, sig] = token.split(".");
  const ts = Number(tsStr);
  if (!Number.isFinite(ts) || !sig) return { ok: false, error: "Please reload the page and try again." };
  const expect = createHmac("sha256", formSecret()).update(`${page}.${ts}`).digest("hex").slice(0, 32);
  if (!safeEqual(sig, expect)) return { ok: false, error: "Please reload the page and try again." };
  const age = now - ts;
  if (age < MIN_SUBMIT_MS) return { ok: false, error: "That was a bit quick. Please wait a few seconds and send again." };
  if (age > MAX_FORM_AGE_MS) return { ok: false, error: "This form expired. Please reload the page." };
  return { ok: true };
}

/* ---------- per-IP hashed rate limit (memory only) ---------- */

const ipBuckets = new Map<string, { count: number; resetAt: number }>();
function dailySalt(now: number): string {
  return `${formSecret()}:${Math.floor(now / 86_400_000)}`;
}
export function ipKey(ip: string, now = Date.now()): string {
  return createHmac("sha256", dailySalt(now)).update(ip).digest("hex").slice(0, 24);
}
export function consumeIp(key: string, now = Date.now(), max = PER_IP_MAX) {
  const cur = ipBuckets.get(key);
  const b = !cur || cur.resetAt <= now ? { count: 0, resetAt: now + PER_IP_WINDOW_MS } : cur;
  b.count += 1;
  ipBuckets.set(key, b);
  if (ipBuckets.size > 5000) for (const [k, v] of ipBuckets) if (v.resetAt <= now) ipBuckets.delete(k);
  return { allowed: b.count <= max, resetAt: b.resetAt };
}
export function resetRateLimits() { ipBuckets.clear(); }

/* ---------- storage ---------- */

export interface Snapshot { data: CommentsData; version: string | null }
export interface CommentBackend {
  load(): Promise<Snapshot>;
  /** Throws ConflictError when `version` is stale. */
  save(data: CommentsData, version: string | null): Promise<void>;
}
export class ConflictError extends Error {}

export class MemoryBackend implements CommentBackend {
  private data: CommentsData = { comments: [] };
  private v = 0;
  async load() { return { data: JSON.parse(JSON.stringify(this.data)) as CommentsData, version: String(this.v) }; }
  async save(data: CommentsData, version: string | null) {
    if (version !== String(this.v)) throw new ConflictError();
    this.data = JSON.parse(JSON.stringify(data));
    this.v += 1;
  }
}

/** Durable $0 storage: one JSON file in a private GitHub repo (git history = backups). */
export class GitHubBackend implements CommentBackend {
  constructor(
    private token: string,
    private repo: string,
    private path = "comments.json",
    private fetchImpl: typeof fetch = fetch,
  ) {}
  private url() { return `${process.env["COMMENTS_GH_API_BASE"] ?? "https://api.github.com"}/repos/${this.repo}/contents/${this.path}`; }
  private headers() {
    return {
      Authorization: `Bearer ${this.token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "beckify-comments",
    };
  }
  async load(): Promise<Snapshot> {
    const res = await this.fetchImpl(this.url(), { headers: this.headers() });
    if (res.status === 404) return { data: { comments: [] }, version: null };
    if (!res.ok) throw new Error(`storage read failed (${res.status})`);
    const j = (await res.json()) as { content?: string; sha?: string };
    const text = Buffer.from(j.content ?? "", "base64").toString("utf8");
    const parsed = text ? (JSON.parse(text) as CommentsData) : { comments: [] };
    return { data: { comments: Array.isArray(parsed.comments) ? parsed.comments : [] }, version: j.sha ?? null };
  }
  async save(data: CommentsData, version: string | null) {
    const body: Record<string, unknown> = {
      message: "comments: update",
      content: Buffer.from(JSON.stringify(data, null, 1), "utf8").toString("base64"),
    };
    if (version) body["sha"] = version;
    const res = await this.fetchImpl(this.url(), {
      method: "PUT",
      headers: { ...this.headers(), "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    if (res.status === 409 || res.status === 422) throw new ConflictError();
    if (!res.ok) throw new Error(`storage write failed (${res.status})`);
  }
}

export class CommentStore {
  private chain: Promise<unknown> = Promise.resolve();
  private cache: { at: number; snap: Snapshot } | null = null;
  constructor(private backend: CommentBackend, private cacheMs = 30_000) {}

  private async read(fresh: boolean): Promise<Snapshot> {
    const now = Date.now();
    if (!fresh && this.cache && now - this.cache.at < this.cacheMs) return this.cache.snap;
    const snap = await this.backend.load();
    this.cache = { at: now, snap };
    return snap;
  }

  /** Serialised read-modify-write with conflict retry. */
  mutate<T>(fn: (d: CommentsData) => T): Promise<T> {
    const run = async () => {
      for (let attempt = 0; attempt < 4; attempt++) {
        const snap = await this.read(true);
        const data = JSON.parse(JSON.stringify(snap.data)) as CommentsData;
        const out = fn(data);
        try {
          await this.backend.save(data, snap.version);
          this.cache = null;
          return out;
        } catch (e) {
          if (!(e instanceof ConflictError)) throw e;
        }
      }
      throw new Error("storage busy");
    };
    const p = this.chain.then(run, run);
    this.chain = p.catch(() => undefined);
    return p;
  }

  async approved(page: string): Promise<Comment[]> {
    const { data } = await this.read(false);
    return data.comments.filter((c) => c.page === page && c.status === "approved").sort((a, b) => a.ts - b.ts);
  }
  async all(): Promise<Comment[]> {
    const { data } = await this.read(true);
    return data.comments;
  }

  add(page: string, name: string, body: string, now = Date.now()):
    Promise<{ ok: true; id: string } | { ok: false; status: number; error: string }> {
    return this.mutate((d) => {
      const pending = d.comments.filter((c) => c.status === "pending").length;
      if (pending >= MAX_PENDING_TOTAL) return { ok: false as const, status: 503, error: "Comments are paused for now. Please try again later." };
      if (!d.comments.some((c) => c.page === page) && new Set(d.comments.map((c) => c.page)).size >= MAX_PAGE_KEYS)
        return { ok: false as const, status: 400, error: "Unknown page." };
      const h = bodyHash(page, body);
      if (d.comments.some((c) => c.h === h)) return { ok: false as const, status: 409, error: "That comment was already received." };
      const id = randomBytes(6).toString("hex");
      d.comments.push({ id, page, name, body, ts: now, status: "pending", h });
      return { ok: true as const, id };
    });
  }
  approve(id: string) {
    return this.mutate((d) => {
      const c = d.comments.find((x) => x.id === id);
      if (!c) return false;
      c.status = "approved";
      return true;
    });
  }
  remove(id: string) {
    return this.mutate((d) => {
      const n = d.comments.length;
      d.comments = d.comments.filter((x) => x.id !== id);
      return d.comments.length < n;
    });
  }
}

let singleton: CommentStore | null = null;
export function getStore(): CommentStore | null {
  if (singleton) return singleton;
  const token = process.env["COMMENTS_GH_TOKEN"];
  const repo = process.env["COMMENTS_GH_REPO"] ?? "becktj90/beckify-comments";
  if (!token) return null;
  singleton = new CommentStore(new GitHubBackend(token, repo));
  return singleton;
}
export function setStoreForTests(s: CommentStore | null) { singleton = s; }
