import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const dist = resolve(root, "dist/public");
const shell = resolve(dist, "index.html");

const escapeHtml = (value) => value.replaceAll("&", "&amp;").replaceAll('"', "&quot;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const staticRoutes = [
  ["about", "About Trevor Beck | Beckify", "Electrical engineering background, hands-on builds, and the purpose behind Beckify's practical engineering resources."],
  ["privacy", "Privacy Policy | Beckify iOS", "Privacy policy for the Beckify iOS and iPadOS app (bundle ID com.beckify.toolbox). Data Not Collected. Sensor readings and Saved Jobs stay on the device. No analytics, ads, tracking, or accounts."],
  ["projects", "Engineering Projects and Build Logs | Beckify", "Engineering projects, conversion build logs, prototypes, and practical maker work from Beckify."],
  ["projects/vespa-p200e", "Vespa P200E EV Conversion | Beckify", "An engineering case study of a 1979 Vespa P200E electric conversion: 20S10P battery, protection, motor control, hub motor and custom swingarm."],
  ["projects/honda-xr650r", "Honda XR650R Electric Conversion | Beckify", "A public workshop journal for a Honda XR650R electric motorcycle conversion — 76 V pack, QS 4 kW V3 mid-drive, Votol EM-200/2. Build in progress."],
  ["gear", "Recommended Electrical Tools, Supplies & Field Gear | Beckify", "Direct model links for industry-standard tools, electrical test equipment, cable fault locators, jobsite supplies, field power, lighting, cooling, and USA-made choices."],
  ["made-in-america", "American-Made Electrical Tools & Supplies | Made in America | Beckify", "Find verified American-made electrical tools — Klein strippers, CHANNELLOCK pliers, Daniels crimp frames, and 3M tape. Exact models, manufacturer links, and sourcing notes for electricians."],
  ["control-systems", "Control System Toolbox | Beckify", "Undergraduate servo analysis: plant modeling, open- vs closed-loop P control, root locus, lead compensators, PID with Ziegler–Nichols and anti-windup, Bode GM/PM/ωb, and state-feedback pole placement."],
  ["games", "Browser Games | Beckify", "Browser games from Beckify, including arcade loops and a first-person voxel world."],
  ["games/cosmic-cadet", "Cosmic Cadet Browser Game | Beckify", "Play Cosmic Cadet, a responsive browser space shooter with keyboard, pointer, touch, waves, hull damage, pause, and fullscreen play."],
  ["games/booty-butt-scooter", "Booty Butt Scooter Browser Game | Beckify", "Play Booty Butt Scooter, a quick browser game with responsive controls and score tracking."],
  ["games/finger-runner", "Finger Runner Browser Game | Beckify", "Play Finger Runner, a touch-friendly endless browser runner with simple controls, persistent high scores, and quick arcade sessions."],
  ["games/toot-troopers", "Toot Troopers Browser Game | Beckify", "Play Toot Troopers, an original fart-powered flight game starring Apollo and Rocco."],
  ["games/apollo-rocco-run", "Apollo & Rocco Run Browser Game | Beckify", "Play Apollo & Rocco Run, a backyard water-balloon runner starring Apollo (orange balloon) and Rocco (pink balloon)."],
  ["games/pup-planet", "Pup Planet Browser Game | Beckify", "Play Pup Planet: pick Apollo or Rocco and mine and build on a seeded little planet in this first-person WebGL sandbox. Built big and simple for iPad."],
  ["games/new-glenn-runner", "New Glenn Runner Browser Game | Beckify", "Play New Glenn Runner, a stylized vertical launch arcade with KID, CADET, and PAD RAT difficulty and local scoring."],
  ["sitemap", "Beckify Site Map | Engineering Tools and Projects", "Browse every Beckify page, electrical engineering calculator, reference table, field test tool, project, and game."],
];

// The app sets page metadata after hydration, but route-specific static HTML
// lets crawlers and link previews identify the requested page before JavaScript.
const routeShell = (source, route, title, description) => {
  const canonicalUrl = `https://beckify.com/${route}`;
  const encodedTitle = escapeHtml(title);
  const encodedDescription = escapeHtml(description);
  const schema = JSON.stringify({
    "@context": "https://schema.org",
    "@type": route === "gear" ? "CollectionPage" : "WebPage",
    name: title,
    description,
    url: canonicalUrl,
    isPartOf: { "@type": "WebSite", name: "Beckify", url: "https://beckify.com/" },
  });
  return source
    .replace(/<title>[^<]*<\/title>/, `<title>${encodedTitle}</title>`)
    .replace(/<meta name="description" content="[^"]*"\s*\/>/, `<meta name="description" content="${encodedDescription}" />`)
    .replace(/<link rel="canonical" href="[^"]*"\s*\/>/, `<link rel="canonical" href="${canonicalUrl}" />`)
    .replace(/<meta property="og:title" content="[^"]*"\s*\/>/, `<meta property="og:title" content="${encodedTitle}" />`)
    .replace(/<meta property="og:description" content="[^"]*"\s*\/>/, `<meta property="og:description" content="${encodedDescription}" />`)
    .replace(/<meta property="og:url" content="[^"]*"\s*\/>/, `<meta property="og:url" content="${canonicalUrl}" />`)
    .replace(/<meta name="twitter:title" content="[^"]*"\s*\/>/, `<meta name="twitter:title" content="${encodedTitle}" />`)
    .replace(/<meta name="twitter:description" content="[^"]*"\s*\/>/, `<meta name="twitter:description" content="${encodedDescription}" />`)
    .replace("</head>", `<script type="application/ld+json">${schema}</script></head>`);
};

// GitHub Pages serves 404.html with a 404 status. Give every React route its
// own entry file so direct links return 200 while the client router selects
// the correct page after hydration.
const appShell = await readFile(shell, "utf8");
await Promise.all(staticRoutes.map(async ([route, title, description]) => {
  const directory = resolve(dist, route);
  await mkdir(directory, { recursive: true });
  await writeFile(resolve(directory, "index.html"), routeShell(appShell, route, title, description));
}));

// App Store Connect needs a public HTTPS policy that is readable even if a
// crawler does not execute JavaScript. Inject the markdown source as a
// noscript fallback on the privacy route only.
const privacyHtmlPath = resolve(dist, "privacy", "index.html");
const privacySource = await readFile(resolve(root, "../../ios/docs/PRIVACY.md"), "utf8");
const privacyHtml = await readFile(privacyHtmlPath, "utf8");
const privacyFallback = `<noscript><article id="privacy-policy" style="max-width:48rem;margin:2rem auto;padding:1.25rem;color:#eef0fa;font:16px/1.6 system-ui,sans-serif;white-space:pre-wrap">${escapeHtml(privacySource)}</article></noscript>`;
await writeFile(privacyHtmlPath, privacyHtml.replace("</body>", `${privacyFallback}</body>`));
