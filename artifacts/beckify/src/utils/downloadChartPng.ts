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

  // Cloning drops inherited CSS custom properties (e.g. stroke="var(--color-magnitude)").
  // Copy variables onto the clone root, then bake computed fill/stroke onto painted nodes.
  copyCssVariablesOnto(clone, svg);
  bakePresentationAttributes(svg, clone);

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

/** Walk the live tree and copy `--*` custom properties onto the clone root. */
function copyCssVariablesOnto(clone: SVGSVGElement, liveSvg: SVGElement) {
  const seen = new Set<string>();
  let node: Element | null = liveSvg;
  while (node) {
    const cs = getComputedStyle(node);
    for (let i = 0; i < cs.length; i++) {
      const name = cs.item(i);
      if (!name.startsWith("--") || seen.has(name)) continue;
      seen.add(name);
      const value = cs.getPropertyValue(name).trim();
      if (value) clone.style.setProperty(name, value);
    }
    node = node.parentElement;
  }
}

/** Replace var()-based presentation with computed absolute colors on the clone. */
function bakePresentationAttributes(liveRoot: SVGElement, cloneRoot: SVGSVGElement) {
  const liveNodes = [liveRoot, ...Array.from(liveRoot.querySelectorAll<SVGElement>("*"))];
  const cloneNodes = [cloneRoot, ...Array.from(cloneRoot.querySelectorAll<SVGElement>("*"))];
  const count = Math.min(liveNodes.length, cloneNodes.length);
  for (let i = 0; i < count; i++) {
    const live = liveNodes[i];
    const cloned = cloneNodes[i];
    const cs = getComputedStyle(live);
    const fill = cs.fill;
    const stroke = cs.stroke;
    if (fill && fill !== "none" && fill !== "rgba(0, 0, 0, 0)") {
      cloned.setAttribute("fill", fill);
    }
    if (stroke && stroke !== "none" && stroke !== "rgba(0, 0, 0, 0)") {
      cloned.setAttribute("stroke", stroke);
    }
    const strokeWidth = cs.strokeWidth;
    if (strokeWidth) cloned.setAttribute("stroke-width", strokeWidth);
    const opacity = cs.opacity;
    if (opacity && opacity !== "1") cloned.setAttribute("opacity", opacity);
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
