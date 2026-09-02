# Beckify security assessment

**Date:** 2026-09-02  
**Reviewer:** defensive static review of https://github.com/becktj90/beckify (commit `5743563` / `main` at branch time) plus live https://beckify.com and https://api.beckify.com.  
**Contact:** trevorjohnbeck@gmail.com

This is a written finding list, not a bug-bounty program. There is no public vulnerability-disclosure mailbox beyond that address. Please do not file “gotchas” against GitHub Pages for headers the platform cannot set.

## How to read this

Beckify’s public site is a **static GitHub Pages** app. The iOS app is **on-device SwiftUI** (bundle `com.beckify.toolbox`) with no web view of beckify.com. That is a small attack surface: there is no user-account database, no session cookies, and no privileged admin UI. Findings below are sized to that reality. Nothing here is a “the site is owned” story.

A parallel PR ([#26](https://github.com/becktj90/beckify/pull/26)) publishes the iOS privacy policy at https://beckify.com/privacy. This review branched from `main` **before** that merge. `ios/docs/PRIVACY.md` on `main` still says it is a draft and not hosted; do not treat that sentence as the live hosting story once #26 deploys.

## Threat model (short)

| Surface | What an attacker can actually do |
| --- | --- |
| beckify.com | Stored/reflected XSS in the victim’s browser; supply-chain of third-party scripts; stale service-worker content; clickjacking (Pages sends no `frame-ancestors`) |
| api.beckify.com | Spend the TDR vision budget from any browser that can POST from an allowed origin; no user data store |
| iOS app | Read Saved Jobs from an iTunes/iCloud backup of that device; prompt for mic/BT/location only after opening those tools |
| GitHub Actions | Compromised unpinned action could alter the Pages artifact (now pinned in this PR) |

Out of this review’s patch scope (other agents in flight): games visual overhaul / HexGL removal, ads, WKWebView wrap, EMP weapon copy, and rewriting the iOS privacy hosting story.

---

## Summary

No committed secrets, API keys, or `.env` values with credentials were found. Affiliate Amazon URLs already use `rel="sponsored noopener noreferrer"`. Toolbox calculators that interpolate user/OCR text into `innerHTML` go through `escapeHtml`. iOS has no `WKWebView`/`UIWebView`, default ATS (no `NSAllowsArbitraryLoads`), `ITSAppUsesNonExemptEncryption = NO` already set, and no exported URL schemes.

**Highest-confidence issues were medium or lower.** Hardening that is safe to merge is in this same PR (CSP/referrer metas, HTTPS-only TDR base URL, same-origin job deep links, OCR size cap, Actions pin + `persist-credentials: false`, Tesseract major-tag pin).

| Sev | Count |
| --- | ---: |
| Critical | 0 |
| High | 0 |
| Medium | 4 |
| Low | 8 |
| Info | 9 |

---

## Website (artifacts/beckify, live GitHub Pages)

### M1 — Medium — Third-party script surface (GA + AdSense + floating CDN tags)

**Evidence:** `artifacts/beckify/index.html` lines 30–37 (`G-ZVFZ9X595E`); `artifacts/beckify/src/components/ads/MinimalAdUnit.tsx` (`ca-pub-5333275222472637`); `artifacts/beckify/scripts/generate-sitemap.mjs` line 40 (AdSense on generated per-tool SEO pages); `artifacts/beckify/public/toolbox/panel-schedule.html` was `tesseract.js@5` (floating 5.x); `artifacts/beckify/public/toolbox/js/math-explanations.js` loads `mathjax@3` from jsDelivr.

**Impact:** A compromise of Google Tag Manager, AdSense, or an unpinned jsDelivr major tag can run script in every visitor’s origin. That is the largest XSS amplifier on an otherwise static site. GA also means the **website** is not “no analytics,” unlike the iOS app.

**Fix applied:** CSP + referrer metas on the React shell, toolbox, and panel pages; Tesseract pinned to `5.1.1` with SRI. Residual: CSP must allow `'unsafe-inline'` (inline gtag) and the ad/font/CDN hosts already in use, so this is defense-in-depth, not a lock-down. Do not remove GA/AdSense in this PR (ads are out of scope).

### M2 — Medium — TDR vision API is public, authenticated only by origin + IP rate limit

**Evidence:** Live `https://api.beckify.com/api/healthz` returns `{"status":"ok"}`. CORS preflight from `https://beckify.com` is allowed; a foreign origin does not receive `Access-Control-Allow-Origin`. Implementation: `artifacts/api-server/src/routes/analyze-tdr.ts` (image signature checks, 8 MiB cap, 5 req / 15 min / client, provider/model not client-selectable). Client: `artifacts/beckify/public/toolbox/js/tdr-analyzer.js` posts `imageBase64` to `meta[name="beckify-api-base-url"]` which **production injects as `https://api.beckify.com`**.

**Impact:** Anyone who can browse beckify.com can spend OpenAI/Anthropic quota. In-memory rate limits on Vercel do not hold across isolates. Keys stay on the server (good). This is cost abuse, not data theft.

**Fix applied:** Client now ignores a non-`https:` API base. Recommended follow-up (not in this PR): durable rate limit (e.g. Vercel KV) and/or a cheap proof-of-work / Turnstile if the bill becomes noticeable.

### M3 — Medium — GitHub Pages cannot set CSP / `X-Frame-Options` / HSTS as HTTP headers

**Evidence:** `curl -sI https://beckify.com/` (2026-09-02) shows `access-control-allow-origin: *`, `cache-control: max-age=600`, and **no** `Content-Security-Policy`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, or `Strict-Transport-Security`. HTTPS itself works; `www` 301s to apex.

**Impact:** Clickjacking of any Pages document is possible (another site can iframe beckify.com). CORS `*` on static files does not expose credentials (there are none). HSTS is absent, so a first visit on a hostile network could in principle be downgraded; browsers that have seen GitHub’s own HSTS are a separate story.

**Fix applied:** `<meta http-equiv="Content-Security-Policy">` and `<meta name="referrer">` on the documents we control. `frame-ancestors` **cannot** be set via meta CSP (browsers ignore it), so clickjacking remains a Pages platform limit. Toolbox already skips GA pageviews when `window.top !== window.self`.

### M4 — Medium — Unpinned GitHub Actions (supply chain of the deploy)

**Evidence:** `.github/workflows/deploy.yml` used `actions/checkout@v4`, `pnpm/action-setup@v4`, `actions/setup-node@v4`, `actions/upload-pages-artifact@v3`, `actions/deploy-pages@v4` (mutable major tags). Workflow permissions were already `contents: read` + `pages: write` + `id-token: write` (correct for Pages). Checkout default `persist-credentials: true`.

**Impact:** A compromised tag could run in the deploy job and rewrite the Pages artifact. `id-token: write` is required for `deploy-pages` OIDC; it is not a bug.

**Fix applied:** Pin those actions to commit SHAs (commented with the major tag), `persist-credentials: false` on checkout, same pin on `.github/workflows/ios-math.yml`.

### L1 — Low — Saved-job “Open” used `location.href = run.url` without an origin check

**Evidence:** `artifacts/beckify/public/toolbox/js/projects-ui.js` (save path writes `location.pathname + location.search + location.hash`; open path assigned `run.url` from IndexedDB).

**Impact:** IndexedDB is same-origin. A XSS that can write jobs could previously persist a `javascript:` or off-site URL as the “Open” target (defense in depth). Without XSS this is not reachable.

**Fix applied:** `safeJobHref()` only assigns same-origin URLs whose path starts with `/toolbox`.

### L2 — Low — Panel OCR accepted unbounded image files

**Evidence:** `handleFileSelection` in `panel-schedule.js` / `panel-power-study.js` checked `file.type.startsWith('image/')` only. TDR already capped at 12 MB. OCR text that reaches `innerHTML` is escaped (`escapeHtml` including quotes) — that path is in good shape.

**Impact:** A huge local image can stall the tab / Tesseract worker. Not a remote exploit.

**Fix applied:** 12 MiB cap, same as TDR.

### L3 — Low — Toolbox service worker cached all cross-origin GETs

**Evidence:** `artifacts/beckify/public/toolbox/sw.js` `cacheFirst` for any non-same-origin GET (comment: jsPDF/Tesseract CDNs). Root `public/sw.js` already ignores other origins and excludes `/toolbox/`, `/games/`, `/projects/`, `/demos/`. Navigations are network-first (good). Cache bump discipline is documented (`CACHE_VERSION`).

**Impact:** After XSS, an attacker-controlled fetch could be stored in the runtime cache. Without XSS, only CDNs the page already requests are cached.

**Fix applied:** Allow-list `cdn.jsdelivr.net`, Google Fonts, and GA hosts. Cache version bumped to `v14`.

### L4 — Low — URL state restores arbitrary strings into text inputs

**Evidence:** `artifacts/beckify/public/toolbox/js/url-state.js` — selects must match real `<option>` values; number inputs must be finite; other inputs take the raw query string into `.value` (not `innerHTML`).

**Impact:** A shared calculator link can prefill fields (intended). That is not DOM XSS. Social-engineering (“this link shows a fake NEC table”) is possible in theory; the page still runs Beckify’s own JS.

**Fix:** None required. Do not parse query strings as HTML.

### L5 — Low — `innerHTML` remains in several toolbox helpers

**Evidence:** `app.js` `showResult` / transformer / IS-loop rows (values passed through `escapeHtml`); `analog-tools.js` static templates; `conduit-guide.js` numeric SVG; `base-converter.js` digits from integer conversion; `lp-optimizer.js` uses `escapeHtml` on names. HexGL vendor copies (`public/vendor/hexgl/**`) use `innerHTML` on fixed strings — left alone (games out of scope).

**Impact:** Residual risk if a future calculator interpolates unsanitized text. Current OCR/user-derived paths are escaped.

**Fix applied:** No drive-by rewrite of every `innerHTML = ''` clear. Prefer `textContent` for new code.

### L6 — Low — Affiliate / outbound link hygiene (mostly already correct)

**Evidence:** `GearCard.tsx` already `rel="sponsored noopener noreferrer"` on Amazon and `noopener noreferrer` on manufacturer links. `VespaPartsCatalog.tsx` uses `sponsored` when the href contains `amazon.com`. Hardcoded `https://www.amazon.com/dp/...?tag=beckify-20`. Toolbox reference links used `rel="noopener"` only (`toolbox/index.html` UFC / SSCMAN anchors).

**Impact:** `javascript:` in a future CMS-driven URL would be the real bug; today’s data is static https. Missing `noreferrer` on two documentation links leaks the Referer to those hosts.

**Fix applied:** Gear links now drop non-http(s) hrefs. Toolbox doc links get `noopener noreferrer`. Referrer policy meta is `strict-origin-when-cross-origin`.

### L7 — Low — Sitemap / robots do not leak admin; SPA 404 is indexable except the dedicated not-found route

**Evidence:** `public/robots.txt` is `Allow: /` + sitemap. `sitemap.xml` is public marketing/tool URLs only (no `/admin`, `/api`, `/wp-`). Live `/privacy` was 404 at review time (awaiting PR #26). GitHub Pages SPA fallback still serves `index.html` as HTTP 200 for unknown paths; the React not-found route sets `noindex` (site audit P1-2).

**Impact:** No hidden admin to leak. Soft-404s remain a Pages limitation.

### L8 — Low — Client localStorage / IndexedDB holds jobs, prefs, game scores

**Evidence:** `local-store.js` (`beckify-toolbox` IndexedDB, `beckify-prefs` mirror). iOS twin: `JobStore.swift` `UserDefaults` key `com.beckify.toolbox.savedJobs`.

**Impact:** Any XSS on beckify.com can read toolbox jobs in that browser. Data is homework/field snapshots, not passwords. Clearing site data or deleting the iOS app removes it (iOS subject to device backup — see iOS I2).

**Fix:** Don’t put secrets in jobs. Documented, no Keychain migration (Keychain can outlive uninstall; these are not credentials).

### I1 — Info — `access-control-allow-origin: *` on all Pages assets

GitHub Pages default. Static JS/CSS are public anyway. The **API** is not `*`; it allow-lists `https://beckify.com`.

### I2 — Info — `demos/lc9-34/` is a client-side password gate over an encrypted blob

Not a product secret. `document.write` after decrypt is self-XSS of whatever that blob contains. Leave it unless you want the demo taken down.

### I3 — Info — HexGL vendor tree includes old jQuery / ACE / `tests.html`

`public/vendor/hexgl/libs/Editor_files/` and `bkcore.coffee/tests.html`. Extra dusty JS, not linked from the React HexGL wrapper as a first-class route. Games overhaul is out of scope; do not “clean” it in this PR.

### I4 — Info — Mixed content not observed

Live site and API are HTTPS. iOS `Link` targets are `https://beckify.com` and `mailto:`.

### I5 — Info — pnpm `minimumReleaseAge: 1440` is already a supply-chain control

`pnpm-workspace.yaml`. Keep it.

### I6 — Info — Website analytics vs iOS “no analytics”

Do not copy the iOS privacy sentence onto the website. GA (and AdSense when filled) collect visitor data on beckify.com. The native app still has no analytics SDK.

---

## iOS (`ios/`, bundle `com.beckify.toolbox`)

### (no high/critical)

ATS: no `NSAppTransportSecurity` / `NSAllowsArbitraryLoads` in the generated Info.plist keys — **default ATS (HTTPS only)**. Usage strings in `ios/Beckify.xcodeproj/project.pbxproj` match tools that actually call the APIs:

| Key | Used by | When requested |
| --- | --- | --- |
| `NSMicrophoneUsageDescription` | `NoiseMeterView` / `AVAudioApplication.requestRecordPermission` | `onAppear` of Noise Meter |
| `NSBluetoothAlwaysUsageDescription` + Peripheral | `BluetoothScannerView` creates `CBCentralManager` in `start()` | `onAppear` of BLE Scanner |
| `NSLocationWhenInUseUsageDescription` | `FieldPositionView`, `WiFiStatusView` | `onAppear` of those tools |

No camera, photos, tracking, or contacts strings. `PrivacyInfo.xcprivacy`: `NSPrivacyTracking` false, empty collected-data types, UserDefaults reason `CA92.1`. Matches `JobStore`.

No `WKWebView` / `UIWebView` / `SFSafariViewController` in Swift sources. About uses SwiftUI `Link` (system browser / mail). No `CFBundleURLTypes`.

`ITSAppUsesNonExemptEncryption = NO` already set in Debug and Release. Do not duplicate it.

### I7 — Info — Saved Jobs in UserDefaults (not Keychain)

**Evidence:** `ios/Beckify/Models/JobStore.swift`. Values are calculator/sensor snapshots the user chose to save.

**Impact:** Included in unencrypted iTunes/Finder backups and in iCloud backup if the user enables it. That is appropriate for notes and is already disclosed in `ios/docs/PRIVACY.md`. Moving to Keychain would be the wrong control (and can persist after delete). Optional later: `URLResourceValues.isExcludedFromBackup` only if Trevor wants jobs **not** to restore onto a new phone.

### I8 — Info — Search box on ToolboxView

Query filters an in-app catalog (`ToolboxCatalog.matching`). No injection surface into WebKit.

---

## CI / GitHub

Workflows reviewed: `deploy.yml`, `ios-math.yml` only. No other `.github` automations. Deploy already ran typecheck / lint / test before build (`c92ed35` era). `TDR_API_BASE_URL` and `VITE_AMAZON_ASSOCIATE_TAG` are **GitHub vars** (public associate tag is expected). Vision keys belong on Vercel, not in this repo — none were found in tree.

`ios-math.yml` already had `permissions: contents: read` and `persist-credentials: false`.

---

## Hardening in this PR

1. CSP + referrer metas on React `index.html`, toolbox, and both panel pages.  
2. Tesseract `5.1.1` + SHA-384 integrity on panel pages.  
3. TDR API base must be `https:`.  
4. Job “Open” restricted to same-origin `/toolbox` URLs.  
5. Panel OCR 12 MiB file cap.  
6. Toolbox SW cross-origin cache allow-list; `CACHE_VERSION` `v14`.  
7. Actions pinned to SHAs; checkout `persist-credentials: false`.  
8. Gear hrefs ignore non-http(s) URLs; toolbox doc links `noopener noreferrer`.

## Recommended later (not blocking)

- Durable TDR rate limit if `api.beckify.com` bills hurt.  
- Put HSTS / `frame-ancestors` in front of Pages (Cloudflare or similar) if clickjacking or first-visit SSL stripping ever matters.  
- Pin MathJax the same way as Tesseract.  
- Keep `minimumReleaseAge`.  
- After PR #26: confirm https://beckify.com/privacy returns 200 and matches `ios/docs/PRIVACY.md`.
