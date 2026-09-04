# Five-star readiness — Beckify iOS

Jobsite-first checklist for App Store v1. Soft launch / **Prepare for Submission**. App ID `6807908745`. Free, no IAP, no ads. White tunnel icon. Use the **ITMS-90382 upload cooldown** (retry after ~2026-09-05 with a **new** `(MARKETING_VERSION, CURRENT_PROJECT_VERSION)` tuple) to finish this list — do not burn the cooldown on a duplicate binary.

Listing copy, nutrition-label facts, and screenshot sizes stay in [`APP_STORE.md`](APP_STORE.md). Privacy text stays in [`PRIVACY.md`](PRIVACY.md). This file is the **rating and review-risk** plan.

Public sources only. No App Store Connect scrape. No password.

## Executive snapshot

**Already strong (would support 5★ if the binary matches the listing):**

- Free v1 — the #1 1★ pattern in this category is paywall / “NEC year behind an IAP” / “I can Google this.”
- Honest RF instruments: **no fabricated Wi‑Fi or cellular dBm / RSRP**. Reviewers and App Review both punish fake meters.
- Design-aid disclaimer on every tool. Not a PE stamp, not a calibrated SLM, not a TDR.
- Permissions only when the tool opens — not at launch. Photo Library full access is not requested.
- No analytics, no crash SDK, no account, no ads. Look Check uploads a photo only after Analyze Look.
- Field opens first. Cold start hides Recents. Favorites and Jobs empty states now send the operator back to Field.
- Conduit fill already has mixed sizes **and** the nipple 60% toggle (Ch. 9 Table 1 Note 4) — the exact miss that got Southwire a “this app will lie to you” 1★.
- Motor Nameplate OCR: on-device Vision, human confirm, MOCP/LRA never treated as FLA.
- Panel Directory: on-device Vision, photo stays on screen, human confirm, demand/capacity-to-add is a design aid (trip ≠ measured load).
- iPhone **and** iPad (`TARGETED_DEVICE_FAMILY` 1,2). Do not claim iPad if screenshots are iPhone-only.

**Would block 5★ (or a clean review) if we ship sloppy:**

- Inaccurate NEC math (conduit fill, ampacity derate, Ohm’s Law). One inspector-failed pull becomes a 1★ that sits on the product page forever.
- Listing / screenshot / What’s New that overclaims Cellular Path, Wi‑Fi dBm, OCR accuracy, or outdoor glare.
- Permission surprise (mic / Local Network / location) without the usage string matching the tool.
- Review nag on first launch or a custom “Rate us 5 stars” sheet (Ugly’s lost stars for this; Apple rejects custom prompts under 5.6.1 and early-onboarding asks under 5.6.3).
- Broken OCR presented as truth. Confirm-before-save is the mitigation — keep it visible.
- Crashes on first Calculate / Continue (Electrician’s Helper pattern). No crash SDK: **you** are the quality gate.
- ITMS-90382 retry of the same version/build tuple.

---

## First-open / trust punch list (App Design)

Folded from the optional 5★ first-open list. Status is against **this branch** (on top of latest `main`). Do not block the competitor crawl on more design input.

