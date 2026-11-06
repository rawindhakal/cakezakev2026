"use client";

import {
  useState,
  useRef,
  useEffect,
  type Dispatch,
  type SetStateAction,
  type ChangeEvent,
  type KeyboardEvent as ReactKeyboardEvent,
} from "react";
import { useQuery } from "@tanstack/react-query";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogOverlay,
} from "@/components/ui/dialog";
import debounce from "lodash/debounce";
import { t } from "@/utils/translation";
import { useSelector, useDispatch } from "react-redux";
import Image from "next/image";
import { FaLocationCrosshairs } from "react-icons/fa6";
import * as api from "@/api/apiRoutes";
import { setCity } from "@/redux/slices/citySlice";
import { nextZoneRequestSeq } from "@/utils/zoneRequestSeq";
import { toast } from "react-toastify";
import Loader from "../loader/Loader";
import { RiCloseFill } from "react-icons/ri";
import { FiSearch, FiChevronDown } from "react-icons/fi";
import { MdLocationPin } from "react-icons/md";
import MapWrapper from "@/components/maps/MapWrapper";
import type { MapLatLng } from "@/components/maps/types";
import useGeocode from "@/hooks/useGeocode";
import { getPolygonCenter } from "@/utils/helperFunction";
import useLanguages from "@/hooks/useLanguages";
import location from "@/assets/location.svg";
import ThemedSvg from "@/components/notfound/ThemedSvg";
import { useRouter } from "next/navigation";
import {
  setSelectedZone as setSelectedZoneAction,
  setSelectedCountry,
} from "@/redux/slices/locationModalSlice";
import { buildZoneUrl } from "@/utils/zoneUrl";
import { getZoneForChannel } from "@/utils/zoneChannel";
import useDefaultCountry from "@/hooks/useDefaultCountry";

interface LocationZone {
  id: number | string;
  name: string;
  slug?: string;
  boundary: { lat?: number | string; lng?: number | string }[];
  center: { lat: number; lng: number } | null;
}

// Stable fallback — a fresh `[]` per render would re-fire dependent effects.
const NO_ZONES: LocationZone[] = [];

const stripEmoji = (name = "") =>
  name
    .replace(/[\p{Extended_Pictographic}\p{Emoji_Presentation}️‍]/gu, "")
    .trim();

const renderZonesContent = (
  zonesLoading: boolean,
  countryZones: LocationZone[],
  selectedZone: LocationZone | null,
  checkingZone: boolean,
  handleSelectZone: (zone: LocationZone) => void,
) => {
  if (zonesLoading) {
    return (
      <div className="flex flex-wrap gap-2.5">
        {Array.from({ length: 8 }).map((_, i) => (
          <span
            key={i}
            className="h-11 w-32 animate-pulse rounded-lg buttonBackground"
          />
        ))}
      </div>
    );
  }
  if (countryZones.length > 0) {
    return (
      <div className="flex flex-wrap gap-2.5">
        {countryZones.map((zone) => (
          <button
            key={zone.id}
            type="button"
            disabled={checkingZone}
            onClick={() => handleSelectZone(zone)}
            className={`rounded-lg border px-2 py-2.5 text-sm transition duration-200 disabled:opacity-60 ${
              selectedZone?.id === zone.id
                ? "primaryBorderColor primaryColor primaryLightBack font-semibold shadow-sm"
                : "border-gray-200 dark:border-zinc-700 bg-white dark:bg-zinc-900 textColor font-medium shadow-[0_1px_2px_rgba(0,0,0,0.04)] hover:border-[var(--primary-color)] hover:shadow-sm"
            }`}
          >
            {stripEmoji(zone.name)}
          </button>
        ))}
      </div>
    );
  }
  return (
    <p className="mt-2 rounded-xl buttonBackground px-3 py-3 text-xs leading-relaxed SecondaryTextColor">
      {t("no_zones_for_country") ||
        "No delivery zones listed for this country yet. Search or pick a point on the map instead."}
    </p>
  );
};

interface LocationProps {
  showLocation: boolean;
  setShowLocation: Dispatch<SetStateAction<boolean>>;
}

