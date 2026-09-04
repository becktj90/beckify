// Playable heroes are canvas/SVG cartoons. Family photos in
// public/games/kids/ are reserved for profile/avatar UI and must not be
// imported by game components.
export type HeroId = "blaze" | "spark";

export const HERO_IDS = ["blaze", "spark"] as const;

export const HEROES: Record<HeroId, {
  label: string;
  accent: string;
  ink: string;
  prop: string;
  skin: string;
  hair: string;
  shirt: string;
}> = {
  blaze: {
    label: "Blaze",
    accent: "#ff7a2d",
    ink: "#1a140c",
    prop: "orange balloon",
    skin: "#f3c39a",
    hair: "#5a3218",
    shirt: "#ff8a2b",
  },
  spark: {
    label: "Spark",
    accent: "#ff5ea8",
    ink: "#1a140c",
    prop: "pink balloon",
    skin: "#f6c4a8",
    hair: "#3d2416",
    shirt: "#ff6bab",
  },
};

export function cartoonHeroSrc(id: HeroId) {
  const hero = HEROES[id];
  const hair = id === "blaze"
    ? `<path d="M20 30c1-12 10-18 16-18 7 0 15 5 16 17-4-6-9-8-16-7-6 1-12 4-16 8z" fill="${hero.hair}"/>
       <path d="M33 12l3-6 3 6" fill="${hero.hair}"/>`
    : `<path d="M21 32c2-13 11-19 16-19 8 0 14 7 15 18-5-5-10-8-16-7-5 1-11 4-15 8z" fill="${hero.hair}"/>
       <circle cx="52" cy="20" r="4.2" fill="${hero.accent}"/>
       <circle cx="52" cy="20" r="1.6" fill="#fff6b8"/>`;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 72" width="72" height="72">
    <circle cx="36" cy="36" r="35" fill="#1a2438"/>
    <ellipse cx="54" cy="13" rx="7.5" ry="9.5" fill="${hero.accent}" transform="rotate(14 54 13)"/>
    <path d="M50 21Q43 32 39 42" fill="none" stroke="#1a140c" stroke-width="1.5" stroke-linecap="round"/>
    <path d="M18 64q2-18 18-20 16 2 18 20z" fill="${hero.shirt}"/>
    <circle cx="36" cy="32" r="15.5" fill="${hero.skin}"/>
    ${hair}
    <circle cx="30.5" cy="32.5" r="2.1" fill="#1a140c"/>
    <circle cx="41.5" cy="32.5" r="2.1" fill="#1a140c"/>
    <circle cx="31.2" cy="31.8" r="0.6" fill="#fff"/>
    <circle cx="42.2" cy="31.8" r="0.6" fill="#fff"/>
    <path d="M30 39q6 5 12 0" fill="none" stroke="#1a140c" stroke-width="1.7" stroke-linecap="round"/>
  </svg>`;
  return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
}

export function drawCartoonHero(
  ctx: CanvasRenderingContext2D,
  id: HeroId,
  x: number,
  y: number,
  size: number,
  opts?: { ring?: string; squash?: number; alpha?: number; tilt?: number; balloon?: boolean },
) {
  const hero = HEROES[id];
  const squash = opts?.squash ?? 1;
  const radius = size / 2;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(opts?.tilt ?? 0);
  ctx.scale(1, squash);
  ctx.globalAlpha = opts?.alpha ?? 1;

  ctx.beginPath();
  ctx.arc(0, 0, radius, 0, Math.PI * 2);
  ctx.closePath();
  if (opts?.ring) {
    ctx.shadowColor = opts.ring;
    ctx.shadowBlur = Math.max(8, size * 0.12);
  }
  ctx.fillStyle = "#1a2438";
  ctx.fill();
  ctx.shadowBlur = 0;
  ctx.save();
  ctx.clip();

  if (opts?.balloon !== false) {
    ctx.fillStyle = hero.accent;
    ctx.beginPath();
    ctx.ellipse(radius * 0.52, -radius * 0.64, radius * 0.2, radius * 0.26, 0.22, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(26,20,12,0.45)";
    ctx.lineWidth = Math.max(1, size * 0.02);
    ctx.beginPath();
    ctx.moveTo(radius * 0.4, -radius * 0.4);
    ctx.quadraticCurveTo(radius * 0.18, -radius * 0.08, radius * 0.08, radius * 0.18);
    ctx.stroke();
  }

  ctx.fillStyle = hero.shirt;
  ctx.beginPath();
  ctx.moveTo(-radius * 0.52, radius);
  ctx.quadraticCurveTo(-radius * 0.46, radius * 0.12, 0, radius * 0.18);
  ctx.quadraticCurveTo(radius * 0.46, radius * 0.12, radius * 0.52, radius);
  ctx.closePath();
  ctx.fill();

  ctx.fillStyle = hero.skin;
  ctx.beginPath();
  ctx.arc(0, -radius * 0.08, radius * 0.42, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = hero.hair;
  ctx.beginPath();
  if (id === "blaze") {
    ctx.ellipse(-radius * 0.02, -radius * 0.34, radius * 0.4, radius * 0.22, 0, Math.PI, 0);
    ctx.ellipse(-radius * 0.2, -radius * 0.42, radius * 0.16, radius * 0.16, -0.4, 0, Math.PI * 2);
    ctx.ellipse(radius * 0.16, -radius * 0.46, radius * 0.14, radius * 0.16, 0.25, 0, Math.PI * 2);
  } else {
    ctx.ellipse(0, -radius * 0.3, radius * 0.4, radius * 0.24, 0, Math.PI, 0.15);
    ctx.ellipse(radius * 0.22, -radius * 0.28, radius * 0.16, radius * 0.2, 0.4, 0, Math.PI * 2);
  }
  ctx.fill();

  if (id === "spark") {
    ctx.fillStyle = hero.accent;
    ctx.beginPath();
    ctx.arc(radius * 0.34, -radius * 0.42, radius * 0.09, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#fff6b8";
    ctx.beginPath();
    ctx.arc(radius * 0.34, -radius * 0.42, radius * 0.035, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.fillStyle = "#1a140c";
  ctx.beginPath();
  ctx.arc(-radius * 0.14, -radius * 0.06, Math.max(1.4, size * 0.028), 0, Math.PI * 2);
  ctx.arc(radius * 0.14, -radius * 0.06, Math.max(1.4, size * 0.028), 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#fff";
  ctx.beginPath();
  ctx.arc(-radius * 0.11, -radius * 0.085, Math.max(0.6, size * 0.01), 0, Math.PI * 2);
  ctx.arc(radius * 0.17, -radius * 0.085, Math.max(0.6, size * 0.01), 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = "#1a140c";
  ctx.lineWidth = Math.max(1.4, size * 0.024);
  ctx.lineCap = "round";
  ctx.beginPath();
  ctx.arc(0, radius * 0.02, radius * 0.16, 0.2, Math.PI - 0.2);
  ctx.stroke();

  ctx.restore();

  if (opts?.ring) {
    ctx.strokeStyle = opts.ring;
    ctx.lineWidth = Math.max(3, size * 0.055);
    ctx.beginPath();
    ctx.arc(0, 0, radius, 0, Math.PI * 2);
    ctx.stroke();
  }
  ctx.restore();
}

export function drawScooterBody(ctx: CanvasRenderingContext2D, accent: string, facing: 1 | -1, boosting: boolean) {
  ctx.save();
  ctx.scale(facing, 1);
  ctx.fillStyle = accent;
  ctx.strokeStyle = "#10182c";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.roundRect(-38, -6, 72, 14, 7);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = "#1b2438";
  ctx.beginPath();
  ctx.arc(-26, 12, 9, 0, Math.PI * 2);
  ctx.arc(24, 12, 9, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#eef6ff";
  ctx.beginPath();
  ctx.arc(-26, 12, 3.5, 0, Math.PI * 2);
  ctx.arc(24, 12, 3.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = accent;
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(18, -6);
  ctx.lineTo(28, -34);
  ctx.lineTo(42, -34);
  ctx.stroke();
  if (boosting) {
    ctx.fillStyle = "rgba(116, 245, 160, 0.85)";
    ctx.beginPath();
    ctx.ellipse(-52, 4, 18, 10, -0.2, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}
