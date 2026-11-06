export const extractJSONFromMarkup = (markupString: string): any => {
    // [\s\S] stands in for the /s (dotAll) flag, which the compile target predates.
    const jsonRegex = /<script type="application\/ld\+json">([\s\S]*?)<\/script>/;
    const match = markupString.match(jsonRegex);
    if (match && match.length >= 2) {
        const extractedJSON = match[1];

        try {
            return JSON.parse(extractedJSON);
        } catch (error) {
            console.error('Error parsing JSON:', error);
        }
    }

    return null;
};

// Normalizes a border_radius value (number/numeric string/unit string) to a
// valid CSS length, e.g. 16 or "16" -> "16px", "50%" and "1rem" pass through.
export const toCssRadius = (
  value?: number | string | null,
): string | undefined => {
  if (value == null || value === "") return undefined;
  if (typeof value === "number") return Number.isFinite(value) ? `${value}px` : undefined;
  const str = String(value).trim();
  if (str === "") return undefined;
  // Bare number (e.g. "16") -> add px. Anything with a unit/% is used as-is.
  return /^-?\d*\.?\d+$/.test(str) ? `${str}px` : str;
};

// Per-corner border_radius_corners -> CSS border-radius longhand. Missing/
// invalid corners fall back to 0; undefined if every corner is 0.
export const toCssRadiusCorners = (
  corners?: {
    top_left?: number | string | null;
    top_right?: number | string | null;
    bottom_left?: number | string | null;
    bottom_right?: number | string | null;
  } | null,
): string | undefined => {
  if (!corners) return undefined;
  const px = (v?: number | string | null): string => {
    const n = Number(v);
    return Number.isFinite(n) && n > 0 ? `${n}px` : "0";
  };
  const topLeft = px(corners.top_left);
  const topRight = px(corners.top_right);
  const bottomRight = px(corners.bottom_right);
  const bottomLeft = px(corners.bottom_left);
  if (topLeft === "0" && topRight === "0" && bottomRight === "0" && bottomLeft === "0") {
    return undefined;
  }
  return `${topLeft} ${topRight} ${bottomRight} ${bottomLeft}`;
};

// image_aspect ("3:1" or "3/1") -> CSS aspect-ratio, e.g. "3 / 1". Keeps a
// banner's shape across viewports and reserves space before load (avoids CLS).
// undefined for anything unparseable.
export const toCssAspectRatio = (
  value?: number | string | null,
): string | undefined => {
  if (value == null || value === "") return undefined;
  const parts = String(value).trim().split(/[:/]/);
  if (parts.length !== 2) return undefined;
  const w = Number(parts[0]);
  const h = Number(parts[1]);
  // A zero or negative side would collapse the box entirely.
  if (!Number.isFinite(w) || !Number.isFinite(h) || w <= 0 || h <= 0) {
    return undefined;
  }
  return `${w} / ${h}`;
};

// Device-appropriate image from a home_layout `images` object, falling back
// requested device -> web -> app -> tablet -> legacyUrl.
export const pickDeviceImage = (
  images?: Record<string, string> | null,
  device?: string,
  legacyUrl = "",
): string => {
  const imgs: Record<string, string> = images || {};
  return (
    imgs[device as string] || imgs.web || imgs.app || imgs.tablet || legacyUrl || ""
  );
};

// Same fallback as pickDeviceImage, for a numeric field that may be a
// per-breakpoint object or a legacy flat number.
export const pickDeviceNumber = (
  value: unknown,
  device?: string,
  fallback = 0,
): number => {
  if (value != null && typeof value === "object") {
    const obj = value as Record<string, unknown>;
    const picked = obj[device as string] ?? obj.web ?? obj.app ?? obj.tablet;
    const n = Number(picked);
    return Number.isFinite(n) ? n : fallback;
  }
  const n = Number(value);
  return Number.isFinite(n) && value !== "" && value != null ? n : fallback;
};

// Formats an amount with currency symbol + decimals from the API, e.g.
// formatCurrency(536, "₹", 2) -> "₹536.00". trimZeros drops 150.00 -> 150.
export const formatCurrency = (
  amount: number | string,
  currency = "",
  decimalPoint: number | string = 0,
  trimZeros = false,
): string => {
  const num = Number(amount);
  const safeNum = Number.isFinite(num) ? num : 0;
  const decimals = Number.isFinite(Number(decimalPoint))
    ? Number(decimalPoint)
    : 0;
  let text = safeNum.toFixed(decimals);
  if (trimZeros && decimals > 0) {
    text = text.replace(/\.0+$/, "");
  }
  return `${currency ?? ""}${text}`;
};

