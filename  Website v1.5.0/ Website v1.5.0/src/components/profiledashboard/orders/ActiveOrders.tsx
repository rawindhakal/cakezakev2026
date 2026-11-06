"use client";

import React, { useState, useEffect, useRef } from "react";
import { useSelector } from "react-redux";
import { t } from "@/utils/translation";
import ActiveOrdersCard from "./ActiveOrdersCard";
import * as api from "@/api/apiRoutes";
import CardSkeleton from "@/components/skeleton/CardSkeleton";
import StaggerIn from "@/components/ui/StaggerIn";
import OrderNotFoundImage from "@/assets/not_found_images/No_Orders.svg";
import NotFound from "../../notfound/NotFound";
import OrderChannelTabs from "./OrderChannelTabs";
import OrderDateFilter, { type OrderDateFilterValue } from "./OrderDateFilter";
import EcomOrdersList from "./EcomOrdersList";
import useInViewFetch from "@/hooks/useInViewFetch";

const ActiveOrders = () => {
  // Map shopMode ("allShop" -> "ecommerce") to active channel tab
  const shopMode = useSelector((state: any) => state.ShopMode.mode);
  const availableModes = useSelector((state: any) => state.ShopMode.availableModes);
  const [activeChannel, setActiveChannel] = useState<string>(
    shopMode === "allShop" ? "ecommerce" : "quick",
  );

  // Keep the tab in sync if the header mode changes while this page is open.
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- syncs tab with header shop mode
    setActiveChannel(shopMode === "allShop" ? "ecommerce" : "quick");
  }, [shopMode]);
  const [loading, setLoading] = useState(false);
  const [activeOrders, setActiveOrders] = useState<any[]>([]);
  const [offset, setOffset] = useState(0);
  const [totalOrders, setTotalOrders] = useState<number | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [dateFilter, setDateFilter] = useState<OrderDateFilterValue | null>(null);

  const ordersPerPage = 10;
  // Minimum duration (ms) to keep load-more skeleton visible
  const MIN_LOAD_MORE_MS = 500;

  const handleFetchActiveOrders = async (isLoadMore = false, newOffset?: number) => {
    const startedAt = Date.now();
    if (isLoadMore) {
      setLoadingMore(true);
    } else {
      setLoading(true);
    }
    try {
      const response = await api.getOrders({
        limit: ordersPerPage,
        offset: newOffset,
        type: 1,
        orderType: "",
        channel: "quick",
        startDate: dateFilter?.startDate,
        endDate: dateFilter?.endDate,
      });
      if (isLoadMore) {
        const elapsed = Date.now() - startedAt;
        if (elapsed < MIN_LOAD_MORE_MS) {
          await new Promise((r) => setTimeout(r, MIN_LOAD_MORE_MS - elapsed));
        }
      }
      if (response.status == 1) {
        if (isLoadMore) {
          setActiveOrders((ord) => [...ord, ...response.data]);
        } else {
          setActiveOrders(response.data);
        }
        setTotalOrders(response.total);
        setHasMore(response.data?.length === ordersPerPage);
        setLoading(false);
        setLoadingMore(false);
      } else {
        setActiveOrders([]);
        setLoading(false);
        setTotalOrders(0);
        setHasMore(false);
        setLoadingMore(false);
      }
    } catch (error: any) {
      console.log("Error", error);
      setLoading(false);
      setLoadingMore(false);
    }
  };

  // Prevents duplicate fetches in StrictMode
  const fetchedDateFilterRef = useRef<OrderDateFilterValue | null | undefined>(
    undefined,
  );

  useEffect(() => {
    if (fetchedDateFilterRef.current === dateFilter) return;
    fetchedDateFilterRef.current = dateFilter;
    setOffset(0);
    handleFetchActiveOrders(false, 0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dateFilter]);

  const handleFetchMore = async () => {
    setLoadingMore(true);
    const newOffset = offset + ordersPerPage;
    setOffset(newOffset);
    handleFetchActiveOrders(true, newOffset);
  };

  // Infinite scroll trigger sentinel hook
  const loadMoreSentinelRef = useInViewFetch({
    enabled: activeChannel !== "ecommerce" && hasMore && !loading && !loadingMore,
    onLoadMore: handleFetchMore,
  });

  return (
    <div className="w-full overflow-hidden rounded-lg border border-[var(--border-color)]">
      <OrderChannelTabs
        active={activeChannel}
        onChange={setActiveChannel}
        status="ongoing"
        dateValue={dateFilter}
        onDateApply={setDateFilter}
        title={t("active_orders")}
      >
        <OrderDateFilter value={dateFilter} onApply={setDateFilter} />
      </OrderChannelTabs>

      {activeChannel === "ecommerce" ? (
        <EcomOrdersList type={1} dateFilter={dateFilter} />
      ) : (
        <>
          {activeOrders.length === 0 && !loading ? (
            <NotFound image={OrderNotFoundImage} title={t("no_order")} />
          ) : (
            <div className="grid grid-cols-1 items-start gap-3 p-3 lg:grid-cols-2 2xl:grid-cols-3">
              {loading
                ? Array?.from({ length: 6 })?.map((_, index) => (
                    <CardSkeleton variant="order" key={index} />
                  ))
                : activeOrders?.map((order, index) => (
                    <StaggerIn key={order?.id} index={index}>
                      <ActiveOrdersCard
                        order={order}
                        channel={activeChannel}
                        shopMode={shopMode}
                        availableModes={availableModes}
                        onCancelled={() => handleFetchActiveOrders(false, 0)}
                      />
                    </StaggerIn>
                  ))}
              {/* Scroll sentinel element */}
              {hasMore && (
                <div ref={loadMoreSentinelRef} className="col-span-full h-px" />
              )}

              {/* Skeletons displayed while loading more orders */}
              {hasMore
                ? Array?.from({ length: loadingMore ? 3 : 2 })?.map(
                    (_, index) => (
                      <CardSkeleton variant="order" key={`m${index}`} />
                    ),
                  )
                : null}
            </div>
          )}
        </>
      )}
    </div>
  );
};

export default ActiveOrders;