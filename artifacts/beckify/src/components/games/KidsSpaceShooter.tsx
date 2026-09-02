import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from "react";
import { Crosshair, Expand, Minimize2, Pause, Play, RotateCcw, Shield, Volume2, VolumeX, Zap } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";
import {
  ENEMY_BOLT_RADIUS,
  HIT_IFRAMES,
  MAX_HULL,
  PICKUP_RADIUS,
  PLAYFIELD,
  POWER_DURATION,
  START_GUARD,
  applyHeart,
  applyKill,
  clamp,
  enemyFallSpeed,
  enemyHp,
  enemyLeaked,
  fireInterval,
  hudChanged,
  loadScores,
  pickPowerUp,
  playIntent,
  recordRun,
  shipHitsEnemy,
  spawnInterval,
  togglePause,
  type BoardEntry,
  type GameStatus,
  type HudSnapshot,
  type PowerUpKind,
} from "./cosmicCadet";

type Enemy = { x: number; y: number; hp: number; gold: boolean; phase: number };
type Bolt = { x: number; y: number; vx: number; vy: number };
type Spark = { x: number; y: number; vx: number; vy: number; life: number; color: string };
type Pickup = { x: number; y: number; kind: PowerUpKind; bob: number };

const W = PLAYFIELD.width;
const H = PLAYFIELD.height;

function emptyInput() {
  return { left: false, right: false, up: false, down: false, rapid: false };
}

