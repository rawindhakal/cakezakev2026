// Top-level reserved route segments and static assets.
export const RESERVED_ROUTES = new Set([
  // page routes (src/app/*)
  "404",
  "about-us",
  "blog",
  "blogs",
  "brands",
  "cancellation-policy",
  "cart",
  "categories",
  "checkout",
  "contact-us",
  "countries",
  "faqs",
  "order-detail",
  "privacy-policy",
  "product",
  "products",
  "profile",
  "return-and-exchange-policy",
  "search",
  "sellers",
  "shipping-policy",
  "terms-and-conditions",
  "web-payment-status",
  // framework + static assets
  "_next",
  "api",
  "favicon.ico",
  "manifest.json",
  "robots.txt",
  "sitemap.xml",
]);

// Pattern matching valid zone slug strings.
const ZONE_SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

/** Check if a path segment is formatted as a potential zone slug. */
export const isZoneCandidate = (segment?: string | null): boolean =>
  !!segment && !RESERVED_ROUTES.has(segment) && ZONE_SLUG_PATTERN.test(segment);

