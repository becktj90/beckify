/**
 * Visitor-facing counts. Counted from public surfaces, not marketing copy:
 *  - Calculators: unique toolbox sidebar calculator anchors, derived in
 *    toolbox-tools.mjs from the TOOLS registry plus live-nav extras
 *    (circuit simulator, STEM toolkit). Excludes reference tables, the
 *    fittings guide, and Saved Jobs.
 *  - Games: GAMES in site-content.ts.
 */
export { PUBLIC_CALCULATOR_COUNT } from "./toolbox-tools.mjs";
export const PUBLIC_GAME_COUNT = 7;
