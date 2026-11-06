import { startTransition, useCallback, useTransition } from "react";
import { useRouter } from "next/navigation";

/** Custom hook wrapping Next.js App Router navigation in a React transition. */
export const useAppNavigate = () => {
  const router = useRouter();
  const [isPending, startNavTransition] = useTransition();

  const navigate = useCallback(
    (href: string) => {
      startNavTransition(() => {
        router.push(href);
      });
    },
    [router],
  );

  const replace = useCallback(
    (href: string) => {
      startNavTransition(() => {
        router.replace(href);
      });
    },
    [router],
  );

  return { navigate, replace, isPending };
};

export { startTransition };
