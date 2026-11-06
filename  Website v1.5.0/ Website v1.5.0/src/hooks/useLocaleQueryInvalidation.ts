"use client";

import { useEffect, useRef } from "react";
import { useSelector } from "react-redux";
import { useQueryClient } from "@tanstack/react-query";
import { LOCALE_SENSITIVE_KEYS } from "@/utils/queryKeys";

/** Language left the query keys (so SSR seeds match), so refetch on change. */
export default function useLocaleQueryInvalidation() {
  const queryClient = useQueryClient();
  const languageId = useSelector(
    (state: any) => state.Language?.selectedLanguage?.id,
  );
  const previousRef = useRef<unknown>(undefined);

  useEffect(() => {
    const previous = previousRef.current;
    previousRef.current = languageId;
    // First run (and redux-persist's initial rehydrate) is the SSR language.
    if (previous === undefined || previous === languageId) return;
    for (const queryKey of LOCALE_SENSITIVE_KEYS) {
      queryClient.invalidateQueries({ queryKey: [...queryKey] });
    }
  }, [languageId, queryClient]);
}
