"use client";

import { useSelector } from "react-redux";
import { useParams } from "next/navigation";
import useIsHydrated from "@/hooks/useIsHydrated";

// True while the URL zone and the stored city disagree — city coords are stale
// until Header re-seeds them from the zone polygon center.
export default function useZoneCityPending() {
  const routeParams = useParams<{ zone?: string }>();
  const zoneSlugFromUrl = routeParams?.zone ?? null;
  const citySlug = useSelector((state: any) => state.City.city?.slug ?? null);
  const selectedZoneSlug = useSelector(
    (state: any) => state?.LocationModal?.selectedZone?.slug,
  );
  const isHydrated = useIsHydrated();

  return (
    isHydrated &&
    !!zoneSlugFromUrl &&
    zoneSlugFromUrl !== citySlug &&
    zoneSlugFromUrl !== selectedZoneSlug
  );
}
