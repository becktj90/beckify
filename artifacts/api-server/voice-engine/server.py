"""Beckify voice engine: free, self-hosted neural TTS for Crew Talk.

Kokoro-82M (Apache-2.0 weights and voices) through kokoro-onnx (MIT) on CPU.
No network calls at runtime, no keys, no per-call cost.

Only the api-server talks to this process. By default it binds 127.0.0.1, so it is not
reachable from the internet. If you run it elsewhere, set VOICE_ENGINE_TOKEN and send it as
`Authorization: Bearer <token>`.

POST /synthesize  JSON:
  text            str, 1..600 chars (api-server caps at 500)
  lang            "en-us" | "en-gb" | "es"
  voices          [[voice_id, weight], ...]  Kokoro style vectors, blended by weight
  speed           0.5..1.6
  pitch_semitones -4..4 (formant-coupled shift; tempo stays the same)
  format          "mp3" | "wav"
Returns audio/mpeg or audio/wav. GET /healthz returns {"ok": true, ...}.
"""

from __future__ import annotations

import io
import json
import os
import re
import sys
import threading
import time
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import numpy as np

MODEL_DIR = os.environ.get("VOICE_ENGINE_MODEL_DIR", os.path.join(os.path.dirname(__file__), "models"))
# fp32 is deterministic run to run (same line, same audio) and so cacheable. The int8 file is
# smaller but its durations wobble between runs, and it was not used for the listening samples.
MODEL_FILE = os.environ.get("VOICE_ENGINE_MODEL", "kokoro-v1.0.onnx")
VOICES_FILE = os.environ.get("VOICE_ENGINE_VOICES", "voices-v1.0.bin")
HOST = os.environ.get("VOICE_ENGINE_HOST", "127.0.0.1")
PORT = int(os.environ.get("VOICE_ENGINE_PORT", "8090"))
THREADS = int(os.environ.get("VOICE_ENGINE_THREADS", "0"))  # 0 = onnxruntime default
TOKEN = os.environ.get("VOICE_ENGINE_TOKEN", "")
MAX_TEXT = 600
MAX_BODY = 16 * 1024
QUEUE_WAIT_S = float(os.environ.get("VOICE_ENGINE_QUEUE_WAIT_S", "20"))
LANGS = {"en-us", "en-gb", "es"}
SAMPLE_RATE = 24_000

_kokoro = None
_kokoro_lock = threading.Lock()
# One synthesis at a time: the model already uses every core it is given.
_synth_lock = threading.Semaphore(1)


def kokoro():
    global _kokoro
    with _kokoro_lock:
        if _kokoro is None:
            import onnxruntime as ort
            from kokoro_onnx import Kokoro

            opts = ort.SessionOptions()
            if THREADS > 0:
                opts.intra_op_num_threads = THREADS
                opts.inter_op_num_threads = 1
            session = ort.InferenceSession(
                os.path.join(MODEL_DIR, MODEL_FILE), opts, providers=["CPUExecutionProvider"]
            )
            _kokoro = Kokoro.from_session(session, os.path.join(MODEL_DIR, VOICES_FILE))
        return _kokoro


class BadRequest(ValueError):
    pass


def parse_request(raw: dict) -> dict:
    text = raw.get("text")
    if not isinstance(text, str) or not text.strip():
        raise BadRequest("text is required")
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) > MAX_TEXT:
        raise BadRequest("text too long")
    lang = raw.get("lang", "en-us")
    if lang not in LANGS:
        raise BadRequest("unsupported lang")
    voices = raw.get("voices")
    if not isinstance(voices, list) or not 1 <= len(voices) <= 3:
        raise BadRequest("voices must be 1-3 [id, weight] pairs")
    known = set(kokoro().get_voices())
    blend = []
    for item in voices:
        if not (isinstance(item, list) and len(item) == 2 and isinstance(item[0], str)):
            raise BadRequest("bad voice entry")
        vid, weight = item[0], float(item[1])
        if vid not in known or not 0 < weight <= 1:
            raise BadRequest("unknown voice")
        blend.append((vid, weight))
    speed = float(raw.get("speed", 1.0))
    pitch = float(raw.get("pitch_semitones", 0.0))
    if not 0.5 <= speed <= 1.6 or not -4 <= pitch <= 4:
        raise BadRequest("speed or pitch out of range")
    fmt = raw.get("format", "mp3")
    if fmt not in ("mp3", "wav"):
        raise BadRequest("format must be mp3 or wav")
    return {"text": text, "lang": lang, "voices": blend, "speed": speed, "pitch": pitch, "format": fmt}


def style_for(blend):
    k = kokoro()
    total = sum(w for _, w in blend)
    return sum(k.get_voice_style(v) * (w / total) for v, w in blend)


