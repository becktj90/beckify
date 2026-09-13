#!/usr/bin/env python3
"""Generate the Kestrel Heavy iOS App Icon: fictional Pier 7 stack mark.

Violet ring, cyan flame, amber two-stage stack on near-black. Not the Beckify
Toolbox tunnel, not a Look Check lens, and not a Blue Origin / New Glenn mark.

Opaque RGB PNG, no alpha. Apple applies the squircle.

Usage:
    python3 ios/scripts/generate_kestrelheavy_icon.py
    python3 ios/scripts/generate_kestrelheavy_icon.py --out /tmp/AppIcon.png
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 1024
OUT = (
    Path(__file__).resolve().parents[1]
    / "KestrelHeavy"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
    / "AppIcon.png"
)


def _aa(sdf: np.ndarray, size: int) -> np.ndarray:
    return np.clip(0.5 - sdf * size, 0.0, 1.0)


def render(size: int = SIZE) -> Image.Image:
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    xx = (xx + 0.5) / size
    yy = (yy + 0.5) / size
    cx = 0.50
    dx = xx - cx
    dist = np.hypot(dx, yy - 0.50)

    bg = np.array([5, 5, 13], dtype=np.float64)
    violet = np.array([183, 171, 255], dtype=np.float64)
    cyan = np.array([140, 224, 255], dtype=np.float64)
    amber = np.array([255, 207, 93], dtype=np.float64)
    hull = np.array([236, 240, 250], dtype=np.float64)
    ink = np.array([8, 10, 22], dtype=np.float64)

    pix = np.broadcast_to(bg, (size, size, 3)).copy()

    def cover(mask: np.ndarray, color: np.ndarray) -> None:
        a = np.clip(mask, 0.0, 1.0)[..., None]
        pix[:] = pix * (1.0 - a) + color * a

    # Orbital ring — fictional stack mark, not a feather or capsule.
    cover(_aa(np.abs(dist - 0.34) - 0.018, size), violet)

    def half_width(y0: float, y1: float, w0: float, w1: float) -> np.ndarray:
        t = np.clip((yy - y0) / (y1 - y0), 0.0, 1.0)
        return w0 * (1.0 - t) + w1 * t

    # Upper stage (amber) + booster (hull), tapered.
    upper_w = half_width(0.24, 0.48, 0.038, 0.070)
    booster_w = half_width(0.48, 0.74, 0.078, 0.092)
    upper = _aa(np.maximum(np.abs(dx) - upper_w, np.maximum(0.24 - yy, yy - 0.48)), size)
    booster = _aa(np.maximum(np.abs(dx) - booster_w, np.maximum(0.48 - yy, yy - 0.74)), size)
    cover(booster, hull)
    cover(upper, amber)

    # Nose cone sits on the upper stage
    nose_half = np.clip((0.26 - yy) * 0.42, 0.0, 0.055)
    nose = _aa(np.maximum(np.abs(dx) - nose_half, np.maximum(0.17 - yy, yy - 0.26)), size)
    cover(nose, cyan)

    # Interstage band
    band = _aa(np.maximum(np.abs(dx) - 0.074, np.abs(yy - 0.48) - 0.010), size)
    cover(band, violet)

    # Grid-fin ticks (small, not Falcon-shaped)
    fin_l = _aa(np.maximum(np.abs(xx - 0.39) - 0.018, np.abs(yy - 0.62) - 0.028), size)
    fin_r = _aa(np.maximum(np.abs(xx - 0.61) - 0.018, np.abs(yy - 0.62) - 0.028), size)
    cover(np.maximum(fin_l, fin_r) * 0.9, violet)

    # Engine bells
    bell = _aa(np.maximum(np.abs(dx) - 0.055, np.maximum(0.73 - yy, yy - 0.78)), size)
    cover(bell, ink)

    # Flame + core
    flame_w = half_width(0.77, 0.90, 0.050, 0.012)
    flame = _aa(np.maximum(np.abs(dx) - flame_w, np.maximum(0.77 - yy, yy - 0.90)), size)
    cover(flame * 0.92, cyan)
    core_w = half_width(0.77, 0.86, 0.018, 0.004)
    core = _aa(np.maximum(np.abs(dx) - core_w, np.maximum(0.77 - yy, yy - 0.86)), size)
    cover(core, amber)

    # Haven deck tick (painted barge — not an ASDS X)
    deck = _aa(np.maximum(np.abs(dx) - 0.20, np.abs(yy - 0.88) - 0.008), size)
    cover(deck * 0.9, amber)

    # Upper-stage window
    window = _aa(np.hypot(dx, yy - 0.36) - 0.016, size)
    cover(window, ink)

    image = Image.fromarray(np.clip(np.rint(pix), 0, 255).astype(np.uint8), mode="RGB")
    assert image.mode == "RGB"
    assert image.size == (size, size)
    return image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    render().save(args.out, format="PNG")
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
