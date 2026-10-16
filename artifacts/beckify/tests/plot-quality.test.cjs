const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "..");
const read = (rel) => fs.readFileSync(path.join(root, rel), "utf8");

test("plot quality is a standing requirement", () => {
  const doc = read("docs/plot-quality.md");
  assert.match(doc, /devicePixelRatio/);
  assert.match(doc, /#080b10/);
  assert.match(doc, /#40bad6/);
  assert.match(doc, /#609ce6/);
  assert.match(doc, /#e09c56/);
  assert.match(doc, /390/);
  assert.match(doc, /1280/);
  assert.match(doc, /prefers-reduced-motion/);
  assert.match(read("README.md"), /docs\/plot-quality\.md/);
  const palette = read("src/components/control/chartPalette.ts");
  assert.match(palette, /cyan: "#40bad6"/);
  assert.match(palette, /copper: "#e09c56"/);
});

test("toolbox plots use the app palette and crisp canvas scaling", () => {
  const visuals = read("public/toolbox/js/result-visuals.js");
  const smith = read("public/toolbox/js/smith-chart.js");
  const sensor = read("public/toolbox/js/sensor-tools.js");
  assert.doesNotMatch(visuals, /#8b7bff/);
  assert.match(visuals, /#40bad6/);
  assert.match(visuals, /Voltage drop \(%\)/);
  assert.match(visuals, /Torque \(per unit of rated\)/);
  assert.match(visuals, /pointermove/);
  assert.doesNotMatch(smith, /#8b7bff/);
  assert.match(smith, /devicePixelRatio/);
  assert.match(smith, /resistance: '#40bad6'/);
  assert.match(smith, /sc-hover/);
  assert.match(sensor, /devicePixelRatio/);
  assert.match(sensor, /#40bad6/);
  assert.match(read("public/toolbox/js/ebike-battery-designer.js"), /devicePixelRatio/);
  assert.match(read("public/toolbox/js/ebike-battery-designer.js"), /#080b10/);
  for (const file of [
    "public/toolbox/js/xfmr-wizard.js",
    "public/toolbox/js/phasor-diagram.js",
    "public/toolbox/js/analog-tools.js",
    "public/toolbox/js/circuit-sim.js",
    "src/components/control/BodePlot.tsx",
    "src/components/control/StepTuner.tsx",
  ]) {
    assert.doesNotMatch(read(file), /#8b7bff/, file);
  }
});