def pitch_shift(samples: np.ndarray, semitones: float) -> np.ndarray:
    """Resample to move pitch and formants together. The caller pre-scales speed so the
    final tempo matches the profile. Lower = bigger, older-sounding voice."""
    if abs(semitones) < 0.05:
        return samples
    ratio = 2 ** (semitones / 12.0)  # < 1 lowers
    n_out = int(round(len(samples) / ratio))
    x_old = np.arange(len(samples), dtype=np.float64)
    x_new = np.linspace(0, len(samples) - 1, n_out)
    return np.interp(x_new, x_old, samples).astype(np.float32)


def level(samples: np.ndarray) -> np.ndarray:
    """Loud, even playback for a phone speaker: RMS to about -16 dBFS, soft-limited peaks."""
    if samples.size == 0:
        return samples
    rms = float(np.sqrt(np.mean(samples.astype(np.float64) ** 2)))
    if rms > 1e-5:
        samples = samples * (10 ** (-16 / 20) / rms)
    samples = np.tanh(samples * 1.2) / np.tanh(1.2)  # gentle limiter
    return np.clip(samples * 0.97, -1.0, 1.0).astype(np.float32)


def encode(samples: np.ndarray, fmt: str) -> tuple[bytes, str]:
    pcm = (samples * 32767).astype("<i2").tobytes()
    if fmt == "wav":
        buf = io.BytesIO()
        with wave.open(buf, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SAMPLE_RATE)
            w.writeframes(pcm)
        return buf.getvalue(), "audio/wav"
    import lameenc

    enc = lameenc.Encoder()
    enc.set_bit_rate(96)
    enc.set_in_sample_rate(SAMPLE_RATE)
    enc.set_channels(1)
    enc.set_quality(2)
    return bytes(enc.encode(pcm) + enc.flush()), "audio/mpeg"


def synthesize(req: dict) -> tuple[bytes, str, dict]:
    ratio = 2 ** (req["pitch"] / 12.0)
    # Speak faster by 1/ratio before lowering pitch by ratio, so tempo ends at req["speed"].
    model_speed = min(2.0, max(0.5, req["speed"] / ratio))
    t0 = time.time()
    samples, sr = kokoro().create(req["text"], voice=style_for(req["voices"]), speed=model_speed, lang=req["lang"])
    if sr != SAMPLE_RATE:
        raise RuntimeError("unexpected sample rate")
    synth_s = time.time() - t0
    samples = level(pitch_shift(np.asarray(samples, dtype=np.float32), req["pitch"]))
    audio, ctype = encode(samples, req["format"])
    return audio, ctype, {"synth_ms": int(synth_s * 1000), "audio_ms": int(len(samples) / SAMPLE_RATE * 1000)}


class Handler(BaseHTTPRequestHandler):
    server_version = "BeckifyVoice/1"

    def log_message(self, fmt, *args):  # no request text in logs
        sys.stderr.write("voice-engine %s %s\n" % (self.command, self.path))

    def _json(self, status: int, obj: dict):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self) -> bool:
        return not TOKEN or self.headers.get("Authorization", "") == f"Bearer {TOKEN}"

    def do_GET(self):
        if self.path == "/healthz":
            return self._json(200, {"ok": True, "engine": "kokoro-82m", "loaded": _kokoro is not None})
        return self._json(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/synthesize":
            return self._json(404, {"error": "not found"})
        if not self._authorized():
            return self._json(401, {"error": "unauthorized"})
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0 or length > MAX_BODY:
            return self._json(413, {"error": "body too large"})
        try:
            req = parse_request(json.loads(self.rfile.read(length)))
        except (BadRequest, ValueError, TypeError) as exc:
            return self._json(400, {"error": str(exc) or "bad request"})
        if not _synth_lock.acquire(timeout=QUEUE_WAIT_S):
            return self._json(503, {"error": "busy"})
        try:
            audio, ctype, timing = synthesize(req)
        except Exception as exc:  # keep the process alive; api-server falls back
            sys.stderr.write(f"voice-engine synth failed: {type(exc).__name__}\n")
            return self._json(500, {"error": "synthesis failed"})
        finally:
            _synth_lock.release()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(audio)))
        self.send_header("X-Voice-Synth-Ms", str(timing["synth_ms"]))
        self.send_header("X-Voice-Audio-Ms", str(timing["audio_ms"]))
        self.end_headers()
        self.wfile.write(audio)


def main():
    if os.environ.get("VOICE_ENGINE_PRELOAD", "1") == "1":
        kokoro()
        kokoro().create("Ready.", voice="af_heart", speed=1.0, lang="en-us")  # warm the graph
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    sys.stderr.write(f"voice-engine listening on {HOST}:{PORT}\n")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
