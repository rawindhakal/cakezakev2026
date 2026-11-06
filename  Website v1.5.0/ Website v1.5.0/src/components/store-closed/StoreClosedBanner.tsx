"use client";

import { useMemo } from "react";
import dynamic from "next/dynamic";
import { t } from "@/utils/translation";
import useStoreClosed from "@/hooks/useStoreClosed";
import useIsHydrated from "@/hooks/useIsHydrated";
import useLazyLottie from "@/hooks/useLazyLottie";
import { getPrimaryLottieRgb, recolorAnimation } from "@/utils/lottieColor";
import ThemedSvg from "@/components/notfound/ThemedSvg";
import BagHeartSvg from "@/assets/bag-heart.svg";
import SparkleSvg from "@/assets/sparkle.svg";

const Lottie = dynamic(() => import("lottie-react"), { ssr: false });

/**
 * Banner notice displayed at top of homepage when store is temporarily closed.
 */
const StoreClosedBanner = () => {
  const { storeClosed } = useStoreClosed();
  const isHydrated = useIsHydrated();

  // Recolor store closed Lottie animation with primary color accent.
  const storeCloseAnimation = useLazyLottie(
    () => import("@/assets/store-close.json"),
    storeClosed,
  );
  const storeClosedLottie = useMemo(
    () =>
      storeCloseAnimation
        ? recolorAnimation(storeCloseAnimation, getPrimaryLottieRgb(), "accent")
        : null,
    [storeCloseAnimation, isHydrated], // eslint-disable-line react-hooks/exhaustive-deps
  );

  if (!isHydrated || !storeClosed) return null;

  return (
    <div className="container pt-3">
      <div
        role="status"
        className="relative mx-auto max-w-4xl overflow-hidden rounded-2xl border"
        style={{
          borderColor:
            "color-mix(in srgb, var(--primary-color) 10%, transparent)",
          backgroundImage:
            "linear-gradient(110deg, color-mix(in srgb, var(--primary-color) 4%, var(--category-card-bg)), color-mix(in srgb, var(--primary-color) 1.5%, var(--category-card-bg)) 55%, var(--category-card-bg))",
          boxShadow:
            "0 1px 2px color-mix(in srgb, var(--primary-color) 5%, transparent), 0 8px 24px -14px color-mix(in srgb, var(--primary-color) 14%, transparent)",
        }}
      >
        {/* Background glow accents */}
        <span
          aria-hidden="true"
          className="pointer-events-none absolute -end-16 -top-20 z-0 h-36 w-36 rounded-full blur-2xl"
          style={{
            backgroundColor:
              "color-mix(in srgb, var(--primary-color) 8%, transparent)",
          }}
        />
        <span
          aria-hidden="true"
          className="pointer-events-none absolute -bottom-16 -start-12 z-0 h-40 w-40 rounded-full blur-2xl"
          style={{
            backgroundColor:
              "color-mix(in srgb, var(--primary-color) 8%, transparent)",
          }}
        />

        <div className="relative z-10 flex items-center gap-3 px-4 py-3 sm:gap-4 sm:px-5 sm:py-2.5 sm:pe-9">
          <span
            aria-hidden="true"
            className="hidden shrink-0 items-center justify-center sm:flex"
          >
            {storeClosedLottie && (
            <Lottie
              animationData={storeClosedLottie}
              loop
              className="h-16 w-16 lg:h-[72px] lg:w-[72px]"
            />
            )}
          </span>

          <div className="min-w-0 flex-1">
            <p className="text-sm font-extrabold leading-tight tracking-tight sm:text-base primaryColor">
              {t("store_temporarily_closed")}
            </p>
            <p className="mt-0.5 text-xs leading-snug SecondaryTextColor">
              {`${t("store_closed_message")}`.replace(/[.!?]?$/, ".")}{" "}
              {t("thanks_for_your_love_and_support")}
            </p>
          </div>

          {/* End illustration */}
          <span
            aria-hidden="true"
            className="pointer-events-none relative z-10 hidden shrink-0 items-center sm:flex"
          >
            <span className="relative block">
              <ThemedSvg
                src={BagHeartSvg}
                className="h-11 w-11 drop-shadow-sm sm:h-[56px] sm:w-[56px]"
              />
              <ThemedSvg
                src={SparkleSvg}
                className="absolute -end-2 -top-1.5 h-5 w-5 sm:-end-3 sm:h-6 sm:w-6"
              />
            </span>
          </span>
        </div>
      </div>
    </div>
  );
};

export default StoreClosedBanner;

