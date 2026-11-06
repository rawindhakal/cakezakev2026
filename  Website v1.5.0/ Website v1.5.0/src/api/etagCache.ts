import axios, { AxiosRequestConfig } from "axios";

// Server-side ETag revalidation for the read-heavy customer endpoints
// (categories ~66KB, home_layout ~26KB, brands ~1KB). Node keeps no HTTP
// cache, so the tag and body are held here and sent back as If-None-Match.
// No TTL on purpose: the server answers `must-revalidate`, so every call
// still asks and nobody sees stale data.

interface Entry {
  etag: string;
  data: any;
}

const store = new Map<string, Entry>();
// Keys are per URL + params + scope, so per-product and per-slug routes keep
// adding entries. Cap it and drop the least recently used.
const MAX_ENTRIES = 200;

const remember = (key: string, entry: Entry): void => {
  store.delete(key);
  store.set(key, entry);
  if (store.size > MAX_ENTRIES) {
    const oldest = store.keys().next().value;
    if (oldest !== undefined) store.delete(oldest);
  }
};

// Query string is compared order-insensitively by the server, so sort it here
// too; lang/channel/customer are part of the scope the tag covers.
const cacheKey = (
  url: string,
  params: Record<string, any> | undefined,
  headers: Record<string, string>,
): string => {
  const sorted = Object.entries(params || {})
    .filter(([, v]) => v !== undefined && v !== null && v !== "")
    .map(([k, v]) => `${k}=${String(v)}`)
    .sort()
    .join("&");
  const scope = [
    headers["Content-Language"] || "",
    headers.channel || "",
    headers.Authorization || "",
  ].join("|");
  return `${url}?${sorted}#${scope}`;
};

// This API answers refusals with HTTP 200 and status 0 — never cache those.
const isBusinessError = (data: any): boolean =>
  data != null && typeof data === "object" && data.status === 0;

/** GET with If-None-Match; on 304 returns the stored body as a normal success. */
export const getWithEtag = async (
  url: string,
  config: AxiosRequestConfig & { params?: Record<string, any> } = {},
): Promise<any> => {
  const headers = (config.headers || {}) as Record<string, string>;
  const key = cacheKey(url, config.params, headers);
  const cached = store.get(key);

  const response = await axios.get(url, {
    ...config,
    headers: {
      ...headers,
      ...(cached ? { "If-None-Match": cached.etag } : {}),
    },
    // Axios rejects 304 by default; it is a success for us.
    validateStatus: (s) => (s >= 200 && s < 300) || s === 304,
  });

  // 304 means the body is empty by design — never let it reach a caller or
  // overwrite the stored copy.
  if (response.status === 304) {
    // Touch it so an actively revalidated entry is not evicted as "oldest".
    if (cached) remember(key, cached);
    return cached ? cached.data : null;
  }

  const etag = response.headers?.etag || response.headers?.ETag;
  if (etag && !isBusinessError(response.data)) {
    remember(key, { etag, data: response.data });
  }
  return response.data;
};
