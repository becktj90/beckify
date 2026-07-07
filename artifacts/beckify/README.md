# Beckify — Maintenance Guide

This is Trevor Beck's personal site, framed as an **engineering resource hub**
(not a scrolling portfolio). It's a React + Vite app, but the goal of this
structure is that you should be able to make almost all content changes
**without touching component code** — just edit one data file.

## Site structure

The home page (`/`) is a hub: a hero, then a grid of cards that link out to
the rest of the site.

```
/           Home — hero + hub cards
/about      Bio, family photos, contact links
/toolbox    Embedded electrical calculators
/projects   Project cards that link OUT to where the work actually lives
            (endless-sphere thread, hosted app, etc.) — not duplicated here
/games      Embedded game
```

## Directory layout

```
artifacts/beckify/
├── README.md                      ← you are here
├── public/
│   └── toolbox/                   ← the embedded electrical toolbox (self-contained HTML app)
└── src/
    ├── data/
    │   └── site-content.ts        ← ALL page content lives here (text, links, projects, etc.)
    ├── components/
    │   ├── FadeIn.tsx             ← shared scroll-in animation wrapper
    │   ├── SectionHeader.tsx      ← shared section title component
    │   ├── Starfield.tsx          ← fixed starfield + nebula-glow backdrop
    │   ├── Layout.tsx             ← shared shell (starfield + nav + footer) for inner pages
    │   └── sections/              ← one file per reusable content block
    │       ├── Nav.tsx
    │       ├── About.tsx
    │       ├── Projects.tsx
    │       ├── Toolbox.tsx
    │       ├── Games.tsx
    │       ├── Contact.tsx
    │       └── Footer.tsx
    ├── pages/                     ← one file per route, composes sections + Layout
    │   ├── home.tsx               ← hero + hub cards (has its own layout, no Layout.tsx)
    │   ├── about.tsx
    │   ├── toolbox.tsx
    │   ├── projects.tsx
    │   ├── games.tsx
    │   └── not-found.tsx
    ├── assets/                    ← images (profile photo, family photos, logo)
    ├── App.tsx                    ← defines routes (wouter) — one <Route> per page
    └── index.css                  ← design tokens (colors, fonts, spacing, shadows, starfield)
```

## How the styling system works

All colors, fonts, and shared visual tokens are defined once, at the top of
`src/index.css`, as CSS variables inside `:root`. The theme is **deep-space /
nebula**: near-black background, glowing violet-to-blue accent, starfield
backdrop.

```css
:root {
  --background: #05060f;
  --surface: rgba(255, 255, 255, 0.035);
  --foreground: #eef0fa;
  --muted: #9497b8;
  --border: rgba(255, 255, 255, 0.09);
  --accent: #8b7bff;     /* violet — buttons, links, active nav state */
  --accent-2: #4f8bff;   /* blue — used with --accent in gradients */
}
```

Want to change the accent colors? Change `--accent` / `--accent-2` in that
one file — every button, link, badge, gradient headline, and glow that uses
them updates automatically.

Fonts work the same way, defined in the `@theme inline` block right above
`:root`. Swap the Google Fonts URL at the top of the file and update
`--font-sans` / `--font-display` to change the typeface site-wide.

The starfield backdrop (`.starfield`, `.nebula-glow`) is also defined in
`index.css` and rendered once per page via `<Starfield />` — it's pure CSS
(layered radial gradients), no canvas or JS animation loop, so it's cheap to
render on every page.

Section components use a shared `.card-surface` utility class (also defined
in `index.css`) for the consistent glassy-card-with-border-and-glow look
used throughout the site.

## How to add new content (no code changes needed)

Open `src/data/site-content.ts`. Every page reads from an array or object in
that file. Here's a concrete example — **adding a new project card**:

```ts
// src/data/site-content.ts

export const PROJECTS: Project[] = [
  {
    name: "Vespa P200E EV Conversion",
    description: "Converting a P200E to electric...",
    url: "https://endless-sphere.com/sphere/threads/vespa-p200e-ev-conversion.113986/",
    icon: Zap,
  },
  // 👇 just add a new object here to add a new project card
  {
    name: "My New Project",
    description: "A short description of what it does, and where to read more.",
    url: "https://example.com",
    icon: Wifi, // pick any icon already imported at the top of the file
  },
];
```

Projects are meant to **link out** to wherever the real write-up lives
(a forum thread, GitHub repo, hosted app) rather than duplicating that
content on this site — keep the description short.

Save the file — the Projects page automatically renders a new card. The same
pattern applies to:

- `NAV_LINKS` — add/remove/reorder the top navigation (route paths)
- `HOME_NAV_CARDS` — add/remove/reorder the hub cards on the home page
- `CONTACT_LINKS` — add/remove a contact method (shown on About page + footer)
- `PROFILE` — change your name, title, education, or bio text
- `TOOLBOX.embedUrl` / `GAME.embedUrl` — swap which embedded app/game is shown

## Adding a brand-new page

1. Add the page's content data to `src/data/site-content.ts`.
2. Create a new section component in `src/components/sections/` (or reuse an
   existing one), following the pattern in `Toolbox.tsx` (import data from
   `site-content.ts`, wrap content in `<FadeIn>`, use `<SectionHeader>`).
3. Create a new file in `src/pages/`, e.g. `writing.tsx`:
   ```tsx
   import { Layout } from "@/components/Layout";
   import { Writing as WritingSection } from "@/components/sections/Writing";

   export default function WritingPage() {
     return (
       <Layout>
         <WritingSection />
       </Layout>
     );
   }
   ```
4. Register the route in `src/App.tsx` (`<Route path="/writing" component={WritingPage} />`).
5. Add a matching entry to `NAV_LINKS` and/or `HOME_NAV_CARDS` in
   `site-content.ts` with `href: "/writing"`.

## Icons

Icons come from [lucide-react](https://lucide.dev/icons). Import any icon by
name at the top of `site-content.ts` and reference it in your data — no need
to touch component files.
