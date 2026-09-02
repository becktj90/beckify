import { useEffect, useRef, useState } from "react";
import {
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  ArrowUp,
  Maximize2,
  Minimize2,
  Pause,
  Play,
  RotateCcw,
  Volume2,
  VolumeX,
  Wind,
} from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";

type Status = "ready" | "running" | "paused" | "gameover";
type Character = "apollo" | "rocco";
type RowKind = "grass" | "road";
type MoveKind = "hop" | "fart";

type MoveState = {
  fromRow: number;
  fromCol: number;
  toRow: number;
  toCol: number;
  progress: number;
  duration: number;
  kind: MoveKind;
};

type Vehicle = {
  width: number;
  height: number;
  offset: number;
  speed: number;
  color: string;
  accent: string;
  kind: "car" | "van" | "truck";
};

type Puff = {
  x: number;
  y: number;
  life: number;
  radius: number;
  driftX: number;
  driftY: number;
};

const WIDTH = 960;
const HEIGHT = 720;
const ROW_HEIGHT = 72;
const COLS = 7;
const COL_WIDTH = 108;
const BOARD_WIDTH = COLS * COL_WIDTH;
const BOARD_LEFT = (WIDTH - BOARD_WIDTH) / 2;
const BOARD_TOP = 56;
const VISIBLE_ROWS = 10;
const PLAYER_HOME_ROW = 4;
const PLAYER_HOME_COL = 3;
const PLAYER_SPRITE_SIZE = 156;
const PLAYER_BOX_WIDTH = 64;
const PLAYER_BOX_HEIGHT = 78;
const BEST_KEY = "booty-butt-scooter-best";
const SPRITE_SRC = "/games/booty-butt-scooter/scooter-sprites.png";

const clamp = (value: number, min: number, max: number) => Math.max(min, Math.min(max, value));
const lerp = (start: number, end: number, amount: number) => start + (end - start) * amount;
const easeOutCubic = (value: number) => 1 - Math.pow(1 - value, 3);
const modulo = (value: number, mod: number) => ((value % mod) + mod) % mod;
const hash = (seed: number, salt = 0) => {
  const n = Math.sin(seed * 12.9898 + salt * 78.233) * 43758.5453;
  return n - Math.floor(n);
};

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

function tileCenterX(col: number) {
  return BOARD_LEFT + col * COL_WIDTH + COL_WIDTH / 2;
}

function tileCenterY(row: number, cameraRow: number) {
  return BOARD_TOP + (row - cameraRow) * ROW_HEIGHT + ROW_HEIGHT / 2;
}

function rowKind(row: number): RowKind {
  return modulo(row, 5) === 0 ? "grass" : "road";
}

function roadDirection(row: number): -1 | 1 {
  return modulo(row, 2) === 0 ? 1 : -1;
}

function rowVehicles(row: number): Vehicle[] {
  const seed = row * 31.71;
  const count = 2 + Math.floor(hash(seed, 1) * 3);
  const kindOrder: Vehicle["kind"][] = ["car", "car", "van", "truck"];
  const palette = [
    ["#ff7a5a", "#ffc96b"],
    ["#55e6cb", "#0e1b36"],
    ["#8b7bff", "#dad4ff"],
    ["#ff6b8a", "#ffd166"],
  ] as const;

  return Array.from({ length: count }, (_, index) => {
    const kind = kindOrder[Math.floor(hash(seed, 2 + index) * kindOrder.length)];
    const [color, accent] = palette[Math.floor(hash(seed, 7 + index) * palette.length)];
    const width = kind === "car" ? 72 + Math.floor(hash(seed, 11 + index) * 18) : kind === "van" ? 96 : 118;
    const height = kind === "truck" ? 42 : 38;
    const speed = 84 + hash(seed, 19 + index) * 94;
    const offset = hash(seed, 23 + index) * (BOARD_WIDTH + 220);
    return { width, height, offset, speed, color, accent, kind };
  });
}

