/* ============================================================================
   ELECTRONICS BENCH — UI (hub, circuit screen, schematic/breadboard, inspector)
   ============================================================================
   Mirrors the iOS Electronics Lab: pick a circuit, choose the unknown, edit
   part values, see one electrical identity as a schematic and as a solderless
   breadboard. Zoom the board, tap a part to inspect, search every reading.
   ============================================================================ */
(function (global) {
  'use strict';
  const E = global.BeckifyBenchEngine, R = global.BeckifyBenchRender;
  if (!E || !R || typeof document === 'undefined') return;
  const root = document.getElementById('eb-root');
  if (!root) return;

  const state = { circuit: null, unknown: null, values: {}, picture: 'schematic', layer: 'values', zoom: 1, selected: null, query: '', copied: false };
  const STORE = 'beckify-bench-state-v1';
  const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

  function save() { try { localStorage.setItem(STORE, JSON.stringify({ circuit: state.circuit, unknown: state.unknown, values: state.values, picture: state.picture, layer: state.layer })); } catch (e) { /* private mode */ } }
  function restore() {
    try {
      const s = JSON.parse(localStorage.getItem(STORE) || 'null');
      if (s && s.circuit && E.circuits().indexOf(s.circuit) >= 0) { Object.assign(state, { circuit: s.circuit, unknown: s.unknown, values: s.values || {}, picture: s.picture || 'schematic', layer: s.layer || 'values' }); }
    } catch (e) { /* ignore */ }
  }
  function open(id) {
    const s = E.specOf(id);
    Object.assign(state, { circuit: id, unknown: s.defaultUnknown, values: Object.assign({}, s.defaults), selected: null, zoom: 1, query: '' });
    save(); render();
    root.scrollIntoView({ block: 'start' });
  }
  function close() { state.circuit = null; save(); render(); }

  function hub() {
    let h = '<p class="eb-lede">Pick a circuit. Schematic and breadboard share one electrical identity. Node volts and branch currents (A / mA / µA) update as you edit. Tap a part or open the inspector for searchable readings.</p>';
    E.FAMILIES.forEach((fam) => {
      const items = E.SPECS.filter((s) => s.family === fam.id);
      if (!items.length) return;
      h += '<div class="eb-family"><div class="eb-family-title">' + esc(fam.title) + '</div><div class="eb-grid">';
      items.forEach((s) => { h += '<button type="button" class="eb-circuit" data-open="' + s.id + '"><strong>' + esc(s.title) + '</strong><span>' + esc(s.blurb) + '</span></button>'; });
      h += '</div></div>';
    });
    return h;
  }

  function fieldHtml(f) {
    const val = state.values[f.id] == null ? '' : state.values[f.id];
    const help = f.help ? '<small class="eb-help">' + esc(f.help) + '</small>' : '';
    if (f.choices.length) {
      return '<div class="eb-field"><label for="eb_f_' + f.id + '">' + esc(f.title) + '</label><select id="eb_f_' + f.id + '" data-field="' + f.id + '">' +
        f.choices.map((c) => '<option value="' + c.id + '"' + (c.id === val ? ' selected' : '') + '>' + esc(c.title) + '</option>').join('') + '</select>' + help + '</div>';
    }
    return '<div class="eb-field"><label for="eb_f_' + f.id + '">' + esc(f.title) + (f.unit ? ' <span class="eb-unit">(' + esc(f.unit) + ')</span>' : '') + '</label>' +
      '<input id="eb_f_' + f.id + '" data-field="' + f.id + '" inputmode="text" autocomplete="off" autocapitalize="off" spellcheck="false" value="' + esc(val) + '">' + help + '</div>';
  }

  function resultHtml(res) {
    if (!res.ok) return '<div class="result error show" role="alert">' + esc(res.error) + '</div>';
    const sol = res.solution;
    let h = '<div class="eb-headline" aria-live="polite">' + esc(sol.headline) + '</div>';
    h += '<div class="eb-qty">' + sol.quantities.map((qq) => '<div class="eb-q' + (qq.emphasis ? ' eb-q-hot' : '') + '"><span>' + esc(qq.name) + '</span><b>' + esc(E.si(qq.value, qq.unit)) + '</b></div>').join('') + '</div>';
    h += '<details class="eb-work"><summary>Show work</summary><ol>' + sol.steps.map((s) => '<li>' + esc(s) + '</li>').join('') + '</ol></details>';
    h += '<ul class="eb-notes">' + sol.notes.map((s) => '<li>' + esc(s) + '</li>').join('') + '</ul>';
    return h;
  }

  function pitchFor(width) {
    const fit = (width - 16 - 92 - 16) / E.BB_COLUMNS;
    return Math.max(4.5, Math.min(22, fit)) * state.zoom;
  }

  function pictureHtml(res) {
    if (!res.ok) return '<div class="eb-empty">Fix the input above to draw the circuit.</div>';
    const sol = res.solution;
    if (state.picture === 'schematic') return R.renderSchematic(sol, { layer: state.layer });
    if (!sol.layout) return '<div class="eb-empty">No breadboard hookup for this circuit yet. Use the schematic.</div>';
    const w = (root.querySelector('.eb-picture') || root).clientWidth || 360;
    const p = pitchFor(w);
    return '<div class="eb-scroll">' + R.renderBreadboard(sol.layout, { pitch: p, layer: state.layer, selected: state.selected }) + '</div>';
  }

  function auditHtml(res) {
    if (!res.ok || state.picture !== 'breadboard' || !res.solution.layout) return '';
    const a = res.solution.layout.audit;
    const meters = res.solution.layout.meters.map((m) => m.title + ' ' + m.reading).join('  ·  ');
    let h = '<div class="eb-audit ' + (a.ok ? 'ok' : 'bad') + '" role="status">' + (a.ok ? '✓ Board audit: no shorts, opens, or clashing holes.' : '⚠ Board audit: ' + esc(a.shorts.concat(a.opens, a.clashes, a.faults).join('; '))) + '</div>';
    if (meters) h += '<div class="eb-meters" aria-label="Readings">' + esc(meters) + '</div>';
    h += '<p class="eb-caption">' + esc(res.solution.layout.caption) + '</p>';
    return h;
  }

  function inspectorHtml(res) {
    if (!res.ok) return '';
    const terms = state.query.toLowerCase().split(/\s+/).filter(Boolean);
    let rows = R.inspectorRows(res.solution).filter((r) => terms.every((t) => (r.kind + ' ' + r.name + ' ' + r.value).toLowerCase().indexOf(t) >= 0));
    let h = '<details class="eb-inspector"' + (state.query ? ' open' : '') + '><summary>Inspector — every reading</summary>' +
      '<input type="search" id="eb_q" placeholder="Search readings, nodes, parts" value="' + esc(state.query) + '" aria-label="Search readings">' +
      '<table><tbody>' + rows.map((r) => '<tr><td>' + esc(r.kind) + '</td><td>' + esc(r.name) + '</td><td>' + esc(r.value) + '</td></tr>').join('') + '</tbody></table>';
    if (state.selected && res.solution.layout) {
      const c = res.solution.layout.components.find((x) => x.id === state.selected);
      if (c) h += '<p class="eb-sel"><b>' + esc(c.part.label || c.part.name || c.id) + '</b> — ' + c.leads.map((l) => l.hole.column + l.hole.row + ' → ' + esc(l.net)).join(', ') + '</p>';
    }
    return h + '</details>';
  }

  function screen() {
    const s = E.specOf(state.circuit);
    const res = E.solveSafe(state.circuit, state.unknown, state.values);
    const hasBoard = res.ok ? !!res.solution.layout : true;
    let h = '<button type="button" class="btn btn-sm eb-back" data-act="back">‹ All circuits</button>';
    h += '<h3 class="eb-title">' + esc(s.title) + '</h3><p class="eb-lede">' + esc(s.blurb) + '</p>';
    h += '<div class="eb-cols"><div class="eb-inputs">';
    h += '<div class="eb-field"><label for="eb_unknown">Solve for</label><select id="eb_unknown">' + s.unknowns.map((u) => '<option value="' + u.id + '"' + (u.id === state.unknown ? ' selected' : '') + '>' + esc(u.title) + '</option>').join('') + '</select></div>';
    h += '<div class="eb-fields">' + E.visibleFields(state.circuit, state.unknown, state.values).map(fieldHtml).join('') + '</div>';
    h += '<small class="eb-help">Values accept engineering suffixes: 4.7k, 100n, 2.2u, 1M.</small>';
    h += '<div class="eb-actions"><button type="button" class="btn btn-sm" data-act="example">Example</button><button type="button" class="btn btn-sm" data-act="copy">' + (state.copied ? 'Copied' : 'Copy result') + '</button></div>';
    h += '<div class="eb-result" id="eb_result">' + resultHtml(res) + '</div></div>';
    h += '<div class="eb-view"><div class="eb-tabs" role="tablist">' +
      ['schematic', 'breadboard'].map((t) => '<button type="button" role="tab" aria-selected="' + (state.picture === t) + '" class="eb-tab' + (state.picture === t ? ' on' : '') + '" data-pic="' + t + '">' + (t === 'schematic' ? 'Schematic' : 'Breadboard') + '</button>').join('') + '</div>';
    h += '<div class="eb-bar"><label>Labels <select id="eb_layer"><option value="minimal"' + (state.layer === 'minimal' ? ' selected' : '') + '>Minimal</option><option value="values"' + (state.layer === 'values' ? ' selected' : '') + '>Values</option><option value="measurements"' + (state.layer === 'measurements' ? ' selected' : '') + '>Measurements</option></select></label>';
    if (state.picture === 'breadboard') h += '<span class="eb-zoom"><button type="button" class="btn btn-sm" data-act="zoomout" aria-label="Zoom out">−</button><button type="button" class="btn btn-sm" data-act="zoomreset" aria-label="Reset zoom">Fit</button><button type="button" class="btn btn-sm" data-act="zoomin" aria-label="Zoom in">+</button></span>';
    h += '<button type="button" class="btn btn-sm" data-act="png">Save PNG</button></div>';
    h += '<div class="eb-picture" id="eb_picture">' + pictureHtml(res) + '</div>' + auditHtml(res) + inspectorHtml(res) + '</div></div>';
    h += '<p class="eb-foot">Ideal lumped models, not SPICE. BJT bias uses a fixed 0.7 V Vbe and constant β; MOSFETs use the square law. Design aid — check the datasheet before building.' + (hasBoard ? '' : '') + '</p>';
    return h;
  }

  function render() {
    root.innerHTML = '<div class="eb">' + (state.circuit ? screen() : hub()) + '</div>';
  }
  /* partial update while typing so inputs keep focus */
  function update() {
    const res = E.solveSafe(state.circuit, state.unknown, state.values);
    const set = (id, html) => { const el = document.getElementById(id); if (el) el.innerHTML = html; };
    set('eb_result', resultHtml(res));
    set('eb_picture', pictureHtml(res));
    const view = root.querySelector('.eb-view');
    if (view) {
      view.querySelectorAll('.eb-audit,.eb-meters,.eb-caption,.eb-inspector').forEach((n) => n.remove());
      view.insertAdjacentHTML('beforeend', auditHtml(res) + inspectorHtml(res));
    }
    save();
  }

  function copyText() {
    const res = E.solveSafe(state.circuit, state.unknown, state.values);
    if (!res.ok) return res.error;
    const s = res.solution;
    return E.specOf(state.circuit).title + '\n' + s.headline + '\n' + s.quantities.map((qq) => qq.name + ' = ' + E.si(qq.value, qq.unit)).join('\n') + '\n' + s.steps.join('\n') + '\nbeckify.com/toolbox/';
  }

  function savePng() {
    const svgEl = root.querySelector('#eb_picture svg');
    if (!svgEl) return;
    const clone = svgEl.cloneNode(true);
    const vb = clone.getAttribute('viewBox').split(' ').map(Number);
    const scale = Math.max(2, Math.ceil((global.devicePixelRatio || 1) * 2));
    clone.setAttribute('width', vb[2]); clone.setAttribute('height', vb[3]);
    const img = new Image();
    img.onload = () => {
      const cv = document.createElement('canvas'); cv.width = vb[2] * scale; cv.height = vb[3] * scale;
      const ctx = cv.getContext('2d'); ctx.scale(scale, scale); ctx.drawImage(img, 0, 0, vb[2], vb[3]);
      const a = document.createElement('a'); a.download = 'beckify-' + state.circuit + '-' + state.picture + '.png'; a.href = cv.toDataURL('image/png'); a.click();
    };
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(new XMLSerializer().serializeToString(clone));
  }

  root.addEventListener('click', (ev) => {
    const t = ev.target.closest('[data-open],[data-act],[data-pic]');
    if (t) {
      if (t.dataset.open) return open(t.dataset.open);
      if (t.dataset.pic) { state.picture = t.dataset.pic; save(); return render(); }
      const act = t.dataset.act;
      if (act === 'back') return close();
      if (act === 'example') { state.values = Object.assign({}, E.specOf(state.circuit).defaults); state.unknown = E.specOf(state.circuit).defaultUnknown; save(); return render(); }
      if (act === 'copy') { const done = () => { state.copied = true; render(); setTimeout(() => { state.copied = false; render(); }, 1500); }; if (navigator.clipboard) navigator.clipboard.writeText(copyText()).then(done, done); else done(); return; }
      if (act === 'zoomin') { state.zoom = Math.min(4, state.zoom * 1.25); return update(); }
      if (act === 'zoomout') { state.zoom = Math.max(1, state.zoom / 1.25); return update(); }
      if (act === 'zoomreset') { state.zoom = 1; return update(); }
      if (act === 'png') return savePng();
    }
    // tap a breadboard part to inspect
    const svg = ev.target.closest('.eb-breadboard');
    if (svg && state.picture === 'breadboard') {
      const res = E.solveSafe(state.circuit, state.unknown, state.values);
      if (!res.ok || !res.solution.layout) return;
      const rect = svg.getBoundingClientRect(), vb = svg.viewBox.baseVal, k = vb.width / rect.width;
      const x = (ev.clientX - rect.left) * k, y = (ev.clientY - rect.top) * k, p = pitchFor(root.querySelector('.eb-picture').clientWidth || 360);
      let best = null;
      res.solution.layout.components.forEach((c) => {
        const cs = c.leads.map((l) => ({ x: 92 + (l.hole.column - 1) * p, y: 22 + (E.ROW_Y.botPlus - E.ROW_Y[l.hole.row]) * p }));
        const mx = cs.reduce((s, q) => s + q.x, 0) / cs.length, my = cs.reduce((s, q) => s + q.y, 0) / cs.length, d = Math.hypot(mx - x, my - y);
        if (d < p * 1.8 && (!best || d < best.d)) best = { id: c.id, d };
      });
      state.selected = best ? best.id : null;
      update();
    }
  });
  root.addEventListener('input', (ev) => {
    const t = ev.target;
    if (t.dataset && t.dataset.field) { state.values[t.dataset.field] = t.value; update(); }
    else if (t.id === 'eb_q') { state.query = t.value; const keep = t.selectionStart; update(); const q2 = document.getElementById('eb_q'); if (q2) { q2.focus(); q2.setSelectionRange(keep, keep); } }
  });
  root.addEventListener('change', (ev) => {
    const t = ev.target;
    if (t.id === 'eb_unknown') { state.unknown = t.value; save(); render(); }
    else if (t.id === 'eb_layer') { state.layer = t.value; save(); update(); }
    else if (t.dataset && t.dataset.field && E.specOf(state.circuit).fields.some((f) => f.id === t.dataset.field && f.choices.length)) { state.values[t.dataset.field] = t.value; save(); render(); }
  });
  let rz; global.addEventListener('resize', () => { clearTimeout(rz); rz = setTimeout(() => { if (state.circuit && state.picture === 'breadboard') update(); }, 120); });

  // deep link: #sec-electronics-bench/<circuit>
  function fromHash() {
    const m = /electronics-bench\/([A-Za-z0-9]+)/.exec(global.location.hash || '');
    if (m && E.circuits().indexOf(m[1]) >= 0) open(m[1]);
  }
  restore(); render(); fromHash();
  global.addEventListener('hashchange', fromHash);
  // re-measure once the section becomes visible (the classic page hides inactive sections)
  if (global.IntersectionObserver) new IntersectionObserver((es) => { if (es.some((e) => e.isIntersecting) && state.circuit && state.picture === 'breadboard') update(); }).observe(root);
})(typeof window !== 'undefined' ? window : globalThis);
