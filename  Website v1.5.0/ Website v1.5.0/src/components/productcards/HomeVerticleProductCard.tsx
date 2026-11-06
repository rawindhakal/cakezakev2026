import React, { useState, useEffect, useRef, useMemo } from "react";
import { FaStar, FaMinus, FaPlus} from "react-icons/fa";
import Link from "next/link";
import { useProductStoryClick } from "../productstory/ProductStoryContext";
import { t } from "@/utils/translation";
import ProductDetailModal from "../productdetailmodal/ProductDetailModal";
import { useSelector } from "react-redux";
import { formatCurrency, isVideoUrl} from "@/utils/helperFunction";
import { useFavoriteToggle } from "@/hooks/useFavoriteToggle";
import MobileCardGallery from "./MobileCardGallery";
import FewLeftBadge from "./FewLeftBadge";
import TimeIcon from "./TimeIcon";
import { GoEye } from "react-icons/go";
import {
  MdAddShoppingCart} from "react-icons/md";
import VariantsModal from "../variantsmodal/VariantsModal";
import AddonsModal from "../addonsmodal/AddonsModal";
import AddonRepeatModal from "../addonsmodal/AddonRepeatModal";
import AddonLinesModal from "../addonsmodal/AddonLinesModal";
import {
  isVariantOutOfStock} from "@/utils/helperFunction";
import useZoneHref from "@/hooks/useZoneHref";
import useNotifyMe from "@/hooks/useNotifyMe";
import useStoreClosed from "@/hooks/useStoreClosed";
import useIsHydrated from "@/hooks/useIsHydrated";
import useCartLine from "@/hooks/useCartLine";
import useCurrency from "@/hooks/useCurrency";
import { flyToCart } from "@/utils/flyToCart";
import PulseHeart from "@/components/ui/pulse-heart/PulseHeart";
import { RingBell } from "@/components/ui/bell-toggle/BellToggle";
import { ZigzagEdgeIcon } from "@/components/icons";
import ProductTypeTag from "../productdetail/ProductTypeTag";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";

interface HomeVerticleProductCardProps {
  product: any;
  largeImage?: boolean;
  radius?: number | string | null;
  // Use the classic card (variant bar on image, ADD overlap) on mobile too.
  classicMobile?: boolean;
}

