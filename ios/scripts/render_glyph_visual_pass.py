#!/usr/bin/env python3
"""Raster comparison sheet for the 2026-09-15 ToolGlyph visual pass.

Mirrors Swift geometry in ios/Beckify/Views/Components/ToolGlyph.swift so App
Design can re-check fill + even-odd holes vs the #151 stroke-only lock without
Simulator. Not a shipping asset.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# Dark-mode Theme.swift category primaries.
CAT = {
    "field": (224, 156, 86),
    "power": (64, 186, 214),
    "homework": (86, 214, 164),
    "sensors": (240, 128, 196),
    "controls": (176, 140, 244),
    "reference": (168, 180, 196),
}

BG = (8, 11, 16)
MUTED = (148, 162, 178)
FG = (232, 238, 245)
HAIR = (255, 255, 255, 28)

GLYPHS = [
    # Field Quick
    ("voltageDrop", "Voltage Drop", "field", "quick"),
    ("wireAmpacity", "Ampacity", "field", "quick"),
    ("motorFLA", "Motor FLA", "field", "quick"),
    ("receptacleSelector", "Receptacle", "field", "quick"),
    ("wifiStatus", "Wi-Fi", "sensors", "quick"),
    ("conduitFill", "Conduit", "field", "quick"),
    # Power / Basics used on the App Design sheet
    ("ohmsLaw", "Ohm's Law", "homework", "basics"),
    ("power", "Power", "power", "power"),
    # Jobsite
    ("necCircuit", "NEC Circuit", "field", "jobsite"),
    ("shortCircuit", "Short Circuit", "field", "jobsite"),
    ("motorNameplate", "Nameplate", "field", "jobsite"),
    ("lookCheck", "Look Check", "field", "jobsite"),
    # Power + Bench
    ("batteryBank", "Battery", "power", "power"),
    ("upsSizing", "UPS", "power", "power"),
    ("heaterDesign", "Heater", "homework", "bench"),
    ("eBikePackDesigner", "Pack", "homework", "bench"),
    ("solenoidDesign", "Solenoid", "homework", "bench"),
    ("analogWorkbench", "Op-amp", "homework", "bench"),
]


def mix(c, a, bg=BG):
    return tuple(int(bg[i] * (1 - a) + c[i] * a) for i in range(3))


def load_font(size: int, bold: bool = False):
    path = (
        "/usr/share/fonts/truetype/macos/Inter-SemiBold.ttf"
        if bold
        else "/usr/share/fonts/truetype/macos/Inter-Regular.ttf"
    )
    fallback = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.truetype(fallback, size)


def quad(p0, c, p1, steps=18):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        pts.append(
            (
                u * u * p0[0] + 2 * u * t * c[0] + t * t * p1[0],
                u * u * p0[1] + 2 * u * t * c[1] + t * t * p1[1],
            )
        )
    return pts


def bolt(r):
    x, y, w, h = r
    mx, my = x + w / 2, y + h / 2
    return [
        (mx + w * 0.12, y),
        (mx - w * 0.22, my + h * 0.04),
        (mx - w * 0.02, my + h * 0.04),
        (mx - w * 0.16, y + h),
        (mx + w * 0.24, my - h * 0.04),
        (mx + w * 0.04, my - h * 0.04),
    ]


def ribbon(points, width):
    if len(points) < 2:
        return []
    half = width / 2
    left, right = [], []
    n = len(points)
    for i, (px, py) in enumerate(points):
        prev = points[i] if i == 0 else points[i - 1]
        nxt = points[i] if i == n - 1 else points[i + 1]
        dx, dy = nxt[0] - prev[0], nxt[1] - prev[1]
        length = max(math.hypot(dx, dy), 0.001)
        nx, ny = -dy / length * half, dx / length * half
        left.append((px + nx, py + ny))
        right.append((px - nx, py - ny))
    return left + list(reversed(right))


class Well:
    def __init__(self, canvas: Image.Image, ox, oy, size, color, circular, scale):
        self.im = canvas
        self.ox, self.oy, self.size = ox, oy, size
        self.color = color
        self.circular = circular
        self.scale = scale
        self.well = mix(color, 0.22)
        self.draw_well()
        glyph = size * 0.66
        inset = glyph * 0.10
        gx = ox + (size - glyph) / 2
        gy = oy + (size - glyph) / 2
        self.rect = (gx + inset, gy + inset, glyph - 2 * inset, glyph - 2 * inset)
        self.glyph_px = glyph

    def draw_well(self):
        d = ImageDraw.Draw(self.im, "RGBA")
        box = [self.ox, self.oy, self.ox + self.size, self.oy + self.size]
        if self.circular:
            d.ellipse(box, fill=self.well + (255,), outline=self.color + (90,), width=max(1, int(self.scale)))
        else:
            rad = 12 * self.scale
            d.rounded_rectangle(
                box, radius=rad, fill=self.well + (255,), outline=self.color + (90,), width=max(1, int(self.scale))
            )

    @property
    def r(self):
        x, y, w, h = self.rect
        return x, y, w, h

    def lw(self, proposed: bool) -> int:
        weight = 3.2 if proposed else 2.6
        return max(2, round(weight * (self.glyph_px / 44)))

    def stroke_draw(self):
        return ImageDraw.Draw(self.im)

    def line(self, a, b, proposed=False):
        self.stroke_draw().line([a, b], fill=self.color, width=self.lw(proposed), joint="curve")

    def polyline(self, pts, proposed=False, closed=False):
        if closed:
            pts = list(pts) + [pts[0]]
        self.stroke_draw().line(pts, fill=self.color, width=self.lw(proposed), joint="curve")

    def arc(self, bbox, start, end, proposed=False):
        self.stroke_draw().arc(bbox, start=start, end=end, fill=self.color, width=self.lw(proposed))

    def ellipse_stroke(self, bbox, proposed=False):
        self.stroke_draw().ellipse(bbox, outline=self.color, width=self.lw(proposed))

    def rrect_stroke(self, bbox, radius, proposed=False):
        self.stroke_draw().rounded_rectangle(bbox, radius=radius, outline=self.color, width=self.lw(proposed))

    def fill_mask(self, bodies, holes=()):
        """Composite even-odd-style fill: bodies ink, holes punch to well tint."""
        mask = Image.new("L", self.im.size, 0)
        md = ImageDraw.Draw(mask)
        for kind, payload in bodies:
            self._mask_shape(md, kind, payload, 255)
        for kind, payload in holes:
            self._mask_shape(md, kind, payload, 0)
        ink = Image.new("RGB", self.im.size, self.color)
        self.im.paste(ink, mask=mask)

    def _mask_shape(self, md, kind, payload, value):
        if kind == "poly":
            md.polygon(payload, fill=value)
        elif kind == "ellipse":
            md.ellipse(payload, fill=value)
        elif kind == "rrect":
            box, radius = payload
            md.rounded_rectangle(box, radius=radius, fill=value)
        else:
            raise ValueError(kind)


def box(x, y, w, h):
    return [x, y, x + w, y + h]


def draw_glyph(well: Well, kind: str, proposed: bool):
    x, y, w, h = well.r
    mx, my = x + w / 2, y + h / 2
    p = proposed

    if kind == "voltageDrop":
        yy = y + h * 0.28
        left, right = (x + w * 0.16, yy), (x + w - w * 0.16, yy)
        well.line((x, yy), left, p)
        well.polyline(quad(left, (mx, y + h * 0.82), right), p)
        well.line(right, (x + w, yy), p)
        well.line(left, (left[0], y + h - h * 0.06), p)
        well.line(right, (right[0], y + h - h * 0.06), p)
        return

    if kind == "ohmsLaw":
        c = (mx, my - h * 0.06)
        rad = min(w, h) * 0.36
        well.arc([c[0] - rad, c[1] - rad, c[0] + rad, c[1] + rad], 205, 335, p)
        left = (c[0] + math.cos(math.radians(205)) * rad, c[1] + math.sin(math.radians(205)) * rad)
        right = (c[0] + math.cos(math.radians(335)) * rad, c[1] + math.sin(math.radians(335)) * rad)
        foot = y + h - h * 0.10
        well.line(left, (left[0] - w * 0.02, foot), p)
        well.line((left[0] - w * 0.08, foot), (left[0] + w * 0.10, foot), p)
        well.line(right, (right[0] + w * 0.02, foot), p)
        well.line((right[0] - w * 0.10, foot), (right[0] + w * 0.08, foot), p)
        return

    if kind == "wifiStatus":
        slab = [x + w * 0.20, y + h - h * 0.24, x + w * 0.80, y + h - h * 0.08]
        if p:
            well.fill_mask([("rrect", (slab, (slab[3] - slab[1]) * 0.45))])
        else:
            well.rrect_stroke(slab, (slab[3] - slab[1]) * 0.45, p)
            well.line((x + w * 0.35, (slab[1] + slab[3]) / 2), (x + w * 0.47, (slab[1] + slab[3]) / 2), p)
        origin = (mx, slab[1])
        for i in (1, 2):
            rad = w * 0.24 * i
            well.arc([origin[0] - rad, origin[1] - rad, origin[0] + rad, origin[1] + rad], 210, 330, p)
        return

    if kind == "wireAmpacity":
        sleeve = [x + w * 0.16, y + h * 0.16, x + w * 0.84, y + h * 0.84]
        if not p:
            well.rrect_stroke(sleeve, (sleeve[3] - sleeve[1]) * 0.18, False)
            for i in range(3):
                yy = sleeve[1] + (sleeve[3] - sleeve[1]) * (0.28 + 0.22 * i)
                well.line((x + w * 0.06, yy), (x + w * 0.94, yy), False)
            return
        sh = max(2.4, (sleeve[3] - sleeve[1]) * 0.11)
        sw = (sleeve[2] - sleeve[0]) * 0.56
        holes = []
        for i in range(3):
            yy = sleeve[1] + (sleeve[3] - sleeve[1]) * (0.26 + 0.24 * i) - sh / 2
            holes.append(("rrect", ([mx - sw / 2, yy, mx + sw / 2, yy + sh], sh / 2)))
        well.fill_mask([("rrect", (sleeve, (sleeve[3] - sleeve[1]) * 0.18))], holes)
        return

    if kind == "motorFLA":
        can = [x + w * 0.08, y + h * 0.24, x + w * 0.70, y + h * 0.72]
        if not p:
            well.rrect_stroke(can, (can[3] - can[1]) * 0.22, False)
            well.ellipse_stroke(
                [can[0] - w * 0.04, can[1] + (can[3] - can[1]) * 0.12, can[0] + w * 0.12, can[3] - (can[3] - can[1]) * 0.12],
                False,
            )
            well.line((can[2], (can[1] + can[3]) / 2), (x + w - w * 0.06, (can[1] + can[3]) / 2), False)
            return
        ch = can[3] - can[1]
        bell_c = (can[0] + ch * 0.22, (can[1] + can[3]) / 2)
        br = ch * 0.22
        well.fill_mask(
            [("rrect", (can, ch * 0.22))],
            [("ellipse", [bell_c[0] - br, bell_c[1] - br, bell_c[0] + br, bell_c[1] + br])],
        )
        well.line((can[2], (can[1] + can[3]) / 2), (x + w - w * 0.06, (can[1] + can[3]) / 2), True)
        return

    if kind == "receptacleSelector":
        face = [x + w * 0.10, y + h * 0.08, x + w * 0.90, y + h * 0.92]
        fw, fh = face[2] - face[0], face[3] - face[1]
        fmx = (face[0] + face[2]) / 2
        if not p:
            well.rrect_stroke(face, 5 * well.scale, False)
            slot_h = fh * 0.28
            slot_y = face[1] + fh * 0.28
            well.line((fmx - fw * 0.18, slot_y), (fmx - fw * 0.18, slot_y + slot_h), False)
            well.line((fmx + fw * 0.18, slot_y), (fmx + fw * 0.18, slot_y + slot_h), False)
            gr = fw * 0.07
            gy = face[3] - fh * 0.22
            well.ellipse_stroke([fmx - gr, gy - gr, fmx + gr, gy + gr], False)
            return
        slot_h = fh * 0.28
        slot_w = max(2.6, fw * 0.11)
        slot_y = face[1] + fh * 0.28
        gr = fw * 0.09
        gy = face[3] - fh * 0.22
        holes = [
            ("rrect", ([fmx - fw * 0.18 - slot_w / 2, slot_y, fmx - fw * 0.18 + slot_w / 2, slot_y + slot_h], slot_w / 2)),
            ("rrect", ([fmx + fw * 0.18 - slot_w / 2, slot_y, fmx + fw * 0.18 + slot_w / 2, slot_y + slot_h], slot_w / 2)),
            ("ellipse", [fmx - gr, gy - gr, fmx + gr, gy + gr]),
        ]
        well.fill_mask([("rrect", (face, 5 * well.scale))], holes)
        return

    if kind == "conduitFill":
        outer = min(w, h) * 0.46
        if not p:
            well.ellipse_stroke([mx - outer, my - outer, mx + outer, my + outer], False)
            ir = outer * 0.28
            ic = (mx, my + outer * 0.22)
            well.ellipse_stroke([ic[0] - ir, ic[1] - ir, ic[0] + ir, ic[1] + ir], False)
            well.line((mx - outer * 0.72, my - outer * 0.18), (mx + outer * 0.72, my - outer * 0.18), False)
            return
        hole = outer * 0.62
        cr = outer * 0.24
        cc = (mx, my + outer * 0.14)
        well.fill_mask(
            [("ellipse", [mx - outer, my - outer, mx + outer, my + outer])],
            [("ellipse", [mx - hole, my - hole, mx + hole, my + hole])],
        )
        well.fill_mask([("ellipse", [cc[0] - cr, cc[1] - cr, cc[0] + cr, cc[1] + cr])])
        return

    if kind == "power":
        pts = bolt((x, y, w, h))
        if p:
            well.fill_mask([("poly", pts)])
        else:
            well.polyline(pts, False, closed=True)
        return

    if kind == "necCircuit":
        panel = [x + w * 0.12, y + h * 0.08, x + w * 0.88, y + h * 0.92]
        pw, ph = panel[2] - panel[0], panel[3] - panel[1]
        if not p:
            well.rrect_stroke(panel, 4 * well.scale, False)
            for i in range(3):
                yy = panel[1] + ph * (0.28 + 0.22 * i)
                well.line((panel[0] + pw * 0.18, yy), (panel[2] - pw * 0.18, yy), False)
            return
        sh = max(2.4, ph * 0.10)
        sw = pw * 0.64
        holes = []
        for i in range(3):
            yy = panel[1] + ph * (0.26 + 0.22 * i) - sh / 2
            holes.append(("rrect", ([mx - sw / 2, yy, mx + sw / 2, yy + sh], sh / 2)))
        well.fill_mask([("rrect", (panel, 4 * well.scale))], holes)
        return

    if kind == "batteryBank":
        body = [x + w * 0.08, y + h * 0.26, x + w * 0.80, y + h * 0.74]
        bw, bh = body[2] - body[0], body[3] - body[1]
        nub = [body[2], (body[1] + body[3]) / 2 - h * 0.10, body[2] + w * 0.10, (body[1] + body[3]) / 2 + h * 0.10]
        if not p:
            well.rrect_stroke(body, 3 * well.scale, False)
            well.rrect_stroke(nub, 1.5 * well.scale, False)
            well.line((body[0] + bw * 0.33, body[1] + 3), (body[0] + bw * 0.33, body[3] - 3), False)
            well.line((body[0] + bw * 0.66, body[1] + 3), (body[0] + bw * 0.66, body[3] - 3), False)
            return
        gap_w = max(2.2, bw * 0.08)
        gap_h = bh * 0.62
        gy = (body[1] + body[3]) / 2 - gap_h / 2
        holes = [
            ("rrect", ([body[0] + bw * 0.30 - gap_w / 2, gy, body[0] + bw * 0.30 + gap_w / 2, gy + gap_h], gap_w / 2)),
            ("rrect", ([body[0] + bw * 0.62 - gap_w / 2, gy, body[0] + bw * 0.62 + gap_w / 2, gy + gap_h], gap_w / 2)),
        ]
        well.fill_mask(
            [("rrect", (body, 3 * well.scale)), ("rrect", (nub, 1.5 * well.scale))],
            holes,
        )
        return

    if kind == "upsSizing":
        body = [x + w * 0.16, y + h * 0.32, x + w * 0.68, y + h * 0.72]
        bw, bh = body[2] - body[0], body[3] - body[1]
        nub = [body[2], (body[1] + body[3]) / 2 - h * 0.08, body[2] + w * 0.08, (body[1] + body[3]) / 2 + h * 0.08]
        if not p:
            well.rrect_stroke(body, 3 * well.scale, False)
            well.stroke_draw().rectangle(nub, outline=well.color, width=well.lw(False))
            rad = w * 0.28
            c = (x + w - w * 0.22, y + h * 0.28)
            well.arc([c[0] - rad, c[1] - rad, c[0] + rad, c[1] + rad], 210, 330, False)
            return
        gap_w = max(2.2, bw * 0.12)
        gap_h = bh * 0.58
        well.fill_mask(
            [("rrect", (body, 3 * well.scale)), ("rrect", (nub, 1.5 * well.scale))],
            [("rrect", ([mx - gap_w / 2, (body[1] + body[3]) / 2 - gap_h / 2, mx + gap_w / 2, (body[1] + body[3]) / 2 + gap_h / 2], gap_w / 2))],
        )
        rad = w * 0.28
        c = (x + w - w * 0.22, y + h * 0.28)
        well.arc([c[0] - rad, c[1] - rad, c[0] + rad, c[1] + rad], 210, 330, True)
        return

    if kind == "eBikePackDesigner":
        pack = [x + w * 0.10, y + h * 0.16, x + w * 0.90, y + h * 0.84]
        pw, ph = pack[2] - pack[0], pack[3] - pack[1]
        if not p:
            well.rrect_stroke(pack, 4 * well.scale, False)
            well.line((mx, pack[1]), (mx, pack[3]), False)
            well.line((pack[0], pack[1] + ph / 3), (pack[2], pack[1] + ph / 3), False)
            well.line((pack[0], pack[1] + ph * 2 / 3), (pack[2], pack[1] + ph * 2 / 3), False)
            return
        inset_x, inset_y = pw * 0.10, ph * 0.10
        gap_x, gap_y = pw * 0.08, ph * 0.07
        cell_w = (pw - inset_x * 2 - gap_x) / 2
        cell_h = (ph - inset_y * 2 - gap_y * 2) / 3
        holes = []
        for row in range(3):
            for col in range(2):
                cx = pack[0] + inset_x + col * (cell_w + gap_x)
                cy = pack[1] + inset_y + row * (cell_h + gap_y)
                holes.append(("rrect", ([cx, cy, cx + cell_w, cy + cell_h], 2 * well.scale)))
        well.fill_mask([("rrect", (pack, 4 * well.scale))], holes)
        return

    if kind == "shortCircuit":
        block = [x + w * 0.28, y + h * 0.38, x + w * 0.72, y + h * 0.82]
        if p:
            well.fill_mask([("rrect", (block, 3 * well.scale))])
        else:
            well.rrect_stroke(block, 3 * well.scale, False)
        well.line((mx, y + h * 0.08), (mx, block[1]), p)
        well.polyline([(mx - w * 0.14, y + h * 0.22), (mx, y + h * 0.10), (mx + w * 0.14, y + h * 0.22)], p)
        return

    if kind == "motorNameplate":
        plate = [x + w * 0.10, y + h * 0.18, x + w * 0.90, y + h * 0.82]
        pw, ph = plate[2] - plate[0], plate[3] - plate[1]
        if not p:
            well.rrect_stroke(plate, 4 * well.scale, False)
            well.line((plate[0] + pw * 0.16, plate[1] + ph * 0.38), (plate[2] - pw * 0.16, plate[1] + ph * 0.38), False)
            well.line((plate[0] + pw * 0.16, plate[1] + ph * 0.62), (plate[2] - pw * 0.28, plate[1] + ph * 0.62), False)
            return
        sh = max(2.0, ph * 0.10)
        holes = [
            ("rrect", ([plate[0] + pw * 0.16, plate[1] + ph * 0.38 - sh / 2, plate[2] - pw * 0.16, plate[1] + ph * 0.38 + sh / 2], sh / 2)),
            ("rrect", ([plate[0] + pw * 0.16, plate[1] + ph * 0.62 - sh / 2, plate[2] - pw * 0.28, plate[1] + ph * 0.62 + sh / 2], sh / 2)),
        ]
        well.fill_mask([("rrect", (plate, 4 * well.scale))], holes)
        return

    if kind == "lookCheck":
        top = quad((x + w * 0.06, my), (mx, y + h * 0.08), (x + w * 0.94, my))
        bot = quad((x + w * 0.94, my), (mx, y + h * 0.92), (x + w * 0.06, my))
        eye = top + bot[1:]
        if not p:
            well.polyline(eye, False, closed=True)
            pr = w * 0.14
            well.ellipse_stroke([mx - pr, my - pr, mx + pr, my + pr], False)
            return
        pr = w * 0.14
        well.fill_mask([("poly", eye)], [("ellipse", [mx - pr, my - pr, mx + pr, my + pr])])
        return

    if kind == "heaterDesign":
        boxr = [x + w * 0.08, y + h * 0.18, x + w * 0.92, y + h * 0.82]
        bw, bh = boxr[2] - boxr[0], boxr[3] - boxr[1]
        yy = (boxr[1] + boxr[3]) / 2
        zig = [
            (boxr[0] + bw * 0.12, yy),
            (boxr[0] + bw * 0.32, yy - bh * 0.28),
            (boxr[0] + bw * 0.52, yy + bh * 0.28),
            (boxr[0] + bw * 0.72, yy - bh * 0.28),
            (boxr[2] - bw * 0.12, yy),
        ]
        if not p:
            well.rrect_stroke(boxr, 3 * well.scale, False)
            well.polyline(zig, False)
            return
        hole = ribbon(zig, max(2.4, bh * 0.12))
        well.fill_mask([("rrect", (boxr, 3 * well.scale))], [("poly", hole)])
        return

    if kind == "solenoidDesign":
        body = [x + w * 0.08, y + h * 0.22, x + w * 0.66, y + h * 0.78]
        if p:
            well.fill_mask([("rrect", (body, 4 * well.scale))])
        else:
            well.rrect_stroke(body, 4 * well.scale, False)
        mid = (body[1] + body[3]) / 2
        well.line((body[2], mid), (x + w - w * 0.06, mid), p)
        well.line((x + w - w * 0.18, mid - h * 0.12), (x + w - w * 0.18, mid + h * 0.12), p)
        return

    if kind == "analogWorkbench":
        left = x + w * 0.22
        tri = [(left, y + h * 0.12), (x + w - w * 0.10, my), (left, y + h * 0.88)]
        if not p:
            well.polyline(tri, False, closed=True)
            well.line((x, y + h * 0.30), (left, y + h * 0.30), False)
            well.line((x, y + h * 0.70), (left, y + h * 0.70), False)
            well.line((x + w - w * 0.10, my), (x + w, my), False)
            return
        well.fill_mask([("poly", tri)])
        well.line((x, y + h * 0.30), (left, y + h * 0.30), True)
        well.line((x, y + h * 0.70), (left, y + h * 0.70), True)
        well.line((x + w - w * 0.10, my), (x + w, my), True)
        return

    raise KeyError(kind)


def row(im, title, items, y, well_size, circular, proposed, scale, label_font, title_font):
    d = ImageDraw.Draw(im)
    d.text((48 * scale, y), title, font=title_font, fill=FG)
    y += int(36 * scale)
    gap = int(18 * scale)
    x = 48 * scale
    caption_font = load_font(int(11 * scale))
    for kind, label, cat, _shelf in items:
        well = Well(im, x, y, well_size, CAT[cat], circular, scale)
        draw_glyph(well, kind, proposed)
        tw = caption_font.getlength(label)
        d.text((x + well_size / 2 - tw / 2, y + well_size + 8 * scale), label, font=caption_font, fill=MUTED)
        x += well_size + gap
    return y + well_size + int(34 * scale)


def render(out: Path):
    scale = 3
    width = 1100 * scale
    height = 1680 * scale
    im = Image.new("RGB", (width, height), BG)
    title_font = load_font(int(18 * scale), bold=True)
    section_font = load_font(int(14 * scale), bold=True)
    note_font = load_font(int(11 * scale))

    d = ImageDraw.Draw(im)
    d.text(
        (48 * scale, 36 * scale),
        "Beckify ToolGlyph — App Design visual pass 2026-09-15",
        font=title_font,
        fill=FG,
    )
    d.text(
        (48 * scale, 64 * scale),
        "Overturns #151 stroke-only. A/B = current hollow wireframes. C/D = solid fill + even-odd holes (open marks stay stroke ~3.2 @44).",
        font=note_font,
        fill=MUTED,
    )
    d.text(
        (48 * scale, 84 * scale),
        "Ink = real shelf primary (Jobsite copper, Instruments magenta, Power teal, Bench green). Linux raster of Swift geometry — App Design must re-check on device before merge.",
        font=note_font,
        fill=MUTED,
    )

    quick = [g for g in GLYPHS if g[3] == "quick"]
    sheet11 = quick + [
        next(g for g in GLYPHS if g[0] == "ohmsLaw"),
        next(g for g in GLYPHS if g[0] == "power"),
        next(g for g in GLYPHS if g[0] == "necCircuit"),
        next(g for g in GLYPHS if g[0] == "batteryBank"),
        next(g for g in GLYPHS if g[0] == "eBikePackDesigner"),
    ]
    jobsite = [g for g in GLYPHS if g[0] in ("necCircuit", "shortCircuit", "motorNameplate", "lookCheck")]
    bench = [g for g in GLYPHS if g[0] in ("heaterDesign", "eBikePackDesigner", "solenoidDesign", "analogWorkbench", "upsSizing")]

    y = 120 * scale
    y = row(im, "A  CURRENT  —  stroke-only Quick ~52 (circles)", sheet11, y, 52 * scale, True, False, scale, note_font, section_font)
    y += 18 * scale
    y = row(im, "B  CURRENT  —  stroke-only grid ~72", sheet11, y, 72 * scale, False, False, scale, note_font, section_font)
    y += 22 * scale
    y = row(im, "C  PROPOSED  —  solid fill + even-odd holes  ·  Quick ~52", sheet11, y, 52 * scale, True, True, scale, note_font, section_font)
    y += 18 * scale
    y = row(im, "D  PROPOSED  —  same marks at grid ~72", sheet11, y, 72 * scale, False, True, scale, note_font, section_font)
    y += 28 * scale
    y = row(im, "E  Jobsite metaphors  —  CURRENT stroke  ~72", jobsite, y, 72 * scale, False, False, scale, note_font, section_font)
    y += 12 * scale
    y = row(im, "F  Jobsite metaphors  —  PROPOSED fill+holes  ~72", jobsite, y, 72 * scale, False, True, scale, note_font, section_font)
    y += 28 * scale
    y = row(im, "G  Bench / UPS metaphors  —  CURRENT stroke  ~72", bench, y, 72 * scale, False, False, scale, note_font, section_font)
    y += 12 * scale
    y = row(im, "H  Bench / UPS metaphors  —  PROPOSED fill+holes  ~72", bench, y, 72 * scale, False, True, scale, note_font, section_font)

    # Crop unused bottom
    im = im.crop((0, 0, width, min(height, y + 40 * scale)))
    im = im.filter(ImageFilter.UnsharpMask(radius=0.6, percent=40, threshold=2))
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out, "PNG", optimize=True)
    print(f"wrote {out} {im.size}")


if __name__ == "__main__":
    repo = Path(__file__).resolve().parents[2]
    render(repo / "ios/docs/glyph-visual-pass-2026-09-15.png")
