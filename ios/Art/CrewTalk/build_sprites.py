"""Crew Talk sprite pipeline (Python/Pillow; same outputs an Aseprite CLI export would give).

Reads Art/CrewTalk/base/<asset>.png and <asset>Talk.png (96x96 pixel bases made by extract_base.py)
and writes, per character, into Beckify/Assets.xcassets:
  <asset>Sheet.imageset/<asset>Sheet.png   frames on a grid, 96x96 each, nearest-neighbor only
  <asset>Sheet.dataset/<asset>Sheet.json   frame timing: {frameSize, columns, animations{name:{frames,fps,loop}}}
Animations: idle, talk (4 mouth shapes), gesture, intro, outro.
Run:  python3 Art/CrewTalk/build_sprites.py [--preview DIR]
"""
from PIL import Image, ImageDraw
import json, pathlib, sys
HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
XC = ROOT / "Beckify/Assets.xcassets"
S = 96
COLUMNS = 8
CREW = ["crewBodieHale", "crewTitoSolano", "crewLupitaReyes", "crewJuniePell", "crewPearl", "crewSloaneMerritt"]
CYAN = (64, 224, 255, 255)
# Hand-placed mouth pixel (x, y) on each 96x96 base and talk pose. Edit here if a base is redrawn.
MOUTH = {
    "crewBodieHale": ((47, 20), (46, 19)),
    "crewTitoSolano": ((47, 16), (46, 20)),
    "crewLupitaReyes": ((47, 21), (48, 22)),
    "crewJuniePell": ((45, 25), (49, 25)),
    "crewPearl": ((47, 16), (47, 17)),
    "crewSloaneMerritt": ((48, 16), (46, 16)),
}
MOUTH_DARK = (46, 14, 18, 255)
MOUTH_IN = (150, 52, 58, 255)

def is_skin(p):
    r, g, b, a = p
    return a > 0 and r > 120 and r > g + 12 and g > b and r - b > 40

