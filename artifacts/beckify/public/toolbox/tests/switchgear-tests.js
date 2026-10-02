/* ============================================================================
   Switchgear Logic Lab — tests/switchgear-tests.js
   Phase 1 acceptance suite: gates, timers (both field orders), latches (both
   dominances), one-shots, plant parallel/backfeed, and a hand-built
   main-tie-main example. Runnable under plain `node` (see run-node.js) and in
   a browser (see switchgear-tests.html) — this file has no DOM dependency.
   ============================================================================ */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SwitchgearEngineTests = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  function makeHarness() {
    var results = [];
    function test(name, fn) {
      try {
        fn();
        results.push({ name: name, pass: true });
      } catch (e) {
        results.push({ name: name, pass: false, error: e && e.message ? e.message : String(e) });
      }
    }
    function assert(cond, msg) {
      if (!cond) throw new Error(msg || 'assertion failed');
    }
    function assertEqual(a, b, msg) {
      if (a !== b) throw new Error((msg || 'not equal') + ' (got ' + JSON.stringify(a) + ', expected ' + JSON.stringify(b) + ')');
    }
    return { test: test, assert: assert, assertEqual: assertEqual, results: results };
  }

  function runAll(engine) {
    var model = engine.model, profile = engine.profile, ev = engine.eval, plant = engine.plant, scenario = engine.scenario, lint = engine.lint;
    var h = makeHarness();
    var test = h.test, assert = h.assert, assertEqual = h.assertEqual;

    function gateProject(type, inputCount, invertFlags) {
      var p = profile.clone(profile.GENERIC_PROFILE);
      var proj = model.newProject(p);
      var inputs = [];
      for (var i = 0; i < inputCount; i++) {
        var sig = model.newSignal({ id: 'in' + i, kind: 'VI', name: 'in' + i });
        proj.signals.push(sig);
        inputs.push({ ref: sig.id, invert: !!(invertFlags && invertFlags[i]) });
      }
      var outSig = model.newSignal({ id: 'out', kind: 'VO', name: 'out' });
      proj.signals.push(outSig);
      proj.nodes.push(model.newNode({ id: 'n1', type: type, inputs: inputs, output: 'out' }));
      return proj;
    }

    function evalGate(type, inputCount, bits, invertFlags) {
      var proj = gateProject(type, inputCount, invertFlags);
      var inputs = {};
      bits.forEach(function (b, i) { inputs['in' + i] = b; });
      var r = ev.step(proj, ev.newRuntime(), inputs, 100);
      return r.signalValues.out;
    }

    test('AND truth table', function () {
      assertEqual(evalGate('AND', 2, [true, true]), true);
      assertEqual(evalGate('AND', 2, [true, false]), false);
      assertEqual(evalGate('AND', 2, [false, false]), false);
    });
    test('OR truth table', function () {
      assertEqual(evalGate('OR', 2, [false, false]), false);
      assertEqual(evalGate('OR', 2, [true, false]), true);
    });
    test('NAND truth table', function () {
      assertEqual(evalGate('NAND', 2, [true, true]), false);
      assertEqual(evalGate('NAND', 2, [true, false]), true);
    });
    test('NOR truth table', function () {
      assertEqual(evalGate('NOR', 2, [false, false]), true);
      assertEqual(evalGate('NOR', 2, [true, false]), false);
    });
    test('XOR truth table', function () {
      assertEqual(evalGate('XOR', 2, [true, false]), true);
      assertEqual(evalGate('XOR', 2, [true, true]), false);
    });
    test('NOT inverts', function () {
      assertEqual(evalGate('NOT', 1, [true]), false);
      assertEqual(evalGate('NOT', 1, [false]), true);
    });
    test('per-input invert flag', function () {
      assertEqual(evalGate('AND', 2, [false, true], [true, false]), true);
    });

    function timerProject(fieldA, fieldB, timerFieldOrder) {
      var p = profile.clone(profile.GENERIC_PROFILE);
      p.timerFieldOrder = timerFieldOrder;
      p.scanMs = 10;
      var proj = model.newProject(p);
      proj.signals.push(model.newSignal({ id: 'in', kind: 'VI', name: 'in' }));
      proj.signals.push(model.newSignal({ id: 'out', kind: 'VO', name: 'out' }));
      proj.nodes.push(model.newNode({
        id: 't1', type: 'TIMER', inputs: [{ ref: 'in', invert: false }], output: 'out',
        params: { fieldA: fieldA, fieldB: fieldB },
      }));
      return proj;
    }

    test('timer pickup-then-dropout: output delays on, follows off immediately after dropout field', function () {
      var proj = timerProject(50, 20, 'pickup-then-dropout');
      var rt = ev.newRuntime();
      var r;
      r = ev.step(proj, rt, { in: true }, 10); rt = r.runtime;
      assertEqual(r.signalValues.out, false, 'still picking up at 10ms < 50ms');
      for (var i = 0; i < 4; i++) { r = ev.step(proj, rt, { in: true }, 10); rt = r.runtime; }
      assertEqual(r.signalValues.out, true, 'picked up by 50ms');
      r = ev.step(proj, rt, { in: false }, 10); rt = r.runtime;
      assertEqual(r.signalValues.out, true, 'still on during dropout window');
      r = ev.step(proj, rt, { in: false }, 10); rt = r.runtime;
      assertEqual(r.signalValues.out, false, 'dropped out after 20ms');
    });

    test('timer dropout-then-pickup: same raw fields, swapped interpretation', function () {
      var proj = timerProject(50, 20, 'dropout-then-pickup'); // fieldA=50 now means dropoutMs, fieldB=20 means pickupMs
      var rt = ev.newRuntime();
      var r;
      r = ev.step(proj, rt, { in: true }, 10); rt = r.runtime;
      assertEqual(r.signalValues.out, false, 'still picking up at 10ms < 20ms pickup');
      r = ev.step(proj, rt, { in: true }, 10); rt = r.runtime;
      assertEqual(r.signalValues.out, true, 'picked up by 20ms');
    });

    test('timer 0/0 passes through immediately', function () {
      var proj = timerProject(0, 0, 'pickup-then-dropout');
      var r = ev.step(proj, ev.newRuntime(), { in: true }, 10);
      assertEqual(r.signalValues.out, true);
    });

    function latchProject() {
      var p = profile.clone(profile.GENERIC_PROFILE);
      var proj = model.newProject(p);
      proj.signals.push(model.newSignal({ id: 'set', kind: 'VI', name: 'set' }));
      proj.signals.push(model.newSignal({ id: 'reset', kind: 'VI', name: 'reset' }));
      proj.signals.push(model.newSignal({ id: 'out', kind: 'VO', name: 'out' }));
      proj.nodes.push(model.newNode({
        id: 'l1', type: 'LATCH',
        inputs: [{ ref: 'set', invert: false }, { ref: 'reset', invert: false }],
        output: 'out',
      }));
      return proj;
    }

    test('latch set/reset/hold basic behavior', function () {
      var proj = latchProject();
      var rt = ev.newRuntime();
      var r;
      r = ev.step(proj, rt, { set: true, reset: false }, 100); rt = r.runtime;
      assertEqual(r.signalValues.out, true, 'set latches true');
      r = ev.step(proj, rt, { set: false, reset: false }, 100); rt = r.runtime;
      assertEqual(r.signalValues.out, true, 'holds true with neither asserted');
      r = ev.step(proj, rt, { set: false, reset: true }, 100); rt = r.runtime;
      assertEqual(r.signalValues.out, false, 'reset clears it');
    });

    test('latch dominance: both asserted resolves per dominance override', function () {
      var proj = latchProject();
      var rSet = ev.step(proj, ev.newRuntime(), { set: true, reset: true }, 100, { latchDominanceOverride: 'set' });
      assertEqual(rSet.signalValues.out, true, 'set-dominant: both true -> true');
      var rReset = ev.step(proj, ev.newRuntime(), { set: true, reset: true }, 100, { latchDominanceOverride: 'reset' });
      assertEqual(rReset.signalValues.out, false, 'reset-dominant: both true -> false');
    });

    test('stepBothLatchDominances flags divergence only when both asserted', function () {
      var proj = latchProject();
      var both = ev.stepBothLatchDominances(proj, ev.newRuntime(), { set: true, reset: true }, 100);
      assert(both.divergentSignals.indexOf('out') !== -1, 'should diverge when set and reset both true');
      var neither = ev.stepBothLatchDominances(proj, ev.newRuntime(), { set: false, reset: false }, 100);
      assert(neither.divergentSignals.indexOf('out') === -1, 'should not diverge when neither asserted');
    });

    function oneShotProject(type) {
      var p = profile.clone(profile.GENERIC_PROFILE);
      var proj = model.newProject(p);
      proj.signals.push(model.newSignal({ id: 'in', kind: 'VI', name: 'in' }));
      proj.signals.push(model.newSignal({ id: 'out', kind: 'VO', name: 'out' }));
      proj.nodes.push(model.newNode({ id: 'o1', type: type, inputs: [{ ref: 'in', invert: false }], output: 'out' }));
      return proj;
    }

    test('ONESHOT_POS pulses exactly one scan on rising edge', function () {
      var proj = oneShotProject('ONESHOT_POS');
      var rt = ev.newRuntime();
      var r;
      r = ev.step(proj, rt, { in: false }, 100); rt = r.runtime;
      assertEqual(r.signalValues.out, false);
      r = ev.step(proj, rt, { in: true }, 100); rt = r.runtime;
      assertEqual(r.signalValues.out, true, 'pulses on the rising scan');
      r = ev.step(proj, rt, { in: true }, 100); rt = r.runtime;
      assertEqual(r.signalValues.out, false, 'only one scan long');
    });

    test('ONESHOT_NEG pulses exactly one scan on falling edge', function () {
      var proj = oneShotProject('ONESHOT_NEG');
      var rt = ev.newRuntime();
      var r;
      r = ev.step(proj, rt, { in: true }, 100); rt = r.runtime;
      assertEqual(r.signalValues.out, false);
      r = ev.step(proj, rt, { in: false }, 100); rt = r.runtime;
      assertEqual(r.signalValues.out, true, 'pulses on the falling scan');
      r = ev.step(proj, rt, { in: false }, 100); rt = r.runtime;
      assertEqual(r.signalValues.out, false);
    });

    test('combinational loop is detected and does not hang', function () {
      var p = profile.clone(profile.GENERIC_PROFILE);
      var proj = model.newProject(p);
      proj.signals.push(model.newSignal({ id: 'a', kind: 'VO', name: 'a' }));
      proj.signals.push(model.newSignal({ id: 'b', kind: 'VO', name: 'b' }));
      proj.nodes.push(model.newNode({ id: 'na', type: 'NOT', inputs: [{ ref: 'b', invert: false }], output: 'a' }));
      proj.nodes.push(model.newNode({ id: 'nb', type: 'NOT', inputs: [{ ref: 'a', invert: false }], output: 'b' }));
      var r = ev.step(proj, ev.newRuntime(), {}, 100);
      assertEqual(r.combinationalLoops.length, 1, 'one cycle detected');
      assert(typeof r.signalValues.a === 'boolean', 'evaluation completes instead of hanging');
    });

    function mainTieMainPlant() {
      var pm = plant.newPlantModel();
      pm.buses.push(plant.newBus({ id: 'bus1' }), plant.newBus({ id: 'bus2' }));
      pm.sources.push(plant.newSource({ id: 's1', kind: 'utility' }), plant.newSource({ id: 's2', kind: 'utility' }));
      pm.breakers.push(
        plant.newBreaker({ id: 'b1', label: 'Main 1 (52-U1)', role: 'main', connectsBusA: 'bus1', sourceId: 's1' }),
        plant.newBreaker({ id: 'b2', label: 'Main 2 (52-U2)', role: 'main', connectsBusA: 'bus2', sourceId: 's2' }),
        plant.newBreaker({ id: 'b4', label: 'Tie (52G)', role: 'tie', connectsBusA: 'bus1', connectsBusB: 'bus2' })
      );
      return pm;
    }

    test('main-tie-main: both mains closed, tie open — two isolated buses, no parallel', function () {
      var pm = mainTieMainPlant();
      var positions = { b1: 'closed', b2: 'closed', b4: 'open' };
      var avail = { s1: true, s2: true };
      var findings = plant.analyzeSnapshot(pm, positions, avail);
      assertEqual(findings.filter(function (f) { return f.category === 'parallel-sources'; }).length, 0);
    });

    test('main-tie-main: both mains + tie closed — parallel-sources finding fires', function () {
      var pm = mainTieMainPlant();
      var positions = { b1: 'closed', b2: 'closed', b4: 'closed' };
      var avail = { s1: true, s2: true };
      var findings = plant.analyzeSnapshot(pm, positions, avail);
      assert(findings.some(function (f) { return f.category === 'parallel-sources'; }), 'expected a parallel-sources finding');
    });

    test('main-tie-main: source 1 down, tie closed — backfeed finding fires', function () {
      var pm = mainTieMainPlant();
      var positions = { b1: 'closed', b2: 'closed', b4: 'closed' };
      var avail = { s1: false, s2: true };
      var findings = plant.detectBackfeed(pm, positions, avail);
      assert(findings.some(function (f) { return f.category === 'backfeed'; }), 'expected a backfeed finding');
    });

    test('main-tie-main: tie transfer scenario closes tie only after main 1 opens (no sustained parallel)', function () {
      var pm = mainTieMainPlant();
      var p = profile.clone(profile.GENERIC_PROFILE);
      var proj = model.newProject(p);
      proj.plant = pm;
      pm.breakers[0].position = 'closed';
      pm.breakers[1].position = 'closed';
      pm.breakers[2].position = 'open';
      pm.breakers[2].operateDelayMs = 50;

      var scen = scenario.newScenario({
        id: 'sc1', durationMs: 400, dtMs: 50,
        events: [
          { tMs: 50, type: 'sourceAvailable', sourceId: 's1', available: false },
          { tMs: 100, type: 'breakerPosition', breakerId: 'b1', position: 'open' },
          { tMs: 150, type: 'breakerPosition', breakerId: 'b4', position: 'closed' },
        ],
      });
      var result = scenario.run(proj, scen, ev, plant, {});
      var parallelSteps = result.findings.filter(function (fnd) { return fnd.category === 'parallel-sources'; });
      assertEqual(parallelSteps.length, 0, 'main1 was open before tie closed, so no parallel window occurred');
    });

    test('lint flags undriven reference', function () {
      var p = profile.clone(profile.GENERIC_PROFILE);
      var proj = model.newProject(p);
      proj.signals.push(model.newSignal({ id: 'orphan', kind: 'VO', name: 'orphan' }));
      proj.signals.push(model.newSignal({ id: 'out', kind: 'VO', name: 'out' }));
      proj.nodes.push(model.newNode({ id: 'n1', type: 'NOT', inputs: [{ ref: 'orphan', invert: false }], output: 'out' }));
      var findings = lint.undrivenAndUnconsumed(proj);
      assert(findings.some(function (fnd) { return fnd.category === 'undriven-reference'; }));
    });

    test('lint flags duplicate drivers', function () {
      var p = profile.clone(profile.GENERIC_PROFILE);
      var proj = model.newProject(p);
      proj.signals.push(model.newSignal({ id: 'a', kind: 'VI', name: 'a' }));
      proj.signals.push(model.newSignal({ id: 'out', kind: 'VO', name: 'out' }));
      proj.nodes.push(model.newNode({ id: 'n1', type: 'NOT', inputs: [{ ref: 'a', invert: false }], output: 'out' }));
      proj.nodes.push(model.newNode({ id: 'n2', type: 'NOT', inputs: [{ ref: 'a', invert: true }], output: 'out' }));
      var findings = lint.duplicateDrivers(proj);
      assertEqual(findings.length, 1);
    });

    test('lint flags pass-through 0/0 timer', function () {
      var proj = timerProject(0, 0, 'pickup-then-dropout');
      var findings = lint.timerIssues(proj);
      assert(findings.some(function (fnd) { return fnd.category === 'pass-through-timer'; }));
    });

    test('settled-state enumeration is exhaustive for a small input count', function () {
      var proj = gateProject('AND', 3);
      var enumeration = engine.report.enumerateSettledStates(proj, ev);
      assertEqual(enumeration.exhaustive, true);
      assertEqual(enumeration.rows.length, 8);
      var allTrueRow = enumeration.rows.filter(function (row) {
        return row.inputs.in0 && row.inputs.in1 && row.inputs.in2;
      })[0];
      assertEqual(allTrueRow.outputs.out, true);
    });

    test('non-exclusive position decode is detected from an enumerated table', function () {
      var p = profile.clone(profile.GENERIC_PROFILE);
      var proj = model.newProject(p);
      proj.signals.push(model.newSignal({ id: 'raw', kind: 'VI', name: 'raw' }));
      proj.signals.push(model.newSignal({ id: 'decodeA', kind: 'VO', name: 'decodeA' }));
      proj.signals.push(model.newSignal({ id: 'decodeB', kind: 'VO', name: 'decodeB' }));
      proj.nodes.push(model.newNode({ id: 'na', type: 'NOT', inputs: [{ ref: 'raw', invert: true }], output: 'decodeA' }));
      proj.nodes.push(model.newNode({ id: 'nb', type: 'NOT', inputs: [{ ref: 'raw', invert: true }], output: 'decodeB' }));
      var enumeration = engine.report.enumerateSettledStates(proj, ev);
      var findings = engine.report.nonExclusiveDecodes(enumeration, { position: ['decodeA', 'decodeB'] });
      assert(findings.length === 1, 'both decodes true together should be caught');
    });

    return { results: h.results, passed: h.results.filter(function (r) { return r.pass; }).length, failed: h.results.filter(function (r) { return !r.pass; }).length };
  }

  return { runAll: runAll };
});
