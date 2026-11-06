import type { Metadata } from "next";
import { cache } from "react";
import ContactUsPage from "@/components/pagecomponents/ContactUsPage";
import { fetchSeoRow } from "@/utils/fetchSeoRow";
import { buildPageMetadata } from "@/utils/buildMetadata";
import { canonicalUrl, hreflangAlternates } from "@/utils/canonicalUrl";
import { getLanguagesCached } from "@/api/languageResolver";
import LanguageCodesSeed from "@/app/LanguageCodesSeed";

type Params = Promise<{ lang: string }>;

// cache() dedupes the fetch shared by generateMetadata and the page.
const loadContactUsSeo = cache((lang: string) => fetchSeoRow("Contact us", lang));

const loadLangInfo = cache(async () => {
  const { codes, defaultCode } = await getLanguagesCached();
  return { langCodes: [...codes], defaultCode };
});

// Global route: language-only, never zone-prefixed (see zonePrefixable.ts).
const PATH = "/contact-us";

export async function generateMetadata({
  params,
}: {
  params: Params;
}): Promise<Metadata> {
  const { lang } = await params;
  const [seo, { langCodes, defaultCode }] = await Promise.all([
    loadContactUsSeo(lang),
    loadLangInfo(),
  ]);

  const pageUrl = canonicalUrl({ lang, zone: null, path: PATH, defaultCode });
  const alternates = hreflangAlternates({
    zone: null,
    path: PATH,
    codes: langCodes,
    defaultCode,
  });

  return buildPageMetadata({
    title: seo.title,
    description: seo.description,
    keywords: seo.keywords,
    pageName: PATH,
    ogImage: seo.ogImage,
    ogUrl: pageUrl,
    canonicalUrl: pageUrl,
    alternates,
    favicon: seo.favicon,
  });
}

export default async function ContactUsRoute({
  params,
}: {
  params: Params;
}) {
  const { lang } = await params;
  const [seo, { langCodes }] = await Promise.all([loadContactUsSeo(lang), loadLangInfo()]);

  return (
    <div>
      <LanguageCodesSeed codes={langCodes} />
      {seo.schemaMarkup && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: seo.schemaMarkup }}
        />
      )}
      {/* SEO H1 — page body has none, so visually hidden. */}
      {seo.title && <h1 className="sr-only">{seo.title}</h1>}
      <ContactUsPage />
    </div>
  );
}
