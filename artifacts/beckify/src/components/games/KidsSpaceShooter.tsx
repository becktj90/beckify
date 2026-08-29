import { useEffect, useRef, useState } from "react";

interface Star { x: number; y: number; speed: number; size: number; }

export function KidsSpaceShooter() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [score, setScore] = useState(() => typeof window === "undefined" ? 0 : Number(window.localStorage.getItem("cosmic-cadet-score") || 0));
  const [sound, setSound] = useState(true);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext("2d");
    if (!context) return;
    const stars: Star[] = Array.from({ length: 42 }, () => ({ x: Math.random() * 420, y: Math.random() * 620, speed: 0.4 + Math.random() * 1.2, size: 1 + Math.random() * 3 }));
    let shipX = 210; let points = score; let frame = 0; let animation = 0;
    const resize = () => { const ratio = window.devicePixelRatio || 1; canvas.width = 420 * ratio; canvas.height = 620 * ratio; context.setTransform(ratio, 0, 0, ratio, 0, 0); };
    const move = (event: PointerEvent) => { const rect = canvas.getBoundingClientRect(); shipX = Math.max(35, Math.min(385, ((event.clientX - rect.left) / rect.width) * 420)); };
    const draw = () => { frame += 1; context.fillStyle = "#071b35"; context.fillRect(0, 0, 420, 620); stars.forEach((star) => { star.y = (star.y + star.speed) % 620; context.fillStyle = "#b8e7ff"; context.fillRect(star.x, star.y, star.size, star.size); });
      const asteroidX = 70 + ((frame * 1.7) % 280); const asteroidY = 110 + ((frame * 2.1) % 220); context.fillStyle = "#ffb84a"; context.beginPath(); context.arc(asteroidX, asteroidY, 24, 0, Math.PI * 2); context.fill(); context.fillStyle = "#ff5e7a"; context.fillRect(shipX - 5, 530 - ((frame * 7) % 390), 10, 22); context.fillStyle = "#62e6c5"; context.beginPath(); context.moveTo(shipX, 500); context.lineTo(shipX - 30, 550); context.lineTo(shipX, 540); context.lineTo(shipX + 30, 550); context.closePath(); context.fill(); context.fillStyle = "#fff"; context.font = "700 20px sans-serif"; context.fillText(`Score ${points}`, 18, 34); context.font = "14px sans-serif"; context.fillText("Drag to fly", 18, 57); animation = requestAnimationFrame(draw); };
    resize(); canvas.addEventListener("pointermove", move); canvas.addEventListener("pointerdown", move); window.addEventListener("resize", resize); draw();
    return () => { cancelAnimationFrame(animation); canvas.removeEventListener("pointermove", move); canvas.removeEventListener("pointerdown", move); window.removeEventListener("resize", resize); };
  }, [score]);

  const saveScore = () => { const next = score + 10; setScore(next); localStorage.setItem("cosmic-cadet-score", String(next)); };
  return <section className="card-surface space-y-4 p-6" aria-labelledby="cosmic-cadet-title"><div className="flex flex-wrap items-start justify-between gap-3"><div><p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">Gentle arcade mode</p><h2 id="cosmic-cadet-title" className="font-display text-2xl font-bold">Cosmic Cadet</h2><p className="mt-2 text-sm text-[var(--muted)]">Drag the friendly ship, dodge the asteroids, and earn rocket badges. No game over.</p></div><button type="button" className="rounded-lg border border-[var(--border)] px-3 py-2 text-sm" onClick={() => setSound((value) => !value)}>{sound ? "Sound on" : "Sound off"}</button></div><div className="mx-auto max-w-[420px] overflow-hidden rounded-2xl border-4 border-[#244c76] shadow-2xl"><canvas ref={canvasRef} className="block h-auto w-full touch-none" width="420" height="620" aria-label="Cosmic Cadet game canvas" /></div><div className="flex justify-center"><button type="button" className="rounded-lg bg-[var(--accent)] px-4 py-2 text-sm font-semibold text-white" onClick={saveScore}>Collect rocket badge</button></div></section>;
}

export default KidsSpaceShooter;
