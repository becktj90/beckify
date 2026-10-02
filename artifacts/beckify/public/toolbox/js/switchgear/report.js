/* ============================================================================
   Switchgear Logic Lab — engine/report.js
   Layer 6b (settled-state enumeration) + Phase-1 basic transfer matrix +
   review export builder. Exhaustive bit-packed enumeration when the
   independent boolean input count is <=10; otherwise bounded, honestly
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

  var EXHAUSTIVE_LIMIT = 10;
  var SAMPLE_CAP = 1024;

  function independentInputs(project) {
    return project.signals.filter(function (s) {
      return ['VI', 'CI', 'BREAKER_STATE', 'PLC', 'RELAY_ELEMENT'].indexOf(s.kind) >= 0 && !project.nodes.some(function (node) { return node.output === s.id; });
    }).map(function (s) { return s.id; });
  }

  /** At most 1024 vectors, with independent bits even above 32 inputs. */
  function enumerateSettledStates(project, evalModule, opts) {
    opts = opts || {};
    var ids = opts.inputIds || independentInputs(project);
    var n = ids.length;
    var exhaustive = n <= EXHAUSTIVE_LIMIT;
    var cap = Math.min(SAMPLE_CAP, Math.max(1, opts.sampleCap || SAMPLE_CAP));
    var total = exhaustive ? Math.pow(2, n) : cap;
    var rows = [];
    var seen = Object.create(null);
    for (var i = 0; i < total; i++) {
      var bits = ids.map(function (_, idx) {
        return exhaustive ? !!(i & (1 << idx)) : i === 0 ? false : i === 1 ? true : Math.random() < 0.5;
      });
      var key = bits.map(Number).join('');
      if (seen[key]) continue;
      seen[key] = true;
      var inputs = {};
      ids.forEach(function (id, idx) { inputs[id] = bits[idx]; });
      var result = evalModule.settle(project, evalModule.newRuntime(), inputs, project.profile.scanMs, 500);
      rows.push({ mask: exhaustive ? i : key, inputs: inputs,
        outputs: Object.assign({}, result.result.signalValues), settled: result.settled });
    }
    return { exhaustive: exhaustive, inputIds: ids, rows: rows, count: rows.length,
      totalPossible: Math.pow(2, n), unsettledCount: rows.filter(function (row) { return !row.settled; }).length };
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
  function buildReviewExportHtml(project, findings, enumeration, transferMatrix) {
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
        '<td>' + esc(finding.title) + '<br>Status: ' + esc(finding.status || 'open') + '<pre>' + esc(JSON.stringify(finding.evidence || [], null, 2)) + '</pre></td>' +
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
      : '<p>Not run for the current project.</p>';

    var logicHtml = project.nodes.map(function (node) {
      return '<tr><td>' + esc(node.output) + '</td><td>' + esc(node.type) + '</td><td>' +
        esc(node.inputs.map(function (input) { return (input.invert ? 'NOT ' : '') + input.ref; }).join(', ')) +
        '</td><td>' + esc(JSON.stringify(node.params)) + '</td></tr>';
    }).join('');
    var transferHtml = transferMatrix ? transferMatrix.map(function (row) {
      return '<tr><td>' + row.tMsStart + '–' + row.tMsEnd + '</td><td>' +
        esc(JSON.stringify(row.breakerPositions)) + '</td><td>' + esc(JSON.stringify(row.busFeeds)) + '</td></tr>';
    }).join('') : '';
    return '<!doctype html><html><head><meta charset="utf-8"><title>' + esc(project.name) + ' — Review Export</title>' +
      '<style>' +
      'pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:.8rem}' +
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
      '<h2>Logic</h2><table><thead><tr><th>Output</th><th>Type</th><th>Inputs</th><th>Parameters</th></tr></thead><tbody>' + logicHtml + '</tbody></table>' +
      '<h2>Plant and breaker mappings</h2><pre>' + esc(JSON.stringify({ plant: project.plant, mappings: project.signals.filter(function (signal) { return signal.physical; }) }, null, 2)) + '</pre>' +
      '<h2>Transfer sequence</h2>' + (transferHtml ? '<table><thead><tr><th>Time (ms)</th><th>Breakers</th><th>Bus feeds</th></tr></thead><tbody>' + transferHtml + '</tbody></table>' : '<p>No scenario run for the current project.</p>') +
      '<h2>Settled-State Coverage</h2>' + enumSummary +
      (enumeration ? '<p>' + (enumeration.unsettledCount || 0) + ' vectors did not settle within the scan limit.</p>' : '') +
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
