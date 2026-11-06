// Pure URL query helpers for product listing filter parsing and serialization.

// URL param name for each filter field.
export const FILTER_PARAMS = {
  search: "q",
  brand_ids: "brand",
  category_id: "category",
  sort_filter: "sort",
  attribute_value_ids: "attr",
  seller_id: "seller",
  country_id: "country",
  min_discount_percent: "min_discount",
  max_discount_percent: "max_discount",
  occasion: "occasion",
  relationship: "relationship",
  delivery_type: "delivery",
};

// Owned query keys used for filter URL management.
export const OWNED_QUERY_KEYS = [
  "q",
  "brand",
  "category",
  "price_min",
  "price_max",
  "sort",
  "attr",
  "seller",
  "country",
  "min_discount",
  "max_discount",
  "occasion",
  "relationship",
  "delivery",
];

// Heading a "products" banner puts on the listing URL. Not an owned filter
// key: it survives filter edits, and only "clear all" drops it.
export const LISTING_TITLE_PARAM = "title";

// Query object parameter types.
type QueryValue = string | string[] | undefined;
type QueryObject = Record<string, QueryValue>;

const toStr = (v: QueryValue): string | undefined => (Array.isArray(v) ? v[0] : v);

const parseCsvInts = (v: QueryValue): number[] => {
  const s = toStr(v);
  if (!s) return [];
  return String(s)
    .split(",")
    .map((x) => parseInt(x, 10))
    .filter((n) => !Number.isNaN(n));
};

export interface PriceFilter {
  min_price: number;
  max_price: number;
}

export interface ParsedProductFilter {
  search: string | null;
  brand_ids: number[];
  category_id: string | null;
  price_filter: PriceFilter | null;
  sort_filter: string;
  attribute_value_ids: number[];
  seller_id: string;
  country_id: string;
  min_discount_percent: string;
  max_discount_percent: string;
  occasion: string;
  relationship: string;
  delivery_type: string;
  // Raw bounds as the URL carries them. price_filter needs both; a banner can
  // open the list with only one ("Under 500"), and that bound still filters.
  min_price: string;
  max_price: string;
}

// Parse raw query object into structured product filter state.
export function parseFilterFromQuery(query: QueryObject = {}): ParsedProductFilter {
  const search = toStr(query.q) || null;
  const brand_ids = parseCsvInts(query.brand);
  const category_id = toStr(query.category) || null;
  const sort_filter = toStr(query.sort) || "";
  const attribute_value_ids = parseCsvInts(query.attr);
  const seller_id = toStr(query.seller) || "";
  const country_id = toStr(query.country) || "";
  const min_discount_percent = toStr(query.min_discount) || "";
  const max_discount_percent = toStr(query.max_discount) || "";
  const occasion = toStr(query.occasion) || "";
  const relationship = toStr(query.relationship) || "";
  const delivery_type = toStr(query.delivery) || "";

  const minRaw = toStr(query.price_min);
  const maxRaw = toStr(query.price_max);
  const min = minRaw != null ? Number(minRaw) : NaN;
  const max = maxRaw != null ? Number(maxRaw) : NaN;
  const price_filter =
    !Number.isNaN(min) && !Number.isNaN(max)
      ? { min_price: min, max_price: max }
      : null;

  return {
    search,
    brand_ids,
    category_id,
    price_filter,
    sort_filter,
    attribute_value_ids,
    seller_id,
    country_id,
    min_discount_percent,
    max_discount_percent,
    occasion,
    relationship,
    delivery_type,
    min_price: minRaw != null ? String(minRaw) : "",
    max_price: maxRaw != null ? String(maxRaw) : "",
  };
}

// Check if query object contains no active filter parameters.
export function hasNoFilterParams(query: QueryObject = {}): boolean {
  return !OWNED_QUERY_KEYS.some((k) => query[k] != null && query[k] !== "");
}

// Merge partial filter patch into existing query object.
export interface ProductFilterPatch {
  search?: string | null;
  brand_ids?: (number | string)[] | null;
  category_id?: string | number | null;
  sort_filter?: string | null;
  attribute_value_ids?: (number | string)[] | null;
  seller_id?: string | number | null;
  country_id?: string | number | null;
  min_discount_percent?: string | number | null;
  max_discount_percent?: string | number | null;
  occasion?: string | null;
  relationship?: string | null;
  delivery_type?: string | null;
  price_filter?: { min_price: number | string; max_price: number | string } | null;
}

