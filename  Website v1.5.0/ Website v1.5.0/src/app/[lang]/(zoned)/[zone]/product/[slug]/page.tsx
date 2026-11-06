import type { Metadata } from "next";
import { cache } from "react";
import axios from "axios";
import { notFound } from "next/navigation";
import ProductDescriptionPage from "@/components/pagecomponents/ProductDescriptionPage";
import QuerySeed from "@/app/QuerySeed";
import { productKey } from "@/utils/queryKeys";
import LanguageCodesSeed from "@/app/LanguageCodesSeed";
import { extractJSONFromMarkup } from "@/utils/helperFunction";
import { getProductByIdServer } from "@/api/serverApi";
import { resolveZoneBySlug } from "@/api/zoneResolver";
import { canonicalUrl, hreflangAlternates } from "@/utils/canonicalUrl";
import { getLanguagesCached } from "@/api/languageResolver";
import { buildPageMetadata } from "@/utils/buildMetadata";

// Product + Offer JSON-LD from the SSR product, used only when the admin set no
// schema_markup. Returns a JSON string, or null if data is insufficient.
const buildProductSchema = ({
  productRes,
  slug,
  pageUrl,
}: {
  productRes: any;
  slug: string;
  pageUrl: string;
}) => {
  const p = productRes?.data?.[0] || productRes?.data;
  if (!p) return null;

  // discounted_price is 0 when there's no discount.
  const variant = Array.isArray(p?.variants) ? p.variants[0] : null;
  const rawPrice =
    (variant?.discounted_price && Number(variant.discounted_price) > 0
      ? variant.discounted_price
      : variant?.price) ??
    p?.min_price ??
    p?.price;
  const price = Number(rawPrice);
  if (!price || Number.isNaN(price)) return null;

  // ISO 4217 only (`currency` is the symbol). Some API codes are malformed
  // ("971", "NZ$") — omit rather than invalidate the Offer.
  const rawCurrency = p?.currency_code || productRes?.currency_code;
  const currency = /^[A-Z]{3}$/.test(String(rawCurrency || "").toUpperCase())
    ? String(rawCurrency).toUpperCase()
    : undefined;
  const image =
    p?.image_url ||
    (typeof p?.images?.[0] === "string" ? p.images[0] : p?.images?.[0]?.image_url) ||
    undefined;

  const inStock = Array.isArray(p?.variants)
    ? p.variants.some((v: any) => Number(v?.stock) > 0 || Number(v?.is_unlimited_stock) === 1)
    : Number(p?.stock) > 0;

  const offer: any = {
    "@type": "Offer",
    price: price.toFixed(2),
    availability: inStock ? "https://schema.org/InStock" : "https://schema.org/OutOfStock",
    url: pageUrl,
  };
  if (currency) offer.priceCurrency = currency;

  const schema: any = {
    "@context": "https://schema.org",
    "@type": "Product",
    name: p?.name || p?.title || slug,
    offers: offer,
  };
  if (image) schema.image = image;
  if (p?.short_description || p?.description) {
    schema.description = String(p.short_description || p.description)
      .replace(/<[^>]*>/g, "")
      .trim()
      .slice(0, 500);
  }
  const rating = Number(p?.average_rating ?? p?.rating);
  const ratingCount = Number(p?.total_reviews ?? p?.rating_count);
  if (rating > 0 && ratingCount > 0) {
    schema.aggregateRating = {
      "@type": "AggregateRating",
      ratingValue: rating.toFixed(1),
      reviewCount: ratingCount,
    };
  }
  return JSON.stringify(schema);
};

type Params = Promise<{ lang: string; zone: string; slug: string }>;

type ProductPageData = {
  notFoundPage: boolean;
  slug: string;
  title?: string | null;
  description?: string | null;
  keywords?: string | null;
  og_image?: string | null;
  schemaMarkup?: string | null;
  favicon?: string | null;
  initialProduct: any;
  initialProductMeta?: any;
  zone: string | null;
  lang: string | null;
  langCodes: string[];
  langDefault: string;
};

