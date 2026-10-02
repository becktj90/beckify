/* ============================================================================
   Switchgear Logic Lab — engine/scenario.js
   Scripted event player: drives external signals and/or forces breaker
   positions over time, steps eval.js + plant.js each tick, and records a
   trace the Timing screen and the transfer-matrix/report builder both read.

   Event shapes:
     { tMs, type: 'input',          signalId, value }
     { tMs, type: 'breakerPosition', breakerId, position: 'open'|'closed' }
     { tMs, type: 'sourceAvailable', sourceId, available }
     { tMs, type: 'fault',          fault: 'fail-to-open'|'fail-to-close'|'slow-breaker'
                                            |'feedback-lie',
       targetId, active, params }

   A logic VO can also command a breaker directly: give the VO signal a
   `physical` of { breakerId, role: 'command-close' | 'command-open' } and the
   runner will operate the breaker operateDelayMs after the command goes true
   (honoring profile.commandTypes momentary/maintained and active faults).
   ============================================================================ */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SwitchgearEngine = root.SwitchgearEngine || {};
    root.SwitchgearEngine.scenario = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  function newScenario(opts) {
    return {
      id: opts.id,
      name: opts.name || 'Scenario',
      durationMs: opts.durationMs || 10000,
      dtMs: opts.dtMs || (opts.profile && opts.profile.scanMs) || 100,
      events: (opts.events || []).slice().sort(function (a, b) { return a.tMs - b.tMs; }),
    };
  }

  function initialPositions(plant) {
    var positions = {};
    plant.breakers.forEach(function (b) { positions[b.id] = b.position || 'open'; });
    return positions;
  }

  function initialAvailability(plant) {
    var avail = {};
    plant.sources.forEach(function (s) { avail[s.id] = s.available !== false; });
    return avail;
  }

  function commandSignals(project) {
    return project.signals.filter(function (s) {
      return s.physical && (s.physical.role === 'command-close' || s.physical.role === 'command-open');
    });
  }

  function feedbackSignals(project) {
    return project.signals.filter(function (s) {
      return s.physical && (s.physical.role === 'feedback-closed' || s.physical.role === 'feedback-open');
    });
  }

  var FAULT_TYPES = ['fail-to-open', 'fail-to-close', 'slow-breaker', 'feedback-lie'];
  function validateScenario(project, scenario) {
    var errors = [];
    if (!scenario || !Number.isFinite(scenario.dtMs) || scenario.dtMs < 1 ||
        !Number.isFinite(scenario.durationMs) || scenario.durationMs < 0 ||
        Math.floor(scenario.durationMs / scenario.dtMs) + 1 > 10000) {
      return ['Use a scan period of at least 1 ms and a duration of at most 10,000 scan steps.'];
    }
    if (!Array.isArray(scenario.events) || scenario.events.length > 1000) return ['Use at most 1000 events.'];
    function has(items, id) { return items.some(function (item) { return item.id === id; }); }
    scenario.events.forEach(function (e) {
      if (!e || !Number.isFinite(e.tMs) || e.tMs < 0 || e.tMs > scenario.durationMs) {
        errors.push('Event time must be within the scenario duration.'); return;
      }
      if (e.type === 'input') {
        if (!has(project.signals, e.signalId) || typeof e.value !== 'boolean') errors.push('Invalid input event.');
      } else if (e.type === 'breakerPosition') {
        if (!has(project.plant.breakers, e.breakerId) || ['open', 'closed'].indexOf(e.position) < 0) errors.push('Invalid breaker event.');
      } else if (e.type === 'sourceAvailable') {
        if (!has(project.plant.sources, e.sourceId) || typeof e.available !== 'boolean') errors.push('Invalid source event.');
      } else if (e.type === 'fault') {
        if (FAULT_TYPES.indexOf(e.fault) < 0 || !has(project.plant.breakers, e.targetId) || typeof e.active !== 'boolean') errors.push('Invalid fault event.');
      } else errors.push('Unknown event type.');
    });
    return errors;
  }

  function run(project, scenario, evalModule, plantModule, opts) {
    opts = opts || {};
    var errors = validateScenario(project, scenario);
    if (errors.length) throw new Error(errors.join(' '));
    var plant = project.plant;
    var rt = evalModule.newRuntime();
    var positions = initialPositions(plant);
    var sourceAvailable = initialAvailability(plant);
    var activeFaults = {}; // key: fault+targetId -> params
    var pendingOps = []; // { breakerId, position, readyAtMs }
    var prevCommand = {}; // signalId -> bool, for momentary edge detection
    var steps = [];
    var allFindings = [];

    var eventsByTick = {};
    scenario.events.forEach(function (ev) {
      var tick = Math.ceil(ev.tMs / scenario.dtMs) * scenario.dtMs;
      eventsByTick[tick] = eventsByTick[tick] || [];
      eventsByTick[tick].push(ev);
    });

    function faultActive(fault, targetId) {
      return activeFaults[fault + '::' + targetId];
    }

    function applyEvent(ev) {
      if (ev.type === 'breakerPosition') {
        positions[ev.breakerId] = ev.position;
      } else if (ev.type === 'sourceAvailable') {
        sourceAvailable[ev.sourceId] = !!ev.available;
      } else if (ev.type === 'fault') {
        var key = ev.fault + '::' + ev.targetId;
        if (ev.active) activeFaults[key] = ev.params || {};
        else delete activeFaults[key];
      }
      // 'input' events are applied as externalInputs below, not here.
    }

    var cmdSigs = commandSignals(project);
    var fbSigs = feedbackSignals(project);

    for (var t = 0; t <= scenario.durationMs; t += scenario.dtMs) {
      (eventsByTick[t] || []).forEach(applyEvent);

      var externalInputs = {};
      (eventsByTick[t] || []).forEach(function (ev) {
        if (ev.type === 'input') externalInputs[ev.signalId] = !!ev.value;
      });

      pendingOps = pendingOps.filter(function (op) {
        if (op.readyAtMs > t) return true;
        if (!faultActive(op.position === 'closed' ? 'fail-to-close' : 'fail-to-open', op.breakerId)) positions[op.breakerId] = op.position;
        return false;
      });

      fbSigs.forEach(function (sig) {
        var brk = plant.breakers.filter(function (b) { return b.id === sig.physical.breakerId; })[0];
        if (!brk) return;
        var actualClosed = positions[brk.id] === 'closed';
        var reported = sig.physical.role === 'feedback-closed' ? actualClosed : !actualClosed;
        if (faultActive('feedback-lie', brk.id)) reported = !reported;
        externalInputs[sig.id] = reported;
      });

      var stepResult = evalModule.step(project, rt, externalInputs, scenario.dtMs);
      rt = stepResult.runtime;

      cmdSigs.forEach(function (sig) {
        var brk = plant.breakers.filter(function (b) { return b.id === sig.physical.breakerId; })[0];
        if (!brk) return;
        var commandedTrue = !!stepResult.signalValues[sig.id];
        var rising = commandedTrue && !prevCommand[sig.id];
        prevCommand[sig.id] = commandedTrue;
        var mode = sig.physical.commandType || (project.profile.commandTypes && project.profile.commandTypes.length === 1 ? project.profile.commandTypes[0] : 'momentary');
        var shouldFire = mode === 'maintained' ? commandedTrue : rising;
        if (!shouldFire) return;

        var targetPosition = sig.physical.role === 'command-close' ? 'closed' : 'open';
        var faultType = targetPosition === 'closed' ? 'fail-to-close' : 'fail-to-open';
        if (brk.lockedOut || brk.primaryDisconnected || faultActive(faultType, brk.id)) return; // command issued, breaker never actually moves

        var delay = brk.operateDelayMs || 0;
        var slow = faultActive('slow-breaker', brk.id);
        if (slow) delay = delay * (slow.multiplier || 5);
        var already = pendingOps.some(function (op) { return op.breakerId === brk.id && op.position === targetPosition; });
        if (!already && positions[brk.id] !== targetPosition) {
          pendingOps.push({ breakerId: brk.id, position: targetPosition, readyAtMs: t + delay });
        }
      });

      var findings = plantModule.analyzeSnapshot(plant, positions, sourceAvailable)
        .concat(plantModule.detectBackfeed(plant, positions, sourceAvailable));
      findings.forEach(function (f) { f.tMs = t; });
      allFindings = allFindings.concat(findings);

      steps.push({
        tMs: t,
        signalValues: Object.assign({}, stepResult.signalValues),
        breakerPositions: Object.assign({}, positions),
        sourceAvailable: Object.assign({}, sourceAvailable),
        undrivenRefs: stepResult.undrivenRefs,
      });
    }

    return { steps: steps, findings: allFindings, finalRuntime: rt };
  }

  function compareProfiles(project, scenario, evalModule, plantModule, field, values) {
    var variants = values.map(function (value) {
      var copy = JSON.parse(JSON.stringify(project));
      copy.profile[field] = value;
      return run(copy, scenario, evalModule, plantModule);
    });
    var signals = {};
    variants[0].steps.forEach(function (step, idx) {
      Object.keys(step.signalValues).forEach(function (id) {
        if (!!step.signalValues[id] !== !!variants[1].steps[idx].signalValues[id]) signals[id] = true;
      });
    });
    return Object.keys(signals);
  }

  return {
    compareProfiles: compareProfiles,
    FAULT_TYPES: FAULT_TYPES,
    validateScenario: validateScenario,
    newScenario: newScenario,
    initialPositions: initialPositions,
    initialAvailability: initialAvailability,
    commandSignals: commandSignals,
    feedbackSignals: feedbackSignals,
    run: run,
  };
});
