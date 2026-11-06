import type { Metadata } from "next";
import { cache } from "react";
import { cookies, headers } from "next/headers";
import axios from "axios";
import { getWithEtag } from "@/api/etagCache";
import HomePage from "@/components/pagecomponents/Homepage";
import Custom404 from "@/components/notfound/Custom404";
import LanguageCodesSeed from "@/app/LanguageCodesSeed";
import SsrZoneProvider from "@/app/SsrZoneProvider";
import QuerySeed from "@/app/QuerySeed";
import { homeLayoutKey } from "@/utils/queryKeys";
import { extractJSONFromMarkup } from "@/utils/helperFunction";
import { resolveZoneBySlug, firstZoneLocation } from "@/api/zoneResolver";
import DeadZoneRedirect from "@/components/notfound/DeadZoneRedirect";
import { canonicalUrl, hreflangAlternates } from "@/utils/canonicalUrl";
import { getLanguagesCached } from "@/api/languageResolver";
import { getHomeLayoutServer, getSettingServer } from "@/api/serverApi";
import { deviceFromUserAgent } from "@/utils/deviceFromUserAgent";
import { selectSeoRow, pickSeoField } from "@/utils/selectSeoRow";
import { tabIdFromSlug } from "@/utils/categoryTabSlug";
import { buildPageMetadata } from "@/utils/buildMetadata";
import { SSR_LOCATION_COOKIE, parseSsrLocation } from "@/utils/ssrLocationCookie";

const fallbackProps = () => ({
  title: process.env.NEXT_PUBLIC_META_TITLE || null,
  description: process.env.NEXT_PUBLIC_META_DESCRIPTION || null,
  keywords: process.env.NEXT_PUBLIC_META_KEYWORDS || null,
  schemaMarkup: null as string | null,
  ogImage: null as string | null,
  favicon: null as string | null,
  initialHomeLayout: null as any,
});

// Default JSON-LD WebSite and Organization schema
const defaultHomeSchema = (): string | null => {
  const base = process.env.NEXT_PUBLIC_BASE_URL;
  const name = process.env.NEXT_PUBLIC_META_TITLE || process.env.NEXT_PUBLIC_WEB_NAME || null;
  if (!base || !name) return null;
  return JSON.stringify({
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebSite",
        "@id": `${base}/#website`,
        url: base,
        name,
        description: process.env.NEXT_PUBLIC_META_DESCRIPTION || undefined,
      },
      {
        "@type": "Organization",
        "@id": `${base}/#organization`,
        name,
        url: base,
      },
    ],
  });
};

type HomePageData = {
  notFoundPage: boolean;
  title?: string | null;
  description?: string | null;
  keywords?: string | null;
  ogImage?: string | null;
  schemaMarkup?: string | null;
  favicon?: string | null;
  zone: string | null;
  /** Zone to build links with; may be set even when `zone` (canonical) is null. */
  linkZone?: string | null;
  lang: string | null;
  langCodes: string[];
  langDefault: string;
  initialHomeLayout: any;
  tabSlug: string | null;
};

