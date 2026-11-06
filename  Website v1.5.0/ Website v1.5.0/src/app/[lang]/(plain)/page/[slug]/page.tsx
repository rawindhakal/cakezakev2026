import type { Metadata } from "next";
import { cache } from "react";
import { cookies, headers } from "next/headers";
import Custom404 from "@/components/notfound/Custom404";
import PageBuilderView from "@/components/pagebuilder/PageBuilderView";
import QuerySeed from "@/app/QuerySeed";
import { pageBuilderKey } from "@/utils/queryKeys";
import { PAGE_BUILDER_SECTION_LIMIT } from "@/constants/homeLayout";
import LanguageCodesSeed from "@/app/LanguageCodesSeed";
import { getLanguagesCached } from "@/api/languageResolver";
import { getPageBuilderServer, getSettingServer } from "@/api/serverApi";
import { firstZoneLocation } from "@/api/zoneResolver";
import { deviceFromUserAgent } from "@/utils/deviceFromUserAgent";
import { canonicalUrl, hreflangAlternates } from "@/utils/canonicalUrl";
import { buildPageMetadata } from "@/utils/buildMetadata";
import { SSR_LOCATION_COOKIE, parseSsrLocation } from "@/utils/ssrLocationCookie";

type Params = Promise<{ lang: string; slug: string }>;

type PageBuilderResult =
  | { notFound: true }
  | {
      notFound: false;
      title: string;
      description: string | null;
      keywords: string | null;
      favicon: string | null;
      schemaMarkup: string | null;
      langCodes: string[];
      langDefault: string;
      initialPage: any;
    };

// Zone-less route: coords only seed product sections with a serviceable
// location. One settings call gives both coords and the SSR favicon.
const resolveSsrContext = async (
  clientLocation: { latitude: number; longitude: number } | null,
): Promise<{
  latitude: number | null;
  longitude: number | null;
  favicon: string | null;
}> => {
  let favicon: string | null = null;
  try {
    const settingRes: any = await getSettingServer({});
    const settingData =
      typeof settingRes?.data === "string" ? JSON.parse(atob(settingRes.data)) : settingRes?.data;
    favicon = settingData?.favicon || null;
    // Visitor location beats default_city — avoids a post-hydration refetch.
    if (clientLocation) {
      return { ...clientLocation, favicon };
    }
    const dc = settingData?.default_city;
    if (dc?.latitude && dc?.longitude) {
      return { latitude: dc.latitude, longitude: dc.longitude, favicon };
    }
  } catch (err: any) {
    console.log("SSR page settings fetch failed:", err?.message);
  }
  if (clientLocation) {
    return { ...clientLocation, favicon };
  }
  try {
    const fallback = await firstZoneLocation();
    if (fallback) {
      return { latitude: fallback.latitude, longitude: fallback.longitude, favicon };
    }
  } catch (err: any) {
    console.log("SSR page zone fallback failed:", err?.message);
  }
  return { latitude: null, longitude: null, favicon };
};

const loadPageData = cache(
  async (
    slug: string,
    lang: string,
    userAgent: string,
    // Raw `lat,lng` cookie — in the cache key so locations don't share renders.
    locationCookie: string,
  ): Promise<PageBuilderResult> => {
    // Languages and the SSR location/settings lookup are independent.
    const ctxP = resolveSsrContext(parseSsrLocation(locationCookie));
    ctxP.catch(() => {});
    const { codes, defaultCode: langDefault } = await getLanguagesCached();
    const langCodes = [...codes];

    try {
      const { latitude, longitude, favicon } = await ctxP;
      if (!latitude || !longitude) return { notFound: true };

      const device = deviceFromUserAgent(userAgent);
      const response: any = await getPageBuilderServer({
        slug,
        latitude,
        longitude,
        lang,
        limit: PAGE_BUILDER_SECTION_LIMIT,
        offset: 0,
      });
      const page = response?.data?.page;
      if (!page || !Array.isArray(page?.sections) || page.sections.length === 0) {
        return { notFound: true };
      }

      // Payload has no SEO fields — derive from title/name, then env defaults.
      const title = page?.title || page?.name || "";
      const description =
        page?.name && page?.title && page.name !== page.title
          ? `${page.title} — ${page.name}`
          : process.env.NEXT_PUBLIC_META_DESCRIPTION || null;

      // Minimal WebPage JSON-LD.
      const baseUrl = process.env.NEXT_PUBLIC_BASE_URL;
      const schemaMarkup = baseUrl
        ? JSON.stringify({
            "@context": "https://schema.org",
            "@type": "WebPage",
            "@id": `${baseUrl}/page/${slug}#webpage`,
            url: `${baseUrl}/page/${slug}`,
            name: title || page?.name || slug,
            ...(description ? { description } : {}),
            isPartOf: {
              "@type": "WebSite",
              "@id": `${baseUrl}/#website`,
              url: baseUrl,
              ...(process.env.NEXT_PUBLIC_META_TITLE
                ? { name: process.env.NEXT_PUBLIC_META_TITLE }
                : {}),
            },
          })
        : null;

      return {
        notFound: false,
        title,
        description,
        keywords: process.env.NEXT_PUBLIC_META_KEYWORDS || null,
        favicon,
        schemaMarkup,
        langCodes,
        langDefault,
        initialPage: { data: response.data, latitude, longitude, device },
      };
    } catch (error: any) {
      console.error("Error fetching page_builder data:", error?.message);
      return { notFound: true };
    }
  },
);

async function loadForRequest(lang: string, slug: string) {
  const [headersList, cookieStore] = await Promise.all([headers(), cookies()]);
  const userAgent = headersList.get("user-agent") || "";
  const locationCookie = cookieStore.get(SSR_LOCATION_COOKIE)?.value || "";
  return loadPageData(slug, lang, userAgent, locationCookie);
}

export async function generateMetadata({ params }: { params: Params }): Promise<Metadata> {
  const { lang, slug } = await params;
  const result = await loadForRequest(lang, slug);
  if (result.notFound) return {};

  const path = `/page/${slug}`;
  const pageUrl = canonicalUrl({ lang, zone: null, path, defaultCode: result.langDefault });
  const alternates = hreflangAlternates({
    zone: null,
    path,
    codes: result.langCodes,
    defaultCode: result.langDefault,
  });

  return buildPageMetadata({
    title: result.title,
    description: result.description,
    keywords: result.keywords,
    pageName: "/page/",
    ogUrl: pageUrl,
    canonicalUrl: pageUrl,
    alternates,
    favicon: result.favicon,
  });
}

export default async function PageBuilderRoute({ params }: { params: Params }) {
  const { lang, slug } = await params;
  const result = await loadForRequest(lang, slug);

  // In-page Custom404, not notFound(): rewritten routes calling notFound()
  // serve Next's generic UI instead of the custom design.
  if (result.notFound) {
    return <Custom404 />;
  }

  return (
    <div>
      <LanguageCodesSeed codes={result.langCodes} />
      {result.schemaMarkup && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: result.schemaMarkup }}
        />
      )}
      <QuerySeed
        seeds={[
          result.initialPage?.data
            ? {
                queryKey: [
                  ...pageBuilderKey({
                    slug,
                    latitude: result.initialPage.latitude,
                    longitude: result.initialPage.longitude,
                  }),
                ],
                data: { pages: [result.initialPage.data], pageParams: [0] },
              }
            : null,
        ]}
      >
        <PageBuilderView slug={slug} initialPage={result.initialPage} />
      </QuerySeed>
    </div>
  );
}