// total_allowed_quantity caps units per product; 0/missing/invalid = unlimited.
export const isUnlimitedAllowedQty = (limit?: number | string | null): boolean => {
  const num = Number(limit);
  return !Number.isFinite(num) || num <= 0;
};

// True once the cart qty hits the per-product cap; always false if unlimited.
export const hasReachedAllowedQty = (
  currentQty?: number | string | null,
  limit?: number | string | null,
): boolean => {
  if (isUnlimitedAllowedQty(limit)) return false;
  return Number(currentQty || 0) >= Number(limit);
};

// Cart rows still missing a required prescription (product_type 5,
// is_prescription_required=1). prescriptions is the redux variantId->File map.
export const getMissingRequiredPrescriptions = (
  items?: any[] | null,
  prescriptions?: Record<string, File> | null,
): any[] =>
  (items || []).filter((it) => {
    if (Number(it?.product_type) !== 5) return false;
    if (Number(it?.is_prescription_required) !== 1) return false;
    const vid = String(it?.variant_id ?? it?.product_variant_id);
    return !(prescriptions && prescriptions[vid] instanceof File);
  });

export const hasMissingRequiredPrescriptions = (
  items?: any[] | null,
  prescriptions?: Record<string, File> | null,
): boolean => getMissingRequiredPrescriptions(items, prescriptions).length > 0;

// True when adding would push qty past the cap (strict >); false if unlimited.
export const exceedsAllowedQty = (
  totalQty?: number | string | null,
  limit?: number | string | null,
): boolean => {
  if (isUnlimitedAllowedQty(limit)) return false;
  return Number(totalQty || 0) > Number(limit);
};

// ── Variant stock helpers ──────────────────────────────────────────────────
// Stock fields can be numbers or strings and are sometimes missing entirely
// (cross-sell/upsell payloads); these coerce and treat missing as available.

// Unlimited unless is_unlimited_stock is 0/"0"; missing -> unlimited.
export const isVariantUnlimitedStock = (
  variant?: { is_unlimited_stock?: number | string | null } | null,
): boolean => {
  const v = variant?.is_unlimited_stock;
  if (v === undefined || v === null) return true;
  return Number(v) !== 0;
};

// Numeric stock; missing -> Infinity (unknown isn't zero).
export const variantStock = (
  variant?: { stock?: number | string | null } | null,
): number => {
  const s = variant?.stock;
  if (s === undefined || s === null || s === "") return Infinity;
  return Number(s) || 0;
};

// True only when definitively out of stock (limited AND stock <= 0).
export const isVariantOutOfStock = (
  variant?: { is_unlimited_stock?: number | string | null; stock?: number | string | null } | null,
): boolean => !isVariantUnlimitedStock(variant) && variantStock(variant) <= 0;

// True when stock is available to add (unlimited, or limited with stock left).
export const isVariantInStock = (
  variant?: { is_unlimited_stock?: number | string | null; stock?: number | string | null } | null,
): boolean => !isVariantOutOfStock(variant);

// ── Global quantity cap (max_cart_items_count -> total_allowed_quantity -> stock) ──
// Store-wide cart quantity total, across every row.
export const getCartTotalQuantity = (items?: any[] | null): number =>
  (items || []).reduce((total, item) => total + (Number(item?.qty) || 0), 0);

// Absolute max qty for one line (a stepper's `max`): the tightest of store-wide
// cap remaining, total_allowed_quantity, and stock. otherLinesQty must exclude
// this line's own qty, or it gets subtracted from its own headroom twice.
export const getMaxAddableQuantity = ({
  maxCartItemsCount,
  otherLinesQty,
  totalAllowedQty,
  isUnlimitedStock,
  stock,
}: {
  maxCartItemsCount?: number | string | null;
  otherLinesQty?: number | string | null;
  totalAllowedQty?: number | string | null;
  isUnlimitedStock?: boolean;
  stock?: number | string | null;
}): number => {
  const settingCap = isUnlimitedAllowedQty(maxCartItemsCount)
    ? Infinity
    : Math.max(0, Number(maxCartItemsCount) - (Number(otherLinesQty) || 0));
  const allowedCap = isUnlimitedAllowedQty(totalAllowedQty)
    ? Infinity
    : Number(totalAllowedQty);
  const stockCap = isUnlimitedStock ? Infinity : Number(stock) || 0;
  return Math.min(settingCap, allowedCap, stockCap);
};

// ── Date/time formatting driven by the country_setting API ──────────────────
// Renders a JS Date against the API's PHP-style format strings (date_format,
// time_format), read via store.getState() so these stay plain functions.
import { store } from "@/redux/store";

