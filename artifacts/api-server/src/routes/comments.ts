import { Router, type IRouter, type Request, type Response } from "express";
import {
  checkFormToken, consumeIp, getStore, ipKey, issueFormToken, publicComment,
  safeEqual, sanitizePageKey, validateSubmission,
} from "../lib/comments.js";

const router: IRouter = Router();

function adminToken(): string | null {
  const t = process.env["COMMENTS_ADMIN_TOKEN"] ?? "";
  return t.length >= 16 ? t : null;
}
function isAdmin(req: Request): boolean {
  const want = adminToken();
  const m = /^Bearer (.+)$/.exec(req.get("authorization") ?? "");
  return !!want && !!m && safeEqual(m[1]!, want);
}
function noStore(res: Response) { res.setHeader("Cache-Control", "no-store"); }
function fail(res: Response, e: unknown) {
  req_log(e);
  return res.status(503).json({ error: "Comments are temporarily unavailable." });
}
function req_log(_e: unknown) { /* deliberately silent: no request data in logs */ }

router.get("/comments", async (req, res) => {
  noStore(res);
  const page = sanitizePageKey(req.query["page"]);
  if (!page) return res.status(400).json({ error: "Invalid page." });
  const store = getStore();
  const token = issueFormToken(page);
  if (!store) return res.json({ comments: [], token, enabled: false });
  try {
    const list = await store.approved(page);
    return res.json({ comments: list.map(publicComment), token, enabled: true });
  } catch (e) { return fail(res, e); }
});

router.post("/comments", async (req, res) => {
  noStore(res);
  const body = (req.body ?? {}) as Record<string, unknown>;
  // Honeypot: silently pretend success so bots learn nothing.
  if (typeof body["website"] === "string" && body["website"].trim() !== "") {
    return res.status(202).json({ ok: true, message: "Thanks! Your comment will appear after review." });
  }
  const page = sanitizePageKey(body["page"]);
  if (!page) return res.status(400).json({ error: "Invalid page." });
  const tok = checkFormToken(body["token"], page);
  if (!tok.ok) return res.status(400).json({ error: tok.error });
  const v = validateSubmission(body);
  if (!v.ok) return res.status(v.status).json({ error: v.error });
  const store = getStore();
  if (!store) return res.status(503).json({ error: "Comments are not enabled yet." });
  const rl = consumeIp(ipKey(req.ip || req.socket.remoteAddress || "unknown"));
  if (!rl.allowed) {
    res.setHeader("Retry-After", String(Math.ceil((rl.resetAt - Date.now()) / 1000)));
    return res.status(429).json({ error: "Too many comments from your connection. Please try again later." });
  }
  try {
    const out = await store.add(page, v.name, v.body);
    if (!out.ok) return res.status(out.status).json({ error: out.error });
    return res.status(202).json({ ok: true, message: "Thanks! Your comment will appear after review." });
  } catch (e) { return fail(res, e); }
});

/* ---------- moderation (token-protected) ---------- */

router.get("/comments/admin/queue", async (req, res) => {
  noStore(res);
  if (!isAdmin(req)) return res.status(401).json({ error: "Unauthorized." });
  const store = getStore();
  if (!store) return res.status(503).json({ error: "Storage not configured." });
  try {
    const all = await store.all();
    return res.json({
      pending: all.filter((c) => c.status === "pending").sort((a, b) => a.ts - b.ts)
        .map((c) => ({ id: c.id, page: c.page, name: c.name, body: c.body, ts: c.ts })),
      approved: all.filter((c) => c.status === "approved").sort((a, b) => b.ts - a.ts).slice(0, 50)
        .map((c) => ({ id: c.id, page: c.page, name: c.name, body: c.body, ts: c.ts })),
    });
  } catch (e) { return fail(res, e); }
});

