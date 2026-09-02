export type KidId = "apollo" | "rocco";

export const KIDS: Record<KidId, { label: string; accent: string; ink: string; file: string; prop: string }> = {
  apollo: { label: "Apollo", accent: "#ff7a2d", ink: "#1a140c", file: "games/kids/apollo.png", prop: "orange balloon" },
  rocco: { label: "Rocco", accent: "#ff5ea8", ink: "#1a140c", file: "games/kids/rocco.png", prop: "pink balloon" },
};

export function kidSrc(id: KidId, base = "/") {
  const root = base.endsWith("/") ? base : `${base}/`;
  return `${root}${KIDS[id].file}`.replace(/([^:]\/)\/+/g, "$1");
}

export function portraitReady(image: CanvasImageSource | HTMLImageElement | undefined) {
  return Boolean(image && "naturalWidth" in image && image.complete && image.naturalWidth > 0);
}

export function drawKidPortrait(
  ctx: CanvasRenderingContext2D,
  image: CanvasImageSource | undefined,
  x: number,
  y: number,
  size: number,
  opts?: { ring?: string; squash?: number; alpha?: number; tilt?: number },
) {
  const squash = opts?.squash ?? 1;
  const ready = portraitReady(image as HTMLImageElement | undefined);
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(opts?.tilt ?? 0);
  ctx.scale(1, squash);
  ctx.globalAlpha = opts?.alpha ?? 1;
  ctx.beginPath();
  ctx.arc(0, 0, size / 2, 0, Math.PI * 2);
  ctx.closePath();
  if (opts?.ring) {
    ctx.shadowColor = opts.ring;
    ctx.shadowBlur = Math.max(8, size * 0.12);
  }
  if (ready && image) {
    ctx.save();
    ctx.clip();
    ctx.drawImage(image, -size / 2, -size / 2, size, size);
    ctx.restore();
  } else {
    ctx.fillStyle = opts?.ring ?? "#ff7a2d";
    ctx.fill();
  }
  if (opts?.ring) {
    ctx.shadowBlur = 0;
    ctx.strokeStyle = opts.ring;
    ctx.lineWidth = Math.max(3, size * 0.055);
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
