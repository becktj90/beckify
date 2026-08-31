import { useEffect, useRef, useState } from "react";
import { Box, Hammer, Maximize2, Minimize2, RefreshCw, RotateCw, Volume2, VolumeX } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";

// Chunked voxel storage, procedural terrain, and the mine/place interaction
// loop follow the general architecture pioneered by fogleman/Craft (MIT
// license, https://github.com/fogleman/Craft): a dense per-chunk block grid,
// deterministic seeded generation, and raycast-driven break/place. This is an
// original TypeScript + Canvas2D isometric implementation — no Craft source,
// shaders, textures, or assets are reused, and none of Craft's C/OpenGL code
// runs here.

const SX = 20, SZ = 20, SY = 10;
const TILE_W = 36, TILE_H = 18, BLOCK_H = 28, PAD = 40;
const HALF_W = TILE_W / 2, HALF_H = TILE_H / 2;
const CANVAS_W = SX * TILE_W + PAD * 2;
const CANVAS_H = SX * TILE_H + SY * BLOCK_H + PAD * 2;
const ORIGIN_X = SX * HALF_W + PAD;
const ORIGIN_Y = SY * BLOCK_H + PAD;
const SAVE_KEY = "voxel-yard-save-v1";
const STATS_KEY = "voxel-yard-stats-v1";

const BLOCK = { AIR: 0, GRASS: 1, DIRT: 2, STONE: 3, SAND: 4, SNOW: 5, WOOD: 6, LEAVES: 7, PLANK: 8, BRICK: 9, GLASS: 10 } as const;
type BlockId = (typeof BLOCK)[keyof typeof BLOCK];
type Rotation = 0 | 1 | 2 | 3;
type FaceDir = "top" | "a" | "b";
interface FaceRec { x: number; y: number; z: number; dir: FaceDir; poly: [number, number][]; fill: string; }
interface Target { x: number; y: number; z: number; dir: FaceDir; }

const PALETTE: Record<number, { name: string; base: string; top?: string; alpha?: number }> = {
  [BLOCK.GRASS]: { name: "Grass", base: "#7a5230", top: "#5cc24b" },
  [BLOCK.DIRT]: { name: "Dirt", base: "#7a5230" },
  [BLOCK.STONE]: { name: "Stone", base: "#8b8f97" },
  [BLOCK.SAND]: { name: "Sand", base: "#e8d391" },
  [BLOCK.SNOW]: { name: "Snow", base: "#eef4ff" },
  [BLOCK.WOOD]: { name: "Wood", base: "#6b4a2c" },
  [BLOCK.LEAVES]: { name: "Leaves", base: "#3f8f4d" },
  [BLOCK.PLANK]: { name: "Plank", base: "#caa25c" },
  [BLOCK.BRICK]: { name: "Brick", base: "#b1503f" },
  [BLOCK.GLASS]: { name: "Glass", base: "#bfe8ff", alpha: 0.55 },
};

const HOTBAR: BlockId[] = [BLOCK.GRASS, BLOCK.DIRT, BLOCK.STONE, BLOCK.SAND, BLOCK.SNOW, BLOCK.WOOD, BLOCK.PLANK, BLOCK.BRICK, BLOCK.GLASS];

const idx = (x: number, y: number, z: number) => x + z * SX + y * SX * SZ;
const inBounds = (x: number, y: number, z: number) => x >= 0 && x < SX && y >= 0 && y < SY && z >= 0 && z < SZ;
const getBlock = (world: Uint8Array, x: number, y: number, z: number) => (inBounds(x, y, z) ? world[idx(x, y, z)] : BLOCK.AIR);
const setBlock = (world: Uint8Array, x: number, y: number, z: number, id: number) => { if (inBounds(x, y, z)) world[idx(x, y, z)] = id; };

