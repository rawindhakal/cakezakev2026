import React, { useEffect, useState, useRef } from "react";
import { useSelector } from "react-redux";
import { t } from "@/utils/translation";
import * as api from "@/api/apiRoutes";
import EcomOrdersCard from "./EcomOrdersCard";
import CardSkeleton from "@/components/skeleton/CardSkeleton";
import StaggerIn from "@/components/ui/StaggerIn";
import OrderNotFoundImage from "@/assets/not_found_images/No_Orders.svg";
import NotFound from "../../notfound/NotFound";
import type { OrderDateFilterValue } from "./OrderDateFilter";
import useInViewFetch from "@/hooks/useInViewFetch";

// Shared list component for e-commerce active and history order tabs
const ECOM_ORDERS_PER_PAGE = 10;
// Minimum duration (ms) to keep load-more skeleton visible
const MIN_LOAD_MORE_MS = 500;

interface EcomOrdersListProps {
  type: number;
  dateFilter?: OrderDateFilterValue | null;
}

const EcomOrdersList = ({ type, dateFilter }: EcomOrdersListProps) => {
  const shopMode = useSelector((state: any) => state.ShopMode.mode);
  const availableModes = useSelector((state: any) => state.ShopMode.availableModes);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [orders, setOrders] = useState<any[]>([]);
  const [offset, setOffset] = useState(0);
  const [total, setTotal] = useState<number | null>(null);
  const [isError, setIsError] = useState(false);

  const handleFetch = async (isLoadMore = false, newOffset = 0) => {
    const startedAt = Date.now();
    if (isLoadMore) {
      setLoadingMore(true);
    } else {
      setLoading(true);
      setIsError(false);
    }
    try {
      const response = await api.getEcomOrders({
        limit: ECOM_ORDERS_PER_PAGE,
        offset: newOffset,
        type,
        startDate: dateFilter?.startDate,
        endDate: dateFilter?.endDate,
      });
      if (isLoadMore) {
        const elapsed = Date.now() - startedAt;
        if (elapsed < MIN_LOAD_MORE_MS) {
          await new Promise((r) => setTimeout(r, MIN_LOAD_MORE_MS - elapsed));
        }
      }
      if (response?.status == 1) {
        const data = response?.data || [];
        setOrders((prev) => (isLoadMore ? [...prev, ...data] : data));
        setTotal(response?.total ?? data.length);
      } else if (!isLoadMore) {
        setOrders([]);
        setTotal(0);
      }
    } catch (error: any) {
      console.log("Error", error);
      if (!isLoadMore) {
        setOrders([]);
        setIsError(true);
      }
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  };

  // Prevents duplicate fetches in StrictMode
  const fetchedKeyRef = useRef<string | undefined>(undefined);

  useEffect(() => {
    const key = `${type}:${dateFilter?.startDate ?? ""}:${dateFilter?.endDate ?? ""}`;
    if (fetchedKeyRef.current === key) return;
    fetchedKeyRef.current = key;
    setOffset(0);
    handleFetch(false, 0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [type, dateFilter]);

  const handleFetchMore = () => {
    const newOffset = offset + ECOM_ORDERS_PER_PAGE;
    setOffset(newOffset);
    handleFetch(true, newOffset);
  };

  const hasMore = total != null && orders.length < total;
  // Infinite scroll trigger sentinel hook
  const loadMoreSentinelRef = useInViewFetch({
    enabled: hasMore && !loading && !loadingMore,
    onLoadMore: handleFetchMore,
  });

  return (
    <>
      {isError && !loading ? (
        <div className="grid place-items-center gap-3 p-10 text-center">
          <p className="font-semibold text-base">{t("something_went_wrong")}</p>
          <button
            className="rounded-lg primaryBackColor py-2 px-5 text-white text-sm font-medium"
            onClick={() => handleFetch(false, 0)}
          >
            {t("retry") || t("try_again") || "Retry"}
          </button>
        </div>
      ) : orders.length === 0 && !loading ? (
        <NotFound image={OrderNotFoundImage} title={t("no_order")} />
      ) : (
        <div className="grid grid-cols-1 items-start gap-3 p-3 lg:grid-cols-2 2xl:grid-cols-3">
          {loading
            ? Array.from({ length: 6 }).map((_, index) => (
                <CardSkeleton variant="order" key={index} />
              ))
            : orders.map((order, index) => (
                <StaggerIn key={order?.id} index={index}>
                  <EcomOrdersCard
                    order={order}
                    channel="ecommerce"
                    shopMode={shopMode}
                    availableModes={availableModes}
                    onCancelled={() => handleFetch(false, 0)}
                  />
                </StaggerIn>
              ))}
          {/* Scroll sentinel element */}
          {hasMore && (
            <div ref={loadMoreSentinelRef} className="col-span-full h-px" />
          )}

          {/* Skeletons displayed while loading more orders */}
          {hasMore
            ? Array.from({ length: loadingMore ? 3 : 2 }).map((_, index) => (
                <CardSkeleton variant="order" key={`m${index}`} />
              ))
            : null}
        </div>
      )}
    </>
  );
};

export default EcomOrdersList;
