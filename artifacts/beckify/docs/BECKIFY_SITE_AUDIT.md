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

56 `section[id^="sec-"]` elements in `public/toolbox/index.html`, grouped by the
toolbox's own category cards. 44 of them are registered with slug, title and
description in `scripts/generate-sitemap.mjs`, which emits 52 per-tool static
routes plus 7 category routes into the sitemap (68 URLs total).

The site-wide command palette (`src/lib/assistant/search.ts`) indexes **17
documents, of which 8 are tools**. The gap between those two registries is the
single highest-leverage discoverability fix available.

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

Measured document width vs viewport width:

| Route | 820 px | 390 px | 320 px | Cause |
| --- | --- | --- | --- | --- |
| All 15 React routes | 938 | 405 | 405 | Fixed header content wider than viewport |
| `/games/pup-planet` | 1048 | 664 | 664 | `.game-stage` fixed 640 px |
| `/games/hexgl` | 1126 | 877 | 877 | `.game-stage` fixed 853 px |
| `/toolbox/panel-schedule.html` | ok | 608 | 608 | `section.window` fixed width |
| `/toolbox/panel-power-study.html` | ok | 732 | 732 | `section.window` fixed width |
| `/toolbox/` | ok | ok | ok | — |

The header is the site-wide cause. It is a single non-wrapping flex row holding
a logo, an "Ask Beckify" button and five links with `whitespace-nowrap`. At
820 px the labels are still shown and the row needs 938 px. Below `sm` the
labels are hidden (`hidden sm:inline`) leaving five icon-only pills — and
`NAV_ICON_NAMES` maps both **Toolbox** and **Control Systems** to the same
`toolbox` icon, so two of the five are visually identical and unlabeled.

The two panel tools are the ones that most need to work on a phone — they exist
to be used standing in front of a panel — and they are the least usable there.

---

## Performance findings

- **One 1,658 kB JavaScript chunk** (462.74 kB gzipped). No code splitting: a
  visitor opening the voltage-drop calculator downloads every game, the control
  systems engine, `three`, `recharts` and `tesseract.js`.
- `dist/public/assets/beck-profile-*.jpg` is 338 kB — larger than the CSS bundle.
- CSS is 134 kB (23.5 kB gzipped), reasonable for Tailwind 4.
- The toolbox loads 27 classic scripts serially with no deferral, but it is a
  separate document and measured fine at all widths.

No before/after performance numbers are claimed in this document yet; nothing
has been optimised.

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

Three visual identities; untested math modules; no root manifest/service worker;
`/gear` 338 kB profile image; root `pnpm build` broken by `mockup-sandbox`.

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

## Deferred improvements

- Restyling the Windows 95 panel-tool skin — flagged for the author's decision
  rather than changed unilaterally.
- Rebuilding the toolbox as React routes — explicitly not recommended. The
  static toolbox is the strongest part of the site and its architecture is
  documented and deliberate.

## Items requiring human engineering review

See the table in the calculation audit above: the Schmitt trigger label/math
mismatch, and the six untested math modules.
