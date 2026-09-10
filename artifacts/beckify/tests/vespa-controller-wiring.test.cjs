/* Vespa build page must show Trevor's corrected 72V controller wiring figure. */
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const page = fs.readFileSync(path.join(root, "src/pages/vespa-p200e.tsx"), "utf8");
const pngPath = path.join(root, "public/projects/vespa/72v-controller-wiring.png");
const svgPath = path.join(root, "public/projects/vespa/72v-controller-wiring.svg");

let failures = 0;
function ok(name, condition, detail) {
  if (!condition) failures += 1;
  console.log((condition ? "  PASS  " : "  FAIL  ") + name + (detail ? " — " + detail : ""));
}

ok(
  "page points at the corrected 72V controller wiring PNG",
  page.includes('wiring: "/projects/vespa/72v-controller-wiring.png"'),
);
ok(
  "page no longer uses the old powertrain-wiring-diagram.jpg as the figure src",
  !page.includes("powertrain-wiring-diagram.jpg"),
);
ok(
  "alt text names 72V controller wiring",
  /alt="72V controller wiring diagram/.test(page),
);
ok(
  "caption notes the redraw and educational build context",
  page.includes("Redrawn from controller-wiring-reference") &&
    page.includes("Educational build"),
);
ok("corrected PNG asset exists", fs.existsSync(pngPath), pngPath);
ok("vector source exists", fs.existsSync(svgPath), svgPath);
ok("PNG is a real image, not a leftover stub", fs.existsSync(pngPath) && fs.statSync(pngPath).size > 20_000);

if (failures) {
  process.exit(1);
}
console.log("vespa controller wiring checks passed");
