// Language URL routing helpers for dynamic language code prefix handling.

export const DEFAULT_LANGUAGE = "en";

/** Checks if a path segment is a non-default language prefix. */
export const isLanguagePrefix = (
  segment?: string | null,
  {
    codes,
    defaultCode,
  }: { codes?: Set<string>; defaultCode?: string | null } = {},
): boolean => {
  if (!segment || !codes) return false;
  const def = defaultCode || DEFAULT_LANGUAGE;
  return segment !== def && codes.has(segment);
};

/** Parses a pathname into optional language prefix and remaining path segments. */
export const parseLangPath = (
  pathname = "",
  langInfo: { codes?: Set<string>; defaultCode?: string | null } = {},
): { lang: string | null; rest: string[] } => {
  const segments = pathname.split("/").filter(Boolean);
  if (segments.length >= 1 && isLanguagePrefix(segments[0], langInfo)) {
    return { lang: segments[0], rest: segments.slice(1) };
  }
  return { lang: null, rest: segments };
};

