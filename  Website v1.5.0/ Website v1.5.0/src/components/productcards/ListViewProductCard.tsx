import React, { useEffect, useState, useRef, useMemo } from "react";
import { t } from "@/utils/translation";
import { FaMinus, FaPlus, FaRegEye, FaStar } from "react-icons/fa";
import Link from "next/link";
import {
  MdAddShoppingCart} from "react-icons/md";
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
import {
  formatCurrency, isVideoUrl} from "@/utils/helperFunction";
import useZoneHref from "@/hooks/useZoneHref";
import useNotifyMe from "@/hooks/useNotifyMe";
import useStoreClosed from "@/hooks/useStoreClosed";
import useIsHydrated from "@/hooks/useIsHydrated";
import useCartLine from "@/hooks/useCartLine";
import useCurrency from "@/hooks/useCurrency";
import { flyToCart } from "@/utils/flyToCart";
import PulseHeart from "@/components/ui/pulse-heart/PulseHeart";
import { RingBell } from "@/components/ui/bell-toggle/BellToggle";
import ProductTypeTag from "../productdetail/ProductTypeTag";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";

interface ListViewProductCardProps {
  product: any;
  radius?: number | string | null;
}

const ListViewProductCard = ({
  product,
  radius = null,
}: ListViewProductCardProps) => {
  const zoneHref = useZoneHref();

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
  // eslint-disable-next-line react-hooks/preserve-manual-memoization -- compiler infers a single field; deps intentionally include both product?.image_url and product?.images since both feed the list
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
  const getProductQuantities = (products: any[]) => {
    return Object.entries(
      products?.reduce((quantities: Record<string, number>, product: any) => {
        const existingQty = quantities[product.product_id] || 0;
        return {
          ...quantities,
          [product.product_id]: existingQty + product.qty,
        };
      }, {}),
    ).map(([productId, qty]) => ({
      product_id: parseInt(productId),
      qty,
    }));
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

  // Optimistic + in-flight-guarded wishlist toggle. Rapid clicks used to each
  // read the pre-response redux state and fire their own addToFavorite; the hook
  // flips redux on click and drops clicks while a call is running.
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

  // Variant/weight line — mobile list rows show it under the price (app style).
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
  // Exact % from API variant, else computed (not rounded up).
  const discountPercent = hasDiscount
    ? (selectedVariant?.discount_percent ??
      Number(
        calculateDiscount(
          selectedVariant?.discounted_price,
          selectedVariant?.price,
        ).toFixed(2),
      ))
    : null;

  // One action control (notify / stepper / add), reused by the inline row and
  // the mobile overlay that sits on the image's bottom edge.
  const actionNode = (
    <>
          {isProductAvailabel ? (
            <button
              type="button"
              disabled={notifyLoading}
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                toggleNotify(isNotifyRequested);
              }}
              className={`flex h-10 flex-1 min-w-0 basis-0 items-center justify-center gap-1.5 rounded-lg border px-3 text-sm font-semibold whitespace-nowrap transition disabled:opacity-60 max-md:h-8 max-md:w-full max-md:flex-none max-md:gap-1 max-md:px-1.5 max-md:text-[11px] max-md:shadow-sm ${
                isNotifyRequested
                  ? "border-gray-300 dark:border-zinc-700 bg-gray-50 dark:bg-zinc-800 text-gray-400 dark:text-zinc-500"
                  : "primaryBorderColor primaryColor bg-white dark:bg-zinc-900 hover:primaryLightBack"
              }`}
            >
              <RingBell on={!!isNotifyRequested} size={15} className="shrink-0 max-md:hidden" />
              <span key={String(!!isNotifyRequested)} className="truncate leading-none motion-safe:animate-fadeSwap">
                {isNotifyRequested ? t("notify_requested") || "Notified" : t("notify_me") || "Notify Me"}
              </span>
            </button>
          ) : (
            <>
              {showStepper ? (
                <button type="button" {...closedProps} aria-label="Remove from cart" onClick={guardClosed(handleQuantityDecrease)} className={`flex h-10 flex-1 min-w-0 basis-0 items-center justify-center gap-1  rounded-lg primaryBackColor text-white max-md:h-8 max-md:w-full max-md:flex-none max-md:shadow-sm ${closedProps.className ?? ""}  text-xs font-bold`}>Remove</button>
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
                  className={`flex h-10 flex-1 min-w-0 basis-0 flex-col items-center justify-center overflow-hidden rounded-lg border primaryBorderColor primaryColor bg-white dark:bg-zinc-900 text-sm font-semibold whitespace-nowrap hover:primaryLightBack transition px-3 max-md:h-8 max-md:w-full max-md:flex-none max-md:px-1.5 max-md:text-[11px] max-md:shadow-sm ${closedProps.className ?? ""}`}
                >
                  <span className="flex items-center gap-1.5 leading-none">
                    <MdAddShoppingCart size={16} className="shrink-0 max-md:hidden" />
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
            </>
          )}
    </>
  );

  return (
    <div className="h-full">
      <Link
        href={zoneHref(`/product/${product?.slug}`)}
        prefetch={false}
        style={{
          ...(radius != null ? { borderRadius: radius } : {}),
          // Border tinted from the API theme (--primary-color) — soft hairline.
          borderColor:
            "color-mix(in srgb, var(--primary-color) 18%, transparent)",
        }}
        className={`flex flex-row max-md:flex-row-reverse h-full min-h-[140px] max-md:min-h-0 w-full gap-3 p-2.5 sm:p-3 group border bg-white dark:bg-zinc-900 rounded-lg shadow-[0_1px_4px_rgba(0,0,0,0.05)] hover:shadow-[0_3px_14px_rgba(0,0,0,0.08)] transition-shadow duration-200 ${
          isProductAvailabel ? "cursor-not-allowed" : ""
        }`}
        onMouseEnter={startHoverSlide}
        onMouseLeave={stopHoverSlide}
      >
        {/* Image — fixed square, top-aligned so card height is driven by content,
            not a stretched image. Keeps every card the same height across a row. */}
        <div className="relative shrink-0 self-start max-md:pb-3">
        <div className="relative w-24 h-24 max-md:w-[108px] max-md:h-[108px] sm:w-28 sm:h-28 overflow-hidden rounded-xl bg-[#f7f8fa] dark:bg-zinc-800">
          {hasDiscount && (discountPercent ?? 0) > 0 && (
            <span
              className={`absolute -left-10 top-4 z-10 w-32 -rotate-45 rtl:left-auto rtl:-right-10 rtl:rotate-45 primaryBackColor py-1 text-center text-[11px] font-bold uppercase leading-none tracking-wide text-white shadow-md ${closedDecorClass}`}
            >
              {Math.round(discountPercent ?? 0)}% {t("off")}
            </span>
          )}
          {/* wishlist + quick view overlay — desktop only, reveal on hover */}
          <div className="absolute right-1.5 top-1.5 z-20 flex flex-col gap-1.5 opacity-100 lg:opacity-0 lg:group-hover:opacity-100 transition-opacity duration-200 cursor-pointer">
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
              className="relative flex h-7 w-7 items-center justify-center rounded-full bg-white/90 dark:bg-zinc-800/90 shadow-sm hover:primaryBorder"
            />
            <button
              type="button"
              onClick={handleShowDetailModal}
              aria-label={t("quick_view")}
              className="max-md:hidden flex h-7 w-7 items-center justify-center rounded-full bg-white/90 dark:bg-zinc-800/90 shadow-sm hover:primaryBorder"
            >
              <FaRegEye size={13} className="svgColors hover:primaryColor" />
            </button>
          </div>
          {isProductAvailabel && (
            <span className="md:hidden absolute start-0 top-0 z-10 rounded-ee-lg bg-gray-600/90 px-1.5 py-0.5 text-[10px] font-medium leading-none text-white">
              {t("sold_out") || "Sold out"}
            </span>
          )}
          {galleryImages.length > 1 ? (
            <>
            <MobileCardGallery
              images={galleryImages}
              alt={
                product?.translations?.name ??
                product?.product_name ??
                product?.name
              }
              imgClassName={`p-2.5 ${isProductAvailabel || storeClosed ? "grayscale" : ""}`}
            />
            {/* Stacked crossfade: active slide opaque, others fade in/out. */}
            <div className="max-md:hidden absolute inset-0">
              {galleryImages.map((img, idx) => (
                <ImageWithPlaceholder
                  key={img + idx}
                  src={img}
                  alt={
                    product?.translations?.name ??
                    product?.product_name ??
                    product?.name
                  }
                  width={400}
                  height={400}
                  className={`absolute inset-0 w-full h-full object-contain p-2.5 transition-opacity duration-500 ease-out ${
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
              alt={
                product?.translations?.name ??
                product?.product_name ??
                product?.name
              }
              width={400}
              height={400}
              className={`w-full h-full object-contain p-2.5 transition duration-200 ${
                isProductAvailabel || storeClosed ? "grayscale" : ""
              }`}
              sizes="(max-width: 640px) 40vw, 200px"
              quality={75}
            />
          )}
        </div>
          {/* Mobile: action hangs off the image's bottom edge (app style). */}
          <div
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
            }}
            className="md:hidden absolute bottom-0 end-1 z-20 w-[72px]"
          >
            {actionNode}
          </div>
        </div>

        {/* vertical divider between image and content — API-themed hairline. */}
        <div
          className="hidden sm:block self-stretch w-px my-1"
          style={{
            background:
              "color-mix(in srgb, var(--primary-color) 14%, transparent)",
          }}
        />

        {/* Content */}
        <div className="flex flex-1 min-w-0 flex-col">
          {/* {product?.category_name && (
            <span className="text-[11px] font-medium text-gray-400 line-clamp-1">
              {product.category_name}
            </span>
          )} */}

          <h3 className="text-sm sm:text-base font-bold capitalize line-clamp-1 textColor group-hover:primaryColor max-md:text-[13px] max-md:font-semibold max-md:line-clamp-2">
            <ProductTypeTag
              type={product?.product_type ?? product?.indicator}
              className="me-1 align-[-2px]"
              iconSize={16}
            />
            {product?.translations?.name ??
              product?.product_name ??
              product?.name}
          </h3>

          {showQuickDelivery && !isProductAvailabel && (
            <span className="mt-0.5 inline-flex w-fit items-center gap-1 rounded-md bg-gray-100 px-1.5 py-0.5 text-[10px] font-semibold text-gray-600 dark:bg-zinc-800 dark:text-zinc-300 max-md:order-last max-md:mt-1 max-md:bg-transparent max-md:px-0 max-md:font-normal max-md:text-[11px] dark:max-md:bg-transparent">
              <TimeIcon size={12} className="primaryColor dark:text-zinc-200" />
              {t("delivery_in")} {deliveryLabel}
            </span>
          )}

          {!!product?.product_rating && Number(product?.rating_count) > 0 && (
            <div className="mt-0.5 flex items-center gap-1 text-xs text-gray-500">
              <div className="flex">
                {[1, 2, 3, 4, 5].map((star) => (
                  <FaStar
                    key={star}
                    size={12}
                    className={
                      star <= Math.round(product?.average_rating || 0)
                        ? "fill-yellow-400 text-yellow-400"
                        : "fill-gray-200 text-gray-200 dark:fill-zinc-600 dark:text-zinc-600"
                    }
                  />
                ))}
              </div>
              <span className="text-gray-400">
                ({Number(product?.average_rating || 0).toFixed(1)})
              </span>
              <span className="line-clamp-1">
                ({product?.rating_count} {t("reviews")})
              </span>
            </div>
          )}

          <FewLeftBadge
            variant={selectedVariant}
            product={product}
            className="mt-0.5"
          />

          {/* Price */}
          <div className="mt-1 flex items-baseline gap-1.5">
            <span className="text-lg font-extrabold tracking-tight textColor">
              {money(
                hasDiscount
                  ? selectedVariant?.discounted_price
                  : selectedVariant?.price,
              )}
            </span>
            {hasDiscount && (
              <span className="text-xs line-through text-gray-400 dark:text-zinc-500">
                {money(selectedVariant?.price)}
              </span>
            )}
          </div>

          {variantLabel && (
            <span className="md:hidden mt-0.5 line-clamp-1 text-[11px] text-gray-500 dark:text-zinc-400">
              {variantLabel}
            </span>
          )}

          {/* Actions — pinned to the bottom (mt-auto) so the ADD row lines up
              across cards regardless of how much text each card has. */}
          <div className="mt-auto pt-2 flex max-md:hidden items-center gap-2">
            {/* like + view inline — mobile/tablet only (desktop uses image overlay) */}
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
              className="relative flex lg:hidden h-10 w-10 shrink-0 items-center justify-center rounded-lg buttonBackground hover:primaryBorder"
            />
            <button
              type="button"
              onClick={handleShowDetailModal}
              aria-label={t("quick_view")}
              className="flex lg:hidden h-10 w-10 shrink-0 items-center justify-center rounded-lg buttonBackground hover:primaryBorder"
            >
              <FaRegEye size={16} className="svgColors hover:primaryColor" />
            </button>
            {actionNode}
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

export default React.memo(ListViewProductCard);
