import type { Metadata } from "next";
import { cache } from "react";
import axios from "axios";
import { getWithEtag } from "@/api/etagCache";
import BlogDetailPage from "@/components/pagecomponents/BlogDetailPage";
import LanguageCodesSeed from "@/app/LanguageCodesSeed";
import Custom404 from "@/components/notfound/Custom404";
import { extractJSONFromMarkup } from "@/utils/helperFunction";
import { canonicalUrl, hreflangAlternates } from "@/utils/canonicalUrl";
import { getLanguagesCached } from "@/api/languageResolver";
import { buildPageMetadata } from "@/utils/buildMetadata";

type Params = Promise<{ lang: string; slug: string }>;

type BlogSeoResult =
  | { notFound: true }
  | {
      notFound: false;
      metaTitle: string;
      metaDescription: string;
      metaKeywords: string;
      markUpSchema: string;
      ogImage: string | null;
      favicon: string | null;
      langCodes: string[];
      langDefault: string;
    };

const loadBlogData = cache(async (slug: string, lang: string): Promise<BlogSeoResult> => {
  // Languages and the blog row are independent — one round trip, not two.
  const blogP = getWithEtag(
    `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_API_SUBURL}/blogs`,
    {
      params: { slug },
      headers: { "Content-Language": lang as string },
    },
  );
  blogP.catch(() => {});
  const { codes, defaultCode: langDefault } = await getLanguagesCached();
  const langCodes = [...codes];

  try {
    const response = await blogP;

    // Missing slug returns 200 with empty data — 404 explicitly (avoid soft-404).
    const blog = response?.data?.[0];
    if (!blog) return { notFound: true };

    // Prefer translation, then root value, then env default.
    const metaKeywords =
      blog?.translations?.meta_keywords || blog?.meta_keywords || process.env.NEXT_PUBLIC_META_KEYWORDS || "";
    const metaTitle =
      blog?.translations?.meta_title || blog?.meta_title || process.env.NEXT_PUBLIC_META_TITLE || "";
    const metaDescription =
      blog?.translations?.meta_description ||
      blog?.meta_description ||
      process.env.NEXT_PUBLIC_META_DESCRIPTION ||
      "";
    const ogImage = blog?.image_url || null;
    const favicon = blog?.favicon || null;
    const schemaMarkupRaw = blog?.translations?.schema_markup || blog?.schema_markup;
    const schemaMarkupObj = schemaMarkupRaw ? extractJSONFromMarkup(schemaMarkupRaw) : null;
    const markUpSchema = schemaMarkupObj ? JSON.stringify(schemaMarkupObj) : "";

    return {
      notFound: false,
      metaTitle,
      metaDescription,
      metaKeywords,
      markUpSchema,
      ogImage,
      favicon,
      langCodes,
      langDefault,
    };
  } catch (error) {
    console.error("Error fetching product data:", error);
    return { notFound: true };
  }
});

export async function generateMetadata({
  params,
}: {
  params: Params;
}): Promise<Metadata> {
  const { lang, slug } = await params;
  const result = await loadBlogData(slug, lang);
  if (result.notFound) return {};

  // Blog URLs are zone-less (middleware 308s legacy /{zone}/blog/x).
  const path = `/blog/${slug}`;
  const pageUrl = canonicalUrl({ lang, zone: null, path, defaultCode: result.langDefault });
  const alternates = hreflangAlternates({
    zone: null,
    path,
    codes: result.langCodes,
    defaultCode: result.langDefault,
  });

  return buildPageMetadata({
    title: result.metaTitle,
    description: result.metaDescription,
    keywords: result.metaKeywords,
    pageName: "/blog/",
    ogUrl: pageUrl,
    canonicalUrl: pageUrl,
    alternates,
    ogImage: result.ogImage,
    favicon: result.favicon,
  });
}

export default async function BlogDetailRoute({
  params,
}: {
  params: Params;
}) {
  const { lang, slug } = await params;
  const result = await loadBlogData(slug, lang);

  // In-page Custom404, not notFound(): rewritten routes calling notFound()
  // serve Next's generic UI instead of the custom design.
  if (result.notFound) {
    return <Custom404 />;
  }

  return (
    <div>
      <LanguageCodesSeed codes={result.langCodes} />
      {result.markUpSchema && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: result.markUpSchema }}
        />
      )}
      <BlogDetailPage />
    </div>
  );
}