export function serializeFilterPatch(
  currentQuery: Record<string, any> = {},
  patch: ProductFilterPatch = {},
): Record<string, any> {
  const next: Record<string, any> = { ...currentQuery };

  const setOrDelete = (key: string, value: any): void => {
    if (value == null || value === "") {
      delete next[key];
    } else {
      next[key] = String(value);
    }
  };

  if ("search" in patch) setOrDelete(FILTER_PARAMS.search, patch.search);
  if ("brand_ids" in patch) {
    const v = patch.brand_ids;
    setOrDelete(FILTER_PARAMS.brand_ids, v?.length ? v.join(",") : null);
  }
  if ("category_id" in patch) {
    setOrDelete(FILTER_PARAMS.category_id, patch.category_id);
  }
  if ("sort_filter" in patch) {
    const v = patch.sort_filter;
    setOrDelete(FILTER_PARAMS.sort_filter, v && v !== "default" ? v : null);
  }
  if ("attribute_value_ids" in patch) {
    const v = patch.attribute_value_ids;
    setOrDelete(
      FILTER_PARAMS.attribute_value_ids,
      v?.length ? v.join(",") : null,
    );
  }
  if ("seller_id" in patch) setOrDelete(FILTER_PARAMS.seller_id, patch.seller_id);
  if ("country_id" in patch)
    setOrDelete(FILTER_PARAMS.country_id, patch.country_id);
  if ("min_discount_percent" in patch)
    setOrDelete(FILTER_PARAMS.min_discount_percent, patch.min_discount_percent);
  if ("max_discount_percent" in patch)
    setOrDelete(FILTER_PARAMS.max_discount_percent, patch.max_discount_percent);
  if ("occasion" in patch) setOrDelete(FILTER_PARAMS.occasion, patch.occasion);
  if ("relationship" in patch) setOrDelete(FILTER_PARAMS.relationship, patch.relationship);
  if ("delivery_type" in patch) setOrDelete(FILTER_PARAMS.delivery_type, patch.delivery_type);
  if ("price_filter" in patch) {
    const v = patch.price_filter;
    if (v == null || v.min_price == null || v.max_price == null) {
      delete next.price_min;
      delete next.price_max;
    } else {
      next.price_min = String(v.min_price);
      next.price_max = String(v.max_price);
    }
  }

  return next;
}

// Clear all owned filter query parameters from current query.
export function clearFilterQuery(
  currentQuery: Record<string, any> = {},
  { preserveCategory = false }: { preserveCategory?: boolean } = {},
): Record<string, any> {
  const next: Record<string, any> = { ...currentQuery };
  for (const key of OWNED_QUERY_KEYS) {
    if (preserveCategory && key === "category") continue;
    delete next[key];
  }
  // "cat" drives the category listing (title/breadcrumb); leaving it re-seeds
  // the cleared category from sessionStorage.
  if (!preserveCategory) {
    delete next.cat;
    // A banner's heading describes a filter set that is gone now.
    delete next[LISTING_TITLE_PARAM];
  }
  return next;
}

// Build API-compatible parameter object from parsed product filters.
export function buildFilterApiParams(
  filter: any,
  { search }: { search?: string } = {},
): Record<string, any> {
  const params: Record<string, any> = {
    min_price: filter?.price_filter?.min_price ?? (filter?.min_price || undefined),
    max_price: filter?.price_filter?.max_price ?? (filter?.max_price || undefined),
    ...(filter?.category_id && { category_id: filter.category_id }),
    brand_ids: (filter?.brand_ids ?? []).join(","),
    ...(filter?.attribute_value_ids?.length > 0 && {
      attribute_value_ids: filter.attribute_value_ids.join(","),
    }),
    sort: filter?.sort_filter,
    search: search !== undefined ? search : filter?.search,
    branch_id: filter?.seller_id,
    country_id: filter?.country_id,
    ...(filter?.min_discount_percent && {
      min_discount_percent: filter.min_discount_percent,
    }),
    ...(filter?.max_discount_percent && {
      max_discount_percent: filter.max_discount_percent,
    }),
    ...(filter?.occasion && { occasion: filter.occasion }),
    ...(filter?.relationship && { relationship: filter.relationship }),
    ...(filter?.delivery_type && { delivery_type: filter.delivery_type }),
  };
  return params;
}


// The eight keys customer/products accepts inside a banner's `redirect_params`.
const REDIRECT_PARAM_KEYS = [
  "category_id",
  "brand_ids",
  "attribute_value_ids",
  "min_price",
  "max_price",
  "min_discount_percent",
  "max_discount_percent",
  "sort",
] as const;

const SORT_VALUES = ["new", "popular", "price_low", "price_high", "discount"];

// Keep only the eight documented keys with a non-blank value. The API already
// drops blanks, zeros and bad ids, so nothing here is re-validated — a key that
// survives is sent as it came.
export function sanitizeRedirectParams(
  redirectParams: any,
): Record<string, string> {
  if (!redirectParams || typeof redirectParams !== "object") return {};
  const clean: Record<string, string> = {};
  for (const key of REDIRECT_PARAM_KEYS) {
    const value = redirectParams[key];
    if (value == null || String(value).trim() === "") continue;
    if (key === "sort" && !SORT_VALUES.includes(String(value))) continue;
    clean[key] = String(value);
  }
  return clean;
}

// Turn a banner's redirect_params into the listing's own query object.
// `categorySlug` replaces redirect_params.category_id, which arrives as an id
// while the listing URL carries slugs.
export function buildProductsRedirectQuery(
  redirectParams: any,
  { categorySlug, title }: { categorySlug?: string; title?: string } = {},
): Record<string, string> {
  const clean = sanitizeRedirectParams(redirectParams);
  const query = serializeFilterPatch(
    {},
    {
      category_id: categorySlug || null,
      brand_ids: clean.brand_ids ? clean.brand_ids.split(",") : null,
      attribute_value_ids: clean.attribute_value_ids
        ? clean.attribute_value_ids.split(",")
        : null,
      sort_filter: clean.sort || null,
      min_discount_percent: clean.min_discount_percent || null,
      max_discount_percent: clean.max_discount_percent || null,
      // Either bound alone is a valid listing filter, so they go in raw rather
      // than through price_filter, which needs both.
    },
  );
  if (clean.min_price) query.price_min = clean.min_price;
  if (clean.max_price) query.price_max = clean.max_price;
  if (title) query[LISTING_TITLE_PARAM] = title;
  return query;
}
