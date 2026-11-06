"use client";

import { useEffect, useRef } from "react";
import { usePathname, useSearchParams } from "next/navigation";
import { pageview } from "@/utils/gtag";

// GA pageview + scroll reset on client-side route changes.
export default function NavigationEvents() {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  // First view is sent by GA init's onReady (AppContent) — skip first run.
  const isFirstRun = useRef(true);
  // Own ref — isFirstRun is already flipped by the effect above.
  const isFirstScrollRun = useRef(true);

  useEffect(() => {
    if (isFirstRun.current) {
      isFirstRun.current = false;
      return;
    }
    const qs = searchParams?.toString();
    const url = qs ? `${pathname}?${qs}` : pathname || "/";
    pageview(url);
  }, [pathname, searchParams]);

  // scrollRestoration lands on a stale offset (often the footer) before the
  // new page lays out. Pathname only — filter/?tab= changes keep scroll.
  useEffect(() => {
    if (isFirstScrollRun.current) {
      isFirstScrollRun.current = false;
      return;
    }
    window.scrollTo({ top: 0, behavior: "auto" });
  }, [pathname]);

  return null;
}
