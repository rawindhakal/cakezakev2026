"use client";

import React, {
  useState,
  useEffect,
  useCallback,
  useMemo,
  useRef,
} from "react";
import Image from "next/image";
import { useSelector } from "react-redux";
import { useRouter } from "next/navigation";
import useEmblaCarousel from "embla-carousel-react";
import Autoplay from "embla-carousel-autoplay";
import { pickDeviceImage, toCssAspectRatio } from "@/utils/helperFunction";
import { resolveIdCsvToSlugCsv } from "@/utils/categorySlugResolver";
import useZoneHref from "@/hooks/useZoneHref";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import useNavClick from "@/hooks/useNavClick";
import useProductsRedirect from "@/hooks/useProductsRedirect";

// Per carousel_style UI presets
const STYLE_MAP: Record<
  string,
  {
    container: string;
    align: string;
    slideBasis: string;
    slidePad: string;
    inner: string;
    rounded: string;
    aspect: string;
    spotlight: boolean;
  }
> = {
  full_width: {
    container: "w-full",
    align: "center",
    slideBasis: "basis-full",
    slidePad: "",
    inner: "",
    rounded: "rounded-none",
    aspect: "aspect-[1200/650]",
    spotlight: false,
  },
  card: {
    container: "",
    align: "center",
    slideBasis: "basis-full",
    slidePad: "",
    inner: "",
    rounded: "rounded-xl",
    aspect: "aspect-[1200/650]",
    spotlight: false,
  },
  peek: {
    container: "",
    align: "center",
    slideBasis: "basis-[88%] sm:basis-[82%] md:basis-[75%] lg:basis-[80%]",
    slidePad: "px-2",
    inner: "p-1",
    rounded: "rounded-2xl",
    aspect: "aspect-[1200/650]",
    spotlight: false,
  },
  spotlight: {
    container: "",
    align: "center",
    slideBasis: "basis-[88%] sm:basis-[82%] md:basis-[75%] lg:basis-[80%]",
    slidePad: "px-2",
    inner: "p-1",
    rounded: "rounded-2xl",
    aspect: "aspect-[1200/650]",
    spotlight: true,
  },
  story: {
    container: "",
    align: "center",
    slideBasis: "basis-full",
    slidePad: "",
    inner: "",
    rounded: "rounded-lg",
    aspect: "aspect-[1200/650]",
    spotlight: false,
  },
};

// Priority gates LCP image promotion for above-the-fold sliders.
interface BannerSliderSectionProps {
  block: any;
  borderRadius?: string | number;
  device?: string;
  priority?: boolean;
  // Resolves category tree for navigation.
  resolveCategoryTree?: () => Promise<any[]>;
}

