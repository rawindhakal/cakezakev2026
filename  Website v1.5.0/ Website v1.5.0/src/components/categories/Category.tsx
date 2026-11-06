"use client";

import React, { useEffect, useState } from "react";
import BreadCrumb from "../breadcrumb/BreadCrumb";
import * as api from "@/api/apiRoutes";
import { useQuery } from "@tanstack/react-query";
import CategoryPanel from "./CategoryPanel";
import { useParams, useRouter } from "next/navigation";
import { useDispatch, useSelector } from "react-redux";
import {
  setSelectedCategories,
  setListingSource,
  setCategorySlug,
  setCategoryBreadcrumb,
  setBlockSource,
} from "@/redux/slices/productFilterSlice";
import { t } from "@/utils/translation";
import { PackageOpen } from "lucide-react";
import useZoneHref from "@/hooks/useZoneHref";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import { categoriesKey } from "@/utils/queryKeys";
import useIsHydrated from "@/hooks/useIsHydrated";
import useInViewFetch from "@/hooks/useInViewFetch";
import useNavClick from "@/hooks/useNavClick";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";

const Category = ({ initialCategory = null }: { initialCategory?: any }) => {
  const zoneHref = useZoneHref();
  const { buildQueryPatch } = useUrlProductFilters();
  const dispatch = useDispatch();
  const router = useRouter();
  const { run: runNavClick } = useNavClick();
  const params = useParams();
  const slug = params?.slug;
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  const city = useSelector((state: any) => state.City);
  // SSR coords until hydrated — avoids refetching the seeded page.
  const isHydrated = useIsHydrated();
  const latitude = !isHydrated
    ? initialCategory?.latitude
    : city?.city?.latitude || initialCategory?.latitude;
  const longitude = !isHydrated
    ? initialCategory?.longitude
    : city?.city?.longitude || initialCategory?.longitude;

  const [page, setPage] = useState(1);
  const [loadedCategories, setLoadedCategories] = useState<any[]>([]);
  const categoryPerPage = 12;
  const slug_id = slug === "all" ? "" : slug;

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setPage(1);
    setLoadedCategories([]);
  }, [slug_id, language?.id]);

  const {
    data: categoriesResponse,
    isLoading,
    isFetching,
  } = useQuery({
    queryKey: categoriesKey({ page, slug: slug_id, latitude, longitude }),
    queryFn: async () => {
      const offset = (page - 1) * categoryPerPage;

      return api.getCategories({
        limit: categoryPerPage,
        offset,
        slug: slug_id,
        latitude,
        longitude,
      });
    },
    enabled: latitude != null && longitude != null,
    staleTime: 1000 * 60 * 5,
    gcTime: 1000 * 60 * 30,
  });

  const totalCategories = categoriesResponse?.total || 0;

  useEffect(() => {
    if (categoriesResponse?.data) {
      if (page === 1) {
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setLoadedCategories(categoriesResponse.data);
      } else {
        setLoadedCategories((prev) => {
          const existingIds = new Set(prev.map((c: any) => c.id));
          const newItems = categoriesResponse.data.filter(
            (c: any) => !existingIds.has(c.id),
          );
          return [...prev, ...newItems];
        });
      }
    }
  }, [categoriesResponse, page]);

  const categoryBreadcrumb = useSelector(
    (state: any) => state.ProductFilter.categoryBreadcrumb,
  );

  const navigateToCategory = (category: any) => {
    const exists = categoryBreadcrumb.some((c: any) => c.id === category.id);

    const newBreadcrumb = exists
      ? categoryBreadcrumb
      : [
          ...categoryBreadcrumb,
          {
            id: category.id,
            name: category.translations?.name || category.name,
            slug: category.slug,
          },
        ];

    dispatch(setListingSource({ data: "category" }));
    dispatch(setCategorySlug({ data: category.slug }));
    dispatch(setCategoryBreadcrumb({ data: newBreadcrumb }));
    dispatch(setSelectedCategories({ data: category.id }));
    // Clear stale "See All" block source, else it overrides this category.
    dispatch(setBlockSource());
    const qs = new URLSearchParams(
      buildQueryPatch({ category_id: category.slug }),
    ).toString();
    const dest = zoneHref("/products");
    router.push(qs ? `${dest}?${qs}` : dest);
  };

  // Programmatic push — start the progress bar explicitly.
  const handleCategoryClick = (category: any) =>
    runNavClick(() => navigateToCategory(category), category?.id);

  useEffect(() => {
    dispatch(setCategoryBreadcrumb({ data: [] }));
  }, [dispatch]);

  const hasMore = loadedCategories.length < totalCategories;

  const handleLoadMore = () => {
    if (!isFetching && hasMore) {
      setPage((prev) => prev + 1);
    }
  };

  const loadMoreSentinelRef = useInViewFetch({
    enabled: hasMore && !isLoading && !isFetching,
    onLoadMore: handleLoadMore,
  });

  // Direct loads have no breadcrumb — fall back to the SSR name.
  const title =
    categoryBreadcrumb?.find((c: any) => c.slug === slug)?.name ||
    (slug && slug !== "all" ? initialCategory?.name : null);

  const showingAll = !slug || slug === "all";

  const renderCategoryGrid = () => {
    if (isLoading && loadedCategories.length === 0) {
      return (
        <div className="my-8 grid grid-cols-2 gap-x-3 gap-y-14 pt-10 sm:grid-cols-4 sm:gap-x-4 lg:grid-cols-5 xl:grid-cols-6 max-md:my-0 max-md:grid-cols-4 max-md:gap-x-2.5 max-md:gap-y-4 max-md:pt-3 max-md:pb-6">
          {Array.from({ length: 12 }).map((_, index) => (
            <TileSkeleton key={index} />
          ))}
        </div>
      );
    }
    if (loadedCategories.length === 0) {
      return (
        <div className="my-16 flex flex-col items-center justify-center text-center">
          <div className="mb-4 flex h-16 w-16 items-center justify-center rounded-2xl primaryLightBack">
            <PackageOpen className="h-8 w-8 primaryColor" />
          </div>
          <h3 className="text-lg font-semibold text-slate-800 dark:text-zinc-100">
            {t("no_categories_found")}
          </h3>
          <p className="mt-1 text-sm text-slate-500 dark:text-zinc-400">
            {t("try_again_later")}
          </p>
        </div>
      );
    }
    return (
      <div className="my-8 grid grid-cols-2 gap-x-3 gap-y-14 pt-10 sm:grid-cols-4 sm:gap-x-4 lg:grid-cols-5 xl:grid-cols-6 max-md:my-0 max-md:grid-cols-4 max-md:gap-x-2.5 max-md:gap-y-4 max-md:pt-3 max-md:pb-6">
        {loadedCategories.map((category: any, index: number) => (
          <div
            key={category?.id}
            className="categoryCardIn"
            style={{ "--card-index": index % categoryPerPage } as React.CSSProperties}
          >
            {/* Mobile: Blinkit-style tile. Desktop keeps the panel + popover. */}
            <div className="md:hidden">
              <MobileCategoryTile category={category} onSelect={handleCategoryClick} />
            </div>
            <div className="max-md:hidden">
              <CategoryPanel category={category} onSelect={handleCategoryClick} />
            </div>
          </div>
        ))}
        {/* Load-more sentinel. */}
        {hasMore && (
          <div ref={loadMoreSentinelRef} className="col-span-full h-px" />
        )}
        {/* Always shown while more exist — hints to keep scrolling. */}
        {hasMore &&
          Array.from({ length: isFetching ? 6 : 2 }).map((_, i) => (
            <TileSkeleton key={`sk-${i}`} />
          ))}
      </div>
    );
  };

  return (
    <section className="bodyBackgroundColor min-h-screen">
      <div className="max-md:hidden">
        <BreadCrumb title={title} />
      </div>
      {/* Mobile: plain white title bar (Blinkit). */}
      <h1 className="md:hidden bg-white px-4 pb-3 pt-4 text-[24px] font-bold tracking-tight textColor dark:bg-zinc-900">
        {title || t("categories")}
      </h1>
      <div className="container">
        <div className="max-md:hidden categoryCardBackground relative mt-6 overflow-hidden rounded-2xl border border-slate-200/70 px-6 py-7 dark:border-zinc-800 sm:px-8 sm:py-8">
          <span className="pointer-events-none absolute -right-16 -top-16 h-44 w-44 rounded-full primaryLightBack blur-2xl" />
          <div className="relative flex flex-wrap items-end justify-between gap-3">
            <div>
              <h1 className="text-2xl font-extrabold tracking-tight text-slate-900 dark:text-zinc-50 sm:text-3xl">
                {title || (showingAll ? t("all_categories") : t("categories"))}
              </h1>
              <p className="mt-1.5 max-w-xl text-sm text-slate-500 dark:text-zinc-400">
                {t("browse_categories_subtitle")}
              </p>
            </div>
            {totalCategories > 0 && (
              <span className="inline-flex items-center gap-1.5 rounded-full border border-slate-200 bg-white px-3.5 py-1.5 text-sm font-semibold text-slate-700 shadow-sm dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-200">
                <span className="primaryColor">{totalCategories}</span>
                {t("categories")}
              </span>
            )}
          </div>
        </div>

        {renderCategoryGrid()}
      </div>
    </section>
  );
};