const loadHomeData = cache(
  async (
    lang: string | undefined,
    zoneSlug: string | undefined,
    tabSlugParam: string | null,
    userAgent: string,
    // Raw lat,lng location cookie for request cache key
    locationCookie: string,
  ): Promise<HomePageData> => {
    const clientLocation = parseSsrLocation(locationCookie);
    // Zone, languages, settings and SEO don't depend on each other — fire them
    // together so SSR costs one round trip instead of four. Each is awaited at
    // its original spot, so error handling below is unchanged. The bare
    // .catch() marks rejections as handled; the real await still throws.
    const zoneP = zoneSlug
      ? resolveZoneBySlug(zoneSlug)
      : Promise.resolve(null);
    const langP = getLanguagesCached();
    const settingP = getSettingServer({ lang });
    const seoP = getWithEtag(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_API_SUBURL}/settings/get_seo_settings`,
      {
        params: { page_type: "Home" },
        headers: { "Content-Language": lang as string },
      },
    );
    for (const p of [zoneP, langP, settingP, seoP]) p.catch(() => {});
    try {
      // Resolve and validate zone slug from route segment
      let resolved: any = null;
      try {
        resolved = await zoneP;
      } catch (err: any) {
        console.warn("[home] zone resolve failed:", err?.message);
      }
      // Return 404 data shape if zone slug is invalid
      if (zoneSlug && !resolved) {
        return {
          notFoundPage: true,
          zone: null,
          lang: lang ?? null,
          langCodes: ["en"],
          langDefault: "en",
          initialHomeLayout: null,
          tabSlug: null,
        };
      }
      const zone = resolved?.zone?.slug ?? null;
      // Link zone slug for generating product links in server HTML
      let linkZone: string | null = zone;
      // hreflang language codes from the API — never hardcoded.
      const { codes: langCodesSet, defaultCode: langDefault } = await langP;
      const langCodes = [...langCodesSet];

      // Determine SSR coordinates and channel from zone or fallback
      let ssrLat = resolved?.latitude ?? null;
      let ssrLng = resolved?.longitude ?? null;
      let ssrChannel = resolved?.channel ?? null;
      // Raw channel string from zones API
      let ssrRawChannel = resolved?.rawChannel ?? null;
      // Site-wide favicon fallback from web settings
      let settingFavicon: string | null = null;
      try {
        const settingRes: any = await settingP;
        const settingData =
          typeof settingRes?.data === "string" ? JSON.parse(atob(settingRes.data)) : settingRes?.data;
        settingFavicon = settingData?.favicon || null;
        // Fallback to clientLocation or default_city coordinates
        if (!resolved || !ssrLat || !ssrLng) {
          // Prefer client location cookie over default_city
          const dc = clientLocation ?? settingData?.default_city;
          if (dc?.latitude && dc?.longitude) {
            ssrLat = dc.latitude;
            ssrLng = dc.longitude;
            // Default channel to quick for zone-less requests
            if (!resolved) ssrChannel = "quick";
          }
        }
      } catch (err: any) {
        console.log("SSR settings fetch failed:", err?.message);
      }

      // Last-resort location fallback using first available zone centroid
      if (!ssrLat || !ssrLng) {
        try {
          const fallback: any = await firstZoneLocation();
          if (fallback) {
            ssrLat = fallback.latitude;
            ssrLng = fallback.longitude;
            ssrChannel = fallback.channel;
            ssrRawChannel = fallback.rawChannel ?? null;
            if (!linkZone) linkZone = fallback.slug ?? null;
          }
        } catch (err: any) {
          console.log("SSR zones fallback failed:", err?.message);
        }
      }

      // Find link zone slug for bare home page
      if (!linkZone) {
        try {
          const linkFallback: any = await firstZoneLocation();
          linkZone = linkFallback?.slug ?? null;
        } catch (err: any) {
          console.log("SSR link-zone fallback failed:", err?.message);
        }
      }

      let initialHomeLayout: any = null;
      let ssrTabId: any = null;
      if (ssrLat && ssrLng) {
        // Detect device type from user agent
        const device = deviceFromUserAgent(userAgent);
        try {
          const homeRes: any = await getHomeLayoutServer({
            latitude: ssrLat,
            longitude: ssrLng,
            // No tab picked — the backend returns its first tab's layout.
            categoryId: null,
            lang,
            channel: ssrChannel,
            device,
          });
          // status 0 = store closed; a client-side state, not baked into SSR.
          if (homeRes?.status == 1 && homeRes?.data) {
            let data = homeRes.data;

            // Resolve requested tab ID from category tabs
            let requestedId = tabIdFromSlug(data?.category_tabs, tabSlugParam);
            // Shop mode key for client hydration alignment
            let ssrShopMode = ssrChannel === "ecommerce" ? "allShop" : "quick";

            // Alternative channel tab lookup if requested tab is missing
            let tabChannel = ssrChannel;
            if (!requestedId && tabSlugParam && ssrRawChannel === "both") {
              const alt = "ecommerce";
              try {
                const altRes: any = await getHomeLayoutServer({
                  latitude: ssrLat,
                  longitude: ssrLng,
                  categoryId: null,
                  lang,
                  channel: alt,
                  device,
                });
                const altId = tabIdFromSlug(altRes?.data?.category_tabs, tabSlugParam);
                if (altId) {
                  requestedId = altId;
                  tabChannel = alt;
                  ssrShopMode = "allShop";
                  data = altRes.data;
                }
              } catch (err: any) {
                console.log("SSR alt-channel tab lookup failed:", err?.message);
              }
            }

            const firstTabId = data?.category_tabs?.[0]?.id ?? null;
            if (requestedId && String(requestedId) !== String(firstTabId)) {
              try {
                const tabRes: any = await getHomeLayoutServer({
                  latitude: ssrLat,
                  longitude: ssrLng,
                  categoryId: requestedId,
                  lang,
                  // The channel the tab was FOUND in, not the zone's default.
                  channel: tabChannel,
                  device,
                });
                if (tabRes?.status == 1 && tabRes?.data) {
                  data = tabRes.data;
                  ssrTabId = requestedId;
                }
              } catch (err: any) {
                console.log("SSR home_layout tab fetch failed:", err?.message);
              }
            }

            initialHomeLayout = {
              data,
              latitude: ssrLat,
              longitude: ssrLng,
              device,
              // Category tab ID used for initial fetch
              categoryId: ssrTabId,
              // Shop mode alignment for initial home layout
              shopMode: ssrShopMode,
            };
          }
        } catch (err: any) {
          // Never fail the page on this — the client refetches on mount.
          console.log("SSR home_layout fetch failed:", err?.message);
        }
      }

      try {
        const response = await seoP;

        let metatitle = process.env.NEXT_PUBLIC_META_TITLE || null;
        let metaDescription = process.env.NEXT_PUBLIC_META_DESCRIPTION || null;
        let metaKeywords = process.env.NEXT_PUBLIC_META_KEYWORDS || null;
        let ogImage: string | null = null;
        let schemaMarkup: any = null;
        let favicon: string | null = null;

        // Select SEO settings for resolved zone or default
        const seo = selectSeoRow(response?.data, resolved?.zone?.id ?? null);
        if (seo) {
          const pick = (key: string) => pickSeoField(seo, key);
          metatitle = pick("meta_title") || metatitle;
          metaDescription = pick("meta_description") || metaDescription;
          metaKeywords = pick("meta_keyword") || metaKeywords;
          ogImage = pick("og_image_url") || ogImage;
          favicon = pick("favicon") || favicon;
          const rawSchema = pick("schema_markup");
          if (rawSchema) {
            schemaMarkup = extractJSONFromMarkup(rawSchema) || schemaMarkup;
          }
        }

        // Fall back to general settings favicon if SEO row has none
        if (!favicon) favicon = settingFavicon;

        return {
          notFoundPage: false,
          title: metatitle,
          description: metaDescription,
          keywords: metaKeywords,
          schemaMarkup:
            (schemaMarkup && typeof schemaMarkup !== "string" ? JSON.stringify(schemaMarkup) : schemaMarkup) ||
            defaultHomeSchema(),
          ogImage,
          favicon,
          zone,
          linkZone,
          lang: lang ?? null,
          langCodes,
          langDefault,
          initialHomeLayout,
          // Resolved tab slug for URL alignment
          tabSlug: ssrTabId ? tabSlugParam : null,
        };
      } catch (error) {
        console.log("error", error);
        // Fallback metadata payload retaining zone and language context
        return {
          notFoundPage: false,
          ...fallbackProps(),
          schemaMarkup: defaultHomeSchema(),
          favicon: settingFavicon,
          zone,
          linkZone,
          lang: lang ?? null,
          langCodes,
          langDefault,
          initialHomeLayout,
          tabSlug: ssrTabId ? tabSlugParam : null,
        };
      }
    } catch (fatal: any) {
      // Log fatal error and fall back to 404 response shape
      console.error("[home] fatal, serving 404:", fatal?.stack || fatal?.message || fatal);
      return {
        notFoundPage: true,
        zone: null,
        lang: lang ?? null,
        langCodes: ["en"],
        langDefault: "en",
        initialHomeLayout: null,
        tabSlug: null,
      };
    }
  },
);

async function loadForRequest(lang: string, zone: string | null, tabSlugParam: string | null) {
  const [headersList, cookieStore] = await Promise.all([headers(), cookies()]);
  const userAgent = headersList.get("user-agent") || "";
  const locationCookie = cookieStore.get(SSR_LOCATION_COOKIE)?.value || "";
  return loadHomeData(lang, zone ?? undefined, tabSlugParam, userAgent, locationCookie);
}

export async function generateHomeMetadata(lang: string, zone: string | null, tabSlugParam: string | null): Promise<Metadata> {
  const data = await loadForRequest(lang, zone, tabSlugParam);
  if (data.notFoundPage) return {};

  // Build canonical URL and hreflang alternates with tab query string
  const tabQuery = data.tabSlug ? `?tab=${encodeURIComponent(data.tabSlug)}` : "";
  const pageUrl = canonicalUrl({ lang: data.lang, zone: data.zone, path: "/", defaultCode: data.langDefault }) + tabQuery;
  const alternates = hreflangAlternates({
    zone: data.zone,
    path: "/",
    codes: data.langCodes,
    defaultCode: data.langDefault,
  }).map((alt) => ({ ...alt, href: alt.href + tabQuery }));

  return buildPageMetadata({
    title: data.title,
    description: data.description,
    keywords: data.keywords,
    pageName: "/",
    ogImage: data.ogImage,
    ogUrl: pageUrl,
    canonicalUrl: pageUrl,
    alternates,
    favicon: data.favicon,
  });
}

// Seed the SSR home layout under the same key the client query uses.
function homeLayoutSeed(seed: any) {
  if (!seed?.data) return null;
  return {
    queryKey: [
      ...homeLayoutKey({
        latitude: seed.latitude,
        longitude: seed.longitude,
        categoryId: seed.categoryId ?? null,
        shopMode: seed.shopMode,
      }),
    ],
    data: { pages: [seed.data], pageParams: [0] },
  };
}

export async function HomePageBody({ lang, zone, tabSlugParam }: { lang: string; zone: string | null; tabSlugParam: string | null }) {
  const data = await loadForRequest(lang, zone, tabSlugParam);

  // Render Custom404 UI for missing zone or invalid state
  if (data.notFoundPage) {
    // A zone slug that no longer exists (zone removed/renamed): reset the saved zone and go home.
    return zone ? <DeadZoneRedirect /> : <Custom404 />;
  }

  return (
    <>
      <LanguageCodesSeed codes={data.langCodes} />
      {data.schemaMarkup && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: data.schemaMarkup }}
        />
      )}
      {/* Provide SSR link zone for server-rendered HTML */}
      <SsrZoneProvider zone={data.linkZone ?? data.zone ?? null}>
        <QuerySeed seeds={[homeLayoutSeed(data.initialHomeLayout)]}>
          <HomePage initialHomeLayout={data.initialHomeLayout} heading={data.title} />
        </QuerySeed>
      </SsrZoneProvider>
    </>
  );
}
