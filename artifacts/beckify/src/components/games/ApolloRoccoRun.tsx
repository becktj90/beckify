import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from "react";
import { ArrowDown, ArrowLeft, ArrowRight, ArrowUp, Maximize2, Minimize2, Pause, Play, RotateCcw, Volume2, VolumeX } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";
import { KIDS, drawKidPortrait, kidSrc } from "./characterArt";
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
  runPoints,
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
  const horizon = 168;
  const ground = HEIGHT - 28;
  const y = horizon + (ground - horizon) * (1 - ease);
  const half = 26 + 198 * (1 - ease);
  const x = WIDTH / 2 + (lane - 1) * (half * 0.72);
  const scale = 0.18 + 0.82 * (1 - ease);
  return { x, y: y - lift * 86 * scale, scale, half };
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
  const assetBase = import.meta.env.BASE_URL;

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
    portraits.apollo.src = kidSrc("apollo", assetBase);
    portraits.rocco.src = kidSrc("rocco", assetBase);

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
      const points = runPoints(distance, treats);
      setScore(points);
      let nextBest = Math.max(bestRef.current, points);
      try {
        nextBest = saveBest(localStorage, points);
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
      setScore(runPoints(distance, treats));
    };

    const drawFence = (z: number) => {
      const point = project(1, z, 0);
      ctx.fillStyle = "#c4b49a";
      ctx.fillRect(0, point.y - 46 * point.scale, WIDTH, 8 * point.scale);
      for (let i = 0; i < 9; i += 1) {
        const x = 18 + i * 62;
        ctx.fillStyle = i % 2 ? "#b89a74" : "#d2c0a2";
        ctx.fillRect(x, point.y - 78 * point.scale, 10 * point.scale, 78 * point.scale);
      }
    };

    const drawShrub = (seed: number, side: -1 | 1, z: number) => {
      const point = project(side === -1 ? 0 : 2, z, 0);
      const x = point.x + side * (point.half + 40 * point.scale);
      ctx.fillStyle = seed % 2 === 0 ? "#2f7a3c" : "#246433";
      ctx.beginPath();
      ctx.ellipse(x, point.y - 18 * point.scale, 26 * point.scale, 22 * point.scale, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#86f7a9";
      ctx.beginPath();
      ctx.arc(x + 8 * point.scale, point.y - 24 * point.scale, 6 * point.scale, 0, Math.PI * 2);
      ctx.fill();
    };

    const draw = () => {
      const sky = ctx.createLinearGradient(0, 0, 0, HEIGHT);
      sky.addColorStop(0, "#7ec8ff");
      sky.addColorStop(0.42, "#b7e4ff");
      sky.addColorStop(0.62, "#d8f3c9");
      sky.addColorStop(1, "#6fbf6a");
      ctx.fillStyle = sky;
      ctx.fillRect(0, 0, WIDTH, HEIGHT);

      ctx.fillStyle = "rgba(255,255,255,0.85)";
      for (let i = 0; i < 5; i += 1) {
        const x = (i * 140 + elapsed * 12) % (WIDTH + 80) - 40;
        const y = 36 + (i * 17) % 48;
        ctx.beginPath();
        ctx.ellipse(x, y, 34, 16, 0, 0, Math.PI * 2);
        ctx.ellipse(x + 22, y + 4, 26, 14, 0, 0, Math.PI * 2);
        ctx.fill();
      }

      const near = project(1, PLAYER_Z, 0);
      const far = project(1, FAR_Z, 0);
      drawFence(FAR_Z - 2);
      ctx.beginPath();
      ctx.moveTo(near.x - near.half, near.y + 18);
      ctx.lineTo(far.x - far.half, far.y);
      ctx.lineTo(far.x + far.half, far.y);
      ctx.lineTo(near.x + near.half, near.y + 18);
      ctx.closePath();
      const pathFill = ctx.createLinearGradient(0, far.y, 0, near.y);
      pathFill.addColorStop(0, "#d7b07a");
      pathFill.addColorStop(1, "#c8944e");
      ctx.fillStyle = pathFill;
      ctx.fill();
      ctx.strokeStyle = "rgba(255,255,255,0.35)";
      ctx.lineWidth = 3;
      ctx.stroke();

      for (const laneIndex of [0.5, 1.5] as const) {
        const a = project(laneIndex, PLAYER_Z, 0);
        const b = project(laneIndex, FAR_Z, 0);
        ctx.strokeStyle = "rgba(255,255,255,0.45)";
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
        drawShrub(i, -1, z);
        drawShrub(i + 3, 1, z + 1.4);
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
            ctx.fillStyle = "#2f6fbf";
            ctx.beginPath();
            ctx.ellipse(0, -8, 34, 16, 0, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = "#7ec8ff";
            ctx.beginPath();
            ctx.ellipse(0, -16, 22, 10, 0, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = "#f4d35e";
            ctx.fillRect(-8, -6, 16, 8);
          } else {
            ctx.strokeStyle = "#55c1ff";
            ctx.lineWidth = 5;
            ctx.beginPath();
            ctx.moveTo(-22, -78);
            ctx.quadraticCurveTo(8, -20, 18, 6);
            ctx.stroke();
            ctx.fillStyle = "#ff7a2d";
            ctx.beginPath();
            ctx.arc(18, 8, 9, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = "rgba(126, 200, 255, 0.45)";
            ctx.fillRect(-28, -86, 56, 12);
          }
          ctx.restore();
        } else {
          const point = project(item.lane, item.z, 0.35);
          ctx.save();
          ctx.translate(point.x, point.y);
          ctx.scale(point.scale, point.scale);
          ctx.fillStyle = riderRef.current === "rocco" ? "#ff5ea8" : "#ff7a2d";
          ctx.shadowColor = ctx.fillStyle;
          ctx.shadowBlur = 16;
          ctx.beginPath();
          ctx.arc(0, 0, 11, 0, Math.PI * 2);
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
      const hidden = iframes > 0 && Math.floor(elapsed * 16) % 2 === 0;
      drawKidPortrait(ctx, portraits[riderRef.current], 0, pose === "jump" ? -10 : Math.sin(bob) * 3, 92, {
        ring: RIDERS[riderRef.current].accent,
        squash: pose === "slide" ? 0.62 : 1,
        alpha: hidden ? 0.45 : 1,
        tilt: pose === "jump" ? -0.1 : 0,
      });
      ctx.restore();

      if (flash > 0) {
        ctx.fillStyle = `rgba(255,80,110,${flash})`;
        ctx.fillRect(0, 0, WIDTH, HEIGHT);
      }
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
    const visibility = () => {
      if (document.hidden && statusRef.current === "running") setGameStatus("paused");
    };
    document.addEventListener("visibilitychange", visibility);
    raf = requestAnimationFrame(frame);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("keydown", keyDown);
      document.removeEventListener("visibilitychange", visibility);
      audio?.close().catch(() => {});
    };
  }, [assetBase]);

  const overlayAction = () => {
    const intent = playIntent(status);
    if (intent === "resume") setGameStatus("running");
    else startRef.current();
  };

  const onCanvasPointerDown = (event: ReactPointerEvent<HTMLCanvasElement>) => {
    swipe.current = { id: event.pointerId, x: event.clientX, y: event.clientY };
    event.currentTarget.setPointerCapture(event.pointerId);
  };
  const endSwipe = (event: ReactPointerEvent<HTMLCanvasElement>) => {
    const start = swipe.current;
    swipe.current = null;
    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
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

  const activeKid = KIDS[rider];
  const maxHits = TUNING[difficulty].hits;

  return (
    <section className="space-y-5" aria-labelledby="apollo-rocco-run-title">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <p className="text-xs font-bold uppercase tracking-[.2em]" style={{ color: activeKid.accent }}>Backyard water-balloon run</p>
          <h1 id="apollo-rocco-run-title" className="font-display text-3xl font-bold">Apollo &amp; Rocco Run</h1>
          <p className="mt-1 max-w-xl text-sm text-[var(--muted)]">
            Apollo holds the orange balloon. Rocco brings the pink balloon and water gun. Hop the kiddie pools, slide under the sprinklers, grab snacks.
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
        className={`game-stage relative mx-auto overflow-hidden bg-[#7ec8ff] shadow-[0_24px_80px_rgba(0,0,0,.42)] ${immersive ? "fixed inset-0 z-[70] flex max-w-none items-center rounded-none border-0 p-3" : "w-full min-w-0 max-w-[540px] rounded-2xl border border-[#7ec8ff]"}`}
      >
        <canvas
          ref={canvasRef}
          width={WIDTH}
          height={HEIGHT}
          className="block h-auto w-full touch-none select-none"
          aria-label="Apollo and Rocco Run three-lane backyard runner"
          onPointerDown={onCanvasPointerDown}
          onPointerUp={endSwipe}
          onPointerCancel={endSwipe}
        />
        {immersive ? <button type="button" className="absolute right-4 top-4 z-30 rounded-full border border-white/30 bg-[#06101f]/90 p-3 text-white shadow-lg" onClick={exitFullscreen} aria-label="Exit fullscreen"><Minimize2 size={18} /></button> : null}

        <div className="kid-hud">
          <div className="kid-chip" style={{ color: activeKid.accent }}>
            <img src={kidSrc(rider, assetBase)} alt="" width={32} height={32} />
            <div>
              <span>{activeKid.label}</span>
              <strong>{score.toString().padStart(4, "0")}</strong>
            </div>
          </div>
          <div className="kid-chip">
            <div>
              <span>{difficulty.toUpperCase()}</span>
              <div className="kid-hearts" aria-label={`${hits} hearts left`}>
                {Array.from({ length: maxHits }, (_, index) => <i key={index} className={index < hits ? "" : "is-empty"} />)}
              </div>
            </div>
            <div className="kid-stage-actions">
              <button type="button" onClick={() => pauseRef.current()} aria-label={status === "paused" ? "Resume run" : "Pause run"}>{status === "paused" ? <Play size={16} /> : <Pause size={16} />}</button>
              <button type="button" onClick={() => toggleFullscreen(stageRef.current)} aria-label={immersive ? "Exit fullscreen" : "Play fullscreen"}>{immersive ? <Minimize2 size={16} /> : <Maximize2 size={16} />}</button>
            </div>
          </div>
        </div>

        {status !== "running" ? (
          <div className="kid-overlay" onClick={(event) => { if ((event.target as HTMLElement).closest("button")) return; overlayAction(); }}>
            <div className="kid-overlay-card">
              <p className="text-xs font-semibold uppercase tracking-[0.2em]" style={{ color: activeKid.accent }}>
                {status === "gameover" ? "Splash out" : status === "paused" ? "Timeout" : "Pick a kid"}
              </p>
              <h2 className="font-display font-bold">
                {status === "gameover" ? "Try another lap." : status === "paused" ? "Still on the path." : "Water balloon run."}
              </h2>
              <p>
                {status === "gameover"
                  ? `You scored ${score}. Local best ${best}. This device only.`
                  : status === "paused"
                    ? "Pause keeps this run. Resume when you are ready."
                    : "Apollo is the orange balloon kid. Rocco is the pink balloon / water gun kid. KID is the default — wide gaps, slow ramp, four hits."}
              </p>
              {status !== "paused" ? (
                <>
                  <div className="kid-pick">
                    {(["apollo", "rocco"] as Rider[]).map((id) => (
                      <button
                        key={id}
                        type="button"
                        className={rider === id ? "is-on" : ""}
                        style={rider === id ? { borderColor: KIDS[id].accent, background: KIDS[id].accent, color: KIDS[id].ink } : undefined}
                        onClick={() => setRider(id)}
                      >
                        <img src={kidSrc(id, assetBase)} alt="" width={72} height={72} />
                        {KIDS[id].label}
                      </button>
                    ))}
                  </div>
                  <div className="mt-3 flex justify-center gap-2">
                    <button type="button" className={`game-control rounded-full border px-4 py-2 text-sm font-semibold ${difficulty === "kid" ? "border-[#ff7a2d] bg-[#ff7a2d] text-[#1a140c]" : "border-white/20 text-white"}`} onClick={() => setDifficulty("kid")}>KID</button>
                    <button type="button" className={`game-control rounded-full border px-4 py-2 text-sm font-semibold ${difficulty === "cadet" ? "border-[#ffcb75] bg-[#ffcb75] text-[#1a140c]" : "border-white/20 text-white"}`} onClick={() => setDifficulty("cadet")}>CADET</button>
                  </div>
                </>
              ) : null}
              <button type="button" className="kid-play" style={{ background: activeKid.accent, color: activeKid.ink }} onClick={overlayAction}>
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

        <div className="kid-pads" aria-label="On-canvas runner controls">
          <div>
            <button type="button" className="kid-pad" style={{ borderColor: activeKid.accent }} aria-label="Move left" {...hold("left")}>
              <ArrowLeft size={26} />
              <span>Left</span>
            </button>
            <button type="button" className="kid-pad" style={{ borderColor: activeKid.accent }} aria-label="Move right" {...hold("right")}>
              <ArrowRight size={26} />
              <span>Right</span>
            </button>
          </div>
          <div>
            <button type="button" className="kid-pad" style={{ borderColor: "#ffcb75" }} aria-label="Jump" {...hold("jump")}>
              <ArrowUp size={26} />
              <span>Jump</span>
            </button>
            <button type="button" className="kid-pad" style={{ borderColor: "#ffcb75" }} aria-label="Slide" {...hold("slide")}>
              <ArrowDown size={26} />
              <span>Slide</span>
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
