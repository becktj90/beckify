# Crew Talk pixel sprites

Pre-made animations for the Crew Talk helpers. Nothing is generated in the app.

- `extract_base.py` — one-time: cuts each painted portrait (and its talk pose) out of its navy background into a 96×96, 24-color pixel base under `base/`. Hand-edit the bases after this; don't re-run unless a portrait changes.
- `build_sprites.py` — exports, per helper, `Beckify/Assets.xcassets/<portrait>Sheet.imageset` (8-column PNG sheet) and `<portrait>SheetTiming.dataset` (JSON frame timing). Animations: `idle` (loop), `talk` (4 mouth shapes, loop), `gesture`, `intro`, `outro`. Mouth pixels are hand-placed in `MOUTH`.

```sh
python3 -m venv .venv && .venv/bin/pip install pillow numpy scipy
.venv/bin/python ios/Art/CrewTalk/build_sprites.py --preview /tmp/crewtalk-preview
```

Same layout an Aseprite `--sheet --data` export would give (grid PNG + frame/tag JSON), so frames can be cleaned up in Aseprite later and re-exported to the same names. Timing is read by `CrewSpriteSheetSpec` / `CrewClipTimeline` in BeckifyMath.
