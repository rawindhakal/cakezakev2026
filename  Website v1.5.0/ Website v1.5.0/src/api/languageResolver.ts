import axios from "axios";
import { getWithEtag } from "@/api/etagCache";
import * as apiEndPoints from "@/api/apiEndpoints";

// Server-side cached language list used by middleware and routing

const ACCESS_KEY = "903361";
const BASE = `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_API_SUBURL}`;
const SYSTEM_TYPE_WEBSITE = 3;
const CACHE_TTL_MS = 1000 * 60 * 30; // 30 min — languages change very rarely

type LanguageCacheEntry = { codes: Set<string>; defaultCode: string };

let __cache: LanguageCacheEntry | null = null;
let __cachedAt = 0;
let __inflight: Promise<LanguageCacheEntry> | null = null;

const fetchLanguages = async (): Promise<LanguageCacheEntry> => {
  const res = await getWithEtag(`${BASE}/${apiEndPoints.getSystemLanguage}`, {
    params: { system_type: SYSTEM_TYPE_WEBSITE },
    headers: { "x-access-key": ACCESS_KEY },
  });
  const rows = res?.data || [];
  const codes = new Set<string>();
  let defaultCode = "en";
  for (const r of rows) {
    if (!r?.code) continue;
    codes.add(r.code);
    if (r.is_default == 1) defaultCode = r.code;
  }
  return { codes, defaultCode };
};

/** Fetch and cache supported system languages with fallback */
export const getLanguagesCached = async ({
  now = Date.now(),
}: { now?: number } = {}): Promise<LanguageCacheEntry> => {
  if (__cache && now - __cachedAt < CACHE_TTL_MS) return __cache;
  if (__inflight) return __inflight;

  __inflight = fetchLanguages()
    .then((data) => {
      __cache = data;
      __cachedAt = now;
      return data;
    })
    .catch((err) => {
      console.warn("[lang] fetch failed:", err?.message);
      return __cache || { codes: new Set(["en"]), defaultCode: "en" };
    })
    .finally(() => {
      __inflight = null;
    });

  return __inflight;
};