| # | Gate | Status | Where / what’s left |
| --- | --- | --- | --- |
| 1 | **No review prompt** on first launch, after a permission deny, or mid-Calculate. Gate on a clear win (saved job). | **Done** | `ReviewAskPolicy` + `ReviewAskStore`: 2 session days, ≥12 h, 2 saved jobs. Never from `onAppear`, Save, or Calculate. `SettingsLinkButton` / deny path calls `notePermissionDenied()` and **blocks the sheet for the rest of that session**. Mac: confirm first launch is silent (dev builds always *can* show the sheet if called). |
| 2 | **Cold start useful, not empty theater.** Recents hidden until used. | **Done** (PR #87, verified) | `ToolGridView`: Recents render only when `!recents.tools.isEmpty`. `RecentToolsStore` does not seed fake tools. First-open Field home is the jobsite grid. Favorites + Jobs empty states have **Browse Field**. |
| 3 | **Sensor honesty before the big number** + screenshot honesty (no fake Wi‑Fi/cellular dBm/RSRP). | **Done** in-app / **Todo** shots | Cellular already had a banner above the gauges. Wi‑Fi Path now uses the same `RFHonestyBanner` **above** `WiFiStrengthGauge`. Listing/What’s New/Review notes already forbid invented dBm. **Todo (Mac):** screenshots must show the honesty line, not a crop that looks like a field-strength meter. |
| 4 | **Permissions on tool open only**; denied → Settings; don’t block Toolbox home. | **Done** | No permission call in `BeckifyApp` / Field home. Mic, BT, location (Position, Wi‑Fi Path), camera (OCR) request in-tool. Deny states use `ToolEmptyState` + `SettingsLinkButton`. Solar latitude deny now also offers Settings and still accepts typed lat. Toolbox home stays usable if every instrument is denied. **Todo (Mac):** deny each sheet once and confirm Field home still opens. LAN RTT copy mentions Local Network; public hosts (1.1.1.1) skip that sheet. |
| 5 | **Jobsite friction:** Done keyboard, 44pt segments, outdoor contrast. | **Mostly done** / **Todo** listing | `Theme.touchTarget` = 44. Field \| Toolkit segments are `.controlSize(.large)` + `minHeight: 44`. `NumberField` uses decimal pad; `ToolScaffold` now has a keyboard **Done** bar (decimal pad has no system Done). Tokens are built for bright field light + dark shop. **Todo:** do **not** claim a dedicated outdoor/high-contrast mode on the listing. Optional device check: Settings → Display → Increase Contrast. |
| 6 | **Icon / listing match chrome.** No outdoor, calibrated, or Jobs-restore claims unless true. | **Done** in copy / **Todo** Connect | Icon: white tunnel on black (`APP_STORE.md`). Jobs: “Open in tool” restores **matching** inputs and **does not block** if some fields cannot map (`JobsView` hint). Noise Meter / sensors: uncalibrated. **Todo (Connect):** screenshots and What’s New must match — no “calibrated SLM,” no “full job restore,” no outdoor mode. |
| 7 | **Design-aid disclaimer on calculators**, not only About. | **Done** | There is no About screen. `ToolScaffold` defaults to `Theme.disclaimer` (“Design aid only — not a PE stamp…”). Sensors use `Theme.sensorDisclaimer`. Extra honesty on OCR, conduit/cost/length, Control Systems, e-bike pack, etc. Reference Library is the intentional `.none` (it’s a table, not a calc). |

---

## 1. Competitor complaints → Beckify mitigations

Crawled public App Store review pages and review-mirror sites for Southwire Conduit Fill Calc, Ugly’s Electrical References, Electrical Calc Elite, Electric Toolkit, and Electrician’s Helper (2026-09-04). Themes below are what field EEs actually write.

| What they praise / hate | Public signal | Beckify now | Still todo (Trevor / Mac) |
| --- | --- | --- | --- |
| **Wrong conduit fill / nipple 60%** | Southwire 1★: nipple between panels calculated 56% vs hand 67% / 60% max; inspector called it. Electrician’s Helper: XHHW-2 vs Table 5 mismatch; missing bare wire. | Mixed Ch. 9 Table 4/5 fill; **Nipple ≤ 24 in (60%)** toggle; design-aid banner. Tests cover nipple area. | On device: one mixed pull + one nipple vs the book. If a size/insulation is missing, say so in the tool — do not silently substitute. Bare / Table 5A is a later add if operators ask. |
| **Inaccurate everyday math** | Electrical Calc Elite 1★: 9 W / 120 V shown as 0.043 A (should be 0.075 A). Derate “still unable.” | Explicit Calculate; Ohm’s Law needs two of three; no silent guess on blanks (`CalcError.missing`). | Run Ohm’s Law, VD, 310.16 ampacity, Motor FLA on a physical device. Compare one worked example to the handbook. |
| **Paywall / paid NEC year / “Google is free”** | Elite IAP for NEC 2023; Electric Toolkit $5.99 with broken keys → “robbed.” | v1 is **$0**, no StoreKit products, no ads. | Do not add IAP or a paid price in Connect. What’s New: “No ads, no IAP.” |
| **Review nag every launch** | Ugly’s: “unless I leave a review, every single time I open the app…” (lost 3★). | System `requestReview` only, after a **returning** session + a clear win (see §3). Never first launch. | Confirm in Simulator (dev builds always show the sheet) that first launch is silent. |
| **Search doesn’t find the table** | Ugly’s: article numbers and table titles miss. | Search covers Field + Toolkit and labels the area. Ampacity / wifi / cellular / milliohm footers. | Type the keyword list from `APP_STORE.md` on device. If a shipped tool doesn’t appear, that’s a 1★. |
| **Crashes / stuck Continue** | Electrician’s Helper: crash after selecting conduit. Elite: “equal sign doesn’t work.” | Linux math tests; stale-result banner instead of silent overwrite. | Mac: Calculate / Reset / Example on Field jobsite tools + Cellular / Wi‑Fi Path + OCR. |
| **Broken or bait OCR** | Category risk (not a single app): garbage fields saved as truth. | Confirm marks reviewed. MOCP/LRA ≠ FLA. Cloud VLM **off**. Photo not uploaded. | Screenshot must show the confirm step, not a magic “done” plate. |
| **Permission / privacy surprise** | Utility-app Review rejections: missing usage strings; location at launch; nutrition label vs an SDK. | Usage strings in the target; location/mic/BT/Local Network/camera only in-tool; `PrivacyInfo.xcprivacy` declares Photos only for Look Check Analyze Look (not linked, not tracking). | Connect nutrition label = **Photos** (App Functionality). Review notes must say Analyze Look is user-initiated and nameplate/panel stay on-device. |
| **iPad claim without iPad UI** | Guideline 2.3 / 2.4: metadata must match. Several paid toolkits are “Designed for iPad” and then feel like stretched phone. | Target is iPhone + iPad. Adaptive grid. | Capture a **13" iPad** screenshot set. If you skip iPad shots, do not market iPad-only features. |
| **Outdoor glare / forced dark** | Operators use phones in sun. Claiming “high contrast outdoor mode” you don’t have is a 2.3 risk. | Follows system light/dark. No forced dark. `APP_STORE.md` already forbids overclaim. | Ship system-appearance shots. Optional: Settings → Display → Increase Contrast on a glare check — don’t put it on the listing. |
| **Fake RF meters** | Users **and** Review will roast a “dBm” number iOS does not give third parties. | Wi‑Fi: 0…1 `signalStrength` as %/bars + TCP RTT. Cellular: RAT generation + TCP RTT. No invented RSRP. | Screenshots: gauges labeled generation / RTT ms. Review notes paste the honesty paragraph. |

Sources (public):

- [Southwire Conduit Fill Calc reviews](https://apps.apple.com/us/app/southwire-conduit-fill-calc/id509204523?see-all=reviews)
- [Ugly’s Electrical References reviews](https://apps.apple.com/us/app/uglys-electrical-references/id1134770838?see-all=reviews)
- [Electrical Calc Elite](https://apps.apple.com/us/app/electrical-calc-elite/id510284903) / [negative-review mirror](https://appsupports.co/510284903/electrical-calc-elite/negative-reviews)
- [Electric Toolkit](https://apps.apple.com/us/app/electric-toolkit-calculator/id516862639) / [negative-review mirror](https://appsupports.co/516862639/electric-toolkit-calculator/negative-reviews)
- Electrician’s Helper review excerpts via public customer-service mirrors
- Apple: [Requesting App Store reviews](https://developer.apple.com/documentation/storekit/requesting-app-store-reviews), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) 2.3, 5.1.1, 5.6.1–5.6.4, [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

---

## 2. Pre-submit checklist (Connect + binary)

Do these on a Mac after the ITMS-90382 window. This environment cannot archive or upload.

### Privacy nutrition label

- [ ] App Privacy = **Photos** for Look Check Analyze Look (matches [`PRIVACY.md`](PRIVACY.md) and `PrivacyInfo.xcprivacy`). Not linked. Not tracking.
- [ ] Do **not** declare Location / Microphone as collected: they are processed on device and never leave. Photos are collected only after Analyze Look.
- [ ] Tracking = No. No advertising SDKs to declare. Look Check may forward a user-initiated photo through the Beckify API to OpenAI/Anthropic.
- [ ] Privacy Policy URL live: https://beckify.com/privacy
- [ ] Usage strings (already in the Xcode target) match the Review notes: mic = Noise Meter dBFS; location = Position / Wi‑Fi Path / optional Solar latitude; Local Network = TCP RTT to a LAN host; camera = Motor Nameplate OCR, Panel Directory, and Look Check; Bluetooth = BLE scanner.

### Listing

- [ ] Name **Beckify**, subtitle **Field EE toolbox**, category Productivity (Utilities secondary OK).
- [ ] Price **Free**. No IAP. Age 4+.
- [ ] Support + Marketing: https://beckify.com. Copyright 2026 Trevor Beck.
- [ ] Description matches the catalog in [`APP_STORE.md`](APP_STORE.md) — including **Cellular Path**, **Conductor Length by Resistance**, and field instruments. Do not list website-only studios (LQR / Kalman / MPC).
- [ ] Keywords ≤ 100 characters (draft in `APP_STORE.md`).
- [ ] Promotional text keeps “design aid — not a PE stamp.”

### What’s New (paste into Connect)

Use the draft already in `APP_STORE.md`. Keep all four honesty clauses:

1. Cellular Path gauges are **radio generation + TCP RTT**, not RSRP/dBm.
2. Wi‑Fi Path is **percent/bars + TCP RTT**, not dBm.
3. Conductor Length is a milliohm estimate — **not a TDR**.
4. Control Systems Ziegler–Nichols is educational — **not commissioning**.

### Screenshots

- [ ] 6.9" (or 6.5") iPhone **and** 13" iPad. 3–8 each. **No website shots.**
- [ ] First-open Field home: no Recents, no fake tool-count pills.
- [ ] One plot + Share. One OCR **confirm** frame. One Cellular Path frame that cannot be read as a signal-bar meter.
- [ ] System light or dark — do not require dark-only. Do not claim outdoor mode.

### App Review notes (paste)

Suggested block:

> Beckify is a native SwiftUI field electrical toolbox (not a web wrapper). Free, no ads, no IAP, no account, no analytics. Saved Jobs and last-used inputs stay in UserDefaults on device.
>
> Permissions are requested only when that instrument or OCR tool is opened — not at launch. Microphone = uncalibrated Noise Meter (dBFS, not an SLM). Location When In Use = Position, Wi‑Fi Path (SSID / Apple 0–1 signalStrength / optional heatmap), optional Solar latitude. Local Network = optional TCP RTT to a LAN/gateway host (latency, not RF). Camera = Motor Nameplate OCR and Panel Directory (Vision on device; photos never upload) or Look Check (uploads only after Analyze Look). Photo Library full access is not requested. Bluetooth = BLE scanner.
>
> iOS does not expose Wi‑Fi RSSI/dBm or cellular RSRP/RSRQ/SINR/dBm to third-party apps. The Wi‑Fi and Cellular Path tools do not invent those numbers. Cellular color gauges are radio generation (from RAT) and TCP RTT milliseconds.
>
> NEC tools are a design aid citing table numbers (310.16, 430.248/250, Ch. 9 Tables 1/4/5, 450.3(B)). Not a PE stamp or a substitute for the code book.
>
> Encryption: ITSAppUsesNonExemptEncryption = NO (HTTPS links only).

### Support / review hygiene

- [ ] `mailto:trevorjohnbeck@gmail.com` works. Reply to 1★ with a fix, not a pitch (Guideline 5.6.1).
- [ ] DPLA accepted if Connect still flags it.
- [ ] Export compliance answered **No** (standard HTTPS exemption only).

### Binary / ITMS-90382

- [ ] After ~2026-09-05, upload **once** with a unique version/build. ITMS-90382 here is Apple’s “upload limit reached — wait 1 day,” usually from repeating the same tuple or hammering Transporter.
- [ ] Do not bump marketing version just to spam uploads. `1.0` / `CURRENT_PROJECT_VERSION` increment is enough if 1.0 (1) already consumed the limit.
- [ ] This is still **not** TestFlight distribution and **not** Submit for Review until screenshots + notes are attached.

---

## 3. In-app rating prompt (wired)

Apple: use the system API only (5.6.1). Max **3** sheets per user per 365 days — StoreKit enforces that. Never a custom star dialog. Never on first launch (HIG + 5.6.3 discovery-fraud pattern). Never from a button tap (`requestReview` may no-op; don’t hang UX on it).

Beckify implementation (this PR):

| Piece | Behavior |
| --- | --- |
| `ReviewAskPolicy` (BeckifyMath, tested on Linux) | Ask only if **2+ distinct UTC session days**, **≥ 12 h** since first launch, **this marketing version not already prompted**, and a **clear win**. |
| Clear win (policy) | **2 saved jobs**, or **1 save + 5 successful Calculate**, or **8 successful Calculate** with no save. |
| Clear win (v1 wiring) | **Saved jobs only** — `JobStore.save` increments the counter. Calculate-without-save does not arm a prompt (that would fire from a button tap). Calc-count thresholds stay in the policy for a later hook. |
| When the sheet is considered | Operator **returns to Field home** (pops the tool stack) or **switches back to the Toolbox tab** — end of a sequence. 2 s delay. |
| When it never fires | First `onAppear`, first calendar session, first 12 hours, Save tap, Calculate tap, **this session after a permission deny** (`notePermissionDenied`), TestFlight (Apple no-ops there). |

`import StoreKit` is for `RequestReviewAction` only. There is still **no** IAP target and **no** StoreKit product.

Optional later (not shipped): a quiet “Rate Beckify” row that opens `https://apps.apple.com/app/id6807908745?action=write-review` — user-initiated, Apple-approved. Do not add a “Rate us 5 stars” banner.

---

## 4. Crash / quality gates before asking for reviews

Do **not** enable the review ask in your own head (or rely on soft-launch testers) until these pass. The in-app policy already waits for a returning day; this section is the human gate.

1. **Math:** `cd ios/BeckifyMath && swift test` green on this repo (includes `ReviewAskPolicyTests`).
2. **Device smoke (Mac + phone):** cold launch → Field home → Voltage Drop or Ampacity Calculate → save a named job → Conductor Length milliohm example → Cellular Path (honest empty RSRP) → Wi‑Fi Path (no dBm row) → Nameplate OCR confirm → Jobs tab shows the note → Favorites star round-trip.
3. **iPad:** Field | Toolkit, search, one plot Share, Jobs empty “Browse Field.”
4. **Permissions:** first open of Noise Meter / Position / BLE / OCR / Wi‑Fi RTT-to-LAN each shows **one** system sheet with the Beckify string. Deny paths stay usable (blank reading + Settings link where we already have it).
5. **No prompt on first launch.** Dev builds always show the StoreKit sheet *if called* — confirm we do **not** call it on first open.
6. **No crash reporter** by design. If a tester hits a crash, fix it before Submit. A 1★ crash review on day one is expensive.

---

## 5. Honesty constraints (review-risk reducers)

Keep these. They are product, listing, and Review armor:

- No fake Wi‑Fi RSSI/dBm. No fake cellular RSRP/RSRQ/SINR/dBm.
- TCP RTT is not ICMP ping. LAN target may prompt Local Network; public hosts (1.1.1.1) should not.
- CTCarrier may be empty (deprecated iOS 16+). Leave blanks blank.
- Noise Meter is uncalibrated dBFS, not OSHA/SLM.
- Conductor Cost is planning $/kft, not LME or a bid.
- Conductor Length is not a cable locator or TDR.
- OCR is a suggestion; human confirm; nothing uploaded.
- Every tool: design aid, not a PE stamp or calibrated instrument.
- App follows system appearance. Do not claim outdoor/high-contrast mode.

---

## 6. First-open bounce

See **First-open / trust punch list** above (items 2, 4, 7). Cold Field home hides Recents until used. Favorites and Jobs empty states send the operator back to Field. Do not add an onboarding carousel. Field EE brand is instrument panel, not tutorial chrome.

---

## 7. Soft-launch order (after cooldown)

1. Unique build upload. Wait for processing.
2. Attach screenshots + What’s New + Review notes + nutrition label.
3. Internal device pass of §4.
4. Submit for Review (Trevor). Do not merge this as “we submitted.”
5. After release: reply to reviews; only then does the in-app ask start to matter. First-week testers will not see it (12 h + second session day). That is intentional.
