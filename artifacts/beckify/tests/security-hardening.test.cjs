/* Regression checks for the 2026-09 security review hardening. */
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const repo = path.join(__dirname, "..", "..", "..");

let failures = 0;
function ok(name, condition) {
  if (!condition) failures += 1;
  console.log((condition ? "  PASS  " : "  FAIL  ") + name);
}

function read(...parts) {
  return fs.readFileSync(path.join(...parts), "utf8");
}

console.log("\n--- Security hardening ---");

const reactIndex = read(root, "index.html");
ok(
  "React shell has a CSP meta",
  /http-equiv="Content-Security-Policy"/.test(reactIndex) && /object-src 'none'/.test(reactIndex),
);
ok("React shell has a referrer policy meta", /name="referrer"/.test(reactIndex));

const toolboxHtml = read(root, "public", "toolbox", "index.html");
ok(
  "Toolbox has a CSP meta with object-src none",
  /http-equiv="Content-Security-Policy"/.test(toolboxHtml) && /object-src 'none'/.test(toolboxHtml),
);
ok("Toolbox doc links include noreferrer", /rel="noopener noreferrer"/.test(toolboxHtml));

const panelSchedule = read(root, "public", "toolbox", "panel-schedule.html");
const panelPower = read(root, "public", "toolbox", "panel-power-study.html");
ok(
  "Panel schedule pins Tesseract 5.1.1 with integrity",
  /tesseract\.js@5\.1\.1\/dist\/tesseract\.min\.js/.test(panelSchedule) &&
    /integrity="sha384-/.test(panelSchedule) &&
    /crossorigin="anonymous"/.test(panelSchedule),
);
ok(
  "Panel power study pins Tesseract 5.1.1 with integrity",
  /tesseract\.js@5\.1\.1\/dist\/tesseract\.min\.js/.test(panelPower) &&
    /integrity="sha384-/.test(panelPower),
);
ok("Panel pages have CSP metas", /Content-Security-Policy/.test(panelSchedule) && /Content-Security-Policy/.test(panelPower));

const tdr = read(root, "public", "toolbox", "js", "tdr-analyzer.js");
ok("TDR API helper rejects non-https bases", /u\.protocol !== 'https:'/.test(tdr));

const projectsUi = read(root, "public", "toolbox", "js", "projects-ui.js");
ok("Job Open uses safeJobHref", /function safeJobHref/.test(projectsUi) && /safeJobHref\(run\.url\)/.test(projectsUi));

const panelJs = read(root, "public", "toolbox", "js", "panel-schedule.js");
const panelPowerJs = read(root, "public", "toolbox", "js", "panel-power-study.js");
ok("Panel schedule OCR caps upload size", /12 \* 1024 \* 1024/.test(panelJs));
ok("Panel power study OCR caps upload size", /12 \* 1024 \* 1024/.test(panelPowerJs));

const sw = read(root, "public", "toolbox", "sw.js");
ok("Toolbox SW cache version bumped after hardening", /CACHE_VERSION = 'v17'/.test(sw));
ok("Toolbox SW allow-lists CDN hosts", /RUNTIME_HOST_ALLOWLIST/.test(sw) && /cdn\.jsdelivr\.net/.test(sw));

const deploy = read(repo, ".github", "workflows", "deploy.yml");
ok("Deploy checkout is SHA-pinned", /actions\/checkout@[0-9a-f]{40}/.test(deploy));
ok("Deploy checkout drops credentials", /persist-credentials:\s*false/.test(deploy));
ok("Deploy workflow keeps contents: read", /contents:\s*read/.test(deploy));

const iosMath = read(repo, ".github", "workflows", "ios-math.yml");
ok("iOS math checkout is SHA-pinned", /actions\/checkout@[0-9a-f]{40}/.test(iosMath));

const gear = read(root, "src", "components", "gear", "GearCard.tsx");
ok("GearCard ignores non-http(s) URLs", /function httpUrl/.test(gear));

process.exitCode = failures ? 1 : 0;
