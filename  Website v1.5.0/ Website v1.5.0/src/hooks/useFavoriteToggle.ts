import { useCallback, useEffect, useRef, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { toast } from "react-toastify";
import * as api from "@/api/apiRoutes";
import { t } from "@/utils/translation";
import {
  setFavoriteProductIds,
  syncFavoriteId,
} from "@/redux/slices/FavoriteSlice";
import useIsHydrated from "./useIsHydrated";

/** Optimistic and debounced wishlist toggle hook for a single product. */
export interface UseFavoriteToggleOptions {
  productId: number | string;
  /** Callback fired after successful toggle with new liked state. */
  onToggled?: (liked: boolean) => void;
  /** Debounce window (ms), default 500 */
  delay?: number;
  /** Server-provided favorite status. */
  serverLiked?: boolean | number | null;
}

// Products toggled in this page session.
const toggledThisSession = new Set<string>();

export interface UseFavoriteToggleResult {
  liked: boolean;
  pending: boolean;
  /** Logged in — a toggle will actually flip (guests just get a login toast). */
  canToggle: boolean;
  toggle: (e?: { preventDefault?: () => void; stopPropagation?: () => void }) => void;
}

export function useFavoriteToggle({
  productId,
  onToggled,
  delay = 500,
  serverLiked,
}: UseFavoriteToggleOptions): UseFavoriteToggleResult {
  const dispatch = useDispatch();
  const jwtToken = useSelector((state: any) => state.User.jwtToken);
  const favoriteProducts = useSelector(
    (state: any) => state.Favorite.favouriteProductIds,
  );
  // Hydration guard for favourite product IDs.
  const isHydrated = useIsHydrated();

  // True while a flush's API call is in flight — drives caller loading UI.
  const [pending, setPending] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  // Server-side liked state at click burst start.
  const baseRef = useRef<boolean | null>(null);
  // Target liked state for upcoming flush.
  const targetRef = useRef<boolean | null>(null);
  // Unmount tracking ref.
  const mountedRef = useRef(true);

  // Check if product is liked for authenticated user.
  const liked =
    isHydrated && !!jwtToken && !!favoriteProducts?.includes(productId);

  // Live state refs for stable debounced handler.
  const stateRef = useRef({ favoriteProducts, onToggled });
  useEffect(() => {
    stateRef.current = { favoriteProducts, onToggled };
  });

  // Synchronize live ref with liked state.
  const liveRef = useRef(liked);
  useEffect(() => {
    if (baseRef.current == null) liveRef.current = liked;
  });

  // Cancel pending flush on unmount.
  useEffect(
    () => () => {
      mountedRef.current = false;
      clearTimeout(timer.current ?? undefined);
    },
    [],
  );

  const applyIds = useCallback(
    (nextLiked: boolean | null) => {
      const ids = stateRef.current.favoriteProducts || [];
      const nextIds = nextLiked
        ? [...ids.filter((id: any) => id != productId), productId]
        : ids.filter((id: any) => id != productId);
      dispatch(setFavoriteProductIds({ data: nextIds }));
    },
    [dispatch, productId],
  );

  // Sync server-provided favorite state on mount.
  const serverSaysLiked = !!Number(serverLiked);
  useEffect(() => {
    if (!isHydrated || !jwtToken || !serverSaysLiked) return;
    if (baseRef.current != null) return;
    if (toggledThisSession.has(String(productId))) return;
    const ids = stateRef.current.favoriteProducts || [];
    if (ids.some((id: any) => id == productId)) return;
    dispatch(syncFavoriteId({ id: productId, liked: true }));
  }, [isHydrated, jwtToken, serverSaysLiked, productId, dispatch]);

  const scheduleFlush = useCallback(() => {
    clearTimeout(timer.current ?? undefined);
    timer.current = setTimeout(async () => {
      const target = targetRef.current;
      const base = baseRef.current;
      baseRef.current = null;
      if (target == null || target === base) return;

      setPending(true);
      try {
        const response = target
          ? await api.addToFavorite({ product_id: productId })
          : await api.removeFromFavorite({ product_id: productId });

        // Handle already favoritized or removed API responses.
        const alreadyThere =
          response?.status != 1 &&
          (target
            ? /already/i.test(response?.message || "")
            : /not (found|exist|in)/i.test(response?.message || ""));
        if (alreadyThere) {
          applyIds(target);
        } else if (response?.status == 1) {
          stateRef.current.onToggled?.(target);
          toast.success(response.message);
        } else {
          applyIds(base);
          toast.error(response?.message);
        }
      } catch (error) {
        console.log("Error", error);
        applyIds(base);
      } finally {
        if (mountedRef.current) setPending(false);
      }
    }, delay);
  }, [applyIds, delay, productId]);

  const toggle = useCallback(
    (e?: { preventDefault?: () => void; stopPropagation?: () => void }) => {
      e?.preventDefault?.();
      e?.stopPropagation?.();

      if (!jwtToken) {
        // Show login required toast for guest user.
        toast.error(t("required_login_message_for_wishlist"), {
          toastId: "required_login_message_for_wishlist",
        });
        return;
      }

      // Initialize burst baseline.
      if (baseRef.current == null) baseRef.current = liveRef.current;
      toggledThisSession.add(String(productId));

      const next = !liveRef.current;
      liveRef.current = next;
      targetRef.current = next;
      applyIds(next);
      scheduleFlush();
    },
    [applyIds, jwtToken, scheduleFlush, productId],
  );

  return { liked, pending, toggle, canToggle: !!jwtToken };
}

