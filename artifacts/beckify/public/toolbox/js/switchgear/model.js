/* ============================================================================
   Switchgear Logic Lab — engine/model.js
   Versioned data model: profile, signals, nodes, plant, scenarios, findings.
   Pure JS. No DOM access. Loaded by both the web UI and the iOS JSCore bridge.
   ============================================================================ */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SwitchgearEngine = root.SwitchgearEngine || {};
    root.SwitchgearEngine.model = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var MODEL_VERSION = 1;

  var NODE_TYPES = [
    'AND', 'OR', 'NOR', 'NAND', 'XOR', 'NOT',
    'LATCH', 'TIMER', 'ONESHOT_POS', 'ONESHOT_NEG',
    'CONST_ON', 'CONST_OFF',
  ];

  var SIGNAL_KINDS = ['VI', 'VO', 'CI', 'PLC', 'RELAY_ELEMENT', 'BREAKER_STATE', 'CONST'];

  var VARIADIC_TYPES = { AND: true, OR: true, NOR: true, NAND: true, XOR: true };
  var SINGLE_INPUT_TYPES = { NOT: true, TIMER: true, ONESHOT_POS: true, ONESHOT_NEG: true };
  var NO_INPUT_TYPES = { CONST_ON: true, CONST_OFF: true };

  function uid(prefix) {
    return prefix + '_' + Math.random().toString(36).slice(2, 10);
  }

  /** A fresh, empty project using the given profile id. Caller supplies the profile object. */
  function newProject(profile) {
    return {
      modelVersion: MODEL_VERSION,
      id: uid('proj'),
      name: 'Untitled switchgear logic project',
      createdAt: new Date().toISOString(),
      profile: profile,
      signals: [],
      nodes: [],
      plant: newPlant(),
      scenarios: [],
      findings: [],
    };
  }

  function newPlant() {
    return {
      breakers: [],
      sources: [],
      buses: [],
      ties: [],
    };
  }

  function newSignal(opts) {
    if (SIGNAL_KINDS.indexOf(opts.kind) === -1) {
      throw new Error('Unknown signal kind: ' + opts.kind);
    }
    return {
      id: opts.id || uid('sig'),
      kind: opts.kind,
      name: opts.name || opts.id || 'signal',
      number: opts.number || null,
      description: opts.description || '',
      direction: opts.direction || (opts.kind === 'VO' ? 'output' : opts.kind === 'CONST' ? 'internal' : 'input'),
      physical: opts.physical || null,
    };
  }

  function newNode(opts) {
    if (NODE_TYPES.indexOf(opts.type) === -1) {
      throw new Error('Unknown node type: ' + opts.type);
    }
    var inputs = opts.inputs || [];
    if (NO_INPUT_TYPES[opts.type] && inputs.length !== 0) {
      throw new Error(opts.type + ' takes no inputs');
    }
    if (SINGLE_INPUT_TYPES[opts.type] && inputs.length !== 1) {
      throw new Error(opts.type + ' requires exactly 1 input');
    }
    if (opts.type === 'LATCH' && inputs.length !== 2) {
      throw new Error('LATCH requires exactly 2 inputs: [set, reset]');
    }
    if (VARIADIC_TYPES[opts.type] && inputs.length < 1) {
      throw new Error(opts.type + ' requires at least 1 input');
    }
    if (opts.type === 'TIMER' && ['fieldA', 'fieldB'].some(function (field) {
      return opts.params && opts.params[field] != null && (!Number.isFinite(opts.params[field]) || opts.params[field] < 0);
    })) throw new Error('Timer delays must be finite nonnegative milliseconds.');
    return {
      id: opts.id || uid('node'),
      type: opts.type,
      inputs: inputs.map(function (i) {
        return { ref: i.ref, invert: !!i.invert };
      }),
      params: opts.params || {},
      output: opts.output,
      sourceLine: opts.sourceLine || null,
      verified: opts.verified !== false,
    };
  }

  function newFinding(opts) {
    return {
      id: opts.id || uid('find'),
      severity: opts.severity || 'info',
      category: opts.category,
      title: opts.title,
      evidence: opts.evidence || [],
      suggestedTest: opts.suggestedTest || null,
      status: opts.status || 'open',
    };
  }

  /** Every signal id a node reads from, independent of node type quirks. */
  function nodeInputRefs(node) {
    return node.inputs.map(function (i) { return i.ref; });
  }

  function findSignal(project, id) {
    for (var i = 0; i < project.signals.length; i++) {
      if (project.signals[i].id === id) return project.signals[i];
    }
    return null;
  }

  function findNode(project, id) {
    for (var i = 0; i < project.nodes.length; i++) {
      if (project.nodes[i].id === id) return project.nodes[i];
    }
    return null;
  }

  /** The node (if any) whose `output` drives this signal id. Multiple drivers is a lint finding, not a throw. */
  function driversOf(project, signalId) {
    return project.nodes.filter(function (n) { return n.output === signalId; });
  }

  function validateProject(project) {
    var errors = [];
    function object(v) { return v && typeof v === 'object' && !Array.isArray(v); }
    function finite(v, min) { return typeof v === 'number' && Number.isFinite(v) && v >= min; }
    if (!object(project)) return ['Project must be an object.'];
    if (project.modelVersion !== MODEL_VERSION) errors.push('Unsupported project version.');
    if (typeof project.name !== 'string') errors.push('Project name must be text.');
    var profile = project.profile;
    if (!object(profile) || !finite(profile.scanMs, 1) ||
        ['pickup-then-dropout', 'dropout-then-pickup', 'unknown'].indexOf(profile.timerFieldOrder) < 0 ||
        ['set', 'reset', 'unknown'].indexOf(profile.latchDominance) < 0 ||
        ['declaration', 'reverse'].indexOf(profile.evalOrder) < 0 || typeof profile.verified !== 'boolean') {
      errors.push('Invalid system profile.');
    }
    function records(items, label, limit) {
      if (!Array.isArray(items) || items.length > limit) {
        errors.push(label + ' must be an array of at most ' + limit + ' entries.');
        return [];
      }
      var seen = Object.create(null);
      return items.filter(function (item) {
        if (!object(item) || typeof item.id !== 'string' || !item.id ||
            ['__proto__', 'constructor', 'prototype'].indexOf(item.id) >= 0) {
          errors.push('Invalid ' + label + ' entry or id.'); return false;
        }
        if (seen[item.id]) errors.push('Duplicate ' + label + ' id: ' + item.id);
        seen[item.id] = true;
        return true;
      });
    }
    var signals = records(project.signals, 'signal', 256);
    var nodes = records(project.nodes, 'node', 256);
    var signalIds = Object.create(null);
    signals.forEach(function (s) {
      signalIds[s.id] = true;
      if (SIGNAL_KINDS.indexOf(s.kind) < 0 || typeof s.name !== 'string') errors.push('Invalid signal: ' + s.id);
    });
    nodes.forEach(function (n) {
      try { newNode(n); } catch (e) { errors.push('Node ' + n.id + ': ' + e.message); return; }
      if (!Array.isArray(n.inputs) || !object(n.params)) { errors.push('Invalid node fields: ' + n.id); return; }
      if (!signalIds[n.output]) errors.push('Node ' + n.id + ' drives unknown signal: ' + n.output);
      n.inputs.forEach(function (input) {
        if (!object(input) || !signalIds[input.ref]) errors.push('Node ' + n.id + ' references unknown signal.');
      });
      if (n.type === 'TIMER' && !['fieldA', 'fieldB'].every(function (key) {
        return n.params[key] == null || finite(n.params[key], 0);
      })) errors.push('Timer fields must be finite nonnegative milliseconds: ' + n.id);
    });
    if (!object(project.plant)) errors.push('Missing plant.');
    else {
      var buses = records(project.plant.buses, 'bus', 32);
      var sources = records(project.plant.sources, 'source', 32);
      var breakers = records(project.plant.breakers, 'breaker', 64);
      function has(items, id) { return items.some(function (item) { return item.id === id; }); }
      breakers.forEach(function (b) {
        if (!has(buses, b.connectsBusA) || (b.connectsBusB && !has(buses, b.connectsBusB)) ||
            (b.sourceId && !has(sources, b.sourceId)) || ['open', 'closed'].indexOf(b.position) < 0 ||
            !finite(b.operateDelayMs, 0)) errors.push('Invalid breaker topology or timing: ' + b.id);
      });
      signals.forEach(function (s) {
        if (s.physical && (!object(s.physical) || !has(breakers, s.physical.breakerId) ||
            ['command-close', 'command-open', 'feedback-closed', 'feedback-open'].indexOf(s.physical.role) < 0)) {
          errors.push('Invalid breaker mapping: ' + s.id);
        }
      });
    }
    records(project.scenarios, 'scenario', 100).forEach(function (scenario) {
      if (typeof scenario.name !== 'string' || !Array.isArray(scenario.events) || scenario.events.length > 1000 ||
          !finite(scenario.durationMs, 0) || !finite(scenario.dtMs, 1)) errors.push('Invalid scenario: ' + scenario.id);
    });
    if (!Array.isArray(project.findings) || project.findings.some(function (f) {
      return !object(f) || typeof f.title !== 'string' || !Array.isArray(f.evidence);
    })) errors.push('Invalid findings.');
    return errors;
  }

  return {
    MODEL_VERSION: MODEL_VERSION,
    NODE_TYPES: NODE_TYPES,
    SIGNAL_KINDS: SIGNAL_KINDS,
    VARIADIC_TYPES: VARIADIC_TYPES,
    SINGLE_INPUT_TYPES: SINGLE_INPUT_TYPES,
    NO_INPUT_TYPES: NO_INPUT_TYPES,
    uid: uid,
    newProject: newProject,
    newPlant: newPlant,
    newSignal: newSignal,
    newNode: newNode,
    newFinding: newFinding,
    nodeInputRefs: nodeInputRefs,
    findSignal: findSignal,
    findNode: findNode,
    driversOf: driversOf,
    validateProject: validateProject,
  };
});
