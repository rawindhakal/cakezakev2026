import React, { useState, useEffect, useRef, useMemo } from "react";
import { FaStar, FaMinus, FaPlus} from "react-icons/fa";
import {
  MdAddShoppingCart} from "react-icons/md";
import Link from "next/link";
import { t } from "@/utils/translation";
import VariantsModal from "../variantsmodal/VariantsModal";
import AddonsModal from "../addonsmodal/AddonsModal";
import AddonRepeatModal from "../addonsmodal/AddonRepeatModal";
import AddonLinesModal from "../addonsmodal/AddonLinesModal";
import ProductDetailModal from "../productdetailmodal/ProductDetailModal";
import { useSelector } from "react-redux";
import { useFavoriteToggle } from "@/hooks/useFavoriteToggle";
import MobileCardGallery from "./MobileCardGallery";
import FewLeftBadge from "./FewLeftBadge";
import TimeIcon from "./TimeIcon";
import { GoEye } from "react-icons/go";
import {
  formatCurrency,
  isVariantOutOfStock, isVideoUrl} from "@/utils/helperFunction";
import useZoneHref from "@/hooks/useZoneHref";
import useNotifyMe from "@/hooks/useNotifyMe";
import useIsRtl from "@/hooks/useIsRtl";
import useStoreClosed from "@/hooks/useStoreClosed";
import useIsHydrated from "@/hooks/useIsHydrated";
import useCartLine from "@/hooks/useCartLine";
import useCurrency from "@/hooks/useCurrency";
import { flyToCart } from "@/utils/flyToCart";
import PulseHeart from "@/components/ui/pulse-heart/PulseHeart";
import { RingBell } from "@/components/ui/bell-toggle/BellToggle";
import ProductTypeTag from "../productdetail/ProductTypeTag";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";

interface VerticleProductCardProps {
  product: any;
  largeImage?: boolean;
  radius?: number | string | null;
}

