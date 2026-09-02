import { useEffect, useRef, useState } from "react";
import { Maximize2, Minimize2, Pause, Play, RotateCcw, Volume2, VolumeX } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";
import { KIDS, drawKidPortrait, kidSrc, type KidId } from "./characterArt";

type Status = "ready" | "running" | "paused" | "gameover";
type Rider = KidId;
type Gate = { x: number; gapY: number; scored: boolean };
const W = 480;
const H = 640;
const BEST_KEY = "toot-troopers-best";
const GAP = 102;
const GRAVITY = 13.2;
const PIPE_SPEED = 102;
const HIT_X = 16;
const HIT_Y = 12;
const safeBest = () => {
  try {
    const value = Number(localStorage.getItem(BEST_KEY));
    return Number.isFinite(value) && value >= 0 ? value : 0;
  } catch {
    return 0;
  }
};

const togglePause = (status: Status): Status => {
  if (status === "running") return "paused";
  if (status === "paused") return "running";
  return status;
};

export function TootTroopers() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const statusRef = useRef<Status>("ready");
  const riderRef = useRef<Rider>("apollo");
  const soundRef = useRef(true);
  const startRef = useRef<() => void>(() => {});
  const pauseRef = useRef<() => void>(() => {});
  const [status, setStatus] = useState<Status>("ready");
  const [rider, setRider] = useState<Rider>("apollo");
  const [score, setScore] = useState(0);
  const [best, setBest] = useState(safeBest);
  const [sound, setSound] = useState(true);
  const bestRef = useRef(best);
  const { immersive, toggleFullscreen, exitFullscreen } = useGameFullscreen();
  const assetBase = import.meta.env.BASE_URL;

  useEffect(() => { riderRef.current = rider; }, [rider]);
  useEffect(() => { soundRef.current = sound; }, [sound]);
  useEffect(() => { bestRef.current = best; }, [best]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext("2d");
    if (!canvas || !ctx) return;
    let y = H / 2;
    let velocity = 0;
    let elapsed = 0;
    let scoreValue = 0;
    let last = performance.now();
    let raf = 0;
    let audio: AudioContext | undefined;
    let gates: Gate[] = [];
    let lastHud = 0;
    let lastTootAt = 0;
    const characterArt = { apollo: new Image(), rocco: new Image() };
    characterArt.apollo.src = kidSrc("apollo", assetBase);
    characterArt.rocco.src = kidSrc("rocco", assetBase);
    const state = (next: Status) => { statusRef.current = next; setStatus(next); };
    const audioReady = () => {
      if (!soundRef.current) return undefined;
      try {
        audio ??= new AudioContext();
        if (audio.state === "suspended") void audio.resume().catch(() => {});
        return audio;
      } catch {
        return undefined;
      }
    };
    const tone = (hz: number, length: number, volume: number, kind: OscillatorType = "triangle") => {
      const soundNode = audioReady();
      if (!soundNode) return;
      const osc = soundNode.createOscillator();
      const gain = soundNode.createGain();
      osc.type = kind;
      osc.frequency.setValueAtTime(hz, soundNode.currentTime);
      gain.gain.setValueAtTime(volume, soundNode.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, soundNode.currentTime + length);
      osc.connect(gain).connect(soundNode.destination);
      osc.start();
      osc.stop(soundNode.currentTime + length);
    };
    const toot = () => {
      const now = performance.now();
      if (now - lastTootAt < 42) return;
      lastTootAt = now;
      const soundNode = audioReady();
      if (!soundNode) return;
      const variants = [[108, 0.13, "sine"], [142, 0.11, "square"], [92, 0.18, "triangle"], [175, 0.09, "sine"], [124, 0.15, "square"], [78, 0.2, "triangle"]] as const;
      const [pitch, length, shape] = variants[Math.floor(Math.random() * variants.length)];
      const osc = soundNode.createOscillator();
      const gain = soundNode.createGain();
      const wobble = soundNode.createOscillator();
      const wobbleGain = soundNode.createGain();
      osc.type = shape;
      osc.frequency.setValueAtTime(pitch + Math.random() * 20, soundNode.currentTime);
      osc.frequency.exponentialRampToValueAtTime(Math.max(48, pitch * 0.58), soundNode.currentTime + length);
      wobble.frequency.value = 18 + Math.random() * 18;
      wobbleGain.gain.value = 12;
      wobble.connect(wobbleGain).connect(osc.frequency);
      gain.gain.setValueAtTime(0.055, soundNode.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, soundNode.currentTime + length);
      osc.connect(gain).connect(soundNode.destination);
      wobble.start();
      osc.start();
      wobble.stop(soundNode.currentTime + length);
      osc.stop(soundNode.currentTime + length);
    };
    const reset = (running: boolean) => {
      y = H / 2;
      velocity = 0;
      elapsed = 0;
      scoreValue = 0;
      gates = [{ x: W + 80, gapY: 250, scored: false }, { x: W + 330, gapY: 390, scored: false }];
      setScore(0);
      state(running ? "running" : "ready");
    };
    const flap = () => {
      if (statusRef.current === "gameover") {
        reset(true);
        toot();
        return;
      }
      if (statusRef.current === "paused") {
        state("running");
        return;
      }
      if (statusRef.current === "ready") reset(true);
      if (statusRef.current !== "running") return;
      velocity = -7.1;
      toot();
    };
    const pause = () => state(togglePause(statusRef.current));
    startRef.current = flap;
    pauseRef.current = pause;
    const crash = () => {
      if (statusRef.current !== "running") return;
      state("gameover");
      const next = Math.max(bestRef.current, scoreValue);
      if (next > bestRef.current) {
        bestRef.current = next;
        setBest(next);
        try { localStorage.setItem(BEST_KEY, String(next)); } catch { /* optional */ }
      }
      tone(75, 0.28, 0.07, "sawtooth");
    };
    const draw = (now: number) => {
      const dt = Math.min(0.033, (now - last) / 1000);
      last = now;
      const sky = ctx.createLinearGradient(0, 0, 0, H);
      sky.addColorStop(0, "#7ec8ff");
      sky.addColorStop(0.55, "#b7e4ff");
      sky.addColorStop(1, "#f7e7a8");
      ctx.fillStyle = sky;
      ctx.fillRect(0, 0, W, H);
      ctx.fillStyle = "rgba(255,255,255,0.8)";
      for (let i = 0; i < 6; i += 1) {
        const x = (i * 110 + elapsed * 18) % (W + 60) - 30;
        ctx.beginPath();
        ctx.ellipse(x, 48 + (i % 3) * 22, 28, 14, 0, 0, Math.PI * 2);
        ctx.fill();
      }
      if (statusRef.current === "running") {
        elapsed += dt;
        velocity += GRAVITY * dt;
        y += velocity;
        if (gates[gates.length - 1].x < W - 130) gates.push({ x: W + 60, gapY: 150 + Math.random() * 320, scored: false });
        gates.forEach((g) => {
          g.x -= PIPE_SPEED * dt;
          if (!g.scored && g.x + 54 < 128) {
            g.scored = true;
            scoreValue += 1;
            if (now - lastHud > 150) {
              setScore(scoreValue);
              lastHud = now;
            }
            tone(720, 0.1, 0.025);
          }
        });
        gates = gates.filter((g) => g.x > -80);
        for (const g of gates) {
          if (128 + HIT_X > g.x && 128 - HIT_X < g.x + 54 && (y - HIT_Y < g.gapY - GAP || y + HIT_Y > g.gapY + GAP)) crash();
        }
        if (y < 10 || y > H - 10) crash();
      }
      gates.forEach((g) => {
        ctx.fillStyle = "#ff8a4c";
        ctx.fillRect(g.x, 0, 54, g.gapY - GAP);
        ctx.fillRect(g.x, g.gapY + GAP, 54, H);
        ctx.fillStyle = "#ffe08a";
        ctx.fillRect(g.x - 8, g.gapY - GAP - 14, 70, 16);
        ctx.fillRect(g.x - 8, g.gapY + GAP - 2, 70, 16);
        ctx.strokeStyle = "rgba(255,255,255,0.65)";
        ctx.lineWidth = 4;
        ctx.beginPath();
        ctx.ellipse(g.x + 27, g.gapY, 32, GAP - 8, 0, 0, Math.PI * 2);
        ctx.stroke();
      });
      const active = riderRef.current;
      ctx.save();
      ctx.translate(128, y);
      ctx.rotate(Math.max(-0.3, Math.min(0.45, velocity / 16)));
      drawKidPortrait(ctx, characterArt[active], 0, 0, 86, { ring: KIDS[active].accent, tilt: 0 });
      ctx.restore();
      raf = requestAnimationFrame(draw);
    };
    const pointer = (event: PointerEvent) => { event.preventDefault(); flap(); };
    const key = (event: KeyboardEvent) => {
      if (event.code === "Space" || event.code === "ArrowUp") {
        event.preventDefault();
        if (!event.repeat) flap();
      }
      if (event.code === "KeyP" || event.code === "Escape") {
        event.preventDefault();
        pause();
      }
    };
    canvas.addEventListener("pointerdown", pointer);
    window.addEventListener("keydown", key);
    raf = requestAnimationFrame(draw);
    return () => {
      cancelAnimationFrame(raf);
      audio?.close().catch(() => {});
      canvas.removeEventListener("pointerdown", pointer);
      window.removeEventListener("keydown", key);
    };
  }, [assetBase]);

  const kid = KIDS[rider];
  return (
    <section className="space-y-5" aria-labelledby="toot-troopers-title">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <p className="text-xs font-bold uppercase tracking-[.2em]" style={{ color: kid.accent }}>Arcade / fart-powered flight</p>
          <h1 id="toot-troopers-title" className="font-display text-3xl font-bold">Toot Troopers</h1>
          <p className="mt-1 max-w-xl text-sm text-[var(--muted)]">Apollo and Rocco are late for the sky picnic. Fart-flap through the inflatable rings and keep the snacks airborne.</p>
        </div>
        <div className="flex gap-2">
          <button type="button" className="game-control rounded-md border border-[var(--border)] p-2" onClick={() => setSound((v) => !v)} aria-label={sound ? "Mute game" : "Unmute game"}>{sound ? <Volume2 size={16} /> : <VolumeX size={16} />}</button>
          <button type="button" className="game-control rounded-md border border-[var(--border)] p-2" onClick={() => toggleFullscreen(stageRef.current)} aria-label={immersive ? "Exit fullscreen" : "Play fullscreen"}>{immersive ? <Minimize2 size={16} /> : <Maximize2 size={16} />}</button>
        </div>
      </div>
      <div ref={stageRef} className={`game-stage relative mx-auto overflow-hidden bg-[#7ec8ff] ${immersive ? "fixed inset-0 z-[70] flex max-w-none items-center rounded-none p-3" : "w-full min-w-0 max-w-[480px] rounded-2xl border border-[#7ec8ff]"}`}>
        <canvas ref={canvasRef} width={W} height={H} className="block h-auto w-full touch-none" aria-label="Toot Troopers fart-powered side-scrolling game" />
        {immersive && <button type="button" className="absolute right-4 top-4 z-30 rounded-full border border-white/30 bg-[#11133d] p-3 text-white" onClick={exitFullscreen} aria-label="Exit fullscreen"><Minimize2 size={16} /></button>}
        <div className="kid-hud">
          <div className="kid-chip" style={{ color: kid.accent }}>
            <img src={kidSrc(rider, assetBase)} alt="" width={32} height={32} />
            <div><span>{kid.label}</span><strong>TOOTS {score}</strong></div>
          </div>
          <div className="kid-chip">
            <div><span>Best</span><b>{best}</b></div>
            <div className="kid-stage-actions">
              <button type="button" onClick={() => pauseRef.current()} aria-label={status === "paused" ? "Resume" : "Pause"}>{status === "paused" ? <Play size={16} /> : <Pause size={16} />}</button>
            </div>
          </div>
        </div>
        {status !== "running" && (
          <div className="kid-overlay" onClick={(event) => { if ((event.target as HTMLElement).closest("button")) return; if (status === "paused") pauseRef.current(); else startRef.current(); }}>
            <div className="kid-overlay-card">
              <p className="text-xs font-bold uppercase tracking-[.2em]" style={{ color: kid.accent }}>{status === "gameover" ? `Snack crash · ${score} gates` : status === "paused" ? "Holding altitude" : "Ready for takeoff"}</p>
              <h2 className="font-display font-bold">{status === "gameover" ? "Try another toot." : status === "paused" ? "Still flying." : "Pick a kid."}</h2>
              {status !== "paused" ? (
                <div className="kid-pick">
                  {(["apollo", "rocco"] as Rider[]).map((id) => (
                    <button key={id} type="button" className={rider === id ? "is-on" : ""} style={rider === id ? { borderColor: KIDS[id].accent, background: KIDS[id].accent, color: KIDS[id].ink } : undefined} onClick={() => setRider(id)}>
                      <img src={kidSrc(id, assetBase)} alt="" width={72} height={72} />
                      {KIDS[id].label}
                    </button>
                  ))}
                </div>
              ) : null}
              <button type="button" className="kid-play" style={{ background: kid.accent, color: kid.ink }} onClick={() => status === "paused" ? pauseRef.current() : startRef.current()}>
                <Play size={16} />
                {status === "gameover" ? "Try again" : status === "paused" ? "Resume" : "FART TO FLY"}
              </button>
            </div>
          </div>
        )}
      </div>
      <div className="game-command-bar flex flex-wrap items-center justify-between gap-3 text-sm">
        <span aria-live="polite">Toots {score} · Local best {best}</span>
        <button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => startRef.current()}><RotateCcw size={15} /> Fart</button>
      </div>
      <p className="text-xs text-[var(--muted)]">Tap/click the game or press Space / ↑ to fart-flap. P pauses. One toot, one flap—no surprise double jumps.</p>
    </section>
  );
}
