import { randomBytes, randomInt } from "node:crypto";

/**
 * In-memory pairing rooms for Crew Talk device linking.
 *
 * Two people, two languages, text only. Nothing is persisted. Rooms live in
 * one process, so the API must run as a single machine for linking to work
 * (see README → Crew Talk rooms). The pid is the participant's secret.
 */

export type RoomLanguage = "en" | "es";

export type RoomEvent =
  | { t: "ready"; partnerLanguage: RoomLanguage | null; partnerOnline: boolean }
  | { t: "peer"; language: RoomLanguage; online: boolean }
  | { t: "message"; id: string; language: RoomLanguage; text: string };

type Send = (event: RoomEvent) => void;

interface Participant {
  pid: string;
  language: RoomLanguage;
  send: Send | null;
  pending: RoomEvent[];
  offlineSince: number | null;
  sentAt: number[];
}

interface Room {
  code: string;
  participants: Participant[];
  lastActive: number;
}

export type StoreFailure = { ok: false; status: number; error: string };

export const ROOM_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const ROOM_CODE_LENGTH = 6;
export const ROOM_MAX_TEXT_CHARS = 500;
export const ROOM_MAX_ROOMS = 300;
export const ROOM_IDLE_TTL_MS = 30 * 60 * 1000;
export const ROOM_OFFLINE_GRACE_MS = 2 * 60 * 1000;
export const ROOM_SEND_LIMIT = 20;
export const ROOM_SEND_WINDOW_MS = 10_000;
const MAX_PENDING = 20;

export function normalizeRoomLanguage(raw: unknown): RoomLanguage | null {
  if (typeof raw !== "string") return null;
  const primary = raw.trim().toLowerCase().replace(/_/g, "-").split("-")[0];
  return primary === "en" || primary === "es" ? primary : null;
}

export function normalizeRoomCode(raw: unknown): string {
  if (typeof raw !== "string") return "";
  return raw.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
}

export class RoomStore {
  private readonly rooms = new Map<string, Room>();

  constructor(private readonly now: () => number = Date.now) {}

  get size(): number {
    return this.rooms.size;
  }

  create(language: RoomLanguage): { ok: true; code: string; pid: string } | StoreFailure {
    this.sweep();
    if (this.rooms.size >= ROOM_MAX_ROOMS) {
      return { ok: false, status: 503, error: "Too many active rooms. Try again shortly." };
    }
    let code = "";
    for (let attempt = 0; attempt < 20; attempt += 1) {
      const candidate = Array.from({ length: ROOM_CODE_LENGTH }, () =>
        ROOM_CODE_ALPHABET[randomInt(ROOM_CODE_ALPHABET.length)],
      ).join("");
      if (!this.rooms.has(candidate)) {
        code = candidate;
        break;
      }
    }
    if (!code) return { ok: false, status: 503, error: "Could not allocate a room code." };
    const participant = newParticipant(language);
    this.rooms.set(code, { code, participants: [participant], lastActive: this.now() });
    return { ok: true, code, pid: participant.pid };
  }

  join(
    rawCode: unknown,
    language: RoomLanguage,
  ): { ok: true; pid: string; partnerLanguage: RoomLanguage } | StoreFailure {
    this.sweep();
    const room = this.rooms.get(normalizeRoomCode(rawCode));
    if (!room) return { ok: false, status: 404, error: "Room not found. Check the code." };
    if (room.participants.length >= 2) {
      return { ok: false, status: 409, error: "This room already has two people." };
    }
    const host = room.participants[0];
    if (host.language === language) {
      return {
        ok: false,
        status: 409,
        error: "Both people picked the same language. One of you needs to pick the other.",
      };
    }
    const guest = newParticipant(language);
    room.participants.push(guest);
    room.lastActive = this.now();
    this.deliver(host, { t: "peer", language, online: false });
    return { ok: true, pid: guest.pid, partnerLanguage: host.language };
  }

  has(rawCode: unknown, pid: unknown): boolean {
    return this.find(rawCode, pid) !== null;
  }

