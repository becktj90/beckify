import { useEffect, useRef } from "react";

/**
 * Animated nautilus trace — a logarithmic (equiangular) spiral, r = R·e^(bθ).
 * The animal adds shell at a constant angular rate, so every whorl is a
 * scaled copy of the last; that self-similarity is what makes the curve
 * equiangular and what drives the animation here.
 *
 * The expansion rate is the real one. Nautilus pompilius widens by roughly
 * ×3 per revolution — it is *not* the golden spiral (×φ⁴ ≈ 6.85 per turn),
 * despite that being the popular claim. Using the true ratio also shows far
 * more of the shell in a given frame, which is what makes it read as a shell
 * rather than a fan.
 *
 * The loop exploits self-similarity: rotating the curve by α is identical to
 * scaling it by e^(-bα), so sweeping rotation 0→π/2 while scaling 1→e^(bπ/2)
 * maps the spiral exactly onto itself. The reset is therefore invisible and
 * the shell appears to grow forever.
 *
 * Septa (chamber walls) run from a point on the spiral to the matching point
 * one full turn inward — the true radial span of the shell tube at that angle.
 *
 * Decorative only. Honours prefers-reduced-motion by drawing one static frame.
 */

/** Measured whorl expansion of Nautilus pompilius, per full revolution. */
const WHORL_EXPANSION = 3.03;
const B = Math.log(WHORL_EXPANSION) / (2 * Math.PI);
/** Chamber walls every 40° — about nine per whorl, as on a real shell. */
const SEPTUM_STEP = (2 * Math.PI) / 9;
/** One loop = a quarter turn plus the scale that cancels it. */
const LOOP_ANGLE = Math.PI / 2;
const PERIOD_MS = 13000;

export const NautilusTrace = ({ className }: { className?: string }) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    let width = 0;
    let height = 0;
    let raf = 0;

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const rect = canvas.getBoundingClientRect();
      width = rect.width;
      height = rect.height;
      canvas.width = Math.max(1, Math.round(width * dpr));
      canvas.height = Math.max(1, Math.round(height * dpr));
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };

    /** Radial envelope: dense bright core, softly dissolving at the outer whorl. */
    const envelope = (r: number, outer: number) => {
      const rise = Math.min(1, r / (outer * 0.012));
      const fall = 1 - Math.min(1, Math.max(0, (r - outer * 0.68) / (outer * 0.32)));
      return rise * fall;
    };

    /** Peak zoom reached at the end of a loop, before the seamless reset. */
    const MAX_ZOOM = Math.exp(B * LOOP_ANGLE);

    const draw = (elapsed: number) => {
      ctx.clearRect(0, 0, width, height);
      if (width < 2 || height < 2) return;

      const cx = width * 0.5;
      const cy = height * 0.5;
      // Size the whole shell to the short side so every whorl stays in frame.
      // A spiral cropped by a wide, short box reads as disconnected arcs.
      const outer = Math.min(height, width) * 0.46;
      const base = outer;

      const u = (elapsed % PERIOD_MS) / PERIOD_MS;
      const zoom = Math.exp(B * LOOP_ANGLE * u);
      const spin = u * LOOP_ANGLE;

      // Run from sub-pixel at the core out to the outermost whorl.
      const thetaMin = Math.log(0.12 / (base * MAX_ZOOM)) / B;
      const thetaMax = 0;

      const point = (theta: number) => {
        const r = base * zoom * Math.exp(B * theta);
        const a = theta + spin;
        return { x: cx + r * Math.cos(a), y: cy + r * Math.sin(a), r };
      };

      // ── Chamber septa: spiral(θ) back to spiral(θ − 2π), one whorl inward.
      //    Only the inner chambers carry walls — the outermost whorl is the
      //    living chamber, and on a real shell it has no septum. Capping them
      //    here also stops the long outer spans reading as a spider's web. ──
      const septumLimit = outer * 0.5;
      ctx.lineWidth = 1;
      for (let theta = thetaMin + 2 * Math.PI; theta <= thetaMax; theta += SEPTUM_STEP) {
        const outerPt = point(theta);
        if (outerPt.r > septumLimit) break;
        const innerPt = point(theta - 2 * Math.PI);
        const fade = 1 - Math.min(1, outerPt.r / septumLimit);
        const alpha = envelope(outerPt.r, outer) * 0.42 * (0.25 + 0.75 * fade);
        if (alpha <= 0.004) continue;
        ctx.strokeStyle = `rgba(139, 123, 255, ${alpha.toFixed(4)})`;
        ctx.beginPath();
        ctx.moveTo(innerPt.x, innerPt.y);
        ctx.lineTo(outerPt.x, outerPt.y);
        ctx.stroke();
      }

      // ── The shell curve itself, drawn in short segments so colour, weight
      //    and opacity can shift with radius (blue core → violet rim) ──
      const step = 0.03;
      let prev = point(thetaMin);
      for (let theta = thetaMin + step; theta <= thetaMax; theta += step) {
        const curr = point(theta);
        const alpha = envelope(curr.r, outer);
        if (alpha > 0.004) {
          const mix = Math.min(1, curr.r / (outer * 0.75));
          const red = Math.round(79 + (139 - 79) * mix);
          const green = Math.round(139 + (123 - 139) * mix);
          ctx.strokeStyle = `rgba(${red}, ${green}, 255, ${alpha.toFixed(4)})`;
          ctx.lineWidth = 0.8 + 1.5 * mix;
          ctx.beginPath();
          ctx.moveTo(prev.x, prev.y);
          ctx.lineTo(curr.x, curr.y);
          ctx.stroke();
        }
        prev = curr;
      }

      // ── Soft bloom over the dense core, where the chambers crowd together ──
      const radius = height * 0.34;
      const glow = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius);
      glow.addColorStop(0, "rgba(139, 123, 255, 0.20)");
      glow.addColorStop(1, "rgba(139, 123, 255, 0)");
      ctx.fillStyle = glow;
      ctx.beginPath();
      ctx.arc(cx, cy, radius, 0, Math.PI * 2);
      ctx.fill();
    };

    let start = 0;
    const frame = (now: number) => {
      if (!start) start = now;
      draw(now - start);
      raf = requestAnimationFrame(frame);
    };

    const stop = () => {
      if (raf) cancelAnimationFrame(raf);
      raf = 0;
    };

    const begin = () => {
      stop();
      if (motionQuery.matches) {
        draw(0);
      } else {
        start = 0;
        raf = requestAnimationFrame(frame);
      }
    };

    const observer = new ResizeObserver(() => {
      resize();
      if (motionQuery.matches) draw(0);
    });
    observer.observe(canvas);

    resize();
    begin();
    motionQuery.addEventListener("change", begin);

    return () => {
      stop();
      observer.disconnect();
      motionQuery.removeEventListener("change", begin);
    };
  }, []);

  return <canvas ref={canvasRef} className={className} aria-hidden="true" />;
};
