import type { Metadata } from "next";
import { cache } from "react";
import { notFound } from "next/navigation";
import ShippingPolicyPage from "@/components/pagecomponents/ShippingPolicyPage";
import { fetchSeoRow, resolveZoneForSeo } from "@/utils/fetchSeoRow";
import { buildPageMetadata } from "@/utils/buildMetadata";
import { canonicalUrl, hreflangAlternates } from "@/utils/canonicalUrl";
import { getLanguagesCached } from "@/api/languageResolver";
import LanguageCodesSeed from "@/app/LanguageCodesSeed";

type Params = Promise<{ lang: string }>;

// Never zone-prefixed — resolveZoneForSeo(undefined) gives the default SEO row.
const loadShippingPolicySeo = cache(async (lang: string) => {
  const { zoneId, notFound: zoneNotFound } = await resolveZoneForSeo(undefined);
  if (zoneNotFound) return { notFound: true as const };
  const seo = await fetchSeoRow("Shipping policy", lang, zoneId);
  const { codes, defaultCode: langDefault } = await getLanguagesCached();
  return { notFound: false as const, seo, langCodes: [...codes], langDefault };
});

const PATH = "/shipping-policy";

export async function generateMetadata({
  params,
}: {
  params: Params;
}): Promise<Metadata> {
  const { lang } = await params;
  const result = await loadShippingPolicySeo(lang);
  if (result.notFound) return {};

  const pageUrl = canonicalUrl({
    lang,
    zone: null,
    path: PATH,
    defaultCode: result.langDefault,
  });
  const alternates = hreflangAlternates({
    zone: null,
    path: PATH,
    codes: result.langCodes,
    defaultCode: result.langDefault,
  });

  return buildPageMetadata({
    title: result.seo.title,
    description: result.seo.description,
    keywords: result.seo.keywords,
    pageName: PATH,
    ogImage: result.seo.ogImage,
    ogUrl: pageUrl,
    canonicalUrl: pageUrl,
    alternates,
    favicon: result.seo.favicon,
  });
}

export default async function ShippingPolicyRoute({
  params,
}: {
  params: Params;
}) {
  const { lang } = await params;
  const result = await loadShippingPolicySeo(lang);
  if (result.notFound) notFound();

  return (
    <div>
      <LanguageCodesSeed codes={result.langCodes} />
      {result.seo.schemaMarkup && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: result.seo.schemaMarkup }}
        />
      )}
      {/* SEO H1 — CMS body has none, so visually hidden. */}
      {result.seo.title && <h1 className="sr-only">{result.seo.title}</h1>}
      <ShippingPolicyPage />
    </div>
  );
}
