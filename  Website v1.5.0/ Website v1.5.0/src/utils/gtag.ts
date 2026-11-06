import { CONSENT_DECLINED, readConsent } from "@/utils/cookieConsent";

// GA4 helpers. _app.js's gtag.js only fires page_view on initial load, so
// client-side route changes must be reported by hand via pageview().

export const GA_MEASUREMENT_ID = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID;

// No ID configured -> every helper no-ops. The consent check is a second
// line of defence: a visitor who accepts then declines keeps the already-
// loaded tag for the session (unmounting <Script> doesn't unload it).
export const isGaEnabled = (): boolean =>
  !!GA_MEASUREMENT_ID &&
  typeof window !== "undefined" &&
  !!(window as any).gtag &&
  readConsent() !== CONSENT_DECLINED;

// Explicit event, not gtag("config", ...) — the tag inits with
// send_page_view:false, so a repeat config call wouldn't emit a page_view.
export const pageview = (url: string): void => {
  if (!isGaEnabled()) return;
  (window as any).gtag("event", "page_view", {
    page_path: url,
    page_location: window.location.href,
    page_title: document.title,
  });
};

// Generic event helper: gtag("event", name, params).
export const event = (name: string, params: Record<string, any> = {}): void => {
  if (!isGaEnabled()) return;
  (window as any).gtag("event", name, params);
};

