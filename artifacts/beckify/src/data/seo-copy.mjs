/**
 * Discoverability copy: unique document titles and meta descriptions.
 *
 * Hub pages and the highest-traffic-worthy calculators get hand-written
 * titles so crawlers do not see a cloned "Beckify — …" / "… | Beckify"
 * template. Remaining toolbox routes use their registry title as-is
 * (already unique) without a site-name suffix.
 *
 * Consumed by SchemaHead callers, generate-sitemap.mjs, generate-static-routes.mjs,
 * and the home / toolbox / Vespa internal-link rows.
 *
 * Plain ESM (no TypeScript syntax) so Node scripts can import it directly.
 */

/** Highest-traffic-worthy calculators. Home, toolbox hub, and tool SEO pages link these. */
export const FEATURED_TOOLS = [
  { slug: "ohms-law", label: "Ohm's Law" },
  { slug: "voltage-drop", label: "Voltage drop" },
  { slug: "wire-size-ampacity", label: "Ampacity / wire size" },
  { slug: "conduit-fill", label: "Conduit fill" },
  { slug: "motor", label: "Motor FLA" },
  { slug: "conductor-length-resistance", label: "Conductor length" },
];

/** Extra crawl targets from the homepage toolbox tile (canonical SEO URLs). */
export const HOME_TOOLBOX_EXTRAS = [
  { slug: "transformer", label: "Transformer" },
  { slug: "short-circuit", label: "Short circuit" },
  { slug: "nec-circuit", label: "NEC circuit" },
  { slug: "battery-bank", label: "Battery bank" },
];

/** Calculators that actually apply to the Vespa conversion journal. */
export const VESPA_RELATED_TOOLS = [
  { slug: "battery-build-designer", label: "18650 pack designer" },
  { slug: "battery-bank", label: "Battery bank calculator" },
  { slug: "voltage-drop", label: "Voltage drop" },
  { slug: "wire-size-ampacity", label: "Ampacity / wire size" },
  { slug: "ohms-law", label: "Ohm's Law" },
  { slug: "motor", label: "Motor FLA" },
  { slug: "ebike-drivetrain", label: "E-bike drivetrain" },
];

export const FEATURED_TOOL_SLUGS = new Set(FEATURED_TOOLS.map((tool) => tool.slug));

/**
 * React + static-shell routes. Keys match SchemaHead `path` values
 * (no trailing slash except `/` and `/toolbox/`).
 */
export const PAGE_SEO = {
  "/": {
    title: "Beckify — electrical calculators, NEC references, and workshop builds",
    description:
      "Free electrical engineering calculators and NEC reference tables, plus workshop journals for a 1979 Vespa P200E conversion and other builds. Kestrel Heavy is the on-site arcade.",
  },
  "/toolbox/": {
    title: "Electrical engineering toolbox — Ohm's Law, voltage drop, ampacity, conduit fill",
    description:
      "Browser-based electrical calculators for Ohm's Law, voltage drop, wire ampacity, conduit fill, motor FLA, and field tools. No account. Verify results against the adopted code edition.",
  },
  "/about": {
    title: "Trevor Beck — electrical engineer behind Beckify",
    description:
      "Trevor Beck is an electrical engineer in aerospace. Beckify is his public set of field calculators, NEC references, and hands-on conversion journals.",
  },
  "/privacy": {
    title: "Beckify iOS privacy policy — Look Check, sensors, and Saved Jobs",
    description:
      "Privacy policy for the Beckify iOS and iPadOS app (bundle ID com.beckify.toolbox). Look Check uploads a photo only when you tap Analyze Look. Sensors and Saved Jobs stay on the device. No analytics, ads, tracking, or accounts.",
  },
  "/projects": {
    title: "EV conversions and engineering build logs",
    description:
      "Workshop journals for a 1979 Vespa P200E electric conversion, a Honda XR650R mid-drive in progress, and other Beckify engineering projects.",
  },
  "/projects/vespa-p200e": {
    title: "1979 Vespa P200E electric conversion — 72V workshop journal",
    description:
      "Workshop journal for converting a 1979 Vespa P200E to 72V electric power: 20S10P pack, VOTOL controller, QS hub motor, and a fabricated swingarm.",
  },
  "/projects/honda-xr650r": {
    title: "Honda XR650R electric conversion — 76 V workshop journal",
    description:
      "Public workshop journal for a Honda XR650R electric motorcycle conversion — 76 V pack, QS 4 kW V3 mid-drive, Votol EM-200/2. Build in progress.",
  },
  "/control-systems": {
    title: "Control system toolbox — PID, Bode, root locus, and state feedback",
    description:
      "Undergraduate servo analysis: pick an example plant or enter your own G(s), then tune PID, Bode margins, root locus, lead compensators, and state-feedback. Educational approximations — not for commissioning.",
  },
  "/games": {
    title: "Kestrel Heavy — Beckify browser games",
    description: "Play Kestrel Heavy, Beckify's on-site Pier 7 launch arcade. No ads, no install, local scores in this browser.",
  },
  "/games/kestrel-heavy": {
    title: "Play Kestrel Heavy — Pier 7 launch arcade",
    description:
      "Play Kestrel Heavy in the browser: launch from Pier 7 on KID, CADET, or PAD RAT difficulty, recover on barge Haven, and keep a local personal best. No install.",
  },
  "/sitemap": {
    title: "Beckify site map — every calculator, project, and page",
    description:
      "Browse every Beckify page, electrical engineering calculator, reference table, field test tool, project, and game from one list.",
  },
};

