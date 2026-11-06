"use client";

import React from "react";
import { useDispatch } from "react-redux";
import { useRouter } from "next/navigation";
import { Swiper, SwiperSlide } from "swiper/react";
import { Autoplay, FreeMode } from "swiper/modules";
import "swiper/css";
import "swiper/css/free-mode";
import ImageWithPlaceholder from "@/components/image-with-placeholder/ImageWithPlaceholder";
import {
  setListingSource,
  setCategorySlug,
  setCategoryBreadcrumb,
  setBlockSource,
} from "@/redux/slices/productFilterSlice";
import useZoneHref from "@/hooks/useZoneHref";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import useNavClick from "@/hooks/useNavClick";
import useDir from "@/hooks/useDir";
import { toCssAspectRatio, pickDeviceNumber, pickDeviceImage } from "@/utils/helperFunction";

// Renders home layout category section (horizontal, circular, or grid layout).
interface CategorySectionProps {
  block: any;
  borderRadius?: string | number;
  device?: string;
}

const CategorySection = ({ block, borderRadius, device = "web" }: CategorySectionProps) => {
  const zoneHref = useZoneHref();
  const { buildQueryPatch } = useUrlProductFilters();
  const dir = useDir();
  const dispatch = useDispatch();
  const router = useRouter();
  const { run: runNavClick } = useNavClick();

  const categories = block?.categories || [];
  if (categories.length === 0) return null;

  const layout = String(block?.layout || "grid");
  const isHorizontal = layout === "horizontal";
  const isCircular = layout === "circular";
  const isRow = isHorizontal || isCircular;
  const cols =
    pickDeviceNumber(block?.config?.grid_columns, device, 0) ||
    Number.parseInt(layout.split("_")[1], 10) ||
    4;

  const gap = pickDeviceNumber(
    block?.config?.category_gap ?? block?.config?.chip_gap,
    device,
    8,
  );
  const chipRadius = pickDeviceNumber(
    block?.config?.category_radius ?? block?.config?.chip_radius,
    device,
    12,
  );
  const radius = isCircular ? "9999px" : `${chipRadius}px`;

  const config = block?.config || {};
  const variant = config?.variant;
  const isDefault = !variant || variant === "default";
  const isColorVariant = variant === "with_color";

  const showTitle = isDefault ? false : !!config?.section_title;
  const title = showTitle ? config?.section_title : null;

  const bgImageUrl =
    config?.background_image_url && typeof config.background_image_url === "object"
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
  const itemTextColor = isDefault ? null : config?.item_text_color || null;

  const blockPadding = Number.isFinite(Number(config?.block_padding))
    ? Number(config.block_padding)
    : 0;
  const BASE_INLINE_PADDING = isRow ? 10 : 0;
  const blockPaddingStyle = {
    paddingTop: blockPadding,
    paddingBottom: blockPadding,
    paddingLeft: BASE_INLINE_PADDING + blockPadding,
    paddingRight: BASE_INLINE_PADDING + blockPadding,
  };

  const bgAspectPadding = (() => {
    if (!hasBg) return undefined;
    const aspectSource = config?.bg_image_aspect ?? config?.image_aspect;
    const aspectRaw =
      aspectSource && typeof aspectSource === "object"
        ? pickDeviceImage(aspectSource, device)
        : aspectSource;
    const ratio = toCssAspectRatio(aspectRaw);
    if (!ratio) return undefined;
    const [w, h] = ratio.split("/").map((n: string) => Number(n.trim()));
    if (!w || !h) return undefined;
    return `${(h / w) * 100}%`;
  })();

  const navigateToCategory = (category: any) => {
    dispatch(setListingSource({ data: "category" }));
    dispatch(setCategorySlug({ data: category.slug }));
    dispatch(
      setCategoryBreadcrumb({
        data: [
          {
            id: category.id,
            name: category?.translations?.name || category?.name,
            slug: category.slug,
          },
        ],
      }),
    );
    dispatch(setBlockSource());
    const qs = new URLSearchParams(
      buildQueryPatch({ category_id: category.slug }),
    ).toString();
    const dest = zoneHref("/products");
    router.push(qs ? `${dest}?${qs}` : dest);
  };

  const handleCategoryClick = (category: any) =>
    runNavClick(() => navigateToCategory(category), category?.id);

  const renderChip = (category: any, { inSlide = false }: { inSlide?: boolean } = {}) => {
    const chipWidthClass =
      inSlide || !isRow ? "w-full" : "shrink-0 w-[72px] sm:w-20";
    return (
    <button
    type="button"
      key={category.id}
      onClick={() => handleCategoryClick(category)}
      className={`flex flex-col items-center text-center cursor-pointer group ${chipWidthClass}`}
    >
      <div
        className="relative w-full max-w-[80px] sm:max-w-[96px] mx-auto aspect-square overflow-hidden categoryTileBack"
        style={{ borderRadius: radius }}
      >
        <ImageWithPlaceholder
          src={category.image_url}
          width={300}
          height={300}
          alt={category?.translations?.name ?? category?.name}
          className="w-full h-full aspect-square object-contain p-1"
        />
      </div>
      <span
        className={`text-[11px] sm:text-xs leading-tight mt-2 w-full line-clamp-2 font-medium ${
          itemTextColor ? "" : "text-slate-700 dark:text-zinc-300"
        }`}
        style={itemTextColor ? { color: itemTextColor } : undefined}
      >
        {category?.translations?.name ?? category?.name}
      </span>
    </button>
    );
  };

  const panelRoundedClass =
    borderRadius == null && (hasBg || backgroundColor) ? "" : "";

  return (
    <section dir={dir}>
      <div
        className={`relative overflow-hidden ${panelRoundedClass}`}
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
        <div className="relative" style={blockPaddingStyle}>
          {title && (
            <h2
              className={`text-xl sm:text-3xl font-extrabold leading-[1.1] mt-0 mb-4 ${
                textColor ? "" : "text-gray-900 dark:text-zinc-100"
              } ${
                blockPaddingStyle.paddingLeft === 0 ? "ps-3" : ""
              }`}
              style={textColor ? { color: textColor } : undefined}
            >
              {title}
            </h2>
          )}
          {isRow ? (
        <>
          {/* Mobile swiper */}
          <div className="sm:hidden">
            <Swiper
              key={dir}
              modules={[Autoplay]}
              slidesPerView={4.2}
              spaceBetween={gap}
              loop={categories.length > 4}
              autoplay={{
                delay: 2000,
                disableOnInteraction: false,
                pauseOnMouseEnter: true,
              }}
            >
              {categories.map((category) => (
                <SwiperSlide key={category.id}>
                  {renderChip(category, { inSlide: true })}
                </SwiperSlide>
              ))}
            </Swiper>
          </div>
          {/* Desktop swiper */}
          <div className="hidden sm:block">
            <Swiper
              key={dir}
              modules={[FreeMode]}
              freeMode={true}
              slidesPerView="auto"
              spaceBetween={gap}
              grabCursor={true}
              className="!pb-1 [&_.swiper-slide]:!w-[72px] sm:[&_.swiper-slide]:!w-20"
            >
              {categories.map((category) => (
                <SwiperSlide key={category.id}>
                  {renderChip(category, { inSlide: true })}
                </SwiperSlide>
              ))}
            </Swiper>
          </div>
        </>
          ) : (
            <div
              className="grid"
              style={{
                gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`,
                gap: `${gap}px`,
              }}
            >
              {categories.map((category) => renderChip(category))}
            </div>
          )}
        </div>
      </div>
    </section>
  );
};

export default React.memo(CategorySection);
