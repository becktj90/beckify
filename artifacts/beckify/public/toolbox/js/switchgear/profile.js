/* ============================================================================
   Switchgear Logic Lab — engine/profile.js
   Versioned vendor System Profiles. Every vendor-specific behavior assumption
   lives here, never hardcoded in eval.js, so the engine stays vendor-neutral.
   Each profile declares verified + sourceNote; unverified fields must surface
   an amber "UNVERIFIED" tag in the UI — see 8A visualization + export rules.
   ============================================================================ */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SwitchgearEngine = root.SwitchgearEngine || {};
    root.SwitchgearEngine.profile = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var TIMER_FIELD_ORDERS = ['pickup-then-dropout', 'dropout-then-pickup', 'unknown'];
  var LATCH_DOMINANCES = ['set', 'reset', 'unknown'];
  var EVAL_ORDERS = ['declaration', 'reverse'];
  var COMMAND_TYPES = ['momentary', 'maintained'];

  function assertProfile(p) {
    var errs = [];
    if (TIMER_FIELD_ORDERS.indexOf(p.timerFieldOrder) === -1) errs.push('bad timerFieldOrder');
    if (LATCH_DOMINANCES.indexOf(p.latchDominance) === -1) errs.push('bad latchDominance');
    if (EVAL_ORDERS.indexOf(p.evalOrder) === -1) errs.push('bad evalOrder');
    if (typeof p.scanMs !== 'number' || p.scanMs <= 0) errs.push('bad scanMs');
    if (typeof p.verified !== 'boolean') errs.push('verified must be boolean');
    return errs;
  }

  /** Generic, vendor-agnostic default. Safe to mark verified: our own neutral behavior, no vendor claim. */
  var GENERIC_PROFILE = {
    id: 'generic-v1',
    vendor: 'Generic / unspecified',
    version: '1.0',
    timerFieldOrder: 'pickup-then-dropout',
    latchDominance: 'reset',
    scanMs: 100,
    evalOrder: 'declaration',
    maxTimers: 64,
    maxVirtualOutputs: 256,
    commandTypes: COMMAND_TYPES.slice(),
    verified: true,
    sourceNote: 'Beckify default assumptions for a generic programmable-logic switchgear controller. Not tied to any vendor manual; confirm against your actual device before relying on results.',
  };

  /**
   * Entellisys FlexLogic — first-cut profile, deliberately UNVERIFIED.
   * Section 13 "open items" from the build spec: true eval order, true timer
   * field order, true latch dominance, true scan period are all unconfirmed
   * against a real Entellisys reference manual. Values below are the engine's
   * best inference from the seed printout text and must stay flagged amber
   * until a human confirms them against vendor documentation.
   */
  var ENTELLISYS_FLEXLOGIC_PROFILE = {
    id: 'entellisys-flexlogic-v1',
    vendor: 'Entellisys (FlexLogic)',
    version: '1.0-draft',
    timerFieldOrder: 'unknown',
    latchDominance: 'unknown',
    scanMs: 100,
    evalOrder: 'declaration',
    maxTimers: 128,
    maxVirtualOutputs: 256,
    commandTypes: COMMAND_TYPES.slice(),
    verified: false,
    sourceNote: 'Inferred from a single decoded FlexLogic text printout, not from a vendor reference manual. Evaluation order, timer field order, latch dominance, and scan period are all unconfirmed — see Section 13 open items. Treat every result from this profile as a candidate finding for engineering judgment, not a certified behavior.',
  };

  var BUILTIN_PROFILES = [GENERIC_PROFILE, ENTELLISYS_FLEXLOGIC_PROFILE];

  function byId(id) {
    for (var i = 0; i < BUILTIN_PROFILES.length; i++) {
      if (BUILTIN_PROFILES[i].id === id) return BUILTIN_PROFILES[i];
    }
    return null;
  }

  /** Clone so UI edits (e.g. resolving an 'unknown' field order after human confirmation) never mutate the builtin. */
  function clone(profile) {
    return JSON.parse(JSON.stringify(profile));
  }

  return {
    TIMER_FIELD_ORDERS: TIMER_FIELD_ORDERS,
    LATCH_DOMINANCES: LATCH_DOMINANCES,
    EVAL_ORDERS: EVAL_ORDERS,
    COMMAND_TYPES: COMMAND_TYPES,
    GENERIC_PROFILE: GENERIC_PROFILE,
    ENTELLISYS_FLEXLOGIC_PROFILE: ENTELLISYS_FLEXLOGIC_PROFILE,
    BUILTIN_PROFILES: BUILTIN_PROFILES,
    byId: byId,
    clone: clone,
    assertProfile: assertProfile,
  };
});
