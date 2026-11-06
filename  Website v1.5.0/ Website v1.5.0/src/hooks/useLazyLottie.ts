import { useEffect, useState } from "react";

/** Loads a Lottie JSON in its own chunk after mount (or once `enabled`), keeping it out of the initial bundle. */
export default function useLazyLottie<T = any>(
  load: () => Promise<{ default: T }>,
  enabled = true,
): T | null {
  const [data, setData] = useState<T | null>(null);
  useEffect(() => {
    if (!enabled || data) return;
    let alive = true;
    load()
      .then((mod) => {
        if (alive) setData(mod.default);
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled]);
  return data;
}
