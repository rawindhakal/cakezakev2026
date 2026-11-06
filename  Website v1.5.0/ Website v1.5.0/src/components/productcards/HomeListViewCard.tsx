import React, { useEffect, useState, useRef, useMemo } from "react";
import { t } from "@/utils/translation";
import { FaMinus, FaPlus, FaRegEye, FaStar } from "react-icons/fa";
import {
  MdAddShoppingCart} from "react-icons/md";
import Link from "next/link";
import { useProductStoryClick } from "../productstory/ProductStoryContext";
import VariantsModal from "../variantsmodal/VariantsModal";
import AddonsModal from "../addonsmodal/AddonsModal";
import AddonRepeatModal from "../addonsmodal/AddonRepeatModal";
import AddonLinesModal from "../addonsmodal/AddonLinesModal";
import ProductDetailModal from "../productdetailmodal/ProductDetailModal";
import { useSelector } from "react-redux";
import { useFavoriteToggle } from "@/hooks/useFavoriteToggle";
import { BiHeart, BiSolidHeart } from "react-icons/bi";
import MobileCardGallery from "./MobileCardGallery";
import FewLeftBadge from "./FewLeftBadge";
import TimeIcon from "./TimeIcon";
import {
  formatCurrency, isVideoUrl} from "@/utils/helperFunction";
import useZoneHref from "@/hooks/useZoneHref";
import useStoreClosed from "@/hooks/useStoreClosed";
import useNotifyMe from "@/hooks/useNotifyMe";
import useIsHydrated from "@/hooks/useIsHydrated";
import useCartLine from "@/hooks/useCartLine";
import useCurrency from "@/hooks/useCurrency";
import { flyToCart } from "@/utils/flyToCart";
import PulseHeart from "@/components/ui/pulse-heart/PulseHeart";
import { RingBell } from "@/components/ui/bell-toggle/BellToggle";
import { ZigzagEdgeIcon } from "@/components/icons";
import ProductTypeTag from "../productdetail/ProductTypeTag";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";

interface HomeListViewCardProps {
  product: any;
  radius?: number | string | null;
}

