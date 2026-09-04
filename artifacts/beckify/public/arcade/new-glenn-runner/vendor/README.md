# Phaser 4 vendor build

`phaser.min.js` is the official **Phaser 4.2.1** full UMD build (Matter included).

Same bytes as jsDelivr:

`https://cdn.jsdelivr.net/npm/phaser@4.2.1/dist/phaser.min.js`

Copied from the `phaser@4.2.1` npm package (`dist/phaser.min.js`). Do **not** vendor `phaser-arcade-physics` or any arcade-only split — New Glenn Runner uses built-in Matter.

Do not load Phaser from a CDN in `index.html`. The arcade iframe must stay same-origin (`script-src 'self'`).

Refresh the file with:

```
node artifacts/beckify/scripts/sync-phaser.mjs
```