// --- Deterministic hashed-lattice noise, seeded by a plain number (not
// Math.random) so terrain generation is reproducible from its seed alone. ---
function hashLattice(x: number, y: number, z: number, seed: number) {
  let h = x * 374761393 + y * 668265263 + z * 2147483647 + seed * 2654435761;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967295;
}
const fade = (t: number) => t * t * (3 - 2 * t);

function noise2D(x: number, z: number, seed: number) {
  const x0 = Math.floor(x), z0 = Math.floor(z);
  const xf = fade(x - x0), zf = fade(z - z0);
  const h00 = hashLattice(x0, 0, z0, seed), h10 = hashLattice(x0 + 1, 0, z0, seed);
  const h01 = hashLattice(x0, 0, z0 + 1, seed), h11 = hashLattice(x0 + 1, 0, z0 + 1, seed);
  const nx0 = h00 + xf * (h10 - h00), nx1 = h01 + xf * (h11 - h01);
  return nx0 + zf * (nx1 - nx0);
}
function fbm2D(x: number, z: number, seed: number, octaves = 4) {
  let amp = 0.5, freq = 1, sum = 0, norm = 0;
  for (let i = 0; i < octaves; i++) { sum += noise2D(x * freq, z * freq, seed) * amp; norm += amp; amp *= 0.5; freq *= 2; }
  return sum / norm;
}
function noise3D(x: number, y: number, z: number, seed: number) {
  const x0 = Math.floor(x), y0 = Math.floor(y), z0 = Math.floor(z);
  const xf = fade(x - x0), yf = fade(y - y0), zf = fade(z - z0);
  const c000 = hashLattice(x0, y0, z0, seed), c100 = hashLattice(x0 + 1, y0, z0, seed);
  const c010 = hashLattice(x0, y0 + 1, z0, seed), c110 = hashLattice(x0 + 1, y0 + 1, z0, seed);
  const c001 = hashLattice(x0, y0, z0 + 1, seed), c101 = hashLattice(x0 + 1, y0, z0 + 1, seed);
  const c011 = hashLattice(x0, y0 + 1, z0 + 1, seed), c111 = hashLattice(x0 + 1, y0 + 1, z0 + 1, seed);
  const x00 = c000 + xf * (c100 - c000), x10 = c010 + xf * (c110 - c010);
  const x01 = c001 + xf * (c101 - c001), x11 = c011 + xf * (c111 - c011);
  const y0v = x00 + yf * (x10 - x00), y1v = x01 + yf * (x11 - x01);
  return y0v + zf * (y1v - y0v);
}

function generateWorld(seed: number): Uint8Array {
  const world = new Uint8Array(SX * SY * SZ);
  const cx = (SX - 1) / 2, cz = (SZ - 1) / 2, maxR = Math.min(cx, cz);
  const seaLevel = 3;
  for (let x = 0; x < SX; x++) {
    for (let z = 0; z < SZ; z++) {
      const n = fbm2D(x * 0.15, z * 0.15, seed);
      const dist = Math.hypot(x - cx, z - cz) / maxR;
      const falloff = Math.max(0, 1 - (Math.min(1, dist) ** 2.2));
      let h = Math.round(2 + n * 7 * falloff);
      h = Math.max(1, Math.min(SY - 3, h));
      const beach = h <= seaLevel;
      for (let y = 0; y < h; y++) {
        if (y > 0 && y < h - 2 && noise3D(x * 0.3, y * 0.35, z * 0.3, seed + 4242) > 0.63) continue;
        let id: number = BLOCK.STONE;
        if (y === h - 1) id = beach ? BLOCK.SAND : h >= SY - 4 ? BLOCK.SNOW : BLOCK.GRASS;
        else if (y >= h - 3) id = beach ? BLOCK.SAND : BLOCK.DIRT;
        setBlock(world, x, y, z, id);
      }
      const isTree = !beach && h < SY - 5 && x > 1 && x < SX - 2 && z > 1 && z < SZ - 2 && hashLattice(x * 3, 0, z * 7, seed + 909) < 0.045;
      if (isTree) {
        for (let t = 0; t < 3; t++) setBlock(world, x, h + t, z, BLOCK.WOOD);
        for (let dy = 2; dy <= 4; dy++) {
          const ly = h + dy;
          if (ly >= SY) continue;
          const spread = dy === 4 ? 0 : 1;
          for (let dx = -spread; dx <= spread; dx++) {
            for (let dz = -spread; dz <= spread; dz++) {
              const lx = x + dx, lz = z + dz;
              if (lx < 0 || lx >= SX || lz < 0 || lz >= SZ) continue;
              if (getBlock(world, lx, ly, lz) === BLOCK.AIR) setBlock(world, lx, ly, lz, BLOCK.LEAVES);
            }
          }
        }
      }
    }
  }
  return world;
}

