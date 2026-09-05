/** UMD Phaser 4.2.1 (full Matter build) is loaded by the page; modules consume this shim. */
const Phaser = window.Phaser;
if (!Phaser) {
  throw new Error('Phaser 4.2.1 failed to load from vendor/phaser.min.js (full build with Matter).');
}
export default Phaser;
export { Phaser };
