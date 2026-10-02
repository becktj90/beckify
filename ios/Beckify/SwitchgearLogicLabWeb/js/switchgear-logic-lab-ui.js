/* ============================================================================
   Switchgear Logic Lab — js/switchgear-logic-lab-ui.js
   DOM glue only. All logic lives in js/switchgear/*.js (no DOM access there,
   so the same files bundle into the iOS JSCore bridge unchanged). This file
   renders the 8 Phase 1 screens, persists the project to localStorage, and
   never writes anything resembling a vendor-loadable settings file.
   ============================================================================ */
(function () {
  'use strict';

  var E = window.SwitchgearEngine;
  var STORAGE_KEY = 'beckify-switchgear-logic-lab-project-v1';

  var state = {
    project: null,
    lastScenarioResult: null,
    lastScenarioId: null,
    lastTransferMatrix: null,
    lastEnumeration: null,
    timingSelection: {},
    analyzeExtra: [], // findings from on-demand analyze runs not yet merged into project.findings
  };

  // ---------------------------------------------------------------- persistence

  function save() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state.project)); } catch (e) { /* storage unavailable; project still works in-memory */ }
    renderProfilePill();
  }

  function loadFromStorage() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      if (raw) return JSON.parse(raw);
    } catch (e) { /* ignore corrupt/blocked storage */ }
    return null;
  }

  function newBlankProject() {
    return E.model.newProject(E.profile.clone(E.profile.GENERIC_PROFILE));
  }

  // ---------------------------------------------------------------- small DOM helpers

  function $(id) { return document.getElementById(id); }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function opt(value, label, selected) {
    return '<option value="' + esc(value) + '"' + (selected ? ' selected' : '') + '>' + esc(label) + '</option>';
  }
  function signalOptions(selectedId) {
    return state.project.signals.map(function (s) {
      return opt(s.id, s.name + ' (' + s.kind + ')', s.id === selectedId);
    }).join('');
  }
  function downloadBlob(filename, mime, content) {
    var blob = new Blob([content], { type: mime });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 2000);
  }

  // ---------------------------------------------------------------- tabs

  function wireTabs() {
    $('sgllTabs').addEventListener('click', function (e) {
      var btn = e.target.closest('.sgll-tab');
      if (!btn) return;
      document.querySelectorAll('.sgll-tab').forEach(function (t) { t.classList.toggle('active', t === btn); });
      document.querySelectorAll('.sgll-screen').forEach(function (s) { s.classList.toggle('active', s.id === 'screen-' + btn.dataset.screen); });
    });
  }

  // ---------------------------------------------------------------- profile pill

  function renderProfilePill() {
    var p = state.project.profile;
    $('sgllProfilePill').innerHTML = 'Profile: ' + esc(p.vendor) + (p.verified ? '' : ' <span class="sgll-unverified">UNVERIFIED</span>');
  }

  // ================================================================== PROJECT SCREEN

  function renderProject() {
    var p = state.project;
    var profilesHtml = E.profile.BUILTIN_PROFILES.map(function (bp) {
      return opt(bp.id, bp.vendor + (bp.verified ? '' : ' (UNVERIFIED)'), bp.id === p.profile.id);
    }).join('');

    $('screen-project').innerHTML =
      '<div class="sgll-grid">' +
        '<div class="sgll-card">' +
          '<h2>Project</h2>' +
          '<div class="sgll-field"><label>Project name</label><input id="sgllProjName" value="' + esc(p.name) + '"></div>' +
          '<div class="sgll-row">' +
            '<button class="sgll-btn" data-action="new-project">New project</button>' +
            '<button class="sgll-btn" data-action="load-demo">Load demo project</button>' +
          '</div>' +
          '<h3>Save / load</h3>' +
          '<div class="sgll-row">' +
            '<button class="sgll-btn" data-action="export-project">Export project JSON</button>' +
            '<label class="sgll-btn" style="text-align:center">Import project JSON<input type="file" accept="application/json" id="sgllImportFile" style="display:none"></label>' +
          '</div>' +
          '<p class="sgll-empty">Saved automatically to this device only. Nothing here is uploaded or shared.</p>' +
        '</div>' +
        '<div class="sgll-card">' +
          '<h2>System profile</h2>' +
          '<div class="sgll-field"><label>Vendor profile</label><select id="sgllProfileSelect">' + profilesHtml + '</select></div>' +
          '<p class="sgll-empty">' + esc(p.profile.sourceNote) + '</p>' +
          '<h3>Profile settings</h3>' +
          '<div class="sgll-row">' +
            '<div class="sgll-field"><label>Timer field order</label><select id="sgllTimerFieldOrder">' +
              E.profile.TIMER_FIELD_ORDERS.map(function (v) { return opt(v, v, v === p.profile.timerFieldOrder); }).join('') +
            '</select></div>' +
            '<div class="sgll-field"><label>Latch dominance</label><select id="sgllLatchDominance">' +
              E.profile.LATCH_DOMINANCES.map(function (v) { return opt(v, v, v === p.profile.latchDominance); }).join('') +
            '</select></div>' +
          '</div>' +
          '<div class="sgll-row">' +
            '<div class="sgll-field"><label>Evaluation order</label><select id="sgllEvalOrder">' +
              E.profile.EVAL_ORDERS.map(function (v) { return opt(v, v, v === p.profile.evalOrder); }).join('') +
            '</select></div>' +
            '<div class="sgll-field"><label>Scan period (ms)</label><input type="number" min="1" id="sgllScanMs" value="' + p.profile.scanMs + '"></div>' +
          '</div>' +
          '<p class="sgll-empty">Changing these does not change your actual switchgear — it changes which assumption the simulator uses. Confirm against the real device reference manual before trusting results.</p>' +
        '</div>' +
      '</div>';

    $('sgllProjName').addEventListener('input', function () { state.project.name = this.value; save(); });
    $('sgllProfileSelect').addEventListener('change', function () {
      var builtin = E.profile.byId(this.value);
      state.project.profile = E.profile.clone(builtin);
      save(); renderAll();
    });
    $('sgllTimerFieldOrder').addEventListener('change', function () { state.project.profile.timerFieldOrder = this.value; save(); renderAnalyze(); });
    $('sgllLatchDominance').addEventListener('change', function () { state.project.profile.latchDominance = this.value; save(); renderAnalyze(); });
    $('sgllEvalOrder').addEventListener('change', function () { state.project.profile.evalOrder = this.value; save(); });
    $('sgllScanMs').addEventListener('change', function () { state.project.profile.scanMs = Math.max(1, parseInt(this.value, 10) || 100); save(); });

    $('screen-project').querySelector('[data-action="new-project"]').addEventListener('click', function () {
      if (!confirm('Start a new blank project? This replaces the currently loaded project (export first if you want to keep it).')) return;
      state.project = newBlankProject();
      save(); renderAll();
    });
    $('screen-project').querySelector('[data-action="load-demo"]').addEventListener('click', function () {
      if (!confirm('Load the demo main-tie-main project? This replaces the currently loaded project.')) return;
      state.project = E.seedMainTieMain.build(E.model, E.profile, E.plant);
      save(); renderAll();
    });
    $('screen-project').querySelector('[data-action="export-project"]').addEventListener('click', function () {
      downloadBlob((state.project.name || 'switchgear-project').replace(/[^a-z0-9-_]+/gi, '_') + '.json', 'application/json', JSON.stringify(state.project, null, 2));
    });
    $('sgllImportFile').addEventListener('change', function (e) {
      var file = e.target.files[0];
      if (!file) return;
      var reader = new FileReader();
      reader.onload = function () {
        try {
          var imported = JSON.parse(reader.result);
          var errors = E.model.validateProject(imported);
          if (errors.length) { alert('This file has structural problems and was not loaded:\n' + errors.join('\n')); return; }
          state.project = imported;
          save(); renderAll();
        } catch (err) {
          alert('Could not read this file as a Switchgear Logic Lab project: ' + err.message);
        }
      };
      reader.readAsText(file);
    });
  }

  // ================================================================== LOGIC SCREEN

  function nodeInputCountSpec(type) {
    if (E.model.NO_INPUT_TYPES[type]) return 0;
    if (type === 'LATCH') return 2;
    if (E.model.SINGLE_INPUT_TYPES[type]) return 1;
    return -1; // variadic
  }

  function nodeFormHtml(existing) {
    var type = (existing && existing.type) || 'AND';
    var inputs = (existing && existing.inputs) || [{ ref: '', invert: false }];
    var count = nodeInputCountSpec(type);
    if (count >= 0) {
      while (inputs.length < count) inputs.push({ ref: '', invert: false });
      inputs = inputs.slice(0, Math.max(count, 1));
    }

    var labels = type === 'LATCH' ? ['Set', 'Reset'] : null;

    var inputsHtml = count === 0 ? '<p class="sgll-empty">No inputs.</p>' : inputs.map(function (inp, idx) {
      return '<div class="sgll-row" data-input-row="' + idx + '">' +
        '<select class="sgll-node-input-ref">' + opt('', labels ? labels[idx] + '…' : 'Select signal…') + signalOptions(inp.ref) + '</select>' +
        '<label class="sgll-checkbox-row"><input type="checkbox" class="sgll-node-input-invert"' + (inp.invert ? ' checked' : '') + '> Invert</label>' +
        (count === -1 ? '<button type="button" class="sgll-btn sgll-btn-sm" data-action="remove-input">−</button>' : '') +
        '</div>';
    }).join('');

    var timerParamsHtml = type === 'TIMER' ? (
      '<div class="sgll-row">' +
        '<div class="sgll-field"><label>Field A (ms)</label><input type="number" min="0" id="sgllTimerFieldA" value="' + ((existing && existing.params && existing.params.fieldA) || 0) + '"></div>' +
        '<div class="sgll-field"><label>Field B (ms)</label><input type="number" min="0" id="sgllTimerFieldB" value="' + ((existing && existing.params && existing.params.fieldB) || 0) + '"></div>' +
      '</div>' +
      '<p class="sgll-empty">Current profile timer field order: <strong>' + esc(state.project.profile.timerFieldOrder) + '</strong>.</p>'
    ) : '';

    return (
      '<div class="sgll-field"><label>Node type</label><select id="sgllNodeType">' +
        E.model.NODE_TYPES.map(function (t) { return opt(t, t, t === type); }).join('') +
      '</select></div>' +
      '<div id="sgllNodeInputs">' + inputsHtml + '</div>' +
      (count === -1 ? '<button type="button" class="sgll-btn sgll-btn-sm" data-action="add-input">+ Add input</button>' : '') +
      timerParamsHtml +
      '<div class="sgll-field"><label>Drives output signal</label><select id="sgllNodeOutput">' + opt('', 'Select signal…') + signalOptions(existing && existing.output) + '</select></div>' +
      '<div class="sgll-row">' +
        '<button type="button" class="sgll-btn sgll-btn-primary" data-action="save-node">' + (existing ? 'Save node' : 'Add node') + '</button>' +
        '<button type="button" class="sgll-btn" data-action="cancel-node">Cancel</button>' +
      '</div>'
    );
  }

  function wireNodeForm(container, existingId) {
    function rerenderInputsFor(type) {
      var count = nodeInputCountSpec(type);
      var rows = Array.prototype.slice.call(container.querySelectorAll('[data-input-row]'));
      var current = rows.map(function (row) {
        return { ref: row.querySelector('.sgll-node-input-ref').value, invert: row.querySelector('.sgll-node-input-invert').checked };
      });
      if (count === 0) current = [];
      else if (count > 0) { while (current.length < count) current.push({ ref: '', invert: false }); current = current.slice(0, count); }
      container.querySelector('#sgllNodeInputs').outerHTML = '<div id="sgllNodeInputs"></div>';
      var temp = nodeFormHtml({ type: type, inputs: current, output: container.querySelector('#sgllNodeOutput') ? container.querySelector('#sgllNodeOutput').value : null, params: readTimerParamsIfPresent(container) });
      container.innerHTML = temp;
      wireNodeForm(container, existingId);
    }

    function readTimerParamsIfPresent(c) {
      var a = c.querySelector('#sgllTimerFieldA');
      var b = c.querySelector('#sgllTimerFieldB');
      return a && b ? { fieldA: parseInt(a.value, 10) || 0, fieldB: parseInt(b.value, 10) || 0 } : {};
    }

    container.querySelector('#sgllNodeType').addEventListener('change', function () { rerenderInputsFor(this.value); });

    container.onclick = function (e) {
      if (e.target.matches('[data-action="add-input"]')) {
        var wrap = document.createElement('div');
        wrap.innerHTML = '<div class="sgll-row" data-input-row="x"><select class="sgll-node-input-ref">' + opt('', 'Select signal…') + signalOptions() + '</select><label class="sgll-checkbox-row"><input type="checkbox" class="sgll-node-input-invert"> Invert</label><button type="button" class="sgll-btn sgll-btn-sm" data-action="remove-input">−</button></div>';
        container.querySelector('#sgllNodeInputs').appendChild(wrap.firstChild);
      }
      if (e.target.matches('[data-action="remove-input"]')) {
        e.target.closest('[data-input-row]').remove();
      }
      if (e.target.matches('[data-action="cancel-node"]')) {
        renderLogic();
      }
      if (e.target.matches('[data-action="save-node"]')) {
        var type = container.querySelector('#sgllNodeType').value;
        var output = container.querySelector('#sgllNodeOutput').value;
        if (!output) { alert('Choose an output signal.'); return; }
        var inputs = Array.prototype.slice.call(container.querySelectorAll('[data-input-row]')).map(function (row) {
          return { ref: row.querySelector('.sgll-node-input-ref').value, invert: row.querySelector('.sgll-node-input-invert').checked };
        }).filter(function (i) { return i.ref; });
        var params = readTimerParamsIfPresent(container);
        try {
          var node = E.model.newNode({ id: existingId, type: type, inputs: inputs, output: output, params: params });
          if (existingId) {
            var idx = state.project.nodes.findIndex(function (n) { return n.id === existingId; });
            state.project.nodes[idx] = node;
          } else {
            state.project.nodes.push(node);
          }
          save(); renderLogic(); renderEquations();
        } catch (err) {
          alert('Could not save this node: ' + err.message);
        }
      }
    };
  }

  function nodeExpression(node) {
    var sigName = function (id) { var s = E.model.findSignal(state.project, id); return s ? s.name : id; };
    var ref = function (inp) { return (inp.invert ? 'NOT ' : '') + sigName(inp.ref); };
    switch (node.type) {
      case 'LATCH': return 'LATCH(set=' + ref(node.inputs[0]) + ', reset=' + ref(node.inputs[1]) + ')';
      case 'TIMER': return 'TIMER(' + ref(node.inputs[0]) + ', fieldA=' + (node.params.fieldA || 0) + 'ms, fieldB=' + (node.params.fieldB || 0) + 'ms)';
      case 'NOT': return 'NOT ' + sigName(node.inputs[0].ref);
      case 'ONESHOT_POS': case 'ONESHOT_NEG': return node.type + '(' + ref(node.inputs[0]) + ')';
      case 'CONST_ON': return 'ON';
      case 'CONST_OFF': return 'OFF';
      default: return node.type + '(' + node.inputs.map(ref).join(', ') + ')';
    }
  }

  function renderLogic() {
    var p = state.project;
    var signalRows = p.signals.map(function (s) {
      return '<tr><td>' + esc(s.kind) + '</td><td>' + esc(s.name) + '</td><td><code>' + esc(s.id) + '</code></td><td>' + esc(s.number || '') + '</td>' +
        '<td>' + esc(s.description || '') + '</td>' +
        '<td><button class="sgll-btn sgll-btn-sm sgll-btn-danger" data-action="delete-signal" data-id="' + esc(s.id) + '">Delete</button></td></tr>';
    }).join('');

    var nodeRows = p.nodes.map(function (n) {
      var driving = E.model.findSignal(p, n.output);
      return '<div class="sgll-node-block">' +
        '<span class="sgll-node-type">' + esc(n.type) + '</span>' +
        '<span class="sgll-node-expr">' + esc(nodeExpression(n)) + ' &rarr; <strong>' + esc(driving ? driving.name : n.output) + '</strong></span>' +
        '<span class="sgll-row" style="flex:0 0 auto">' +
          '<button class="sgll-btn sgll-btn-sm" data-action="edit-node" data-id="' + esc(n.id) + '">Edit</button>' +
          '<button class="sgll-btn sgll-btn-sm sgll-btn-danger" data-action="delete-node" data-id="' + esc(n.id) + '">Delete</button>' +
        '</span></div>';
    }).join('') || '<p class="sgll-empty">No logic nodes yet. Add signals first, then build nodes from them.</p>';

    $('screen-logic').innerHTML =
      '<div class="sgll-grid">' +
        '<div class="sgll-card">' +
          '<h2>Signals</h2>' +
          '<div id="sgllSignalForm"></div>' +
          '<button class="sgll-btn" data-action="add-signal">+ Add signal</button>' +
          '<div style="overflow-x:auto;margin-top:10px"><table class="sgll-table"><thead><tr><th>Kind</th><th>Name</th><th>ID</th><th>Number</th><th>Description</th><th></th></tr></thead><tbody>' + signalRows + '</tbody></table></div>' +
        '</div>' +
        '<div class="sgll-card">' +
          '<h2>Logic nodes (block form)</h2>' +
          '<p class="sgll-empty">Phase 1 ships the block-form editor only. A drag-wire graph view is planned for Phase 2.</p>' +
          '<div id="sgllNodeForm"></div>' +
          '<button class="sgll-btn" data-action="add-node">+ Add node</button>' +
          '<div class="sgll-node-list" style="margin-top:10px">' + nodeRows + '</div>' +
        '</div>' +
      '</div>';

    $('screen-logic').onclick = function handler(e) {
      if (e.target.matches('[data-action="add-signal"]')) {
        $('sgllSignalForm').innerHTML = signalFormHtml();
        wireSignalForm($('sgllSignalForm'));
      }
      if (e.target.matches('[data-action="delete-signal"]')) {
        var id = e.target.dataset.id;
        var used = state.project.nodes.some(function (n) { return n.output === id || n.inputs.some(function (i) { return i.ref === id; }); });
        if (used && !confirm('This signal is used by at least one node. Delete anyway?')) return;
        state.project.signals = state.project.signals.filter(function (s) { return s.id !== id; });
        save(); renderLogic(); renderEquations();
      }
      if (e.target.matches('[data-action="add-node"]')) {
        if (!state.project.signals.length) { alert('Add at least one signal first.'); return; }
        $('sgllNodeForm').innerHTML = nodeFormHtml(null);
        wireNodeForm($('sgllNodeForm'), null);
      }
      if (e.target.matches('[data-action="edit-node"]')) {
        var node = E.model.findNode(state.project, e.target.dataset.id);
        $('sgllNodeForm').innerHTML = nodeFormHtml(node);
        wireNodeForm($('sgllNodeForm'), node.id);
      }
      if (e.target.matches('[data-action="delete-node"]')) {
        state.project.nodes = state.project.nodes.filter(function (n) { return n.id !== e.target.dataset.id; });
        save(); renderLogic(); renderEquations();
      }
    };
  }

  function signalFormHtml() {
    return '<div class="sgll-card" style="margin-bottom:10px">' +
      '<div class="sgll-row">' +
        '<div class="sgll-field"><label>Kind</label><select id="sgllSigKind">' + E.model.SIGNAL_KINDS.map(function (k) { return opt(k, k); }).join('') + '</select></div>' +
        '<div class="sgll-field"><label>Name</label><input id="sgllSigName" placeholder="e.g. Main 1 Close Command"></div>' +
        '<div class="sgll-field"><label>Number (optional)</label><input id="sgllSigNumber" placeholder="e.g. VO 156"></div>' +
      '</div>' +
      '<div class="sgll-field"><label>Description (optional)</label><input id="sgllSigDesc"></div>' +
      '<div class="sgll-row">' +
        '<button class="sgll-btn sgll-btn-primary" data-action="save-signal">Add signal</button>' +
        '<button class="sgll-btn" data-action="cancel-signal">Cancel</button>' +
      '</div></div>';
  }

  function wireSignalForm(container) {
    container.onclick = function (e) {
      if (e.target.matches('[data-action="cancel-signal"]')) { container.innerHTML = ''; }
      if (e.target.matches('[data-action="save-signal"]')) {
        var name = $('sgllSigName').value.trim();
        if (!name) { alert('Give the signal a name.'); return; }
        var sig = E.model.newSignal({
          kind: $('sgllSigKind').value,
          name: name,
          number: $('sgllSigNumber').value.trim() || null,
          description: $('sgllSigDesc').value.trim(),
        });
        state.project.signals.push(sig);
        save(); renderLogic(); renderEquations();
      }
    };
  }

  // ================================================================== EQUATIONS SCREEN

  function renderEquations() {
    var p = state.project;
    var lines = p.nodes.map(function (n) {
      var driving = E.model.findSignal(p, n.output);
      return (driving ? driving.name : n.output) + '  =  ' + nodeExpression(n);
    });
    $('screen-equations').innerHTML =
      '<div class="sgll-card">' +
        '<h2>Equations</h2>' +
        '<p class="sgll-empty">Auto-generated from the logic nodes, read-only in Phase 1. Edit logic on the Logic screen; a bidirectional equation editor is planned for Phase 2.</p>' +
        '<div class="sgll-equations">' + (lines.length ? esc(lines.join('\n')) : 'No logic nodes yet.') + '</div>' +
      '</div>';
  }

  // ================================================================== ONE-LINE SCREEN

  function staticPositions() {
    var pos = {};
    state.project.plant.breakers.forEach(function (b) { pos[b.id] = b.position || 'open'; });
    return pos;
  }
  function staticAvailability() {
    var avail = {};
    state.project.plant.sources.forEach(function (s) { avail[s.id] = s.available !== false; });
    return avail;
  }

  function applyMainTieMainTemplate(withGenerator) {
    var plant = E.plant.newPlantModel();
    plant.buses.push(E.plant.newBus({ id: 'bus1', label: 'Bus 1' }), E.plant.newBus({ id: 'bus2', label: 'Bus 2' }));
    plant.sources.push(E.plant.newSource({ id: 'src1', label: 'Source 1', kind: 'utility' }), E.plant.newSource({ id: 'src2', label: 'Source 2', kind: 'utility' }));
    plant.breakers.push(
      E.plant.newBreaker({ id: 'main1', label: 'Main 1', role: 'main', connectsBusA: 'bus1', sourceId: 'src1', position: 'closed' }),
      E.plant.newBreaker({ id: 'main2', label: 'Main 2', role: 'main', connectsBusA: 'bus2', sourceId: 'src2', position: 'closed' }),
      E.plant.newBreaker({ id: 'tie', label: 'Tie', role: 'tie', connectsBusA: 'bus1', connectsBusB: 'bus2', position: 'open' })
    );
    if (withGenerator) {
      plant.sources.push(E.plant.newSource({ id: 'gen1', label: 'Generator', kind: 'generator', available: false }));
      plant.breakers.push(E.plant.newBreaker({ id: 'gen1brk', label: 'Generator Breaker', role: 'generator', connectsBusA: 'bus2', sourceId: 'gen1', position: 'open' }));
    }
    state.project.plant = plant;
    save(); renderOneline();
  }

  function onelineSvg(plant, positions, avail) {
    var busX = {};
    var width = Math.max(560, plant.buses.length * 220 + 80);
    plant.buses.forEach(function (b, i) { busX[b.id] = 80 + i * 220; });
    var busY = 140;
    var parts = [];
    parts.push('<svg class="sgll-oneline-svg" viewBox="0 0 ' + width + ' 320" xmlns="http://www.w3.org/2000/svg">');

    var energized = E.plant.energizedBuses(plant, positions, avail);

    plant.buses.forEach(function (b) {
      var x = busX[b.id];
      var isEnergized = (energized[b.id] || []).length > 0;
      parts.push('<line x1="' + (x - 70) + '" y1="' + busY + '" x2="' + (x + 70) + '" y2="' + busY + '" stroke-width="5" class="' + (isEnergized ? 'sgll-bus-energized' : 'sgll-bus-dead') + '"/>');
      parts.push('<text x="' + x + '" y="' + (busY + 24) + '" text-anchor="middle">' + esc(b.label) + (isEnergized ? ' (energized)' : ' (dead)') + '</text>');
    });

    plant.breakers.forEach(function (b) {
      var closed = positions[b.id] === 'closed';
      if (b.sourceId) {
        var x = busX[b.connectsBusA];
        var src = plant.sources.filter(function (s) { return s.id === b.sourceId; })[0];
        var srcAvail = src && avail[src.id];
        parts.push('<line x1="' + x + '" y1="40" x2="' + x + '" y2="' + busY + '" stroke="' + (srcAvail ? '#6bdc8f' : '#93a0b4') + '" stroke-width="3"/>');
        parts.push('<rect x="' + (x - 10) + '" y="80" width="20" height="20" class="' + (closed ? 'sgll-breaker-closed' : 'sgll-breaker-open') + '"/>');
        parts.push('<text x="' + x + '" y="30" text-anchor="middle">' + esc(src ? src.label : b.sourceId) + (srcAvail ? '' : ' (unavailable)') + '</text>');
        parts.push('<text x="' + x + '" y="118" text-anchor="middle">' + esc(b.label) + '</text>');
      } else if (b.connectsBusB) {
        var xa = busX[b.connectsBusA], xb = busX[b.connectsBusB];
        var mid = (xa + xb) / 2;
        parts.push('<line x1="' + (xa + 70) + '" y1="' + busY + '" x2="' + (xb - 70) + '" y2="' + busY + '" stroke="#93a0b4" stroke-width="2" stroke-dasharray="4 3"/>');
        parts.push('<rect x="' + (mid - 10) + '" y="' + (busY - 10) + '" width="20" height="20" class="' + (closed ? 'sgll-breaker-closed' : 'sgll-breaker-open') + '"/>');
        parts.push('<text x="' + mid + '" y="' + (busY + 42) + '" text-anchor="middle">' + esc(b.label) + '</text>');
      }
    });

    parts.push('</svg>');
    return parts.join('');
  }

  function renderOneline() {
    var p = state.project;
    var positions = staticPositions();
    var avail = staticAvailability();
    var findings = E.plant.analyzeSnapshot(p.plant, positions, avail).concat(E.plant.detectBackfeed(p.plant, positions, avail));

    var breakerControls = p.plant.breakers.map(function (b) {
      var closed = positions[b.id] === 'closed';
      return '<div class="sgll-row"><span style="flex:2">' + esc(b.label) + '</span>' +
        '<button class="sgll-btn sgll-btn-sm" data-action="toggle-breaker" data-id="' + esc(b.id) + '">' + (closed ? 'Open it' : 'Close it') + '</button></div>';
    }).join('') || '<p class="sgll-empty">No breakers yet.</p>';

    var sourceControls = p.plant.sources.map(function (s) {
      return '<div class="sgll-row"><span style="flex:2">' + esc(s.label) + '</span>' +
        '<label class="sgll-checkbox-row"><input type="checkbox" data-action="toggle-source" data-id="' + esc(s.id) + '" ' + (avail[s.id] ? 'checked' : '') + '> Available</label></div>';
    }).join('') || '<p class="sgll-empty">No sources yet.</p>';

    var findingsHtml = findings.length ? findings.map(findingCardHtml).join('') : '<p class="sgll-empty">No parallel-source, backfeed, or lockout/disconnect conditions in this static snapshot.</p>';

    $('screen-oneline').innerHTML =
      '<div class="sgll-row" style="margin-bottom:10px">' +
        '<button class="sgll-btn" data-action="template-mtm">Load main-tie-main template</button>' +
        '<button class="sgll-btn" data-action="template-mtm-gen">Load main-tie-main + generator template</button>' +
      '</div>' +
      onelineSvg(p.plant, positions, avail) +
      '<div class="sgll-grid" style="margin-top:12px">' +
        '<div class="sgll-card"><h3>Breakers (static snapshot)</h3>' + breakerControls + '</div>' +
        '<div class="sgll-card"><h3>Sources</h3>' + sourceControls + '</div>' +
        '<div class="sgll-card"><h3>Findings on this snapshot</h3>' + findingsHtml + '</div>' +
      '</div>';

    $('screen-oneline').querySelector('[data-action="template-mtm"]').addEventListener('click', function () {
      if (confirm('Replace the current plant topology with a 2-bus main-tie-main template?')) applyMainTieMainTemplate(false);
    });
    $('screen-oneline').querySelector('[data-action="template-mtm-gen"]').addEventListener('click', function () {
      if (confirm('Replace the current plant topology with a main-tie-main + generator template?')) applyMainTieMainTemplate(true);
    });
    $('screen-oneline').querySelectorAll('[data-action="toggle-breaker"]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var b = state.project.plant.breakers.filter(function (x) { return x.id === btn.dataset.id; })[0];
        b.position = b.position === 'closed' ? 'open' : 'closed';
        save(); renderOneline();
      });
    });
    $('screen-oneline').querySelectorAll('[data-action="toggle-source"]').forEach(function (chk) {
      chk.addEventListener('change', function () {
        var s = state.project.plant.sources.filter(function (x) { return x.id === chk.dataset.id; })[0];
        s.available = chk.checked;
        save(); renderOneline();
      });
    });
  }

  // ================================================================== SCENARIOS SCREEN

  function eventRowHtml(ev, idx) {
    return '<div class="sgll-row" data-event-idx="' + idx + '">' +
      '<input type="number" min="0" class="sgll-ev-t" value="' + ev.tMs + '" style="flex:0 0 70px" title="time (ms)">' +
      '<select class="sgll-ev-type" style="flex:0 0 140px">' +
        ['input', 'breakerPosition', 'sourceAvailable', 'fault'].map(function (t) { return opt(t, t, t === ev.type); }).join('') +
      '</select>' +
      '<input class="sgll-ev-target" placeholder="signalId / breakerId / sourceId" value="' + esc(ev.signalId || ev.breakerId || ev.sourceId || ev.targetId || '') + '" style="flex:1">' +
      '<input class="sgll-ev-value" placeholder="value (true/false/open/closed)" value="' + esc(ev.value != null ? ev.value : ev.position || ev.available || '') + '" style="flex:1">' +
      '<button class="sgll-btn sgll-btn-sm sgll-btn-danger" data-action="remove-event" data-idx="' + idx + '">−</button>' +
      '</div>';
  }

  function parseEventRow(row) {
    var t = parseInt(row.querySelector('.sgll-ev-t').value, 10) || 0;
    var type = row.querySelector('.sgll-ev-type').value;
    var target = row.querySelector('.sgll-ev-target').value.trim();
    var rawValue = row.querySelector('.sgll-ev-value').value.trim();
    var boolValue = rawValue === 'true' || rawValue === 'closed';
    if (type === 'input') return { tMs: t, type: type, signalId: target, value: boolValue };
    if (type === 'breakerPosition') return { tMs: t, type: type, breakerId: target, position: rawValue === 'closed' ? 'closed' : 'open' };
    if (type === 'sourceAvailable') return { tMs: t, type: type, sourceId: target, available: boolValue };
    return { tMs: t, type: 'fault', fault: rawValue, targetId: target, active: true };
  }

  function renderScenarios() {
    var p = state.project;
    var scenarioTabs = p.scenarios.map(function (s, idx) {
      return '<button class="sgll-btn sgll-btn-sm" data-action="select-scenario" data-idx="' + idx + '">' + esc(s.name) + '</button>';
    }).join(' ');

    var selected = p.scenarios[state.selectedScenarioIdx || 0];

    var body = '<p class="sgll-empty">No scenarios yet.</p>';
    if (selected) {
      var rows = selected.events.map(eventRowHtml).join('');
      body =
        '<div class="sgll-field"><label>Scenario name</label><input id="sgllScenName" value="' + esc(selected.name) + '"></div>' +
        '<div class="sgll-row"><div class="sgll-field"><label>Duration (ms)</label><input type="number" id="sgllScenDuration" value="' + selected.durationMs + '"></div>' +
        '<div class="sgll-field"><label>Scan dt (ms)</label><input type="number" id="sgllScenDt" value="' + selected.dtMs + '"></div></div>' +
        '<h3>Events</h3><div id="sgllEventRows">' + rows + '</div>' +
        '<button class="sgll-btn sgll-btn-sm" data-action="add-event">+ Add event</button>' +
        '<div class="sgll-row" style="margin-top:10px">' +
          '<button class="sgll-btn sgll-btn-primary" data-action="save-run-scenario">Save &amp; run</button>' +
          '<button class="sgll-btn sgll-btn-danger" data-action="delete-scenario">Delete scenario</button>' +
        '</div>';
    }

    var resultHtml = '';
    if (state.lastScenarioResult && state.lastScenarioId === (selected && selected.id)) {
      var findings = state.lastScenarioResult.findings;
      resultHtml = '<div class="sgll-card"><h3>Run result</h3>' +
        '<p>' + state.lastScenarioResult.steps.length + ' scan steps. ' + findings.length + ' finding(s) over the run.</p>' +
        (findings.length ? findings.slice(0, 20).map(findingCardHtml).join('') : '<p class="sgll-empty">No findings during this run.</p>') +
        '<p class="sgll-empty">See the Timing screen to plot signals from this run.</p>' +
        '</div>';
    }

    $('screen-scenarios').innerHTML =
      '<div class="sgll-row" style="margin-bottom:10px">' + scenarioTabs +
        '<button class="sgll-btn" data-action="add-scenario">+ New scenario</button></div>' +
      '<div class="sgll-grid"><div class="sgll-card">' + body + '</div>' + resultHtml + '</div>';

    var screen = $('screen-scenarios');
    screen.querySelectorAll('[data-action="select-scenario"]').forEach(function (btn) {
      btn.addEventListener('click', function () { state.selectedScenarioIdx = parseInt(btn.dataset.idx, 10); renderScenarios(); });
    });
    var addScenBtn = screen.querySelector('[data-action="add-scenario"]');
    if (addScenBtn) addScenBtn.addEventListener('click', function () {
      p.scenarios.push(E.scenario.newScenario({ id: E.model.uid('scen'), name: 'New scenario', durationMs: 2000, dtMs: p.profile.scanMs, events: [] }));
      state.selectedScenarioIdx = p.scenarios.length - 1;
      save(); renderScenarios();
    });
    if (!selected) return;

    screen.querySelector('#sgllScenName').addEventListener('input', function () { selected.name = this.value; save(); });
    screen.querySelector('#sgllScenDuration').addEventListener('change', function () { selected.durationMs = parseInt(this.value, 10) || 0; save(); });
    screen.querySelector('#sgllScenDt').addEventListener('change', function () { selected.dtMs = parseInt(this.value, 10) || 100; save(); });
    screen.querySelector('[data-action="add-event"]').addEventListener('click', function () {
      selected.events.push({ tMs: 0, type: 'input', signalId: '', value: false });
      save(); renderScenarios();
    });
    screen.querySelector('[data-action="delete-scenario"]').addEventListener('click', function () {
      if (!confirm('Delete scenario "' + selected.name + '"?')) return;
      p.scenarios.splice(state.selectedScenarioIdx, 1);
      state.selectedScenarioIdx = 0;
      save(); renderScenarios();
    });
    screen.querySelectorAll('[data-action="remove-event"]').forEach(function (btn) {
      btn.addEventListener('click', function () { selected.events.splice(parseInt(btn.dataset.idx, 10), 1); save(); renderScenarios(); });
    });
    screen.querySelector('[data-action="save-run-scenario"]').addEventListener('click', function () {
      selected.events = Array.prototype.slice.call(screen.querySelectorAll('[data-event-idx]')).map(parseEventRow).sort(function (a, b) { return a.tMs - b.tMs; });
      save();
      try {
        var result = E.scenario.run(p, selected, E.eval, E.plant, {});
        state.lastScenarioResult = result;
        state.lastScenarioId = selected.id;
        renderScenarios(); renderTiming();
      } catch (err) {
        alert('Could not run this scenario: ' + err.message);
      }
    });
  }

  // ================================================================== TIMING SCREEN

  function timingSvg(steps, signalIds) {
    if (!steps.length || !signalIds.length) return '<p class="sgll-empty">Pick at least one signal to plot, and run a scenario first.</p>';
    var width = 900, rowHeight = 46, left = 190;
    var height = signalIds.length * rowHeight + 40;
    var maxT = steps[steps.length - 1].tMs || 1;
    var xScale = function (t) { return left + (t / maxT) * (width - left - 20); };
    var parts = ['<svg class="sgll-timing-svg" viewBox="0 0 ' + width + ' ' + height + '" xmlns="http://www.w3.org/2000/svg">'];

    signalIds.forEach(function (sigId, row) {
      var y = 24 + row * rowHeight;
      var label = (E.model.findSignal(state.project, sigId) || { name: sigId }).name;
      parts.push('<text x="4" y="' + (y + 4) + '">' + esc(label) + '</text>');
      var points = [];
      steps.forEach(function (step, i) {
        var v = !!step.signalValues[sigId];
        var x = xScale(step.tMs);
        var yTrace = y - (v ? 14 : 0);
        points.push((i === 0 ? 'M' : 'L') + x + ' ' + yTrace);
      });
      parts.push('<path d="' + points.join(' ') + '" fill="none" stroke-width="2" class="sgll-timing-trace-high"/>');
      parts.push('<line x1="' + left + '" y1="' + y + '" x2="' + (width - 20) + '" y2="' + y + '" class="sgll-timing-trace-low" stroke-width="1"/>');
    });
    parts.push('<text x="' + (width - 60) + '" y="' + (height - 4) + '">' + maxT + 'ms</text>');
    parts.push('</svg>');
    return parts.join('');
  }

  function renderTiming() {
    var p = state.project;
    if (!state.lastScenarioResult) {
      $('screen-timing').innerHTML = '<div class="sgll-card"><h2>Timing</h2><p class="sgll-empty">Run a scenario on the Scenarios screen first — this chart plots its recorded steps.</p></div>';
      return;
    }
    var checks = p.signals.map(function (s) {
      var checked = state.timingSelection[s.id];
      return '<label class="sgll-checkbox-row"><input type="checkbox" data-action="toggle-timing-signal" data-id="' + esc(s.id) + '" ' + (checked ? 'checked' : '') + '> ' + esc(s.name) + '</label>';
    }).join('');

    var selectedIds = p.signals.filter(function (s) { return state.timingSelection[s.id]; }).map(function (s) { return s.id; });

    $('screen-timing').innerHTML =
      '<div class="sgll-grid">' +
        '<div class="sgll-card"><h3>Signals to plot</h3><div class="sgll-node-list">' + checks + '</div></div>' +
        '<div class="sgll-card" style="grid-column:span 2"><h2>Timing chart</h2>' + timingSvg(state.lastScenarioResult.steps, selectedIds) + '</div>' +
      '</div>';

    $('screen-timing').querySelectorAll('[data-action="toggle-timing-signal"]').forEach(function (chk) {
      chk.addEventListener('change', function () { state.timingSelection[chk.dataset.id] = chk.checked; renderTiming(); });
    });
  }

  // ================================================================== ANALYZE SCREEN

  function findingCardHtml(f) {
    var sev = f.severity || 'info';
    return '<div class="sgll-finding sev-' + esc(sev) + '">' +
      '<div class="sgll-finding-title"><span class="sgll-badge sgll-badge-' + esc(sev) + '">' + esc(sev) + '</span> ' + esc(f.title) + '</div>' +
      '<div class="sgll-finding-meta">' + esc(f.category) + (f.suggestedTest ? ' — ' + esc(f.suggestedTest) : '') + '</div>' +
      '</div>';
  }

  function renderAnalyze() {
    var p = state.project;
    var findings = p.findings || [];

    $('screen-analyze').innerHTML =
      '<div class="sgll-row" style="margin-bottom:10px">' +
        '<button class="sgll-btn sgll-btn-primary" data-action="run-lint">Run static lint</button>' +
        '<button class="sgll-btn" data-action="run-enum">Run settled-state enumeration</button>' +
        '<button class="sgll-btn" data-action="run-latch-check">Check latch dominance divergence</button>' +
        '<button class="sgll-btn" data-action="run-timer-check">Check timer field order divergence</button>' +
      '</div>' +
      '<div id="sgllAnalyzeExtra"></div>' +
      '<div class="sgll-card"><h2>Findings (' + findings.length + ')</h2><div id="sgllFindingsList">' +
      (findings.length ? findings.map(function (f, idx) { return findingCardWithActions(f, idx); }).join('') : '<p class="sgll-empty">No findings yet. Run an analysis above.</p>') +
      '</div></div>';

    var screen = $('screen-analyze');
    screen.querySelector('[data-action="run-lint"]').addEventListener('click', function () {
      var results = E.lint.lintProject(p, E.eval);
      mergeFindings(results);
    });
    screen.querySelector('[data-action="run-enum"]').addEventListener('click', function () {
      var ids = E.report.independentInputs(p);
      if (!ids.length) { alert('Add at least one VI/CI/BREAKER_STATE signal first.'); return; }
      state.lastEnumeration = E.report.enumerateSettledStates(p, E.eval);
      renderEnumerationSummary();
    });
    screen.querySelector('[data-action="run-latch-check"]').addEventListener('click', function () {
      if (!p.nodes.some(function (n) { return n.type === 'LATCH'; })) { alert('No latches in this project yet.'); return; }
      var ids = E.report.independentInputs(p);
      var found = [];
      ids.length && ids.length <= 10 ? enumerateAndDiff() : (function () {
        var diff = E.eval.stepBothLatchDominances(p, E.eval.newRuntime(), {}, p.profile.scanMs);
        if (diff.divergentSignals.length) found.push(makeDivergenceFinding('latch-dominance-divergence', diff.divergentSignals));
        mergeFindings(found);
      })();
      function enumerateAndDiff() {
        var enumeration = E.report.enumerateSettledStates(p, E.eval, { inputIds: ids });
        var anyDivergence = {};
        enumeration.rows.forEach(function (row) {
          var diff = E.eval.stepBothLatchDominances(p, E.eval.newRuntime(), row.inputs, p.profile.scanMs);
          diff.divergentSignals.forEach(function (s) { anyDivergence[s] = true; });
        });
        var sigs = Object.keys(anyDivergence);
        if (sigs.length) found.push(makeDivergenceFinding('latch-dominance-divergence', sigs));
        mergeFindings(found);
      }
    });
    screen.querySelector('[data-action="run-timer-check"]').addEventListener('click', function () {
      if (!p.nodes.some(function (n) { return n.type === 'TIMER'; })) { alert('No timers in this project yet.'); return; }
      var diff = E.eval.stepBothTimerFieldOrders(p, E.eval.newRuntime(), {}, p.profile.scanMs);
      var found = diff.divergentSignals.length ? [makeDivergenceFinding('timer-field-order-divergence', diff.divergentSignals)] : [];
      mergeFindings(found);
    });

    renderEnumerationSummary();
    wireFindingActions();
  }

  function makeDivergenceFinding(category, signals) {
    return {
      id: E.model.uid('find'), severity: 'high', category: category,
      title: (category === 'latch-dominance-divergence' ? 'Latch dominance interpretation changes behavior for: ' : 'Timer field-order interpretation changes behavior for: ') + signals.join(', '),
      evidence: signals.map(function (s) { return { signalId: s }; }),
      suggestedTest: 'Confirm the real device setting against its reference manual, then set the profile accordingly.',
      status: 'open',
    };
  }

  function mergeFindings(newFindings) {
    if (!newFindings.length) { alert('No new findings from this check.'); return; }
    state.project.findings = (state.project.findings || []).concat(newFindings);
    save(); renderAnalyze();
  }

  function renderEnumerationSummary() {
    var el = $('sgllAnalyzeExtra');
    if (!el) return;
    var en = state.lastEnumeration;
    if (!en) { el.innerHTML = ''; return; }
    el.innerHTML = '<div class="sgll-card"><h3>Settled-state coverage</h3>' +
      '<p>' + en.rows.length + ' of ' + en.totalPossible + ' input vectors ' + (en.exhaustive ? 'enumerated exhaustively.' : '<strong>sampled — bounded, not exhaustive.</strong>') + '</p>' +
      '</div>';
  }

  function wireFindingActions() {
    var list = $('sgllFindingsList');
    if (!list) return;
    list.addEventListener('click', function (e) {
      var btn = e.target.closest('[data-finding-action]');
      if (!btn) return;
      var idx = parseInt(btn.dataset.idx, 10);
      var f = state.project.findings[idx];
      if (btn.dataset.findingAction === 'accept') f.status = 'accepted';
      if (btn.dataset.findingAction === 'dismiss') f.status = 'dismissed';
      save(); renderAnalyze();
    });
  }

  function findingCardWithActions(f, idx) {
    var sev = f.severity || 'info';
    return '<div class="sgll-finding sev-' + esc(sev) + '">' +
      '<div class="sgll-finding-title"><span class="sgll-badge sgll-badge-' + esc(sev) + '">' + esc(sev) + '</span> ' + esc(f.title) + ' <span class="sgll-finding-meta">[' + esc(f.status || 'open') + ']</span></div>' +
      '<div class="sgll-finding-meta">' + esc(f.category) + (f.suggestedTest ? ' — ' + esc(f.suggestedTest) : '') + '</div>' +
      '<div class="sgll-finding-actions">' +
        '<button class="sgll-btn sgll-btn-sm" data-finding-action="accept" data-idx="' + idx + '">Accept</button>' +
        '<button class="sgll-btn sgll-btn-sm" data-finding-action="dismiss" data-idx="' + idx + '">Dismiss</button>' +
      '</div></div>';
  }

  // ================================================================== EXPORT SCREEN

  function renderExport() {
    $('screen-export').innerHTML =
      '<div class="sgll-card">' +
        '<h2>Export</h2>' +
        '<p class="sgll-empty">Every export below is a review package for engineering judgment — never a vendor-loadable settings file.</p>' +
        '<div class="sgll-row">' +
          '<button class="sgll-btn sgll-btn-primary" data-action="open-review">Open printable review export</button>' +
          '<button class="sgll-btn" data-action="download-review">Download review export HTML</button>' +
          '<button class="sgll-btn" data-action="download-findings-csv">Download findings CSV</button>' +
        '</div>' +
      '</div>';

    $('screen-export').querySelector('[data-action="open-review"]').addEventListener('click', function () {
      var html = E.report.buildReviewExportHtml(state.project, state.project.findings || [], state.lastEnumeration);
      var blob = new Blob([html], { type: 'text/html' });
      var url = URL.createObjectURL(blob);
      window.open(url, '_blank');
    });
    $('screen-export').querySelector('[data-action="download-review"]').addEventListener('click', function () {
      var html = E.report.buildReviewExportHtml(state.project, state.project.findings || [], state.lastEnumeration);
      downloadBlob('switchgear-review-export.html', 'text/html', html);
    });
    $('screen-export').querySelector('[data-action="download-findings-csv"]').addEventListener('click', function () {
      var findings = state.project.findings || [];
      var header = 'severity,category,title,status,suggestedTest\n';
      var rows = findings.map(function (f) {
        return [f.severity, f.category, f.title, f.status, f.suggestedTest || ''].map(function (v) {
          return '"' + String(v).replace(/"/g, '""') + '"';
        }).join(',');
      }).join('\n');
      downloadBlob('switchgear-findings.csv', 'text/csv', header + rows);
    });
  }

  // ================================================================== INIT

  function renderAll() {
    renderProfilePill();
    renderProject();
    renderLogic();
    renderEquations();
    renderOneline();
    renderScenarios();
    renderTiming();
    renderAnalyze();
    renderExport();
  }

  function init() {
    state.project = loadFromStorage() || newBlankProject();
    wireTabs();
    renderAll();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
