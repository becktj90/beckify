import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const dist = resolve(root, "dist/public");
const shell = resolve(dist, "index.html");

const escapeHtml = (value) => value.replaceAll("&", "&amp;").replaceAll('"', "&quot;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const staticRoutes = [
  ["about", "About Trevor Beck | Beckify", "Electrical engineering background, hands-on builds, and the purpose behind Beckify's practical engineering resources."],
  ["projects", "Engineering Projects and Build Logs | Beckify", "Engineering projects, conversion build logs, prototypes, and practical maker work from Beckify."],
  ["projects/vespa-p200e", "Vespa P200E EV Conversion | Beckify", "An engineering case study of a 1979 Vespa P200E electric conversion: 20S10P battery, protection, motor control, hub motor and custom swingarm."],
  ["gear", "Recommended Electrical Tools, Supplies & Field Gear | Beckify", "Direct model links for industry-standard tools, electrical test equipment, cable fault locators, jobsite supplies, field power, lighting, cooling, and USA-made choices."],
  ["made-in-america", "American-Made Electrical Tools & Supplies | Made in America | Beckify", "Find verified American-made electrical tools — Klein strippers, CHANNELLOCK pliers, Daniels crimp frames, and 3M tape. Exact models, manufacturer links, and sourcing notes for electricians."],
  ["control-systems", "Control System Toolbox | Beckify", "Model plants, inspect Bode and root-locus behavior, and compare PID, LQR, and MPC control workflows in an interactive browser toolbox."],
  ["games", "Browser Games | Beckify", "Browser games from Beckify, including arcade loops, a first-person voxel world, and HexGL."],
  ["games/cosmic-cadet", "Cosmic Cadet Browser Game | Beckify", "Play Cosmic Cadet, a responsive browser space shooter with keyboard, pointer, touch, waves, hull damage, pause, and fullscreen play."],
  ["games/booty-butt-scooter", "Booty Butt Scooter Browser Game | Beckify", "Play Booty Butt Scooter, a quick browser game with responsive controls and score tracking."],
  ["games/finger-runner", "Finger Runner Browser Game | Beckify", "Play Finger Runner, a touch-friendly endless browser runner with simple controls, persistent high scores, and quick arcade sessions."],
  ["games/toot-troopers", "Toot Troopers Browser Game | Beckify", "Play Toot Troopers, an original fart-powered flight game starring Apollo and Rocco."],
  ["games/pup-planet", "Pup Planet Browser Game | Beckify", "Play Pup Planet: pick Apollo or Rocco, the space pups, and mine and build on a seeded little planet in this first-person WebGL sandbox. Built big and simple for iPad."],
  ["games/hexgl", "HexGL Browser Game | Beckify", "Play HexGL, a futuristic WebGL racing game by Thibaut Despoulain (BKcore), hosted on Beckify under the MIT License."],
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
