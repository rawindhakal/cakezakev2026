"use client";

import { useEffect, useRef } from "react";

interface UseScrollThresholdFetchOptions {
  // Scroll threshold ratio (0..1).
  threshold?: number;
  // Whether pagination fetch is active.
  enabled: boolean;
  onLoadMore: () => void;
  // Container ref to measure scroll progress against.
  containerRef?: React.RefObject<HTMLElement | null>;
}

// Scroll-position based load-more trigger with rAF throttling and latch protection.
const useScrollThresholdFetch = ({
  threshold = 0.7,
  enabled,
  onLoadMore,
  containerRef,
}: UseScrollThresholdFetchOptions) => {
  // Store callbacks in refs to avoid re-binding scroll listeners.
  const onLoadMoreRef = useRef(onLoadMore);
  const enabledRef = useRef(enabled);
  const firedRef = useRef(false);
  // Manual check execution ref.
  const checkRef = useRef<() => void>(() => {});

  // Keep onLoadMore ref synced post-commit.
  useEffect(() => {
    onLoadMoreRef.current = onLoadMore;
  }, [onLoadMore]);

  useEffect(() => {
    // Reset latch when re-enabled and trigger immediate check.
    if (enabled) firedRef.current = false;
    enabledRef.current = enabled;
    checkRef.current();
  }, [enabled]);

  useEffect(() => {
    if (typeof window === "undefined") return;

    let frame = 0;

    const check = () => {
      frame = 0;
      if (!enabledRef.current || firedRef.current) return;

      const container = containerRef?.current;
      if (container) {
        const rect = container.getBoundingClientRect();
        const viewportH = window.innerHeight || 0;
        // Distance from the container's top to the viewport's bottom edge.
        const seen = viewportH - rect.top;
        if (rect.height <= 0 || seen >= rect.height * threshold) {
          firedRef.current = true;
          onLoadMoreRef.current();
        }
        return;
      }

      const doc = document.documentElement;
      const scrolled = window.scrollY || doc.scrollTop || 0;
      const viewport = window.innerHeight || doc.clientHeight || 0;
      const total = doc.scrollHeight || 0;
      const scrollable = total - viewport;

      // Auto-fire if scrollable height is zero or negative.
      if (scrollable <= 0) {
        firedRef.current = true;
        onLoadMoreRef.current();
        return;
      }

      if (scrolled / scrollable >= threshold) {
        firedRef.current = true;
        onLoadMoreRef.current();
      }
    };

    const onScroll = () => {
      if (frame) return;
      frame = window.requestAnimationFrame(check);
    };

    checkRef.current = check;

    // Initial check on mount or enable.
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll, { passive: true });
    return () => {
      if (frame) window.cancelAnimationFrame(frame);
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [threshold]);
};

export default useScrollThresholdFetch;
