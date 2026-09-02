import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from "react";
import { ArrowDown, ArrowLeft, ArrowRight, ArrowUp, Maximize2, Minimize2, Pause, Play, RotateCcw, Volume2, VolumeX } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";
import {
  FAR_Z,
  PLAYER_Z,
  RIDERS,
  TUNING,
  applyHit,
  hazardResult,
  inHitWindow,
  jumpLift,
  loadBest,
  poseFromTimers,
  playIntent,
  runSpeed,
  saveBest,
  shiftLane,
  spawnGap,
  startJump,
  startSlide,
  swipeAction,
  togglePause,
  planHazards,
  type Difficulty,
  type GameStatus,
  type Hazard,
  type Lane,
  type Rider,
  type Treat,
} from "./apolloRoccoRun";

const WIDTH = 540;
const HEIGHT = 720;
const STEP = 1 / 60;

type InputName = "left" | "right" | "jump" | "slide";

const safeBest = () => {
  try {
    return loadBest(localStorage);
  } catch {
    return 0;
  }
};

function project(lane: number, z: number, lift = 0) {
  const depth = Math.max(0, Math.min(1, z / FAR_Z));
  const ease = depth * depth;
  const horizon = 108;
  const ground = HEIGHT - 28;
  const y = horizon + (ground - horizon) * (1 - ease);
  const half = 26 + 198 * (1 - ease);
  const x = WIDTH / 2 + (lane - 1) * (half * 0.72);
  const scale = 0.18 + 0.82 * (1 - ease);
  return { x, y: y - lift * 86 * scale, scale, half };
}