interface MobileCategoryTileProps {
  category: any;
  onSelect: (category: any) => void;
}

const MobileCategoryTile = ({ category, onSelect }: MobileCategoryTileProps) => {
  const name = category?.translations?.name ?? category?.name;
  return (
    <button
      type="button"
      onClick={() => onSelect(category)}
      className="flex w-full flex-col items-center gap-1.5 text-center transition-transform active:scale-95"
    >
      {/* Soft tint of the theme colour, so it re-tints per white-label build. */}
      <span className="relative block aspect-square w-full overflow-hidden rounded-2xl bg-[color-mix(in_srgb,var(--primary-color)_8%,white)] dark:bg-zinc-800">
        <ImageWithPlaceholder
          src={category?.image_url}
          alt={name || "category"}
          width={160}
          height={160}
          className="h-full w-full object-contain p-1.5"
        />
      </span>
      <span className="line-clamp-2 text-[12px] font-medium leading-tight textColor">
        {name}
      </span>
    </button>
  );
};

// Mobile tile skeleton; desktop shows the panel skeleton.
const TileSkeleton = () => (
  <>
    <div className="md:hidden flex flex-col items-center gap-1.5">
      <div className="aspect-square w-full animate-pulse rounded-2xl bg-slate-200 dark:bg-zinc-800" />
      <div className="h-3 w-12 animate-pulse rounded bg-slate-200 dark:bg-zinc-800" />
    </div>
    <div className="max-md:hidden">
      <PanelSkeleton />
    </div>
  </>
);

const PanelSkeleton = () => (
  <div className="categoryCardBackground relative flex h-28 flex-col items-center justify-center gap-2 rounded-2xl px-3 pb-4 pt-6 shadow-[0_0_20px_rgba(0,0,0,0.1)] dark:shadow-[0_0_20px_rgba(0,0,0,0.5)]">
    <div className="absolute left-1/2 top-0 h-20 w-20 -translate-x-1/2 -translate-y-1/2 animate-pulse rounded-full bg-slate-200 dark:bg-zinc-800" />
    <div className="mt-8 h-3.5 w-16 animate-pulse rounded bg-slate-200 dark:bg-zinc-800" />
    <div className="h-3 w-12 animate-pulse rounded bg-slate-100 dark:bg-zinc-800/70" />
  </div>
);

export default Category;
