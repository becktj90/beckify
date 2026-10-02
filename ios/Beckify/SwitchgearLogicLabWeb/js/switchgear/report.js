/* ============================================================================
   Switchgear Logic Lab — engine/report.js
   Layer 6b (settled-state enumeration) + Phase-1 basic transfer matrix +
   review export builder. Exhaustive bit-packed enumeration when the
   independent boolean input count is <=24; otherwise bounded, honestly
   labeled sampling. Non-exclusive position decodes (two signals in the same
   declared positionGroup both true for some input vector) are detected here,
   against the enumerated table, per the spec's 6a/6b split.
   ============================================================================ */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SwitchgearEngine = root.SwitchgearEngine || {};
    root.SwitchgearEngine.report = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var EXHAUSTIVE_LIMIT = 24;
  var SAMPLE_CAP = 4000;

  function independentInputs(project) {
    return project.signals.filter(function (s) {
      return s.kind === 'VI' || s.kind === 'CI' || s.kind === 'BREAKER_STATE';
    }).map(function (s) { return s.id; });
  }

  function vectorToInputs(ids, mask) {
    var inputs = {};
    ids.forEach(function (id, idx) { inputs[id] = !!(mask & (1 << idx)); });
    return inputs;
  }

  function randomMask(bitCount) {
    var mask = 0;
    for (var i = 0; i < bitCount; i++) {
      if (Math.random() < 0.5) mask |= (1 << i);
    }
    return mask;
  }

  /**
   * Settled-state table: one row per input vector, output values once the
   * engine stops changing under that static input (static timers ignore
   * elapsed time by running enough scans to clear any pickup/dropout — this
   * is a steady-state view, not a timing simulation; Timing screen covers that).
   */
  function enumerateSettledStates(project, evalModule, opts) {
    opts = opts || {};
    var ids = opts.inputIds || independentInputs(project);
    var n = ids.length;
    var exhaustive = n <= EXHAUSTIVE_LIMIT;
    var total = exhaustive ? Math.pow(2, n) : SAMPLE_CAP;
    var rows = [];
    var seen = {};

    for (var i = 0; i < total; i++) {
      var mask = exhaustive ? i : randomMask(n);
      if (!exhaustive) {
        if (seen[mask]) continue;
        seen[mask] = true;
      }
      var inputs = vectorToInputs(ids, mask);
      var settleResult = evalModule.settle(project, evalModule.newRuntime(), inputs, project.profile.scanMs, 500);
      rows.push({
        mask: mask,
        inputs: inputs,
        outputs: Object.assign({}, settleResult.result.signalValues),
        settled: settleResult.settled,
      });
    }

    return { exhaustive: exhaustive, inputIds: ids, rows: rows, count: rows.length, totalPossible: exhaustive ? total : Math.pow(2, n) };
  }

  /** positionGroups: { groupId: [signalId, ...] } — mutually-exclusive decodes by convention. */
  function nonExclusiveDecodes(enumeration, positionGroups) {
    var findings = [];
    Object.keys(positionGroups || {}).forEach(function (groupId) {
      var members = positionGroups[groupId];
      var offendingVectors = [];
      enumeration.rows.forEach(function (row) {
        var trueMembers = members.filter(function (sigId) { return row.outputs[sigId] || row.inputs[sigId]; });
        if (trueMembers.length > 1) offendingVectors.push({ mask: row.mask, members: trueMembers });
      });
      if (offendingVectors.length) {
        findings.push({
          severity: 'critical',
          category: 'non-exclusive-decode',
          title: 'Position group "' + groupId + '" has ' + offendingVectors.length + ' input vector(s) where more than one decode is true at once: ' + members.join(', '),
          evidence: offendingVectors.slice(0, 10),
          suggestedTest: 'Physically cycle the breaker through these conditions and confirm only one position decode is ever asserted.',
          status: 'open',
        });
      }
    });
    return findings;
  }

  /** Collapses a scenario run into distinct plant states and reports which source(s) feed which bus(es) in each — Phase 1's "basic transfer matrix from simple scenarios". */
  function buildTransferMatrix(scenarioResult, plant, plantModule) {
    var rows = [];
    var lastKey = null;
    scenarioResult.steps.forEach(function (step) {
      var key = JSON.stringify(step.breakerPositions) + '|' + JSON.stringify(step.sourceAvailable);
      if (key === lastKey) {
        rows[rows.length - 1].tMsEnd = step.tMs;
        return;
      }
      lastKey = key;
      var energized = plantModule.energizedBuses(plant, step.breakerPositions, step.sourceAvailable);
      var busFeeds = {};
      Object.keys(energized).forEach(function (busId) {
        var sources = {};
        energized[busId].forEach(function (e) { sources[e.sourceId] = true; });
        busFeeds[busId] = Object.keys(sources);
      });
      rows.push({
        tMsStart: step.tMs,
        tMsEnd: step.tMs,
        breakerPositions: Object.assign({}, step.breakerPositions),
        sourceAvailable: Object.assign({}, step.sourceAvailable),
        busFeeds: busFeeds,
      });
    });
    return rows;
  }

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function severityBadge(sev) {
    return '<span class="sgll-badge sgll-badge-' + esc(sev) + '">' + esc(sev) + '</span>';
  }

  /**
   * Printable HTML review package: diagrams/equations summary, I/O table,
   * findings with evidence, assumptions page for every UNVERIFIED setting,
   * and the "Review export, not a vendor settings file" footer on the page.
   * Caller opens this string in a new window/tab and calls print().
   */
  function buildReviewExportHtml(project, findings, enumeration) {
    var profile = project.profile;
    var assumptions = [];
    if (!profile.verified) {
      assumptions.push('Profile "' + profile.vendor + '" (' + profile.id + ') is UNVERIFIED: ' + profile.sourceNote);
    }
    if (profile.timerFieldOrder === 'unknown') assumptions.push('Timer field order is unknown; engine defaults to pickup-then-dropout for live simulation only.');
    if (profile.latchDominance === 'unknown') assumptions.push('Latch dominance is unknown; engine defaults to reset-dominant for live simulation only.');

    var findingsHtml = findings.map(function (finding) {
      return '<tr>' +
        '<td>' + severityBadge(finding.severity) + '</td>' +
        '<td>' + esc(finding.category) + '</td>' +
        '<td>' + esc(finding.title) + '</td>' +
        '<td>' + esc(finding.suggestedTest || '') + '</td>' +
        '<td></td><td></td><td></td>' +
        '</tr>';
    }).join('\n');

    var ioRows = project.signals.map(function (s) {
      return '<tr><td>' + esc(s.kind) + '</td><td>' + esc(s.name) + '</td><td>' + esc(s.number || '') + '</td><td>' + esc(s.description || '') + '</td></tr>';
    }).join('\n');

    var enumSummary = enumeration
      ? '<p>' + enumeration.rows.length + ' of ' + enumeration.totalPossible + ' input vectors ' +
        (enumeration.exhaustive ? 'enumerated exhaustively.' : 'sampled — <strong>bounded, not exhaustive</strong>.') + '</p>'
      : '';

    return '<!doctype html><html><head><meta charset="utf-8"><title>' + esc(project.name) + ' — Review Export</title>' +
      '<style>' +
      'body{font-family:system-ui,sans-serif;color:#111;margin:2rem;}' +
      'h1,h2{border-bottom:2px solid #333;padding-bottom:.25rem}' +
      'table{width:100%;border-collapse:collapse;margin:1rem 0}' +
      'th,td{border:1px solid #ccc;padding:.4rem .6rem;text-align:left;font-size:.9rem}' +
      '.sgll-badge{display:inline-block;padding:.1rem .5rem;border-radius:.3rem;font-size:.75rem;font-weight:600;text-transform:uppercase}' +
      '.sgll-badge-critical{background:#5a1414;color:#ffb4b4}.sgll-badge-high{background:#5a3b14;color:#ffd9a0}' +
      '.sgll-badge-medium{background:#5a5414;color:#f2ec9e}.sgll-badge-low{background:#1c3b1c;color:#b7e3b7}' +
      '.sgll-badge-info{background:#13324a;color:#a8d4f5}' +
      '.sgll-banner{background:#2a1f05;color:#f2c14e;border:1px solid #f2c14e;padding:.75rem 1rem;border-radius:.4rem;margin-bottom:1.5rem;font-weight:600}' +
      '.sgll-footer{margin-top:3rem;padding-top:1rem;border-top:1px solid #999;font-size:.8rem;color:#555}' +
      '@media print{.sgll-footer{position:fixed;bottom:0;left:0;right:0}}' +
      '</style></head><body>' +
      '<div class="sgll-banner">Offline model of programmable switchgear logic. Not a protection or control certification tool. Findings below are candidate findings for engineering judgment, not pass/fail certification.</div>' +
      '<h1>' + esc(project.name) + ' — Review Export</h1>' +
      '<p>Profile: ' + esc(profile.vendor) + ' (' + esc(profile.id) + ') — ' + (profile.verified ? 'verified' : '<strong>UNVERIFIED</strong>') + '</p>' +
      '<h2>Assumptions</h2>' +
      (assumptions.length ? '<ul>' + assumptions.map(function (a) { return '<li>' + esc(a) + '</li>'; }).join('') + '</ul>' : '<p>No unverified assumptions recorded.</p>') +
      '<h2>I/O Table</h2><table><thead><tr><th>Kind</th><th>Name</th><th>Number</th><th>Description</th></tr></thead><tbody>' + ioRows + '</tbody></table>' +
      '<h2>Settled-State Coverage</h2>' + enumSummary +
      '<h2>Findings</h2><table><thead><tr><th>Severity</th><th>Category</th><th>Title</th><th>Suggested test</th><th>Pass</th><th>Fail</th><th>Initials</th></tr></thead><tbody>' + findingsHtml + '</tbody></table>' +
      '<div class="sgll-footer">Review export, not a vendor settings file. Generated by Beckify Switchgear Logic Lab — offline analysis only.</div>' +
      '</body></html>';
  }

  return {
    EXHAUSTIVE_LIMIT: EXHAUSTIVE_LIMIT,
    independentInputs: independentInputs,
    enumerateSettledStates: enumerateSettledStates,
    nonExclusiveDecodes: nonExclusiveDecodes,
    buildTransferMatrix: buildTransferMatrix,
    buildReviewExportHtml: buildReviewExportHtml,
  };
});
