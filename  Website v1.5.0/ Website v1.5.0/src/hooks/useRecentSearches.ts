"use client";

import { useCallback, useEffect, useState } from "react";

const STORAGE_KEY = "recent_searches_v1";
const MAX_ITEMS = 8;

const read = (): string[] => {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    const parsed = raw ? JSON.parse(raw) : [];
    return Array.isArray(parsed) ? parsed.filter((s) => typeof s === "string") : [];
  } catch {
    return [];
  }
};

const write = (items: string[]) => {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
  } catch {
    // Storage blocked (private mode) — recent searches just won't persist.
  }
};

// Device-local search history; loaded after mount so SSR and first paint match.
const useRecentSearches = () => {
  const [recent, setRecent] = useState<string[]>([]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- one-time load from localStorage after mount
    setRecent(read());
  }, []);

  const add = useCallback((term: string) => {
    const value = term.trim();
    if (!value) return;
    setRecent((prev) => {
      const next = [
        value,
        ...prev.filter((s) => s.toLowerCase() !== value.toLowerCase()),
      ].slice(0, MAX_ITEMS);
      write(next);
      return next;
    });
  }, []);

  const remove = useCallback((term: string) => {
    setRecent((prev) => {
      const next = prev.filter((s) => s !== term);
      write(next);
      return next;
    });
  }, []);

  const clear = useCallback(() => {
    setRecent([]);
    write([]);
  }, []);

  return { recent, add, remove, clear };
};

export default useRecentSearches;