const BannerSliderSection = ({
  block,
  borderRadius,
  device = "web",
  priority = false,
  resolveCategoryTree,
}: BannerSliderSectionProps) => {
  const zoneHref = useZoneHref();
  const { buildQueryPatch } = useUrlProductFilters();
  const router = useRouter();
  const { run: runNavClick } = useNavClick();
  const openProductsRedirect = useProductsRedirect(resolveCategoryTree);
  const language = useSelector((state: any) => state.Language.selectedLanguage);

  const config = block?.config || {};
  const items = (block?.items || []).filter((item: any) =>
    pickDeviceImage(item?.images, device, item?.image_url),
  );
  const itemCount = items.length;

  const S = STYLE_MAP[config?.carousel_style] || STYLE_MAP.card;
  const isStory = config?.carousel_style === "story";

  // Embla autoplay plugin for non-story sliders.
  const plugins = useMemo(
    () =>
      config?.auto_scroll && !isStory && itemCount > 1
        ? [
            Autoplay({
              delay: config?.speed_ms || 3000,
              stopOnInteraction: false,
              stopOnMouseEnter: false,
              stopOnFocusIn: false,
            }),
          ]
        : [],
    [config?.auto_scroll, config?.speed_ms, isStory, itemCount],
  );

  // Symmetric peek centers slides so neighbors peek on both sides.
  const symmetricPeek = S.spotlight || config?.carousel_style === "peek";

  // Embla carousel options.
  const emblaOptions = useMemo(
    () => ({
      loop: !!((config?.infinite_loop || symmetricPeek) && itemCount > 1),
      align: S.align as any,
      containScroll: (symmetricPeek ? "" : "trimSnaps") as any,
      direction: (language?.type === "RTL" ? "rtl" : "ltr") as any,
      watchDrag: itemCount > 1,
    }),
    [config?.infinite_loop, itemCount, S.align, symmetricPeek, language?.type],
  );

  const [emblaRef, emblaApi] = useEmblaCarousel(emblaOptions, plugins);

  const [selectedIndex, setSelectedIndex] = useState(0);
  const [scrollSnaps, setScrollSnaps] = useState<number[]>([]);
  const [isVisible, setIsVisible] = useState(true);

  // Lazy-load images by tracking visible and adjacent slide indices.
  const [loadedIndices, setLoadedIndices] = useState<Set<number>>(
    () => new Set([0, 1, Math.max(itemCount - 1, 0)]),
  );

  // Story progress refs (manipulates DOM width directly to avoid re-renders).
  const fillRefs = useRef<(HTMLSpanElement | null)[]>([]);
  const setProgressWidth = useCallback((index: number, pct: number) => {
    const node = fillRefs.current[index];
    if (node) node.style.width = `${pct}%`;
  }, []);

  const autoScroll = !!config?.auto_scroll;
  const infiniteLoop = !!config?.infinite_loop;
  const speedMs = config?.speed_ms || 3000;
  const imageAspectRaw =
    config?.image_aspect && typeof config.image_aspect === "object"
      ? pickDeviceImage(config.image_aspect, device)
      : config?.image_aspect;
  const aspectRatio = toCssAspectRatio(imageAspectRaw) ?? "3 / 1";

  const viewportRef = useRef<HTMLDivElement>(null);
  const rafRef = useRef<number | null>(null);
  const startTimeRef = useRef<number | null>(null);
  const elapsedRef = useRef(0);
  const frozenRef = useRef(false);
  const indexRef = useRef(0);

  // Story auto-advance logic.
  const advanceStory = useCallback(() => {
    const last = itemCount - 1;
    const cur = indexRef.current;
    let next: number;
    if (cur < last) next = cur + 1;
    else if (infiniteLoop) next = 0;
    else return false;
    indexRef.current = next;
    setSelectedIndex(next);
    if (emblaApi) emblaApi.scrollTo(next);
    return true;
  }, [emblaApi, infiniteLoop, itemCount]);

  // Reset progress on active story change.
  useEffect(() => {
    elapsedRef.current = 0;
    startTimeRef.current = null;
    fillRefs.current.forEach((node: HTMLSpanElement | null) => {
      if (node) node.style.width = "0%";
    });
  }, [selectedIndex]);

  // Pause story autoplay when hidden or offscreen.
  useEffect(() => {
    const node = viewportRef.current;
    if (!node || typeof IntersectionObserver === "undefined") return;
    const observer = new IntersectionObserver(
      ([entry]: IntersectionObserverEntry[]) => setIsVisible(entry.isIntersecting),
      { threshold: 0.5 },
    );
    observer.observe(node);
    const onTabVisibility = () => setIsVisible(!document.hidden);
    document.addEventListener("visibilitychange", onTabVisibility);
    return () => {
      observer.disconnect();
      document.removeEventListener("visibilitychange", onTabVisibility);
    };
  }, []);

  // RAF loop for story progress bar animation.
  useEffect(() => {
    if (!isStory || !autoScroll || itemCount < 2 || !isVisible) return;

    let stopped = false;
    startTimeRef.current = null;
    const tick = (now: number) => {
      if (stopped) return;
      if (startTimeRef.current == null) {
        startTimeRef.current = now - elapsedRef.current;
        frozenRef.current = false;
      }
      const elapsed = now - startTimeRef.current;

      if (elapsed >= speedMs) {
        if (advanceStory()) {
          elapsedRef.current = 0;
          startTimeRef.current = now;
          setProgressWidth(indexRef.current, 0);
        } else if (!frozenRef.current) {
          frozenRef.current = true;
          elapsedRef.current = speedMs;
          setProgressWidth(indexRef.current, 100);
        }
      } else {
        elapsedRef.current = elapsed;
        setProgressWidth(indexRef.current, (elapsed / speedMs) * 100);
      }
      rafRef.current = requestAnimationFrame(tick);
    };
    rafRef.current = requestAnimationFrame(tick);
    return () => {
      stopped = true;
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    };
  }, [
    isStory,
    autoScroll,
    itemCount,
    isVisible,
    speedMs,
    infiniteLoop,
    emblaApi,
    advanceStory,
    setProgressWidth,
  ]);

  const scrollTo = useCallback(
    (index: number) => emblaApi && emblaApi.scrollTo(index),
    [emblaApi],
  );
  const scrollPrev = useCallback(
    () => emblaApi && emblaApi.scrollPrev(),
    [emblaApi],
  );
  const scrollNext = useCallback(() => {
    if (!emblaApi) return;
    if (emblaApi.canScrollNext()) emblaApi.scrollNext();
    else if (infiniteLoop) emblaApi.scrollTo(0);
  }, [emblaApi, infiniteLoop]);
  const onSelect = useCallback(() => {
    if (!emblaApi) return;
    const idx = emblaApi.selectedScrollSnap();
    indexRef.current = idx;
    setSelectedIndex(idx);
    const n = emblaApi.slideNodes().length || 1;
    const prevIdx = (idx - 1 + n) % n;
    const nextIdx = (idx + 1) % n;
    setLoadedIndices((prev) => {
      if (prev.has(prevIdx) && prev.has(idx) && prev.has(nextIdx)) return prev;
      const next = new Set(prev);
      next.add(prevIdx);
      next.add(idx);
      next.add(nextIdx);
      return next;
    });
  }, [emblaApi]);

  useEffect(() => {
    if (!emblaApi) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setScrollSnaps(emblaApi.scrollSnapList());
    emblaApi.on("select", onSelect);
    emblaApi.on("reInit", onSelect);
    return () => {
      emblaApi.off("select", onSelect);
    };
  }, [emblaApi, onSelect]);

  const hasRedirect = (item: any) =>
    (item?.redirect_type === "url" && item?.redirect_url) ||
    ((item?.redirect_type === "product" ||
      item?.redirect_type === "category") &&
      item?.redirect_id) ||
    (item?.redirect_type === "page" && item?.redirect_slug) ||
    // An all-blank filter set is valid: it opens the unfiltered listing.
    item?.redirect_type === "products";

  const navigate = async (item: any) => {
    if (item?.redirect_type === "url" && item?.redirect_url) {
      window.open(item.redirect_url, "_blank");
    } else if (item?.redirect_type === "product" && item?.redirect_id) {
      router.push(zoneHref(`/product/${item.redirect_id}`));
    } else if (item?.redirect_type === "category" && item?.redirect_id) {
      const tree = (await resolveCategoryTree?.()) || [];
      const slug =
        resolveIdCsvToSlugCsv(tree, item.redirect_id.toString()) ||
        item.redirect_id.toString();
      const qs = new URLSearchParams(
        buildQueryPatch({ category_id: slug }),
      ).toString();
      const dest = zoneHref("/products");
      router.push(qs ? `${dest}?${qs}` : dest);
    } else if (item?.redirect_type === "products") {
      await openProductsRedirect(item);
    } else if (item?.redirect_type === "page" && item?.redirect_slug) {
      router.push(zoneHref(`/page/${item.redirect_slug}`));
    }
  };

  const handleClick = (item: any, index: number) => {
    if (!hasRedirect(item)) return;
    runNavClick(() => navigate(item), index);
  };

  if (itemCount === 0) return null;

  return (
    <section>
      <div className={S.container} ref={viewportRef}>
        <div className="relative">
          {/* Embla viewport */}
          <div className="overflow-hidden" ref={emblaRef}>
            <div className="flex">
              {items.map((item: any, index: number) => {
                const src = pickDeviceImage(
                  item?.images,
                  device,
                  item?.image_url,
                );
                const dimmed = S.spotlight && index !== selectedIndex;
                return (
                  <div
                    className={`relative flex-shrink-0 min-w-0 ${S.slideBasis} ${S.slidePad}`}
                    key={index}
                  >
                    <div
                      className={`transition duration-300 ease-out ${
                        hasRedirect(item) ? "cursor-pointer" : "cursor-default"
                      } ${S.inner} ${
                        dimmed ? "scale-90 opacity-50" : "scale-100 opacity-100"
                      }`}
                      onClick={() => handleClick(item, index)}
                    >
                      <div
                        className={`relative w-full overflow-hidden ${borderRadius == null ? S.rounded : ""}`}
                        style={{
                          aspectRatio,
                          ...(borderRadius == null ? {} : { borderRadius }),
                        }}
                      >
                        {loadedIndices.has(index) && (
                          <Image
                            src={src}
                            alt="Banner image"
                            priority={priority && index === 0}
                            fetchPriority={priority && index === 0 ? "high" : undefined}
                            className={`absolute inset-0 w-full h-full object-cover ${borderRadius == null ? S.rounded : ""}`}
                            style={
                              borderRadius == null ? undefined : { borderRadius }
                            }
                            width={1920}
                            height={1040}
                            sizes={
                              config?.carousel_style === "full_width"
                                ? "100vw"
                                : "(max-width: 768px) 100vw, 1280px"
                            }
                            quality={75}
                          />
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Story tap zones */}
          {isStory && autoScroll && itemCount > 1 && (
            <>
              <button
                type="button"
                onClick={scrollPrev}
                aria-label="Previous story"
                className="absolute left-0 top-0 z-20 h-full w-1/3 cursor-pointer focus:outline-none"
              />
              <button
                type="button"
                onClick={scrollNext}
                aria-label="Next story"
                className="absolute right-0 top-0 z-20 h-full w-2/3 cursor-pointer focus:outline-none"
              />
            </>
          )}

          {!isStory &&
            config?.indicator === "dots" &&
            scrollSnaps.length > 1 && (
              <div className="absolute bottom-3 left-1/2 -translate-x-1/2 flex items-center justify-center gap-1.5 w-fit z-10">
                {scrollSnaps.map((_: number, index: number) => (
                  <button
                    key={index}
                    onClick={() => scrollTo(index)}
                    aria-label={`Go to slide ${index + 1}`}
                    style={
                      index === selectedIndex
                        ? { backgroundColor: "#000" }
                        : undefined
                    }
                    className={`h-2 w-2 rounded-full transition duration-300 ease-out [box-shadow:0_1px_2px_rgba(0,0,0,0.3)] ${
                      index === selectedIndex
                        ? "scale-110"
                        : "bg-white/45 hover:bg-white/70"
                    }`}
                  />
                ))}
              </div>
            )}
        </div>

        {/* Story segmented progress bar */}
        {isStory && itemCount > 0 && (
          <div className="flex items-center w-full mt-2 px-2">
            <div className="flex gap-1.5 w-full">
              {items.map((_: any, index: number) => {
                const isActive = index === selectedIndex;
                const initialFill = isActive && !autoScroll ? 100 : 0;
                return (
                  <button
                    key={index}
                    type="button"
                    onClick={() => scrollTo(index)}
                    className="flex-1 h-4 flex items-center cursor-pointer focus:outline-none"
                    aria-label={`Go to slide ${index + 1}`}
                  >
                    <span className="block w-full h-1 rounded-full bg-gray-300/80 overflow-hidden">
                      <span
                        ref={(node: HTMLSpanElement | null) => {
                          fillRefs.current[index] = node;
                        }}
                        className="block h-full rounded-full bg-[var(--primary-color)]"
                        style={{ width: `${initialFill}%` }}
                      />
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </section>
  );
};

export default React.memo(BannerSliderSection);
