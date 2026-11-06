import axios from "axios";
import * as apiEndPoints from "@/api/apiEndpoints";
import { getWithEtag } from "@/api/etagCache";
import { HOME_LAYOUT_INITIAL_SECTION_LIMIT } from "@/constants/homeLayout";

// Server-only API helpers for SSR/gSSP with explicit inputs

const ACCESS_KEY = "903361";
const BASE = `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_API_SUBURL}`;

const serverHeaders = ({
  lang,
  channel,
}: {
  lang?: string;
  channel?: string;
}): Record<string, string> => {
  const headers: Record<string, string> = { "x-access-key": ACCESS_KEY };
  if (lang) headers["Content-Language"] = lang;
  if (channel) headers.channel = channel;
  return headers;
};

/** Fetch product details server-side by slug or ID */
export const getProductByIdServer = async ({
  slug,
  latitude,
  longitude,
  lang,
  channel,
}: {
  slug?: string;
  latitude?: number | string;
  longitude?: number | string;
  lang?: string;
  channel?: string;
}): Promise<any> => {
  // GET since the API moved these reads off POST — POST now answers 405.
  const params: Record<string, any> = { latitude, longitude };
  if (slug) params.slug = slug;

  // product_by_id is the only one of the four that carries an ETag — repeat
  // views of the same product revalidate to 304 and cost no body.
  return getWithEtag(`${BASE}/${apiEndPoints.getProductById}`, {
    params,
    headers: serverHeaders({ lang, channel }),
  });
};

/** Fetch products list server-side for sitemap enumeration */
export const getProductsServer = async ({
  latitude,
  longitude,
  channel,
  lang,
  limit = 100,
  offset = 0,
}: {
  latitude?: number | string;
  longitude?: number | string;
  channel?: string;
  lang?: string;
  limit?: number;
  offset?: number;
}): Promise<any[]> => {
  const response = await axios.get(`${BASE}/${apiEndPoints.getProducts}`, {
    params: { latitude, longitude, limit, offset },
    headers: serverHeaders({ lang, channel }),
  });
  return response.data?.data || [];
};

/** Fetch product listing envelope server-side for page hydration */
export const getProductListingServer = async ({
  latitude,
  longitude,
  channel,
  lang,
  limit = 12,
  offset = 0,
  filters = undefined,
}: {
  latitude?: number | string;
  longitude?: number | string;
  channel?: string;
  lang?: string;
  limit?: number;
  offset?: number;
  filters?: Record<string, any>;
}): Promise<any> => {
  const params: Record<string, any> = { latitude, longitude, limit, offset };
  if (filters) {
    for (const key in filters) {
      const v = filters[key];
      if (v !== null && v !== undefined && v !== "") params[key] = v;
    }
  }

  const response = await axios.get(`${BASE}/${apiEndPoints.getProducts}`, {
    params,
    headers: serverHeaders({ lang, channel: channel || "quick" }),
  });
  return response.data;
};

/** Fetch home layout sections server-side for location */
export const getHomeLayoutServer = async ({
  latitude,
  longitude,
  categoryId = null,
  lang,
  channel,
  device,
}: {
  latitude?: number | string;
  longitude?: number | string;
  categoryId?: number | string | null;
  lang?: string;
  channel?: string;
  device?: string;
}): Promise<any> => {
  const params: {
    latitude?: number | string;
    longitude?: number | string;
    category_id?: number | string;
    limit?: number;
    offset?: number;
    device?: string;
  } = { latitude, longitude, limit: HOME_LAYOUT_INITIAL_SECTION_LIMIT, offset: 0 };
  // Append category ID filter if set
  if (categoryId != null && categoryId !== "") {
    params.category_id = categoryId;
  }
  if (device != null && device !== "") {
    params.device = device;
  }
  return getWithEtag(`${BASE}/${apiEndPoints.homeLayout}`, {
    params,
    // Default to quick channel if omitted
    headers: serverHeaders({ lang, channel: channel || "quick" }),
  });
};

/** Fetch page-builder CMS page content server-side */
export const getPageBuilderServer = async ({
  slug,
  id,
  latitude,
  longitude,
  lang,
  limit,
  offset,
}: {
  slug?: string;
  id?: number | string;
  latitude?: number | string;
  longitude?: number | string;
  lang?: string;
  limit?: number;
  offset?: number;
}): Promise<any> => {
  // Query by slug or id
  const params: Record<string, any> = { latitude, longitude };
  if (slug != null && slug !== "") params.slug = slug;
  else if (id != null && id !== "") params.id = id;
  if (limit != null) params.limit = limit;
  if (offset != null) params.offset = offset;
  return getWithEtag(`${BASE}/${apiEndPoints.pageBuilder}`, {
    params,
    headers: serverHeaders({ lang }),
  });
};

/** Fetch web settings server-side */
export const getSettingServer = async ({
  lang,
}: { lang?: string } = {}): Promise<any> => {
  return getWithEtag(`${BASE}/${apiEndPoints.getSettings}`, {
    params: { is_web_setting: 1 },
    headers: serverHeaders({ lang }),
  });
};

// Short TTL cache for demo mode flag
const DEMO_MODE_CACHE_TTL_MS = 5 * 60 * 1000;
let demoModeCache: { value: boolean; expiresAt: number } | null = null;

/** Check if demo mode is enabled on the server */
export const isDemoModeServer = async (): Promise<boolean> => {
  if (demoModeCache && demoModeCache.expiresAt > Date.now()) {
    return demoModeCache.value;
  }
  try {
    const res = await getSettingServer({});
    // Parse setting data JSON or object
    const settingData =
      typeof res?.data === "string" ? JSON.parse(atob(res.data)) : res?.data;
    const value = settingData?.demo_mode == 1;
    demoModeCache = { value, expiresAt: Date.now() + DEMO_MODE_CACHE_TTL_MS };
    return value;
  } catch {
    return false;
  }
};

/** Fetch child categories for a parent category server-side */
export const getCategoryChildrenServer = async ({
  slug,
  latitude,
  longitude,
  lang,
  channel,
  limit = 12,
  offset = 0,
}: {
  slug?: string;
  latitude?: number | string;
  longitude?: number | string;
  lang?: string;
  channel?: string;
  limit?: number;
  offset?: number;
}): Promise<any> => {
  const params: Record<string, any> = { limit, offset };
  if (slug) params.slug = slug;
  if (latitude != null) params.latitude = latitude;
  if (longitude != null) params.longitude = longitude;

  return getWithEtag(`${BASE}/${apiEndPoints.getCategory}`, {
    params,
    headers: serverHeaders({ lang, channel: channel || "quick" }),
  });
};

/** Fetch full category tree server-side, revalidated by ETag */
export const getCategoriesTreeServer = async ({
  latitude,
  longitude,
  lang,
  channel,
}: {
  latitude?: number | string;
  longitude?: number | string;
  lang?: string;
  channel?: string;
}): Promise<any> => {
  // No TTL layer here: the server says must-revalidate, so getWithEtag asks
  // every time and a 304 costs no body.
  return getWithEtag(`${BASE}/${apiEndPoints.getCategory}`, {
    params: { latitude, longitude },
    headers: serverHeaders({ lang, channel: channel || "quick" }),
  });
};
