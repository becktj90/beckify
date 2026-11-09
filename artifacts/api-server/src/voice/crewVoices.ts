/**
 * Crew Talk character voices on the free Beckify voice engine (Kokoro-82M).
 *
 * Each character is a blend of Kokoro voice styles plus pace and a small pitch move.
 * The dialect lives in the words: Crew Talk rewrites keep the full meaning and are
 * written in each character's own style before they reach this table. The voice only
 * sets timbre, pace, and energy. No impressions of real people and no caricature.
 *
 * Shipped iOS builds send ElevenLabs voice ids. Those ids are kept here only as lookup
 * keys so old and new builds land on the same character; they never call ElevenLabs.
 */

export type CrewVoiceKey =
  | "bodieHale"
  | "titoSolano"
  | "lupitaReyes"
  | "humbertoArismendi"
  | "humbertoArismendiEnglish"
  | "juniePell"
  | "pearl"
  | "sloaneMerritt"
  | "dreLacey"
  | "cassianVale";

export type VoiceEngineLang = "en-us" | "en-gb" | "es";

export interface CrewVoiceProfile {
  /** Kokoro voice ids and weights. Weights are normalized by the engine. */
  voices: ReadonlyArray<readonly [string, number]>;
  /** Final tempo. 1 is the model's natural pace. */
  speed: number;
  /** Formant-coupled pitch move in semitones. Negative is deeper and older. */
  pitchSemitones: number;
  lang: VoiceEngineLang;
  /** One line on why these settings fit the character brief. */
  brief: string;
  /**
   * Spoken-only respellings for words the phonemizer misreads. Display text never
   * changes. Keep these to pronunciation fixes, never word swaps.
   */
  say?: ReadonlyArray<readonly [RegExp, string]>;
}

export const CREW_VOICE_PROFILES: Readonly<Record<CrewVoiceKey, CrewVoiceProfile>> = {
  bodieHale: {
    voices: [["am_puck", 0.6], ["am_fenrir", 0.4]],
    speed: 0.88,
    pitchSemitones: -0.7,
    lang: "en-us",
    brief: "Laid-back coastal California guy: unhurried, low and a little rough, relaxed melody.",
  },
  titoSolano: {
    voices: [["em_santa", 0.6], ["em_alex", 0.4]],
    speed: 0.9,
    pitchSemitones: -2.2,
    lang: "es",
    brief: "Older Cuban jobsite hand: deep, weathered, short direct phrases.",
  },
  lupitaReyes: {
    voices: [["ef_dora", 1]],
    speed: 0.96,
    pitchSemitones: 0.3,
    lang: "es",
    brief: "Warm Mexican Spanish from Jalisco and Mexico City: bright, friendly, easy pace.",
  },
  humbertoArismendi: {
    voices: [["em_alex", 0.75], ["em_santa", 0.25]],
    speed: 0.88,
    pitchSemitones: -1.2,
    lang: "es",
    brief: "Dignified Caracas master electrician in his 70s: measured, courteous, polished.",
  },
  humbertoArismendiEnglish: {
    // A Spanish-speaker style vector reading English phonemes gives a natural
    // Spanish-speaker color without exaggeration.
    voices: [["em_alex", 0.6], ["am_adam", 0.4]],
    speed: 0.88,
    pitchSemitones: -1.2,
    lang: "en-us",
    brief: "The same Humberto in courteous English, unhurried, with his own Spanish-speaker color.",
  },
  juniePell: {
    voices: [["af_bella", 0.55], ["af_nicole", 0.45]],
    speed: 0.8,
    pitchSemitones: -1.0,
    lang: "en-us",
    brief: "Ornery backwoods woman: slow, thick, proud, takes her time with every word.",
  },
  pearl: {
    voices: [["af_heart", 0.7], ["af_aoede", 0.3]],
    speed: 0.94,
    pitchSemitones: -0.8,
    lang: "en-us",
    brief: "Warm woman in her 40s: soft, steady, kind, never rushed.",
    say: [[/\bhon\b/gi, "hun"]],
  },
  sloaneMerritt: {
    voices: [["af_sarah", 0.6], ["af_kore", 0.4]],
    speed: 1.02,
    pitchSemitones: 0.4,
    lang: "en-us",
    brief: "Polished HR lead: bright, brisk, upbeat meeting voice.",
  },
  dreLacey: {
    voices: [["am_michael", 0.5], ["am_onyx", 0.5]],
    speed: 1.06,
    pitchSemitones: 0,
    lang: "en-us",
    brief: "East Oakland electrician: loud, quick, full of energy. Slang is in the words, not the voice.",
    say: [[/\bAy,/g, "Aye,"]],
  },
  cassianVale: {
    voices: [["bm_george", 0.6], ["bm_fable", 0.4]],
    speed: 0.95,
    pitchSemitones: 0,
    lang: "en-gb",
    brief: "Look Check roast host: dry, arch, crisp delivery.",
  },
};