const Location = ({ showLocation, setShowLocation }: LocationProps) => {
  // Resolves the default country (drives the zone fetch); `resolving` shows a
  // loading state until it lands.
  const { resolving: resolvingCountry } = useDefaultCountry();
  const router = useRouter();
  const { parseLangPath } = useLanguages();
  const city = useSelector((state: any) => state.City);
  const setting = useSelector((state: any) => state.Setting);
  const theme = useSelector((state: any) => state.Theme.theme);
  const inputDomRef = useRef<HTMLInputElement>(null);
  const debounceTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const dispatch = useDispatch();
  const [mapView, setMapView] = useState(false);
  const [addressLoading, setAddressLoading] = useState(false);
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  const [center, setCenter] = useState<
    { lat: number; lng: number; streetViewControl?: boolean } | undefined
  >();
  const [inputValue, setInputValue] = useState("");
  const [resultedPlaces, setResultedPlaces] = useState<any>([]);
  const [highlightedIndex, setHighlightedIndex] = useState(-1);
  const [mapSearchValue, setMapSearchValue] = useState("");
  const [mapResults, setMapResults] = useState<any>([]);
  const [mapHighlightedIndex, setMapHighlightedIndex] = useState(-1);
  const mapSearchDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(
    null,
  );
  const [checkingZone, setCheckingZone] = useState(false);

  // Shared with the footer's country selector.
  const selectedCountry = useSelector(
    (state: any) => state?.LocationModal?.selectedCountry,
  );
  const [countryOpen, setCountryOpen] = useState(false);
  const countryRef = useRef<HTMLDivElement>(null);
  const countryOptionRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const [selectedZone, setSelectedZone] = useState<LocationZone | null>(null);

  const { reverseGeocode } = useGeocode();

  interface LocalLocation {
    city?: string | null;
    formatted_address?: string;
    lat: number;
    lng: number;
  }

  const [localLocation, setlocalLocation] = useState<LocalLocation>({
    city: "",
    formatted_address: "",
    lat: Number.parseFloat("0"),
    lng: Number.parseFloat("0"),
  });

  const { data: countries = [] } = useQuery<any[]>({
    queryKey: ["location-modal-countries", city?.city?.latitude, city?.city?.longitude],
    queryFn: () =>
      api
        .getCountries({
          limit: 100,
          offset: 0,
          latitude: city?.city?.latitude,
          longitude: city?.city?.longitude,
        })
        .then((res) => res?.data || []),
    staleTime: 1000 * 60 * 5,
    gcTime: 1000 * 60 * 30,
  });

  useEffect(() => {
    if (!countryOpen) return;
    const handlePointerDown = (e: MouseEvent) => {
      if (
        countryRef.current &&
        !countryRef.current.contains(e.target as Node)
      ) {
        setCountryOpen(false);
      }
    };
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") setCountryOpen(false);
    };
    document.addEventListener("mousedown", handlePointerDown);
    document.addEventListener("keydown", handleKeyDown);
    countryOptionRefs.current[0]?.focus();
    return () => {
      document.removeEventListener("mousedown", handlePointerDown);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [countryOpen]);

  const handleCountryListKeyDown = (
    e: ReactKeyboardEvent<HTMLUListElement>,
  ) => {
    const options = countryOptionRefs.current.filter(
      (el): el is HTMLButtonElement => Boolean(el),
    );
    const currentIndex = options.indexOf(
      document.activeElement as HTMLButtonElement,
    );
    if (e.key === "ArrowDown") {
      e.preventDefault();
      options[(currentIndex + 1) % options.length]?.focus();
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      options[(currentIndex - 1 + options.length) % options.length]?.focus();
    } else if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      const country = countries[currentIndex];
      if (country) handleCountryChange(country);
    }
  };

  // Zone ids are per-country — clear the picked zone.
  const handleCountryChange = (country: any) => {
    setCountryOpen(false);
    if (String(country?.id) === String(selectedCountry?.id)) return;
    setSelectedZone(null);
    dispatch(setSelectedCountry(country));
  };

  // center derived from polygon_boundary (null when empty).
  const { data: countryZones = NO_ZONES, isFetching: zonesLoading } = useQuery<
    LocationZone[]
  >({
    queryKey: ["location-modal-zones", selectedCountry?.id],
    queryFn: () =>
      api.getZones({ country_id: selectedCountry.id }).then((res) =>
        (res?.data || []).map((zone: any) => ({
          id: zone.id,
          name: zone.name,
          // Use verbatim — never derive from name.
          slug: zone.slug,
          boundary: Array.isArray(zone.polygon_boundary)
            ? zone.polygon_boundary
            : [],
          center: getPolygonCenter(zone.polygon_boundary),
        })),
      ),
    enabled: !!selectedCountry?.id,
    staleTime: 1000 * 60 * 5,
    gcTime: 1000 * 60 * 30,
  });

  // Backfill selectedZone once zones load (open effect may run first).
  useEffect(() => {
    if (!showLocation || selectedZone || countryZones.length === 0) return;
    const match = countryZones.find((z) => z.id === city?.city?.id);
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (match) setSelectedZone(match);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [showLocation, countryZones]);

  useEffect(() => {
    if (!showLocation) return;
    // Saved location → reopen straight on the map with the pin there;
    // otherwise seed from GPS.
    const cityLat = Number.parseFloat(city?.city?.latitude);
    const cityLng = Number.parseFloat(city?.city?.longitude);
    if (cityLat && cityLng) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setlocalLocation({
        lat: cityLat,
        lng: cityLng,
        city: city?.city?.name,
        formatted_address: city?.city?.formatted_address,
      });
      setMapView(true);
      const match = countryZones.find((z) => z.id === city?.city?.id);
      if (match) setSelectedZone(match);
      return;
    }
    if (!navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const lat = position.coords.latitude;
        const lng = position.coords.longitude;
        setlocalLocation({ lat: lat, lng: lng });
      },
      () => {},
    );
    // Seed on open only — don't move the pin mid-drag.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [showLocation]);

  useEffect(() => {
    const center = {
      lat: localLocation.lat,
      lng: localLocation.lng,
      streetViewControl: false,
    };
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setCenter(center);
  }, [localLocation.lat, localLocation.lng]);

  useEffect(() => {
    const inputEl = inputDomRef.current;
    if (inputEl) {
      // Forward reference is safe — only used after render.
      // eslint-disable-next-line react-hooks/immutability
      inputEl.addEventListener("keydown", handleKeyDown);
    }
    return () => {
      if (inputEl) {
        inputEl.removeEventListener("keydown", handleKeyDown);
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [resultedPlaces, highlightedIndex]);

  useEffect(() => {
    return () => {
      if (debounceTimeoutRef.current) {
        clearTimeout(debounceTimeoutRef.current);
      }
      if (mapSearchDebounceRef.current) {
        clearTimeout(mapSearchDebounceRef.current);
      }
    };
  }, []);

  // Opens the map on the zone. Local state only — redux is written on
  // confirm, else closing without confirming would still navigate there.
  const handleSelectZone = async (zone: LocationZone) => {
    setErrorMessage("");
    setSelectedZone(zone);
    setMapView(true);
    if (!zone.center) return;
    setCheckingZone(true);
    try {
      const geo = await reverseGeocode(zone.center.lat, zone.center.lng);
      setlocalLocation({
        city: zone.name,
        formatted_address: geo?.formatted_address || zone.name,
        lat: zone.center.lat,
        lng: zone.center.lng,
      });
    } catch (error) {
      console.log("Error resolving zone centre:", error);
      setlocalLocation({
        city: zone.name,
        formatted_address: zone.name,
        lat: zone.center.lat,
        lng: zone.center.lng,
      });
    } finally {
      setCheckingZone(false);
    }
  };

  const handleInputChange = (e: ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setInputValue(value);
    if (debounceTimeoutRef.current) {
      clearTimeout(debounceTimeoutRef.current);
    }

    debounceTimeoutRef.current = setTimeout(() => {
      if (value.length > 2) {
        handleFetchPlaces(value);
      } else {
        setResultedPlaces([]);
      }
    }, 1000);
  };

  const handleCloseLocation = () => {
    setShowLocation(false);
    setMapView(false);
    setSelectedZone(null);
  };

  const handleViewMap = async () => {
    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const lat = position.coords.latitude;
        const lng = position.coords.longitude;
        setlocalLocation({ lat: lat, lng: lng });

        try {
          const result = await reverseGeocode(lat, lng);
          if (result?.formatted_address) {
            setlocalLocation((state) => ({
              ...state,
              formatted_address: result.formatted_address,
            }));
          }
          setMapView(true);
        } catch (error) {
          toast.error(t("provided_api_invalid"));
          console.log("err", error);
        }
      },
      (error: GeolocationPositionError) => {
        console.log("Geolocation error:", error);

        switch (error.code) {
          case error.PERMISSION_DENIED:
            toast.error(
              t("location_permission_denied") ||
                "Please enable location permission in your browser",
            );
            break;
          case error.POSITION_UNAVAILABLE:
            toast.error(
              t("location_unavailable") ||
                "Location information is unavailable",
            );
            break;
          case error.TIMEOUT:
            toast.error(t("location_timeout") || "Location request timed out");
            break;
          default:
            toast.error(
              t("location_error") ||
                "An unknown error occurred while getting location",
            );
            break;
        }
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 0,
      },
    );
  };

  const handleConfirmLocation = async (
    latitude?: number,
    longitude?: number,
    cityName?: string | null,
    formattedAddress?: string,
  ) => {
    try {
      if (errorMessage !== "") {
        setInputValue("");
        toast.error("We are not deliver on this city");
        return;
      }
      const resolvedLat = latitude ?? localLocation.lat;
      const resolvedLng = longitude ?? localLocation.lng;
      const result = await getZoneForChannel({
        latitude: resolvedLat,
        longitude: resolvedLng,
        dispatch,
      });
      if (result?.status == 1) {
        // Supersede any in-flight Header.fetchCity so it can't revert this.
        nextZoneRequestSeq();
        dispatch(
          setCity({
            data: {
              id: result.data.id,
              name: cityName || localLocation.city,
              state: result.data.state,
              slug: result.data.slug,
              formatted_address:
                formattedAddress || localLocation.formatted_address,
              latitude: resolvedLat,
              longitude: resolvedLng,
              min_amount_for_free_delivery:
                result.data.min_amount_for_free_delivery,
              delivery_charge_method: result.data.delivery_charge_method,
              fixed_charge: result.data.fixed_charge,
              per_km_charge: result.data.per_km_charge,
              time_to_travel: result.data.time_to_travel,
              max_deliverable_distance: result.data.max_deliverable_distance,
              distance: result.data.distance,
              zone_id: result.data.zone_id,
              channel: result.data.channel,
            },
          }),
        );
        // Backend-resolved zone is canonical, dispatched now so Header updates
        // this commit. getZone has no name — fall back to chip / zone list.
        const resolvedZoneName =
          result.data?.name ||
          (selectedZone?.id === result.data?.id ? selectedZone?.name : null) ||
          countryZones.find((z) => z.id === result.data?.id)?.name ||
          null;
        if (process.env.NODE_ENV !== "production") {
          console.log("[ZONE TRACE] source=Location.handleConfirmLocation", {
            id: result.data.id,
            name: resolvedZoneName,
            slug: result.data.slug,
          });
        }
        dispatch(
          setSelectedZoneAction({
            id: result.data.id,
            name: resolvedZoneName,
            slug: result.data.slug,
          }),
        );
        setShowLocation(false);
        setInputValue("");
        setResultedPlaces([]);
        setAddressLoading(false);
        setErrorMessage("");
        setMapView(false);

        // Swap the zone segment in the visible URL (window.location, lang
        // stripped then re-added): /bhuj-quick/product/x → /surat-zone/product/x.
        // Resolved slug wins over the chip — a dragged pin never sets the chip.
        const zoneSlug = result.data?.slug || selectedZone?.slug;
        if (zoneSlug && typeof window !== "undefined") {
          const currentPath = window.location.pathname;
          const { lang, rest } = parseLangPath(currentPath);
          const langlessPath = `/${rest.join("/")}`;
          const nextUrl = buildZoneUrl(langlessPath, zoneSlug);
          if (nextUrl && nextUrl !== langlessPath) {
            const localizedNextUrl = lang ? `/${lang}${nextUrl}` : nextUrl;
            // Drop routing-internal params.
            const publicQuery = new URLSearchParams(window.location.search);
            publicQuery.delete("zone");
            publicQuery.delete("slug");
            publicQuery.delete("lang");
            const qs = publicQuery.toString();
            router.push(qs ? `${localizedNextUrl}?${qs}` : localizedNextUrl);
          }
        }
      } else if (result.status == 0) {
        setLoading(false);
        toast.error(t("We_doesn't_deliver_at_selected_city"));
        setShowLocation(true);
      } else {
        setLoading(false);
        setErrorMessage(result.message);
      }
    } catch (error) {
      console.log("error", error);
    }
  };

  // Reverse-geocode a clicked/dragged point and validate its zone.
  const resolvePoint = async (lat: number, lng: number) => {
    setAddressLoading(true);
    try {
      const geo = await reverseGeocode(lat, lng);
      const formatted = geo?.formatted_address || "";
      const res = await getZoneForChannel({
        latitude: lat,
        longitude: lng,
        dispatch,
      });
      if (res?.status === 1) {
        setlocalLocation({
          formatted_address: formatted,
          city: res?.data?.name,
          lat,
          lng,
        });
        setErrorMessage("");
      } else {
        setlocalLocation({
          city: null,
          formatted_address: formatted,
          lat,
          lng,
        });
        setErrorMessage(res?.message || "");
      }
    } catch (error) {
      console.log("err", error);
    } finally {
      setAddressLoading(false);
    }
  };

  const debouncedResolvePoint = useRef(
    debounce((lat: number, lng: number) => resolvePoint(lat, lng), 500),
  ).current;

  const handleMapClick = ({ lat, lng }: MapLatLng) => {
    debouncedResolvePoint(lat, lng);
  };

  const handleDragEnd = ({ lat, lng }: MapLatLng) => {
    resolvePoint(lat, lng);
  };

  const handleMapKeyDown = (e: ReactKeyboardEvent<HTMLInputElement>) => {
    if (!mapResults?.suggestions?.length) return;
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setMapHighlightedIndex((prev) =>
        prev < mapResults.suggestions?.length - 1 ? prev + 1 : 0,
      );
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setMapHighlightedIndex((prev) =>
        prev > 0 ? prev - 1 : mapResults?.suggestions?.length - 1,
      );
    } else if (e.key === "Enter") {
      if (mapHighlightedIndex >= 0) {
        const selected = mapResults?.suggestions[mapHighlightedIndex];
        handleMapSelectLocation(selected?.placePrediction);
      }
    }
  };

  const handleFetchPlaces = async (input: string) => {
    setHighlightedIndex(-1);
    try {
      const response = await api.getPlaces({ input: input });
      if (response.status === 1) {
        setResultedPlaces(response.data);
      } else {
        toast.error(response.message);
      }
    } catch (error) {
      console.error("Error fetching places:", error);
      toast.error("Failed to fetch places");
    }
  };

  const handleKeyDown = (e: KeyboardEvent) => {
    if (!resultedPlaces?.suggestions?.length) return;
    if (e.key === "ArrowDown") {
      setHighlightedIndex((prev) =>
        prev < resultedPlaces.suggestions?.length - 1 ? prev + 1 : 0,
      );
    } else if (e.key === "ArrowUp") {
      setHighlightedIndex((prev) =>
        prev > 0 ? prev - 1 : resultedPlaces?.suggestions?.length - 1,
      );
    } else if (e.key === "Enter") {
      if (highlightedIndex >= 0) {
        const selected = resultedPlaces?.suggestions[highlightedIndex];
        handleSelectLocation(selected?.placePrediction);
      }
    }
  };

  const handleSelectLocation = (place: any) => {
    const description = `${place.structuredFormat.mainText.text}, ${place.structuredFormat.secondaryText.text}`;
    setInputValue(description);
    setResultedPlaces([]);
    getPlacecDetails(place);
    setHighlightedIndex(-1);
  };

  const getPlacecDetails = async (place: any) => {
    try {
      const response = await api.getPlacesDetails({
        placeId: place.placeId,
      });

      if (response.status === 1) {
        const { latitude, longitude } = response?.data?.location ?? {};
        const cityName = response.data.addressComponents?.[0]?.longText;
        const formattedAddress = response.data.formattedAddress;
        setlocalLocation({
          formatted_address: response.data.formattedAddress,
          city: cityName,
          lat: Number.parseFloat(latitude),
          lng: Number.parseFloat(longitude),
        });
        await handleConfirmLocation(
          latitude,
          longitude,
          cityName,
          formattedAddress,
        );
        setAddressLoading(false);
      } else {
        setInputValue("");
        setErrorMessage(response.message);
      }
    } catch (error) {
      console.log("Error fetching place details:", error);
    }
  };

  // Map-view search: recenters the pin without confirming.
  const handleMapSearchInput = (e: ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setMapSearchValue(value);
    if (mapSearchDebounceRef.current) {
      clearTimeout(mapSearchDebounceRef.current);
    }
    mapSearchDebounceRef.current = setTimeout(() => {
      if (value.length > 2) {
        handleFetchMapPlaces(value);
      } else {
        setMapResults([]);
      }
    }, 800);
  };

  const handleFetchMapPlaces = async (input: string) => {
    setMapHighlightedIndex(-1);
    try {
      const response = await api.getPlaces({ input });
      if (response.status === 1) {
        setMapResults(response.data);
      } else {
        toast.error(response.message);
      }
    } catch (error) {
      console.error("Error fetching places:", error);
      toast.error("Failed to fetch places");
    }
  };

  const handleMapSelectLocation = async (place: any) => {
    const description = `${place.structuredFormat.mainText.text}, ${place.structuredFormat.secondaryText.text}`;
    setMapSearchValue(description);
    setMapResults([]);
    setMapHighlightedIndex(-1);
    setAddressLoading(true);
    try {
      const response = await api.getPlacesDetails({ placeId: place.placeId });
      if (response.status === 1) {
        const { latitude, longitude } = response?.data?.location ?? {};
        const res = await getZoneForChannel({
          latitude,
          longitude,
          dispatch,
        });
        setlocalLocation({
          formatted_address: response.data.formattedAddress,
          city: res?.status === 1 ? res?.data?.name : null,
          lat: Number.parseFloat(latitude),
          lng: Number.parseFloat(longitude),
        });
        setErrorMessage(res?.status === 1 ? "" : res?.message || "");
      } else {
        setErrorMessage(response.message);
      }
    } catch (error) {
      console.log("Error fetching place details:", error);
    } finally {
      setAddressLoading(false);
    }
  };

  const handleShowModal = () => {
    setShowLocation(false);
    setMapView(false);
  };

  const hasNoCityConfigured =
    setting.setting?.default_city == null && city?.city == null;
  let overlayClassName;
  if (theme == "light") {
    overlayClassName = hasNoCityConfigured ? "bg-white/100" : "bg-white/10";
  } else {
    overlayClassName = hasNoCityConfigured ? "bg-black/100" : "bg-black/10";
  }

  return (
    <>
      {loading ? (
        <Loader screen={"full"} />
      ) : (
        <Dialog open={showLocation} onOpenChange={handleCloseLocation}>
          <DialogOverlay className={overlayClassName} />
          <DialogContent
            onInteractOutside={(e) => e.preventDefault()}
            className={[
              "max-w-2xl max-h-[92vh] overflow-y-auto",
              // Mobile + tablet: bottom sheet (full width, anchored bottom, slides up).
              "max-lg:left-0 max-lg:top-auto max-lg:bottom-0 max-lg:translate-x-0 max-lg:translate-y-0",
              "max-lg:max-w-none max-lg:max-h-[90dvh] max-lg:!rounded-t-2xl max-lg:!rounded-b-none max-lg:border-x-0 max-lg:border-b-0",
              "max-lg:px-4 max-lg:pt-2 max-lg:pb-[calc(1rem+env(safe-area-inset-bottom))] max-lg:duration-300",
              "max-lg:data-[state=open]:slide-in-from-bottom-full max-lg:data-[state=open]:slide-in-from-left-0 max-lg:data-[state=open]:zoom-in-100",
              "max-lg:data-[state=closed]:slide-out-to-bottom-full max-lg:data-[state=closed]:slide-out-to-left-0 max-lg:data-[state=closed]:zoom-out-100",
            ].join(" ")}
            // Accessible name (the visible heading isn't a Radix Title).
            title={t("select_location")}
          >
            {/* Sheet grab handle (mobile/tablet). */}
            <span
              aria-hidden
              className="mx-auto -mb-2 block h-1 w-10 rounded-full bg-gray-300 dark:bg-zinc-700 lg:hidden"
            />
            <DialogHeader className="text-lg font-extrabold flex-row items-center flex justify-between">
              <div className="flex items-center gap-2">
                <span className="primaryLightBack flex h-8 w-8 items-center justify-center rounded-full primaryColor">
                  <FaLocationCrosshairs size={16} className="primaryColor" />
                </span>
                {t("select_location")}
              </div>
              {setting.setting?.default_city == null && city?.city == null ? (
                <></>
              ) : (
                <div className="closeButtonBg rounded-full p-[8px] gap-[4px] cursor-pointer transition-transform duration-200 hover:scale-110 active:scale-95">
                  <RiCloseFill size={22} onClick={() => handleShowModal()} />
                </div>
              )}
            </DialogHeader>
            <div className="flex">
              {!mapView ? (
                <div className="flex flex-col w-full">
                  {setting?.setting?.web_settings?.web_logo && (
                    <div className="relative mx-auto h-[72px] w-[180px] mb-2">
                      <Image
                        src={setting?.setting?.web_settings?.web_logo}
                        fill
                        className="object-contain"
                        alt="logo"
                      />
                    </div>
                  )}
                  <h2 className="text-center font-bold text-base textColor">
                    {t("select_delivery_location")}
                  </h2>
                  <p className="text-center text-xs SecondaryTextColor mt-1 mb-5">
                    {t("search_delivery_location")}
                  </p>

                  <button
                    type="button"
                    className="group w-full rounded-xl primaryBackColor text-white py-3 px-4 text-sm font-semibold flex items-center justify-center gap-2 shadow-md shadow-black/10 transition duration-200 hover:opacity-95 hover:shadow-lg active:scale-[0.99]"
                    onClick={handleViewMap}
                  >
                    <FaLocationCrosshairs className="transition-transform duration-200 group-hover:rotate-45" />
                    {t("use_my_current_location")}
                  </button>

                  <div className="relative mt-3">
                    <div className="relative">
                      <FiSearch className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-base SecondaryTextColor" />
                      <input
                        ref={inputDomRef}
                        type="text"
                        role="combobox"
                        aria-expanded={resultedPlaces?.suggestions?.length > 0}
                        aria-controls="location-suggestions-listbox"
                        aria-activedescendant={
                          highlightedIndex >= 0
                            ? `location-suggestion-${highlightedIndex}`
                            : undefined
                        }
                        aria-autocomplete="list"
                        value={inputValue}
                        placeholder={t("search_delivery_location")}
                        className="w-full py-3.5 pl-11 pr-14 buttonBackground outline-none rounded-xl text-sm border border-gray-200 dark:border-zinc-700 focus:border-[var(--primary-color)] transition duration-200 placeholder:SecondaryTextColor"
                        onChange={(event) => {
                          handleInputChange(event);
                        }}
                      />
                      <button
                        type="button"
                        onClick={handleViewMap}
                        aria-label={t("use_my_current_location")}
                        className="primaryLightBack absolute right-2 top-1/2 -translate-y-1/2 flex h-9 w-9 items-center justify-center rounded-lg primaryColor transition-opacity duration-200 hover:opacity-80"
                      >
                        <FaLocationCrosshairs size={15} />
                      </button>
                    </div>
                    {resultedPlaces?.suggestions?.length > 0 && (
                      <div
                        id="location-suggestions-listbox"
                        className="absolute z-10 mt-1 w-full bg-white dark:bg-zinc-900 rounded-xl shadow-xl ring-1 ring-black/5 max-h-[220px] overflow-y-auto"
                        role="listbox"
                      >
                        {resultedPlaces?.suggestions?.map((item, index) => (
                          <div
                            role="option"
                            id={`location-suggestion-${index}`}
                            aria-selected={highlightedIndex === index}
                            key={index}
                            className={`flex items-start gap-2 px-3 py-2.5 cursor-pointer transition-colors duration-150 border-b border-gray-50 dark:border-zinc-800 last:border-b-0 ${
                              highlightedIndex === index
                                ? "primaryBackColor text-white"
                                : "hover:bg-gray-50 dark:hover:bg-zinc-800"
                            }`}
                            onClick={() =>
                              handleSelectLocation(item.placePrediction)
                            }
                          >
                            <FaLocationCrosshairs
                              className={`mt-0.5 shrink-0 text-xs ${
                                highlightedIndex === index
                                  ? "text-white"
                                  : "primaryColor"
                              }`}
                            />
                            <div className="min-w-0">
                              <div className="font-medium text-sm truncate">
                                {
                                  item?.placePrediction.structuredFormat
                                    .mainText.text
                                }
                              </div>
                              <div
                                className={`text-xs truncate ${
                                  highlightedIndex === index
                                    ? "text-white/80"
                                    : "SecondaryTextColor"
                                }`}
                              >
                                {
                                  item?.placePrediction.structuredFormat
                                    .secondaryText?.text
                                }
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  <div className="flex items-center justify-between my-5 gap-3">
                    <hr className="flex-grow border-t border-solid border-gray-200 dark:border-zinc-700" />
                    <span className="rounded-full  px-3 py-1 text-[11px] font-semibold SecondaryTextColor uppercase tracking-wider">
                      {t("or") || "OR"}
                    </span>
                    <hr className="flex-grow border-t border-solid border-gray-200 dark:border-zinc-700" />
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full buttonBackground dark:bg-white/10">
                      <MdLocationPin size={20} className="primaryColor" />
                    </span>
                    <div className="flex flex-col gap-0.5 flex-1 min-w-0">
                      <span className="text-sm font-semibold textColor">
                        {t("where_do_we_deliver") || "Pick your delivery zone"}
                      </span>
                      {!zonesLoading && countryZones.length > 0 && (
                        <span className="text-xs SecondaryTextColor">
                          {t("we_deliver_to") || "We deliver to"}{" "}
                          {countryZones.length}{" "}
                          {t("zones_across") || "zones across"}{" "}
                          {selectedCountry?.name}
                          {". "}
                          {t("choose_nearest_zone") ||
                            "Choose the one nearest to you."}
                        </span>
                      )}
                    </div>
                  </div>
                  {resolvingCountry ? (
                    <div className="mb-1 mt-2 flex items-center gap-2 text-sm">
                      <span className="SecondaryTextColor">
                        {t("delivering_to") || "Delivering to"}
                      </span>
                      <span className="h-8 w-24 animate-pulse rounded-[5px] buttonBackground" />
                    </div>
                  ) : (
                    selectedCountry && countries.length > 1 && (
                    <div className="mb-1 mt-2 flex items-center gap-2 text-sm">
                      <span className="SecondaryTextColor">
                        {t("delivering_to") || "Delivering to"}
                      </span>
                      <div className="relative" ref={countryRef}>
                        <button
                          type="button"
                          onClick={() => setCountryOpen((prev) => !prev)}
                          aria-haspopup="listbox"
                          aria-expanded={countryOpen}
                          aria-label={t("select_country") || "Select country"}
                          className={`flex items-center gap-1.5 rounded-[5px] border px-2 py-1.5 transition-colors duration-200 ${
                            countryOpen
                              ? "primaryBorderColor primaryLightBack"
                              : "border-gray-200 dark:border-zinc-700 bg-white dark:bg-zinc-900 hover:border-[var(--primary-color)]"
                          }`}
                        >
                          {selectedCountry?.logo_url && (
                            <Image
                              src={selectedCountry.logo_url}
                              alt=""
                              width={18}
                              height={13}
                              className="h-[13px] w-[18px] shrink-0 rounded-[2px] object-cover"
                            />
                          )}
                          <span className="max-w-[120px] truncate font-semibold textColor">
                            {selectedCountry?.name}
                          </span>
                          <FiChevronDown
                            size={13}
                            className={`shrink-0 opacity-60 transition-transform duration-200 ${
                              countryOpen ? "rotate-180" : ""
                            }`}
                          />
                        </button>

                        {countryOpen && (
                          <ul
                            role="listbox"
                            aria-label={t("select_country") || "Select country"}
                            onKeyDown={handleCountryListKeyDown}
                            className="absolute start-0 top-full z-[60] mt-1.5 max-h-[200px] w-[200px] overflow-y-auto rounded-[5px] border border-gray-200 dark:border-zinc-700 bg-white dark:bg-zinc-900 py-1 shadow-lg"
                          >
                            {countries.map((country, index) => (
                              <li key={country?.id}>
                                <button
                                  type="button"
                                  role="option"
                                  ref={(el) => {
                                    countryOptionRefs.current[index] = el;
                                  }}
                                  tabIndex={index === 0 ? 0 : -1}
                                  aria-selected={
                                    selectedCountry?.id === country?.id
                                  }
                                  onClick={() => handleCountryChange(country)}
                                  className={`flex w-full items-center gap-2 px-2.5 py-1.5 text-start text-[13px] transition-colors duration-200 hover:bg-gray-50 dark:hover:bg-zinc-800 ${
                                    selectedCountry?.id === country?.id
                                      ? "primaryColor font-semibold"
                                      : "textColor"
                                  }`}
                                >
                                  {country?.logo_url && (
                                    <Image
                                      src={country.logo_url}
                                      alt=""
                                      width={18}
                                      height={13}
                                      className="h-[13px] w-[18px] shrink-0 rounded-[2px] object-cover"
                                    />
                                  )}
                                  <span className="flex-1 truncate">
                                    {country?.name}
                                  </span>
                                </button>
                              </li>
                            ))}
                          </ul>
                        )}
                      </div>
                    </div>
                    )
                  )}

                  {resolvingCountry ? (
                    <div className="flex flex-wrap gap-2.5">
                      {Array.from({ length: 8 }).map((_, i) => (
                        <span
                          key={i}
                          className="h-11 w-32 animate-pulse rounded-lg buttonBackground"
                        />
                      ))}
                    </div>
                  ) : (
                    selectedCountry && (
                    <div className="flex flex-col gap-3 mb-4">
                      {renderZonesContent(
                        zonesLoading,
                        countryZones,
                        selectedZone,
                        checkingZone,
                        handleSelectZone,
                      )}

                      {!zonesLoading && countryZones.length > 0 && (
                        <div className="primaryLightBack relative flex items-center gap-3 overflow-hidden rounded-lg py-2 pl-2 pr-28 mt-2 ">
                          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white/70 dark:bg-white/10 ">
                            <MdLocationPin size={24} className="primaryColor" />
                          </span>
                          <div className="flex flex-col ">
                            <span className="text-sm font-bold textColor">
                              {t("dont_see_your_area") ||
                                "Don't see your area?"}
                            </span>
                            <span className="text-xs SecondaryTextColor">
                              {t("always_expanding") ||
                                "We're always expanding. Stay tuned!"}
                            </span>
                          </div>

                          <ThemedSvg
                            src={location}
                            alt=""
                            aria-hidden="true"
                            className="pointer-events-none absolute right-4 top-1/2 h-10 w-12 -translate-y-1/2 [&>svg]:!h-full [&>svg]:!w-full"
                          />
                        </div>
                      )}
                    </div>
                    )
                  )}

                  {errorMessage !== "" && (
                    <div className="mb-3 rounded-xl border border-red-200 bg-red-50 px-3 py-2.5 text-sm text-red-600 dark:border-red-900/40 dark:bg-red-900/20 dark:text-red-400">
                      {errorMessage}
                    </div>
                  )}
                </div>
              ) : (
                <div className="flex flex-col gap-3 w-full">
                  <div className="relative w-full">
                    <FaLocationCrosshairs className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-sm SecondaryTextColor" />
                    <input
                      type="text"
                      role="combobox"
                      aria-expanded={mapResults?.suggestions?.length > 0}
                      aria-controls="map-suggestions-listbox"
                      aria-activedescendant={
                        mapHighlightedIndex >= 0
                          ? `map-suggestion-${mapHighlightedIndex}`
                          : undefined
                      }
                      aria-autocomplete="list"
                      value={mapSearchValue}
                      placeholder={t("search_delivery_location")}
                      className="w-full py-3 pl-9 pr-3 buttonBackground outline-none rounded-xl text-sm border border-transparent focus:border-[var(--primary-color)] transition duration-200 placeholder:textColor"
                      onChange={handleMapSearchInput}
                      onKeyDown={handleMapKeyDown}
                    />
                    {mapResults?.suggestions?.length > 0 && (
                      <div
                        id="map-suggestions-listbox"
                        className="absolute z-[1100] mt-1 w-full bg-white dark:bg-zinc-900 rounded-xl shadow-xl ring-1 ring-black/5 max-h-[220px] overflow-y-auto overflow-hidden"
                        role="listbox"
                      >
                        {mapResults?.suggestions?.map((item, index) => (
                          <div
                            role="option"
                            id={`map-suggestion-${index}`}
                            aria-selected={mapHighlightedIndex === index}
                            key={index}
                            className={`flex items-start gap-2 px-3 py-2.5 cursor-pointer transition-colors duration-150 border-b border-gray-50 dark:border-zinc-800 last:border-b-0 ${
                              mapHighlightedIndex === index
                                ? "primaryBackColor text-white"
                                : "hover:bg-gray-50 dark:hover:bg-zinc-800"
                            }`}
                            onClick={() =>
                              handleMapSelectLocation(item.placePrediction)
                            }
                          >
                            <FaLocationCrosshairs className="mt-0.5 shrink-0 text-xs primaryColor" />
                            <div className="min-w-0">
                              <div className="font-medium text-sm truncate textColor">
                                {
                                  item?.placePrediction.structuredFormat
                                    .mainText.text
                                }
                              </div>
                              <div className="text-xs truncate SecondaryTextColor">
                                {
                                  item?.placePrediction.structuredFormat
                                    .secondaryText?.text
                                }
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                  {selectedZone && (
                    <div className="flex items-center gap-2 text-xs SecondaryTextColor">
                      <span className="inline-flex max-w-[55%] shrink-0 items-center gap-1.5 rounded-full border border-gray-200 px-2.5 py-1 dark:border-zinc-700">
                        <span className="h-2 w-2 shrink-0 rounded-full bg-[#2563eb]" />
                        <span className="truncate whitespace-nowrap textColor font-medium">
                          {selectedZone.name}
                        </span>
                      </span>
                      <span className="min-w-0 flex-1 truncate">
                        <span className="max-md:hidden">
                          {t("drag_pin_in_zone") ||
                            "Drag the pin to your exact address"}
                        </span>
                        <span className="md:hidden">
                          {t("drag_pin_short") || "Drag pin to adjust"}
                        </span>
                      </span>
                    </div>
                  )}
                  <div className="w-full flex flex-col gap-4">
                    {mapView ? (
                      <div className="overflow-hidden rounded-xl ring-1 ring-black/5 shadow-sm">
                        <MapWrapper
                          latitude={center?.lat ?? 0}
                          longitude={center?.lng ?? 0}
                          zoom={11}
                          // Viewport-relative so Confirm stays reachable.
                          height="min(360px, 42vh)"
                          draggableMarker
                          onMarkerDragEnd={handleDragEnd}
                          onMapClick={handleMapClick}
                          polygon={
                            selectedZone?.boundary as MapLatLng[] | undefined
                          }
                          fitToMarkers={(selectedZone?.boundary?.length ?? 0) >= 3}
                        />
                      </div>
                    ) : null}
                  </div>

                  <div className="rounded-xl buttonBackground px-3 py-2.5">
                    <p className="text-sm textColor flex gap-1.5">
                      <FaLocationCrosshairs className="mt-0.5 shrink-0 primaryColor" />
                      <span>
                        <b className="font-semibold">{t("address")}: </b>
                        {addressLoading ? (
                          <span className="SecondaryTextColor">....</span>
                        ) : (
                          localLocation.formatted_address
                        )}
                      </span>
                    </p>
                  </div>

                  <button
                    type="button"
                    onClick={() => handleConfirmLocation()}
                    className="w-full primaryBackColor text-white py-3 rounded-xl text-sm font-semibold shadow-md shadow-black/10 transition duration-200 hover:opacity-95 active:scale-[0.99]"
                  >
                    {t("confirm")}
                  </button>
                  <button
                    type="button"
                    onClick={() => setMapView(false)}
                    className="w-full py-2.5 rounded-xl text-sm font-medium SecondaryTextColor hover:textColor hover:buttonBackground transition-colors duration-200"
                  >
                    {t("go_back")}
                  </button>
                </div>
              )}
            </div>
          </DialogContent>
        </Dialog>
      )}
    </>
  );
};

export default Location;
