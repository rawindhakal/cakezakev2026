"use client";

import { useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { FiInfo, FiX } from "react-icons/fi";
import * as TooltipPrimitive from "@radix-ui/react-tooltip";
import { t } from "@/utils/translation";
import { setPromoAutoApplyError } from "@/redux/slices/cartSlice";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";

// Error banner for promo code auto-apply failures with detailed tooltip
const CouponAutoApplyError = () => {
  const dispatch = useDispatch();
  const err = useSelector((s: any) => s.Cart?.promoAutoApplyError);
  const [open, setOpen] = useState(false);
  if (!err) return null;

  return (
    <div className="flex items-center gap-2 border-b border-emerald-200 bg-emerald-50 px-3 py-2 text-xs dark:border-emerald-500/25 dark:bg-emerald-500/10">
      <TooltipProvider delayDuration={150}>
        <Tooltip open={open} onOpenChange={setOpen}>
          <TooltipTrigger asChild>
            <button
              type="button"
              onClick={() => setOpen((v) => !v)}
              className="flex min-w-0 flex-1 cursor-help items-center gap-2 text-start"
            >
              <FiInfo size={14} className="shrink-0 text-emerald-600" />
              <p className="min-w-0 flex-1 truncate text-emerald-700 dark:text-emerald-300">
                <span className="font-bold uppercase tracking-wide">{err.code}</span>
                <span className="mx-1 opacity-50">·</span>
                {err.reason}
              </p>
            </button>
          </TooltipTrigger>
          <TooltipContent
            side="bottom"
            align="start"
            className="z-[80] max-w-[280px] rounded-lg border-emerald-200 bg-white px-3 py-2.5 text-xs leading-relaxed text-gray-700 shadow-lg dark:border-emerald-500/30 dark:bg-zinc-900 dark:text-zinc-200"
          >
            <p className="mb-1 flex items-center gap-1.5 font-bold uppercase tracking-wide text-emerald-700 dark:text-emerald-300">
              <FiInfo size={12} className="shrink-0" />
              {err.code}
            </p>
            <p>{err.reason}</p>
            <TooltipPrimitive.Arrow className="fill-white dark:fill-zinc-900" />
          </TooltipContent>
        </Tooltip>
      </TooltipProvider>
      <button
        type="button"
        aria-label={t("close") || "Close"}
        onClick={() => dispatch(setPromoAutoApplyError(null))}
        className="shrink-0 text-emerald-500 transition hover:text-emerald-700"
      >
        <FiX size={14} />
      </button>
    </div>
  );
};

export default CouponAutoApplyError;
