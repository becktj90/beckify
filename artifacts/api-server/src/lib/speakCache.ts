import { createHash } from "node:crypto";

/**
 * In-memory LRU cache for ElevenLabs speech audio on `/api/speak`.
 *
 * Crew Talk is live, unbounded user speech, so most lines are unique and are
 * never cached. But jobsite phrases repeat constantly ("Kill the power.",
 * "Panel is dead.", ...), and every repeat was re-synthesized and re-billed
 * at ElevenLabs v3 rates. This cache makes a repeat line free.
 *
 * Key: the same canonical document the iOS client already hashes in
 * `CrewTalkSpeakRequest.audioCacheKey` (BeckifyMath/CrewTalkContracts.swift):
 * `crewtalk-speak-v1`, `voiceMode=jobsite`, model, voice, language, format,
 * text — NFC-normalized, trimmed, CR/LF folded to LF — SHA-256 hex. The
 * iOS on-device cache and this server cache therefore agree on keys, so a
 * line cached on the phone and a line cached on the server are the same clip.
 * Voice settings and seed are deterministic per voice id server-side
 * (Bodie/Junie presets, Sloane seed 50505), so they need no key component.
 * Audio tags in the text (e.g. `[coughs]`) are part of the text as sent to
 * ElevenLabs, so they are part of the key.
 *
 * Scope: ElevenLabs path only. The OpenAI path is not cached — its
 * instructions make delivery non-deterministic take-to-take, and its
 * per-character cost is ~5x lower, so caching it buys little.
 *
 * Caps (defaults, overridable per instance for tests):
 * - 200 entries and 50 MB total. A 128 kbps MP3 is ~16 KB per second of
 *   speech; a 500-character Crew Talk line is at most ~30 s, so 200 entries
 *   is roughly 15–40 MB in practice and the byte cap is the binding limit.
 * - 24 h TTL. Voice ids, model, and server-side voice settings change only
 *   on deploy, and a deploy restarts the process (see below), so 24 h bounds
 *   staleness without churning the cache every window.
 *
 * Lifetime: process memory only. Fly.io scale-to-zero and any deploy or
 * restart wipe this cache — that is expected and safe (a miss just
 * re-synthesizes). The iOS on-device cache is the durable layer; this one
 * is a shared second layer for repeat lines across devices/sessions.
 *
 * Accounting: a cache hit never calls ElevenLabs and never charges the
 * ElevenLabs character budget (`chargeBudget("eleven")`). The per-client
 * request rate limit (20 speak requests / 15 min) still applies to hits —
 * it is the anti-abuse guard, and a hit still costs the server a response.
 * Hits are logged as `ai_usage` with kind `speak`, outcome `ok`, units 0.
 */

export interface SpeakCacheInput {
  voice: string;
  model: string;
  language: string;
  format: string;
  text: string;
}

export interface SpeakCacheOptions {
  /** Maximum entries held. Default 200. */
  maxEntries?: number;
  /** Maximum total audio bytes held. Default 50 MB. */
  maxBytes?: number;
  /** Entry lifetime in milliseconds. Default 24 h. */
  ttlMs?: number;
}

export const SPEAK_CACHE_MAX_ENTRIES = 200;
export const SPEAK_CACHE_MAX_BYTES = 50 * 1024 * 1024;
export const SPEAK_CACHE_TTL_MS = 24 * 60 * 60 * 1000;

/** Canonical text, matching `CrewTalkSpeakRequest.canonicalText` on iOS. */
export function canonicalSpeakText(raw: string): string {
  return raw
    .normalize("NFC")
    .trim()
    .replace(/\r\n?/g, "\n");
}

/** Canonical cache document, matching `CrewTalkSpeakRequest.canonicalCacheDocument`. */
export function speakCacheDocument(input: SpeakCacheInput): string {
  return [
    "crewtalk-speak-v1",
    "voiceMode=jobsite",
    `model=${input.model}`,
    `voice=${input.voice}`,
    `language=${input.language}`,
    `format=${input.format}`,
    `text=${canonicalSpeakText(input.text)}`,
  ].join("\n");
}

/** SHA-256 hex of the canonical cache document. */
export function speakCacheKey(input: SpeakCacheInput): string {
  return createHash("sha256").update(speakCacheDocument(input), "utf8").digest("hex");
}

interface SpeakCacheEntry {
  audio: Buffer;
  storedAt: number;
}

export interface SpeakCacheStats {
  hits: number;
  misses: number;
  entries: number;
  bytes: number;
}

export class SpeakAudioCache {
  private readonly maxEntries: number;
  private readonly maxBytes: number;
  private readonly ttlMs: number;
  private readonly entries = new Map<string, SpeakCacheEntry>();
  private bytes = 0;
  private hits = 0;
  private misses = 0;

  constructor(options: SpeakCacheOptions = {}) {
    this.maxEntries = options.maxEntries ?? SPEAK_CACHE_MAX_ENTRIES;
    this.maxBytes = options.maxBytes ?? SPEAK_CACHE_MAX_BYTES;
    this.ttlMs = options.ttlMs ?? SPEAK_CACHE_TTL_MS;
  }

  /** Returns cached audio, or null. A hit refreshes recency (LRU). */
  get(key: string, now = Date.now()): Buffer | null {
    const entry = this.entries.get(key);
    if (!entry) {
      this.misses += 1;
      return null;
    }
    if (now - entry.storedAt > this.ttlMs) {
      this.bytes -= entry.audio.length;
      this.entries.delete(key);
      this.misses += 1;
      return null;
    }
    // Refresh LRU order: delete + re-insert moves it to the newest end.
    this.entries.delete(key);
    this.entries.set(key, entry);
    this.hits += 1;
    return entry.audio;
  }

  /** Stores audio. Empty buffers are never stored. Evicts oldest first. */
  set(key: string, audio: Buffer, now = Date.now()): void {
    if (!audio.length) return;
    const existing = this.entries.get(key);
    if (existing) {
      this.bytes -= existing.audio.length;
      this.entries.delete(key);
    }
    // A single clip larger than the whole cache is not worth keeping.
    if (audio.length > this.maxBytes) return;
    this.entries.set(key, { audio, storedAt: now });
    this.bytes += audio.length;
    while (this.entries.size > this.maxEntries || this.bytes > this.maxBytes) {
      const oldest = this.entries.keys().next();
      if (oldest.done) break;
      const evicted = this.entries.get(oldest.value);
      if (evicted) this.bytes -= evicted.audio.length;
      this.entries.delete(oldest.value);
    }
  }

  stats(): SpeakCacheStats {
    return { hits: this.hits, misses: this.misses, entries: this.entries.size, bytes: this.bytes };
  }

  /** Test-only. Drops all entries and counters. */
  clearForTests(): void {
    this.entries.clear();
    this.bytes = 0;
    this.hits = 0;
    this.misses = 0;
  }
}

/** Process-wide cache for the speak route. Wiped on restart / scale-to-zero. */
export const elevenSpeakCache = new SpeakAudioCache();
