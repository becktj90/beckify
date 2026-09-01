/* Regression test for an axe-core "select-name" violation (critical impact,
   210 nodes across the two panel tools): the poles/circuitClass/loadType
   <select> elements generated per circuit row had no accessible name at all,
   unlike the neighboring demandFactor <input>, which already carried a
   per-row aria-label. This checks the generated markup directly rather than
   the underlying calculation, since the defect was in the template string,
   not the math. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..', 'public', 'toolbox');

let checks = 0;
for (const file of ['js/panel-power-study.js', 'js/panel-schedule.js']) {
  const src = fs.readFileSync(path.join(root, file), 'utf8');
  const openTags = src.match(/<select[^>]*>/g) || [];
  const rowSelects = openTags.filter((tag) => tag.includes('data-field='));
  assert.ok(rowSelects.length > 0, `${file} has at least one per-row <select> to check`);
  for (const tag of rowSelects) {
    assert.ok(/aria-label=/.test(tag), `${file}: <select> missing aria-label: ${tag.slice(0, 80)}`);
    checks += 1;
  }
}

console.log(`Panel tool <select> accessible-name check passed (${checks} select templates)`);
