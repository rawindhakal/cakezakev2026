import { NextResponse } from "next/server";
import axios from "axios";
import { getZonesCached, requestChannel } from "@/api/zoneResolver";
import { getProductsServer, isDemoModeServer } from "@/api/serverApi";
import { getLanguagesCached } from "@/api/languageResolver";
import { getPolygonCenter } from "@/utils/helperFunction";
import { canonicalUrl } from "@/utils/canonicalUrl";
import * as apiEndPoints from "@/api/apiEndpoints";

// Zone- and language-aware sitemap, cached per TTL.
//   GLOBAL_LANG_ROUTES — per language, never zone-prefixed.
//   zone loop          — language x zone: /{zone}, /{zone}/products,
//                        /{zone}/product/{slug} (zone's own catalogue).
// URLs built via canonicalUrl so they always match each page's canonical.

export const dynamic = "force-dynamic";

const BASE = process.env.NEXT_PUBLIC_BASE_URL;
const CACHE_TTL_MS = 1000 * 60 * 60; // 1 h — zone catalogues change slowly
const MAX_PRODUCTS_PER_ZONE = 500;

// Paths must match each page's own PATH constant.
const GLOBAL_LANG_ROUTES: [string, string, string][] = [
  ["/", "1.0", "daily"],
  ["/categories", "0.8", "weekly"],
  ["/blogs", "0.6", "weekly"],
  ["/about-us", "0.5", "monthly"],
  ["/contact-us", "0.5", "monthly"],
  ["/faqs", "0.5", "monthly"],
  ["/privacy-policy", "0.3", "yearly"],
  ["/terms-and-conditions", "0.3", "yearly"],
  ["/shipping-policy", "0.3", "yearly"],
  ["/cancellation-policy", "0.3", "yearly"],
  ["/return-and-exchange-policy", "0.3", "yearly"],
];

// Not language-aware — listed once, no lang variants.
const STATIC_ROUTES: [string, string, string][] = [
  ["/brands", "0.7", "weekly"],
  ["/sellers", "0.7", "weekly"],
  ["/countries", "0.6", "weekly"],
];

const ACCESS_KEY = "903361";
const API_BASE = `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_API_SUBURL}`;
const SLUG_PAGE_LIMIT = 200;
const MAX_SLUG_PAGES = 50; // hard backstop against a runaway paginator

let __cache: string | null = null;
let __cachedAt = 0;

const urlEntry = (
  loc: string,
  { changefreq = "daily", priority = "0.7" }: { changefreq?: string; priority?: string } = {},
) =>
  `  <url>
    <loc>${loc}</loc>
    <changefreq>${changefreq}</changefreq>
    <priority>${priority}</priority>
  </url>`;

// Every data[].slug from a paginated GET endpoint.
const fetchSlugs = async (endpoint: string): Promise<string[]> => {
  const slugs: string[] = [];
  try {
    for (let offset = 0; offset < MAX_SLUG_PAGES * SLUG_PAGE_LIMIT; offset += SLUG_PAGE_LIMIT) {
      const res = await axios.get(`${API_BASE}/${endpoint}`, {
        params: { limit: SLUG_PAGE_LIMIT, offset },
        headers: { "x-access-key": ACCESS_KEY },
      });
      const rows = res.data?.data || [];
      for (const r of rows) if (r?.slug) slugs.push(r.slug);
      if (rows.length < SLUG_PAGE_LIMIT) break; // short page = last page
    }
  } catch (err: any) {
    console.warn(`[sitemap] ${endpoint} slugs failed:`, err?.message);
  }
  return slugs;
};

// Map keyed on final URL — de-dupes languages resolving to the same href.
const addEntry = (
  seen: Map<string, string>,
  loc: string,
  opts: { priority?: string; changefreq?: string },
) => {
  if (seen.has(loc)) return;
  seen.set(loc, urlEntry(loc, opts));
};

