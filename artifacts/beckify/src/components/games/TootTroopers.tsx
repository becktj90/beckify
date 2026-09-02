import { useEffect, useRef, useState } from "react";
import { Play, RotateCcw, Volume2, VolumeX } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";

type Status = "ready" | "running" | "gameover";
type Rider = "apollo" | "rocco";
type Gate = { x: number; gapY: number; scored: boolean };
const W = 480, H = 640, BEST_KEY = "toot-troopers-best";
const GAP = 102, GRAVITY = 13.2, PIPE_SPEED = 102, HIT_X = 16, HIT_Y = 12;
const safeBest = () => { try { const value = Number(localStorage.getItem(BEST_KEY)); return Number.isFinite(value) && value >= 0 ? value : 0; } catch { return 0; } };

export function TootTroopers() {
  const canvasRef = useRef<HTMLCanvasElement>(null), stageRef = useRef<HTMLDivElement>(null), statusRef = useRef<Status>("ready"), riderRef = useRef<Rider>("apollo"), soundRef = useRef(true), startRef = useRef<() => void>(() => {});
  const [status, setStatus] = useState<Status>("ready"), [rider, setRider] = useState<Rider>("apollo"), [score, setScore] = useState(0), [best, setBest] = useState(safeBest), [sound, setSound] = useState(true); const bestRef = useRef(best);
  const { immersive, toggleFullscreen, exitFullscreen } = useGameFullscreen();
  useEffect(() => { riderRef.current = rider; }, [rider]); useEffect(() => { soundRef.current = sound; }, [sound]); useEffect(() => { bestRef.current = best; }, [best]);
  useEffect(() => {
    const canvas = canvasRef.current, ctx = canvas?.getContext("2d"); if (!canvas || !ctx) return;
    let y = H / 2, velocity = 0, elapsed = 0, scoreValue = 0, last = performance.now(), raf = 0, audio: AudioContext | undefined, gates: Gate[] = [], lastHud = 0, lastTootAt = 0;
    const characterArt = {
      apollo: new Image(),
      rocco: new Image(),
    };
    const assetBase = import.meta.env.BASE_URL;
    characterArt.apollo.src = `${assetBase}games/toot-troopers/apollo.png`;
    characterArt.rocco.src = `${assetBase}games/toot-troopers/rocco.png`;
    const state = (next: Status) => { statusRef.current = next; setStatus(next); };
    const audioReady = () => {
      if (!soundRef.current) return undefined;
      try {
        audio ??= new AudioContext();
        if (audio.state === "suspended") void audio.resume().catch(() => {});
        return audio;
      } catch { return undefined; }
    };
    const tone = (hz: number, length: number, volume: number, kind: OscillatorType = "triangle") => {
      const sound = audioReady(); if (!sound) return;
      const osc = sound.createOscillator(), gain = sound.createGain();
      osc.type = kind; osc.frequency.setValueAtTime(hz, sound.currentTime);
      gain.gain.setValueAtTime(volume, sound.currentTime); gain.gain.exponentialRampToValueAtTime(.001, sound.currentTime + length);
      osc.connect(gain).connect(sound.destination); osc.start(); osc.stop(sound.currentTime + length);
    };
    // A small, bounded cartoon-toot bank: each fart mixes a different pitch, wobble and puff.
    const toot = () => {
      const now = performance.now(); if (now - lastTootAt < 42) return; lastTootAt = now;
      const sound = audioReady(); if (!sound) return;
      const variants = [[108, .13, "sine"], [142, .11, "square"], [92, .18, "triangle"], [175, .09, "sine"], [124, .15, "square"], [78, .2, "triangle"]] as const;
      const [pitch, length, shape] = variants[Math.floor(Math.random() * variants.length)];
      const osc = sound.createOscillator(), gain = sound.createGain(), wobble = sound.createOscillator(), wobbleGain = sound.createGain();
      osc.type = shape; osc.frequency.setValueAtTime(pitch + Math.random() * 20, sound.currentTime); osc.frequency.exponentialRampToValueAtTime(Math.max(48, pitch * .58), sound.currentTime + length);
      wobble.frequency.value = 18 + Math.random() * 18; wobbleGain.gain.value = 12; wobble.connect(wobbleGain).connect(osc.frequency);
      gain.gain.setValueAtTime(.055, sound.currentTime); gain.gain.exponentialRampToValueAtTime(.001, sound.currentTime + length);
      osc.connect(gain).connect(sound.destination); wobble.start(); osc.start(); wobble.stop(sound.currentTime + length); osc.stop(sound.currentTime + length);
    };
    const reset = (running: boolean) => { y = H / 2; velocity = 0; elapsed = 0; scoreValue = 0; gates = [{ x: W + 80, gapY: 250, scored: false }, { x: W + 330, gapY: 390, scored: false }]; setScore(0); state(running ? "running" : "ready"); };
    const flap = () => { if (statusRef.current === "gameover") { reset(true); toot(); return; } if (statusRef.current === "ready") reset(true); velocity = -7.1; toot(); };
    startRef.current = flap;
    const crash = () => { if (statusRef.current !== "running") return; state("gameover"); const next = Math.max(bestRef.current, scoreValue); if (next > bestRef.current) { bestRef.current = next; setBest(next); try { localStorage.setItem(BEST_KEY, String(next)); } catch {} } tone(75, .28, .07, "sawtooth"); };
    const drawRider = () => { const active = riderRef.current; const rocco = active === "rocco", image = characterArt[active]; ctx.save(); ctx.translate(128, y); ctx.rotate(Math.max(-.3, Math.min(.45, velocity / 16))); ctx.shadowColor = rocco ? "#ffc652" : "#55e6cb"; ctx.shadowBlur = 18; if (image.complete && image.naturalWidth > 0) { ctx.drawImage(image, -47, -48, 94, 94); } else { ctx.fillStyle = rocco ? "#ffcb75" : "#6df0df"; ctx.beginPath(); ctx.ellipse(0, 0, 25, 19, 0, 0, Math.PI * 2); ctx.fill(); ctx.fillStyle = "#17213b"; ctx.beginPath(); ctx.arc(10, -4, 4, 0, Math.PI * 2); ctx.fill(); } ctx.globalAlpha = .72; ctx.fillStyle = rocco ? "#dca3ff" : "#86f7a9"; ctx.beginPath(); ctx.arc(-39, 10, 14, 0, Math.PI * 2); ctx.fill(); ctx.restore(); };
    const draw = (now: number) => { const dt = Math.min(.033, (now - last) / 1000); last = now; const sky = ctx.createLinearGradient(0, 0, 0, H); sky.addColorStop(0, "#16184f"); sky.addColorStop(1, "#49255f"); ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H); ctx.fillStyle = "rgba(255,255,255,.5)"; for (let i = 0; i < 34; i++) ctx.fillRect((i * 83 + elapsed * 14) % W, (i * 47) % H, 2, 2);
      if (statusRef.current === "running") { elapsed += dt; velocity += GRAVITY * dt; y += velocity; if (gates[gates.length - 1].x < W - 130) gates.push({ x: W + 60, gapY: 150 + Math.random() * 320, scored: false }); gates.forEach(g => { g.x -= PIPE_SPEED * dt; if (!g.scored && g.x + 54 < 128) { g.scored = true; scoreValue++; if (now - lastHud > 150) { setScore(scoreValue); lastHud = now; } tone(720, .1, .025); } }); gates = gates.filter(g => g.x > -80); for (const g of gates) if (128 + HIT_X > g.x && 128 - HIT_X < g.x + 54 && (y - HIT_Y < g.gapY - GAP || y + HIT_Y > g.gapY + GAP)) crash(); if (y < 10 || y > H - 10) crash(); }
      gates.forEach(g => { ctx.fillStyle = "#ef6e66"; ctx.fillRect(g.x, 0, 54, g.gapY - GAP); ctx.fillRect(g.x, g.gapY + GAP, 54, H); ctx.fillStyle = "#ffcc75"; ctx.fillRect(g.x - 7, g.gapY - GAP - 8, 68, 12); ctx.fillRect(g.x - 7, g.gapY + GAP - 4, 68, 12); }); drawRider(); ctx.fillStyle = "#fff"; ctx.font = "700 18px sans-serif"; ctx.fillText(`TOOTS ${scoreValue}`, 18, 34); ctx.fillStyle = "#d8ddff"; ctx.font = "12px monospace"; ctx.fillText(`${riderRef.current.toUpperCase()} // BEST ${best}`, 18, 54); raf = requestAnimationFrame(draw); };
    const pointer = (event: PointerEvent) => { event.preventDefault(); flap(); }; const key = (event: KeyboardEvent) => { if (event.code === "Space" || event.code === "ArrowUp") { event.preventDefault(); if (!event.repeat) flap(); } };
    canvas.addEventListener("pointerdown", pointer); window.addEventListener("keydown", key); raf = requestAnimationFrame(draw); return () => { cancelAnimationFrame(raf); audio?.close().catch(() => {}); canvas.removeEventListener("pointerdown", pointer); window.removeEventListener("keydown", key); };
  }, []);
  return <section className="space-y-5" aria-labelledby="toot-troopers-title"><div className="flex flex-wrap items-end justify-between gap-3"><div><p className="text-xs font-bold uppercase tracking-[.2em] text-[#6df0df]">Arcade / fart-powered flight</p><h1 id="toot-troopers-title" className="font-display text-3xl font-bold">Toot Troopers</h1><p className="mt-1 max-w-xl text-sm text-[var(--muted)]">Apollo and Rocco are late for the sky picnic. Fart-flap through the traffic cones and keep the snacks airborne.</p></div><div className="flex gap-2"><button className="game-control rounded-md border border-[var(--border)] p-2" onClick={() => setSound(v => !v)} aria-label={sound ? "Mute game" : "Unmute game"}>{sound ? <Volume2 size={16} /> : <VolumeX size={16} />}</button><button className="game-control rounded-md border border-[var(--border)] px-3 py-2 text-xs" onClick={() => toggleFullscreen(stageRef.current)}>{immersive ? "Exit fullscreen" : "Fullscreen"}</button></div></div><div ref={stageRef} className={`game-stage relative mx-auto overflow-hidden bg-[#11133d] ${immersive ? "fixed inset-0 z-[70] flex max-w-none items-center rounded-none p-3" : "w-full min-w-0 max-w-[480px] rounded-2xl border border-[#6df0df]/50"}`}><canvas ref={canvasRef} width={W} height={H} className="block h-auto w-full touch-none" aria-label="Toot Troopers fart-powered side-scrolling game" />{immersive && <button className="absolute right-4 top-4 z-10 rounded-full border border-white/30 bg-[#11133d] p-3" onClick={exitFullscreen} aria-label="Exit fullscreen">×</button>}{status !== "running" && <div className="absolute inset-0 grid place-items-center bg-[#100d31]/55 p-5 text-center"><div><p className="text-xs font-bold uppercase tracking-[.2em] text-[#6df0df]">{status === "gameover" ? `Snack crash · ${score} gates` : "Ready for takeoff"}</p><button className="game-control mt-4 inline-flex items-center gap-2 rounded-xl bg-[#6df0df] px-5 py-3 font-bold text-[#10203a]" onClick={() => startRef.current()}><Play size={16} />{status === "gameover" ? "Try again" : "FART TO FLY"}</button></div></div>}</div><div className="flex flex-wrap items-center justify-between gap-3 text-sm"><div className="flex gap-2"><button className={`game-control rounded-full border px-3 py-2 ${rider === "apollo" ? "bg-[#6df0df] text-[#10203a]" : "border-[var(--border)]"}`} onClick={() => setRider("apollo")}>Apollo</button><button className={`game-control rounded-full border px-3 py-2 ${rider === "rocco" ? "bg-[#ffcb75] text-[#10203a]" : "border-[var(--border)]"}`} onClick={() => setRider("rocco")}>Rocco</button></div><span aria-live="polite">Toots {score} · Local best {best}</span><button className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => startRef.current()}><RotateCcw size={15} /> Fart</button></div><p className="text-xs text-[var(--muted)]">Tap/click the game or press Space / ↑ to fart-flap. One toot, one flap—no surprise double jumps.</p></section>;
}