function drawVehicle(
  context: CanvasRenderingContext2D,
  vehicle: Vehicle,
  x: number,
  y: number,
  direction: -1 | 1,
) {
  context.save();
  context.translate(x, y);
  context.scale(direction, 1);

  context.shadowColor = vehicle.color;
  context.shadowBlur = 12;
  context.fillStyle = vehicle.color;
  roundedRectPath(context, -vehicle.width / 2, -vehicle.height / 2, vehicle.width, vehicle.height, 14);
  context.fill();

  context.shadowBlur = 0;
  context.fillStyle = vehicle.accent;
  roundedRectPath(context, -vehicle.width / 2 + 8, -vehicle.height / 2 + 8, vehicle.width - 16, vehicle.height - 16, 10);
  context.fill();

  context.fillStyle = "#10152a";
  const wheelY = vehicle.height / 2 - 4;
  for (const wheelX of [-vehicle.width / 2 + 16, vehicle.width / 2 - 16]) {
    context.beginPath();
    context.arc(wheelX, wheelY, 10, 0, Math.PI * 2);
    context.fill();
    context.beginPath();
    context.arc(wheelX, wheelY, 4, 0, Math.PI * 2);
    context.fillStyle = "#eef0fa";
    context.fill();
    context.fillStyle = "#10152a";
  }

  if (vehicle.kind !== "car") {
    context.fillStyle = "#eef0fa";
    context.fillRect(-vehicle.width / 2 + 16, -vehicle.height / 2 + 12, vehicle.width - 32, 6);
  }

  if (vehicle.kind === "truck") {
    context.fillStyle = "rgba(255,255,255,0.18)";
    context.fillRect(vehicle.width / 2 - 18, -vehicle.height / 2 + 10, 6, vehicle.height - 20);
  }

  context.restore();
}

function drawCharacterSprite(
  context: CanvasRenderingContext2D,
  image: HTMLImageElement,
  character: Character,
  farting: boolean,
  x: number,
  y: number,
  scale: number,
  tilt: number,
) {
  const frameX = farting ? 1 : 0;
  const frameY = character === "apollo" ? 0 : 1;
  const sx = frameX * 512;
  const sy = frameY * 512;
  const dw = PLAYER_SPRITE_SIZE * scale;
  const dh = PLAYER_SPRITE_SIZE * scale;

  context.save();
  context.translate(x, y);
  context.rotate(tilt);
  context.drawImage(image, sx, sy, 512, 512, -dw / 2, -dh / 2, dw, dh);
  context.restore();
}

function drawRoadSurface(context: CanvasRenderingContext2D, y: number, isGrass: boolean) {
  if (isGrass) {
    const fill = context.createLinearGradient(0, y - ROW_HEIGHT / 2, 0, y + ROW_HEIGHT / 2);
    fill.addColorStop(0, "#0f2a25");
    fill.addColorStop(1, "#142f27");
    context.fillStyle = fill;
    context.fillRect(BOARD_LEFT - 28, y - ROW_HEIGHT / 2, BOARD_WIDTH + 56, ROW_HEIGHT);

    context.fillStyle = "rgba(109, 240, 223, 0.12)";
    for (let i = 0; i < 6; i += 1) {
      const x = BOARD_LEFT + 12 + i * 144;
      context.beginPath();
      context.arc(x, y - 9, 7 + (i % 2), 0, Math.PI * 2);
      context.fill();
    }
    context.fillStyle = "#234f3c";
    for (let i = 0; i < 8; i += 1) {
      const x = BOARD_LEFT + 8 + i * 96;
      context.fillRect(x, y + 15, 20, 4);
    }
    return;
  }

  const asphalt = context.createLinearGradient(0, y - ROW_HEIGHT / 2, 0, y + ROW_HEIGHT / 2);
  asphalt.addColorStop(0, "#131c35");
  asphalt.addColorStop(1, "#0b1222");
  context.fillStyle = asphalt;
  context.fillRect(BOARD_LEFT - 28, y - ROW_HEIGHT / 2, BOARD_WIDTH + 56, ROW_HEIGHT);

  context.fillStyle = "rgba(255,255,255,0.06)";
  for (let i = 0; i < 6; i += 1) {
    context.fillRect(BOARD_LEFT - 2, y - ROW_HEIGHT / 2 + i * 12, BOARD_WIDTH + 4, 1);
  }

  context.strokeStyle = "rgba(255, 255, 255, 0.18)";
  context.lineWidth = 2;
  for (let col = 1; col < COLS; col += 1) {
    context.setLineDash([18, 14]);
    context.beginPath();
    const laneX = BOARD_LEFT + col * COL_WIDTH;
    context.moveTo(laneX, y - ROW_HEIGHT / 2 + 8);
    context.lineTo(laneX, y + ROW_HEIGHT / 2 - 8);
    context.stroke();
  }
  context.setLineDash([]);
}

