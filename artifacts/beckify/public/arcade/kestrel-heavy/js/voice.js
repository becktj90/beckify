/**
 * Launch-control voice. Phrase pools + cooldown + phase-once so the same
 * line does not loop. Variants rotate across retries. Tokens: {id} {payload} {mark}.
 */
export const LINES = {
  pad: [
    'Pier 7 standing by. Terminal count is armed.',
    'Pad is green. {id} on the mount. Range holding.',
    'Haven is on station. Pier 7 ready for {id}.',
  ],
  terminal: [
    'Pier 7 terminal count. {id} on the pad. Range is green.',
    'Terminal count. Auto-sequence running on {id}.',
    'T-minus eight. {id} is go for the count.',
  ],
  tankpress: [
    'Tank pressurization. LOX and LCH4 going flight pressure.',
    'Prop tanks coming up. Flight pressure on both sides.',
    'Pressurization complete path. Methane and LOX are live.',
  ],
  internal: [
    'Vehicle on internal power. Ground power is safed.',
    'Internal power. Umbilicals are going quiet.',
    'Stack is on its own buses. Ground power off.',
  ],
  deluge: [
    'Water deluge. Pad suppression is on.',
    'Deluge is up. Sound suppression flowing.',
    'Water on the table. Deluge confirmed.',
  ],
  ignition: [
    'Ignition. Seven core engines at startup.',
    'Startup. Chambers coming up on all seven.',
    'Ignition confirmed. Thrust is building.',
  ],
  liftoff: [
    'Liftoff. {id} clearing the tower.',
    'Liftoff. Tower clear. Pitch and roll are armed.',
    '{id} is off the pad. Vehicle is climbing.',
  ],
  maxq: [
    'Max-Q. Vehicle through the region of maximum dynamic pressure.',
    'Max-Q. q is peaking. Hold the line.',
    'Through Max-Q. Dynamic pressure is falling off.',
  ],
  meco: [
    'MECO. First-stage cores shutdown. Hold attitude for sep.',
    'MECO confirmed. Cores are out. Stand by for the sep zone.',
    'Main engine cutoff. Hold the stack. Sep zone incoming.',
  ],
  sep: [
    'Sep zone. ALIGN green, then press SEPARATE.',
    'Stage sep is a skill beat. Stay in the band, then SEPARATE.',
    'Sep zone live. Green ALIGN, then press SEPARATE.',
  ],
  'align-green': [
    'ALIGN green. Press SEPARATE.',
    'Attitude is in. Press SEPARATE.',
    'Green board. SEPARATE — pyros.',
  ],
  'align-wide': [
    'ALIGN wide. Straighten, then tap.',
    'Rates are high. Kill the side load, then tap.',
    'Not yet. Get ALIGN green first.',
  ],
  'sep-clear': [
    'Booster clear. Keep the relative motion wide of the stack.',
    'Sep confirmed. Open the gap, then Haven.',
    'Clean sep. Booster is free. Stay off the upper.',
  ],
  'sep-wide': [
    'Sep wide. Relative motion is hot. Clear the stack.',
    'Hot sep. Steer off the upper stage.',
    'Wide sep. Combo is gone — stay clear.',
  ],
  'sep-contact': [
    'Stack contact. Combo gone. Stay clear.',
    'Recontact. Get away from the upper.',
  ],
  ses1: [
    'SES-1. Upper-stage engine is lit. {payload} still coasting under the fairing.',
    'Upper is burning. {payload} rides to insertion.',
    'SES-1 nominal. Second stage is making velocity.',
  ],
  fairing: [
    'Fairing jettison. {mark} — {payload} is free of the stack.',
    'Fairing is off. {payload} sees sky.',
    '{mark} fairing jettison confirmed.',
  ],
  entry: [
    'Entry burn. Pitch over. Haven is downrange. Strakes next.',
    'Reentry. Long approach. Strakes, then glide the diagonal.',
    'Entry burn. Hold the pitch. Engines wait for the landing burn.',
  ],
  landing: [
    'Landing burn. HOLD climb. Kill sink over the paint.',
    'Landing burn. Fire engines, then straighten for the deck.',
    'Engines for the deck. Hold burn, then settle.',
  ],
  touchdown: [
    'Touchdown. BOOSTER RECOVERED. Sea state nominal.',
    'On Haven. Soft deck. Coffee earned.',
    'Deck is caught. Booster is standing.',
  ],
  seco: [
    'SECO. Upper stage shutdown. Insertion complete.',
    'SECO confirmed. {payload} is on the coast.',
    'Upper is out. Insertion looks good.',
  ],
  deploy: [
    '{payload} deploy confirmed. {id} is a good flight.',
    'Deploy. {payload} is free. {id} done.',
    'Spacecraft sep. {id} is in the book.',
  ],
  'haven-slide': [
    'Haven downrange. Pitch over, then strakes. Glide the diagonal. Do not burn yet.',
    'Haven is the barge — small on purpose. Glide, then fire the landing burn.',
    'Long approach. Hold the glide. Engines wait for the landing burn.',
  ],
  'haven-reentry': [
    'Pitch over. Reentry. Strakes stand by — do not burn yet.',
    'Reentry. Hold attitude. Aero strakes next.',
  ],
  'haven-maxq': [
    'Descent max-Q. Strakes are working. Hold the glide.',
    'Through descent max-Q. Ride the diagonal into Haven.',
  ],
  'haven-straighten': [
    'RCS — straighten for the painted deck.',
    'Straighten. Paint is the catch zone.',
    'Kill the lean. Brake over the mark.',
  ],
  'hint-ascent': [
    'Grab the cyan aero shield. Steer around birds and ice.',
    'Pickups are free hits and fuel. Do not ignore them.',
  ],
  'hint-corridor': [
    'Stay inside the corridor. Dotted rails are the bounds.',
    'Those rails are the fly-out. Drift out and the stack aborts.',
  ],
  'corridor-edge': [
    'Corridor edge. Steer back between the rails.',
    'Outside the rails is a RUD. Nudge back in.',
  ],
  'hint-pickup': [
    'Cyan aero shield, in the corridor — steer into it for one free hit.',
    'Grab the cyan shield ahead of the stack before Max-Q.',
  ],
  'hint-sep': [
    'After MECO: hold attitude. Stay in the SEP ZONE, then press SEPARATE.',
    'Sep is a press, not a hold. Wait for the band, then SEPARATE.',
  ],
  'hint-haven': [
    'Strakes out. Glide the diagonal. Do not burn until the window.',
    'Hold the glide. Fire engines for the landing burn, then straighten.',
  ],
  'haven-strakes': [
    'Strakes deployed. Aero control is live. Hold the glide.',
    'Strakes out. Ride the diagonal into Haven.',
  ],
  'haven-burn': [
    'Landing burn window. HOLD TO BURN. Keep holding and drag onto the paint.',
    'Engines wait on a hold. HOLD TO BURN, then steer the deck.',
  ],
  'haven-burn-hold': [
    'Burn hold is in. Keep holding. Drag onto the paint.',
    'Landing burn lit. Hold it and straighten for the deck.',
  ],
  'haven-burn-nag': [
    'HOLD TO BURN. A tap will not kill sink over Haven.',
    'The window is open. Hold the burn or you will splash.',
  ],
  'press-ok': [
    'Launch confirmed. Cores coming up.',
    'Tap is in. Throttle is coming up.',
  ],
  'pickup-shield': [
    'Aero shield on the stack.',
    'Shield is up. One free hit.',
  ],
  'pickup-fuel': [
    'LOX top-off. Thrust grace is back.',
    'Prop load bumped. Keep climbing.',
  ],
  'pickup-boost': [
    'Core kick. Extra thrust, short window.',
    'Overdrive. Ride it, then settle.',
  ],
  'shield-hit': [
    'Aero shield absorbed the hit.',
    'Shield took that one. Still flying.',
  ],
  'close-call': [
    'Close call. KID mode keeps you flying.',
    'That would have been RUD. KID lets it slide.',
  ],
  'struct-warn': [
    'Structural hit — integrity is down. Another hit may be RUD.',
    'Airframe is hurt. Watch the INT bar.',
  ],
  'health-graze': [
    'Grazed. Integrity holding. Fly cleaner.',
    'Hit registered. Stack is still flying.',
  ],
  'health-lethal': [
    'Integrity gone. Range safe.',
    'Structural limit. Vehicle is lost.',
  ],
  'health-scrape': [
    'Corridor scrape. Steer back inside the rails.',
    'Skinning the corridor. Integrity is dropping.',
  ],
  'fuel-low': [
    'Propellant low. Hold climb or the cores will starve.',
    'Fuel is thin. Do not coast the rest of the corridor.',
  ],
  recovered: [
    'Landed on Haven. Sea state nominal. Coffee earned.',
    'Soft catch. Booster is standing on Haven.',
  ],
  salvage: [
    'Hard catch. Booster on deck, score clipped.',
    'On the barge, but it was ugly. Score takes the hit.',
  ],
  tip: [
    'Tip on deck. Gold ring kissed steel — score clipped.',
    'Attitude was long at contact. Tip. Score clipped.',
  ],
  splash: [
    'Splash. Combo reset — upper stage still flies.',
    'In the drink. Upper stage does not care. You do.',
  ],
};

