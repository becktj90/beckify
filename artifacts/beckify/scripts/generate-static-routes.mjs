import { copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const dist = resolve(root, "dist/public");
const shell = resolve(dist, "index.html");

const gearDescription = "Direct model links for professional electrical test equipment: multimeters, clamp meters, insulation testers, hand tools, oscilloscopes, cable testers, RF analyzers, and budget picks.";
const gearSchema = JSON.stringify({
  "@context": "https://schema.org",
  "@type": "CollectionPage",
  name: "Recommended Electrical Test Equipment and Tools for Professionals",
  description: gearDescription,
  url: "https://beckify.com/gear",
  about: ["electrical test equipment", "electrical hand tools", "multimeters", "clamp meters", "insulation testing", "oscilloscopes", "RF test equipment"],
});

// The app sets page metadata after hydration, but this static entry also gives
// search and sharing crawlers the route-specific information immediately.
const gearShell = (await readFile(shell, "utf8"))
  .replace(/<title>[^<]*<\/title>/, "<title>Recommended Electrical Test Equipment &amp; Tools | Beckify</title>")
  .replace(/<meta name="description" content="[^"]*"\s*\/>/, `<meta name="description" content="${gearDescription}" />`)
  .replace(/<link rel="canonical" href="[^"]*"\s*\/>/, '<link rel="canonical" href="https://beckify.com/gear" />')
  .replace(/<meta property="og:title" content="[^"]*"\s*\/>/, '<meta property="og:title" content="Recommended Electrical Test Equipment &amp; Tools | Beckify" />')
  .replace(/<meta property="og:description" content="[^"]*"\s*\/>/, `<meta property="og:description" content="${gearDescription}" />`)
  .replace(/<meta property="og:url" content="[^"]*"\s*\/>/, '<meta property="og:url" content="https://beckify.com/gear" />')
  .replace(/<meta name="twitter:title" content="[^"]*"\s*\/>/, '<meta name="twitter:title" content="Recommended Electrical Test Equipment &amp; Tools | Beckify" />')
  .replace(/<meta name="twitter:description" content="[^"]*"\s*\/>/, `<meta name="twitter:description" content="${gearDescription}" />`)
  .replace("</head>", `<script type="application/ld+json">${gearSchema}</script></head>`);

// GitHub Pages serves 404.html with a 404 status. Give every React route its
// own entry file so direct links return 200 while the client router selects
// the correct page after hydration.
const routes = [
  "about",
  "projects",
  "projects/vespa-p200e",
  "gear",
  "games",
  "games/cosmic-cadet",
  "games/booty-butt-scooter",
  "games/finger-runner",
  "sitemap",
];

await Promise.all(routes.map(async (route) => {
  const directory = resolve(dist, route);
  await mkdir(directory, { recursive: true });
  if (route === "gear") {
    await writeFile(resolve(directory, "index.html"), gearShell);
    return;
  }
  await copyFile(shell, resolve(directory, "index.html"));
}));
