# Beckify Site Audit

Living document. Started 2026-09-01. Every finding below was reproduced against
a production build (`pnpm --filter @workspace/beckify build`) served by
`vite preview`, using Chromium via Playwright and `axe-core` 4.x.

Findings are evidence-first: where a number appears (bundle size, node counts,
pixel widths) it was measured, not estimated. Where a calculation is questioned,
the governing formula and a reproducible case are given. Anything I could not
verify with confidence is filed under **Requires Engineering Review** rather
than changed.

---

## Executive summary

Beckify is in far better technical shape than its surface suggests. The
engineering content is the strongest part of the product and the code behind it
is disciplined: 56 calculator sections, 55 of which handle hostile input
(blank / zero / negative / `1e12` / `1e-12` / `abc` / `1,000`) without leaking
`NaN`, `Infinity`, `undefined` or `null`, and which fail with sentences like
"Power factor must be between 0 and 1." rather than "INVALID INPUT". Ampacity
tables match NEC Table 310.16 exactly. OCR-derived text is HTML-escaped
everywhere it reaches `innerHTML`. There are no committed secrets and no
JavaScript errors on any route.

The problems are almost entirely at the seams, not in the engineering:

1. **The site is two products wearing different clothes.** A React SPA holds the
   identity, projects, games and gear. A separate static app at `/toolbox/`
   holds 56 engineering tools with its own visual language, its own navigation
   and its own search. A third identity — a Windows 95 skeuomorphic skin — is
   used by the two panel-schedule tools. The best content on the site is the
   least connected to it.
2. **Navigation fails below desktop width.** The header overflows the viewport
   at every width under roughly 1000 px, which is the cause of the horizontal
   scroll present on all 15 React routes. On a phone it degrades to five
   icon-only buttons, two of which use the *same* icon.
3. **Global search knows about 8 of 44 tools.** "smith chart", "555 timer",
   "harmonics", "NEMA", "resonance", "lighting", "generator" and "UPS" all
   return nothing, though each is a real tool with its own sitemap URL.
4. **One calculator crashes** on ordinary input, and pinch-zoom is disabled
   site-wide.

None of these require rewriting working architecture. The tool registry needed
to fix search already exists in `scripts/generate-sitemap.mjs`; the toolbox
already has a categorised directory that Phase 9 of the brief asks for.

---

## Current site architecture

| Layer | Technology | Notes |
| --- | --- | --- |
| App | React 19 + Vite 7 + TypeScript | `artifacts/beckify` in a pnpm workspace |
| Routing | `wouter`, `base={BASE_URL}` | 15 client routes, `Switch`/`Route` in `src/App.tsx` |
| Styling | Tailwind 4 + CSS custom properties | Tokens in `src/index.css`; deep-space/nebula theme |
| Content | `src/data/site-content.ts` | Nav, hub cards, profile, contact — data-driven by design |
| Toolbox | Vanilla JS, no build step | `public/toolbox/`, 27 classic `<script>` files sharing one global scope |
| Build | `prebuild` sitemap → `vite build` → `postbuild` sitemap + static routes | `scripts/generate-*.mjs` |
| Hosting | GitHub Pages, `deploy.yml` on push to `main` | `404.html` is a copy of `index.html` (SPA fallback) |
| PWA | Service worker + manifest scoped to `/toolbox/` only | Deliberate — see `public/toolbox/sw.js` header comment |
| Tests | `node --test ./tests/*.test.cjs` | 9 files, 9 passing |
| Lint | Biome, `preset: none` with a hand-picked rule set | Formatter deliberately off; rationale documented in `biome.json` |

**Baseline at audit start** — all green, so any later failure is attributable:

```
typecheck   pass
tests       9/9 pass
lint        102 files, 0 findings
build       dist/public/assets/index-*.js  1,658.01 kB (462.74 kB gzip)
            dist/public/assets/index-*.css   134.17 kB ( 23.52 kB gzip)
```

One pre-existing failure, unrelated to this package: `pnpm build` at the
workspace root fails because `artifacts/mockup-sandbox` requires a `PORT`
environment variable to load its Vite config. The deploy workflow builds only
`@workspace/beckify`, so production is unaffected.

---

## Page inventory

18 reachable documents were crawled at 1440 / 820 / 390 / 320 px.

