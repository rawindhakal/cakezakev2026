// Category-tab slugs for the home page's `?tab=` param. Tabs have no slug
// field (ids are opaque builder strings), so the slug is derived from `name`
// and resolved back by matching. Renaming a tab changes its URL; an unmatched
// slug falls back to the first tab instead of 404ing.

// Home-layout tab entry; the API shape is loosely defined/builder-driven.
type CategoryTab = {
  id?: number | string;
  slug?: string;
  name?: string;
  translations?: { name?: string };
  [key: string]: any;
};

// "Home & Kitchen" -> "home-kitchen"; "" if unusable.
export const slugifyTabName = (name?: unknown): string => {
  if (typeof name !== "string") return "";
  return (
    name
      .normalize("NFKD")
      // Strip diacritics so "Café" and "Cafe" produce the same slug.
      .replace(/[̀-ͯ]/g, "")
      .toLowerCase()
      .trim()
      // Any run of non-alphanumerics becomes a single hyphen.
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
  );
};

// Prefers an API-provided `slug` once the backend adds one.
export const tabSlug = (tab?: CategoryTab | null): string => {
  if (!tab) return "";
  const apiSlug = typeof tab.slug === "string" ? tab.slug.trim() : "";
  if (apiSlug) return slugifyTabName(apiSlug) || "";
  return slugifyTabName(tab?.translations?.name ?? tab?.name);
};

// `?tab=` slug -> tab id. null (no match) means "no tab picked", so a stale
// slug renders the default home. First match wins; names aren't unique.
export const tabIdFromSlug = (
  tabs?: CategoryTab[] | null,
  slug?: string | null,
): number | string | null => {
  if (!Array.isArray(tabs) || !slug) return null;
  const target = slugifyTabName(slug);
  if (!target) return null;
  const match = tabs.find((tab) => tabSlug(tab) === target);
  return match?.id ?? null;
};

// Inverse: tab id -> slug for the URL. "" for the first tab, so the default home stays "/".
export const slugFromTabId = (
  tabs?: CategoryTab[] | null,
  id?: number | string | null,
): string => {
  if (!Array.isArray(tabs) || tabs.length === 0 || id == null) return "";
  const index = tabs.findIndex((tab) => String(tab?.id) === String(id));
  if (index <= 0) return "";
  return tabSlug(tabs[index]);
};
