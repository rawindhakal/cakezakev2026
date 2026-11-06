"use client";
import React, { useEffect, useState } from "react";
import { MdOutlineCelebration } from "react-icons/md";
import { FiTrash2 } from "react-icons/fi";
import { t } from "@/utils/translation";
import useIsRtl from "@/hooks/useIsRtl";
import SpinWinConfetti from "@/components/spinwin/SpinWinConfetti";

interface AppliedCouponCardProps {
  code: string;
  /** pre-formatted, e.g. "₹10.00" */
  savedAmount: string;
  discountType?: string;
  onRemove: () => void;
  loading?: boolean;
}

// Applied-coupon ticket — matches CartCouponCard's look.
const AppliedCouponCard = ({ code, savedAmount, discountType, onRemove, loading }: AppliedCouponCardProps) => {
  const rtl = useIsRtl();
  // Notch at 66% from start edge; mirrored for RTL.
  const notchPct = rtl ? 34 : 66;

  // One confetti burst when the ticket appears — applying a coupon used to be
  // just a toast. Skipped for reduced motion.
  const [celebrating, setCelebrating] = useState(false);
  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- fires the burst once the applied ticket mounts
    setCelebrating(true);
    const timer = setTimeout(() => setCelebrating(false), 2200);
    return () => clearTimeout(timer);
  }, [code]);

  return (
    <div
      className="relative mb-2 flex items-stretch rounded-lg motion-safe:animate-ticketIn"
      style={{
        backgroundImage:
          "linear-gradient(135deg, color-mix(in srgb, var(--primary-color) 14%, var(--category-card-bg)), color-mix(in srgb, var(--primary-color) 7%, var(--category-card-bg)))",
        WebkitMaskImage: `radial-gradient(circle 8px at ${notchPct}% 0, transparent 8px, #000 8.5px), radial-gradient(circle 8px at ${notchPct}% 100%, transparent 8px, #000 8.5px)`,
        maskImage: `radial-gradient(circle 8px at ${notchPct}% 0, transparent 8px, #000 8.5px), radial-gradient(circle 8px at ${notchPct}% 100%, transparent 8px, #000 8.5px)`,
        WebkitMaskComposite: "source-in",
        maskComposite: "intersect",
      }}
    >
      <SpinWinConfetti active={celebrating} />

      <span
        className="pointer-events-none absolute top-3 bottom-3 -translate-x-1/2 border-l border-dashed border-[color-mix(in_srgb,var(--primary-color)_45%,transparent)] dark:border-white/40"
        style={{ left: `${notchPct}%` }}
      />

      <div className="flex items-center gap-2.5 min-w-0 basis-[66%] grow px-3 sm:px-3.5 py-3.5">
        <span
          className="flex h-9 w-9 sm:h-10 sm:w-10 shrink-0 items-center justify-center rounded-full text-white shadow-sm motion-safe:animate-iconSpinIn"
          style={{ backgroundColor: "var(--primary-color)" }}
        >
          <MdOutlineCelebration size={20} />
        </span>
        <div className="flex flex-col min-w-0">
          <span className="text-[11px] font-medium primaryColor dark:text-white leading-tight">
            {t("promoCodeSuccess") || t("coupon_applied") || "Coupon Applied"}
          </span>
          <span className="text-sm sm:text-base font-extrabold textColor truncate leading-tight tracking-wide uppercase">
            {code}
          </span>
        </div>
      </div>

      <div className="flex items-center justify-center gap-1.5 sm:gap-2 shrink-0 basis-[34%] grow pl-2 sm:pl-4 pr-2 sm:pr-3 py-3.5">
        <div className="flex flex-col items-center leading-tight min-w-0">
          {discountType === "free_delivery" ? (
            <span className="text-[10px] sm:text-[11px] font-bold primaryColor dark:text-white uppercase tracking-wide text-center leading-snug">
              {t("free_delivery") || "Free Delivery"}
            </span>
          ) : (
            <>
              <span className="text-base sm:text-lg font-extrabold primaryColor dark:text-white truncate max-w-full">
                {savedAmount}
              </span>
              <span className="text-[9px] font-bold SecondaryTextColor uppercase tracking-widest">
                {t("you_save") || t("you_saved") || "Saved"}
              </span>
            </>
          )}
        </div>
        <button
          type="button"
          onClick={onRemove}
          disabled={loading}
          aria-label={t("delete") || t("remove") || "Remove"}
          className="flex items-center justify-center text-gray-400 hover:text-red-500 transition shrink-0 disabled:opacity-50"
        >
          <FiTrash2 size={16} />
        </button>
      </div>
    </div>
  );
};

export default AppliedCouponCard;
