/* ============================================================================
   WIRE COLORS — NEC identification + UL 508A industrial control panel practice
   ============================================================================
   Code vs convention is labeled on every row. Not a substitute for the
   adopted NEC edition or UL 508A. Hot colors are not NEC-mandated except
   where a row says CODE.
   ============================================================================ */

(function (global) {
  'use strict';

  var NEC_SYSTEMS = [
    {
      id: '120-240-1ph',
      title: '120/240 V single-phase 3-wire',
      rows: [
        { conductor: 'L1 (ungrounded)', color: 'Black', swatch: '#1a1a1a', ink: '#f5f5f5', mandate: 'convention', cite: 'Industry convention — NEC does not require a specific hot color.' },
        { conductor: 'L2 (ungrounded)', color: 'Red', swatch: '#dc2626', ink: '#fff', mandate: 'convention', cite: 'Industry convention — NEC does not require a specific hot color.' },
        { conductor: 'Neutral (grounded)', color: 'White or gray', swatch: '#f4f4f5', ink: '#18181b', mandate: 'code', cite: 'NEC 200.6 — grounded conductor identification.' },
        { conductor: 'Equipment grounding', color: 'Green / green-yellow / bare', swatch: '#16a34a', ink: '#052e16', mandate: 'code', cite: 'NEC 250.119 — EGC identification.' },
      ],
    },
    {
      id: '120-208-3ph',
      title: '120/208 V three-phase 4-wire wye',
      rows: [
        { conductor: 'Phase A (ungrounded)', color: 'Black', swatch: '#1a1a1a', ink: '#f5f5f5', mandate: 'convention', cite: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Phase B (ungrounded)', color: 'Red', swatch: '#dc2626', ink: '#fff', mandate: 'convention', cite: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Phase C (ungrounded)', color: 'Blue', swatch: '#2563eb', ink: '#fff', mandate: 'convention', cite: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Neutral (grounded)', color: 'White or gray', swatch: '#f4f4f5', ink: '#18181b', mandate: 'code', cite: 'NEC 200.6 — grounded conductor identification.' },
        { conductor: 'Equipment grounding', color: 'Green / green-yellow / bare', swatch: '#16a34a', ink: '#052e16', mandate: 'code', cite: 'NEC 250.119 — EGC identification.' },
      ],
    },
    {
      id: '120-240-3ph-highleg',
      title: '120/240 V three-phase 4-wire high-leg delta',
      rows: [
        { conductor: 'Phase A (ungrounded)', color: 'Black', swatch: '#1a1a1a', ink: '#f5f5f5', mandate: 'convention', cite: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Phase B high-leg (ungrounded)', color: 'Orange', swatch: '#f97316', ink: '#1c1008', mandate: 'code', cite: 'NEC 110.15 — the high-leg must be identified orange (or other effective means). This one is code, not convention.' },
        { conductor: 'Phase C (ungrounded)', color: 'Blue', swatch: '#2563eb', ink: '#fff', mandate: 'convention', cite: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Neutral (grounded)', color: 'White or gray', swatch: '#f4f4f5', ink: '#18181b', mandate: 'code', cite: 'NEC 200.6 — grounded conductor identification.' },
        { conductor: 'Equipment grounding', color: 'Green / green-yellow / bare', swatch: '#16a34a', ink: '#052e16', mandate: 'code', cite: 'NEC 250.119 — EGC identification.' },
      ],
    },
    {
      id: '277-480-3ph',
      title: '277/480 V three-phase 4-wire wye',
      rows: [
        { conductor: 'Phase A (ungrounded)', color: 'Brown', swatch: '#7c4a1e', ink: '#fff7ed', mandate: 'convention', cite: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Phase B (ungrounded)', color: 'Orange', swatch: '#f97316', ink: '#1c1008', mandate: 'convention', cite: 'Industry convention — not an NEC color mandate. Orange here is not the high-leg rule.' },
        { conductor: 'Phase C (ungrounded)', color: 'Yellow', swatch: '#eab308', ink: '#1c1500', mandate: 'convention', cite: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Neutral (grounded)', color: 'Gray (often preferred at 277 V)', swatch: '#a1a1aa', ink: '#18181b', mandate: 'code', cite: 'NEC 200.6 allows white or gray. Gray at 480Y/277 V is convention, not a separate code color.' },
        { conductor: 'Equipment grounding', color: 'Green / green-yellow / bare', swatch: '#16a34a', ink: '#052e16', mandate: 'code', cite: 'NEC 250.119 — EGC identification.' },
      ],
    },
    {
      id: 'dc',
      title: 'DC power (field convention)',
      rows: [
        { conductor: 'Positive (ungrounded)', color: 'Red (common) or blue', swatch: '#dc2626', ink: '#fff', mandate: 'convention', cite: 'Industry convention — NEC does not assign a required DC hot color in premises wiring.' },
        { conductor: 'Negative (ungrounded or return)', color: 'Black (common) or white/blue per system', swatch: '#1a1a1a', ink: '#f5f5f5', mandate: 'convention', cite: 'Confirm the system drawing. Grounded DC returns follow 200.6 when they are grounded conductors.' },
        { conductor: 'Grounded conductor (if used)', color: 'White or gray', swatch: '#f4f4f5', ink: '#18181b', mandate: 'code', cite: 'NEC 200.6 when the conductor is a grounded conductor.' },
        { conductor: 'Equipment grounding', color: 'Green / green-yellow / bare', swatch: '#16a34a', ink: '#052e16', mandate: 'code', cite: 'NEC 250.119 — EGC identification.' },
      ],
    },
  ];

  /* UL 508A 3rd Edition (with the April 2020 color-coding revision):
     66.5 internal wiring of power circuits; 66.9 internal wiring of control
     circuits. Yellow / orange foreign-voltage identification is the safety
     callout. This is industrial control panel practice — not NEC-mandated
     hot colors. */
  var UL508A_ROWS = [
    { color: 'Black', swatch: '#1a1a1a', ink: '#f5f5f5', role: 'Ungrounded AC or DC power / line', section: 'UL 508A 66.5.2(a)', note: 'Power-circuit ungrounded conductors throughout the panel unless another identification is documented.', safety: false },
    { color: 'Red', swatch: '#dc2626', ink: '#fff', role: 'Ungrounded AC control', section: 'UL 508A 66.9.1(a)', note: 'Ungrounded AC control-circuit conductors (post-2020 text: red for AC control).', safety: false },
    { color: 'Blue', swatch: '#2563eb', ink: '#fff', role: 'Ungrounded DC control', section: 'UL 508A 66.9.1(b)', note: 'Ungrounded DC control-circuit conductors.', safety: false },
    { color: 'Yellow or orange', swatch: '#eab308', ink: '#1c1500', role: 'Interlock / foreign voltage — may be live when the disconnect is off', section: 'UL 508A 66.9.1.3 / exception to 66.6.1', note: 'SAFETY: ungrounded conductors of excepted circuits that remain energized with the main disconnect OFF. Treat as live. Older 66.9 text said yellow or orange; the 2020 revision uses orange for this ungrounded excepted circuit.', safety: true },
    { color: 'White or gray', swatch: '#f4f4f5', ink: '#18181b', role: 'Grounded AC (power or control)', section: 'UL 508A 66.5.2(b) and 66.9.1.2(a)', note: 'Grounded AC current-carrying conductor. Three white stripes on a color other than green, blue, or orange are also recognized.', safety: false },
    { color: 'White with blue stripe', swatch: '#e0f2fe', ink: '#0c4a6e', role: 'Grounded DC', section: 'UL 508A 66.9.1.2(b)', note: 'Grounded DC current-carrying control-circuit conductor.', safety: false },
    { color: 'White with orange (or yellow) stripe', swatch: '#fef3c7', ink: '#78350f', role: 'Grounded conductor of a foreign-voltage / excepted circuit', section: 'UL 508A 66.9.1.2(c)', note: 'Grounded conductor of a circuit that remains energized when the main disconnect is OFF.', safety: true },
    { color: 'Green or green/yellow', swatch: '#16a34a', ink: '#052e16', role: 'Grounding / protective earth', section: 'UL 508A (EGC) / NEC 250.119', note: 'Equipment grounding. Not a current-carrying circuit conductor.', safety: false },
  ];

  var NEC_CODE_NOTES = [
    { article: '200.6', text: 'Grounded conductors identified white or gray (or three white stripes). CODE.' },
    { article: '250.119', text: 'EGC identified green, green with yellow stripe, or bare. CODE.' },
    { article: '110.15', text: 'High-leg of a 4-wire delta identified orange (or other effective means). CODE — this is the orange that is not convention.' },
    { article: '210.5(C)', text: 'Ungrounded conductors in some occupancies must be identified by phase/system where more than one nominal voltage system is present. Identification method is posted — colors themselves are still not assigned by 210.5(C) except as the identification system you adopt.' },
  ];

  function highLegRow() {
    var sys = NEC_SYSTEMS.filter(function (s) { return s.id === '120-240-3ph-highleg'; })[0];
    return sys.rows.filter(function (r) { return /high-leg/i.test(r.conductor); })[0];
  }

  function ulYellowInterlock() {
    return UL508A_ROWS.filter(function (r) { return r.safety && /yellow/i.test(r.color); })[0];
  }

  function el(id) { return document.getElementById(id); }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function swatchCard(row) {
    var badge = row.mandate === 'code'
      ? '<span class="wc-badge wc-badge-code">CODE</span>'
      : '<span class="wc-badge wc-badge-conv">CONVENTION — not code</span>';
    return '<article class="wc-swatch" style="background:' + row.swatch + ';color:' + row.ink + '">' +
      '<div class="wc-swatch-name">' + escapeHtml(row.color) + '</div>' +
      '<div class="wc-swatch-role">' + escapeHtml(row.conductor) + '</div>' +
      badge +
      '<p class="wc-swatch-cite">' + escapeHtml(row.cite) + '</p>' +
      '</article>';
  }

  function renderNec() {
    var host = el('wc_nec_systems');
    if (!host) return;
    host.innerHTML = NEC_SYSTEMS.map(function (sys) {
      return '<div class="wc-system" id="wc-' + escapeHtml(sys.id) + '">' +
        '<h3 class="wc-system-title">' + escapeHtml(sys.title) + '</h3>' +
        '<div class="wc-swatch-grid">' + sys.rows.map(swatchCard).join('') + '</div>' +
        '</div>';
    }).join('');

    var notes = el('wc_nec_notes');
    if (notes) {
      notes.innerHTML = '<ul>' + NEC_CODE_NOTES.map(function (n) {
        return '<li><strong>' + escapeHtml(n.article) + ':</strong> ' + escapeHtml(n.text) + '</li>';
      }).join('') + '</ul>';
    }
  }

  function renderUl() {
    var host = el('wc_ul_grid');
    if (!host) return;
    host.innerHTML = UL508A_ROWS.map(function (row) {
      var extra = row.safety ? '<p class="wc-safety">Safety callout — may be live with the disconnect off. This is UL 508A industrial control panel practice, not an NEC-mandated hot color.</p>' : '';
      return '<article class="wc-swatch' + (row.safety ? ' wc-swatch-safety' : '') + '" style="background:' + row.swatch + ';color:' + row.ink + '">' +
        '<div class="wc-swatch-name">' + escapeHtml(row.color) + '</div>' +
        '<div class="wc-swatch-role">' + escapeHtml(row.role) + '</div>' +
        '<p class="wc-swatch-cite">' + escapeHtml(row.section) + ' — ' + escapeHtml(row.note) + '</p>' +
        extra +
        '</article>';
    }).join('');
  }

  function bind() {
    if (!el('sec-wire-colors')) return;
    renderNec();
    renderUl();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bind);
  } else {
    bind();
  }

  global.__wireColorsTestApi = {
    NEC_SYSTEMS: NEC_SYSTEMS,
    UL508A_ROWS: UL508A_ROWS,
    NEC_CODE_NOTES: NEC_CODE_NOTES,
    highLegRow: highLegRow,
    ulYellowInterlock: ulYellowInterlock,
  };
})(typeof window !== 'undefined' ? window : globalThis);