const loadProductData = cache(
  async (slug: string, lang: string, zoneSlug: string): Promise<ProductPageData> => {
    // Assigned before try — the catch block reads them.
    let langCodes = ["en"];
    let langDefault = "en";
    try {
      const langs = await getLanguagesCached();
      langCodes = [...langs.codes];
      langDefault = langs.defaultCode;

      const seoPromise = axios.get(
        `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_API_SUBURL}/products/get_seo`,
        {
          params: { slug },
          headers: { "Content-Language": lang },
        },
      );

      // Chained on the zone (needs its coords), overlapping get_seo.
      const productPromise = resolveZoneBySlug(zoneSlug).then(async (zone: any) => {
        if (!zone)
          return { resolved: null, initialProduct: null, initialProductMeta: null };
        try {
          const productRes = await getProductByIdServer({
            slug,
            latitude: zone.latitude,
            longitude: zone.longitude,
            lang,
            channel: zone.channel,
          });
          const ok = productRes?.status == 1 && productRes?.data;
          return {
            resolved: zone,
            initialProduct: ok ? productRes : null,
            initialProductMeta: ok
              ? {
                  latitude: zone.latitude,
                  longitude: zone.longitude,
                  shopMode: zone.channel === "ecommerce" ? "allShop" : "quick",
                }
              : null,
          };
        } catch (err: any) {
          // Never fail the page on this — the client refetches on mount.
          console.log("SSR product fetch failed:", err?.message);
          return { resolved: zone, initialProduct: null, initialProductMeta: null };
        }
      });

      const [response, { resolved, initialProduct, initialProductMeta }] = await Promise.all([
        seoPromise,
        productPromise,
      ]);

      // Truthiness, not `!= null` — API sends "" for unset SEO fields.
      const isMetadata =
        !!response.data.data?.meta_title &&
        !!response.data.data?.meta_description &&
        !!response.data.data?.meta_keywords;

      // No admin SEO → use product name/description so pages aren't duplicates.
      const p = initialProduct?.data?.[0] || initialProduct?.data;
      const productName: string | undefined = p?.name || p?.title;
      const productDescription: string | undefined = p?.short_description || p?.description
        ? String(p.short_description || p.description)
            .replace(/<[^>]*>/g, "")
            .trim()
            .slice(0, 160)
        : undefined;

      const productImage: string | undefined =
        p?.image_url ||
        (typeof p?.images?.[0] === "string" ? p.images[0] : p?.images?.[0]?.image_url) ||
        undefined;

      let metatitle = productName || process.env.NEXT_PUBLIC_META_TITLE;
      let metaDescription = productDescription || process.env.NEXT_PUBLIC_META_DESCRIPTION;
      let metaKeywords = process.env.NEXT_PUBLIC_META_KEYWORDS;
      let schemaMarkup: any = null;
      let og_image = productImage || null;
      let favicon = null;
      if (isMetadata) {
        const seoData = response.data.data;
        metatitle = seoData?.meta_title;
        metaDescription = seoData?.meta_description;
        metaKeywords = seoData?.meta_keywords;
        og_image = seoData?.og_image;
        favicon = seoData?.favicon;
        if (seoData?.schema_markup) {
          schemaMarkup = extractJSONFromMarkup(seoData?.schema_markup);
        }
      }

      // Unknown zone → 404.
      if (!resolved) {
        return {
          notFoundPage: true,
          slug,
          initialProduct: null,
          zone: null,
          lang: lang ?? null,
          langCodes,
          langDefault,
        };
      }

      // Admin schema wins; otherwise generate one.
      if (!schemaMarkup && initialProduct) {
        try {
          const offerUrl = canonicalUrl({
            lang,
            zone: resolved.zone.slug,
            path: `/product/${slug}`,
            defaultCode: langDefault,
          });
          const productSchema = buildProductSchema({
            productRes: initialProduct,
            slug,
            pageUrl: offerUrl,
          });
          if (productSchema) schemaMarkup = productSchema;
        } catch (err: any) {
          console.log("SSR product schema build failed:", err?.message);
        }
      }

      return {
        notFoundPage: false,
        slug,
        title: metatitle,
        description: metaDescription,
        keywords: metaKeywords,
        og_image,
        // Admin schema is an object, generated one already a string.
        schemaMarkup: schemaMarkup
          ? typeof schemaMarkup === "string"
            ? schemaMarkup
            : JSON.stringify(schemaMarkup)
          : null,
        favicon: favicon ? favicon : null,
        initialProduct,
        initialProductMeta,
        zone: resolved.zone.slug,
        lang: lang ?? null,
        langCodes,
        langDefault,
      };
    } catch (error) {
      console.log("error", error);
      // Failed SEO fetch must not 404 — env defaults; client refetches product.
      return {
        notFoundPage: false,
        slug,
        title: process.env.NEXT_PUBLIC_META_TITLE ?? null,
        description: process.env.NEXT_PUBLIC_META_DESCRIPTION ?? null,
        keywords: process.env.NEXT_PUBLIC_META_KEYWORDS ?? null,
        og_image: null,
        schemaMarkup: null,
        favicon: null,
        initialProduct: null,
        // Unvalidated — resolver may not have run.
        zone: zoneSlug,
        lang: lang ?? null,
        langCodes,
        langDefault,
      };
    }
  },
);

export async function generateMetadata({ params }: { params: Params }): Promise<Metadata> {
  const { lang, zone, slug } = await params;
  const data = await loadProductData(slug, lang, zone);
  if (data.notFoundPage) return {};

  // Self-canonical across lang + zone; hreflang links translations.
  const path = `/product/${slug}`;
  const pageUrl = canonicalUrl({ lang: data.lang, zone: data.zone, path, defaultCode: data.langDefault });
  const alternates = hreflangAlternates({
    zone: data.zone,
    path,
    codes: data.langCodes,
    defaultCode: data.langDefault,
  });

  return buildPageMetadata({
    title: data.title,
    description: data.description,
    keywords: data.keywords,
    pageName: "/product/",
    ogUrl: pageUrl,
    canonicalUrl: pageUrl,
    alternates,
    ogImage: data.og_image,
    favicon: data.favicon,
  });
}

export default async function ZoneProductRoute({ params }: { params: Params }) {
  const { lang, zone, slug } = await params;
  const data = await loadProductData(slug, lang, zone);

  // Real HTTP 404 via not-found.tsx.
  if (data.notFoundPage) {
    notFound();
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
      <QuerySeed
        seeds={[
          data.initialProduct
            ? {
                queryKey: [
                  ...productKey({
                    slug,
                    latitude: data.initialProductMeta?.latitude,
                    longitude: data.initialProductMeta?.longitude,
                    shopMode: data.initialProductMeta?.shopMode,
                  }),
                ],
                data: data.initialProduct,
                // Matches the old initialDataUpdatedAt: 0 — still revalidates.
                updatedAt: 0,
              }
            : null,
        ]}
      >
        <ProductDescriptionPage
          initialProduct={data.initialProduct}
          initialProductMeta={data.initialProductMeta}
        />
      </QuerySeed>
    </>
  );
}
