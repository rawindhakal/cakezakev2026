"use client";

import React from "react";
import { useRouter } from "next/navigation";
import { Swiper, SwiperSlide } from "swiper/react";
import { Autoplay, FreeMode } from "swiper/modules";
import "swiper/css";
import "swiper/css/free-mode";
import ImageWithPlaceholder from "@/components/image-with-placeholder/ImageWithPlaceholder";
import useZoneHref from "@/hooks/useZoneHref";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import useNavClick from "@/hooks/useNavClick";
import useDir from "@/hooks/useDir";
import { toCssAspectRatio, pickDeviceNumber, pickDeviceImage } from "@/utils/helperFunction";

// Renders home layout brand section (horizontal, circular, or grid layout).
interface BrandSectionProps {
  block: any;
  borderRadius?: string | number;
  device?: string;
}

const BrandSection = ({ block, borderRadius, device = "web" }: BrandSectionProps) => {
  const zoneHref = useZoneHref();
  const { buildQueryPatch } = useUrlProductFilters();
  const dir = useDir();
  const router = useRouter();
  const { run: runNavClick } = useNavClick();

  const brands = block?.brands || [];
  if (brands.length === 0) return null;

  const layout = String(block?.layout || "horizontal");
  const isCircular = layout === "circular";
  const isRow = layout === "horizontal" || isCircular;
  const configCols =
    pickDeviceNumber(block?.config?.grid_columns, device, 0) ||
    Number.parseInt(layout.split("_")[1], 10) ||
    4;
  const cols = Math.min(configCols, brands.length);

  const gap = pickDeviceNumber(
    block?.config?.brand_gap ?? block?.config?.chip_gap,
    device,
    8,
  );
  const chipRadius = pickDeviceNumber(
    block?.config?.brand_radius ?? block?.config?.chip_radius,
    device,
    12,
  );
  const radius = isCircular ? "9999px" : `${chipRadius}px`;
  const showName = block?.config?.show_name !== false;

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

  const navigateToBrand = (brand: any) => {
    const qs = new URLSearchParams(
      buildQueryPatch({ brand_ids: [brand.id] }),
    ).toString();
    const dest = zoneHref("/products");
    router.push(qs ? `${dest}?${qs}` : dest);
  };

  const handleBrandClick = (brand: any) =>
    runNavClick(() => navigateToBrand(brand), brand?.id);

  const renderChip = (brand: any, { inSlide = false }: { inSlide?: boolean } = {}) => {
    const chipWidthClass =
      inSlide || !isRow ? "w-full" : "shrink-0 w-[72px] sm:w-20";
    return (
    <button
    type="button"
      key={brand.id}
      onClick={() => handleBrandClick(brand)}
      className={`flex flex-col items-center text-center cursor-pointer group ${chipWidthClass}`}
    >
      <div
        className={`relative w-full max-w-[110px] sm:max-w-[130px] mx-auto aspect-square overflow-hidden bg-white dark:bg-zinc-900 transition-all duration-200 group-hover:shadow-md border`}
        style={{
          borderRadius: radius,
          borderColor: "color-mix(in srgb, var(--primary-color) 25%, transparent)",
        }}
      >
        <ImageWithPlaceholder
          src={brand.image_url}
          width={300}
          height={300}
          alt={brand?.translations?.name ?? brand?.name}
          className={`w-full h-full aspect-square object-contain p-2`}
        />
      </div>
      {showName && (
        <span
          className={`text-[11px] sm:text-xs leading-tight mt-2 w-full line-clamp-1 font-medium ${
            itemTextColor ? "" : "text-slate-700 dark:text-zinc-300"
          }`}
          style={itemTextColor ? { color: itemTextColor } : undefined}
        >
          {brand?.translations?.name ?? brand?.name}
        </span>
      )}
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
                loop={brands.length > 4}
                autoplay={{ delay: 2000, disableOnInteraction: false, pauseOnMouseEnter: true }}
              >
                {brands.map((brand) => (
                  <SwiperSlide key={brand.id}>
                    {renderChip(brand, { inSlide: true })}
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
                {brands.map((brand) => (
                  <SwiperSlide key={brand.id}>
                    {renderChip(brand, { inSlide: true })}
                  </SwiperSlide>
                ))}
              </Swiper>
            </div>
          </>
          ) : (
            <div
              className="grid items-start"
              style={{
                gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`,
                gap: `${gap}px`,
              }}
            >
              {brands.map((brand) => renderChip(brand))}
            </div>
          )}
        </div>
      </div>
    </section>
  );
};

export default React.memo(BrandSection);
