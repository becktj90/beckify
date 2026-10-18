import { PUBLIC_CALCULATOR_COUNT, resolveToolSlug } from "./toolbox-tools.mjs";

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
  { slug: "wire-size-ampacity", label: "Ampacity calculator" },
  { slug: "conduit-fill", label: "Conduit fill calculator" },
  { slug: "transformer-sizing", label: "Transformer fuse & breaker" },
  { slug: "photometrics", label: "Photometric calculator" },
  { slug: "voltage-drop", label: "Voltage drop calculator" },
  { slug: "ohms-law", label: "Ohm's Law calculator" },
  { slug: "motor", label: "Motor FLA calculator" },
  { slug: "conductor-length-resistance", label: "Conductor length" },
];

/** Extra crawl targets from the homepage toolbox tile (canonical SEO URLs). */
export const HOME_TOOLBOX_EXTRAS = [
  { slug: "transformer", label: "Transformer calculator" },
  { slug: "transformer-engine", label: "Transformer conductors" },
  { slug: "short-circuit", label: "Fault current calculator" },
  { slug: "nec-circuit", label: "NEC circuit calculator" },
  { slug: "battery-bank", label: "Battery bank" },
];

/** More homepage chips. Each slug has a real /toolbox/<slug>/ page. */
export const HOME_MORE_TOOLS = [
  { slug: "emp-emc-shielding", label: "EMP / EMC" },
  { slug: "magnetic-circuit", label: "Magnetic circuit" },
  { slug: "transient-circuits", label: "Transients" },
  { slug: "phasor-diagram", label: "Phasors" },
  { slug: "electronics-bench", label: "Breadboard generator" },
  { slug: "semiconductor-iv", label: "Semiconductor I-V" },
  { slug: "fiber-link", label: "Fiber / NA" },
  { slug: "gaussian-beam", label: "Gaussian beam" },
  { slug: "lp-optimizer", label: "LP optimizer" },
  { slug: "number-base-converter", label: "Number-base" },
  { slug: "battery-build-designer", label: "Battery pack designer" },
  { slug: "pitch-hum-identifier", label: "Pitch / hum" },
  { slug: "audio-spectrum-analyzer", label: "Audio spectrum" },
  { slug: "sound-level-meter", label: "Sound level" },
  { slug: "lux-light-meter", label: "Lux meter" },
];

/**
 * Old URLs that 404 in Search Console. GitHub Pages cannot 301 to another
 * path, so generate-static-routes.mjs writes a noindex refresh stub. These
 * paths stay out of the sitemap.
 */
export const RETIRED_REDIRECTS = [
  ["games/apollo-rocco-run", "/games/kestrel-heavy/"],
  ["games/booty-butt-scooter", "/games/kestrel-heavy/"],
  ["games/cosmic-cadet", "/games/kestrel-heavy/"],
  ["games/finger-runner", "/games/kestrel-heavy/"],
  ["games/hexgl", "/games/kestrel-heavy/"],
  ["games/pup-planet", "/games/kestrel-heavy/"],
  ["games/toot-troopers", "/games/kestrel-heavy/"],
  ["made-in-america", "/toolbox/"],
  ["toolbox/look-check", "/toolbox/"],
];

/** Calculators that actually apply to the Vespa conversion journal. */
export const VESPA_RELATED_TOOLS = [
  { slug: "battery-build-designer", label: "18650 pack designer" },
  { slug: "battery-bank", label: "Battery bank calculator" },
  { slug: "voltage-drop", label: "Voltage drop" },
  { slug: "wire-size-ampacity", label: "Wire size & ampacity" },
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
      `Free electrical calculators, NEC reference tables, and workshop build journals. ${PUBLIC_CALCULATOR_COUNT} field tools for electricians and engineers — no account needed.`,
  },
  "/toolbox/": {
    title: "Free electrical calculators — Ohm's Law, voltage drop, ampacity, conduit fill",
    description:
      `Free ampacity, conduit fill, and voltage drop calculators, plus Ohm's Law and transformer fuse sizing. ${PUBLIC_CALCULATOR_COUNT} tools, no signup.`,
  },
  "/about": {
    title: "Trevor Beck — electrical engineer behind Beckify",
    description:
      "Trevor Beck is an electrical engineer in aerospace. Beckify is his public set of field calculators, NEC references, and hands-on conversion journals.",
  },
  "/privacy": {
    title: "Beckify iOS privacy policy — photos, sensors, and Saved Jobs",
    description:
      "Privacy policy for the Beckify iOS and iPadOS app (bundle ID com.beckify.toolbox). Nameplate and panel photos upload only when you tap Analyze. Sensors and Saved Jobs stay on the device. No analytics, ads, tracking, or accounts.",
  },
  "/contact": {
    title: "Contact Beckify — email for the app, site, and shop",
    description:
      "How to reach Beckify by email about the iPhone and iPad app, the website, Kestrel Heavy, and orders from shop.beckify.com.",
  },
  "/apps": {
    title: "Beckify for iPhone and iPad — field electrical toolbox on the App Store",
    description:
      "Beckify is a native iPhone and iPad electrical toolbox: voltage drop, wire ampacity, conduit fill, motor FLA, and more. Free, no ads. Download on the App Store.",
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
    description:
      "Play Kestrel Heavy, Beckify's on-site Pier 7 launch arcade. Keyboard or touch, no ads, no install, local scores in this browser.",
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
  "contact",
  "apps",
  "projects",
  "projects/vespa-p200e",
  "projects/honda-xr650r",
  "control-systems",
  "games",
  "games/kestrel-heavy",
  "games/new-glenn-runner",
  // Legacy redirects only (see generate-static-routes.mjs). Not in sitemap.
  "gear",
  "products",
  "shop",
  "store",
  "sitemap",
  "toolbox",
  ...RETIRED_REDIRECTS.map(([route]) => route),
];