function encodeWorld(world: Uint8Array) {
  let s = "";
  for (let i = 0; i < world.length; i++) s += String.fromCharCode(world[i]);
  return btoa(s);
}
function decodeWorld(b64: string): Uint8Array | null {
  try {
    const bin = atob(b64);
    if (bin.length !== SX * SY * SZ) return null;
    const arr = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
    return arr;
  } catch {
    return null;
  }
}
const loadStats = () => {
  try {
    const raw = localStorage.getItem(STATS_KEY);
    const parsed = raw ? JSON.parse(raw) : null;
    return { mined: Number(parsed?.mined) || 0, placed: Number(parsed?.placed) || 0 };
  } catch {
    return { mined: 0, placed: 0 };
  }
};

// --- Isometric projection. The camera is fixed looking along the (1,1,1)
// diagonal, so painting voxels in ascending (vx + y + vz) order — and only
// ever drawing the top, +vx, and +vz faces — gives correct occlusion with no
// z-buffer. `rotation` re-maps which real grid axes are treated as "east"
// (+vx) and "south" (+vz) so every side of the island can be reached. ---
type RotateMeta = { toV: (x: number, z: number) => [number, number]; aD: [number, number]; bD: [number, number] };
function rotateMeta(r: Rotation): RotateMeta {
  if (r === 0) return { toV: (x, z) => [x, z], aD: [1, 0], bD: [0, 1] };
  if (r === 1) return { toV: (x, z) => [z, SX - 1 - x], aD: [0, 1], bD: [-1, 0] };
  if (r === 2) return { toV: (x, z) => [SX - 1 - x, SZ - 1 - z], aD: [-1, 0], bD: [0, -1] };
  return { toV: (x, z) => [SZ - 1 - z, x], aD: [0, -1], bD: [1, 0] };
}
function outwardDelta(dir: FaceDir, rotation: Rotation): [number, number, number] {
  if (dir === "top") return [0, 1, 0];
  const { aD, bD } = rotateMeta(rotation);
  return dir === "a" ? [aD[0], 0, aD[1]] : [bD[0], 0, bD[1]];
}
function project(vx: number, vy: number, vz: number): [number, number] {
  return [ORIGIN_X + (vx - vz) * HALF_W, ORIGIN_Y + (vx + vz) * HALF_H - vy * BLOCK_H];
}
function shade(hex: string, factor: number, alpha?: number) {
  const r = Number.parseInt(hex.slice(1, 3), 16), g = Number.parseInt(hex.slice(3, 5), 16), b = Number.parseInt(hex.slice(5, 7), 16);
  const rr = Math.min(255, Math.round(r * factor)), gg = Math.min(255, Math.round(g * factor)), bb = Math.min(255, Math.round(b * factor));
  return alpha === undefined ? `rgb(${rr},${gg},${bb})` : `rgba(${rr},${gg},${bb},${alpha})`;
}

