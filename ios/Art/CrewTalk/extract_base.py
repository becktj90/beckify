"""Step 1 of the Crew Talk pixel pipeline: turn the painted portraits into small pixel bases.
Writes Art/CrewTalk/base/<asset>.png (96x96, transparent, <=24 colors). Run once; hand-edit bases afterwards."""
from PIL import Image, ImageFilter
import pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]
XC = ROOT / "Beckify/Assets.xcassets"
OUT = pathlib.Path(__file__).parent / "base"
SIZE = 96
# Sloane wears navy on navy, so her edge test has to be finer.
THRESH = {"crewSloaneMerritt": 5}
def load(name):
    d = XC / f"{name}.imageset"
    if not d.exists():  # portrait not on this branch yet: CREW_PORTRAIT_DIR=/path/with/<name>.jpg
        import os
        d = pathlib.Path(os.environ.get("CREW_PORTRAIT_DIR", d))
        return Image.open(next(p for p in d.iterdir() if p.stem == name)).convert("RGB")
    return Image.open(next(p for p in d.iterdir() if p.suffix in (".png", ".jpg"))).convert("RGB")
def mask(im, thr=26):
    # Background is a smooth navy gradient. Estimate it per row from the empty side margins,
    # then keep everything that differs from it, and fill interior holes.
    import numpy as np
    from scipy import ndimage
    a = np.asarray(im).astype(int)
    h, w, _ = a.shape
    side = np.concatenate([a[:, :160], a[:, -160:]], axis=1)
    rowbg = np.median(side, axis=1)[:, None, :]
    d = np.abs(a - rowbg).sum(axis=2)
    m = d > thr
    if thr >= 10:
        m = ndimage.binary_opening(m, iterations=2)
    lab, n = ndimage.label(m)
    if n:
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        m = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 400])
    m = ndimage.binary_closing(m, iterations=4 if thr >= 10 else 9)
    m = ndimage.binary_fill_holes(m)
    return Image.fromarray((m * 255).astype("uint8"))
def base(name, box=None, thr=26):
    im = load(name); m = mask(im, thr)
    bbox = box or m.getbbox()
    l, t, r, b = bbox
    # square crop centered on the figure, padded
    hgt = (b - t) * 1.04; cx = (l + r) / 2
    sq = (int(cx - hgt / 2), int(b - hgt), int(cx + hgt / 2), int(b + 2))
    rgb = im.crop(sq).resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    a = m.crop(sq).resize((SIZE, SIZE), Image.Resampling.BOX).point(lambda v: 255 if v > 110 else 0)
    if thr < 10:
        # Flat background shared with the outfit fill: lift that fill a shade so the figure reads on navy.
        import numpy as np
        ra = np.asarray(rgb).astype(int)
        flat = np.abs(ra - ra[0, 0]).sum(axis=2) < 10
        ra[flat] = (34, 58, 108)
        rgb = Image.fromarray(ra.astype("uint8"))
    q = rgb.quantize(colors=24, method=Image.Quantize.MEDIANCUT).convert("RGB")
    out = q.convert("RGBA"); out.putalpha(a)
    return out, bbox
if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    only = sys.argv[1:]
    for n in ["crewBodieHale","crewTitoSolano","crewLupitaReyes","crewJuniePell","crewPearl","crewSloaneMerritt","crewDreLacey","crewHumbertoArismendi"]:
        if only and n not in only:
            continue
        thr = THRESH.get(n, 26)
        b, bbox = base(n, None, thr); b.save(OUT / f"{n}.png")
        t, _ = base(n + "Talk", bbox, thr); t.save(OUT / f"{n}Talk.png")
        print(n, bbox)
