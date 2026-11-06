"use client";

import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AnimatePresence, m } from "framer-motion";
import dynamic from "next/dynamic";
import { usePathname, useSearchParams } from "next/navigation";
import { useInfiniteQuery, useQueryClient } from "@tanstack/react-query";
import { tabIdFromSlug, slugFromTabId } from "@/utils/categoryTabSlug";
import { useDispatch, useSelector } from "react-redux";
import * as api from "@/api/apiRoutes";
import {
  setLayoutTheme,
  setSelectedCategoryId as setSelectedCategoryIdAction,
  setShopMode,
  setDefaultApplied,
} from "@/redux/slices/shopModeSlice";
import SectionsRenderer from "./SectionsRenderer";
import SectionSkeleton from "./sections/SectionSkeleton";
import CategoryTabs from "../categories/CategoryTabs";
// Lazy — rarely-shown components.
const DemoBuyNow = dynamic(() => import("../demo/DemoBuyNow"), { ssr: false });
const Location = dynamic(() => import("../locationmodal/Location"), {
  ssr: false,
});
const StoreClosed = dynamic(
  () => import("@/components/store-closed/StoreClosed"),
);
const StoreClosedBanner = dynamic(
  () => import("@/components/store-closed/StoreClosedBanner"),
);
const NotFound = dynamic(() => import("../notfound/NotFound"));
import NoProductSvg from "@/assets/empty-state/no-product.svg";
import { t } from "@/utils/translation";
import useIsHydrated from "@/hooks/useIsHydrated";
import useScrollThresholdFetch from "@/hooks/useScrollThresholdFetch";
import { HOME_LAYOUT_INITIAL_SECTION_LIMIT } from "@/constants/homeLayout";
import { homeLayoutKey } from "@/utils/queryKeys";
import useFullCategoryTree from "@/hooks/useFullCategoryTree";

// Must match shopModeSlice's initial `mode` or the SSR query key mismatches on hydration.
const SHOP_MODE_SSR_DEFAULT = "quick";


interface HomeLayoutProps {
  initialHomeLayout?: any;
}

