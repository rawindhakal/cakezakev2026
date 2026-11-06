import { useCallback, useEffect, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import * as api from "@/api/apiRoutes";

// Category tree cache duration (session-wide).
const CATEGORY_TREE_CACHE_MS = Infinity;

interface UseFullCategoryTreeOptions {
  latitude?: number | string;
  longitude?: number | string;
  languageId?: number | string;
}

export default function useFullCategoryTree({
  latitude,
  longitude,
  languageId,
}: UseFullCategoryTreeOptions = {}) {
  // Debounce location/language parameters to avoid redundant tree fetches.
  const [debounced, setDebounced] = useState({ latitude, longitude, languageId });
  useEffect(() => {
    const id = setTimeout(
      () => setDebounced({ latitude, longitude, languageId }),
      300,
    );
    return () => clearTimeout(id);
  }, [latitude, longitude, languageId]);

  const queryClient = useQueryClient();
  // Normalized query key for category tree cache.
  const queryKey = [
    "fullCategoryTree",
    debounced.languageId,
    debounced.latitude == null ? null : Number(debounced.latitude),
    debounced.longitude == null ? null : Number(debounced.longitude),
  ];
  const queryFn = async () => {
    const res: any = await api.getCategories({
      latitude: debounced.latitude,
      longitude: debounced.longitude,
    });
    return Array.isArray(res?.data) ? res.data : [];
  };

  const query = useQuery({
    queryKey,
    queryFn,
    enabled: debounced.latitude != null && debounced.longitude != null,
    // Cache category tree session-wide.
    staleTime: CATEGORY_TREE_CACHE_MS,
    gcTime: CATEGORY_TREE_CACHE_MS,
  });

  // Imperative fetch function for resolving category tree on demand.
  const resolveCategoryTree = useCallback(async (): Promise<any[]> => {
    if (debounced.latitude == null || debounced.longitude == null) return [];
    return queryClient.fetchQuery({
      queryKey: [
        "fullCategoryTree",
        debounced.languageId,
        Number(debounced.latitude),
        Number(debounced.longitude),
      ],
      queryFn: async () => {
        const res: any = await api.getCategories({
          latitude: debounced.latitude,
          longitude: debounced.longitude,
        });
        return Array.isArray(res?.data) ? res.data : [];
      },
      staleTime: CATEGORY_TREE_CACHE_MS,
    });
  }, [queryClient, debounced.languageId, debounced.latitude, debounced.longitude]);

  return { ...query, resolveCategoryTree };
}

