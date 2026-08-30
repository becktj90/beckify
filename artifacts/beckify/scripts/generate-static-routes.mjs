import { copyFile, mkdir } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const dist = resolve(root, "dist/public");
const shell = resolve(dist, "index.html");

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
  "games/finger-runner",
  "sitemap",
];

await Promise.all(routes.map(async (route) => {
  const directory = resolve(dist, route);
  await mkdir(directory, { recursive: true });
  await copyFile(shell, resolve(directory, "index.html"));
}));