function buildFaces(world: Uint8Array, rotation: Rotation): FaceRec[] {
  const { toV, aD, bD } = rotateMeta(rotation);
  const solids: { x: number; y: number; z: number; id: number; vx: number; vz: number }[] = [];
  for (let x = 0; x < SX; x++) {
    for (let z = 0; z < SZ; z++) {
      for (let y = 0; y < SY; y++) {
        const id = getBlock(world, x, y, z);
        if (id === BLOCK.AIR) continue;
        const [vx, vz] = toV(x, z);
        solids.push({ x, y, z, id, vx, vz });
      }
    }
  }
  solids.sort((p, q) => p.vx + p.y + p.vz - (q.vx + q.y + q.vz));
  const faces: FaceRec[] = [];
  for (const s of solids) {
    const def = PALETTE[s.id];
    if (!def) continue;
    const sideBase = s.id === BLOCK.GRASS ? PALETTE[BLOCK.DIRT].base : def.base;
    const topVisible = getBlock(world, s.x, s.y + 1, s.z) === BLOCK.AIR;
    const aVisible = getBlock(world, s.x + aD[0], s.y, s.z + aD[1]) === BLOCK.AIR;
    const bVisible = getBlock(world, s.x + bD[0], s.y, s.z + bD[1]) === BLOCK.AIR;
    const { vx, vz, y } = s;
    if (topVisible) {
      faces.push({ x: s.x, y: s.y, z: s.z, dir: "top", fill: shade(def.top ?? def.base, 1, def.alpha), poly: [project(vx, y + 1, vz), project(vx + 1, y + 1, vz), project(vx + 1, y + 1, vz + 1), project(vx, y + 1, vz + 1)] });
    }
    if (aVisible) {
      faces.push({ x: s.x, y: s.y, z: s.z, dir: "a", fill: shade(sideBase, 0.72, def.alpha), poly: [project(vx + 1, y, vz), project(vx + 1, y, vz + 1), project(vx + 1, y + 1, vz + 1), project(vx + 1, y + 1, vz)] });
    }
    if (bVisible) {
      faces.push({ x: s.x, y: s.y, z: s.z, dir: "b", fill: shade(sideBase, 0.5, def.alpha), poly: [project(vx, y, vz + 1), project(vx + 1, y, vz + 1), project(vx + 1, y + 1, vz + 1), project(vx, y + 1, vz + 1)] });
    }
  }
  return faces;
}

function pointInPoly(px: number, py: number, poly: [number, number][]) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    const intersect = yi > py !== yj > py && px < ((xj - xi) * (py - yi)) / (yj - yi) + xi;
    if (intersect) inside = !inside;
  }
  return inside;
}

