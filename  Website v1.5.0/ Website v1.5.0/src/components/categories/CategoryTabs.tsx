import React, { useRef, useState, useEffect, useLayoutEffect } from "react";
import { useSelector } from "react-redux";
import { Swiper, SwiperSlide } from "swiper/react";
import { FreeMode, Mousewheel } from "swiper/modules";
import type { Swiper as SwiperType } from "swiper";
import "swiper/css";
import "swiper/css/free-mode";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import useIsHydrated from "@/hooks/useIsHydrated";
import { pickDeviceImage } from "@/utils/helperFunction";

interface TabProps {
  active: boolean;
  onClick: () => void;
  icon?: React.ReactNode;
  image?: string;
  headerIcon?: string;
  label?: string;
  collapsed: boolean;
}

const INDICATOR_TRANSITION =
  "transform 380ms cubic-bezier(0.22, 1, 0.36, 1), width 380ms cubic-bezier(0.22, 1, 0.36, 1)";

// Module-scope: inside the parent it remounted every slide each render.
const Tab = React.memo(function Tab({
  active,
  onClick,
  icon,
  image,
  headerIcon,
  label,
  collapsed,
}: TabProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`relative flex flex-col items-center w-[54px] sm:w-[76px] cursor-pointer group transition-[padding,gap,transform] duration-300 ease-out active:scale-95 ${
        collapsed ? "gap-0 pt-0 pb-1.5" : "gap-1 pt-1 pb-1"
      }`}
    >
      <div
        style={{ borderRadius: 5 }}
        className={`relative flex items-center justify-center overflow-hidden transition-[height,opacity,transform] duration-300 ease-out ${
          collapsed
            ? "w-6 h-0 opacity-0 scale-75"
            : `w-6 h-6 sm:w-7 sm:h-7 opacity-100 ${active ? "scale-110" : "scale-100"}`
        }`}
      >
        {image || headerIcon ? (
          <ImageWithPlaceholder
            src={headerIcon || image}
            width={120}
            height={120}
            alt={label}
            className="w-full h-full aspect-square object-contain"
          />
        ) : (
          icon
        )}
      </div>
      <span
        style={{ color: "var(--layout-header-text)" }}
        // text-ellipsis, not line-clamp — line-clamp clipped centered text
        // from both edges ("Janmashtami" → "anmastami").
        className={`w-full max-w-full overflow-hidden text-ellipsis whitespace-nowrap text-[11px] sm:text-[15px] leading-tight text-center transition-colors ${
          active ? "font-bold" : "font-semibold"
        }`}
      >
        {label}
      </span>
    </button>
  );
});

interface CategoryTabsProps {
  categories?: any[];
  selectedId?: number | string | null;
  onSelect?: (categoryId: number | string) => void;
  device?: string;
}

