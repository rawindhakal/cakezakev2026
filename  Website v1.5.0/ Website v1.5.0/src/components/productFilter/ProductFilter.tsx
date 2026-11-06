"use client";

import { useState, useEffect, useRef, useCallback, useMemo } from "react";
import { useDispatch, useSelector, shallowEqual } from "react-redux";
import { clearAllFilter, setBlockSource } from "@/redux/slices/productFilterSlice";
import * as api from "@/api/apiRoutes";
import { useProductFilters } from "@/hooks/useProductFilters";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import useFullCategoryTree from "@/hooks/useFullCategoryTree";
import { resolveSlugCsvToIdCsv } from "@/utils/categorySlugResolver";
import { t } from "@/utils/translation";
import useIsHydrated from "@/hooks/useIsHydrated";
import CategoryTree from "./CategoryTree";
import CategorySearchModal from "./CategorySearchModal";
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible";
import { FaChevronDown } from "react-icons/fa";
import { Checkbox } from "@/components/ui/checkbox";
import dynamic from "next/dynamic";
// import { resetSelectedCategories } from "@/redux/slices/productFilterSlice";
const PriceSlider = dynamic(() => import("./PriceSlider"), { ssr: false });
import FilterSkeleton from "./FilterSkeleton";
import BrandSearchModal from "./BrandSearchModal";

export interface ProductFilterProps {
  /** Raw API product rows. */
  setProductResult: (products: any[]) => void;
  setOffset: (offset: number) => void;
  minPrice: number | null | undefined;
  maxPrice: number | null | undefined;
  values: number[];
  setValues: (values: number[]) => void;
  setMinPrice: (value: number) => void;
  setMaxPrice: (value: number) => void;
  setShowFilter?: (show: boolean) => void;
  /** Hide category section flag. */
  hideCategory?: boolean;
}