export function VoxelYard() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const worldRef = useRef<Uint8Array>(new Uint8Array(SX * SY * SZ));
  const seedRef = useRef(0);
  const facesRef = useRef<FaceRec[]>([]);
  const targetRef = useRef<Target | null>(null);
  const rotationRef = useRef<Rotation>(0);
  const selectedRef = useRef<BlockId>(BLOCK.GRASS);
  const mutedRef = useRef(false);
  const mineRef = useRef<() => void>(() => {});
  const placeRef = useRef<() => void>(() => {});
  const rotateRef = useRef<() => void>(() => {});
  const newIslandRef = useRef<() => void>(() => {});

  const [selected, setSelected] = useState<BlockId>(BLOCK.GRASS);
  const [muted, setMuted] = useState(false);
  const [stats, setStats] = useState(loadStats);
  const [targetLabel, setTargetLabel] = useState<string | null>(null);
  const [started, setStarted] = useState(false);
  const [confirmingReset, setConfirmingReset] = useState(false);
  const { immersive, toggleFullscreen, exitFullscreen } = useGameFullscreen();

  useEffect(() => { mutedRef.current = muted; }, [muted]);
  useEffect(() => { selectedRef.current = selected; }, [selected]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext("2d");
    if (!canvas || !ctx) return;

    let world: Uint8Array;
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      const parsed = raw ? JSON.parse(raw) : null;
      const decoded = parsed?.world ? decodeWorld(parsed.world) : null;
      if (decoded) { world = decoded; seedRef.current = Number(parsed.seed) || 0; }
      else { seedRef.current = Math.floor(Math.random() * 1e9); world = generateWorld(seedRef.current); }
    } catch {
      seedRef.current = Math.floor(Math.random() * 1e9);
      world = generateWorld(seedRef.current);
    }
    worldRef.current = world;

    const persist = () => {
      try { localStorage.setItem(SAVE_KEY, JSON.stringify({ seed: seedRef.current, world: encodeWorld(worldRef.current) })); } catch { /* storage is optional */ }
    };
    persist();

    let audio: AudioContext | undefined;
    const tone = (freq: number, len: number, type: OscillatorType, volume = 0.05) => {
      if (mutedRef.current) return;
      try {
        audio ??= new AudioContext();
        const osc = audio.createOscillator(), gain = audio.createGain();
        osc.type = type;
        osc.frequency.setValueAtTime(freq, audio.currentTime);
        gain.gain.setValueAtTime(volume, audio.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audio.currentTime + len);
        osc.connect(gain).connect(audio.destination);
        osc.start();
        osc.stop(audio.currentTime + len);
      } catch { /* audio is optional */ }
    };

    const rebuild = () => { facesRef.current = buildFaces(worldRef.current, rotationRef.current); };
    rebuild();

    const findFaceAt = (px: number, py: number) => {
      const faces = facesRef.current;
      for (let i = faces.length - 1; i >= 0; i--) if (pointInPoly(px, py, faces[i].poly)) return faces[i];
      return null;
    };
    const bumpStats = (kind: "mined" | "placed") => {
      setStats((current) => {
        const next = { ...current, [kind]: current[kind] + 1 };
        try { localStorage.setItem(STATS_KEY, JSON.stringify(next)); } catch { /* storage is optional */ }
        return next;
      });
    };

    const mine = () => {
      const t = targetRef.current;
      if (!t || getBlock(worldRef.current, t.x, t.y, t.z) === BLOCK.AIR) return;
      setBlock(worldRef.current, t.x, t.y, t.z, BLOCK.AIR);
      rebuild(); persist(); tone(90, 0.16, "sawtooth", 0.06); bumpStats("mined");
      targetRef.current = null; setTargetLabel(null);
    };
    const place = () => {
      const t = targetRef.current;
      if (!t) return;
      const [dx, dy, dz] = outwardDelta(t.dir, rotationRef.current);
      const nx = t.x + dx, ny = t.y + dy, nz = t.z + dz;
      if (!inBounds(nx, ny, nz) || getBlock(worldRef.current, nx, ny, nz) !== BLOCK.AIR) return;
      setBlock(worldRef.current, nx, ny, nz, selectedRef.current);
      rebuild(); persist(); tone(360, 0.09, "square", 0.05); bumpStats("placed");
      targetRef.current = { x: nx, y: ny, z: nz, dir: t.dir };
      setTargetLabel(`${PALETTE[selectedRef.current]?.name ?? "Block"} · (${nx}, ${ny}, ${nz})`);
    };
    const rotate = () => {
      rotationRef.current = ((rotationRef.current + 1) % 4) as Rotation;
      targetRef.current = null; setTargetLabel(null);
      rebuild(); tone(520, 0.08, "triangle", 0.03);
    };
    const newIsland = () => {
      seedRef.current = Math.floor(Math.random() * 1e9);
      worldRef.current = generateWorld(seedRef.current);
      targetRef.current = null; setTargetLabel(null);
      rebuild(); persist(); tone(220, 0.22, "triangle", 0.05);
    };
    mineRef.current = mine; placeRef.current = place; rotateRef.current = rotate; newIslandRef.current = newIsland;

    const pointerDown = (event: PointerEvent) => {
      event.preventDefault();
      setStarted(true);
      const rect = canvas.getBoundingClientRect();
      const scaleX = canvas.width / rect.width, scaleY = canvas.height / rect.height;
      const px = (event.clientX - rect.left) * scaleX, py = (event.clientY - rect.top) * scaleY;
      const face = findFaceAt(px, py);
      if (face) {
        targetRef.current = { x: face.x, y: face.y, z: face.z, dir: face.dir };
        setTargetLabel(`${PALETTE[getBlock(worldRef.current, face.x, face.y, face.z)]?.name ?? "Block"} · (${face.x}, ${face.y}, ${face.z})`);
      } else {
        targetRef.current = null; setTargetLabel(null);
      }
    };
    const contextMenu = (event: MouseEvent) => event.preventDefault();
    const keyDown = (event: KeyboardEvent) => {
      if (event.repeat) return;
      const digit = Number(event.key);
      if (digit >= 1 && digit <= HOTBAR.length) { setSelected(HOTBAR[digit - 1]); return; }
      if (event.key === "r" || event.key === "R") rotate();
      if (event.key === "m" || event.key === "M") mine();
      if (event.key === "p" || event.key === "P") place();
    };

    let raf = 0;
    const draw = (now: number) => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      const sky = ctx.createLinearGradient(0, 0, 0, canvas.height);
      sky.addColorStop(0, "#1a2550"); sky.addColorStop(1, "#0a0f24");
      ctx.fillStyle = sky; ctx.fillRect(0, 0, canvas.width, canvas.height);
      for (const face of facesRef.current) {
        ctx.beginPath();
        ctx.moveTo(face.poly[0][0], face.poly[0][1]);
        for (let i = 1; i < face.poly.length; i++) ctx.lineTo(face.poly[i][0], face.poly[i][1]);
        ctx.closePath();
        ctx.fillStyle = face.fill;
        ctx.fill();
        ctx.strokeStyle = "rgba(3,7,20,0.28)";
        ctx.lineWidth = 1;
        ctx.stroke();
      }
      const t = targetRef.current;
      if (t) {
        const face = facesRef.current.find((f) => f.x === t.x && f.y === t.y && f.z === t.z && f.dir === t.dir);
        if (face) {
          const glow = 0.55 + Math.sin(now / 220) * 0.35;
          ctx.beginPath();
          ctx.moveTo(face.poly[0][0], face.poly[0][1]);
          for (let i = 1; i < face.poly.length; i++) ctx.lineTo(face.poly[i][0], face.poly[i][1]);
          ctx.closePath();
          ctx.strokeStyle = `rgba(255,214,90,${glow})`;
          ctx.lineWidth = 3;
          ctx.stroke();
        } else {
          targetRef.current = null;
        }
      }
      raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);

    canvas.addEventListener("pointerdown", pointerDown);
    canvas.addEventListener("contextmenu", contextMenu);
    window.addEventListener("keydown", keyDown);
    return () => {
      cancelAnimationFrame(raf);
      canvas.removeEventListener("pointerdown", pointerDown);
      canvas.removeEventListener("contextmenu", contextMenu);
      window.removeEventListener("keydown", keyDown);
      audio?.close().catch(() => {});
    };
  }, []);

  return (
    <section className="space-y-6" aria-labelledby="voxel-yard-title">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--accent)]">Sandbox / Voxel builder</p>
          <h1 id="voxel-yard-title" className="font-display text-3xl font-bold tracking-tight">Voxel Yard</h1>
          <p className="mt-2 max-w-xl text-sm text-[var(--muted)]">A creative voxel-building sandbox: tap a block to target it, then mine or place. Rotate the view to reach every side of the island. Touch, mouse, and keyboard all work.</p>
        </div>
        <div className="flex items-center gap-3 text-xs text-[var(--muted)]">
          <span>MINED {stats.mined} · PLACED {stats.placed}</span>
          <button type="button" className="game-icon-button rounded-md border border-[var(--border)] p-2" onClick={() => setMuted((v) => !v)} aria-label={muted ? "Enable game sounds" : "Mute game sounds"}>{muted ? <VolumeX size={16} /> : <Volume2 size={16} />}</button>
          <button type="button" className="game-icon-button rounded-md border border-[var(--border)] p-2" onClick={() => toggleFullscreen(stageRef.current)} aria-label={immersive ? "Exit fullscreen" : "Play fullscreen"}>{immersive ? <Minimize2 size={16} /> : <Maximize2 size={16} />}</button>
        </div>
      </div>

      <div ref={stageRef} className={`game-stage relative mx-auto overflow-hidden bg-[#0a0f24] shadow-[0_20px_60px_rgba(0,0,0,.35)] ${immersive ? "fixed inset-0 z-[70] flex max-w-none items-center rounded-none border-0 p-3" : "max-w-[800px] rounded-2xl border border-[#2e5d86]"}`}>
        <canvas ref={canvasRef} width={CANVAS_W} height={CANVAS_H} className="block h-auto w-full touch-none" aria-label="Voxel Yard isometric voxel builder" />
        {immersive ? <button type="button" className="absolute right-4 top-4 z-10 rounded-full border border-white/30 bg-[#0a0f24]/90 p-3 text-white shadow-lg" onClick={exitFullscreen} aria-label="Exit fullscreen"><Minimize2 size={18} /></button> : null}
        {!started ? (
          <div className="pointer-events-none absolute inset-0 flex items-center justify-center bg-[#0a0f24]/55 p-6 text-center backdrop-blur-[1px]">
            <div className="max-w-xs">
              <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#6df0df]">Ready to build</p>
              <h2 className="mt-2 font-display text-2xl font-bold text-white">Tap any block face</h2>
              <p className="mt-3 text-sm leading-6 text-[#b9c8dc]">Target a face, then Mine or Place. Rotate to reach every side of the island.</p>
            </div>
          </div>
        ) : null}
      </div>

      <div className="game-command-bar flex flex-wrap items-center justify-between gap-3 text-xs text-[var(--muted)]">
        <span aria-live="polite">{targetLabel ? `Target: ${targetLabel}` : "No block targeted — tap the island"}</span>
        <div className="flex flex-wrap gap-2" aria-label="Voxel Yard controls">
          <button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => mineRef.current()} disabled={!targetLabel}><Hammer size={14} />Mine</button>
          <button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => placeRef.current()} disabled={!targetLabel}><Box size={14} />Place</button>
          <button type="button" className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2" onClick={() => rotateRef.current()}><RotateCw size={14} />Rotate</button>
          <button
            type="button"
            className="game-control inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-2"
            onClick={() => {
              if (!confirmingReset) {
                setConfirmingReset(true);
                window.setTimeout(() => setConfirmingReset(false), 3000);
                return;
              }
              setConfirmingReset(false);
              newIslandRef.current();
            }}
          >
            <RefreshCw size={14} />{confirmingReset ? "Tap again to confirm" : "New island"}
          </button>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2" aria-label="Block palette" role="listbox">
        {HOTBAR.map((id, i) => (
          <button
            key={id}
            type="button"
            role="option"
            aria-selected={selected === id}
            className={`game-control flex items-center gap-1.5 rounded-full border px-3 py-2 text-xs font-semibold ${selected === id ? "border-[#6df0df] bg-[#6df0df] text-[#0a0f24]" : "border-[var(--border)]"}`}
            onClick={() => setSelected(id)}
          >
            <span className="inline-block h-3.5 w-3.5 rounded-sm border border-black/20" style={{ background: PALETTE[id].top ?? PALETTE[id].base }} />
            {PALETTE[id].name}
            <span className="opacity-60">{i + 1}</span>
          </button>
        ))}
      </div>

      <p className="text-xs text-[var(--muted)]">Tap a block face to target it, then use Mine or Place. Press 1–9 to pick a block, R to rotate the view, M to mine, and P to place. Your island saves automatically in this browser.</p>
    </section>
  );
}

export default VoxelYard;
