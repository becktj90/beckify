/* ============================================================================
   Switchgear Logic Lab — engine/trace.js
   "Why won't it close?" / "why did it open?" explanations. Both directions
   share one recursive walk back from a target signal to its driving node's
   operands: for a gate that is currently blocking (AND false, OR true-by-
   default-path, etc.) it reports the minimum set of unsatisfied operands —
   not a full truth dump — plus live timer phase/elapsed and latch dominance
   so an operator sees exactly what to check next.
   ============================================================================ */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SwitchgearEngine = root.SwitchgearEngine || {};
    root.SwitchgearEngine.trace = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  function driverNode(project, signalId) {
    for (var i = 0; i < project.nodes.length; i++) {
      if (project.nodes[i].output === signalId) return project.nodes[i];
    }
    return null;
  }

  function signalLabel(project, signalId) {
    for (var i = 0; i < project.signals.length; i++) {
      if (project.signals[i].id === signalId) return project.signals[i].name;
    }
    return signalId;
  }

  function childValue(signalValues, inp) {
    var raw = !!signalValues[inp.ref];
    return inp.invert ? !raw : raw;
  }

  /**
   * Recursively explains why `signalId` currently holds `signalValues[signalId]`.
   * runtimeExtras: { timerState, latchState } from the eval runtime, optional —
   * enriches TIMER/LATCH leaves with live phase/elapsed/dominance detail.
   */
  function explain(project, signalValues, signalId, runtimeExtras, depth, visited) {
    depth = depth || 0;
    visited = visited || {};
    var value = !!signalValues[signalId];
    var label = signalLabel(project, signalId);

    if (depth > 64 || visited[signalId]) {
      return { signalId: signalId, label: label, value: value, type: 'cycle-guard', children: [] };
    }
    visited = Object.assign({}, visited);
    visited[signalId] = true;

    var node = driverNode(project, signalId);
    if (!node) {
      return { signalId: signalId, label: label, value: value, type: 'undriven-or-input', children: [] };
    }

    var node_ = node;
    var out = { signalId: signalId, label: label, value: value, type: node_.type, nodeId: node_.id, children: [] };

    function childFor(inputIndex) {
      var inp = node_.inputs[inputIndex];
      var v = childValue(signalValues, inp);
      var sub = explain(project, signalValues, inp.ref, runtimeExtras, depth + 1, visited);
      sub.effectiveValue = inp.invert ? !sub.value : sub.value;
      sub.inverted = inp.invert;
      return sub;
    }

    switch (node_.type) {
      case 'AND':
      case 'NAND': {
        var wantTrue = node_.type === 'AND' ? value : !value;
        node_.inputs.forEach(function (inp, idx) {
          var v = childValue(signalValues, inp);
          if (!v) out.children.push(childFor(idx)); // only the blocking (false) operands — minimum unsatisfied set
        });
        out.note = wantTrue
          ? 'all operands satisfied'
          : (out.children.length ? out.children.length + ' operand(s) unsatisfied' : 'contradiction: no false operand found');
        break;
      }
      case 'OR':
      case 'NOR': {
        var anyTrue = node_.inputs.some(function (inp) { return childValue(signalValues, inp); });
        if (anyTrue) {
          node_.inputs.forEach(function (inp, idx) {
            if (childValue(signalValues, inp)) out.children.push(childFor(idx)); // the satisfied path(s)
          });
        } else {
          node_.inputs.forEach(function (inp, idx) { out.children.push(childFor(idx)); }); // every alternative, all unsatisfied
        }
        out.note = anyTrue ? 'satisfied via ' + out.children.length + ' path(s)' : 'no operand satisfied — any one would do';
        break;
      }
      case 'XOR': {
        node_.inputs.forEach(function (inp, idx) { out.children.push(childFor(idx)); });
        out.note = 'XOR: odd number of true operands required';
        break;
      }
      case 'NOT': {
        out.children.push(childFor(0));
        out.note = 'inverted';
        break;
      }
      case 'LATCH': {
        var setChild = childFor(0);
        var resetChild = childFor(1);
        out.children.push(setChild, resetChild);
        var dominance = (project.profile.latchDominance || 'reset');
        out.note = 'latch holds ' + value + '; dominance=' + dominance +
          (runtimeExtras && runtimeExtras.latchState && node_.id in runtimeExtras.latchState
            ? ' (stored=' + runtimeExtras.latchState[node_.id] + ')' : '');
        break;
      }
      case 'TIMER': {
        out.children.push(childFor(0));
        var ts = runtimeExtras && runtimeExtras.timerState && runtimeExtras.timerState[node_.id];
        var fields = project.profile.timerFieldOrder === 'dropout-then-pickup'
          ? { pickupMs: node_.params.fieldB || 0, dropoutMs: node_.params.fieldA || 0 }
          : { pickupMs: node_.params.fieldA || 0, dropoutMs: node_.params.fieldB || 0 };
        if (ts) {
          var remaining = ts.phase === 'pickup' ? Math.max(0, fields.pickupMs - ts.elapsed)
            : ts.phase === 'dropout' ? Math.max(0, fields.dropoutMs - ts.elapsed) : 0;
          out.note = 'phase=' + ts.phase + ' elapsed=' + ts.elapsed + 'ms remaining=' + remaining + 'ms' +
            (project.profile.timerFieldOrder === 'unknown' ? ' (timer field order UNVERIFIED — see profile)' : '');
        } else {
          out.note = 'pickup=' + fields.pickupMs + 'ms dropout=' + fields.dropoutMs + 'ms';
        }
        break;
      }
      case 'ONESHOT_POS':
      case 'ONESHOT_NEG': {
        out.children.push(childFor(0));
        out.note = 'single-scan pulse on ' + (node_.type === 'ONESHOT_POS' ? 'rising' : 'falling') + ' edge';
        break;
      }
      case 'CONST_ON':
      case 'CONST_OFF': {
        out.note = 'constant';
        break;
      }
      default:
        out.note = 'unknown node type';
    }

    return out;
  }

  /** "Why won't it close?" — convenience wrapper asserting the target is currently false. */
  function whyWontItClose(project, signalValues, targetSignalId, runtimeExtras) {
    return explain(project, signalValues, targetSignalId, runtimeExtras);
  }

  /** "Why did it open?" — same walk, read as a forward causal explanation of a true signal. */
  function whyDidItOpen(project, signalValues, targetSignalId, runtimeExtras) {
    return explain(project, signalValues, targetSignalId, runtimeExtras);
  }

  return {
    driverNode: driverNode,
    explain: explain,
    whyWontItClose: whyWontItClose,
    whyDidItOpen: whyDidItOpen,
  };
});