const Filter = ({
  setProductResult,
  setOffset,
  minPrice,
  maxPrice,
  values,
  setValues,
  setMinPrice,
  setMaxPrice,
  setShowFilter = () => {},
}: ProductFilterProps) => {
  const {
    filter: urlFilter,
    setMany,
    clearAll: clearUrlFilters,
  } = useUrlProductFilters();
  // Extract block source parameters from redux store
  const {
    data_source,
    manual_product_ids,
    block_source_id,
    block_category_ids,
    block_brand_ids,
    filter_mode,
  } = useSelector(
    (state: any) => ({
      data_source: state.ProductFilter.data_source,
      manual_product_ids: state.ProductFilter.manual_product_ids,
      block_source_id: state.ProductFilter.block_source_id,
      block_category_ids: state.ProductFilter.block_category_ids,
      block_brand_ids: state.ProductFilter.block_brand_ids,
      filter_mode: state.ProductFilter.filter_mode,
    }),
    shallowEqual,
  );
  // Memoize combined URL and redux filter object
  const filter = useMemo(
    () => ({
      ...urlFilter,
      data_source,
      manual_product_ids,
      block_source_id,
      block_category_ids,
      block_brand_ids,
      filter_mode,
    }),
    [
      urlFilter,
      data_source,
      manual_product_ids,
      block_source_id,
      block_category_ids,
      block_brand_ids,
      filter_mode,
    ],
  );
  // Determine if any user filter is currently applied
  const isFilterApplied =
    filter?.brand_ids?.length > 0 ||
    filter?.attribute_value_ids?.length > 0 ||
    filter?.price_filter != null ||
    (filter?.sort_filter && filter?.sort_filter !== "default") ||
    (filter as any)?.search_sizes?.some((s: any) => s.checked) ||
    (filter?.seller_id != null && filter?.seller_id !== "") ||
    (filter?.country_id != null && filter?.country_id !== "") ||
    (filter?.min_discount_percent != null &&
      filter?.min_discount_percent !== "") ||
    (filter?.max_discount_percent != null &&
      filter?.max_discount_percent !== "") ||
    (filter?.search != null && filter?.search !== "") ||
    // Check if active category is applied
    (filter?.category_id != null &&
      filter?.category_id !== "" &&
      filter?.category_id !== "NaN" &&
      filter?.category_id !== "all categories");
  const city = useSelector((state: any) => state.City);
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  const dispatch = useDispatch();
  // Hydrated location coordinates for client queries
  const isHydrated = useIsHydrated();
  const hydratedLatitude = isHydrated ? city?.city?.latitude : undefined;
  const hydratedLongitude = isHydrated ? city?.city?.longitude : undefined;
  // Resolve category slug CSV to numeric ID CSV
  const { data: fullCategoryTree } = useFullCategoryTree({
    latitude: hydratedLatitude,
    longitude: hydratedLongitude,
    languageId: language?.id,
  });
  const resolvedCategoryIdCsv = filter?.category_id
    ? resolveSlugCsvToIdCsv(fullCategoryTree ?? [], filter.category_id)
    : "";
  // Memoize initial filter prop for CategoryTree
  const categoryTreeInitialFilter = useMemo(
    () => ({ category_id: resolvedCategoryIdCsv }),
    [resolvedCategoryIdCsv],
  );
  const [selectedCategories, setSelectedCategories] = useState<(number | string)[]>([]);
  // Seed selected categories from block source ID in display mode
  useEffect(() => {
    if (filter?.data_source !== "category" || !filter?.block_source_id) return;
    const blockCategoryId = Number(filter.block_source_id);
    if (Number.isNaN(blockCategoryId)) return;
    // Resolve leaf category IDs for block source subtree
    const findNode = (nodes: any[]): any =>
      nodes.reduce((found: any, node: any) => {
        if (found) return found;
        if (node.id === blockCategoryId) return node;
        return findNode(node.cat_active_childs ?? []);
      }, null);
    const leafIdsOf = (node: any): (number | string)[] => {
      const children = node?.cat_active_childs;
      if (!Array.isArray(children) || children.length === 0) return [node.id];
      return children.flatMap(leafIdsOf);
    };
    const node = findNode(fullCategoryTree ?? []);
    if (!node) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- seed selected categories from block source
    setSelectedCategories(leafIdsOf(node));
  }, [filter?.data_source, filter?.block_source_id, fullCategoryTree]);
  // State for top-level category list and pagination
  const [allCategories, setAllCategories] = useState<any[]>([]);
  const [totalCategories, setTotalCategories] = useState<number | null>(null);
  const [catOffset, setCatOffset] = useState(0);
  const [loadingCategories, setLoadingCategories] = useState(false);
  const categoryLimit = 10;
  const [showCategoryModal, setShowCategoryModal] = useState(false);
  // Memoize visible categories slice to prevent rerenders
  const visibleAllCategories = useMemo(
    () => allCategories.slice(0, categoryLimit),
    [allCategories],
  );
  // State for available brand filters
  const [brands, setbrands] = useState<any[] | null>(null);
  const brandLimit = 10;
  const [showBrandModal, setShowBrandModal] = useState(false);

  const [tempMinPrice, setTempMinPrice] = useState<number | null>(null);
  const [tempMaxPrice, setTempMaxPrice] = useState<number | null>(null);
  // Draft staged selection state for brand and attribute filters
  const [draftBrandIds, setDraftBrandIds] = useState<number[]>(filter?.brand_ids ?? []);
  const [draftAttrIds, setDraftAttrIds] = useState<number[]>(
    filter?.attribute_value_ids ?? [],
  );
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- sync draft brand IDs with filter
    setDraftBrandIds(filter?.brand_ids ?? []);
  }, [filter?.brand_ids]);
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- sync draft attribute IDs with filter
    setDraftAttrIds(filter?.attribute_value_ids ?? []);
  }, [filter?.attribute_value_ids]);
  const [defaultMinPrice, setDefaultMinPrice] = useState<number | null | undefined>(minPrice);
  const [defaultMaxPrice, setDefaultMaxPrice] = useState<number | null | undefined>(maxPrice);
  // Active accordion collapsible section keys
  const [activeKey, setActiveKey] = useState<string[]>([]);

  // Fetch category-specific filter options
  const {
    filters: categoryFilters,
    isLoading: loadingFilters,
    isError: filtersError,
  } = useProductFilters({
    // Pass numeric category ID to filter endpoint
    categoryId: resolvedCategoryIdCsv,
    latitude: hydratedLatitude,
    longitude: hydratedLongitude,
    languageId: language?.id,
    dataSource: filter?.data_source,
    manualProductIds: filter?.manual_product_ids,
    sourceId: filter?.block_source_id,
    blockCategoryIds: filter?.block_category_ids,
    blockBrandIds: filter?.block_brand_ids,
    filterMode: filter?.filter_mode,
    minDiscountPercent: filter?.min_discount_percent,
    maxDiscountPercent: filter?.max_discount_percent,
  });

  // Sync brand list from category filters API
  useEffect(() => {
    const catBrands = categoryFilters?.brands;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- update brands list from API response
    setbrands(Array.isArray(catBrands) ? catBrands : []);
  }, [categoryFilters]);

  // Auto-open collapsible sections carrying active filters
  useEffect(() => {
    const open: string[] = [];

    // Static groups.
    if (filter?.brand_ids?.length > 0) open.push("2");
    if (filter?.price_filter != null) open.push("4");
    const hasCategory =
      filter?.category_id != null &&
      filter?.category_id !== "" &&
      filter?.category_id !== "NaN" &&
      filter?.category_id !== "all categories";
    if (hasCategory) open.push("1", "cat");

    // Dynamic attribute groups: open the ones owning a selected value id.
    const selectedAttrIds = filter?.attribute_value_ids ?? [];
    if (selectedAttrIds.length > 0) {
      (categoryFilters?.attributes ?? []).forEach((a: any) => {
        const owns = (a?.values ?? []).some((v: any) =>
          selectedAttrIds.includes(Number.parseInt(v.id, 10)),
        );
        if (owns) open.push(`attr-${a.id}`);
      });
    }

    if (open.length === 0) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- auto-open active filter sections
    setActiveKey((prev) => {
      const missing = open.filter((k) => !prev.includes(k));
      return missing.length === 0 ? prev : [...prev, ...missing];
    });
  }, [
    categoryFilters,
    filter?.brand_ids,
    filter?.price_filter,
    filter?.category_id,
    filter?.attribute_value_ids,
  ]);

  // Seed default slider bounds from category filter range
  useEffect(() => {
    const min = categoryFilters?.min_price ?? (categoryFilters as any)?.price_min;
    const max = categoryFilters?.max_price ?? (categoryFilters as any)?.price_max;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- seed default price bounds from category min/max
    if (min != null) setDefaultMinPrice(Number(min));
    if (max != null) setDefaultMaxPrice(Number(max));
  }, [categoryFilters]);

  // Calculate active slider price range bounds
  const catMin = categoryFilters?.min_price ?? (categoryFilters as any)?.price_min;
  const catMax = categoryFilters?.max_price ?? (categoryFilters as any)?.price_max;
  const sliderMinPrice = catMin != null ? Number(catMin) : minPrice;
  const sliderMaxPrice = catMax != null ? Number(catMax) : maxPrice;

  // A banner can open the list with one price bound only. The slider spans the
  // scoped range; that single handle sits where the banner left it.
  const thumbMinPrice = filter?.min_price
    ? Number(filter.min_price)
    : sliderMinPrice;
  const thumbMaxPrice = filter?.max_price
    ? Number(filter.max_price)
    : sliderMaxPrice;

  const handleActiveKey = (key: string) => {
    setActiveKey((prevActiveKeys) =>
      prevActiveKeys.includes(key)
        ? prevActiveKeys.filter((item) => item !== key)
        : [...prevActiveKeys, key],
    );
  };

  // Fetch paginated category tree list
  const categoriesFetchKeyRef = useRef<string | null>(null);
  const fetchCategories = useCallback(
    // eslint-disable-next-line react-hooks/preserve-manual-memoization -- primitive deps scoped intentionally
    async (offsetVal: number = 0, append: boolean = false) => {
      const key = `${offsetVal}:${language?.id}:${city?.city?.latitude}:${city?.city?.longitude}`;
      if (!append && categoriesFetchKeyRef.current === key) return;
      categoriesFetchKeyRef.current = key;
      setLoadingCategories(true);
      try {
        const res = await api.getCategories({
          limit: categoryLimit,
          offset: offsetVal,
          latitude: city?.city?.latitude,
          longitude: city?.city?.longitude,
        });
        if (res?.status == 1 && Array.isArray(res?.data)) {
          setAllCategories((prev) =>
            append ? [...prev, ...res.data] : res.data,
          );
          setTotalCategories(res?.total ?? res.data.length);
        }
      } catch (error) {
        console.log("[filter] getCategories failed", error);
        // Reset key ref on request failure
        if (categoriesFetchKeyRef.current === key) {
          categoriesFetchKeyRef.current = null;
        }
      } finally {
        setLoadingCategories(false);
      }
    },
    [language?.id, city?.city?.latitude, city?.city?.longitude],
  );

  // Debounced category fetch on language or location update
  useEffect(() => {
    const id = setTimeout(() => {
      setCatOffset(0);
      fetchCategories(0, false);
    }, 300);
    return () => clearTimeout(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [language?.id, city?.city?.latitude, city?.city?.longitude]);

  const loadMoreCategories = () => {
    const next = catOffset + categoryLimit;
    setCatOffset(next);
    fetchCategories(next, true);
  };

  // const fetchCategories = async () => {
  //   setLoadingCategories(true);
  //   try {
  //     const categories = await api.getCategories();
  //     setCategories(categories.data);
  //   } catch (error) {
  //     console.log("erorr", error);
  //   } finally {
  //     setLoadingCategories(false);
  //   }
  // };

  // Handle category selection update and URL sync
  const handleCategoryChange = (categories: (number | string)[], slugs: string[]) => {
    const nextCategoryId = (slugs ?? []).join(",");
    // Bail if selected category is unchanged
    if (String(filter?.category_id ?? "") === nextCategoryId) {
      setSelectedCategories(categories);
      return;
    }
    setSelectedCategories(categories);
    // NOTE: Comment below line due to empty state issue in product page on refresh
    // setProductResult([]); // Reset products
    setOffset(0); // Reset offset
    // Reset selected attributes on category change
    setMany({ attribute_value_ids: [], category_id: nextCategoryId });
    // Clear block source mode on direct category selection
    dispatch(setBlockSource());
  };

  // Tree mount-sync: tick the resolved leaves only. Rewriting the URL slug here
  // dropped the banner's other filters and re-keyed the products query.
  const handleInitialCategorySelect = (categories: (number | string)[]) => {
    setSelectedCategories(categories);
  };

  // Toggle attribute value selection in draft state
  const toggleAttributeValue = (valueId: number | string) => {
    const id = Number.parseInt(String(valueId), 10);
    setDraftAttrIds((current) =>
      current.includes(id) ? current.filter((v) => v !== id) : [...current, id],
    );
  };

  const filterbyBrands = (brand: any) => {
    setDraftBrandIds((current) => {
      const next = [...current];
      if (next.includes(brand.id)) {
        next.splice(next.indexOf(brand.id), 1);
      } else {
        next.push(Number.parseInt(brand.id));
      }
      return sort_unique_brand_ids(next);
    });
  };

  // Debounced auto-commit of draft filter changes to URL
  const skipFirstCommit = useRef(true);
  useEffect(() => {
    // Skip initial commit on component mount
    if (skipFirstCommit.current) {
      skipFirstCommit.current = false;
      return;
    }
    const id = setTimeout(() => {
      // Check if staged draft selections changed
      const sameIds = (a: number[] = [], b: number[] = []) =>
        a.length === b.length && a.every((v, i) => v === b[i]);
      const brandsChanged = !sameIds(draftBrandIds, filter?.brand_ids ?? []);
      const attrsChanged = !sameIds(
        draftAttrIds,
        filter?.attribute_value_ids ?? [],
      );
      const nextMin = tempMinPrice ?? values[0];
      const nextMax = tempMaxPrice ?? values[1];
      const priceChanged =
        tempMinPrice != null &&
        tempMaxPrice != null &&
        (nextMin !== filter?.price_filter?.min_price ||
          nextMax !== filter?.price_filter?.max_price);

      if (!brandsChanged && !attrsChanged && !priceChanged) return;

      setOffset(0);
      setProductResult([]);
      // Commit filter patch to URL state
      const patch: Record<string, any> = {};
      if (brandsChanged) patch.brand_ids = draftBrandIds;
      if (attrsChanged) patch.attribute_value_ids = draftAttrIds;
      if (priceChanged)
        patch.price_filter = { min_price: nextMin, max_price: nextMax };
      setMany(patch);
    }, 500);
    return () => clearTimeout(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- commit draft changes on selection updates
  }, [draftBrandIds, draftAttrIds, tempMinPrice, tempMaxPrice]);

  const sort_unique_brand_ids = (int_brand_ids) => {
    if (int_brand_ids.length === 0) return int_brand_ids;
    int_brand_ids = int_brand_ids.sort(function (a, b) {
      return a * 1 - b * 1;
    });
    const ret = [int_brand_ids[0]];
    for (let i = 1; i < int_brand_ids.length; i++) {
      // Remove duplicates from sorted array
      if (int_brand_ids[i - 1] !== int_brand_ids[i]) {
        ret.push(int_brand_ids[i]);
      }
    }
    return ret;
  };

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- sync default price bounds with slider range
    setDefaultMinPrice(sliderMinPrice);
    setDefaultMaxPrice(sliderMaxPrice);
  }, [sliderMinPrice, sliderMaxPrice]);

  // Seed slider thumbs with default price range when unconstrained
  useEffect(() => {
    if (filter?.price_filter != null) return;
    // Fall back to parent price bounds when API is loading
    const min = thumbMinPrice ?? minPrice;
    const max = thumbMaxPrice ?? maxPrice;
    if (min == null || max == null) return;
    setValues([Number(min), Number(max)]);
  }, [
    thumbMinPrice,
    thumbMaxPrice,
    minPrice,
    maxPrice,
    filter?.price_filter,
    setValues,
  ]);

  // Restore slider thumbs and temp price from applied price filter
  useEffect(() => {
    const pf = filter?.price_filter;
    if (pf == null) {
      // Reset slider thumbs when price filter is removed
      const min = thumbMinPrice ?? minPrice;
      const max = thumbMaxPrice ?? maxPrice;
      if (min != null && max != null) setValues([Number(min), Number(max)]);
      // eslint-disable-next-line react-hooks/set-state-in-effect -- restore slider thumbs from active price filter
      setTempMinPrice(null);
      setTempMaxPrice(null);
      return;
    }
    const min = Number(pf.min_price);
    const max = Number(pf.max_price);
    if (Number.isNaN(min) || Number.isNaN(max)) return;
    setValues([min, max]);
    setTempMinPrice(min);
    setTempMaxPrice(max);
    // Run on mount and applied price filter changes
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    filter?.price_filter?.min_price,
    filter?.price_filter?.max_price,
    sliderMinPrice,
    sliderMaxPrice,
  ]);

  // Render dynamic attribute filter sections
  let attributeFiltersSection;
  if (filtersError) {
    attributeFiltersSection = (
      <div className="px-4 py-3 bottomBorder text-sm text-[#DB3D26]">
        {t("something_went_wrong")}
      </div>
    );
  } else if (loadingFilters) {
    attributeFiltersSection = (
      <div className="px-4 py-4 bottomBorder">
        <div className="h-4 w-24 rounded bg-black/10 animate-pulse" />
      </div>
    );
  } else {
    attributeFiltersSection =
      Array.isArray(categoryFilters?.attributes) &&
      categoryFilters.attributes.map((attribute) => {
        const groupKey = `attr-${attribute.id}`;
        const isOpen = activeKey.includes(groupKey);
        return (
          <Collapsible
            key={groupKey}
            open={isOpen}
            className="w-full bottomBorder"
            onOpenChange={() => handleActiveKey(groupKey)}
          >
            <CollapsibleTrigger className="w-full p-4 flex justify-between items-center group/trig hover:bg-black/[0.02] transition-colors">
              <div className="text-[15px] font-semibold textColor">
                {attribute?.name}
              </div>
              <div
                className={`transition-transform duration-250 ${
                  isOpen ? "rotate-0" : "-rotate-90"
                }`}
              >
                <FaChevronDown size={12} className="text-gray-400" />
              </div>
            </CollapsibleTrigger>
            <CollapsibleContent>
              <div className="filter-row px-2 pb-4 md:px-2 lg:px-4">
                {(attribute?.values ?? []).map((val) => {
                  const isChecked = draftAttrIds.includes(
                    Number.parseInt(String(val.id), 10),
                  );
                  return (
                    <label
                      key={val.id}
                      className={`flex items-center gap-2.5 rounded-md px-2 py-2 cursor-pointer border transition-colors ${
                        isChecked
                          ? "border-[var(--primary-color)]/40 bg-black/[0.03]"
                          : "border-transparent hover:bg-black/5"
                      }`}
                    >
                      <Checkbox
                        className="data-[state=checked]:primaryBackColor shadow-sm border-gray-300 border-[1.5px]"
                        checked={isChecked}
                        onCheckedChange={() => toggleAttributeValue(val.id)}
                      />
                      <span
                        className={`text-sm textColor ${
                          isChecked ? "font-semibold" : "font-normal"
                        }`}
                      >
                        {val?.value}
                      </span>
                    </label>
                  );
                })}
              </div>
            </CollapsibleContent>
          </Collapsible>
        );
      });
  }

  return (
    <>
      {loadingFilters ? (
        <FilterSkeleton />
      ) : (
        <div className="md:cardBorder md:border rounded-xl headerBackgroundColor overflow-hidden">
          <div className="px-4 py-4 bottomBorder ">
            <div className="flex justify-between items-center gap-2">
              <h5 className="text-lg font-bold">{t("filters")}</h5>
              {isFilterApplied && (
                <button
                  type="button"
                  className="m-0 text-sm font-medium text-[#DB3D26] cursor-pointer hover:underline whitespace-nowrap"
                  onClick={() => {
                    setSelectedCategories([]);
                    // Reset price range to catalog bounds
                    const resetMin = Number(
                      sliderMinPrice ?? defaultMinPrice ?? minPrice,
                    );
                    const resetMax = Number(
                      sliderMaxPrice ?? defaultMaxPrice ?? maxPrice,
                    );
                    setMinPrice(resetMin);
                    setMaxPrice(resetMax);
                    setValues([resetMin, resetMax]);
                    // Reset staged price filters
                    setTempMinPrice(null);
                    setTempMaxPrice(null);
                    // Reset staged brand and attribute selections
                    setDraftBrandIds([]);
                    setDraftAttrIds([]);
                    // Skip auto-commit on clear
                    skipFirstCommit.current = true;

                    // Clear all URL and redux filter parameters
                    clearUrlFilters();
                    dispatch(clearAllFilter());
                    // dispatch(resetSelectedCategories())
                    setOffset(0);
                    setProductResult([]);
                    // Close filter drawer on next frame after reset
                    requestAnimationFrame(() => setShowFilter(false));
                  }}
                >
                  {t("clearAll")}
                </button>
              )}
            </div>
          </div>
          {/* Sub-category picker section */}
          {Array.isArray(categoryFilters?.child_categories) &&
            categoryFilters.child_categories.length > 0 && (
              <Collapsible
                open={activeKey.includes("1")}
                className="w-full bottomBorder"
                onOpenChange={() => handleActiveKey("1")}
              >
                <CollapsibleTrigger className="w-full p-4 flex justify-between items-center group/trig hover:bg-black/[0.02] transition-colors">
                  <div className="text-[15px] font-semibold textColor">
                    {t("product_category")}
                  </div>
                  <div
                    className={`transition-transform duration-250 ${
                      activeKey.includes("1") ? "rotate-0" : "-rotate-90"
                    }`}
                  >
                    <FaChevronDown size={12} className="text-gray-400" />
                  </div>
                </CollapsibleTrigger>

                <CollapsibleContent>
                  <div className="filter-row">
                    <CategoryTree
                      categories={categoryFilters.child_categories}
                      selectedCategories={selectedCategories}
                      onCategoryChange={handleCategoryChange}
                      onInitialSelect={handleInitialCategorySelect}
                      initialFilter={categoryTreeInitialFilter}
                    />
                  </div>
                </CollapsibleContent>
              </Collapsible>
            )}

          {/* Top-level categories section */}
          {allCategories?.length > 0 && (
            <Collapsible
              open={activeKey.includes("cat")}
              className="w-full bottomBorder"
              onOpenChange={() => handleActiveKey("cat")}
            >
              <CollapsibleTrigger className="w-full p-4 flex justify-between items-center group/trig hover:bg-black/[0.02] transition-colors">
                <div className="text-[15px] font-semibold textColor">
                  {t("browse_categories") || "Browse Categories"}
                </div>
                <div
                  className={`transition-transform duration-250 ${
                    activeKey.includes("cat") ? "rotate-0" : "-rotate-90"
                  }`}
                >
                  <FaChevronDown size={12} className="text-gray-400" />
                </div>
              </CollapsibleTrigger>
              <CollapsibleContent>
                <div className="filter-row">
                  {/* CategoryTree for top-level categories */}
                  <CategoryTree
                    categories={visibleAllCategories}
                    selectedCategories={selectedCategories}
                    onCategoryChange={handleCategoryChange}
                    onInitialSelect={handleInitialCategorySelect}
                    initialFilter={categoryTreeInitialFilter}
                  />
                  {/* Load more categories modal button */}
                  {(allCategories.length > categoryLimit ||
                    (totalCategories != null &&
                      totalCategories > allCategories.length)) && (
                    <button
                      type="button"
                      onClick={() => setShowCategoryModal(true)}
                      className="ms-9 -mt-4 px-2.5 py-2 text-sm font-semibold text-[var(--primary-color)] hover:underline"
                    >
                      {allCategories.length > categoryLimit
                        ? `+${allCategories.length - categoryLimit} ${t("more")}`
                        : t("more")}
                    </button>
                  )}
                </div>
              </CollapsibleContent>
            </Collapsible>
          )}

          {allCategories?.length > 0 && (
            <CategorySearchModal
              open={showCategoryModal}
              onOpenChange={setShowCategoryModal}
              categories={allCategories}
              selectedCategories={selectedCategories}
              onCategoryChange={handleCategoryChange}
              onLoadMore={loadMoreCategories}
              hasMore={
                totalCategories != null && totalCategories > allCategories.length
              }
              loadingMore={loadingCategories}
            />
          )}

          {brands && brands?.length > 0 && (
            <Collapsible
              open={activeKey.includes("2")}
              className="w-full bottomBorder"
              onOpenChange={() => handleActiveKey("2")}
            >
              <CollapsibleTrigger className="w-full p-4 flex justify-between items-center group/trig hover:bg-black/[0.02] transition-colors">
                <div className="text-[15px] font-semibold textColor">
                  {t("brands")}
                </div>
                <div
                  className={`transition-transform duration-250 ${
                    activeKey.includes("2") ? "rotate-0" : "-rotate-90"
                  }`}
                >
                  <FaChevronDown size={12} className="text-gray-400" />
                </div>
              </CollapsibleTrigger>
              <CollapsibleContent>
                <div className="flex flex-col gap-1 px-2 pb-4 md:px-2 lg:px-4">
                  {brands.slice(0, brandLimit).map((brand) => {
                    const isChecked = draftBrandIds.includes(brand.id);
                    const brandName =
                      brand?.translations?.name ?? brand?.name;
                    return (
                      <label
                        key={brand.id}
                        className={`flex items-center gap-2.5 rounded-lg px-2 py-1.5 cursor-pointer border transition-colors ${
                          isChecked
                            ? "primaryColorBorder primaryLightBack"
                            : "border-transparent hover:bg-black/[0.04] dark:hover:bg-white/[0.06]"
                        }`}
                      >
                        <Checkbox
                          className="data-[state=checked]:primaryBackColor shadow-sm border-gray-300 border-[1.5px] shrink-0"
                          checked={isChecked}
                          onCheckedChange={() => filterbyBrands(brand)}
                        />
                        {brand?.image_url && (
                          <span className="flex h-8 w-8 shrink-0 items-center justify-center overflow-hidden rounded-md border cardBorder bg-white">
                            {/* eslint-disable-next-line @next/next/no-img-element */}
                            <img
                              src={brand.image_url}
                              alt={brandName}
                              className="h-full w-full object-contain p-0.5"
                              loading="lazy"
                            />
                          </span>
                        )}
                        <span
                          title={brandName}
                          className={`min-w-0 flex-1 truncate text-sm textColor ${
                            isChecked ? "font-semibold" : "font-normal"
                          }`}
                        >
                          {brandName}
                        </span>
                      </label>
                    );
                  })}
                  {brands.length > brandLimit && (
                    <button
                      type="button"
                      onClick={() => setShowBrandModal(true)}
                      className="mt-1 self-start px-2 py-1.5 text-sm font-semibold primaryColor hover:underline"
                    >
                      {`+${brands.length - brandLimit} ${t("more")}`}
                    </button>
                  )}
                </div>
              </CollapsibleContent>
            </Collapsible>
          )}

          {brands && brands.length > brandLimit && (
            <BrandSearchModal
              open={showBrandModal}
              onOpenChange={setShowBrandModal}
              brands={brands}
              selectedBrandIds={draftBrandIds}
              onToggleBrand={filterbyBrands}
            />
          )}

          {/* Dynamic attribute filter sections */}
          {attributeFiltersSection}

          <Collapsible
            open={activeKey.includes("4")}
            className="w-full bottomBorder"
            onOpenChange={() => handleActiveKey("4")}
          >
            <CollapsibleTrigger className="w-full p-4 flex justify-between items-center group/trig hover:bg-black/[0.02] transition-colors">
              <div className="text-[15px] font-semibold textColor">
                {t("priceRange")}
              </div>
              <div
                className={`transition-transform duration-250 ${
                  activeKey.includes("4") ? "rotate-0" : "-rotate-90"
                }`}
              >
                <FaChevronDown size={12} className="text-gray-400" />
              </div>
            </CollapsibleTrigger>
            <CollapsibleContent className="px-2 pb-4 md:px-2 lg:px-4">
              <div className="flex flex-col gap-4">
                <PriceSlider
                  minPrice={sliderMinPrice}
                  maxPrice={sliderMaxPrice}
                  setValues={setValues}
                  setTempMaxPrice={setTempMaxPrice}
                  setTempMinPrice={setTempMinPrice}
                  values={values}
                />
              </div>
            </CollapsibleContent>
          </Collapsible>

          {/* Auto-committing filter section */}
        </div>
      )}
    </>
  );
};

export default Filter;
