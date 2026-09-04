# Phaser 4 vendor build

`phaser.min.js` is the official Phaser 4.2.1 UMD build, copied from the `phaser` npm package.

Do not load Phaser from a CDN in `index.html` — the arcade iframe must stay same-origin (`script-src 'self'`).

Refresh the file with:

```
node artifacts/beckify/scripts/sync-phaser.mjs
```
