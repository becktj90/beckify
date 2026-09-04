#!/usr/bin/env python3
"""Generate the Beckify iOS App Icon: white tunnel, shared bottom tangent.

Four nested pure-white rings on opaque black. Circle midlines share one
bottom tangent (tunnel / aperture — not concentric). Stroke weights are
heavy enough to survive ~60pt home-screen size.

Writes an opaque RGB PNG (no alpha) to the App Icon catalog slot.

Usage:
    python3 ios/scripts/generate_app_icon.py
    python3 ios/scripts/generate_app_icon.py --out /tmp/AppIcon.png
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 1024
# Canvas edge → outer stroke outer-edge. 10% sits in the 8–12% squircle safe band.
MARGIN_FRAC = 0.10
# Outer first. Outer 48–64px; inners never hairline (≥16–24px).
STROKES = (56, 40, 28, 24)
# Innermost midline radius — small enough to recede, large enough at 60pt.
INNER_RADIUS = 64.0


def ring_radii(outer_radius: float, strokes: tuple[int, ...], inner_radius: float) -> list[float]:
    """Even black gaps at the top of the stack (widest aperture).

    Along the vertical diameter, the gap between consecutive stroke inner/outer
    edges is constant. Shared-bottom-tangent geometry then compresses those
    gaps to zero at the tangent.
    """
    n_gaps = len(strokes) - 1
    half_pairs = sum((strokes[i] + strokes[i + 1]) / 2.0 for i in range(n_gaps))
    # sum_i 2*(r_i - r_{i+1}) - (w_i + w_{i+1})/2  =  2*(r0 - r_last) - half_pairs
    # We want each of those n_gaps terms equal to G:
    # n_gaps * G = 2*(r0 - r_last) - half_pairs
    gap = (2.0 * (outer_radius - inner_radius) - half_pairs) / n_gaps
    radii = [outer_radius]
    for i in range(n_gaps):
        step = (gap + (strokes[i] + strokes[i + 1]) / 2.0) / 2.0
        radii.append(radii[-1] - step)
    return radii


def render(size: int = SIZE) -> Image.Image:
    margin = size * MARGIN_FRAC
    outer_extent = size / 2.0 - margin  # center → outer painted edge
    r0 = outer_extent - STROKES[0] / 2.0
    radii = ring_radii(r0, STROKES, INNER_RADIUS)

    cx = size / 2.0
    cy0 = size / 2.0
    tangent = cy0 + radii[0]  # shared midline bottom tangent
    centers_y = [tangent - r for r in radii]

    # Pixel centers. Coverage is a 1px-wide smoothstep on the ring SDF.
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    xx += 0.5
    yy += 0.5
    ink = np.zeros((size, size), dtype=np.float64)
    for radius, stroke, cy in zip(radii, STROKES, centers_y):
        dist = np.hypot(xx - cx, yy - cy)
        sdf = np.abs(dist - radius) - stroke / 2.0
        coverage = np.clip(0.5 - sdf, 0.0, 1.0)
        ink = np.maximum(ink, coverage)

    pix = np.rint(ink * 255.0).astype(np.uint8)
    rgb = np.stack([pix, pix, pix], axis=-1)
    image = Image.fromarray(rgb, mode="RGB")
    assert image.mode == "RGB"
    assert image.size == (size, size)
    return image


def default_out() -> Path:
    return (
        Path(__file__).resolve().parents[1]
        / "Beckify"
        / "Assets.xcassets"
        / "AppIcon.appiconset"
        / "AppIcon.png"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=default_out())
    parser.add_argument("--size", type=int, default=SIZE)
    args = parser.parse_args()
    image = render(args.size)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.out, format="PNG")
    saved = Image.open(args.out)
    print(f"wrote {args.out} {saved.size} {saved.mode}")


if __name__ == "__main__":
    main()
