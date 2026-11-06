import { useInfiniteQuery } from "@tanstack/react-query";
import * as api from "@/api/apiRoutes";
import type { SpinWheelReward, SpinWheelRewardsSummary } from "@/types/spinWin";

const PAGE_SIZE = 10;

export interface UseSpinWheelRewardsParams {
  latitude?: number | string;
  longitude?: number | string;
  /** Filter by reward type ("promo_code" | "wallet" | "free_delivery"). */
  rewardType?: string;
  /** Gate fetch on location readiness and caller request. */
  enabled?: boolean;
}

export interface UseSpinWheelRewardsResult {
  /** Every loaded page's rows, flattened, for the active filter. */
  rewards: SpinWheelReward[];
  /** Lifetime-wide summary from first page. */
  summary: SpinWheelRewardsSummary | null;
  /** Total row count for the active filter. */
  total: number | null;
  isLoading: boolean;
  isLoadingMore: boolean;
  isError: boolean;
  hasMore: boolean;
  loadMore: () => void;
  refetch: () => void;
}

// Fetches user won-rewards history and summary using paginated infinite query.
export const useSpinWheelRewards = ({
  latitude,
  longitude,
  rewardType,
  enabled = true,
}: UseSpinWheelRewardsParams): UseSpinWheelRewardsResult => {
  const query = useInfiniteQuery({
    queryKey: ["spin-wheel-rewards", latitude, longitude, rewardType],
    queryFn: async ({ pageParam }) => {
      const res = await api.getSpinWheelRewards({
        latitude,
        longitude,
        rewardType,
        limit: PAGE_SIZE,
        offset: pageParam,
      });
      const data = res?.data ?? res ?? null;
      return {
        rewards: (data?.rewards ?? []) as SpinWheelReward[],
        summary: (data?.summary ?? null) as SpinWheelRewardsSummary | null,
        total: (res?.total ?? null) as number | null,
      };
    },
    initialPageParam: 0,
    getNextPageParam: (lastPage, allPages) => {
      const loaded = allPages.reduce((n, p) => n + p.rewards.length, 0);
      if (lastPage.total == null || loaded >= lastPage.total) return undefined;
      return loaded;
    },
    enabled: enabled && latitude != null && longitude != null,
    staleTime: 30_000,
  });

  const pages = query.data?.pages ?? [];
  const rewards = pages.flatMap((p) => p.rewards);
  const total = pages[0]?.total ?? null;
  const summary = pages[0]?.summary ?? null;

  return {
    rewards,
    summary,
    total,
    isLoading: query.isLoading,
    isLoadingMore: query.isFetchingNextPage,
    isError: query.isError,
    hasMore: Boolean(query.hasNextPage),
    loadMore: () => {
      if (query.hasNextPage && !query.isFetchingNextPage) query.fetchNextPage();
    },
    refetch: () => query.refetch(),
  };
};

export default useSpinWheelRewards;