/** Static route directories written by generate-static-routes.mjs (no leading slash). */
export const STATIC_ROUTE_PATHS = [
  "about",
  "privacy",
  "projects",
  "projects/vespa-p200e",
  "projects/honda-xr650r",
  "control-systems",
  "games",
  "games/kestrel-heavy",
  "games/new-glenn-runner",
  "sitemap",
];

export const TOOL_SEO_TITLES = {
  "ohms-law": "Ohm's Law calculator — solve voltage, current, resistance, and power",
  "voltage-drop": "Voltage drop calculator — single-phase and three-phase feeders",
  "wire-size-ampacity": "Wire size and ampacity calculator — NEC Table 310.16",
  conductors: "Conductor sizing — ampacity, voltage drop, and I²R cost",
  "conduit-fill": "Conduit fill calculator — Chapter 9 areas and Table 1 limits",
  motor: "Motor FLA calculator — NEC Tables 430.248 and 430.250",
  "conductor-length-resistance": "Conductor length from resistance — milliohm reading to feet",
  transformer: "Transformer calculator — ratio, NEC 450.3(B) sizing, and conductors",
  "short-circuit": "Short-circuit current calculator — available fault from kVA and %Z",
  "nec-circuit": "NEC circuit calculator — branch-circuit conductor and OCPD sizing",
  "battery-bank": "Battery bank calculator — backup duration, strings, and C-rate",
  "battery-build-designer": "18650 battery pack designer — series-parallel layout and nickel strip",
  "ebike-drivetrain": "E-bike drivetrain calculator — torque, sprockets, speed, and range",
  "conduit-fill-mixed": "Mixed conduit fill calculator — EMT, PVC, IMC, and RMC",
  "motor-calculations": "Motor current calculator — HP, kW, and amps (formula mode)",
  "conductor-cost-optimizer": "Conductor cost optimizer — ampacity, parallels, and I²R energy",
};

export const CATEGORY_SEO_TITLES = {
  fundamentals: "Electrical fundamentals — Ohm's Law, power, and magnetic circuits",
  "ac-circuits": "AC circuit tools — reactance, transients, phasors, and power factor",
  distribution: "Power distribution calculators — conductors, conduit, and transformers",
  "power-systems": "On-site power tools — UPS, generator, solar, and facility load",
  "nec-calculations": "NEC calculation tools — circuits, ampacity, and raceway fill",
  "field-test-fault-locating": "Field test tools — TDR, nameplates, panel schedules, and meters",
  "reference-tables": "Electrical reference tables — ampacity, FLA, conduit, and NEMA",
};

export function pageSeo(path) {
  return PAGE_SEO[path] ?? null;
}

export function seoForStaticRoute(route) {
  if (route === "games/new-glenn-runner") return PAGE_SEO["/games/kestrel-heavy"];
  return PAGE_SEO[`/${route}`] ?? null;
}

export function toolDocumentTitle(slug, fallbackTitle) {
  return TOOL_SEO_TITLES[slug] ?? fallbackTitle;
}

export function categoryDocumentTitle(slug, fallbackTitle) {
  return CATEGORY_SEO_TITLES[slug] ?? fallbackTitle;
}

export function toolboxPermalink(slug) {
  return `/toolbox/${slug}/`;
}

export function homeToolboxLinks() {
  return [...FEATURED_TOOLS, ...HOME_TOOLBOX_EXTRAS];
}
