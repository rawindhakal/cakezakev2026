"use client";

import React, { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { format } from "date-fns";
import type { DateRange } from "react-day-picker";
import { LuCalendarDays, LuStore, LuZap } from "react-icons/lu";
import { RiCloseFill } from "react-icons/ri";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";
import { Calendar } from "@/components/ui/calendar";
import { t } from "@/utils/translation";
import useIsRtl from "@/hooks/useIsRtl";
import useZoneHref from "@/hooks/useZoneHref";
import type { OrderDateFilterValue } from "./OrderDateFilter";

const STATUSES = [
  { key: "ongoing", labelKey: "active_orders", href: "/profile/activeorders" },
  { key: "completed", labelKey: "order_history", href: "/profile/orderhistory" },
];

const CHANNELS = [
  { key: "quick", labelKey: "quick", icon: LuZap },
  { key: "ecommerce", labelKey: "all_shop", icon: LuStore },
];

interface OrderFilterSheetProps {
  open: boolean;
  onClose: () => void;
  /** Which list is on screen; switching navigates to the other route. */
  status: "ongoing" | "completed";
  channel: string;
  onChannelChange: (key: string) => void;
  value: OrderDateFilterValue | null;
  onApply: (value: OrderDateFilterValue | null) => void;
}

// Mobile-only filter sheet: order status, channel and date range in one place,
// so the list header keeps just a title and a filter button.
const OrderFilterSheet = ({
  open,
  onClose,
  status,
  channel,
  onChannelChange,
  value,
  onApply,
}: OrderFilterSheetProps) => {
  const rtl = useIsRtl();
  const router = useRouter();
  const zoneHref = useZoneHref();

  const [draftChannel, setDraftChannel] = useState(channel);
  const [range, setRange] = useState<DateRange | undefined>(undefined);

  // Reopen shows the applied state, not the last abandoned draft.
  useEffect(() => {
    if (!open) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- seeds the draft from applied filters when the sheet opens
    setDraftChannel(channel);
    setRange(
      value?.startDate && value?.endDate
        ? { from: new Date(value.startDate), to: new Date(value.endDate) }
        : undefined,
    );
  }, [open, channel, value?.startDate, value?.endDate]);

  const handleStatus = (next: (typeof STATUSES)[number]) => {
    if (next.key === status) return;
    onClose();
    router.push(zoneHref(next.href));
  };

  const handleApply = () => {
    onChannelChange(draftChannel);
    if (range?.from && range?.to) {
      onApply({
        startDate: format(range.from, "yyyy-MM-dd"),
        endDate: format(range.to, "yyyy-MM-dd"),
      });
    } else if (!range?.from) {
      onApply(null);
    }
    onClose();
  };

  const handleClear = () => {
    setRange(undefined);
    setDraftChannel("quick");
    onChannelChange("quick");
    onApply(null);
    onClose();
  };

  const chip = (selected: boolean) =>
    `flex flex-1 items-center justify-center gap-1.5 rounded-xl border px-3 py-2.5 text-sm transition ${
      selected
        ? "primaryBorderColor primaryLightBack primaryColor font-semibold"
        : "cardBorder SecondaryTextColor font-medium"
    }`;

  return (
    <Sheet open={open} onOpenChange={(next) => !next && onClose()}>
      <SheetContent
        side="bottom"
        className="max-h-[92svh] overflow-y-auto rounded-t-2xl p-0"
      >
        <div className="flex items-center justify-between border-b cardBorder px-4 py-3">
          <SheetTitle className="text-base font-bold textColor">
            {t("filter") || "Filter"}
          </SheetTitle>
          <button
            type="button"
            onClick={onClose}
            aria-label={t("close") || "Close"}
            className="flex h-8 w-8 items-center justify-center rounded-full bg-black/5 active:scale-90"
          >
            <RiCloseFill size={18} />
          </button>
        </div>

        <div className="flex flex-col gap-5 px-4 py-4">
          <div className="flex flex-col gap-2">
            <p className="text-xs font-semibold uppercase tracking-wide SecondaryTextColor">
              {t("orders") || "Orders"}
            </p>
            <div className="flex gap-2">
              {STATUSES.map((s) => (
                <button
                  key={s.key}
                  type="button"
                  onClick={() => handleStatus(s)}
                  className={chip(s.key === status)}
                >
                  {t(s.labelKey)}
                </button>
              ))}
            </div>
          </div>

          <div className="flex flex-col gap-2">
            <p className="text-xs font-semibold uppercase tracking-wide SecondaryTextColor">
              {t("channel") || "Channel"}
            </p>
            <div className="flex gap-2">
              {CHANNELS.map(({ key, labelKey, icon: Icon }) => (
                <button
                  key={key}
                  type="button"
                  onClick={() => setDraftChannel(key)}
                  className={chip(key === draftChannel)}
                >
                  <Icon size={15} />
                  {t(labelKey)}
                </button>
              ))}
            </div>
          </div>

          <div className="flex flex-col gap-2">
            <p className="flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wide SecondaryTextColor">
              <LuCalendarDays size={13} />
              {t("date_range") || "Date range"}
            </p>
            <div className="overflow-hidden rounded-xl border cardBorder">
              <Calendar
                mode="range"
                dir={rtl ? "rtl" : "ltr"}
                selected={range}
                onSelect={setRange}
                numberOfMonths={1}
                className="w-full p-2"
                classNames={{
                  day_selected:
                    "primaryBackColor text-white hover:primaryBackColor hover:text-white focus:primaryBackColor focus:text-white rounded-md",
                  day_range_start: "day-range-start rounded-l-md",
                  day_range_end: "day-range-end rounded-r-md",
                  day_range_middle: "primaryLightBack primaryColor rounded-none",
                  day_today: "primaryColor font-bold",
                }}
              />
            </div>
            <p className="text-xs SecondaryTextColor">
              {range?.from
                ? `${format(range.from, "dd MMM yyyy")}${
                    range?.to ? ` – ${format(range.to, "dd MMM yyyy")}` : ""
                  }`
                : t("pick_start_and_end") || "Pick a start and end date"}
            </p>
          </div>
        </div>

        <div className="sticky bottom-0 flex items-center gap-3 border-t cardBorder bg-white px-4 py-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))] dark:bg-zinc-900">
          <button
            type="button"
            onClick={handleClear}
            className="flex-1 rounded-xl border cardBorder py-2.5 text-sm font-medium SecondaryTextColor"
          >
            {t("clear") || "Clear"}
          </button>
          <button
            type="button"
            onClick={handleApply}
            className="flex-1 rounded-xl primaryBackColor py-2.5 text-sm font-semibold text-white"
          >
            {t("apply") || "Apply"}
          </button>
        </div>
      </SheetContent>
    </Sheet>
  );
};

export default OrderFilterSheet;
