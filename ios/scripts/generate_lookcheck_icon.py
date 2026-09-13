#!/usr/bin/env python3
"""Generate the Look Check iOS App Icon: lens mark on opaque black.

Hot magenta outer ring, amber iris, white specular — entertainment product,
not the Beckify Toolbox tunnel. Opaque RGB PNG, no alpha.

Usage:
    python3 ios/scripts/generate_lookcheck_icon.py
    python3 ios/scripts/generate_lookcheck_icon.py --out /tmp/AppIcon.png
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 1024
OUT = Path(__file__).resolve().parents[1] / "LookCheck" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"


def render(size: int = SIZE) -> Image.Image:
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    xx = (xx + 0.5) / size
    yy = (yy + 0.5) / size
    cx, cy = 0.50, 0.52
    dist = np.hypot(xx - cx, yy - cy)

    bg = np.array([10, 8, 14], dtype=np.float64)
    magenta = np.array([255, 77, 109], dtype=np.float64)
    amber = np.array([245, 193, 92], dtype=np.float64)
    white = np.array([246, 241, 234], dtype=np.float64)

    pix = np.broadcast_to(bg, (size, size, 3)).copy()

    def ring(radius: float, width: float, color: np.ndarray, strength: float = 1.0) -> None:
        sdf = np.abs(dist - radius) - width / 2.0
        cover = np.clip(0.5 - sdf * size, 0.0, 1.0) * strength
        pix[:] = pix * (1.0 - cover[..., None]) + color * cover[..., None]

    def disc(radius: float, color: np.ndarray, strength: float = 1.0) -> None:
        cover = np.clip((radius - dist) * size, 0.0, 1.0) * strength
        pix[:] = pix * (1.0 - cover[..., None]) + color * cover[..., None]

    ring(0.34, 0.055, magenta, 1.0)
    ring(0.27, 0.018, white, 0.55)
    disc(0.18, amber, 0.95)
    disc(0.08, np.array([18, 12, 22], dtype=np.float64), 1.0)
    highlight = np.hypot(xx - 0.40, yy - 0.40)
    spec = np.clip((0.055 - highlight) * size, 0.0, 1.0) ** 1.4
    pix[:] = pix * (1.0 - spec[..., None] * 0.85) + white * spec[..., None] * 0.85

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
