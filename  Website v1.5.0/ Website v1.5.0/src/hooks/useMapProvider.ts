import { useSelector } from "react-redux";
import {
  DEFAULT_MAP_PROVIDER,
  isSupportedProvider,
} from "../components/maps/types";

// Supported map providers, mirroring components/maps/types.js's MapProvider typedef.
type MapProvider = "google" | "osm";

/** Resolve active map provider from backend settings. */
export default function useMapProvider(): {
  provider: MapProvider | null;
  rawProvider: unknown;
  isLoading: boolean;
  isSupported: boolean;
} {
  const setting = useSelector((state: any) => state.Setting.setting);
  const status = useSelector((state: any) => state.Setting.status);

  // Settings not fetched yet -> treat as loading so we don't flash fallback.
  const isLoading = !setting && status === "loading";

  // Backend may nest it under web settings; accept both top-level and nested.
  const rawProvider =
    setting?.map_provider ??
    setting?.web_settings?.map_provider ??
    null;

  let provider: MapProvider | null = null;
  if (isSupportedProvider(rawProvider)) {
    provider = rawProvider.toLowerCase() as MapProvider;
  } else if (rawProvider == null && !isLoading) {
    // Missing/null provider: fall back to default (or null to force fallback UI).
    provider = DEFAULT_MAP_PROVIDER;
  }

  return {
    provider,
    rawProvider,
    isLoading,
    isSupported: isSupportedProvider(rawProvider),
  };
}

