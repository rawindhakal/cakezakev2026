"use client";

import { useEffect, useState } from "react";
import * as api from "@/api/apiRoutes";

/** Billing details form state and region/country resolution logic for checkout. */
export interface BillingDetailsState {
  sameAsShipping: boolean;
  name: string;
  mobile: string;
  countryCode: string;
  address: string;
  city: string;
  state: string;
  pincode: string;
  country: string;
  countryId: string;
  regionId: string;
}

const emptyBilling: BillingDetailsState = {
  sameAsShipping: true,
  name: "",
  mobile: "",
  countryCode: "",
  address: "",
  city: "",
  state: "",
  pincode: "",
  country: "",
  countryId: "",
  regionId: "",
};

export default function useBillingDetails() {
  const [billing, setBilling] = useState<BillingDetailsState>(emptyBilling);
  const [countries, setCountries] = useState<any[]>([]);
  const [regions, setRegions] = useState<any[]>([]);
  // Tracks whether region list fetch has completed for the selected country.
  const [regionsLoaded, setRegionsLoaded] = useState(false);

  // Fetch the country list once, for the Billing Country <select>.
  useEffect(() => {
    let cancelled = false;
    api
      .getCountriesWithDefault()
      .then((response: any) => {
        if (cancelled) return;
        setCountries(response?.data || []);
      })
      .catch((error: any) => {
        console.warn("[billing] country fetch failed:", error?.message);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  // Fetch the region list whenever the selected billing country changes.
  useEffect(() => {
    if (!billing.countryId) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- clears stale region list when country is unset; not derivable from render
      setRegions([]);
      setRegionsLoaded(false);
      return;
    }
    let cancelled = false;
    setRegionsLoaded(false);
    api
      .getRegions({ country_id: billing.countryId })
      .then((response: any) => {
        if (cancelled) return;
        setRegions(response?.status == 1 ? response.data || [] : []);
        setRegionsLoaded(true);
      })
      .catch((error: any) => {
        console.warn("[billing] region fetch failed:", error?.message);
        if (cancelled) return;
        setRegions([]);
        setRegionsLoaded(true);
      });
    return () => {
      cancelled = true;
    };
  }, [billing.countryId]);

  const setField = <K extends keyof BillingDetailsState>(
    key: K,
    value: BillingDetailsState[K],
  ) => {
    setBilling((state) => ({ ...state, [key]: value }));
  };

  const setSameAsShipping = (checked: boolean) => setField("sameAsShipping", checked);

  const handleMobileChange = ({
    dialCode,
    rawPhone,
  }: {
    dialCode: string;
    rawPhone: string;
  }) => {
    setBilling((state) => ({ ...state, mobile: rawPhone, countryCode: dialCode }));
  };

  const handleMobileCountryReady = (country: any) => {
    if (!country?.dial_code) return;
    setBilling((state) =>
      state.countryCode ? state : { ...state, countryCode: country.dial_code },
    );
  };

  // Synchronize selected country ID and name, resetting state/region selection.
  const handleCountryChange = (value: string) => {
    const picked = countries.find((c: any) => String(c.id) === value);
    setBilling((state) => ({
      ...state,
      countryId: value,
      country: picked?.name ?? state.country,
      regionId: "",
      state: "",
    }));
  };

  // Synchronize selected region ID and state name with fallback for custom text.
  const handleRegionChange = (value: string) => {
    const picked = regions.find((r: any) => String(r.id) === value);
    setBilling((prev) => ({
      ...prev,
      regionId: value,
      state: picked?.name ?? (regions.length === 0 ? value : prev.state),
    }));
  };

  const reset = () => setBilling(emptyBilling);

  // Flag indicating if country regions list is available.
  const hasRegions = regionsLoaded && regions.length > 0;
  const regionsEmpty = regionsLoaded && regions.length === 0;
  // Send regionId only if matched from a valid country regions list.
  const regionIdToSend =
    regions.length > 0 ? billing.regionId || undefined : undefined;

  // Check if mandatory billing fields are filled.
  const isFilled =
    !!billing.name && !!billing.mobile && !!billing.address && !!billing.city && !!billing.country;

  // Valid if same as shipping or mandatory billing fields are filled.
  const isValid = billing.sameAsShipping || isFilled;

  return {
    billing,
    countries,
    regions,
    regionsLoaded,
    hasRegions,
    regionsEmpty,
    regionIdToSend,
    setSameAsShipping,
    setField,
    handleMobileChange,
    handleMobileCountryReady,
    handleCountryChange,
    handleRegionChange,
    reset,
    isValid,
    isFilled,
  };
}

