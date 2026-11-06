"use client";

import { ProductStoryList } from "@/components/productstory/ProductStoryContext";
import { memo, useState, useEffect, useMemo, useRef, useDeferredValue } from "react";
import Image from "next/image";
import { IoArrowForward, IoChevronForward } from "react-icons/io5";
import { AnimatePresence, m } from "framer-motion";
import { Swiper, SwiperSlide } from "swiper/react";
import "swiper/css";
import { useDispatch, useSelector } from "react-redux";
import { useRouter } from "next/navigation";
import HomeVerticleProductCard from "../../productcards/HomeVerticleProductCard";
import HomeListViewCard from "../../productcards/HomeListViewCard";
import useDir from "@/hooks/useDir";
import useIsRtl from "@/hooks/useIsRtl";
import useT from "@/hooks/useT";
import useZoneHref from "@/hooks/useZoneHref";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import useNavClick from "@/hooks/useNavClick";
import * as api from "@/api/apiRoutes";
import { findNodeById } from "@/utils/categorySlugResolver";
import {
  clearAllFilter,
  setBlockSource,
  setListingSource,
  setCategorySlug,
  setCategoryBreadcrumb,
} from "@/redux/slices/productFilterSlice";
import {
  toCssAspectRatio,
  pickDeviceNumber,
  pickDeviceImage,
} from "@/utils/helperFunction";
import FolderTabOutline from "./FolderTabOutline";

interface ProductTabsSectionProps {
  block: any;
  borderRadius?: string | number;
  device?: string;
}

