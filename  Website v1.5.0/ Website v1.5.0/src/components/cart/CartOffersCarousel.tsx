"use client";

import React, { useCallback, useEffect, useMemo, useState } from "react";
import Image from "next/image";
import { useDispatch, useSelector } from "react-redux";
import { toast } from "react-toastify";
import useEmblaCarousel from "embla-carousel-react";
import Autoplay from "embla-carousel-autoplay";
import {
  FiCheck,
  FiChevronLeft,
  FiChevronRight,
  FiGift,
  FiTag,
} from "react-icons/fi";
import { RiCoupon3Line, RiWallet3Line } from "react-icons/ri";
import * as api from "@/api/apiRoutes";
import { t } from "@/utils/translation";
import { setCartPromo, clearCartPromo } from "@/redux/slices/cartSlice";
import useDir from "@/hooks/useDir";

interface CartOffersCarouselProps {
  /** Opens the coupon drawer — header nudge + slide body lead into it. */
  onOpenCoupons: () => void;
}

// Myntra-style "Offers (N)" strip: 1 promo card per view, auto-swaps every
// 3.5s, swipe or side arrows + dots. Hidden when no code applies.
const CartOffersCarousel = ({ onOpenCoupons }: CartOffersCarouselProps) => {
  const dir = useDir();
  const cartSubTotal = useSelector((state: any) => state.Cart?.cartSubTotal);
  const city = useSelector((state: any) => state.City?.city);
  const appliedCode = useSelector(
    (state: any) => state.Cart?.promo_code?.promo_code,
  );
  const isLoggedIn = useSelector((state: any) => !!state.User?.jwtToken);
  const dispatch = useDispatch();
  // promo_code currently being validated — disables its button, shows "...".
  const [applyingCode, setApplyingCode] = useState<string | null>(null);
  // /promo rows — untyped API payload, kept `any[]`.
  const [offers, setOffers] = useState<any[]>([]);
  const [selected, setSelected] = useState(0);
  const [snapCount, setSnapCount] = useState(0);
  const [canPrev, setCanPrev] = useState(false);
  const [canNext, setCanNext] = useState(false);

  const multiple = offers.length > 1;

  // Stable options/plugins — a fresh object each render makes embla-react
  // reinit and resets the autoplay timer. 1 card per view, so loop is safe:
  // autoplay wraps last → first instead of stalling at the end.
  const emblaOptions = useMemo(
    () => ({
      loop: multiple,
      align: "start" as const,
      direction: (dir === "RTL" ? "rtl" : "ltr") as "rtl" | "ltr",
      watchDrag: multiple,
    }),
    [multiple, dir],
  );
  // Pauses on hover so a user reading/aiming at Apply isn't yanked away;
  // resumes after a swipe/arrow click instead of stopping for good.
  const plugins = useMemo(
    () =>
      multiple
        ? [
            Autoplay({
              delay: 3500,
              stopOnInteraction: false,
              stopOnMouseEnter: true,
            }),
          ]
        : [],
    [multiple],
  );
  const [emblaRef, emblaApi] = useEmblaCarousel(emblaOptions, plugins);

  // Applicability depends on the cart total — refetch when it settles
  // (debounced so qty-stepper bursts fire one /promo call, not one per click).
  useEffect(() => {
    let alive = true;
    const timer = setTimeout(() => {
      api
        .getPromo({
          amount: cartSubTotal,
          latitude: city?.latitude,
          longitude: city?.longitude,
        })
        .then((res) => {
          // Applicable only — locked ones (min order unmet) stay in the drawer.
          if (alive && res?.status == 1)
            setOffers(
              (res?.data || []).filter((c: any) => c?.is_applicable != 0),
            );
        })
        .catch((error) => console.log("Error", error));
    }, 600);
    return () => {
      alive = false;
      clearTimeout(timer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cartSubTotal]);

  const onSelect = useCallback(() => {
    if (!emblaApi) return;
    setSelected(emblaApi.selectedScrollSnap());
    setSnapCount(emblaApi.scrollSnapList().length);
    setCanPrev(emblaApi.canScrollPrev());
    setCanNext(emblaApi.canScrollNext());
  }, [emblaApi]);

  useEffect(() => {
    if (!emblaApi) return;
    // Initial snap/arrow state — embla's own "init" fired before we subscribed.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    onSelect();
    emblaApi.on("select", onSelect).on("reInit", onSelect);
    return () => {
      emblaApi.off("select", onSelect).off("reInit", onSelect);
    };
  }, [emblaApi, onSelect]);

  // Direct apply from the slide — same /promo/validate flow as CouponCodeCard.
  // Tapping an already-applied code removes it.
  const handleApply = async (code: string) => {
    if (!code || applyingCode) return;
    if (!isLoggedIn) {
      toast.error(t("login_continue") || "Login To Continue");
      return;
    }
    if (appliedCode == code) {
      dispatch(clearCartPromo());
      return;
    }
    setApplyingCode(code);
    try {
      const response = await api.setPromoCode({
        promoCodeName: code,
        amount: cartSubTotal,
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      if (response.status == 1) {
        dispatch(setCartPromo({ data: response.data }));
        toast.success(response.message);
      } else {
        toast.error(response.message);
      }
    } catch (error) {
      console.log("Error", error);
      toast.error(t("something_went_wrong"));
    } finally {
      setApplyingCode(null);
    }
  };

  if (!offers.length) return null;

  const scrollable = snapCount > 1;
  const arrowCls =
    "hidden md:flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-white dark:bg-zinc-800 textColor shadow-[0_1px_4px_rgba(0,0,0,0.12)] transition hover:scale-105 disabled:opacity-40 disabled:hover:scale-100 disabled:cursor-not-allowed";
  const tint = (pct: number) =>
    `color-mix(in srgb, var(--primary-color) ${pct}%, transparent)`;

  return (
    <div>
      <div
        className="rounded-xl px-2 pt-2.5 pb-3 sm:px-3"
        style={{ backgroundColor: tint(7) }}
      >
        {/* header: tag badge + "Offers (N)" | gift nudge → drawer */}
        <div className="flex items-center justify-between gap-2 px-1 mb-2.5">
          <div className="flex items-center gap-2.5 min-w-0">
            <span
              className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-white shadow-sm"
              style={{ backgroundColor: "var(--primary-color)" }}
            >
              <FiTag size={15} className="rtl:-scale-x-100" />
            </span>
            <span className="text-base sm:text-lg font-bold primaryColor dark:text-white truncate">
              {t("offers") || "Offers"} ({offers.length})
            </span>
          </div>
          <button
            type="button"
            onClick={onOpenCoupons}
            className="flex items-center gap-1.5 shrink-0 text-xs sm:text-sm font-medium primaryColor dark:text-white hover:opacity-80 transition"
          >
            <FiGift size={15} />
            <span className="hidden sm:inline">
              {t("save_more_with_exciting_offers") ||
                "Save more with exciting offers!"}
            </span>
            <FiChevronRight size={18} className="rtl:-scale-x-100" />
          </button>
        </div>

        <div className="flex items-center gap-2 sm:gap-3">
          {scrollable && (
            <button
              type="button"
              onClick={() => emblaApi?.scrollPrev()}
              disabled={!canPrev}
              aria-label={t("previous") || "Previous"}
              className={arrowCls}
            >
              <FiChevronLeft size={16} className="rtl:-scale-x-100" />
            </button>
          )}

          <div className="overflow-hidden flex-1 min-w-0" ref={emblaRef}>
            <div className="flex -ms-2">
              {offers.map((offer) => {
                const isCashback = offer?.discount_apply_type === "wallet";
                const isApplied = appliedCode == offer?.promo_code;
                const isApplying = applyingCode == offer?.promo_code;
                const description =
                  offer?.description || offer?.translations?.message;
                return (
                  <div
                    key={offer?.id}
                    className="basis-full shrink-0 min-w-0 ps-2"
                  >
                    <div className="h-full w-full flex items-center gap-2.5 md:gap-3 rounded-lg bg-white dark:bg-zinc-800 px-2.5 py-2 md:px-3 md:py-2.5 shadow-[0_1px_3px_rgba(0,0,0,0.05)] transition hover:shadow-[0_2px_8px_rgba(0,0,0,0.08)]">
                      {/* body → drawer for full terms */}
                      <button
                        type="button"
                        onClick={onOpenCoupons}
                        className="flex items-center gap-2.5 md:gap-3 min-w-0 flex-1 text-start"
                      >
                        <span className="relative flex h-10 w-10 md:h-12 md:w-12 shrink-0 items-center justify-center overflow-hidden rounded-md bg-black/[0.03] dark:bg-white/[0.06]">
                          {offer?.image_url ? (
                            <Image
                              src={offer.image_url}
                              alt={offer?.promo_code || "offer"}
                              fill
                              sizes="(max-width: 768px) 40px, 48px"
                              className="object-cover"
                            />
                          ) : isCashback ? (
                            <RiWallet3Line size={22} className="primaryColor" />
                          ) : (
                            <RiCoupon3Line size={22} className="primaryColor" />
                          )}
                        </span>
                        <span className="flex flex-col min-w-0 flex-1">
                          <span className="text-sm font-bold textColor truncate leading-tight">
                            {offer?.title || offer?.promo_code}
                          </span>
                          {description && (
                            <span className="mt-0.5 text-xs SecondaryTextColor truncate">
                              {description}
                            </span>
                          )}
                          {offer?.promo_code && (
                            <span
                              className="mt-1.5 w-fit max-w-full truncate rounded-md border border-dashed px-2 py-0.5 text-xs font-bold uppercase tracking-wide primaryColor dark:text-white"
                              style={{
                                borderColor: tint(55),
                                backgroundColor: tint(6),
                              }}
                            >
                              {offer.promo_code}
                            </span>
                          )}
                        </span>
                      </button>

                      {offer?.promo_code &&
                        (isApplied ? (
                          <button
                            type="button"
                            onClick={() => handleApply(offer.promo_code)}
                            title={t("remove") || "Remove"}
                            className="flex shrink-0 items-center justify-center gap-1 rounded-lg border px-2.5 py-1.5 text-[11px] md:px-3 md:py-2 md:text-sm font-bold primaryColor dark:text-white transition hover:opacity-80"
                            style={{
                              borderColor: tint(40),
                              backgroundColor: tint(10),
                            }}
                          >
                            <FiCheck size={15} />
                            {t("applied") || "Applied"}
                          </button>
                        ) : (
                          <button
                            type="button"
                            onClick={() => handleApply(offer.promo_code)}
                            disabled={!!applyingCode}
                            className="shrink-0 whitespace-nowrap rounded-lg border primaryBorderColor primaryLightBack primaryColor px-2.5 py-1.5 text-[11px] font-bold transition active:scale-95 disabled:opacity-60 disabled:cursor-not-allowed md:min-w-[112px] md:border-0 md:bg-[var(--primary-color)] md:px-4 md:py-2 md:text-sm md:text-white md:shadow-sm md:hover:brightness-110"
                          >
                            {isApplying ? (
                              "..."
                            ) : (
                              <>
                                <span className="md:hidden">
                                  {t("apply") || "Apply"}
                                </span>
                                <span className="hidden md:inline">
                                  {t("apply_coupon") || "Apply Coupon"}
                                </span>
                              </>
                            )}
                          </button>
                        ))}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {scrollable && (
            <button
              type="button"
              onClick={() => emblaApi?.scrollNext()}
              disabled={!canNext}
              aria-label={t("next") || "Next"}
              className={arrowCls}
            >
              <FiChevronRight size={16} className="rtl:-scale-x-100" />
            </button>
          )}
        </div>
      </div>

      {scrollable && (
        <div className="flex justify-center items-center gap-2 mt-3">
          {Array.from({ length: snapCount }).map((_, i) => (
            <button
              key={i}
              type="button"
              onClick={() => emblaApi?.scrollTo(i)}
              aria-label={`${i + 1}`}
              className={`h-2 w-2 rounded-full transition-colors ${
                i === selected ? "" : "bg-gray-300 dark:bg-zinc-600"
              }`}
              style={
                i === selected
                  ? { backgroundColor: "var(--primary-color)" }
                  : undefined
              }
            />
          ))}
        </div>
      )}
    </div>
  );
};

export default CartOffersCarousel;
