"use client";

import React, { useId, useRef } from "react";
import { t } from "@/utils/translation";
import {
  openSpinWheel,
  originFromElement,
} from "@/components/spinwin/spinWheelEvents";
import { SpinWheelPromoIcon } from "@/components/icons";

// Standalone spin wheel promo card for profile sidebar
// Fixed multi-color wheel art configuration

const SpinWheelPromoBanner = () => {
  // Generate unique instance SVG gradient ids
  const uid = useId().replace(/:/g, "");
  const goldId = `promoWheelGold-${uid}`;
  const hubId = `promoWheelHub-${uid}`;
  const wheelRef = useRef<SVGSVGElement>(null);
  return (
  // Clipped promo banner container
  <div className="@container">
  <div className="relative overflow-hidden rounded-2xl bg-white p-4 shadow-sm cardBorder dark:bg-zinc-900 @[260px]:pe-[75px] @[300px]:pe-[113px]">
    <div className="min-w-0">
      <p className="text-[15px] font-bold leading-tight textColor">
        {t("get_free_wallet_cash") || "Get Free Wallet Cash"}
      </p>
      <p className="mt-1 text-[12px] leading-snug SecondaryTextColor">
        {t("get_free_wallet_cash_desc") ||
          "Spin the Wheel and get free wallet cash & Surprise Discounts"}
      </p>
      <button
        type="button"
        // The dialog wheel grows out of this card's wheel graphic.
        onClick={() => openSpinWheel(originFromElement(wheelRef.current))}
        // 3D pushable button CTA
        className="btnPush mt-3 mb-[5px] whitespace-nowrap rounded-xl px-5 py-2 text-[13px] @[300px]:px-6 font-extrabold text-white"
      >
        {t("spin_now") || "Spin Now"}
      </button>
    </div>

    {/* Wheel icon element */}
    <SpinWheelPromoIcon ref={wheelRef} goldId={goldId} hubId={hubId} />
  </div>
  </div>
  );
};

export default SpinWheelPromoBanner;
