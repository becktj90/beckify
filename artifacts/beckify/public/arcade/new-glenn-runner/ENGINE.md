# New Glenn Runner — engine lock

**Phaser `4.2.1` + built-in Matter only.** Do not swap in Babylon, Three, Unity, or `phaser-arcade-physics`.

| Pin | Source |
| --- | --- |
| npm | `"phaser": "4.2.1"` in `artifacts/beckify/package.json` |
| Vendor | `vendor/phaser.min.js` — official **full** UMD build (includes Matter) |
| jsDelivr equivalent | `https://cdn.jsdelivr.net/npm/phaser@4.2.1/dist/phaser.min.js` |
| Refresh | `node artifacts/beckify/scripts/sync-phaser.mjs` |

The arcade iframe CSP is `script-src 'self'`. Load the vendor file same-origin. Never put a Phaser CDN tag in `index.html`.

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
scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
```

Create bodies with `this.matter.add.sprite` / `image` / `rectangle`. Do **not** construct a standalone `Matter.Engine` outside Phaser.

## Matter gotchas we respect

- Forces are tiny (`0.01–0.1`). Velocities are about `1–15` per step — not pixels/sec.
- Matter positions are **center of mass**, not top-left.
- `setBody` / `setRectangle` wipe mass, friction, and collision filters — re-apply after any reshape.
- Pause with `this.matter.pause()` / `this.matter.resume()` (delegates to the Phaser Matter world). Physics pauses only when `paused === true`.
- Collision categories + sensors: deck paint and water are sensors (water is not a solid floor). Pickups and hazards are sensors.
- Jacklyn is a diagonal slide-in, then RCS straighten, then a soft-land velocity check (`landingVy`). No Falcon grid fins, A-frame legs, or ASDS circle-X.

## Old canvas path

`index.html` sets `data-ng-engine="phaser4"` and mounts `#ng-phaser-root`. If `public/toolbox/js/arcade.js` is ever included, `init()` returns immediately so the 420×640 canvas path cannot fight Phaser.

## Stage

Internal resolution is **1280×720**. The React embed (`NewGlennRunner.tsx`) is `aspect-video` (16:9) max 1280. Phaser `Scale.FIT` + `CENTER_BOTH` fills that frame; the cabinet parent is 100% of the iframe so chrome does not letterbox the playfield. Refresh FIT on resize / fullscreen / orientation. Do not use `Scale.RESIZE` for the Matter world.
