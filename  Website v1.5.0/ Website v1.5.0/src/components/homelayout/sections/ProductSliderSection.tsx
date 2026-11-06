"use client";

import { ProductStoryList } from "@/components/productstory/ProductStoryContext";
import React from "react";
import { IoArrowForward, IoChevronForward } from "react-icons/io5";
import { Swiper, SwiperSlide } from "swiper/react";
import "swiper/css";
import { useDispatch, useSelector } from "react-redux";
import { useRouter } from "next/navigation";
import HomeVerticleProductCard from "../../productcards/HomeVerticleProductCard";
import HomeListViewCard from "../../productcards/HomeListViewCard";
import useT from "@/hooks/useT";
import useIsRtl from "@/hooks/useIsRtl";
import {
  clearAllFilter,
  setBlockSource,
  setListingSource,
  setCategorySlug,
  setCategoryBreadcrumb,
} from "@/redux/slices/productFilterSlice";
import * as api from "@/api/apiRoutes";
import useZoneHref from "@/hooks/useZoneHref";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import useNavClick from "@/hooks/useNavClick";
import useDir from "@/hooks/useDir";
import { findNodeById } from "@/utils/categorySlugResolver";
import { toCssAspectRatio, pickDeviceNumber, pickDeviceImage } from "@/utils/helperFunction";

interface ProductSliderSectionProps {
  block: any;
  borderRadius?: string | number;
  device?: string;
}

const ProductSliderSection = ({ block, borderRadius, device = "web" }: ProductSliderSectionProps) => {
  const zoneHref = useZoneHref();
  const { buildQueryPatch } = useUrlProductFilters();
  const rtl = useIsRtl();
  const tr = useT();
  const dispatch = useDispatch();
  const router = useRouter();
  const { run: runNavClick } = useNavClick();
  const dir = useDir();
  const cityLat = useSelector((state: any) => state.City.city?.latitude);
  const cityLng = useSelector((state: any) => state.City.city?.longitude);

  const config = block?.config || {};
  const products = block?.products || [];

  const dataSource = config?.data_source ?? block?.data_source ?? "";
  const viewMorePreviewImages = (
    config?.viewMorePreviewImages ??
    block?.viewMorePreviewImages ??
    []
  ).filter(Boolean);
  const hasViewMore = viewMorePreviewImages.length > 0;
  const previewThumbs = viewMorePreviewImages.slice(0, 3);
  const manualProductIds =
    config?.manual_product_ids ?? block?.manual_product_ids ?? "";

  const firstId = (...values: any[]) => {
    const hit = values.find(
      (v) => v != null && v !== "" && !(Array.isArray(v) && v.length === 0),
    );
    if (hit == null) return "";
    return Array.isArray(hit)
      ? hit.filter((x: any) => x != null && x !== "").join(",")
      : String(hit);
  };

  // Any row — automatic ones too — can carry a category/brand scope.
  const blockCategoryIds = firstId(
    block?.category_ids,
    block?.category_id,
    config?.category_ids,
    config?.category_id,
  );
  const blockBrandIds = firstId(
    block?.brand_ids,
    block?.brand_id,
    config?.brand_ids,
    config?.brand_id,
  );
  // Sent only for "everything except these" — never defaulted.
  const filterMode = block?.filter_mode ?? config?.filter_mode ?? "";

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
        console.log("See All category resolve failed", error?.message);
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

  if (products.length === 0) return null;

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

  const cardRadius = config?.product_card_radius;
  const blockPadding = Number.isFinite(Number(config?.block_padding))
    ? Number(config.block_padding)
    : null;
  const hasPadding = blockPadding != null;
  const BASE_INLINE_PADDING = isGrid || isList ? 0 : 10;
  const inlinePadding = isGrid || isList ? (hasPadding ? blockPadding : 0) : BASE_INLINE_PADDING;
  const blockPaddingStyle = {
    paddingTop: hasPadding ? blockPadding : 0,
    paddingBottom: hasPadding ? blockPadding : 0,
  };
  const inlinePaddingStyle = {
    paddingLeft: inlinePadding,
    paddingRight: inlinePadding,
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

  const cardWrap = (product: any) => (
    <div className="h-full">
      <HomeVerticleProductCard
        product={adaptProduct(product)}
        radius={cardRadius}
      />
    </div>
  );

  const listRow = (product: any) => (
    <HomeListViewCard
      key={product.id}
      product={adaptProduct(product)}
      radius={cardRadius}
    />
  );

  const storyProducts = products.map(adaptProduct);

  return (
    <ProductStoryList products={storyProducts}>
    <section>
      {/* Slider panel */}
      <div
        className={`relative overflow-hidden ${borderRadius != null ? "" : ""}`}
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
              {title ? (
                <h2
                  className={`text-xl sm:text-3xl font-extrabold leading-[1.1] m-0 ${
                    textColor ? "" : "text-gray-900 dark:text-zinc-100"
                  }`}
                  style={textColor ? { color: textColor } : undefined}
                >
                  {title}
                </h2>
              ) : (
                <span />
              )}
            </div>
          )}

          {isGrid ? (
            <div
              className={`grid mt-2 ${
                gridCols
                  ? ""
                  : "grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6"
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
              {products.map((product) => (
                <React.Fragment key={product.id}>
                  {gridCols === 1 ? (
                    <div className="w-full max-w-[220px]">
                      {cardWrap(product)}
                    </div>
                  ) : (
                    cardWrap(product)
                  )}
                </React.Fragment>
              ))}
            </div>
          ) : isList ? (
            <div
              className={`mt-2 grid items-stretch ${
                device === "web" ? "grid-cols-2" : "grid-cols-1"
              }`}
              style={{ ...inlinePaddingStyle, gap: `${gap}px` }}
            >
              {products.map((product) => (
                <div key={product.id} className="h-full">
                  {listRow(product)}
                </div>
              ))}
            </div>
          ) : (
            <div className={`relative ${title ? "mt-6" : "mt-2"}`}>
              <Swiper
                key={`${String(rtl)}-${device}-${slideCount}`}
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
                {products.map((product) => (
                  <SwiperSlide key={product.id} className="!h-auto">
                    {cardWrap(product)}
                  </SwiperSlide>
                ))}
              </Swiper>
            </div>
          )}

          {/* View More button */}
          {hasViewMore && (
            <div className="mt-5 pb-4 flex justify-center">
              <button
                type="button"
                onClick={handleSeeAll}
                className="inline-flex max-w-full items-center gap-3 rounded-full bg-white dark:bg-zinc-900 p-1.5 pe-1.5 shadow-[0_3px_14px_rgba(0,0,0,0.16)] max-md:gap-2 max-md:p-1 max-md:shadow-[0_2px_10px_rgba(0,0,0,0.12)]"
              >
                <span className="flex items-center flex-shrink-0">
                  {previewThumbs.map((src, index) => (
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

export default React.memo(ProductSliderSection);
