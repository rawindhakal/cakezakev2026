"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { usePathname } from "next/navigation";

// Default target key for single-target click handlers.
const SINGLE_TARGET_KEY = "__single__";

// Progress bar state listeners and counter.
type Listener = (active: boolean) => void;
const listeners = new Set<Listener>();
// Active pending navigation request count.
let pendingCount = 0;

const emit = () => {
  const active = pendingCount > 0;
  listeners.forEach((listener) => listener(active));
};

export const subscribeNavProgress = (listener: Listener) => {
  listeners.add(listener);
  listener(pendingCount > 0);
  return () => {
    listeners.delete(listener);
  };
};

export const startNavProgress = () => {
  pendingCount += 1;
  emit();
};

export const stopNavProgress = () => {
  pendingCount = Math.max(pendingCount - 1, 0);
  emit();
};

// Reset pending navigation progress count on route change.
export const resetNavProgress = () => {
  if (pendingCount === 0) return;
  pendingCount = 0;
  emit();
};

/** Wrap navigation click handlers to provide instant progress feedback and prevent double clicks. */
const useNavClick = () => {
  const [pendingKey, setPendingKey] = useState<string | null>(null);
  // Ref tracking pending click state.
  const pendingRef = useRef(false);

  const run = useCallback(
    async (handler: () => void | Promise<void>, key?: string | number) => {
      if (pendingRef.current) return;
      pendingRef.current = true;
      setPendingKey(key != null ? String(key) : SINGLE_TARGET_KEY);
      startNavProgress();
      try {
        await handler();
      } catch (error) {
        console.log("Navigation click failed", error);
        // Clear pending status on handler failure.
        pendingRef.current = false;
        setPendingKey(null);
        stopNavProgress();
        return;
      }
      // Fallback timeout to reset pending status if navigation does not occur.
      setTimeout(() => {
        pendingRef.current = false;
        setPendingKey(null);
        stopNavProgress();
      }, 8000);
    },
    [],
  );

  const pathname = usePathname();
  useEffect(() => {
    pendingRef.current = false;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- syncs with the router's route change, an external system
    setPendingKey(null);
  }, [pathname]);

  const isPending = useCallback(
    (key?: string | number) =>
      pendingKey != null &&
      pendingKey === (key != null ? String(key) : SINGLE_TARGET_KEY),
    [pendingKey],
  );

  return { run, isPending, pending: pendingKey != null };
};

export default useNavClick;