const MONTHS_FULL = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];
const MONTHS_SHORT = MONTHS_FULL.map((m) => m.slice(0, 3));
const DAYS_FULL = [
  "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
];
const DAYS_SHORT = DAYS_FULL.map((d) => d.slice(0, 3));
const pad = (n: number): string => String(n).padStart(2, "0");

// Renders a Date with a PHP-style format string; "\" escapes a literal char.
export const phpFormat = (d: Date, fmt: string): string => {
  const h24 = d.getHours();
  const h12 = h24 % 12 || 12;
  const tokens: Record<string, string | number> = {
    d: pad(d.getDate()),
    j: d.getDate(),
    D: DAYS_SHORT[d.getDay()],
    l: DAYS_FULL[d.getDay()],
    N: d.getDay() === 0 ? 7 : d.getDay(),
    w: d.getDay(),
    M: MONTHS_SHORT[d.getMonth()],
    F: MONTHS_FULL[d.getMonth()],
    m: pad(d.getMonth() + 1),
    n: d.getMonth() + 1,
    Y: d.getFullYear(),
    y: pad(d.getFullYear() % 100),
    H: pad(h24),
    G: h24,
    h: pad(h12),
    g: h12,
    i: pad(d.getMinutes()),
    s: pad(d.getSeconds()),
    A: h24 < 12 ? "AM" : "PM",
    a: h24 < 12 ? "am" : "pm",
  };
  let out = "";
  for (let i = 0; i < fmt.length; i++) {
    const c = fmt[i];
    if (c === "\\") {
      out += fmt[++i] ?? "";
    } else {
      out += c in tokens ? tokens[c] : c;
    }
  }
  return out;
};

const getCountryFormats = (): { date: string; time: string } => {
  const cs = (store.getState() as any).CountrySetting?.countrySetting;
  return {
    date: cs?.date_format || "d M Y",
    time: cs?.time_format || "H:i",
  };
};

export const sanitizeDate = (dateString: string): string => {
  if (!dateString) return "";
  if (typeof dateString !== "string") return dateString;
  let str = dateString.trim().replace(/Z+$/i, "");
  // "YYYY-MM-DD HH:mm:ss" -> "YYYY-MM-DDTHH:mm:ss"
  str = str.replace(
    /^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2}(?:\.\d+)?)/,
    "$1T$2"
  );
  // ISO datetime with no offset: append Z so JS parses as UTC, then converts to local.
  if (
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(str) &&
    !/[Zz]|[+-]\d{2}:?\d{2}$/.test(str)
  ) {
    str += "Z";
  }
  return str;
};

export const formatDate = (
  date?: string | number | Date | null,
  fmt?: string,
): string => {
  if (!date) return "";
  const sanitized = typeof date === "string" ? sanitizeDate(date) : date;
  const d = new Date(sanitized);
  if (isNaN(d as any)) return "";
  return phpFormat(d, fmt || getCountryFormats().date);
};

export const formatTime = (
  date?: string | number | Date | null,
  fmt?: string,
): string => {
  if (!date) return "";
  const sanitized = typeof date === "string" ? sanitizeDate(date) : date;
  const d = new Date(sanitized);
  if (isNaN(d as any)) return "";
  return phpFormat(d, fmt || getCountryFormats().time);
};

// Combined date + time, e.g. "05 Jul 2026 14:30".
export const formatDateTime = (date?: string | number | Date | null): string => {
  if (!date) return "";
  const { date: df, time: tf } = getCountryFormats();
  return formatDate(date, `${df} ${tf}`);
};

// Bounding-box midpoint of a zone's polygon_boundary — the API gives no
// center point, and a vertex average is wrong for a sparse/irregular polygon.
export const getPolygonCenter = (
  polygon?: { lat?: number | string; lng?: number | string }[] | null,
): { lat: number; lng: number } | null => {
  if (!Array.isArray(polygon) || polygon.length === 0) return null;
  const points = polygon.filter(
    (p) => Number.isFinite(Number(p?.lat)) && Number.isFinite(Number(p?.lng)),
  );
  if (points.length === 0) return null;
  const lats = points.map((p) => Number(p?.lat));
  const lngs = points.map((p) => Number(p?.lng));
  return {
    lat: (Math.min(...lats) + Math.max(...lats)) / 2,
    lng: (Math.min(...lngs) + Math.max(...lngs)) / 2,
  };
};

// Product galleries get videos through the same image_url field the API uses
// for stills, so the extension is all there is to go on.
const VIDEO_EXTENSIONS = new Set(["mp4", "webm", "mov", "m4v", "ogv"]);

export const isVideoUrl = (url?: string | null): boolean => {
  if (!url) return false;
  const path = String(url).split(/[?#]/)[0];
  const ext = path.split(".").pop()?.toLowerCase() ?? "";
  return VIDEO_EXTENSIONS.has(ext);
};
