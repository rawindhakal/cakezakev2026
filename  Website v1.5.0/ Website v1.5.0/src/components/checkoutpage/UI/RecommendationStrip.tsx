"use client";
import React from "react";
import dynamic from "next/dynamic";
import { IoMdArrowBack, IoMdArrowForward } from "react-icons/io";
import { Swiper, SwiperSlide } from "swiper/react";
import { Navigation } from "swiper/modules";
import "swiper/css";
import "swiper/css/navigation";
import { t } from "@/utils/translation";
import { isRtl } from "@/lib/utils";

const HomeVerticleProductCard = dynamic(
  () => import("@/components/productcards/HomeVerticleProductCard"),
  { ssr: false },
);

interface RecommendationStripProps {
  id: string;
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  /** Products from getCartRecommendations(). */
  products: any[];
}

// Recommendation carousel (hidden when empty).
const RecommendationStrip = ({ id, title, subtitle, products }: RecommendationStripProps) => {
  const rtl = isRtl();
  if (!products || products.length === 0) return null;
  return (
    <div className="bodyBackgroundColor cardBorder !rounded-lg shadow-sm overflow-hidden">
      <div className="flex items-center justify-between gap-3 p-4 md:p-5">
        <div className="min-w-0">
          <span className="font-bold text-lg md:text-xl">{title}</span>
          {subtitle && (
            <p className="text-xs SecondaryTextColor mt-1">{subtitle}</p>
          )}
        </div>
        {products.length > 1 && (
          <div
            className={`hidden md:flex gap-2 shrink-0 ${rtl ? "flex-row-reverse" : ""}`}
          >
            <button
              type="button"
              className={`group textColor cardBorder rounded-full rec-prev-${id} p-2 hover:primaryBackColor hover:text-white transition`}
              aria-label={t("previous") || "Previous"}
            >
              <IoMdArrowBack
                size={18}
                className="group-hover:text-white transition-colors"
              />
            </button>
            <button
              type="button"
              className={`group textColor cardBorder rounded-full rec-next-${id} p-2 hover:primaryBackColor hover:text-white transition`}
              aria-label={t("next") || "Next"}
            >
              <IoMdArrowForward
                size={18}
                className="group-hover:text-white transition-colors"
              />
            </button>
          </div>
        )}
      </div>
      <div className="px-4 md:px-5 pb-4 md:pb-5">
        {/* Remount on RTL change. */}
        <Swiper
          key={String(rtl)}
          modules={[Navigation]}
          spaceBetween={12}
          // Padding so edge card borders aren't clipped.
          slidesOffsetBefore={2}
          slidesOffsetAfter={2}
          style={{ paddingTop: 4, paddingBottom: 4 }}
          navigation={{ prevEl: `.rec-prev-${id}`, nextEl: `.rec-next-${id}` }}
          wrapperClass="swiper-wrapper items-stretch"
          breakpoints={{
            0: { slidesPerView: 2.2, spaceBetween: 8 },
            400: { slidesPerView: 2.4, spaceBetween: 8 },
            500: { slidesPerView: 2.8, spaceBetween: 10 },
            768: { slidesPerView: 3, spaceBetween: 12 },
            1024: { slidesPerView: 4, spaceBetween: 12 },
          }}
        >
          {products.map((product) => (
            <SwiperSlide
              key={product?.variant_id || product?.id}
              className="!h-auto"
            >
              <HomeVerticleProductCard product={product} />
            </SwiperSlide>
          ))}
        </Swiper>
      </div>
    </div>
  );
};

export default RecommendationStrip;
