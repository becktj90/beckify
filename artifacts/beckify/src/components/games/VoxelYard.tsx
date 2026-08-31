import { useEffect, useRef, useState } from "react";
import * as THREE from "three";
import { Maximize2, Minimize2, RefreshCw, Volume2, VolumeX } from "lucide-react";
import { useGameFullscreen } from "@/hooks/use-game-fullscreen";

// First-person WebGL voxel sandbox. Chunked storage, seeded terrain, and
// raycast mine/place follow the architecture of fogleman/Craft (MIT,
// https://github.com/fogleman/Craft). Original TypeScript + three.js — no
// Craft source, shaders, textures, or assets are reused.

const CHUNK = 16;
const MAX_Y = 48;
const SEA = 10;
const VIEW = 3;
const TILE = 16;
const ATLAS = 4;
const SAVE_KEY = "voxel-yard-save-v2";
const STATS_KEY = "voxel-yard-stats-v1";
const PLAYER_R = 0.28;
const PLAYER_H = 1.72;
const EYE = 1.58;

const BLOCK = { AIR: 0, GRASS: 1, DIRT: 2, STONE: 3, SAND: 4, SNOW: 5, WOOD: 6, LEAVES: 7, PLANK: 8, BRICK: 9, GLASS: 10 } as const;
type BlockId = (typeof BLOCK)[keyof typeof BLOCK];

const PALETTE: Record<number, { name: string; color: string; top?: number; side?: number; bottom?: number; tile: number; alpha?: boolean }> = {
  [BLOCK.GRASS]: { name: "Grass", color: "#5cc24b", tile: 0, top: 0, side: 1, bottom: 2 },
  [BLOCK.DIRT]: { name: "Dirt", color: "#7a5230", tile: 2 },
  [BLOCK.STONE]: { name: "Stone", color: "#8b8f97", tile: 3 },
  [BLOCK.SAND]: { name: "Sand", color: "#e8d391", tile: 4 },
  [BLOCK.SNOW]: { name: "Snow", color: "#eef4ff", tile: 5 },
  [BLOCK.WOOD]: { name: "Wood", color: "#6b4a2c", tile: 6, top: 11, side: 6 },
  [BLOCK.LEAVES]: { name: "Leaves", color: "#3f8f4d", tile: 7 },
  [BLOCK.PLANK]: { name: "Plank", color: "#caa25c", tile: 8 },
  [BLOCK.BRICK]: { name: "Brick", color: "#b1503f", tile: 9 },
  [BLOCK.GLASS]: { name: "Glass", color: "#bfe8ff", tile: 10, alpha: true },
};

const HOTBAR: BlockId[] = [BLOCK.GRASS, BLOCK.DIRT, BLOCK.STONE, BLOCK.SAND, BLOCK.SNOW, BLOCK.WOOD, BLOCK.PLANK, BLOCK.BRICK, BLOCK.GLASS];

const chunkOf = (n: number) => Math.floor(n / CHUNK);
const loc = (n: number) => ((n % CHUNK) + CHUNK) % CHUNK;
const ck = (cx: number, cz: number) => `${cx}:${cz}`;
const ek = (x: number, y: number, z: number) => `${x},${y},${z}`;
const inY = (y: number) => y >= 0 && y < MAX_Y;

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
  return h00 + xf * (h10 - h00) + zf * ((h01 + xf * (h11 - h01)) - (h00 + xf * (h10 - h00)));
}
function fbm2D(x: number, z: number, seed: number, octaves = 5) {
  let amp = 0.5, freq = 1, sum = 0, norm = 0;
  for (let i = 0; i < octaves; i++) { sum += noise2D(x * freq, z * freq, seed) * amp; norm += amp; amp *= 0.5; freq *= 2; }
  return sum / norm;
}
function noise3D(x: number, y: number, z: number, seed: number) {
  const x0 = Math.floor(x), y0 = Math.floor(y), z0 = Math.floor(z);
  const xf = fade(x - x0), yf = fade(y - y0), zf = fade(z - z0);
  const n = (ix: number, iy: number, iz: number) => hashLattice(ix, iy, iz, seed);
  const x00 = n(x0, y0, z0) + xf * (n(x0 + 1, y0, z0) - n(x0, y0, z0));
  const x10 = n(x0, y0 + 1, z0) + xf * (n(x0 + 1, y0 + 1, z0) - n(x0, y0 + 1, z0));
  const x01 = n(x0, y0, z0 + 1) + xf * (n(x0 + 1, y0, z0 + 1) - n(x0, y0, z0 + 1));
  const x11 = n(x0, y0 + 1, z0 + 1) + xf * (n(x0 + 1, y0 + 1, z0 + 1) - n(x0, y0 + 1, z0 + 1));
  const y0v = x00 + yf * (x10 - x00), y1v = x01 + yf * (x11 - x01);
  return y0v + zf * (y1v - y0v);
}

const loadStats = () => {
  try {
    const parsed = JSON.parse(localStorage.getItem(STATS_KEY) || "null");
    return { mined: Number(parsed?.mined) || 0, placed: Number(parsed?.placed) || 0 };
  } catch {
    return { mined: 0, placed: 0 };
  }
};

