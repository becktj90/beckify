/* Browser-script/markup wiring regression checks. */
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..', 'public', 'toolbox');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const smith = fs.readFileSync(path.join(root, 'js', 'smith-chart.js'), 'utf8');

let failures = 0;
function ok(name, condition) {
  if (!condition) failures += 1;
  console.log((condition ? '  PASS  ' : '  FAIL  ') + name);
}

console.log('\n--- Toolbox DOM/script integrity ---');
['sc_r', 'sc_x', 'sc_freq', 'sc_z0', 'sc_tl_deg', 'sc_tl_dir'].forEach((id) => {
  ok('Smith field exists: ' + id, new RegExp('id="' + id + '"').test(html));
  ok('Smith script uses live field: ' + id, smith.includes("'" + id + "'"));
});
ok('Smith manual entry does not use obsolete impedance IDs', !/sc-z-real|sc-z-imag/.test(smith));
ok('signed net-reactance input exists', /id="imp_x"/.test(html));
ok('legacy XL/XC impedance inputs removed', !/id="imp_xl"|id="imp_xc"/.test(html));
ok('home control has an accessible name in markup', /class="nav-btn home-btn"[^>]*aria-label=/.test(html));

process.exitCode = failures ? 1 : 0;