export function BootyButtScooter() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const spriteRef = useRef<HTMLImageElement | null>(null);
  const statusRef = useRef<Status>("ready");
  const bestRef = useRef(0);
  const scoreRef = useRef(0);
  const moveRef = useRef<MoveState | null>(null);
  const fartCooldownRef = useRef(0);
  const fartFlashRef = useRef(0);
  const invulnerableRef = useRef(0);
  const puffsRef = useRef<Puff[]>([]);
  const riderRef = useRef<Character>("apollo");
  const soundRef = useRef(true);
  const startRef = useRef<(() => void) | null>(null);
  const resetRef = useRef<(() => void) | null>(null);
  const hopRef = useRef<((direction: "up" | "down" | "left" | "right") => void) | null>(null);
  const fartRef = useRef<(() => void) | null>(null);
  const setStatusRef = useRef<((next: Status) => void) | null>(null);

  const [status, setStatus] = useState<Status>("ready");
  const [score, setScore] = useState(0);
  const [best, setBest] = useState(() => (typeof window === "undefined" ? 0 : Number(localStorage.getItem(BEST_KEY) || 0)));
  const [character, setCharacter] = useState<Character>("apollo");
  const [sound, setSound] = useState(true);
  const { immersive, toggleFullscreen, exitFullscreen } = useGameFullscreen();

  useEffect(() => {
    bestRef.current = best;
  }, [best]);

  useEffect(() => {
    riderRef.current = character;
  }, [character]);

  useEffect(() => {
    soundRef.current = sound;
  }, [sound]);

  useEffect(() => {
    const image = new Image();
    image.src = SPRITE_SRC;
    image.onload = () => {
      spriteRef.current = image;
    };
    return () => {
      spriteRef.current = null;
    };
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    const context = canvas?.getContext("2d");
    if (!canvas || !context) return;

    let audio: AudioContext | null = null;
    const chirp = (notes: number[], duration = 0.12, type: OscillatorType = "triangle", volume = 0.035) => {
      if (!soundRef.current || typeof window === "undefined") return;
      audio ??= new AudioContext();
      notes.forEach((note, index) => {
        const oscillator = audio!.createOscillator();
        const gain = audio!.createGain();
        oscillator.type = type;
        oscillator.frequency.setValueAtTime(note, audio!.currentTime + index * 0.035);
        gain.gain.setValueAtTime(volume, audio!.currentTime + index * 0.035);
        gain.gain.exponentialRampToValueAtTime(0.001, audio!.currentTime + index * 0.035 + duration);
        oscillator.connect(gain).connect(audio!.destination);
        oscillator.start(audio!.currentTime + index * 0.035);
        oscillator.stop(audio!.currentTime + index * 0.035 + duration);
      });
    };

    const player = {
      row: 0,
      col: PLAYER_HOME_COL,
      renderRow: 0,
      renderCol: PLAYER_HOME_COL,
      move: null as MoveState | null,
      bob: 0,
      trail: 0,
    };

    const setGameStatus = (next: Status) => {
      statusRef.current = next;
      setStatus(next);
    };
    setStatusRef.current = setGameStatus;

    const resetWorld = () => {
      player.row = 0;
      player.col = PLAYER_HOME_COL;
      player.renderRow = 0;
      player.renderCol = PLAYER_HOME_COL;
      player.move = null;
      player.bob = 0;
      player.trail = 0;
      moveRef.current = null;
      fartCooldownRef.current = 0;
      fartFlashRef.current = 0;
      invulnerableRef.current = 0;
      puffsRef.current = [];
      scoreRef.current = 0;
      setScore(0);
      setGameStatus("ready");
    };
    resetRef.current = resetWorld;

    const startRun = () => {
      resetWorld();
      setGameStatus("running");
      chirp([523, 659, 784], 0.14, "triangle", 0.025);
    };

    const canMoveTo = (row: number, col: number) => row >= 0 && row < 9999 && col >= 0 && col < COLS;

    const pushMove = (deltaRow: number, deltaCol: number, kind: MoveKind) => {
      if (statusRef.current !== "running" || player.move) return;

      const targetRow = player.row + deltaRow;
      const targetCol = clamp(player.col + deltaCol, 0, COLS - 1);
      if (!canMoveTo(targetRow, targetCol)) return;

      player.move = {
        fromRow: player.row,
        fromCol: player.col,
        toRow: targetRow,
        toCol: targetCol,
        progress: 0,
        duration: kind === "fart" ? 0.26 : 0.16,
        kind,
      };
      moveRef.current = player.move;
      if (kind === "fart") {
        chirp([180, 126, 88], 0.16, "sawtooth", 0.04);
        fartFlashRef.current = 0.72;
        invulnerableRef.current = 0.7;
        puffsRef.current.push(
          { x: tileCenterX(player.col) - 6, y: tileCenterY(player.row, player.renderRow - PLAYER_HOME_ROW) + 16, life: 0.42, radius: 18, driftX: -28, driftY: 8 },
          { x: tileCenterX(player.col) - 20, y: tileCenterY(player.row, player.renderRow - PLAYER_HOME_ROW) + 20, life: 0.5, radius: 20, driftX: -34, driftY: 5 },
          { x: tileCenterX(player.col) - 34, y: tileCenterY(player.row, player.renderRow - PLAYER_HOME_ROW) + 24, life: 0.58, radius: 23, driftX: -40, driftY: 1 },
        );
      }
    };

    const fart = () => {
      if (statusRef.current === "ready" || statusRef.current === "gameover") {
        startRun();
        return;
      }
      if (statusRef.current !== "running" || player.move || fartCooldownRef.current > 0) return;
      fartCooldownRef.current = 1.8;
      pushMove(2, 0, "fart");
      scoreRef.current += 2;
      setScore(scoreRef.current);
    };
    fartRef.current = fart;

    const hop = (direction: "up" | "down" | "left" | "right") => {
      if (statusRef.current === "ready" || statusRef.current === "gameover") {
        startRun();
        return;
      }
      if (statusRef.current !== "running" || player.move) return;
      if (direction === "up") pushMove(1, 0, "hop");
      if (direction === "down") pushMove(-1, 0, "hop");
      if (direction === "left") pushMove(0, -1, "hop");
      if (direction === "right") pushMove(0, 1, "hop");
      chirp(direction === "up" ? [420, 620] : [360], 0.07, "square", 0.018);
    };
    hopRef.current = hop;

    const finish = () => {
      const nextBest = Math.max(bestRef.current, scoreRef.current);
      bestRef.current = nextBest;
      setBest(nextBest);
      if (typeof window !== "undefined") {
        localStorage.setItem(BEST_KEY, String(nextBest));
      }
      setGameStatus("gameover");
      chirp([180, 125, 80], 0.24, "sawtooth", 0.055);
    };

    const collisionAt = (renderRow: number, renderCol: number) => {
      if (invulnerableRef.current > 0) return false;
      const row = Math.round(renderRow);
      if (rowKind(row) !== "road") return false;

      const roadY = tileCenterY(row, renderRow - PLAYER_HOME_ROW);
      const playerX = tileCenterX(renderCol);
      const playerBox = {
        x: playerX - PLAYER_BOX_WIDTH / 2,
        y: roadY - PLAYER_BOX_HEIGHT / 2,
        width: PLAYER_BOX_WIDTH,
        height: PLAYER_BOX_HEIGHT,
      };

      const vehicles = rowVehicles(row);
      const direction = roadDirection(row);
      const laneDirection = direction;
      const time = performance.now() / 1000;
      const span = BOARD_WIDTH + 240;

      for (const vehicle of vehicles) {
        const base = vehicle.offset + time * vehicle.speed * laneDirection;
        const positions = [-1, 0, 1].map((repeat) => BOARD_LEFT - 120 + modulo(base + repeat * span, span));
        for (const x of positions) {
          const box = {
            x: x - vehicle.width / 2,
            y: roadY - vehicle.height / 2,
            width: vehicle.width,
            height: vehicle.height,
          };
          const overlapX = playerBox.x < box.x + box.width && playerBox.x + playerBox.width > box.x;
          const overlapY = playerBox.y < box.y + box.height && playerBox.y + playerBox.height > box.y;
          if (overlapX && overlapY) {
            return true;
          }
        }
      }
      return false;
    };

    const update = (dt: number) => {
      fartCooldownRef.current = Math.max(0, fartCooldownRef.current - dt);
      fartFlashRef.current = Math.max(0, fartFlashRef.current - dt);
      invulnerableRef.current = Math.max(0, invulnerableRef.current - dt);

      if (player.move) {
        player.move.progress = Math.min(1, player.move.progress + dt / player.move.duration);
        const eased = easeOutCubic(player.move.progress);
        player.renderRow = lerp(player.move.fromRow, player.move.toRow, eased);
        player.renderCol = lerp(player.move.fromCol, player.move.toCol, eased);
        player.bob = Math.sin(eased * Math.PI) * (player.move.kind === "fart" ? 22 : 14);
        player.trail = player.move.kind === "fart" ? 1 : 0;

        if (player.move.progress >= 1) {
          player.row = player.move.toRow;
          player.col = player.move.toCol;
          player.renderRow = player.row;
          player.renderCol = player.col;
          if (player.row > scoreRef.current) {
            scoreRef.current = player.row;
            setScore(scoreRef.current);
            if (player.row > 0 && player.row % 5 === 0) chirp([784, 988, 1175], 0.14, "triangle", 0.035);
          }
          if (collisionAt(player.renderRow, player.renderCol)) {
            finish();
          }
          player.move = null;
          moveRef.current = null;
          player.trail = 0;
        }
      } else {
        player.renderRow = player.row;
        player.renderCol = player.col;
        player.bob = Math.sin(performance.now() / 180) * 4;
        if (collisionAt(player.renderRow, player.renderCol)) {
          finish();
        }
      }

      puffsRef.current.forEach((puff) => {
        puff.life -= dt;
        puff.x += puff.driftX * dt;
        puff.y += puff.driftY * dt;
      });
      puffsRef.current = puffsRef.current.filter((puff) => puff.life > 0);
    };

    const drawPuff = (puff: Puff) => {
      context.save();
      context.globalAlpha = clamp(puff.life * 2.2, 0, 1);
      const radius = puff.radius * (1 + (1 - puff.life) * 0.4);
      context.fillStyle = puff.life > 0.2 ? "#74f5a0" : "#f7df61";
      context.beginPath();
      context.ellipse(puff.x, puff.y, radius * 1.1, radius * 0.72, 0, 0, Math.PI * 2);
      context.fill();
      context.fillStyle = "rgba(255,255,255,0.4)";
      context.beginPath();
      context.arc(puff.x - 6, puff.y - 4, radius * 0.28, 0, Math.PI * 2);
      context.fill();
      context.restore();
    };

    const draw = () => {
      const cameraRow = player.renderRow - PLAYER_HOME_ROW;
      const sky = context.createLinearGradient(0, 0, 0, HEIGHT);
      sky.addColorStop(0, "#091120");
      sky.addColorStop(0.55, "#0e1730");
      sky.addColorStop(1, "#06101f");
      context.fillStyle = sky;
      context.fillRect(0, 0, WIDTH, HEIGHT);

      const glow = context.createRadialGradient(WIDTH * 0.48, HEIGHT * 0.24, 20, WIDTH * 0.48, HEIGHT * 0.24, 340);
      glow.addColorStop(0, "rgba(109,240,223,0.16)");
      glow.addColorStop(1, "transparent");
      context.fillStyle = glow;
      context.fillRect(0, 0, WIDTH, HEIGHT);

      context.fillStyle = "rgba(255,255,255,0.05)";
      for (let i = 0; i < 42; i += 1) {
        const x = (i * 103) % WIDTH;
        const y = 28 + ((i * 67) % 208);
        context.fillRect(x, y, 2, 2);
      }

      for (let visualRow = -2; visualRow <= VISIBLE_ROWS + 2; visualRow += 1) {
        const row = Math.floor(cameraRow) + visualRow;
        const y = tileCenterY(row, cameraRow);
        const isGrass = rowKind(row) === "grass";
        drawRoadSurface(context, y, isGrass);

        if (isGrass) {
          context.fillStyle = "#274535";
          for (let tree = 0; tree < 3; tree += 1) {
            const treeX = BOARD_LEFT + 48 + tree * 216 + modulo(row * 19, 38);
            context.fillRect(treeX, y - 25, 8, 36);
            context.beginPath();
            context.arc(treeX + 4, y - 32, 16, 0, Math.PI * 2);
            context.fill();
          }
        } else {
          const vehicles = rowVehicles(row);
          const direction = roadDirection(row);
          const time = performance.now() / 1000;
          const span = BOARD_WIDTH + 240;
          const roadY = y;
          vehicles.forEach((vehicle, index) => {
            const base = vehicle.offset + time * vehicle.speed * direction + index * 128;
            const x = BOARD_LEFT - 120 + modulo(base, span);
            drawVehicle(context, vehicle, x, roadY, direction);
          });
        }
      }

      puffsRef.current.forEach(drawPuff);

      const sprite = spriteRef.current;
      if (sprite) {
        const x = tileCenterX(player.renderCol);
        const y = tileCenterY(player.renderRow, cameraRow) + player.bob;
        const tilt = clamp((player.move?.toCol ?? player.col) - player.renderCol, -1, 1) * 0.12;
        drawCharacterSprite(context, sprite, riderRef.current, fartFlashRef.current > 0, x, y, 0.6, tilt);

        if (fartFlashRef.current > 0) {
          context.save();
          context.globalAlpha = clamp(fartFlashRef.current * 1.8, 0, 1);
          const fartGlow = context.createRadialGradient(x - 30, y + 18, 6, x - 30, y + 18, 56);
          fartGlow.addColorStop(0, "rgba(116,245,160,0.8)");
          fartGlow.addColorStop(1, "rgba(116,245,160,0)");
          context.fillStyle = fartGlow;
          context.beginPath();
          context.ellipse(x - 48, y + 18, 36, 16, -0.08, 0, Math.PI * 2);
          context.fill();
          context.restore();
        }
      }

      const hudY = 28;
      context.fillStyle = "#eef0fa";
      context.font = "700 18px Space Grotesk, sans-serif";
      context.fillText(`ROW ${String(scoreRef.current).padStart(3, "0")}`, 20, hudY);
      context.font = "500 12px JetBrains Mono, monospace";
      context.fillStyle = "#8fa6c5";
      context.fillText("TAP / ARROWS TO HOP", 20, hudY + 24);
      context.fillText("SPACE OR F TO FART-BOOST", 20, hudY + 42);

      context.save();
      context.textAlign = "right";
      context.fillStyle = "#6df0df";
      context.font = "700 12px JetBrains Mono, monospace";
      context.fillText(`BEST ${String(bestRef.current).padStart(3, "0")}`, WIDTH - 20, hudY);
      context.fillStyle = fartCooldownRef.current <= 0 ? "#74f5a0" : "#ffcb75";
      context.fillText(fartCooldownRef.current <= 0 ? "FART READY" : `FART ${fartCooldownRef.current.toFixed(1)}s`, WIDTH - 20, hudY + 20);
      context.fillStyle = "#8fa6c5";
      context.fillText(`RIDER ${riderRef.current === "apollo" ? "APOLLO" : "ROCCO"}`, WIDTH - 20, hudY + 40);
      context.fillStyle = "#74f5a0";
      context.fillText("SPACE / F = FART", WIDTH - 20, hudY + 60);
      context.restore();
    };

    let previous = performance.now();
    let raf = 0;

    const frame = (now: number) => {
      const dt = Math.min(0.05, (now - previous) / 1000);
      previous = now;

      if (statusRef.current === "running") {
        update(dt);
      }

      draw();
      raf = requestAnimationFrame(frame);
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.code === "ArrowUp" || event.code === "KeyW") {
        event.preventDefault();
        hop("up");
      }
      if (event.code === "ArrowDown" || event.code === "KeyS") {
        event.preventDefault();
        hop("down");
      }
      if (event.code === "ArrowLeft" || event.code === "KeyA") {
        event.preventDefault();
        hop("left");
      }
      if (event.code === "ArrowRight" || event.code === "KeyD") {
        event.preventDefault();
        hop("right");
      }
      if (event.code === "Space" || event.code === "KeyF") {
        event.preventDefault();
        fart();
      }
      if (event.code === "KeyP" || event.code === "Escape") {
        event.preventDefault();
        setGameStatus(statusRef.current === "paused" ? "running" : "paused");
      }
      if (event.code === "Enter" && statusRef.current !== "running") {
        startRun();
      }
    };

    const touch = { x: 0, y: 0, time: 0 };
    const handlePointerDown = (event: PointerEvent) => {
      touch.x = event.clientX;
      touch.y = event.clientY;
      touch.time = performance.now();
      canvas.setPointerCapture(event.pointerId);
    };
    const handlePointerUp = (event: PointerEvent) => {
      const dx = event.clientX - touch.x;
      const dy = event.clientY - touch.y;
      const elapsed = performance.now() - touch.time;
      canvas.releasePointerCapture(event.pointerId);

      if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 26) {
        hop(dx > 0 ? "right" : "left");
        return;
      }
      if (dy < -24) {
        hop("up");
        return;
      }
      if (dy > 24) {
        hop("down");
        return;
      }
      if (elapsed < 360) {
        fart();
      }
    };

    startRef.current = startRun;
    canvas.addEventListener("pointerdown", handlePointerDown);
    canvas.addEventListener("pointerup", handlePointerUp);
    window.addEventListener("keydown", handleKeyDown);
    raf = requestAnimationFrame(frame);

    return () => {
      cancelAnimationFrame(raf);
      canvas.removeEventListener("pointerdown", handlePointerDown);
      canvas.removeEventListener("pointerup", handlePointerUp);
      window.removeEventListener("keydown", handleKeyDown);
      startRef.current = null;
      resetRef.current = null;
      hopRef.current = null;
      fartRef.current = null;
      setStatusRef.current = null;
      spriteRef.current = null;
      audio?.close();
    };
  }, []);

  const reset = () => {
    resetRef.current?.();
  };

  const changeCharacter = (next: Character) => {
    setCharacter(next);
  };

  return (
    <section className="space-y-6" aria-labelledby="booty-butt-scooter-title">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--accent)]">Arcade / Crossy scooter</p>
          <h1 id="booty-butt-scooter-title" className="font-display text-3xl font-bold tracking-tight">
            Booty Butt Scooter
          </h1>
          <p className="mt-2 max-w-xl text-sm text-[var(--muted)]">
            Help Apollo or Rocco hop through traffic, dodge the cross-town crush, and fart-boost past the meanest gaps.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-3 text-xs text-[var(--muted)]">
          <span>BEST {best.toString().padStart(3, "0")}</span>
          <button type="button" className="game-icon-button rounded-md border border-[var(--border)] p-2" onClick={() => setSound((value) => !value)} aria-label={sound ? "Mute game sounds" : "Enable game sounds"}>{sound ? <Volume2 size={16} /> : <VolumeX size={16} />}</button>
          <button
            type="button"
            className="game-icon-button rounded-md border border-[var(--border)] p-2"
            onClick={() => toggleFullscreen(stageRef.current)}
            aria-label={immersive ? "Exit fullscreen" : "Play fullscreen"}
          >
            {immersive ? <Minimize2 size={16} /> : <Maximize2 size={16} />}
          </button>
        </div>
      </div>

      <div
        ref={stageRef}
        className={`game-stage relative mx-auto overflow-hidden bg-[#06101f] shadow-[0_24px_80px_rgba(0,0,0,.42)] ${immersive ? "fixed inset-0 z-[70] flex max-w-none items-center rounded-none border-0 p-3" : "w-full min-w-0 max-w-[960px] rounded-3xl border border-[#29446c]"}`}
      >
        <canvas
          ref={canvasRef}
          width={WIDTH}
          height={HEIGHT}
          className="block h-auto w-full touch-none select-none"
          aria-label="Booty Butt Scooter crossy road game"
        />
        {immersive ? <button type="button" className="absolute right-4 top-4 z-20 rounded-full border border-white/30 bg-[#06101f]/90 p-3 text-white shadow-lg" onClick={exitFullscreen} aria-label="Exit fullscreen"><Minimize2 size={18} /></button> : null}

        {status !== "running" ? (
          <div className="absolute inset-0 flex items-center justify-center bg-[#06101f]/76 p-6 text-center backdrop-blur-[2px]">
            <div className="max-w-sm">
              <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#6df0df]">
                {status === "gameover" ? "Run ended" : status === "paused" ? "Course paused" : "Ready to ride"}
              </p>
              <h2 className="mt-2 font-display text-3xl font-bold text-white">
                {status === "gameover" ? "Try the next crossing." : status === "paused" ? "Hold your lane." : "Choose your rider."}
              </h2>
              <p className="mt-3 text-sm leading-6 text-[#b9c8dc]">
                {status === "gameover"
                  ? `You made it to row ${score}. Best ${best}.`
                  : "Arrow keys or taps hop one tile. Space or F gives a fart boost and a little invulnerability."}
              </p>
              <div className="mt-5 flex justify-center gap-2">
                <button
                  type="button"
                  className={`game-control rounded-full border px-3 py-2 text-sm font-semibold ${character === "apollo" ? "border-[#6df0df] bg-[#6df0df] text-[#06101f]" : "border-[var(--border)] text-white"}`}
                  onClick={() => changeCharacter("apollo")}
                >
                  Apollo
                </button>
                <button
                  type="button"
                  className={`game-control rounded-full border px-3 py-2 text-sm font-semibold ${character === "rocco" ? "border-[#ffcb75] bg-[#ffcb75] text-[#06101f]" : "border-[var(--border)] text-white"}`}
                  onClick={() => changeCharacter("rocco")}
                >
                  Rocco
                </button>
              </div>
              <button
                type="button"
                className="game-control pointer-events-auto mt-5 inline-flex items-center gap-2 rounded-lg bg-[#6df0df] px-5 py-3 text-sm font-semibold text-[#06101f]"
                onClick={() => (status === "paused" ? setStatusRef.current?.("running") : startRef.current?.())}
              >
                <Play size={16} />
                {status === "paused" ? "Resume" : status === "gameover" ? "Run again" : "Start run"}
              </button>
            </div>
          </div>
        ) : null}
      </div>

      <div className="game-command-bar flex flex-wrap items-center justify-between gap-3 text-xs text-[var(--muted)]">
        <span>
          Score {score} · Best {best} · Rider {character === "apollo" ? "Apollo" : "Rocco"}
        </span>
        <div className="flex flex-wrap gap-2" aria-label="Scooter controls">
          <button
            type="button"
            className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2"
            onClick={() => setStatusRef.current?.(status === "paused" ? "running" : "paused")}
          >
            <Pause size={14} />
            {status === "paused" ? "Resume" : "Pause"}
          </button>
          <button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={reset}>
            <RotateCcw size={14} />
            Reset
          </button>
          <button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => hopRef.current?.("left")}>
            <ArrowLeft size={14} />
            Left
          </button>
          <button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => hopRef.current?.("up")}>
            <ArrowUp size={14} />
            Hop
          </button>
          <button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => fartRef.current?.()}>
            <Wind size={14} />
            Fart
          </button>
          <button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => hopRef.current?.("right")}>
            Right
            <ArrowRight size={14} />
          </button>
          <button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => hopRef.current?.("down")}>
            <ArrowDown size={14} />
            Back
          </button>
        </div>
      </div>
    </section>
  );
}