function moderate(action: "approve" | "delete") {
  return async (req: Request, res: Response) => {
    noStore(res);
    if (!isAdmin(req)) return res.status(401).json({ error: "Unauthorized." });
    const store = getStore();
    if (!store) return res.status(503).json({ error: "Storage not configured." });
    const id = typeof req.body?.id === "string" ? req.body.id : "";
    if (!/^[a-f0-9]{12}$/.test(id)) return res.status(400).json({ error: "Invalid id." });
    try {
      const ok = action === "approve" ? await store.approve(id) : await store.remove(id);
      return ok ? res.json({ ok: true }) : res.status(404).json({ error: "Not found." });
    } catch (e) { return fail(res, e); }
  };
}
router.post("/comments/admin/approve", moderate("approve"));
router.post("/comments/admin/delete", moderate("delete"));

const ADMIN_HTML = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">
<title>Comment moderation</title>
<style>
:root{color-scheme:light dark;--bg:#fff;--fg:#111;--mu:#666;--bd:#ddd;--ac:#0a7d96}
@media(prefers-color-scheme:dark){:root{--bg:#080b10;--fg:#e8eef5;--mu:#94a2b2;--bd:#2a313b;--ac:#40bad6}}
body{font:16px/1.5 system-ui,sans-serif;background:var(--bg);color:var(--fg);margin:0;padding:16px;max-width:640px;margin-inline:auto}
h1{font-size:1.25rem}input,button{font:inherit;padding:.6rem .8rem;border-radius:8px;border:1px solid var(--bd);background:transparent;color:inherit}
button{cursor:pointer;min-height:44px}button.p{background:var(--ac);color:#fff;border-color:var(--ac)}
.c{border:1px solid var(--bd);border-radius:10px;padding:12px;margin:10px 0}.m{color:var(--mu);font-size:.8rem}
.b{white-space:pre-wrap;word-break:break-word;margin:.4rem 0}.r{display:flex;gap:8px}
</style></head><body><h1>Comment moderation</h1>
<div id="login"><input id="t" type="password" placeholder="Admin token" autocomplete="off" style="width:70%"> <button class="p" id="go">Open</button>
<p class="m">The token stays in this tab only (no cookies, cleared when you close it).</p></div>
<div id="app" hidden><p class="m" id="sum"></p><h2>Pending</h2><div id="pend"></div><h2>Recently approved</h2><div id="appr"></div></div>
<script>
var tok=sessionStorage.getItem("ct")||"";
function api(p,o){o=o||{};o.headers={"Authorization":"Bearer "+tok,"Content-Type":"application/json"};return fetch("/api/comments/admin/"+p,o)}
function card(c,pending){var d=document.createElement("div");d.className="c";
var m=document.createElement("div");m.className="m";m.textContent=c.page+" · "+(c.name||"Anonymous")+" · "+new Date(c.ts).toLocaleString();
var b=document.createElement("div");b.className="b";b.textContent=c.body;var r=document.createElement("div");r.className="r";
function act(label,path,cls){var x=document.createElement("button");x.textContent=label;if(cls)x.className=cls;x.onclick=function(){x.disabled=true;api(path,{method:"POST",body:JSON.stringify({id:c.id})}).then(load)};r.appendChild(x)}
if(pending)act("Approve","approve","p");act("Delete","delete");
d.append(m,b,r);return d}
function load(){api("queue").then(function(r){if(r.status===401){sessionStorage.removeItem("ct");document.getElementById("login").hidden=false;document.getElementById("app").hidden=true;return}
return r.json().then(function(j){document.getElementById("login").hidden=true;document.getElementById("app").hidden=false;
document.getElementById("sum").textContent=j.pending.length+" pending";
var p=document.getElementById("pend"),a=document.getElementById("appr");p.textContent="";a.textContent="";
j.pending.forEach(function(c){p.appendChild(card(c,true))});if(!j.pending.length)p.textContent="Nothing waiting.";
j.approved.forEach(function(c){a.appendChild(card(c,false))})})})}
document.getElementById("go").onclick=function(){tok=document.getElementById("t").value.trim();sessionStorage.setItem("ct",tok);load()};
if(tok)load();
</script></body></html>`;

router.get("/comments/admin", (_req, res) => {
  noStore(res);
  res.setHeader("Content-Security-Policy", "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'");
  res.setHeader("X-Robots-Tag", "noindex");
  res.type("html").send(ADMIN_HTML);
});

export default router;
