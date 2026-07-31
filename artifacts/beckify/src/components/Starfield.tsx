import { PenroseField } from "@/components/PenroseField";

/**
 * Fixed deep-space backdrop: drifting/twinkling starfield, an aperiodic
 * Penrose tiling texture, blurred nebula glows, shooting stars, and a couple
 * of slow-floating planets. Rendered once in the page Layout so it stays
 * behind every page's content. Purely decorative — animations live in
 * src/index.css.
 */
export const Starfield = () => (
  <>
    <div className="starfield">
      <span className="shooting-star" />
      <span className="shooting-star" />
      <span className="shooting-star" />
      <div className="space-object planet" />
      <div className="space-object moon" />
    </div>
    <PenroseField />
    <div className="nebula-glow">
      <span />
      <span />
      <span />
    </div>
  </>
);
