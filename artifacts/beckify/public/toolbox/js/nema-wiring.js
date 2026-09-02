/* ============================================================================
   NEMA WIRING CONFIGURATIONS & COLOR-CODE REFERENCE
   ============================================================================
   Visual field reference. SVG pin/blade diagrams, not photographs.
   Neutral/EGC colors cite NEC 200.6 and 250.119. Ungrounded (hot) colors are
   industry convention except the high-leg identification in 110.15.
   ============================================================================ */
(function (global) {
  'use strict';

  var C = {
    hot: '#f5c451',
    hot2: '#f87171',
    hot3: '#4f8bff',
    neu: '#eef0fa',
    gnd: '#4ade80',
    body: '#1a1d2e',
    rim: '#8b7bff',
    slot: '#0b0d18',
    label: '#eef0fa',
    muted: '#9497b8',
  };

  /* Blade maps are as viewed facing the RECEPTACLE (female, wall/device). */
  var CONFIGS = [
    { id: '5-15', name: 'NEMA 5-15', volts: 125, amps: 15, phase: '1φ', poles: 2, wires: 3, locking: false, family: 'straight',
      summary: 'Everyday 15 A duplex. Neutral slot is the taller opening.',
      blades: [
        { id: 'N', role: 'Neutral (grounded)', color: 'White or gray', code: 'NEC 200.6', kind: 'neu', shape: 'slot-tall', x: 38, y: 42 },
        { id: 'H', role: 'Hot (ungrounded)', color: 'Black (convention)', code: 'convention', kind: 'hot', shape: 'slot-short', x: 62, y: 42 },
        { id: 'G', role: 'Equipment grounding', color: 'Green / green-yellow / bare', code: 'NEC 250.119', kind: 'gnd', shape: 'u-ground', x: 50, y: 68 },
      ] },
    { id: '5-20', name: 'NEMA 5-20', volts: 125, amps: 20, phase: '1φ', poles: 2, wires: 3, locking: false, family: 'straight',
      summary: '20 A 125 V. Neutral is a T-slot so a 5-15 plug still fits.',
      blades: [
        { id: 'N', role: 'Neutral (grounded)', color: 'White or gray', code: 'NEC 200.6', kind: 'neu', shape: 't-slot', x: 38, y: 42 },
        { id: 'H', role: 'Hot (ungrounded)', color: 'Black (convention)', code: 'convention', kind: 'hot', shape: 'slot-short', x: 62, y: 42 },
        { id: 'G', role: 'Equipment grounding', color: 'Green / green-yellow / bare', code: 'NEC 250.119', kind: 'gnd', shape: 'u-ground', x: 50, y: 68 },
      ] },
    { id: '6-15', name: 'NEMA 6-15', volts: 250, amps: 15, phase: '1φ', poles: 2, wires: 3, locking: false, family: 'straight',
      summary: '15 A 250 V. Two hots, no neutral. Horizontal slots.',
      blades: [
        { id: 'X', role: 'Hot X (ungrounded)', color: 'Black (convention)', code: 'convention', kind: 'hot', shape: 'slot-h', x: 38, y: 42 },
        { id: 'Y', role: 'Hot Y (ungrounded)', color: 'Red (convention)', code: 'convention', kind: 'hot2', shape: 'slot-h', x: 62, y: 42 },
        { id: 'G', role: 'Equipment grounding', color: 'Green / green-yellow / bare', code: 'NEC 250.119', kind: 'gnd', shape: 'u-ground', x: 50, y: 68 },
      ] },
    { id: '6-20', name: 'NEMA 6-20', volts: 250, amps: 20, phase: '1φ', poles: 2, wires: 3, locking: false, family: 'straight',
      summary: '20 A 250 V. Neutral is not present. One slot is T-shaped.',
      blades: [
        { id: 'X', role: 'Hot X (ungrounded)', color: 'Black (convention)', code: 'convention', kind: 'hot', shape: 'slot-h', x: 38, y: 42 },
        { id: 'Y', role: 'Hot Y (ungrounded)', color: 'Red (convention)', code: 'convention', kind: 'hot2', shape: 't-slot', x: 62, y: 42 },
        { id: 'G', role: 'Equipment grounding', color: 'Green / green-yellow / bare', code: 'NEC 250.119', kind: 'gnd', shape: 'u-ground', x: 50, y: 68 },
      ] },
    { id: '6-50', name: 'NEMA 6-50', volts: 250, amps: 50, phase: '1φ', poles: 2, wires: 3, locking: false, family: 'straight',
      summary: 'Common welder / 250 V equipment receptacle. Two hots + ground.',
      blades: [
        { id: 'X', role: 'Hot X (ungrounded)', color: 'Black (convention)', code: 'convention', kind: 'hot', shape: 'slot-h', x: 32, y: 40 },
        { id: 'Y', role: 'Hot Y (ungrounded)', color: 'Red (convention)', code: 'convention', kind: 'hot2', shape: 'slot-h', x: 68, y: 40 },
        { id: 'G', role: 'Equipment grounding', color: 'Green / green-yellow / bare', code: 'NEC 250.119', kind: 'gnd', shape: 'u-ground', x: 50, y: 70 },
      ] },
    { id: '14-30', name: 'NEMA 14-30', volts: '125/250', amps: 30, phase: '1φ', poles: 3, wires: 4, locking: false, family: 'straight',
      summary: 'Dryer-style 4-wire: two hots, neutral, ground. Do not bootleg a ground to the neutral.',
      blades: [
        { id: 'X', role: 'Hot X (ungrounded)', color: 'Black (convention)', code: 'convention', kind: 'hot', shape: 'slot-diag-l', x: 32, y: 38 },
        { id: 'Y', role: 'Hot Y (ungrounded)', color: 'Red (convention)', code: 'convention', kind: 'hot2', shape: 'slot-diag-r', x: 68, y: 38 },
        { id: 'W', role: 'Neutral (grounded)', color: 'White or gray', code: 'NEC 200.6', kind: 'neu', shape: 'slot-l', x: 50, y: 32 },
        { id: 'G', role: 'Equipment grounding', color: 'Green / green-yellow / bare', code: 'NEC 250.119', kind: 'gnd', shape: 'u-ground', x: 50, y: 70 },
      ] },
    { id: '14-50', name: 'NEMA 14-50', volts: '125/250', amps: 50, phase: '1φ', poles: 3, wires: 4, locking: false, family: 'straight',
      summary: 'Range / EVSE-style 4-wire 50 A. Same X-Y-W-G roles as 14-30, larger pins.',
      blades: [
        { id: 'X', role: 'Hot X (ungrounded)', color: 'Black (convention)', code: 'convention', kind: 'hot', shape: 'slot-diag-l', x: 30, y: 38 },
        { id: 'Y', role: 'Hot Y (ungrounded)', color: 'Red (convention)', code: 'convention', kind: 'hot2', shape: 'slot-diag-r', x: 70, y: 38 },
        { id: 'W', role: 'Neutral (grounded)', color: 'White or gray', code: 'NEC 200.6', kind: 'neu', shape: 'slot-l', x: 50, y: 30 },
        { id: 'G', role: 'Equipment grounding', color: 'Green / green-yellow / bare', code: 'NEC 250.119', kind: 'gnd', shape: 'u-ground', x: 50, y: 72 },
      ] },
    { id: 'TT-30', name: 'NEMA TT-30', volts: 125, amps: 30, phase: '1φ', poles: 2, wires: 3, locking: false, family: 'straight',
      summary: 'RV 30 A recreational receptacle. One hot, one neutral, one ground.',
      blades: [
        { id: 'H', role: 'Hot (ungrounded)', color: 'Black (convention)', code: 'convention', kind: 'hot', shape: 'slot-short', x: 38, y: 40 },
        { id: 'N', role: 'Neutral (grounded)', color: 'White or gray', code: 'NEC 200.6', kind: 'neu', shape: 'slot-tall', x: 62, y: 40 },
        { id: 'G', role: 'Equipment grounding', color: 'Green / green-yellow / bare', code: 'NEC 250.119', kind: 'gnd', shape: 'u-ground', x: 50, y: 70 },
      ] },
    { id: 'L5-20', name: 'NEMA L5-20', volts: 125, amps: 20, phase: '1φ', poles: 2, wires: 3, locking: true, family: 'locking',
      summary: 'Twist-lock 125 V. Ground is the unique keyed pin.',
      blades: lockBlades125() },
    { id: 'L5-30', name: 'NEMA L5-30', volts: 125, amps: 30, phase: '1φ', poles: 2, wires: 3, locking: true, family: 'locking',
      summary: 'Twist-lock 125 V 30 A. Same pin roles as L5-20, larger shell.',
      blades: lockBlades125() },
    { id: 'L6-20', name: 'NEMA L6-20', volts: 250, amps: 20, phase: '1φ', poles: 2, wires: 3, locking: true, family: 'locking',
      summary: 'Twist-lock 250 V. Two hots + ground, no neutral.',
      blades: lockBlades250() },
    { id: 'L6-30', name: 'NEMA L6-30', volts: 250, amps: 30, phase: '1φ', poles: 2, wires: 3, locking: true, family: 'locking',
      summary: 'Twist-lock 250 V 30 A. Common for 240 V tools.',
      blades: lockBlades250() },
    { id: 'L14-20', name: 'NEMA L14-20', volts: '125/250', amps: 20, phase: '1φ', poles: 3, wires: 4, locking: true, family: 'locking',
      summary: 'Twist-lock 4-wire 125/250 V. Two hots, neutral, ground.',
      blades: lockBlades125250() },
    { id: 'L14-30', name: 'NEMA L14-30', volts: '125/250', amps: 30, phase: '1φ', poles: 3, wires: 4, locking: true, family: 'locking',
      summary: 'Generator / transfer 30 A locking 4-wire. Same X-Y-W-G as L14-20.',
      blades: lockBlades125250() },
    { id: 'L15-30', name: 'NEMA L15-30', volts: 250, amps: 30, phase: '3φ', poles: 3, wires: 4, locking: true, family: 'locking',
      summary: 'Three-phase 250 V locking. Three hots + ground, no neutral.',
      blades: lockBlades3ph() },
    { id: 'L21-30', name: 'NEMA L21-30', volts: '120/208', amps: 30, phase: '3φ', poles: 4, wires: 5, locking: true, family: 'locking',
      summary: 'Three-phase 4-pole 5-wire: X Y Z W + ground. 120/208 V wye.',
      blades: lockBlades3phWye() },
  ];

  function lockBlades125() {
    return [
      { id: 'G', role: 'Equipment grounding', color: 'Green / green-yellow / bare', code: 'NEC 250.119', kind: 'gnd', shape: 'pin-key', angle: -90, r: 22 },
      { id: 'N', role: 'Neutral (grounded)', color: 'White or gray', code: 'NEC 200.6', kind: 'neu', shape: 'pin', angle: 150, r: 22 },
      { id: 'H', role: 'Hot (ungrounded)', color: 'Black (convention)', code: 'convention', kind: 'hot', shape: 'pin', angle: 30, r: 22 },
    ];
  }
  function lockBlades250() {
    return [
      { id: 'G', role: 'Equipment grounding', color: 'Green / green-yellow / bare', code: 'NEC 250.119', kind: 'gnd', shape: 'pin-key', angle: -90, r: 22 },
      { id: 'X', role: 'Hot X (ungrounded)', color: 'Black (convention)', code: 'convention', kind: 'hot', shape: 'pin', angle: 150, r: 22 },
      { id: 'Y', role: 'Hot Y (ungrounded)', color: 'Red (convention)', code: 'convention', kind: 'hot2', shape: 'pin', angle: 30, r: 22 },
    ];
  }
  function lockBlades125250() {
    return [
      { id: 'G', role: 'Equipment grounding', color: 'Green / green-yellow / bare', code: 'NEC 250.119', kind: 'gnd', shape: 'pin-key', angle: -90, r: 24 },
      { id: 'W', role: 'Neutral (grounded)', color: 'White or gray', code: 'NEC 200.6', kind: 'neu', shape: 'pin', angle: 90, r: 24 },
      { id: 'X', role: 'Hot X (ungrounded)', color: 'Black (convention)', code: 'convention', kind: 'hot', shape: 'pin', angle: 180, r: 24 },
      { id: 'Y', role: 'Hot Y (ungrounded)', color: 'Red (convention)', code: 'convention', kind: 'hot2', shape: 'pin', angle: 0, r: 24 },
    ];
  }
  function lockBlades3ph() {
    return [
      { id: 'G', role: 'Equipment grounding', color: 'Green / green-yellow / bare', code: 'NEC 250.119', kind: 'gnd', shape: 'pin-key', angle: -90, r: 24 },
      { id: 'X', role: 'Hot X (ungrounded)', color: 'Black (convention)', code: 'convention', kind: 'hot', shape: 'pin', angle: 150, r: 24 },
      { id: 'Y', role: 'Hot Y (ungrounded)', color: 'Red (convention)', code: 'convention', kind: 'hot2', shape: 'pin', angle: 30, r: 24 },
      { id: 'Z', role: 'Hot Z (ungrounded)', color: 'Blue (convention)', code: 'convention', kind: 'hot3', shape: 'pin', angle: 90, r: 24 },
    ];
  }
  function lockBlades3phWye() {
    return [
      { id: 'G', role: 'Equipment grounding', color: 'Green / green-yellow / bare', code: 'NEC 250.119', kind: 'gnd', shape: 'pin-key', angle: -90, r: 26 },
      { id: 'W', role: 'Neutral (grounded)', color: 'White or gray', code: 'NEC 200.6', kind: 'neu', shape: 'pin', angle: 90, r: 18 },
      { id: 'X', role: 'Hot X (ungrounded)', color: 'Black (convention)', code: 'convention', kind: 'hot', shape: 'pin', angle: 180, r: 24 },
      { id: 'Y', role: 'Hot Y (ungrounded)', color: 'Red (convention)', code: 'convention', kind: 'hot2', shape: 'pin', angle: 0, r: 24 },
      { id: 'Z', role: 'Hot Z (ungrounded)', color: 'Blue (convention)', code: 'convention', kind: 'hot3', shape: 'pin', angle: 45, r: 24 },
    ];
  }

  var COLOR_SYSTEMS = [
    {
      id: '120-240-1ph',
      title: '120/240 V single-phase 3-wire',
      rows: [
        { conductor: 'L1 (ungrounded)', color: 'Black', mandate: 'Industry convention — NEC does not require a specific hot color.' },
        { conductor: 'L2 (ungrounded)', color: 'Red', mandate: 'Industry convention — NEC does not require a specific hot color.' },
        { conductor: 'Neutral (grounded)', color: 'White or gray', mandate: 'NEC 200.6 — grounded conductor identification.' },
        { conductor: 'Equipment grounding', color: 'Green, green with yellow stripe, or bare', mandate: 'NEC 250.119 — EGC identification.' },
      ],
    },
    {
      id: '120-208-3ph',
      title: '120/208 V three-phase 4-wire wye',
      rows: [
        { conductor: 'Phase A (ungrounded)', color: 'Black', mandate: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Phase B (ungrounded)', color: 'Red', mandate: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Phase C (ungrounded)', color: 'Blue', mandate: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Neutral (grounded)', color: 'White or gray', mandate: 'NEC 200.6 — grounded conductor identification.' },
        { conductor: 'Equipment grounding', color: 'Green, green with yellow stripe, or bare', mandate: 'NEC 250.119 — EGC identification.' },
      ],
    },
    {
      id: '120-240-3ph',
      title: '120/240 V three-phase 4-wire high-leg delta',
      rows: [
        { conductor: 'Phase A (ungrounded)', color: 'Black', mandate: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Phase B high-leg (ungrounded)', color: 'Orange', mandate: 'NEC 110.15 — the high-leg must be identified orange (or other effective means). This one is code, not convention.' },
        { conductor: 'Phase C (ungrounded)', color: 'Blue', mandate: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Neutral (grounded)', color: 'White or gray', mandate: 'NEC 200.6 — grounded conductor identification.' },
        { conductor: 'Equipment grounding', color: 'Green, green with yellow stripe, or bare', mandate: 'NEC 250.119 — EGC identification.' },
      ],
    },
    {
      id: '277-480-3ph',
      title: '277/480 V three-phase 4-wire wye',
      rows: [
        { conductor: 'Phase A (ungrounded)', color: 'Brown', mandate: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Phase B (ungrounded)', color: 'Orange', mandate: 'Industry convention — not an NEC color mandate. Orange here is not the high-leg rule.' },
        { conductor: 'Phase C (ungrounded)', color: 'Yellow', mandate: 'Industry convention — not an NEC color mandate.' },
        { conductor: 'Neutral (grounded)', color: 'Gray (often preferred at 277 V to distinguish from 120 V white)', mandate: 'NEC 200.6 allows white or gray. Gray is convention at 480Y/277 V, not a separate code color.' },
        { conductor: 'Equipment grounding', color: 'Green, green with yellow stripe, or bare', mandate: 'NEC 250.119 — EGC identification.' },
      ],
    },
    {
      id: 'dc',
      title: 'DC power (field convention)',
      rows: [
        { conductor: 'Positive', color: 'Red', mandate: 'Industry convention — NEC does not assign red to DC positive.' },
        { conductor: 'Negative (ungrounded)', color: 'Black', mandate: 'Industry convention.' },
        { conductor: 'Negative (if grounded)', color: 'White or gray', mandate: 'NEC 200.6 still applies when a DC conductor is grounded.' },
        { conductor: 'Equipment grounding', color: 'Green, green with yellow stripe, or bare', mandate: 'NEC 250.119 — EGC identification.' },
      ],
    },
  ];

  function fillFor(kind) {
    return { hot: C.hot, hot2: C.hot2, hot3: C.hot3, neu: C.neu, gnd: C.gnd }[kind] || C.hot;
  }

  function polar(cx, cy, r, angleDeg) {
    var a = (angleDeg * Math.PI) / 180;
    return { x: cx + r * Math.cos(a), y: cy + r * Math.sin(a) };
  }

  function bladeShape(b) {
    var fill = fillFor(b.kind);
    if (b.shape === 'slot-tall') {
      return '<rect x="' + (b.x - 3.2) + '" y="' + (b.y - 14) + '" width="6.4" height="28" rx="1.2" fill="' + C.slot + '" stroke="' + fill + '" stroke-width="1.4"/>';
    }
    if (b.shape === 'slot-short') {
      return '<rect x="' + (b.x - 3.2) + '" y="' + (b.y - 10) + '" width="6.4" height="20" rx="1.2" fill="' + C.slot + '" stroke="' + fill + '" stroke-width="1.4"/>';
    }
    if (b.shape === 'slot-h') {
      return '<rect x="' + (b.x - 14) + '" y="' + (b.y - 3.2) + '" width="28" height="6.4" rx="1.2" fill="' + C.slot + '" stroke="' + fill + '" stroke-width="1.4"/>';
    }
    if (b.shape === 't-slot') {
      return '<rect x="' + (b.x - 3.2) + '" y="' + (b.y - 12) + '" width="6.4" height="24" rx="1.2" fill="' + C.slot + '" stroke="' + fill + '" stroke-width="1.4"/>' +
        '<rect x="' + (b.x - 12) + '" y="' + (b.y - 3.2) + '" width="24" height="6.4" rx="1.2" fill="' + C.slot + '" stroke="' + fill + '" stroke-width="1.4"/>';
    }
    if (b.shape === 'slot-l') {
      return '<rect x="' + (b.x - 12) + '" y="' + (b.y - 3.5) + '" width="24" height="7" rx="1.2" fill="' + C.slot + '" stroke="' + fill + '" stroke-width="1.4"/>';
    }
    if (b.shape === 'slot-diag-l') {
      return '<rect x="' + (b.x - 3) + '" y="' + (b.y - 14) + '" width="6" height="28" rx="1.2" transform="rotate(-25 ' + b.x + ' ' + b.y + ')" fill="' + C.slot + '" stroke="' + fill + '" stroke-width="1.4"/>';
    }
    if (b.shape === 'slot-diag-r') {
      return '<rect x="' + (b.x - 3) + '" y="' + (b.y - 14) + '" width="6" height="28" rx="1.2" transform="rotate(25 ' + b.x + ' ' + b.y + ')" fill="' + C.slot + '" stroke="' + fill + '" stroke-width="1.4"/>';
    }
    if (b.shape === 'u-ground') {
      return '<path d="M ' + (b.x - 8) + ' ' + (b.y - 4) + ' a 8 10 0 0 0 16 0" fill="none" stroke="' + fill + '" stroke-width="3.2" stroke-linecap="round"/>' +
        '<circle cx="' + b.x + '" cy="' + (b.y + 2) + '" r="3.4" fill="' + fill + '"/>';
    }
    var p = polar(50, 50, b.r || 22, b.angle || 0);
    var r = b.shape === 'pin-key' ? 6.4 : 5;
    return '<circle cx="' + p.x.toFixed(1) + '" cy="' + p.y.toFixed(1) + '" r="' + r + '" fill="' + fill + '" stroke="#05060f" stroke-width="1.4"/>' +
      '<text x="' + p.x.toFixed(1) + '" y="' + (p.y + 3.2).toFixed(1) + '" text-anchor="middle" font-size="7" font-weight="700" fill="#05060f">' + b.id + '</text>';
  }

  function bladeLabel(b, i) {
    if (b.shape === 'pin' || b.shape === 'pin-key') {
      var p = polar(50, 50, (b.r || 22) + 14, b.angle || 0);
      return '<text x="' + p.x.toFixed(1) + '" y="' + p.y.toFixed(1) + '" text-anchor="middle" font-size="6.5" fill="' + fillFor(b.kind) + '" font-weight="700">' + b.id + '</text>';
    }
    var ly = 12 + i * 0; /* labels live in the table, not stacked on the face */
    return '<text x="' + b.x + '" y="' + (b.y - 18) + '" text-anchor="middle" font-size="7" fill="' + fillFor(b.kind) + '" font-weight="700">' + b.id + '</text>';
  }

  function renderDiagram(cfg) {
    var face = cfg.locking
      ? '<circle cx="50" cy="50" r="38" fill="' + C.body + '" stroke="' + C.rim + '" stroke-width="2.4"/>' +
        '<circle cx="50" cy="50" r="30" fill="none" stroke="rgba(255,255,255,0.12)" stroke-width="1" stroke-dasharray="3 3"/>' +
        '<path d="M 50 12 L 53 18 L 47 18 Z" fill="' + C.rim + '"/>'
      : '<rect x="14" y="10" width="72" height="80" rx="10" fill="' + C.body + '" stroke="' + C.rim + '" stroke-width="2.2"/>';
    var blades = cfg.blades.map(function (b, i) { return bladeShape(b) + bladeLabel(b, i); }).join('');
    var title = cfg.name + ' receptacle, facing the device';
    return '<svg viewBox="0 0 100 100" role="img" aria-label="' + escapeAttr(title) + '">' + face + blades + '</svg>';
  }

  function escapeAttr(s) {
    return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
  }
  function escapeHtml(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function configById(id) {
    for (var i = 0; i < CONFIGS.length; i++) if (CONFIGS[i].id === id) return CONFIGS[i];
    return CONFIGS[0];
  }

  function renderPicker(activeId) {
    var host = document.getElementById('nema_picker');
    if (!host) return;
    host.innerHTML = CONFIGS.map(function (c) {
      var on = c.id === activeId ? ' aria-current="true"' : '';
      return '<button type="button" class="nema-chip' + (c.id === activeId ? ' is-active' : '') + '" data-nema-id="' + c.id + '"' + on + '>' +
        escapeHtml(c.id) + '<span>' + escapeHtml(String(c.volts) + ' V · ' + c.amps + ' A') + '</span></button>';
    }).join('');
  }

  function renderDetail(cfg) {
    var diagram = document.getElementById('nema_diagram');
    var meta = document.getElementById('nema_meta');
    var map = document.getElementById('nema_blades');
    if (diagram) diagram.innerHTML = renderDiagram(cfg);
    if (meta) {
      meta.innerHTML =
        '<div class="res-row"><span class="res-label">Configuration</span><span class="res-val">' + escapeHtml(cfg.name) + '</span></div>' +
        '<div class="res-row"><span class="res-label">Voltage</span><span class="res-val">' + escapeHtml(String(cfg.volts)) + ' V</span></div>' +
        '<div class="res-row"><span class="res-label">Ampere rating</span><span class="res-val">' + cfg.amps + ' A</span></div>' +
        '<div class="res-row"><span class="res-label">Phase / poles / wires</span><span class="res-val">' + escapeHtml(cfg.phase + ' · ' + cfg.poles + 'P ' + cfg.wires + 'W') + '</span></div>' +
        '<div class="res-row"><span class="res-label">Style</span><span class="res-val">' + (cfg.locking ? 'Locking (twist-lock)' : 'Straight blade') + '</span></div>' +
        '<p class="note" style="margin-top:10px">' + escapeHtml(cfg.summary) + ' Diagram is the receptacle face, not the plug. Confirm the device marking in the field.</p>';
      meta.classList.add('show');
    }
    if (map) {
      var rows = cfg.blades.map(function (b) {
        var codeNote = b.code === 'convention'
          ? 'Hot color is industry convention, not an NEC requirement.'
          : b.code;
        return '<tr><td>' + escapeHtml(b.id) + '</td><td>' + escapeHtml(b.role) + '</td><td>' + escapeHtml(b.color) + '</td><td>' + escapeHtml(codeNote) + '</td></tr>';
      }).join('');
      map.innerHTML = '<div class="ref-table-wrap"><table class="ref-table" aria-label="Blade to conductor map"><thead><tr><th>Blade</th><th>Conductor</th><th>Typical color</th><th>Code vs convention</th></tr></thead><tbody>' + rows + '</tbody></table></div>';
    }
  }

  function renderColors() {
    var host = document.getElementById('nema_colors');
    if (!host) return;
    host.innerHTML = COLOR_SYSTEMS.map(function (sys) {
      var rows = sys.rows.map(function (r) {
        return '<tr><td>' + escapeHtml(r.conductor) + '</td><td>' + escapeHtml(r.color) + '</td><td>' + escapeHtml(r.mandate) + '</td></tr>';
      }).join('');
      return '<div class="card"><div class="card-title">' + escapeHtml(sys.title) + '</div><div class="card-body">' +
        '<div class="ref-table-wrap"><table class="ref-table"><thead><tr><th>Conductor</th><th>Typical US color</th><th>What the NEC actually says</th></tr></thead><tbody>' + rows + '</tbody></table></div></div></div>';
    }).join('');
  }

  function show(id) {
    var cfg = configById(id);
    renderPicker(cfg.id);
    renderDetail(cfg);
  }

  function init() {
    if (!document.getElementById('sec-nema-wiring')) return;
    renderColors();
    show('5-15');
    var picker = document.getElementById('nema_picker');
    if (picker) {
      picker.addEventListener('click', function (ev) {
        var btn = ev.target.closest('[data-nema-id]');
        if (btn) show(btn.getAttribute('data-nema-id'));
      });
    }
    if (typeof registerUrlState === 'function') {
      registerUrlState('sec-nema-wiring', 'nema-wiring', null);
    }
    if (typeof bindLastUsed === 'function') bindLastUsed('sec-nema-wiring', 'nema-wiring');
  }

  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
  }

  global.__nemaWiringTestApi = {
    CONFIGS: CONFIGS,
    COLOR_SYSTEMS: COLOR_SYSTEMS,
    configById: configById,
    renderDiagram: renderDiagram,
  };
})(typeof window !== 'undefined' ? window : globalThis);
