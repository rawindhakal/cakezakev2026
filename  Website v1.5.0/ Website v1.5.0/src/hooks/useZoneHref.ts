import { useCallback } from "react";
import { useSelector } from "react-redux";
import { useParams } from "next/navigation";
import { buildLocalizedPath } from "@/utils/canonicalUrl";
import { isZonePrefixableRoute } from "@/utils/zonePrefixable";
import useLanguages from "@/hooks/useLanguages";
import useIsHydrated from "@/hooks/useIsHydrated";
import { useSsrZone } from "@/app/SsrZoneProvider";

// Builds language- and zone-prefixed hrefs for internal links.
const useZoneHref = () => {
  const params = useParams<{ lang?: string; zone?: string }>();
  const { defaultCode } = useLanguages();
  const rawStoredZone = useSelector(
    (state: any) => state?.LocationModal?.selectedZone?.slug,
  );
  // Gate storedZone on hydration state to prevent SSR hydration mismatches.
  const isHydrated = useIsHydrated();
  const storedZone = isHydrated ? rawStoredZone : undefined;

  // Server-rendered zone fallback for zone-less pages.
  const ssrZone = useSsrZone();

  const routeLang = params?.lang ?? null;
  const routeZone = params?.zone ?? null;

  return useCallback(
    (href: string) => {
      if (typeof href !== "string" || !href.startsWith("/")) return href;

      // Determine zone slug priority: route param -> hydrated stored zone -> SSR fallback.
      const zoneSlug = routeZone || storedZone || ssrZone;
      if (!zoneSlug && !routeLang) return href;

      // Split off query/hash so they survive the prefixing.
      const [path, ...tail] = href.split(/(?=[?#])/);
      const rest = path.replace(/^\//, "").split("/").filter(Boolean);

      // Check whether target route accepts zone prefixing.
      const canZone = rest.length === 0 || isZonePrefixableRoute(rest[0]);
      const built = buildLocalizedPath({
        lang: routeLang,
        zone: canZone ? zoneSlug : null,
        path,
        defaultCode,
      });
      return built + tail.join("");
    },
    [routeZone, routeLang, storedZone, ssrZone, defaultCode],
  );
};

export default useZoneHref;
