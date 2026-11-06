// Shared query keys so SSR seeds and client queries can't drift apart.
// Coords/ids are stringified because SSR sends strings where redux holds numbers.

const str = (value: unknown) =>
  value == null || value === "" ? null : String(value);

export const homeLayoutKey = ({
  latitude,
  longitude,
  categoryId,
  shopMode,
}: {
  latitude?: unknown;
  longitude?: unknown;
  categoryId?: unknown;
  shopMode?: unknown;
}) => ["home-layout", str(latitude), str(longitude), str(categoryId), shopMode] as const;

export const productsKey = ({
  filter,
  categoryIds,
  latitude,
  longitude,
  shopMode,
}: {
  filter: unknown;
  categoryIds: unknown;
  latitude?: unknown;
  longitude?: unknown;
  shopMode?: unknown;
}) =>
  [
    "products",
    filter,
    categoryIds,
    str(latitude),
    str(longitude),
    shopMode,
  ] as const;

export const productKey = ({
  slug,
  latitude,
  longitude,
  shopMode,
}: {
  slug?: unknown;
  latitude?: unknown;
  longitude?: unknown;
  shopMode?: unknown;
}) => ["product", str(slug), str(latitude), str(longitude), shopMode] as const;

export const categoriesKey = ({
  page,
  slug,
  latitude,
  longitude,
}: {
  page?: unknown;
  slug?: unknown;
  latitude?: unknown;
  longitude?: unknown;
}) => ["categories", page ?? 1, str(slug), str(latitude), str(longitude)] as const;

export const pageBuilderKey = ({
  slug,
  latitude,
  longitude,
}: {
  slug?: unknown;
  latitude?: unknown;
  longitude?: unknown;
}) => ["page-builder", str(slug), str(latitude), str(longitude)] as const;

// Pre-hydration values of the redux-backed browse filters in ProductsList.
export const SSR_PRODUCT_FILTER_DEFAULTS = {
  listing_source: "all",
  category_slug: "",
  data_source: "",
  manual_product_ids: "",
  block_source_id: "",
  block_category_ids: "",
  block_brand_ids: "",
  filter_mode: "",
};

// grid_view is presentation only, so it never belongs in the key.
export const productsFilterKeyPart = (filter: any, search: unknown) => ({
  ...filter,
  grid_view: undefined,
  search,
});

// Prefixes invalidated when the language changes, since locale left the keys.
export const LOCALE_SENSITIVE_KEYS = [
  ["home-layout"],
  ["products"],
  ["product"],
  ["categories"],
  ["page-builder"],
  ["subCategories"],
  // Country/zone names come back translated, and these keys carry no language.
  ["footer-countries"],
  ["location-modal-countries"],
  ["location-modal-zones"],
] as const;

// Backend cache_versions groups → the key prefixes each group owns. Keys here
// are flat strings (not nested under a group), so a version bump invalidates
// every prefix listed instead of one `[group]` root.
export const CACHE_VERSION_GROUP_KEYS: Record<string, readonly string[]> = {
  catalog: [
    "home-layout",
    "products",
    "product",
    "product-filters",
    "product-ratings",
    "categories",
    "subCategories",
    "fullCategoryTree",
  ],
  content: ["page-builder"],
  geo: [
    "footer-countries",
    "location-modal-countries",
    "location-modal-zones",
  ],
  // Settings and languages are redux-backed, not react-query.
  settings: [],
  languages: [],
};
