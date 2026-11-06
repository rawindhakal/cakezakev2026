"use client";

import React from "react";
import Image from "next/image";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { RiCloseFill } from "react-icons/ri";
import { FaPlay, FaStar, FaStarHalfAlt } from "react-icons/fa";
import { Swiper, SwiperSlide } from "swiper/react";
import "swiper/css";
import "swiper/css/navigation";
import { Navigation } from "swiper/modules";
import { t } from "@/utils/translation";
import { FiMinus, FiPlus } from "react-icons/fi";
import { LuPill } from "react-icons/lu";
import TimeIcon from "../productcards/TimeIcon";
import CancelIcon from "@/assets/icon/cancel.svg";
import NotCancelIcon from "@/assets/icon/Not-cancel.svg";
import ReturnIcon from "@/assets/icon/return.svg";
import NoReturnIcon from "@/assets/icon/no-return.svg";
import CodIcon from "@/assets/icon/cod.svg";
import ThemedSvg from "@/components/notfound/ThemedSvg";
import Loader from "../loader/Loader";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import ProductMedia from "../productdetail/ProductMedia";
import { isVideoUrl } from "@/utils/helperFunction";
import {
  MdAddShoppingCart,
  MdRemoveShoppingCart,
  MdNotificationsActive,
  MdNotificationsNone,
} from "react-icons/md";
import { getProductTypeMeta } from "../productdetail/productType";
import FewLeftBadge from "../productcards/FewLeftBadge";
import PriceFlip from "../productdetail/PriceFlip";
import { SlidingChipGroup } from "../productdetail/SlidingChips";
import PulseHeart from "@/components/ui/pulse-heart/PulseHeart";

interface DialogDetailViewProps {
  showDetailModal: boolean;
  /** Sheet open on top: step back behind it instead of closing. */
  pushedBack?: boolean;
  rtl: boolean;
  loading: boolean;
  product: any;
  productDetails: any;
  selectVariant: any;
  productImages: string[];
  selectedImage: string;
  ratingData: any;
  currency: string;
  hasDiscount: boolean;
  discountLabel: string | null;
  showQuickDelivery: boolean;
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
  handleBuyNow: () => void;
  handleHideDetailModal: () => void;
  liked: boolean;
  canToggleLike: boolean;
  handleProductLikes: () => void;
  handleChangeCoverImage: (img: string) => void;
  returnStatusText: string;
  cancelableText: string;
}

