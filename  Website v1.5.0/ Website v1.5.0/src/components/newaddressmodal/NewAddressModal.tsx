import React, { useEffect, useRef, useState } from "react";
import { Dialog, DialogContent, DialogHeader } from "@/components/ui/dialog";
import { t } from "@/utils/translation";
import { RiCloseFill } from "react-icons/ri";
import * as api from "@/api/apiRoutes";
import { BiCurrentLocation } from "react-icons/bi";
import { FiSearch } from "react-icons/fi";
import Loader from "../loader/Loader";
import { useDispatch, useSelector } from "react-redux";
import { toast } from "react-toastify";
import useGeocode from "@/hooks/useGeocode";
import MapWrapper from "@/components/maps/MapWrapper";
import PhoneNumberInput from "@/components/phonenumberinput/PhoneNumberInput";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import useDir from "@/hooks/useDir";
import { setCity } from "@/redux/slices/citySlice";
import { setSelectedZone } from "@/redux/slices/locationModalSlice";
import type { MapLatLng } from "@/components/maps/types";

interface AddressDetails {
  name: string;
  mobile_num: string;
  country_code?: string;
  alternate_mobile_num: string;
  alternate_country_code?: string;
  address: string;
  landmark: string;
  city: string;
  area: string;
  pincode: string;
  state: string;
  country: string;
  country_id?: string;
  region_id?: string;
  address_type: string;
  is_default: boolean;
}

interface LocalLocation {
  city?: string;
  formatted_address?: string;
  lat?: number;
  lng?: number;
}

interface MapCenter {
  lat?: number;
  lng?: number;
  streetViewControl?: boolean;
}

interface NewAddressModalProps {
  showAddAddres: boolean;
  setShowAddAddres: (value: boolean) => void;
  isAddressSelected: boolean;
  fetchAddress: (opts?: { selectNewestFrom?: any[] }) => void;
  adoptZone?: boolean;
}

