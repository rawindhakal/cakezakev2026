import { useCallback } from "react";
import useMapProvider from "./useMapProvider";
import {
  reverseGeocode as reverseGeocodeImpl,
  forwardGeocode as forwardGeocodeImpl,
} from "@/utils/geocode";

// Supported map providers.
type MapProvider = "google" | "osm";

/** Provider-bound geocoding hook supporting Google Maps and OpenStreetMap. */
export default function useGeocode(): {
  provider: MapProvider | null;
  reverseGeocode: (lat: number, lng: number) => Promise<any>;
  forwardGeocode: (query: string) => Promise<{ lat: number; lng: number } | null>;
} {
  const { provider } = useMapProvider();

  // Reverse geocoding helper using active provider.
  const reverseGeocode = useCallback(
    (lat: number, lng: number) =>
      reverseGeocodeImpl(lat, lng, provider as "google" | "osm"),
    [provider]
  );

  const forwardGeocode = useCallback(
    (query: string) => forwardGeocodeImpl(query, provider as "google" | "osm"),
    [provider]
  );

  return { provider, reverseGeocode, forwardGeocode };
}

