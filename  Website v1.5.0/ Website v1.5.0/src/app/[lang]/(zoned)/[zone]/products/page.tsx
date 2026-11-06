import type { Metadata } from "next";
import { cache } from "react";
import { notFound } from "next/navigation";
import axios from "axios";
import { getWithEtag } from "@/api/etagCache";
import Productspage from "@/components/pagecomponents/Productspage";
import LanguageCodesSeed from "@/app/LanguageCodesSeed";
import QuerySeed from "@/app/QuerySeed";
import {
  productsKey,
  productsFilterKeyPart,
  SSR_PRODUCT_FILTER_DEFAULTS,
} from "@/utils/queryKeys";
import { extractJSONFromMarkup } from "@/utils/helperFunction";
import { selectSeoRow, pickSeoField } from "@/utils/selectSeoRow";
import { resolveZoneBySlug } from "@/api/zoneResolver";
import { canonicalUrl, hreflangAlternates } from "@/utils/canonicalUrl";
import { getLanguagesCached } from "@/api/languageResolver";
import {
  getProductListingServer,
  getCategoriesTreeServer,
} from "@/api/serverApi";
import {
  parseFilterFromQuery,
  buildFilterApiParams,
  hasNoFilterParams,
} from "@/utils/urlProductFilters";
import { resolveSlugCsvToIdCsv } from "@/utils/categorySlugResolver";
import { buildPageMetadata } from "@/utils/buildMetadata";

// Must match ProductsList's `total_products_per_page` or offsets diverge.
const PRODUCTS_PER_PAGE = 12;

type Params = Promise<{ lang: string; zone: string }>;
type SearchParams = Promise<Record<string, string | string[] | undefined>>;

type ProductsPageData = {
  notFoundZone: boolean;
  title?: string | null;
  description?: string | null;
  keywords?: string | null;
  schemaMarkup?: string | null;
  ogImage?: string | null;
  favicon?: string | null;
  zone: string | null;
  lang: string | null;
  langCodes: string[];
  langDefault: string;
  initialProducts: any;
};

