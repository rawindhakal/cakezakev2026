"use client";

import React, { useEffect, useState } from "react";
import { t } from "@/utils/translation";
import NotificationCard from "../notifications/NotificationCard";
import * as api from "../../api/apiRoutes";
import NoNotificationImage from "@/assets/empty-state/no-notification.svg";
import CardSkeleton from "../skeleton/CardSkeleton";
import NotFound from "../notfound/NotFound";
import useInViewFetch from "@/hooks/useInViewFetch";

const Notifications = () => {
  const total_notifications_per_page = 7;

  // Notification items array from API
  const [notifications, setNotifications] = useState<any[]>([]);
  const [currPage, setCurrPage] = useState(1);
  const [offset, setoffset] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [totalNotications, setTotalNotifications] = useState<number | null>(null);
  const [isError, setIsError] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  // Minimum duration (ms) to keep load-more skeleton visible
  const MIN_LOAD_MORE_MS = 500;

  const handleFetchNotifications = async (offset = 0) => {
    const startedAt = Date.now();
    if (offset === 0) {
      setIsLoading(true);
      setIsError(false);
    } else {
      setLoadingMore(true);
    }
    try {
      const response = await api.getNotifications({
        limit: total_notifications_per_page,
        offset,
      });
      if (offset !== 0) {
        const elapsed = Date.now() - startedAt;
        if (elapsed < MIN_LOAD_MORE_MS) {
          await new Promise((r) => setTimeout(r, MIN_LOAD_MORE_MS - elapsed));
        }
      }
      setTotalNotifications(response.total);
      setNotifications((prev) =>
        offset === 0 ? response.data : [...prev, ...response?.data],
      );
      setIsLoading(false);
      setLoadingMore(false);
    } catch (error) {
      setIsLoading(false);
      setLoadingMore(false);
      if (offset === 0) {
        setIsError(true);
      }
      console.log("Error ", error);
    }
  };

  // Fetch notifications on component mount
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- fetch-on-mount; not derivable from render
    handleFetchNotifications();
  }, []);

  const handleLoadMore = (pageNum: number) => {
    setCurrPage(pageNum);
    setoffset(
      pageNum * total_notifications_per_page - total_notifications_per_page,
    );
    handleFetchNotifications(
      pageNum * total_notifications_per_page - total_notifications_per_page,
    );
  };

  const hasMore = (notifications?.length ?? 0) < (totalNotications ?? 0);
  // Infinite scroll trigger sentinel hook
  const loadMoreSentinelRef = useInViewFetch({
    enabled: hasMore && !isLoading && !loadingMore,
    onLoadMore: () => handleLoadMore(currPage + 1),
  });

  return (
    <div>
      <div className="@container cardBorder rounded-xl bg-white dark:bg-zinc-900 shadow-sm overflow-hidden">
        <div className="flex justify-between items-center px-5 py-4 border-b border-gray-100 dark:border-zinc-800">
          <h2 className="font-bold text-lg textColor">{t("notification")}</h2>
        </div>
        {/* Two cards per row once the list itself is wide enough (@container), one
            on phones / beside the tablet sidebar. */}
        <div className="grid grid-cols-1 gap-3 p-4 @[720px]:grid-cols-2">
          {isLoading &&
            Array.from({ length: total_notifications_per_page }).map(
              (_, idx) => (
                <div key={idx} className="w-full">
                  <CardSkeleton height={100} padding="p-1" />
                </div>
              ),
            )}
          {notifications?.length > 0 ? (
            <>
              {notifications?.map((notification) => (
                <NotificationCard
                  notification={notification}
                  key={notification?.id}
                />
              ))}
              {/* Scroll sentinel element */}
              {hasMore && <div ref={loadMoreSentinelRef} className="col-span-full h-px" />}
              {/* Skeletons displayed while loading more notifications */}
              {hasMore &&
                Array.from({ length: loadingMore ? 4 : 2 }).map((_, idx) => (
                  <div key={`m${idx}`} className="w-full">
                    <CardSkeleton height={100} padding="p-1" />
                  </div>
                ))}
            </>
          ) : !isLoading && isError ? (
            <div className="col-span-full grid place-items-center gap-3 py-10 text-center">
              <p className="font-semibold text-base textColor">
                {t("something_went_wrong") || "Something went wrong"}
              </p>
              <button
                className="rounded-lg primaryBackColor py-2 px-5 text-white text-sm font-medium"
                onClick={() => handleFetchNotifications(0)}
              >
                {t("retry") || t("try_again") || "Retry"}
              </button>
            </div>
          ) : (
            !isLoading && (
              <NotFound
                image={NoNotificationImage}
                title={t("empty_notification_list_message")}
                className="col-span-full"
              />
            )
          )}
        </div>

      </div>
    </div>
  );
};

export default Notifications;