const HomeListViewCard = ({
  product,
  radius = null,
}: HomeListViewCardProps) => {
  const zoneHref = useZoneHref();
  const handleStoryClick = useProductStoryClick(product?.id);

  // Product's decimal_point as fallback (country_setting omits it).
  const { currency, decimals } = useCurrency(product);
  const money = (val: number) => formatCurrency(val, currency, decimals, true);
  const city = useSelector((state: any) => state.City.city);
  const shopMode = useSelector((state: any) => state.ShopMode.mode);

  // ETA badge: quick mode + product has an ETA. Hydration-gated (shopMode is persisted).
  const hydrated = useIsHydrated();
  const deliveryLabel = product?.time_to_deliver;
  const showQuickDelivery = hydrated && shopMode === "quick" && !!deliveryLabel;

  // Seeded synchronously so SSR shows a price; the effect refines it.
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
  } = useCartLine(product, { initialVariant: product?.variants?.[0] ?? [] });
  const [showVariants, setShowVariants] = useState(false);
  const [showProductDetail, setShowProductDetail] = useState(false);
  // Set on first Add/+/- click so cards don't animate on page load.
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

  // Hover slideshow gallery: image_url + images[], deduped.
  // eslint-disable-next-line react-hooks/preserve-manual-memoization
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
    }, 2400);
  };

  const stopHoverSlide = () => {
    if (hoverTimerRef.current) {
      clearInterval(hoverTimerRef.current);
      hoverTimerRef.current = null;
    }
    setHoverImgIdx(0);
  };

  useEffect(() => () => stopHoverSlide(), []);

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

  const productsVariants = product.variants;

  const {
    storeClosed,
    guard: guardClosed,
    closedProps,
    closedDecorClass,
  } = useStoreClosed();

  const isProductAvailabel =
    (product?.variants?.length <= 1 &&
      product?.variants?.[0]?.is_unlimited_stock == 0 &&
      product?.variants?.[0]?.stock == 0) ||
    (selectedVariant?.stock <= 0 && selectedVariant?.is_unlimited_stock == 0) ||
    selectedVariant?.status == 0 ||
    product?.status == 0;

  const hasDiscount =
    selectedVariant?.discounted_price !== 0 &&
    selectedVariant?.discounted_price !== selectedVariant?.price;
  // Discount % comes straight from the API; hidden if 0/absent, no computed fallback.
  const discountPercent =
    Number(selectedVariant?.discount_percent ?? product?.discount_percent) ||
    null;

  return (
    <div className="h-full">
      <Link
        href={zoneHref(`/product/${product?.slug}`)}
        prefetch={false}
        onClick={handleStoryClick}
        style={{
          ...(radius != null ? { borderRadius: radius } : {}),
          // Border tinted from the API theme (--primary-color) — soft hairline.
          borderColor:
            "color-mix(in srgb, var(--primary-color) 18%, transparent)",
        }}
        className={`relative flex h-full flex-row items-center w-full gap-3 sm:gap-4 p-2.5 sm:p-3 group border bg-white dark:bg-zinc-900 rounded-2xl overflow-hidden shadow-[0_2px_12px_rgba(0,0,0,0.04)] transition-all duration-300 ease-out ${
          isProductAvailabel ? "cursor-pointer" : ""
        }`}
        onMouseEnter={startHoverSlide}
        onMouseLeave={stopHoverSlide}
      >
        {/* Discount ribbon, shown only when the API sends a percent. */}
        {discountPercent && (
          <div
            className={`absolute top-0 left-4 z-10 drop-shadow-md ${closedDecorClass}`}
          >
            <div className="primaryBackColor text-white text-center px-1.5 pt-1 pb-0.5">
              <span className="block text-[11px] md:text-[13px] font-extrabold leading-none">
                {discountPercent}%
              </span>
              <span className="block text-[8px] md:text-[9px] font-semibold uppercase tracking-wide leading-none mt-0.5">
                {t("off")}
              </span>
            </div>
<ZigzagEdgeIcon size={6} />
          </div>
        )}
        {/* Mobile wishlist — card's top-right corner; desktop uses the image overlay. */}
        <button
          type="button"
          onClick={handleProductLikes}
          className="lg:hidden absolute top-2 right-2 z-20 flex h-8 w-8 items-center justify-center rounded-full bg-white/90 dark:bg-zinc-900/90 backdrop-blur shadow-sm ring-1 ring-black/5 transition-transform duration-200 active:scale-90"
          aria-label={t("add_to_wishlist") || "Wishlist"}
        >
          {liked ? (
            <BiSolidHeart size={15} className="primaryFilledColor" />
          ) : (
            <BiHeart size={15} className="svgColors" />
          )}
        </button>

        {/* Image */}
        <div className="relative shrink-0 w-24 h-24 sm:w-32 sm:h-32 overflow-hidden rounded-xl bg-gradient-to-br from-gray-50 to-gray-100 dark:from-zinc-800 dark:to-zinc-900">
          {galleryImages.length > 1 ? (
            <>
            <MobileCardGallery
              images={galleryImages}
              alt={product?.name}
              imgClassName={`p-3 ${isProductAvailabel || storeClosed ? "grayscale" : ""}`}
            />
            {/* Cross-fade, not remount: images stacked, only active one opaque, avoids a flash. */}
            <div className="max-md:hidden relative h-full w-full transition-transform duration-300 ease-out group-hover:scale-110">
              {galleryImages.map((imgSrc, idx) => (
                <ImageWithPlaceholder
                  key={idx}
                  src={imgSrc}
                  alt={product?.name}
                  width={400}
                  height={400}
                  className={`absolute inset-0 w-full h-full object-contain p-3 transition-opacity duration-700 ease-in-out ${
                    idx === hoverImgIdx ? "opacity-100" : "opacity-0"
                  } ${isProductAvailabel || storeClosed ? "grayscale" : ""}`}
                  sizes="(max-width: 640px) 40vw, 200px"
                  quality={75}
                  priority={idx === 0}
                />
              ))}
            </div>
            </>
          ) : (
            <ImageWithPlaceholder
              src={galleryImages[0] ?? product?.image_url}
              alt={product?.name}
              width={400}
              height={400}
              className={`w-full h-full object-contain p-3 transition-transform duration-300 ease-out group-hover:scale-110 ${isProductAvailabel || storeClosed ? "grayscale" : ""}`}
              sizes="(max-width: 640px) 40vw, 200px"
              quality={75}
            />
          )}

          {/* Wishlist + quick view — desktop-only hover overlay, hidden on mobile. */}
          <div className="absolute top-1.5 right-1.5 z-20 hidden lg:flex flex-col gap-1.5 opacity-0 group-hover:opacity-100 transition-opacity duration-200 cursor-pointer">
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
              className="relative flex h-7 w-7 sm:h-8 sm:w-8 items-center justify-center rounded-full bg-white/90 backdrop-blur shadow-md ring-1 ring-black/5"
            />
            <button
              type="button"
              onClick={handleShowDetailModal}
              aria-label={t("quick_view")}
              className="flex h-7 w-7 sm:h-8 sm:w-8 items-center justify-center rounded-full bg-white/90 backdrop-blur shadow-md ring-1 ring-black/5 transition-transform duration-200 hover:scale-110 active:scale-95"
            >
              <FaRegEye size={13} className="svgColors" />
            </button>
          </div>
        </div>

        {/* vertical divider between image and details — API-themed hairline. */}
        <div
          className="hidden sm:block self-stretch w-px my-1"
          style={{
            background:
              "color-mix(in srgb, var(--primary-color) 14%, transparent)",
          }}
        />

        {/* Details + Actions wrapper — stacks on mobile, side-by-side on lg */}
        <div className="flex flex-1 min-w-0 flex-col gap-3 lg:flex-row lg:items-center lg:gap-5">
          {/* Details */}
          <div className="flex flex-1 min-w-0 flex-col">
            {product?.category_name && (
              <span className="text-[10px] sm:text-[11px] font-semibold uppercase tracking-wide text-gray-400 dark:text-zinc-500 line-clamp-1">
                {product.category_name}
              </span>
            )}

            <h3 className="textColor text-sm sm:text-base font-bold capitalize line-clamp-2 transition-colors duration-200 group-hover:primaryColor dark:group-hover:text-white">
              <ProductTypeTag
                type={product?.product_type ?? product?.indicator}
                className="me-1.5 align-[-2px]"
                iconSize={16}
              />
              {product?.translations?.name ?? product?.name}
            </h3>

            {/* rating + delivery on one line */}
            <div className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1">
              {!!product?.product_rating &&
                Number(product?.rating_count) > 0 && (
                  <span className="flex items-center gap-1 text-[11px] font-bold text-gray-700 dark:text-zinc-200">
                    <FaStar size={11} className="text-amber-400" />
                    {Number(product?.average_rating).toFixed(1)}
                    <span className="font-normal text-gray-400 dark:text-zinc-500">
                      ({product?.rating_count})
                    </span>
                  </span>
                )}
            </div>

            {product?.short_description && (
              <p className="mt-1 text-[12px] sm:text-sm text-gray-500 dark:text-zinc-400 leading-snug line-clamp-1 lg:line-clamp-2">
                {product.short_description}
              </p>
            )}

            <FewLeftBadge
              variant={selectedVariant}
              product={product}
              className="mt-1"
            />

            {/* Price */}
            <div className="mt-2 flex flex-wrap items-baseline gap-x-2 gap-y-1">
              <span className="textColor text-lg sm:text-xl font-extrabold tracking-tight">
                {money(
                  hasDiscount
                    ? selectedVariant?.discounted_price
                    : selectedVariant?.price,
                )}
              </span>
              {hasDiscount && (
                <>
                  <span className="text-xs sm:text-sm line-through SecondaryTextColor">
                    {money(selectedVariant?.price)}
                  </span>
                  {(discountPercent ?? 0) > 0 && (
                    <span className="text-[11px] sm:text-xs font-bold text-green-600 whitespace-nowrap">
                      {discountPercent}% {t("off")}
                    </span>
                  )}
                </>
              )}
            </div>
          </div>

          {/* Actions — ADD / stepper only; wishlist sits in the card corner. */}
          {/* One row under the details on small screens — stacking them there
              made the card tall and squeezed the title. */}
          <div className="flex w-full flex-row items-center justify-between gap-2 lg:w-auto lg:flex-col lg:items-end lg:self-center lg:shrink-0">
            {showQuickDelivery && !isProductAvailabel && (
              <span className="inline-flex shrink-0 items-center gap-1 rounded-full bg-gray-100 dark:bg-zinc-800 px-2 py-0.5 text-[10px] font-bold text-gray-700 dark:text-zinc-300">
                {/* 12px, not 9px — this icon's detail collapses into a smudge smaller. */}
                <TimeIcon size={12} className="primaryColor dark:text-zinc-200" />
                {deliveryLabel}
              </span>
            )}
            {/* ADD / stepper — min width so long translated labels can grow it */}
            <div className="w-auto min-w-[76px] sm:min-w-[84px] shrink-0">
              {isProductAvailabel ? (
                <button
                  type="button"
                  disabled={notifyLoading}
                  onClick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    toggleNotify(isNotifyRequested);
                  }}
                  className={`flex h-9 w-full items-center justify-center gap-1 rounded-lg border text-[11px] font-semibold text-center leading-tight px-2 transition disabled:opacity-60 ${
                    isNotifyRequested
                      ? "border-gray-200 dark:border-zinc-700 bg-gray-50 dark:bg-zinc-800 text-gray-400 dark:text-zinc-500"
                      : "primaryBorderColor primaryColor bg-white dark:bg-zinc-900 hover:primaryLightBack"
                  }`}
                >
                  <RingBell on={!!isNotifyRequested} size={14} className="shrink-0" />
                  <span key={String(!!isNotifyRequested)} className="motion-safe:animate-fadeSwap">
                    {isNotifyRequested ? t("notify_requested") || "Notified" : t("notify_me") || "Notify Me"}
                  </span>
                </button>
              ) : showStepper ? (
                <button type="button" {...closedProps} aria-label="Remove from cart" onClick={guardClosed(handleQuantityDecrease)} className={`flex h-9 w-full items-center justify-center gap-1  rounded-lg primaryBackColor text-white ${closedProps.className ?? ""}  text-xs font-bold`}>Remove</button>
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
                  {...closedProps}
                  className={`flex h-9 w-full flex-col items-center justify-center overflow-hidden rounded-lg border primaryBorderColor primaryColor bg-white dark:bg-zinc-900 px-2 text-[13px] md:text-[14px] font-semibold whitespace-nowrap hover:primaryLightBack transition ${closedProps.className ?? ""}`}
                >
                  <span className="flex items-center gap-1 leading-none">
                    <MdAddShoppingCart size={14} className="shrink-0" />
                    {t("add")}
                  </span>
                  {(hasAddons || productsVariants?.length > 1) && (
                    <span className="w-full truncate text-center text-[9px] font-medium normal-case leading-none mt-0.5 opacity-80">
                      {hasAddons
                        ? t("addon_customisable")
                        : `${productsVariants?.length} ${t("options") || "options"}`}
                    </span>
                  )}
                </button>
              )}
            </div>
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

export default HomeListViewCard;
