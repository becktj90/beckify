/* ============================================================================
   CONDUIT & FITTINGS GUIDE  ·  conduit-guide.js
   ============================================================================
   Interactive reference for every NEC-listed wiring method (raceways):

     • Cross-section SVG illustrations for all 10 conduit types
     • Flexible conduit side-profile illustrations
     • Fitting-type diagrams (conduit bodies, connectors, straps)
     • Interactive selector: answer 6 questions → recommended type(s)
     • NEC article-by-article requirements & permitted/not-permitted uses
     • Air Force / Space Force / NASA special requirements
       (AFSPCMAN 91-710, AFI 32-1064, UFC 3-550-01, NASA KSC-E-165)

   All SVG is generated inline — no external images required.
   DOM manipulation uses textContent / createElement — no innerHTML for
   user-supplied values.
   ============================================================================ */

(function () {
'use strict';

/* ──────────────────────────────────────────────────────────────────────────
   DATA — one record per wiring method
   ────────────────────────────────────────────────────────────────────────── */

const CONDUIT_DATA = [
  {
    id: 'emt',
    name: 'EMT',
    fullName: 'Electrical Metallic Tubing',
    article: '358',
    material: 'Steel (galvanized) or aluminum',
    wall: 'thin',        // thin / medium / heavy / flexi
    metallic: true,
    flexible: false,
    rigid: true,
    color: '#a0aec0',    // light gray
    boreColor: '#1a202c',
    maxTradeSz: '4"',
    maxConductors: 'Table C.1',
    tempRating: '–20 °C to +75 °C (90 °C conductors permitted)',
    locations: {
      dry: true, damp: true, wet: true,
      directBury: false, concrete: false,
      hazardousC1D1: false, hazardousC1D2: false,
      hazardousC2: true, corrosive: false,
    },
    support: 'Every 10 ft; within 3 ft of each outlet box, panel, or fitting',
    supportNec: '358.30',
    permittedUses: [
      'Exposed and concealed indoor wiring',
      'In concrete (not in direct contact with earth)',
      'In damp or wet locations with listed fittings',
      'Fished in walls (existing)',
    ],
    notPermitted: [
      'Where subject to severe physical damage',
      'In direct contact with earth or fill (not listed for direct burial)',
      'In hazardous locations (Class I, Div. 1 or 2 — unless explosionproof)',
      'Where exposed to destructive corrosive agents',
    ],
    pros: [
      'Lightest metal conduit — easy to handle and bend',
      'Fastest metallic-conduit installation',
      'Lowest cost of metallic raceways',
      'Set-screw or compression fittings — no threading required',
      'Can be used as equipment grounding conductor (bonded)',
    ],
    cons: [
      'Thin wall — susceptible to crushing and mechanical damage',
      'Cannot be threaded — relies on mechanical fittings',
      'Less physical protection than RMC or IMC',
      'Galvanized version can corrode in coastal/acidic environments',
    ],
    commonUse: 'Standard commercial/industrial indoor wiring, office buildings, light manufacturing, above-grade mechanical rooms',
    fittings: 'Set-screw connectors & couplings, compression connectors & couplings, conduit bodies (LB, LL, LR, C, T), 1-hole straps, 2-hole straps, beam clamps',
    afNote: 'NOT permitted in explosive/propellant handling areas, Class I hazardous locations, launch complex (LC) structures, or within ESQD arcs. Approved for general office and support facilities.',
    afRef: 'AFSPCMAN 91-710 Vol. 3, §3; AFI 32-1064 §3; UFC 3-550-01',
    necPermitRef: '358.10',
    necNotRef: '358.12',
    svgOuter: '#94a3b8',
    svgInner: '#0f172a',
    svgLabel: '#60a5fa',
    wallFraction: 0.10,   // outer radius fraction for wall thickness (visual)
  },
  {
    id: 'imc',
    name: 'IMC',
    fullName: 'Intermediate Metal Conduit',
    article: '342',
    material: 'Steel (galvanized) — thicker than EMT, thinner than RMC',
    wall: 'medium',
    metallic: true,
    flexible: false,
    rigid: true,
    color: '#718096',
    boreColor: '#1a202c',
    maxTradeSz: '4"',
    maxConductors: 'Table C.4',
    tempRating: '–20 °C to +75 °C (90 °C conductors permitted)',
    locations: {
      dry: true, damp: true, wet: true,
      directBury: true, concrete: true,
      hazardousC1D1: true, hazardousC1D2: true,
      hazardousC2: true, corrosive: false,
    },
    support: 'Every 10 ft; within 3 ft of each termination',
    supportNec: '342.30',
    permittedUses: [
      'All atmospheric conditions and locations',
      'Direct burial in earth or concrete',
      'Hazardous locations (Class I, Div. 1 & 2; Class II)',
      'Exposed or concealed',
      'Wet locations',
    ],
    notPermitted: [
      'Where exposed to severe corrosive influences (unless protected/coated)',
    ],
    pros: [
      'Lighter than RMC — easier to install',
      'Threaded — same fittings as RMC',
      'Listed for all the same uses as RMC in most cases',
      'Good balance of strength and workability',
    ],
    cons: [
      'More expensive than EMT',
      'Requires threading tool or pre-cut lengths',
      'Heavier than EMT',
    ],
    commonUse: 'Industrial facilities, warehouses, commercial buildings, outdoor exposed runs, direct burial where RMC is cost-prohibitive',
    fittings: 'Threaded couplings, threaded locknuts, bushings, conduit bodies, compression couplings (IMC-rated), weatherproof fittings',
    afNote: 'Acceptable substitute for RMC in most Air Force/Space Force applications. Preferred over EMT for any area with potential mechanical damage or outdoor exposure.',
    afRef: 'UFC 3-550-01 §3-3; AFSPCMAN 91-710 Vol. 3',
    necPermitRef: '342.10',
    necNotRef: '342.12',
    svgOuter: '#64748b',
    svgInner: '#0f172a',
    svgLabel: '#60a5fa',
    wallFraction: 0.17,
  },
  {
    id: 'rmc',
    name: 'RMC / GRC',
    fullName: 'Rigid Metal Conduit (Galvanized Rigid Conduit)',
    article: '344',
    material: 'Steel (hot-dip galvanized), stainless steel, or aluminum',
    wall: 'heavy',
    metallic: true,
    flexible: false,
    rigid: true,
    color: '#4b5563',
    boreColor: '#0d1117',
    maxTradeSz: '6"',
    maxConductors: 'Table C.8',
    tempRating: '–20 °C to +75 °C (90 °C conductors permitted)',
    locations: {
      dry: true, damp: true, wet: true,
      directBury: true, concrete: true,
      hazardousC1D1: true, hazardousC1D2: true,
      hazardousC2: true, corrosive: true,
    },
    support: 'Every 10 ft; within 3 ft of each termination',
    supportNec: '344.30',
    permittedUses: [
      'All atmospheric conditions and locations — most universally permitted conduit',
      'Direct burial in earth',
      'Encased in concrete',
      'Hazardous locations (all classes/divisions)',
      'Severe physical damage exposure',
      'Corrosive environments (with appropriate material selection)',
      'Coastal and marine environments (galvanized or stainless)',
      'Launch complex structures',
    ],
    notPermitted: [
      'Where severe corrosive conditions exist — unless protective coating or stainless steel used',
    ],
    pros: [
      'Maximum physical protection — thick wall withstands impact',
      'Threaded joints provide strongest mechanical connection',
      'Listed for every NEC application — no location restrictions',
      'Can be used as EGC',
      'Longest runs possible without excessive support',
    ],
    cons: [
      'Heaviest and most difficult to install',
      'Requires threading equipment',
      'Most expensive metallic conduit',
      'More labor-intensive bending',
    ],
    commonUse: 'Industrial, petrochemical, launch complexes, hazardous locations, outdoor exposed, underground direct burial, any area with severe physical damage concern',
    fittings: 'Threaded couplings (tapered NPT thread), unions, threaded conduit bodies, Myers hubs, weatherproof hubs, explosion-proof fittings',
    afNote: 'REQUIRED in: launch complex structures, explosive/propellant handling areas, Class I Div. 1 locations, within ESQD arcs, all outdoor exposed runs in operational facilities. Stainless steel RMC required in propellant and corrosive environments. This is the baseline conduit type for all Air Force/Space Force mission-critical wiring.',
    afRef: 'AFSPCMAN 91-710 Vol. 3 §3-2; AFI 32-1064 §3-1; UFC 3-550-01 §3-2; NASA KSC-E-165 §4.2',
    necPermitRef: '344.10',
    necNotRef: '344.12',
    svgOuter: '#374151',
    svgInner: '#0d1117',
    svgLabel: '#f59e0b',
    wallFraction: 0.22,
  },
  {
    id: 'fmc',
    name: 'FMC',
    fullName: 'Flexible Metal Conduit ("Greenfield")',
    article: '348',
    material: 'Interlocked aluminum or steel strip (spiral armor)',
    wall: 'flexi',
    metallic: true,
    flexible: true,
    rigid: false,
    color: '#6b7280',
    boreColor: '#1a202c',
    maxTradeSz: '4"',
    maxConductors: 'Table C.3',
    tempRating: '–20 °C to +60 °C',
    locations: {
      dry: true, damp: false, wet: false,
      directBury: false, concrete: false,
      hazardousC1D1: false, hazardousC1D2: false,
      hazardousC2: false, corrosive: false,
    },
    support: 'Every 4.5 ft; within 12 in of each outlet box; max 3 ft for horizontal whips to equipment',
    supportNec: '348.30',
    permittedUses: [
      'Dry locations',
      'Connection to motors, transformers, and equipment subject to vibration (whips)',
      'Accessible attic and ceiling spaces (with support requirements)',
      'Where flexibility is needed for installation',
    ],
    notPermitted: [
      'Wet or damp locations (unless specifically listed)',
      'Direct burial',
      'Concrete encasement',
      'Hazardous locations (unless listed for that use)',
      'Where subject to physical damage',
      'Lengths over 6 ft for equipment connection (without anchor/clamp)',
    ],
    pros: [
      'Easy to route around obstacles and through tight spaces',
      'Isolates vibration — ideal for motor connections',
      'No bending tools required',
    ],
    cons: [
      'Not listed for wet/outdoor locations',
      'Weaker than rigid conduit — not for general wiring',
      'EGC typically required inside (FMC not always listed as EGC — see 348.60)',
      'Limited to short whip lengths',
    ],
    commonUse: 'Motor/equipment connection whips (HVAC, pumps, compressors), transformer secondary connections, final connections to vibrating equipment',
    fittings: 'FMC connectors (screw-in or squeeze), FMC 90° and 45° connectors, angle fittings',
    afNote: 'Permitted for equipment whip connections only (≤ 6 ft). Not permitted as general wiring method in mission-critical or hazardous areas. Verify EGC is provided inside.',
    afRef: 'UFC 3-550-01 §3-5; AFI 32-1064',
    necPermitRef: '348.10',
    necNotRef: '348.12',
    svgOuter: '#4b5563',
    svgInner: '#111827',
    svgLabel: '#a3e635',
    wallFraction: 0.14,
    isFlexible: true,
  },
  {
    id: 'lfmc',
    name: 'LFMC',
    fullName: 'Liquidtight Flexible Metal Conduit ("Sealtite")',
    article: '350',
    material: 'Interlocked metal spiral core with PVC or thermoplastic jacket',
    wall: 'flexi',
    metallic: true,
    flexible: true,
    rigid: false,
    color: '#78716c',
    boreColor: '#1a202c',
    maxTradeSz: '4"',
    maxConductors: 'Table C.7',
    tempRating: '–40 °C to +60 °C (higher-rated types available)',
    locations: {
      dry: true, damp: true, wet: true,
      directBury: false, concrete: false,
      hazardousC1D1: false, hazardousC1D2: true,
      hazardousC2: true, corrosive: false,
    },
    support: 'Every 4.5 ft; within 12 in of each termination',
    supportNec: '350.30',
    permittedUses: [
      'Outdoor and wet locations',
      'Where flexibility, vibration isolation, and moisture resistance are needed',
      'Class I, Div. 2 and Class II hazardous locations (when listed)',
      'Motor and equipment connections in damp/wet environments',
    ],
    notPermitted: [
      'Direct burial (unless listed for that use)',
      'Concrete encasement',
      'Class I, Div. 1 hazardous locations',
      'Where subject to physical damage',
      'Exceeds 6 ft for equipment whips',
    ],
    pros: [
      'Weatherproof — suitable for outdoor installations',
      'Vibration isolation like FMC',
      'Chemical and oil-resistant jacket available',
      'Listed for wet and damp locations',
    ],
    cons: [
      'More expensive than FMC',
      'Limited like FMC — short whips only',
      'EGC typically required inside (see 350.60)',
    ],
    commonUse: 'Outdoor motor connections, rooftop HVAC equipment, outdoor lighting fixtures, equipment in wet process areas, outdoor pump connections',
    fittings: 'LFMC liquidtight connectors (straight and 90°), strain-relief fittings, weatherproof box connectors',
    afNote: 'Preferred over FMC for any outdoor or damp equipment connection. Required for outdoor motor whips in Air Force/Space Force facilities. Verify EGC.',
    afRef: 'UFC 3-550-01 §3-6; AFI 32-1064',
    necPermitRef: '350.10',
    necNotRef: '350.12',
    svgOuter: '#57534e',
    svgInner: '#111827',
    svgLabel: '#a3e635',
    wallFraction: 0.18,
    isFlexible: true,
    hasJacket: true,
  },
  {
    id: 'pvc40',
    name: 'PVC Sch. 40',
    fullName: 'Rigid PVC Conduit — Schedule 40 (RNC Type A)',
    article: '352',
    material: 'Polyvinyl chloride (PVC) — gray or orange',
    wall: 'thin-plastic',
    metallic: false,
    flexible: false,
    rigid: true,
    color: '#9ca3af',
    boreColor: '#1e293b',
    maxTradeSz: '6"',
    maxConductors: 'Table C.11',
    tempRating: '–20 °C to +75 °C ambient; conductor limited to 75 °C in many applications',
    locations: {
      dry: true, damp: true, wet: true,
      directBury: true, concrete: true,
      hazardousC1D1: false, hazardousC1D2: false,
      hazardousC2: false, corrosive: true,
    },
    support: 'Per Table 352.30(B) — ranges from 3 ft (1/2") to 8 ft (over 2")',
    supportNec: '352.30',
    permittedUses: [
      'Underground direct burial (in trench or concrete encasement)',
      'Wet and corrosive locations above grade',
      'Concealed in walls and ceilings',
      'Above-grade exposed in areas not subject to physical damage',
    ],
    notPermitted: [
      'Hazardous locations (unless specifically listed)',
      'Support of luminaires or other equipment',
      'Areas subject to physical damage (exposed above grade)',
      'Where ambient temperature exceeds 50 °C without derating',
      'In direct sunlight without UV-rated type',
      'Service entrance above grade (limited by 230.43)',
    ],
    pros: [
      'Corrosion-proof — ideal for direct burial and underground',
      'Lightweight and easy to work with',
      'No rust or galvanic corrosion',
      'Lower cost than metallic conduit',
      'Easy solvent-cement joints',
    ],
    cons: [
      'Cannot serve as EGC — separate grounding conductor required always',
      'Brittle at low temperatures — susceptible to impact damage when cold',
      'Thermal expansion is significant — expansion fittings required',
      'Not suitable where mechanical protection is needed above grade',
      'Flame propagation concern — not for plenum without special listing',
    ],
    commonUse: 'Underground site utilities, direct burial feeders, concrete-encased underground duct banks, chemical/corrosive areas',
    fittings: 'Solvent-cement couplings, PVC conduit bodies (LB, etc.), PVC expansion fittings, PVC adapters to metallic, bell-end adapters for direct burial',
    afNote: 'Permitted for underground use only at most AF/Space Force facilities. NOT permitted above grade in mission-critical buildings. All underground PVC runs must transition to RMC or IMC at building entries. Concrete-encased duct banks typical for site distribution.',
    afRef: 'UFC 3-550-01 §3-4; AFSPCMAN 91-710 Vol. 3 §3-5; NASA KSC-E-165 §4.3',
    necPermitRef: '352.10',
    necNotRef: '352.12',
    svgOuter: '#94a3b8',
    svgInner: '#1e293b',
    svgLabel: '#c084fc',
    wallFraction: 0.12,
    isPlastic: true,
  },
  {
    id: 'pvc80',
    name: 'PVC Sch. 80',
    fullName: 'Rigid PVC Conduit — Schedule 80 (RNC Type B — Heavy Wall)',
    article: '352',
    material: 'Polyvinyl chloride (PVC) — gray, heavier wall than Schedule 40',
    wall: 'medium-plastic',
    metallic: false,
    flexible: false,
    rigid: true,
    color: '#6b7280',
    boreColor: '#1e293b',
    maxTradeSz: '6"',
    maxConductors: 'Table C.12',
    tempRating: '–20 °C to +75 °C',
    locations: {
      dry: true, damp: true, wet: true,
      directBury: true, concrete: true,
      hazardousC1D1: false, hazardousC1D2: false,
      hazardousC2: false, corrosive: true,
    },
    support: 'Per Table 352.30(B)',
    supportNec: '352.30',
    permittedUses: [
      'All uses permitted for Schedule 40',
      'Exposed above-grade in areas with moderate physical damage potential (better than Sch. 40)',
      'Chemical process areas',
      'Exposed exterior applications with impact concern',
    ],
    notPermitted: [
      'Same as Schedule 40 — hazardous locations, high-temperature environments',
      'Cannot serve as EGC',
    ],
    pros: [
      'Thicker wall than Schedule 40 — better mechanical protection',
      'Corrosion-proof',
      'Can be used above grade where physical protection is needed',
      'Threaded ends possible (unlike Schedule 40)',
    ],
    cons: [
      'Smaller bore than Sch. 40 for same trade size — fewer conductors',
      'Higher cost than Schedule 40',
      'Still cannot serve as EGC',
    ],
    commonUse: 'Chemical plant electrical runs, marine/coastal facilities, areas with corrosive chemicals or wash-down, above-grade exposed runs in moderate-damage environments',
    fittings: 'Same as Schedule 40 — also threaded (Schedule 80 ends can be threaded)',
    afNote: 'Preferred over Sch. 40 for above-grade corrosive environment installations. Still not a substitute for RMC in hazardous or mission-critical areas.',
    afRef: 'UFC 3-550-01 §3-4',
    necPermitRef: '352.10',
    necNotRef: '352.12',
    svgOuter: '#4b5563',
    svgInner: '#1e293b',
    svgLabel: '#c084fc',
    wallFraction: 0.20,
    isPlastic: true,
  },
  {
    id: 'ent',
    name: 'ENT',
    fullName: 'Electrical Nonmetallic Tubing ("Smurf Tube")',
    article: '362',
    material: 'Corrugated PVC — blue or orange',
    wall: 'flexi-plastic',
    metallic: false,
    flexible: true,
    rigid: false,
    color: '#3b82f6',
    boreColor: '#1e293b',
    maxTradeSz: '2"',
    maxConductors: 'Table C.2',
    tempRating: '–10 °C to +60 °C',
    locations: {
      dry: true, damp: false, wet: false,
      directBury: false, concrete: true,
      hazardousC1D1: false, hazardousC1D2: false,
      hazardousC2: false, corrosive: false,
    },
    support: 'Every 3 ft; within 3 ft of each outlet box',
    supportNec: '362.30',
    permittedUses: [
      'Concealed in walls, floors, and ceilings',
      'In concrete (directly encased)',
      'Residential and light commercial (not exceeding 3 floors)',
      'Where flexibility aids rough-in installation',
    ],
    notPermitted: [
      'Exposed locations (not permitted exposed)',
      'Direct burial',
      'Wet or damp locations',
      'Hazardous locations',
      'Above 3 floors in buildings (height limitations)',
      'Over 50 °C ambient',
    ],
    pros: [
      'Fastest rough-in for residential/light commercial',
      'Bends easily by hand — no tools needed',
      'Inexpensive',
      'Blue color makes it easily visible in walls during construction',
    ],
    cons: [
      'Cannot be exposed — walls and ceilings only',
      'No EGC function — separate ground required',
      'Not suitable for most commercial/industrial work',
      'Limited to 2" max trade size',
    ],
    commonUse: 'Residential in-wall wiring, light commercial rough-in, concrete slab-embedded branch circuits, pre-wired stud walls',
    fittings: 'Snap-in connectors, ENT-to-EMT adapters, push-in couplings, box adapters',
    afNote: 'Generally NOT permitted in Air Force/Space Force facilities. Residential construction only. Never appropriate for mission-critical, industrial, or launch facility use.',
    afRef: 'UFC 3-550-01 (not listed as a permitted type for AF facilities)',
    necPermitRef: '362.10',
    necNotRef: '362.12',
    svgOuter: '#2563eb',
    svgInner: '#1e293b',
    svgLabel: '#60a5fa',
    wallFraction: 0.10,
    isFlexible: true,
    isPlastic: true,
  },
  {
    id: 'lfnc',
    name: 'LFNC',
    fullName: 'Liquidtight Flexible Nonmetallic Conduit',
    article: '356',
    material: 'Flexible PVC inner corrugated tube with smooth PVC jacket (Type FNMC-B) or Type FNMC-A (corrugated outer)',
    wall: 'flexi-plastic',
    metallic: false,
    flexible: true,
    rigid: false,
    color: '#374151',
    boreColor: '#1e293b',
    maxTradeSz: '4"',
    maxConductors: 'Table C.6',
    tempRating: '–10 °C to +60 °C',
    locations: {
      dry: true, damp: true, wet: true,
      directBury: false, concrete: false,
      hazardousC1D1: false, hazardousC1D2: false,
      hazardousC2: false, corrosive: false,
    },
    support: 'Every 3 ft; within 12 in of each termination',
    supportNec: '356.30',
    permittedUses: [
      'Outdoor and wet locations (where flexibility is needed)',
      'Where flexibility is required and LFMC is not needed',
      'Equipment whips in corrosive/chemical environments',
    ],
    notPermitted: [
      'Direct burial',
      'Concrete encasement',
      'Hazardous locations',
      'Exceeds 6 ft total length',
      'Where physical damage is likely',
    ],
    pros: [
      'Corrosion-proof — no metallic components',
      'Lighter than LFMC',
      'Cost-effective for chemical/wash-down environments',
    ],
    cons: [
      'No EGC function — separate grounding required',
      'Limited to short whips',
      'Not listed for hazardous locations',
    ],
    commonUse: 'Equipment connections in chemical process areas, corrosive environments, food processing facilities with wash-down requirements',
    fittings: 'Liquidtight nonmetallic connectors, snap-in fittings, LFNC-to-conduit adapters',
    afNote: 'Seldom used in AF/Space Force facilities. When needed for corrosive environment equipment whips, verify EGC is provided inside.',
    afRef: 'UFC 3-550-01',
    necPermitRef: '356.10',
    necNotRef: '356.12',
    svgOuter: '#1f2937',
    svgInner: '#0f172a',
    svgLabel: '#6ee7b7',
    wallFraction: 0.16,
    isFlexible: true,
    isPlastic: true,
  },
  {
    id: 'hdpe',
    name: 'HDPE',
    fullName: 'High-Density Polyethylene Conduit (Type RTRC/HDPE)',
    article: '353',
    material: 'High-density polyethylene (HDPE) — black, orange, or yellow',
    wall: 'medium-plastic',
    metallic: false,
    flexible: false,
    rigid: true,
    color: '#1f2937',
    boreColor: '#0f172a',
    maxTradeSz: '6"',
    maxConductors: 'Per manufacturer listing',
    tempRating: '–40 °C to +75 °C (excellent cold-weather performance)',
    locations: {
      dry: false, damp: true, wet: true,
      directBury: true, concrete: true,
      hazardousC1D1: false, hazardousC1D2: false,
      hazardousC2: false, corrosive: true,
    },
    support: 'Per manufacturer listing; typically used as direct-burial duct bank',
    supportNec: '353.30',
    permittedUses: [
      'Direct burial underground',
      'Concrete-encased duct banks',
      'High-water-table or coastal underground installations',
      'Corrosive soil environments',
    ],
    notPermitted: [
      'Above grade or exposed',
      'Hazardous locations',
      'Where temperature exceeds rating',
    ],
    pros: [
      'Excellent for direct burial in corrosive soils',
      'Resistant to most acids, alkalis, and solvents',
      'Very low friction — long cable pulls',
      'HDPE duct banks have long service life',
      'Common for telecom and medium-voltage cable duct banks',
    ],
    cons: [
      'Above-grade use not permitted',
      'Requires heat-fusion or mechanical joints',
      'Cannot serve as EGC',
      'Limited toolbox of fittings vs. PVC',
    ],
    commonUse: 'Telecom underground, utility site distribution, site medium-voltage duct banks, industrial plant underground networks',
    fittings: 'Heat-fusion couplings, mechanical couplings, bell-end adapters, pull boxes',
    afNote: 'Used for underground site utility duct banks at AF/Space Force installations. Transition to RMC required at building entry. Typical for medium-voltage underground cable systems. Coordinate with civil/utility engineers.',
    afRef: 'UFC 3-550-01 §3-4; AFSPCMAN 91-710 Vol. 3; NASA KSC-E-165 §4.3 (site utilities)',
    necPermitRef: '353.10',
    necNotRef: '353.12',
    svgOuter: '#111827',
    svgInner: '#030712',
    svgLabel: '#fbbf24',
    wallFraction: 0.18,
    isPlastic: true,
  },
];

/* ──────────────────────────────────────────────────────────────────────────
   SVG CROSS-SECTION GENERATOR
   ────────────────────────────────────────────────────────────────────────── */

/**
 * Builds a cross-section SVG for a given conduit record.
 * Rigid types: concentric circle with proportional wall thickness.
 * Flexible types: concentric circle PLUS a side-profile corrugation view.
 */
function buildXsectionSvg(c) {
  const W = 320, H = c.isFlexible ? 260 : 180;
  const cx = W / 2;
  // Cross-section portion
  const xscy = c.isFlexible ? 90 : H / 2;
  const rOuter = c.isFlexible ? 52 : 70;
  const wallFrac = c.wallFraction || 0.14;
  const rInner = rOuter * (1 - wallFrac * 2);

  let gradient = '';
  let circles = '';
  let labels = '';

  // Determine fill styling
  const outerFill = c.svgOuter;
  const innerFill = c.svgInner;
  const labelColor = c.svgLabel;
  const bg = '#0d1117';

  // EGC indicator — separate copper wire inside for non-metallic
  const showEgcDot = !c.metallic;

  // Build gradient defs
  gradient = `<defs>
    <radialGradient id="grad-${c.id}-outer" cx="35%" cy="30%">
      <stop offset="0%" stop-color="${outerFill}" stop-opacity="0.9"/>
      <stop offset="100%" stop-color="${outerFill}" stop-opacity="0.5"/>
    </radialGradient>
    <radialGradient id="grad-${c.id}-inner" cx="40%" cy="35%">
      <stop offset="0%" stop-color="${bg}" stop-opacity="1"/>
      <stop offset="100%" stop-color="${innerFill}" stop-opacity="1"/>
    </radialGradient>
  </defs>`;

  // Outer (wall) ring
  circles += `<circle cx="${cx}" cy="${xscy}" r="${rOuter}" fill="url(#grad-${c.id}-outer)" stroke="${outerFill}" stroke-width="1.5"/>`;

  // Inner (bore) circle
  circles += `<circle cx="${cx}" cy="${xscy}" r="${rInner}" fill="url(#grad-${c.id}-inner)" stroke="${bg}" stroke-width="0.5"/>`;

  // For metallic conduit: simulate metallic luster with highlight arc
  if (c.metallic) {
    circles += `<path d="M ${cx - rOuter * 0.6},${xscy - rOuter * 0.5} A ${rOuter} ${rOuter} 0 0 1 ${cx + rOuter * 0.4},${xscy - rOuter * 0.7}" stroke="rgba(255,255,255,0.18)" stroke-width="${rOuter * 0.09}" fill="none" stroke-linecap="round"/>`;
  }

  // For plastic: add plastic sheen arc
  if (c.isPlastic) {
    circles += `<path d="M ${cx - rOuter * 0.5},${xscy - rOuter * 0.55} A ${rOuter} ${rOuter} 0 0 1 ${cx + rOuter * 0.3},${xscy - rOuter * 0.65}" stroke="rgba(255,255,255,0.10)" stroke-width="${rOuter * 0.07}" fill="none" stroke-linecap="round"/>`;
  }

  // EGC dot (separate ground wire inside non-metallic conduit)
  if (showEgcDot) {
    const dx = rInner * 0.5, dy = rInner * 0.5;
    circles += `<circle cx="${cx + dx}" cy="${xscy + dy}" r="${rOuter * 0.09}" fill="#6ee7b7" stroke="#0d1117" stroke-width="1.5"/>`;
    circles += `<text x="${cx + dx + 10}" y="${xscy + dy + 4}" fill="#6ee7b7" font-size="7" font-family="ui-monospace,monospace">EGC reqd</text>`;
  }

  // Wall dimension arrow
  const arrowY = xscy + rOuter + 16;
  circles += `<line x1="${cx - rOuter}" y1="${arrowY}" x2="${cx + rOuter}" y2="${arrowY}" stroke="${labelColor}" stroke-width="0.8" opacity="0.6"/>`;
  circles += `<line x1="${cx - rInner}" y1="${arrowY - 4}" x2="${cx - rInner}" y2="${arrowY + 4}" stroke="${labelColor}" stroke-width="0.8" opacity="0.6"/>`;
  circles += `<line x1="${cx + rInner}" y1="${arrowY - 4}" x2="${cx + rInner}" y2="${arrowY + 4}" stroke="${labelColor}" stroke-width="0.8" opacity="0.6"/>`;

  // "WALL" label
  const wallR = (rOuter - rInner);
  circles += `<text x="${cx - rOuter - 4}" y="${arrowY + 3}" fill="${labelColor}" font-size="7.5" font-family="ui-monospace,monospace" text-anchor="end" opacity="0.8">wall</text>`;

  // Labels
  labels += `<text x="${cx}" y="${H - (c.isFlexible ? 100 : 14)}" fill="${labelColor}" font-size="10" font-family="ui-monospace,monospace" text-anchor="middle" font-weight="bold">${c.name} — Cross Section</text>`;
  labels += `<text x="${cx}" y="${H - (c.isFlexible ? 88 : 3)}" fill="#64748b" font-size="8.5" font-family="ui-monospace,monospace" text-anchor="middle">${c.material.split('—')[0].trim()}</text>`;

  // For flexible types: add side-profile corrugation view below
  let flexProfile = '';
  if (c.isFlexible) {
    const profY = xscy + rOuter + 40;
    const profH = 50;
    const profW = W * 0.7;
    const profX = (W - profW) / 2;

    flexProfile += `<text x="${cx}" y="${profY - 6}" fill="${labelColor}" font-size="9" font-family="ui-monospace,monospace" text-anchor="middle" opacity="0.85">Side Profile</text>`;

    // Top and bottom envelope lines
    const env = profH / 2;
    const cenv = profH * 0.28;

    // Corrugations: draw a sinusoidal path for top & bottom
    const waves = 12;
    const waveW = profW / waves;
    let topPath = `M ${profX},${profY}`;
    let botPath = `M ${profX},${profY + profH}`;
    for (let i = 0; i <= waves; i++) {
      const px = profX + i * waveW;
      const mx = profX + (i + 0.5) * waveW;
      if (i < waves) {
        topPath += ` Q ${mx - waveW * 0.25},${profY - 7} ${mx},${profY - (i % 2 === 0 ? 8 : 2)} Q ${mx + waveW * 0.25},${profY + 3} ${px + waveW},${profY}`;
        botPath += ` Q ${mx - waveW * 0.25},${profY + profH + 7} ${mx},${profY + profH + (i % 2 === 0 ? 8 : 2)} Q ${mx + waveW * 0.25},${profY + profH - 3} ${px + waveW},${profY + profH}`;
      }
    }

    const fillColor = c.isPlastic ? c.svgOuter + '55' : 'rgba(100,116,139,0.4)';
    const strokeC = c.svgOuter;

    // Fill the profile
    flexProfile += `<path d="${topPath} L ${profX + profW},${profY + profH} ${botPath.replace('M ', 'L ')} Z" fill="${fillColor}" stroke="none"/>`;
    flexProfile += `<path d="${topPath}" fill="none" stroke="${strokeC}" stroke-width="1.5"/>`;
    flexProfile += `<path d="${botPath}" fill="none" stroke="${strokeC}" stroke-width="1.5"/>`;

    // For LFMC/LFNC: add outer jacket lines (straight)
    if (c.hasJacket) {
      flexProfile += `<line x1="${profX}" y1="${profY - 14}" x2="${profX + profW}" y2="${profY - 14}" stroke="${c.svgOuter}" stroke-width="2.5" opacity="0.7"/>`;
      flexProfile += `<line x1="${profX}" y1="${profY + profH + 14}" x2="${profX + profW}" y2="${profY + profH + 14}" stroke="${c.svgOuter}" stroke-width="2.5" opacity="0.7"/>`;
      flexProfile += `<text x="${profX + profW + 4}" y="${profY - 11}" fill="${labelColor}" font-size="8" font-family="ui-monospace,monospace">jacket</text>`;
    }

    labels += flexProfile;
  }

  return `<svg viewBox="0 0 ${W} ${H}" width="100%" xmlns="http://www.w3.org/2000/svg" aria-label="${c.fullName} cross-section diagram" role="img" style="display:block;max-width:${W}px;margin:0 auto;background:${bg};border-radius:6px">${gradient}${circles}${labels}</svg>`;
}

/* ──────────────────────────────────────────────────────────────────────────
   FITTINGS SVG
   ────────────────────────────────────────────────────────────────────────── */

/** Draws a simple conduit body shape (LB, LL, LR, C, T, X) as SVG */
function buildFittingSvg(type) {
  const W = 200, H = 120;
  const bg = '#0d1117';
  const stroke = '#8b7bff';
  const fill = '#1e1b4b';
  const textC = '#e2e8f0';
  let svg = `<svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg" style="background:${bg};border-radius:4px;display:inline-block">`;

  const cx = W / 2, cy = H / 2;
  const r = 14;  // conduit radius
  const boxW = 36, boxH = 36;

  switch (type) {
    case 'LB': {
      // Vertical entry, 90° back
      svg += `<rect x="${cx - boxW/2}" y="${cy - boxH/2}" width="${boxW}" height="${boxH}" fill="${fill}" stroke="${stroke}" stroke-width="2" rx="3"/>`;
      svg += `<rect x="${cx - r}" y="${cy - boxH/2 - 28}" width="${r*2}" height="28" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;  // top (entry)
      svg += `<rect x="${cx - boxW/2 - 28}" y="${cy - r}" width="28" height="${r*2}" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;  // left (back exit)
      svg += `<text x="${cx}" y="${H - 8}" fill="${textC}" font-size="11" text-anchor="middle" font-family="ui-monospace">LB</text>`;
      break;
    }
    case 'LL': {
      svg += `<rect x="${cx - boxW/2}" y="${cy - boxH/2}" width="${boxW}" height="${boxH}" fill="${fill}" stroke="${stroke}" stroke-width="2" rx="3"/>`;
      svg += `<rect x="${cx - r}" y="${cy - boxH/2 - 28}" width="${r*2}" height="28" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
      svg += `<rect x="${cx + boxW/2}" y="${cy - r}" width="28" height="${r*2}" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
      svg += `<text x="${cx}" y="${H - 8}" fill="${textC}" font-size="11" text-anchor="middle" font-family="ui-monospace">LL</text>`;
      break;
    }
    case 'LR': {
      svg += `<rect x="${cx - boxW/2}" y="${cy - boxH/2}" width="${boxW}" height="${boxH}" fill="${fill}" stroke="${stroke}" stroke-width="2" rx="3"/>`;
      svg += `<rect x="${cx - r}" y="${cy - boxH/2 - 28}" width="${r*2}" height="28" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
      svg += `<rect x="${cx - boxW/2 - 28}" y="${cy - r}" width="28" height="${r*2}" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
      svg += `<text x="${cx}" y="${H - 8}" fill="${textC}" font-size="11" text-anchor="middle" font-family="ui-monospace">LR</text>`;
      break;
    }
    case 'C': {
      svg += `<rect x="${cx - boxW/2}" y="${cy - boxH/2}" width="${boxW}" height="${boxH}" fill="${fill}" stroke="${stroke}" stroke-width="2" rx="3"/>`;
      svg += `<rect x="${cx - r}" y="${cy - boxH/2 - 26}" width="${r*2}" height="26" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
      svg += `<rect x="${cx - r}" y="${cy + boxH/2}" width="${r*2}" height="26" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
      svg += `<text x="${cx}" y="${H - 8}" fill="${textC}" font-size="11" text-anchor="middle" font-family="ui-monospace">C (inline)</text>`;
      break;
    }
    case 'T': {
      svg += `<rect x="${cx - boxW/2}" y="${cy - boxH/2}" width="${boxW}" height="${boxH}" fill="${fill}" stroke="${stroke}" stroke-width="2" rx="3"/>`;
      svg += `<rect x="${cx - r}" y="${cy - boxH/2 - 24}" width="${r*2}" height="24" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
      svg += `<rect x="${cx - boxW/2 - 24}" y="${cy - r}" width="24" height="${r*2}" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
      svg += `<rect x="${cx + boxW/2}" y="${cy - r}" width="24" height="${r*2}" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
      svg += `<text x="${cx}" y="${H - 8}" fill="${textC}" font-size="11" text-anchor="middle" font-family="ui-monospace">T (tee)</text>`;
      break;
    }
    case 'X': {
      svg += `<rect x="${cx - boxW/2}" y="${cy - boxH/2}" width="${boxW}" height="${boxH}" fill="${fill}" stroke="${stroke}" stroke-width="2" rx="3"/>`;
      svg += `<rect x="${cx - r}" y="${cy - boxH/2 - 22}" width="${r*2}" height="22" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
      svg += `<rect x="${cx - r}" y="${cy + boxH/2}" width="${r*2}" height="22" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
      svg += `<rect x="${cx - boxW/2 - 22}" y="${cy - r}" width="22" height="${r*2}" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
      svg += `<rect x="${cx + boxW/2}" y="${cy - r}" width="22" height="${r*2}" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
      svg += `<text x="${cx}" y="${H - 8}" fill="${textC}" font-size="11" text-anchor="middle" font-family="ui-monospace">X (cross)</text>`;
      break;
    }
  }

  svg += '</svg>';
  return svg;
}

/* ──────────────────────────────────────────────────────────────────────────
   INTERACTIVE CONDUIT SELECTOR
   ────────────────────────────────────────────────────────────────────────── */

window.runConduitSelector = function () {
  const out = document.getElementById('cg-selector-result');
  if (!out) return;
  out.textContent = '';

  const outdoor      = document.getElementById('cg_outdoor')?.value;
  const wet          = document.getElementById('cg_wet')?.value;
  const burial       = document.getElementById('cg_burial')?.value;
  const hazardous    = document.getElementById('cg_hazardous')?.value;
  const damage       = document.getElementById('cg_damage')?.value;
  const corrosive    = document.getElementById('cg_corrosive')?.value;
  const facility     = document.getElementById('cg_facility')?.value;
  const flexible     = document.getElementById('cg_flexible')?.value;

  // Score each type
  const scores = CONDUIT_DATA.map(function (c) {
    let score = 0;
    let reasons = [];
    let disqualified = false;
    let disqualReasons = [];

    // Direct burial
    if (burial === 'yes') {
      if (!c.locations.directBury && !c.locations.concrete) {
        disqualified = true;
        disqualReasons.push('Not listed for direct burial');
      } else {
        score += 2;
        reasons.push('Listed for direct burial');
      }
    }

    // Wet location
    if (wet === 'yes') {
      if (!c.locations.wet && !c.locations.damp) {
        disqualified = true;
        disqualReasons.push('Not listed for wet locations');
      } else {
        score += 1;
        reasons.push('Wet-location listed');
      }
    }

    // Hazardous location
    if (hazardous === 'c1d1') {
      if (!c.locations.hazardousC1D1) {
        disqualified = true;
        disqualReasons.push('Not permitted in Class I, Div. 1');
      } else {
        score += 3;
        reasons.push('Class I Div. 1 listed');
      }
    }
    if (hazardous === 'c1d2') {
      if (!c.locations.hazardousC1D1 && !c.locations.hazardousC1D2) {
        disqualified = true;
        disqualReasons.push('Not permitted in Class I, Div. 2');
      } else {
        score += 2;
        reasons.push('Hazardous location listed');
      }
    }

    // Physical damage
    if (damage === 'severe') {
      if (c.wall !== 'heavy' && c.wall !== 'medium') {
        score -= 2;
        reasons.push('⚠ Thin wall — not ideal for severe damage');
      } else if (c.wall === 'heavy') {
        score += 2;
        reasons.push('Heavy wall — best physical protection');
      }
      if (c.flexible) {
        disqualified = true;
        disqualReasons.push('Flexible conduit not permitted where severe damage expected');
      }
    }
    if (damage === 'moderate' && c.wall === 'heavy') {
      score += 1;
      reasons.push('Heavy wall — excellent protection');
    }

    // Corrosive
    if (corrosive === 'yes') {
      if (!c.locations.corrosive && c.metallic) {
        score -= 2;
        reasons.push('⚠ May corrode in corrosive environments — specify coated or stainless');
      } else if (!c.metallic) {
        score += 1;
        reasons.push('Non-metallic — corrosion-proof');
      }
    }

    // Outdoor (but not burial)
    if (outdoor === 'yes' && burial !== 'yes') {
      if (!c.locations.wet && !c.locations.damp) {
        score -= 1;
        reasons.push('⚠ Not listed for outdoor (wet) location');
      }
      if (c.isPlastic && damage !== 'none') {
        score -= 1;
        reasons.push('Plastic conduit exposed above grade requires special consideration');
      }
    }

    // Flexible requirement
    if (flexible === 'yes') {
      if (!c.flexible) {
        score -= 1;
        reasons.push('Rigid — flexibility not available');
      } else {
        score += 2;
        reasons.push('Flexible type — meets requirement');
      }
    } else if (flexible === 'no' && c.flexible) {
      score -= 2;
      reasons.push('Flexible type — not preferred for general wiring');
    }

    // Space Force / launch facility
    if (facility === 'launch') {
      if (c.id === 'rmc') {
        score += 4;
        reasons.push('✓ REQUIRED for launch complex structures (AFSPCMAN 91-710)');
      } else if (c.id === 'imc') {
        score += 2;
        reasons.push('✓ Acceptable for non-hazardous launch facility areas');
      } else if (c.id === 'emt') {
        disqualified = true;
        disqualReasons.push('NOT permitted in launch complexes or propellant areas (AFSPCMAN 91-710)');
      } else if (c.isPlastic) {
        if (burial === 'yes') {
          score += 1;
          reasons.push('Acceptable for underground site utilities');
        } else {
          disqualified = true;
          disqualReasons.push('Not approved for above-grade launch facility use');
        }
      }
    } else if (facility === 'af-gen') {
      if (c.id === 'rmc' || c.id === 'imc') {
        score += 1;
        reasons.push('Preferred for AF facilities (UFC 3-550-01)');
      } else if (c.id === 'ent') {
        disqualified = true;
        disqualReasons.push('Not approved for AF facility general use');
      }
    }

    // Prefer metallic for general use
    if (!c.metallic && burial !== 'yes' && facility !== 'none') {
      score -= 1;
    }

    return {
      conduit: c,
      score: score,
      reasons: reasons,
      disqualified: disqualified,
      disqualReasons: disqualReasons,
    };
  });

  // Separate qualified from disqualified
  const qualified = scores.filter(s => !s.disqualified).sort((a, b) => b.score - a.score);
  const disqualified = scores.filter(s => s.disqualified);

  // Render recommendation
  const resClass = out.className;
  out.className = 'result show';

  function addHeading(text) {
    const h = document.createElement('div');
    h.className = 'res-row';
    h.style.borderBottom = '1px solid rgba(139,123,255,0.35)';
    h.style.marginTop = '0.6rem';
    const l = document.createElement('span');
    l.className = 'res-label';
    l.style.textTransform = 'uppercase';
    l.style.letterSpacing = '0.12em';
    l.style.fontSize = '0.72em';
    l.style.color = '#8b7bff';
    l.textContent = text;
    h.appendChild(l);
    out.appendChild(h);
  }

  function addRow(label, value, color, bold) {
    const row = document.createElement('div');
    row.className = 'res-row';
    const l = document.createElement('span'); l.className = 'res-label'; l.textContent = label;
    const v = document.createElement('span'); v.className = 'res-val'; v.textContent = value;
    if (color) v.style.color = color;
    if (bold) v.style.fontWeight = '700';
    row.appendChild(l); row.appendChild(v);
    out.appendChild(row);
  }

  function addNote(text) {
    const p = document.createElement('p');
    p.style.cssText = 'margin:0.4rem 0 0;font-size:0.78em;line-height:1.5;opacity:0.75;';
    p.textContent = text;
    out.appendChild(p);
  }

  if (qualified.length === 0) {
    addHeading('No Matching Conduit Type');
    addNote('No standard conduit type meets all selected criteria simultaneously. Review requirements or select a different combination.');
    return;
  }

  addHeading('Recommended Conduit Types');
  qualified.slice(0, 3).forEach(function (s, i) {
    const colors = ['#6ee7b7', '#93c5fd', '#fde68a'];
    addRow(
      (i + 1) + '. ' + s.conduit.fullName,
      'NEC Art. ' + s.conduit.article,
      colors[i] || '#e2e8f0',
      i === 0,
    );
    s.reasons.forEach(function (r) { addNote('  · ' + r); });
  });

  addHeading('Design Notes');
  const top = qualified[0].conduit;
  addNote('Scroll to the ' + top.fullName + ' card below for full NEC requirements, permitted/not-permitted uses, and Air Force/Space Force guidance.');
  addNote('Always verify the local AHJ (Authority Having Jurisdiction) accepts the selected wiring method. Obtain AFSPCMAN 91-710 approvals for launch facility or Range Safety applications.');

  if (disqualified.length > 0) {
    addHeading('Eliminated Types');
    disqualified.forEach(function (s) {
      addRow(s.conduit.name, s.disqualReasons.join('; '), '#ff8a8a');
    });
  }
};

/* ──────────────────────────────────────────────────────────────────────────
   TAB NAVIGATION
   ────────────────────────────────────────────────────────────────────────── */

window.cgShowTab = function (tabId, groupId) {
  const group = document.getElementById(groupId);
  if (!group) return;
  group.querySelectorAll('.cg-pane').forEach(function (p) { p.style.display = 'none'; });
  group.querySelectorAll('.cg-tab-btn').forEach(function (b) { b.classList.remove('active'); });
  const pane = document.getElementById(tabId);
  if (pane) pane.style.display = '';
  const btn = group.querySelector('[data-tab="' + tabId + '"]');
  if (btn) btn.classList.add('active');
};

/* ──────────────────────────────────────────────────────────────────────────
   INITIALISATION — inject SVG cross-sections into the page
   ────────────────────────────────────────────────────────────────────────── */

document.addEventListener('DOMContentLoaded', function () {
  if (!document.getElementById('sec-conduit-guide')) return;

  // Inject SVG cross-sections into prepared placeholders.
  // NOTE: buildXsectionSvg generates SVG markup entirely from the static
  // CONDUIT_DATA constant defined in this file — no user-supplied values are
  // interpolated into the HTML, so this innerHTML assignment is safe.
  CONDUIT_DATA.forEach(function (c) {
    const el = document.getElementById('cg-xsec-' + c.id);
    if (el) el.innerHTML = buildXsectionSvg(c);
  });

  // Inject fitting body diagrams.
  // Same note as above: buildFittingSvg only interpolates static numeric
  // constants — no user input reaches these strings.
  ['LB', 'LL', 'LR', 'C', 'T', 'X'].forEach(function (t) {
    const el = document.getElementById('cg-fitting-' + t);
    if (el) el.innerHTML = buildFittingSvg(t);
  });

  // Default tab for conduit types
  const firstTab = document.querySelector('#cg-type-tabs .cg-tab-btn');
  if (firstTab) firstTab.click();

  // Default tab for fittings
  const firstFit = document.querySelector('#cg-fitting-tabs .cg-tab-btn');
  if (firstFit) firstFit.click();
});

})(); // end IIFE
