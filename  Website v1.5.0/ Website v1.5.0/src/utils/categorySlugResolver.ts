// Resolves category slugs <-> ids by walking an already-fetched tree — the
// API has no direct slug/id lookup. Slugs are unique across the whole tree.
import {
  collectLeafCategoryEntries,
  type CategoryNode,
} from "@/utils/categoryTree";

const childrenOf = (node?: CategoryNode | null): CategoryNode[] =>
  Array.isArray(node?.cat_active_childs) ? node.cat_active_childs : [];

const findNode = (
  tree: CategoryNode[] | null | undefined,
  predicate: (node: CategoryNode) => boolean,
): CategoryNode | null => {
  const stack = [...(Array.isArray(tree) ? tree : [])];
  while (stack.length) {
    const node = stack.pop();
    if (!node) continue;
    if (predicate(node)) return node;
    stack.push(...childrenOf(node));
  }
  return null;
};

export const findNodeBySlug = (
  tree: CategoryNode[] | null | undefined,
  slug?: string | null,
): CategoryNode | null =>
  slug ? findNode(tree, (n) => n?.slug === slug) : null;

export const findNodeById = (
  tree: CategoryNode[] | null | undefined,
  id?: number | string | null,
): CategoryNode | null =>
  id != null ? findNode(tree, (n) => String(n?.id) === String(id)) : null;

// Slug CSV (from the URL) -> leaf id CSV (for the products API). Unknown
// slugs are dropped; a parent slug expands to its leaf descendants.
export const resolveSlugCsvToIdCsv = (
  tree: CategoryNode[] | null | undefined,
  slugCsv?: string | null,
): string => {
  if (!slugCsv) return "";
  const slugs = String(slugCsv)
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const ids: (number | string)[] = [];
  const seen = new Set<number | string>();
  for (const slug of slugs) {
    const node = findNodeBySlug(tree, slug);
    if (!node) continue;
    const leafEntries =
      childrenOf(node).length > 0
        ? collectLeafCategoryEntries(node)
        : [{ id: node.id, slug: node.slug }];
    for (const entry of leafEntries) {
      if (entry.id != null && !seen.has(entry.id)) {
        seen.add(entry.id);
        ids.push(entry.id);
      }
    }
  }
  return ids.join(",");
};

// Id CSV -> slug CSV, for building a URL from a CMS-configured id. Unknown ids are dropped.
export const resolveIdCsvToSlugCsv = (
  tree: CategoryNode[] | null | undefined,
  idCsv?: string | null,
): string => {
  if (!idCsv) return "";
  const ids = String(idCsv)
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const slugs: string[] = [];
  for (const id of ids) {
    const node = findNodeById(tree, id);
    if (node?.slug) slugs.push(node.slug);
  }
  return slugs.join(",");
};
