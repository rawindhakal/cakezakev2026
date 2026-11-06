"use client";

import React from "react";
import { createPortal } from "react-dom";
import Image from "next/image";
import { FaStar } from "react-icons/fa";
import { FiChevronLeft, FiChevronRight, FiChevronUp, FiMinus, FiPlus } from "react-icons/fi";
import { LuPill, LuShare2 } from "react-icons/lu";
import TimeIcon from "../productcards/TimeIcon";
import { t } from "@/utils/translation";
import ShareDrawer from "../productdetail/ShareDrawer";
import ProductDescription from "../productdetail/ProductDescription";
import CancelIcon from "@/assets/icon/cancel.svg";
import NotCancelIcon from "@/assets/icon/Not-cancel.svg";
import ReturnIcon from "@/assets/icon/return.svg";
import NoReturnIcon from "@/assets/icon/no-return.svg";
import CodIcon from "@/assets/icon/cod.svg";
import ThemedSvg from "@/components/notfound/ThemedSvg";
import { sanitizeHtml } from "@/utils/sanitizeHtml";
import StoryImage from "../productstory/StoryImage";
import ProductMedia from "../productdetail/ProductMedia";
import { isVideoUrl } from "@/utils/helperFunction";
import FewLeftBadge from "../productcards/FewLeftBadge";
import PriceFlip from "../productdetail/PriceFlip";
import { SlidingChipGroup } from "../productdetail/SlidingChips";
import PulseHeart from "@/components/ui/pulse-heart/PulseHeart";
import SimilarProducts from "../productslist/SimilarProducts";
import RecentalyViewedProducts from "../productslist/RecentalyViewedProducts";
import ProductTypeTag from "../productdetail/ProductTypeTag";

interface StoryDetailViewProps {
  rtl: boolean;
  product: any;
  productDetails: any;
  selectVariant: any;
  productImages: string[];
  selectedImage: string;
  ratingData: any;
  showQuickDelivery: boolean;
  currency: string;
  hasDiscount: boolean;
  discountLabel: string | null;
  deliveryLabel: string;
  isVariantAvailable: boolean;
  isNotifyRequested: boolean;
  notifyLoading: boolean;
  handleToggleNotify: () => void;
  handleChangeVariant: (variant: any) => void;
  handleSelectAxis: (attrId: any, valId: any) => void;
  selectedAxisValue: (attrId: any) => any;
  isAxisValueAvailable: (attrId: any, valId: any) => boolean;
  getVariantLabel: (variant: any) => string;
  showStepper: boolean;
  stepperQty: number;
  guestMaxQty: number;
  maxQty: number;
  cart: any;
  closedProps: any;
  guardClosed: any;
  handleStepperIncrease: () => void;
  handleStepperDecrease: () => void;
  handleStepperAdd: () => void;
  handleHideDetailModal: () => void;
  liked: boolean;
  canToggleLike: boolean;
  handleProductLikes: () => void;
  handleChangeCoverImage: (img: string) => void;
  storyExpanded: boolean;
  onStoryExpandChange?: (expanded: boolean) => void;
  isShareOpen: boolean;
  setIsShareOpen: (open: boolean) => void;
  featuresOpen: boolean;
  setFeaturesOpen: React.Dispatch<React.SetStateAction<boolean>>;
  returnStatusText: string;
  cancelableText: string;
  storyRootRef: React.RefObject<HTMLDivElement | null>;
  storyScrollRef: React.RefObject<HTMLDivElement | null>;
  onStoryTouchStart: (e: React.TouchEvent) => void;
  onStoryTouchMove: (e: React.TouchEvent) => void;
  onStoryTouchEnd: (e: React.TouchEvent) => void;
  recentlyViewedProducts?: any[];
  shareUrl: string;
}

