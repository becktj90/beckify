import { useEffect, useRef, useState } from "react";
import { Maximize2, Pause, Play, RotateCcw, ArrowLeft, ArrowRight, ArrowUp } from "lucide-react";

type Status = "ready" | "running" | "paused" | "gameover";
type HazardKind = "cone" | "barrier";

type Hazard = {
  lane: number;
  x: number;
  kind: HazardKind;
  width: number;
  height: number;
  passed: boolean;
};

type Pickup = {
  lane: number;
  x: number;
  y: number;
  width: number;
  height: number;
  value: number;
  collected: boolean;
};

const WIDTH = 960;
const HEIGHT = 540;
const STEP = 1 / 120;
const ROAD_TOP = 188;
const ROAD_BOTTOM = 492;
const PLAYER_X = 210;
const PLAYER_WIDTH = 70;
const PLAYER_HEIGHT = 52;
const PLAYER_LANE_Y = [352, 308, 264];
const BEST_KEY = "booty-butt-scooter-best";

const clamp = (value: number, min: number, max: number) => Math.max(min, Math.min(max, value));

function roundedRectPath(context: CanvasRenderingContext2D, x: number, y: number, width: number, height: number, radius: number) {
  const r = Math.min(radius, width / 2, height / 2);
  context.beginPath();
  context.moveTo(x + r, y);
  context.arcTo(x + width, y, x + width, y + height, r);
  context.arcTo(x + width, y + height, x, y + height, r);
  context.arcTo(x, y + height, x, y, r);
  context.arcTo(x, y, x + width, y, r);
  context.closePath();
}

function drawScooter(context: CanvasRenderingContext2D, x: number, y: number, tilt: number, air: number, laneDrift: number) {
  context.save();
  context.translate(x, y);
  context.rotate(tilt);

  const bob = Math.sin(air * Math.PI * 2) * 2;
  const shadowAlpha = clamp(0.4 - air * 0.18, 0.08, 0.35);

  context.save();
  context.translate(4, 34 + bob);
  context.fillStyle = `rgba(0, 0, 0, ${shadowAlpha})`;
  context.beginPath();
  context.ellipse(0, 0, 36, 9, 0, 0, Math.PI * 2);
  context.fill();
  context.restore();

  context.lineCap = "round";
  context.lineJoin = "round";

  // Wheels
  context.strokeStyle = "#22283d";
  context.fillStyle = "#0d1224";
  context.lineWidth = 8;
  for (const wheelX of [-18, 30]) {
    context.beginPath();
    context.arc(wheelX, 34, 12, 0, Math.PI * 2);
    context.fill();
    context.stroke();
    context.strokeStyle = "#6df0df";
    context.lineWidth = 2;
    context.beginPath();
    context.arc(wheelX, 34, 5, laneDrift, laneDrift + Math.PI * 2);
    context.stroke();
    context.strokeStyle = "#22283d";
    context.lineWidth = 8;
  }

  // Chassis and body
  const bodyGradient = context.createLinearGradient(-24, 2, 34, 36);
  bodyGradient.addColorStop(0, "#ffcf79");
  bodyGradient.addColorStop(0.55, "#ff9e4a");
  bodyGradient.addColorStop(1, "#ff7f5c");
  context.fillStyle = bodyGradient;
  roundedRectPath(context, -18, 10 + bob * 0.3, 54, 18, 9);
  context.fill();

  context.fillStyle = "#f2f4ff";
  roundedRectPath(context, -2, -10 + bob * 0.15, 44, 16, 7);
  context.fill();

  context.fillStyle = "#20273c";
  roundedRectPath(context, 12, -6 + bob * 0.12, 16, 32, 8);
  context.fill();

  context.fillStyle = "#6df0df";
  roundedRectPath(context, 16, -4 + bob * 0.1, 8, 12, 3);
  context.fill();

  context.fillStyle = "#152036";
  context.beginPath();
  context.moveTo(-8, 10 + bob * 0.18);
  context.lineTo(18, -4 + bob * 0.1);
  context.lineTo(23, 0 + bob * 0.08);
  context.lineTo(0, 12 + bob * 0.18);
  context.closePath();
  context.fill();

  // Rider
  context.fillStyle = "#0f1426";
  context.beginPath();
  context.arc(20, -20 + bob * 0.12, 11, 0, Math.PI * 2);
  context.fill();
  context.fillStyle = "#f0bfa8";
  context.beginPath();
  context.arc(18, -21 + bob * 0.12, 7, 0, Math.PI * 2);
  context.fill();
  context.fillStyle = "#ff6d8f";
  context.beginPath();
  context.arc(21, -24 + bob * 0.12, 13, Math.PI * 0.15, Math.PI * 1.15);
  context.lineTo(30, -13 + bob * 0.12);
  context.lineTo(11, -12 + bob * 0.12);
  context.closePath();
  context.fill();
  context.strokeStyle = "#0f1426";
  context.lineWidth = 3;
  context.beginPath();
  context.moveTo(18, -12 + bob * 0.12);
  context.lineTo(8, 1 + bob * 0.18);
  context.lineTo(-2, 10 + bob * 0.22);
  context.stroke();
  context.beginPath();
  context.moveTo(18, -12 + bob * 0.12);
  context.lineTo(34, 4 + bob * 0.12);
  context.stroke();

  context.restore();
}