function drawPup(
  ctx: CanvasRenderingContext2D,
  rider: Rider,
  pose: ReturnType<typeof poseFromTimers>,
  bob: number,
  blink: boolean,
) {
  const accent = RIDERS[rider].accent;
  const sliding = pose === "slide";
  ctx.save();
  ctx.scale(sliding ? 1.18 : 1, sliding ? 0.62 : 1);
  ctx.translate(0, sliding ? 18 : 0);
  ctx.rotate(pose === "jump" ? -0.12 : bob * 0.08);
  ctx.fillStyle = accent;
  ctx.shadowColor = accent;
  ctx.shadowBlur = 18;
  ctx.beginPath();
  ctx.ellipse(0, 8, 26, 30, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.shadowBlur = 0;
  ctx.fillStyle = rider === "rocco" ? "#ffe7a8" : "#c8fff6";
  ctx.beginPath();
  ctx.ellipse(0, -18, 22, 20, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = accent;
  ctx.beginPath();
  ctx.ellipse(-18, -30, 8, 14, -0.4, 0, Math.PI * 2);
  ctx.ellipse(18, -30, 8, 14, 0.4, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#142038";
  ctx.beginPath();
  ctx.ellipse(-8, -20, 4.5, blink ? 1.2 : 5.2, 0, 0, Math.PI * 2);
  ctx.ellipse(8, -20, 4.5, blink ? 1.2 : 5.2, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#0a1020";
  ctx.beginPath();
  ctx.ellipse(0, -12, 4, 3, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#f4fbff";
  ctx.beginPath();
  ctx.arc(-7, -22, 1.4, 0, Math.PI * 2);
  ctx.arc(9, -22, 1.4, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = accent;
  ctx.beginPath();
  ctx.ellipse(24, 10, 10, 6, 0.4, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#10182c";
  if (pose === "jump") {
    ctx.fillRect(-16, 34, 10, 8);
    ctx.fillRect(6, 34, 10, 8);
  } else {
    ctx.fillRect(-18, 32, 12, 10);
    ctx.fillRect(6, 32, 12, 10);
  }
  ctx.fillStyle = "rgba(255,255,255,0.35)";
  ctx.fillRect(-16, -6, 18, 8);
  ctx.restore();
}

export function ApolloRoccoRun() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const statusRef = useRef<GameStatus>("ready");
  const riderRef = useRef<Rider>("apollo");
  const difficultyRef = useRef<Difficulty>("kid");
  const soundRef = useRef(true);
  const bestRef = useRef(safeBest());
  const startRef = useRef(() => {});
  const resetRef = useRef(() => {});
  const pauseRef = useRef(() => {});
  const actRef = useRef<(name: InputName) => void>(() => {});
  const [status, setStatus] = useState<GameStatus>("ready");
  const [rider, setRider] = useState<Rider>("apollo");
  const [difficulty, setDifficulty] = useState<Difficulty>("kid");
  const [score, setScore] = useState(0);
  const [hits, setHits] = useState<number>(TUNING.kid.hits);
  const [best, setBest] = useState(safeBest);
  const [sound, setSound] = useState(true);
  const { immersive, toggleFullscreen, exitFullscreen } = useGameFullscreen();
  const swipe = useRef<{ id: number; x: number; y: number } | null>(null);

  const setGameStatus = (next: GameStatus) => {
    statusRef.current = next;
    setStatus(next);
  };

  useEffect(() => { riderRef.current = rider; }, [rider]);
  useEffect(() => { difficultyRef.current = difficulty; }, [difficulty]);
  useEffect(() => { soundRef.current = sound; }, [sound]);
  useEffect(() => { bestRef.current = best; }, [best]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext("2d");
    if (!canvas || !ctx) return;

    let audio: AudioContext | undefined;
    let raf = 0;
    let last = performance.now();
    let accumulator = 0;
    let elapsed = 0;
    let distance = 0;
    let spawnAt = 10;
    let nextId = 1;
    let lane: Lane = 1;
    let visualLane = 1;
    let jumpLeft = 0;
    let slideLeft = 0;
    let hitsLeft: number = TUNING.kid.hits;
    let iframes = 0;
    let treats = 0;
    let bob = 0;
    let flash = 0;
    const hazards: Hazard[] = [];
    const snacks: Treat[] = [];
    const sparks: { x: number; y: number; vx: number; vy: number; life: number; color: string }[] = [];
    const portraits = {
      apollo: new Image(),
      rocco: new Image(),
    };
    const assetBase = import.meta.env.BASE_URL;
    portraits.apollo.src = `${assetBase}games/toot-troopers/apollo.png`;
    portraits.rocco.src = `${assetBase}games/toot-troopers/rocco.png`;

    const tone = (hz: number, seconds: number, volume = 0.03, type: OscillatorType = "triangle") => {
      if (!soundRef.current) return;
      try {
        audio ??= new AudioContext();
        if (audio.state === "suspended") void audio.resume().catch(() => {});
        const osc = audio.createOscillator();
        const gain = audio.createGain();
        osc.type = type;
        osc.frequency.setValueAtTime(hz, audio.currentTime);
        osc.frequency.exponentialRampToValueAtTime(Math.max(60, hz * 0.55), audio.currentTime + seconds);
        gain.gain.setValueAtTime(volume, audio.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audio.currentTime + seconds);
        osc.connect(gain).connect(audio.destination);
        osc.start();
        osc.stop(audio.currentTime + seconds);
      } catch {
        /* Audio is optional. */
      }
    };

    const burst = (x: number, y: number, color: string) => {
      for (let i = 0; i < 10; i += 1) {
        sparks.push({ x, y, vx: (Math.random() - 0.5) * 80, vy: -20 - Math.random() * 70, life: 0.35 + Math.random() * 0.35, color });
      }
    };

    const resetWorld = (running: boolean) => {
      const tuning = TUNING[difficultyRef.current];
      elapsed = 0;
      distance = 0;
      spawnAt = 8;
      nextId = 1;
      lane = 1;
      visualLane = 1;
      jumpLeft = 0;
      slideLeft = 0;
      hitsLeft = tuning.hits;
      iframes = 0;
      treats = 0;
      bob = 0;
      flash = 0;
      hazards.length = 0;
      snacks.length = 0;
      sparks.length = 0;
      setScore(0);
      setHits(hitsLeft);
      setGameStatus(running ? "running" : "ready");
    };

    const start = () => {
      resetWorld(true);
      tone(520, 0.12, 0.03, "square");
    };

    const finish = () => {
      let nextBest = Math.max(bestRef.current, Math.floor(distance));
      try {
        nextBest = saveBest(localStorage, Math.floor(distance));
      } catch {
        /* Local scores are optional. */
      }
      bestRef.current = nextBest;
      setBest(nextBest);
      setGameStatus("gameover");
      tone(90, 0.32, 0.05, "sawtooth");
    };

    const act = (name: InputName) => {
      if (statusRef.current === "ready" || statusRef.current === "gameover") {
        if (name === "jump" || name === "slide") start();
        return;
      }
      if (statusRef.current !== "running") return;
      const tuning = TUNING[difficultyRef.current];
      if (name === "left") lane = shiftLane(lane, -1);
      if (name === "right") lane = shiftLane(lane, 1);
      if (name === "jump") {
        const next = startJump(jumpLeft, slideLeft, tuning.jumpTime);
        if (next !== jumpLeft) {
          jumpLeft = next;
          tone(640, 0.1, 0.025, "square");
        }
      }
      if (name === "slide") {
        const next = startSlide(jumpLeft, slideLeft, tuning.slideTime);
        if (next !== slideLeft) {
          slideLeft = next;
          tone(220, 0.12, 0.03, "triangle");
        }
      }
    };

    const pause = () => setGameStatus(togglePause(statusRef.current));

    startRef.current = start;
    resetRef.current = () => resetWorld(false);
    pauseRef.current = pause;
    actRef.current = act;

    const update = (dt: number) => {
      const tuning = TUNING[difficultyRef.current];
      const speed = runSpeed(elapsed, difficultyRef.current);
      elapsed += dt;
      distance += speed * dt * 4.2;
      bob += dt * 10;
      jumpLeft = Math.max(0, jumpLeft - dt);
      slideLeft = Math.max(0, slideLeft - dt);
      iframes = Math.max(0, iframes - dt);
      flash = Math.max(0, flash - dt);
      visualLane += (lane - visualLane) * Math.min(1, dt * 12);

      spawnAt -= speed * dt;
      if (spawnAt <= 0) {
        const pack = planHazards(tuning.maxBlockedLanes, Math.random);
        pack.forEach((item) => {
          hazards.push({ id: nextId, lane: item.lane, z: FAR_Z, kind: item.kind });
          nextId += 1;
        });
        const used = new Set(pack.map((item) => item.lane));
        const open = ([0, 1, 2] as Lane[]).filter((item) => !used.has(item));
        if (open.length && Math.random() < 0.55) {
          snacks.push({ id: nextId, lane: open[Math.floor(Math.random() * open.length)], z: FAR_Z + 3, taken: false });
          nextId += 1;
        }
        spawnAt = spawnGap(difficultyRef.current, Math.random);
      }

      hazards.forEach((hazard) => { hazard.z -= speed * dt; });
      snacks.forEach((treat) => { treat.z -= speed * dt; });
      while (hazards[0] && hazards[0].z < PLAYER_Z - 1.4) hazards.shift();
      while (snacks[0] && (snacks[0].taken || snacks[0].z < PLAYER_Z - 1.4)) snacks.shift();

      const pose = poseFromTimers(jumpLeft, slideLeft);
      for (const treat of snacks) {
        if (!treat.taken && treat.lane === lane && inHitWindow(treat.z, tuning.hitDepth + 0.4)) {
          treat.taken = true;
          treats += 1;
          distance += 8;
          const point = project(treat.lane, treat.z, 0.4);
          burst(point.x, point.y, RIDERS[riderRef.current].accent);
          tone(880, 0.08, 0.02);
        }
      }

      for (const hazard of hazards) {
        if (hazard.lane !== lane || !inHitWindow(hazard.z, tuning.hitDepth)) continue;
        if (hazardResult(pose, hazard.kind) === "clear") continue;
        const result = applyHit(hitsLeft, iframes, tuning.iframes);
        hitsLeft = result.hitsLeft;
        iframes = result.iframes;
        if (!result.ignored) {
          flash = 0.28;
          setHits(hitsLeft);
          const point = project(hazard.lane, hazard.z, 0);
          burst(point.x, point.y, "#ff6b8a");
          tone(140, 0.16, 0.04, "sawtooth");
        }
        if (result.dead) {
          finish();
          break;
        }
      }

      sparks.forEach((spark) => {
        spark.x += spark.vx * dt;
        spark.y += spark.vy * dt;
        spark.life -= dt;
      });
      for (let i = sparks.length - 1; i >= 0; i -= 1) if (sparks[i].life <= 0) sparks.splice(i, 1);
      setScore(Math.floor(distance) + treats * 5);
    };

    const drawTree = (seed: number, side: -1 | 1, z: number) => {
      const point = project(side === -1 ? 0 : 2, z, 0);
      const x = point.x + side * (point.half + 36 * point.scale);
      const h = 70 * point.scale;
      ctx.fillStyle = "#10221c";
      ctx.fillRect(x - 4 * point.scale, point.y - h, 8 * point.scale, h);
      ctx.fillStyle = seed % 2 === 0 ? "#1d4a3a" : "#16382e";
      ctx.beginPath();
      ctx.ellipse(x, point.y - h, 22 * point.scale, 28 * point.scale, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "rgba(109,240,223,0.18)";
      ctx.beginPath();
      ctx.arc(x + 6 * point.scale, point.y - h - 4, 6 * point.scale, 0, Math.PI * 2);
      ctx.fill();
    };

    const draw = () => {
      const sky = ctx.createLinearGradient(0, 0, 0, HEIGHT);
      sky.addColorStop(0, "#0b1230");
      sky.addColorStop(0.45, "#12203a");
      sky.addColorStop(1, "#071018");
      ctx.fillStyle = sky;
      ctx.fillRect(0, 0, WIDTH, HEIGHT);

      ctx.fillStyle = "rgba(238,240,250,0.55)";
      for (let i = 0; i < 42; i += 1) {
        const x = (i * 97 + elapsed * 8) % WIDTH;
        const y = 18 + (i * 37) % 120;
        ctx.fillRect(x, y, i % 5 === 0 ? 2 : 1, i % 5 === 0 ? 2 : 1);
      }

      const near = project(1, PLAYER_Z, 0);
      const far = project(1, FAR_Z, 0);
      ctx.beginPath();
      ctx.moveTo(near.x - near.half, near.y + 18);
      ctx.lineTo(far.x - far.half, far.y);
      ctx.lineTo(far.x + far.half, far.y);
      ctx.lineTo(near.x + near.half, near.y + 18);
      ctx.closePath();
      const pathFill = ctx.createLinearGradient(0, far.y, 0, near.y);
      pathFill.addColorStop(0, "#163028");
      pathFill.addColorStop(1, "#1f4638");
      ctx.fillStyle = pathFill;
      ctx.fill();
      ctx.strokeStyle = "rgba(109,240,223,0.22)";
      ctx.lineWidth = 2;
      ctx.stroke();

      for (const laneIndex of [0.5, 1.5] as const) {
        const a = project(laneIndex, PLAYER_Z, 0);
        const b = project(laneIndex, FAR_Z, 0);
        ctx.strokeStyle = "rgba(255,255,255,0.16)";
        ctx.setLineDash([14, 16]);
        ctx.beginPath();
        ctx.moveTo(a.x, a.y + 8);
        ctx.lineTo(b.x, b.y);
        ctx.stroke();
      }
      ctx.setLineDash([]);

      const scroll = elapsed * 9;
      for (let i = 0; i < 10; i += 1) {
        const z = ((i * 5 + scroll) % FAR_Z);
        drawTree(i, -1, z);
        drawTree(i + 3, 1, z + 1.4);
      }

      const ordered = [...hazards, ...snacks.filter((item) => !item.taken)].sort((a, b) => b.z - a.z);
      ordered.forEach((item) => {
        if ("kind" in item) {
          const lift = item.kind === "high" ? 0.72 : 0;
          const point = project(item.lane, item.z, lift);
          ctx.save();
          ctx.translate(point.x, point.y);
          ctx.scale(point.scale, point.scale);
          if (item.kind === "low") {
            ctx.fillStyle = "#6b3e24";
            ctx.beginPath();
            ctx.ellipse(0, -4, 30, 12, 0, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = "#86f7a9";
            ctx.fillRect(-20, -12, 16, 5);
          } else {
            ctx.strokeStyle = "#6df0df";
            ctx.lineWidth = 4;
            ctx.beginPath();
            ctx.moveTo(-18, -70);
            ctx.quadraticCurveTo(0, -10, 16, 8);
            ctx.stroke();
            ctx.fillStyle = "#ffcb75";
            ctx.beginPath();
            ctx.arc(16, 8, 7, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = "rgba(109,240,223,0.35)";
            ctx.fillRect(-26, -78, 52, 10);
          }
          ctx.restore();
        } else {
          const point = project(item.lane, item.z, 0.35);
          ctx.save();
          ctx.translate(point.x, point.y);
          ctx.scale(point.scale, point.scale);
          ctx.fillStyle = "#ffcb75";
          ctx.shadowColor = "#ffcb75";
          ctx.shadowBlur = 16;
          ctx.beginPath();
          ctx.arc(0, 0, 10, 0, Math.PI * 2);
          ctx.fill();
          ctx.restore();
        }
      });

      sparks.forEach((spark) => {
        ctx.globalAlpha = Math.max(0, spark.life * 2);
        ctx.fillStyle = spark.color;
        ctx.fillRect(spark.x, spark.y, 3, 3);
      });
      ctx.globalAlpha = 1;

      const pose = poseFromTimers(jumpLeft, slideLeft);
      const lift = jumpLift(jumpLeft, TUNING[difficultyRef.current].jumpTime);
      const player = project(visualLane, PLAYER_Z, lift);
      ctx.save();
      ctx.translate(player.x, player.y - 18);
      ctx.scale(player.scale * 1.15, player.scale * 1.15);
      if (iframes > 0 && Math.floor(elapsed * 16) % 2 === 0) ctx.globalAlpha = 0.45;
      const portrait = portraits[riderRef.current];
      if (portrait.complete && portrait.naturalWidth > 0 && pose !== "slide") {
        ctx.save();
        ctx.translate(0, pose === "jump" ? -8 : Math.sin(bob) * 3);
        ctx.drawImage(portrait, -42, -58, 84, 84);
        ctx.restore();
      } else {
        drawPup(ctx, riderRef.current, pose, Math.sin(bob), Math.floor(elapsed * 2) % 9 === 0);
      }
      ctx.restore();

      if (flash > 0) {
        ctx.fillStyle = `rgba(255,80,110,${flash})`;
        ctx.fillRect(0, 0, WIDTH, HEIGHT);
      }

      ctx.fillStyle = "#eef0fa";
      ctx.font = "700 16px Space Grotesk, sans-serif";
      ctx.fillText(`${RIDERS[riderRef.current].label.toUpperCase()}  ${Math.floor(distance).toString().padStart(4, "0")}m`, 18, 28);
      ctx.fillStyle = "#8fa6c5";
      ctx.font = "12px JetBrains Mono, monospace";
      ctx.fillText(`${difficultyRef.current.toUpperCase()} · SNACKS ${treats} · BEST ${bestRef.current}`, 18, 48);
      ctx.fillStyle = "#ff6b8a";
      for (let i = 0; i < TUNING[difficultyRef.current].hits; i += 1) {
        ctx.globalAlpha = i < hitsLeft ? 1 : 0.22;
        ctx.beginPath();
        ctx.arc(WIDTH - 22 - i * 18, 24, 6, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.globalAlpha = 1;
    };

    const frame = (now: number) => {
      const elapsedFrame = Math.min(0.05, (now - last) / 1000);
      last = now;
      if (statusRef.current === "running") {
        accumulator += elapsedFrame;
        while (accumulator >= STEP) {
          update(STEP);
          accumulator -= STEP;
        }
      }
      draw();
      raf = requestAnimationFrame(frame);
    };

    const keyDown = (event: KeyboardEvent) => {
      if (["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Space", "KeyA", "KeyD", "KeyW", "KeyS"].includes(event.code)) event.preventDefault();
      if (event.repeat) return;
      if (event.code === "ArrowLeft" || event.code === "KeyA") act("left");
      if (event.code === "ArrowRight" || event.code === "KeyD") act("right");
      if (event.code === "ArrowUp" || event.code === "KeyW" || event.code === "Space") act("jump");
      if (event.code === "ArrowDown" || event.code === "KeyS") act("slide");
      if (event.code === "KeyP" || event.code === "Escape") pause();
    };

    window.addEventListener("keydown", keyDown);
    raf = requestAnimationFrame(frame);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("keydown", keyDown);
      audio?.close().catch(() => {});
    };
  }, []);

  const overlayAction = () => {
    const intent = playIntent(status);
    if (intent === "resume") setGameStatus("running");
    else startRef.current();
  };

  const onCanvasPointerDown = (event: ReactPointerEvent<HTMLCanvasElement>) => {
    swipe.current = { id: event.pointerId, x: event.clientX, y: event.clientY };
  };
  const onCanvasPointerUp = (event: ReactPointerEvent<HTMLCanvasElement>) => {
    const start = swipe.current;
    swipe.current = null;
    if (!start || start.id !== event.pointerId) return;
    const action = swipeAction(event.clientX - start.x, event.clientY - start.y);
    if (action) actRef.current(action);
  };

  const hold = (name: InputName) => ({
    onPointerDown: (event: ReactPointerEvent<HTMLButtonElement>) => {
      event.preventDefault();
      event.stopPropagation();
      actRef.current(name);
    },
  });

  return (
    <section className="space-y-5" aria-labelledby="apollo-rocco-run-title">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <p className="text-xs font-bold uppercase tracking-[.2em] text-[#6df0df]">Arcade / endless-runner genre</p>
          <h1 id="apollo-rocco-run-title" className="font-display text-3xl font-bold">Apollo &amp; Rocco Run</h1>
          <p className="mt-1 max-w-xl text-sm text-[var(--muted)]">
            Original Beckify game featuring Apollo and Rocco. Keep running the star-moss trail, hop the logs, and slide under the glow-vines.
          </p>
        </div>
        <div className="flex items-center gap-2 text-xs text-[var(--muted)]">
          <span>LOCAL BEST {best.toString().padStart(4, "0")}</span>
          <button type="button" className="game-icon-button rounded-md border border-[var(--border)] p-2" onClick={() => setSound((value) => !value)} aria-label={sound ? "Mute game sounds" : "Enable game sounds"}>{sound ? <Volume2 size={16} /> : <VolumeX size={16} />}</button>
          <button type="button" className="game-icon-button rounded-md border border-[var(--border)] p-2" onClick={() => toggleFullscreen(stageRef.current)} aria-label={immersive ? "Exit fullscreen" : "Play fullscreen"}>{immersive ? <Minimize2 size={16} /> : <Maximize2 size={16} />}</button>
        </div>
      </div>

      <div
        ref={stageRef}
        className={`game-stage relative mx-auto overflow-hidden bg-[#071018] shadow-[0_24px_80px_rgba(0,0,0,.42)] ${immersive ? "fixed inset-0 z-[70] flex max-w-none items-center rounded-none border-0 p-3" : "max-w-[540px] rounded-2xl border border-[#2e5d86]"}`}
      >
        <canvas
          ref={canvasRef}
          width={WIDTH}
          height={HEIGHT}
          className="block h-auto w-full touch-none select-none"
          aria-label="Apollo and Rocco Run three-lane endless runner"
          onPointerDown={onCanvasPointerDown}
          onPointerUp={onCanvasPointerUp}
          onPointerCancel={() => { swipe.current = null; }}
        />
        {immersive ? <button type="button" className="absolute right-4 top-4 z-20 rounded-full border border-white/30 bg-[#06101f]/90 p-3 text-white shadow-lg" onClick={exitFullscreen} aria-label="Exit fullscreen"><Minimize2 size={18} /></button> : null}

        <div className="pointer-events-none absolute inset-x-0 top-3 z-10 flex justify-end px-3">
          <div className="pointer-events-auto flex gap-2">
            <button type="button" className="grid h-11 w-11 place-items-center rounded-full border border-white/25 bg-[#06101f]/80 text-white" onClick={() => pauseRef.current()} aria-label={status === "paused" ? "Resume run" : "Pause run"}>{status === "paused" ? <Play size={16} /> : <Pause size={16} />}</button>
            <button type="button" className="grid h-11 w-11 place-items-center rounded-full border border-white/25 bg-[#06101f]/80 text-white" onClick={() => toggleFullscreen(stageRef.current)} aria-label={immersive ? "Exit fullscreen" : "Play fullscreen"}>{immersive ? <Minimize2 size={16} /> : <Maximize2 size={16} />}</button>
          </div>
        </div>

        {status !== "running" ? (
          <div className="absolute inset-0 z-20 flex items-center justify-center bg-[#06101f]/78 p-5 text-center backdrop-blur-[2px]" onClick={(event) => { if ((event.target as HTMLElement).closest("button")) return; overlayAction(); }}>
            <div className="max-w-sm">
              <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#6df0df]">
                {status === "gameover" ? "Trail ended" : status === "paused" ? "Run paused" : "Star-moss trail"}
              </p>
              <h2 className="mt-2 font-display text-3xl font-bold text-white">
                {status === "gameover" ? "Try another lap." : status === "paused" ? "Still on the path." : "Pick a pup."}
              </h2>
              <p className="mt-3 text-sm leading-6 text-[#b9c8dc]">
                {status === "gameover"
                  ? `You ran ${score}. Local best ${best}. This device only.`
                  : status === "paused"
                    ? "Pause keeps this run. Resume when you are ready."
                    : "Original Beckify game featuring Apollo and Rocco. KID is the default — wide gaps, slow ramp, three hits."}
              </p>
              {status !== "paused" ? (
                <>
                  <div className="mt-5 flex justify-center gap-2">
                    <button type="button" className={`game-control rounded-full border px-4 py-2 text-sm font-semibold ${rider === "apollo" ? "border-[#6df0df] bg-[#6df0df] text-[#06101f]" : "border-white/20 text-white"}`} onClick={() => setRider("apollo")}>Apollo</button>
                    <button type="button" className={`game-control rounded-full border px-4 py-2 text-sm font-semibold ${rider === "rocco" ? "border-[#ffcb75] bg-[#ffcb75] text-[#06101f]" : "border-white/20 text-white"}`} onClick={() => setRider("rocco")}>Rocco</button>
                  </div>
                  <div className="mt-3 flex justify-center gap-2">
                    <button type="button" className={`game-control rounded-full border px-4 py-2 text-sm font-semibold ${difficulty === "kid" ? "border-[#6df0df] bg-[#6df0df] text-[#06101f]" : "border-white/20 text-white"}`} onClick={() => setDifficulty("kid")}>KID</button>
                    <button type="button" className={`game-control rounded-full border px-4 py-2 text-sm font-semibold ${difficulty === "cadet" ? "border-[#ffcb75] bg-[#ffcb75] text-[#06101f]" : "border-white/20 text-white"}`} onClick={() => setDifficulty("cadet")}>CADET</button>
                  </div>
                </>
              ) : null}
              <button type="button" className="game-control pointer-events-auto mt-5 inline-flex items-center gap-2 rounded-lg bg-[#6df0df] px-5 py-3 text-sm font-semibold text-[#06101f]" onClick={overlayAction}>
                <Play size={16} />
                {status === "paused" ? "Resume" : status === "gameover" ? "Run again" : "Start run"}
              </button>
              {status === "paused" ? (
                <button type="button" className="game-control mt-3 inline-flex items-center gap-2 rounded-lg border border-white/20 px-4 py-2 text-sm text-white" onClick={() => resetRef.current()}>
                  <RotateCcw size={15} /> Start over
                </button>
              ) : null}
            </div>
          </div>
        ) : null}

        <div className="pointer-events-none absolute inset-x-0 bottom-0 z-10 flex items-end justify-between gap-3 p-3" aria-label="On-canvas runner controls">
          <div className="pointer-events-auto flex gap-2">
            <button type="button" className="grid h-[5.6rem] w-[5.6rem] place-items-center rounded-full border border-[#6df0df]/70 bg-[#06101f]/75 text-white shadow-[0_0_18px_rgba(109,240,223,.25)]" aria-label="Move left" {...hold("left")}>
              <ArrowLeft size={32} />
              <span className="text-[10px] font-bold uppercase tracking-[0.16em]">Left</span>
            </button>
            <button type="button" className="grid h-[5.6rem] w-[5.6rem] place-items-center rounded-full border border-[#6df0df]/70 bg-[#06101f]/75 text-white shadow-[0_0_18px_rgba(109,240,223,.25)]" aria-label="Move right" {...hold("right")}>
              <ArrowRight size={32} />
              <span className="text-[10px] font-bold uppercase tracking-[0.16em]">Right</span>
            </button>
          </div>
          <div className="pointer-events-auto flex gap-2">
            <button type="button" className="grid h-[5.6rem] w-[5.6rem] place-items-center rounded-full border border-[#ffcb75]/70 bg-[#06101f]/75 text-white shadow-[0_0_18px_rgba(255,203,117,.22)]" aria-label="Jump" {...hold("jump")}>
              <ArrowUp size={32} />
              <span className="text-[10px] font-bold uppercase tracking-[0.16em]">Jump</span>
            </button>
            <button type="button" className="grid h-[5.6rem] w-[5.6rem] place-items-center rounded-full border border-[#ffcb75]/70 bg-[#06101f]/75 text-white shadow-[0_0_18px_rgba(255,203,117,.22)]" aria-label="Slide" {...hold("slide")}>
              <ArrowDown size={32} />
              <span className="text-[10px] font-bold uppercase tracking-[0.16em]">Slide</span>
            </button>
          </div>
        </div>
      </div>

      <p className="text-xs text-[var(--muted)]">
        Hearts left {hits}. Arrows or WASD to change lanes, Space / Up to jump, Down to slide, P to pause. Swipe the trail the same way. Pads stay on the playfield. Local best is saved on this device only.
      </p>
    </section>
  );
}