function makeAtlas() {
  const size = TILE * ATLAS;
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("atlas");
  const paint = (col: number, row: number, base: string, speck: string, count: number, extra?: (x: number, y: number) => void) => {
    const x = col * TILE, y = row * TILE;
    ctx.fillStyle = base;
    ctx.fillRect(x, y, TILE, TILE);
    ctx.fillStyle = speck;
    for (let i = 0; i < count; i++) ctx.fillRect(x + (i * 7 + col * 3) % TILE, y + (i * 13 + row * 5) % TILE, 1, 1);
    extra?.(x, y);
  };
  paint(0, 0, "#4fb83d", "#8be56a", 28);
  paint(1, 0, "#7a5230", "#5a3a20", 18, (x, y) => { ctx.fillStyle = "#4fb83d"; ctx.fillRect(x, y, TILE, 4); ctx.fillStyle = "#8be56a"; ctx.fillRect(x + 2, y + 1, 2, 2); });
  paint(2, 0, "#7a5230", "#4a3018", 22);
  paint(3, 0, "#8b8f97", "#c5c8ce", 26);
  paint(4, 0, "#e8d391", "#fff3c4", 20);
  paint(5, 0, "#eef4ff", "#ffffff", 12);
  paint(6, 0, "#6b4a2c", "#3d2918", 10, (x, y) => { ctx.fillStyle = "#4a3018"; ctx.fillRect(x + 6, y, 2, TILE); });
  paint(7, 0, "#2f7a3c", "#6dce62", 40, (x, y) => { ctx.clearRect(x + 3, y + 4, 2, 2); ctx.clearRect(x + 11, y + 9, 2, 2); });
  paint(0, 1, "#caa25c", "#8d6a2e", 14, (x, y) => { ctx.fillStyle = "#8d6a2e"; ctx.fillRect(x, y + 7, TILE, 1); });
  paint(1, 1, "#b1503f", "#7a2e22", 8, (x, y) => { ctx.fillStyle = "#d7c4b4"; ctx.fillRect(x, y + 7, TILE, 1); ctx.fillRect(x + 7, y, 1, 7); ctx.fillRect(x + 3, y + 8, 1, 8); });
  paint(2, 1, "#bfe8ff", "#ffffff", 10, (x, y) => { ctx.fillStyle = "rgba(255,255,255,0.35)"; ctx.fillRect(x + 2, y + 2, 5, 5); });
  paint(3, 1, "#6b4a2c", "#caa25c", 16, (x, y) => { ctx.strokeStyle = "#3d2918"; ctx.strokeRect(x + 1, y + 1, 14, 14); });
  const tex = new THREE.CanvasTexture(canvas);
  tex.magFilter = THREE.NearestFilter;
  tex.minFilter = THREE.NearestFilter;
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.needsUpdate = true;
  return tex;
}

function tileUV(tile: number) {
  const col = tile % ATLAS, row = Math.floor(tile / ATLAS);
  const pad = 0.003;
  const u0 = col / ATLAS + pad, u1 = (col + 1) / ATLAS - pad;
  const v1 = 1 - row / ATLAS - pad, v0 = 1 - (row + 1) / ATLAS + pad;
  return [u0, v0, u1, v0, u1, v1, u0, v1] as const;
}

const FACES: { dir: [number, number, number]; verts: [number, number, number][]; shade: number }[] = [
  { dir: [1, 0, 0], shade: 0.78, verts: [[1, 0, 0], [1, 0, 1], [1, 1, 1], [1, 1, 0]] },
  { dir: [-1, 0, 0], shade: 0.68, verts: [[0, 0, 1], [0, 0, 0], [0, 1, 0], [0, 1, 1]] },
  { dir: [0, 1, 0], shade: 1, verts: [[0, 1, 0], [1, 1, 0], [1, 1, 1], [0, 1, 1]] },
  { dir: [0, -1, 0], shade: 0.48, verts: [[0, 0, 1], [1, 0, 1], [1, 0, 0], [0, 0, 0]] },
  { dir: [0, 0, 1], shade: 0.84, verts: [[1, 0, 1], [0, 0, 1], [0, 1, 1], [1, 1, 1]] },
  { dir: [0, 0, -1], shade: 0.6, verts: [[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0]] },
];

