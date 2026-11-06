"use client";

import React, { useState, type ReactNode } from "react";
import { t } from "@/utils/translation";
import { LuZap, LuStore, LuSlidersHorizontal } from "react-icons/lu";
import OrderFilterSheet from "./OrderFilterSheet";
import type { OrderDateFilterValue } from "./OrderDateFilter";

// Clean nav-style header above the order lists: title left, Quick/All Shop tabs
// inline, date filter pill right. No gray fill — sits on the card's white bg.
// `children` (date filter) stays in the SAME place on both tabs.
const TABS = [
  { key: "quick", labelKey: "quick", icon: LuZap },
  { key: "ecommerce", labelKey: "all_shop", icon: LuStore },
];

interface OrderChannelTabsProps {
  active: string;
  onChange: (key: string) => void;
  title?: string;
  children?: ReactNode;
  /** Which list this header sits on — drives the sheet's status switch. */
  status: "ongoing" | "completed";
  dateValue: OrderDateFilterValue | null;
  onDateApply: (value: OrderDateFilterValue | null) => void;
}

const OrderChannelTabs = ({
  active,
  onChange,
  title,
  children,
  status,
  dateValue,
  onDateApply,
}: OrderChannelTabsProps) => {
  const [sheetOpen, setSheetOpen] = useState(false);
  const filtersApplied = active !== "quick" || !!dateValue?.startDate;

  return (
    <>
    {/* Mobile: title + one filter button; everything else lives in the sheet. */}
    <div className="flex items-center justify-between gap-3 border-b border-[var(--border-color)] px-4 py-3 md:hidden">
      {title && (
        <h2 className="truncate text-lg font-bold tracking-tight">{title}</h2>
      )}
      <button
        type="button"
        onClick={() => setSheetOpen(true)}
        aria-label={t("filter") || "Filter"}
        className={`relative flex h-9 w-9 shrink-0 items-center justify-center rounded-full border transition active:scale-90 ${
          filtersApplied
            ? "primaryBorderColor primaryLightBack primaryColor"
            : "cardBorder textColor"
        }`}
      >
        <LuSlidersHorizontal size={17} />
        {filtersApplied && (
          <span className="absolute -end-0.5 -top-0.5 h-2 w-2 rounded-full primaryBackColor" />
        )}
      </button>
    </div>

    <OrderFilterSheet
      open={sheetOpen}
      onClose={() => setSheetOpen(false)}
      status={status}
      channel={active}
      onChannelChange={onChange}
      value={dateValue}
      onApply={onDateApply}
    />

    <div className="hidden flex-col gap-4 border-b border-[var(--border-color)] px-4 py-4 md:flex lg:flex-row lg:items-center lg:justify-between lg:px-6">
      {/* Left: title + tabs inline */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between sm:gap-6 lg:justify-start">
        {title && (
          <h2 className="font-bold text-lg sm:text-xl tracking-tight whitespace-nowrap">
            {title}
          </h2>
        )}
        <div className="flex items-center gap-4 sm:gap-5">
          {TABS.map(({ key, labelKey, icon: Icon }) => {
            const isActive = active === key;
            return (
              <button
                key={key}
                type="button"
                onClick={() => onChange(key)}
                className={`relative flex items-center gap-1.5 whitespace-nowrap pb-1 text-sm transition-colors ${
                  isActive
                    ? "primaryColor font-semibold"
                    : "SecondaryTextColor hover:textColor font-medium"
                }`}
              >
                <Icon size={15} />
                {t(labelKey)}
                <span
                  className={`absolute inset-x-0 -bottom-px h-0.5 rounded-full primaryBackColor transition duration-300 ${
                    isActive ? "opacity-100 scale-x-100" : "opacity-0 scale-x-50"
                  }`}
                />
              </button>
            );
          })}
        </div>
      </div>

      {/* Right: date filter */}
      {children && (
        <div className="shrink-0 self-start lg:self-auto">{children}</div>
      )}
    </div>
    </>
  );
};

export default OrderChannelTabs;
