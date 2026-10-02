/* ============================================================================
   Switchgear Logic Lab — engine/plant.js
   One-line topology: breakers, sources, buses. Derives bus energization from
   breaker positions + source availability, and flags parallel-of-two-sources,
   dead-bus close, backfeed, and unintended source ties. Breaker commands
   (open/close) go through an operate delay and report a position-feedback
   signal separately from the commanded state, so "fail to open/close" and
   "feedback lie" fault injection (scenario.js) has somewhere to act.
   ============================================================================ */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SwitchgearEngine = root.SwitchgearEngine || {};
    root.SwitchgearEngine.plant = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  function newBreaker(opts) {
    return {
      id: opts.id,
      label: opts.label || opts.id,
      role: opts.role || 'tie', // 'main' | 'generator' | 'tie' | 'feeder'
      connectsBusA: opts.connectsBusA,
      connectsBusB: opts.connectsBusB || null, // null for a main/feeder breaker that only ties to one bus + a source
      sourceId: opts.sourceId || null,
      operateDelayMs: opts.operateDelayMs || 0,
      position: opts.position || 'open', // commanded/actual settled position for static plant snapshots
      primaryDisconnected: !!opts.primaryDisconnected,
      lockedOut: !!opts.lockedOut,
    };
  }

  function newSource(opts) {
    return {
      id: opts.id,
      label: opts.label || opts.id,
      kind: opts.kind || 'utility', // 'utility' | 'generator'
      available: opts.available !== false,
    };
  }

  function newBus(opts) {
    return { id: opts.id, label: opts.label || opts.id };
  }

  function newPlantModel() {
    return { breakers: [], sources: [], buses: [] };
  }

  function busesOf(breaker) {
    var list = [breaker.connectsBusA];
    if (breaker.connectsBusB) list.push(breaker.connectsBusB);
    return list;
  }

  /**
   * Energization snapshot from a position map ({breakerId: 'open'|'closed'})
   * and a source availability map ({sourceId: bool}). Pure graph walk: a bus
   * is energized if it is reachable, through closed breakers, from an
   * available source.
   */
  function energizedBuses(plant, positions, sourceAvailable) {
    var adjacency = {}; // busId -> [{busId, breakerId}]
    plant.buses.forEach(function (b) { adjacency[b.id] = []; });
    var sourceFeeds = {}; // busId -> [{sourceId, breakerId}]
    plant.buses.forEach(function (b) { sourceFeeds[b.id] = []; });

    plant.breakers.forEach(function (brk) {
      var closed = positions[brk.id] === 'closed';
      if (!closed) return;
      if (brk.sourceId) {
        sourceFeeds[brk.connectsBusA].push({ sourceId: brk.sourceId, breakerId: brk.id });
      } else if (brk.connectsBusB) {
        adjacency[brk.connectsBusA].push({ busId: brk.connectsBusB, breakerId: brk.id });
        adjacency[brk.connectsBusB].push({ busId: brk.connectsBusA, breakerId: brk.id });
      }
    });

    var energized = {}; // busId -> [{sourceId, path: [breakerId,...]}]
    plant.buses.forEach(function (b) { energized[b.id] = []; });

    function bfsFromSource(sourceId, startBusId, startBreakerId) {
      var visited = {};
      var queue = [{ busId: startBusId, path: [startBreakerId] }];
      visited[startBusId] = true;
      while (queue.length) {
        var cur = queue.shift();
        energized[cur.busId].push({ sourceId: sourceId, path: cur.path });
        adjacency[cur.busId].forEach(function (edge) {
          if (visited[edge.busId]) return;
          visited[edge.busId] = true;
          queue.push({ busId: edge.busId, path: cur.path.concat([edge.breakerId]) });
        });
      }
    }

    plant.buses.forEach(function (b) {
      sourceFeeds[b.id].forEach(function (feed) {
        if (sourceAvailable[feed.sourceId]) {
          bfsFromSource(feed.sourceId, b.id, feed.breakerId);
        }
      });
    });

    return energized;
  }

  /**
   * Weakness checks on a single static position snapshot. Returns plain
   * finding-shaped objects (severity/category/title/evidence); trace.js and
   * lint.js both reuse this against scenario time-steps for dynamic checks.
   */
  function analyzeSnapshot(plant, positions, sourceAvailable) {
    var findings = [];
    var energized = energizedBuses(plant, positions, sourceAvailable);

    Object.keys(energized).forEach(function (busId) {
      var feeds = energized[busId];
      var distinctSources = {};
      feeds.forEach(function (f) { distinctSources[f.sourceId] = true; });
      var sourceIds = Object.keys(distinctSources);
      if (sourceIds.length > 1) {
        findings.push({
          severity: 'high',
          category: 'parallel-sources',
          title: 'Bus ' + busId + ' is fed by ' + sourceIds.length + ' sources simultaneously: ' + sourceIds.join(', '),
          evidence: feeds.map(function (f) { return { sourceId: f.sourceId, path: f.path }; }),
        });
      }
    });

    plant.breakers.forEach(function (brk) {
      if (positions[brk.id] !== 'closed') return;
      if (brk.primaryDisconnected) {
        findings.push({
          severity: 'critical',
          category: 'close-on-disconnected',
          title: 'Breaker ' + brk.label + ' commanded/shown closed while primary-disconnected (racked out / test position)',
          evidence: [{ breakerId: brk.id }],
        });
      }
      if (brk.lockedOut) {
        findings.push({
          severity: 'critical',
          category: 'close-on-lockout',
          title: 'Breaker ' + brk.label + ' commanded/shown closed while locked out',
          evidence: [{ breakerId: brk.id }],
        });
      }
    });

    return findings;
  }

  /** Backfeed: a de-energized utility source's bus becomes energized from the opposite side through a closed tie/generator path. */
  function detectBackfeed(plant, positions, sourceAvailable) {
    var energized = energizedBuses(plant, positions, sourceAvailable);
    var findings = [];
    plant.sources.forEach(function (src) {
      if (sourceAvailable[src.id]) return;
      var feedingBreaker = plant.breakers.filter(function (b) { return b.sourceId === src.id; })[0];
      if (!feedingBreaker || positions[feedingBreaker.id] !== 'closed' || feedingBreaker.primaryDisconnected) return;
      var bus = feedingBreaker.connectsBusA;
      var feeds = (energized[bus] || []).filter(function (f) { return f.sourceId !== src.id; });
      if (feeds.length) {
        findings.push({
          severity: 'critical',
          category: 'backfeed',
          title: 'Unavailable source ' + src.label + ' is energized from elsewhere (backfeed) via bus ' + bus,
          evidence: feeds,
        });
      }
    });
    return findings;
  }

  return {
    newBreaker: newBreaker,
    newSource: newSource,
    newBus: newBus,
    newPlantModel: newPlantModel,
    busesOf: busesOf,
    energizedBuses: energizedBuses,
    analyzeSnapshot: analyzeSnapshot,
    detectBackfeed: detectBackfeed,
  };
});
