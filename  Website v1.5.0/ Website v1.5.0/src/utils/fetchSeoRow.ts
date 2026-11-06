import axios from "axios";
import { extractJSONFromMarkup } from "@/utils/helperFunction";
import { selectSeoRow, pickSeoField } from "@/utils/selectSeoRow";
import { resolveZoneBySlug } from "@/api/zoneResolver";

export type SeoPageData = {
  title: string;
  description: string;
  keywords: string;
  schemaMarkup: string | null;
  ogImage: string;
  favicon: string | null;
};

const defaultSeoData = (): SeoPageData => ({
  title: process.env.NEXT_PUBLIC_META_TITLE || "",
  description: process.env.NEXT_PUBLIC_META_DESCRIPTION || "",
  keywords: process.env.NEXT_PUBLIC_META_KEYWORDS || "",
  schemaMarkup: null,
  ogImage: "",
  favicon: null,
});

// Fetches and shapes the SEO row for one static content page_type, shared by
// every content-page route. zoneId is optional: zone-aware pages pass it so
// that zone's own row wins over is_default (see selectSeoRow).
export async function fetchSeoRow(
  pageType: string,
  lang?: string | null,
  zoneId?: number | null,
): Promise<SeoPageData> {
  const defaults = defaultSeoData();
  try {
    const response = await axios.get(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_API_SUBURL}/settings/get_seo_settings`,
      {
        params: { page_type: pageType },
        headers: { "Content-Language": lang },
      },
    );
    const seo = selectSeoRow(response.data.data, zoneId ?? null);
    if (!seo) return defaults;

    const pick = (key: string) => pickSeoField(seo, key);
    const rawSchema = pick("schema_markup");
    const schemaMarkup = rawSchema ? extractJSONFromMarkup(rawSchema) : null;

    return {
      title: pick("meta_title") || defaults.title,
      description: pick("meta_description") || defaults.description,
      keywords: pick("meta_keyword") || defaults.keywords,
      ogImage: pick("og_image_url") || defaults.ogImage,
      schemaMarkup: schemaMarkup ? JSON.stringify(schemaMarkup) : null,
      favicon: pick("favicon") || defaults.favicon,
    };
  } catch (error) {
    console.log("error", error);
    return defaults;
  }
}

// Resolves `?zone=` to a zone id for selectSeoRow. Unresolvable slug = dead
// URL, so the caller should 404 rather than silently serve is_default.
export async function resolveZoneForSeo(
  zoneSlug?: string | null,
): Promise<{ zoneId: number | null; notFound: boolean }> {
  if (!zoneSlug) return { zoneId: null, notFound: false };
  const resolved = await resolveZoneBySlug(zoneSlug);
  if (!resolved) return { zoneId: null, notFound: true };
  return { zoneId: resolved.zone?.id ?? null, notFound: false };
}