export const TOOL_SEO_TITLES = {
  "ohms-law": "Ohm's Law calculator — free voltage, current, resistance, and power",
  "voltage-drop": "Voltage drop calculator — free NEC feeder check, no signup",
  "wire-size-ampacity": "Ampacity calculator — free NEC Table 310.16 wire size",
  conductors: "Ampacity calculator — free conductor size, voltage drop, and cost",
  "conduit-fill": "Conduit fill calculator — free NEC Chapter 9 check",
  motor: "Motor FLA calculator — free NEC Tables 430.248 and 430.250",
  "conductor-length-resistance": "Conductor length calculator — feet from a milliohm reading",
  transformer: "Transformer calculator — free kVA, current, and NEC 450.3(B)",
  "transformer-sizing": "Transformer primary fuse and breaker sizing — NEC 450.3(B)",
  "transformer-engine": "Transformer conductor and breaker sizing — free NEC check",
  "transformer-design": "Transformer connection guide — delta-wye, high-leg, and fault current",
  "short-circuit": "Transformer fault current calculator — free from kVA and %Z",
  "nec-circuit": "NEC circuit calculator — free conductor and breaker size",
  "battery-bank": "Battery bank calculator — free backup hours, strings, and C-rate",
  "battery-build-designer": "18650 battery pack designer — free series-parallel layout",
  "electronics-bench": "Breadboard generator — free circuit schematic and hookup",
  "lightning-protection": "Lightning protection calculator — free NFPA 780 terminals and down conductors",
  "receptacle-circuit": "Receptacle circuit calculator — free outlets per circuit and voltage drop",
  "equipment-ground": "Equipment grounding conductor calculator — free NEC 250.122 table",
  "resistor-color-code": "Resistor color code calculator — free 4 and 5 band decoder",
  "motor-speed": "Motor speed and slip calculator — free synchronous RPM and torque",
  "adc-dac": "ADC and DAC calculator — free LSB, SNR and Nyquist",
  "instrumentation-amp": "Instrumentation amplifier calculator — free gain from Rg",
  "linear-regulator": "Linear regulator calculator — free LM317 Vout and heat",
  "noise-snr": "Noise and SNR calculator — free Johnson noise and signal-to-noise",
  "ebike-drivetrain": "E-bike calculator — free torque, sprockets, speed, and range",
  "conduit-fill-mixed": "Mixed conduit fill calculator — free EMT, PVC, IMC, and RMC",
  "motor-calculations": "Motor current calculator — free HP, kW, and amps",
  "conductor-cost-optimizer": "Conductor cost calculator — free ampacity and I²R check",
  photometrics: "Photometric calculator — free lighting level estimate",
};

