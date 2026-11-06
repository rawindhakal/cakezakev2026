"use client";
import React from "react";
import { FiInfo, FiTrash2 } from "react-icons/fi";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { t } from "@/utils/translation";

interface RowProps {
  label: React.ReactNode;
  value: React.ReactNode;
  onRemove?: () => void;
  badge?: { refundable?: any };
  // Tax already included in value; shown in a tooltip.
  taxNote?: React.ReactNode;
}

// Label is inline text, not a flex row: a flex label clipped long labels and
// dropped the (i) onto a line of its own in the narrow summary column.
// Tap-to-open on touch lives in ui/tooltip.tsx, so this is a plain tooltip.
const TaxNoteTooltip = ({ note }: { note: React.ReactNode }) => (
  <TooltipProvider delayDuration={150}>
    <Tooltip>
      <TooltipTrigger asChild>
        <button
          type="button"
          className="ms-1 inline-flex translate-y-[2px] text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
          aria-label={typeof note === "string" ? note : "tax info"}
        >
          <FiInfo size={13} />
        </button>
      </TooltipTrigger>
      <TooltipContent className="max-w-[240px] text-xs">{note}</TooltipContent>
    </Tooltip>
  </TooltipProvider>
);

const Row = ({ label, value, onRemove, badge, taxNote }: RowProps) => (
  <div className="flex justify-between items-start gap-3 text-sm">
    <span className="SecondaryTextColor min-w-0 leading-snug">
      <span>{label}</span>
      {badge && (
        <span
          className={`ms-1 text-[11px] font-medium ${
            badge.refundable
              ? "text-green-600 dark:text-green-400"
              : "text-gray-400 dark:text-zinc-500"
          }`}
        >
          (
          {badge.refundable
            ? t("refundable") || "Refundable"
            : t("non_refundable") || "Non-refundable"}
          )
        </span>
      )}
      {taxNote && <TaxNoteTooltip note={taxNote} />}
      {onRemove && (
        <button
          type="button"
          className="ms-1 inline-flex translate-y-[2px] text-red-500 transition hover:text-red-600"
          onClick={onRemove}
          aria-label="remove"
        >
          <FiTrash2 size={14} />
        </button>
      )}
    </span>
    <span className="shrink-0 font-semibold textColor">{value}</span>
  </div>
);

export default Row;
