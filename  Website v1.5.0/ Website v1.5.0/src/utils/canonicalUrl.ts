import { DEFAULT_LANGUAGE } from "@/utils/languageRoutes";

// Canonical/hreflang URLs for a localized, zone-prefixed page.
// Segment order: /{lang?}/{zone?}/{path}; default language is never prefixed.
// defaultCode always comes from the languages API, never hardcoded.

// Strip a trailing slash so the joined URL can't become "https://host//path".
const BASE = (process.env.NEXT_PUBLIC_BASE_URL || "").replace(/\/+$/, "");

/** Relative localized path; canonicalUrl and useZoneHref both build on this. */
export const buildLocalizedPath = ({
  lang,
  zone,
  path = "/",
  defaultCode,
}: {
  lang?: string | null;
  zone?: string | null;
  path?: string;
  defaultCode?: string | null;
} = {}): string => {
  const def = defaultCode || DEFAULT_LANGUAGE;
  const segments: string[] = [];
  if (lang && lang !== def) segments.push(lang);
  if (zone) segments.push(zone);

  const cleanPath = path === "/" ? "" : path.replace(/^\//, "");
  if (cleanPath) segments.push(cleanPath);

  return segments.length ? `/${segments.join("/")}` : "/";
};

/** Absolute URL for one (lang, zone, path) combination. */
export const canonicalUrl = ({
  lang,
  zone,
  path = "/",
  defaultCode,
}: {
  lang?: string | null;
  zone?: string | null;
  path?: string;
  defaultCode?: string | null;
} = {}): string => {
  const localized = buildLocalizedPath({ lang, zone, path, defaultCode });
  return `${BASE}${localized === "/" ? "" : localized}`;
};

/** hreflang alternates: one per language, plus x-default. */
export const hreflangAlternates = ({
  zone,
  path = "/",
  codes = [],
  defaultCode,
}: {
  zone?: string | null;
  path?: string;
  codes?: string[];
  defaultCode?: string | null;
} = {}): { hrefLang: string; href: string }[] => {
  const def = defaultCode || DEFAULT_LANGUAGE;
  // Dedupe; keep the default present even if the list is momentarily empty.
  const all = [...new Set([def, ...codes])];
  const alternates = all.map((lang) => ({
    hrefLang: lang,
    href: canonicalUrl({ lang, zone, path, defaultCode: def }),
  }));
  alternates.push({
    hrefLang: "x-default",
    href: canonicalUrl({ lang: def, zone, path, defaultCode: def }),
  });
  return alternates;
};
