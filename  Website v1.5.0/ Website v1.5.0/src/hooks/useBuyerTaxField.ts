"use client";

import { useEffect, useState } from "react";
import { useSelector } from "react-redux";
import * as api from "@/api/apiRoutes";
import { t } from "@/utils/translation";

interface BuyerTaxFieldCoords {
  latitude?: number | string | null;
  longitude?: number | string | null;
}

/**
 * buyer_tax_field of the country the buyer is billed in. The spec follows the
 * buyer's country, not the store's, and country_setting resolves it from the
 * coordinates sent — so pass the billed address's coords when they differ.
 */
export default function useBuyerTaxField(coords?: BuyerTaxFieldCoords) {
  const storeField = useSelector(
    (state: any) => state.CountrySetting?.countrySetting?.buyer_tax_field,
  );
  const [field, setField] = useState<any>(storeField || null);
  const latitude = coords?.latitude;
  const longitude = coords?.longitude;

  useEffect(() => {
    if (latitude == null || longitude == null) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- falls back to the session's country while no billed coords are known
      setField(storeField || null);
      return;
    }
    let cancelled = false;
    api
      .getCountrySetting({ latitude, longitude })
      .then((res: any) => {
        const data =
          typeof res?.data === "string" ? JSON.parse(atob(res.data)) : res?.data;
        if (cancelled) return;
        setField(data?.buyer_tax_field || null);
      })
      .catch((error: any) => {
        console.warn("[buyer-tax] country setting fetch failed:", error?.message);
      });
    return () => {
      cancelled = true;
    };
  }, [latitude, longitude, storeField]);

  const enabled = Number(field?.enabled) === 1;
  const label = field?.label || "";

  // Empty is always valid; a null regex accepts anything the buyer types.
  const validate = (value: string) => {
    const typed = String(value ?? "").trim();
    if (!enabled || !typed) return null;
    const pattern = field?.regex;
    if (!pattern) return null;
    try {
      if (new RegExp(pattern).test(typed.toUpperCase().replace(/\s+/g, ""))) {
        return null;
      }
    } catch {
      return null;
    }
    return (
      t("please_enter_valid_tax_number")?.replace("{label}", label) ||
      `Please enter a valid ${label}.`
    );
  };

  return { enabled, label, regex: field?.regex ?? null, validate };
}
