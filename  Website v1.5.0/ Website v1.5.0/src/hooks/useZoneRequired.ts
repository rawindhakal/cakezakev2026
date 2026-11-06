import { useEffect } from "react";
import { useDispatch, useSelector } from "react-redux";
import { useParams, usePathname, useRouter } from "next/navigation";
import { setShowLocation } from "@/redux/slices/locationModalSlice";
import { buildLocalizedPath } from "@/utils/canonicalUrl";
import { isZonePrefixableRoute } from "@/utils/zonePrefixable";
import useLanguages from "@/hooks/useLanguages";
import useIsHydrated from "@/hooks/useIsHydrated";

// Enforces that zone-prefixable routes carry a valid zone in the URL or opens location modal.
const useZoneRequired = () => {
  const router = useRouter();
  const pathname = usePathname();
  const params = useParams<{ lang?: string; zone?: string }>();
  const dispatch = useDispatch();
  const { defaultCode } = useLanguages();
  const storedZoneSlug = useSelector(
    (state: any) => state?.LocationModal?.selectedZone?.slug,
  );
  // Gate enforcement effect until hydration settles.
  const isHydrated = useIsHydrated();

  useEffect(() => {
    if (!isHydrated) return;
    // Already on a zone URL — nothing to enforce.
    if (params?.zone) return;

    const currentPath = pathname || "/";
    const segments = currentPath.split("/").filter(Boolean);
    // Strip leading language segment if present.
    const routeSegments =
      params?.lang && segments[0] === params.lang ? segments.slice(1) : segments;
    const routeName = routeSegments[0];

    if (!isZonePrefixableRoute(routeName)) return;

    if (storedZoneSlug) {
      // Redirect to zone-prefixed URL if zone is stored in Redux.
      const routePath = `/${routeSegments.join("/")}`;
      const nextUrl = buildLocalizedPath({
        lang: params?.lang ?? null,
        zone: storedZoneSlug,
        path: routePath,
        defaultCode,
      });
      if (nextUrl && nextUrl !== currentPath) {
        const qs = new URLSearchParams(window.location.search).toString();
        router.replace(qs ? `${nextUrl}?${qs}` : nextUrl);
      }
      return;
    }

    // Prompt location picker modal if no zone is selected.
    dispatch(setShowLocation(true));
    // router/searchParams deliberately omitted: Next's useRouter() memoizes a
    // fresh object keyed on bfcacheId, which changes on every push/replace —
    // including router here would re-fire this effect right after the
    // router.replace() call above. The params?.zone guard makes that safe
    // (the URL now carries a zone, so the re-fire is a no-op), but it's
    // needless churn; the effect only needs to react to the state listed.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isHydrated, params?.zone, params?.lang, pathname, storedZoneSlug, dispatch, defaultCode]);
};

export default useZoneRequired;
