"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { t } from "@/utils/translation";
import * as api from "@/api/apiRoutes";
import { useSelector } from "react-redux";
import WishlistCard from "../productcards/WishlistCard";
import CardSkeleton from "../skeleton/CardSkeleton";
import NoWishListImage from "@/assets/empty-state/empty-whistlist.svg";
import NotFound from "../notfound/NotFound";
import useInViewFetch from "@/hooks/useInViewFetch";

const Wishlist = () => {
  const lat = useSelector((state: any) => state.City.city?.latitude);
  const lng = useSelector((state: any) => state.City.city?.longitude);
  // Wishlist products state
  const [wishlistProducts, setWishlistProducts] = useState<any[]>([]);
  const [offset, setOffset] = useState(0);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [total, setTotal] = useState<number | null>(null);
  const [isError, setIsError] = useState(false);
  // Flag indicating if all items for current zone have been fetched
  const [reachedEnd, setReachedEnd] = useState(false);

  const itemPerPage = 10;

  // Offsets already requested — blocks duplicate/in-flight pages when the
  // sentinel re-arms or StrictMode double-mounts.
  const requestedOffsetsRef = useRef<Set<number>>(new Set());
  const inFlightRef = useRef(false);

  // Minimum duration (ms) to keep load-more skeleton visible
  const MIN_LOAD_MORE_MS = 500;

  const handleFetchLikedProducts = useCallback(
    async ({
      fetchOffset = 0,
      isAppend = false,
    }: { fetchOffset?: number; isAppend?: boolean } = {}) => {
      if (lat == null || lng == null) return;
      if (inFlightRef.current) return;
      if (isAppend && requestedOffsetsRef.current.has(fetchOffset)) return;
      if (!isAppend) requestedOffsetsRef.current.clear();
      requestedOffsetsRef.current.add(fetchOffset);
      inFlightRef.current = true;
      const startedAt = Date.now();
      if (isAppend) {
        setLoadingMore(true);
      } else {
        setLoading(true);
        setIsError(false);
      }
      try {
        const response = await api.getFavorite({
          latitude: lat,
          longitude: lng,
          limit: itemPerPage,
          offset: fetchOffset,
        });
        if (isAppend) {
          const elapsed = Date.now() - startedAt;
          if (elapsed < MIN_LOAD_MORE_MS) {
            await new Promise((r) => setTimeout(r, MIN_LOAD_MORE_MS - elapsed));
          }
        }
        if (response.status == 1) {
          const rows = Array.isArray(response.data) ? response.data : [];
          setWishlistProducts((prev) => (isAppend ? [...prev, ...rows] : rows));
          setTotal(response.total);
          setReachedEnd(rows.length < itemPerPage);
        } else {
          setReachedEnd(true);
          if (!isAppend) {
            setWishlistProducts([]);
            setTotal(0);
          }
        }
      } catch (error) {
        if (!isAppend) {
          setIsError(true);
        }
        // Don't let the sentinel retry a failing page in a loop.
        setReachedEnd(true);
        requestedOffsetsRef.current.delete(fetchOffset);
        console.log("Error", error);
      } finally {
        inFlightRef.current = false;
        setLoading(false);
        setLoadingMore(false);
      }
    },
    [lat, lng, itemPerPage],
  );

  useEffect(() => {
    // Reset to first page whenever the city (delivery location) changes.
    // eslint-disable-next-line react-hooks/set-state-in-effect -- fetch-on-dependency-change pattern; not derivable from render
    handleFetchLikedProducts({ fetchOffset: 0, isAppend: false });
    setOffset(0);
  }, [lat, lng, handleFetchLikedProducts]);

  // Next page derived from rows already held, not from `offset` state — the
  // sentinel can fire twice before a setState commits.
  const handleLoadMore = () => {
    const nextOffset =
      Math.ceil(wishlistProducts.length / itemPerPage) * itemPerPage;
    if (nextOffset === 0) return;
    setOffset(nextOffset);
    handleFetchLikedProducts({ fetchOffset: nextOffset, isAppend: true });
  };

  const hasMore =
    !reachedEnd && (total ?? 0) > (wishlistProducts?.length ?? 0);
  // Infinite scroll trigger sentinel hook
  const loadMoreSentinelRef = useInViewFetch({
    enabled: hasMore && !loading && !loadingMore,
    onLoadMore: handleLoadMore,
  });

  return (
    <div className="w-full cardBorder rounded-2xl overflow-hidden">
      <div className="backgroundColor flex justify-between px-3 sm:px-5 py-3 sm:py-4 items-center border-b">
        <h2 className="font-bold text-lg sm:text-xl">{t("wishlist")}</h2>
        {!loading && wishlistProducts?.length > 0 && (
          <span className="SecondaryTextColor text-sm font-medium">
            {/* Item count summary display */}
            {reachedEnd ? wishlistProducts.length : (total ?? wishlistProducts.length)}{" "}
            {t("items") || "items"}
          </span>
        )}
      </div>
      <div className="p-2 sm:p-4">
        {loading ? (
          <div className="grid grid-cols-1 xl:grid-cols-2 gap-2.5 sm:gap-3">
            {Array?.from({ length: 8 })?.map((_, index) => (
              <CardSkeleton height={104} padding="3px" key={index} />
            ))}
          </div>
        ) : isError ? (
          <div className="grid place-items-center gap-3 py-10 text-center">
            <p className="font-semibold text-base fontColor">
              {t("something_went_wrong") || "Something went wrong"}
            </p>
            <button
              className="rounded-lg primaryBackColor py-2 px-5 text-white text-sm font-medium"
              onClick={() =>
                handleFetchLikedProducts({ fetchOffset: 0, isAppend: false })
              }
            >
              {t("retry") || t("try_again") || "Retry"}
            </button>
          </div>
        ) : wishlistProducts?.length > 0 ? (
          <div className="grid grid-cols-1 xl:grid-cols-2 gap-2.5 sm:gap-3">
            {wishlistProducts?.map((prdct) => (
              <WishlistCard
                key={prdct?.id}
                product={prdct}
                setWishlistProducts={setWishlistProducts}
                wishlistProducts={wishlistProducts}
                setTotal={setTotal}
                handleFetchLikedProducts={handleFetchLikedProducts}
              />
            ))}

            {/* Scroll sentinel element */}
            {hasMore && <div ref={loadMoreSentinelRef} className="col-span-full h-px" />}

            {/* Skeletons displayed while loading more items */}
            {hasMore &&
              Array?.from({ length: loadingMore ? 4 : 2 })?.map((_, index) => (
                <CardSkeleton
                  height={104}
                  padding="3px"
                  key={`more-${index}`}
                />
              ))}
          </div>
        ) : (
          <NotFound
            image={NoWishListImage}
            title={t("enter_wishlist_message")}
            className="col-span-12"
          />
        )}

      </div>
    </div>
  );
};

export default Wishlist;