  /**
   * Attach a live stream. Flushes any queued messages. A second subscribe
   * for the same pid replaces the first (reconnect).
   */
  subscribe(
    rawCode: unknown,
    pid: unknown,
    send: Send,
  ): { ok: true; unsubscribe: () => void } | StoreFailure {
    const found = this.find(rawCode, pid);
    if (!found) return { ok: false, status: 404, error: "Room or participant not found." };
    const { room, me, other } = found;
    me.send = send;
    me.offlineSince = null;
    room.lastActive = this.now();
    send({
      t: "ready",
      partnerLanguage: other?.language ?? null,
      partnerOnline: Boolean(other?.send),
    });
    const queued = me.pending.splice(0, me.pending.length);
    for (const event of queued) send(event);
    if (other) this.deliver(other, { t: "peer", language: me.language, online: true });
    return {
      ok: true,
      unsubscribe: () => {
        if (me.send !== send) return;
        me.send = null;
        me.offlineSince = this.now();
        const current = this.find(rawCode, pid);
        if (current?.other) {
          this.deliver(current.other, { t: "peer", language: me.language, online: false });
        }
      },
    };
  }

  post(
    rawCode: unknown,
    pid: unknown,
    text: unknown,
  ): { ok: true; id: string; delivered: boolean } | StoreFailure {
    const found = this.find(rawCode, pid);
    if (!found) return { ok: false, status: 404, error: "Room or participant not found." };
    const { room, me, other } = found;
    const body = typeof text === "string" ? text.trim() : "";
    if (!body) return { ok: false, status: 400, error: "Provide text to send." };
    if (body.length > ROOM_MAX_TEXT_CHARS) {
      return { ok: false, status: 413, error: `Text must be ${ROOM_MAX_TEXT_CHARS} characters or fewer.` };
    }
    const now = this.now();
    me.sentAt = me.sentAt.filter((at) => now - at < ROOM_SEND_WINDOW_MS);
    if (me.sentAt.length >= ROOM_SEND_LIMIT) {
      return { ok: false, status: 429, error: "Slow down a little." };
    }
    me.sentAt.push(now);
    room.lastActive = now;
    if (!other) return { ok: false, status: 409, error: "Waiting for the other person to join." };
    const id = randomBytes(6).toString("hex");
    const delivered = Boolean(other.send);
    this.deliver(other, { t: "message", id, language: me.language, text: body });
    return { ok: true, id, delivered };
  }

  leave(rawCode: unknown, pid: unknown): void {
    const found = this.find(rawCode, pid);
    if (!found) return;
    const { room, me, other } = found;
    me.send = null;
    room.participants = room.participants.filter((p) => p !== me);
    if (other) this.deliver(other, { t: "peer", language: me.language, online: false });
    if (room.participants.length === 0) this.rooms.delete(room.code);
  }

  /** Drop idle rooms and participants who never came back. */
  sweep(): void {
    const now = this.now();
    for (const [code, room] of this.rooms) {
      room.participants = room.participants.filter(
        (p) => p.send !== null || p.offlineSince === null || now - p.offlineSince < ROOM_OFFLINE_GRACE_MS,
      );
      const idle = now - room.lastActive > ROOM_IDLE_TTL_MS;
      const anyoneLive = room.participants.some((p) => p.send !== null);
      if (room.participants.length === 0 || (idle && !anyoneLive)) this.rooms.delete(code);
    }
  }

  private find(
    rawCode: unknown,
    pid: unknown,
  ): { room: Room; me: Participant; other: Participant | undefined } | null {
    if (typeof pid !== "string" || !pid) return null;
    const room = this.rooms.get(normalizeRoomCode(rawCode));
    if (!room) return null;
    const me = room.participants.find((p) => p.pid === pid);
    if (!me) return null;
    return { room, me, other: room.participants.find((p) => p !== me) };
  }

  private deliver(target: Participant, event: RoomEvent): void {
    if (target.send) {
      target.send(event);
      return;
    }
    // Presence blips are not worth queueing. Messages are.
    if (event.t !== "message") return;
    target.pending.push(event);
    if (target.pending.length > MAX_PENDING) target.pending.shift();
  }
}

function newParticipant(language: RoomLanguage): Participant {
  return {
    pid: randomBytes(16).toString("hex"),
    language,
    send: null,
    pending: [],
    offlineSince: null,
    sentAt: [],
  };
}

export const roomStore = new RoomStore();
