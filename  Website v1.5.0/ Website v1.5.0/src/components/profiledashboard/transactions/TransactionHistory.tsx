"use client";

import { t } from "@/utils/translation";
import React, { useEffect, useState } from "react";
import TransactionCard from "./TransactionCard";
import * as api from "@/api/apiRoutes";
import CardSkeleton from "@/components/skeleton/CardSkeleton";
import NoTransactionImage from "@/assets/empty-state/no-transaction.svg";
import NotFound from "@/components/notfound/NotFound";
import { LuReceipt } from "react-icons/lu";
import useInViewFetch from "@/hooks/useInViewFetch";

const TransactionHistory = () => {
  const [transaction, setTransaction] = useState<any[]>([]);
  const [offset, setOffset] = useState(0);
  const [total, setTotal] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [isError, setIsError] = useState(false);

  const transactionPerPage = 9;
  // Scroll-triggered load-more can fire the instant the page mounts (page 1
  // shorter than the viewport), before the user has scrolled at all — on a
  // fast connection that resolves before the skeleton ever paints, which
  // reads as "did scrolling do nothing?". Flooring how long the load-more
  // skeleton stays up guarantees at least one visible frame of it.
  const MIN_LOAD_MORE_MS = 500;

  const handleFetchTransactions = async (isLoadMore = false, newOffset?: number) => {
    const startedAt = Date.now();
    if (isLoadMore) {
      setLoadingMore(true);
    } else {
      setLoading(true);
      setIsError(false);
    }
    try {
      const response = await api.getUserTransactions({
        limit: transactionPerPage,
        offset: newOffset,
        type: "transactions",
      });
      if (isLoadMore) {
        const elapsed = Date.now() - startedAt;
        if (elapsed < MIN_LOAD_MORE_MS) {
          await new Promise((r) => setTimeout(r, MIN_LOAD_MORE_MS - elapsed));
        }
      }
      if (response.status == 1) {
        setTransaction((trnscn) =>
          isLoadMore ? [...trnscn, ...response.data] : response.data,
        );
        setTotal(response.total);
        setLoading(false);
        setLoadingMore(false);
      } else {
        setLoading(false);
        setLoadingMore(false);
      }
    } catch (error: any) {
      setLoading(false);
      setLoadingMore(false);
      if (!isLoadMore) {
        setIsError(true);
      }
      console.log("Error", error);
    }
  };

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- initial data fetch on mount
    handleFetchTransactions(false, 0);
  }, []);

  const handleFetchMore = () => {
    const newOffset = offset + transactionPerPage;
    setOffset(newOffset);
    handleFetchTransactions(true, newOffset);
  };

  const hasMore = (total as number) > transaction?.length;
  // Sentinel-based: this list sits inside a wider profile-dashboard page with
  // other content and a footer below it, so a whole-page-height scroll
  // threshold would only fire once basically at the true bottom. A sentinel
  // at the list's own last row fires independent of what's below it.
  const loadMoreSentinelRef = useInViewFetch({
    enabled: hasMore && !loading && !loadingMore,
    onLoadMore: handleFetchMore,
  });

  return (
    <div>
      <div className="w-full cardBorder rounded-2xl overflow-hidden bg-white dark:bg-zinc-900 shadow-sm">
        <div className="flex items-center justify-between gap-3 p-4 md:p-5 border-b border-[color:var(--border-color)]">
          <div className="flex items-center gap-3">
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl primaryLightBack primaryColor">
              <LuReceipt size={18} />
            </span>
            <div>
              <h2 className="text-base md:text-lg font-bold fontColor leading-tight">
                {t("transaction_history")}
              </h2>
              {/* {total != null && total > 0 && (
                                  <p className="text-xs SecondaryTextColor">
                                    {total} {t("transactions")}
                                  </p>
                                )} */}
            </div>
          </div>
        </div>
        <div className="p-2 sm:p-3">
          <div className="grid grid-cols-12">
            {loading ? (
              Array?.from({ length: 6 })?.map((_, index) => {
                return (
                  <div
                    className="col-span-12  md:col-span-6 lg:col-span-6 "
                    key={index}
                  >
                    <CardSkeleton height={200} padding="p-4" key={index} />
                  </div>
                );
              })
            ) : isError ? (
              <div className="col-span-12 grid place-items-center gap-3 py-10 text-center">
                <p className="font-semibold text-base fontColor">
                  {t("something_went_wrong") || "Something went wrong"}
                </p>
                <button
                  className="rounded-lg primaryBackColor py-2 px-5 text-white text-sm font-medium"
                  onClick={() => handleFetchTransactions(false, 0)}
                >
                  {t("retry") || t("try_again") || "Retry"}
                </button>
              </div>
            ) : transaction?.length > 0 ? (
              transaction?.map((transaction) => {
                return (
                  <TransactionCard
                    transaction={transaction}
                    key={transaction?.id}
                  />
                );
              })
            ) : (
              <NotFound
                image={NoTransactionImage}
                title={t("no_transaction")}
                className="col-span-12"
              />
            )}
            {/* Sits at the true end of the loaded list — this, not the
                whole page, is what useInViewFetch watches. */}
            {hasMore && (
              <div ref={loadMoreSentinelRef} className="col-span-12 h-px" />
            )}

            {/* Shown whenever more pages exist, not just while one is in
                flight — a persistent hint that scrolling further loads more,
                visible as soon as the first page lands. */}
            {hasMore &&
              Array?.from({ length: loadingMore ? 6 : 2 })?.map((_, index) => (
                <div
                  className="col-span-12  md:col-span-6 lg:col-span-6"
                  key={`m${index}`}
                >
                  <CardSkeleton height={200} padding="2px" />
                </div>
              ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default TransactionHistory;