import { useEffect, useRef, useState } from "react";
import { Maximize2, Pause, Play, RotateCcw } from "lucide-react";

type Status = "ready" | "running" | "paused" | "gameover";
type Obstacle = { x: number; width: number; height: number; hue: string };

const WIDTH = 640;
const HEIGHT = 320;
const GROUND = 260;
const STEP = 1 / 120;
const BEST_KEY = "finger-runner-best";

export function FingerRunner() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const statusRef = useRef<Status>("ready");
  const restartRef = useRef<(() => void) | null>(null);
  const jumpRef = useRef<(() => void) | null>(null);
  const [status, setStatus] = useState<Status>("ready");
  const [score, setScore] = useState(0);
  const [best, setBest] = useState(() => typeof window === "undefined" ? 0 : Number(localStorage.getItem(BEST_KEY) || 0));

  const setGameStatus = (next: Status) => {
    statusRef.current = next;
    setStatus(next);
  };

  useEffect(() => {
    const canvas = canvasRef.current;
    const context = canvas?.getContext("2d");
    if (!canvas || !context) return;

    const player = { x: 88, y: GROUND - 42, width: 28, height: 42, velocityY: 0 };
    const obstacles: Obstacle[] = [];
    const dust: { x: number; y: number; life: number }[] = [];
    let runScore = 0;
    let speed = 260;
    let spawnIn = 1.1;
    let accumulator = 0;
    let previous = performance.now();
    let animationFrame = 0;

    const resetWorld = () => {
      player.y = GROUND - player.height;
      player.velocityY = 0;
      obstacles.length = 0;
      dust.length = 0;
      runScore = 0;
      speed = 260;
      spawnIn = 1.1;
      accumulator = 0;
      setScore(0);
    };

    const start = () => {
      resetWorld();
      setGameStatus("running");
    };

    const jump = () => {
      if (statusRef.current === "ready" || statusRef.current === "gameover") start();
      if (statusRef.current !== "running") return;
      if (player.y >= GROUND - player.height - 1) {
        player.velocityY = -690;
        dust.push({ x: player.x + 8, y: GROUND - 4, life: 0.45 });
      }
    };

    const finish = () => {
      const nextBest = Math.max(best, Math.floor(runScore));
      setBest(nextBest);
      if (typeof window !== "undefined") localStorage.setItem(BEST_KEY, String(nextBest));
      setGameStatus("gameover");
    };

    const intersects = (obstacle: Obstacle) =>
      player.x + player.width - 5 > obstacle.x &&
      player.x + 5 < obstacle.x + obstacle.width &&
      player.y + player.height > GROUND - obstacle.height &&
      player.y < GROUND;

    const update = (dt: number) => {
      player.velocityY += 1750 * dt;
      player.y = Math.min(GROUND - player.height, player.y + player.velocityY * dt);
      speed = Math.min(520, 260 + runScore * 3.2);
      runScore += dt * (speed / 70);
      spawnIn -= dt;
      if (spawnIn <= 0) {
        const height = 28 + Math.random() * 34;
        obstacles.push({ x: WIDTH + 20, width: 18 + Math.random() * 16, height, hue: Math.random() > 0.5 ? "#ffb84a" : "#ff6b8a" });
        spawnIn = Math.max(0.58, 1.15 - runScore / 900) + Math.random() * 0.45;
      }
      obstacles.forEach((obstacle) => { obstacle.x -= speed * dt; });
      while (obstacles[0] && obstacles[0].x + obstacles[0].width < -20) obstacles.shift();
      dust.forEach((particle) => { particle.x -= speed * 0.35 * dt; particle.life -= dt; });
      while (dust[0]?.life <= 0) dust.shift();
      if (obstacles.some(intersects)) finish();
      setScore(Math.floor(runScore));
    };

    const draw = () => {
      const gradient = context.createLinearGradient(0, 0, 0, HEIGHT);
      gradient.addColorStop(0, "#101a3b");
      gradient.addColorStop(1, "#06101f");
      context.fillStyle = gradient;
      context.fillRect(0, 0, WIDTH, HEIGHT);
      context.fillStyle = "rgba(139, 123, 255, 0.16)";
      context.fillRect(0, GROUND, WIDTH, 2);
      context.fillStyle = "rgba(142, 233, 255, 0.45)";
      for (let x = 26; x < WIDTH; x += 57) {
        const y = 36 + (x * 17) % 120;
        context.fillRect(x, y, 2, 2);
      }
      context.strokeStyle = "rgba(139, 123, 255, 0.16)";
      context.lineWidth = 1;
      for (let x = -40; x < WIDTH; x += 40) {
        context.beginPath(); context.moveTo(x, GROUND + 16); context.lineTo(x + 28, HEIGHT); context.stroke();
      }
      obstacles.forEach((obstacle) => {
        context.save();
        context.fillStyle = obstacle.hue;
        context.shadowColor = obstacle.hue;
        context.shadowBlur = 14;
        context.beginPath();
        context.roundRect(obstacle.x, GROUND - obstacle.height, obstacle.width, obstacle.height, 4);
        context.fill();
        context.restore();
      });
      dust.forEach((particle) => {
        context.globalAlpha = Math.max(0, particle.life * 2);
        context.fillStyle = "#55e6cb";
        context.fillRect(particle.x, particle.y, 4, 2);
      });
      context.globalAlpha = 1;
      context.save();
      context.translate(player.x, player.y);
      context.fillStyle = "#55e6cb";
      context.shadowColor = "#55e6cb";
      context.shadowBlur = 18;
      context.beginPath();
      context.roundRect(0, 10, player.width, player.height - 10, 7);
      context.fill();
      context.fillStyle = "#eef0fa";
      context.fillRect(18, 17, 5, 5);
      context.fillStyle = "#ffb84a";
      context.fillRect(5, player.height - 2, 7, 5);
      context.fillRect(18, player.height - 2, 7, 5);
      context.restore();
      context.fillStyle = "#eef0fa";
      context.font = "600 15px Space Grotesk, sans-serif";
      context.fillText(`DISTANCE ${Math.floor(runScore).toString().padStart(4, "0")}`, 18, 28);
      context.fillStyle = "#8fa6c5";
      context.font = "12px JetBrains Mono, monospace";
      context.fillText("JUMP THE SIGNAL GATES", 18, 48);
    };

    const frame = (now: number) => {
      const elapsed = Math.min(0.08, (now - previous) / 1000);
      previous = now;
      if (statusRef.current === "running") {
        accumulator += elapsed;
        while (accumulator >= STEP) { update(STEP); accumulator -= STEP; }
      }
      draw();
      animationFrame = requestAnimationFrame(frame);
    };

    const keyDown = (event: KeyboardEvent) => {
      if (event.code === "Space" || event.code === "ArrowUp") { event.preventDefault(); jump(); }
      if (event.code === "KeyP" || event.code === "Escape") setGameStatus(statusRef.current === "paused" ? "running" : "paused");
    };
    const pointerDown = (event: PointerEvent) => { event.preventDefault(); jump(); };
    canvas.addEventListener("pointerdown", pointerDown);
    window.addEventListener("keydown", keyDown);
    restartRef.current = start;
    jumpRef.current = jump;
    animationFrame = requestAnimationFrame(frame);
    return () => { cancelAnimationFrame(animationFrame); restartRef.current = null; jumpRef.current = null; canvas.removeEventListener("pointerdown", pointerDown); window.removeEventListener("keydown", keyDown); };
  }, [best]);

  const toggleFullscreen = async () => {
    if (!stageRef.current) return;
    if (document.fullscreenElement) await document.exitFullscreen();
    else await stageRef.current.requestFullscreen?.();
  };
  const reset = () => { restartRef.current?.(); setGameStatus("ready"); };

  return (
    <section className="space-y-6" aria-labelledby="finger-runner-title">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--accent)]">Arcade / Reflex course</p>
          <h1 id="finger-runner-title" className="font-display text-3xl font-bold tracking-tight">Finger Runner</h1>
          <p className="mt-2 max-w-xl text-sm text-[var(--muted)]">A one-button runner built for short sessions: read the rhythm, clear the gates, and chase a longer distance.</p>
        </div>
        <div className="flex items-center gap-3 text-xs text-[var(--muted)]">
          <span>BEST {best.toString().padStart(4, "0")}</span>
          <button type="button" className="rounded-md border border-[var(--border)] p-2" onClick={toggleFullscreen} aria-label="Toggle fullscreen"><Maximize2 size={16} /></button>
        </div>
      </div>
      <div ref={stageRef} className="relative mx-auto max-w-[640px] overflow-hidden rounded-2xl border border-[#2e5d86] bg-[#06101f] shadow-[0_20px_60px_rgba(0,0,0,.35)]">
        <canvas ref={canvasRef} width={WIDTH} height={HEIGHT} className="block h-auto w-full touch-none" aria-label="Finger Runner endless runner" />
        {status !== "running" ? <div className="absolute inset-0 flex items-center justify-center bg-[#06101f]/80 p-6 text-center backdrop-blur-[2px]"><div className="max-w-xs"><p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#55e6cb]">{status === "gameover" ? "Run complete" : status === "paused" ? "Course paused" : "Ready to run"}</p><h2 className="mt-2 font-display text-3xl font-bold text-white">{status === "gameover" ? "Beat your line." : status === "paused" ? "Hold position." : "Find the rhythm."}</h2><p className="mt-3 text-sm leading-6 text-[#b9c8dc]">{status === "gameover" ? `Distance ${score}. Best ${best}.` : "Tap, click, Space, or Arrow Up to jump. Press P or Escape to pause."}</p><button type="button" className="pointer-events-auto mt-5 inline-flex items-center gap-2 rounded-lg bg-[#55e6cb] px-5 py-3 text-sm font-semibold text-[#06101f]" onClick={() => status === "paused" ? setGameStatus("running") : restartRef.current?.()}><Play size={16} />{status === "paused" ? "Resume" : status === "gameover" ? "Run again" : "Start run"}</button></div></div> : null}
      </div>
      <div className="flex flex-wrap items-center justify-between gap-3 text-xs text-[var(--muted)]"><span>Distance {score} · Best {best}</span><div className="flex gap-2"><button type="button" className="inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => setGameStatus(status === "paused" ? "running" : "paused")}><Pause size={14} />{status === "paused" ? "Resume" : "Pause"}</button><button type="button" className="inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={reset}><RotateCcw size={14} />Reset</button><button type="button" className="rounded-md border border-[var(--border)] px-3 py-2" onClick={() => jumpRef.current?.()}>Jump</button></div></div>
    </section>
  );
}
