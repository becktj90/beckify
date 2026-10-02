/* ============================================================================
   Switchgear Logic Lab — engine/eval.js
   Deterministic scan-based evaluator: read inputs -> evaluate combinational
   nodes in profile order -> update timers by scanMs -> update latches ->
   apply one-shots. Pure function of (project, runtime, externalInputs, dtMs).

   Assumption made explicit as a profile setting (spec: "ask only if blocked,
   otherwise state your assumption and make it a profile setting"): a node's
   combinational/stateful classification determines pass membership; all
   stateful nodes (LATCH/TIMER/ONESHOT_*) evaluate after every combinational
   node each scan, in the fixed sub-order timers -> latches -> one-shots, and
   read that same scan's already-resolved combinational signal values.
   `profile.evalOrder` controls only the order combinational nodes run in
   ('declaration' or 'reverse' of project.nodes order).
   ============================================================================ */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SwitchgearEngine = root.SwitchgearEngine || {};
    root.SwitchgearEngine.eval = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var COMBINATIONAL = { AND: 1, OR: 1, NOR: 1, NAND: 1, XOR: 1, NOT: 1, CONST_ON: 1, CONST_OFF: 1 };
  var STATEFUL = { LATCH: 1, TIMER: 1, ONESHOT_POS: 1, ONESHOT_NEG: 1 };

  function isCombinational(node) { return !!COMBINATIONAL[node.type]; }
  function isStateful(node) { return !!STATEFUL[node.type]; }

  function readSignal(signalValues, ref, invert) {
    var v = !!signalValues[ref];
    return invert ? !v : v;
  }

  function gate(type, bits) {
    switch (type) {
      case 'AND': return bits.every(function (b) { return b; });
      case 'OR': return bits.some(function (b) { return b; });
      case 'NAND': return !bits.every(function (b) { return b; });
      case 'NOR': return !bits.some(function (b) { return b; });
      case 'XOR': return bits.filter(Boolean).length % 2 === 1;
      case 'NOT': return !bits[0];
      case 'CONST_ON': return true;
      case 'CONST_OFF': return false;
      default: throw new Error('Not a combinational gate: ' + type);
    }
  }

  function combinationalOrder(project, evalOrder) {
    var nodes = project.nodes.filter(isCombinational);
    return evalOrder === 'reverse' ? nodes.slice().reverse() : nodes;
  }

  /**
   * Builds a dependency graph among combinational nodes (edge a->b when b
   * reads a signal that a drives) and returns { cycles: [[nodeId,...]], order }.
   * Used both by eval (to freeze cyclic nodes at their last value instead of
   * spinning) and by lint.js (to report "combinational loop" findings).
   */
  function analyzeCombinationalGraph(project) {
    var combNodes = project.nodes.filter(isCombinational);
    var driverByOutput = {};
    combNodes.forEach(function (n) { driverByOutput[n.output] = n.id; });
    var byId = {};
    combNodes.forEach(function (n) { byId[n.id] = n; });

    var WHITE = 0, GRAY = 1, BLACK = 2;
    var color = {};
    combNodes.forEach(function (n) { color[n.id] = WHITE; });
    var cycles = [];
    var stack = [];

    function visit(nodeId) {
      color[nodeId] = GRAY;
      stack.push(nodeId);
      var node = byId[nodeId];
      node.inputs.forEach(function (inp) {
        var driverId = driverByOutput[inp.ref];
        if (!driverId) return;
        if (color[driverId] === GRAY) {
          var idx = stack.indexOf(driverId);
          cycles.push(stack.slice(idx));
        } else if (color[driverId] === WHITE) {
          visit(driverId);
        }
      });
      stack.pop();
      color[nodeId] = BLACK;
    }

    combNodes.forEach(function (n) { if (color[n.id] === WHITE) visit(n.id); });

    var inCycle = {};
    cycles.forEach(function (c) { c.forEach(function (id) { inCycle[id] = true; }); });

    return { cycles: cycles, inCycleNodeIds: Object.keys(inCycle) };
  }

  function newRuntime() {
    return {
      signalValues: {},
      timerState: {},
      latchState: {},
      oneShotState: {},
      scanCount: 0,
      tMs: 0,
    };
  }

  function cloneRuntime(rt) {
    return JSON.parse(JSON.stringify(rt));
  }

  function resolveTimerFields(profile, params) {
    var a = params.fieldA || 0;
    var b = params.fieldB || 0;
    if (profile.timerFieldOrder === 'dropout-then-pickup') return { pickupMs: b, dropoutMs: a };
    // 'pickup-then-dropout' and 'unknown' both default pickup-first for live simulation;
    // lint.js separately flags 'unknown' as a candidate finding, and
    // evalBothTimerFieldOrders() below lets Analyze diff the two readings.
    return { pickupMs: a, dropoutMs: b };
  }

  function stepTimer(state, input, dtMs, pickupMs, dropoutMs) {
    state = state || { output: false, elapsed: 0, phase: 'idle' };
    if (input) {
      if (state.output) {
        state.phase = 'on';
        state.elapsed = 0;
      } else {
        state.phase = 'pickup';
        state.elapsed += dtMs;
        if (state.elapsed >= pickupMs) {
          state.output = true;
          state.phase = 'on';
          state.elapsed = 0;
        }
      }
    } else {
      if (!state.output) {
        state.phase = 'idle';
        state.elapsed = 0;
      } else {
        state.phase = 'dropout';
        state.elapsed += dtMs;
        if (state.elapsed >= dropoutMs) {
          state.output = false;
          state.phase = 'idle';
          state.elapsed = 0;
        }
      }
    }
    return state;
  }

  function stepLatch(prevOutput, setIn, resetIn, dominance) {
    if (setIn && resetIn) {
      return dominance === 'set' ? true : false; // 'reset' and 'unknown' default to reset-dominant
    }
    if (setIn) return true;
    if (resetIn) return false;
    return !!prevOutput;
  }

  function stepOneShot(prevInput, input, edge) {
    if (edge === 'pos') return !prevInput && input;
    return prevInput && !input;
  }

  /**
   * Runs exactly one scan. externalInputs: { signalId: boolean } for every
   * VI/CI/BREAKER_STATE-kind signal and any signal with no driving node.
   * opts.latchDominanceOverride / evalOrderOverride let Analyze diff
   * interpretations without mutating the stored profile.
   */
  function step(project, runtime, externalInputs, dtMs, opts) {
    opts = opts || {};
    var profile = project.profile;
    var evalOrder = opts.evalOrderOverride || profile.evalOrder;
    var latchDominance = opts.latchDominanceOverride || profile.latchDominance;

    var rt = cloneRuntime(runtime);
    var signalValues = rt.signalValues;
    var undriven = {};

    project.signals.forEach(function (s) {
      if (Object.prototype.hasOwnProperty.call(externalInputs, s.id)) {
        signalValues[s.id] = !!externalInputs[s.id];
      } else if (!(s.id in signalValues)) {
        signalValues[s.id] = false;
      }
    });

    var graph = analyzeCombinationalGraph(project);
    var frozen = {};
    graph.inCycleNodeIds.forEach(function (id) { frozen[id] = true; });

    combinationalOrder(project, evalOrder).forEach(function (node) {
      if (frozen[node.id]) return; // keep last-scan value; lint.js reports the loop separately
      var bits = node.inputs.map(function (i) {
        if (!(i.ref in signalValues)) undriven[i.ref] = true;
        return readSignal(signalValues, i.ref, i.invert);
      });
      signalValues[node.output] = gate(node.type, bits);
    });

    project.nodes.filter(function (n) { return n.type === 'TIMER'; }).forEach(function (node) {
      var input = readSignal(signalValues, node.inputs[0].ref, node.inputs[0].invert);
      var fields = resolveTimerFields(profile, node.params);
      var state = stepTimer(rt.timerState[node.id], input, dtMs, fields.pickupMs, fields.dropoutMs);
      rt.timerState[node.id] = state;
      signalValues[node.output] = state.output;
    });

    project.nodes.filter(function (n) { return n.type === 'LATCH'; }).forEach(function (node) {
      var setIn = readSignal(signalValues, node.inputs[0].ref, node.inputs[0].invert);
      var resetIn = readSignal(signalValues, node.inputs[1].ref, node.inputs[1].invert);
      var prev = !!rt.latchState[node.id];
      var out = stepLatch(prev, setIn, resetIn, latchDominance);
      rt.latchState[node.id] = out;
      signalValues[node.output] = out;
    });

    project.nodes.filter(function (n) { return n.type === 'ONESHOT_POS' || n.type === 'ONESHOT_NEG'; }).forEach(function (node) {
      var input = readSignal(signalValues, node.inputs[0].ref, node.inputs[0].invert);
      var prevState = rt.oneShotState[node.id] || { prevInput: false };
      var pulse = stepOneShot(prevState.prevInput, input, node.type === 'ONESHOT_POS' ? 'pos' : 'neg');
      rt.oneShotState[node.id] = { prevInput: input };
      signalValues[node.output] = pulse;
    });

    rt.scanCount += 1;
    rt.tMs += dtMs;

    return {
      runtime: rt,
      signalValues: signalValues,
      undrivenRefs: Object.keys(undriven),
      combinationalLoops: graph.cycles,
    };
  }

  /**
   * Analyze helper: run a settled (repeated-until-stable, capped) scan under
   * both latch-dominance interpretations from the same starting runtime and
   * report whether they diverge. Used when profile.latchDominance === 'unknown'.
   */
  function stepBothLatchDominances(project, runtime, externalInputs, dtMs) {
    var a = step(project, runtime, externalInputs, dtMs, { latchDominanceOverride: 'set' });
    var b = step(project, runtime, externalInputs, dtMs, { latchDominanceOverride: 'reset' });
    var divergentSignals = Object.keys(a.signalValues).filter(function (id) {
      return !!a.signalValues[id] !== !!b.signalValues[id];
    });
    return { setDominant: a, resetDominant: b, divergentSignals: divergentSignals };
  }

  function stepBothTimerFieldOrders(project, runtime, externalInputs, dtMs) {
    var a = step(project, runtime, externalInputs, dtMs, { evalOrderOverride: project.profile.evalOrder });
    var pickupFirst = Object.assign({}, project, { profile: Object.assign({}, project.profile, { timerFieldOrder: 'pickup-then-dropout' }) });
    var dropoutFirst = Object.assign({}, project, { profile: Object.assign({}, project.profile, { timerFieldOrder: 'dropout-then-pickup' }) });
    var r1 = step(pickupFirst, runtime, externalInputs, dtMs);
    var r2 = step(dropoutFirst, runtime, externalInputs, dtMs);
    var divergentSignals = Object.keys(r1.signalValues).filter(function (id) {
      return !!r1.signalValues[id] !== !!r2.signalValues[id];
    });
    return { pickupThenDropout: r1, dropoutThenPickup: r2, divergentSignals: divergentSignals };
  }

  /** Runs a scan repeatedly with unchanging inputs until signalValues stop changing or maxScans is hit. */
  function settle(project, runtime, externalInputs, dtMs, maxScans) {
    maxScans = maxScans || 200;
    var rt = runtime;
    var last = null;
    var result = null;
    for (var i = 0; i < maxScans; i++) {
      result = step(project, rt, externalInputs, dtMs);
      rt = result.runtime;
      var snapshot = JSON.stringify(result.signalValues);
      var timerPending = Object.keys(rt.timerState).some(function (id) {
        return rt.timerState[id].phase === 'pickup' || rt.timerState[id].phase === 'dropout';
      });
      if (snapshot === last && !timerPending) {
        return { result: result, settled: true, scans: i + 1 };
      }
      last = snapshot;
    }
    return { result: result, settled: false, scans: maxScans };
  }

  return {
    isCombinational: isCombinational,
    isStateful: isStateful,
    analyzeCombinationalGraph: analyzeCombinationalGraph,
    newRuntime: newRuntime,
    cloneRuntime: cloneRuntime,
    resolveTimerFields: resolveTimerFields,
    step: step,
    stepBothLatchDominances: stepBothLatchDominances,
    stepBothTimerFieldOrders: stepBothTimerFieldOrders,
    settle: settle,
  };
});