const HomeVerticleProductCard = ({
  product,
  largeImage = false,
  radius = null,
  classicMobile = false,
}: HomeVerticleProductCardProps) => {
  const zoneHref = useZoneHref();
  const handleStoryClick = useProductStoryClick(product?.id);

  // Format currency with zone defaults
  const { currency, decimals } = useCurrency(product);
  const money = (val: number) => formatCurrency(val, currency, decimals, true);
  const city = useSelector((state: any) => state.City.city);
  const shopMode = useSelector((state: any) => state.ShopMode.mode);

  // Quick delivery label gated on hydration
  const hydrated = useIsHydrated();
  const deliveryLabel = product?.time_to_deliver;
  const showQuickDelivery = hydrated && shopMode === "quick" && !!deliveryLabel;

  // Initial variant state
  const {
    cart,
    setting,
    selectedVariant,
    setSelectedVariant,
    isProductAlreadyAdded,
    addedQuantity,
    maxQty,
    guestMaxQty,
    serverDisplayQty,
    showStepper,
    hasAddons,
    showAddons,
    setShowAddons,
    addonLines,
    lastAddonLine,
    showAddonRepeat,
    setShowAddonRepeat,
    showAddonLines,
    setShowAddonLines,
    repeatLastAddonLine,
    repeatAddonLine,
    openAddonSheetAfterClose,
    removeAddonLine,
    handleIntialAddToCart,
    handleQuantityIncrease,
    handleQuantityDecrease,
  } = useCartLine(product, {
    initialVariant: product?.variants?.[0] ?? [],
    guardDisabledVariantOnGuestAdd: false,
    rethrowRemoveError: false,
    useStockHelpers: true,
  });
  const [showProductDetail, setShowProductDetail] = useState(false);
  // Stepper animation state
  const [qtyAnim, setQtyAnim] = useState(false);
  const [showVariants, setShowVariants] = useState(false);
  const {
    isNotifyRequested,
    setIsNotifyRequested,
    loading: notifyLoading,
    toggle: toggleNotify,
  } = useNotifyMe({
    variantId: selectedVariant?.id,
    latitude: city?.latitude,
    longitude: city?.longitude,
  });
  useEffect(() => {
    setIsNotifyRequested(!!selectedVariant?.is_notify_requested);
  }, [
    selectedVariant?.id,
    selectedVariant?.is_notify_requested,
    setIsNotifyRequested,
  ]);

  // Deduplicated gallery images for hover slideshow
  const galleryImages: string[] = useMemo(() => {
    const toUrl = (img: any) =>
      typeof img === "string" ? img : img?.image_url;
    const list = [
      product?.image_url,
      ...(product?.images || []).map(toUrl),
      // Clips belong on the detail page; a card shows stills only.
    ].filter((url: any) => Boolean(url) && !isVideoUrl(url));
    return [...new Set(list)];
  }, [product?.image_url, product?.images]);

  const [hoverImgIdx, setHoverImgIdx] = useState(0);
  const hoverTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const startHoverSlide = () => {
    if (galleryImages.length <= 1) return;
    if (hoverTimerRef.current) return;
    hoverTimerRef.current = setInterval(() => {
      setHoverImgIdx((i) => (i + 1) % galleryImages.length);
    }, 1600);
  };

  const stopHoverSlide = () => {
    if (hoverTimerRef.current) {
      clearInterval(hoverTimerRef.current);
      hoverTimerRef.current = null;
    }
    setHoverImgIdx(0);
  };

  // Clean up hover interval on unmount
  useEffect(() => () => stopHoverSlide(), []);

  const handleShowDetailModal = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setShowProductDetail(true);
  };

  const handleShowVariantModal = (e: React.MouseEvent, product: any) => {
    e.preventDefault();
    e.stopPropagation();
    // An addon product picks its variant inside the addon sheet instead, so
    // the answers and the variant are sent in one add call.
    if (hasAddons) {
      setShowAddons(true);
      return;
    }
    if (product.variants.length > 1) {
      setShowVariants(true);
    } else {
      return;
    }
  };

  // Favorite toggle hook
  const {
    liked,
    pending: likePending,
    toggle: handleProductLikes,
    canToggle: canToggleLike,
  } = useFavoriteToggle({
    productId: product?.id,
    serverLiked: product?.is_favorite,
  });

  const productsVariants = product?.variants;

  const {
    storeClosed,
    guard: guardClosed,
    closedProps,
    closedDecorClass,
  } = useStoreClosed();

  const isProductAvailabel =
    (product?.variants?.length <= 1 &&
      isVariantOutOfStock(product?.variants?.[0])) ||
    isVariantOutOfStock(selectedVariant) ||
    Number(selectedVariant?.status) === 0 ||
    Number(product?.status) === 0;

  const hasDiscount =
    selectedVariant?.discounted_price !== 0 &&
    selectedVariant?.discounted_price !== selectedVariant?.price;
  // Discount percentage
  const discountPercent =
    Number(selectedVariant?.discount_percent ?? product?.discount_percent) ||
    null;

  // Rating visibility
  const showRating =
    !!product?.product_rating && Number(product?.rating_count) > 0;

  // Variant label
  const variantLabel = (() => {
    const v = selectedVariant;
    if (!v) return "";
    if (v.measurement) {
      const unit =
        v?.unit?.translations?.short_code ?? v?.unit?.short_code ?? "";
      return `${v.measurement}${unit ? ` ${unit}` : ""}`;
    }
    if (Array.isArray(v.attributes) && v.attributes.length) {
      return v.attributes
        .map((a: any) => a?.attribute_value)
        .filter(Boolean)
        .join(", ");
    }
    return "";
  })();

  // Action control (notify / variants / stepper / add) — one slot, overlaps the
  // image's bottom-right like the Blinkit card. The stepper needs more room
  // than ADD, so the slot widens with it instead of squeezing −/qty/+.
  // Content-sized, capped at both ends: a percentage spanned most of a wide
  // card, a fixed px swamped the ~90px cards an admin slidesPerView of 3 makes.
  const actionWidthCls = showStepper
    ? "w-auto min-w-[74px] max-w-[96px]"
    : "w-auto min-w-[56px] max-w-[86px]";
  const actionSlot = isProductAvailabel ? (
    <button
      type="button"
      disabled={notifyLoading}
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        toggleNotify(isNotifyRequested);
      }}
      className={`flex h-8 w-full items-center justify-center gap-1 rounded-lg border bg-white dark:bg-zinc-900 px-2 text-[11px] font-bold leading-none shadow-sm transition disabled:opacity-60 md:h-9 md:text-[12px] ${
        isNotifyRequested
          ? "border-gray-200 text-gray-400 dark:border-zinc-700 dark:text-zinc-500"
          : "primaryBorderColor primaryColor hover:primaryLightBack"
      }`}
    >
      <RingBell on={!!isNotifyRequested} size={12} className="shrink-0" />
      <span
        key={String(!!isNotifyRequested)}
        className="truncate motion-safe:animate-fadeSwap"
      >
        {isNotifyRequested
          ? t("notified") || "Notified"
          : t("notify") || "Notify"}
      </span>
    </button>
  ) : productsVariants?.length > 1 && !(hasAddons && showStepper) ? (
    <button
      type="button"
      onClick={guardClosed((e) => handleShowVariantModal(e, product))}
      {...closedProps}
      className={`flex h-8 w-full flex-col items-center justify-center overflow-hidden rounded-lg border primaryBorderColor primaryColor bg-white dark:bg-zinc-900 text-[11px] font-bold uppercase leading-none shadow-sm transition hover:primaryLightBack md:h-9 md:text-[13px] ${closedProps.className ?? ""}`}
    >
      <span className="flex flex-1 items-center justify-center gap-1 px-2">
        <MdAddShoppingCart size={13} className="hidden shrink-0 md:block" />
        {t("add")}
      </span>
      <span className="w-full truncate primaryBackColor px-0.5 py-[2px] text-[7px] font-semibold normal-case leading-none text-white md:text-[9px]">
        {hasAddons
          ? t("addon_customisable")
          : `${productsVariants?.length} ${t("options") || "options"}`}
      </span>
    </button>
  ) : showStepper ? (
    <button type="button" {...closedProps} aria-label="Remove from cart" onClick={guardClosed(handleQuantityDecrease)} className={`flex h-8 w-full items-center justify-center gap-1 rounded-lg primaryBackColor text-white shadow-sm md:h-9 ${closedProps.className ?? ""}  text-xs font-bold`}>Remove</button>
  ) : (
    <button
      type="button"
      onClickCapture={(e) => {
        setQtyAnim(true);
        // Nothing reaches the cart yet when the addon sheet opens.
        if (!storeClosed && !hasAddons) flyToCart(e.currentTarget);
      }}
      onClick={guardClosed((e) => handleIntialAddToCart(e))}
      {...closedProps}
      className={`flex h-8 w-full flex-col items-center justify-center overflow-hidden rounded-lg border primaryBorderColor primaryColor bg-white dark:bg-zinc-900 text-[11px] font-bold uppercase leading-none shadow-sm transition hover:primaryLightBack md:h-9 md:text-[13px] ${closedProps.className ?? ""}`}
    >
      <span className="flex flex-1 items-center justify-center gap-1 px-2">
        <MdAddShoppingCart size={13} className="hidden shrink-0 md:block" />
        {t("add")}
      </span>
      {hasAddons && (
        <span className="w-full truncate primaryBackColor px-0.5 py-[2px] text-[7px] font-semibold normal-case leading-none text-white md:text-[9px]">
          {t("addon_customisable")}
        </span>
      )}
    </button>
  );


  // Average rating — desktop card draws five stars.
  const ratingValue = Math.round(
    Number(product?.average_rating ?? product?.rating ?? 0),
  );

  // Desktop action button sizing, kept from the pre-10-Oct card.
  const mobileActionCls =
    "max-md:order-2 max-md:relative max-md:z-10 max-md:self-end max-md:me-0 max-md:w-[48%] max-md:min-w-[44px] max-md:rounded-lg max-md:shadow-sm";

  // Desktop keeps the pre-10-Oct card; mobile uses the new overlay card.
  const desktopCard = (
    <div
      style={{
        ...(radius != null ? { borderRadius: radius } : {}),
        // Border tinted from the API theme (--primary-color), soft so it reads as
        // a modern hairline rather than a hard outline.
        borderColor:
          "color-mix(in srgb, var(--primary-color) 18%, transparent)",
      }}
      className="group relative flex h-full flex-col overflow-hidden rounded-2xl border bg-white dark:bg-zinc-900 shadow-[0_2px_12px_rgba(0,0,0,0.04)] max-md:overflow-visible max-md:rounded-2xl max-md:border-0 max-md:bg-white max-md:p-2 max-md:shadow-none dark:max-md:bg-zinc-900"
      onMouseEnter={startHoverSlide}
      onMouseLeave={stopHoverSlide}
    >
      {/* Discount ribbon */}
      {discountPercent && (
        <div
          className={`absolute top-0 left-3 z-10 drop-shadow-md max-md:hidden ${closedDecorClass}`}
        >
          <div className="primaryBackColor text-white text-center px-1 md:px-1.5 pt-0.5 md:pt-1 pb-0.5">
            <span className="block text-[9px] md:text-[12px] font-extrabold leading-none">
              {discountPercent}%
            </span>
            <span className="block text-[7px] md:text-[9px] font-semibold uppercase tracking-wide leading-none mt-0.5">
              {t("off")}
            </span>
          </div>
          <ZigzagEdgeIcon size={4} />
        </div>
      )}
      {/* Product link */}
      <Link
        href={zoneHref(`/product/${product?.slug}`)}
        prefetch={false}
        onClick={handleStoryClick}
        // Mobile reorder layout
        className={`flex grow flex-col max-md:contents ${isProductAvailabel ? "cursor-pointer" : ""}`}
      >
        {/* Product image */}
        <div className="relative p-1.5 md:p-2 max-md:order-1 max-md:p-0">
          <div className="relative aspect-[4/3] max-md:aspect-[4/5] md:aspect-square w-full overflow-hidden rounded-xl bg-gray-50 dark:bg-zinc-800 max-md:bg-gray-50 dark:max-md:bg-zinc-800">
            {galleryImages.length > 1 ? (
              <>
              {/* Hover slideshow cross-fade */}
              <div className="max-md:hidden relative h-full w-full transition-transform duration-300 ease-out group-hover:scale-110">
                {galleryImages.map((imgSrc, idx) => (
                  <ImageWithPlaceholder
                    key={idx}
                    className={`absolute inset-0 object-contain h-full w-full p-1.5 md:p-2.5 max-md:p-0 max-md:pb-7 transition-opacity duration-700 ease-in-out ${
                      idx === hoverImgIdx ? "opacity-100" : "opacity-0"
                    } ${isProductAvailabel ? "md:grayscale" : storeClosed ? "grayscale" : ""}`}
                    alt={product?.translations?.name ?? product?.name}
                    src={imgSrc}
                    width={300}
                    height={300}
                    priority={idx === 0}
                  />
                ))}
              </div>
              {/* Mobile has no hover slideshow — show the first image */}
              <ImageWithPlaceholder
                className={`md:hidden object-contain h-full w-full p-0 pb-7 ${storeClosed ? "grayscale" : ""}`}
                alt={product?.translations?.name ?? product?.name}
                src={galleryImages[0]}
                width={300}
                height={300}
              />
              </>
            ) : (
              <ImageWithPlaceholder
                className={`object-contain h-full w-full p-1.5 md:p-2.5 max-md:p-0 max-md:pb-7 transition-transform duration-300 ease-out group-hover:scale-110 ${isProductAvailabel ? "md:grayscale" : storeClosed ? "grayscale" : ""}`}
                alt={product?.translations?.name ?? product?.name}
                src={galleryImages[0] ?? product?.image_url}
                width={300}
                height={300}
              />
            )}
            {/* Sold out badge */}
            {isProductAvailabel && (
              <span className="md:hidden absolute start-0 top-0 z-10 rounded-ee-lg bg-gray-600/90 px-2 py-1 text-[11px] font-medium leading-none text-white">
                {t("sold_out") || "Sold out"}
              </span>
            )}
            {/* Variant bar */}
            <span className="md:hidden absolute inset-x-0 bottom-0 z-[5] flex h-7 items-center bg-gray-100 ps-1.5 text-[10px] font-medium text-gray-700 dark:bg-zinc-800/95 dark:text-zinc-200">
              <span
                className="min-w-0 max-w-[46%] pe-1.5 line-clamp-2 break-words text-[11px] leading-[1.15]"
                title={variantLabel}
              >
                {variantLabel}
              </span>
            </span>
            {showQuickDelivery && !isProductAvailabel && (
              <span className="absolute bottom-2 left-2 z-10 hidden md:inline-flex items-center gap-1 rounded-md bg-white/95 dark:bg-zinc-900/90 backdrop-blur-sm px-1.5 py-0.5 text-[10px] font-bold text-gray-800 dark:text-zinc-100 shadow-sm ring-1 ring-black/5">
                <TimeIcon size={12} className="primaryColor" />
                {deliveryLabel}
              </span>
            )}
          </div>

          {/* Wishlist & quick view */}
          <div className="absolute top-1.5 right-1.5 md:top-2 md:right-2 z-20 flex flex-col gap-1.5 md:gap-2 opacity-100 lg:opacity-0 lg:group-hover:opacity-100 transition-opacity duration-200 cursor-pointer">
            <PulseHeart
              liked={!!liked}
              onToggle={handleProductLikes}
              animate={canToggleLike}
              showCount={false}
              size={15}
              corner={999}
              pillColor="transparent"
              likedColor="var(--primary-color)"
              label={t("wishlist") || "Wishlist"}
              className="relative flex h-6 w-6 max-md:h-8 max-md:w-8 max-md:bg-transparent max-md:shadow-none md:h-7 md:w-7 items-center justify-center rounded-full bg-white dark:bg-zinc-900 shadow"
            />
            <button
              type="button"
              onClick={handleShowDetailModal}
              aria-label={t("quick_view")}
              className="max-md:hidden flex h-6 w-6 md:h-7 md:w-7 items-center justify-center rounded-full bg-white dark:bg-zinc-900 shadow"
            >
              <GoEye
                size={12}
                className="text-gray-600 dark:text-zinc-300 md:hidden"
              />
              <GoEye
                size={14}
                className="text-gray-600 dark:text-zinc-300 hidden md:block"
              />
            </button>
          </div>
        </div>

        {/* Product details */}
        <div className="flex grow flex-col px-2 pt-1 pb-0 md:px-3 md:pb-0 max-md:order-5 max-md:px-0.5 max-md:pb-2 max-md:pt-0.5">
          {/* Quick delivery ETA */}
          {showQuickDelivery && !isProductAvailabel && (
            <span className="md:hidden order-last mt-1 inline-flex w-fit items-center gap-1 text-[10px] text-gray-600 dark:text-zinc-300">
              <TimeIcon size={11} className="shrink-0" />
              {deliveryLabel}
            </span>
          )}
          {/* Category eyebrow */}
          <span className="hidden md:block h-[12px] text-[9px] md:text-[10px] uppercase tracking-wide text-gray-400 dark:text-zinc-500 line-clamp-1 leading-none">
            {product?.category_name || ""}
          </span>

          {/* Product name */}
          <h3
            className={`mt-0.5 textColor text-[12px] max-md:text-[12px] max-md:font-normal max-md:line-clamp-3 md:text-[13px] font-semibold leading-snug line-clamp-1 capitalize ${isProductAvailabel ? "max-md:opacity-60" : ""}`}
          >
            <ProductTypeTag
              type={product?.product_type ?? product?.indicator}
              className="me-1.5 align-[-2px]"
              iconSize={13}
            />
            {product?.translations?.name ?? product?.name}
          </h3>

          {/* Rating row */}
          {showRating && (
            <div className="mt-0.5 flex items-center">
              <span className="flex items-center gap-0.5 text-[10px] md:text-[11px] text-gray-500 dark:text-zinc-400">
                {[1, 2, 3, 4, 5].map((i) => (
                  <FaStar
                    key={i}
                    size={12}
                    className={
                      i <= ratingValue
                        ? "text-yellow-400"
                        : "text-gray-300 dark:text-zinc-600"
                    }
                  />
                ))}
                <span className="text-gray-400 dark:text-zinc-500">
                  ({product?.rating_count})
                </span>
              </span>
            </div>
          )}

          <FewLeftBadge
            variant={selectedVariant}
            product={product}
            className="max-md:text-[9px] max-md:whitespace-nowrap"
          />
        </div>
      </Link>

      {/* Price and cart controls */}
      <div className="flex flex-row flex-wrap items-end justify-between gap-x-2 gap-y-1 px-2 py-1.5 md:px-3 max-md:contents">
        <div className="flex min-w-0 flex-row md:flex-col flex-wrap items-baseline md:items-stretch gap-x-1.5 leading-tight max-md:order-3 max-md:px-0.5 max-md:pt-1.5">
          <span className="textColor text-[13px] max-md:text-[13px] max-md:font-bold md:text-[15px] font-extrabold whitespace-nowrap">
            {money(
              hasDiscount
                ? selectedVariant?.discounted_price
                : selectedVariant?.price,
            )}
          </span>
          {/* Original price */}
          {hasDiscount && (
            <span className="SecondaryTextColor text-[11px] max-md:text-[10px] md:text-[12px] whitespace-nowrap line-through">
              {money(selectedVariant?.price)}
            </span>
          )}

        </div>

        {/* Mobile discount row — always rendered (empty when there is no
            discount) so every card's title starts at the same height. */}
        <div className="md:hidden order-4 flex h-[13px] items-center gap-2 px-0.5">
          {discountPercent ? (
            <>
              <span className="shrink-0 text-[10px] font-bold uppercase text-green-600">
                {discountPercent}% {t("off")}
              </span>
              <span className="h-px flex-1 border-t border-dashed border-gray-300 dark:border-zinc-600" />
            </>
          ) : null}
        </div>

        {isProductAvailabel ? (
          <button
            type="button"
            disabled={notifyLoading}
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              toggleNotify(isNotifyRequested);
            }}
            className={`flex h-8 md:h-9 w-full md:w-auto md:min-w-[92px] shrink-0 items-center justify-center gap-1 rounded-lg border text-[10px] md:text-[11px] font-bold uppercase text-center leading-tight px-2 transition disabled:opacity-60 ${mobileActionCls} max-md:-mt-[30px] max-md:h-7 max-md:whitespace-nowrap max-md:px-1 max-md:text-[10px] max-md:font-semibold max-md:normal-case ${
              isNotifyRequested
                ? "border-gray-200 dark:border-zinc-700 bg-gray-50 dark:bg-zinc-800 text-gray-400 dark:text-zinc-500"
                : "primaryBorderColor primaryColor bg-white dark:bg-zinc-900 hover:primaryLightBack"
            }`}
          >
            <RingBell on={!!isNotifyRequested} size={13} className="shrink-0 max-md:hidden" />
            <span
              key={`m-${!!isNotifyRequested}`}
              className="md:hidden motion-safe:animate-fadeSwap"
            >
              {isNotifyRequested
                ? t("notified") || "Notified"
                : t("notify") || "Notify"}
            </span>
            <span
              key={`d-${!!isNotifyRequested}`}
              className="max-md:hidden motion-safe:animate-fadeSwap"
            >
              {isNotifyRequested
                ? t("notify_requested") || "Notified"
                : t("notify_me") || "Notify Me"}
            </span>
          </button>
        ) : product?.variants?.length > 1 && !(hasAddons && showStepper) ? (
          // Multi-variant add button
          <button
            type="button"
            onClick={guardClosed((e) => handleShowVariantModal(e, product))}
            {...closedProps}
            className={`flex h-8 md:h-9 w-full md:w-auto md:min-w-[92px] shrink-0 flex-col items-center justify-center rounded-lg border primaryBorderColor primaryColor bg-white dark:bg-zinc-900 px-2 text-[13px] md:text-[14px] font-semibold whitespace-nowrap hover:primaryLightBack transition ${mobileActionCls} max-md:h-7 max-md:justify-between max-md:overflow-hidden max-md:p-0 max-md:-mt-[30px] ${closedProps.className ?? ""}`}
          >
            <span className="flex items-center gap-1 leading-none max-md:w-full max-md:min-h-0 max-md:flex-1 max-md:justify-center max-md:text-[11px] max-md:font-semibold max-md:tracking-wide max-md:uppercase">
              <MdAddShoppingCart size={14} className="shrink-0 max-md:hidden" />
              {t("add")}
            </span>
            <span className="text-[9px] font-medium normal-case leading-none mt-0.5 opacity-80 max-md:mt-0 max-md:w-full max-md:bg-[var(--primary-color)] max-md:py-[2px] max-md:text-[8px] max-md:leading-none max-md:text-white max-md:opacity-100">
              {hasAddons
                ? t("addon_customisable")
                : `${product?.variants?.length} ${t("options") || "options"}`}
            </span>
          </button>
        ) : showStepper ? (
          <button type="button" {...closedProps} aria-label="Remove from cart" onClick={guardClosed(handleQuantityDecrease)} className={`flex h-8 md:h-9 w-[92px] shrink-0 items-center justify-center gap-1 rounded-lg primaryBackColor text-white ${mobileActionCls} max-md:-mt-[30px] max-md:h-7 ${closedProps.className ?? ""}  text-xs font-bold`}>Remove</button>
        ) : (
          <button
            type="button"
            onClickCapture={(e) => {
              setQtyAnim(true);
              // Nothing reaches the cart yet when the addon sheet opens.
              if (!storeClosed && !hasAddons) flyToCart(e.currentTarget);
            }}
            onClick={guardClosed((e) => handleIntialAddToCart(e))}
            {...closedProps}
            className={`flex h-8 md:h-9 w-full md:w-auto md:min-w-[92px] shrink-0 flex-col items-center justify-center overflow-hidden rounded-lg border primaryBorderColor primaryColor bg-white dark:bg-zinc-900 px-2 text-[13px] md:text-[14px] font-semibold whitespace-nowrap hover:primaryLightBack transition ${mobileActionCls} max-md:-mt-[30px] max-md:h-7 max-md:text-[11px] max-md:font-semibold max-md:tracking-wide max-md:uppercase ${hasAddons ? "max-md:justify-between max-md:p-0" : ""} ${closedProps.className ?? ""}`}
          >
            <span className="flex items-center justify-center gap-1 leading-none max-md:w-full max-md:min-h-0 max-md:flex-1">
              <MdAddShoppingCart size={14} className="shrink-0 max-md:hidden" />
              {t("add")}
            </span>
            {hasAddons && (
              <span className="text-[9px] font-medium normal-case leading-none mt-0.5 opacity-80 max-md:mt-0 max-md:w-full max-md:truncate max-md:bg-[var(--primary-color)] max-md:py-[2px] max-md:text-center max-md:text-[8px] max-md:text-white max-md:opacity-100">
                {t("addon_customisable")}
              </span>
            )}
          </button>
        )}
      </div>
    </div>
  );

  const mobileCard = (
    <div
      style={{
        ...(radius != null ? { borderRadius: radius } : {}),
        // Border tinted from the API theme (--primary-color), soft so it reads as
        // a modern hairline rather than a hard outline.
        borderColor:
          "color-mix(in srgb, var(--primary-color) 18%, transparent)",
      }}
      className="group relative flex h-full flex-col rounded-2xl border bg-white p-1.5 shadow-[0_2px_12px_rgba(0,0,0,0.04)] md:p-2 dark:bg-zinc-900"
      onMouseEnter={startHoverSlide}
      onMouseLeave={stopHoverSlide}
    >
      <Link
        href={zoneHref(`/product/${product?.slug}`)}
        prefetch={false}
        onClick={handleStoryClick}
        className="flex h-full flex-col"
      >
        {/* Image */}
        <div className="relative">
          <div className="relative aspect-square w-full overflow-hidden rounded-xl bg-gray-50 dark:bg-zinc-800">
            {galleryImages.length > 1 ? (
              <>
                <MobileCardGallery
                  images={galleryImages}
                  alt={product?.translations?.name ?? product?.name}
                  imgClassName={`p-1 ${isProductAvailabel || storeClosed ? "grayscale" : ""}`}
                />
              </>
            ) : (
              <ImageWithPlaceholder
                className={`h-full w-full object-contain p-1 transition-transform duration-300 ease-out group-hover:scale-110 md:p-2 ${isProductAvailabel || storeClosed ? "grayscale" : ""}`}
                alt={product?.translations?.name ?? product?.name}
                src={galleryImages[0] ?? product?.image_url}
                width={300}
                height={300}
              />
            )}

            {/* Discount ribbon */}
            {discountPercent && !isProductAvailabel ? (
              <div
                className={`absolute start-0 top-0 z-[7] drop-shadow-sm ${closedDecorClass}`}
              >
                <div className="primaryBackColor px-1 pb-0.5 pt-0.5 text-center text-white md:px-1.5 md:pt-1">
                  <span className="block text-[9px] font-extrabold leading-none md:text-[11px]">
                    {discountPercent}%
                  </span>
                  <span className="mt-0.5 block text-[7px] font-semibold uppercase leading-none tracking-wide md:text-[8px]">
                    {t("off")}
                  </span>
                </div>
                <ZigzagEdgeIcon size={4} />
              </div>
            ) : null}

            {/* Sold out */}
            {isProductAvailabel && (
              <span className="absolute inset-0 z-[6] grid place-items-center bg-white/55 dark:bg-zinc-900/55">
                <span className="rounded-md bg-gray-700/90 px-2 py-1 text-[9px] font-bold uppercase leading-none tracking-wide text-white md:text-[10px]">
                  {t("sold_out") || "Sold out"}
                </span>
              </span>
            )}
          </div>

          {/* Wishlist & quick view */}
          <div className="absolute end-1 top-1 z-20 flex flex-col gap-1.5 opacity-100 transition-opacity duration-200 lg:opacity-0 lg:group-hover:opacity-100">
            <PulseHeart
              liked={!!liked}
              onToggle={handleProductLikes}
              animate={canToggleLike}
              showCount={false}
              size={14}
              corner={999}
              pillColor="transparent"
              likedColor="var(--primary-color)"
              label={t("wishlist") || "Wishlist"}
              className="relative flex h-6 w-6 items-center justify-center rounded-full bg-white/90 shadow ring-1 ring-black/5 backdrop-blur sm:h-7 sm:w-7 dark:bg-zinc-900/90"
            />
            <button
              type="button"
              onClick={handleShowDetailModal}
              aria-label={t("quick_view")}
              className="hidden h-7 w-7 items-center justify-center rounded-full bg-white/90 shadow ring-1 ring-black/5 backdrop-blur md:flex dark:bg-zinc-900/90"
            >
              <GoEye size={13} className="text-gray-600 dark:text-zinc-300" />
            </button>
          </div>

          {/* Action — overlaps the image's bottom-right, half outside it. */}
          <div
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
            }}
            className={`absolute -bottom-3 end-1 z-20 flex justify-end ${actionWidthCls}`}
          >
            {actionSlot}
          </div>
        </div>

        {/* Details — mt clears the action's overhang. */}
        <div className="mt-4 flex flex-1 flex-col px-0.5 pb-0.5">
          {showQuickDelivery && !isProductAvailabel && (
            <span className="mb-1 inline-flex w-fit items-center gap-1 rounded-md bg-gray-100 px-1.5 py-0.5 text-[9px] font-bold uppercase leading-none tracking-wide text-gray-700 dark:bg-zinc-800 dark:text-zinc-300">
              <TimeIcon size={10} className="shrink-0 primaryColor" />
              {deliveryLabel}
            </span>
          )}

          <h3
            className={`line-clamp-2 min-h-[30px] text-[12px] font-semibold capitalize leading-[1.25] textColor md:min-h-[32px] md:text-[13px] ${isProductAvailabel ? "opacity-60" : ""}`}
          >
            <ProductTypeTag
              type={product?.product_type ?? product?.indicator}
              className="me-1.5 align-[-2px]"
              iconSize={13}
            />
            {product?.translations?.name ?? product?.name}
          </h3>

          {/* Variant/weight line — height reserved so every card's price aligns. */}
          <span className="mt-0.5 line-clamp-1 min-h-[14px] text-[10px] leading-[14px] text-gray-500 dark:text-zinc-400 md:text-[11px]">
            {variantLabel}
          </span>

          {showRating && (
            <span className="mt-1 flex w-fit items-center gap-0.5 text-[10px] font-semibold text-gray-600 dark:text-zinc-300">
              <FaStar size={10} className="text-yellow-400" />
              {Number(product?.average_rating ?? 0).toFixed(1)}
              <span className="font-normal text-gray-400 dark:text-zinc-500">
                ({product?.rating_count})
              </span>
            </span>
          )}

          <FewLeftBadge
            variant={selectedVariant}
            product={product}
            className="mt-1 text-[9px] whitespace-nowrap"
          />

          {/* Price pinned to the card's bottom */}
          <div className="mt-auto flex flex-wrap items-baseline gap-x-1.5 gap-y-0.5 pt-1.5 leading-tight">
            <span className="whitespace-nowrap text-[13px] font-extrabold textColor md:text-[15px]">
              {money(
                hasDiscount
                  ? selectedVariant?.discounted_price
                  : selectedVariant?.price,
              )}
            </span>
            {hasDiscount && (
              <>
                <span className="whitespace-nowrap text-[10px] line-through SecondaryTextColor md:text-[12px]">
                  {money(selectedVariant?.price)}
                </span>
                {discountPercent ? (
                  <span className="whitespace-nowrap text-[10px] font-bold text-green-600">
                    {discountPercent}% {t("off")}
                  </span>
                ) : null}
              </>
            )}
          </div>
        </div>
      </Link>
    </div>
  );

  return (
    <>
      {classicMobile ? (
        <div className="h-full">{desktopCard}</div>
      ) : (
        <>
          <div className="hidden h-full md:block">{desktopCard}</div>
          <div className="h-full md:hidden">{mobileCard}</div>
        </>
      )}

      <ProductDetailModal
        product={product}
        showDetailModal={showProductDetail}
        setShowDetailModal={setShowProductDetail}
      />
      <VariantsModal
        product={product}
        showVariants={showVariants}
        setShowVariants={setShowVariants}
      />
      <AddonsModal
        product={product}
        showAddons={showAddons}
        setShowAddons={setShowAddons}
        variant={selectedVariant}
      />
      <AddonRepeatModal
        open={showAddonRepeat}
        setOpen={setShowAddonRepeat}
        product={product}
        lastLine={lastAddonLine}
        onRepeat={repeatLastAddonLine}
        onAddNew={openAddonSheetAfterClose}
      />
      <AddonLinesModal
        open={showAddonLines}
        setOpen={setShowAddonLines}
        product={product}
        lines={addonLines}
        onRemoveLine={removeAddonLine}
        onRepeatLine={repeatAddonLine}
        onAddNew={openAddonSheetAfterClose}
      />
    </>
  );
};

export default HomeVerticleProductCard;
