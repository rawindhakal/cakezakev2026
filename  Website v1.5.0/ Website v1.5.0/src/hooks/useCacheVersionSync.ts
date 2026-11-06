"use client";

import { useEffect, useRef } from "react";
import { useSelector } from "react-redux";
import { useQueryClient } from "@tanstack/react-query";
import { CACHE_VERSION_GROUP_KEYS } from "@/utils/queryKeys";

const STORAGE_KEY = "cacheVersions";

const readStored = (): Record<string, string> | null => {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
};

const writeStored = (versions: Record<string, string>) => {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(versions));
  } catch {
    // Private mode / blocked storage: in-memory ref still covers this session.
  }
};

/**
 * Settings carry `cache_versions`; a changed group means that data moved, so
 * refetch it. Nothing happens on a backend that doesn't send the field.
 */
export default function useCacheVersionSync() {
  const queryClient = useQueryClient();
  const versions = useSelector(
    (state: any) => state.Setting?.setting?.cache_versions,
  ) as Record<string, string> | undefined;
  // Persisted too, so a reload still notices what changed while the tab was shut.
  const previousRef = useRef<Record<string, string> | null>(null);

  useEffect(() => {
    if (!versions) return;
    const previous = previousRef.current ?? readStored();
    previousRef.current = versions;
    writeStored(versions);
    if (!previous) return;
    for (const group of Object.keys(versions)) {
      if (versions[group] === previous[group]) continue;
      for (const prefix of CACHE_VERSION_GROUP_KEYS[group] ?? []) {
        queryClient.invalidateQueries({ queryKey: [prefix] });
      }
    }
  }, [versions, queryClient]);
}
