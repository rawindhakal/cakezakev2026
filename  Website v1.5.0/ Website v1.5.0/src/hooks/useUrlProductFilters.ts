import { useCallback, useMemo } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import {
  parseFilterFromQuery,
  serializeFilterPatch,
  clearFilterQuery,
  hasNoFilterParams,
} from "@/utils/urlProductFilters";

// URL search params single-source-of-truth hook for product listing filters.
export default function useUrlProductFilters() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  // Plain object map of search params.
  const currentQuery = useMemo(
    () => Object.fromEntries(searchParams?.entries() ?? []),
    [searchParams],
  );

  const filter = useMemo(
    () => parseFilterFromQuery(currentQuery),
    [currentQuery],
  );

  const currentPath = pathname || "/";

  // Builds the literal visible URL string (path + query) for the address bar.
  const buildUrlString = useCallback(
    (query: Record<string, any>) => {
      const qs = new URLSearchParams(
        Object.entries(query).filter(([, v]) => v != null && v !== ""),
      ).toString();
      return qs ? `${currentPath}?${qs}` : currentPath;
    },
    [currentPath],
  );

  const applyUrl = useCallback(
    (nextUrl: string) => {
      router.replace(nextUrl, { scroll: false });
    },
    [router],
  );

  const patchUrl = useCallback(
    (patch: Record<string, any>) => {
      const nextQuery = serializeFilterPatch(currentQuery, patch);
      // Skip replace if query parameters have not changed.
      const same =
        Object.keys(nextQuery).length === Object.keys(currentQuery).length &&
        Object.entries(nextQuery).every(([k, v]) => currentQuery[k] === v);
      if (same) return;
      applyUrl(buildUrlString(nextQuery));
    },
    [currentQuery, applyUrl, buildUrlString],
  );

  const clearAll = useCallback(
    ({ preserveCategory = false } = {}) => {
      const nextQuery = clearFilterQuery(currentQuery, { preserveCategory });
      applyUrl(buildUrlString(nextQuery));
    },
    [currentQuery, applyUrl, buildUrlString],
  );

  return {
    filter,
    isReady: true,
    // Indicates if URL carries no filter query params.
    isDefaultUnfilteredView: hasNoFilterParams(currentQuery),
    setSearch: (v: any) => patchUrl({ search: v || null }),
    setBrandIds: (arr: any) => patchUrl({ brand_ids: arr }),
    setCategoryId: (id: any) => patchUrl({ category_id: id || null }),
    setAttributeValueIds: (arr: any) => patchUrl({ attribute_value_ids: arr }),
    setPriceFilter: (minMaxOrNull: any) => patchUrl({ price_filter: minMaxOrNull }),
    setSort: (v: any) => patchUrl({ sort_filter: v || null }),
    setSellerId: (id: any) => patchUrl({ seller_id: id || null }),
    setCountryId: (id: any) => patchUrl({ country_id: id || null }),
    setMany: (patch: Record<string, any>) => patchUrl(patch),
    clearAll,
    // Standalone filter query patch builder.
    buildQueryPatch: (patch: Record<string, any>) => serializeFilterPatch({}, patch),
  };
}