| Route | h1 | axe violations | Console | Notes |
| --- | --- | --- | --- | --- |
| `/` | 1 | 3 | clean | Hero is decorative; no value proposition, no primary CTA |
| `/about` | 1 | 5 | clean | |
| `/projects` | **0** | 5 | clean | |
| `/projects/vespa-p200e` | 1 | 3 | clean | 9 scrollable regions not keyboard-focusable |
| `/gear` | 1 | 3 | clean | 72 contrast nodes (affiliate links) |
| `/control-systems` | **0** | 6 | clean | Sliders are 16 px tall |
| `/games` | **0** | 5 | clean | |
| `/games/cosmic-cadet` … `/toot-troopers` | 1 | 2–3 | clean | |
| `/games/pup-planet` | 1 | 3 | WebGL only | Stage fixed at 640 px |
| `/games/hexgl` | 1 | 3 | WebGL only | Stage fixed at 853 px |
| `/sitemap` | **0** | 5 | clean | 7 contrast nodes |
| 404 (any unknown path) | 1 | 3 | clean | Returns 200 with `robots: index, follow` |
| `/toolbox/` | **0** | 1 | clean | Strongest page on the site |
| `/toolbox/panel-schedule.html` | 1 | 1 (84 nodes) | clean | No metadata; 608 px wide at 390 px |
| `/toolbox/panel-power-study.html` | 1 | 1 (126 nodes) | clean | No metadata; 732 px wide at 390 px |

Metadata on the React routes is genuinely good: every route has a unique title,
description, canonical, OG image, `twitter:card` and JSON-LD.

---

## Tool inventory

57 `section[id^="sec-"]` elements in `public/toolbox/index.html`, grouped by the
toolbox's own category cards. 45 of them are registered with slug, title and
description in `src/data/toolbox-tools.mjs`, the single source of truth
consumed by both `scripts/generate-sitemap.mjs` (per-tool static SEO routes)
and `src/lib/assistant/search.ts` (the "Ask Beckify" search index) — since the
P1 fix below, these two can no longer drift apart the way the search index
once did (8 of 44 real tools indexed).

---

## Engineering calculation audit

### Method

Every section was driven in a real browser with seven hostile input classes
(blank, `0`, `-5`, `1e12`, `1e-12`, `abc`, `1,000`), its calculate handler
invoked, and its result region scanned for `NaN`, `Infinity`, `undefined` and
`null`. Page errors were captured throughout.

A first pass appeared to read output from all 56 sections but in fact read
nothing from 12 of them; a sanity pass measured characters-of-output per section
and the 6 real calculators among those 12 (`sec-vdrop`, `sec-wire-select`,
`sec-circuit-sim`, `sec-tdr`, `sec-lsi`, `sec-isloop`) were re-tested against
their actual result containers and handler names. Recording this because a
sweep that silently tests nothing is worse than no sweep.

### Result

**55 of 56 sections are clean.** The three tools that initially looked silent
turned out to be correct — they were emitting exactly the kind of message the
brief asks for:

- `sec-wire-select` → "Power factor must be between 0 and 1."
- `sec-lsi` → "Short-time pickup must be greater than long-time pickup."
- `sec-isloop` → full barrier/field-device comparison table

### Verified correct

