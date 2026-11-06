// Flattens a category's cat_active_childs tree into leaf ids to filter products
// on — products live only at leaves, so a parent resolves to its descendants.

// Category node shape is deeply nested/API-driven; kept loose on purpose.
export type CategoryNode = {
  id?: number | string;
  slug?: string;
  cat_active_childs?: CategoryNode[];
  [key: string]: any;
};

export type LeafCategoryEntry = { id?: number | string; slug?: string };

const childrenOf = (node?: CategoryNode | null): CategoryNode[] =>
  Array.isArray(node?.cat_active_childs) ? node.cat_active_childs : [];

// Leaf descendants under `node` as {id, slug} pairs; node itself if it's a leaf. Deduped.
export const collectLeafCategoryEntries = (
  node?: CategoryNode | null,
): LeafCategoryEntry[] => {
  const out: LeafCategoryEntry[] = [];
  const seen = new Set<number | string>();
  const walk = (n?: CategoryNode | null) => {
    const kids = childrenOf(n);
    if (kids.length === 0) {
      if (n?.id != null && !seen.has(n.id)) {
        seen.add(n.id);
        out.push({ id: n.id, slug: n.slug });
      }
      return;
    }
    kids.forEach(walk);
  };
  walk(node);
  return out;
};

// Leaf descendant ids under `node`.
export const collectLeafCategoryIds = (
  node?: CategoryNode | null,
): (number | string | undefined)[] =>
  collectLeafCategoryEntries(node).map((e) => e.id);

/** Convert resolved ids into the comma-string `category_id` filter format. */
export const toCategoryIdCsv = (
  ids?: (number | string | null | undefined)[] | null,
): string =>
  Array.isArray(ids) ? ids.filter((id) => id != null).join(",") : "";

/** Convert resolved {id,slug} entries into a comma-string of slugs. */
export const toCategorySlugCsv = (
  entries?: LeafCategoryEntry[] | null,
): string =>
  Array.isArray(entries)
    ? entries
        .map((e) => e?.slug)
        .filter((slug) => slug != null && slug !== "")
        .join(",")
    : "";
