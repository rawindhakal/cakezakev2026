import { useCallback } from "react";
import enTranslation from "@/utils/en.json";
import { t } from "@/utils/translation";
import useIsHydrated from "./useIsHydrated";

// Hydration-safe translation helper that falls back to English before hydration.
const useT = (): ((label: string) => string) => {
  const hydrated = useIsHydrated();
  return useCallback(
    (label: string) =>
      hydrated ? t(label) : (enTranslation as Record<string, string>)[label],
    [hydrated],
  );
};

export default useT;
