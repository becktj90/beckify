"""Unit tests for the voice engine that do not need the model. Run: python3 -m unittest test_server"""

import io
import unittest
import wave

import numpy as np

import server


class FakeKokoro:
    def get_voices(self):
        return ["af_heart", "am_puck", "em_santa"]


class VoiceEngineTests(unittest.TestCase):
    def setUp(self):
        server._kokoro = FakeKokoro()

    def tearDown(self):
        server._kokoro = None

    def good(self, **over):
        body = {"text": "Kill the power.", "lang": "en-us", "voices": [["am_puck", 0.6], ["af_heart", 0.4]], "speed": 0.9, "pitch_semitones": -1, "format": "mp3"}
        body.update(over)
        return body

    def test_accepts_profile(self):
        req = server.parse_request(self.good())
        self.assertEqual(req["voices"], [("am_puck", 0.6), ("af_heart", 0.4)])
        self.assertEqual(req["lang"], "en-us")

    def test_rejects_bad_input(self):
        for over in (
            {"text": ""},
            {"text": "x" * 601},
            {"lang": "fr"},
            {"voices": [["nope", 1]]},
            {"voices": []},
            {"voices": [["am_puck", 0]]},
            {"speed": 3},
            {"pitch_semitones": 9},
            {"format": "ogg"},
        ):
            with self.assertRaises(server.BadRequest, msg=str(over)):
                server.parse_request(self.good(**over))

    def test_pitch_shift_lowers_and_stretches(self):
        sr = server.SAMPLE_RATE
        t = np.arange(sr) / sr
        tone = np.sin(2 * np.pi * 200 * t).astype(np.float32)
        out = server.pitch_shift(tone, -12)
        self.assertAlmostEqual(len(out) / len(tone), 2.0, places=2)
        # Zero crossings per second halve when pitch drops an octave.
        zc = lambda x: np.count_nonzero(np.diff(np.signbit(x))) / (len(x) / sr)
        self.assertAlmostEqual(zc(out) / zc(tone), 0.5, delta=0.02)
        self.assertIs(server.pitch_shift(tone, 0), tone)

    def test_level_is_loud_and_clipped(self):
        quiet = (0.01 * np.sin(np.linspace(0, 400, 24000))).astype(np.float32)
        out = server.level(quiet)
        self.assertLessEqual(float(np.max(np.abs(out))), 1.0)
        self.assertGreater(float(np.sqrt(np.mean(out ** 2))), 0.1)

    def test_wav_encoding(self):
        audio, ctype = server.encode(np.zeros(2400, dtype=np.float32), "wav")
        self.assertEqual(ctype, "audio/wav")
        with wave.open(io.BytesIO(audio)) as w:
            self.assertEqual(w.getframerate(), 24000)
            self.assertEqual(w.getnframes(), 2400)


if __name__ == "__main__":
    unittest.main()
