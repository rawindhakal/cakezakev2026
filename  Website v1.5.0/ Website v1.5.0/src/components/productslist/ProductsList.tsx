"use client";

import React, { useEffect, useMemo, useRef, useState } from "react";
import { m, LayoutGroup } from "framer-motion";
import { useInfiniteQuery } from "@tanstack/react-query";
import BreadCrumb from "../breadcrumb/BreadCrumb";
import { t } from "@/utils/translation";
import Filter from "../productFilter/ProductFilter";
import * as api from "@/api/apiRoutes";
import { useDispatch, useSelector } from "react-redux";
import { useQuery } from "@tanstack/react-query";
import {
  setCategoryBreadcrumb,
  setListingSource,
  setCategorySlug,
  setSelectedCategories,
  setBlockSource,
} from "@/redux/slices/productFilterSlice";
import { useRouter, useSearchParams } from "next/navigation";
import useZoneHref from "@/hooks/useZoneHref";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import useFullCategoryTree from "@/hooks/useFullCategoryTree";
import {
  collectLeafCategoryEntries,
  toCategorySlugCsv,
} from "@/utils/categoryTree";
import { resolveSlugCsvToIdCsv } from "@/utils/categorySlugResolver";
import { LISTING_TITLE_PARAM } from "@/utils/urlProductFilters";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import "swiper/css";
import "swiper/css/navigation";
import VerticleProductCard from "../productcards/VerticleProductCard";
import ListViewProductCard from "../productcards/ListViewProductCard";
import { FaThList } from "react-icons/fa";
import CardSkeleton from "../skeleton/CardSkeleton";
import FilterDrawer from "../productFilter/FilterDrawer";
import { IoFilter } from "react-icons/io5";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import { LuArrowUpDown, LuCheck, LuChevronDown, LuChevronLeft, LuLayoutGrid, LuList, LuSlidersHorizontal } from "react-icons/lu";
import { IoCartOutline } from "react-icons/io5";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";
import NoOrderSvg from "@/assets/empty-state/no-product.svg";
import NotFound from "@/components/notfound/NotFound";
import { productsKey, productsFilterKeyPart } from "@/utils/queryKeys";
import useIsHydrated from "@/hooks/useIsHydrated";
import useZoneCityPending from "@/hooks/useZoneCityPending";
import useInViewFetch from "@/hooks/useInViewFetch";
import { useProductFilters } from "@/hooks/useProductFilters";
import { ColumnsIcon } from "@/components/icons";

// Must match shopModeSlice's initial `mode` or the SSR query key mismatches.
const SHOP_MODE_SSR_DEFAULT = "quick";

// Shared by the desktop dropdown and the mobile sort sheet.
const SORT_OPTIONS = [
  { value: "default", label: "default" },
  { value: "new", label: "newest_first" },
  { value: "price_high", label: "high_to_low" },
  { value: "price_low", label: "low_to_high" },
  { value: "discount", label: "discount_high_to_low" },
  { value: "popular", label: "popularity" },
];

// Mobile action bar height offset
const MOBILE_ACTION_BAR_H = 4;

// Props interface for Products component
interface ProductsListProps {
  initialProducts?: any;
}

