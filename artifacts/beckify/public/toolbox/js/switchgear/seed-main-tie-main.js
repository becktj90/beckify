/* ============================================================================
   Switchgear Logic Lab — js/switchgear/seed-main-tie-main.js
   A small, GENERIC (non-vendor) demo project: main-tie-main with a generator,
   two interlocked close-permissive gates, and one timer — just enough to
   click around the Phase 1 screens. This is NOT the Entellisys FlexLogic
   seed project from the Phase 2 spec (that one ships with its own 10
   acceptance findings); this is a vendor-neutral starter using the generic
   profile.
   ============================================================================ */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SwitchgearEngine = root.SwitchgearEngine || {};
    root.SwitchgearEngine.seedMainTieMain = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  function build(model, profileModule, plantModule) {
    var profile = profileModule.clone(profileModule.GENERIC_PROFILE);
    var project = model.newProject(profile);
    project.name = 'Demo: Main-Tie-Main with Generator';

    var S = model.newSignal;
    project.signals = [
      S({ id: 'utility1Ok', kind: 'VI', name: 'Utility 1 Healthy', description: 'Utility source 1 voltage/phase OK' }),
      S({ id: 'utility2Ok', kind: 'VI', name: 'Utility 2 Healthy', description: 'Utility source 2 voltage/phase OK' }),
      S({ id: 'genRunning', kind: 'VI', name: 'Generator Running' }),
      S({ id: 'main1Fb', kind: 'BREAKER_STATE', name: 'Main 1 Closed Feedback', physical: { breakerId: 'main1', role: 'feedback-closed' } }),
      S({ id: 'main2Fb', kind: 'BREAKER_STATE', name: 'Main 2 Closed Feedback', physical: { breakerId: 'main2', role: 'feedback-closed' } }),
      S({ id: 'tieFb', kind: 'BREAKER_STATE', name: 'Tie Closed Feedback', physical: { breakerId: 'tie', role: 'feedback-closed' } }),
      S({ id: 'main1CloseCmd', kind: 'VO', name: 'Main 1 Close Command', physical: { breakerId: 'main1', role: 'command-close' } }),
      S({ id: 'tieCloseCmd', kind: 'VO', name: 'Tie Close Command', physical: { breakerId: 'tie', role: 'command-close' } }),
      S({ id: 'tieClosePermissive', kind: 'VO', name: 'Tie Close Permissive' }),
      S({ id: 'notMain1', kind: 'VO', name: 'Main 1 Not Closed (internal)' }),
      S({ id: 'genOnDelay', kind: 'VO', name: 'Generator Run Confirmed (2s)' }),
    ];

    project.nodes = [
      model.newNode({ id: 'n_notMain1', type: 'NOT', inputs: [{ ref: 'main1Fb' }], output: 'notMain1' }),
      model.newNode({
        id: 'n_tiePermissive', type: 'AND',
        inputs: [{ ref: 'notMain1' }, { ref: 'genOnDelay' }],
        output: 'tieClosePermissive',
      }),
      model.newNode({
        id: 'n_genDelay', type: 'TIMER',
        inputs: [{ ref: 'genRunning' }],
        output: 'genOnDelay',
        params: { fieldA: 2000, fieldB: 0 },
      }),
      model.newNode({ id: 'n_main1cmd', type: 'AND', inputs: [{ ref: 'utility1Ok' }], output: 'main1CloseCmd' }),
      model.newNode({ id: 'n_tiecmd', type: 'AND', inputs: [{ ref: 'tieClosePermissive' }], output: 'tieCloseCmd' }),
    ];

    project.plant = plantModule.newPlantModel();
    project.plant.buses.push(
      plantModule.newBus({ id: 'bus1', label: 'Bus 1' }),
      plantModule.newBus({ id: 'bus2', label: 'Bus 2' })
    );
    project.plant.sources.push(
      plantModule.newSource({ id: 'utility1', label: 'Utility 1', kind: 'utility' }),
      plantModule.newSource({ id: 'utility2', label: 'Utility 2', kind: 'utility' }),
      plantModule.newSource({ id: 'generator1', label: 'Generator 1', kind: 'generator', available: false })
    );
    project.plant.breakers.push(
      plantModule.newBreaker({ id: 'main1', label: 'Main 1 (52-1)', role: 'main', connectsBusA: 'bus1', sourceId: 'utility1', operateDelayMs: 300, position: 'open' }),
      plantModule.newBreaker({ id: 'main2', label: 'Main 2 (52-2)', role: 'main', connectsBusA: 'bus2', sourceId: 'utility2', operateDelayMs: 300, position: 'closed' }),
      plantModule.newBreaker({ id: 'gen1', label: 'Generator Breaker (52-G)', role: 'generator', connectsBusA: 'bus2', sourceId: 'generator1', operateDelayMs: 300, position: 'open' }),
      plantModule.newBreaker({ id: 'tie', label: 'Tie (52-T)', role: 'tie', connectsBusA: 'bus1', connectsBusB: 'bus2', operateDelayMs: 500, position: 'open' })
    );

    project.scenarios = [{
      id: 'sc_demo', name: 'Utility 1 loss, generator start, tie closes',
      durationMs: 6000, dtMs: 100,
      events: [
        { tMs: 0, type: 'input', signalId: 'utility1Ok', value: true },
        { tMs: 0, type: 'input', signalId: 'utility2Ok', value: true },
        { tMs: 0, type: 'breakerPosition', breakerId: 'main1', position: 'closed' },
        { tMs: 500, type: 'input', signalId: 'utility1Ok', value: false },
        { tMs: 500, type: 'sourceAvailable', sourceId: 'utility1', available: false },
        { tMs: 500, type: 'breakerPosition', breakerId: 'main1', position: 'open' },
        { tMs: 800, type: 'input', signalId: 'genRunning', value: true },
        { tMs: 800, type: 'sourceAvailable', sourceId: 'generator1', available: true },
        { tMs: 1000, type: 'breakerPosition', breakerId: 'gen1', position: 'closed' },
      ],
    }];

    return project;
  }

  return { build: build };
});