export function KidsSpaceShooter() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const stickRef = useRef<HTMLButtonElement>(null);
  const scoreNode = useRef<HTMLElement>(null);
  const waveNode = useRef<HTMLElement>(null);
  const hullNode = useRef<HTMLElement>(null);
  const guardNode = useRef<HTMLSpanElement>(null);
  const trackNode = useRef<HTMLSpanElement>(null);
  const burstNode = useRef<HTMLSpanElement>(null);
  const statusRef = useRef<GameStatus>("ready");
  const input = useRef(emptyInput());
  const startRef = useRef(() => {});
  const resetRef = useRef(() => {});
  const pauseRef = useRef(() => {});
  const [status, setStatus] = useState<GameStatus>("ready");
  const [score, setScore] = useState(0);
  const [wave, setWave] = useState(1);
  const [hull, setHull] = useState(MAX_HULL);
  const [muted, setMuted] = useState(false);
  const [board, setBoard] = useState<BoardEntry[]>(() => {
    try { return loadScores(localStorage).board; } catch { return []; }
  });
  const [best, setBest] = useState(() => {
    try { return loadScores(localStorage).best; } catch { return 0; }
  });
  const mutedRef = useRef(muted);
  const { immersive, toggleFullscreen, exitFullscreen } = useGameFullscreen();
  const gameStatus = (next: GameStatus) => { statusRef.current = next; setStatus(next); };

  useEffect(() => { mutedRef.current = muted; }, [muted]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext("2d");
    if (!canvas || !ctx) return;

    const stars = Array.from({ length: 130 }, (_, i) => ({ x: (i * 89) % W, y: (i * 47) % H, r: 0.5 + i % 3, speed: 0.2 + i % 5 * 0.08 }));
    const rocks = Array.from({ length: 22 }, (_, i) => ({ x: (i * 127) % W, y: (i * 157) % H, r: 3 + i % 5 * 2 }));
    const enemies: Enemy[] = [];
    const bolts: Bolt[] = [];
    const sparks: Spark[] = [];
    const pickups: Pickup[] = [];
    let shipX = W / 2;
    let shipY = H - 180;
    let points = 0;
    let kills = 0;
    let currentWave = 1;
    let currentHull = MAX_HULL;
    let spawn = 0;
    let fireCooldown = 0;
    let iframe = 0;
    let guard = 0;
    let track = 0;
    let burst = 0;
    let waveFlash = 0;
    let last = performance.now();
    let frame = 0;
    let raf = 0;
    let audio: AudioContext | undefined;
    let published: HudSnapshot = { score: 0, wave: 1, hull: MAX_HULL };
    const hullBits = () => Array.from(hullNode.current?.querySelectorAll("b") ?? []);

    const beep = (hz: number, seconds: number, volume = 0.025, type: OscillatorType = "sine") => {
      if (mutedRef.current) return;
      try {
        audio ??= new AudioContext();
        const osc = audio.createOscillator();
        const gain = audio.createGain();
        osc.type = type;
        osc.frequency.value = hz;
        gain.gain.setValueAtTime(volume, audio.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audio.currentTime + seconds);
        osc.connect(gain).connect(audio.destination);
        osc.start();
        osc.stop(audio.currentTime + seconds);
      } catch { /* Audio is optional. */ }
    };

    const burstFx = (x: number, y: number, color: string, count = 18) => {
      for (let i = 0; i < count; i++) sparks.push({ x, y, vx: (Math.random() - 0.5) * 5, vy: (Math.random() - 0.5) * 5, life: 0.5 + Math.random() * 0.5, color });
    };

    const paintHud = () => {
      if (scoreNode.current) scoreNode.current.textContent = points.toLocaleString();
      if (waveNode.current) waveNode.current.textContent = currentWave.toString().padStart(2, "0");
      hullBits().forEach((bit, index) => bit.classList.toggle("is-full", index < currentHull));
      guardNode.current?.classList.toggle("is-on", guard > 0);
      trackNode.current?.classList.toggle("is-on", track > 0);
      burstNode.current?.classList.toggle("is-on", burst > 0);
      const next = { score: points, wave: currentWave, hull: currentHull };
      if (hudChanged(published, next)) {
        published = next;
        setScore(next.score);
        setWave(next.wave);
        setHull(next.hull);
      }
    };

    const start = () => {
      enemies.length = 0;
      bolts.length = 0;
      sparks.length = 0;
      pickups.length = 0;
      shipX = W / 2;
      shipY = H - 180;
      points = 0;
      kills = 0;
      currentWave = 1;
      currentHull = MAX_HULL;
      spawn = 0;
      fireCooldown = 0;
      iframe = 0;
      guard = START_GUARD;
      track = 0;
      burst = 0;
      waveFlash = 0;
      published = { score: -1, wave: -1, hull: -1 };
      paintHud();
      gameStatus("playing");
      beep(440, 0.12, 0.035, "triangle");
    };

    const reset = () => { start(); gameStatus("ready"); paintHud(); };
    startRef.current = start;
    resetRef.current = reset;
    pauseRef.current = () => {
      const next = togglePause(statusRef.current);
      if (next !== statusRef.current) gameStatus(next);
    };

    const collect = (kind: PowerUpKind) => {
      if (kind === "heart") {
        currentHull = applyHeart(currentHull);
        beep(620, 0.1, 0.03, "triangle");
        return;
      }
      if (kind === "guard") { guard = POWER_DURATION.guard; beep(300, 0.12, 0.03, "sine"); }
      if (kind === "track") { track = POWER_DURATION.track; beep(540, 0.1, 0.03, "square"); }
      if (kind === "burst") { burst = POWER_DURATION.burst; beep(760, 0.08, 0.025, "square"); }
    };

    const fire = () => {
      if (statusRef.current !== "playing" || fireCooldown > 0) return;
      fireCooldown = fireInterval(burst > 0 || input.current.rapid);
      bolts.push({ x: shipX, y: shipY - 43, vx: 0, vy: -14 });
      if (track > 0) {
        bolts.push({ x: shipX, y: shipY - 40, vx: -4.2, vy: -13 });
        bolts.push({ x: shipX, y: shipY - 40, vx: 4.2, vy: -13 });
      }
      beep(850, 0.03, 0.01, "square");
    };

    const damage = () => {
      if (statusRef.current !== "playing" || currentHull <= 0 || iframe > 0 || guard > 0) return;
      currentHull -= 1;
      iframe = HIT_IFRAMES;
      burstFx(shipX, shipY, "#ff6f75", 30);
      beep(95, 0.18, 0.05, "sawtooth");
      paintHud();
      if (currentHull <= 0) {
        try {
          const recorded = recordRun(localStorage, points, currentWave);
          setBest(recorded.best);
          setBoard(recorded.board);
        } catch {
          setBest((current) => Math.max(current, points));
        }
        gameStatus("gameover");
        input.current = emptyInput();
      }
    };

    const dropLoot = (enemy: Enemy) => {
      const kind = pickPowerUp(enemy.gold, Math.random);
      if (!kind) return;
      pickups.push({ x: enemy.x, y: enemy.y, kind, bob: Math.random() * 6 });
    };

    const background = () => {
      const sky = ctx.createLinearGradient(0, 0, 0, H);
      sky.addColorStop(0, "#020617");
      sky.addColorStop(0.55, "#090c28");
      sky.addColorStop(1, "#030615");
      ctx.fillStyle = sky;
      ctx.fillRect(0, 0, W, H);
      const nebula = ctx.createRadialGradient(110, H * 0.55, 15, 110, H * 0.55, 280);
      nebula.addColorStop(0, "rgba(77, 49, 204, .34)");
      nebula.addColorStop(1, "rgba(20, 11, 72, 0)");
      ctx.fillStyle = nebula;
      ctx.fillRect(0, 0, W, H);
      const planet = ctx.createRadialGradient(10, H - 25, 5, 25, H - 25, 180);
      planet.addColorStop(0, "#99e5ff");
      planet.addColorStop(0.18, "#277fc0");
      planet.addColorStop(0.65, "#0a315d");
      planet.addColorStop(1, "rgba(5, 12, 32, 0)");
      ctx.fillStyle = planet;
      ctx.fillRect(0, H - 290, 280, 300);
      stars.forEach((star) => {
        ctx.globalAlpha = 0.35 + ((frame + star.x) % 70) / 130;
        ctx.fillStyle = "#d9eeff";
        ctx.fillRect(star.x, star.y, star.r, star.r);
      });
      ctx.globalAlpha = 1;
      rocks.forEach((rock) => {
        ctx.fillStyle = "rgba(119, 140, 178, .52)";
        ctx.beginPath();
        ctx.arc(rock.x, rock.y, rock.r, 0, Math.PI * 2);
        ctx.fill();
      });
    };

    const ship = () => {
      if (iframe > 0 && Math.floor(iframe * 12) % 2 === 0) return;
      ctx.save();
      ctx.translate(shipX, shipY);
      if (guard > 0) {
        ctx.strokeStyle = "rgba(82, 223, 255, .85)";
        ctx.lineWidth = 3;
        ctx.shadowColor = "#52dfff";
        ctx.shadowBlur = 16;
        ctx.beginPath();
        ctx.arc(0, 0, 46, 0, Math.PI * 2);
        ctx.stroke();
      }
      ctx.shadowColor = "#39d8ff";
      ctx.shadowBlur = 23;
      const paint = ctx.createLinearGradient(0, -50, 0, 44);
      paint.addColorStop(0, "#f6ffff");
      paint.addColorStop(0.5, "#78a9d8");
      paint.addColorStop(1, "#193353");
      ctx.fillStyle = paint;
      ctx.beginPath();
      ctx.moveTo(0, -49);
      ctx.lineTo(23, -5);
      ctx.lineTo(36, 32);
      ctx.lineTo(10, 20);
      ctx.lineTo(0, 40);
      ctx.lineTo(-10, 20);
      ctx.lineTo(-36, 32);
      ctx.lineTo(-23, -5);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = "#132844";
      ctx.beginPath();
      ctx.moveTo(0, -31);
      ctx.lineTo(11, -5);
      ctx.lineTo(0, 8);
      ctx.lineTo(-11, -5);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = "#ff7445";
      ctx.fillRect(-4, 20, 8, 16);
      ctx.fillStyle = burst > 0 || input.current.rapid ? "#ffe14a" : "#52dfff";
      ctx.fillRect(-24, 27, 8, 21);
      ctx.fillRect(16, 27, 8, 21);
      ctx.fillRect(-4, 33, 8, 26);
      ctx.restore();
    };

    const enemyShape = (enemy: Enemy) => {
      ctx.save();
      ctx.translate(enemy.x, enemy.y);
      ctx.shadowColor = enemy.gold ? "#ffd14f" : "#bf74ff";
      ctx.shadowBlur = 18;
      ctx.fillStyle = enemy.gold ? "#f2a72c" : "#9b58ff";
      ctx.beginPath();
      ctx.moveTo(0, -26);
      ctx.lineTo(19, -6);
      ctx.lineTo(28, 9);
      ctx.lineTo(8, 17);
      ctx.lineTo(0, 29);
      ctx.lineTo(-8, 17);
      ctx.lineTo(-28, 9);
      ctx.lineTo(-19, -6);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = "#211444";
      ctx.beginPath();
      ctx.arc(0, 0, 8, 0, Math.PI * 2);
      ctx.fill();
      if (enemy.hp > 1) {
        ctx.strokeStyle = "#fff0b9";
        ctx.lineWidth = 2;
        ctx.strokeRect(-24, -36, 48, 4);
      }
      ctx.restore();
    };

    const pickupShape = (item: Pickup) => {
      const bounce = Math.sin(frame * 0.12 + item.bob) * 4;
      ctx.save();
      ctx.translate(item.x, item.y + bounce);
      ctx.shadowBlur = 14;
      if (item.kind === "heart") {
        ctx.fillStyle = "#ff7aa8";
        ctx.shadowColor = "#ff7aa8";
        ctx.beginPath();
        ctx.arc(-6, -2, 7, 0, Math.PI * 2);
        ctx.arc(6, -2, 7, 0, Math.PI * 2);
        ctx.moveTo(-12, 0);
        ctx.lineTo(0, 14);
        ctx.lineTo(12, 0);
        ctx.fill();
      } else {
        ctx.fillStyle = item.kind === "guard" ? "#52dfff" : item.kind === "burst" ? "#ffc52f" : "#c877ff";
        ctx.shadowColor = ctx.fillStyle;
        ctx.beginPath();
        ctx.moveTo(0, -12);
        ctx.lineTo(10, -4);
        ctx.lineTo(7, 10);
        ctx.lineTo(-7, 10);
        ctx.lineTo(-10, -4);
        ctx.closePath();
        ctx.fill();
      }
      ctx.restore();
    };

    const loop = (now: number) => {
      const dt = Math.min(2, (now - last) / 16.67);
      last = now;
      frame += 1;
      background();
      if (statusRef.current === "playing") {
        stars.forEach((star) => { star.y = (star.y + star.speed * dt) % H; });
        shipX = clamp(shipX + (Number(input.current.right) - Number(input.current.left)) * 7.2 * dt, 38, W - 38);
        shipY = clamp(shipY + (Number(input.current.down) - Number(input.current.up)) * 6 * dt, 118, H - 176);
        spawn -= dt / 60;
        fireCooldown -= dt / 60;
        iframe = Math.max(0, iframe - dt / 60);
        guard = Math.max(0, guard - dt / 60);
        track = Math.max(0, track - dt / 60);
        burst = Math.max(0, burst - dt / 60);
        waveFlash = Math.max(0, waveFlash - dt / 60);
        if (spawn <= 0) {
          spawn = spawnInterval(currentWave);
          enemies.push({ x: 55 + Math.random() * (W - 110), y: -35, hp: enemyHp(currentWave, Math.random), gold: Math.random() > 0.78, phase: Math.random() * 7 });
        }
        fire();
        enemies.forEach((enemy) => {
          enemy.y += enemyFallSpeed(currentWave) * dt;
          enemy.x += Math.sin(frame * 0.045 + enemy.phase) * 0.85 * dt;
        });
        bolts.forEach((bolt) => { bolt.x += bolt.vx * dt; bolt.y += bolt.vy * dt; });
        sparks.forEach((spark) => { spark.x += spark.vx * dt; spark.y += spark.vy * dt; spark.life -= 0.025 * dt; });
        pickups.forEach((item) => { item.y += 1.6 * dt; });
        for (let i = bolts.length - 1; i >= 0; i--) {
          const bolt = bolts[i];
          if (bolt.y < -20 || bolt.x < -20 || bolt.x > W + 20) { bolts.splice(i, 1); continue; }
          for (let j = enemies.length - 1; j >= 0; j--) {
            const enemy = enemies[j];
            if (Math.hypot(bolt.x - enemy.x, bolt.y - enemy.y) < ENEMY_BOLT_RADIUS) {
              bolts.splice(i, 1);
              enemy.hp -= 1;
              if (enemy.hp <= 0) {
                const next = applyKill({ points, kills }, enemy.gold);
                if (next.wave !== currentWave) waveFlash = 1.6;
                points = next.points;
                kills = next.kills;
                currentWave = next.wave;
                dropLoot(enemy);
                burstFx(enemy.x, enemy.y, enemy.gold ? "#ffcd4f" : "#c277ff");
                beep(210, 0.07, 0.03);
                enemies.splice(j, 1);
                paintHud();
              }
              break;
            }
          }
        }
        for (let i = enemies.length - 1; i >= 0; i--) {
          const enemy = enemies[i];
          if (enemyLeaked(enemy.y, H)) {
            enemies.splice(i, 1);
            continue;
          }
          if (shipHitsEnemy(shipX, shipY, enemy.x, enemy.y)) {
            enemies.splice(i, 1);
            damage();
          }
        }
        for (let i = pickups.length - 1; i >= 0; i--) {
          const item = pickups[i];
          if (item.y > H + 20) { pickups.splice(i, 1); continue; }
          if (Math.hypot(item.x - shipX, item.y - shipY) < PICKUP_RADIUS) {
            collect(item.kind);
            pickups.splice(i, 1);
            paintHud();
          }
        }
        paintHud();
      }
      bolts.forEach((bolt) => {
        ctx.fillStyle = "#59e7ff";
        ctx.shadowColor = ctx.fillStyle;
        ctx.shadowBlur = 13;
        ctx.fillRect(bolt.x - 2, bolt.y - 14, 4, 25);
      });
      ctx.shadowBlur = 0;
      enemies.forEach(enemyShape);
      pickups.forEach(pickupShape);
      sparks.forEach((spark) => {
        ctx.globalAlpha = clamp(spark.life, 0, 1);
        ctx.fillStyle = spark.color;
        ctx.fillRect(spark.x, spark.y, 3, 3);
      });
      ctx.globalAlpha = 1;
      ship();
      if (waveFlash > 0 && statusRef.current === "playing") {
        ctx.save();
        ctx.globalAlpha = Math.min(1, waveFlash);
        ctx.fillStyle = "#f5fbff";
        ctx.font = "800 28px Space Grotesk, sans-serif";
        ctx.textAlign = "center";
        ctx.fillText(`WAVE ${currentWave.toString().padStart(2, "0")}`, W / 2, H * 0.38);
        ctx.restore();
      }
      raf = requestAnimationFrame(loop);
    };

    const move = (event: PointerEvent) => {
      const rect = canvas.getBoundingClientRect();
      shipX = clamp((event.clientX - rect.left) / rect.width * W, 38, W - 38);
      shipY = clamp((event.clientY - rect.top) / rect.height * H, 118, H - 176);
    };

    const fromOverlay = (event: Event) => (event.target as HTMLElement | null)?.closest(".cosmic-controls, .cosmic-canvas-actions, .cosmic-ready, .cosmic-exit");

    const beginFromPointer = () => {
      const intent = playIntent(statusRef.current);
      if (intent === "resume") gameStatus("playing");
      else if (intent === "start") start();
    };

    const down = (event: PointerEvent) => {
      if (fromOverlay(event)) return;
      event.preventDefault();
      beginFromPointer();
      if (statusRef.current !== "playing") return;
      canvas.setPointerCapture(event.pointerId);
      move(event);
    };

    const pointerMove = (event: PointerEvent) => {
      if (fromOverlay(event) || statusRef.current !== "playing") return;
      if (event.buttons === 0 && !canvas.hasPointerCapture(event.pointerId)) return;
      move(event);
    };

    const keydown = (event: KeyboardEvent) => {
      if (event.code === "ArrowLeft" || event.code === "KeyA") input.current.left = true;
      if (event.code === "ArrowRight" || event.code === "KeyD") input.current.right = true;
      if (event.code === "ArrowUp" || event.code === "KeyW") input.current.up = true;
      if (event.code === "ArrowDown" || event.code === "KeyS") input.current.down = true;
      if (event.code === "Space") {
        event.preventDefault();
        const intent = playIntent(statusRef.current);
        if (intent === "resume") gameStatus("playing");
        else if (intent === "start") start();
        input.current.rapid = statusRef.current === "playing";
      }
      if (event.code === "KeyP") {
        event.preventDefault();
        pauseRef.current();
      }
      if (event.code === "Escape" && (statusRef.current === "playing" || statusRef.current === "paused")) {
        pauseRef.current();
      }
    };

    const keyup = (event: KeyboardEvent) => {
      if (event.code === "ArrowLeft" || event.code === "KeyA") input.current.left = false;
      if (event.code === "ArrowRight" || event.code === "KeyD") input.current.right = false;
      if (event.code === "ArrowUp" || event.code === "KeyW") input.current.up = false;
      if (event.code === "ArrowDown" || event.code === "KeyS") input.current.down = false;
      if (event.code === "Space") input.current.rapid = false;
    };

    const clearInput = () => { input.current = emptyInput(); };
    const visibility = () => {
      if (document.hidden && statusRef.current === "playing") gameStatus("paused");
      clearInput();
    };

    canvas.addEventListener("pointerdown", down);
    canvas.addEventListener("pointermove", pointerMove);
    window.addEventListener("blur", clearInput);
    document.addEventListener("visibilitychange", visibility);
    window.addEventListener("keydown", keydown);
    window.addEventListener("keyup", keyup);
    raf = requestAnimationFrame(loop);
    return () => {
      cancelAnimationFrame(raf);
      audio?.close().catch(() => {});
      canvas.removeEventListener("pointerdown", down);
      canvas.removeEventListener("pointermove", pointerMove);
      window.removeEventListener("blur", clearInput);
      document.removeEventListener("visibilitychange", visibility);
      window.removeEventListener("keydown", keydown);
      window.removeEventListener("keyup", keyup);
    };
  }, []);

  const hold = (on: (event: ReactPointerEvent<HTMLButtonElement>) => void, off: () => void) => ({
    onPointerDown: (event: ReactPointerEvent<HTMLButtonElement>) => {
      event.preventDefault();
      event.stopPropagation();
      event.currentTarget.setPointerCapture(event.pointerId);
      if (statusRef.current === "ready" || statusRef.current === "gameover") startRef.current();
      if (statusRef.current === "paused") gameStatus("playing");
      on(event);
    },
    onPointerMove: (event: ReactPointerEvent<HTMLButtonElement>) => {
      if (!event.currentTarget.hasPointerCapture(event.pointerId)) return;
      event.preventDefault();
      on(event);
    },
    onPointerUp: () => off(),
    onPointerCancel: () => off(),
    onLostPointerCapture: () => off(),
  });

  const aimStick = (event: ReactPointerEvent<HTMLButtonElement>) => {
    const pad = stickRef.current;
    if (!pad) return;
    const rect = pad.getBoundingClientRect();
    const dx = event.clientX - (rect.left + rect.width / 2);
    const dy = event.clientY - (rect.top + rect.height / 2);
    const dead = 16;
    input.current.left = dx < -dead;
    input.current.right = dx > dead;
    input.current.up = dy < -dead;
    input.current.down = dy > dead;
  };

  const clearStick = () => {
    input.current.left = false;
    input.current.right = false;
    input.current.up = false;
    input.current.down = false;
  };

  const overlayAction = () => {
    const intent = playIntent(status);
    if (intent === "resume") gameStatus("playing");
    else startRef.current();
  };

  return (
    <section className="cosmic-cadet" aria-labelledby="cosmic-cadet-title">
      <header className="cosmic-title">
        <h1 id="cosmic-cadet-title">COSMIC CADET</h1>
        <p>KID SPACE BLASTER</p>
        <i />
      </header>
      <div className="cosmic-layout">
        <aside className="cosmic-brief">
          <h2>COSMIC CADET</h2>
          <p>Fly your ship, zap the purple rocks, and catch glowing stars. Built for little pilots.</p>
          <ul>
            <li><Crosshair /><span><b>AUTO BLAST</b>Your ship shoots by itself. Steer and stay safe.</span></li>
            <li><Shield /><span><b>CATCH THE STARS</b>Grab shields, triple shots, and turbo blasts.</span></li>
            <li><Zap /><span><b>BEST FLIGHTS</b>Beat your own high scores on this device.</span></li>
          </ul>
        </aside>
        <div className="cosmic-center">
          <div ref={stageRef} className={`cosmic-game-stage ${immersive ? "is-immersive" : ""}`}>
            <div className="cosmic-hud" aria-live="polite" aria-label={`Score ${score}, wave ${wave}, hull ${hull}`}>
              <div><span>SCORE</span><strong ref={scoreNode}>0</strong></div>
              <div><span>WAVE</span><strong ref={waveNode}>01</strong></div>
              <div className="cosmic-hull"><span>HULL</span><i ref={hullNode}>{Array.from({ length: MAX_HULL }, (_, index) => <b key={index} className={index < MAX_HULL ? "is-full" : ""} />)}</i></div>
              <div className="cosmic-powerbar" aria-label="Power-ups">
                <span ref={guardNode} title="Shield"><Shield size={16} /></span>
                <span ref={trackNode} title="Triple shot"><Crosshair size={16} /></span>
                <span ref={burstNode} title="Turbo blast"><Zap size={16} /></span>
              </div>
            </div>
            <canvas ref={canvasRef} width={W} height={H} aria-label="Cosmic Cadet arcade space shooter" />
            <div className="cosmic-canvas-actions">
              <button type="button" onClick={() => setMuted((value) => !value)} aria-label={muted ? "Turn sound on" : "Mute game"}>{muted ? <VolumeX size={17} /> : <Volume2 size={17} />}</button>
              <button type="button" onClick={() => pauseRef.current()} aria-label={status === "paused" ? "Resume game" : "Pause game"}>{status === "paused" ? <Play size={17} /> : <Pause size={17} />}</button>
              <button type="button" onClick={() => toggleFullscreen(stageRef.current)} aria-label={immersive ? "Exit fullscreen" : "Play fullscreen"}>{immersive ? <Minimize2 size={17} /> : <Expand size={17} />}</button>
            </div>
            {immersive && <button type="button" className="cosmic-exit" onClick={exitFullscreen} aria-label="Exit fullscreen"><Minimize2 size={19} /></button>}
            {status !== "playing" && (
              <div
                className="cosmic-ready"
                onClick={(event) => {
                  if ((event.target as HTMLElement).closest("button")) return;
                  overlayAction();
                }}
              >
                <span>{status === "gameover" ? `MISSION OVER · ${score.toLocaleString()} POINTS` : status === "paused" ? "SYSTEMS PAUSED" : "READY FOR LAUNCH"}</span>
                {status === "gameover" && board.length > 0 && (
                  <ol className="cosmic-board">
                    {board.slice(0, 3).map((entry, index) => (
                      <li key={`${entry.at}-${entry.score}-${index}`}>#{index + 1} {entry.score.toLocaleString()}</li>
                    ))}
                  </ol>
                )}
                <button type="button" onClick={overlayAction}>
                  <Play size={17} />
                  {status === "gameover" ? "FLY AGAIN" : status === "paused" ? "RESUME" : "TAP TO PLAY"}
                </button>
                {status === "paused" && (
                  <button type="button" className="cosmic-ghost" onClick={() => resetRef.current()}>
                    <RotateCcw size={16} /> START OVER
                  </button>
                )}
              </div>
            )}
            <div className="cosmic-controls" aria-label="Touch controls">
              <button type="button" ref={stickRef} className="cosmic-stick" aria-label="Steer ship" {...hold(aimStick, clearStick)}>
                <b />
                <span>FLY</span>
              </button>
              <button type="button" className="cosmic-shoot" aria-label="Turbo blast" {...hold(() => { input.current.rapid = true; }, () => { input.current.rapid = false; })}>BLAST</button>
            </div>
          </div>
        </div>
        <aside className="cosmic-side">
          <div>
            <h2>QUICK TIPS</h2>
            <p><Shield /><span><b>Protect your hull</b>Rocks that fly past do not hurt. Blink means you are safe.</span></p>
            <p><Zap /><span><b>Catch glowing stars</b>Shield, spray shots, or turbo blast.</span></p>
            <p><Crosshair /><span><b>Drag to fly</b>Or mash the FLY pad with a thumb.</span></p>
          </div>
          <div className="cosmic-best">
            <span>BEST FLIGHTS</span>
            <strong>{best.toLocaleString()}</strong>
            {board.length > 0 && (
              <ol className="cosmic-board">
                {board.map((entry, index) => (
                  <li key={`${entry.at}-${entry.score}-${index}`}>#{index + 1} {entry.score.toLocaleString()} · wave {entry.wave}</li>
                ))}
              </ol>
            )}
          </div>
        </aside>
      </div>
    </section>
  );
}

export default KidsSpaceShooter;