export const ABORTS = {
  corridor: {
    id: 'corridor',
    reason: 'Lost the corridor — fell back toward the pad',
    banner: 'RUD — LOST THE CORRIDOR',
    radio: [
      'No climb. Stack is falling back toward Pier 7. Range safe.',
      'Vehicle lost the loft. Pad is in the way.',
    ],
    coach: 'Hold climb through the first kilometers. Coasting off the pad is a RUD.',
  },
  fuel: {
    id: 'fuel',
    reason: 'Propellant starved — cores flamed out on the way up',
    banner: 'RUD — PROPELLANT STARVED',
    radio: [
      'Chambers are out. No propellant, no climb.',
      'Fuel hit zero. Cores flamed out. Range safe.',
    ],
    coach: 'Hold a steady climb and grab LOX pickups. An empty stack cannot fly the corridor.',
  },
  corridorEdge: {
    id: 'corridorEdge',
    reason: 'Left the flight corridor — outside the dotted rails',
    banner: 'RUD — LEFT THE CORRIDOR',
    radio: [
      'Outside the rails. Range safe.',
      'Left the corridor. Stack is lost.',
    ],
    coach: 'Stay between the dotted rails. They are the fly-out bounds, not decoration.',
  },
  hazard: {
    id: 'hazard',
    reason: 'Corridor impact — structural limit exceeded',
    banner: 'RUD — CORRIDOR IMPACT',
    radio: [
      'Structural limit exceeded. Vehicle is lost. Range safe.',
      'Impact in the corridor. Airframe is gone.',
    ],
    coach: 'Steer around birds, ice, and debris. An aero shield buys one hit.',
  },
  bird: {
    id: 'bird',
    reason: 'Bird strike in the low corridor — vehicle lost',
    banner: 'RUD — BIRD STRIKE',
    radio: [
      'Bird strike. Structural failure. Range safe.',
      'Low-corridor bird strike. Stack is gone.',
    ],
    coach: 'Early climb is busy. Steer early — birds do not move for you.',
  },
  ice: {
    id: 'ice',
    reason: 'Ice shed impact — structural limit exceeded',
    banner: 'RUD — ICE IMPACT',
    radio: [
      'Ice impact. Airframe exceeded. Range safe.',
      'Shed ice took the stack. Flight is over.',
    ],
    coach: 'Ice falls through the corridor after Max-Q. Nudge, do not freeze.',
  },
  debris: {
    id: 'debris',
    reason: 'Debris strike — vehicle lost',
    banner: 'RUD — DEBRIS STRIKE',
    radio: [
      'Debris strike. Vehicle lost. Range safe.',
      'Corridor debris. Structural fail.',
    ],
    coach: 'High corridor is junk-heavy. Give debris a wide berth.',
  },
  balloon: {
    id: 'balloon',
    reason: 'Balloon / clutter strike — vehicle lost',
    banner: 'RUD — CORRIDOR CLUTTER',
    radio: [
      'Clutter strike. Stack is gone. Range safe.',
      'Low-altitude clutter. Flight terminated.',
    ],
    coach: 'Balloons look soft. At this speed they are not. Steer around them.',
  },
  maxq: {
    id: 'maxq',
    reason: 'Max-Q structural exceedance — dynamic pressure plus impact',
    banner: 'RUD — MAX-Q STRUCTURAL',
    radio: [
      'Max-Q plus impact. Airframe let go. Range safe.',
      'Dynamic pressure peak and a hit. Vehicle is lost.',
    ],
    coach: 'Through Max-Q, fly smooth and skip the junk. q is already trying to break you.',
  },
  attitude: {
    id: 'attitude',
    reason: 'Attitude exceedance through Max-Q — stack exceeded sideslip',
    banner: 'RUD — ATTITUDE EXCEEDANCE',
    radio: [
      'Sideslip through Max-Q. Structural fail. Range safe.',
      'Attitude was long in the q region. Vehicle lost.',
    ],
    coach: 'Keep the stack straight through Max-Q. Large steers at peak q are a RUD on PAD RAT.',
  },
  sepFoul: {
    id: 'sepFoul',
    reason: 'Sep collision geometry — stack fouled',
    banner: 'RUD — SEP FOUL',
    radio: [
      'Sep geometry was dirty. Stack fouled. Range safe.',
      'Hot sep, bad angle. Stages kissed. Flight over.',
    ],
    coach: 'Stay in the SEP ZONE, ALIGN green, then press SEPARATE. A cocked sep fouls the stack.',
  },
  recontact: {
    id: 'recontact',
    reason: 'Recontact after sep — booster struck the upper stage',
    banner: 'RUD — RECONTACT',
    radio: [
      'Recontact. Booster hit the upper. Range safe.',
      'Relative motion closed. Stages collided.',
    ],
    coach: 'After pyros, open the gap. Do not drift back into the upper stage.',
  },
  tip: {
    id: 'tip',
    reason: 'Tip on deck — attitude over 14° at Haven contact',
    banner: 'TIP ON DECK — SCORE CLIPPED',
    radio: [
      'Tip on deck. Gold ring kissed steel — score clipped.',
      'Attitude was long at contact. Tip. Upper stage still flies.',
    ],
    coach: 'Straighten with RCS before the paint. A leaning booster is a tip, not a catch.',
  },
  salvage: {
    id: 'salvage',
    reason: 'Hard catch — high sink rate or off the paint',
    banner: 'HARD CATCH — SCORE CLIPPED',
    radio: [
      'Hard catch. Booster on deck, score clipped.',
      'On Haven, but sink or miss-paint made it salvage.',
    ],
    coach: 'Brake early over the painted deck. Soft sink, on the mark.',
  },
  splash: {
    id: 'splash',
    reason: 'Missed Haven — booster in the water',
    banner: 'SPLASH — HAVEN MISSED',
    radio: [
      'Splash. Combo reset — upper stage still flies.',
      'Off the barge. Booster is in the drink.',
    ],
    coach: 'Haven is small and downrange. Glide the diagonal, then fire the landing burn over the paint.',
  },
  fuelHaven: {
    id: 'fuelHaven',
    reason: 'Landing burn starved — no propellant over Haven',
    banner: 'SPLASH — NO LANDING BURN',
    radio: [
      'No propellant over Haven. Cannot brake. Splash.',
      'Landing burn starved. Booster is going in.',
    ],
    coach: 'Save fuel for the barge. A dry booster cannot kill sink over the deck.',
  },
};