function drawHazard(context: CanvasRenderingContext2D, hazard: Hazard, x: number, y: number, speedPhase: number) {
  context.save();
  context.translate(x, y);

  if (hazard.kind === "cone") {
    context.fillStyle = "#ff9b3d";
    context.strokeStyle = "#cf6f13";
    context.lineWidth = 2;
    context.beginPath();
    context.moveTo(-hazard.width / 2, 22);
    context.lineTo(0, -hazard.height / 2);
    context.lineTo(hazard.width / 2, 22);
    context.closePath();
    context.fill();
    context.stroke();
    context.fillStyle = "#fff4d4";
    context.fillRect(-hazard.width / 2 + 4, 6, hazard.width - 8, 5);
    context.fillStyle = "#ffcb75";
    context.fillRect(-hazard.width / 2 + 2, 15, hazard.width - 4, 4);
  } else {
    context.fillStyle = "#f25f6b";
    roundedRectPath(context, -hazard.width / 2, -hazard.height / 2, hazard.width, hazard.height, 8);
    context.fill();
    context.fillStyle = "#ffffff";
    for (let i = -2; i < 3; i += 1) {
      context.save();
      context.translate(i * 9, 0);
      context.rotate(Math.PI * 0.22);
      context.fillRect(-3, -hazard.height / 2 + 10, 6, hazard.height - 20);
      context.restore();
    }
    context.fillStyle = "#1d2440";
    context.fillRect(-hazard.width / 2 - 8, hazard.height / 2 - 2, hazard.width + 16, 4);
  }

  context.globalAlpha = 0.18 + Math.sin(speedPhase * 0.006) * 0.05;
  context.fillStyle = "#6df0df";
  context.fillRect(-hazard.width / 2 - 2, hazard.height / 2 + 4, hazard.width + 4, 4);
  context.restore();
}

