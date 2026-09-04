/**
 * ============================================================================
 * SITE CONTENT
 * ============================================================================
 * This file is the single source of truth for everything you SEE on the
 * site: nav links, the home page hub cards, bio text, projects, contact
 * links, and the embedded game/toolbox URLs.
 *
 * You should almost never need to touch the component files in
 * `src/components/` or `src/pages/` to update content — just edit the
 * arrays and objects below, save, and the site updates automatically.
 *
 * See the root README.md for a full walkthrough with examples.
 * ============================================================================
 */

import {
  Terminal,
  Wifi,
  Wrench,
  Gamepad2,
  Rocket,
  Mail,
  Linkedin,
  Github,
  Youtube,
  Phone,
  Flag,
  Zap,
  type LucideIcon,
} from "lucide-react";

/** ------------------------------------------------------------------------
 * SITE-WIDE SETTINGS
 * -------------------------------------------------------------------- */
export const SITE_VERSION = "v3.0.0";

/** ------------------------------------------------------------------------
 * NAVIGATION
 * Top nav bar shown on every page. `href` is a route path (this site is
 * multi-page, not a single scrolling page).
 * -------------------------------------------------------------------- */
export interface NavLink {
  href: string;
  label: string;
  icon: LucideIcon;
  /**
   * The toolbox is a standalone app served from /toolbox/, not a React route,
   * so it needs a real navigation. Client-side routing to it would render a
   * React page instead of the actual toolbox.
   */
  external?: boolean;
}

export const NAV_LINKS: NavLink[] = [
  { href: "/toolbox/", label: "Toolbox", icon: Wrench, external: true },
  { href: "/control-systems", label: "Control Systems", icon: Zap },
  { href: "/projects", label: "Projects", icon: Rocket },
  { href: "/games", label: "Games", icon: Gamepad2 },
];

/** ------------------------------------------------------------------------
 * HOME PAGE HUB CARDS
 * The home page is a hub — a hero plus a grid of cards linking out to the
 * rest of the site. Add/remove/reorder cards here.
 * -------------------------------------------------------------------- */
export interface HubCard {
  title: string;
  description: string;
  href: string;
  icon: LucideIcon;
  /** See NavLink.external. */
  external?: boolean;
}

export const HOME_NAV_CARDS: HubCard[] = [
  {
    title: "Made in America",
    description: "Verified U.S.-made electrical hand tools with exact model numbers.",
    href: "/made-in-america",
    icon: Flag,
  },
  {
    title: "EE Toolbox",
    description: "Electrical calculators and quick-reference tools.",
    href: "/toolbox/",
    external: true,
    icon: Wrench,
  },
  {
    title: "Projects",
    description: "Vespa EV conversion, Sniffmaster, and other builds.",
    href: "/projects",
    icon: Rocket,
  },
  {
    title: "Games",
    description: "New Glenn Runner — a launch arcade in the browser. No ads.",
    href: "/games",
    icon: Gamepad2,
  },
  {
    title: "Control System Toolbox",
    description: "Model plants, compare open- vs closed-loop P, design lead and PID, and read Bode GM/PM/ωb.",
    href: "/control-systems",
    icon: Zap,
  },
];

/** ------------------------------------------------------------------------
 * SITE IDENTITY
 * How the site presents itself — nav, hero, metadata. Deliberately separate
 * from PROFILE: the site is branded "Beckify", not as a personal homepage.
 * PROFILE below is only for the About page, where the bio belongs.
 * -------------------------------------------------------------------- */
export const SITE = {
  name: "Beckify",
  tagline: "Engineering tools, references & builds",
};

/** ------------------------------------------------------------------------
 * PROFILE / ABOUT
 * Used only by the About page.
 * -------------------------------------------------------------------- */
export const PROFILE = {
  name: "Trevor Beck",
  title: "Electrical Engineer @ Blue Origin",
  education: "B.S. Electrical Engineering, Cal Poly",
  bio: "Electrical engineer at Blue Origin with a diverse background across aerospace, energy, and hands-on fabrication. Married to Sara, with two sons — Apollo and Rocco.",
};

