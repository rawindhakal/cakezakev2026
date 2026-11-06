"use client";
import React, { memo, useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { m } from "framer-motion";
import StoryImage from "./StoryImage";
import ProductDetailModal from "../productdetailmodal/ProductDetailModal";

interface ProductStorySheetProps {
  products: any[];
  startIndex: number;
  onClose: () => void;
}

const MORPH_MS = 340;
const MORPH_EASE = "cubic-bezier(0.32, 0.72, 0, 1)";

interface StorySlideProps {
  product: any;
  isActive: boolean;
  /** Render the full card (else a light preview). */
  near: boolean;
  /** Allowed to fetch details (active ± 1); cached data still shows otherwise. */
  fetch: boolean;
  expanded: boolean;
  onClose: () => void;
  onExpandChange: (expanded: boolean) => void;
}

// Memoised so settling on a new card only re-renders the slides whose
// active/near state actually changed. Far slides get a cheap preview.
const StorySlide = memo(function StorySlide({
  product,
  isActive,
  near,
  fetch,
  expanded,
  onClose,
  onExpandChange,
}: StorySlideProps) {
  // Expand/collapse morph: the card's slot stays in the track; the card itself
  // goes position:fixed and animates its box between the slot and the screen.
  //   card -> pre (fixed at slot rect) -> full (transition to viewport)
  //   full -> closing (transition back to slot rect) -> card
  const slotRef = useRef<HTMLDivElement>(null);
  const [phase, setPhase] = useState<"card" | "pre" | "full" | "closing">("card");
  const [rect, setRect] = useState<DOMRect | null>(null);
  useLayoutEffect(() => {
    const slot = slotRef.current;
    if (!slot) return;
    if (expanded && (phase === "card" || phase === "closing")) {
      setRect(slot.getBoundingClientRect());
      setPhase("pre");
    } else if (!expanded && (phase === "pre" || phase === "full")) {
      setRect(slot.getBoundingClientRect());
      setPhase("closing");
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [expanded]);
  useEffect(() => {
    if (phase === "pre") {
      let id2 = 0;
      const id1 = requestAnimationFrame(() => {
        id2 = requestAnimationFrame(() => setPhase("full"));
      });
      return () => {
        cancelAnimationFrame(id1);
        cancelAnimationFrame(id2);
      };
    }
    if (phase === "closing") {
      const id = setTimeout(() => setPhase("card"), MORPH_MS);
      return () => clearTimeout(id);
    }
  }, [phase]);

  const morphTransition = `top ${MORPH_MS}ms ${MORPH_EASE}, left ${MORPH_MS}ms ${MORPH_EASE}, width ${MORPH_MS}ms ${MORPH_EASE}, height ${MORPH_MS}ms ${MORPH_EASE}, border-radius ${MORPH_MS}ms ${MORPH_EASE}`;
  const cardStyle: React.CSSProperties | undefined =
    phase === "card" || !rect
      ? undefined
      : phase === "full"
        ? {
            position: "fixed",
            top: 0,
            left: 0,
            width: "100vw",
            height: "100dvh",
            borderRadius: 0,
            zIndex: 10,
            overflow: "hidden",
            transition: morphTransition,
          }
        : {
            position: "fixed",
            top: rect.top,
            left: rect.left,
            width: rect.width,
            height: rect.height,
            borderRadius: 24,
            zIndex: 10,
            overflow: "hidden",
            transition: phase === "closing" ? morphTransition : "none",
          };

  const setShow = useCallback(
    (show: boolean) => {
      if (!show) onClose();
    },
    [onClose],
  );
  return (
    <div
      ref={slotRef}
      className={`h-full w-[88vw] shrink-0 snap-center snap-always ${
        phase === "card" ? "transition-transform duration-300" : ""
      } ${isActive || phase !== "card" ? "" : "scale-[0.96]"}`}
    >
      <div className="h-full w-full" style={cardStyle}>
      {near ? (
        <ProductDetailModal
          layout="story"
          product={product}
          showDetailModal={fetch}
          setShowDetailModal={setShow}
          storyExpanded={expanded}
          onStoryExpandChange={isActive ? onExpandChange : undefined}
        />
      ) : (
        <div className="flex h-full flex-col overflow-hidden rounded-3xl bg-white dark:bg-zinc-900">
          <div className="relative aspect-square w-full bg-gray-100 dark:bg-zinc-800">
            {product?.image_url && (
              <StoryImage src={product.image_url} alt={product?.name || "product"} />
            )}
          </div>
          <p className="px-4 pt-4 text-lg font-bold textColor">
            {product?.translations?.name ?? product?.name}
          </p>
        </div>
      )}
      </div>
    </div>
  );
});

// Full-screen swipe track of product cards; neighbours peek at the edges.
// Swipe up on a card expands it to full-screen details; pull down collapses.
// Only the active card and its neighbours fetch details.
const ProductStorySheet = ({ products, startIndex, onClose }: ProductStorySheetProps) => {
  const trackRef = useRef<HTMLDivElement>(null);
  const [active, setActive] = useState(startIndex);
  // Only the tapped card mounts during the open spring (mounting three heavy
  // cards at once made it stutter); neighbours join once it has settled.
  // Mounted cards stay mounted, so swiping back never remounts/reloads them.
  const [settled, setSettled] = useState(false);
  const [mountedIdx, setMountedIdx] = useState<Set<number>>(
    () => new Set([startIndex]),
  );
  const mountedRef = useRef(mountedIdx);
  useEffect(() => {
    mountedRef.current = mountedIdx;
  }, [mountedIdx]);
  useEffect(() => {
    if (!settled) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- grows the keep-alive set as the active card moves
    setMountedIdx((prev) => {
      const add = [active - 1, active, active + 1].filter(
        (i) => i >= 0 && i < products.length && !prev.has(i),
      );
      if (!add.length) return prev;
      const next = new Set(prev);
      add.forEach((i) => next.add(i));
      return next;
    });
  }, [active, settled, products.length]);

  // Then warm the rest during idle time, nearest first, one card per idle
  // slot — so swiping never swaps a preview for a freshly mounted card.
  useEffect(() => {
    if (!settled) return;
    const ric: (cb: () => void) => number =
      (window as any).requestIdleCallback ?? ((cb) => window.setTimeout(cb, 60));
    const cic: (id: number) => void =
      (window as any).cancelIdleCallback ?? window.clearTimeout;
    let id = 0;
    const step = () => {
      const prev = mountedRef.current;
      let pick = -1;
      for (let d = 1; d < products.length && pick < 0; d++) {
        if (active + d < products.length && !prev.has(active + d)) pick = active + d;
        else if (active - d >= 0 && !prev.has(active - d)) pick = active - d;
      }
      if (pick < 0) return;
      const next = new Set(prev);
      next.add(pick);
      mountedRef.current = next;
      setMountedIdx(next);
      id = ric(step);
    };
    id = ric(step);
    return () => cic(id);
  }, [settled, active, products.length]);
  const [expanded, setExpanded] = useState(false);
  const expandedRef = useRef(false);
  const onCloseRef = useRef(onClose);
  // History entries this sheet pushed and still owns. Reading them back off
  // history.state was unreliable — Next rewrites state on its own navigations,
  // so a stale `productStory` flag (or a missing one) sent go(-n) past our
  // entries and navigated the user to the previous real page.
  const ownedEntries = useRef(0);
  useEffect(() => {
    onCloseRef.current = onClose;
  }, [onClose]);
  useEffect(() => {
    expandedRef.current = expanded;
  }, [expanded]);

  // Horizontal-only centring; scrollIntoView could also scroll the page.
  const centerSlide = useCallback((i: number) => {
    const track = trackRef.current;
    const slide = track?.children[i] as HTMLElement | undefined;
    if (!track || !slide) return;
    const left = slide.offsetLeft - (track.clientWidth - slide.offsetWidth) / 2;
    const isRtl = getComputedStyle(track).direction === "rtl";
    track.scrollLeft = isRtl ? left - (track.scrollWidth - track.clientWidth) : left;
  }, []);

  useLayoutEffect(() => {
    centerSlide(startIndex);
  }, [startIndex, centerSlide]);

  // Re-centre the active card once it drops back into the track.
  useLayoutEffect(() => {
    if (expanded) return;
    centerSlide(active);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [expanded]);

  // History entries: one for the sheet, one more while expanded, so the
  // hardware back button collapses first, then closes.
  useEffect(() => {
    // Our history entries share the page URL; on back, browser/Next scroll
    // restoration jumped the page (to the footer). Restore it ourselves.
    const savedY = window.scrollY;
    const prevRestoration = window.history.scrollRestoration;
    window.history.scrollRestoration = "manual";
    const restoreScroll = () => {
      window.scrollTo({ top: savedY, behavior: "instant" as ScrollBehavior });
      requestAnimationFrame(() =>
        window.scrollTo({ top: savedY, behavior: "instant" as ScrollBehavior }),
      );
    };

    window.history.pushState({ ...window.history.state, productStory: true }, "");
    ownedEntries.current = 1;
    const onPop = () => {
      // One of ours just popped. Two left means the expanded entry went: the
      // sheet stays open and only collapses. One left means the sheet itself.
      ownedEntries.current = Math.max(ownedEntries.current - 1, 0);
      if (ownedEntries.current > 0) setExpanded(false);
      else onCloseRef.current();
      restoreScroll();
    };
    window.addEventListener("popstate", onPop);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    // Pulling the card down otherwise triggers the browser's pull-to-refresh
    // (full site reload + loader).
    const html = document.documentElement;
    const prevHtmlOverscroll = html.style.overscrollBehaviorY;
    const prevBodyOverscroll = document.body.style.overscrollBehaviorY;
    html.style.overscrollBehaviorY = "none";
    document.body.style.overscrollBehaviorY = "none";
    return () => {
      window.removeEventListener("popstate", onPop);
      document.body.style.overflow = prevOverflow;
      html.style.overscrollBehaviorY = prevHtmlOverscroll;
      document.body.style.overscrollBehaviorY = prevBodyOverscroll;
      restoreScroll();
      window.history.scrollRestoration = prevRestoration;
    };
  }, []);

  const requestClose = useCallback(() => {
    const owned = ownedEntries.current;
    // Nothing of ours left on the stack — going back here would leave the page.
    if (owned <= 0) {
      onCloseRef.current();
      return;
    }
    ownedEntries.current = 0;
    window.history.go(-owned);
  }, []);

  const handleExpandChange = useCallback((next: boolean) => {
    if (next === expandedRef.current) return;
    if (next) {
      window.history.pushState(
        { ...window.history.state, productStory: true, storyExpanded: true },
        "",
      );
      ownedEntries.current += 1;
      setExpanded(true);
    } else if (ownedEntries.current > 1) {
      // onPop decrements and collapses.
      window.history.back();
    } else {
      setExpanded(false);
    }
  }, []);

  // Resolve the active card only once the swipe settles — updating it
  // mid-scroll re-rendered the heavy cards on every frame.
  const settleTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const handleScroll = () => {
    if (settleTimer.current) clearTimeout(settleTimer.current);
    settleTimer.current = setTimeout(() => {
      const track = trackRef.current;
      if (!track || expandedRef.current) return;
      const mid = track.getBoundingClientRect().left + track.clientWidth / 2;
      let best = 0;
      let bestDist = Infinity;
      Array.from(track.children).forEach((el, i) => {
        const r = (el as HTMLElement).getBoundingClientRect();
        const d = Math.abs(r.left + r.width / 2 - mid);
        if (d < bestDist) {
          bestDist = d;
          best = i;
        }
      });
      setActive(best);
    }, 90);
  };
  useEffect(
    () => () => {
      if (settleTimer.current) clearTimeout(settleTimer.current);
    },
    [],
  );

  return createPortal(
    <div className="fixed inset-0 z-50 md:hidden">
      <m.button
        type="button"
        aria-label="close"
        onClick={requestClose}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        transition={{ duration: 0.25 }}
        className="absolute inset-0 bg-black/70"
      />
      <m.div
        className="relative h-full"
        initial={{ y: "100%" }}
        onAnimationComplete={() => setSettled(true)}
        animate={{ y: 0 }}
        exit={{ y: "100%", transition: { duration: 0.28, ease: [0.32, 0.72, 0, 1] } }}
        transition={{ type: "spring", damping: 30, stiffness: 300, mass: 0.8 }}
      >
      <div
        ref={trackRef}
        onScroll={handleScroll}
        className={`relative flex h-full snap-x snap-mandatory gap-2 overscroll-contain px-[6vw] pb-[max(12px,env(safe-area-inset-bottom))] pt-[max(12px,env(safe-area-inset-top))] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden ${
          expanded ? "overflow-hidden" : "overflow-x-auto overscroll-x-contain"
        }`}
      >
        {products.map((p, i) => (
          <StorySlide
            key={p?.id ?? i}
            product={p}
            isActive={i === active}
            near={mountedIdx.has(i)}
            fetch={Math.abs(i - active) <= 1}
            expanded={expanded && i === active}
            onClose={requestClose}
            onExpandChange={handleExpandChange}
          />
        ))}
      </div>
      </m.div>
    </div>,
    document.body,
  );
};

export default ProductStorySheet;