const DialogDetailView = ({
  showDetailModal,
  rtl,
  loading,
  product,
  productDetails,
  selectVariant,
  productImages,
  selectedImage,
  ratingData,
  currency,
  hasDiscount,
  discountLabel,
  showQuickDelivery,
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
  handleBuyNow,
  handleHideDetailModal,
  liked,
  canToggleLike,
  handleProductLikes,
  handleChangeCoverImage,
  returnStatusText,
  cancelableText,
  pushedBack = false,
}: DialogDetailViewProps) => {
  return (
    <Dialog open={showDetailModal}>
      <DialogContent
        dir={rtl ? "rtl" : "ltr"}
        overlayClassName="backdrop-blur-sm"
        className={`custom-scrollbar w-full max-w-xl lg:max-w-[860px] overflow-y-auto max-h-[92dvh] md:max-h-[85vh] rounded-t-2xl md:rounded-2xl !p-0 top-auto bottom-0 translate-y-0 md:top-[50%] md:bottom-auto md:translate-y-[-50%] transition-[transform,opacity,filter] duration-300 ease-out ${
          pushedBack
            ? "pointer-events-none scale-[0.97] opacity-0 md:translate-y-[-50%] md:scale-[0.97]"
            : ""
        }`}
        title={
          productDetails?.translations?.name ??
          productDetails?.name ??
          t("product")
        }
      >
        <button
          type="button"
          className="sticky top-3 z-30 ms-auto me-3 mt-3 -mb-11 closeButtonBg rounded-full p-[6px] gap-[4px] cursor-pointer"
          onClick={handleHideDetailModal}
        >
          <RiCloseFill size={20} />
        </button>
        <div>
          {loading ? (
            <div className="flex items-center justify-center min-h-[60dvh] md:min-h-[420px] w-full">
              <Loader background="transparent" />
            </div>
          ) : (
            <div className="flex flex-col justify-center md:justify-start mx-auto">
              <div className="sticky top-0 z-20 bg-background px-4 py-3.5 md:px-5 border-b rounded-t-2xl md:rounded-t-2xl">
                <h2 className="font-bold text-lg md:text-xl break-words pe-10">
                  {productDetails?.translations?.name ?? productDetails?.name}
                </h2>
                <FewLeftBadge
                  variant={selectVariant}
                  product={productDetails}
                  size={14}
                  className="!text-sm !font-bold"
                />
                <div className="flex items-center gap-1 flex-wrap">
                  {productDetails?.fssai_lic_no && (
                    <div className="flex items-center gap-3">
                      <div className="text-xs">
                        {productDetails?.fssai_lic_img && (
                          <Image
                            width={36}
                            height={36}
                            src={productDetails?.fssai_lic_img}
                            className="object-contain"
                            alt="fssaiImage"
                          />
                        )}
                      </div>
                      <div className="text-xs">
                        {t("fssai_license_no")} {productDetails?.fssai_lic_no}
                      </div>
                    </div>
                  )}
                </div>
              </div>
              <div className="grid grid-cols-1 lg:grid-cols-12 px-4 md:px-5 mt-4 gap-3 lg:gap-6 pb-5 justify-center">
                <div className="lg:col-span-5 col-span-12">
                  <div className="relative aspect-square h-auto w-full max-w-[260px] md:max-w-[320px] lg:max-w-none mx-auto">
                    <ProductMedia
                      src={selectedImage}
                      alt={productDetails?.name || "Product"}
                      className="h-full w-full aspect-square rounded-sm object-contain"
                      width={424}
                      height={424}
                    />

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
                      className="absolute right-2 top-2 z-10 flex h-10 w-10 items-center justify-center rounded-full bg-white dark:bg-zinc-800 shadow-md hover:bg-gray-50 dark:hover:bg-zinc-700"
                    />
                  </div>
                  <div className="mt-[10px]">
                    <Swiper
                      key={String(rtl)}
                      spaceBetween={10}
                      modules={[Navigation]}
                      className="brand-swiper"
                      breakpoints={{
                        1200: { slidesPerView: 6 },
                        1024: { slidesPerView: 5 },
                        768: { slidesPerView: 5 },
                        375: { slidesPerView: 4.5 },
                        0: { slidesPerView: 4 },
                      }}
                    >
                      {productImages?.map((image) => (
                        <SwiperSlide key={image}>
                          <button
                            type="button"
                            onClick={() => handleChangeCoverImage(image)}
                            className={`relative aspect-square w-full overflow-hidden rounded-lg border-2 bg-white dark:bg-zinc-800 ${
                              selectedImage === image
                                ? "primaryBorder"
                                : "border-[#DFE3E8] dark:border-zinc-700"
                            }`}
                          >
                            <ProductMedia
                              thumb
                              src={image}
                              alt={productDetails?.name || "Product"}
                              height={90}
                              width={90}
                              className="h-full w-full object-contain p-1"
                            />
                            {isVideoUrl(image) && (
                              <span className="pointer-events-none absolute inset-0 flex items-center justify-center">
                                <span className="flex h-5 w-5 items-center justify-center rounded-full bg-black/55 text-white">
                                  <FaPlay size={8} className="ms-[1px]" />
                                </span>
                              </span>
                            )}
                          </button>
                        </SwiperSlide>
                      ))}
                    </Swiper>
                  </div>
                </div>
                <div className="col-span-12 lg:col-span-7">
                  <div className="relative flex flex-col gap-2.5">
                    {/* Brand */}
                    {productDetails?.brand_name && (
                      <div className="flex items-center gap-1.5 text-sm">
                        <span className="text-gray-500 dark:text-zinc-400">
                          {t("brand")}
                        </span>
                        <span className="font-semibold primaryColor">
                          {productDetails?.brand_name}
                        </span>
                      </div>
                    )}

                    {/* Rating */}
                    {product?.product_rating &&
                      (ratingData?.average_rating > 0 ||
                        productDetails?.rating_count > 0) && (
                        <div className="flex items-center gap-2 text-sm text-gray-500 dark:text-zinc-400">
                          <div className="flex">
                            {[1, 2, 3, 4, 5].map((star) => {
                              const roundedRating =
                                Math.round(
                                  (ratingData?.average_rating || 0) * 2,
                                ) / 2;
                              if (star <= Math.floor(roundedRating)) {
                                return (
                                  <FaStar
                                    key={star}
                                    size={16}
                                    className="fill-yellow-400 text-yellow-400"
                                  />
                                );
                              } else if (
                                star === Math.floor(roundedRating) + 1 &&
                                roundedRating % 1 === 0.5
                              ) {
                                return (
                                  <FaStarHalfAlt
                                    key={star}
                                    size={16}
                                    className="fill-yellow-400 text-yellow-400"
                                  />
                                );
                              }
                              return (
                                <FaStar
                                  key={star}
                                  size={16}
                                  className="fill-gray-200 text-gray-200"
                                />
                              );
                            })}
                          </div>
                          <span className="font-bold text-gray-900 dark:text-zinc-100">
                            {(ratingData?.average_rating || 0).toFixed(0)}
                            <span className="font-normal text-gray-400 dark:text-zinc-500">
                              /5.0
                            </span>
                          </span>
                          <span className="text-gray-500 dark:text-zinc-400">
                            ({productDetails?.rating_count || 0} {t("reviews")})
                          </span>
                        </div>
                      )}

                    {/* Price + delivery pill */}
                    <div className="flex flex-wrap items-center justify-between gap-3">
                      <PriceFlip
                        flipKey={selectVariant?.id}
                        className="flex items-baseline gap-3"
                      >
                        <span className="text-2xl font-extrabold tracking-tight text-gray-900 dark:text-zinc-100">
                          {currency}
                          {hasDiscount
                            ? selectVariant?.discounted_price
                            : selectVariant?.price}
                        </span>
                        {hasDiscount && (
                          <span className="text-base font-medium text-gray-400 dark:text-zinc-500 line-through">
                            {currency}
                            {selectVariant?.price}
                          </span>
                        )}
                        {discountLabel && (
                          <span className="rounded-md bg-green-100 px-2 py-1 text-xs font-bold uppercase text-green-700">
                            {discountLabel}
                          </span>
                        )}
                      </PriceFlip>

                      {showQuickDelivery && (
                        <div className="inline-flex w-fit items-center gap-2 rounded-full primaryLightBack py-1.5 ps-2 pe-3.5 text-sm">
                          <span className="flex h-7 w-7 items-center justify-center rounded-full bg-white dark:bg-zinc-900 shadow-sm">
                            <TimeIcon size={16} className="primaryColor" />
                          </span>
                          <span dir="auto" className="font-bold primaryColor">
                            {deliveryLabel}
                          </span>
                        </div>
                      )}
                    </div>

                    <FewLeftBadge
                      variant={selectVariant}
                      product={productDetails}
                      size={14}
                      className="!text-sm !font-bold"
                    />

                    {/* Short description */}
                    {productDetails?.short_description && (
                      <p className="line-clamp-3 text-sm font-normal leading-5 text-gray-600 dark:text-zinc-300">
                        {productDetails?.short_description}
                      </p>
                    )}

                    {/* Variant selector */}
                    {productDetails?.variants?.length > 1 &&
                      (Array.isArray(productDetails?.variant_axes) &&
                      productDetails.variant_axes.length ? (
                        <div className="flex flex-wrap gap-x-6 gap-y-3">
                          {productDetails.variant_axes.map((axis: any) => {
                            const sel = selectedAxisValue(axis.attribute_id);
                            return (
                              <div
                                key={axis.attribute_id}
                                className="flex min-w-[120px] flex-col gap-1.5"
                              >
                                <p className="text-sm font-semibold text-gray-700 dark:text-zinc-200">
                                  {axis.attribute_name}
                                </p>
                                <SlidingChipGroup
                                  activeKey={sel}
                                  className="flex flex-wrap gap-2"
                                  indicatorClassName="rounded-lg border primaryBorder primaryLightBack dark:bg-white/10 dark:border-white"
                                >
                                  {(ready) => axis.values?.map((val: any) => {
                                    const isSel =
                                      sel === val.attribute_value_id;
                                    const isAvailable =
                                      isSel ||
                                      isAxisValueAvailable(
                                        axis.attribute_id,
                                        val.attribute_value_id,
                                      );
                                    const unavailableVariantButtonClass =
                                      !isAvailable
                                        ? "cursor-not-allowed border-gray-200 dark:border-zinc-800 text-gray-300 dark:text-zinc-600 line-through opacity-60"
                                        : "border-gray-200 dark:border-zinc-700 text-gray-700 dark:text-zinc-200 hover:border-gray-400";
                                    const variantButtonClass = isSel
                                      ? ready
                                        ? "border-transparent primaryColor dark:text-white"
                                        : "primaryBorder primaryLightBack primaryColor dark:bg-white/10 dark:text-white dark:border-white"
                                      : unavailableVariantButtonClass;
                                    return (
                                      <button
                                        key={val.attribute_value_id}
                                        type="button"
                                        data-chip-active={isSel}
                                        disabled={!isAvailable}
                                        title={
                                          isAvailable
                                            ? undefined
                                            : t("variantNotAvailable")
                                        }
                                        onClick={() =>
                                          handleSelectAxis(
                                            axis.attribute_id,
                                            val.attribute_value_id,
                                          )
                                        }
                                        className={`relative flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-[13px] font-medium transition ${variantButtonClass}`}
                                      >
                                        {val.attribute_value}
                                      </button>
                                    );
                                  })}
                                </SlidingChipGroup>
                              </div>
                            );
                          })}
                        </div>
                      ) : (
                        <div className="flex flex-col gap-3">
                          <p className="text-base font-medium">
                            {t("chooseVariant")} :{" "}
                            <span className="font-semibold">
                              {getVariantLabel(selectVariant)}
                            </span>
                          </p>
                          <SlidingChipGroup
                            activeKey={selectVariant?.id}
                            className="flex flex-wrap gap-3"
                            indicatorClassName="rounded-2xl border primaryBorder primaryBackColor"
                          >
                            {(ready) =>
                              productDetails?.variants?.map((variant: any) => (
                                <button
                                  key={variant.id}
                                  type="button"
                                  data-chip-active={selectVariant?.id == variant?.id}
                                  onClick={() => handleChangeVariant(variant)}
                                  title={getVariantLabel(variant)}
                                  className={`relative max-w-full whitespace-normal break-words text-start rounded-2xl border px-5 py-2 text-sm font-medium transition duration-300 ${
                                    selectVariant?.id == variant?.id
                                      ? ready
                                        ? "border-transparent text-white"
                                        : "primaryBorder primaryBackColor text-white"
                                      : "border-[#DFE3E8] dark:border-zinc-700 text-gray-700 dark:text-zinc-200 hover:primaryBorder"
                                  }`}
                                >
                                  {getVariantLabel(variant)}
                                </button>
                              ))
                            }
                          </SlidingChipGroup>
                        </div>
                      ))}

                    <hr className="border-gray-200 dark:border-zinc-700 my-0.5" />

                    {/* Cart actions and stepper */}
                    <div className="flex flex-col gap-2">
                      {isVariantAvailable ? (
                        <div className="flex flex-wrap items-stretch gap-2.5">
                          {showStepper ? (
                            <button
                              type="button"
                              onClick={handleStepperDecrease}
                              {...closedProps}
                              className={`flex h-11 flex-1 sm:flex-none sm:w-[160px] items-center justify-center gap-2 rounded-lg primaryBackColor px-4 text-sm font-bold text-white shadow-sm ${closedProps.className ?? ""}`}
                            >
                              <FiMinus /> Remove from cart
                            </button>
                          ) : (
                            <button
                              type="button"
                              onClick={guardClosed(handleStepperAdd)}
                              {...closedProps}
                              className={`group flex h-11 flex-1 sm:flex-none sm:w-[160px] items-center justify-center gap-2 whitespace-nowrap rounded-lg border-2 primaryBorder primaryColor dark:text-white dark:border-white/40 px-4 text-sm font-bold transition hover:primaryBackColor hover:text-white hover:border-transparent active:scale-95 ${closedProps.className ?? ""}`}
                            >
                              <MdAddShoppingCart
                                size={18}
                                className="transition-transform group-hover:scale-110"
                              />
                              {t("add_to_cart")}
                            </button>
                          )}
                          <button
                            type="button"
                            onClick={guardClosed(handleBuyNow)}
                            {...closedProps}
                            className={`flex h-11 flex-1 sm:flex-none sm:w-[140px] items-center justify-center whitespace-nowrap rounded-lg primaryBackColor px-4 text-sm font-bold text-white shadow-sm transition hover:opacity-90 active:scale-95 ${closedProps.className ?? ""}`}
                          >
                            {t("buy_now")}
                          </button>
                        </div>
                      ) : (
                        <div className="flex flex-wrap items-center gap-2.5">
                          <output className="inline-flex h-9 w-fit items-center gap-1.5 rounded-full border border-red-200 bg-red-50 dark:border-red-500/40 dark:bg-red-500/10 px-3 text-xs font-bold text-red-600 dark:text-red-400">
                            <MdRemoveShoppingCart
                              size={14}
                              className="shrink-0"
                            />
                            {t("out_of_stock")}
                          </output>
                          <button
                            type="button"
                            disabled={notifyLoading}
                            onClick={handleToggleNotify}
                            className={`inline-flex h-9 items-center justify-center gap-1.5 whitespace-nowrap rounded-full border px-3.5 text-xs font-bold transition disabled:opacity-60 ${
                              isNotifyRequested
                                ? "primaryBorder primaryColor bg-transparent"
                                : "primaryBorder primaryBackColor text-white hover:opacity-90"
                            }`}
                          >
                            {isNotifyRequested ? (
                              <MdNotificationsActive
                                size={14}
                                className="shrink-0"
                              />
                            ) : (
                              <MdNotificationsNone
                                size={14}
                                className="shrink-0"
                              />
                            )}
                            {isNotifyRequested
                              ? t("notify_requested") || "Notified"
                              : t("notify_me") || "Notify Me"}
                          </button>
                        </div>
                      )}
                    </div>

                    {/* Trust badges */}
                    <div
                      className={`flex items-stretch divide-x divide-gray-200 dark:divide-zinc-700 rounded-xl border border-gray-200 dark:border-zinc-700 py-2.5 ${rtl ? "divide-x-reverse" : ""}`}
                    >
                      {(() => {
                        const typeMeta = getProductTypeMeta(
                          productDetails?.product_type ??
                            productDetails?.indicator,
                        );
                        if (!typeMeta) return null;
                        const { svg, Icon, labelKey, color } = typeMeta as any;
                        return (
                          <div className="flex flex-1 flex-col items-center justify-center gap-1.5 px-2 text-center">
                            {svg ? (
                              <span className="relative h-8 w-8">
                                <Image
                                  src={svg}
                                  fill
                                  alt={t(labelKey)}
                                  className="object-contain"
                                />
                              </span>
                            ) : (
                              <Icon className={`h-7 w-7 ${color}`} />
                            )}
                            <span className="text-[11px] font-semibold leading-tight text-gray-700 dark:text-zinc-200">
                              {t(labelKey)}
                            </span>
                          </div>
                        );
                      })()}

                      <div className="flex flex-1 flex-col items-center justify-center gap-1.5 px-2 text-center">
                        <ThemedSvg
                          src={
                            productDetails?.cancelable_status == 1
                              ? CancelIcon
                              : NotCancelIcon
                          }
                          alt="cancelable"
                          className="h-8 w-8"
                        />
                        <span className="text-[11px] font-semibold leading-tight text-gray-700 dark:text-zinc-200">
                          {cancelableText}
                        </span>
                      </div>

                      <div className="flex flex-1 flex-col items-center justify-center gap-1.5 px-2 text-center">
                        <ThemedSvg
                          src={
                            productDetails?.return_status == 1
                              ? ReturnIcon
                              : NoReturnIcon
                          }
                          alt="returnable"
                          className="h-8 w-8"
                        />
                        <span className="text-[11px] font-semibold leading-tight text-gray-700 dark:text-zinc-200">
                          {returnStatusText}
                        </span>
                      </div>

                      {productDetails?.cod_allowed == 1 && (
                        <div className="flex flex-1 flex-col items-center justify-center gap-1.5 px-2 text-center">
                          <ThemedSvg
                            src={CodIcon}
                            alt="cash on delivery"
                            className="h-8 w-8"
                          />
                          <span className="text-[11px] font-semibold leading-tight text-gray-700 dark:text-zinc-200">
                            {t("cash_on_delivery")}
                          </span>
                        </div>
                      )}
                    </div>

                    {/* Prescription note */}
                    {Number(productDetails?.product_type) === 5 &&
                      productDetails?.prescription_note && (
                        <div className="flex items-start gap-3 rounded-r-lg primaryColorBorder border-0 border-l-4 primaryLightBack px-4 py-3">
                          <LuPill
                            size={18}
                            className="mt-0.5 shrink-0 primaryColor"
                          />
                          <div className="flex flex-col gap-1">
                            <span className="text-xs font-bold uppercase tracking-wide primaryColor">
                              {t("prescription_required") ||
                                "Prescription Required"}
                            </span>
                            <span className="text-sm leading-relaxed text-gray-700 dark:text-zinc-200 whitespace-pre-line">
                              {productDetails?.prescription_note?.replaceAll(
                                "**",
                                "",
                              )}
                            </span>
                          </div>
                        </div>
                      )}

                    {/* Meta */}
                    <div className="flex flex-col gap-2 text-sm">
                      {productDetails?.category_name && (
                        <div className="flex gap-2">
                          <span className="shrink-0 whitespace-nowrap font-semibold">
                            {t("category")} :
                          </span>
                          <span className="text-gray-600 dark:text-zinc-300">
                            {productDetails?.category_name}
                          </span>
                        </div>
                      )}
                      {productDetails?.tag_names && (
                        <div className="flex gap-2">
                          <span className="shrink-0 whitespace-nowrap font-semibold">
                            {t("tag")} :
                          </span>
                          <span className="text-gray-600 dark:text-zinc-300">
                            {Array.isArray(productDetails?.tag_names)
                              ? productDetails.tag_names.join(", ")
                              : productDetails?.tag_names}
                          </span>
                        </div>
                      )}
                      {productDetails?.made_in?.name && (
                        <div className="flex gap-2">
                          <span className="shrink-0 whitespace-nowrap font-semibold">
                            {t("made_in")} :
                          </span>
                          <span className="text-gray-600 dark:text-zinc-300">
                            {productDetails?.made_in?.name}
                          </span>
                        </div>
                      )}
                      {productDetails?.branch_name && (
                        <div className="flex gap-2">
                          <span className="shrink-0 whitespace-nowrap font-semibold">
                            {t("sold_by")} :
                          </span>
                          <span className="text-gray-600 dark:text-zinc-300">
                            {productDetails?.branch_name}
                          </span>
                        </div>
                      )}
                      {productDetails?.manufacturer && (
                        <div className="flex gap-2">
                          <span className="shrink-0 whitespace-nowrap font-semibold">
                            {t("manufacturer")} :
                          </span>
                          <span className="text-gray-600 dark:text-zinc-300">
                            {productDetails?.manufacturer}
                          </span>
                        </div>
                      )}
                      {productDetails?.fssai_lic_no && (
                        <div className="flex items-center gap-2">
                          <span className="shrink-0 whitespace-nowrap font-semibold">
                            {t("fssai_license_no")}
                          </span>
                          {productDetails?.fssai_lic_img && (
                            <Image
                              width={100}
                              height={100}
                              src={productDetails?.fssai_lic_img}
                              className="w-9 h-9 object-contain"
                              alt="fssaiImage"
                            />
                          )}
                          <span className="text-gray-600 dark:text-zinc-300">
                            {productDetails?.fssai_lic_no}
                          </span>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default DialogDetailView;