const ONCE = new Set([
  'hint-ascent', 'hint-sep', 'hint-haven', 'fuel-low',
  'hint-corridor', 'hint-pickup',
  'liftoff', 'maxq', 'meco', 'sep', 'ses1', 'fairing',
  'entry', 'landing', 'touchdown', 'seco', 'deploy',
  'terminal', 'tankpress', 'internal', 'deluge', 'ignition',
  'haven-slide', 'haven-straighten', 'haven-strakes', 'haven-burn',
  'haven-reentry', 'haven-maxq', 'press-ok', 'haven-burn-hold',
]);

const COOLDOWN = {
  'align-green': 2.8,
  'align-wide': 3.4,
  'pickup-shield': 2.6,
  'pickup-fuel': 2.6,
  'pickup-boost': 2.6,
  'shield-hit': 2.2,
  'close-call': 2.4,
  'struct-warn': 2.2,
  'health-graze': 1.6,
  'health-scrape': 2.4,
  'sep-contact': 3,
  'corridor-edge': 2.8,
  'haven-burn-nag': 3.2,
};

export function fillLine(text, mission) {
  const id = mission?.id || 'KH-1';
  const payload = mission?.payload || 'payload';
  const mark = mission?.mark || 'KH';
  return String(text || '')
    .replaceAll('{id}', id)
    .replaceAll('{payload}', payload)
    .replaceAll('{mark}', mark);
}

