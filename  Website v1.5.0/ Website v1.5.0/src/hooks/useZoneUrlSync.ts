import { useEffect, useRef } from "react";
import { useSelector } from "react-redux";
import { usePathname, useParams, useRouter } from "next/navigation";
import useLanguages from "@/hooks/useLanguages";
import { buildLocalizedPath } from "@/utils/canonicalUrl";
import { DEFAULT_LANGUAGE } from "@/utils/languageRoutes";

// Syncs URL zone segment when shop mode toggle changes zone_slug.
const useZoneUrlSync = () => {
  const router = useRouter();
  const pathname = usePathname();
  const params = useParams<{ lang?: string; zone?: string }>();
  const { defaultCode } = useLanguages();
  const zoneSlug = useSelector((state: any) => state?.ShopMode?.zoneSlug);
  const lastSynced = useRef<string | null>(null);
  // The route zone this hook has already seen settle.
  const seenRouteZone = useRef<string | null>(null);

  useEffect(() => {
    const routeZone = params?.zone ?? null;
    // Not on a zone URL — nothing to keep in sync.
    if (!routeZone) return;
    // The URL zone just changed (a zone pick). zoneSlug still describes the
    // PREVIOUS zone until the new home_layout lands, so acting now would
    // bounce the user straight back. Wait for that response instead.
    if (seenRouteZone.current !== routeZone) {
      seenRouteZone.current = routeZone;
      return;
    }
    if (!zoneSlug || zoneSlug === routeZone) return;
    // Don't re-fire for a swap already performed.
    if (lastSynced.current === zoneSlug) return;

    // Extract sub-path by accounting for language and zone route parameters.
    const currentPath = pathname || "/";
    const segments = currentPath.split("/").filter(Boolean);
    const langOccupiesSegment = Boolean(
      params?.lang && params.lang !== (defaultCode || DEFAULT_LANGUAGE),
    );
    const dropCount = (langOccupiesSegment ? 1 : 0) + 1; // +1 for [zone], always present here
    const rest = segments.slice(dropCount);
    const routePath = `/${rest.join("/")}`;

    const nextUrl = buildLocalizedPath({
      lang: params?.lang ?? null,
      zone: zoneSlug,
      path: routePath,
      defaultCode,
    });
    if (!nextUrl || nextUrl === currentPath) return;

    lastSynced.current = zoneSlug;
    const publicQuery = new URLSearchParams(window.location.search);
    const qs = publicQuery.toString();
    // Replace router state; omit router from dependencies to prevent re-triggering effect.
    router.replace(qs ? `${nextUrl}?${qs}` : nextUrl);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [zoneSlug, params?.zone, params?.lang, pathname, defaultCode]);
};

export default useZoneUrlSync;
