import { useQuery, keepPreviousData } from "@tanstack/react-query";
import * as api from "@/api/apiRoutes";

export interface FilterAttributeValue {
  id: number;
  value: string;
}

export interface FilterAttribute {
  id: number;
  name: string;
  values: FilterAttributeValue[];
}

export interface FilterBrand {
  id: number;
  name: string;
}

export interface ProductFiltersData {
  category?: { id: number; name: string };
  child_categories?: Array<{ id: number; name: string }>;
  brands?: FilterBrand[];
  attributes?: FilterAttribute[];
  min_price?: number;
  max_price?: number;
}

export interface UseProductFiltersParams {
  /** Active category id. null/""/"NaN"/"all categories" → treated as "no category" (global filters). */
  categoryId?: string | number | null;
  latitude?: number | string;
  longitude?: number | string;
  /** Re-fetch when UI language changes (localized names). */
  languageId?: string | number;
  dataSource?: string;
  manualProductIds?: any;
  sourceId?: string | number;
  blockCategoryIds?: string;
  blockBrandIds?: string;
  filterMode?: string;
  /** Banner discount band — scopes the sheet to the same set the list shows. */
  minDiscountPercent?: string;
  maxDiscountPercent?: string;
}

export interface UseProductFiltersResult {
  filters: ProductFiltersData | null;
  isLoading: boolean;
  isError: boolean;
  error: unknown;
  refetch: () => void;
}

// Fetches category-aware filter options (brands, price range, attributes).
export const useProductFilters = ({
  categoryId,
  latitude,
  longitude,
  languageId,
  dataSource,
  manualProductIds,
  sourceId,
  blockCategoryIds,
  blockBrandIds,
  filterMode,
  minDiscountPercent,
  maxDiscountPercent,
}: UseProductFiltersParams): UseProductFiltersResult => {
  // Normalize "no category" sentinels to null.
  const activeCategoryId =
    categoryId != null &&
    categoryId !== "" &&
    categoryId !== "NaN" &&
    categoryId !== "all categories"
      ? categoryId
      : null;

  const query = useQuery({
    queryKey: [
      "product-filters",
      activeCategoryId,
      latitude,
      longitude,
      languageId,
      dataSource,
      manualProductIds,
      sourceId,
      blockCategoryIds,
      blockBrandIds,
      filterMode,
      minDiscountPercent,
      maxDiscountPercent,
    ],
    queryFn: async () => {
      const res = await api.getProductFilters({
        latitude,
        longitude,
        category_id: activeCategoryId,
        data_source: dataSource,
        manual_product_ids: manualProductIds,
        source_id: sourceId,
        block_category_ids: blockCategoryIds,
        block_brand_ids: blockBrandIds,
        filter_mode: filterMode,
        min_discount_percent: minDiscountPercent,
        max_discount_percent: maxDiscountPercent,
      });
      // API may wrap payload in { data } or return it flat.
      return res?.data ?? res ?? null;
    },
    // Fire query only when location is available.
    enabled: latitude != null && longitude != null,
    staleTime: 1000 * 60 * 5,
    gcTime: 1000 * 60 * 30,
    placeholderData: keepPreviousData,
  });

  return {
    filters: query.data ?? null,
    isLoading: query.isLoading,
    isError: query.isError,
    error: query.error,
    refetch: query.refetch,
  };
};

export default useProductFilters;