/** ------------------------------------------------------------------------
 * CONTACT LINKS
 * Used on the About page and in the footer.
 * Set `external: true` for links that should open in a new tab.
 * -------------------------------------------------------------------- */
const EMAIL_ADDRESS = "trevorjohnbeck@gmail.com";
const PHONE_DISPLAY = "+1 (510) 432-4862";
const PHONE_TEL = "+15104324862";

export interface ContactLink {
  href: string;
  label: string;
  icon: LucideIcon;
  external: boolean;
}

export const CONTACT_LINKS: ContactLink[] = [
  { href: `mailto:${EMAIL_ADDRESS}`, label: EMAIL_ADDRESS, icon: Mail, external: false },
  { href: `tel:${PHONE_TEL}`, label: PHONE_DISPLAY, icon: Phone, external: false },
  { href: "https://www.linkedin.com/in/trevor-beck-892ab068", label: "LinkedIn", icon: Linkedin, external: true },
  { href: "https://github.com/becktj90", label: "GitHub", icon: Github, external: true },
  { href: "https://youtube.com/@trevorbeck7150", label: "YouTube", icon: Youtube, external: true },
];

/** ------------------------------------------------------------------------
 * PROJECTS
 * -------------------------------------------------------------------- *
 * Each project is a card that links OUT to where the real content lives
 * (an external write-up, forum thread, or hosted app) rather than
 * duplicating that content on this site. To add a new project, copy an
 * existing object below and edit it.
 * -------------------------------------------------------------------- */
export interface Project {
  name: string;
  description: string;
  url: string;
  icon: LucideIcon;
  /** Set for destinations hosted outside Beckify. */
  external?: boolean;
}

export const PROJECTS: Project[] = [
  {
    name: "Vespa P200E EV Conversion",
    description:
      "A 72V P200E conversion with a custom swingarm, hand-built battery pack, hub motor, and hard-earned lessons from the road.",
    url: "/projects/vespa-p200e",
    icon: Zap,
  },
  {
    name: "Honda XR650R Electric Conversion",
    description:
      "Build in progress — 76 V Electro & Company pack, QS 4 kW V3 mid-drive, and Votol EM-200/2 on the XR650R chassis. Public workshop journal.",
    url: "/projects/honda-xr650r",
    icon: Zap,
  },
  {
    name: "Sniffmaster",
    description: "An experimental web project. Enter at your own risk.",
    url: "https://sniffmaster-web.vercel.app",
    icon: Wifi,
    external: true,
  },
  {
    name: "LC-9 3/4 Power Distribution",
    description: "Protected internal-style power distribution dashboard. Sign in to view the dashboard.",
    url: "/demos/lc9-34/",
    icon: Terminal,
  },
];

/** ------------------------------------------------------------------------
 * TOOLBOX (embedded electrical calculators)
 * -------------------------------------------------------------------- */
export const TOOLBOX = {
  description:
    "Calculators and reference tools for facilities and electrical work, built into the site below.",
  embedUrl: "./toolbox/index.html",
};

/** ------------------------------------------------------------------------
 * GAMES
 *
 * Playable titles live under /games/<slug>, matching the hub Play Now
 * links. Set `external` for anything off beckify.com so it opens in a new tab.
 * -------------------------------------------------------------------- */
export interface Game {
  name: string;
  description: string;
  /** "#" renders a disabled "Coming Soon" card. */
  url: string;
  external?: boolean;
}

export const GAMES: Game[] = [
  {
    name: "New Glenn Runner",
    description:
      "A Phaser 4 launch arcade: charge liftoff at LC-36, dodge the corridor, then recover first stage on barge Jacklyn.",
    url: "/games/new-glenn-runner",
  },
];

// Legacy single-game export for backwards compatibility
export const GAME = GAMES[0];