const buildSitemap = async (): Promise<string> => {
  const [zones, { codes, defaultCode }] = await Promise.all([
    getZonesCached(),
    getLanguagesCached(),
  ]);
  const languages = [...codes];
  const seen = new Map<string, string>();

  for (const [path, priority, changefreq] of STATIC_ROUTES) {
    addEntry(seen, `${BASE}${path}`, { priority, changefreq });
  }

  for (const [path, priority, changefreq] of GLOBAL_LANG_ROUTES) {
    for (const lang of languages) {
      const loc = canonicalUrl({ lang, zone: null, path, defaultCode });
      addEntry(seen, loc, { priority, changefreq });
    }
  }

  // Blog + category detail: per language, zone-less.
  const [blogSlugs, categorySlugs] = await Promise.all([
    fetchSlugs(apiEndPoints.blogs),
    fetchSlugs(apiEndPoints.getCategory),
  ]);
  for (const slug of blogSlugs) {
    for (const lang of languages) {
      const loc = canonicalUrl({ lang, zone: null, path: `/blog/${slug}`, defaultCode });
      addEntry(seen, loc, { changefreq: "weekly", priority: "0.6" });
    }
  }
  for (const slug of categorySlugs) {
    for (const lang of languages) {
      const loc = canonicalUrl({
        lang,
        zone: null,
        path: `/categories/${slug}`,
        defaultCode,
      });
      addEntry(seen, loc, { changefreq: "weekly", priority: "0.7" });
    }
  }

  for (const zone of zones as any[]) {
    // No boundary → route 404s → skip (same check as the resolver).
    const center = getPolygonCenter(zone?.polygon_boundary);
    if (!center || !zone?.slug) continue;

    for (const lang of languages) {
      addEntry(
        seen,
        canonicalUrl({ lang, zone: zone.slug, path: "/", defaultCode }),
        { changefreq: "daily", priority: "0.9" },
      );
      addEntry(
        seen,
        canonicalUrl({ lang, zone: zone.slug, path: "/products", defaultCode }),
        { changefreq: "daily", priority: "0.8" },
      );
    }

    const products: any[] = await getProductsServer({
      latitude: center.lat,
      longitude: center.lng,
      // API rejects "both" — normalize.
      channel: requestChannel(zone.channel),
      lang: undefined,
      limit: MAX_PRODUCTS_PER_ZONE,
    }).catch((err: any) => {
      console.warn(`[sitemap] ${zone.slug} products failed:`, err?.message);
      return [];
    });

    for (const p of products) {
      if (!p?.slug) continue;
      for (const lang of languages) {
        addEntry(
          seen,
          canonicalUrl({
            lang,
            zone: zone.slug,
            path: `/product/${p.slug}`,
            defaultCode,
          }),
          { changefreq: "weekly", priority: "0.7" },
        );
      }
    }
    if (products.length >= MAX_PRODUCTS_PER_ZONE) {
      console.warn(
        `[sitemap] ${zone.slug} hit the ${MAX_PRODUCTS_PER_ZONE} cap — some products omitted`,
      );
    }
  }

  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${[...seen.values()].join("\n")}
</urlset>`;
};

// Demo mode: static pages only — skips zone/product fetches to save quota.
const buildDemoSitemap = async (): Promise<string> => {
  const urls = GLOBAL_LANG_ROUTES.map(([path, priority, changefreq]) =>
    urlEntry(`${BASE}${path}`, { priority, changefreq }),
  ).join("\n");
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>`;
};

export async function GET() {
  if (await isDemoModeServer()) {
    return new NextResponse(await buildDemoSitemap(), {
      headers: {
        "Content-Type": "text/xml",
        "Cache-Control": "public, s-maxage=3600, stale-while-revalidate=86400",
      },
    });
  }

  const now = Date.now();
  if (!__cache || now - __cachedAt > CACHE_TTL_MS) {
    __cache = await buildSitemap();
    __cachedAt = now;
  }

  return new NextResponse(__cache, {
    headers: {
      "Content-Type": "text/xml",
      "Cache-Control": "public, s-maxage=3600, stale-while-revalidate=86400",
    },
  });
}
