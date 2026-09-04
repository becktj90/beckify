/** UMD Phaser 4 is loaded by the page; modules consume this shim. */
const Phaser = window.Phaser;
if (!Phaser) {
  throw new Error('Phaser 4 failed to load from the local vendor build.');
}
export default Phaser;
export { Phaser };