const Products = ({ initialProducts = null }: ProductsListProps) => {
  const total_products_per_page = 12;
  const dispatch = useDispatch();
  const cart = useSelector((state: any) => state.Cart);
  const city = useSelector((state: any) => state.City);
  const setting = useSelector((state: any) => state.Setting.setting);
  // Gate persisted redux/localStorage reads on this, else hydration mismatch (#418).
  const isHydrated = useIsHydrated();
  // This page hides the site header on mobile, so it carries its own cart
  // anchor: flyToCart needs a visible [data-cart-target] to land on.
  const cartItemCount = (
    cart?.isGuest === true ? cart?.guestCart : cart?.cartProducts
  )?.reduce((n: number, p: any) => n + (Number(p?.qty) || 0), 0) ?? 0;
  // The persisted city still points at the previous zone until Header re-seeds it.
  const zoneCityPending = useZoneCityPending();
  // SSR coords until hydrated (so initialData applies), then redux city.
  // While the zone is pending, SSR coords win — they already match the URL zone.
  const useSsrCoords = !isHydrated || (zoneCityPending && initialProducts?.latitude != null);
  const latitude = useSsrCoords
    ? initialProducts?.latitude
    : city?.city?.latitude ||
      setting?.default_city?.latitude ||
      initialProducts?.latitude;
  const longitude = useSsrCoords
    ? initialProducts?.longitude
    : city?.city?.longitude ||
      setting?.default_city?.longitude ||
      initialProducts?.longitude;
  // Filter values live in the URL (same on server and client).
  const {
    filter: urlFilter,
    isReady: routerIsReady,
    setCategoryId,
    setSort,
    buildQueryPatch,
  } = useUrlProductFilters();
  const router = useRouter();
  const zoneHref = useZoneHref();
  // Redux browse and block source filters
  const persistedListingSource = useSelector(
    (state: any) => state.ProductFilter.listing_source,
  );
  const persistedCategorySlug = useSelector(
    (state: any) => state.ProductFilter.category_slug,
  );
  const persistedDataSource = useSelector(
    (state: any) => state.ProductFilter.data_source,
  );
  const persistedManualProductIds = useSelector(
    (state: any) => state.ProductFilter.manual_product_ids,
  );
  const persistedBlockSourceId = useSelector(
    (state: any) => state.ProductFilter.block_source_id,
  );
  const persistedBlockCategoryIds = useSelector(
    (state: any) => state.ProductFilter.block_category_ids,
  );
  const persistedBlockBrandIds = useSelector(
    (state: any) => state.ProductFilter.block_brand_ids,
  );
  const persistedFilterMode = useSelector(
    (state: any) => state.ProductFilter.filter_mode,
  );
  const listing_source = isHydrated ? persistedListingSource : "all";
  const category_slug = isHydrated ? persistedCategorySlug : "";
  const data_source = isHydrated ? persistedDataSource : "";
  const manual_product_ids = isHydrated ? persistedManualProductIds : "";
  const block_source_id = isHydrated ? persistedBlockSourceId : "";
  const block_category_ids = isHydrated ? persistedBlockCategoryIds : "";
  const block_brand_ids = isHydrated ? persistedBlockBrandIds : "";
  const filter_mode = isHydrated ? persistedFilterMode : "";
  // Memoized — effects key on `filter` by reference (a new object looped).
  const filter: any = useMemo(
    () => ({
      
      ...urlFilter,
      listing_source,
      category_slug,
      data_source,
      manual_product_ids,
      block_source_id,
      block_category_ids,
      block_brand_ids,
      filter_mode,
    }),
    [
      urlFilter,
      listing_source,
      category_slug,
      data_source,
      manual_product_ids,
      block_source_id,
      block_category_ids,
      block_brand_ids,
      filter_mode,
    ],
  );
  const persistedShopMode = useSelector((state: any) => state.ShopMode.mode);
  const shopMode = isHydrated ? persistedShopMode : SHOP_MODE_SSR_DEFAULT;
  const [minPrice, setMinPrice] = useState<number | null>(null);
  const [maxPrice, setMaxPrice] = useState<number | null>(null);
  const [values, setValues] = useState<number[]>([]);
  const [showFilter, setShowFilter] = useState(false);
  const [showSort, setShowSort] = useState(false);

  // Floating dock sits 12px above the Sort | Filter bar (no tab nav here).
  useEffect(() => {
    const root = document.documentElement;
    root.style.setProperty("--mobile-dock-bottom", `${MOBILE_ACTION_BAR_H + 12}px`);
    return () => {
      root.style.removeProperty("--mobile-dock-bottom");
    };
  }, []);
  // Grid/list view mode state persisted in localStorage
  const [viewMode, setViewMode] = useState<number | "list">(5);
  const viewModeRestored = useRef(false);
  useEffect(() => {
    const saved = window.localStorage.getItem("productsViewMode");
    viewModeRestored.current = true;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (saved === "list") return setViewMode("list");
    const n = Number(saved);
    if ([2, 3, 4, 5].includes(n)) setViewMode(n);
  }, []);
  useEffect(() => {
    // Don't overwrite the saved value before it's restored.
    if (!viewModeRestored.current) return;
    window.localStorage.setItem("productsViewMode", String(viewMode));
  }, [viewMode]);
  const isList = viewMode === "list";
  const gridCols = isList ? 4 : viewMode;
  // Last grid choice, so the mobile toggle returns to it after list view.
  const lastGridColsRef = useRef<number>(5);
  useEffect(() => {
    if (!isList) lastGridColsRef.current = viewMode as number;
  }, [viewMode, isList]);
  const [debouncedSearch, setDebouncedSearch] = useState(filter?.search);
  const { selectedLanguage } = useSelector((state: any) => state.Language);
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  const categoryBreadcrumb = useSelector(
    (state: any) => state.ProductFilter.categoryBreadcrumb,
  );

  const hideFilter = false;

  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedSearch(filter?.search);
    }, 500);
    return () => clearTimeout(timer);
  }, [filter?.search]);

  const refetchBreadcrumbTranslations = async () => {
    const updated = await Promise.all(
      categoryBreadcrumb.map(async (category: any) => {
        try {
          const res = await api.getCategories({
            slug: category.slug,
            is_own_data: 1,
            latitude,
            longitude,
          });
          const data = res?.data;
          return {
            ...category,
            name: data?.[0]?.translations?.name || category.name,
            translations: data?.[0]?.translations || category.translations,
          };
        } catch {
          return category;
        }
      }),
    );
    dispatch(setCategoryBreadcrumb({ data: updated }));
  };

  useEffect(() => {
    if (!categoryBreadcrumb || categoryBreadcrumb.length === 0) return;
    refetchBreadcrumbTranslations();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- refetch breadcrumb translations when language changes
  }, [selectedLanguage]);

  // category_id is a slug CSV from the URL, resolved to ids via the tree.
  const isValidCategoryId =
    filter?.category_id != null &&
    filter?.category_id !== "" &&
    filter?.category_id !== "NaN" &&
    filter?.category_id !== "all categories";

  const { data: fullCategoryTree } = useFullCategoryTree({
    latitude,
    longitude,
    languageId: language?.id,
  });

  const resolvedCategoryIdCsv = isValidCategoryId
    ? resolveSlugCsvToIdCsv(fullCategoryTree ?? [], filter.category_id)
    : "";

  const finalCategoryIds = isValidCategoryId ? resolvedCategoryIdCsv : null;

  // Entry category's children. `?slug=X` returns X's CHILDREN ([] for a leaf).
  const { data: childCategories = null } = useQuery({
    queryKey: [
      "subCategories",
      listing_source,
      category_slug,
      latitude,
      longitude,
    ],
    queryFn: async () => {
      if (listing_source !== "category" || !category_slug) {
        return null;
      }
      const res = await api.getCategories({
        slug: category_slug,
        latitude,
        longitude,
      });
      return Array.isArray(res?.data) ? res.data : [];
    },
    enabled:
      listing_source === "category" &&
      !!category_slug &&
      latitude != null &&
      longitude != null,
    staleTime: 1000 * 60 * 5,
    gcTime: 1000 * 60 * 30,
  });

  // Resolve parent category slug to leaf slugs on initial entry
  const resolvedSlugRef = useRef<string | null>(null);
  useEffect(() => {
    if (listing_source !== "category" || !category_slug) return;
    if (!childCategories) return;
    if (resolvedSlugRef.current === category_slug) return;
    resolvedSlugRef.current = category_slug;

    // Leaf entry — its own id already works.
    if (childCategories.length === 0) return;

    const leafEntries = childCategories.flatMap((child: any) =>
      collectLeafCategoryEntries(child),
    );
    const leafSlugCsv = toCategorySlugCsv(leafEntries);
    if (leafSlugCsv && String(filter?.category_id ?? "") !== leafSlugCsv) {
      setCategoryId(leafSlugCsv);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [category_slug, listing_source, childCategories]);

  // Reset the guard on leaving the category flow.
  useEffect(() => {
    if (listing_source !== "category") {
      resolvedSlugRef.current = null;
    }
  }, [listing_source]);

  const effectiveCategoryIds = finalCategoryIds || null;

  const fetchProducts = async ({ pageParam = 0 }: { pageParam?: number }) => {
    const filterParams = {
      min_price: filter.price_filter?.min_price ?? (filter?.min_price || undefined),
      max_price: filter.price_filter?.max_price ?? (filter?.max_price || undefined),
      ...(effectiveCategoryIds && {
        category_id: effectiveCategoryIds,
      }),
      brand_ids: filter?.brand_ids.toString(),
      ...(filter?.attribute_value_ids?.length > 0 && {
        attribute_value_ids: filter.attribute_value_ids.join(","),
      }),
      sort: filter?.sort_filter,
      search: debouncedSearch,
      limit: total_products_per_page,
      sizes: filter?.search_sizes
        ?.filter((obj: any) => obj.checked)
        .map((obj: any) => obj["size"])
        .join(","),
      offset: pageParam,
      unit_ids: filter?.search_sizes
        ?.filter((obj: any) => obj.checked)
        .map((obj: any) => obj["unit_id"])
        .join(","),
      branch_id: filter?.seller_id,
      country_id: filter?.country_id,
      ...(filter?.min_discount_percent && {
        min_discount_percent: filter.min_discount_percent,
      }),
      ...(filter?.max_discount_percent && {
        max_discount_percent: filter.max_discount_percent,
      }),
      section_id: filter?.section_id,
      // Configure data source filter parameters
      ...(filter?.data_source === "manual"
        ? filter?.manual_product_ids && {
            data_source: "manual",
            manual_product_ids: filter.manual_product_ids,
          }
        : filter?.data_source &&
          filter.data_source !== "category" &&
          filter.data_source !== "brand" && {
            data_source: filter.data_source,
          }),
      // URL category wins over a stale block_source_id.
      ...(filter?.data_source === "category" &&
        filter?.block_source_id &&
        !effectiveCategoryIds && {
          category_id: filter.block_source_id,
        }),
      ...(filter?.data_source === "brand" &&
        filter?.block_source_id && {
          brand_ids: filter.block_source_id,
        }),
      // An automatic row scoped by category/brand — ids pass through as received.
      ...(filter?.block_category_ids &&
        !effectiveCategoryIds && {
          category_id: filter.block_category_ids,
        }),
      ...(filter?.block_brand_ids &&
        !(filter?.brand_ids?.length > 0) && {
          brand_ids: filter.block_brand_ids,
        }),
      ...(filter?.filter_mode && { filter_mode: filter.filter_mode }),
    };

    return await api.getProductByFilter({
      latitude,
      longitude,
      filters: filterParams,
    });
  };

  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    isLoading,
    isFetching,
    isError,
    refetch,
  } = useInfiniteQuery({
    queryKey: productsKey({
      filter: productsFilterKeyPart(filter, debouncedSearch),
      categoryIds: effectiveCategoryIds,
      latitude,
      longitude,
      shopMode,
    }),
    queryFn: fetchProducts,
    getNextPageParam: (lastPage: any, allPages: any[]) => {
      if (!lastPage.data || lastPage.data.length < total_products_per_page) {
        return undefined;
      }
      const nextOffset = allPages.length * total_products_per_page;
      // Manual "See All" stops at its id count (backend may over-return).
      if (filter?.data_source === "manual") {
        const manualCount = String(filter?.manual_product_ids ?? "")
          .split(",")
          .filter(Boolean).length;
        if (nextOffset >= manualCount) return undefined;
      }
      return nextOffset;
    },
    initialPageParam: 0,
    // Query enabled gate for SSR hydration and category tree resolution
    enabled:
      !!latitude &&
      !!longitude &&
      !(isValidCategoryId && fullCategoryTree == null) &&
      (routerIsReady ||
        (initialProducts &&
          !filter?.data_source &&
          latitude === initialProducts.latitude &&
          longitude === initialProducts.longitude &&
          JSON.stringify(urlFilter) ===
            JSON.stringify(initialProducts.filter ?? {}))),
    // No placeholderData: filter changes show skeletons, not stale results.
    // Returning to a key already fetched (coords settling, filter toggled back)
    // serves the cache instead of firing the same request again.
    staleTime: 1000 * 30,
  });

  // Deduplicate products from paginated response
  const productResult = useMemo(() => {
    const rows = data?.pages?.flatMap((page: any) => page?.data ?? []) ?? [];
    const seen = new Set();
    const unique: any[] = [];
    for (const p of rows) {
      const key = p?.id ?? p?.slug;
      if (key == null) {
        unique.push(p);
        continue;
      }
      if (seen.has(key)) continue;
      seen.add(key);
      unique.push(p);
    }
    return unique;
  }, [data?.pages]);
  // Cards at index >= this are new arrivals and fade in.
  const prevCountRef = useRef(0);
  const totalProducts = data?.pages?.[0]?.total || 0;
  // Determine resolving category state
  /* eslint-disable react-hooks/refs */
  const isResolvingCategory =
    listing_source === "category" &&
    !!category_slug &&
    resolvedSlugRef.current !== category_slug;
  /* eslint-enable react-hooks/refs */
  // Load-more excluded — it keeps rendered products.
  const loading =
    isLoading || (isFetching && !isFetchingNextPage) || isResolvingCategory;
  const isLoadMoreLoading = isFetchingNextPage;

  const setProductResult = () => {};
  const setOffset = () => {};

  const handlePrices = async (result: any) => {
    // API may omit total_min/max_price — derive from products.
    const products = result?.data || [];
    const prices = products
      .map((p: any) => Number(p?.min_price ?? p?.price))
      .filter((n: number) => !Number.isNaN(n));
    const apiMin = Number(
      result?.total_min_price ?? (prices.length ? Math.min(...prices) : 0),
    );
    const apiMax = Number(
      result?.total_max_price ?? (prices.length ? Math.max(...prices) : 0),
    );

    if (
      filter?.price_filter?.min_price !== undefined &&
      filter?.price_filter?.min_price !== null &&
      filter?.price_filter?.max_price !== null &&
      filter?.price_filter?.max_price !== undefined
    ) {
      setValues([
        parseInt(String(filter?.price_filter?.min_price), 10),
        parseInt(String(filter?.price_filter?.max_price), 10),
      ]);
      setMinPrice(apiMin);
      setMaxPrice(apiMax);
    } else {
      // Reset price filter bounds when unconstrained
      setMinPrice(apiMin);
      setMaxPrice(apiMin === apiMax ? apiMax + 100 : apiMax);
      setValues([]);
    }
  };

  useEffect(() => {
    if (data?.pages?.[0]) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      handlePrices(data.pages[0]);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data]);

  // Toolbar sticky offset = measured header height (varies by breakpoint/mode).
  const [headerH, setHeaderH] = useState(0);
  useEffect(() => {
    const header = document.getElementById("site-header");
    if (!header) return;
    const measure = () => setHeaderH(header.offsetHeight);
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(header);
    window.addEventListener("resize", measure);
    return () => {
      ro.disconnect();
      window.removeEventListener("resize", measure);
    };
  }, []);

  // Infinite scroll; 800px lead ≈ two card rows.
  const loadMoreRef = useInViewFetch({
    enabled: !!hasNextPage && !isFetchingNextPage && !isLoading,
    onLoadMore: fetchNextPage,
    rootMarginPx: 800,
  });

  const sortProduct = async (value: string) => {
    setSort(value);
  };

  // Drives the dot on the mobile FILTER button.
  const hasActiveFilter =
    (urlFilter?.brand_ids?.length ?? 0) > 0 ||
    (urlFilter?.attribute_value_ids?.length ?? 0) > 0 ||
    !!urlFilter?.price_filter ||
    isValidCategoryId ||
    !!urlFilter?.seller_id ||
    !!urlFilter?.country_id ||
    !!urlFilter?.min_discount_percent ||
    !!urlFilter?.max_discount_percent;
  const activeSortLabel = SORT_OPTIONS.find(
    (o) => o.value === (filter?.sort_filter || "default"),
  )?.label;

  // Adapt the sparse listing payload to the shape the cards expect.
  const firstImage = (p: any) => {
    const img = p?.images?.[0];
    return (
      p?.image_url || (typeof img === "string" ? img : img?.image_url) || ""
    );
  };

  const adaptVariant = (v: any, p: any) => ({
    ...v,
    price: v?.price ?? p?.price ?? p?.min_price ?? 0,
    discounted_price: v?.discounted_price ?? 0,
    stock: v?.stock ?? 0,
    is_unlimited_stock: v?.is_unlimited_stock ?? p?.is_unlimited_stock ?? 0,
    status: v?.status ?? 1,
    measurement: v?.measurement ?? v?.attributes_text ?? "",
    unit: v?.unit ?? { short_code: "" },
  });

  const adaptProduct = (p: any) => {
    const hasVariants = Array.isArray(p?.variants) && p.variants.length > 0;
    return {
      ...p,
      name: p?.name || p?.short_description || "",
      image_url: firstImage(p),
      total_allowed_quantity: p?.total_allowed_quantity ?? p?.stock ?? 999,
      average_rating: p?.average_rating ?? p?.rating ?? "3",
      rating_count: p?.rating_count || 0,
      time_to_deliver: p?.time_to_deliver || "",
      is_featured: p?.is_featured ?? false,
      variants: hasVariants
        ? p.variants.map((v: any) => adaptVariant(v, p))
        : [
            {
              id: p?.variant_id ?? p?.id,
              price: p?.price ?? p?.min_price ?? 0,
              discounted_price: p?.discounted_price ?? 0,
              stock: p?.stock ?? 0,
              is_unlimited_stock: p?.is_unlimited_stock ?? 0,
              status: 1,
              measurement: "",
              unit: { short_code: "" },
            },
          ],
    };
  };

  // Stable per-product objects so memoized cards skip re-render on append.
  const adaptedProducts = useMemo(
    () => productResult.map((p: any) => adaptProduct(p)),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [productResult],
  );

  // Attribute filter on → one card per matching variant (white in sm and m = 2 cards).
  const selectedAttrIds = useMemo(
    () =>
      (urlFilter?.attribute_value_ids ?? [])
        .map((id: any) => Number(id))
        .filter((n: number) => !Number.isNaN(n)),
    [urlFilter?.attribute_value_ids],
  );

  // Same query key as the filter sidebar — served from cache, no extra request.
  const { filters: filterOptions } = useProductFilters({
    categoryId: resolvedCategoryIdCsv,
    latitude,
    longitude,
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

  // Listing variants carry `variant_attributes: [{name, value}]` with no ids,
  // so the selected ids are resolved to names through the filter options.
  const selectedAttrGroups = useMemo(() => {
    if (selectedAttrIds.length === 0) return [];
    const norm = (v: any) => String(v ?? "").trim().toLowerCase();
    const groups: { name: string; values: Set<string> }[] = [];
    for (const attr of filterOptions?.attributes ?? []) {
      const picked = (attr?.values ?? []).filter((v: any) =>
        selectedAttrIds.includes(Number(v?.id)),
      );
      if (picked.length === 0) continue;
      groups.push({
        name: norm(attr?.name),
        values: new Set(picked.map((v: any) => norm(v?.value))),
      });
    }
    return groups;
  }, [filterOptions, selectedAttrIds]);

  const displayCards = useMemo(() => {
    const asProductCard = (p: any) => ({ key: String(p?.id), product: p });
    if (selectedAttrGroups.length === 0) return adaptedProducts.map(asProductCard);

    const norm = (v: any) => String(v ?? "").trim().toLowerCase();
    const variantMatches = (v: any) => {
      const pairs = Array.isArray(v?.variant_attributes)
        ? v.variant_attributes
        : v?.attributes;
      if (!Array.isArray(pairs) || pairs.length === 0) return false;
      return selectedAttrGroups.every((g) => {
        const sameAxis = pairs.filter((a: any) => norm(a?.name) === g.name);
        // Axis missing on this payload — fall back to a value-only match.
        const pool = sameAxis.length > 0 ? sameAxis : pairs;
        return pool.some((a: any) =>
          g.values.has(norm(a?.value ?? a?.attribute_value)),
        );
      });
    };

    const rows: any[] = [];
    for (const p of adaptedProducts) {
      const matches = (p?.variants ?? []).filter(variantMatches);
      // Nothing matched (payload without attribute data) — keep the plain card.
      if (matches.length === 0) {
        rows.push(asProductCard(p));
        continue;
      }
      for (const v of matches) {
        const img = v?.image || firstImage(v);
        rows.push({
          key: `${p?.id}-${v?.id}`,
          product: {
            ...p,
            name: v?.name || p?.name,
            variants: [v],
            ...(img ? { image_url: img } : {}),
          },
        });
      }
    }
    return rows;
  }, [adaptedProducts, selectedAttrGroups]);

  useEffect(() => {
    prevCountRef.current = displayCards.length;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [productResult.length]);

  const placeholderItems = Array.from({ length: 12 }).map((_, index) => index);

  // ── Mobile (Blinkit) ──
  // Mobile navigation rail category items
  const kidsOf = (n: any): any[] =>
    Array.isArray(n?.cat_active_childs) ? n.cat_active_childs : [];
  const nameOf = (n: any) => n?.translations?.name ?? n?.name;
  const railItems = useMemo(() => {
    if (listing_source !== "category" || !childCategories?.length) return [];
    return childCategories.map((child: any) => ({
      id: child.id,
      node: child,
      name: nameOf(child),
      image: child?.image_url,
      kids: kidsOf(child),
      csv: toCategorySlugCsv(collectLeafCategoryEntries(child)),
    }));
  }, [childCategories, listing_source]);
  const hasRail = railItems.length > 0;
  const [pickedRailId, setPickedRailId] = useState<any>(null);
  // Rail pick to restore after a back-navigation (see restore effect below).
  const pendingRailPickRef = useRef<any>(null);
  useEffect(() => {
    setPickedRailId(pendingRailPickRef.current);
    pendingRailPickRef.current = null;
  }, [category_slug]);
  const activeRail =
    railItems.find((r: any) => r.id === pickedRailId) ?? railItems[0] ?? null;
  // Mobile only: right side shows subcategory tiles instead of products.
  const railShowsTiles = !!activeRail && activeRail.kids.length > 0;

  // Mobile entry default category filter
  const railSeededRef = useRef<string | null>(null);
  useEffect(() => {
    if (!hasRail || railSeededRef.current === category_slug) return;
    if (!window.matchMedia("(max-width: 767px)").matches) return;
    railSeededRef.current = category_slug;
    const first = railItems[0];
    if (first && first.kids.length === 0 && first.csv) setCategoryId(first.csv);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hasRail, category_slug, railItems]);

  const handleRailClick = (item: any) => {
    if (item.id === activeRail?.id) return;
    setPickedRailId(item.id);
    if (item.kids.length === 0) setCategoryId(item.csv);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  // Manage session storage context for category navigation
  const searchParams = useSearchParams();
  const searchKey = searchParams?.toString() ?? "";
  const urlCat = searchParams?.get("cat") || "";

  // A "products" banner names the screen it opens; its heading outranks the
  // category crumb, and an empty redirect_title falls back to "Products".
  const bannerTitle = searchParams?.get(LISTING_TITLE_PARAM) || "";
  const mobileTitle =
    bannerTitle ||
    categoryBreadcrumb?.[categoryBreadcrumb.length - 1]?.name ||
    (filter?.search ? `"${filter.search}"` : t("products") || "Products");
  const ctxKey = (slug: string) => `plist-ctx:${slug}`;

  // Remember this category's context so a later Back can restore it.
  useEffect(() => {
    if (listing_source !== "category" || !category_slug) return;
    try {
      window.sessionStorage.setItem(
        ctxKey(category_slug),
        JSON.stringify({ crumb: categoryBreadcrumb ?? [], railPick: pickedRailId }),
      );
    } catch {
      // storage unavailable — Back still works, just without the breadcrumb.
    }
  }, [listing_source, category_slug, categoryBreadcrumb, pickedRailId]);

  // Sync category state from URL query parameter
  const pendingNavRef = useRef<string | null>(null);
  useEffect(() => {
    if (!isHydrated || !urlCat) return;
    if (pendingNavRef.current) {
      if (pendingNavRef.current !== urlCat) return;
      pendingNavRef.current = null;
    }
    if (urlCat === category_slug) return;
    let ctx: any = null;
    try {
      ctx = JSON.parse(window.sessionStorage.getItem(ctxKey(urlCat)) || "null");
    } catch {
      ctx = null;
    }
    // Prevent one-shot category slug resolution overwrite
    resolvedSlugRef.current = urlCat;
    railSeededRef.current = urlCat;
    pendingRailPickRef.current = ctx?.railPick ?? null;
    dispatch(setListingSource({ data: "category" }));
    if (ctx?.crumb) dispatch(setCategoryBreadcrumb({ data: ctx.crumb }));
    dispatch(setCategorySlug({ data: urlCat }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchKey, isHydrated, category_slug]);

  // Sync category slug to URL query string
  useEffect(() => {
    if (listing_source !== "category" || !category_slug || urlCat) return;
    const params = new URLSearchParams(window.location.search);
    params.set("cat", category_slug);
    router.replace(`${window.location.pathname}?${params.toString()}`, { scroll: false });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchKey, listing_source, category_slug]);

  // Subcategory tile → that category's own product listing.
  const openSubcategory = (cat: any) => {
    pendingNavRef.current = cat.slug;
    const crumb = [
      ...(categoryBreadcrumb ?? []),
      { id: cat.id, name: nameOf(cat), slug: cat.slug },
    ];
    dispatch(setListingSource({ data: "category" }));
    dispatch(setCategorySlug({ data: cat.slug }));
    dispatch(setCategoryBreadcrumb({ data: crumb }));
    dispatch(setSelectedCategories({ data: cat.id }));
    dispatch(setBlockSource());
    const params = new URLSearchParams(buildQueryPatch({ category_id: cat.slug }));
    params.set("cat", cat.slug);
    router.push(`${zoneHref("/products")}?${params.toString()}`);
  };

  return (
    // Mobile: light grey page so the framed image boxes stand out (app style).
    <section className="max-md:bg-[#f4f6fb] max-md:min-h-screen dark:max-md:bg-zinc-950">
      <div>
        <div className="max-md:hidden">
          <BreadCrumb title={bannerTitle || undefined} />
        </div>
        {/* Mobile title + Filters / Sort chips (Blinkit). */}
        <div className="md:hidden border-b border-gray-100 bg-white dark:border-zinc-800 dark:bg-zinc-900">
          <div className="flex items-center gap-1 px-2 pt-2.5">
            <button
              type="button"
              aria-label={t("back") || "Back"}
              onClick={() =>
                window.history.length > 1 ? router.back() : router.push(zoneHref("/"))
              }
              className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full textColor active:bg-black/5"
            >
              <LuChevronLeft size={24} className="rtl:rotate-180" />
            </button>
            <h1 className="min-w-0 flex-1 truncate text-[20px] font-bold capitalize textColor">
              {mobileTitle}
            </h1>
            <button
              type="button"
              aria-label={t("cart") || "Cart"}
              onClick={() => router.push(zoneHref("/cart"))}
              className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full textColor active:bg-black/5"
            >
              <span data-cart-target className="relative inline-flex">
                <IoCartOutline size={24} />
                {isHydrated && cartItemCount > 0 && (
                  <span className="absolute -top-1 -right-1.5 flex h-[16px] min-w-[16px] items-center justify-center rounded-full primaryBackColor px-1 text-[9px] font-bold leading-none text-white">
                    <span key={cartItemCount} className="motion-safe:animate-qtyPop">
                      {cartItemCount}
                    </span>
                  </span>
                )}
              </span>
            </button>
          </div>
          <div className={`flex gap-2 px-4 py-2.5 ${railShowsTiles ? "hidden" : ""}`}>
            {!hideFilter && (
              <button
                type="button"
                onClick={() => setShowFilter(true)}
                className={`relative flex h-9 items-center gap-1.5 rounded-lg border px-3 text-[13px] font-medium transition active:scale-95 ${
                  hasActiveFilter
                    ? "primaryBorderColor primaryColor primaryLightBack"
                    : "border-gray-200 textColor dark:border-zinc-700"
                }`}
              >
                <LuSlidersHorizontal size={15} />
                {t("filters") || t("filter") || "Filters"}
                <LuChevronDown size={15} />
              </button>
            )}
            <button
              type="button"
              onClick={() => setShowSort(true)}
              className={`flex h-9 min-w-0 items-center gap-1.5 rounded-lg border px-3 text-[13px] font-medium transition active:scale-95 ${
                filter?.sort_filter && filter.sort_filter !== "default"
                  ? "primaryBorderColor primaryColor primaryLightBack"
                  : "border-gray-200 textColor dark:border-zinc-700"
              }`}
            >
              <LuArrowUpDown size={15} className="shrink-0" />
              <span className="truncate">{t(activeSortLabel || "default") || "Default"}</span>
              <LuChevronDown size={15} className="shrink-0" />
            </button>
            {/* Mobile list / grid switcher. */}
            <div className="ms-auto flex h-9 shrink-0 items-center rounded-full bg-gray-100 p-1 dark:bg-zinc-800">
              <button
                type="button"
                aria-label={t("list_view") || "List view"}
                aria-pressed={isList}
                onClick={() => setViewMode("list")}
                className={`flex h-7 w-7 items-center justify-center rounded-full transition ${
                  isList
                    ? "bg-white shadow-sm primaryColor dark:bg-zinc-900"
                    : "text-gray-400"
                }`}
              >
                <LuList size={14} />
              </button>
              <button
                type="button"
                aria-label={t("grid_view") || "Grid view"}
                aria-pressed={!isList}
                onClick={() => setViewMode(lastGridColsRef.current)}
                className={`flex h-7 w-7 items-center justify-center rounded-full transition ${
                  !isList
                    ? "bg-white shadow-sm primaryColor dark:bg-zinc-900"
                    : "text-gray-400"
                }`}
              >
                <LuLayoutGrid size={14} />
              </button>
            </div>
          </div>
        </div>
        <div className="container max-md:px-0">
          <div className="mb-5 md:mb-8 md:mt-2">
            <div>
              <div className="flex gap-6 max-md:gap-0">
                {/* Mobile subcategory rail (Blinkit). */}
                {hasRail && (
                  <aside
                    className="md:hidden sticky w-[72px] shrink-0 self-start overflow-y-auto border-e border-gray-100 bg-white [scrollbar-width:none] dark:border-zinc-800 dark:bg-zinc-900 [&::-webkit-scrollbar]:hidden"
                    style={{ top: headerH, maxHeight: `calc(100dvh - ${headerH}px)` }}
                  >
                    {railItems.map((item: any) => {
                      const active = item.id === activeRail?.id;
                      return (
                        <button
                          key={item.id}
                          type="button"
                          onClick={() => handleRailClick(item)}
                          className={`relative flex w-full flex-col items-center gap-1 px-1 py-2.5 text-center ${
                            active ? "bg-[color-mix(in_srgb,var(--primary-color)_6%,white)] dark:bg-zinc-800/60" : ""
                          }`}
                        >
                          {active && (
                            <span className="absolute inset-y-2 end-0 w-[3px] rounded-s-full bg-[var(--primary-color)]" />
                          )}
                          <span
                            className={`relative flex h-12 w-12 items-center justify-center overflow-hidden rounded-full ${
                              active
                                ? "bg-[color-mix(in_srgb,var(--primary-color)_14%,white)]"
                                : "bg-gray-100 dark:bg-zinc-800"
                            }`}
                          >
                            {item.image ? (
                              <ImageWithPlaceholder
                                src={item.image}
                                alt={item.name}
                                width={96}
                                height={96}
                                className="h-full w-full object-contain p-1"
                              />
                            ) : (
                              <LuLayoutGrid size={20} className="primaryColor" />
                            )}
                          </span>
                          <span
                            className={`line-clamp-2 text-[11px] leading-tight ${
                              active ? "font-bold textColor" : "SecondaryTextColor"
                            }`}
                          >
                            {item.name}
                          </span>
                        </button>
                      );
                    })}
                  </aside>
                )}
                {/* Desktop filter sidebar */}
                {!hideFilter && (
                  <aside
                    className="hidden lg:block w-[280px] shrink-0 self-start sticky overflow-y-auto overscroll-contain custom-scrollbar"
                    style={{
                      // headerH is the floor — the strip vars are 0 without it.
                      top: `max(${headerH}px, calc(var(--layout-header-h) + var(--layout-strip-h)))`,
                      maxHeight: `calc(100vh - max(${headerH}px, calc(var(--layout-header-h) + var(--layout-strip-h))) - 1rem)`,
                    }}
                  >
                    <Filter
                      setProductResult={setProductResult}
                      setOffset={setOffset}
                      minPrice={minPrice}
                      maxPrice={maxPrice}
                      values={values}
                      setValues={setValues}
                      setMinPrice={setMinPrice}
                      setMaxPrice={setMaxPrice}
                    />
                  </aside>
                )}

                <div className={`flex flex-1 min-w-0 flex-col gap-6 max-md:gap-0 max-md:pt-2 ${hasRail ? "max-md:px-1.5" : "max-md:px-2"}`}>
                  <div
                    // Desktop/tablet only — mobile uses the bottom Sort | Filter bar.
                    className={`hidden md:block ${listing_source === "category" ? "mb-1" : "mb-2"}`}
                  >
                    {loading ? (
                      <CardSkeleton height={70} />
                    ) : (
                      <div
                        className={` flex justify-between flex-col md:flex-row  md:items-center px-4 py-3 cardBorder border rounded-xl gap-3 md:gap-0  headerBackgroundColor  `}
                      >
                        <div className="flex items-center gap-3 order-1 md:order-1">
                          {!hideFilter && (
                            <button
                              type="button"
                              onClick={() => setShowFilter(true)}
                              className="flex lg:hidden items-center gap-2 rounded-lg primaryBackColor text-white px-4 h-10 text-sm font-semibold transition hover:opacity-90 active:scale-[0.98]"
                            >
                              <IoFilter size={18} />
                              {t("filter")}
                            </button>
                          )}
                          <p className="text-sm font-medium text-gray-500">
                            <span className="font-bold text-foreground">
                              {totalProducts}
                            </span>{" "}
                            {t("products_found")}
                          </p>
                        </div>
                        <div className="flex justify-between items-center gap-3 order-2 md:order-2 ">
                          <div className="flex flex-1 md:flex-none  gap-2 items-center">
                            <p className="hidden sm:block text-sm text-nowrap font-medium text-gray-500">
                              {t("sortBy")}
                            </p>
                            <Select
                              onValueChange={sortProduct}
                              value={filter?.sort_filter}
                            >
                              <SelectTrigger className="w-full md:w-[150px] lg:w-[200px] h-10 buttonBackground border-none rounded-lg font-medium">
                                <SelectValue placeholder={t("default")} />
                              </SelectTrigger>
                              <SelectContent className="w-[180px] md:w-[150px] lg:w-[200px] h-full z-30">
                                {SORT_OPTIONS.map((o) => (
                                  <SelectItem key={o.value} value={o.value}>
                                    {t(o.label)}
                                  </SelectItem>
                                ))}
                              </SelectContent>
                            </Select>
                          </div>
                          {/* View switcher; 4/5 columns only at xl. */}
                          <div className="hidden md:flex items-center gap-1 buttonBackground rounded-lg p-1">
                            <button
                              type="button"
                              aria-label="list view"
                              aria-pressed={isList}
                              onClick={() => setViewMode("list")}
                              className={`flex h-8 w-8 items-center justify-center rounded-md transition ${
                                isList
                                  ? "primaryBackColor text-white shadow-sm"
                                  : "text-gray-500 hover:text-foreground"
                              }`}
                            >
                              <FaThList size={15} />
                            </button>
                            {[2, 3, 4, 5].map((cols) => (
                              <button
                                key={cols}
                                type="button"
                                aria-label={`${cols} columns`}
                                aria-pressed={!isList && viewMode === cols}
                                onClick={() => setViewMode(cols)}
                                className={`h-8 w-8 items-center justify-center rounded-md transition ${
                                  cols >= 4 ? "hidden xl:flex" : "flex"
                                } ${
                                  !isList && viewMode === cols
                                    ? "primaryBackColor text-white shadow-sm"
                                    : "text-gray-500 hover:text-foreground"
                                }`}
                              >
                                <ColumnsIcon count={cols} size={16} />
                              </button>
                            ))}
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                  {/* Mobile: just the count, scrolls away with the page. */}
                  <p className="hidden">
                    {loading ? (
                      <span className="inline-block h-3 w-28 animate-pulse rounded bg-gray-200 dark:bg-zinc-700" />
                    ) : (
                      <>
                        <span className="font-bold textColor">{totalProducts}</span>{" "}
                        {t("products_found")}
                      </>
                    )}
                  </p>
                  {railShowsTiles && (
                    <div className="md:hidden grid grid-cols-3 gap-x-2 gap-y-4 px-1 pt-1 pb-6">
                      {activeRail.kids.map((sub: any) => (
                        <button
                          key={sub.id}
                          type="button"
                          onClick={() => openSubcategory(sub)}
                          className="flex flex-col items-center gap-1.5 text-center transition-transform active:scale-95"
                        >
                          <span className="relative block aspect-square w-full overflow-hidden rounded-2xl bg-[color-mix(in_srgb,var(--primary-color)_8%,white)] dark:bg-zinc-800">
                            <ImageWithPlaceholder
                              src={sub?.image_url}
                              alt={nameOf(sub) || "category"}
                              width={160}
                              height={160}
                              className="h-full w-full object-contain p-1.5"
                            />
                          </span>
                          <span className="line-clamp-2 text-[12px] font-medium leading-tight textColor">
                            {nameOf(sub)}
                          </span>
                        </button>
                      ))}
                    </div>
                  )}
                  <LayoutGroup>
                    <div
                      className={`grid gap-4 auto-rows-min ${railShowsTiles ? "max-md:hidden" : ""} ${hasRail ? "max-md:gap-1.5" : "max-md:gap-2"} ${
                        isList
                          ? // Not product-grid-cols — its media rule would overflow rows.
                            "grid-cols-1 lg:grid-cols-2 xl:grid-cols-3"
                          : `product-grid-cols grid-cols-2 ${hasRail ? "" : "max-md:grid-cols-3"}`
                      }`}
                      style={
                        isList
                          ? undefined
                          : ({
                              "--grid-cols": gridCols,
                            } as React.CSSProperties)
                      }
                    >
                      {loading ? (
                        placeholderItems.map((index: number) => (
                          <div key={index}>
                            <CardSkeleton
                              variant={isList ? "list" : "product"}
                            />
                          </div>
                        ))
                      ) : isError && productResult?.length <= 0 ? (
                        <div className="col-span-full grid place-items-center gap-3 py-16 text-center">
                          <p className="font-semibold text-base fontColor">
                            {t("something_went_wrong") ||
                              "Something went wrong"}
                          </p>
                          <button
                            type="button"
                            onClick={() => refetch()}
                            className="rounded-lg primaryBackColor py-2 px-5 text-white text-sm font-medium"
                          >
                            {t("retry") || t("try_again") || "Retry"}
                          </button>
                        </div>
                      ) : productResult?.length <= 0 ? (
                        <NotFound
                          image={NoOrderSvg}
                          title={t("no_products_found")}
                          className="col-span-full"
                        />
                      ) : (
                        // eslint-disable-next-line react-hooks/refs
                        displayCards.map((card: any, index: number) => {
                          const adapted = card.product;
                          const isNew = index >= prevCountRef.current;
                          return (
                            // FLIP only on view-mode change, not on page append.
                            <m.div
                              key={card.key}
                              layout="position"
                              layoutDependency={viewMode}
                              initial={isNew ? { opacity: 0, y: 18 } : false}
                              animate={{ opacity: 1, y: 0 }}
                              transition={{
                                duration: 0.4,
                                ease: [0.22, 1, 0.36, 1],
                                // New page arrives card by card, not all at once.
                                delay: isNew ? Math.min(index - prevCountRef.current, 11) * 0.045 : 0,
                              }}
                            >
                              {isList ? (
                                <ListViewProductCard product={adapted} />
                              ) : (
                                <VerticleProductCard product={adapted} />
                              )}
                            </m.div>
                          );
                        })
                      )}

                      {isLoadMoreLoading
                        ? placeholderItems.map((index: number) => (
                            <m.div
                              key={`more-${index}`}
                              initial={{ opacity: 0, y: 24, scale: 0.96 }}
                              animate={{ opacity: 1, y: 0, scale: 1 }}
                              transition={{
                                duration: 0.4,
                                ease: [0.22, 1, 0.36, 1],
                                delay: (index % 6) * 0.06,
                              }}
                            >
                              <CardSkeleton
                                variant={isList ? "list" : "product"}
                              />
                            </m.div>
                          ))
                        : null}
                      {hasNextPage && (
                        <div
                          ref={loadMoreRef}
                          className="col-span-full h-1 w-full"
                          aria-hidden="true"
                        />
                      )}
                    </div>
                  </LayoutGroup>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <Sheet open={showSort} onOpenChange={setShowSort}>
        <SheetContent
          side="bottom"
          className="z-[60] rounded-t-2xl p-0 md:hidden"
        >
          <SheetTitle className="border-b px-5 pb-3 pt-4 text-xs font-bold uppercase tracking-wider SecondaryTextColor">
            {t("sortBy")}
          </SheetTitle>
          <ul className="py-1 pb-[calc(0.5rem+env(safe-area-inset-bottom))]">
            {SORT_OPTIONS.map((o) => {
              const active = (filter?.sort_filter || "default") === o.value;
              return (
                <li key={o.value}>
                  <button
                    type="button"
                    onClick={() => {
                      sortProduct(o.value);
                      setShowSort(false);
                    }}
                    className={`flex w-full items-center justify-between px-5 py-3 text-sm ${
                      active ? "font-semibold primaryColor" : "textColor"
                    }`}
                  >
                    {t(o.label)}
                    {active && <LuCheck size={16} />}
                  </button>
                </li>
              );
            })}
          </ul>
        </SheetContent>
      </Sheet>

      {!hideFilter && (
        <FilterDrawer
          showFilter={showFilter}
          setShowFilter={setShowFilter}
          setProductResult={setProductResult}
          setOffset={setOffset}
          minPrice={minPrice}
          maxPrice={maxPrice}
          values={values}
          setValues={setValues}
          setMaxPrice={setMaxPrice}
          setMinPrice={setMinPrice}
        />
      )}
    </section>
  );
};

export default Products;