export function VoxelYard() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const selectedRef = useRef<BlockId>(BLOCK.GRASS);
  const mutedRef = useRef(false);
  const flyingRef = useRef(false);
  const startedRef = useRef(false);

  const [selected, setSelected] = useState<BlockId>(BLOCK.GRASS);
  const [muted, setMuted] = useState(false);
  const [flying, setFlying] = useState(false);
  const [stats, setStats] = useState(loadStats);
  const [started, setStarted] = useState(false);
  const [confirmingReset, setConfirmingReset] = useState(false);
  const [hint, setHint] = useState("Click the world to look around");
  const { immersive, toggleFullscreen, exitFullscreen } = useGameFullscreen();

  useEffect(() => { mutedRef.current = muted; }, [muted]);
  useEffect(() => { selectedRef.current = selected; }, [selected]);
  useEffect(() => { flyingRef.current = flying; }, [flying]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const stage = stageRef.current;
    if (!canvas || !stage) return;

    const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: "high-performance" });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.08;
    renderer.setClearColor(0x87b8e8, 1);

    const scene = new THREE.Scene();
    scene.background = new THREE.Color("#7fb6ea");
    scene.fog = new THREE.Fog("#9fc7ee", 48, 110);

    const camera = new THREE.PerspectiveCamera(72, 1, 0.08, 220);
    camera.rotation.order = "YXZ";

    scene.add(new THREE.HemisphereLight(0xbddcff, 0x3d4a28, 1.15));
    const sun = new THREE.DirectionalLight(0xfff1c8, 1.35);
    sun.position.set(40, 80, 18);
    scene.add(sun);

    const water = new THREE.Mesh(
      new THREE.PlaneGeometry(400, 400),
      new THREE.MeshLambertMaterial({ color: 0x1b6fa8, transparent: true, opacity: 0.42, depthWrite: false }),
    );
    water.rotation.x = -Math.PI / 2;
    water.position.y = SEA + 0.28;
    scene.add(water);

    const atlas = makeAtlas();
    const matOpaque = new THREE.MeshLambertMaterial({ map: atlas, vertexColors: true, alphaTest: 0.15 });
    const matGlass = new THREE.MeshLambertMaterial({ map: atlas, vertexColors: true, transparent: true, opacity: 0.55, depthWrite: false });

    const chunks = new Map<string, Uint8Array>();
    const meshes = new Map<string, { solid: THREE.Mesh; glass: THREE.Mesh }>();
    const edits = new Map<string, number>();
    let seed = Math.floor(Math.random() * 1e9);
    const player = { x: 0.5, y: 20, z: 0.5, vx: 0, vy: 0, vz: 0, yaw: 0.4, pitch: -0.18, grounded: false };
    let persistTimer = 0;
    let hadPosition = false;

    try {
      const parsed = JSON.parse(localStorage.getItem(SAVE_KEY) || "null");
      if (parsed?.seed) seed = Number(parsed.seed) || seed;
      if (Array.isArray(parsed?.edits)) {
        for (let i = 0; i + 3 < parsed.edits.length; i += 4) edits.set(ek(parsed.edits[i], parsed.edits[i + 1], parsed.edits[i + 2]), parsed.edits[i + 3]);
      }
      if (Number.isFinite(parsed?.x) && Number.isFinite(parsed?.y)) {
        player.x = parsed.x; player.y = parsed.y; player.z = parsed.z;
        player.yaw = parsed.yaw || 0; player.pitch = parsed.pitch || 0;
        hadPosition = true;
      }
    } catch { /* optional */ }

    const persist = () => {
      const packed: number[] = [];
      edits.forEach((id, key) => { const [x, y, z] = key.split(",").map(Number); packed.push(x, y, z, id); });
      try {
        localStorage.setItem(SAVE_KEY, JSON.stringify({ seed, edits: packed, x: player.x, y: player.y, z: player.z, yaw: player.yaw, pitch: player.pitch }));
      } catch { /* optional */ }
    };

    const idx = (x: number, y: number, z: number) => loc(x) + loc(z) * CHUNK + y * CHUNK * CHUNK;
    const get = (x: number, y: number, z: number) => {
      if (!inY(y)) return BLOCK.AIR;
      const data = chunks.get(ck(chunkOf(x), chunkOf(z)));
      return data ? data[idx(x, y, z)] : BLOCK.AIR;
    };
    const solid = (x: number, y: number, z: number) => get(Math.floor(x), Math.floor(y), Math.floor(z)) !== BLOCK.AIR;

    const generateChunk = (cx: number, cz: number) => {
      const data = new Uint8Array(CHUNK * MAX_Y * CHUNK);
      const setLocal = (x: number, y: number, z: number, id: number) => {
        if (!inY(y) || chunkOf(x) !== cx || chunkOf(z) !== cz) return;
        data[idx(x, y, z)] = id;
      };
      for (let lx = 0; lx < CHUNK; lx++) {
        for (let lz = 0; lz < CHUNK; lz++) {
          const x = cx * CHUNK + lx, z = cz * CHUNK + lz;
          const continent = fbm2D(x * 0.01, z * 0.01, seed);
          const ridge = fbm2D(x * 0.04, z * 0.04, seed + 99);
          let h = Math.floor(SEA - 4 + continent * 22 + ridge * 6);
          h = Math.max(2, Math.min(MAX_Y - 6, h));
          const beach = h <= SEA + 1;
          for (let y = 0; y < h; y++) {
            if (y > 1 && y < h - 2 && noise3D(x * 0.12, y * 0.16, z * 0.12, seed + 4242) > 0.72) continue;
            let id: number = BLOCK.STONE;
            if (y === h - 1) id = beach ? BLOCK.SAND : h >= SEA + 14 ? BLOCK.SNOW : BLOCK.GRASS;
            else if (y >= h - 4) id = beach ? BLOCK.SAND : BLOCK.DIRT;
            data[idx(x, y, z)] = id;
          }
          const tree = !beach && h < MAX_Y - 8 && h > SEA + 2 && hashLattice(x * 3, 0, z * 7, seed + 909) < 0.028;
          if (tree) {
            for (let t = 0; t < 4; t++) setLocal(x, h + t, z, BLOCK.WOOD);
            for (let dy = 2; dy <= 5; dy++) {
              const spread = dy === 5 ? 0 : dy === 2 ? 2 : 1;
              for (let dx = -spread; dx <= spread; dx++) {
                for (let dz = -spread; dz <= spread; dz++) {
                  if (dx === 0 && dz === 0 && dy < 4) continue;
                  setLocal(x + dx, h + dy, z + dz, BLOCK.LEAVES);
                }
              }
            }
          }
        }
      }
      edits.forEach((id, key) => {
        const [x, y, z] = key.split(",").map(Number);
        if (chunkOf(x) === cx && chunkOf(z) === cz && inY(y)) data[idx(x, y, z)] = id;
      });
      chunks.set(ck(cx, cz), data);
    };

    const meshChunk = (cx: number, cz: number) => {
      const data = chunks.get(ck(cx, cz));
      if (!data) return;
      const pos: number[] = [], norm: number[] = [], uv: number[] = [], col: number[] = [], idxA: number[] = [];
      const gPos: number[] = [], gNorm: number[] = [], gUv: number[] = [], gCol: number[] = [], gIdx: number[] = [];
      const pushFace = (lists: { p: number[]; n: number[]; u: number[]; c: number[]; i: number[] }, x: number, y: number, z: number, face: typeof FACES[number], tile: number, id: number) => {
        const base = lists.p.length / 3;
        const uvs = tileUV(tile);
        const tint = id === BLOCK.GRASS && face.dir[1] === 1 ? 1.08 : 1;
        for (let v = 0; v < 4; v++) {
          const [vx, vy, vz] = face.verts[v];
          lists.p.push(x + vx, y + vy, z + vz);
          lists.n.push(face.dir[0], face.dir[1], face.dir[2]);
          lists.u.push(uvs[v * 2], uvs[v * 2 + 1]);
          const shade = face.shade * tint;
          lists.c.push(shade, shade, shade);
        }
        lists.i.push(base, base + 1, base + 2, base, base + 2, base + 3);
      };
      for (let lx = 0; lx < CHUNK; lx++) {
        for (let lz = 0; lz < CHUNK; lz++) {
          for (let y = 0; y < MAX_Y; y++) {
            const x = cx * CHUNK + lx, z = cz * CHUNK + lz;
            const id = data[idx(x, y, z)];
            if (id === BLOCK.AIR) continue;
            const def = PALETTE[id];
            if (!def) continue;
            const lists = def.alpha ? { p: gPos, n: gNorm, u: gUv, c: gCol, i: gIdx } : { p: pos, n: norm, u: uv, c: col, i: idxA };
            for (const face of FACES) {
              const nx = x + face.dir[0], ny = y + face.dir[1], nz = z + face.dir[2];
              const nid = get(nx, ny, nz);
              const neighborOpaque = nid !== BLOCK.AIR && nid !== BLOCK.GLASS;
              if (neighborOpaque) continue;
              if (def.alpha && nid === id) continue;
              const tile = face.dir[1] === 1 ? def.top ?? def.tile : face.dir[1] === -1 ? def.bottom ?? def.tile : def.side ?? def.tile;
              pushFace(lists, x, y, z, face, tile, id);
            }
          }
        }
      }
      const prev = meshes.get(ck(cx, cz));
      if (prev) { scene.remove(prev.solid, prev.glass); prev.solid.geometry.dispose(); prev.glass.geometry.dispose(); }
      const build = (p: number[], n: number[], u: number[], c: number[], i: number[], material: THREE.Material) => {
        const geo = new THREE.BufferGeometry();
        if (p.length) {
          geo.setAttribute("position", new THREE.Float32BufferAttribute(p, 3));
          geo.setAttribute("normal", new THREE.Float32BufferAttribute(n, 3));
          geo.setAttribute("uv", new THREE.Float32BufferAttribute(u, 2));
          geo.setAttribute("color", new THREE.Float32BufferAttribute(c, 3));
          geo.setIndex(i);
        }
        const mesh = new THREE.Mesh(geo, material);
        mesh.frustumCulled = false;
        scene.add(mesh);
        return mesh;
      };
      meshes.set(ck(cx, cz), { solid: build(pos, norm, uv, col, idxA, matOpaque), glass: build(gPos, gNorm, gUv, gCol, gIdx, matGlass) });
    };

    const dirty = new Set<string>();
    const mark = (x: number, y: number, z: number) => {
      dirty.add(ck(chunkOf(x), chunkOf(z)));
      if (loc(x) === 0) dirty.add(ck(chunkOf(x) - 1, chunkOf(z)));
      if (loc(x) === CHUNK - 1) dirty.add(ck(chunkOf(x) + 1, chunkOf(z)));
      if (loc(z) === 0) dirty.add(ck(chunkOf(x), chunkOf(z) - 1));
      if (loc(z) === CHUNK - 1) dirty.add(ck(chunkOf(x), chunkOf(z) + 1));
    };
    const setBlock = (x: number, y: number, z: number, id: number) => {
      if (!inY(y)) return;
      const key = ck(chunkOf(x), chunkOf(z));
      if (!chunks.has(key)) generateChunk(chunkOf(x), chunkOf(z));
      const data = chunks.get(key);
      if (!data) return;
      data[idx(x, y, z)] = id;
      edits.set(ek(x, y, z), id);
      mark(x, y, z);
    };

    const wanted: string[] = [];
    const syncChunks = (force = false) => {
      const pcx = chunkOf(player.x), pcz = chunkOf(player.z);
      wanted.length = 0;
      for (let dz = -VIEW; dz <= VIEW; dz++) {
        for (let dx = -VIEW; dx <= VIEW; dx++) wanted.push(ck(pcx + dx, pcz + dz));
      }
      wanted.sort((a, b) => {
        const [ax, az] = a.split(":").map(Number), [bx, bz] = b.split(":").map(Number);
        return (ax - pcx) ** 2 + (az - pcz) ** 2 - ((bx - pcx) ** 2 + (bz - pcz) ** 2);
      });
      let built = 0;
      for (const key of wanted) {
        if (!chunks.has(key)) {
          const [cx, cz] = key.split(":").map(Number);
          generateChunk(cx, cz);
          meshChunk(cx, cz);
          for (const neighbor of [ck(cx - 1, cz), ck(cx + 1, cz), ck(cx, cz - 1), ck(cx, cz + 1)]) {
            if (meshes.has(neighbor)) {
              const [nx, nz] = neighbor.split(":").map(Number);
              meshChunk(nx, nz);
            }
          }
          built++;
          if (!force && built >= 2) break;
        } else if (!meshes.has(key)) {
          const [cx, cz] = key.split(":").map(Number);
          meshChunk(cx, cz);
          built++;
          if (!force && built >= 2) break;
        }
      }
      meshes.forEach((mesh, key) => {
        if (!wanted.includes(key)) {
          scene.remove(mesh.solid, mesh.glass);
          mesh.solid.geometry.dispose();
          mesh.glass.geometry.dispose();
          meshes.delete(key);
        }
      });
    };

    const highest = (x: number, z: number) => {
      for (let y = MAX_Y - 1; y >= 0; y--) if (get(Math.floor(x), y, Math.floor(z)) !== BLOCK.AIR) return y + 1;
      return SEA + 4;
    };
    syncChunks(true);
    if (!hadPosition) player.y = highest(player.x, player.z) + 0.01;

    const highlight = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(1.01, 1.01, 1.01)), new THREE.LineBasicMaterial({ color: 0xffd65a }));
    highlight.visible = false;
    scene.add(highlight);

    const keys = new Set<string>();
    const lookDrag = { active: false, lx: 0, ly: 0 };
    const coarse = window.matchMedia("(pointer: coarse)").matches;
    let stickX = 0, stickZ = 0;

    const blocked = (px: number, py: number, pz: number) => {
      const minX = Math.floor(px - PLAYER_R), maxX = Math.floor(px + PLAYER_R);
      const minY = Math.floor(py), maxY = Math.floor(py + PLAYER_H - 0.01);
      const minZ = Math.floor(pz - PLAYER_R), maxZ = Math.floor(pz + PLAYER_R);
      for (let y = minY; y <= maxY; y++) for (let x = minX; x <= maxX; x++) for (let z = minZ; z <= maxZ; z++) if (solid(x, y, z)) return true;
      return false;
    };

    const raycast = () => {
      const dir = new THREE.Vector3(0, 0, -1).applyEuler(camera.rotation);
      let x = Math.floor(camera.position.x), y = Math.floor(camera.position.y), z = Math.floor(camera.position.z);
      const stepX = dir.x > 0 ? 1 : -1, stepY = dir.y > 0 ? 1 : -1, stepZ = dir.z > 0 ? 1 : -1;
      const tDeltaX = Math.abs(1 / (dir.x || 1e-8)), tDeltaY = Math.abs(1 / (dir.y || 1e-8)), tDeltaZ = Math.abs(1 / (dir.z || 1e-8));
      let tMaxX = ((stepX > 0 ? x + 1 - camera.position.x : camera.position.x - x) * tDeltaX);
      let tMaxY = ((stepY > 0 ? y + 1 - camera.position.y : camera.position.y - y) * tDeltaY);
      let tMaxZ = ((stepZ > 0 ? z + 1 - camera.position.z : camera.position.z - z) * tDeltaZ);
      let px = x, py = y, pz = z;
      for (let i = 0; i < 48; i++) {
        if (inY(y) && get(x, y, z) !== BLOCK.AIR) return { x, y, z, px, py, pz, id: get(x, y, z) };
        px = x; py = y; pz = z;
        if (tMaxX < tMaxY && tMaxX < tMaxZ) { x += stepX; if (tMaxX > 8) break; tMaxX += tDeltaX; }
        else if (tMaxY < tMaxZ) { y += stepY; if (tMaxY > 8) break; tMaxY += tDeltaY; }
        else { z += stepZ; if (tMaxZ > 8) break; tMaxZ += tDeltaZ; }
      }
      return null;
    };

    let audio: AudioContext | undefined;
    const tone = (freq: number, len: number, type: OscillatorType, volume = 0.04) => {
      if (mutedRef.current) return;
      try {
        audio ??= new AudioContext();
        const osc = audio.createOscillator(), gain = audio.createGain();
        osc.type = type; osc.frequency.setValueAtTime(freq, audio.currentTime);
        gain.gain.setValueAtTime(volume, audio.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audio.currentTime + len);
        osc.connect(gain).connect(audio.destination); osc.start(); osc.stop(audio.currentTime + len);
      } catch { /* optional */ }
    };

    const bump = (kind: "mined" | "placed") => {
      setStats((current) => {
        const next = { ...current, [kind]: current[kind] + 1 };
        try { localStorage.setItem(STATS_KEY, JSON.stringify(next)); } catch { /* optional */ }
        return next;
      });
    };

    const mine = () => {
      const hit = raycast();
      if (!hit || hit.y <= 0) return;
      setBlock(hit.x, hit.y, hit.z, BLOCK.AIR);
      tone(90, 0.14, "sawtooth", 0.05); bump("mined"); persistTimer = 0.4;
    };
    const place = () => {
      const hit = raycast();
      if (!hit) return;
      const { px, py, pz } = hit;
      if (!inY(py) || get(px, py, pz) !== BLOCK.AIR) return;
      if (Math.abs(px + 0.5 - player.x) < PLAYER_R + 0.35 && py < player.y + PLAYER_H && py + 1 > player.y && Math.abs(pz + 0.5 - player.z) < PLAYER_R + 0.35) return;
      setBlock(px, py, pz, selectedRef.current);
      tone(340, 0.08, "square", 0.04); bump("placed"); persistTimer = 0.4;
    };

    const resize = () => {
      const w = stage.clientWidth || 800, h = stage.clientHeight || 480;
      renderer.setSize(w, h, false);
      camera.aspect = w / Math.max(1, h);
      camera.updateProjectionMatrix();
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(stage);

    const applyLook = (dx: number, dy: number) => {
      player.yaw -= dx * 0.0022;
      player.pitch = Math.max(-1.4, Math.min(1.4, player.pitch - dy * 0.0022));
    };

    const enter = async () => {
      startedRef.current = true;
      setStarted(true);
      if (!coarse) {
        try { await canvas.requestPointerLock(); } catch { /* iPad / denied */ }
      }
      audio?.resume().catch(() => {});
    };

    const pointerDown = (event: PointerEvent) => {
      event.preventDefault();
      if (!startedRef.current) { void enter(); return; }
      if (coarse) {
        lookDrag.active = true; lookDrag.lx = event.clientX; lookDrag.ly = event.clientY;
        canvas.setPointerCapture(event.pointerId);
        return;
      }
      if (event.button === 2) { place(); return; }
      if (event.button === 0) mine();
      if (document.pointerLockElement !== canvas) {
        lookDrag.active = true; lookDrag.lx = event.clientX; lookDrag.ly = event.clientY;
        canvas.setPointerCapture(event.pointerId);
      }
    };
    const pointerMove = (event: PointerEvent) => {
      if (document.pointerLockElement === canvas) {
        applyLook(event.movementX, event.movementY);
        return;
      }
      if (!lookDrag.active) return;
      applyLook(event.clientX - lookDrag.lx, event.clientY - lookDrag.ly);
      lookDrag.lx = event.clientX; lookDrag.ly = event.clientY;
    };
    const pointerUp = () => { lookDrag.active = false; };
    const contextMenu = (event: MouseEvent) => event.preventDefault();

    const keyDown = (event: KeyboardEvent) => {
      if (event.repeat && event.key.length === 1 && event.key >= "1" && event.key <= "9") return;
      const digit = Number(event.key);
      if (digit >= 1 && digit <= HOTBAR.length) { setSelected(HOTBAR[digit - 1]); return; }
      if (event.code === "Tab") { event.preventDefault(); setFlying((v) => !v); return; }
      if (event.code === "Escape" && document.pointerLockElement) document.exitPointerLock();
      keys.add(event.code);
    };
    const keyUp = (event: KeyboardEvent) => { keys.delete(event.code); };

    const stickEl = stage.querySelector("[data-stick]") as HTMLElement | null;
    const onStick = (event: PointerEvent) => {
      if (!stickEl) return;
      const rect = stickEl.getBoundingClientRect();
      const dx = (event.clientX - (rect.left + rect.width / 2)) / (rect.width / 2);
      const dy = (event.clientY - (rect.top + rect.height / 2)) / (rect.height / 2);
      stickX = Math.max(-1, Math.min(1, dx));
      stickZ = Math.max(-1, Math.min(1, dy));
    };
    const stickEnd = () => { stickX = 0; stickZ = 0; };
    stickEl?.addEventListener("pointerdown", (e) => { (e.target as HTMLElement).setPointerCapture((e as PointerEvent).pointerId); onStick(e as PointerEvent); });
    stickEl?.addEventListener("pointermove", (e) => { if (stickX || stickZ || (e as PointerEvent).buttons) onStick(e as PointerEvent); });
    stickEl?.addEventListener("pointerup", stickEnd);
    stickEl?.addEventListener("pointercancel", stickEnd);

    let last = performance.now(), raf = 0;
    const tick = (now: number) => {
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      dirty.forEach((key) => { const [cx, cz] = key.split(":").map(Number); meshChunk(cx, cz); });
      dirty.clear();
      syncChunks();

      const sprint = keys.has("ShiftLeft") || keys.has("ShiftRight");
      const speed = flyingRef.current ? 11 : sprint ? 7.2 : 4.4;
      let ix = (keys.has("KeyD") ? 1 : 0) - (keys.has("KeyA") ? 1 : 0) + stickX;
      let iz = (keys.has("KeyS") ? 1 : 0) - (keys.has("KeyW") ? 1 : 0) + stickZ;
      const len = Math.hypot(ix, iz) || 1;
      ix /= len; iz /= len;
      const sin = Math.sin(player.yaw), cos = Math.cos(player.yaw);
      const wishX = ix * cos + iz * sin;
      const wishZ = -ix * sin + iz * cos;
      player.vx = wishX * speed;
      player.vz = wishZ * speed;
      if (flyingRef.current) {
        player.vy = ((keys.has("Space") ? 1 : 0) - (sprint ? 1 : 0)) * speed;
      } else {
        player.vy -= 28 * dt;
        if (player.grounded && keys.has("Space")) player.vy = 8.6;
      }

      const nx = player.x + player.vx * dt;
      if (!blocked(nx, player.y, player.z)) player.x = nx; else player.vx = 0;
      const nz = player.z + player.vz * dt;
      if (!blocked(player.x, player.y, nz)) player.z = nz; else player.vz = 0;
      const ny = player.y + player.vy * dt;
      if (!blocked(player.x, ny, player.z)) {
        player.y = ny; player.grounded = false;
      } else {
        if (player.vy < 0) player.grounded = true;
        player.vy = 0;
      }
      if (player.y < 1.1) { player.y = highest(player.x, player.z) + 0.05; player.vy = 0; }

      camera.position.set(player.x, player.y + EYE, player.z);
      camera.rotation.set(player.pitch, player.yaw, 0);

      const under = camera.position.y < SEA + 0.2;
      const fog = scene.fog as THREE.Fog;
      fog.color.set(under ? "#0a3355" : "#9fc7ee");
      scene.background = new THREE.Color(under ? "#08243c" : "#7fb6ea");
      fog.near = under ? 4 : 48;
      fog.far = under ? 28 : 110;

      const hit = raycast();
      let nextHint = flyingRef.current ? "Flying · Tab to walk" : "WASD move · click mine · right-click place";
      if (hit) {
        highlight.visible = true;
        highlight.position.set(hit.x + 0.5, hit.y + 0.5, hit.z + 0.5);
        nextHint = `${PALETTE[hit.id]?.name ?? "Block"}  (${hit.x}, ${hit.y}, ${hit.z})`;
      } else {
        highlight.visible = false;
      }
      setHint((current) => current === nextHint ? current : nextHint);

      persistTimer -= dt;
      if (persistTimer < 0) { persistTimer = 8; persist(); }
      renderer.render(scene, camera);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);

    canvas.addEventListener("pointerdown", pointerDown);
    canvas.addEventListener("pointermove", pointerMove);
    canvas.addEventListener("pointerup", pointerUp);
    canvas.addEventListener("pointercancel", pointerUp);
    canvas.addEventListener("contextmenu", contextMenu);
    window.addEventListener("keydown", keyDown);
    window.addEventListener("keyup", keyUp);

    const resetWorld = () => {
      seed = Math.floor(Math.random() * 1e9);
      edits.clear();
      chunks.clear();
      meshes.forEach((mesh) => { scene.remove(mesh.solid, mesh.glass); mesh.solid.geometry.dispose(); mesh.glass.geometry.dispose(); });
      meshes.clear();
      player.x = 0.5; player.z = 0.5; player.vx = player.vy = player.vz = 0;
      syncChunks(true);
      player.y = highest(player.x, player.z) + 0.05;
      persist();
      tone(220, 0.2, "triangle", 0.05);
    };
    (stage as HTMLElement & { __reset?: () => void; __enter?: () => void; __mine?: () => void; __place?: () => void }).__reset = resetWorld;
    (stage as HTMLElement & { __reset?: () => void; __enter?: () => void; __mine?: () => void; __place?: () => void }).__enter = enter;
    (stage as HTMLElement & { __reset?: () => void; __enter?: () => void; __mine?: () => void; __place?: () => void }).__mine = mine;
    (stage as HTMLElement & { __reset?: () => void; __enter?: () => void; __mine?: () => void; __place?: () => void }).__place = place;

    return () => {
      persist();
      cancelAnimationFrame(raf);
      ro.disconnect();
      canvas.removeEventListener("pointerdown", pointerDown);
      canvas.removeEventListener("pointermove", pointerMove);
      canvas.removeEventListener("pointerup", pointerUp);
      canvas.removeEventListener("pointercancel", pointerUp);
      canvas.removeEventListener("contextmenu", contextMenu);
      window.removeEventListener("keydown", keyDown);
      window.removeEventListener("keyup", keyUp);
      stickEl?.removeEventListener("pointerup", stickEnd);
      meshes.forEach((mesh) => { scene.remove(mesh.solid, mesh.glass); mesh.solid.geometry.dispose(); mesh.glass.geometry.dispose(); });
      matOpaque.dispose(); matGlass.dispose(); atlas.dispose();
      renderer.dispose();
      audio?.close().catch(() => {});
      if (document.pointerLockElement === canvas) document.exitPointerLock();
    };
  }, []);

  return (
    <section className="space-y-6" aria-labelledby="voxel-yard-title">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--accent)]">Sandbox / First-person voxel world</p>
          <h1 id="voxel-yard-title" className="font-display text-3xl font-bold tracking-tight">Voxel Yard</h1>
          <p className="mt-2 max-w-2xl text-sm text-[var(--muted)]">A WebGL first-person sandbox: walk an endless seeded continent, mine and place blocks, fly, and keep your world in this browser. Built for pointer lock on desktop and drag-look on iPad.</p>
        </div>
        <div className="flex items-center gap-3 text-xs text-[var(--muted)]">
          <span>MINED {stats.mined} · PLACED {stats.placed}{flying ? " · FLY" : ""}</span>
          <button type="button" className="game-icon-button rounded-md border border-[var(--border)] p-2" onClick={() => setMuted((v) => !v)} aria-label={muted ? "Enable game sounds" : "Mute game sounds"}>{muted ? <VolumeX size={16} /> : <Volume2 size={16} />}</button>
          <button type="button" className="game-icon-button rounded-md border border-[var(--border)] p-2" onClick={() => toggleFullscreen(stageRef.current)} aria-label={immersive ? "Exit fullscreen" : "Play fullscreen"}>{immersive ? <Minimize2 size={16} /> : <Maximize2 size={16} />}</button>
        </div>
      </div>

      <div ref={stageRef} className={`game-stage relative mx-auto overflow-hidden bg-[#7fb6ea] shadow-[0_20px_60px_rgba(0,0,0,.35)] ${immersive ? "fixed inset-0 z-[70] rounded-none border-0" : "aspect-[16/10] min-h-[420px] max-w-[960px] rounded-2xl border border-[#2e5d86]"}`}>
        <canvas ref={canvasRef} className="block h-full w-full touch-none" aria-label="Voxel Yard first-person voxel world" />
        <div className="pointer-events-none absolute left-1/2 top-1/2 z-10 h-4 w-4 -translate-x-1/2 -translate-y-1/2">
          <span className="absolute left-1/2 top-0 h-4 w-px -translate-x-1/2 bg-white/90" />
          <span className="absolute left-0 top-1/2 h-px w-4 -translate-y-1/2 bg-white/90" />
        </div>
        <p className="pointer-events-none absolute left-3 top-3 rounded-md bg-black/35 px-2 py-1 text-[11px] tracking-wide text-white/90">{hint}</p>
        {immersive ? <button type="button" className="absolute right-4 top-4 z-10 rounded-full border border-white/30 bg-[#0a0f24]/90 p-3 text-white shadow-lg" onClick={exitFullscreen} aria-label="Exit fullscreen"><Minimize2 size={18} /></button> : null}
        <div data-stick className="absolute bottom-4 left-4 z-10 h-24 w-24 rounded-full border border-white/30 bg-black/25 md:hidden" aria-label="Move" />
        <div className="absolute bottom-4 right-4 z-10 flex gap-2 md:hidden">
          <button type="button" className="rounded-full border border-white/30 bg-black/45 px-4 py-3 text-xs font-semibold uppercase tracking-wide text-white" onClick={() => (stageRef.current as HTMLElement & { __mine?: () => void })?.__mine?.()}>Mine</button>
          <button type="button" className="rounded-full border border-white/30 bg-[#6df0df]/90 px-4 py-3 text-xs font-semibold uppercase tracking-wide text-[#0a0f24]" onClick={() => (stageRef.current as HTMLElement & { __place?: () => void })?.__place?.()}>Place</button>
        </div>
        {!started ? (
          <div className="pointer-events-none absolute inset-0 z-20 flex items-center justify-center bg-[#08203a]/55 p-6 text-center backdrop-blur-[2px]">
            <div className="max-w-sm">
              <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#6df0df]">WebGL world</p>
              <h2 className="mt-2 font-display text-2xl font-bold text-white">Enter the island</h2>
              <p className="mt-3 text-sm leading-6 text-[#b9c8dc]">Click to capture the mouse. WASD to walk, Space to jump, Tab to fly, left click mine, right click place.</p>
              <button type="button" className="game-control pointer-events-auto mt-5 inline-flex items-center gap-2 rounded-lg bg-[#6df0df] px-5 py-3 text-sm font-semibold text-[#0a0f24]" onClick={() => void (stageRef.current as HTMLElement & { __enter?: () => void })?.__enter?.()}>Play</button>
            </div>
          </div>
        ) : null}
      </div>

      <div className="game-command-bar flex flex-wrap items-center justify-between gap-3 text-xs text-[var(--muted)]">
        <span aria-live="polite">{hint}</span>
        <div className="flex flex-wrap gap-2">
          <button type="button" className="game-control rounded-md border border-[var(--border)] px-3 py-2" onClick={() => setFlying((v) => !v)}>{flying ? "Walk" : "Fly"}</button>
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
              (stageRef.current as HTMLElement & { __reset?: () => void } | null)?.__reset?.();
            }}
          >
            <RefreshCw size={14} />{confirmingReset ? "Tap again to confirm" : "New world"}
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
            <span className="inline-block h-3.5 w-3.5 rounded-sm border border-black/20" style={{ background: PALETTE[id].color }} />
            {PALETTE[id].name}
            <span className="opacity-60">{i + 1}</span>
          </button>
        ))}
      </div>
      <p className="text-xs text-[var(--muted)]">WASD walk, Shift sprint, Space jump, Tab fly, 1–9 hotbar, left click mine, right click place. Your world autosaves in this browser.</p>
    </section>
  );
}

export default VoxelYard;