export function createVoice() {
  return {
    cursor: Object.create(null),
    used: Object.create(null),
    heard: Object.create(null),
    lastKey: '',
    lastLine: '',
    lastAt: -999,
    lastBanner: '',
    beginFlight() {
      this.heard = Object.create(null);
      this.lastKey = '';
      this.lastLine = '';
      this.lastAt = -999;
      this.lastBanner = '';
    },
  };
}

function poolFor(key) {
  return LINES[key] || null;
}

export function pickLine(voice, key, mission) {
  const pool = poolFor(key);
  if (!pool || !pool.length) return '';
  let used = voice.used[key] || (voice.used[key] = []);
  const unused = pool.map((_, i) => i).filter((i) => !used.includes(i));
  let idx;
  if (unused.length) {
    idx = unused[0];
  } else {
    idx = ((voice.cursor[key] || 0) + 1) % pool.length;
    used = voice.used[key] = [];
  }
  used.push(idx);
  voice.cursor[key] = idx;
  let line = fillLine(pool[idx], mission);
  if (line && line === voice.lastLine && pool.length > 1) {
    idx = (idx + 1) % pool.length;
    voice.cursor[key] = idx;
    if (!used.includes(idx)) used.push(idx);
    line = fillLine(pool[idx], mission);
  }
  return line;
}

