// Cookie name for mirroring visitor location coordinates to server for SSR seeding.
export const SSR_LOCATION_COOKIE = "ssr_loc";

const MAX_AGE_SECONDS = 60 * 60 * 24 * 30;

export interface SsrLocation {
  latitude: number;
  longitude: number;
}

const isFiniteCoord = (value: unknown): value is number =>
  typeof value === "number" && Number.isFinite(value);

/** Parse the cookie's raw `lat,lng` value. Returns null for anything malformed. */
export const parseSsrLocation = (raw: string | undefined | null): SsrLocation | null => {
  if (!raw) return null;
  const [latRaw, lngRaw] = raw.split(",");
  const latitude = Number(latRaw);
  const longitude = Number(lngRaw);
  if (!isFiniteCoord(latitude) || !isFiniteCoord(longitude)) return null;
  if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return null;
  return { latitude, longitude };
};

/** Write latitude and longitude coordinates into the SSR location cookie. */
export const writeSsrLocationCookie = (
  latitude: unknown,
  longitude: unknown,
): void => {
  if (typeof document === "undefined") return;
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (!isFiniteCoord(lat) || !isFiniteCoord(lng)) return;
  try {
    document.cookie = `${SSR_LOCATION_COOKIE}=${lat},${lng}; path=/; max-age=${MAX_AGE_SECONDS}; SameSite=Lax`;
  } catch {
    /* cookies blocked — SSR just falls back to default_city as before */
  }
};