const HomeLayout = ({ initialHomeLayout = null }: HomeLayoutProps) => {
  const queryClient = useQueryClient();
  const dispatch = useDispatch();
  const city = useSelector((state: any) => state.City.city);
  const setting = useSelector((state: any) => state.Setting.setting);
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  const storeClosedSoft =
    useSelector((state: any) => state.ShopMode?.storeClosed) === true;
  const isHydrated = useIsHydrated();
  const latitude = !isHydrated
    ? initialHomeLayout?.latitude
    : city?.latitude ||
      setting?.default_city?.latitude ||
      initialHomeLayout?.latitude;
  const longitude = !isHydrated
    ? initialHomeLayout?.longitude
    : city?.longitude ||
      setting?.default_city?.longitude ||
      initialHomeLayout?.longitude;
  const { resolveCategoryTree } = useFullCategoryTree({
    latitude,
    longitude,
    languageId: language?.id,
  });
  const ssrShopMode = initialHomeLayout?.shopMode || SHOP_MODE_SSR_DEFAULT;
  const persistedShopMode = useSelector((state: any) => state.ShopMode.mode);
  const shopMode = isHydrated ? persistedShopMode : ssrShopMode;
  const prevShopMode = useRef(shopMode);
  const hydrationHandledRef = useRef(false);

  // Adopt the channel the SSR body was rendered in, unless a default is already applied.
  const defaultApplied = useSelector((state: any) => state.ShopMode.defaultApplied);
  const ssrModeAdoptedRef = useRef(false);
  useEffect(() => {
    if (!isHydrated || ssrModeAdoptedRef.current) return;
    ssrModeAdoptedRef.current = true;
    if (defaultApplied || !initialHomeLayout?.shopMode) return;
    if (persistedShopMode !== ssrShopMode) {
      dispatch(setShopMode({ mode: ssrShopMode }));
    }
    dispatch(setDefaultApplied());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isHydrated]);

  const pathname = usePathname();
  const searchParams = useSearchParams();
  const tabSlugParam = searchParams?.get("tab") ?? null;
  const ssrCategoryId = initialHomeLayout?.categoryId ?? null;
  const knownTabs =
    (queryClient
      .getQueriesData({ queryKey: ["home-layout"] }) as any[])
      .filter(([key]: any) => key?.[4] === shopMode)
      // Infinite-query entries are { pages, pageParams } — the tabs live on page 0.
      .map(([, entry]: any) => entry?.pages?.[0]?.category_tabs)
      .find((tabs: any) => Array.isArray(tabs) && tabs.length > 0) ||
    (shopMode === ssrShopMode
      ? initialHomeLayout?.data?.category_tabs
      : null) ||
    [];
  const resolvedFromUrl = tabIdFromSlug(knownTabs, tabSlugParam);
  const urlCategoryId = tabSlugParam
    ? (resolvedFromUrl ?? ssrCategoryId)
    : null;

  // Only a user-driven tab change dims the sections — a background refetch
  // (post-hydration lat/lng key change, for one) must not fade the whole page.
  const [tabSwitchPending, setTabSwitchPending] = useState(false);
  // Clicked tab id, authoritative until useSearchParams reports the new URL.
  const [pendingTabId, setPendingTabId] = useState<any>(undefined);

  const selectedCategoryId =
    pendingTabId !== undefined ? pendingTabId : urlCategoryId;

  // Layout runs its own home_layout query off redux — mirror the tab into it.
  useEffect(() => {
    dispatch(setSelectedCategoryIdAction(selectedCategoryId ?? null));
  }, [selectedCategoryId, dispatch]);

  const setSelectedCategoryId = (id: any) => {
    setPendingTabId(id ?? null);
    // No eager redux dispatch: the URL mirror above owns it, so the header
    // (which reads redux) cannot switch tab ahead of the body (which reads the URL).
    setTabSwitchPending(true);
    const slug = slugFromTabId(knownTabs, id);

    const visiblePath = pathname || "/";
    const params = new URLSearchParams(searchParams?.toString());
    if (slug) params.set("tab", slug);
    else params.delete("tab");
    params.delete("zone");
    params.delete("lang");
    const search = params.toString();
    const nextUrl = search ? `${visiblePath}?${search}` : visiblePath;

    // Native replaceState, not router.replace: a router navigation refetches the
    // RSC payload and re-runs the whole SSR data load (~1.5-2.5s) for a tab whose
    // sections the client already has cached. pendingTabId owns the tab until
    // useSearchParams catches up, so the URL drift that forced router.replace is gone.
    window.history.replaceState(window.history.state, "", nextUrl);
    const reduceMotion = window.matchMedia?.(
      "(prefers-reduced-motion: reduce)",
    ).matches;
    window.scrollTo({ top: 0, behavior: reduceMotion ? "auto" : "smooth" });
  };

  const [modeSwitching, setModeSwitching] = useState(false);

  const [device, setDevice] = useState(initialHomeLayout?.device || "web");
  useEffect(() => {
    const compute = () => {
      const w = window.innerWidth;
      let next = "web";
      if (w < 768) next = "app";
      else if (w < 1024) next = "tablet";
      setDevice(next);
    };
    compute();
    window.addEventListener("resize", compute);
    return () => window.removeEventListener("resize", compute);
  }, []);

  // Device left the query key (SSR seeds can't know the viewport), so a real
  // bucket change has to invalidate instead of landing on a different key.
  const prevDevice = useRef(device);
  useEffect(() => {
    if (prevDevice.current === device) return;
    prevDevice.current = device;
    queryClient.invalidateQueries({ queryKey: ["home-layout"] });
  }, [device, queryClient]);

  // Handle shop mode changes.
  useEffect(() => {
    if (!hydrationHandledRef.current) {
      hydrationHandledRef.current = isHydrated;
      prevShopMode.current = shopMode;
      return;
    }
    if (prevShopMode.current === shopMode) return;
    prevShopMode.current = shopMode;
    setSelectedCategoryId(null);
    setModeSwitching(true);
    queryClient.invalidateQueries({
      queryKey: homeLayoutKey({ latitude, longitude, categoryId: null, shopMode }),
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [shopMode, isHydrated, queryClient, latitude, longitude, language?.id]);

  // Freeze the seed's timestamp — a fresh Date.now() each render would keep
  // resetting staleTime.
  const [mountedAt] = useState(() => Date.now());
  // SSR already fetched page 0. Without seeding it the body showed a skeleton
  // and refetched the same payload on mount, so the header (which reads the SSR
  // tabs directly) painted a round-trip ahead of the sections.
  const ssrSeed = useMemo(() => {
    if (!initialHomeLayout?.data) return undefined;
    if (shopMode !== ssrShopMode) return undefined;
    if (String(selectedCategoryId ?? "") !== String(ssrCategoryId ?? ""))
      return undefined;
    if (String(latitude ?? "") !== String(initialHomeLayout.latitude ?? ""))
      return undefined;
    if (String(longitude ?? "") !== String(initialHomeLayout.longitude ?? ""))
      return undefined;
    return { pages: [initialHomeLayout.data], pageParams: [0] };
  }, [
    initialHomeLayout,
    shopMode,
    ssrShopMode,
    selectedCategoryId,
    ssrCategoryId,
    latitude,
    longitude,
  ]);

  // Infinite sections query for home layout.
  const {
    data: infiniteData,
    isLoading,
    isFetching,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
  } = useInfiniteQuery({
    queryKey: homeLayoutKey({
      latitude,
      longitude,
      categoryId: selectedCategoryId,
      shopMode,
    }),
    queryFn: async ({ pageParam }) => {
      const response = await api.getHomeLayout({
        latitude,
        longitude,
        category_id: selectedCategoryId,
        limit: HOME_LAYOUT_INITIAL_SECTION_LIMIT,
        offset: pageParam,
        device,
      });
      if (response?.status === 0 && response?.message) {
        return { storeClosed: true, message: response.message };
      }
      return response?.data ?? null;
    },
    initialPageParam: 0,
    getNextPageParam: (lastPage: any, allPages: any[]) => {
      const nextOffset = (allPages ?? []).reduce(
        (sum, page) => sum + (page?.layout?.sections?.length ?? 0),
        0,
      );
      const totalSections = lastPage?.total_sections;
      const lastPageCount = lastPage?.layout?.sections?.length ?? 0;
      const hasMore =
        typeof totalSections === "number"
          ? nextOffset < totalSections
          : lastPageCount >= HOME_LAYOUT_INITIAL_SECTION_LIMIT;
      return hasMore ? nextOffset : undefined;
    },
    enabled: !!(latitude && longitude),
    initialData: ssrSeed as any,
    initialDataUpdatedAt: ssrSeed ? mountedAt : undefined,
    placeholderData: (prev: any) =>
      Array.isArray(prev?.pages) && Array.isArray(prev?.pageParams)
        ? prev
        : undefined,
    staleTime: 1000 * 60 * 5,
    gcTime: 1000 * 60 * 30,
    refetchOnWindowFocus: false,
    refetchOnMount: false,
  });

  const data = infiniteData?.pages?.[0];

  // invalidateQueries starts the refetch asynchronously, so isFetching is still
  // false on the render right after the switch — wait for a real fetch first.
  const modeFetchSeen = useRef(false);
  useEffect(() => {
    if (!modeSwitching) {
      modeFetchSeen.current = false;
      return;
    }
    if (isFetching) {
      modeFetchSeen.current = true;
      return;
    }
    if (!modeFetchSeen.current) return;
     
    setModeSwitching(false);
  }, [isFetching, modeSwitching]);

  useEffect(() => {
    if (pendingTabId === undefined) return;
    if (String(pendingTabId ?? "") !== String(urlCategoryId ?? "")) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setPendingTabId(undefined);
  }, [pendingTabId, urlCategoryId]);

  const tabFetchSeen = useRef(false);
  useEffect(() => {
    if (!tabSwitchPending) {
      tabFetchSeen.current = false;
      return;
    }
    if (isFetching) {
      tabFetchSeen.current = true;
      return;
    }
    // Also clear once the URL has caught up with no fetch at all — a cached
    // (prefetched) tab would otherwise leave the flag stuck on.
    if (!tabFetchSeen.current && pendingTabId !== undefined) return;
     
    setTabSwitchPending(false);
  }, [isFetching, tabSwitchPending, pendingTabId]);

  // Sync layout header theme with active category tab.
  useEffect(() => {
    const tabs = data?.category_tabs;
    if (!Array.isArray(tabs) || tabs.length === 0) return;
    const activeId = selectedCategoryId ?? tabs[0]?.id;
    const activeTab = tabs.find((tab: any) => String(tab?.id) === String(activeId));
    const theme = activeTab?.background_theme ? activeTab : data?.layout;
    if (theme) dispatch(setLayoutTheme(theme));
  }, [data?.category_tabs, data?.layout, selectedCategoryId, dispatch]);

  // Prefetch category tab content into query cache.
  const prefetchTab = useCallback(
    (tabId: any) => {
      if (tabId == null || !latitude || !longitude) return;
      queryClient.prefetchInfiniteQuery({
        queryKey: homeLayoutKey({
          latitude,
          longitude,
          categoryId: tabId,
          shopMode,
        }),
        queryFn: async () => {
          const response = await api.getHomeLayout({
            latitude,
            longitude,
            category_id: tabId,
            limit: HOME_LAYOUT_INITIAL_SECTION_LIMIT,
            offset: 0,
            device,
          });
          if (response?.status === 0 && response?.message) {
            return { storeClosed: true, message: response.message };
          }
          return response?.data ?? null;
        },
        initialPageParam: 0,
        staleTime: 1000 * 60 * 5,
      });
    },
    [queryClient, latitude, longitude, shopMode, device],
  );

  const rawCategoryTabs = data?.category_tabs;
  const tabIdsKey = useMemo(
    () =>
      Array.isArray(rawCategoryTabs)
        ? rawCategoryTabs.map((tab: any) => tab?.id).join(",")
        : "",
    [rawCategoryTabs],
  );
  useEffect(() => {
    const tabs = data?.category_tabs;
    if (!Array.isArray(tabs) || tabs.length <= 1) return;
    // Neighbour tabs are a convenience, not the page — skip the extra requests
    // for visitors on a metered or slow connection.
    const conn = (navigator as any)?.connection;
    if (conn?.saveData || /(^|-)2g$/.test(conn?.effectiveType || "")) return;
    const activeId = selectedCategoryId ?? tabs[0]?.id;
    const activeIndex = tabs.findIndex(
      (tab: any) => String(tab?.id) === String(activeId),
    );
    const neighbours = [tabs[activeIndex - 1], tabs[activeIndex + 1]].filter(
      Boolean,
    );
    const idle =
      typeof window !== "undefined" && "requestIdleCallback" in window
        ? (window as any).requestIdleCallback
        : (cb: () => void) => setTimeout(cb, 400);
    const cancelIdle =
      typeof window !== "undefined" && "cancelIdleCallback" in window
        ? (window as any).cancelIdleCallback
        : clearTimeout;
    const handle = idle(() => {
      neighbours.forEach((tab: any) => prefetchTab(tab.id));
    });
    return () => cancelIdle(handle);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tabIdsKey, selectedCategoryId, prefetchTab]);

  const firstPageSectionCount = data?.layout?.sections?.length ?? 0;

  const sections = useMemo(() => {
    const pages = infiniteData?.pages ?? [];
    const seenIds = new Set<any>();
    const all: any[] = [];
    for (const page of pages) {
      for (const section of page?.layout?.sections ?? []) {
        if (seenIds.has(section?.id)) continue;
        seenIds.add(section?.id);
        all.push(section);
      }
    }
    return all;
  }, [infiniteData?.pages]);

  const listKey = `${shopMode}|${selectedCategoryId ?? ""}|${device}`;
  const [mounted, setMounted] = useState({
    key: listKey,
    count: sections.length,
  });
  if (
    mounted.key !== listKey ||
    (mounted.count === 0 && sections.length > 0)
  ) {
    setMounted({ key: listKey, count: sections.length });
  }
  const mountedCount = Math.min(mounted.count, sections.length);
  const mountingPending = mountedCount < sections.length;
  useEffect(() => {
    if (!mountingPending) return;
    const idle =
      "requestIdleCallback" in window
        ? (cb: () => void) =>
            (window as any).requestIdleCallback(cb, { timeout: 150 })
        : (cb: () => void) => window.setTimeout(cb, 16);
    const cancel =
      "cancelIdleCallback" in window
        ? (id: number) => (window as any).cancelIdleCallback(id)
        : (id: number) => window.clearTimeout(id);
    const id = idle(() =>
      setMounted((m) => ({ ...m, count: m.count + 1 })),
    );
    return () => cancel(id);
  }, [mountingPending, mounted.count]);

  const buildSkeletonTypes = useCallback(
    (replacingAll: boolean) => {
      const totalSections = infiniteData?.pages?.[0]?.total_sections;
      let count = HOME_LAYOUT_INITIAL_SECTION_LIMIT;
      if (!replacingAll && typeof totalSections === "number") {
        count = Math.max(0, totalSections - sections.length);
      }
      count = Math.min(count, HOME_LAYOUT_INITIAL_SECTION_LIMIT) || 1;
      const template = replacingAll
        ? sections.slice(0, count)
        : sections.slice(-count);
      return Array.from(
        { length: count },
        (_, index) => template[index]?.blocks?.[0]?.type,
      );
    },
    [infiniteData?.pages, sections],
  );

  const sectionsContainerRef = useRef<HTMLDivElement>(null);
  useScrollThresholdFetch({
    threshold: 0.5,
    containerRef: sectionsContainerRef,
    enabled:
      !!hasNextPage &&
      !isFetchingNextPage &&
      !isFetching &&
      !mountingPending &&
      !!latitude &&
      !!longitude,
    onLoadMore: fetchNextPage,
  });

  // Dim from the click, not from the fetch — the URL (and so the fetch) only
  // catches up a tick later, and that gap read as a dead click. The highlight
  // (pendingTabId) already moves on click, so the dim can wait for real work.
  const tabSwitching =
    isHydrated &&
    tabSwitchPending &&
    isFetching &&
    !isFetchingNextPage &&
    !modeSwitching;

  if (!latitude || !longitude) {
    return (
      <div className="min-h-[60vh]">
        <Location showLocation={true} setShowLocation={() => {}} />
      </div>
    );
  }

  // Section mix is unknown until the response lands — SectionSkeleton falls back
  // to its product_slider shape for an undefined type.
  if ((isLoading && !data) || (modeSwitching && isFetching)) {
    return (
      <div aria-busy="true">
        {Array.from({ length: HOME_LAYOUT_INITIAL_SECTION_LIMIT }, (_, index) => (
          <SectionSkeleton
            key={`initial-skeleton-${index}`}
            type={index === 0 ? "banner_slider" : undefined}
            fullBleed={index === 0}
          />
        ))}
      </div>
    );
  }

  if (data?.storeClosed) {
    return <StoreClosed />;
  }

  const layout = data?.layout;
  const isCategoryWise = data?.home_type === "category_wise";
  const categoryTabs = isCategoryWise ? data?.category_tabs || [] : [];

  // Derived, not stored — storing would change the key and refetch.
  // The optimistic id only moves the highlight; the query still follows the URL.
  const highlightedTabId =
    pendingTabId !== undefined ? pendingTabId : selectedCategoryId;
  const activeTabId = highlightedTabId ?? categoryTabs[0]?.id ?? null;
  if (sections.length === 0 && categoryTabs.length === 0) return null;

  // Tab switch (not load-more): hide the previous tab's sections. Pagination
  // keeps loaded sections and appends placeholders below.
  const isSwitchingTab = tabSwitching;
  // Skeletons only for load-more, or a switch with nothing previous to show.
  const showSectionSkeletons =
    isFetchingNextPage || (isSwitchingTab && sections.length === 0);
  const renderedSections = sections.slice(0, mountedCount);
  const skeletonTypes = showSectionSkeletons
    ? buildSkeletonTypes(isSwitchingTab)
    : [];

  const backgroundStyle: React.CSSProperties = {};
  if (layout?.text_color) {
    backgroundStyle.color = layout.text_color;
  }

  return (
    <div style={backgroundStyle} dir={isHydrated ? language?.type : undefined}>
      <CategoryTabs
        categories={categoryTabs}
        selectedId={activeTabId}
        onSelect={setSelectedCategoryId}
        device={device}
      />

      {storeClosedSoft && <StoreClosedBanner />}

      {/* delay-200: a prefetched tab lands first and never flashes dim. */}
      <div
        ref={sectionsContainerRef}
        aria-busy={isSwitchingTab || undefined}
        className={`transition-opacity duration-200 ${
          isSwitchingTab
            ? "delay-200 pointer-events-none opacity-35"
            : "delay-0 opacity-100"
        }`}
      >
          {sections.length === 0 && !showSectionSkeletons && (
            <div className="container flex items-center justify-center min-h-[70vh]">
              <NotFound
                image={NoProductSvg}
                title={t("no_data_found")}
                size={400}
                className="!py-0 [&_img]:!max-w-[400px] [&_svg]:!max-w-[400px] [&_img]:!w-full [&_svg]:!w-full"
              />
            </div>
          )}
          <SectionsRenderer
            sections={renderedSections}
            device={device}
            resolveCategoryTree={resolveCategoryTree}
            firstPageSectionCount={firstPageSectionCount}
          />
          <AnimatePresence>
            {showSectionSkeletons && (
              <m.div
                key="section-skeletons"
                aria-busy="true"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.25, ease: [0.22, 1, 0.36, 1] }}
              >
                {skeletonTypes.map((type, index) => (
                  <SectionSkeleton
                    key={`section-skeleton-${index}`}
                    type={type}
                    fullBleed={type === "banner_slider"}
                  />
                ))}
              </m.div>
            )}
          </AnimatePresence>
      </div>
      {/* Renders only when demo_mode is "1". */}
      <DemoBuyNow />
    </div>
  );
};

export default HomeLayout;