def mouth_point(im):
    """Mouth sits about 80% down the face. The face is the skin blob in the top quarter."""
    px = im.load()
    pts = [(x, y) for y in range(4, S // 3) for x in range(S) if is_skin(px[x, y])]
    rows = sorted({y for _, y in pts})
    top = rows[0]
    # The face ends where skin narrows into the neck: stop at the first row after top+6 with < 3 skin px.
    widths = {y: sum(1 for _, yy in pts if yy == y) for y in rows}
    bottom = top
    for y in range(top, top + 18):
        if widths.get(y, 0) >= 3 or y < top + 6:
            bottom = y
        else:
            break
    xs = [x for x, y in pts if top <= y <= bottom]
    cx = round(sum(xs) / len(xs))
    return cx, top + round((bottom - top) * 0.80)

def mouth(im, pt, shape):
    out = im.copy(); d = ImageDraw.Draw(out); x, y = pt
    if shape == 1:
        d.rectangle([x - 1, y, x, y], fill=MOUTH_DARK)
    elif shape == 2:
        d.rectangle([x - 1, y, x + 1, y + 1], fill=MOUTH_DARK); d.point((x, y + 1), fill=MOUTH_IN)
    elif shape == 3:
        d.rectangle([x - 2, y, x + 1, y + 1], fill=MOUTH_DARK); d.line([x - 1, y + 1, x, y + 1], fill=MOUTH_IN)
    return out

def shifted(im, dy=0, split=None):
    """Move the whole sprite (split=None) or just the part above row `split` by dy pixels."""
    out = Image.new("RGBA", im.size)
    if split is None:
        out.alpha_composite(im, (0, dy)); return out
    out.alpha_composite(im.crop((0, split, S, S)), (0, split))
    out.alpha_composite(im.crop((0, 0, S, split)), (0, dy))
    return out

def blink(im, pt):
    """Close the eyes: a skin-tone line across the eye row, two rows above... about 45% down the face."""
    out = im.copy(); px = out.load(); x, y = pt
    ey = y - 5
    for xx in range(x - 4, x + 5):
        p = px[xx, ey]
        if p[3] and sum(p[:3]) < 260:  # dark eye pixels only
            px[xx, ey] = px[xx, ey - 1] if is_skin(px[xx, ey - 1]) else p
    return out

def beam(im, rows_visible):
    """Retro scan-in: rows from the bottom up are visible; a cyan scanline rides the edge."""
    out = Image.new("RGBA", im.size)
    top = S - rows_visible
    if rows_visible > 0:
        out.alpha_composite(im.crop((0, top, S, S)), (0, top))
    bbox = im.getbbox()
    if 0 < rows_visible < S and bbox:
        d = ImageDraw.Draw(out)
        d.line([bbox[0] - 2, top, bbox[2] + 1, top], fill=CYAN)
    return out

def frames_for(name):
    base = Image.open(HERE / "base" / f"{name}.png").convert("RGBA")
    talk = Image.open(HERE / "base" / f"{name}Talk.png").convert("RGBA")
    mp, mpt = MOUTH[name]
    waist = mp[1] + 26
    frames, anims = [], {}
    def add(key, imgs, fps, loop):
        start = len(frames); frames.extend(imgs)
        anims[key] = {"frames": list(range(start, start + len(imgs))), "fps": fps, "loop": loop}
    add("idle", [base, base, shifted(base, 1, waist), shifted(base, 1, waist), blink(shifted(base, 1, waist), (mp[0], mp[1] + 1)), base], 5, True)
    add("talk", [mouth(base, mp, 0), mouth(base, mp, 2), shifted(mouth(base, mp, 3), -1), mouth(base, mp, 1)], 10, True)
    add("gesture", [mouth(talk, mpt, 2), shifted(mouth(talk, mpt, 3), -2), shifted(mouth(talk, mpt, 3), -1), mouth(talk, mpt, 1)], 8, False)
    add("intro", [beam(base, r) for r in (0, 16, 36, 56, 76, 96)], 12, False)
    add("outro", [beam(base, r) for r in (96, 72, 48, 24, 8, 0)], 12, False)
    return frames, anims

def sheet(frames):
    rows = (len(frames) + COLUMNS - 1) // COLUMNS
    out = Image.new("RGBA", (COLUMNS * S, rows * S))
    for i, f in enumerate(frames):
        out.alpha_composite(f, ((i % COLUMNS) * S, (i // COLUMNS) * S))
    return out

def write_catalog(name, img, spec):
    iset = XC / f"{name}Sheet.imageset"; iset.mkdir(exist_ok=True)
    img.save(iset / f"{name}Sheet.png", optimize=True)
    (iset / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}Sheet.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": False, "template-rendering-intent": "original"},
    }, indent=2) + "\n")
    dset = XC / f"{name}Sheet.dataset"; dset.mkdir(exist_ok=True)
    (dset / f"{name}Sheet.json").write_text(json.dumps(spec, indent=2) + "\n")
    (dset / "Contents.json").write_text(json.dumps({
        "data": [{"filename": f"{name}Sheet.json", "idiom": "universal", "universal-type-identifier": "public.json"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")

def main():
    preview = None
    if "--preview" in sys.argv:
        preview = pathlib.Path(sys.argv[sys.argv.index("--preview") + 1]); preview.mkdir(parents=True, exist_ok=True)
    rows = []
    for name in CREW:
        frames, anims = frames_for(name)
        spec = {"frameSize": S, "columns": COLUMNS, "frameCount": len(frames), "animations": anims}
        img = sheet(frames)
        write_catalog(name, img, spec)
        rows.append((name, frames))
        print(f"{name}: {len(frames)} frames, sheet {img.size}")
    if preview:
        n = max(len(f) for _, f in rows)
        cs = Image.new("RGBA", (n * S, len(rows) * S), (11, 19, 40, 255))
        d = ImageDraw.Draw(cs)
        for r, (_, frames) in enumerate(rows):
            for c, f in enumerate(frames):
                cs.alpha_composite(f, (c * S, r * S))
                d.rectangle([c * S, r * S, c * S + S - 1, r * S + S - 1], outline=(28, 44, 80, 255))
        cs.resize((cs.width * 2, cs.height * 2), Image.Resampling.NEAREST).save(preview / "contact-sheet.png")

if __name__ == "__main__":
    main()