export function speak(voice, key, opts = {}) {
  const t = Number(opts.t) || 0;
  const mission = opts.mission;
  const once = opts.once ?? ONCE.has(key);
  if (once && voice.heard[key]) return null;
  const wait = opts.cooldown ?? COOLDOWN[key] ?? 0;
  if (wait > 0 && voice.lastKey === key && t - voice.lastAt < wait) return null;
  const radio = opts.radio || pickLine(voice, key, mission);
  if (!radio) return null;
  if (radio === voice.lastLine && t - voice.lastAt < 1.6) return null;
  voice.heard[key] = true;
  voice.lastKey = key;
  voice.lastLine = radio;
  voice.lastAt = t;
  const banner = opts.banner == null ? '' : opts.banner;
  if (banner) voice.lastBanner = banner;
  return {
    key,
    radio,
    banner,
    kind: opts.kind || 'info',
    holdMs: opts.holdMs == null ? 2000 : opts.holdMs,
  };
}

export function describeAbort(id, extra) {
  const base = ABORTS[id] || ABORTS.hazard;
  const reason = extra?.reason || base.reason;
  return {
    ...base,
    reason,
    banner: extra?.banner || base.banner,
    coach: extra?.coach || base.coach,
  };
}

export function abortRadio(voice, abort, mission) {
  const pool = abort.radio || [];
  const key = `abort-${abort.id}`;
  const used = voice.used[key] || (voice.used[key] = []);
  const unused = pool.map((_, i) => i).filter((i) => !used.includes(i));
  const idx = unused.length ? unused[0] : ((voice.cursor[key] || 0) + 1) % Math.max(1, pool.length);
  if (pool.length) {
    used.push(idx);
    voice.cursor[key] = idx;
  }
  return fillLine(pool[idx] || abort.reason, mission);
}

export function pauseHintFor(status, sepPhase) {
  if (status === 'PRELAUNCH') return 'TAP ANYWHERE to launch. Then just steer. Stay between the dotted corridor rails.';
  if (status === 'ASCENT') return 'Climb stays on. Drag or A/D to steer. Stay between the dotted rails. Grab the aero shield.';
  if (status === 'SEP') {
    if (sepPhase === 'window') return 'Stay in the SEP ZONE. ALIGN green, then press SEPARATE.';
    if (sepPhase === 'clear') return 'Open the gap. Stay off the upper stage, then Haven.';
    return 'MECO. Hold attitude. Sep zone is coming — straighten for ALIGN.';
  }
  if (status === 'JACKLYN') return 'Pitch over, strakes out. Long diagonal glide, then HOLD TO BURN and keep holding while you steer onto the paint.';
  return 'Tap to launch, then steer. After MECO, SEP ZONE then SEPARATE. Glide Haven, then HOLD TO BURN.';
}

export function hazardAbortId(kind, atMaxQ) {
  if (atMaxQ) return 'maxq';
  if (kind === 'bird' || kind === 'ice' || kind === 'debris' || kind === 'balloon') return kind;
  return 'hazard';
}
