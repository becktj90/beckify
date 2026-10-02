#!/usr/bin/env node
/* Node-side runner for the Switchgear Logic Lab engine test suite.
   Loads each engine/test file with vm.runInContext against a bare global —
   the same "no module system, just a global object" execution model as a
   browser <script> tag or an iOS JSContext.evaluateScript(), so a pass here
   means the files will behave the same way in production. No npm deps. */
'use strict';
var fs = require('fs');
var path = require('path');
var vm = require('vm');

var engineDir = path.join(__dirname, '..', 'js', 'switchgear');
var engineFiles = ['model.js', 'profile.js', 'eval.js', 'plant.js', 'scenario.js', 'trace.js', 'lint.js', 'report.js'];

var context = vm.createContext({ console: console, Math: Math, JSON: JSON, Object: Object, Array: Array, Set: Set, Date: Date });

engineFiles.forEach(function (name) {
  var file = path.join(engineDir, name);
  vm.runInContext(fs.readFileSync(file, 'utf8'), context, { filename: file });
});
vm.runInContext(fs.readFileSync(path.join(__dirname, 'switchgear-tests.js'), 'utf8'), context, { filename: 'switchgear-tests.js' });

var outcome = context.SwitchgearEngineTests.runAll(context.SwitchgearEngine);

outcome.results.forEach(function (r) {
  console.log((r.pass ? 'PASS' : 'FAIL') + ' — ' + r.name + (r.error ? ' :: ' + r.error : ''));
});
console.log(outcome.passed + ' passed, ' + outcome.failed + ' failed');
process.exit(outcome.failed ? 1 : 0);
