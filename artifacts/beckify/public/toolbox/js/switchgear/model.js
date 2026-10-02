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
    var signalIds = {};
    project.signals.forEach(function (s) {
      if (signalIds[s.id]) errors.push('Duplicate signal id: ' + s.id);
      signalIds[s.id] = true;
    });
    project.nodes.forEach(function (n) {
      if (!signalIds[n.output]) {
        errors.push('Node ' + n.id + ' drives unknown signal: ' + n.output);
      }
      nodeInputRefs(n).forEach(function (ref) {
        if (!signalIds[ref]) {
          errors.push('Node ' + n.id + ' references unknown signal: ' + ref);
        }
      });
    });
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