export function BootyButtScooter() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const statusRef = useRef<Status>("ready");
  const bestRef = useRef(0);
  const laneRef = useRef(1);
  const targetLaneRef = useRef(1);
  const jumpRef = useRef(0);
  const scoreRef = useRef(0);
  const streakRef = useRef(0);
  const gameOverRef = useRef(false);
  const startRef = useRef<(() => void) | null>(null);
  const resetRef = useRef<(() => void) | null>(null);
  const jumpActionRef = useRef<(() => void) | null>(null);
  const statusSetterRef = useRef<((next: Status) => void) | null>(null);

  const [status, setStatus] = useState<Status>("ready");
  const [score, setScore] = useState(0);
  const [best, setBest] = useState(() => (typeof window === "undefined" ? 0 : Number(localStorage.getItem(BEST_KEY) || 0)));
  const [lane, setLane] = useState(1);

  useEffect(() => {
    bestRef.current = best;
  }, [best]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const context = canvas?.getContext("2d");
    if (!canvas || !context) return;

    const hazards: Hazard[] = [];
    const pickups: Pickup[] = [];
    const laneSmoke: { lane: number; x: number; life: number }[] = [];
    const player = {
      x: PLAYER_X,
      y: PLAYER_LANE_Y[1],
      lane: 1,
      targetLane: 1,
      jumpY: 0,
      jumpV: 0,
      airTime: 0,
      speedPhase: 0,
    };

    let speed = 340;
    let spawnTimer = 0.75;
    let pickupTimer = 1.35;
    let distance = 0;
    let collected = 0;
    let previous = performance.now();
    let animationFrame = 0;

    const setGameStatus = (next: Status) => {
      statusRef.current = next;
      setStatus(next);
    };
    statusSetterRef.current = setGameStatus;

    const resetWorld = () => {
      hazards.length = 0;
      pickups.length = 0;
      laneSmoke.length = 0;
      player.lane = 1;
      player.targetLane = 1;
      player.jumpY = 0;
      player.jumpV = 0;
      player.airTime = 0;
      player.speedPhase = 0;
      speed = 340;
      spawnTimer = 0.55;
      pickupTimer = 1.15;
      distance = 0;
      collected = 0;
      gameOverRef.current = false;
      laneRef.current = 1;
      targetLaneRef.current = 1;
      jumpRef.current = 0;
      scoreRef.current = 0;
      setLane(1);
      setScore(0);
      setGameStatus("ready");
    };

    const start = () => {
      resetWorld();
      setGameStatus("running");
    };

    const moveLane = (direction: -1 | 1) => {
      if (statusRef.current === "ready") setGameStatus("running");
      if (statusRef.current !== "running") return;
      targetLaneRef.current = clamp(targetLaneRef.current + direction, 0, 2);
    };

    const jump = () => {
      if (statusRef.current === "ready" || statusRef.current === "gameover") start();
      if (statusRef.current !== "running") return;
      if (player.jumpY === 0) {
        player.jumpV = 780;
        player.airTime = 0.001;
        laneSmoke.push({ lane: player.lane, x: PLAYER_X - 8, life: 0.28 });
      }
    };
    jumpActionRef.current = jump;

    const finish = () => {
      if (gameOverRef.current) return;
      gameOverRef.current = true;
      const nextBest = Math.max(bestRef.current, Math.floor(scoreRef.current));
      bestRef.current = nextBest;
      setBest(nextBest);
      if (typeof window !== "undefined") localStorage.setItem(BEST_KEY, String(nextBest));
      setGameStatus("gameover");
    };

    const spawnHazard = () => {
      const lane = Math.floor(Math.random() * 3);
      const kind: HazardKind = Math.random() < 0.58 ? "cone" : "barrier";
      const width = kind === "cone" ? 40 : 82;
      const height = kind === "cone" ? 48 : 68;
      hazards.push({ lane, x: WIDTH + 120, kind, width, height, passed: false });
    };

    const spawnPickup = () => {
      const lane = Math.floor(Math.random() * 3);
      pickups.push({
        lane,
        x: WIDTH + 60,
        y: 0,
        width: 22,
        height: 22,
        value: 25,
        collected: false,
      });
    };

    const playerBounds = () => {
      const laneY = PLAYER_LANE_Y[player.lane] ?? PLAYER_LANE_Y[1];
      const jump = player.jumpY;
      const top = laneY - PLAYER_HEIGHT - jump;
      return { x: PLAYER_X - PLAYER_WIDTH / 2, y: top, width: PLAYER_WIDTH, height: PLAYER_HEIGHT + jump };
    };

    const intersects = (hazard: Hazard) => {
      const bounds = playerBounds();
      const hazardX = hazard.x;
      const hazardY = PLAYER_LANE_Y[hazard.lane] ?? PLAYER_LANE_Y[1];
      const hazardBounds = {
        x: hazardX - hazard.width / 2,
        y: hazardY - hazard.height,
        width: hazard.width,
        height: hazard.height,
      };
      const overlapX = bounds.x < hazardBounds.x + hazardBounds.width && bounds.x + bounds.width > hazardBounds.x;
      const overlapY = bounds.y < hazardBounds.y + hazardBounds.height && bounds.y + bounds.height > hazardBounds.y;
      if (!overlapX || !overlapY) return false;

      if (hazard.kind === "cone") {
        return player.jumpY < 24;
      }
      return true;
    };

    const update = (dt: number) => {
      player.targetLane = targetLaneRef.current;
      if (player.lane !== player.targetLane) {
        player.lane = player.targetLane;
      }
      laneRef.current = player.lane;
      setLane(player.lane);

      if (player.jumpY > 0 || player.jumpV > 0) {
        player.jumpV -= 1820 * dt;
        player.jumpY = Math.max(0, player.jumpY + player.jumpV * dt);
        if (player.jumpY === 0) {
          player.jumpV = 0;
          player.airTime = 0;
        } else {
          player.airTime += dt * 4.2;
        }
      }

      speed = Math.min(660, 340 + distance * 0.055 + scoreRef.current * 0.12);
      distance += speed * dt;
      scoreRef.current = Math.floor(distance / 8 + collected * 15 + streakRef.current * 3);

      spawnTimer -= dt;
      if (spawnTimer <= 0) {
        spawnHazard();
        spawnTimer = clamp(1.05 - distance / 14000, 0.45, 0.95) + Math.random() * 0.34;
      }

      pickupTimer -= dt;
      if (pickupTimer <= 0) {
        if (Math.random() < 0.7) spawnPickup();
        pickupTimer = 1.35 + Math.random() * 0.9;
      }

      hazards.forEach((hazard) => {
        hazard.x -= speed * dt;
        if (!hazard.passed && hazard.x < PLAYER_X - 20) {
          hazard.passed = true;
          streakRef.current += 1;
        }
      });
      while (hazards[0] && hazards[0].x < -180) hazards.shift();

      pickups.forEach((pickup) => {
        pickup.x -= speed * dt;
        pickup.y = (PLAYER_LANE_Y[pickup.lane] ?? PLAYER_LANE_Y[1]) - 92;
        if (!pickup.collected) {
          const bounds = playerBounds();
          const pickupBounds = {
            x: pickup.x - pickup.width / 2,
            y: pickup.y - pickup.height / 2,
            width: pickup.width,
            height: pickup.height,
          };
          const overlapX = bounds.x < pickupBounds.x + pickupBounds.width && bounds.x + bounds.width > pickupBounds.x;
          const overlapY = bounds.y < pickupBounds.y + pickupBounds.height && bounds.y + bounds.height > pickupBounds.y;
          if (overlapX && overlapY) {
            pickup.collected = true;
            collected += 1;
            scoreRef.current += pickup.value;
            laneSmoke.push({ lane: pickup.lane, x: pickup.x, life: 0.42 });
          }
        }
      });
      while (pickups[0] && pickups[0].x < -120) pickups.shift();

      laneSmoke.forEach((smoke) => {
        smoke.x -= speed * 0.18 * dt;
        smoke.life -= dt;
      });
      while (laneSmoke[0]?.life <= 0) laneSmoke.shift();

      if (hazards.some(intersects)) finish();

      setScore(scoreRef.current);
      player.speedPhase += dt * (1 + speed / 220);
    };

    const drawBackground = () => {
      const sky = context.createLinearGradient(0, 0, 0, HEIGHT);
      sky.addColorStop(0, "#08111f");
      sky.addColorStop(0.52, "#0d1630");
      sky.addColorStop(1, "#06101f");
      context.fillStyle = sky;
      context.fillRect(0, 0, WIDTH, HEIGHT);

      const glow = context.createRadialGradient(190, 100, 18, 190, 100, 260);
      glow.addColorStop(0, "rgba(109, 240, 223, 0.18)");
      glow.addColorStop(1, "transparent");
      context.fillStyle = glow;
      context.fillRect(0, 0, WIDTH, HEIGHT);

      context.fillStyle = "rgba(255, 255, 255, 0.04)";
      for (let x = 34; x < WIDTH; x += 88) {
        const y = 28 + ((x * 19) % 124);
        context.fillRect(x, y, 2, 2);
      }

      context.fillStyle = "#0b1328";
      context.beginPath();
      context.moveTo(0, 150);
      context.lineTo(78, 128);
      context.lineTo(150, 146);
      context.lineTo(230, 114);
      context.lineTo(310, 138);
      context.lineTo(404, 104);
      context.lineTo(486, 132);
      context.lineTo(560, 110);
      context.lineTo(660, 144);
      context.lineTo(760, 122);
      context.lineTo(856, 138);
      context.lineTo(WIDTH, 118);
      context.lineTo(WIDTH, 188);
      context.lineTo(0, 188);
      context.closePath();
      context.fill();

      context.fillStyle = "#101a34";
      context.fillRect(0, 188, WIDTH, ROAD_BOTTOM - ROAD_TOP);

      context.fillStyle = "#0a1020";
      context.fillRect(0, ROAD_BOTTOM, WIDTH, HEIGHT - ROAD_BOTTOM);

      context.strokeStyle = "rgba(109, 240, 223, 0.35)";
      context.lineWidth = 2;
      context.beginPath();
      context.moveTo(0, ROAD_TOP);
      context.lineTo(WIDTH, ROAD_TOP);
      context.moveTo(0, ROAD_BOTTOM);
      context.lineTo(WIDTH, ROAD_BOTTOM);
      context.stroke();

      const laneLines = [336, 480, 624];
      context.strokeStyle = "rgba(255, 255, 255, 0.13)";
      context.lineWidth = 3;
      laneLines.slice(0, 2).forEach((lineX) => {
        context.setLineDash([24, 16]);
        context.beginPath();
        context.moveTo(lineX, ROAD_TOP + 8);
        context.lineTo(lineX, ROAD_BOTTOM - 16);
        context.stroke();
      });
      context.setLineDash([]);

      context.fillStyle = "rgba(255, 255, 255, 0.06)";
      for (let y = ROAD_TOP + 34; y < ROAD_BOTTOM; y += 42) {
        const width = 180 - (y - ROAD_TOP) * 0.22;
        context.fillRect(480 - width / 2, y, width, 2);
      }

      context.fillStyle = "#0d1430";
      for (let i = 0; i < 5; i += 1) {
        const x = 82 + i * 178;
        const height = 44 + (i % 3) * 16;
        context.fillRect(x, 92, 44, height);
      }
    };

    const draw = () => {
      drawBackground();

      const roadWave = Math.sin(player.speedPhase) * 0.5;
      context.fillStyle = "rgba(109, 240, 223, 0.12)";
      context.fillRect(0, ROAD_TOP + 1, WIDTH, 2);
      context.fillRect(0, ROAD_BOTTOM - 1, WIDTH, 2);

      hazards.forEach((hazard) => {
        const x = hazard.x;
        const y = PLAYER_LANE_Y[hazard.lane] ?? PLAYER_LANE_Y[1];
        drawHazard(context, hazard, x, y, player.speedPhase);
      });

      pickups.forEach((pickup) => {
        if (pickup.collected) return;
        const x = pickup.x;
        const y = pickup.y;
        context.save();
        context.translate(x, y);
        context.shadowColor = "#6df0df";
        context.shadowBlur = 16;
        context.fillStyle = "#6df0df";
        context.beginPath();
        context.moveTo(0, -12);
        context.lineTo(10, 0);
        context.lineTo(0, 12);
        context.lineTo(-10, 0);
        context.closePath();
        context.fill();
        context.shadowBlur = 0;
        context.fillStyle = "#0f1426";
        context.beginPath();
        context.arc(0, 0, 4, 0, Math.PI * 2);
        context.fill();
        context.restore();
      });

      laneSmoke.forEach((smoke) => {
        const y = (PLAYER_LANE_Y[smoke.lane] ?? PLAYER_LANE_Y[1]) - 22;
        context.save();
        context.globalAlpha = clamp(smoke.life * 2.4, 0, 0.65);
        context.fillStyle = "#6df0df";
        context.beginPath();
        context.ellipse(smoke.x, y + roadWave * 2, 16, 5, 0, 0, Math.PI * 2);
        context.fill();
        context.restore();
      });

      const playerY = (PLAYER_LANE_Y[laneRef.current] ?? PLAYER_LANE_Y[1]) - player.jumpY;
      const tilt = clamp((targetLaneRef.current - laneRef.current) * 0.18 + Math.sin(player.speedPhase * 0.08) * 0.03, -0.26, 0.26);
      context.save();
      context.translate(PLAYER_X, playerY);
      context.rotate(tilt);
      drawScooter(context, 0, 0, tilt, player.airTime, player.speedPhase);
      context.restore();

      context.fillStyle = "#eef0fa";
      context.font = "700 18px Space Grotesk, sans-serif";
      context.fillText(`SCORE ${Math.floor(scoreRef.current).toString().padStart(4, "0")}`, 20, 32);
      context.fillStyle = "#8fa6c5";
      context.font = "500 12px JetBrains Mono, monospace";
      context.fillText("SWIPE / ARROW LEFT-RIGHT TO CHANGE LANES", 20, 56);
      context.fillText("TAP / SPACE / ARROW UP TO BOOST OVER GATES", 20, 74);

      context.save();
      context.fillStyle = "#6df0df";
      context.globalAlpha = 0.95;
      context.font = "600 12px JetBrains Mono, monospace";
      context.textAlign = "right";
      context.fillText(`BEST ${bestRef.current.toString().padStart(4, "0")}`, WIDTH - 18, 32);
      context.fillText(`STREAK ${streakRef.current.toString().padStart(2, "0")}`, WIDTH - 18, 52);
      context.restore();
    };

    const frame = (now: number) => {
      const elapsed = Math.min(0.08, (now - previous) / 1000);
      previous = now;

      if (statusRef.current === "running") {
        let accumulator = elapsed;
        while (accumulator > 0) {
          const dt = Math.min(STEP, accumulator);
          update(dt);
          accumulator -= dt;
        }
      }

      draw();
      animationFrame = requestAnimationFrame(frame);
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.code === "ArrowLeft" || event.code === "KeyA") {
        event.preventDefault();
        moveLane(-1);
      }
      if (event.code === "ArrowRight" || event.code === "KeyD") {
        event.preventDefault();
        moveLane(1);
      }
      if (event.code === "ArrowUp" || event.code === "Space") {
        event.preventDefault();
        jump();
      }
      if (event.code === "KeyP" || event.code === "Escape") {
        setGameStatus(statusRef.current === "paused" ? "running" : "paused");
      }
      if (event.code === "Enter" && statusRef.current !== "running") {
        start();
      }
    };

    const pointerState = { x: 0, y: 0, time: 0 };
    const handlePointerDown = (event: PointerEvent) => {
      pointerState.x = event.clientX;
      pointerState.y = event.clientY;
      pointerState.time = performance.now();
      canvas.setPointerCapture(event.pointerId);
    };
    const handlePointerUp = (event: PointerEvent) => {
      const dx = event.clientX - pointerState.x;
      const dy = event.clientY - pointerState.y;
      const elapsed = performance.now() - pointerState.time;
      canvas.releasePointerCapture(event.pointerId);

      if (Math.abs(dx) > 34 && Math.abs(dx) > Math.abs(dy)) {
        moveLane(dx > 0 ? 1 : -1);
        return;
      }
      if (Math.abs(dy) > 36 && dy < 0) {
        jump();
        return;
      }
      if (elapsed < 450) {
        jump();
      }
    };

    canvas.addEventListener("pointerdown", handlePointerDown);
    canvas.addEventListener("pointerup", handlePointerUp);
    window.addEventListener("keydown", handleKeyDown);
    startRef.current = start;
    resetRef.current = resetWorld;
    animationFrame = requestAnimationFrame(frame);

    return () => {
      cancelAnimationFrame(animationFrame);
      canvas.removeEventListener("pointerdown", handlePointerDown);
      canvas.removeEventListener("pointerup", handlePointerUp);
      window.removeEventListener("keydown", handleKeyDown);
      startRef.current = null;
      resetRef.current = null;
      statusSetterRef.current = null;
    };
  }, []);

  const toggleFullscreen = async () => {
    if (!stageRef.current) return;
    if (document.fullscreenElement) {
      await document.exitFullscreen();
      return;
    }
    await stageRef.current.requestFullscreen?.();
  };

  const reset = () => {
    resetRef.current?.();
    setStatus("ready");
  };

  const shiftLane = (direction: -1 | 1) => {
    if (status === "ready") {
      startRef.current?.();
    }
    if (status === "paused" || status === "gameover") return;
    const nextLane = clamp(targetLaneRef.current + direction, 0, 2);
    targetLaneRef.current = nextLane;
    laneRef.current = nextLane;
    setLane(nextLane);
  };

  return (
    <section className="space-y-6" aria-labelledby="booty-butt-scooter-title">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--accent)]">Arcade / Lane runner</p>
          <h1 id="booty-butt-scooter-title" className="font-display text-3xl font-bold tracking-tight">
            Booty Butt Scooter
          </h1>
          <p className="mt-2 max-w-xl text-sm text-[var(--muted)]">
            Ride the glowing scooter lane, swap lanes fast, and hop the barricades before the city traffic closes the gap.
          </p>
        </div>
        <div className="flex items-center gap-3 text-xs text-[var(--muted)]">
          <span>BEST {best.toString().padStart(4, "0")}</span>
          <button
            type="button"
            className="rounded-md border border-[var(--border)] p-2"
            onClick={toggleFullscreen}
            aria-label="Toggle fullscreen"
          >
            <Maximize2 size={16} />
          </button>
        </div>
      </div>

      <div
        ref={stageRef}
        className="relative mx-auto max-w-[960px] overflow-hidden rounded-3xl border border-[#29446c] bg-[#06101f] shadow-[0_24px_80px_rgba(0,0,0,.42)]"
      >
        <canvas
          ref={canvasRef}
          width={WIDTH}
          height={HEIGHT}
          className="block h-auto w-full touch-none select-none"
          aria-label="Booty Butt Scooter lane runner"
        />

        {status !== "running" ? (
          <div className="absolute inset-0 flex items-center justify-center bg-[#06101f]/76 p-6 text-center backdrop-blur-[2px]">
            <div className="max-w-sm">
              <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#6df0df]">
                {status === "gameover" ? "Run ended" : status === "paused" ? "Course paused" : "Ready to ride"}
              </p>
              <h2 className="mt-2 font-display text-3xl font-bold text-white">
                {status === "gameover" ? "Try a cleaner line." : status === "paused" ? "Hold the lane." : "Pick a lane and roll."}
              </h2>
              <p className="mt-3 text-sm leading-6 text-[#b9c8dc]">
                {status === "gameover"
                  ? `Score ${score}. Best ${best}.`
                  : "Tap, click, Space, or Arrow Up to boost. Use Arrow Left and Right, or swipe, to change lanes."}
              </p>
        <button
          type="button"
          className="pointer-events-auto mt-5 inline-flex items-center gap-2 rounded-lg bg-[#6df0df] px-5 py-3 text-sm font-semibold text-[#06101f]"
                onClick={() => (status === "paused" ? statusSetterRef.current?.("running") : startRef.current?.())}
              >
                <Play size={16} />
                {status === "paused" ? "Resume" : status === "gameover" ? "Run again" : "Start run"}
              </button>
            </div>
          </div>
        ) : null}
      </div>

      <div className="flex flex-wrap items-center justify-between gap-3 text-xs text-[var(--muted)]">
        <span>
          Score {score} · Best {best} · Lane {lane + 1}
        </span>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            className="inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2"
            onClick={() => statusSetterRef.current?.(status === "paused" ? "running" : "paused")}
          >
            <Pause size={14} />
            {status === "paused" ? "Resume" : "Pause"}
          </button>
          <button type="button" className="inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={reset}>
            <RotateCcw size={14} />
            Reset
          </button>
          <button type="button" className="inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => shiftLane(-1)}>
            <ArrowLeft size={14} />
            Left
          </button>
          <button type="button" className="inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => jumpActionRef.current?.()}>
            <ArrowUp size={14} />
            Boost
          </button>
          <button type="button" className="inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => shiftLane(1)}>
            Right
            <ArrowRight size={14} />
          </button>
        </div>
      </div>
    </section>
  );
}
