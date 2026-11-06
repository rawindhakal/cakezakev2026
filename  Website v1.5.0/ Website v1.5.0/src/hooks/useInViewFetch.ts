"use client";

import { useCallback, useEffect, useRef } from "react";

interface UseInViewFetchOptions {
  /** Whether fetching additional items is enabled. */
  enabled: boolean;
  onLoadMore: () => void;
  /** Sentinel viewport margin threshold in pixels. */
  rootMarginPx?: number;
}

/** IntersectionObserver-based infinite scroll sentinel hook for loading more data. */
const useInViewFetch = ({
  enabled,
  onLoadMore,
  rootMarginPx = 300,
}: UseInViewFetchOptions) => {
  const onLoadMoreRef = useRef(onLoadMore);
  useEffect(() => {
    onLoadMoreRef.current = onLoadMore;
  }, [onLoadMore]);

  const enabledRef = useRef(enabled);
  // Latch ref to prevent duplicate triggers during in-flight fetches.
  const firedRef = useRef(false);
  // Visibility ref tracking intersection state changes.
  const inViewRef = useRef(false);
  useEffect(() => {
    if (enabled) firedRef.current = false;
    enabledRef.current = enabled;
    if (enabled && inViewRef.current && !firedRef.current) {
      firedRef.current = true;
      onLoadMoreRef.current();
    }
  }, [enabled]);

  const observerRef = useRef<IntersectionObserver | null>(null);

  const sentinelCallbackRef = useCallback(
    (node: HTMLDivElement | null) => {
      observerRef.current?.disconnect();
      observerRef.current = null;
      inViewRef.current = false;
      if (!node || typeof IntersectionObserver === "undefined") return;

      const observer = new IntersectionObserver(
        (entries) => {
          const entry = entries[0];
          inViewRef.current = !!entry?.isIntersecting;
          if (!entry?.isIntersecting) return;
          if (!enabledRef.current || firedRef.current) return;
          firedRef.current = true;
          onLoadMoreRef.current();
        },
        { rootMargin: `0px 0px ${rootMarginPx}px 0px` },
      );
      observer.observe(node);
      observerRef.current = observer;
    },
    [rootMarginPx],
  );

  return sentinelCallbackRef;
};

export default useInViewFetch;

