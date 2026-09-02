import { useEffect, useRef, useState } from "react";
import { Maximize2, Minimize2, Pause, Play, RotateCcw, Volume2, VolumeX } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";

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
      audio ??= new AudioContext();
      const oscillator = audio.createOscillator(); const gain = audio.createGain();
      oscillator.type = type; oscillator.frequency.setValueAtTime(frequency, audio.currentTime); oscillator.frequency.exponentialRampToValueAtTime(Math.max(40, endFrequency), audio.currentTime + duration);
      gain.gain.setValueAtTime(volume, audio.currentTime); gain.gain.exponentialRampToValueAtTime(0.001, audio.currentTime + duration);
      oscillator.connect(gain).connect(audio.destination); oscillator.start(); oscillator.stop(audio.currentTime + duration);
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
      gradient.addColorStop(0, "#101a3b");
      gradient.addColorStop(1, "#06101f");
      context.fillStyle = gradient;
      context.fillRect(0, 0, WIDTH, HEIGHT);
      context.fillStyle = "rgba(139, 123, 255, 0.16)";
      context.fillRect(0, GROUND, WIDTH, 2);
      context.fillStyle = "rgba(112, 144, 255, 0.13)";
      for (let x = -20; x < WIDTH + 80; x += 64) {
        const building = 26 + (x * 13 + 91) % 52;
        context.fillRect(x, GROUND - 32 - building, 42, building);
        context.fillStyle = "rgba(85, 230, 203, 0.32)";
        for (let windowY = GROUND - 25 - building; windowY < GROUND - 38; windowY += 13) context.fillRect(x + 9, windowY, 4, 3);
        context.fillStyle = "rgba(112, 144, 255, 0.13)";
      }
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
      context.translate(player.x, player.y);
      context.fillStyle = "#55e6cb";
      context.shadowColor = "#55e6cb";
      context.shadowBlur = 18;
      context.beginPath();
      context.roundRect(0, 10, player.width, player.height - 10, 7);
      context.fill();
      context.fillStyle = "#10213b";
      context.fillRect(5, 14, player.width - 10, 9);
      context.fillStyle = "#eef0fa";
      context.fillRect(18, 17, 5, 5);
      context.fillStyle = "#ffb84a";
      context.fillRect(7, 17, 5, 3);
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
      context.textAlign = "right";
      context.fillStyle = "#8fa6c5";
      context.fillText(`SPEED ${Math.round(speed)} · SECTOR 03`, WIDTH - 18, 28);
      context.textAlign = "left";
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
    return () => { cancelAnimationFrame(animationFrame); restartRef.current = null; jumpRef.current = null; audio?.close(); canvas.removeEventListener("pointerdown", pointerDown); window.removeEventListener("keydown", keyDown); };
  }, [best]);

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
          <button type="button" className="game-icon-button rounded-md border border-[var(--border)] p-2" onClick={() => setSound((value) => !value)} aria-label={sound ? "Mute game sounds" : "Enable game sounds"}>{sound ? <Volume2 size={16} /> : <VolumeX size={16} />}</button>
          <button type="button" className="game-icon-button rounded-md border border-[var(--border)] p-2" onClick={() => toggleFullscreen(stageRef.current)} aria-label={immersive ? "Exit fullscreen" : "Play fullscreen"}>{immersive ? <Minimize2 size={16} /> : <Maximize2 size={16} />}</button>
        </div>
      </div>
      <div ref={stageRef} className={`game-stage relative mx-auto overflow-hidden bg-[#06101f] shadow-[0_20px_60px_rgba(0,0,0,.35)] ${immersive ? "fixed inset-0 z-[70] flex max-w-none items-center rounded-none border-0 p-3" : "w-full min-w-0 max-w-[640px] rounded-2xl border border-[#2e5d86]"}`}>
        <canvas ref={canvasRef} width={WIDTH} height={HEIGHT} className="block h-auto w-full touch-none" aria-label="Finger Runner endless runner" />
        {immersive ? <button type="button" className="absolute right-4 top-4 z-10 rounded-full border border-white/30 bg-[#06101f]/90 p-3 text-white shadow-lg" onClick={exitFullscreen} aria-label="Exit fullscreen"><Minimize2 size={18} /></button> : null}
        {status !== "running" ? <div className="absolute inset-0 flex items-center justify-center bg-[#06101f]/80 p-6 text-center backdrop-blur-[2px]"><div className="max-w-xs"><p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#55e6cb]">{status === "gameover" ? "Run complete" : status === "paused" ? "Course paused" : "Ready to run"}</p><h2 className="mt-2 font-display text-3xl font-bold text-white">{status === "gameover" ? "Beat your line." : status === "paused" ? "Hold position." : "Find the rhythm."}</h2><p className="mt-3 text-sm leading-6 text-[#b9c8dc]">{status === "gameover" ? `Distance ${score}. Best ${best}.` : "Tap, click, Space, or Arrow Up to jump. Press P or Escape to pause."}</p><button type="button" className="game-control pointer-events-auto mt-5 inline-flex items-center gap-2 rounded-lg bg-[#55e6cb] px-5 py-3 text-sm font-semibold text-[#06101f]" onClick={() => status === "paused" ? setGameStatus("running") : restartRef.current?.()}><Play size={16} />{status === "paused" ? "Resume" : status === "gameover" ? "Run again" : "Start run"}</button></div></div> : null}
      </div>
      <div className="game-command-bar flex flex-wrap items-center justify-between gap-3 text-xs text-[var(--muted)]"><span aria-live="polite">Distance {score} · Best {best}</span><div className="flex gap-2" aria-label="Runner controls"><button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => setGameStatus(status === "paused" ? "running" : "paused")}><Pause size={14} />{status === "paused" ? "Resume" : "Pause"}</button><button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={reset}><RotateCcw size={14} />Reset</button><button type="button" className="game-control rounded-md border border-[var(--border)] px-3 py-2" onClick={() => jumpRef.current?.()}>Jump</button></div></div>
    </section>
  );
}