/** Meta descriptions. Query phrase first, then the benefit, NEC cite, and no signup. */
export const TOOL_SEO_DESCRIPTIONS = {
  "ohms-law": "Free Ohm's Law calculator. Enter any two of voltage, current, and resistance to get the third, plus watts. No signup.",
  "voltage-drop": "Free voltage drop calculator for single-phase and three-phase feeders. NEC Chapter 9 K-method, with the 3% and 5% design notes and a worked example. No signup.",
  "wire-size-ampacity": "Free ampacity calculator for copper and aluminum. NEC Table 310.16, temperature and bundling adjustments, then a voltage-drop check. No signup.",
  conductors: "Free ampacity calculator that also checks voltage drop and I²R cost for copper or aluminum runs. NEC Table 310.16. No signup.",
  "conduit-fill": "Free conduit fill calculator for EMT, PVC, IMC, and RMC. NEC Chapter 9 Table 1 limits, with a worked example. No signup.",
  motor: "Free motor FLA calculator using NEC Tables 430.248 and 430.250. Table amps are what you use for conductor and breaker sizing. No signup.",
  "conductor-length-resistance": "Free conductor length calculator. Enter gauge and a milliohm reading to get feet of copper or aluminum. No signup.",
  transformer: "Free transformer calculator for turns ratio, line current, and primary fuse or breaker sizing under NEC Table 450.3(B). No signup.",
  "transformer-sizing": "Size a transformer primary fuse or breaker with NEC Table 450.3(B), Note 1, and the next standard rating. Free, with a worked example. No signup.",
  "transformer-engine": "Free transformer conductor and breaker sizing for primary and secondary current, equipment ground, voltage drop, and conduit. No signup.",
  "transformer-design": "Free transformer connection guide for delta-wye, high-leg versus corner-grounded delta, and a %Z fault estimate. No signup.",
  "short-circuit": "Free transformer fault-current calculator from kVA, voltage, and percent impedance. A planning estimate, not an arc-flash study. No signup.",
  "nec-circuit": "Free NEC circuit calculator for load current, conductor ampacity, voltage drop, and the overcurrent device. No signup.",
  "battery-bank": "Free battery bank calculator for backup hours, series strings, and C-rate. No signup.",
  "battery-build-designer": "Free 18650 pack designer for series-parallel layout, C-rate, and nickel-strip current. No signup.",
  "noise-snr": "Free noise and SNR calculator for Johnson noise, shot noise, amplifier e_n and i_n, and total referred noise. No signup.",
  "linear-regulator": "Free LM317 and LDO calculator for output voltage, R2, dropout margin, power dissipation, and junction temperature. No signup.",
  "instrumentation-amp": "Free instrumentation amplifier calculator for gain from Rg, difference-amp gain, output swing, and common-mode range. No signup.",
  "adc-dac": "Free ADC and DAC calculator for LSB size, code count, ideal quantization SNR, Nyquist frequency, and DAC voltage. No signup.",
  "motor-speed": "Free induction motor calculator for synchronous speed, slip, slip frequency and shaft torque from horsepower. No signup.",
  "resistor-color-code": "Free resistor color code calculator. Decode 4-band and 5-band resistors or find the bands for any value. No signup.",
  "equipment-ground": "Free NEC Table 250.122 calculator for the minimum equipment grounding conductor from OCPD rating, copper or aluminum. No signup.",
  "receptacle-circuit": "Free calculator for how many receptacles fit on a 15 or 20 A circuit (NEC 220.14(I)) with conductor and voltage-drop checks. No signup.",
  "lightning-protection": "Free NFPA 780 lightning protection planner: strike terminals, down conductors, rolling sphere and separation distance. No signup.",
  "electronics-bench": "Free breadboard generator and circuit bench. Solve a circuit, then see its schematic and a solderless hookup with banded resistors. No signup.",
  "ebike-drivetrain": "Free e-bike calculator for torque, sprocket ratio, speed, and range. No signup.",
  "conduit-fill-mixed": "Free mixed conduit fill calculator for different wire sizes in EMT, PVC, IMC, or RMC. NEC Chapter 9. No signup.",
  "motor-calculations": "Free motor current calculator for horsepower, kilowatts, and amps. For conductor and breaker sizing, use the NEC FLA tables. No signup.",
  "conductor-cost-optimizer": "Free conductor cost calculator comparing ampacity, parallel runs, and I²R energy. No signup.",
  photometrics: "Free photometric calculator for average illuminance from lumens, room area, and light loss. A design check, not a full lighting layout. No signup.",
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
  const retired = RETIRED_REDIRECTS.find(([from]) => from === route);
  if (retired) return retired[1].startsWith("/games/") ? PAGE_SEO["/games/kestrel-heavy"] : PAGE_SEO["/toolbox/"];
  if (route === "shop" || route === "store") return { title: "Beckify Shop", description: "Electrical engineering and math inspired goods from Beckify." };
  if (route === "toolbox" || route === "gear" || route === "products") {
    return PAGE_SEO["/toolbox/"];
  }
  return PAGE_SEO[`/${route}`] ?? null;
}

export function toolDocumentTitle(slug, fallbackTitle) {
  return TOOL_SEO_TITLES[slug] ?? fallbackTitle;
}

export function toolDocumentDescription(slug, fallbackDescription) {
  return TOOL_SEO_DESCRIPTIONS[slug] ?? fallbackDescription;
}

export function categoryDocumentTitle(slug, fallbackTitle) {
  return CATEGORY_SEO_TITLES[slug] ?? fallbackTitle;
}

export function toolboxPermalink(slug) {
  const resolved = resolveToolSlug(slug);
  const path = `/toolbox/${slug}/`;
  return resolved?.anchor ? `${path}#${resolved.anchor}` : path;
}

export function homeToolboxLinks() {
  return [...FEATURED_TOOLS, ...HOME_TOOLBOX_EXTRAS];
}
