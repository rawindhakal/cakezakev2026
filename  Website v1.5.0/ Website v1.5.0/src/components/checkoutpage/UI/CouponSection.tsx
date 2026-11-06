import {
  FiTag,
  FiTrash2,
  FiChevronLeft,
  FiChevronRight,
} from "react-icons/fi";
import { MdOutlineCelebration } from "react-icons/md";
import { RiCouponLine } from "react-icons/ri";
import { t } from "@/utils/translation";
import { isRtl } from "@/lib/utils";

interface AppliedCouponTicketProps {
  code?: string;
  amountText: string;
  isCashback: boolean;
  /** Free delivery has no discount amount to show. */
  isFreeDelivery?: boolean;
  onRemove: () => void;
}

// Applied coupon as a notched ticket (RTL-mirrored).
export const AppliedCouponTicket = ({
  code,
  amountText,
  isCashback,
  isFreeDelivery,
  onRemove,
}: AppliedCouponTicketProps) => {
  const rtl = isRtl();
  // One split drives the notches, the tear line and the two halves, so they
  // stay aligned. 62% leaves the stub room for "Free Delivery" in the narrow
  // order-summary column without clipping the code.
  const splitPct = rtl ? 38 : 62;
  const notchMaskImage = `radial-gradient(circle 7px at ${splitPct}% 0, transparent 7px, #000 7.5px), radial-gradient(circle 7px at ${splitPct}% 100%, transparent 7px, #000 7.5px)`;

  return (
    <div
      className="relative flex items-stretch rounded-lg motion-safe:animate-ticketIn"
      style={{
        backgroundImage:
          "linear-gradient(135deg, color-mix(in srgb, var(--primary-color) 14%, var(--category-card-bg)), color-mix(in srgb, var(--primary-color) 7%, var(--category-card-bg)))",
        WebkitMaskImage: notchMaskImage,
        maskImage: notchMaskImage,
        WebkitMaskComposite: "source-in",
        maskComposite: "intersect",
      }}
    >
      {/* dashed tear line between the two notches */}
      {/* dashed tear line between the two notches */}
      <span
        className="pointer-events-none absolute bottom-3 top-3 -translate-x-1/2 border-l border-dashed border-[color-mix(in_srgb,var(--primary-color)_45%,transparent)] dark:border-white/40"
        style={{ left: `${splitPct}%` }}
      />

      <div
        className="flex min-w-0 shrink-0 grow items-center gap-2 px-2.5 py-2.5 sm:gap-2.5 sm:px-3.5 sm:py-3.5"
        style={{ flexBasis: `${splitPct}%` }}
      >
        <span
          className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-white shadow-sm motion-safe:animate-iconSpinIn sm:h-10 sm:w-10"
          style={{ backgroundColor: "var(--primary-color)" }}
        >
          <MdOutlineCelebration size={18} />
        </span>
        <div className="flex min-w-0 flex-col">
          <span className="truncate text-[11px] font-medium leading-tight primaryColor dark:text-white">
            {t("promoCodeSuccess")}
          </span>
          {/* Codes are long and the summary column is narrow — wrap instead of
              clipping to "FREE-DELIV…". */}
          <span className="text-sm font-extrabold uppercase leading-tight tracking-wide textColor break-all sm:text-base">
            {code}
          </span>
        </div>
      </div>

      <div
        className="flex min-w-0 shrink-0 grow items-center justify-center gap-1 py-2.5 pl-2.5 pr-2 sm:gap-2 sm:py-3.5 sm:pl-3.5 sm:pr-3"
        style={{ flexBasis: `${100 - splitPct}%` }}
      >
        <div className="flex min-w-0 flex-col items-center leading-tight">
          <span
            className={`font-extrabold primaryColor dark:text-white max-w-full ${
              isFreeDelivery
                ? "text-[11px] uppercase leading-snug text-center"
                : "text-sm sm:text-lg truncate"
            }`}
          >
            {isFreeDelivery
              ? t("free_delivery") || "Free Delivery"
              : isCashback
                ? amountText
                : `-${amountText}`}
          </span>
          {!isFreeDelivery && (
            <span className="text-[9px] font-bold SecondaryTextColor uppercase tracking-wide">
              {isCashback ? t("cashback") : t("you_save") || "Saved"}
            </span>
          )}
        </div>
        <button
          type="button"
          onClick={onRemove}
          aria-label={t("delete")}
          className="flex items-center justify-center text-gray-400 hover:text-red-500 transition shrink-0"
        >
          <FiTrash2 size={16} />
        </button>
      </div>
    </div>
  );
};

interface CouponInputProps {
  value: string;
  onChange: (value: string) => void;
  onApply: () => void;
  onViewAll: () => void;
}

// Code entry + "view all coupons" link.
export const CouponInput = ({
  value,
  onChange,
  onApply,
  onViewAll,
}: CouponInputProps) => {
  const rtl = isRtl();
  return (
    <>
      <div className="flex items-center gap-2 cardBorder rounded-lg px-3 py-2 focus-within:primaryColorBorder transition">
        <FiTag size={16} className="SecondaryTextColor shrink-0" />
        <input
          type="text"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={t("discount_code")}
          className="flex-1 bg-transparent outline-none text-sm min-w-0"
        />
        <button
          type="button"
          className="font-bold primaryColor dark:text-white text-sm shrink-0 px-1"
          onClick={onApply}
        >
          {t("apply")}
        </button>
      </div>

      <button
        type="button"
        className={`flex items-center justify-between text-sm font-semibold primaryColor dark:text-white hover:opacity-80 transition ${rtl ? "text-right" : "text-left"}`}
        onClick={onViewAll}
      >
        <span className="flex items-center gap-1.5">
          <RiCouponLine size={16} />
          {t("view_all_coupons")}
        </span>
        {rtl ? <FiChevronLeft size={16} /> : <FiChevronRight size={16} />}
      </button>
    </>
  );
};
