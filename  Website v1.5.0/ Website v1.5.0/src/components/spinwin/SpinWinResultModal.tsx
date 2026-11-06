"use client";

import React from "react";
import Image from "next/image";
import { toast } from "react-toastify";
import { Dialog, DialogContent, DialogHeader } from "@/components/ui/dialog";
import { RiCloseFill, RiFileCopyLine, RiWallet3Line } from "react-icons/ri";
import { MdOutlineCelebration } from "react-icons/md";
import { t } from "@/utils/translation";
import type { SpinWheelSegment, SpinWheelSpinResult } from "@/types/spinWin";
import useCurrency from "@/hooks/useCurrency";
import { formatCurrency } from "@/utils/helperFunction";
import SpinWinConfetti from "./SpinWinConfetti";

interface SpinWinResultModalProps {
  open: boolean;
  onClose: () => void;
  /** Landed segment for display icon/color. */
  segment: SpinWheelSegment | null;
  /** Result details (title, message, promo code, wallet credit). */
  result: SpinWheelSpinResult | null;
  onPrimaryAction: () => void;
}

/**
 * Modal displaying win/loss results after a spin.
 */
const SpinWinResultModal = ({
  open,
  onClose,
  segment,
  result,
  onPrimaryAction,
}: SpinWinResultModalProps) => {
  const { currency, decimals } = useCurrency();

  if (!segment || !result) return null;

  const isWin = result.result === "win";
  const promo = result.promo_code;
  const wallet = result.wallet;
  const isFreeDelivery = promo?.discount_type === "free_delivery";

  const handleCopyCode = () => {
    if (!promo?.promo_code) return;
    navigator.clipboard
      .writeText(promo.promo_code)
      .then(() => toast.success(t("copied") || "Copied"))
      .catch(() => toast.error(t("something_went_wrong")));
  };

  return (
    <Dialog open={open} onOpenChange={(v) => !v && onClose()}>
      <DialogContent
        className="w-full sm:max-w-[360px] rounded-[28px] overflow-hidden p-0 gap-0 border-0 shadow-2xl bg-white dark:bg-zinc-950"
        title={result.title || segment.label}
      >
        <DialogHeader className="absolute end-3 top-3 z-30 space-y-0">
          <button
            onClick={onClose}
            className="flex h-8 w-8 items-center justify-center rounded-full bg-black/[0.06] text-zinc-500 shadow-sm ring-1 ring-black/[0.04] transition hover:bg-black/10 hover:text-zinc-700 dark:bg-white/10 dark:text-zinc-300 dark:ring-white/10 dark:hover:bg-white/20"
          >
            <RiCloseFill size={18} />
          </button>
        </DialogHeader>

        <div className="relative flex flex-col items-center px-6 pb-6 pt-10 text-center">
          <SpinWinConfetti active={isWin} />

          {/* Primary glow backdrop */}
          <div
            className="pointer-events-none absolute left-1/2 top-0 h-36 w-36 -translate-x-1/2 rounded-full opacity-[0.12] blur-3xl"
            style={{ backgroundColor: "var(--primary-color)" }}
          />

          {/* Segment icon badge */}
          <span
            className="relative z-10 flex h-[68px] w-[68px] items-center justify-center rounded-full shadow-lg ring-4 ring-white dark:ring-zinc-950"
            style={{
              background: segment.icon_url
                ? "linear-gradient(160deg, color-mix(in srgb, var(--primary-color) 88%, #fff), var(--primary-color))"
                : segment.color,
              boxShadow:
                "0 10px 24px -8px color-mix(in srgb, var(--primary-color) 50%, transparent)",
            }}
          >
            {segment.icon_url && (
              <Image
                src={segment.icon_url}
                alt=""
                width={34}
                height={34}
                className="h-[34px] w-[34px] object-contain"
                unoptimized
              />
            )}
          </span>

          <div className="relative z-10 mt-5 flex flex-col items-center gap-1.5">
            <span className="text-xl font-bold leading-tight tracking-tight textColor">
              {result.title || (isWin ? t("congratulations") || "Congratulations!" : segment.label)}
            </span>
            {result.message && (
              <span className="max-w-[260px] text-[13px] leading-relaxed SecondaryTextColor">
                {result.message}
              </span>
            )}
          </div>

          {/* Promo code ticket */}
          {promo && (
            <div
              className="relative z-10 mt-5 flex w-full items-stretch rounded-xl"
              style={{
                backgroundImage:
                  "linear-gradient(135deg, color-mix(in srgb, var(--primary-color) 10%, var(--category-card-bg)), color-mix(in srgb, var(--primary-color) 4%, var(--category-card-bg)))",
                WebkitMaskImage:
                  "radial-gradient(circle 7px at 74% 0, transparent 7px, #000 7.5px), radial-gradient(circle 7px at 74% 100%, transparent 7px, #000 7.5px)",
                maskImage:
                  "radial-gradient(circle 7px at 74% 0, transparent 7px, #000 7.5px), radial-gradient(circle 7px at 74% 100%, transparent 7px, #000 7.5px)",
                WebkitMaskComposite: "source-in",
                maskComposite: "intersect",
              }}
            >
              {/* Dashed divider */}
              <span className="pointer-events-none absolute top-3 bottom-3 left-[74%] -translate-x-1/2 border-l border-dashed border-[color-mix(in_srgb,var(--primary-color)_40%,transparent)]" />

              <div className="flex min-w-0 grow basis-[74%] flex-col items-start justify-center gap-0.5 px-4 py-3.5">
                <span className="flex items-center gap-1 text-[10px] font-semibold uppercase tracking-wide SecondaryTextColor">
                  <MdOutlineCelebration size={12} />
                  {t("couponCode") || t("coupon_code") || "Coupon Code"}
                </span>
                <span className="text-lg font-extrabold uppercase tracking-wide primaryColor">
                  {promo.promo_code}
                </span>
                {!isFreeDelivery && promo.minimum_order_amount > 0 && (
                  <span className="text-[11px] SecondaryTextColor">
                    {t("minimum_order") || "Min. Order"}{" "}
                    {formatCurrency(promo.minimum_order_amount, currency, decimals)}
                  </span>
                )}
              </div>
              <button
                type="button"
                onClick={handleCopyCode}
                className="flex shrink-0 basis-[26%] flex-col items-center justify-center gap-1 py-3.5 primaryColor transition hover:opacity-75"
              >
                <RiFileCopyLine size={18} />
                <span className="text-[10px] font-bold uppercase tracking-wide">
                  {t("copy") || "Copy"}
                </span>
              </button>
            </div>
          )}

          {/* Wallet credit — same amber-cashback treatment CartCouponCard uses. */}
          {wallet && wallet.amount > 0 && (
            <div className="relative z-10 mt-5 flex w-full items-center gap-3 overflow-hidden rounded-xl border border-amber-200 bg-gradient-to-r from-amber-50 via-orange-50 to-amber-50 px-3.5 py-3 dark:border-amber-500/25 dark:from-amber-500/10 dark:via-orange-500/10 dark:to-amber-500/10">
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-amber-500/15 text-amber-600 dark:text-amber-400 ring-4 ring-amber-500/5">
                <RiWallet3Line size={20} />
              </span>
              <div className="min-w-0 flex-grow text-start">
                <p className="text-sm font-extrabold leading-tight text-amber-700 dark:text-amber-400">
                  {t("cashback_added_to_wallet_instant") || "Added to your wallet instantly"}
                </p>
              </div>
              <span className="shrink-0 rounded-lg bg-amber-500 px-2.5 py-1 text-sm font-extrabold text-white shadow-sm">
                +{formatCurrency(wallet.amount, currency, decimals)}
              </span>
            </div>
          )}

          <button
            type="button"
            onClick={onPrimaryAction}
            className="relative z-10 mt-6 w-full rounded-full primaryBackColor py-3.5 text-sm font-bold text-white shadow-md transition hover:opacity-95 active:scale-[0.98]"
          >
            {isWin && promo
              ? t("claim_coupon") || "Claim Coupon"
              : isWin && wallet
                ? t("view_wallet") || "View Wallet"
                : t("done") || "Done"}
          </button>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default SpinWinResultModal;
