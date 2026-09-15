# Kestrel Heavy — engine lock

**Phaser `4.2.1` + built-in Matter only.** Do not swap in Babylon, Three, Unity, or `phaser-arcade-physics`.

| Pin | Source |
| --- | --- |
| npm | `"phaser": "4.2.1"` in `artifacts/beckify/package.json` |
| Vendor | `vendor/phaser.min.js` — official **full** UMD build (includes Matter) |
| jsDelivr equivalent | `https://cdn.jsdelivr.net/npm/phaser@4.2.1/dist/phaser.min.js` |
| Refresh | `node artifacts/beckify/scripts/sync-phaser.mjs` |

The arcade iframe CSP is `script-src 'self'`. Load the vendor file same-origin. Never put a Phaser CDN tag in `index.html`.

iOS App Store shell: `ios/KestrelHeavy/` packs this directory via `ios/scripts/pack_kestrelheavy_game.py` (scheme **KestrelHeavy**, bundle `com.beckify.kestrelheavy`). Re-pack after arcade changes. Toolbox Archive / Xcode Cloud stays on scheme **Beckify**.

## Game config (required)

```js
type: Phaser.WEBGL, // AUTO only if WebGL is missing on the device
physics: {
  default: 'matter',
  matter: {
    gravity: { x: 0, y: /* arcade-tuned, ~0.85 */ },
    enableSleeping: true, // settled deck / pad bodies
    debug: false,         // true only behind ?debug=1
  },
},
scale: { mode: Phaser.Scale.ENVELOP, autoCenter: Phaser.Scale.CENTER_BOTH }, // FIT letterboxes; ENVELOP fills
```

Create bodies with `this.matter.add.sprite` / `image` / `rectangle`. Do **not** construct a standalone `Matter.Engine` outside Phaser.

## Matter gotchas we respect

- Forces are tiny (`0.01–0.1`). Velocities are about `1–15` per step — not pixels/sec.
- Matter positions are **center of mass**, not top-left.
- `setBody` / `setRectangle` wipe mass, friction, and collision filters — re-apply after any reshape.
- Pause with `this.matter.pause()` / `this.matter.resume()` (delegates to the Phaser Matter world). Physics pauses only when `paused === true`.
- Collision categories + sensors: deck paint and water are sensors (water is not a solid floor). Pickups and hazards are sensors.
- Haven recovery (arcade-compressed): **reentry pitch-over** → **strakes deployed** → diagonal **glide** (descent max-Q) → player **landing burn** → RCS straighten (`landingVy` + `landingTol`). Solid black strakes, not lattice grid fins. No A-frame legs or ASDS circle-X.
- After SEPARATE the camera stays on the booster. SES-1 and fairing jettison play as off-booster beats, then Haven.
- Mobile climb pad is one-thumb: **hold to climb/burn**, **drag left/right to steer**. Keyboard Space + A/D is unchanged. Optional ◀ ▶ pads stay as a second-finger path.
- Ascent camera uses `CAM.lookAheadY` so incoming corridor junk sits on-screen under the HUD. Hazard sprites carry an amber halo for phone contrast.
- Ascent dotted rails are the **flight corridor** (Phaser graphics, not sky decoration). Stay between them or abort; KID is bounced back inside.
- MECO → stage sep is a playable beat (`SEP` status) in a marked **SEP ZONE** with an on-screen **SEPARATE** button. Camera stays locked on the stack. It is not a 400ms cutscene.

## QA beats

Append to the cabinet URL (iframe `src` or standalone `index.html`):

| Flag | Starts at |
| --- | --- |
| `?beat=haven` | Zoomed-out Haven approach |
| `?beat=jacklyn` | Same as `haven` (legacy alias) |
| `?beat=sep` | MECO / stage-sep window |
| `?debug=1` | Matter debug outlines |

Looping BGM is the Suno instrumental “Kestrel Heavy” (`audio/theme.ogg` / `.mp3`), started on launch via `AudioApi.setTheme`. Mute / SOUND / Music settings apply. Theme volume stays under SFX; critical callouts duck it.

## Old canvas path

`index.html` sets `data-ng-engine="phaser4"` and mounts `#ng-phaser-root`. If `public/toolbox/js/arcade.js` is ever included, `init()` returns immediately so the 420×640 canvas path cannot fight Phaser.

## Stage

Internal resolution is **1280×720**. The React embed (`KestrelHeavy.tsx`) is `aspect-video` (16:9) max 1280. Phaser `Scale.ENVELOP` + `CENTER_BOTH` covers the parent (FIT letterboxes on 16:10 / DevTools). The cabinet parent is 100% of the iframe so chrome does not steal the playfield. Do not use `Scale.RESIZE` for the Matter world.
