/* ============================================================================
   Switchgear Logic Lab — engine/lint.js
   Layer 6a: static lint. Zero evaluation — pure structural analysis of the
   model graph. (Layer 6b settled-state enumeration, which needs to actually
   run the logic, lives in report.js.) Every check returns finding-shaped
   objects: { severity, category, title, evidence, suggestedTest }.
   ============================================================================ */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SwitchgearEngine = root.SwitchgearEngine || {};
    root.SwitchgearEngine.lint = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  function f(severity, category, title, evidence, suggestedTest) {
    return { severity: severity, category: category, title: title, evidence: evidence || [], suggestedTest: suggestedTest || null, status: 'open' };
  }

  function constantOperands(project) {
    var constOutputs = {};
    project.nodes.forEach(function (n) {
      if (n.type === 'CONST_ON' || n.type === 'CONST_OFF') constOutputs[n.output] = n.type;
    });
    project.signals.forEach(function (s) { if (s.kind === 'CONST') constOutputs[s.id] = 'CONST'; });

    var out = [];
    project.nodes.forEach(function (n) {
      n.inputs.forEach(function (inp) {
        if (constOutputs[inp.ref]) {
          out.push(f('medium', 'placeholder-constant',
            'Node ' + n.id + ' (' + n.type + ') has a constant operand (' + constOutputs[inp.ref] + ') wired to ' + inp.ref,
            [{ nodeId: n.id, signalId: inp.ref }],
            'Confirm this is an intentional placeholder/force, not an unfinished interlock.'));
        }
      });
    });
    return out;
  }

  function undrivenAndUnconsumed(project) {
    var out = [];
    var drivenSignals = {};
    project.nodes.forEach(function (n) { drivenSignals[n.output] = true; });
    var consumedSignals = {};
    project.nodes.forEach(function (n) { n.inputs.forEach(function (i) { consumedSignals[i.ref] = true; }); });

    project.signals.forEach(function (s) {
      var isExternalInput = s.kind === 'VI' || s.kind === 'CI' || s.kind === 'BREAKER_STATE' || s.kind === 'CONST';
      if (!isExternalInput && !drivenSignals[s.id] && consumedSignals[s.id]) {
        out.push(f('high', 'undriven-reference',
          'Signal ' + s.name + ' (' + s.id + ') is referenced by logic but has no driving node — it evaluates false',
          [{ signalId: s.id }],
          'Confirm whether this is driven on another sheet/profile not yet entered.'));
      }
      if (drivenSignals[s.id] && !consumedSignals[s.id] && s.kind !== 'VO') {
        out.push(f('low', 'unconsumed-output',
          'Signal ' + s.name + ' (' + s.id + ') is driven but never read by any other node',
          [{ signalId: s.id }]));
      }
    });
    return out;
  }

  function duplicateDrivers(project) {
    var bySignal = {};
    project.nodes.forEach(function (n) {
      bySignal[n.output] = bySignal[n.output] || [];
      bySignal[n.output].push(n.id);
    });
    var out = [];
    Object.keys(bySignal).forEach(function (sig) {
      if (bySignal[sig].length > 1) {
        out.push(f('critical', 'duplicate-driver',
          'Signal ' + sig + ' is driven by ' + bySignal[sig].length + ' nodes: ' + bySignal[sig].join(', '),
          bySignal[sig].map(function (id) { return { nodeId: id }; }),
          'Resolve which node is authoritative, or combine with an explicit gate.'));
      }
    });
    return out;
  }

  function latchReachableReset(project) {
    var driverByOutput = {};
    project.nodes.forEach(function (n) { driverByOutput[n.output] = n; });

    function reachesExternal(signalId, visited) {
      visited = visited || {};
      if (visited[signalId]) return false;
      visited[signalId] = true;
      var sig = project.signals.filter(function (s) { return s.id === signalId; })[0];
      if (sig && (sig.kind === 'VI' || sig.kind === 'CI' || sig.kind === 'BREAKER_STATE')) return true;
      var node = driverByOutput[signalId];
      if (!node) return false;
      if (node.type === 'CONST_ON' || node.type === 'CONST_OFF') return false;
      return node.inputs.some(function (inp) { return reachesExternal(inp.ref, visited); });
    }

    var out = [];
    project.nodes.filter(function (n) { return n.type === 'LATCH'; }).forEach(function (n) {
      var resetRef = n.inputs[1].ref;
      if (!reachesExternal(resetRef)) {
        out.push(f('critical', 'latch-no-reachable-reset',
          'Latch ' + n.id + ' driving ' + n.output + ' has no reset path traceable to any external input',
          [{ nodeId: n.id, resetRef: resetRef }],
          'Manually cycle every upstream condition on the reset side and confirm the output can actually clear.'));
      }
    });
    return out;
  }

  function redundantTerms(project) {
    var out = [];
    project.nodes.forEach(function (n) {
      var seen = {};
      var dupes = [];
      n.inputs.forEach(function (inp) {
        var key = inp.ref + '|' + inp.invert;
        if (seen[key]) dupes.push(inp.ref);
        seen[key] = true;
      });
      if (dupes.length) {
        out.push(f('low', 'redundant-term',
          'Node ' + n.id + ' (' + n.type + ') repeats operand(s): ' + dupes.join(', '),
          [{ nodeId: n.id }]));
      }
    });
    return out;
  }

  function timerIssues(project) {
    var out = [];
    var timers = project.nodes.filter(function (n) { return n.type === 'TIMER'; });
    timers.forEach(function (n) {
      var a = n.params.fieldA || 0;
      var b = n.params.fieldB || 0;
      if (a === 0 && b === 0) {
        out.push(f('medium', 'pass-through-timer',
          'Timer ' + n.id + ' has both fields at 0 — it passes its input straight through with no delay',
          [{ nodeId: n.id }],
          'Confirm a 0/0 timer here is intentional and not a placeholder for an unset delay.'));
      }
    });
    if (project.profile.timerFieldOrder === 'unknown' && timers.length) {
      out.push(f('high', 'timer-field-order-unverified',
        'Profile timer field order is UNVERIFIED — ' + timers.length + ' timer(s) may have pickup/dropout swapped',
        timers.map(function (n) { return { nodeId: n.id }; }),
        'Confirm true field order against the vendor reference manual, then set profile.timerFieldOrder.'));
    }
    if (project.profile.maxTimers && timers.length > project.profile.maxTimers) {
      out.push(f('high', 'profile-limit-timers',
        'Project uses ' + timers.length + ' timers, exceeding profile limit of ' + project.profile.maxTimers,
        []));
    }
    return out;
  }

  function profileLimits(project) {
    var out = [];
    var voCount = project.signals.filter(function (s) { return s.kind === 'VO'; }).length;
    if (project.profile.maxVirtualOutputs && voCount > project.profile.maxVirtualOutputs) {
      out.push(f('high', 'profile-limit-vo',
        'Project uses ' + voCount + ' virtual outputs, exceeding profile limit of ' + project.profile.maxVirtualOutputs,
        []));
    }
    return out;
  }

  /** Signals read by logic feeding 2+ distinct VO outputs — a shared dependency that can fail multiple "independent" interlocks at once. */
  function commonCauseDependencies(project) {
    var driverByOutput = {};
    project.nodes.forEach(function (n) { driverByOutput[n.output] = n; });
    var voSignals = project.signals.filter(function (s) { return s.kind === 'VO'; });

    function upstreamSignals(signalId, acc, visited) {
      visited = visited || {};
      if (visited[signalId]) return;
      visited[signalId] = true;
      acc.add(signalId);
      var node = driverByOutput[signalId];
      if (!node) return;
      node.inputs.forEach(function (inp) { upstreamSignals(inp.ref, acc, visited); });
    }

    var reachFromVO = {}; // signalId -> Set(voId)
    voSignals.forEach(function (vo) {
      var acc = new Set();
      upstreamSignals(vo.id, acc);
      acc.forEach(function (sigId) {
        reachFromVO[sigId] = reachFromVO[sigId] || new Set();
        reachFromVO[sigId].add(vo.id);
      });
    });

    var out = [];
    Object.keys(reachFromVO).forEach(function (sigId) {
      var vos = Array.from(reachFromVO[sigId]);
      if (vos.length >= 2 && sigId !== vos[0]) {
        out.push(f('medium', 'common-cause-dependency',
          'Signal ' + sigId + ' feeds ' + vos.length + ' separate virtual outputs: ' + vos.join(', '),
          [{ signalId: sigId, affectedVOs: vos }],
          'If these outputs are meant to be independent interlocks, a single failure of this signal defeats all of them at once — confirm that is acceptable.'));
      }
    });
    return out;
  }

  function labelMismatches(project) {
    var out = [];
    (project.plant.breakers || []).forEach(function (b) {
      if (b.labelNote) {
        out.push(f('medium', 'label-mismatch', 'Breaker ' + b.id + ': ' + b.labelNote, [{ breakerId: b.id }]));
      }
    });
    project.signals.forEach(function (s) {
      if (s.labelNote) {
        out.push(f('medium', 'label-mismatch', 'Signal ' + s.name + ' (' + s.id + '): ' + s.labelNote, [{ signalId: s.id }]));
      }
    });
    return out;
  }

  function combinationalLoops(project, evalModule) {
    var graph = evalModule.analyzeCombinationalGraph(project);
    return graph.cycles.map(function (cycle) {
      return f('critical', 'combinational-loop',
        'Combinational loop through nodes: ' + cycle.join(' -> '),
        cycle.map(function (id) { return { nodeId: id }; }),
        'Break the loop with a latch/timer, or confirm the evaluation order makes this settle as intended.');
    });
  }

  function lintProject(project, evalModule) {
    var findings = []
      .concat(constantOperands(project))
      .concat(undrivenAndUnconsumed(project))
      .concat(duplicateDrivers(project))
      .concat(latchReachableReset(project))
      .concat(redundantTerms(project))
      .concat(timerIssues(project))
      .concat(profileLimits(project))
      .concat(commonCauseDependencies(project))
      .concat(labelMismatches(project));
    if (evalModule) findings = findings.concat(combinationalLoops(project, evalModule));
    return findings;
  }

  return {
    constantOperands: constantOperands,
    undrivenAndUnconsumed: undrivenAndUnconsumed,
    duplicateDrivers: duplicateDrivers,
    latchReachableReset: latchReachableReset,
    redundantTerms: redundantTerms,
    timerIssues: timerIssues,
    profileLimits: profileLimits,
    commonCauseDependencies: commonCauseDependencies,
    labelMismatches: labelMismatches,
    combinationalLoops: combinationalLoops,
    lintProject: lintProject,
  };
});
