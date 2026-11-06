import { useEffect, useRef, useState } from "react";
import { useSelector } from "react-redux";
import { RiDiscountPercentFill } from "react-icons/ri";
import { FiPlus, FiChevronDown } from "react-icons/fi";
import { t } from "@/utils/translation";

interface UnlockCouponNudgeProps {
  code?: string;
  /** What the user must do to unlock. */
  message?: string;
  /** e.g. "Get 10% off" */
  benefit?: string;
  /** Renders "Shop more". */
  onAction?: () => void;
  /** Renders the "View all coupons" footer. */
  onViewAll?: () => void;
  className?: string;
  /** false = no outer border/tint, for nesting inside a caller's own card. */
  bordered?: boolean;
}

// Coupon unlock nudge + "View all coupons" footer.
const UnlockCouponNudge = ({
  code,
  message,
  benefit,
  onAction,
  onViewAll,
  className = "",
  bordered = true,
}: UnlockCouponNudgeProps) => {
  const subTotal = Number(useSelector((state: any) => state.Cart?.cartSubTotal) || 0);
  // Code the cart just crossed the minimum for (server stops nudging it).
  const [unlocked, setUnlocked] = useState<string | null>(null);
  const prevRef = useRef<{ code?: string; subTotal: number }>({ code, subTotal });

  useEffect(() => {
    const prev = prevRef.current;
    prevRef.current = { code, subTotal };
    if (!prev.code || prev.code === code || subTotal <= prev.subTotal) return;
    setUnlocked(prev.code);
    const timer = setTimeout(() => setUnlocked(null), 5000);
    return () => clearTimeout(timer);
  }, [code, subTotal]);

  const hasNudge = Boolean(message || code);
  if (!hasNudge && !onViewAll && !unlocked) return null;

  return (
    <div
      className={`${bordered ? "overflow-hidden rounded-lg border border-[color-mix(in_srgb,var(--primary-color)_15%,transparent)]" : ""} ${className}`}
      style={
        bordered
          ? {
              // Fades to --category-card-bg (not #fff) for dark mode.
              backgroundImage:
                "linear-gradient(to bottom, color-mix(in srgb, var(--primary-color) 6%, var(--category-card-bg)), var(--category-card-bg))",
            }
          : // Caller's card already paints the tint.
            undefined
      }
    >
      {unlocked && (
        <div className="couponUnlockIn relative flex items-center gap-2.5 overflow-hidden border-b border-green-200 bg-green-50 px-4 py-3 dark:border-green-900/50 dark:bg-green-950/40">
          <span aria-hidden="true" className="couponUnlockShine pointer-events-none absolute inset-y-0 w-1/3" />
          <span className="couponUnlockShake flex shrink-0 items-center justify-center text-green-600 dark:text-green-400">
            <RiDiscountPercentFill size={24} />
          </span>
          <div className="min-w-0 flex-grow">
            <p className="text-sm font-extrabold text-green-700 dark:text-green-400">
              <span className="uppercase tracking-wide">{unlocked}</span>{" "}
              {t("coupon_unlocked") || "unlocked!"} 🎉
            </p>
            <p className="text-xs text-green-700/80 dark:text-green-400/80">
              {t("apply_to_save_more") || "Apply it now to save more"}
            </p>
          </div>
          {onViewAll && (
            <button
              type="button"
              onClick={onViewAll}
              className="relative shrink-0 rounded-lg bg-green-600 px-3 py-1.5 text-xs font-bold text-white transition active:scale-95"
            >
              {t("apply") || "Apply"}
            </button>
          )}
        </div>
      )}

      {hasNudge && !unlocked && (
        // Stacks below md: side by side, the message wraps one word per line
        // between the icon and the button.
        <div className="flex flex-col gap-2.5 px-4 py-3.5 md:flex-row md:items-center">
          <div className="flex min-w-0 flex-grow items-center gap-2.5">
            <span className="flex shrink-0 items-center justify-center primaryColor">
              <RiDiscountPercentFill size={24} />
            </span>

            <div className="min-w-0 flex-grow">
              <div className="flex flex-wrap items-baseline gap-x-2 gap-y-0.5">
                {code && (
                  <span className="text-sm font-extrabold uppercase tracking-wide textColor">
                    {code}
                  </span>
                )}
                {benefit && (
                  <span className="text-sm font-bold text-green-600 dark:text-green-400">
                    {benefit}
                  </span>
                )}
              </div>

              {message && (
                <p className="mt-1 text-[13px] leading-snug SecondaryTextColor">
                  {message}
                </p>
              )}
            </div>
          </div>

          {onAction && (
            <button
              type="button"
              onClick={onAction}
              className="flex w-full shrink-0 items-center justify-center gap-1 rounded-lg border border-[color-mix(in_srgb,var(--primary-color)_25%,transparent)] bg-[var(--category-card-bg)] px-3 py-1.5 text-[13px] font-semibold textColor shadow-sm transition hover:primaryBackColor hover:text-white hover:border-transparent active:scale-95 md:ms-auto md:w-auto"
            >
              <FiPlus size={14} />
              {t("shop_more") || "Shop more"}
            </button>
          )}
        </div>
      )}

      {onViewAll && (
        <button
          type="button"
          onClick={onViewAll}
          className={`flex w-full items-center justify-between px-4 py-3 text-sm font-semibold textColor ${
            hasNudge
              ? "border-t border-[color-mix(in_srgb,var(--primary-color)_15%,transparent)]"
              : ""
          }`}
        >
          {t("view_all_coupons") || "View all coupons"}
          <FiChevronDown size={18} className="SecondaryTextColor" />
        </button>
      )}
    </div>
  );
};

export default UnlockCouponNudge;