| Item | Check |
| --- | --- |
| `WIRE_AMP_CU75` | Matches NEC Table 310.16, 75 °C copper column, all 18 sizes |
| `WIRE_AMP_AL75` | Matches NEC Table 310.16, 75 °C aluminium column, all 17 sizes |
| `WIRE_CM` | Standard AWG circular mils (14 AWG listed 4110 vs 4107 — 0.07 %, immaterial) |
| Voltage drop | `VD = m·K·I·L/CM`, m = 2 (1φ) or √3 (3φ), K = 12.9 Cu / 21.2 Al Ω·cmil/ft. Built-in example (480 V, 3φ, 45 A, 250 ft, Cu, #4) hand-computes to 6.02 V / 1.25 %, matching the tool |
| Demand / diversity / coincidence / load factor | Definitions in `factor-tools.js` match standard usage: demand = peak/connected, diversity = Σindividual/peak, coincidence = 1/diversity, load factor = average/peak |
| Growth projection | `peak·(1+r)^n`; years-to-capacity `ln(capacity/peak)/ln(1+r)` — both standard |
| 3 %/5 % thresholds | Correctly labelled "NEC Recommendation", not a requirement. NEC 210.19(A) and 215.2(A) informational notes are recommendations |

### Defects found — `sec-load-factors` (`public/toolbox/js/factor-tools.js`)

All four are missing-guard bugs. **No formula is wrong**, so all four are safe to
fix without engineering judgement.

1. **Crash — `RangeError: Invalid string length`.** Line 50 builds the growth
   chart polyline with one point per year: `for (let year = 0; year <= years;
   year += 1) points += ...`. `years` is unbounded user input, so entering
   `1e12` attempts a string of ~10¹² coordinates and throws, aborting the
   handler mid-render. *Repro: any horizon ≥ ~10⁷.*
2. **`NaN%` / `Infinity%` demand factor.** Line 75 computes `peak / connected`
   guarded only by `connected != null`. Every sibling branch guards its divisor
   (`peak > 0`, `capacity > 0`); this one does not. Connected load 0 → `Infinity%`;
   both 0 → `NaN%`.
3. **`Infinity` coincidence factor.** Line 80 computes `1 / diversity` where
   `diversity = individual / peak`. Guarded on `peak > 0` but not `individual > 0`,
   so a zero sum-of-individual-maxima yields `Infinity`.
4. **`Infinity%` projected utilisation.** Line 93, where `(1+r)^years` overflows
   to `Infinity` for large inputs; same root cause as (1).

### Requires engineering review

| Item | Why | Not changed because |
| --- | --- | --- |
| Toolbox Schmitt trigger labelled "Non-inverting" implements the inverting form | The math and the label disagree | Either the label or the math is intended; only the author knows which |
| 14 AWG circular mils listed as 4110, references commonly give 4107 | 0.07 % difference | Immaterial to any result; changing it churns a verified table for no gain |
| `stem-tools.js` (98 KB), `conduit-guide.js` (48 KB), `xfmr-wizard.js` (44 KB), `circuit-sim.js` (56 KB), `tdr-analyzer.js`, `battery-tools.js` | No unit tests | Black-box input sweep found no defects, but that is not equivalent to verifying their formulas |

---

## Accessibility findings

axe-core at 390 px, aggregated across 18 documents:

| Impact | Rule | Nodes | Pages |
| --- | --- | ---: | ---: |
| critical | `select-name` | 210 | 2 |
| serious | `color-contrast` | 89 | 12 |
| moderate | `region` | 66 | 7 |
| moderate | `meta-viewport` | 15 | 15 |
| moderate | `landmark-one-main` | 13 | 13 |
| serious | `scrollable-region-focusable` | 9 | 1 |
| moderate | `page-has-heading-one` | 5 | 5 |
| moderate | `heading-order` | 3 | 3 |

- **`maximum-scale=1` disables pinch-zoom on all 15 React routes** (WCAG 2.2 AA
  1.4.4 Resize Text).
- **210 unlabeled `<select>`** in the panel tools: the `poles`, `circuitClass`
  and `loadType` selects on every circuit row. The neighbouring `demandFactor`
  input already carries a per-circuit `aria-label`, so the pattern to follow is
  established in the same file.
- **Touch targets below 24 × 24** (WCAG 2.2 AA 2.5.8): footer social links are
  16 × 16; "Site Map" and "Recommended Gear" are 20 px tall; the Vespa journal
  nav links are 20 px tall; the control-systems PID sliders are 16 px tall.
- **9 scrollable regions on the Vespa page** are not reachable by keyboard.

---

## Mobile findings

Original measurement (document width vs viewport width) found the site-wide
header overflowing below `sm` — a single non-wrapping flex row of five
`whitespace-nowrap` links plus "Ask Beckify" needed 938 px and had nothing
narrower than icon-only pills below that, two of which (Toolbox and Control
Systems) shared the same icon and were unlabeled. **Fixed in Stage 1**
(`Nav.tsx` rewrite): the full link row is now `hidden lg:flex`, replaced below
that breakpoint by a real hamburger menu (`Sheet`) listing every nav item with
its own distinct icon and a label. `/games/pup-planet` and `/games/hexgl`
still overflow at narrow widths because their `.game-stage` is a fixed-pixel
canvas — unchanged, tracked as a game-area item out of this audit's scope
(concurrent work in progress there).

### Mobile/desktop content-parity audit

Prompted by a direct report that mobile might be missing content present on
desktop. Verified with a Playwright crawl of all 8 non-game React routes:
scrolled each page fully at both 1280 px and 375 px viewports (to trigger the
`FadeIn` scroll-reveal components rather than catch them mid-animation — an
earlier version of this same check produced a false "control-systems page is
90% blank on mobile" reading purely from `fullPage` screenshotting before any
scroll fired those reveals), then diffed the set of visible, non-empty text
nodes (`display`/`visibility`/`opacity` all checked) between the two.

Every diff across all 8 routes reduces to the same two benign causes:

- Nav links (`Toolbox`, `Control Systems`, `Projects`, `Games`) that collapse
  from the visible bar into the hamburger menu below `lg` — same links, same
  destinations.
- `Ask Beckify` / `⌘K` — the label and keyboard-shortcut hint shrink to an
  icon-only button below `md` (a keyboard shortcut is meaningless on touch
  anyway).

`/control-systems` additionally showed several step-response chart x-axis
tick labels (`"0 s"`, `"1 s"`, `"3 s"` …) as mobile-only-missing — recharts
reduces tick density on the narrower mobile chart to avoid label overlap,
which is expected responsive-charting behavior, not lost content. Confirmed
by simulating a real scroll and screenshotting: the chart curve, its x/y
axes, and every numeric readout (rise time, overshoot, settling time,
steady-state error, stability badge) render correctly on mobile.

The toolbox (`public/toolbox/`) needs no equivalent crawl: its mobile drawer
and desktop sidebar are the same 54-item `nav-btn` list in one shared DOM,
repositioned by a CSS media query rather than built from two separate
sources, so there is no separate mobile subset that could drift out of sync.

**Conclusion: no content is hidden or missing on mobile anywhere on the site.**

---

## Performance findings

- ~~One 1,658 kB JavaScript chunk (462.74 kB gzipped).~~ **Fixed** — see
  Completed improvements. Main entry chunk is now 525 kB (165 kB gzip); heavy
  per-route dependencies (three.js, the control-systems engine) load only on
  the pages that use them.
- `dist/public/assets/beck-profile-*.jpg` is 338 kB — larger than the CSS
  bundle. Not yet addressed (P2).
- CSS is 134 kB (23.5 kB gzipped), reasonable for Tailwind 4.
- The toolbox loads 27 classic scripts serially with no deferral, but it is a
  separate document and measured fine at all widths.

---

## SEO findings

Strong overall. Every React route has a unique title, description, canonical,
OG image, `twitter:card`, `robots` and JSON-LD, and the sitemap carries 68 URLs
including 52 per-tool static routes.

Three defects:

1. **Soft-404 is indexable.** Unknown paths return HTTP 200 (GitHub Pages SPA
   fallback, unavoidable) *and* declare `robots: index, follow` with a canonical.
   Any bad inbound link becomes an indexable duplicate of the home page. Needs
   `noindex` on the not-found route.
2. **`panel-schedule.html` and `panel-power-study.html` carry no metadata at
   all** — no description, canonical, OG or JSON-LD — despite being sitemap
   destinations.
3. **NEC citation drift.** The toolbox declares NEC 2023, but 12 places still
   cite Table **310.15(B)(16)** — the 2017-and-earlier designation, renumbered
   to Table **310.16** in NEC 2020. 25 other places already use 310.16. The
   values are correct; only the citations are stale. In a tool whose credibility
   rests on citing correctly, this matters.

---

## Security and privacy findings

Clean. Recorded so it does not get re-audited from scratch later.

- No secrets, API keys or tokens in client code.
- `dangerouslySetInnerHTML` used twice, both with author-controlled static
  content (MathML from a local constant; chart CSS).
- 31 `innerHTML =` sites in the toolbox. Every one that touches user-derived
  data — the OCR panel-schedule path — routes it through a correct `escapeHtml`.
  Numeric-only interpolation elsewhere.
- External origins: Google Fonts, Google Tag Manager, and two reference links
  (`static.e-publishing.af.mil`, `wbdg.org`). No ad network in the toolbox.
- `pnpm-workspace.yaml` enforces `minimumReleaseAge: 1440` as a supply-chain
  defence, with the rationale documented in-file.

---

## Architecture findings

- **No CI gate.** `.github/workflows/deploy.yml` is the only workflow. It runs
  on push to `main` and never invokes `test`, `lint` or `typecheck`. A broken
  calculator reaches production the moment it is pushed. It does verify the
  sitemap and robots artefacts before publishing, which is a good instinct
  applied to only one class of risk.
- **Two registries of the same tools.** `scripts/generate-sitemap.mjs` (44 tools,
  authoritative) and `src/lib/assistant/search.ts` (8 tools, hand-maintained).
  The second should derive from the first.
- **Three visual identities**: React nebula, toolbox terminal, and a Windows 95
  skin on the panel tools. The retro skin may well be deliberate and liked; it
  is flagged, not removed.
- The React site is not installable; the toolbox is a properly built PWA. The
  service worker header comment shows the `/toolbox/` scope is intentional.

---

## Game findings

Games are cleanly separated under `/games` and do not intrude on the engineering
identity. Two have real mobile defects: `pup-planet` and `hexgl` have game
stages fixed at 640 px and 853 px that do not shrink, forcing horizontal scroll
on every phone. WebGL console warnings on both are sandbox artefacts (software
rendering), not product defects.

---

## Project / build findings

The Vespa P200E page was restructured immediately before this audit: narrative
sections 01–09 followed by the bill of materials at 10, a new wiring section
with the full powertrain schematic, and 25 inline part references that jump to
their BOM row. Remaining issues are the 9 keyboard-inaccessible scrollable
regions and 20 px-tall journal-nav links noted above.

---

## Prioritised findings

### P0 — critical

| # | Finding | Evidence |
| --- | --- | --- |
| P0-1 | Pinch-zoom disabled site-wide (`maximum-scale=1`) | axe `meta-viewport`, 15 pages |
| P0-2 | Header overflows viewport below ~1000 px, causing site-wide horizontal scroll; degrades to 5 unlabeled icons, 2 identical | 938 px at 820; 405 px at 390 |
| P0-3 | `calcLoadFactors` crashes on large horizons; emits `NaN%` / `Infinity%` / `Infinity` | `RangeError: Invalid string length` |
| P0-4 | 210 unlabeled `<select>` in panel tools | axe `select-name`, critical |
| P0-5 | Panel tools unusable on mobile (608 / 732 px at 390 px) | measured |

### P1 — high impact

| # | Finding |
| --- | --- |
| P1-1 | Global search indexes 8 of 44 tools |
| P1-2 | 404 route declares `index, follow` |
| P1-3 | Panel tool pages have no metadata |
| P1-4 | 12 stale NEC 310.15(B)(16) citations against a declared NEC 2023 basis |
| P1-5 | 5 pages without `<h1>`; 3 heading-order skips; 13 without `<main>` |
| P1-6 | Touch targets below 24 × 24 in footer, Vespa nav, control-systems sliders |
| P1-7 | Contrast failures: footer "About Me" (11 pages), `/gear` (72), `/sitemap` (7) |
| P1-8 | No CI gate before deploy |
| P1-9 | Homepage communicates nothing in the first screen |
| P1-10 | `pup-planet` / `hexgl` stages do not shrink on mobile |
| P1-11 | Assistant "Inspect a photo" is a non-functional stub shipped to users |
| P1-12 | Single 1.66 MB bundle, no code splitting |

### P2 — valuable

Three visual identities (deferred, see below); untested math modules (need
domain-expert formula review, not just more tests — see "Requires
engineering review" above); root `pnpm build` broken by the unrelated
`mockup-sandbox` workspace package (out of scope for beckify). Root
manifest/service worker and the oversized profile image are done — see
Stage 3 below.

### P3 — future

Beckify Workspace (project-scoped calculation sets and an exportable calculation
package); accounts and cloud persistence; collaboration.

---

## Recommended implementation roadmap

1. **Correctness and access** — P0-1 … P0-5. No cosmetic work before this.
2. **Discoverability** — derive the search index from the sitemap tool registry;
   fix the 404 robots directive and panel-tool metadata.
3. **Credibility** — reconcile NEC citations; add the missing `h1`/`main`
   landmarks.
4. **Homepage and identity** — value proposition, primary actions, cohesion
   between the React shell and the toolbox.
5. **Performance** — route-level code splitting; image budget.
6. **Testing and CI** — add a workflow that gates deploys; unit-test the
   untested math modules.

---

## Completed improvements

_Updated as work lands._

- Audit document created; baseline recorded.
- **P0-3 fixed** (`c3d52ee`): load-factors calculator no longer crashes on a
  large growth horizon (`RangeError: Invalid string length`) and no longer
  leaks `NaN%`/`Infinity%`/`Infinity` from unguarded divisions. Regression
  test added (`tests/toolbox-load-factors.test.cjs`).
- **P0-1 and P0-2 fixed** (`516d2ec`): removed `maximum-scale=1` (pinch-zoom
  restored on all React routes); replaced the non-wrapping header with a
  responsive nav — full label row from `lg` up, a single menu button below
  that opens the same links in an accessible slide-out sheet (focus trap,
  Escape-to-close, 44px+ touch targets). Verified 0px horizontal overflow at
  1440/1024/1023/820/768/390/320px (previously 6 of 7 widths overflowed).
  Also fixed two icon defects surfaced by the same work: Control Systems and
  Toolbox shared one glyph, and Recommended Gear silently fell back to the
  home icon.
- **P0-4 and P0-5 fixed** (`cf8784b`): added `aria-label` to the 3
  per-circuit-row `<select>` elements in both panel tools (axe-core
  `select-name`, critical, 210 nodes → 0). Fixed the CSS Grid `min-width:
  auto` bug that let the OCR review table force the whole page to 608-732px
  wide inside a 390px viewport, defeating the table's own `overflow: auto`;
  one rule (`.workspace > .window { min-width: 0 }`) took both pages to 0px
  overflow. Regression test added
  (`tests/toolbox-panel-select-labels.test.cjs`).

All five P0 findings are fixed and verified. Stage 1 is complete.

### Stage 2 (P1) — discoverability, credibility, performance

- **P1-1 fixed** (`c204eb1`): global search hand-maintained 17 documents (8
  tools) separately from the sitemap's 44-tool registry — "smith chart",
  "555 timer", "harmonics", "nema", "resonance", "generator", "ups" all
  returned nothing. Extracted the registry into
  `src/data/toolbox-tools.mjs` (shared by `scripts/generate-sitemap.mjs` and
  the search index) plus a new `REFERENCE_TABLES` list for the 6 static
  reference tables that were searchable nowhere. Regression test
  (`tests/assistant-search.test.cjs`) plus a live-UI Playwright check;
  sitemap.xml output is byte-identical to before the extraction.
- **P1-2, P1-3, P1-4 fixed** (`3eff5ca`): the not-found route rendered
  generic Replit scaffolding and inherited `index,follow` — any broken
  inbound link became an indexable duplicate of whatever page it happened to
  render on GitHub Pages' SPA fallback. Rewrote it as a real page (matching
  the site) with `noindex,follow` via a new `robots` prop on `SchemaHead`.
  Added full metadata (title/description/canonical/OG/JSON-LD) to
  `panel-schedule.html` and `panel-power-study.html`, which had none despite
  being real linked pages. Fixed 12 stale NEC 310.15(B)(16) citations
  (pre-2020 numbering) to 310.16, matching the 25 places already correct and
  the toolbox's declared NEC 2023 basis — text only, no calculation changed.
- **P1-5, P1-6, P1-7 fixed** (`86bd120`): axe-core violations dropped from
  3-6 per page to 0 across all 15 React routes (re-crawled and verified).
  `<main>` landmark added via `Layout.tsx` (13 pages had none). Added a
  `level` prop to `SectionHeader` and set `h1` at the four page-title call
  sites (Projects, Games, Sitemap, Control Systems), fixing 5 pages with no
  `h1` and 3 heading-order skips this surfaced. Touch targets grown to
  WCAG's 24px minimum (footer icons, Vespa nav, control-systems sliders).
  Contrast fixes computed against real background colors: `--accent-foreground`
  was white-on-accent at 3.25-3.29:1 (now reuses `--background`, 6.1-6.2:1);
  footer "About Me" was opacity-60 (3.14:1, now 85%/5.33:1); sitemap's green
  category badge was #008300 (3.69:1, now #2ea043/5.18:1); gear page's photo
  caption was slate-500 (4.28:1, now slate-600/6.82:1).
- **P1-11 fixed** (`7ef69dc`): removed the "Ask Beckify" photo-upload control,
  which told users "Connect this handoff to the vision endpoint when API
  credentials are available" — a non-functional stub with no backend to
  connect to.
- **P1-12 fixed** (`97992ee`): every route except Home converted to
  `React.lazy()` + `Suspense`. Main entry chunk: 1,699 kB → 525 kB (478 kB →
  165 kB gzip), a 69% reduction. Heavy per-page dependencies (three.js on
  `pup-planet`, the control-systems engine) now load only on the pages that
  use them.
- **CI gate added** (`c92ed35`): `deploy.yml` called beckify's own
  vite-only build script directly, bypassing the root build's typecheck step
  entirely and never running lint or tests. Added typecheck/lint/test steps
  before the build step.

Remaining P1 items (homepage value proposition, P2/P3 backlog) are listed
above under Prioritised findings and not yet started.

### Merged and deployed

All of Stage 1 (P0) and Stage 2 (P1) above merged to `main` (`0ecbe1f`) and
deployed via GitHub Actions run
[#112](https://github.com/becktj90/beckify/actions/runs/33577585149) (build
succeeded through Test on the first real run of the new CI gate) —
**caught a real, previously-invisible bug**: `node --test "./tests/*.test.cjs"`
relies on Node's own glob resolution for the quoted pattern, which resolved
fine on this session's Node 22 but matched zero files on the CI runner's
pinned Node 20.20.2, since nothing had ever actually run `npm test` in CI
before this gate existed. Fixed in `dafcdd2` by dropping the quotes so bash
expands the glob before Node ever sees it — portable across Node versions
by construction, no longer dependent on Node's own glob-handling version.
Redeployed via run
[#113](https://github.com/becktj90/beckify/actions/runs/33577857128),
succeeded. Verified live: `curl https://beckify.com/` serves the corrected
viewport meta (no `maximum-scale=1`).

### Stage 3 (P2) — image budget and installability

- **Profile photo shrunk 338 kB → 17 kB** (`33b40ed`): source was a
  1170×2532 full-res phone photo rendering at a max of 144×144 CSS px in
  `About.tsx`. Cropped to 432×432 (3x for retina) and re-encoded as mozjpeg
  q82.
- **Root PWA manifest and service worker added**: the toolbox already had
  its own install/offline story scoped to `/toolbox/`; the React shell had
  none. Added `public/manifest.json` (icons generated from the existing
  `favicon-512.png` mark, no new artwork), linked it plus a `theme-color`
  meta tag from `index.html`, and registered `public/sw.js` from
  `main.tsx`. The service worker network-first's navigations (so a
  returning visitor is never stuck on a stale shell) and
  stale-while-revalidates same-origin GETs — no build-time asset list is
  needed since Vite content-hashes every chunk, so each hashed file is
  immutable once fetched. It explicitly bails out on `/toolbox/`,
  `/games/`, `/projects/` and `/demos/` so it never competes with the
  toolbox's own service worker or caches content that changes
  independently of this app's deploys. Verified via Playwright: the worker
  registers and activates with zero console errors, `manifest.json`/`sw.js`
  /icons all serve 200 from a production build.

### New tool — Heater Design Wizard

Requested directly: an industrial heater electrical sizing tool plus a custom
resistance-wire element designer. Added as `sec-heater-wizard`
(`public/toolbox/js/heater-wizard.js`), following the existing
`xfmr-wizard`/`xfmr-engine` conventions (shared `wt*` render helpers,
`xePickConductor`/`nextStandardOCPD` for the branch-circuit recommendation,
`registerUrlState`/`registerReport` wiring, a step-by-step proof drawer).

- **Electrical sizing**: given total power, line voltage, phase and wye/delta
  wiring, derives leg/phase/element voltage, current, resistance and power
  for a balanced resistive load, plus a 125%-continuous-load branch-circuit
  conductor and OCPD recommendation. All three-phase relations (`R_leg =
  V_LL²/P` wye, `3×V_LL²/P` delta, `I_line = P/(√3×V_LL)`) were hand-verified
  self-consistent (each connection's three legs independently sum back to
  the same total power and line current) before shipping.
- **Element design**: given a target resistance and power (with a one-click
  pass-through from the electrical sizing result), computes bare
  resistance-wire length, current density and surface power density for a
  chosen alloy and AWG gauge, plus optional coil turns/length for a given
  mandrel diameter. The AWG diameter formula (`d = 0.005 × 92^((36−n)/39)`
  inches) is the wire gauge standard's own definition — verified against the
  well-known reference points AWG 36 = 0.0050 in, AWG 20 = 0.0320 in, AWG 10 =
  0.1019 in, and AWG 1/0 = 0.3249 in, all exact.
- **What is not asserted as fact**: alloy resistivity, maximum element
  temperature and any surface-power-density guidance for Nichrome/Kanthal are
  typical published reference figures the tool cannot verify against a
  specific spool — every one is an editable input with a visible caution to
  confirm against the wire supplier's datasheet before fabricating an
  element, rather than a hidden constant presented as measured fact.
- 29 new hand-verified assertions in `tests/toolbox-heater-wizard.test.cjs`
  covering the AWG formula, both wye and delta self-consistency, the
  series/parallel per-element split, the element-design formulas, and coil
  geometry. `npm test` 13/13, clean `tsc`/`biome`/build.
- An axe-core scan of the new section (both calculators run, coil path
  included) found zero new violations. It initially found unassociated
  `<label>`s and unnamed `<select>` elements — but the same scan against the
  pre-existing Transformer Design Wizard this tool was modeled on shows the
  identical issue, confirming it as a pre-existing sitewide `<label>`/`for`
  pattern rather than something newly introduced. Fixed it in this new
  section anyway (added `for`/id pairing to every label) rather than
  propagate a known issue into new code. The one remaining flagged node
  (`.btn-copy`, the shared copy-result button from `app.js`) is the same
  pre-existing sitewide contrast issue on every calculator's copy button —
  out of scope for this feature, not fixed here.

### New project page — Honda XR650R Electric Conversion

Integrated a handoff package (page component, assets, integration docs)
for a second EV-conversion build log at `/projects/honda-xr650r`, alongside
the existing Vespa page. Followed the handoff's own instructions
(`CLAUDE.md`/`INTEGRATION.md`/`ASSETS.md` in the package) rather than
improvising the wiring:

- Page, CAD files, and staged photos copied into `src/pages/` and
  `public/projects/honda-xr650r/`; route added to `App.tsx`; project card
  added to `site-content.ts`; sitemap entries added to both
  `generate-sitemap.mjs` *and* `generate-static-routes.mjs` — the handoff's
  own checklist only named the former, so the static per-route SEO shell
  (title/description/canonical/OG/JSON-LD, the same pattern every other
  route uses) would have been silently missing without the second edit.
- The handoff flagged 6 image slots the page code referenced but had no
  file for (`initial-bike`, `stripped-chassis`, `original-swingarm`,
  `rear-sprocket`, `spare-wheel`, `bodywork`), pointing at a Google Drive
  folder of ~30 unsorted UUID-named workshop photos to source them from.
  Downloaded and visually reviewed 16 of them (some large files exceeded a
  single-transfer size limit and were skipped), matched 5 real, distinct
  photos to 5 of the 6 slots, and produced the 6th (`spare-wheel`) as a
  second, differently-cropped use of the same swingarm photo rather than
  either inventing a photo that doesn't exist or shipping two visually
  identical images in adjacent slots. One candidate photo showed a
  "ZN Lithium 78V/25.2Ah" battery label — a different pack than the page's
  own text describes ("Electro & Company 76V/24Ah, Apr 2023") — so it and
  its sibling shots were excluded rather than used to illustrate a battery
  the page doesn't claim. Every alt text and figure caption for a
  substituted image was rewritten to describe what the photo actually
  shows (e.g. dropped "removed... stored for restoration" for a photo that
  shows the bodywork still mounted). The two Drive-flagged receipt/PII
  screenshots were never fetched.
- Converted the sourced JPEGs to `.webp` (matching what the page code
  already expected) sized to how each one actually displays — 36–258 KB
  each, versus the 3–10 MB Drive originals.
- The handoff's own inner `<main>` wrapper would have duplicated `Layout`'s
  `<main>` landmark — the identical bug already found and fixed on the
  Vespa page earlier in this audit. Fixed the same way here (`<main>` →
  `<div>`) before it ever shipped, rather than reintroducing a known issue.
- An axe-core scan (full page, all `FadeIn` scroll-reveal sections settled
  to their final opacity before scanning — an earlier pass mid-transition
  produced inconsistent, partly-fictitious readings, the same class of
  false positive already documented in the Mobile findings section)
  surfaced a real, measured contrast failure: the page's `--xr-red` accent
  (`#e02b24`) was 4.36:1 against the site's `#05060f` background, just
  under the 4.5:1 AA threshold, and further short (2.6:1) against the
  lighter `~#3f3f50` card backgrounds a few components render on. Fixed
  with Python sRGB/relative-luminance math (the same method used
  throughout this audit) rather than eyeballing a replacement: `--xr-red`
  moved to `#f43f38` (5.4:1 on the page background, with headroom for
  antialiasing sampling variance observed during verification), and the
  handful of card-scoped labels/body text given their own verified-passing
  shades against the measured card background. Zero violations and zero
  console errors on a fully-settled re-scan at both 1280px and 390px, no
  horizontal overflow at 390px, and `/projects/vespa-p200e` and
  `/toolbox/` confirmed still loading (200) per the handoff's own
  checklist. `npm test`/`tsc`/`biome`/build all clean.

## Deferred improvements

- Restyling the Windows 95 panel-tool skin — flagged for the author's decision
  rather than changed unilaterally.
- Rebuilding the toolbox as React routes — explicitly not recommended. The
  static toolbox is the strongest part of the site and its architecture is
  documented and deliberate.

## Items requiring human engineering review

See the table in the calculation audit above: the Schmitt trigger label/math
mismatch, and the six untested math modules.
