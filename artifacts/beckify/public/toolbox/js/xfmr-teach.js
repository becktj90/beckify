/* ============================================================================
   TRANSFORMER TEACHING MATH
   Ratio, line/phase current, connection choice, enclosure, and color notes.
   The wizard and the Ratio & current card both call this. Not a second tool.
   Design aid only — not a PE stamp. AHJ and the project spec win on colors.
   ============================================================================ */

(function (root) {
  'use strict';

  var SQRT3 = Math.sqrt(3);
  /* Open-delta bank capacity / closed three-unit bank of the same units. */
  var OPEN_DELTA_OF_CLOSED = SQRT3 / 3;

  var DISCLAIMER = 'Design aid and teaching tool. Not a PE stamp. Verify the nameplate, the equipment listing, and the NEC/NESC edition your AHJ enforces before you buy or land conductors.';

  var COLOR_DISCLAIMER = 'Common North American practice. The AHJ and the project specification win. White or gray identifies a grounded conductor (NEC 200.6). Green, green with a yellow stripe, or bare identifies an equipment grounding conductor (NEC 250.119). Other hot colors are convention, except the high-leg orange rule in NEC 110.15.';

  function phasesOf(phases) {
    return phases === 1 || phases === '1' || phases === '1ph' ? 1 : 3;
  }

  function lineCurrent(kva, volts, phases) {
    if (!(kva > 0) || !(volts > 0)) return NaN;
    return phasesOf(phases) === 1
      ? (kva * 1000) / volts
      : (kva * 1000) / (SQRT3 * volts);
  }

  function turnsRatio(primaryVolts, secondaryVolts) {
    if (!(primaryVolts > 0) || !(secondaryVolts > 0)) return NaN;
    return primaryVolts / secondaryVolts;
  }

  function kvaFromCurrent(volts, amps, phases) {
    if (!(volts > 0) || !(amps > 0)) return NaN;
    return phasesOf(phases) === 1
      ? (volts * amps) / 1000
      : (SQRT3 * volts * amps) / 1000;
  }

  /**
   * Infinite-bus symmetrical fault current from nameplate percent impedance.
   * Ignores cable, bus, and utility impedance. Not a coordination study.
   */
  function faultCurrent(kva, volts, percentZ, phases) {
    if (!(kva > 0) || !(volts > 0) || !(percentZ > 0)) return null;
    var baseAmps = lineCurrent(kva, volts, phases);
    var z = percentZ / 100;
    return {
      baseAmps: baseAmps,
      symmetricalAmps: baseAmps / z,
      note: 'Infinite-bus estimate: Isc = Ibase / (%Z / 100). Conductor, bus, and utility impedance are ignored. Not a coordination study and not an inrush calculation.',
    };
  }

  function phaseVolts(kind, lineVolts) {
    if (kind === 'wye') return lineVolts / SQRT3;
    return lineVolts;
  }

  function phaseAmps(kind, lineAmps) {
    if (kind === 'delta' || kind === 'high-leg' || kind === 'corner') return lineAmps / SQRT3;
    if (kind === 'open-delta') return lineAmps;
    return lineAmps;
  }

  var ALIASES = {
    '1ph': 'isolation',
    highleg: 'high-leg',
    'high-leg-delta': 'high-leg',
    corner: 'corner-grounded',
  };

  function resolveId(id) {
    if (!id) return '';
    return ALIASES[id] || id;
  }

  var CONNECTIONS = [
    {
      id: 'isolation',
      name: 'Single-phase isolation',
      phases: 1,
      priKind: 'single',
      secKind: 'single',
      priConn: '1ph',
      secConn: '1ph',
      wireCount: 2,
      isolated: true,
      kvaBasis: 'throughput',
      phaseShift: 'n/a',
      why: 'Two separate windings. Use it when the secondary must be its own system: control power, a new neutral bond, or a break in a ground loop. The nameplate kVA is the power the windings actually transform.',
      when: 'Lighting panels, HVAC control, 480-to-240 or 240-to-120 step-down, and any load that must not share a metallic path with the primary.',
      avoid: 'Do not use an isolation transformer when you only need a few percent of voltage change. That job is a buck-boost, and it is smaller because most of the power is conducted, not transformed.',
      grounding: 'If you bond the secondary neutral, the transformer is a separately derived system and needs a grounding electrode conductor at that bond.',
      hazards: [],
      nec: 'NEC 250.30 when the secondary is separately derived. 450.3(B) still sizes the overcurrent device.',
      typical: '240 V to 120 V control, or 480 V to 240/120 V.',
    },
    {
      id: 'autotransformer',
      name: 'Autotransformer',
      phases: 'both',
      priKind: 'auto',
      secKind: 'auto',
      priConn: '1ph',
      secConn: '1ph',
      wireCount: 3,
      isolated: false,
      kvaBasis: 'throughput',
      phaseShift: '0°',
      why: 'One winding with a tap. The series section only transforms the voltage difference, so a small unit can pass a larger load. Use it for a real step up or step down when you do not need isolation.',
      when: 'Motor starting taps, a 240-to-208 trim that is more than a buck-boost catalog unit, or a three-phase auto bank when the utility and the load can share a conductor.',
      avoid: 'Not isolation. A ground fault or a surge on one side is on the other side too. Do not use it to derive a new grounded system.',
      grounding: 'The primary and secondary share a conductor, so this is generally not a separately derived system. Do not add a second neutral-ground bond.',
      hazards: ['No galvanic isolation. Do not bond both sides to ground as if they were two systems.'],
      nec: 'NEC 450.4 covers autotransformer overcurrent protection. Article 210.9 limits some branch-circuit uses.',
      typical: '240 V ↔ 208 V, or a reduced-voltage motor starter.',
    },
    {
      id: 'buck-boost',
      name: 'Buck-boost',
      phases: 'both',
      priKind: 'auto',
      secKind: 'auto',
      priConn: '1ph',
      secConn: '1ph',
      wireCount: 2,
      isolated: false,
      kvaBasis: 'winding',
      phaseShift: '0°',
      why: 'A small two-winding transformer connected as an autotransformer to raise or lower voltage a little (often 5–20%). The catalog kVA is the winding rating, not the load it can pass.',
      when: 'A long feeder that lands a bit low, or a 208 V supply feeding 230 V equipment. Three single-phase units make a three-phase bank.',
      avoid: 'Not an isolation transformer and not a way to create 120 V from a corner-grounded delta. If you need a new neutral, use a two-winding isolation transformer or a zig-zag.',
      grounding: 'Connected as an autotransformer, the supply and load share conductors. Do not treat the case as a new separately derived system.',
      hazards: ['The load kVA is larger than the nameplate. Read the wiring diagram on the unit — buck and boost use different jumpers.'],
      nec: 'Follow the manufacturer jumper diagram. Overcurrent still has to protect the conductors you actually install.',
      typical: '208 V boosted toward 230 V, or 240 V bucked toward 208 V.',
    },
    {
      id: 'delta-wye',
      name: 'Delta–Wye (Δ–Y)',
      phases: 3,
      priKind: 'delta',
      secKind: 'wye',
      priConn: 'delta',
      secConn: 'wye',
      wireCount: 4,
      isolated: true,
      kvaBasis: 'throughput',
      phaseShift: '30°',
      why: 'The usual step-down. The delta primary gives triplen harmonics a place to circulate so they stay off the primary lines. The wye secondary gives you a neutral.',
      when: '480 V delta to 208Y/120 V receptacles, or a higher primary to 480Y/277 V lighting. This is the connection to pick when the load needs a neutral and the primary does not.',
      avoid: 'Do not pick this when the secondary must be ungrounded, and do not call a 208Y/120 V secondary a high-leg delta.',
      grounding: 'Solidly ground the secondary neutral for a normal grounded system. That bond makes it a separately derived system.',
      hazards: [],
      nec: 'NEC 250.30 at the secondary bond. The 30° shift matters if you ever parallel another bank.',
      typical: '480 V → 208Y/120 V, or 13.8 kV → 480Y/277 V.',
    },
    {
      id: 'wye-delta',
      name: 'Wye–Delta (Y–Δ)',
      phases: 3,
      priKind: 'wye',
      secKind: 'delta',
      priConn: 'wye',
      secConn: 'delta',
      wireCount: 3,
      isolated: true,
      kvaBasis: 'throughput',
      phaseShift: '30°',
      why: 'Common step-up. The wye primary can be the grounded side (a generator or a utility neutral). The delta secondary has no neutral, which is what many motor loads want.',
      when: 'Generator step-up, or an industrial drive bus that never needs 120 V or 277 V.',
      avoid: 'Do not expect 120 V from this secondary. If you need a neutral later, add a zig-zag or a second transformer. Do not corner-ground it just to “have a ground” without reading the hazards.',
      grounding: 'Ground the primary neutral if that system requires it. The delta secondary is ungrounded until you deliberately ground it.',
      hazards: [],
      nec: 'A neutral on the delta side is not free. Derive one with a zig-zag or a center tap, on purpose.',
      typical: 'Generator step-up. Industrial motors.',
    },
    {
      id: 'delta-delta',
      name: 'Delta–Delta (Δ–Δ)',
      phases: 3,
      priKind: 'delta',
      secKind: 'delta',
      priConn: 'delta',
      secConn: 'delta',
      wireCount: 3,
      isolated: true,
      kvaBasis: 'throughput',
      phaseShift: '0°',
      why: 'No phase shift, and no neutral on either side. Motor loads that do not need 120 V. If one unit fails, the other two can run open-delta at reduced capacity.',
      when: 'Legacy industrial and mining systems, and motor-only secondaries where a neutral would be a lie.',
      avoid: 'A poor choice when the building needs receptacles or 277 V lighting. Grounding is the hard part — see corner-grounded, ungrounded, or zig-zag rather than pretending there is a neutral.',
      grounding: 'Ungrounded until you add a grounding scheme. A delta-delta nameplate does not mean corner-grounded.',
      hazards: [],
      nec: 'If a neutral is required, derive it. Do not bootleg one from a phase.',
      typical: 'Motor loads. Legacy 480 V delta.',
    },
    {
      id: 'wye-wye',
      name: 'Wye–Wye (Y–Y)',
      phases: 3,
      priKind: 'wye',
      secKind: 'wye',
      priConn: 'wye',
      secConn: 'wye',
      wireCount: 4,
      isolated: true,
      kvaBasis: 'throughput',
      phaseShift: '0°',
      why: 'Both sides have a neutral, and there is no 30° shift. That is useful on some utility ties. It is a bad default in a building.',
      when: 'A utility or substation transformer that already has a delta tertiary, or a specification that requires zero phase shift and neutrals on both sides.',
      avoid: 'Without a delta tertiary, triplen harmonics and neutral instability show up on both systems. Do not specify Y–Y alone for an office step-down.',
      grounding: 'Both neutrals can be grounded. The tertiary, if you have one, is what keeps the harmonics honest.',
      hazards: ['Third harmonics have no delta path unless a tertiary winding is present.'],
      nec: 'NEC 250.30 still applies to a separately derived secondary. The tertiary is a design requirement, not a code footnote you can skip.',
      typical: 'Utility transmission with a delta tertiary.',
    },
    {
      id: 'open-delta',
      name: 'Open delta (V–V)',
      phases: 3,
      priKind: 'open-delta',
      secKind: 'open-delta',
      priConn: 'delta',
      secConn: 'delta',
      wireCount: 3,
      isolated: true,
      kvaBasis: 'throughput',
      phaseShift: '0°',
      why: 'Two transformers do the job of three, at a cost. Capacity is 57.7% of a closed bank built from three of the same units. Each unit carries line current, not line current over √3.',
      when: 'One unit of a delta bank has failed and the plant must stay up, or a small three-phase load where a third unit is not justified.',
      avoid: 'Not a permanent substitute for a full bank on a growing load. Voltage balance is worse, and there is still no neutral.',
      grounding: 'Same grounding problem as a closed delta. Open delta does not create a neutral.',
      hazards: ['Each remaining unit carries full line current. Do not size the units as if they were still in a closed bank.'],
      nec: 'Protect the conductors for the current they carry now, not for the current the missing unit used to share.',
      typical: 'Emergency operation after a failed unit. Small three-phase loads.',
    },
    {
      id: 'zigzag',
      name: 'Zig-zag grounding',
      phases: 3,
      priKind: 'zigzag',
      secKind: 'zigzag',
      priConn: 'wye',
      secConn: 'wye',
      wireCount: 4,
      isolated: false,
      kvaBasis: 'throughput',
      phaseShift: 'n/a',
      groundingOnly: true,
      why: 'A grounding transformer. It derives a neutral on a delta (or an ungrounded system) so you can detect or clear ground faults. It does not step voltage down for a power panel.',
      when: 'An existing delta has no neutral and you need a ground reference or a neutral for ground-fault relaying, not for a 120 V receptacle.',
      avoid: 'Do not load it like a power transformer. Do not confuse it with a high-leg center tap, which really does make 120 V.',
      grounding: 'The zig-zag neutral is the point you ground or connect through a resistor. Continuous neutral amps come from the nameplate, not from a 120 V load calc.',
      hazards: ['Not a step-down. A kVA rating here is a grounding rating, often short-time.'],
      nec: 'Used with 250.30 or with ground-fault detection, depending on whether the system is separately derived. Confirm the one-line.',
      typical: 'Neutral derivation on a 480 V delta.',
    },
    {
      id: 'high-leg',
      name: 'High-leg delta (center-tapped)',
      phases: 3,
      priKind: 'delta',
      secKind: 'high-leg',
      priConn: 'delta',
      secConn: 'wye',
      wireCount: 4,
      isolated: true,
      kvaBasis: 'throughput',
      phaseShift: '0°',
      why: 'A delta secondary with a center tap on one winding. That tap is the neutral: 120 V to the two ends of that winding, and about 208 V from the opposite corner (the high leg, wild leg, stinger) to the neutral. It feeds 240 V three-phase and 120 V single-phase from one bank.',
      when: 'Older US commercial buildings that already are 240/120 V four-wire delta. New work usually wants 208Y/120 V instead.',
      avoid: 'Not a corner-grounded delta. The center tap is a neutral. The high leg is not grounded. Do not land 120 V loads on the high leg.',
      grounding: 'Ground the center tap, not a corner. The high leg stays an ungrounded conductor and must be identified.',
      hazards: [
        'High leg to neutral is line voltage × √3/2 (about 208 V on a 240 V system). A 120 V ballast or receptacle on that leg fails.',
        'Identify the high leg orange or by another effective means (NEC 110.15). In a panelboard it is the B phase where that edition requires it.',
        'Orange on a 480Y/277 V system is a different convention. Do not treat that orange as a high leg, and do not treat this high leg as a 480 V brown/orange/yellow phase.',
      ],
      nec: 'NEC 110.15 and the service and panelboard rules for which phase the high leg occupies. Confirm the edition the AHJ enforces.',
      typical: '240/120 V four-wire delta.',
    },
    {
      id: 'corner-grounded',
      name: 'Corner-grounded delta',
      phases: 3,
      priKind: 'delta',
      secKind: 'corner',
      priConn: 'delta',
      secConn: 'delta',
      wireCount: 3,
      isolated: true,
      kvaBasis: 'throughput',
      phaseShift: '0°',
      why: 'One phase conductor is intentionally grounded so a delta system has a ground reference and a ground fault becomes a high current the breaker can see. There is no neutral and no 120 V.',
      when: 'An existing 480 V or 240 V delta, usually motors only, where the owner already runs it corner-grounded and the gear is listed for it.',
      avoid: 'Do not choose this for a new building that needs receptacles or lighting at 120 V or 277 V. Do not “upgrade” it to a high-leg by moving the ground to a corner of a center-tapped bank, or the other way around.',
      grounding: 'The grounded phase is a grounded conductor. It carries load current. It is not an equipment grounding conductor.',
      hazards: [
        'The grounded phase sits at 0 V to ground and still carries load current. Mark it white or gray. Do not mark it green, and do not mark it orange.',
        'The other two phases are full line-to-line voltage to ground. A 480 V corner-grounded system is 480 V to the enclosure, not 277 V.',
        'A ground fault on an ungrounded phase is a phase-to-phase fault. Many drives and GFCI devices assume a wye.',
        'This is not a high-leg system. There is no wild leg and no 120 V neutral.',
      ],
      nec: 'The grounded conductor follows the identification rules for grounded conductors. Overcurrent in that conductor is restricted; motor circuits have a specific allowance. Read the section that matches the circuit, and the listing on the breaker.',
      typical: 'Legacy 480 V delta motor systems.',
    },
    {
      id: 'ungrounded-delta',
      name: 'Ungrounded delta',
      phases: 3,
      priKind: 'delta',
      secKind: 'delta',
      priConn: 'delta',
      secConn: 'delta',
      wireCount: 3,
      isolated: true,
      kvaBasis: 'throughput',
      phaseShift: '0°',
      why: 'No intentional ground on the phases. The first ground fault does not trip; it only charges the system capacitance. A detector (lights or a relay) is what tells you. The second fault is phase-to-phase.',
      when: 'A process that must ride through the first ground fault, and only where someone will actually answer the alarm.',
      avoid: 'Not the same as corner-grounded. Nothing is bolted to ground. Do not omit the detector. Do not add 120 V loads.',
      grounding: 'No grounded phase and no neutral. The equipment grounding conductor still exists so metal is bonded. It does not ground a phase.',
      hazards: [
        'The second ground fault is a line-to-line fault, often in a place you did not expect.',
        'Phase-to-ground voltage can float above line-to-neutral expectations. Do not use wye-rated gear blindly.',
      ],
      nec: 'Ground-fault detection is part of the design, not an accessory you add later if the budget survives.',
      typical: 'Older process plants. Some drive secondaries with a separate grounding scheme.',
    },
    {
      id: 'grounded-wye',
      name: 'Solidly grounded wye',
      phases: 3,
      priKind: 'delta',
      secKind: 'wye',
      priConn: 'delta',
      secConn: 'wye',
      wireCount: 4,
      isolated: true,
      kvaBasis: 'throughput',
      phaseShift: '30°',
      why: 'The usual building secondary. Phase-to-ground is line voltage / √3, so 480Y/277 V is 277 V to ground and 208Y/120 V is 120 V to ground. Ground faults are high current and the breaker clears them. You get a real neutral.',
      when: 'Almost every new 208Y/120 V or 480Y/277 V panel. The hardware is usually a delta-wye transformer. This card is the grounding scheme, not a different product.',
      avoid: 'Do not solidly ground a wye and also serve the panel as if it were high-leg or corner-grounded. One system, one scheme.',
      grounding: 'One neutral-ground bond at the source of the separately derived system. Extra bonds downstream put neutral current on the equipment ground.',
      hazards: [],
      nec: 'NEC 250.30 for the bond and the grounding electrode conductor. Neutral and equipment ground are different conductors.',
      typical: '208Y/120 V and 480Y/277 V distribution.',
    },
    {
      id: 'resistance-ground',
      name: 'Resistance grounding (note)',
      phases: 3,
      priKind: 'wye',
      secKind: 'wye',
      priConn: 'wye',
      secConn: 'wye',
      wireCount: 4,
      isolated: true,
      kvaBasis: 'throughput',
      phaseShift: 'n/a',
      groundingOnly: true,
      computesOhms: false,
      why: 'The neutral still exists, but a resistor stands between neutral and ground. Low-resistance grounding limits the fault to a current a relay can trip on, often on medium-voltage systems, and reduces the damage of a solid fault. High-resistance grounding limits the first fault to a few amps and alarms, so the process stays up.',
      when: 'You have a study that already picked low-resistance or high-resistance, and you need to remember what that does to the loads.',
      avoid: 'High-resistance grounding cannot feed line-to-neutral loads. This screen will not invent the resistor ohms from kVA.',
      grounding: 'The resistor is the ground path. Do not bypass it with a second solid bond.',
      hazards: ['Line-to-neutral loads do not belong on a high-resistance grounded system.'],
      nec: 'High-level only. The resistor, the relay, and the time rating come from the ground-fault study and the listing.',
      typical: 'Medium-voltage low-resistance grounding. 480 V high-resistance grounding on a process bus.',
    },
    {
      id: 'reactance-ground',
      name: 'Reactance grounding (note)',
      phases: 3,
      priKind: 'wye',
      secKind: 'wye',
      priConn: 'wye',
      secConn: 'wye',
      wireCount: 4,
      isolated: true,
      kvaBasis: 'throughput',
      phaseShift: 'n/a',
      groundingOnly: true,
      computesOhms: false,
      why: 'A reactor instead of a resistor between neutral and ground. It limits ground-fault current while still allowing enough current for relaying. Some systems use it around ferroresonance. The value is a study result.',
      when: 'The one-line already says reactance grounded. Use this card to remember it is not a solid ground and not a high-leg.',
      avoid: 'Do not calculate the reactor here. kVA and voltage are not enough.',
      grounding: 'One grounding path, through the reactor. No extra solid bond.',
      hazards: [],
      nec: 'High-level only. Not a reactor design.',
      typical: 'Utility and some industrial neutrals where a study specified a reactor.',
    },
  ];

  function connectionById(id) {
    var key = resolveId(id);
    for (var i = 0; i < CONNECTIONS.length; i++) {
      if (CONNECTIONS[i].id === key) return CONNECTIONS[i];
    }
    return null;
  }

  function connectionsForPhase(phase) {
    var p = phasesOf(phase);
    return CONNECTIONS.filter(function (c) {
      return c.phases === 'both' || c.phases === p;
    });
  }

  var INTENTS = [
    { id: 'receptacles-208', connectionId: 'delta-wye', label: '480 V in, 208Y/120 V receptacles', why: 'Delta primary, wye secondary, neutral grounded. Black/red/blue is the common hot practice on that wye.' },
    { id: 'lighting-277', connectionId: 'delta-wye', label: '277 V lighting (480Y/277 V secondary)', why: 'Same delta-wye hardware, different secondary voltage. Brown/orange/yellow is common practice. Orange here is not a high leg.' },
    { id: 'motors-only', connectionId: 'delta-delta', label: 'Motors only, no neutral', why: 'Delta-delta or a wye-delta step-up. Add a grounding scheme on purpose if the delta must be referenced to ground.' },
    { id: 'legacy-240', connectionId: 'high-leg', label: 'Existing 240 V three-phase plus 120 V', why: 'High-leg (center-tapped) delta. Orange identifies the wild leg. This is not a corner ground.' },
    { id: 'ground-a-delta', connectionId: 'corner-grounded', label: 'Ground a delta, no 120 V loads', why: 'Corner-grounded delta. Full line voltage to ground on two phases. The grounded phase is white or gray, not green and not orange.' },
    { id: 'derive-neutral', connectionId: 'zigzag', label: 'Add a neutral to a delta', why: 'Zig-zag grounding transformer. It is not a power step-down and it is not a high-leg.' },
    { id: 'lost-a-unit', connectionId: 'open-delta', label: 'One delta unit failed', why: 'Open delta keeps three-phase power at 57.7% of the closed bank. Each unit carries line current.' },
    { id: 'trim-voltage', connectionId: 'buck-boost', label: 'Voltage is only a little off', why: 'Buck-boost. The nameplate is the winding kVA, not the load kVA. Not isolation.' },
    { id: 'isolate', connectionId: 'isolation', label: 'Isolation or a new grounded system', why: 'Two windings. On three-phase power, that is usually a delta-wye, not a control transformer.' },
    { id: 'step-up', connectionId: 'wye-delta', label: 'Step up, no secondary neutral', why: 'Wye-delta is the usual step-up. The delta secondary has no 120 V.' },
    { id: 'both-neutrals', connectionId: 'wye-wye', label: 'Neutral on both sides', why: 'Only with a delta tertiary. Otherwise triplen harmonics have nowhere to go.' },
    { id: 'continuity', connectionId: 'ungrounded-delta', label: 'Ride through the first ground fault', why: 'Ungrounded delta plus a detector. Not a corner ground.' },
    { id: 'limit-fault', connectionId: 'resistance-ground', label: 'Limit ground-fault current', why: 'Resistance grounding. This tool does not size the resistor. High-resistance grounding and line-to-neutral loads do not mix.' },
  ];

  function suggest(intent, phase) {
    var row = null;
    for (var i = 0; i < INTENTS.length; i++) {
      if (INTENTS[i].id === intent) row = INTENTS[i];
    }
    if (!row) return null;
    if (phasesOf(phase) === 3 && row.connectionId === 'isolation') {
      return {
        id: row.id,
        connectionId: 'delta-wye',
        label: row.label,
        why: 'Three-phase isolation for a building load is a two-winding transformer, usually delta-wye. A single-phase isolation transformer is the control-power case.',
      };
    }
    return {
      id: row.id,
      connectionId: row.connectionId,
      label: row.label,
      why: row.why,
    };
  }

  function kFactorNote(level) {
    var notes = {
      k1: 'Linear loads. K-1 is the ordinary transformer. No extra harmonic rating.',
      k4: 'Some nonlinear load (ordinary office equipment). K-4 is a common catalog step. This is not a thermal design.',
      k13: 'VFDs, a large UPS, or a dense IT room. K-13 is the usual nameplate conversation. Harmonic heating is extra eddy-current loss. A larger breaker does not fix it. The Harmonics tool estimates distortion; it does not assign a K-factor.',
      k20: 'Heavy switch-mode load. K-20 exists for that. Still use the manufacturer’s data. The Harmonics tool estimates distortion; it does not assign a K-factor.',
    };
    return notes[level] || notes.k1;
  }

  function palette480() {
    return [
      { name: 'A', colorName: 'Brown', hex: '#7c4a1e', role: 'convention' },
      { name: 'B', colorName: 'Orange', hex: '#f97316', role: 'convention' },
      { name: 'C', colorName: 'Yellow', hex: '#eab308', role: 'convention' },
    ];
  }

  function palette208() {
    return [
      { name: 'A', colorName: 'Black', hex: '#1a1a1a', role: 'convention' },
      { name: 'B', colorName: 'Red', hex: '#dc2626', role: 'convention' },
      { name: 'C', colorName: 'Blue', hex: '#2563eb', role: 'convention' },
    ];
  }

  function neutralLead() {
    return { name: 'N', colorName: 'White or gray', hex: '#f4f4f5', role: 'code' };
  }

  function egcLead() {
    return { name: 'EGC', colorName: 'Green / green-yellow / bare', hex: '#16a34a', role: 'code' };
  }

  function is480Class(volts) {
    return volts >= 360;
  }

  /**
   * Distribution color plan for the secondary.
   * schemeId matches wire-colors.js NEC_SYSTEMS when that chart applies.
   */
  function colorPlan(connectionId, secondaryVolts, primaryVolts) {
    var id = resolveId(connectionId);
    var vs = Number(secondaryVolts) || 0;
    var vp = Number(primaryVolts) || 0;
    var plan = {
      schemeId: null,
      summary: '',
      disclaimer: COLOR_DISCLAIMER,
      leads: [],
      twoSystems: '',
    };
    if (vp > 0 && vs > 0 && Math.abs(vp - vs) / vs > 0.15) {
      plan.twoSystems = 'Two nominal voltage systems: NEC 210.5(C) requires the ungrounded conductors of each system to be identified. Brown/orange/yellow for 480Y and black/red/blue for 208Y is common North American practice, not a mandated palette.';
    }

    if (id === 'high-leg') {
      plan.schemeId = '120-240-3ph-highleg';
      plan.summary = 'High leg, usually B, is orange. That identification is NEC 110.15 (or another effective means) — this orange is code, not the 480Y convention. A and C are often black and blue (convention). The center-tap neutral is white or gray. The equipment ground is green, green-yellow, or bare.';
      plan.leads = [
        { name: 'A', colorName: 'Black', hex: '#1a1a1a', role: 'convention' },
        { name: 'B high-leg', colorName: 'Orange', hex: '#f97316', role: 'code' },
        { name: 'C', colorName: 'Blue', hex: '#2563eb', role: 'convention' },
        neutralLead(),
        egcLead(),
      ];
      return plan;
    }

    if (id === 'corner-grounded') {
      var ungrounded = is480Class(vs) ? [
        { name: 'Ungrounded', colorName: 'Brown', hex: '#7c4a1e', role: 'convention' },
        { name: 'Ungrounded', colorName: 'Yellow', hex: '#eab308', role: 'convention' },
      ] : [
        { name: 'Ungrounded', colorName: 'Black', hex: '#1a1a1a', role: 'convention' },
        { name: 'Ungrounded', colorName: 'Red', hex: '#dc2626', role: 'convention' },
      ];
      plan.schemeId = null;
      plan.summary = 'The grounded phase is a grounded conductor: white or gray. It carries load current. Do not mark it green, and do not mark it orange. Orange is the high-leg rule, and a corner-grounded delta has no high leg. Leave orange unused so nobody confuses this with a wild leg or with phase B of a 480Y. The equipment ground is a separate green, green-yellow, or bare conductor.';
      plan.leads = ungrounded.concat([
        { name: 'Grounded phase', colorName: 'White or gray', hex: '#f4f4f5', role: 'code' },
        egcLead(),
      ]);
      return plan;
    }

    if (id === 'autotransformer' || id === 'buck-boost') {
      var upper = Math.max(vs, vp);
      plan.schemeId = is480Class(upper) ? '277-480-3ph' : '120-240-1ph';
      plan.summary = 'Buck-boost and other autotransformers do not invent a new color code and they do not isolate. Keep the colors of the system you already have. Under 250 V that is often black and red, or black/red/blue on a 208Y. At 480Y the common practice is brown/orange/yellow, and that orange is not a high leg. White or gray is the grounded conductor. Green is the equipment ground.';
      plan.leads = is480Class(upper)
        ? palette480().concat([neutralLead(), egcLead()])
        : [
          { name: 'L1', colorName: 'Black', hex: '#1a1a1a', role: 'convention' },
          { name: 'L2', colorName: 'Red', hex: '#dc2626', role: 'convention' },
          neutralLead(),
          egcLead(),
        ];
      return plan;
    }

    if (id === 'isolation' || (connectionById(id) && connectionById(id).phases === 1)) {
      plan.schemeId = '120-240-1ph';
      plan.summary = 'Single-phase practice: black and red for the ungrounded conductors (convention), white or gray for the grounded conductor, green for the equipment ground.';
      plan.leads = [
        { name: 'L1', colorName: 'Black', hex: '#1a1a1a', role: 'convention' },
        { name: 'L2', colorName: 'Red', hex: '#dc2626', role: 'convention' },
        neutralLead(),
        egcLead(),
      ];
      return plan;
    }

    var conn = connectionById(id);
    var hasNeutral = conn && (conn.secKind === 'wye' || conn.secKind === 'high-leg' || conn.wireCount === 4) && id !== 'corner-grounded';
    var hot = is480Class(vs) ? palette480() : palette208();

    if (id === 'ungrounded-delta' || id === 'delta-delta' || id === 'open-delta' || id === 'wye-delta') {
      plan.schemeId = null;
      plan.summary = is480Class(vs)
        ? 'No neutral. Hot colors are convention. On a 480 V delta, brown/orange/yellow is common so the feeders are not mistaken for 208 V black/red/blue. That orange is not a high leg. Do not land a white conductor on a phase. Equipment ground stays green.'
        : 'No neutral. Black/red/blue is common practice for the ungrounded phases under 250 V. Do not identify a phase as white. Equipment ground stays green.';
      plan.leads = hot.concat([egcLead()]);
      return plan;
    }

    if (hasNeutral || id === 'grounded-wye' || id === 'delta-wye' || id === 'wye-wye' || id === 'zigzag' || id === 'resistance-ground' || id === 'reactance-ground') {
      plan.schemeId = is480Class(vs) ? '277-480-3ph' : '120-208-3ph';
      plan.summary = is480Class(vs)
        ? '480Y/277 V practice: brown, orange, yellow on the phases. Those hot colors are convention, not code. Orange on this system is not the high-leg rule. Gray is often used on the 277 V neutral so it is not mistaken for a 120 V white; white or gray both satisfy the grounded-conductor rule. Equipment ground is green.'
        : '208Y/120 V practice: black, red, blue on the phases (convention), white or gray neutral, green equipment ground.';
      if (id === 'zigzag') {
        plan.summary += ' The zig-zag neutral is a grounding neutral, not a license to hang 120 V receptacles on it unless the unit is listed and sized for that current.';
      }
      plan.leads = hot.concat([neutralLead(), egcLead()]);
      return plan;
    }

    plan.summary = 'Identify the grounded conductor white or gray and the equipment ground green. Hot colors follow the site standard.';
    plan.leads = hot.concat([egcLead()]);
    return plan;
  }

  function placement(construction, environment) {
    var env = environment || 'indoor';
    var table = {
      'dry-vent': {
        indoor: { nema: '1', ip: 'IP20 (approx.)', note: 'Ventilated dry-type in a clean electrical room. NEMA 1 keeps out casual contact and light dirt. It is not rainproof. Do not enclose a ventilated core in a sealed Type 4 box and expect the same temperature rise.' },
        industrial: { nema: '12', ip: 'IP54 (approx.)', note: 'Dust and dripping liquids want NEMA 12, not NEMA 1. A ventilated AA unit may be the wrong product in that room. Use it only if the manufacturer lists that enclosure with that cooling class. Otherwise look at encapsulated or a listed outdoor-rated unit indoors.' },
        outdoor: { nema: '3R', ip: 'IP32 (approx. for 3R)', note: 'A standard ventilated dry-type is an indoor machine. Outdoor placement needs a listed NEMA 3R (rain) or NEMA 3 (rain and dust) enclosure, or a different transformer. NEMA 3R does not claim dust-tightness.' },
        coastal: { nema: '3X or 4X', ip: 'IP54 to IP66 (approx.)', note: 'Salt and chemicals. NEMA 3R is not the corrosion-resistant type. 3X or 4X is the conversation, and only if that transformer is listed in that enclosure.' },
        washdown: { nema: '4X', ip: 'IP66 (approx.)', note: 'Hose-down. Ventilated dry-type generally cannot take it. Cast coil or a listed 4X enclosure is the path. NEMA and IP are not interchangeable — check both charts.' },
      },
      'dry-encap': {
        indoor: { nema: '1 or 12', ip: 'IP20 to IP54 (approx.)', note: 'Encapsulated or cast coil tolerates moisture and dust better than a ventilated core. Indoor commercial is still often NEMA 1 or 12. Confirm the nameplate enclosure, not the resin alone.' },
        industrial: { nema: '12 or 4', ip: 'IP54 to IP66 (approx.)', note: 'Dust, dripping liquid, or washdown spray. Match the listing. The resin is not a substitute for a NEMA 4 gasket if the leads are open.' },
        outdoor: { nema: '3R', ip: 'IP32 (approx. for 3R)', note: 'Many encapsulated units are listed NEMA 3R for rain. Windblown dust is NEMA 3, not 3R. Read the listing.' },
        coastal: { nema: '3X or 4X', ip: 'IP54 to IP66 (approx.)', note: 'Ask for the corrosion-resistant enclosure. A painted 3R cabinet is not 4X.' },
        washdown: { nema: '4X', ip: 'IP66 (approx.)', note: 'Only with a listed watertight enclosure. Do not assume the cast coil seals the terminals.' },
      },
      'liquid-mineral': {
        indoor: { nema: 'vault / listed compartment', ip: 'not a NEMA 1 dry-type', note: 'Mineral oil indoors is a vault or a listed fire-rated room conversation (see the type note on NEC 450), not a NEMA 1 electrical-room dry-type. The tank is not a NEMA 1 box.' },
        industrial: { nema: '3R compartment if outdoors-style', ip: 'IP32 (approx. if 3R)', note: 'Termination compartments on pad-mount gear are commonly NEMA 3R. The oil tank still needs containment. This is not a thermal design.' },
        outdoor: { nema: '3R', ip: 'IP32 (approx. for 3R)', note: 'The usual place for mineral oil is outdoors: pad-mount or substation. Weatherproof the terminations (commonly 3R). Provide oil containment. Do not call the tank NEMA 1.' },
        coastal: { nema: '3X or 4X on the compartment', ip: 'IP54 to IP66 (approx.)', note: 'Coastal hardware wants a corrosion-resistant compartment. The oil is a separate fire and spill problem.' },
        washdown: { nema: '4X if listed', ip: 'IP66 (approx.)', note: 'Hose-down and mineral oil are a poor pair. If the compartment must be 4X, it has to be listed that way. Prefer not to put an oil tank in a washdown room.' },
      },
      'liquid-fr3': {
        indoor: { nema: '1 or 3R compartment', ip: 'IP20 to IP32 (approx.)', note: 'Less-flammable liquid can be an indoor option where the listing and NEC 450.23 allow it. The compartment still follows the room: NEMA 1 in a clean room, not a pretend NEMA 4. Containment still applies.' },
        industrial: { nema: '12 or 3R', ip: 'IP54 or IP32 (approx.)', note: 'Match the room. The fluid rating does not rate the box.' },
        outdoor: { nema: '3R', ip: 'IP32 (approx. for 3R)', note: 'Outdoor pad or substation, rain-resistant terminations. Ester fluid does not remove the need for a listed enclosure.' },
        coastal: { nema: '3X or 4X', ip: 'IP54 to IP66 (approx.)', note: 'Corrosion-resistant compartment. Confirm the listing.' },
        washdown: { nema: '4X if listed', ip: 'IP66 (approx.)', note: 'Only with a listed watertight compartment. The fluid flash point is not an enclosure rating.' },
      },
    };
    var row = table[construction] || table['dry-vent'];
    return row[env] || row.indoor;
  }

  function racewayNotes(environment, connectionId, secondaryVolts) {
    var id = resolveId(connectionId);
    var wet = environment === 'outdoor' || environment === 'coastal' || environment === 'washdown';
    var notes = {
      insulation: wet
        ? 'Wet or outdoor runs: THWN-2 or XHHW-2. A conductor marked only THHN is not a wet-location insulation.'
        : 'Indoor dry runs: THHN/THWN-2 or XHHW-2. The Conductors mode picks the AWG. This line is only the insulation family.',
      raceway: wet
        ? 'RMC, IMC, or PVC for the outdoor or wet run. LFMC for a short whip to a transformer that can vibrate. EMT is a dry-location raceway.'
        : 'EMT is the usual indoor dry raceway. Use RMC or IMC where the run can be hit. PVC where corrosion or concrete calls for it. Size the raceway in Conduit Fill — count the equipment grounding conductor too.',
      mv: 'These notes are 1000 V and below. A medium-voltage primary is the MV cable tool, not THHN in EMT.',
      extras: [],
    };
    if (id === 'corner-grounded') {
      notes.extras.push('Pull three circuit conductors plus an equipment grounding conductor. The white or gray conductor is the grounded phase, and it is current-carrying. Do not land it on the ground bar and do not use the raceway as that phase. Phase-to-ground on the other two legs is the full line-to-line voltage, so a 480 V corner-grounded system is 480 V to the enclosure. Gear has to be rated for that, not for 277 V.');
    }
    if (id === 'high-leg') {
      notes.extras.push('Four current-carrying secondary conductors (A, B, C, and the center-tap neutral) plus an equipment grounding conductor. Identify the high leg orange. Do not put 120 V loads on it. Do not reuse 480Y brown/orange/yellow as if this orange were phase B of a 480 V wye.');
    }
    if (id === 'ungrounded-delta') {
      notes.extras.push('Three phase conductors plus an equipment grounding conductor so metal is bonded. There is no white phase conductor. The equipment ground does not ground a phase.');
    }
    if (secondaryVolts > 1000) {
      notes.extras.push(notes.mv);
    }
    return notes;
  }

  function installNotes(opts) {
    opts = opts || {};
    var id = resolveId(opts.connectionId || opts.id);
    var place = placement(opts.construction || 'dry-vent', opts.environment || 'indoor');
    var race = racewayNotes(opts.environment || 'indoor', id, opts.secondaryVolts);
    var colors = colorPlan(id, opts.secondaryVolts, opts.primaryVolts);
    return {
      nema: place.nema,
      ip: place.ip,
      enclosure: place.note,
      insulation: race.insulation,
      raceway: race.raceway,
      mv: race.mv,
      extras: race.extras,
      colors: colors,
      charts: 'Enclosure types are the NEMA enclosure chart and the IP chart in this toolbox. NEMA and IP tests are not the same test. Wire colors are the Wire colors page. AHJ and the project spec win.',
    };
  }

  function autoMath(kva, vp, vs, phases, kvaIs) {
    var vHigh = Math.max(vp, vs);
    var vLow = Math.min(vp, vs);
    if (!(vHigh > vLow)) return null;
    var coRatio = (vHigh - vLow) / vHigh;
    var throughput = kvaIs === 'winding' ? kva / coRatio : kva;
    var winding = kvaIs === 'winding' ? kva : kva * coRatio;
    var iHigh = lineCurrent(throughput, vHigh, phases);
    var iLow = lineCurrent(throughput, vLow, phases);
    return {
      coRatio: coRatio,
      throughputKva: throughput,
      windingKva: winding,
      iHigh: iHigh,
      iLow: iLow,
      seriesAmps: iHigh,
      commonAmps: iLow - iHigh,
    };
  }

  function analyze(input) {
    input = input || {};
    var conn = connectionById(input.id || input.connectionId);
    if (!conn) return null;
    var kva = Number(input.kva);
    var vp = Number(input.primaryVolts != null ? input.primaryVolts : input.vp);
    var vs = Number(input.secondaryVolts != null ? input.secondaryVolts : input.vs);
    var phases = conn.phases === 1 ? 1 : 3;
    if (conn.phases === 'both') phases = phasesOf(input.phases != null ? input.phases : 3);
    var percentZ = Number(input.percentZ);
    var usable = kva > 0 && vp > 0 && (vs > 0 || conn.priKind === 'zigzag');
    var result = {
      id: conn.id,
      name: conn.name,
      phases: phases,
      lineRatio: usable ? turnsRatio(vp, vs) : NaN,
      windingRatio: NaN,
      primaryLineAmps: NaN,
      secondaryLineAmps: NaN,
      primaryPhaseVolts: NaN,
      primaryPhaseAmps: NaN,
      secondaryPhaseVolts: NaN,
      secondaryPhaseAmps: NaN,
      extra: {},
      fault: null,
      warnings: conn.hazards.slice(),
      disclaimer: DISCLAIMER,
      colors: colorPlan(conn.id, vs, vp),
      install: installNotes({
        connectionId: conn.id,
        construction: input.construction,
        environment: input.environment,
        secondaryVolts: vs,
        primaryVolts: vp,
      }),
      kFactor: kFactorNote(input.kFactor || 'k1'),
      connection: conn,
    };
    if (!usable) return result;

    if (conn.priKind === 'auto') {
      var auto = autoMath(kva, vp, vs, phases, input.kvaIs || conn.kvaBasis);
      result.extra.auto = auto;
      result.lineRatio = turnsRatio(Math.max(vp, vs), Math.min(vp, vs));
      result.windingRatio = result.lineRatio;
      result.primaryLineAmps = vp >= vs ? auto.iHigh : auto.iLow;
      result.secondaryLineAmps = vp >= vs ? auto.iLow : auto.iHigh;
      result.primaryPhaseVolts = vp;
      result.secondaryPhaseVolts = vs;
      result.primaryPhaseAmps = result.primaryLineAmps;
      result.secondaryPhaseAmps = result.secondaryLineAmps;
    } else if (conn.priKind === 'zigzag') {
      var neutralAmps = (SQRT3 * kva * 1000) / vp;
      result.extra.zigzag = {
        neutralAmps: neutralAmps,
        phaseAmps: neutralAmps / 3,
        note: 'Continuous neutral current for a zig-zag rated kVA at the system line-to-line voltage. Not a secondary load current. Short-time ratings are often higher — use the nameplate.',
      };
      result.primaryLineAmps = neutralAmps / 3;
      result.secondaryLineAmps = NaN;
      result.lineRatio = NaN;
      result.windingRatio = NaN;
      result.primaryPhaseVolts = vp / SQRT3;
      result.primaryPhaseAmps = neutralAmps / 3;
    } else {
      result.primaryLineAmps = lineCurrent(kva, vp, phases);
      result.secondaryLineAmps = lineCurrent(kva, vs, phases);
      result.primaryPhaseVolts = phaseVolts(conn.priKind === 'open-delta' ? 'delta' : (conn.priKind === 'single' ? 'single' : conn.priKind), vp);
      result.secondaryPhaseVolts = phaseVolts(conn.secKind === 'wye' ? 'wye' : 'delta', vs);
      if (conn.priKind === 'single') result.primaryPhaseVolts = vp;
      if (conn.secKind === 'single' || conn.secKind === 'high-leg' || conn.secKind === 'corner') {
        result.secondaryPhaseVolts = vs;
      }
      result.primaryPhaseAmps = phaseAmps(conn.priKind === 'single' ? 'single' : conn.priKind, result.primaryLineAmps);
      result.secondaryPhaseAmps = phaseAmps(conn.secKind === 'single' ? 'single' : conn.secKind, result.secondaryLineAmps);
      if (conn.priKind !== 'zigzag' && result.secondaryPhaseVolts > 0) {
        var priPhaseV = (conn.priKind === 'wye') ? vp / SQRT3 : vp;
        var secPhaseV = (conn.secKind === 'wye') ? vs / SQRT3 : vs;
        result.windingRatio = priPhaseV / secPhaseV;
      }
      if (conn.secKind === 'high-leg') {
        result.extra.highLeg = {
          van: vs / 2,
          vbn: vs * SQRT3 / 2,
          vcn: vs / 2,
          note: 'A and C to the center tap are half the line voltage. B, the high leg, is line voltage × √3/2 to the neutral.',
        };
      }
      if (conn.secKind === 'corner') {
        result.extra.corner = {
          groundedPhaseToGround: 0,
          ungroundedPhaseToGround: vs,
          note: 'One phase is at ground potential. The other two are full line-to-line voltage to ground. There is no line-to-neutral voltage.',
        };
      }
      if (conn.priKind === 'open-delta') {
        result.extra.openDelta = {
          capacityOfClosed: OPEN_DELTA_OF_CLOSED,
          closedBankKva: kva / OPEN_DELTA_OF_CLOSED,
          unitCurrent: result.secondaryLineAmps,
          note: 'Bank kVA here is the open-delta rating. A closed bank of three equal units would be this kVA divided by √3/3. Each unit carries line current.',
        };
      }
    }

    if (percentZ > 0 && conn.priKind !== 'zigzag' && conn.priKind !== 'auto') {
      result.fault = faultCurrent(kva, vs, percentZ, phases);
    } else if (percentZ > 0 && (conn.groundingOnly || conn.priKind === 'auto')) {
      result.extra.faultSkipped = 'Percent impedance on a grounding transformer or an autotransformer is not this infinite-bus power formula. Use the nameplate ohms or a study.';
    }
    if (conn.computesOhms === false) {
      result.extra.ohms = 'Resistor or reactor ohms are not computed. kVA and voltage are not a ground-fault study.';
    }
    return result;
  }

  root.XFMR_TEACH = {
    SQRT3: SQRT3,
    OPEN_DELTA_OF_CLOSED: OPEN_DELTA_OF_CLOSED,
    DISCLAIMER: DISCLAIMER,
    COLOR_DISCLAIMER: COLOR_DISCLAIMER,
    CONNECTIONS: CONNECTIONS,
    INTENTS: INTENTS,
    lineCurrent: lineCurrent,
    turnsRatio: turnsRatio,
    kvaFromCurrent: kvaFromCurrent,
    faultCurrent: faultCurrent,
    resolveId: resolveId,
    connectionById: connectionById,
    connectionsForPhase: connectionsForPhase,
    suggest: suggest,
    kFactorNote: kFactorNote,
    colorPlan: colorPlan,
    placement: placement,
    racewayNotes: racewayNotes,
    installNotes: installNotes,
    autoMath: autoMath,
    analyze: analyze,
  };
})(typeof window !== 'undefined' ? window : globalThis);
