import { useCallback, useEffect, useRef, useState } from "react";

/** Optimistic and debounced quantity stepper hook for cart updates. */
export interface FlushCtx {
  reqId: number;
  isStale: () => boolean;
}

export interface UseDebouncedQuantityOptions {
  /** Authoritative qty from the cart store */
  serverQty: number;
  /** Callback to update quantity on server. */
  onCommit?: (qty: number, ctx: FlushCtx) => void | Promise<void>;
  /** Callback to remove item units. */
  onRemove?: (units: number, ctx: FlushCtx) => void | Promise<void>;
  /** Clamp ceiling (allowed/stock); optional */
  max?: number;
  /** Called when a +click is blocked by max */
  onMax?: () => void;
  /** Debounce window (ms), default 500 */
  delay?: number;
}

export interface UseDebouncedQuantityResult {
  displayQty: number;
  increment: () => void;
  decrement: () => void;
  pending: boolean;
}

export function useDebouncedQuantity({
  serverQty,
  onCommit,
  onRemove,
  max,
  onMax,
  delay = 500,
}: UseDebouncedQuantityOptions): UseDebouncedQuantityResult {
  // Optimistic quantity override (null when synced with server).
  const [optimistic, setOptimistic] = useState<number | null>(null);
  // Loading status during pending flush.
  const [pending, setPending] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const targetRef = useRef<number | null>(null);
  // Request sequence ID to prevent race conditions from stale responses.
  const reqSeqRef = useRef(0);
  // Active in-flight flush count.
  const inFlightRef = useRef(0);
  // Base quantity before current click burst.
  const baseRef = useRef<number | null>(null);
  // Live quantity ref across render cycles.
  const liveRef = useRef(serverQty);

  // Callback refs for stable handlers.
  const cbRef = useRef({ onCommit, onRemove, onMax, max });
  useEffect(() => {
    cbRef.current = { onCommit, onRemove, onMax, max };
  });

  // Server quantity ref.
  const serverQtyRef = useRef(serverQty);
  useEffect(() => {
    serverQtyRef.current = serverQty;
  });

  // Capture baseline quantity for click burst.
  const captureBase = useCallback(() => {
    if (baseRef.current == null)
      baseRef.current = liveRef.current ?? serverQty ?? 0;
  }, [serverQty]);

  const displayQty = optimistic != null ? optimistic : serverQty;

  // Clear optimistic override once server catches up.
  useEffect(() => {
    if (optimistic != null && serverQty === optimistic) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- clear optimistic override once server catches up
      setOptimistic(null);
      liveRef.current = serverQty;
    } else if (optimistic == null) {
      liveRef.current = serverQty;
    }
  }, [serverQty, optimistic]);

  const scheduleFlush = useCallback(() => {
    clearTimeout(timer.current ?? undefined);
    timer.current = setTimeout(async () => {
      const target = targetRef.current;
      const base = baseRef.current ?? 0;
      baseRef.current = null;
      if (target == null || target === base) return;

      const reqId = ++reqSeqRef.current;
      const isStale = () => reqId !== reqSeqRef.current;
      const ctx = { reqId, isStale };

      inFlightRef.current += 1;
      setPending(true);
      try {
        if (target < base) {
          await cbRef.current.onRemove?.(base - target, ctx);
        } else {
          await cbRef.current.onCommit?.(target, ctx);
        }
      } catch {
        // Revert optimistic quantity on failure if not stale.
        if (!isStale()) {
          setOptimistic(null);
          liveRef.current = serverQtyRef.current;
        }
      } finally {
        inFlightRef.current = Math.max(0, inFlightRef.current - 1);
        if (inFlightRef.current === 0) setPending(false);
      }
    }, delay);
  }, [delay]);

  const increment = useCallback(() => {
    captureBase();
    const current = liveRef.current ?? 0;
    const cap = cbRef.current.max;
    if (cap != null && current >= cap) {
      cbRef.current.onMax?.();
      return;
    }
    const next = current + 1;
    liveRef.current = next;
    targetRef.current = next;
    setOptimistic(next);
    scheduleFlush();
  }, [captureBase, scheduleFlush]);

  const decrement = useCallback(() => {
    captureBase();
    const current = liveRef.current ?? 0;
    const next = Math.max(0, current - 1);
    liveRef.current = next;
    targetRef.current = next;
    setOptimistic(next);
    scheduleFlush();
  }, [captureBase, scheduleFlush]);

  // Cancel timer and invalidate in-flight requests on unmount.
  useEffect(
    () => () => {
      clearTimeout(timer.current ?? undefined);
      reqSeqRef.current += 1;
    },
    [],
  );

  return { displayQty, increment, decrement, pending };
}