const VerticleProductCard = ({
  product,
  largeImage = false,
  radius = null,
}: VerticleProductCardProps) => {
  const zoneHref = useZoneHref();
  const rtl = useIsRtl();

  // Format currency with zone defaults
  const { currency, decimals } = useCurrency(product);
  const money = (val: number) => formatCurrency(val, currency, decimals, true);
  const city = useSelector((state: any) => state.City.city);
  const shopMode = useSelector((state: any) => state.ShopMode.mode);

  // Quick delivery label gated on hydration
  const hydrated = useIsHydrated();
  const deliveryLabel = product?.time_to_deliver;
  const showQuickDelivery = hydrated && shopMode === "quick" && !!deliveryLabel;

  // Initial default variant computation
  const defaultVariant = useMemo(() => {
    const variants = product?.variants;
    if (!Array.isArray(variants) || variants.length === 0) return undefined;
    const inStock = variants.find(
      (variant: any) => variant?.is_unlimited_stock === 0 && variant?.stock > 0,
    );
    return inStock ?? variants[0];
  }, [product?.variants]);

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
  } = useCartLine(product, { initialVariant: defaultVariant });
  const [showVariants, setShowVariants] = useState(false);
  const [showProductDetail, setShowProductDetail] = useState(false);
  // Stepper animation state
  const [qtyAnim, setQtyAnim] = useState(false);
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
    }, 900);
  };

  const stopHoverSlide = () => {
    if (hoverTimerRef.current) {
      clearInterval(hoverTimerRef.current);
      hoverTimerRef.current = null;
    }
    setHoverImgIdx(0);
  };

  useEffect(() => () => stopHoverSlide(), []);

  const calculateDiscount = (discountPrice: number, actualPrice: number) => {
    const difference = actualPrice - discountPrice;
    const actualDiscountPrice = difference / actualPrice;
    return actualDiscountPrice * 100;
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

  const handleShowDetailModal = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setShowProductDetail(true);
  };

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
    isVariantOutOfStock(selectedVariant) ||
    (selectedVariant?.status !== undefined &&
      Number(selectedVariant?.status) === 0) ||
    (product?.status !== undefined && Number(product?.status) === 0);

  const hasDiscount =
    selectedVariant?.discounted_price !== 0 &&
    selectedVariant?.discounted_price !== selectedVariant?.price;
  const discountPercent = hasDiscount
    ? Math.round(
        selectedVariant?.discount_percent ??
          product?.discount_percent ??
          calculateDiscount(
            selectedVariant?.discounted_price,
            selectedVariant?.price,
          ),
      )
    : null;

  const branchName =
    product?.brand_name ??
    product?.branch_name ??
    product?.branch?.branch_name ??
    "";

  // Some payloads send `rating` instead of `average_rating`.
  const ratingValue = Math.round(
    Number(product?.average_rating ?? product?.rating ?? 0),
  );

  // product_rating may be true/1/"1" — coerce loosely.
  const showRating =
    !!product?.product_rating && Number(product?.rating_count) > 0;

  // Mobile (Blinkit-style) variant label for the grey bar under the image.
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
  // Mobile: action control overlaps the image's bottom-right (Blinkit).
  const mobileActionCls =
    "max-md:order-2 max-md:relative max-md:z-10 max-md:self-end max-md:me-0 max-md:w-[50%] max-md:min-w-[48px] max-md:rounded-lg max-md:shadow-sm max-md:shrink-0";

  return (
    <div className="@container relative h-full">
      <Link
        href={zoneHref(`/product/${product?.slug}`)}
        prefetch={false}
        style={{
          ...(radius != null ? { borderRadius: radius } : {}),
          borderColor:
            "color-mix(in srgb, var(--primary-color) 18%, transparent)",
        }}
        className={`group flex h-full flex-col overflow-hidden rounded-lg border bg-white dark:bg-zinc-900 shadow-[0_2px_12px_rgba(0,0,0,0.04)] transition-all duration-200 max-md:overflow-visible max-md:rounded-none max-md:border-0 max-md:bg-transparent max-md:p-0 max-md:shadow-none dark:max-md:bg-transparent ${
          isProductAvailabel ? "cursor-not-allowed" : ""
        }`}
        onMouseEnter={startHoverSlide}
        onMouseLeave={stopHoverSlide}
      >
        <div className="relative p-2 max-md:order-1 max-md:p-0">
          {hasDiscount &&
            (discountPercent ?? 0) > 0 &&
            (() => {
              const offLabel = `${discountPercent}% ${t("off")}`;
              // Long translations shrink to fit the fixed-width ribbon.
              const isLong = offLabel.length > 10;
              return (
                <span
                  className={`max-md:hidden absolute top-4 z-10 w-40 transform-gpu ${isLong ? "overflow-hidden whitespace-nowrap" : ""} [backface-visibility:hidden] primaryBackColor py-1.5 text-center font-bold uppercase leading-none text-white shadow-md ${isLong ? "text-[9px] tracking-tight" : "text-[13px] tracking-wide"} ${rtl ? "-right-12 rotate-45" : "-left-12 -rotate-45"} ${closedDecorClass}`}
                >
                  {offLabel}
                </span>
              );
            })()}
          <div className="relative aspect-[5/4] max-md:aspect-[4/5] w-full overflow-hidden rounded-xl bg-gray-50 dark:bg-zinc-800 max-md:bg-white max-md:ring-1 max-md:ring-gray-200 dark:max-md:bg-zinc-900 dark:max-md:ring-zinc-700">
            {/* Mobile: "Sold out" tag (matches the app). isProductAvailabel is
                true when the product is NOT available. */}
            {isProductAvailabel && (
              <span className="md:hidden absolute start-0 top-0 z-10 rounded-ee-lg bg-gray-600/90 px-2 py-1 text-[11px] font-medium leading-none text-white">
                {t("sold_out") || "Sold out"}
              </span>
            )}
            {/* Mobile: grey variant bar along the image bottom; ADD overlaps its right end. */}
            <span className="md:hidden absolute inset-x-0 bottom-0 z-[5] flex h-8 items-center bg-gray-100 ps-2 text-[12px] font-medium text-gray-700 dark:bg-zinc-800/95 dark:text-zinc-200">
              <span
                className="min-w-0 max-w-[46%] pe-1.5 line-clamp-2 break-words text-[11px] leading-[1.15]"
                title={variantLabel}
              >
                {variantLabel}
              </span>
            </span>
            {galleryImages.length > 1 ? (
              <>
              <MobileCardGallery
                images={galleryImages}
                alt={
                  product?.translations?.name ??
                  product?.product_name ??
                  product?.name
                }
                imgClassName={`pb-8 ${storeClosed ? "grayscale" : ""}`}
                dotsClassName="bottom-9 start-2"
              />
              <div className="max-md:hidden relative h-full w-full transition-transform duration-300 ease-out group-hover:scale-110">
                {galleryImages.map((img, idx) => (
                  <ImageWithPlaceholder
                    key={img + idx}
                    className={`absolute inset-0 object-contain h-full w-full p-2.5 max-md:p-0 max-md:pb-8 transition-opacity duration-500 ease-out ${
                      idx === hoverImgIdx ? "opacity-100" : "opacity-0"
                    } ${isProductAvailabel ? "md:grayscale" : storeClosed ? "grayscale" : ""}`}
                    alt={
                      product?.translations?.name ??
                      product?.product_name ??
                      product?.name
                    }
                    src={img}
                    width={300}
                    height={300}
                    priority={idx === 0}
                  />
                ))}
              </div>
              </>
            ) : (
              <ImageWithPlaceholder
                className={`object-contain h-full w-full p-2.5 max-md:p-0 max-md:pb-8 transition-transform duration-300 ease-out group-hover:scale-110 ${
                  isProductAvailabel
                    ? "md:grayscale"
                    : storeClosed
                      ? "grayscale"
                      : ""
                }`}
                alt={
                  product?.translations?.name ??
                  product?.product_name ??
                  product?.name
                }
                src={galleryImages[0] ?? product?.image_url}
                width={300}
                height={300}
                // No priority — preloading every tile hurts the real LCP.
              />
            )}
            {showQuickDelivery && !isProductAvailabel && (
              <span
                className={`max-md:hidden absolute bottom-2 z-10 inline-flex items-center gap-1 rounded-md bg-white/95 dark:bg-zinc-900/90 backdrop-blur-sm px-1.5 py-0.5 text-[10px] font-bold text-gray-800 dark:text-zinc-100 shadow-sm ring-1 ring-black/5 ${rtl ? "right-2" : "left-2"}`}
              >
                <TimeIcon size={12} className="primaryColor" />
                {deliveryLabel}
              </span>
            )}
          </div>

          <div
            className={`absolute top-3 max-md:top-2.5 z-20 flex flex-col gap-2 opacity-100 lg:opacity-0 lg:group-hover:opacity-100 transition-opacity duration-200 cursor-pointer ${rtl ? "left-3" : "right-3"}`}
          >
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
              className="max-md:hidden relative flex h-8 w-8 items-center justify-center rounded-full bg-white dark:bg-zinc-900 shadow"
            />
            <button
              type="button"
              onClick={handleShowDetailModal}
              aria-label={t("quick_view")}
              className="max-md:hidden flex h-8 w-8 items-center justify-center rounded-full bg-white dark:bg-zinc-900 shadow"
            >
              <GoEye size={15} className="text-gray-600 dark:text-zinc-300" />
            </button>
          </div>
        </div>

        {/* Rows keep fixed heights so price rows line up across cards. */}
        <div className="flex grow flex-col px-2 pt-1 pb-0 md:px-3 max-md:contents">
          {/* min-h keeps height even without a category. */}
          <span className="max-md:hidden block min-h-[13px] text-[9px] md:text-[10px] uppercase tracking-wide text-gray-400 dark:text-zinc-500 truncate leading-tight">
            {product?.category_name || ""}
          </span>

          <h3
            className={`mt-0.5 textColor text-[12px] md:text-[13px] font-semibold leading-snug line-clamp-1 capitalize group-hover:primaryColor dark:group-hover:text-white max-md:order-5 max-md:px-0.5 max-md:text-[13px] max-md:font-normal max-md:line-clamp-3 ${isProductAvailabel ? "max-md:opacity-60" : ""}`}
          >
            <ProductTypeTag
              type={product?.product_type ?? product?.indicator}
              className="me-1.5 align-[-2px]"
              iconSize={13}
            />
            {product?.translations?.name ??
              product?.product_name ??
              product?.name}
          </h3>

          {showRating && (
            <div className="mt-0.5 flex items-center max-md:order-6 max-md:px-0.5">
              <span className="flex items-center gap-0.5 text-[10px] md:text-[11px] text-gray-500 dark:text-zinc-400">
                {[1, 2, 3, 4, 5].map((i) => (
                  <FaStar
                    key={i}
                    size={11}
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
            className="max-md:order-6 max-md:px-0.5 max-md:text-[10px] max-md:whitespace-nowrap"
          />

          {/* Mobile: ETA at the bottom (desktop overlays it on the image). */}
          {showQuickDelivery && !isProductAvailabel && (
            <span className="md:hidden order-7 mt-1 inline-flex w-fit items-center gap-1 px-0.5 text-[11px] text-gray-600 dark:text-zinc-300">
              <TimeIcon size={11} className="shrink-0" />
              {deliveryLabel}
            </span>
          )}
          <span className="md:hidden order-8 h-2.5" aria-hidden />

          {/* No flex-wrap — a wide price would push Add onto its own line. */}
          <div className="mt-auto flex items-end justify-between gap-x-1.5 pt-1.5 pb-1.5 max-md:contents">
            <div className="flex min-w-0 shrink-0 flex-col leading-tight max-md:order-3 max-md:flex-row max-md:items-baseline max-md:gap-1.5 max-md:px-0.5 max-md:pt-1.5">
              <span className="textColor text-[13px] max-md:text-[15px] max-md:font-bold md:text-[15px] font-extrabold whitespace-nowrap">
                {money(
                  hasDiscount
                    ? selectedVariant?.discounted_price
                    : selectedVariant?.price,
                )}
              </span>
              {/* Reserved even without a discount, for equal heights. */}
              <span
                className={`SecondaryTextColor text-[11px] max-md:text-[11px] md:text-[12px] truncate ${hasDiscount ? "line-through" : "invisible max-md:hidden"}`}
              >
                {hasDiscount ? money(selectedVariant?.price) : "0"}
              </span>
            </div>

            {/* Mobile discount row — always rendered (empty without a discount)
                so every card's title starts at the same height. */}
            <div className="md:hidden order-4 flex h-[15px] items-center gap-2 px-0.5">
              {hasDiscount && (discountPercent ?? 0) > 0 ? (
                <>
                  <span className="shrink-0 text-[12px] font-semibold uppercase text-green-600">
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
                className={`flex h-8 md:h-9 w-auto min-w-0 md:min-w-[92px] shrink items-center justify-center gap-1 rounded-lg border px-2 text-[10px] md:text-[11px] font-bold uppercase text-center leading-tight transition disabled:opacity-60 ${mobileActionCls} max-md:-mt-[34px] max-md:h-8 max-md:whitespace-nowrap max-md:px-1 max-md:text-[12px] max-md:font-semibold max-md:normal-case ${
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
            ) : showStepper ? (
              <button type="button" {...closedProps} aria-label="Remove from cart" onClick={guardClosed(handleQuantityDecrease)} className={`flex h-8 md:h-9 w-[84px] md:w-[92px] shrink-0 items-center justify-center gap-1 rounded-lg primaryBackColor text-white ${mobileActionCls} max-md:-mt-[34px] max-md:h-8 ${closedProps.className ?? ""}  text-xs font-bold`}>Remove</button>
            ) : (
              <button
                type="button"
                onClickCapture={(e) => {
                  setQtyAnim(true);
                  // Nothing reaches the cart yet when the addon sheet opens.
                  if (!(productsVariants?.length > 1) && !storeClosed && !hasAddons)
                    flyToCart(e.currentTarget);
                }}
                onClick={guardClosed((e) =>
                  productsVariants?.length > 1
                    ? handleShowVariantModal(e, product)
                    : handleIntialAddToCart(e),
                )}
                aria-label={t("add")}
                {...closedProps}
                className={`flex h-8 md:h-9 w-auto min-w-0 md:min-w-[92px] shrink flex-col items-center justify-center overflow-hidden rounded-lg border primaryBorderColor primaryColor bg-white dark:bg-zinc-900 px-1.5 md:px-2 text-[13px] md:text-[14px] font-semibold whitespace-nowrap hover:primaryLightBack transition ${mobileActionCls} ${
                  hasAddons || productsVariants?.length > 1
                    ? "max-md:-mt-[34px] max-md:h-8 max-md:justify-between max-md:overflow-hidden max-md:p-0"
                    : "max-md:-mt-[34px] max-md:h-8"
                } ${closedProps.className ?? ""}`}
              >
                <span className="flex items-center gap-1 leading-none max-md:w-full max-md:min-h-0 max-md:flex-1 max-md:justify-center max-md:text-[13px] max-md:font-semibold max-md:tracking-wide max-md:uppercase">
                  <MdAddShoppingCart
                    size={14}
                    className="shrink-0 max-md:hidden"
                  />
                  {t("add")}
                </span>
                {(hasAddons || productsVariants?.length > 1) && (
                  <span className="w-full truncate px-1 text-center text-[9px] font-medium normal-case leading-none mt-0.5 opacity-80 max-md:mt-0 max-md:bg-[var(--primary-color)] max-md:py-[2px] max-md:text-white max-md:opacity-100">
                    {hasAddons
                      ? t("addon_customisable")
                      : `${productsVariants?.length} ${t("options") || "options"}`}
                  </span>
                )}
              </button>
            )}
          </div>
        </div>
      </Link>

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
    </div>
  );
};

export default React.memo(VerticleProductCard);
