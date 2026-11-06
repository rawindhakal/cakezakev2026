"use client";

import { createContext, useContext, type ReactNode } from "react";

// Zone the server rendered a zone-less page with, so useZoneHref can prefix
// links in SSR HTML. Context (not Redux effect) so it's there on first render.
// Fallback only — a /{zone}/ URL param wins.
const SsrZoneContext = createContext<string | null>(null);

export const useSsrZone = () => useContext(SsrZoneContext);

export default function SsrZoneProvider({
  zone = null,
  children,
}: {
  zone?: string | null;
  children: ReactNode;
}) {
  return (
    <SsrZoneContext.Provider value={zone}>{children}</SsrZoneContext.Provider>
  );
}