const StoryDetailView = ({
  rtl,
  product,
  productDetails,
  selectVariant,
  productImages,
  selectedImage,
  ratingData,
  showQuickDelivery,
  currency,
  hasDiscount,
  discountLabel,
  deliveryLabel,
  isVariantAvailable,
  isNotifyRequested,
  notifyLoading,
  handleToggleNotify,
  handleChangeVariant,
  handleSelectAxis,
  selectedAxisValue,
  isAxisValueAvailable,
  getVariantLabel,
  showStepper,
  stepperQty,
  guestMaxQty,
  maxQty,
  cart,
  closedProps,
  guardClosed,
  handleStepperIncrease,
  handleStepperDecrease,
  handleStepperAdd,
  handleHideDetailModal,
  liked,
  canToggleLike,
  handleProductLikes,
  handleChangeCoverImage,
  storyExpanded,
  onStoryExpandChange,
  isShareOpen,
  setIsShareOpen,
  featuresOpen,
  setFeaturesOpen,
  returnStatusText,
  cancelableText,
  storyRootRef,
  storyScrollRef,
  onStoryTouchStart,
  onStoryTouchMove,
  onStoryTouchEnd,
  recentlyViewedProducts = [],
  shareUrl,
}: StoryDetailViewProps) => {
  const d = productDetails?.id ? productDetails : product;
  const ready = !!productDetails?.id;
  const name = d?.translations?.name ?? d?.name;
  const coverImage = selectedImage || product?.image_url;
  const avgRating = Number(ratingData?.average_rating || 0);
  const ratingCount = Number(d?.rating_count || 0);
  const showRating =
    !!product?.product_rating && (avgRating > 0 || ratingCount > 0);
  const keyFeatures = [
    [t("category"), d?.category_name],
    [t("brand"), d?.brand_name],
    [t("sold_by"), d?.branch_name],
    [t("made_in"), d?.made_in?.name],
    [t("manufacturer"), d?.manufacturer],
  ].filter(([, v]) => v);

  const badges = ready
    ? [
        {
          key: "return",
          src: productDetails?.return_status == 1 ? ReturnIcon : NoReturnIcon,
          label: returnStatusText,
        },
        ...(productDetails?.cod_allowed == 1
          ? [{ key: "cod", src: CodIcon, label: t("cash_on_delivery") }]
          : []),
        {
          key: "cancel",
          src:
            productDetails?.cancelable_status == 1
              ? CancelIcon
              : NotCancelIcon,
          label: cancelableText,
        },
      ]
    : [];

  const imageIndex = Math.max(0, productImages.indexOf(selectedImage));
  const stepImage = (dir: 1 | -1) => {
    const n = productImages.length;
    if (n > 1) handleChangeCoverImage(productImages[(imageIndex + dir + n) % n]);
  };
  // A swipe ends in a click on the image button; skip that one tap.
  const swallowTapRef = React.useRef(false);
  const showNextImage = () => {
    if (swallowTapRef.current) {
      swallowTapRef.current = false;
      return;
    }
    stepImage(1);
  };

  // Horizontal swipe over the image switches photos; the parent's gesture
  // handler bails on the x axis, so it only reads vertical drags.
  const swipeRef = React.useRef<{ x: number; y: number; moved: boolean } | null>(
    null,
  );
  const onImageTouchStart = (e: React.TouchEvent) => {
    const t0 = e.touches[0];
    swipeRef.current = { x: t0.clientX, y: t0.clientY, moved: false };
  };
  const onImageTouchMove = (e: React.TouchEvent) => {
    const start = swipeRef.current;
    if (!start) return;
    const dx = e.touches[0].clientX - start.x;
    const dy = e.touches[0].clientY - start.y;
    if (Math.abs(dx) > 10 && Math.abs(dx) > Math.abs(dy)) start.moved = true;
  };
  const onImageTouchEnd = (e: React.TouchEvent) => {
    const start = swipeRef.current;
    swipeRef.current = null;
    if (!start?.moved) return;
    swallowTapRef.current = true;
    // Clear it if the browser suppressed the click, so the next tap works.
    setTimeout(() => {
      swallowTapRef.current = false;
    }, 400);
    const dx = e.changedTouches[0].clientX - start.x;
    if (Math.abs(dx) < 40) return;
    // Swipe left advances in LTR, right advances in RTL.
    stepImage(dx < 0 !== rtl ? 1 : -1);
  };

  const fullDescription = d?.translations?.description ?? d?.description;

  const variantChip = (selected: boolean, available = true, ready = false) =>
    `relative rounded-xl border px-3.5 py-1.5 text-sm font-medium transition ${
      selected
        ? ready
          ? "border-transparent primaryColor"
          : "primaryBorder primaryLightBack primaryColor"
        : available
          ? "border-gray-200 text-gray-700 dark:border-zinc-700 dark:text-zinc-200"
          : "cursor-not-allowed border-gray-200 text-gray-300 line-through opacity-60 dark:border-zinc-800 dark:text-zinc-600"
    }`;

  return (
    <div
      dir={rtl ? "rtl" : "ltr"}
      ref={storyRootRef}
      className={`isolate flex h-full flex-col overflow-hidden bg-white shadow-lg [transform:translateZ(0)] dark:bg-zinc-900 ${
        storyExpanded ? "" : "rounded-3xl"
      }`}
      onTouchStart={onStoryTouchStart}
      onTouchMove={onStoryTouchMove}
      onTouchEnd={onStoryTouchEnd}
      onTouchCancel={onStoryTouchEnd}
    >
      <div
        ref={storyScrollRef}
        className={`min-h-0 flex-1 overflow-y-auto bg-white dark:bg-zinc-900 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden ${
          storyExpanded
            ? "overscroll-contain pt-[env(safe-area-inset-top)]"
            : "overscroll-y-contain"
        }`}
        onScroll={
          !storyExpanded && onStoryExpandChange
            ? (e) => {
                if (e.currentTarget.scrollTop > 40) onStoryExpandChange(true);
              }
            : undefined
        }
      >
        {storyExpanded && (
          <div className="flex justify-center pb-1 pt-2">
            <span className="h-1 w-10 rounded-full bg-gray-300 dark:bg-zinc-600" />
          </div>
        )}
        {/* Image + overlays */}
        <div
          className="relative aspect-square w-full touch-pan-y overflow-hidden bg-gray-100 dark:bg-zinc-800"
          onTouchStart={onImageTouchStart}
          onTouchMove={onImageTouchMove}
          onTouchEnd={onImageTouchEnd}
        >
          {isVideoUrl(coverImage) ? (
            // Tapping a clip works its controls; the arrows still page the strip.
            <ProductMedia
              src={coverImage}
              alt={name || "product"}
              className="h-full w-full object-contain"
            />
          ) : (
            <button
              type="button"
              onClick={showNextImage}
              aria-label={name}
              className="h-full w-full"
            >
              <StoryImage src={coverImage} alt={name || "product"} priority />
            </button>
          )}

          <button
            type="button"
            onClick={() =>
              onStoryExpandChange
                ? onStoryExpandChange(!storyExpanded)
                : handleHideDetailModal()
            }
            aria-label={
              storyExpanded
                ? t("collapse") || "Collapse"
                : t("view_full_details") || "View full details"
            }
            aria-expanded={storyExpanded}
            className="absolute start-3 top-3 z-20 flex h-11 w-11 items-center justify-center rounded-full bg-white/95 text-gray-800 shadow-md active:scale-90 dark:bg-zinc-900/95 dark:text-zinc-100"
          >
            <FiChevronUp
              size={22}
              className={`transition-transform duration-200 ${storyExpanded ? "rotate-180" : ""}`}
            />
          </button>

          <div className="absolute end-3 top-3 z-20 flex gap-2">
            <button
              type="button"
              onClick={() => setIsShareOpen(true)}
              aria-label={t("share") || "Share"}
              className="flex h-11 w-11 items-center justify-center rounded-full bg-white/95 text-gray-800 shadow-md active:scale-90 dark:bg-zinc-900/95 dark:text-zinc-100"
            >
              <LuShare2 size={19} />
            </button>
            <PulseHeart
              liked={!!liked}
              onToggle={handleProductLikes}
              animate={canToggleLike}
              showCount={false}
              size={21}
              corner={999}
              pillColor="transparent"
              likedColor="var(--primary-color)"
              label={t("wishlist") || "Wishlist"}
              className="relative flex h-11 w-11 items-center justify-center rounded-full bg-white/95 shadow-md dark:bg-zinc-900/95"
            />
          </div>

          {/* Key features drawer */}
          {keyFeatures.length > 0 && onStoryExpandChange && (
            <>
              <div
                className={`absolute inset-y-0 start-0 z-10 flex w-1/2 flex-col justify-end gap-3 bg-zinc-900/90 p-4 text-white [transition:transform_300ms_ease,visibility_300ms] ${
                  featuresOpen
                    ? "visible translate-x-0"
                    : rtl
                      ? "invisible translate-x-full"
                      : "invisible -translate-x-full"
                }`}
              >
                <p className="text-sm font-semibold">
                  {t("key_features") || "Key features"}
                </p>
                {keyFeatures.map(([label, value]) => (
                  <div key={label} className="min-w-0">
                    <p className="text-[11px] text-white/60">{label}</p>
                    <p className="line-clamp-2 text-[13px] font-medium">
                      {value}
                    </p>
                  </div>
                ))}
              </div>
              <button
                type="button"
                onClick={() => setFeaturesOpen((v) => !v)}
                aria-label={t("key_features") || "Key features"}
                aria-expanded={featuresOpen}
                className={`absolute top-1/2 z-20 flex h-11 w-7 -translate-y-1/2 items-center justify-center rounded-e-lg bg-zinc-900/85 text-white transition-[inset-inline-start] duration-300 ${
                  featuresOpen ? "start-1/2" : "start-0"
                }`}
              >
                {featuresOpen !== rtl ? (
                  <FiChevronLeft size={18} />
                ) : (
                  <FiChevronRight size={18} />
                )}
              </button>
            </>
          )}

          {productImages.length > 1 && (
            <div className="pointer-events-none absolute inset-x-0 bottom-3 flex justify-center gap-1.5">
              {productImages.map((img, i) => (
                <span
                  key={img}
                  className={`h-1.5 rounded-full transition duration-300 ${
                    i === imageIndex
                      ? "w-4 primaryBackColor"
                      : "w-1.5 bg-black/20"
                  }`}
                />
              ))}
            </div>
          )}
        </div>

        {/* Info */}
        <div className="flex flex-col gap-1.5 px-4 pb-3 pt-3">
          {(showRating || showQuickDelivery) && (
            <div className="flex items-center gap-2 text-xs text-gray-500 dark:text-zinc-400">
              {showRating && (
                <span className="flex items-center gap-1">
                  <span className="flex">
                    {[1, 2, 3, 4, 5].map((star) => (
                      <FaStar
                        key={star}
                        size={12}
                        className={
                          star <= Math.round(avgRating)
                            ? "text-yellow-400"
                            : "text-gray-200 dark:text-zinc-700"
                        }
                      />
                    ))}
                  </span>
                  ({ratingCount})
                </span>
              )}
              {showRating && showQuickDelivery && (
                <span className="h-3 w-px bg-gray-300 dark:bg-zinc-600" />
              )}
              {showQuickDelivery && (
                <span dir="auto" className="flex items-center gap-1">
                  <TimeIcon size={13} className="primaryColor" />
                  {deliveryLabel}
                </span>
              )}
            </div>
          )}
          <h2 className="text-lg font-bold leading-snug textColor">
            <ProductTypeTag
              type={d?.product_type ?? d?.indicator}
              className="me-1.5 align-[-1px]"
              iconSize={14}
            />
            {name}
          </h2>
          {d?.short_description && (
            <p className="line-clamp-3 text-sm leading-5 text-gray-500 dark:text-zinc-400">
              {d.short_description}
            </p>
          )}
          <FewLeftBadge
            variant={selectVariant}
            product={d}
            size={13}
            className="!text-xs !font-bold"
          />
        </div>

        {/* Variants */}
        {ready && productDetails?.variants?.length > 1 && (
          <div className="flex flex-col gap-3 border-t border-gray-100 px-4 py-3 dark:border-zinc-800">
            {Array.isArray(productDetails?.variant_axes) &&
            productDetails.variant_axes.length ? (
              productDetails.variant_axes.map((axis: any) => {
                const sel = selectedAxisValue(axis.attribute_id);
                return (
                  <div key={axis.attribute_id} className="flex flex-col gap-2">
                    <p className="text-sm font-semibold text-gray-600 dark:text-zinc-300">
                      {axis.attribute_name}
                    </p>
                    <SlidingChipGroup
                      activeKey={sel}
                      className="flex flex-wrap gap-2"
                      indicatorClassName="rounded-xl border primaryBorder primaryLightBack"
                    >
                      {(ready) => axis.values?.map((val: any) => {
                        const isSel = sel === val.attribute_value_id;
                        const ok =
                          isSel ||
                          isAxisValueAvailable(
                            axis.attribute_id,
                            val.attribute_value_id,
                          );
                        return (
                          <button
                            key={val.attribute_value_id}
                            type="button"
                            data-chip-active={isSel}
                            disabled={!ok}
                            onClick={() =>
                              handleSelectAxis(
                                axis.attribute_id,
                                val.attribute_value_id,
                              )
                            }
                            className={variantChip(isSel, ok, ready)}
                          >
                            {val.attribute_value}
                          </button>
                        );
                      })}
                    </SlidingChipGroup>
                  </div>
                );
              })
            ) : (
              <div className="flex flex-col gap-2">
                <p className="text-sm font-semibold text-gray-600 dark:text-zinc-300">
                  {t("chooseVariant")}
                </p>
                <SlidingChipGroup
                  activeKey={selectVariant?.id}
                  className="flex flex-wrap gap-2"
                  indicatorClassName="rounded-xl border primaryBorder primaryLightBack"
                >
                  {(ready) =>
                    productDetails.variants.map((variant: any) => (
                      <button
                        key={variant.id}
                        type="button"
                        data-chip-active={selectVariant?.id == variant?.id}
                        onClick={() => handleChangeVariant(variant)}
                        className={`max-w-full break-words text-start ${variantChip(
                          selectVariant?.id == variant?.id,
                          true,
                          ready,
                        )}`}
                      >
                        {getVariantLabel(variant)}
                      </button>
                    ))
                  }
                </SlidingChipGroup>
              </div>
            )}
          </div>
        )}

        {/* Trust badges */}
        {badges.length > 0 && (
          <div
            className={`mx-4 mt-1 grid divide-x rounded-2xl animate-in fade-in duration-300 bg-white p-3 shadow-[0_2px_12px_rgba(0,0,0,0.06)] ring-1 ring-black/5 dark:divide-zinc-700 dark:bg-zinc-800/60 ${
              rtl ? "divide-x-reverse" : ""
            }`}
            style={{
              gridTemplateColumns: `repeat(${badges.length}, minmax(0, 1fr))`,
            }}
          >
            {badges.map((b) => (
              <div
                key={b.key}
                className="flex min-w-0 flex-col items-center gap-2 px-1.5 text-center"
              >
                <span className="flex h-12 w-12 items-center justify-center rounded-xl primaryLightBack">
                  <ThemedSvg src={b.src} alt={b.key} className="h-7 w-7" />
                </span>
                <span className="line-clamp-2 text-xs font-medium leading-tight textColor">
                  {b.label}
                </span>
              </div>
            ))}
          </div>
        )}

        {!ready && (
          <div className="mx-4 mt-1 h-24 rounded-2xl bg-gray-50 dark:bg-zinc-800/50" />
        )}

        {/* Prescription note — medical products only */}
        {Number(productDetails?.product_type) === 5 &&
          productDetails?.prescription_note && (
            <div className="mx-4 mt-3 flex items-start gap-2.5 rounded-xl primaryLightBack px-3 py-2.5">
              <LuPill size={16} className="mt-0.5 shrink-0 primaryColor" />
              <span className="whitespace-pre-line text-xs leading-relaxed textColor">
                {productDetails.prescription_note.replaceAll("**", "")}
              </span>
            </div>
          )}

        {storyExpanded && ready && (
          <>
            {keyFeatures.length > 0 && (
              <div className="mx-4 mt-3 rounded-2xl p-3 ring-1 ring-black/5 dark:ring-white/10">
                <p className="pb-2 text-sm font-bold textColor">
                  {t("product_info") || "Product Info"}
                </p>
                {[
                  ...keyFeatures,
                  ...(productDetails?.tag_names
                    ? [
                        [
                          t("tag"),
                          Array.isArray(productDetails.tag_names)
                            ? productDetails.tag_names.join(", ")
                            : productDetails.tag_names,
                        ],
                      ]
                    : []),
                  ...(productDetails?.fssai_lic_no
                    ? [[t("fssai_license_no"), productDetails.fssai_lic_no]]
                    : []),
                ].map(([label, value]) => (
                  <div key={label} className="flex gap-3 py-1.5 text-xs">
                    <span className="w-2/5 shrink-0 text-gray-500 dark:text-zinc-400">
                      {label}
                    </span>
                    <span className="min-w-0 flex-1 break-words font-medium textColor">
                      {value}
                    </span>
                  </div>
                ))}
              </div>
            )}
            <div className="mx-4 mt-1">
              <ProductDescription
                product={productDetails}
                ratingData={ratingData}
              />
            </div>
          </>
        )}

        {!storyExpanded && fullDescription && (
          <div className="mx-4 mt-3 rounded-2xl p-3 ring-1 ring-black/5 dark:ring-white/10">
            <p className="pb-1 text-sm font-bold textColor">
              {t("product_desc_title") || "Product Description"}
            </p>
            <div
              className="api-html-content text-sm leading-relaxed"
              dangerouslySetInnerHTML={sanitizeHtml(fullDescription)}
            />
          </div>
        )}

        {/* Specifications */}
        {Array.isArray(selectVariant?.custom_sections) &&
          selectVariant.custom_sections.map((section: any) => (
            <div
              key={section?.section_id}
              className="mx-4 mt-3 overflow-hidden rounded-2xl ring-1 ring-black/5 dark:ring-white/10"
            >
              {section?.section_name && (
                <p className="px-3 pb-1 pt-3 text-sm font-bold textColor">
                  {section.section_name}
                </p>
              )}
              {section?.fields?.map((field: any, index: number) => (
                <div
                  key={`${section?.section_id}-${index}`}
                  className="flex gap-3 px-3 py-2 text-xs"
                >
                  <span className="w-2/5 shrink-0 text-gray-500 dark:text-zinc-400">
                    {field?.field_label}
                  </span>
                  <span className="min-w-0 flex-1 break-words font-medium textColor">
                    {field?.value ?? "-"}
                  </span>
                </div>
              ))}
            </div>
          ))}

        {storyExpanded && (
          <div className="mt-2 px-4">
            {d?.id && <SimilarProducts productId={d.id} />}
            <RecentalyViewedProducts
              recentalyViewedProducts={recentlyViewedProducts}
            />
          </div>
        )}

        <div className="h-4" />
      </div>

      {!storyExpanded && onStoryExpandChange && (
        <button
          type="button"
          onClick={() => onStoryExpandChange(true)}
          className="flex items-center justify-center gap-1 border-t border-gray-100 py-1.5 text-[11px] font-medium text-gray-500 dark:border-zinc-800 dark:text-zinc-400"
        >
          <FiChevronUp size={14} className="animate-bounce" />
          {t("swipe_up_for_details") || "Swipe up for details"}
        </button>
      )}

      {/* Sticky price + action */}
      <div className="flex items-center justify-between gap-3 border-t border-gray-100 px-4 py-3 dark:border-zinc-800">
        <div className="min-w-0">
          <PriceFlip flipKey={selectVariant?.id} className="flex items-baseline gap-1.5">
            <span className="text-xl font-extrabold textColor">
              {currency}
              {hasDiscount
                ? selectVariant?.discounted_price
                : selectVariant?.price}
            </span>
            {hasDiscount && (
              <span className="text-sm text-gray-400 line-through dark:text-zinc-500">
                {currency}
                {selectVariant?.price}
              </span>
            )}
          </PriceFlip>
          {discountLabel && (
            <p className="text-sm font-semibold uppercase text-green-600">
              {discountLabel}
            </p>
          )}
        </div>

        {!selectVariant ? (
          <div className="h-12 w-36 rounded-xl bg-gray-100 dark:bg-zinc-800" />
        ) : !isVariantAvailable ? (
          <button
            type="button"
            disabled={notifyLoading}
            onClick={handleToggleNotify}
            className={`flex h-12 w-36 items-center justify-center gap-1.5 rounded-xl border-2 text-base font-bold transition disabled:opacity-60 ${
              isNotifyRequested
                ? "border-gray-200 text-gray-500 dark:border-zinc-700"
                : "primaryBorder primaryColor"
            }`}
          >
            {isNotifyRequested
              ? t("notify_requested") || "Notified"
              : t("notify_me") || "Notify"}
          </button>
        ) : showStepper ? (
          <button
            type="button"
            onClick={handleStepperDecrease}
            {...closedProps}
            className={`flex h-12 items-center justify-center gap-2 rounded-xl primaryBackColor px-5 text-sm font-bold text-white ${closedProps.className ?? ""}`}
          >
            <FiMinus size={18} /> Remove
          </button>
        ) : (
          <button
            type="button"
            onClick={guardClosed(handleStepperAdd)}
            {...closedProps}
            className={`h-12 w-36 rounded-xl border-2 primaryBorder text-base font-bold uppercase primaryColor transition active:scale-95 ${closedProps.className ?? ""}`}
          >
            {t("add") || "Add"}
          </button>
        )}
      </div>

      {/* Share drawer modal portal */}
      {createPortal(
        <ShareDrawer
          open={isShareOpen}
          onClose={() => setIsShareOpen(false)}
          url={shareUrl}
          title={name}
          description={d?.short_description}
          image={coverImage}
        />,
        document.body,
      )}
    </div>
  );
};

export default StoryDetailView;
