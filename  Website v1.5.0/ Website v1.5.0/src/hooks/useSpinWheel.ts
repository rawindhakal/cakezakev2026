import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";
import { useSelector } from "react-redux";
import * as api from "@/api/apiRoutes";
import type {
  SpinWheelData,
  SpinWheelSegment,
  SpinWheelSpinResult,
  SpinWheelSpins,
} from "@/types/spinWin";

export interface UseSpinWheelParams {
  latitude?: number | string;
  longitude?: number | string;
  /** Gate fetch on readiness. */
  enabled?: boolean;
}

export interface UseSpinWheelResult {
  data: SpinWheelData | null;
  isLoading: boolean;
  isError: boolean;
  spin: () => Promise<{
    segment: SpinWheelSegment | null;
    result: SpinWheelSpinResult | null;
  }>;
  spinning: boolean;
  refetch: () => void;
}

const getUpdatedSpins = (
  result: SpinWheelSpinResult | null | undefined,
): SpinWheelSpins | null => result?.spins ?? null;

// Idempotency key storage key for POST /customer/spin_wheel/spin to prevent duplicate spins on retries.
const IDEMPOTENCY_KEY_STORAGE = "spin_wheel_idempotency_key";

const getOrCreateIdempotencyKey = (): string => {
  if (typeof window === "undefined") return "";
  const existing = window.localStorage.getItem(IDEMPOTENCY_KEY_STORAGE);
  if (existing) return existing;
  const key = crypto.randomUUID();
  window.localStorage.setItem(IDEMPOTENCY_KEY_STORAGE, key);
  return key;
};

const clearIdempotencyKey = (): void => {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(IDEMPOTENCY_KEY_STORAGE);
};

// Fetch spin wheel state and execute spins with optimistic cache updates.
export const useSpinWheel = ({
  latitude,
  longitude,
  enabled = true,
}: UseSpinWheelParams): UseSpinWheelResult => {
  const queryClient = useQueryClient();
  // User ID in query key ensures guest and authenticated state stay separated.
  const userId = useSelector((state: any) => state.User?.user?.id ?? null);
  const queryKey = ["spin-wheel", latitude, longitude, userId];

  const query = useQuery({
    queryKey,
    queryFn: async () => {
      const res = await api.getSpinWheel({ latitude, longitude });
      // API may wrap payload in { data } or return it flat.
      return (res?.data ?? res ?? null) as SpinWheelData | null;
    },
    enabled: enabled && latitude != null && longitude != null,
    staleTime: 60_000,
  });

  const mutation = useMutation({
    mutationFn: async () => {
      const idempotencyKey = getOrCreateIdempotencyKey();
      const res = await api.spinSpinWheel({
        latitude,
        longitude,
        idempotencyKey,
      });
      return (res?.data ?? res ?? null) as SpinWheelSpinResult | null;
    },
    onSuccess: (result) => {
      // Clear key only on confirmed success so retries reuse the same idempotency key.
      clearIdempotencyKey();
      const updatedSpins = getUpdatedSpins(result);
      if (!updatedSpins) return;
      queryClient.setQueryData<SpinWheelData | null>(queryKey, (prev) =>
        prev ? { ...prev, spins: updatedSpins } : prev,
      );
    },
    onSettled: () => {
      // Reconcile spin state and invalidate rewards history cache.
      queryClient.invalidateQueries({ queryKey });
      queryClient.invalidateQueries({ queryKey: ["spin-wheel-rewards"] });
    },
  });

  const spin = async () => {
    const result = await mutation.mutateAsync();
    // Resolve full segment details from cached wheel state.
    const segments = query.data?.segments ?? [];
    const segment =
      segments.find((s) => s.id === result?.segment_id) ??
      segments[result?.segment_index ?? -1] ??
      null;
    return { segment, result };
  };

  return {
    data: query.data ?? null,
    isLoading: query.isLoading,
    isError: query.isError,
    spin,
    spinning: mutation.isPending,
    refetch: query.refetch,
  };
};

export default useSpinWheel;
