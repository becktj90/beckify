import { useEffect, useRef, useState } from "react";
import { Maximize2, Minimize2, Pause, Play, RotateCcw, Volume2, VolumeX } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";
import { KIDS, drawKidPortrait, kidSrc } from "./characterArt";

type Status = "ready" | "running" | "paused" | "gameover";
type Obstacle = { x: number; width: number; height: number; hue: string; kind: "gate" | "crate" | "beacon" };

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
  const resetWorldRef = useRef<(() => void) | null>(null);
  const jumpRef = useRef<(() => void) | null>(null);
  const soundRef = useRef(true);
  const [status, setStatus] = useState<Status>("ready");
  const [score, setScore] = useState(0);
  const [best, setBest] = useState(() => typeof window === "undefined" ? 0 : Number(localStorage.getItem(BEST_KEY) || 0));
  const [sound, setSound] = useState(true);
  const { immersive, toggleFullscreen, exitFullscreen } = useGameFullscreen();

  const setGameStatus = (next: Status) => {
    statusRef.current = next;
    setStatus(next);
  };

  useEffect(() => { soundRef.current = sound; }, [sound]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const context = canvas?.getContext("2d");
    if (!canvas || !context) return;

    let audio: AudioContext | null = null;
    const bleep = (frequency: number, duration: number, endFrequency = frequency, type: OscillatorType = "triangle", volume = 0.03) => {
      if (!soundRef.current) return;
      try {
        audio ??= new AudioContext();
        if (audio.state === "suspended") void audio.resume().catch(() => {});
        const oscillator = audio.createOscillator(); const gain = audio.createGain();
        oscillator.type = type; oscillator.frequency.setValueAtTime(frequency, audio.currentTime); oscillator.frequency.exponentialRampToValueAtTime(Math.max(40, endFrequency), audio.currentTime + duration);
        gain.gain.setValueAtTime(volume, audio.currentTime); gain.gain.exponentialRampToValueAtTime(0.001, audio.currentTime + duration);
        oscillator.connect(gain).connect(audio.destination); oscillator.start(); oscillator.stop(audio.currentTime + duration);
      } catch {
        /* Audio is optional. */
      }
    };
    const player = { x: 88, y: GROUND - 42, width: 28, height: 42, velocityY: 0 };
    const obstacles: Obstacle[] = [];
    const dust: { x: number; y: number; life: number }[] = [];
    let runScore = 0;
    let speed = 260;
    let spawnIn = 1.1;
    let accumulator = 0;
    let coyoteTime = 0;
    let jumpBuffer = 0;
    let previous = performance.now();
    let animationFrame = 0;
    const runner = new Image();
    runner.src = kidSrc("apollo", import.meta.env.BASE_URL);

    const resetWorld = () => {
      player.y = GROUND - player.height;
      player.velocityY = 0;
      obstacles.length = 0;
      dust.length = 0;
      runScore = 0;
      speed = 220;
      spawnIn = 1.1;
      accumulator = 0;
      coyoteTime = 0;
      jumpBuffer = 0;
      setScore(0);
    };

    const start = () => {
      resetWorld();
      setGameStatus("running");
      bleep(440, 0.12, 880);
    };

    const jump = () => {
      if (statusRef.current === "ready" || statusRef.current === "gameover") start();
      if (statusRef.current !== "running") return;
      jumpBuffer = 0.12;
      if (coyoteTime > 0) {
        player.velocityY = -690;
        coyoteTime = 0;
        jumpBuffer = 0;
        dust.push({ x: player.x + 8, y: GROUND - 4, life: 0.45 });
        bleep(520, 0.1, 820, "square", 0.02);
      }
    };

    const finish = () => {
      const nextBest = Math.max(best, Math.floor(runScore));
      setBest(nextBest);
      if (typeof window !== "undefined") localStorage.setItem(BEST_KEY, String(nextBest));
      setGameStatus("gameover");
      bleep(220, 0.3, 70, "sawtooth", 0.05);
    };

    const intersects = (obstacle: Obstacle) =>
      player.x + player.width - 8 > obstacle.x &&
      player.x + 8 < obstacle.x + obstacle.width &&
      player.y + player.height > GROUND - obstacle.height &&
      player.y < GROUND;

    const update = (dt: number) => {
      coyoteTime = Math.max(0, coyoteTime - dt);
      jumpBuffer = Math.max(0, jumpBuffer - dt);
      player.velocityY += 1750 * dt;
      player.y = Math.min(GROUND - player.height, player.y + player.velocityY * dt);
      if (player.y >= GROUND - player.height - 0.5) {
        coyoteTime = 0.18;
        if (jumpBuffer > 0) {
          player.velocityY = -690;
          coyoteTime = 0;
          jumpBuffer = 0;
          dust.push({ x: player.x + 8, y: GROUND - 4, life: 0.45 });
          bleep(520, 0.1, 820, "square", 0.02);
        }
      }
      speed = Math.min(440, 220 + runScore * 2.1);
      runScore += dt * (speed / 70);
      spawnIn -= dt;
      if (spawnIn <= 0) {
        const height = 22 + Math.random() * 26;
        const roll = Math.random();
        const kind: Obstacle["kind"] = roll < 0.45 ? "gate" : roll < 0.75 ? "crate" : "beacon";
        obstacles.push({ x: WIDTH + 20, width: kind === "gate" ? 22 + Math.random() * 14 : 18 + Math.random() * 16, height: kind === "beacon" ? 38 + Math.random() * 16 : height, hue: kind === "beacon" ? "#8b7bff" : Math.random() > 0.5 ? "#ffb84a" : "#ff6b8a", kind });
        spawnIn = Math.max(0.72, 1.32 - runScore / 1100) + Math.random() * 0.5;
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
      gradient.addColorStop(0, "#7ec8ff");
      gradient.addColorStop(0.55, "#cfe9ff");
      gradient.addColorStop(1, "#8ecf7a");
      context.fillStyle = gradient;
      context.fillRect(0, 0, WIDTH, HEIGHT);
      context.fillStyle = "#5aa85a";
      context.fillRect(0, GROUND, WIDTH, HEIGHT - GROUND);
      context.fillStyle = "rgba(255,255,255,0.7)";
      for (let x = 26; x < WIDTH; x += 90) {
        const y = 28 + (x * 17) % 70;
        context.beginPath();
        context.ellipse(x, y, 22, 10, 0, 0, Math.PI * 2);
        context.fill();
      }
      context.fillStyle = "rgba(46, 92, 48, 0.45)";
      for (let x = -20; x < WIDTH + 80; x += 64) {
        const building = 18 + (x * 13 + 91) % 36;
        context.fillRect(x, GROUND - building, 42, building);
      }
      obstacles.forEach((obstacle) => {
        context.save();
        context.fillStyle = obstacle.hue;
        context.shadowColor = obstacle.hue;
        context.shadowBlur = 14;
        if (obstacle.kind === "gate") {
          context.fillRect(obstacle.x, GROUND - obstacle.height, 6, obstacle.height);
          context.fillRect(obstacle.x + obstacle.width - 6, GROUND - obstacle.height, 6, obstacle.height);
          context.fillRect(obstacle.x, GROUND - obstacle.height, obstacle.width, 7);
        } else if (obstacle.kind === "beacon") {
          context.fillRect(obstacle.x + obstacle.width / 2 - 3, GROUND - obstacle.height + 12, 6, obstacle.height - 12);
          context.beginPath(); context.arc(obstacle.x + obstacle.width / 2, GROUND - obstacle.height + 8, 8, 0, Math.PI * 2); context.fill();
        } else {
          context.beginPath(); context.roundRect(obstacle.x, GROUND - obstacle.height, obstacle.width, obstacle.height, 4); context.fill();
          context.fillStyle = "rgba(6,16,31,.65)"; context.fillRect(obstacle.x + 4, GROUND - obstacle.height + 6, obstacle.width - 8, 3);
        }
        context.restore();
      });
      dust.forEach((particle) => {
        context.globalAlpha = Math.max(0, particle.life * 2);
        context.fillStyle = "#55e6cb";
        context.fillRect(particle.x, particle.y, 4, 2);
      });
      context.globalAlpha = 1;
      context.save();
      context.translate(player.x + player.width / 2, player.y + player.height / 2);
      drawKidPortrait(context, runner, 0, 0, 52, { ring: KIDS.apollo.accent });
      context.restore();
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
      if (event.code === "KeyP" || event.code === "Escape") {
        event.preventDefault();
        if (statusRef.current === "running") setGameStatus("paused");
        else if (statusRef.current === "paused") setGameStatus("running");
      }
    };
    const pointerDown = (event: PointerEvent) => { event.preventDefault(); jump(); };
    canvas.addEventListener("pointerdown", pointerDown);
    window.addEventListener("keydown", keyDown);
    restartRef.current = start;
    resetWorldRef.current = resetWorld;
    jumpRef.current = jump;
    animationFrame = requestAnimationFrame(frame);
    return () => { cancelAnimationFrame(animationFrame); restartRef.current = null; resetWorldRef.current = null; jumpRef.current = null; audio?.close(); canvas.removeEventListener("pointerdown", pointerDown); window.removeEventListener("keydown", keyDown); };
  }, [best]);

  const overlayAction = () => {
    if (status === "paused") setGameStatus("running");
    else restartRef.current?.();
  };

  const reset = () => {
    resetWorldRef.current?.();
    setGameStatus("ready");
  };

  return (
    <section className="space-y-6" aria-labelledby="finger-runner-title">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--accent)]">Arcade / Reflex course</p>
          <h1 id="finger-runner-title" className="font-display text-3xl font-bold tracking-tight">Finger Runner</h1>
          <p className="mt-2 max-w-xl text-sm text-[var(--muted)]">A one-button runner built for short sessions: read the rhythm, clear the gates, and chase a longer distance. Apollo (orange balloon) leads the dash.</p>
        </div>
        <div className="flex items-center gap-3 text-xs text-[var(--muted)]">
          <span>BEST {best.toString().padStart(4, "0")}</span>
          <button type="button" className="game-icon-button rounded-md border border-[var(--border)] p-2" onClick={() => setSound((value) => !value)} aria-label={sound ? "Mute game sounds" : "Enable game sounds"}>{sound ? <Volume2 size={16} /> : <VolumeX size={16} />}</button>
          <button type="button" className="game-icon-button rounded-md border border-[var(--border)] p-2" onClick={() => toggleFullscreen(stageRef.current)} aria-label={immersive ? "Exit fullscreen" : "Play fullscreen"}>{immersive ? <Minimize2 size={16} /> : <Maximize2 size={16} />}</button>
        </div>
      </div>
      <div ref={stageRef} className={`game-stage relative mx-auto overflow-hidden bg-[#7ec8ff] shadow-[0_20px_60px_rgba(0,0,0,.35)] ${immersive ? "fixed inset-0 z-[70] flex max-w-none items-center rounded-none border-0 p-3" : "w-full min-w-0 max-w-[640px] rounded-2xl border border-[#7ec8ff]"}`}>
        <canvas ref={canvasRef} width={WIDTH} height={HEIGHT} className="block h-auto w-full touch-none" aria-label="Finger Runner endless runner" />
        {immersive ? <button type="button" className="absolute right-4 top-4 z-30 rounded-full border border-white/30 bg-[#06101f]/90 p-3 text-white shadow-lg" onClick={exitFullscreen} aria-label="Exit fullscreen"><Minimize2 size={18} /></button> : null}
        <div className="kid-hud">
          <div className="kid-chip" style={{ color: KIDS.apollo.accent }}>
            <img src={kidSrc("apollo", import.meta.env.BASE_URL)} alt="" width={32} height={32} />
            <div><span>Apollo</span><strong>{score.toString().padStart(4, "0")}</strong></div>
          </div>
          <div className="kid-chip"><div><span>Best</span><b>{best.toString().padStart(4, "0")}</b></div></div>
        </div>
        {status !== "running" ? (
          <div className="kid-overlay" onClick={(event) => { if ((event.target as HTMLElement).closest("button")) return; overlayAction(); }}>
            <div className="kid-overlay-card">
              <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#ff7a2d]">{status === "gameover" ? "Run complete" : status === "paused" ? "Course paused" : "Ready to run"}</p>
              <h2 className="font-display font-bold">{status === "gameover" ? "Beat your line." : status === "paused" ? "Hold position." : "Find the rhythm."}</h2>
              <p className="mt-3">{status === "gameover" ? `Distance ${score}. Best ${best}.` : "Tap, click, Space, or Arrow Up to jump. Press P or Escape to pause."}</p>
              <button type="button" className="kid-play" style={{ background: KIDS.apollo.accent, color: KIDS.apollo.ink }} onClick={overlayAction}>
                <Play size={16} />
                {status === "paused" ? "Resume" : status === "gameover" ? "Run again" : "Start run"}
              </button>
            </div>
          </div>
        ) : null}
      </div>
      <div className="game-command-bar flex flex-wrap items-center justify-between gap-3 text-xs text-[var(--muted)]"><span aria-live="polite">Distance {score} · Best {best}</span><div className="flex gap-2" aria-label="Runner controls"><button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => { if (status === "running") setGameStatus("paused"); else if (status === "paused") setGameStatus("running"); }}><Pause size={14} />{status === "paused" ? "Resume" : "Pause"}</button><button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={reset}><RotateCcw size={14} />Reset</button><button type="button" className="game-control rounded-md border border-[var(--border)] px-3 py-2" onClick={() => jumpRef.current?.()}>Jump</button></div></div>
    </section>
  );
}
