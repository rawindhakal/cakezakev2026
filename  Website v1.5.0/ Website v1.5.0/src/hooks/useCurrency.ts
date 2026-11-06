"use client";

import { useSelector } from "react-redux";
import useIsHydrated from "@/hooks/useIsHydrated";

/** App-wide source of truth for zone-aware currency display with hydration protection. */
export interface CurrencyResult {
  currency: string;
  currencyCode: string;
  decimals: number;
}

interface FallbackCurrencySource {
  currency?: string | null;
  currency_code?: string | null;
  decimal_point?: number | string | null;
}

export default function useCurrency(
  lastResortFallback?: FallbackCurrencySource | null,
): CurrencyResult {
  const countrySetting = useSelector(
    (state: any) => state.CountrySetting?.countrySetting,
  );
  const globalSetting = useSelector((state: any) => state.Setting?.setting);
  const hydrated = useIsHydrated();

  if (!hydrated) {
    return { currency: "", currencyCode: "", decimals: 0 };
  }

  const currency =
    countrySetting?.currency ||
    globalSetting?.currency ||
    lastResortFallback?.currency ||
    "";
  const currencyCode =
    countrySetting?.currency_code ||
    globalSetting?.currency_code ||
    lastResortFallback?.currency_code ||
    "";
  const decimals = Number(
    countrySetting?.decimal_point ??
      globalSetting?.decimal_point ??
      lastResortFallback?.decimal_point ??
      0,
  );

  return { currency, currencyCode, decimals };
}
