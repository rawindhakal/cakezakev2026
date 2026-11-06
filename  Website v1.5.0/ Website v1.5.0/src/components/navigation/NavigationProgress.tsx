"use client";

import { useEffect, useState } from "react";
import { usePathname, useSearchParams } from "next/navigation";
import Loader from "@/components/loader/Loader";
import {
  resetNavProgress,
  startNavProgress,
  stopNavProgress,
  subscribeNavProgress,
} from "@/hooks/useNavClick";

// Full-screen spinner for pending route navigation
const NavigationProgress = () => {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [active, setActive] = useState(false);

  useEffect(() => subscribeNavProgress(setActive), []);

  // Capture global link click events to trigger progress indicator
  useEffect(() => {
    const onDocumentClick = (event: MouseEvent) => {
      // Ignore modified clicks
      if (
        event.defaultPrevented ||
        event.button !== 0 ||
        event.metaKey ||
        event.ctrlKey ||
        event.shiftKey ||
        event.altKey
      ) {
        return;
      }
      const element = event.target as HTMLElement | null;
      // Skip interactive elements inside links
      if (
        element?.closest?.(
          "button, input, select, textarea, label, [role='button'], [data-no-nav-progress]",
        )
      ) {
        return;
      }
      const anchor = element?.closest?.("a");
      const href = anchor?.getAttribute("href");
      if (!href || anchor?.target === "_blank") return;
      // Ignore anchor/mail/phone links
      if (/^(#|mailto:|tel:|javascript:)/i.test(href)) return;
      // Ignore external URLs
      if (/^https?:\/\//i.test(href) && !href.startsWith(window.location.origin)) {
        return;
      }
      // Ignore same-page links
      const target = new URL(href, window.location.href);
      if (
        target.pathname === window.location.pathname &&
        target.search === window.location.search
      ) {
        return;
      }
      // Start progress indicator on next tick
      setTimeout(() => {
        if ((event as any).__noNavProgress) return;
        // Swiper cancels the click a swipe ends with, but only after this
        // document-capture listener has seen it.
        if (event.defaultPrevented) return;
        startNavProgress();
        // 3s safety timeout to clear stuck progress
        setTimeout(stopNavProgress, 3000);
      }, 0);
    };

    document.addEventListener("click", onDocumentClick, true);
    return () => document.removeEventListener("click", onDocumentClick, true);
  }, []);

  // Reset progress state when route changes
  useEffect(() => {
    resetNavProgress();
  }, [pathname, searchParams]);

  // Delay progress spinner display to avoid flickering on fast navigations
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    if (!active) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setVisible(false);
      return;
    }
    const id = setTimeout(() => setVisible(true), 150);
    return () => clearTimeout(id);
  }, [active]);

  if (!visible) return null;

  return <Loader screen="full" />;
};

export default NavigationProgress;