const loadProductsData = cache(async (lang: string, zoneSlug: string, query: Record<string, any>): Promise<ProductsPageData> => {
  // Languages don't depend on the zone — overlap the two requests.
  const langP = getLanguagesCached();
  langP.catch(() => {});
  // Unknown zone → 404.
  const resolved = await resolveZoneBySlug(zoneSlug);
  if (!resolved) {
    return {
      notFoundZone: true,
      zone: null,
      lang: lang ?? null,
      langCodes: ["en"],
      langDefault: "en",
      initialProducts: null,
    };
  }
  const zone = resolved.zone.slug;
  const { codes, defaultCode: langDefault } = await langP;
  const langCodes = [...codes];

  // Zone centroid (API requires lat/lng). Null when zone has no polygon — then
  // skip SSR; never invent coords (would show another zone's catalogue).
  const ssrLat = resolved.latitude;
  const ssrLng = resolved.longitude;
  const ssrChannel = resolved.channel;

  // Same URL filters the client reads, so filtered links SSR correctly.
  const urlFilter = parseFilterFromQuery(query);
  const isUnfiltered = hasNoFilterParams(query);
  let initialProducts: any = null;
  if (ssrLat && ssrLng) {
    try {
      // category_id is a slug CSV — resolve to ids via the (cached) full tree.
      let apiFilter = urlFilter;
      if (!isUnfiltered && urlFilter.category_id) {
        try {
          const tree: any = await getCategoriesTreeServer({
            latitude: ssrLat,
            longitude: ssrLng,
            lang,
            channel: ssrChannel,
          });
          const resolvedIds = resolveSlugCsvToIdCsv(tree?.data ?? [], urlFilter.category_id);
          apiFilter = { ...urlFilter, category_id: resolvedIds };
        } catch (err: any) {
          // Non-fatal — fall through with the unresolved slug.
          console.log("[products] category tree resolve failed:", err?.message);
        }
      }
      const listing: any = await getProductListingServer({
        latitude: ssrLat,
        longitude: ssrLng,
        channel: ssrChannel,
        lang,
        limit: PRODUCTS_PER_PAGE,
        offset: 0,
        filters: isUnfiltered ? undefined : buildFilterApiParams(apiFilter),
      });
      // status 0 (store closed) is left to the client.
      if (listing?.status == 1) {
        initialProducts = {
          envelope: listing,
          latitude: ssrLat,
          longitude: ssrLng,
          // ProductsList reuses the seed only if its own filter matches.
          filter: urlFilter,
        };
      }
    } catch (err: any) {
      // Non-fatal — client refetches on mount.
      console.log("[products] listing fetch failed:", err?.message);
    }
  }

  const defaults = {
    title: process.env.NEXT_PUBLIC_META_TITLE,
    description: process.env.NEXT_PUBLIC_META_DESCRIPTION,
    keywords: process.env.NEXT_PUBLIC_META_KEYWORDS,
    schemaMarkup: null as string | null,
    ogImage: "",
    favicon: null as string | null,
  };

  try {
    const response = await getWithEtag(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_API_SUBURL}/settings/get_seo_settings`,
      {
        params: { page_type: "Product listing page" },
        headers: { "Content-Language": lang as string },
      },
    );

    let metatitle = defaults.title;
    let metaDescription = defaults.description;
    let metaKeywords = defaults.keywords;
    let schemaMarkup: any = null;
    let ogImage = defaults.ogImage;
    let favicon = defaults.favicon;

    // Zone row when the zone has its own SEO override, else the is_default row.
    const seo = selectSeoRow(response?.data, resolved.zone.id);
    if (seo) {
      const pick = (key: string) => pickSeoField(seo, key);
      metatitle = pick("meta_title") || defaults.title;
      metaDescription = pick("meta_description") || defaults.description;
      metaKeywords = pick("meta_keyword") || defaults.keywords;
      ogImage = pick("og_image_url") || defaults.ogImage;
      favicon = pick("favicon");
      const rawSchema = pick("schema_markup");
      if (rawSchema) {
        schemaMarkup = extractJSONFromMarkup(rawSchema) || defaults.schemaMarkup;
      }
    }

    return {
      notFoundZone: false,
      title: metatitle,
      description: metaDescription,
      keywords: metaKeywords,
      schemaMarkup: schemaMarkup ? JSON.stringify(schemaMarkup) : null,
      ogImage,
      favicon: favicon ? favicon : null,
      zone,
      lang: lang ?? null,
      langCodes,
      langDefault,
      initialProducts,
    };
  } catch (error) {
    console.log("error", error);
    // SEO failure keeps the resolved zone and SSR products.
    return {
      notFoundZone: false,
      ...defaults,
      zone,
      lang: lang ?? null,
      langCodes,
      langDefault,
      initialProducts,
    };
  }
});

export async function generateMetadata({
  params,
  searchParams,
}: {
  params: Params;
  searchParams: SearchParams;
}): Promise<Metadata> {
  const { lang, zone } = await params;
  const query = await searchParams;
  const data = await loadProductsData(lang, zone, query);
  if (data.notFoundZone) return {};

  // Self-canonical across lang + zone; hreflang links translations.
  const pageUrl = canonicalUrl({ lang: data.lang, zone: data.zone, path: "/products", defaultCode: data.langDefault });
  const alternates = hreflangAlternates({
    zone: data.zone,
    path: "/products",
    codes: data.langCodes,
    defaultCode: data.langDefault,
  });

  return buildPageMetadata({
    title: data.title,
    description: data.description,
    keywords: data.keywords,
    pageName: "/products",
    ogImage: data.ogImage,
    ogUrl: pageUrl,
    canonicalUrl: pageUrl,
    alternates,
    favicon: data.favicon,
  });
}

// Mirrors the pre-hydration key ProductsList builds on the server render:
// redux browse filters at their defaults, category ids unresolved, quick mode.
function productsSeed(seed: any) {
  if (!seed?.envelope) return null;
  const filter = { ...(seed.filter ?? {}), ...SSR_PRODUCT_FILTER_DEFAULTS };
  return {
    queryKey: [
      ...productsKey({
        filter: productsFilterKeyPart(filter, seed.filter?.search),
        categoryIds: null,
        latitude: seed.latitude,
        longitude: seed.longitude,
        shopMode: "quick",
      }),
    ],
    data: { pages: [seed.envelope], pageParams: [0] },
  };
}

export default async function ZoneProductsRoute({
  params,
  searchParams,
}: {
  params: Params;
  searchParams: SearchParams;
}) {
  const { lang, zone } = await params;
  const query = await searchParams;
  const data = await loadProductsData(lang, zone, query);
  if (data.notFoundZone) notFound();

  return (
    <>
      <LanguageCodesSeed codes={data.langCodes} />
      {data.schemaMarkup && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: data.schemaMarkup }}
        />
      )}
      <QuerySeed seeds={[productsSeed(data.initialProducts)]}>
        <Productspage initialProducts={data.initialProducts} />
      </QuerySeed>
    </>
  );
}
