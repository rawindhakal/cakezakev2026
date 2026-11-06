import { dehydrate, HydrationBoundary } from "@tanstack/react-query";
import { getQueryClient } from "./getQueryClient";

// updatedAt 0 keeps a seed stale, so the client still revalidates on mount.
type Seed = { queryKey: unknown[]; data: unknown; updatedAt?: number };

/** Seed SSR-fetched payloads into the client query cache under matching keys. */
export default function QuerySeed({
  seeds,
  children,
}: {
  seeds: (Seed | null | undefined | false)[];
  children: React.ReactNode;
}) {
  const queryClient = getQueryClient();
  for (const seed of seeds) {
    if (!seed || seed.data == null) continue;
    queryClient.setQueryData(seed.queryKey, seed.data, {
      updatedAt: seed.updatedAt,
    });
  }
  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      {children}
    </HydrationBoundary>
  );
}
