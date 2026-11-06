"use client";

import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import { IoChevronBack, IoChevronForward } from "react-icons/io5";
import { t } from "@/utils/translation";
import HomeVerticleProductCard from "@/components/productcards/HomeVerticleProductCard";

const ITEM_WIDTH = "w-[40%] shrink-0 min-[420px]:w-[31%] sm:w-[23%] md:w-[30%] lg:w-[22%] xl:w-[18%] 2xl:w-[15.5%]";
const ARROW_CLS =
  "absolute top-[40%] z-30 hidden h-8 w-8 -translate-y-1/2 items-center justify-center rounded-full border border-gray-200 bg-white text-zinc-700 shadow-md transition hover:scale-105 md:flex dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-200";

const SkeletonCard = () => (
  <div className={`${ITEM_WIDTH} flex flex-col gap-2 rounded-xl border border-gray-100 p-2 dark:border-zinc-800`}>
    <div className="aspect-square w-full animate-pulse rounded-lg bg-zinc-200 dark:bg-zinc-800" />
    <div className="h-3 w-3/4 animate-pulse rounded bg-zinc-200 dark:bg-zinc-800" />
    <div className="h-3 w-1/2 animate-pulse rounded bg-zinc-200 dark:bg-zinc-800" />
  </div>
);

interface SearchProductRowProps {
  title: ReactNode;
  products: any[];
  isLoading: boolean;
  animate?: boolean;
}

// Titled single-row product rail for the search panel: swipe on mobile, arrows on desktop.
const SearchProductRow = ({ title, products, isLoading, animate = false }: SearchProductRowProps) => {
  const rowRef = useRef<HTMLDivElement>(null);
  const [canPrev, setCanPrev] = useState(false);
  const [canNext, setCanNext] = useState(false);

  const updateArrows = useCallback(() => {
    const el = rowRef.current;
    if (!el) return;
    const left = Math.abs(el.scrollLeft);
    setCanPrev(left > 2);
    setCanNext(left + el.clientWidth < el.scrollWidth - 2);
  }, []);

  useEffect(() => {
    updateArrows();
    window.addEventListener("resize", updateArrows);
    return () => window.removeEventListener("resize", updateArrows);
  }, [products.length, isLoading, updateArrows]);

  const scrollByPage = (sign: 1 | -1) => {
    const el = rowRef.current;
    if (!el) return;
    const dir = getComputedStyle(el).direction === "rtl" ? -1 : 1;
    el.scrollBy({ left: sign * dir * el.clientWidth * 0.8, behavior: "smooth" });
  };

  return (
    <section className="rounded-xl bg-[#f4f6fb] p-2 pt-3 dark:bg-zinc-950 sm:p-3">
      <h3 className="mb-2.5 px-1.5 text-start text-sm font-bold text-zinc-900 dark:text-zinc-100 sm:mb-3 sm:px-0 sm:text-base">
        {title}
      </h3>
      <div className="relative">
        {canPrev && (
          <button type="button" onClick={() => scrollByPage(-1)} aria-label={t("previous") || "Previous"} className={`${ARROW_CLS} -start-1`}>
            <IoChevronBack size={16} className="rtl:rotate-180" />
          </button>
        )}
        {canNext && (
          <button type="button" onClick={() => scrollByPage(1)} aria-label={t("next") || "Next"} className={`${ARROW_CLS} -end-1`}>
            <IoChevronForward size={16} className="rtl:rotate-180" />
          </button>
        )}
        <div
          ref={rowRef}
          onScroll={updateArrows}
          className="no-scrollbar -mx-2 flex snap-x snap-mandatory scroll-px-2 gap-1.5 overflow-x-auto overscroll-x-contain px-2 pb-1 sm:-mx-3 sm:scroll-px-3 sm:gap-2.5 sm:px-3"
        >
          {isLoading
            ? Array.from({ length: 4 }).map((_, i) => <SkeletonCard key={i} />)
            : products.map((product: any, i: number) => (
                <div
                  key={product.id}
                  className={`${ITEM_WIDTH} snap-start ${animate ? "fadeUpIn" : ""}`}
                  style={animate ? ({ "--i": i } as React.CSSProperties) : undefined}
                >
                  <HomeVerticleProductCard product={product} classicMobile />
                </div>
              ))}
        </div>
      </div>
    </section>
  );
};

export default SearchProductRow;
