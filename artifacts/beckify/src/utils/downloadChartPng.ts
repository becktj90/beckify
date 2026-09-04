/**
 * Export a chart panel (Recharts SVG or any container with an SVG child)
 * as a PNG download — no extra dependencies.
 */
export async function downloadElementAsPng(
  element: HTMLElement,
  fileName: string,
): Promise<void> {
  const svg = element.querySelector("svg");
  if (!svg) {
    throw new Error("No SVG chart found to export.");
  }

  const clone = svg.cloneNode(true) as SVGSVGElement;
  if (!clone.getAttribute("xmlns")) {
    clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
  }

  const bbox = svg.getBoundingClientRect();
  const width = Math.max(1, Math.round(bbox.width) || Number(svg.getAttribute("width")) || 720);
  const height = Math.max(1, Math.round(bbox.height) || Number(svg.getAttribute("height")) || 360);
  clone.setAttribute("width", String(width));
  clone.setAttribute("height", String(height));

  const xml = new XMLSerializer().serializeToString(clone);
  const blob = new Blob([xml], { type: "image/svg+xml;charset=utf-8" });
  const url = URL.createObjectURL(blob);

  try {
    const image = await loadImage(url);
    const canvas = document.createElement("canvas");
    const scale = Math.min(3, window.devicePixelRatio || 2);
    canvas.width = width * scale;
    canvas.height = height * scale;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("Canvas unavailable.");
    ctx.fillStyle = "#05060f";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.scale(scale, scale);
    ctx.drawImage(image, 0, 0, width, height);

    const png = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/png"));
    if (!png) throw new Error("PNG encode failed.");
    triggerDownload(png, fileName.endsWith(".png") ? fileName : `${fileName}.png`);
  } finally {
    URL.revokeObjectURL(url);
  }
}

function loadImage(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error("Failed to rasterize chart SVG."));
    image.src = url;
  });
}

function triggerDownload(blob: Blob, fileName: string) {
  const href = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = href;
  anchor.download = fileName;
  anchor.rel = "noopener";
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(href);
}