// null selectedId → parent picks the first tab.
const CategoryTabs = ({
  categories = [],
  selectedId = null,
  onSelect,
  device = "web",
}: CategoryTabsProps) => {
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  // LTR until hydrated to match SSR.
  const isHydrated = useIsHydrated();
  const dir = isHydrated ? language?.type : undefined;
  const isRtl = isHydrated && language?.type === "rtl";

  const [headerH, setHeaderH] = useState(0);
  const sentinelRef = useRef<HTMLDivElement>(null);
  const stripRef = useRef<HTMLElement>(null);
  const [collapsed, setCollapsed] = useState(false);
  const swiperRef = useRef<SwiperType | null>(null);
  const indicatorRef = useRef<HTMLSpanElement>(null);
  // First placement snaps; later moves transition.
  const indicatorPlacedRef = useRef(false);

  // One underline inside the swiper wrapper, so it scrolls with the slides.
  // offsetLeft/offsetWidth ignore Swiper's transform; the move is a CSS transition.
  const placeIndicator = () => {
    const swiper = swiperRef.current;
    const bar = indicatorRef.current;
    if (!swiper || !bar) return;
    const index = categories.findIndex(
      (c) => String(c.id) === String(selectedId),
    );
    const slide = swiper.slides?.[index];
    if (index < 0 || !slide) {
      bar.style.opacity = "0";
      return;
    }
    if (!indicatorPlacedRef.current) bar.style.transition = "none";
    bar.style.width = `${slide.offsetWidth}px`;
    bar.style.transform = `translateX(${slide.offsetLeft}px)`;
    bar.style.opacity = "1";
    if (!indicatorPlacedRef.current) {
      void bar.offsetWidth;
      bar.style.transition = INDICATOR_TRANSITION;
      indicatorPlacedRef.current = true;
    }
  };

  // The observer below is created once, so it must not capture this render's
  // closure — a stale selectedId moved the underline back to the old tab.
  const placeIndicatorRef = useRef(placeIndicator);

  useLayoutEffect(() => {
    placeIndicatorRef.current = placeIndicator;
  });

  useLayoutEffect(placeIndicator);

  useEffect(() => {
    const el = swiperRef.current?.el;
    if (!el) return;
    const ro = new ResizeObserver(() => placeIndicatorRef.current());
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  // Bring the selected tab into view when it sits at/over the strip edge.
  useEffect(() => {
    const swiper = swiperRef.current;
    if (!swiper || selectedId == null) return;
    const index = categories.findIndex(
      (c) => String(c.id) === String(selectedId),
    );
    const slide = swiper.slides?.[index];
    if (index < 0 || !slide) return;
    const strip = swiper.el.getBoundingClientRect();
    const rect = slide.getBoundingClientRect();
    if (rect.left < strip.left + 24 || rect.right > strip.right - 24) {
      swiper.slideTo(Math.max(index - 1, 0), 400);
    }
  }, [selectedId, categories]);

  // Sticky offset = header height; heights published to :root so the shared
  // header/strip background stays seamless.
  useEffect(() => {
    const header = document.getElementById("site-header");
    const root = document.documentElement;
    const measure = () => {
      // Not offsetHeight — it rounds, leaving a sub-pixel seam.
      const hh = header ? header.getBoundingClientRect().height : 0;
      const sh = stripRef.current
        ? stripRef.current.getBoundingClientRect().height
        : 0;
      // Part of the header that scrolls away on mobile home (see Header).
      const collapse =
        Number.parseFloat(
          getComputedStyle(root).getPropertyValue("--layout-header-collapse"),
        ) || 0;
      setHeaderH(Math.max(0, hh - collapse));
      root.style.setProperty("--layout-header-h", `${hh}px`);
      root.style.setProperty("--layout-strip-h", `${sh}px`);
    };
    measure();
    const ro = new ResizeObserver(measure);
    if (header) ro.observe(header);
    if (stripRef.current) ro.observe(stripRef.current);
    window.addEventListener("resize", measure);
    window.addEventListener("layout-header-collapse", measure);
    return () => {
      ro.disconnect();
      window.removeEventListener("resize", measure);
      window.removeEventListener("layout-header-collapse", measure);
      // Reset, else pages without the strip inherit a stale offset.
      root.style.setProperty("--layout-header-h", "0px");
      root.style.setProperty("--layout-strip-h", "0px");
    };
  }, []);

  // Collapse once stuck: sentinel above the bar leaves view at the header edge.
  useEffect(() => {
    const el = sentinelRef.current;
    if (!el) return;
    const io = new IntersectionObserver(
      ([entry]) => {
        setCollapsed(!entry.isIntersecting);
      },
      {
        rootMargin: `-${headerH}px 0px 0px 0px`,
        threshold: 0,
      },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [headerH]);

  if (!categories || categories.length === 0) return null;

  return (
    <>
      {/* 1px (h-0 was ambiguous), hidden to avoid a hairline seam. */}
      <div
        ref={sentinelRef}
        aria-hidden
        className="h-px -mb-px"
        style={{ visibility: "hidden" }}
      />
      <section
        ref={stripRef}
        dir={dir}
        // No negative margin — would desync the background slice from headerH.
        style={{ top: headerH }}
        // Layout containment keeps the collapse reflow inside the strip.
        className="sticky z-40 layoutHeaderGradientContinue layoutHeaderText [contain:layout_style]"
      >
        <div
          className={`container relative transition-[padding] duration-300 ease-out ${
            collapsed ? "pt-1 pb-0" : "pt-1.5 pb-0"
          }`}
        >
          <>
            <Swiper
              dir={dir}
              key={isRtl ? "rtl" : "ltr"}
              modules={[FreeMode, Mousewheel]}
              slidesPerView="auto"
              spaceBetween={8}
              breakpoints={{ 640: { spaceBetween: 16 } }}
              freeMode={{ enabled: true, momentum: true }}
              mousewheel={{ forceToAxis: true }}
              onSwiper={(swiper) => {
                swiperRef.current = swiper;
                placeIndicator();
              }}
              className="!pb-0 !pt-0"
            >
              {categories.map((category) => {
                // image_url: plain URL (legacy) or per-device object.
                const image =
                  category.image_url && typeof category.image_url === "object"
                    ? pickDeviceImage(category.image_url, device)
                    : category.image_url;
                return (
                  <SwiperSlide key={category.id} className="!w-auto">
                    <Tab
                      collapsed={collapsed}
                      active={String(selectedId) === String(category.id)}
                      onClick={() => onSelect?.(category.id)}
                      image={image}
                      headerIcon={category.header_icon_url}
                      label={category?.translations?.name ?? category?.name}
                    />
                  </SwiperSlide>
                );
              })}
              <span
                slot="wrapper-end"
                ref={indicatorRef}
                aria-hidden
                style={{
                  backgroundColor: "var(--layout-header-text)",
                  opacity: 0,
                  transition: INDICATOR_TRANSITION,
                }}
                className="pointer-events-none absolute bottom-0 left-0 z-10 h-[2px] rounded-full will-change-transform motion-reduce:!transition-none"
              />
            </Swiper>
          </>
        </div>
      </section>
    </>
  );
};

export default CategoryTabs;