/** Ids that shipped iOS builds send. Lookup keys only. */
export const LEGACY_CREW_VOICE_IDS: Readonly<Record<string, CrewVoiceKey>> = {
  XVO6RhOYU9ZEKHFXrx6b: "bodieHale",
  goyf4sY4AqSvMIeO1hb5: "titoSolano",
  m2X69O7Xomk9219qo0Gy: "juniePell",
  // Pre-restyle Junie id still sent by older TestFlight builds.
  tdK8noxHGTBqk6F18tbZ: "juniePell",
  xDnrPZyqSbomyfOcnNpu: "pearl",
  qMmZtYs7EKOOIm0u211n: "sloaneMerritt",
  iGXRQ0smdhSFlb6iV1Pr: "lupitaReyes",
  IvXILleF0UhlyqiuUo87: "humbertoArismendi",
  MAPMuGNkK84YjEK5kMBn: "dreLacey",
};

const KEYS = new Set<string>(Object.keys(CREW_VOICE_PROFILES));

export function isCrewVoiceKey(raw: unknown): raw is CrewVoiceKey {
  return typeof raw === "string" && KEYS.has(raw);
}

/**
 * Which character a speak request is for. Accepts the `crew` field, a `crew:<key>` voice,
 * or a legacy voice id. Humberto's shared legacy id follows the request language.
 */
export function resolveCrewVoiceKey(voice: unknown, crew: unknown, language: string): CrewVoiceKey | null {
  const crewText = typeof crew === "string" ? crew.trim() : "";
  if (isCrewVoiceKey(crewText)) return englishVariant(crewText, language);
  const voiceText = typeof voice === "string" ? voice.trim() : "";
  if (voiceText.startsWith("crew:")) {
    const key = voiceText.slice(5);
    return isCrewVoiceKey(key) ? englishVariant(key, language) : null;
  }
  const legacy = LEGACY_CREW_VOICE_IDS[voiceText];
  return legacy ? englishVariant(legacy, language) : null;
}

function englishVariant(key: CrewVoiceKey, language: string): CrewVoiceKey {
  if (key === "humbertoArismendi" && language === "en") return "humbertoArismendiEnglish";
  if (key === "humbertoArismendiEnglish" && language === "es") return "humbertoArismendi";
  return key;
}

/** Apply a profile's spoken-only respellings. */
export function spokenText(text: string, profile: CrewVoiceProfile): string {
  let out = text;
  for (const [pattern, replacement] of profile.say ?? []) out = out.replace(pattern, replacement);
  return out;
}

/**
 * Translator presets on the free engine. Used only when TRANSLATOR_VOICE_PROVIDER=kokoro;
 * the translator stays on its existing provider by default. Japanese is not offered here.
 */
export const TRANSLATOR_VOICE_PROFILES = {
  california: { voices: [["am_puck", 0.7], ["am_echo", 0.3]], speed: 0.96, pitchSemitones: 0, lang: "en-us", brief: "Coastal California adult, relaxed and warm." },
  deepSouth: { voices: [["am_michael", 0.7], ["am_fenrir", 0.3]], speed: 0.86, pitchSemitones: -1.2, lang: "en-us", brief: "Unhurried Deep South storyteller, low and round." },
  jobsite: { voices: [["em_santa", 0.7], ["em_alex", 0.3]], speed: 0.92, pitchSemitones: -2, lang: "es", brief: "Weathered Cuban and South American tradesman." },
  clean: { voices: [["ef_dora", 1]], speed: 0.96, pitchSemitones: 0, lang: "es", brief: "Warm, polished Spanish." },
} as const satisfies Record<string, CrewVoiceProfile>;