const ProductTabsSection = ({
  block,
  borderRadius,
  device = "web",
}: ProductTabsSectionProps) => {
  const dir = useDir();
  const rtl = useIsRtl();
  const tr = useT();
  const zoneHref = useZoneHref();
  const { buildQueryPatch } = useUrlProductFilters();
  const dispatch = useDispatch();
  const router = useRouter();
  const { run: runNavClick } = useNavClick();
  const cityLat = useSelector((state: any) => state.City.city?.latitude);
  const cityLng = useSelector((state: any) => state.City.city?.longitude);
  const config = block?.config || {};
  const tabs = useMemo(
    () => (Array.isArray(block?.tabs) ? block.tabs : []),
    [block?.tabs],
  );

  const tabRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const stripRef = useRef<HTMLDivElement | null>(null);
  const swiperRef = useRef<any>(null);
  const [{ activeIndex, direction }, setActive] = useState({
    activeIndex: 0,
    direction: 1,
  });
  const selectTab = (index: number) => {
    // Keep the tapped tab visible on narrow strips.
    const el = tabRefs.current[index];
    const strip = stripRef.current;
    if (el && strip && strip.scrollWidth > strip.clientWidth + 1) {
      const target =
        el.offsetLeft - (strip.clientWidth - el.offsetWidth) / 2;
      strip.scrollTo({ left: Math.max(0, target), behavior: "smooth" });
    }
    setActive((prev) =>
      prev.activeIndex === index
        ? prev
        : { activeIndex: index, direction: index > prev.activeIndex ? 1 : -1 },
    );
  };
  // Content follows a deferred index so the indicator animates before the
  // heavy product list re-renders.
  const contentIndex = useDeferredValue(activeIndex);
  const activeTab = tabs[Math.min(contentIndex, Math.max(tabs.length - 1, 0))];

  const [activeTabRect, setActiveTabRect] = useState<{
    left: number;
    top: number;
    width: number;
    height: number;
    stripWidth: number;
  } | null>(null);

  // Measure active tab bounding rect and strip scroll width.
  useEffect(() => {
    const activeEl = tabRefs.current[activeIndex];
    if (!activeEl) return;
    let alive = true;
    let frame = 0;
    // rAF-batched so ResizeObserver bursts (mobile URL bar, font swap) do not
    // thrash layout mid-scroll.
    const measure = () => {
      if (!alive) return;
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        if (!alive) return;
        const r = activeEl.getBoundingClientRect();
        const next = {
          left: activeEl.offsetLeft,
          top: activeEl.offsetTop,
          width: r.width,
          height: r.height,
          stripWidth: stripRef.current?.scrollWidth ?? r.width,
        };
        setActiveTabRect((prev) =>
          prev &&
          prev.left === next.left &&
          prev.top === next.top &&
          prev.width === next.width &&
          prev.height === next.height &&
          prev.stripWidth === next.stripWidth
            ? prev
            : next,
        );
      });
    };
    measure();
    document.fonts?.ready.then(measure);
    if (typeof ResizeObserver === "undefined") {
      return () => {
        alive = false;
        cancelAnimationFrame(frame);
      };
    }
    const observer = new ResizeObserver(measure);
    tabRefs.current.forEach((el) => el && observer.observe(el));
    if (stripRef.current) observer.observe(stripRef.current);
    return () => {
      alive = false;
      cancelAnimationFrame(frame);
      observer.disconnect();
    };
  }, [activeIndex, tabs]);

  const isMobileDevice = device === "app";
  const layout = String(block?.layout || "horizontal");
  const isGrid = layout.startsWith("grid");
  const isList = layout === "list";
  const gap = pickDeviceNumber(config?.product_grid_gap, device, 0);
  const gridCols =
    pickDeviceNumber(config?.grid_columns, device, 0) ||
    parseInt(layout.split("_")[1], 10) ||
    0;
  const slideCount =
    device === "app"
      ? gridCols || 3
      : device === "tablet"
        ? gridCols || 5
        : 0;

  const variant = config?.variant;
  const isDefault = !variant || variant === "default";
  const isColorVariant = variant === "with_color";

  const showTitle = isDefault ? false : !!config?.section_title;
  const title = showTitle ? config?.section_title : null;

  const bgImageUrl =
    config?.background_image_url &&
    typeof config.background_image_url === "object"
      ? pickDeviceImage(config.background_image_url, device)
      : config?.background_image_url;
  const hasBg =
    !isDefault && variant !== "with_title" && variant !== "with_color"
      ? !!bgImageUrl
      : false;

  const backgroundColor = isColorVariant
    ? config?.background_color || null
    : null;
  const textColor = isDefault ? null : config?.text_color || null;

  const cardRadius = config?.product_card_radius;
  const blockPadding = Number.isFinite(Number(config?.block_padding))
    ? Number(config.block_padding)
    : null;
  const hasPadding = blockPadding != null;
  const inlinePadding =
    isGrid || isList ? (hasPadding ? blockPadding : 0) : hasPadding ? blockPadding : 10;
  const inlinePaddingStyle = {
    paddingLeft: inlinePadding,
    paddingRight: inlinePadding,
  };
  const blockPaddingStyle = {
    paddingTop: hasPadding ? blockPadding : 0,
    paddingBottom: hasPadding ? blockPadding : 0,
  };

  const bgAspectPadding = (() => {
    if (!hasBg) return undefined;
    const imageAspectRaw =
      config?.image_aspect && typeof config.image_aspect === "object"
        ? pickDeviceImage(config.image_aspect, device)
        : config?.image_aspect;
    const ratio = toCssAspectRatio(imageAspectRaw);
    if (!ratio) return undefined;
    const [w, h] = ratio.split("/").map((n: any) => Number(n.trim()));
    if (!w || !h) return undefined;
    return `${(h / w) * 100}%`;
  })();

  const tabImageRatio =
    toCssAspectRatio(
      config?.tab_image_aspect && typeof config.tab_image_aspect === "object"
        ? pickDeviceImage(config.tab_image_aspect, device)
        : config?.tab_image_aspect,
    ) || "1/1";

  const rawTabStyle = String(config?.tab_style || "text").toLowerCase();
  const isIconTop = rawTabStyle.includes("icon");

  const tabTextColor = config?.tab_text_color || "#6c757d";
  const activeTabColor = config?.active_tab_color || "#212529";
  const activeOutlineColor = config?.active_outline_color || activeTabColor;
  const activeTabColor2 = config?.active_tab_color_2 || "";

  const activeBgImageUrl =
    config?.active_bg_image_url &&
    typeof config.active_bg_image_url === "object"
      ? pickDeviceImage(config.active_bg_image_url, device)
      : config?.active_bg_image_url;

  const activeBgImageAspect =
    toCssAspectRatio(
      config?.active_bg_image_aspect &&
        typeof config.active_bg_image_aspect === "object"
        ? pickDeviceImage(config.active_bg_image_aspect, device)
        : config?.active_bg_image_aspect,
    ) || undefined;

  const rawIndicator = String(config?.active_indicator || "none").toLowerCase();
  const isUnderline = [
    "underline",
    "under_line",
    "line",
  ].includes(rawIndicator);
  const isOutline = [
    "outline",
    "outlined",
    "outlined_tab",
    "outlined tab",
    "border",
    "folder",
    "folder tab",
  ].includes(rawIndicator);
  const isFill = [
    "fill",
    "filled",
    "filled_background",
    "filled background",
    "filled_bg",
    "fill background",
    "background",
    "bg",
  ].includes(rawIndicator);
  const isNone = !isUnderline && !isOutline && !isFill;

  const rawBgStyle = String(config?.active_bg_style || "none").toLowerCase();
  const effectiveBgStyle = (() => {
    if (isUnderline || isNone) return "none";
    if (isFill && (rawBgStyle === "none" || !rawBgStyle)) return "solid";
    return rawBgStyle;
  })();

  const hasActiveBackdrop = effectiveBgStyle !== "none";

  const activeBackgroundImage = (() => {
    if (effectiveBgStyle === "gradient") {
      const endColor = activeTabColor2 || "transparent";
      return `linear-gradient(180deg, ${activeTabColor}, ${endColor})`;
    }
    if (effectiveBgStyle === "image") {
      if (activeBgImageUrl) return `url(${activeBgImageUrl})`;
      return undefined;
    }
    return undefined;
  })();

  const activeBackgroundSolid = (() => {
    if (effectiveBgStyle === "solid") return activeTabColor;
    if (effectiveBgStyle === "image" && !activeBgImageUrl) return activeTabColor;
    return undefined;
  })();

  const curveFillColor = (() => {
    if (!hasActiveBackdrop) return undefined;
    if (effectiveBgStyle === "gradient") {
      return activeTabColor2 || activeTabColor;
    }
    if (effectiveBgStyle === "solid" || effectiveBgStyle === "image") {
      return activeBackgroundSolid;
    }
    return undefined;
  })();

  const activeTitleColor = (() => {
    if (config?.active_tab_text_color) return config.active_tab_text_color;
    if (isFill || (isOutline && hasActiveBackdrop)) {
      return config?.tab_text_color || "#ffffff";
    }
    return activeTabColor;
  })();

  const animation = String(config?.tab_animation || "none").toLowerCase();

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
      average_rating: p?.average_rating ?? p?.rating ?? 0,
      variants: hasVariants
        ? p.variants.map((v: any) => adaptVariant(v, p))
        : [
            {
              id: p?.variant_id ?? p?.id,
              price: p?.price ?? p?.min_price ?? 0,
              discounted_price: p?.discounted_price ?? 0,
              stock: p?.stock ?? 0,
              is_unlimited_stock: 1,
              status: 1,
              measurement: "",
              unit: { short_code: "" },
            },
          ],
    };
  };

  const limit = Number(activeTab?.limit ?? config?.limit) || 0;
  const products = Array.isArray(activeTab?.products)
    ? limit > 0
      ? activeTab.products.slice(0, limit)
      : activeTab.products
    : [];

  const dataSource =
    activeTab?.data_source ?? config?.data_source ?? block?.data_source ?? "";
  const viewMorePreviewImages = (
    activeTab?.viewMorePreviewImages ??
    config?.viewMorePreviewImages ??
    block?.viewMorePreviewImages ??
    []
  ).filter(Boolean);
  const hasViewMore = viewMorePreviewImages.length > 0;
  const previewThumbs = viewMorePreviewImages.slice(0, 3);
  const manualProductIds =
    activeTab?.manual_product_ids ?? config?.manual_product_ids ?? "";

  const firstId = (...values: any[]) => {
    const hit = values.find(
      (v) => v != null && v !== "" && !(Array.isArray(v) && v.length === 0),
    );
    if (hit == null) return "";
    return Array.isArray(hit)
      ? hit.filter((x: any) => x != null && x !== "").join(",")
      : String(hit);
  };

  // Scope lives on the tab — two tabs of one section can differ.
  const blockCategoryIds = firstId(
    activeTab?.category_ids,
    activeTab?.category_id,
    config?.category_ids,
    config?.category_id,
  );
  const blockBrandIds = firstId(
    activeTab?.brand_ids,
    activeTab?.brand_id,
    config?.brand_ids,
    config?.brand_id,
  );
  // Sent only for "everything except these" — never defaulted.
  const filterMode = activeTab?.filter_mode ?? config?.filter_mode ?? "";

  const sourceId =
    dataSource === "category"
      ? blockCategoryIds
      : dataSource === "brand"
        ? blockBrandIds
        : firstId(blockBrandIds, blockCategoryIds);

  const navigateSeeAll = async () => {
    dispatch(clearAllFilter({}));
    dispatch(
      setBlockSource({
        data_source: dataSource,
        manual_product_ids: manualProductIds,
        source_id: sourceId,
        category_ids: blockCategoryIds,
        brand_ids: blockBrandIds,
        filter_mode: filterMode,
      }),
    );
    let categoryIdPatch: string | null = null;
    let brandIdPatch: number[] | null = null;

    if (dataSource === "category" && sourceId) {
      try {
        const res = await api.getCategories({
          latitude: cityLat,
          longitude: cityLng,
        });
        const rows = Array.isArray(res?.data) ? res.data : [];
        const wantedId = String(sourceId).split(",")[0].trim();
        const match = findNodeById(rows, wantedId);
        if (match?.slug) {
          dispatch(setListingSource({ data: "category" }));
          dispatch(setCategorySlug({ data: match.slug }));
          dispatch(
            setCategoryBreadcrumb({
              data: [
                {
                  id: match.id,
                  name: match?.translations?.name || match?.name,
                  slug: match.slug,
                },
              ],
            }),
          );
          categoryIdPatch = match.slug;
        }
      } catch (error: any) {
        console.log("Tab See All category resolve failed", error?.message);
      }
    }

    if (dataSource === "brand" && sourceId) {
      brandIdPatch = String(sourceId)
        .split(",")
        .map((id) => id.trim())
        .filter(Boolean)
        .map(Number)
        .filter((n) => !Number.isNaN(n));
    }

    const qs = new URLSearchParams(
      buildQueryPatch({
        ...(categoryIdPatch && { category_id: categoryIdPatch }),
        ...(brandIdPatch?.length && { brand_ids: brandIdPatch }),
      }),
    ).toString();
    const dest = zoneHref("/products");
    router.push(qs ? `${dest}?${qs}` : dest);
  };

  const handleSeeAll = () => runNavClick(navigateSeeAll);

  const motionProps = (() => {
    if (animation === "fade") {
      return {
        initial: { opacity: 0 },
        animate: { opacity: 1 },
        exit: { opacity: 0 },
        transition: { duration: 0.22, ease: "easeOut" as const },
      };
    }
    if (animation === "slide") {
      const offset = 28 * direction * (rtl ? -1 : 1);
      return {
        initial: { opacity: 0, x: offset },
        animate: { opacity: 1, x: 0 },
        exit: { opacity: 0, x: -offset },
        transition: { duration: 0.26, ease: "easeOut" as const },
      };
    }
    return {};
  })();

  // One adapted array per tab: stable object identities keep the memoized
  // product cards from re-rendering on every parent render.
  const adaptedProducts = useMemo(
    () => products.map(adaptProduct),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [products],
  );

  // Swiper stays mounted across tabs; rewind instead of rebuilding it.
  useEffect(() => {
    const sw = swiperRef.current;
    if (!sw || sw.destroyed) return;
    sw.slideTo(0, 0);
    sw.update();
  }, [contentIndex]);

  if (tabs.length === 0) return null;

  return (
    <ProductStoryList products={adaptedProducts}>
    <section>
      <div
        className="relative overflow-hidden"
        style={{
          ...(borderRadius != null ? { borderRadius } : {}),
          ...(hasBg
            ? {
                backgroundImage: `url(${bgImageUrl})`,
                backgroundSize: "cover",
                backgroundPosition: "center",
                backgroundRepeat: "no-repeat",
              }
            : {}),
          ...(backgroundColor ? { backgroundColor } : {}),
          ...(textColor ? { color: textColor } : {}),
        }}
      >
        {bgAspectPadding && (
          <div
            aria-hidden
            className="float-left w-0"
            style={{ paddingTop: bgAspectPadding }}
          />
        )}

        <div className="relative" style={blockPaddingStyle} dir={dir}>
          {title && (
            <div
              className="flex justify-between items-center gap-3 mb-3"
              style={inlinePaddingStyle}
            >
              {/* Tab section heading */}
              <h2
                className={`text-[15px] sm:text-base font-bold leading-snug m-0 ${
                  textColor ? "" : "text-gray-900 dark:text-zinc-100"
                }`}
                style={textColor ? { color: textColor } : undefined}
              >
                {title}
              </h2>
            </div>
          )}

          {/* Horizontal scroll tab strip */}
          <div className="relative">
            <m.div
              layoutScroll={!isMobileDevice}
              className={`relative flex overflow-x-auto overscroll-x-contain [scrollbar-width:none] [&::-webkit-scrollbar]:hidden ${
                isOutline ? "gap-[16px]" : "gap-[10px]"
              }`}
              style={{
                ...inlinePaddingStyle,
                ...(isMobileDevice
                  ? { touchAction: "pan-x", WebkitOverflowScrolling: "touch" }
                  : {}),
                paddingLeft: isOutline
                  ? Math.max(Number(inlinePaddingStyle.paddingLeft || 0), 8)
                  : inlinePaddingStyle.paddingLeft,
                paddingRight: isOutline
                  ? Math.max(Number(inlinePaddingStyle.paddingRight || 0), 16)
                  : inlinePaddingStyle.paddingRight,
                paddingBottom: isOutline || hasActiveBackdrop ? 0 : 4,
              }}
              ref={stripRef}
              role="tablist"
            >
              {/* Single sliding fill indicator, driven by the measured active tab. */}
              {(isFill || (hasActiveBackdrop && !isOutline)) && activeTabRect && (
                <span
                  aria-hidden
                  className="pointer-events-none absolute left-0 top-0 z-0 transition-transform duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] will-change-transform"
                  style={{
                    width: activeTabRect.width,
                    height: activeTabRect.height,
                    transform: `translate3d(${activeTabRect.left}px, ${activeTabRect.top}px, 0)`,
                    borderRadius: isIconTop ? 12 : 9999,
                    ...(activeBackgroundImage
                      ? {
                          backgroundImage: activeBackgroundImage,
                          ...(activeBgImageUrl
                            ? { backgroundSize: "cover", backgroundPosition: "center" }
                            : {}),
                        }
                      : {}),
                    ...(activeBackgroundSolid
                      ? { backgroundColor: activeBackgroundSolid }
                      : {}),
                  }}
                />
              )}
              {tabs.slice(0, 8).map((tab: any, index: number) => {
                const isActive = index === activeIndex;
                const tabImage = pickDeviceImage(tab?.images, device);
                const sectionId = block?.id || block?._id || block?.title || "section";
                return (
                  <button
                    key={tab?.id ?? index}
                    ref={(el) => {
                      tabRefs.current[index] = el;
                    }}
                    type="button"
                    role="tab"
                    aria-selected={isActive}
                    onClick={() => selectTab(index)}
                    className={`relative flex shrink-0 items-center transition-colors ${
                      isIconTop
                        ? `w-[64px] min-w-[64px] flex-col text-center gap-1 py-1.5 px-1 ${
                            isOutline ? "justify-center" : "justify-start"
                          }`
                        : "px-3 py-1.5 flex-row justify-center text-center"
                    } ${
                      isOutline
                        ? "rounded-t-xl rounded-b-none"
                        : isFill || hasActiveBackdrop
                        ? isIconTop
                          ? "rounded-xl"
                          : "rounded-full"
                        : "rounded-lg"
                    } ${
                      isActive ? "z-10" : "z-0"
                    }`}
                    style={{
                      color: isActive ? activeTitleColor : tabTextColor,
                      ...(isActive &&
                      effectiveBgStyle === "image" &&
                      activeBgImageUrl &&
                      activeBgImageAspect
                        ? { aspectRatio: activeBgImageAspect, height: "auto" }
                        : {}),
                    }}
                  >
                    {isIconTop && tabImage && (
                      // Fixed 34px box keeps tab size constant; selected icon scales up (Blinkit-style).
                      <span
                        className="relative z-10 block h-auto w-[34px] shrink-0"
                        style={{ aspectRatio: tabImageRatio }}
                      >
                        <span
                          className={`absolute inset-0 overflow-hidden rounded transition-transform duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] ${
                            isActive ? "scale-100" : "scale-[0.76]"
                          }`}
                        >
                          <Image
                            src={tabImage}
                            alt={tab?.title || ""}
                            fill
                            className="object-cover"
                            sizes="34px"
                          />
                        </span>
                      </span>
                    )}
                    {tab?.title ? (
                      <span
                        className={`relative z-10 text-[12px] font-semibold leading-tight ${
                          isIconTop
                            ? "w-full line-clamp-2 break-words"
                            : "whitespace-nowrap"
                        }`}
                      >
                        {tab.title}
                      </span>
                    ) : null}
                    {/* Active underline indicator */}
                    {isActive && isUnderline && (
                      <m.span
                        layoutId={`productTabsActiveUnderline-${sectionId}`}
                        className={`z-10 block h-[2px] rounded-full ${
                          isIconTop
                            ? "absolute bottom-0 inset-x-1"
                            : "absolute bottom-0 inset-x-3"
                        }`}
                        style={{
                          backgroundColor: activeTabColor,
                        }}
                        transition={{ type: "spring", stiffness: 400, damping: 35 }}
                      />
                    )}
                  </button>
                );
              })}

              {/* Folder tab outline overlay */}
              {isOutline && activeTabRect && (
                <FolderTabOutline
                  tabLeft={activeTabRect.left}
                  width={activeTabRect.width}
                  height={activeTabRect.height}
                  stripWidth={activeTabRect.stripWidth}
                  fill={curveFillColor}
                  stroke={activeOutlineColor}
                  gradientFrom={
                    effectiveBgStyle === "gradient" ? activeTabColor : undefined
                  }
                  gradientTo={
                    effectiveBgStyle === "gradient"
                      ? activeTabColor2 || "transparent"
                      : undefined
                  }
                  backgroundImageUrl={
                    effectiveBgStyle === "image" ? activeBgImageUrl : undefined
                  }
                />
              )}

              {/* Baseline spacer */}
              {isOutline && <div aria-hidden className="min-w-4 flex-1 shrink-0" />}
            </m.div>
          </div>

          {/* Product list or grid area */}
          <AnimatePresence mode="wait" initial={false}>
            <m.div
              key={animation === "none" ? "static" : contentIndex}
              {...motionProps}
            >
              {products.length === 0 ? null : isGrid ? (
                <div
                  className={`grid ${isOutline ? "mt-1" : "mt-3"} ${
                    gridCols
                      ? ""
                      : "grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5"
                  }`}
                  style={{
                    ...inlinePaddingStyle,
                    gap: `${gap}px`,
                    ...(gridCols
                      ? {
                          gridTemplateColumns: `repeat(${gridCols}, minmax(0, 1fr))`,
                        }
                      : {}),
                  }}
                >
                  {adaptedProducts.map((product: any) => (
                    <div key={product.id} className="h-full">
                      <HomeVerticleProductCard
                        product={product}
                        radius={cardRadius}
                      />
                    </div>
                  ))}
                </div>
              ) : isList ? (
                <div
                  className={`${isOutline ? "mt-1" : "mt-3"} grid items-stretch ${
                    device === "web" ? "grid-cols-2" : "grid-cols-1"
                  }`}
                  style={{ ...inlinePaddingStyle, gap: `${gap}px` }}
                >
                  {adaptedProducts.map((product: any) => (
                    <div key={product.id} className="h-full">
                      <HomeListViewCard
                        product={product}
                        radius={cardRadius}
                      />
                    </div>
                  ))}
                </div>
              ) : (
                <div className={`relative ${isOutline ? "mt-1" : "mt-3"}`}>
                  <Swiper
                    key={`${String(rtl)}-${device}-${slideCount}`}
                    onSwiper={(sw: any) => {
                      swiperRef.current = sw;
                    }}
                    dir={dir}
                    slidesPerView={1.6}
                    spaceBetween={gap}
                    slidesOffsetBefore={inlinePadding}
                    slidesOffsetAfter={inlinePadding}
                    observer={true}
                    observeParents={true}
                    grabCursor={true}
                    simulateTouch={true}
                    className="brand-swiper [&_.swiper-wrapper]:items-stretch"
                    breakpoints={
                      slideCount
                        ? { 0: { slidesPerView: slideCount, spaceBetween: gap } }
                        : {
                            1536: { slidesPerView: 6, spaceBetween: gap },
                            1280: { slidesPerView: 6, spaceBetween: gap },
                            1024: { slidesPerView: 4, spaceBetween: gap },
                            768: { slidesPerView: 3, spaceBetween: gap },
                            640: { slidesPerView: 2.5, spaceBetween: gap },
                            480: { slidesPerView: 2.2, spaceBetween: gap },
                            0: { slidesPerView: 1.6, spaceBetween: gap },
                          }
                    }
                  >
                    {adaptedProducts.map((product: any) => (
                      <SwiperSlide key={product.id} className="!h-auto">
                        <div className="h-full">
                          <HomeVerticleProductCard
                            product={product}
                            radius={cardRadius}
                          />
                        </div>
                      </SwiperSlide>
                    ))}
                  </Swiper>
                </div>
              )}
            </m.div>
          </AnimatePresence>

          {/* View More button */}
          {hasViewMore && (
            <div className="mt-5 pb-4 flex justify-center" style={inlinePaddingStyle}>
              <button
                type="button"
                onClick={handleSeeAll}
                className="inline-flex max-w-full items-center gap-3 rounded-full bg-white dark:bg-zinc-900 p-1.5 pe-1.5 shadow-[0_3px_14px_rgba(0,0,0,0.16)] max-md:gap-2 max-md:p-1 max-md:shadow-[0_2px_10px_rgba(0,0,0,0.12)]"
              >
                <span className="flex items-center flex-shrink-0">
                  {previewThumbs.map((src: string, index: number) => (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      key={src}
                      src={src}
                      alt=""
                      aria-hidden
                      loading="lazy"
                      className="h-9 w-9 max-md:h-8 max-md:w-8 rounded-full object-contain bg-gray-50 dark:bg-zinc-800 p-0.5 ring-[3px] ring-white dark:ring-zinc-900"
                      style={{
                        ...(index === 0 ? {} : { marginInlineStart: "-12px" }),
                        zIndex: previewThumbs.length - index,
                      }}
                    />
                  ))}
                </span>

                <span className="px-1 text-[15px] max-md:text-[13px] font-bold tracking-tight primaryColor whitespace-nowrap">
                  {tr("view_more")}
                </span>

                <span
                  className="flex h-9 w-9 max-md:h-8 max-md:w-8 flex-shrink-0 items-center justify-center rounded-full text-white bg-[var(--primary-color)]"
                >
                  <IoArrowForward size={17} className="rtl:rotate-180 max-md:hidden" />
                  <IoChevronForward size={16} className="rtl:rotate-180 md:hidden" />
                </span>
              </button>
            </div>
          )}
        </div>
      </div>
    </section>
    </ProductStoryList>
  );
};

export default memo(ProductTabsSection);
