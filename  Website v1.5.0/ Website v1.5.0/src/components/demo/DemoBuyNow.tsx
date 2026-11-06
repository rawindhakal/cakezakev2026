"use client";
import React from "react";
import { useSelector } from "react-redux";
import { t } from "@/utils/translation";
import useIsHydrated from "@/hooks/useIsHydrated";
import useStandalone from "@/hooks/useStandalone";
import { CartIcon } from "@/components/icons";

// Default marketplace purchase URL for template demo
const DEFAULT_BUY_URL =
  "https://www.cakezake.com/products/cakezake-hyperlocal-quick-commerce-ecommerce-platform";

/** Floating "Buy Now" badge displayed on demo deployments */
const DemoBuyNow = () => {
  const setting = useSelector((state: any) => state.Setting.setting);
  // Wait for store rehydration before rendering
  const isHydrated = useIsHydrated();
  // Hide badge in PWA standalone mode
  const isStandalone = useStandalone();

  if (!isHydrated) return null;
  if (isStandalone) return null;
  // Check if demo mode is enabled
  if (setting?.demo_mode != 1) return null;

  const href = process.env.NEXT_PUBLIC_BUY_NOW_URL || DEFAULT_BUY_URL;

  return (
    <a
      href={href}
      target="_blank"
      // Security rel attributes for external link
      rel="noopener noreferrer"
      // Floating action button styles with hover expansion
      className="demo-buy-now-pulse primaryBackColor group fixed start-4 md:start-6 bottom-[calc(72px+env(safe-area-inset-bottom))] md:bottom-6 z-40 flex h-12 items-center overflow-hidden rounded-full px-3.5 text-sm font-bold text-white shadow-lg transition-all duration-300 ease-out hover:-translate-y-0.5 hover:shadow-xl active:scale-95"
    >
      <CartIcon size={16} />
      <span className="max-w-0 overflow-hidden whitespace-nowrap opacity-0 transition-all duration-300 ease-out group-hover:max-w-[100px] group-hover:opacity-100 group-hover:ms-2 group-focus-visible:max-w-[100px] group-focus-visible:opacity-100 group-focus-visible:ms-2">
        {t("buy_now")}
      </span>
    </a>
  );
};

export default DemoBuyNow;
