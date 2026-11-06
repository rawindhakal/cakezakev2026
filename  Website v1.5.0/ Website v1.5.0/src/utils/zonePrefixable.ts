// Allowed routes that support optional zone prefixing.
export const ZONE_PREFIXABLE_ROUTES = new Set(["product", "products", "categories"]);

// undefined/empty first segment means home, which is always zone-prefixable.
export const isZonePrefixableRoute = (firstSegment?: string | null): boolean =>
  !firstSegment || ZONE_PREFIXABLE_ROUTES.has(firstSegment);

// Check if pathname represents product listing route regardless of prefixes.
export const isProductsPath = (pathname?: string | null): boolean =>
  (pathname || "").split("/").filter(Boolean).at(-1) === "products";

