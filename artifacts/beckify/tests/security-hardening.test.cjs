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
ok("React CSP frame-src allows the same-origin Kestrel Heavy iframe", /frame-src 'self'/.test(reactIndex));
ok("React shell has a referrer policy meta", /name="referrer"/.test(reactIndex));

const toolboxHtml = read(root, "public", "toolbox", "index.html");
ok(
  "Toolbox has a CSP meta with object-src none",
  /http-equiv="Content-Security-Policy"/.test(toolboxHtml) && /object-src 'none'/.test(toolboxHtml),
);
ok("Toolbox CSP allows media blob for getUserMedia", /media-src 'self' blob:/.test(toolboxHtml));
ok("Toolbox doc links include noreferrer", /rel="noopener noreferrer"/.test(toolboxHtml));

const panelSchedule = read(root, "public", "toolbox", "panel-schedule.html");
const panelPower = read(root, "public", "toolbox", "panel-power-study.html");
ok(
  "Panel schedule uses local Tesseract helper with SRI pin",
  /js\/ocr-helper\.js/.test(panelSchedule) &&
    !/cdn\.jsdelivr\.net\/npm\/tesseract/.test(panelSchedule),
);
const ocrHelper = read(root, "public", "toolbox", "js", "ocr-helper.js");
const crypto = require("crypto");
const tessBytes = fs.readFileSync(path.join(root, "public", "toolbox", "js", "vendor", "tesseract", "tesseract.min.js"));
const tessSha384 = crypto.createHash("sha384").update(tessBytes).digest("base64");
const ocrSri = (ocrHelper.match(/integrity = 'sha384-([^']+)'/) || [])[1];
ok(
  "OCR helper SRI matches vendored tesseract.min.js SHA-384",
  ocrSri === tessSha384 && /js\/vendor\/tesseract\//.test(ocrHelper),
);
ok(
  "OCR helper pins Tesseract 5.1.1 integrity hash",
  /sha384-GJqSu7vueQ9qN0E9yLPb3Wtpd7OrgK8KmYzC8T1IysG1bcvxvIO4qtYR\/D3A991F/.test(ocrHelper) &&
    /js\/vendor\/tesseract\//.test(ocrHelper),
);
ok(
  "Panel power study uses local Tesseract helper, no CDN",
  /js\/ocr-helper\.js/.test(panelPower) &&
    !/cdn\.jsdelivr\.net\/npm\/tesseract/.test(panelPower),
);
ok("Panel pages have CSP metas", /Content-Security-Policy/.test(panelSchedule) && /Content-Security-Policy/.test(panelPower));

const tdr = read(root, "public", "toolbox", "js", "tdr-analyzer.js");
ok("TDR API helper rejects non-https bases", /u\.protocol !== 'https:'/.test(tdr));
const look = read(root, "public", "toolbox", "js", "look-check.js");
ok("Look Check API helper rejects non-https bases", /u\.protocol !== 'https:'/.test(look));
ok("Look Check does not upload on file pick", /does not upload/.test(look) && /Analyze Look/.test(look));
const vlm = read(root, "public", "toolbox", "js", "vlm-ocr.js");
ok("VLM helper rejects non-https bases", /u\.protocol !== 'https:'/.test(vlm));
ok("VLM helper keeps API tokens out of localStorage", /sessionStorage/.test(vlm) && /TOKEN_KEY/.test(vlm));
ok("VLM helper does not upload unless Enhance is on", /enhanceOn/.test(vlm) && /shouldUpload/.test(vlm));

const projectsUi = read(root, "public", "toolbox", "js", "projects-ui.js");
ok("Job Open uses safeJobHref", /function safeJobHref/.test(projectsUi) && /safeJobHref\(run\.url\)/.test(projectsUi));

const panelJs = read(root, "public", "toolbox", "js", "panel-schedule.js");
const panelPowerJs = read(root, "public", "toolbox", "js", "panel-power-study.js");
ok("Panel schedule OCR caps upload size", /12 \* 1024 \* 1024/.test(panelJs));
ok("Panel and schema CSV cells neutralize formula prefixes", /function csvCell/.test(panelJs) && /\^\[=\+\\-@\]/.test(panelJs));
ok("Panel power study OCR caps upload size", /12 \* 1024 \* 1024/.test(panelPowerJs));

const sw = read(root, "public", "toolbox", "sw.js");
ok("Toolbox SW cache version bumped after OCR wave 2 review follow-ups", /CACHE_VERSION = 'v43'/.test(sw));
ok(
  "Toolbox SW does not precache Tesseract at install",
  !/const SHELL = \[[^\]]*tesseract/s.test(sw),
);
ok(
  "Toolbox SW runtime-caches Tesseract on first OCR use",
  /isTesseractAsset/.test(sw) && /vendor\/tesseract\//.test(sw),
);
ok("Toolbox SW allow-lists CDN hosts", /RUNTIME_HOST_ALLOWLIST/.test(sw) && /cdn\.jsdelivr\.net/.test(sw));

const deploy = read(repo, ".github", "workflows", "deploy.yml");
ok("Deploy checkout is SHA-pinned", /actions\/checkout@[0-9a-f]{40}/.test(deploy));
ok("Deploy checkout drops credentials", /persist-credentials:\s*false/.test(deploy));
ok("Deploy workflow keeps contents: read", /contents:\s*read/.test(deploy));

const iosMath = read(repo, ".github", "workflows", "ios-math.yml");
ok("iOS math checkout is SHA-pinned", /actions\/checkout@[0-9a-f]{40}/.test(iosMath));

const vespa = read(root, "src", "components", "VespaPartsCatalog.tsx");
ok("Vespa Amazon links stay rel=sponsored", vespa.includes('part.href.includes("amazon.com") ? "sponsored noopener noreferrer"'));

process.exitCode = failures ? 1 : 0;
