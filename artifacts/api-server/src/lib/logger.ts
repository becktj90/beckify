import pino from "pino";

const isProduction = process.env.NODE_ENV === "production";

export const logger = pino({
  level: process.env.LOG_LEVEL ?? "info",
  redact: [
    "req.headers.authorization",
    "req.headers.cookie",
    "res.headers['set-cookie']",
  ],
  ...(isProduction
    ? {}
    : {
        transport: {
          target: "pino-pretty",
          options: { colorize: true },
        },
      }),
});

/** Coarse outcome for route timing. Not a request body and not a client id. */
export type RouteTimingOutcome =
  | "ok"
  | "client_error"
  | "rate_limited"
  | "provider_error"
  | "unavailable"
  | "timeout"
  | "error";

export function outcomeFromStatus(status: number): RouteTimingOutcome {
  if (status >= 200 && status < 300) return "ok";
  if (status === 429) return "rate_limited";
  if (status === 502) return "provider_error";
  if (status === 503) return "unavailable";
  if (status === 504) return "timeout";
  if (status >= 400 && status < 500) return "client_error";
  return "error";
}

/**
 * Structured timing for a finished HTTP response.
 * Fields are route, outcome class, and durations only — no text, voice, user id, or key.
 * `first_audio_chunk_ms` is optional and only set when a speak handler measured one.
 */
export function logRouteTiming(fields: {
  route: string;
  outcome: RouteTimingOutcome;
  duration_ms: number;
  first_audio_chunk_ms?: number;
}): void {
  const payload: {
    route: string;
    outcome: RouteTimingOutcome;
    duration_ms: number;
    first_audio_chunk_ms?: number;
  } = {
    route: fields.route,
    outcome: fields.outcome,
    duration_ms: Math.max(0, Math.round(fields.duration_ms)),
  };
  if (
    typeof fields.first_audio_chunk_ms === "number" &&
    Number.isFinite(fields.first_audio_chunk_ms)
  ) {
    payload.first_audio_chunk_ms = Math.max(
      0,
      Math.round(fields.first_audio_chunk_ms),
    );
  }
  logger.info(payload, "route_timing");
}

/** Log once when the response finishes. Does not write the body or change status. */
export function observeRouteTiming(
  res: {
    statusCode: number;
    on: (event: "finish", listener: () => void) => void;
  },
  route: string,
  startedAtMs: number,
  sample?: () => { first_audio_chunk_ms?: number | null } | void,
): void {
  res.on("finish", () => {
    const extra = sample?.();
    logRouteTiming({
      route,
      outcome: outcomeFromStatus(res.statusCode),
      duration_ms: Date.now() - startedAtMs,
      first_audio_chunk_ms: extra?.first_audio_chunk_ms ?? undefined,
    });
  });
}