const NewAddressModal = ({
  showAddAddres,
  setShowAddAddres,
  isAddressSelected,
  fetchAddress,
  adoptZone = true,
}: NewAddressModalProps) => {
  const dispatch = useDispatch();
  const addresses = useSelector((state: any) => state.Addresses);
  const city = useSelector((state: any) => state.City.city);
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  const dir = useDir();
  const { reverseGeocode, forwardGeocode } = useGeocode();
  const [addressLoading, setAddressLoading] = useState<boolean | string>("");
  const [loading, setLoading] = useState(false);
  const [center, setCenter] = useState<MapCenter | undefined>();
  const [zoneServiceable, setZoneServiceable] = useState<boolean | null>(null);
  const [zoneChecking, setZoneChecking] = useState(false);
  const zoneCheckTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [mobileLengthError, setMobileLengthError] = useState<string | null>(null);
  const [altMobileLengthError, setAltMobileLengthError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<any[]>([]);
  const [searchLoading, setSearchLoading] = useState(false);
  const [showResults, setShowResults] = useState(false);
  const [addressDetails, setaddressDetails] = useState<AddressDetails>({
    name: "",
    mobile_num: "",
    country_code: "",
    alternate_mobile_num: "",
    alternate_country_code: "",
    address: "",
    landmark: "",
    city: "",
    area: "",
    pincode: "",
    state: "",
    country: "",
    country_id: "",
    region_id: "",
    address_type: "Home",
    is_default: true,
  });
  const [regions, setRegions] = useState<any[]>([]);
  const [regionsLoaded, setRegionsLoaded] = useState(false);
  const [countries, setCountries] = useState<any[]>([]);

  const [localLocation, setlocalLocation] = useState<LocalLocation>({
    city: "",
    formatted_address: "",
    lat: parseFloat("0"),
    lng: parseFloat("0"),
  });

  // Auto-detect current geolocation on mount
  useEffect(() => {
    if (isAddressSelected) return;
    if (!navigator.geolocation) return;

    const cityLat = parseFloat(city?.latitude);
    const cityLng = parseFloat(city?.longitude);
    const fallbackToCity = () => {
      if (cityLat && cityLng) {
        setlocalLocation({ lat: cityLat, lng: cityLng });
      }
    };

    navigator.geolocation.getCurrentPosition(
      (position: GeolocationPosition) => {
        setlocalLocation({
          lat: position.coords.latitude,
          lng: position.coords.longitude,
        });
      },
      (error: GeolocationPositionError) => {
        console.warn(
          "Geolocation failed, using city fallback:",
          error?.message,
        );
        fallbackToCity();
      },
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 0 },
    );
  }, [showAddAddres, isAddressSelected, city?.latitude, city?.longitude]);

  useEffect(() => {
    const center = {
      lat: localLocation.lat,
      lng: localLocation.lng,
      streetViewControl: false,
    };
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setCenter(center);
  }, [localLocation.lat, localLocation.lng]);

  // Debounced location search places API call
  useEffect(() => {
    const q = searchQuery.trim();
    if (q.length < 3) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setSearchResults([]);
      setSearchLoading(false);
      return;
    }
    setSearchLoading(true);
    const id = setTimeout(async () => {
      try {
        const response = await api.getPlaces({ input: q });
        const predictions =
          response?.status === 1
            ? (response.data?.suggestions || [])
                .map((s: any) => s.placePrediction)
                .filter(Boolean)
            : [];
        setSearchResults(predictions);
        setShowResults(true);
      } catch (error: any) {
        console.warn("Location search failed:", error?.message);
        setSearchResults([]);
      } finally {
        setSearchLoading(false);
      }
    }, 400);
    return () => clearTimeout(id);
  }, [searchQuery]);

  useEffect(() => {
    if (isAddressSelected) return;
    if (addressDetails.address !== "") {
      const fullAddress = `${addressDetails.address}, ${addressDetails.city}, ${addressDetails.state}, ${addressDetails.country}`;
      forwardGeocode(fullAddress)
        .then((loc) => {
          if (loc) setlocalLocation({ lat: loc.lat, lng: loc.lng });
        })
        .catch((error: any) => {
          console.error("Forward geocode failed:", error?.message);
        });
    }
  }, [addressDetails, isAddressSelected, forwardGeocode]);

  // Fetch country list when modal opens
  useEffect(() => {
    if (!showAddAddres) return;
    let cancelled = false;
    api
      .getCountriesWithDefault()
      .then((response: any) => {
        if (cancelled) return;
        setCountries(response?.data || []);
      })
      .catch((error: any) => {
        console.warn("[address] country fetch failed:", error?.message);
      });
    return () => {
      cancelled = true;
    };
  }, [showAddAddres]);

  // Resolve country ID from saved country name
  useEffect(() => {
    if (addressDetails.country_id || !addressDetails.country || !countries.length) {
      return;
    }
    const match = countries.find(
      (c: any) =>
        String(c.name).trim().toLowerCase() ===
        String(addressDetails.country).trim().toLowerCase(),
    );
    if (match) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setaddressDetails((state) => ({ ...state, country_id: String(match.id) }));
    }
  }, [countries, addressDetails.country, addressDetails.country_id]);

  // Fetch regions on country change
  useEffect(() => {
    if (!showAddAddres || !addressDetails.country_id) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setRegions([]);
      setRegionsLoaded(false);
      return;
    }
    let cancelled = false;
    setRegionsLoaded(false);
    api
      .getRegions({ country_id: addressDetails.country_id })
      .then((response: any) => {
        if (cancelled) return;
        setRegions(response?.status == 1 ? response.data || [] : []);
        setRegionsLoaded(true);
      })
      .catch((error: any) => {
        console.warn("[address] region fetch failed:", error?.message);
        if (cancelled) return;
        setRegions([]);
        setRegionsLoaded(true);
      });
    return () => {
      cancelled = true;
    };
  }, [showAddAddres, addressDetails.country_id]);

  // Reset zone serviceability on modal open
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (showAddAddres) setZoneServiceable(null);
  }, [showAddAddres]);

  useEffect(() => {
    if (isAddressSelected && addresses.selectedEditAddress) {
      const savedLat = parseFloat(addresses.selectedEditAddress.latitude);
      const savedLng = parseFloat(addresses.selectedEditAddress.longitude);
      if (savedLat && savedLng) {
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setlocalLocation({ lat: savedLat, lng: savedLng });
      }
      setaddressDetails({
        name: addresses.selectedEditAddress.name,
        mobile_num: addresses.selectedEditAddress.mobile,
        country_code: addresses.selectedEditAddress.country_code,
        alternate_mobile_num: addresses.selectedEditAddress.alternate_mobile,
        alternate_country_code:
          addresses.selectedEditAddress.alternate_country_code,
        address: addresses.selectedEditAddress.address,
        landmark: addresses.selectedEditAddress.landmark,
        city: addresses.selectedEditAddress.city,
        area: addresses.selectedEditAddress.area,
        pincode: addresses.selectedEditAddress.pincode,
        state: addresses.selectedEditAddress.state,
        country: addresses.selectedEditAddress.country,
        country_id: addresses.selectedEditAddress.country_id
          ? String(addresses.selectedEditAddress.country_id)
          : "",
        region_id: addresses.selectedEditAddress.region_id
          ? String(addresses.selectedEditAddress.region_id)
          : "",
        address_type: addresses.selectedEditAddress.type,
        is_default:
          addresses.selectedEditAddress.is_default === 1 ? true : false,
      });
    } else {
      setlocalLocation({
        lat: parseFloat(city?.latitude ? city?.latitude : 0),
        lng: parseFloat(city?.longitude ? city?.longitude : 0),
      });
      setaddressDetails({
        name: "",
        mobile_num: "",
        alternate_mobile_num: "",
        address: "",
        landmark: "", 
        city: "",
        area: "",
        pincode: "",
        state: "",
        country: "",
        country_id: "",
        region_id: "",
        address_type: "Home",
        is_default: true,
      });
    }
  }, [
    isAddressSelected,
    addresses?.selectedEditAddress,
    showAddAddres,
    city?.latitude,
    city?.longitude,
  ]);

  // Adopt zone for selected address coordinates
  const adoptZoneForAddress = async (lat: number | undefined, lng: number | undefined) => {
    try {
      const result = await api.getZone({
        latitude: lat,
        longitude: lng,
        skipChannel: true,
      });
      if (result?.status != 1 || !result?.data) return;
      if (
        city?.zone_id != null &&
        Number(result.data.zone_id) === Number(city.zone_id)
      ) {
        return;
      }
      dispatch(
        setCity({
          data: {
            id: result.data.id,
            name: addressDetails.city || city?.name || "",
            state: result.data.state,
            formatted_address:
              addressDetails.address || city?.formatted_address || "",
            latitude: lat,
            longitude: lng,
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
      if (result.data.slug) {
        dispatch(
          setSelectedZone({
            id: result.data.zone_id ?? null,
            name: result.data.name ?? null,
            slug: result.data.slug,
          }),
        );
      }
    } catch (error: any) {
      console.warn("[address] zone adopt failed:", error?.message);
    }
  };

  const missingRequired = [
    addressDetails.name,
    addressDetails.mobile_num,
    addressDetails.address,
    addressDetails.landmark,
    addressDetails.area,
    addressDetails.city,
    addressDetails.country_id,
    addressDetails.region_id,
  ].some((v) => !String(v ?? "").trim());

  const handleConfirmAddress = async (e: React.FormEvent) => {
    e.preventDefault();
    if (zoneServiceable === false) {
      toast.error(
        t("address_out_of_service_zone") ||
          "We don't deliver to this location.",
      );
      return;
    }
    if (mobileLengthError || altMobileLengthError) {
      toast.error(mobileLengthError || altMobileLengthError);
      return;
    }
    if (!String(addressDetails.mobile_num || "").trim()) {
      toast.error(t("please_enter_phone_number"));
      return;
    }
    if (!addressDetails.country_id) {
      toast.error(t("please_select_country"));
      return;
    }
    if (!String(addressDetails.region_id || "").trim()) {
      toast.error(t("please_select_state") || "Please select state");
      return;
    }
    let lat = center?.lat;
    let lng = center?.lng;
    // Alt number is optional — skip its dial code when no number was entered.
    const altMobile = String(addressDetails.alternate_mobile_num || "").trim();
    if (!isAddressSelected) {
      setLoading(true);
      const prevIds = (addresses?.allAddresses || []).map((a: any) => a.id);
      const response = await api.addAddress({
        name: addressDetails.name,
        mobile: addressDetails.mobile_num,
        country_code: addressDetails.country_code,
        alternate_country_code: altMobile
          ? addressDetails.alternate_country_code
          : undefined,
        type: addressDetails.address_type,
        address: addressDetails.address,
        landmark: addressDetails.landmark,
        area: addressDetails.area,
        pincode: addressDetails.pincode,
        city: addressDetails.city,
        state: addressDetails.state,
        country: addressDetails.country,
        region_id:
          regions.length > 0 ? addressDetails.region_id || undefined : undefined,
        alternate_mobile: altMobile || undefined,
        latitiude: lat,
        longitude: lng,
        is_default: addressDetails.is_default,
      });
      if (response.status == 1) {
        if (adoptZone) await adoptZoneForAddress(lat, lng);
        fetchAddress({ selectNewestFrom: prevIds });
        setLoading(false);
        toast.success(t("address_added_success"));
        setaddressDetails({
          name: "",
          mobile_num: "",
          alternate_mobile_num: "",
          address: "",
          landmark: "",
          city: "",
          area: "",
          pincode: "",
          state: "",
          country: "",
          region_id: "",
          address_type: "Home",
          is_default: false,
        });
        setShowAddAddres(false);
      } else {
        setLoading(false);
        toast.error(response.message || t("something_went_wrong"));
      }
    } else {
      setLoading(true);
      const response = await api.updateAddress({
        id: addresses.selectedEditAddress.id,
        name: addressDetails.name,
        mobile: addressDetails.mobile_num,
        country_code: addressDetails.country_code,
        alternate_country_code: altMobile
          ? addressDetails.alternate_country_code
          : undefined,
        type: addressDetails.address_type,
        address: addressDetails.address,
        landmark: addressDetails.landmark,
        area: addressDetails.area,
        pincode: addressDetails.pincode,
        city: addressDetails.city,
        state: addressDetails.state,
        country: addressDetails.country,
        region_id:
          regions.length > 0 ? addressDetails.region_id || undefined : undefined,
        alternate_mobile: altMobile || undefined,
        latitiude: lat,
        longitude: lng,
        is_default: addressDetails.is_default,
      });
      if (response.status === 1) {
        if (adoptZone) await adoptZoneForAddress(lat, lng);
        toast.success("Succesfully Updated Address!");
        fetchAddress();
        setShowAddAddres(false);
        setLoading(false);
      } else {
        setLoading(false);
        toast.error(response.message || t("something_went_wrong"));
      }
    }
  };

  const handleHideAddressModal = () => {
    setaddressDetails({
      name: "",
      mobile_num: "",
      country_code: "",
      alternate_mobile_num: "",
      alternate_country_code: "",
      address: "",
      landmark: "",
      city: "",
      area: "",
      pincode: "",
      state: "",
      country: "",
      country_id: "",
      region_id: "",
      address_type: "Home",
      is_default: false,
    });
    setShowAddAddres(false);
  };

  // Debounced serviceability check for coordinates
  const checkZoneServiceable = (lat?: number | null, lng?: number | null) => {
    if (zoneCheckTimer.current) clearTimeout(zoneCheckTimer.current);
    if (lat == null || lng == null) return;
    setZoneChecking(true);
    zoneCheckTimer.current = setTimeout(async () => {
      try {
        const result = await api.getZone({
          latitude: lat,
          longitude: lng,
          skipChannel: true,
        });
        const ok = result?.status == 1 && !!result?.data;
        setZoneServiceable(ok);
        if (!ok) {
          toast.error(
            result?.message ||
              t("address_out_of_service_zone") ||
              "We don't deliver to this location.",
          );
        }
      } catch (error: any) {
        console.warn("[address] zone check failed:", error?.message);
        setZoneServiceable(true);
      } finally {
        setZoneChecking(false);
      }
    }, 500);
  };

  useEffect(() => {
    return () => {
      if (zoneCheckTimer.current) clearTimeout(zoneCheckTimer.current);
    };
  }, []);

  const onMarkerDragEnd = async ({ lat, lng }: MapLatLng) => {
    checkZoneServiceable(lat, lng);
    const prev_latlng = {
      lat: localLocation.lat,
      lng: localLocation.lng,
    };

    setlocalLocation({ lat, lng });
    setAddressLoading(true);
    try {
      const result = await reverseGeocode(lat, lng);
      if (result) {
        if (result.address === "" && result.area === "") {
          setlocalLocation({ lat: prev_latlng.lat, lng: prev_latlng.lng });
        } else {
          setaddressDetails((state) => ({
            ...state,
            address: result.address,
            landmark: result.landmark,
            city: result.city,
            area: result.area,
            pincode: result.pincode,
            country: result.country,
            state: result.state,
          }));
        }
      }
    } catch (error: any) {
      console.log(error);
    } finally {
      setAddressLoading(false);
    }
  };

  const handleSelectSearchResult = async (place: any) => {
    setShowResults(false);
    setSearchResults([]);
    setSearchQuery("");
    setAddressLoading(true);
    try {
      let lat = place?._osm?.lat;
      let lng = place?._osm?.lon;
      if (lat == null || lng == null) {
        const response = await api.getPlacesDetails({ placeId: place.placeId });
        if (response?.status !== 1) {
          toast.error(response?.message || t("something_went_wrong"));
          return;
        }
        lat = response.data.location.latitude;
        lng = response.data.location.longitude;
      }
      const latLng = { lat: parseFloat(lat), lng: parseFloat(lng) };
      setCenter(latLng);
      setlocalLocation(latLng);
      checkZoneServiceable(latLng.lat, latLng.lng);

      const result = await reverseGeocode(latLng.lat, latLng.lng);
      if (result) {
        setaddressDetails((state) => ({
          ...state,
          address: result.address,
          landmark: result.landmark,
          city: result.city,
          area: result.area,
          pincode: result.pincode,
          country: result.country,
          state: result.state,
        }));
      }
    } catch (error: any) {
      console.warn("Place details lookup failed:", error?.message);
      toast.error(t("something_went_wrong"));
    } finally {
      setAddressLoading(false);
    }
  };

  const handleCurrentLocationClick = () => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        async (position: GeolocationPosition) => {
          const latLng = {
            lat: parseFloat(String(position.coords.latitude)),
            lng: parseFloat(String(position.coords.longitude)),
          };
          setCenter(latLng);
          setlocalLocation(latLng);
          checkZoneServiceable(latLng.lat, latLng.lng);

          try {
            const result = await reverseGeocode(latLng.lat, latLng.lng);
            if (result) {
              setaddressDetails((state) => ({
                ...state,
                address: result.address,
                landmark: result.landmark,
                city: result.city,
                area: result.area,
                pincode: result.pincode,
                country: result.country,
                state: result.state,
              }));
            } else {
              console.log("No result found");
            }
          } catch (error: any) {
            console.log(error);
          }
        },
        (error: GeolocationPositionError) => {
          console.error("Error detecting location", error);
        },
        {
          enableHighAccuracy: true,
          timeout: 5000,
          maximumAge: 0,
        },
      );
    } else {
      console.log("geolocation not present in navigator");
    }
  };

  const handleMobileChange = ({
    dialCode,
    rawPhone,
    lengthError,
  }: {
    dialCode: string;
    rawPhone: string;
    lengthError?: string | null;
  }) => {
    setMobileLengthError(lengthError ?? null);
    setaddressDetails((state) => ({
      ...state,
      mobile_num: rawPhone,
      country_code: dialCode,
    }));
  };

  const handleAlternateMobileChange = ({
    dialCode,
    rawPhone,
    lengthError,
  }: {
    dialCode: string;
    rawPhone: string;
    lengthError?: string | null;
  }) => {
    setAltMobileLengthError(lengthError ?? null);
    setaddressDetails((state) => ({
      ...state,
      alternate_mobile_num: rawPhone,
      alternate_country_code: dialCode,
    }));
  };

  const handleMobileCountryReady = (country: any) => {
    if (!country?.dial_code) return;
    setaddressDetails((state) =>
      state.country_code
        ? state
        : { ...state, country_code: country.dial_code },
    );
  };

  const handleAltMobileCountryReady = (country: any) => {
    if (!country?.dial_code) return;
    setaddressDetails((state) =>
      state.alternate_country_code
        ? state
        : { ...state, alternate_country_code: country.dial_code },
    );
  };

  const handleSetAddressType = (value: string) => {
    setaddressDetails((state) => ({ ...state, address_type: value }));
  };

  const handleCheckboxChange = (e: { target: { checked: boolean } }) => {
    setaddressDetails((prevDetails) => ({
      ...prevDetails,
      is_default: e.target.checked,
    }));
  };

  const handleRegionChange = (value: string) => {
    const picked = regions.find((r: any) => String(r.id) === value);
    setaddressDetails((state) => ({
      ...state,
      region_id: value,
      state: picked?.name ?? (regions.length === 0 ? value : state.state),
    }));
  };

  const handleCountryChange = (value: string) => {
    const picked = countries.find((c: any) => String(c.id) === value);
    setaddressDetails((state) => ({
      ...state,
      country_id: value,
      country: picked?.name ?? state.country,
      region_id: "",
      state: "",
    }));
  };

  return (
    <Dialog open={showAddAddres}>
      <DialogContent
        dir={dir === "RTL" ? "rtl" : "ltr"}
        className="max-w-4xl w-[95vw] max-h-[90vh] overflow-y-auto custom-scrollbar"
        title={t("new_address")}
      >
        <DialogHeader>
          <div className="flex flex-row justify-between items-center">
            <h2 className="font-bold text-xl">{t("new_address")}</h2>
            <div className="closeButtonBg rounded-full p-[8px] gap-[4px] cursor-pointer">
              <RiCloseFill size={22} onClick={() => handleHideAddressModal()} />
            </div>
          </div>
        </DialogHeader>
        <div className="p-2 ">
          <div className="flex gap-2.5 flex-col">
            {/* Search bar lives ABOVE the map so it never fights the zoom /
                current-location controls — clean on every screen size. */}
            <div className="relative z-[1001]">
              <FiSearch
                size={16}
                className="absolute start-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none"
              />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onFocus={() => searchResults.length && setShowResults(true)}
                placeholder={t("search_location")}
                className="w-full h-10 rounded-lg border border-gray-200 dark:border-zinc-700 bg-white dark:bg-zinc-800 ps-9 pe-9 text-sm text-black dark:text-zinc-100 text-start outline-none shadow-sm focus:ring-2 focus:ring-[color-mix(in_srgb,var(--primary-color)_25%,transparent)]"
              />
              {searchQuery && (
                <RiCloseFill
                  size={18}
                  className="absolute end-2.5 top-1/2 -translate-y-1/2 text-gray-400 cursor-pointer"
                  onClick={() => {
                    setSearchQuery("");
                    setSearchResults([]);
                    setShowResults(false);
                  }}
                />
              )}
              {showResults && (searchLoading || searchResults.length > 0) && (
                <ul className="absolute inset-x-0 top-full mt-1 z-[1002] max-h-56 overflow-y-auto rounded-lg border border-gray-200 dark:border-zinc-700 bg-white dark:bg-zinc-800 shadow-lg custom-scrollbar">
                  {searchLoading && (
                    <li className="px-3 py-2 text-sm text-gray-400">
                      {t("loading")}
                    </li>
                  )}
                  {!searchLoading &&
                    searchResults.map((place, i) => (
                      <li
                        key={place.placeId || i}
                        className="flex items-start gap-2 px-3 py-2 text-sm text-black dark:text-zinc-100 cursor-pointer hover:bg-gray-100 dark:hover:bg-zinc-700 border-b border-gray-100 dark:border-zinc-700 last:border-0"
                        onClick={() => handleSelectSearchResult(place)}
                      >
                        <BiCurrentLocation
                          size={16}
                          className="mt-0.5 shrink-0 text-gray-400"
                        />
                        <span className="flex flex-col">
                          <span className="font-medium">
                            {place.structuredFormat?.mainText?.text}
                          </span>
                          <span className="text-xs text-gray-500 line-clamp-1">
                            {place.structuredFormat?.secondaryText?.text}
                          </span>
                        </span>
                      </li>
                    ))}
                </ul>
              )}
            </div>
            <div className="w-full relative h-[160px] md:h-[190px]">
              <div
                className="absolute z-[1000] top-[10px] right-[10px] bg-white dark:bg-zinc-800 p-[10px] cursor-pointer text-black dark:text-zinc-100 rounded-sm shadow"
                onClick={handleCurrentLocationClick}
              >
                <BiCurrentLocation size={20} className=" " />
              </div>
              <MapWrapper
                latitude={center?.lat as number}
                longitude={center?.lng as number}
                height="100%"
                className="h-full w-full [&>div]:h-full"
                draggableMarker
                onMarkerDragEnd={onMarkerDragEnd}
              />
            </div>
            {/* Out-of-zone banner — sits under the map, OUTSIDE the loading gate
                below, so it's visible the moment the pin resolves outside a zone
                (the form + its own banner are hidden while addressLoading). */}
            {zoneServiceable === false && (
              <div className="flex items-start gap-2 rounded-lg border border-red-200 dark:border-red-500/30 bg-red-50 dark:bg-red-500/10 px-3 py-2 text-sm font-medium text-red-600 dark:text-red-400">
                {t("address_out_of_service_zone") ||
                  "We don't deliver to this location. Please pick an address inside a serviceable area."}
              </div>
            )}
            <div className="w-full h-full">
              {addressLoading ? (
                <div className="flex items-center justify-center">
                  <Loader
                    width={Math.min(300, window.innerWidth - 40)}
                    height={Math.min(300, window.innerWidth - 40)}
                  />
                </div>
              ) : (
                <div className="flex flex-col">
                  <form
                    className="flex flex-col gap-2.5"
                    onSubmit={handleConfirmAddress}
                  >
                    <div className="flex flex-col gap-1.5">
                      <Label className="block text-sm font-bold border-b border-gray-100 pb-1.5">
                        {t("contact_details")}
                      </Label>
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                        <div className="flex flex-col gap-1 sm:col-span-2">
                          <Label>
                            {t("name")}
                            <span className="text-red-500">*</span>
                          </Label>
                          <Input
                            type="text"
                            className="h-9"
                            placeholder={t("name")}
                            value={addressDetails.name}
                            onChange={(e) =>
                              setaddressDetails((state) => ({
                                ...state,
                                name: e.target.value,
                              }))
                            }
                            required
                          />
                        </div>
                        {/* Dial code varies in width (+1 vs +852), so an overlaid
                            placeholder would collide with it. A label above the field
                            states the purpose without overlapping the dial code. */}
                        <div className="flex flex-col gap-1">
                          <Label>
                            {t("mobileNumber")}
                            <span className="text-red-500">*</span>
                          </Label>
                          <PhoneNumberInput
                            value={addressDetails.mobile_num || ""}
                            countryCode={addressDetails.country_code}
                            onChange={handleMobileChange}
                            onCountryReady={handleMobileCountryReady}
                          />
                        </div>
                        <div className="flex flex-col gap-1">
                          <Label>{t("alt_mobile_no")}</Label>
                          <PhoneNumberInput
                            value={addressDetails.alternate_mobile_num || ""}
                            countryCode={addressDetails.alternate_country_code}
                            onChange={handleAlternateMobileChange}
                            onCountryReady={handleAltMobileCountryReady}
                          />
                        </div>
                      </div>
                    </div>
                    <div className="flex flex-col gap-1.5">
                      <Label className="block text-sm font-bold border-b border-gray-100 pb-1.5">
                        {t("address_details")}
                      </Label>
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                        <div className="flex flex-col gap-1 sm:col-span-2">
                          <Label>
                            {t("address")}
                            <span className="text-red-500">*</span>
                          </Label>
                          <Input
                            type="text"
                            className="h-9"
                            placeholder={t("address")}
                            value={addressDetails.address}
                            onChange={(e) =>
                              setaddressDetails((state) => ({
                                ...state,
                                address: e.target.value,
                              }))
                            }
                            required
                          />
                        </div>
                        <div className="flex flex-col gap-1">
                          <Label>
                            {t("enter_landmark")}
                            <span className="text-red-500">*</span>
                          </Label>
                          <Input
                            type="text"
                            className="h-9"
                            placeholder={t("enter_landmark")}
                            value={addressDetails.landmark}
                            onChange={(e) =>
                              setaddressDetails((state) => ({
                                ...state,
                                landmark: e.target.value,
                              }))
                            }
                            required
                          />
                        </div>
                        <div className="flex flex-col gap-1">
                          <Label>
                            {t("enter_area")}
                            <span className="text-red-500">*</span>
                          </Label>
                          <Input
                            type="text"
                            className="h-9"
                            placeholder={t("enter_area")}
                            value={addressDetails.area}
                            onChange={(e) =>
                              setaddressDetails((state) => ({
                                ...state,
                                area: e.target.value,
                              }))
                            }
                            required
                          />
                        </div>
                        <div className="flex flex-col gap-1">
                          <Label>{t("enter_pincode")}</Label>
                          <Input
                            type="text"
                            className="h-9"
                            placeholder={t("enter_pincode")}
                            value={addressDetails.pincode}
                            onChange={(e) =>
                              setaddressDetails((state) => ({
                                ...state,
                                pincode: e.target.value,
                              }))
                            }
                            required
                          />
                        </div>
                        <div className="flex flex-col gap-1">
                          <Label>
                            {t("enter_city")}
                            <span className="text-red-500">*</span>
                          </Label>
                          <Input
                            type="text"
                            className="h-9"
                            placeholder={t("enter_city")}
                            value={addressDetails.city}
                            onChange={(e) =>
                              setaddressDetails((state) => ({
                                ...state,
                                city: e.target.value,
                              }))
                            }
                            required
                          />
                        </div>
                        <div className="flex flex-col gap-1">
                          <Label>
                            {t("enter_country")}
                            <span className="text-red-500">*</span>
                          </Label>
                          <Select
                            value={addressDetails.country_id || undefined}
                            onValueChange={handleCountryChange}
                          >
                            <SelectTrigger className="h-9 w-full">
                              <SelectValue placeholder={t("enter_country")} />
                            </SelectTrigger>
                            <SelectContent className="z-[1002]">
                              {countries.map((c: any) => (
                                <SelectItem key={c.id} value={String(c.id)}>
                                  {c.name}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </div>
                        <div className="flex flex-col gap-1">
                          <Label>
                            {t("enter_state")}
                            <span className="text-red-500">*</span>
                          </Label>
                          {/* Countries with no region list on file get a
                              free-text field instead of a stuck-empty
                              dropdown — region_id doubles as the typed name. */}
                          {regionsLoaded && regions.length === 0 ? (
                            <Input
                              type="text"
                              className="h-9"
                              placeholder={t("enter_state")}
                              value={addressDetails.region_id || ""}
                              onChange={(e) => handleRegionChange(e.target.value)}
                            />
                          ) : (
                            <Select
                              value={addressDetails.region_id || undefined}
                              onValueChange={handleRegionChange}
                              disabled={!addressDetails.country_id}
                            >
                              <SelectTrigger className="h-9 w-full">
                                <SelectValue placeholder={t("enter_state")} />
                              </SelectTrigger>
                              <SelectContent className="z-[1002]">
                                {regions.map((region: any) => (
                                  <SelectItem
                                    key={region.id}
                                    value={String(region.id)}
                                  >
                                    {region.name}
                                  </SelectItem>
                                ))}
                              </SelectContent>
                            </Select>
                          )}
                        </div>
                      </div>
                    </div>
                    <div className="flex flex-col gap-1.5">
                      <Label className="block text-sm font-bold border-b border-gray-100 pb-1.5">
                        {t("address_type")}
                      </Label>
                      <div className="flex flex-wrap items-center gap-2">
                        {["Home", "Office", "Other"].map((type) => {
                          const labelKey =
                            type === "Home"
                              ? "adress_type_home"
                              : type === "Office"
                                ? "address_type_office"
                                : "address_type_other";
                          const active = addressDetails.address_type === type;
                          return (
                            <button
                              key={type}
                              type="button"
                              onClick={() => handleSetAddressType(type)}
                              className={`rounded-lg border px-4 py-1.5 text-sm font-semibold transition ${
                                active
                                  ? "primaryBackColor primaryColorBorder text-white"
                                  : "cardBorder textColor hover:primaryLightBack"
                              }`}
                            >
                              {t(labelKey)}
                            </button>
                          );
                        })}
                        <label className="ml-auto flex items-center gap-2.5 cursor-pointer">
                          <Checkbox
                            checked={addressDetails.is_default}
                            onCheckedChange={(checked) =>
                              handleCheckboxChange({
                                target: { checked: checked === true },
                              })
                            }
                          />
                          <span className="text-sm font-semibold textColor">
                            {t("set_as_default_address")}
                          </span>
                        </label>
                      </div>
                    </div>
                    <Button
                      type="submit"
                      className="primaryBackColor w-full rounded-lg py-2.5 text-sm font-bold text-white transition hover:opacity-90 disabled:opacity-60 disabled:cursor-not-allowed"
                      disabled={
                        loading ||
                        missingRequired ||
                        zoneChecking ||
                        zoneServiceable === false ||
                        !!mobileLengthError ||
                        !!altMobileLengthError
                      }
                    >
                      {loading
                        ? t("loading")
                        : zoneChecking
                          ? t("checking_serviceability") ||
                            "Checking availability…"
                          : t("confirm_location")}
                    </Button>
                  </form>
                </div>
              )}
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default NewAddressModal;
