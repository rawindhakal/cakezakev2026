import axios from "axios";
import { getWithEtag } from "@/api/etagCache";
import * as apiEndPoints from "@/api/apiEndpoints";
import { getPolygonCenter } from "@/utils/helperFunction";

// Server-side zone slug to coordinates resolution helper

const ACCESS_KEY = "903361";
const BASE = `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_API_SUBURL}`;
const authHeaders = { "x-access-key": ACCESS_KEY };

// Zones change rarely — cache per process. No per-user state, safe to share.
const CACHE_TTL_MS = 1000 * 60 * 10;
let __zonesCache: any[] | null = null;
let __zonesCachedAt = 0;
let __zonesInflight: Promise<any[]> | null = null;

// Fetch country IDs for country-scoped zones lookup
const fetchCountryIds = async (): Promise<any[]> => {
  const res = await getWithEtag(`${BASE}/${apiEndPoints.getCountries}`, {
    params: { limit: 200, offset: 0 },
    headers: authHeaders,
  });
  return (res?.data || []).map((c: any) => c?.id).filter((id: any) => id != null);
};

const fetchZonesForCountry = async (countryId?: any): Promise<any[]> => {
  const params: { country_id?: any } = {};
  if (countryId != null) params.country_id = countryId;
  const response = await getWithEtag(`${BASE}/${apiEndPoints.getZones}`, {
    params,
    headers: authHeaders,
  });
  return response?.data || [];
};

const fetchZones = async ({ countryId }: { countryId?: any } = {}): Promise<any[]> => {
  // Explicit country → that country only (sitemap uses this when scoped).
  if (countryId != null) return fetchZonesForCountry(countryId);

  // Merge zones across countries if no explicit country ID provided
  let countryIds: any[] = [];
  try {
    countryIds = await fetchCountryIds();
  } catch (err: any) {
    console.warn("[zones] countries fetch failed:", err?.message);
  }
  if (!countryIds.length) return fetchZonesForCountry();

  let failed = 0;
  const perCountry = await Promise.all(
    countryIds.map((id) =>
      fetchZonesForCountry(id).catch((err) => {
        console.warn(`[zones] country ${id} failed:`, err?.message);
        failed += 1;
        return [];
      }),
    ),
  );
  // Every country errored — a transient API 500, not "this site has no zones".
  // Throwing keeps the empty list out of the cache.
  if (failed === countryIds.length) {
    throw new Error("all country zone fetches failed");
  }
  // Dedupe by slug — a zone shouldn't repeat across countries, but be safe.
  const bySlug = new Map<string, any>();
  for (const list of perCountry) {
    for (const z of list) {
      if (z?.slug && !bySlug.has(z.slug)) bySlug.set(z.slug, z);
    }
  }
  return [...bySlug.values()];
};

// A slug missing from the cached list forces one refetch, at most this often.
const MISS_REFETCH_MIN_MS = 1000 * 30;
let __lastMissRefetchAt = 0;

/** Fetch and cache in-process zone list */
export const getZonesCached = async ({
  countryId,
  now = Date.now(),
  force = false,
}: { countryId?: any; now?: number; force?: boolean } = {}): Promise<any[]> => {
  if (!force && __zonesCache && now - __zonesCachedAt < CACHE_TTL_MS)
    return __zonesCache;
  if (__zonesInflight) return __zonesInflight;

  __zonesInflight = fetchZones({ countryId })
    .then((zones) => {
      // Never cache an empty list: one bad response would 404 every zone page
      // for the whole TTL. Keep the previous list until a real one arrives.
      if (!zones.length) return __zonesCache || [];
      __zonesCache = zones;
      __zonesCachedAt = now;
      return zones;
    })
    .catch((err) => {
      // Fallback to stale cache or empty list on fetch failure
      console.warn("[zones] fetch failed:", err?.message);
      return __zonesCache || [];
    })
    .finally(() => {
      __zonesInflight = null;
    });

  return __zonesInflight;
};

/** Normalize zone channel value to quick or ecommerce */
export const requestChannel = (channel: any): "quick" | "ecommerce" =>
  channel === "quick" || channel === "ecommerce" ? channel : "quick";

/** Resolve zone slug to coordinates and channel details */
export const resolveZoneBySlug = async (
  slug?: string | null,
  { countryId }: { countryId?: any } = {},
): Promise<{
  zone: { id: any; name: any; slug: any };
  latitude: number | null;
  longitude: number | null;
  channel: "quick" | "ecommerce";
  rawChannel: any;
} | null> => {
  if (!slug) return null;

  const zones = await getZonesCached({ countryId });
  let zone = zones.find((z) => z?.slug === slug);
  // A miss may just be a stale list in this process — one zone added since the
  // last fetch would otherwise 404 for the whole TTL. Re-check once, rate-limited
  // so an unknown slug can't hammer the API.
  if (!zone) {
    const now = Date.now();
    if (now - __lastMissRefetchAt >= MISS_REFETCH_MIN_MS) {
      __lastMissRefetchAt = now;
      const fresh = await getZonesCached({ countryId, force: true });
      zone = fresh.find((z) => z?.slug === slug);
    }
  }
  if (!zone) return null;

  const center = getPolygonCenter(zone.polygon_boundary);

  return {
    zone: { id: zone.id, name: zone.name, slug: zone.slug },
    latitude: center?.lat ?? null,
    longitude: center?.lng ?? null,
    channel: requestChannel(zone.channel),
    rawChannel: zone.channel ?? null,
  };
};

/** Fallback location resolution from the first zone with a centroid */
export const firstZoneLocation = async ({
  countryId,
}: { countryId?: any } = {}): Promise<{
  latitude: number;
  longitude: number;
  channel: "quick" | "ecommerce";
  rawChannel: any;
  slug: any;
} | null> => {
  const zones = await getZonesCached({ countryId });
  for (const zone of zones) {
    const center = getPolygonCenter(zone?.polygon_boundary);
    if (center) {
      return {
        latitude: center.lat,
        longitude: center.lng,
        channel: requestChannel(zone?.channel),
        // Raw API value (may be "both"); channel above is header-narrowed.
        rawChannel: zone?.channel ?? null,
        slug: zone?.slug ?? null,
      };
    }
  }
  return null;
};

// Test/debug escape hatch — lets a caller force the next resolve to refetch.
export const __clearZonesCache = (): void => {
  __zonesCache = null;
  __zonesCachedAt = 0;
  __lastMissRefetchAt = 0;
};
