// Helpers for tinting Lottie animations with brand primary color.

// Convert hex/rgb color string to Lottie 0-1 float RGB.
export const toLottieRgb = (
  raw?: string | null,
): [number, number, number] | null => {
  if (!raw) return null;
  const c = raw.trim();
  if (c.startsWith("#")) {
    let hex = c.slice(1);
    if (hex.length === 3) hex = hex.split("").map((h) => h + h).join("");
    if (hex.length !== 6) return null;
    const n = parseInt(hex, 16);
    return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
  }
  const m = c.match(/rgba?\(([^)]+)\)/i);
  if (m) {
    const [r, g, b] = m[1].split(",").map((v) => parseFloat(v));
    return [r / 255, g / 255, b / 255];
  }
  return null;
};

// Read live --primary-color CSS variable as Lottie RGB (client-only).
export const getPrimaryLottieRgb = (): [number, number, number] | null => {
  if (typeof window === "undefined") return null;
  const primary = getComputedStyle(document.documentElement)
    .getPropertyValue("--primary-color")
    .trim();
  return toLottieRgb(primary);
};

const isBlack = (c?: number[] | null): boolean =>
  !!c && c[0] <= 0.05 && c[1] <= 0.05 && c[2] <= 0.05;
const isWhite = (c?: number[] | null): boolean =>
  !!c && c[0] >= 0.95 && c[1] >= 0.95 && c[2] >= 0.95;
// Check if color is near-greyscale neutral.
const isNeutral = (c?: number[] | null): boolean => {
  if (!Array.isArray(c) || c.length < 3) return false;
  const [r, g, b] = c;
  return Math.max(r, g, b) - Math.min(r, g, b) <= 0.08;
};

/** Deep-clone Lottie animation JSON and recolor stroke/fill shapes. */
export const recolorAnimation = (
  data: any,
  rgb: [number, number, number] | null | undefined,
  mode: "black" | "all" | "accent" = "black",
): any => {
  if (!rgb || !data) return data;
  const shouldPaint = (c?: number[] | null): boolean =>
    mode === "accent"
      ? !isNeutral(c)
      : mode === "all"
        ? !isWhite(c)
        : isBlack(c);

  const walk = (node: any): void => {
    if (Array.isArray(node)) return node.forEach(walk);
    if (node && typeof node === "object") {
      if ((node.ty === "st" || node.ty === "fl") && Array.isArray(node.c?.k)) {
        if (shouldPaint(node.c.k)) {
          const a = node.c.k[3];
          node.c.k = a != null ? [...rgb, a] : [...rgb];
        }
      }
      Object.values(node).forEach(walk);
    }
  };

  const clone = JSON.parse(JSON.stringify(data));
  walk(clone.layers);
  return clone;
};

