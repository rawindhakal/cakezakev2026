import { t } from "@/utils/translation";
import { formatCurrency } from "@/utils/helperFunction";
import React from "react";
import { LuGift, LuBadgeCheck, LuClock3 } from "react-icons/lu";
import { RiWallet3Line, RiBankCardLine, RiRefund2Line } from "react-icons/ri";
import { FiInfo } from "react-icons/fi";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";

import useCurrency from "@/hooks/useCurrency";

interface FinalCheckoutSummaryProps {
  // Payload shape varies by order type, no shared type — see AGENTS.md rule 4.
  orderDetail: any;
}

const FinalCheckoutSummary = ({ orderDetail }: FinalCheckoutSummaryProps) => {
  // Placed order's own currency wins over viewer's current zone.
  const { currency, decimals } = useCurrency(orderDetail);
  const money = (val: number | string) => formatCurrency(val, currency, decimals || 2);
  // Split = wallet paid part + non-zero gateway residual; full-wallet (residual 0) isn't a split.
  const walletPaid = Number(
    orderDetail?.paid_wallet ?? orderDetail?.wallet_balance ?? 0,
  );
  const walletUsed = walletPaid > 0;
  const residual = Number(
    orderDetail?.remaining_final || orderDetail?.final_total || 0,
  );
  const isSplit = walletUsed && residual > 0;

  // Charges rendered as own rows below, so pulled out of subtotal to avoid double count.
  const sumAmounts = (rows: any[] | null | undefined, key: string) =>
    (rows ?? []).reduce((acc, r) => acc + Number(r?.[key] || 0), 0);
  const chargesTotal =
    Number(orderDetail?.delivery_charges?.amount ?? orderDetail?.delivery_charge ?? 0) +
    sumAmounts(orderDetail?.additional_charges, "amount") +
    sumAmounts(orderDetail?.surge_charges, "charge") +
    sumAmounts(orderDetail?.zone_additional_charges, "amount");

  // Prefer the API's own subtotal field over deriving it; derivation is last-resort fallback.
  const explicitSubTotal = [
    orderDetail?.total,
    orderDetail?.sub_total,
    orderDetail?.remaining_total,
  ].find((v) => v != null && v !== "" && !Number.isNaN(Number(v)));

  // paidTotal = wallet + gateway residual, matching the Total row below.
  const paidTotal = walletUsed ? walletPaid + residual : residual;

  // Never render a negative subtotal; fall back to derivation instead.
  const subTotal =
    explicitSubTotal != null
      ? Number(explicitSubTotal)
      : Math.max(paidTotal - chargesTotal, 0);

  const grandTotal = paidTotal > 0 ? paidTotal : subTotal + chargesTotal;

  // Per-tax breakdown (IGST/CGST/SGST) for the Subtotal tooltip; zero rows dropped.
  const taxBreakdownRows = (orderDetail?.tax_breakdown || []).filter(
    (tx: any) => Number(tx?.amount) > 0,
  );
  // Delivery-sourced tax rows for the Delivery Charge row's tooltip.
  // delivery_charges is a single object { amount, tax_amount, tax_name, tax_rate },
  // not an array — synthesize a one-row tooltip list from it when charge_tax_lines absent.
  const deliveryChargeAmount = Number(
    orderDetail?.delivery_charges?.amount ?? orderDetail?.delivery_charge ?? 0,
  );
  const deliveryTaxLines = orderDetail?.charge_tax_lines?.length
    ? orderDetail.charge_tax_lines.filter(
        (tx: any) => tx?.source === "delivery" && Number(tx?.amount) > 0,
      )
    : Number(orderDetail?.delivery_charges?.tax_amount) > 0
      ? [
          {
            name: orderDetail.delivery_charges.tax_name,
            rate: orderDetail.delivery_charges.tax_rate,
            amount: orderDetail.delivery_charges.tax_amount,
          },
        ]
      : [];

  // Charge rows carry their own tax ({ tax_name, tax_rate, tax_amount }),
  // shown behind the same info tooltip the delivery row uses.
  const chargeTaxLines = (charge: any) =>
    Number(charge?.tax_amount) > 0
      ? [
          {
            name: charge?.tax_name,
            rate: charge?.tax_rate,
            amount: charge?.tax_amount,
          },
        ]
      : [];

  const TaxInfo = ({ lines, idKey }: { lines: any[]; idKey: string }) =>
    lines.length > 0 ? (
      <TooltipProvider delayDuration={150}>
        <Tooltip>
          <TooltipTrigger asChild>
            <button
              type="button"
              className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 shrink-0"
              aria-label={t("tax") || "Tax"}
            >
              <FiInfo size={13} />
            </button>
          </TooltipTrigger>
          <TooltipContent className="text-xs">
            <div className="flex flex-col gap-0.5">
              {lines.map((tx: any, i: number) => (
                <div
                  key={`${idKey}-tax-${i}`}
                  className="flex justify-between gap-3"
                >
                  <span>
                    {tx?.rate != null ? `${tx?.name} (${tx?.rate}%)` : tx?.name}
                  </span>
                  <span className="tabular-nums">{money(tx?.amount)}</span>
                </div>
              ))}
            </div>
          </TooltipContent>
        </Tooltip>
      </TooltipProvider>
    ) : null;

  return (
    <div className="rounded-lg border border-[var(--border-color)] p-5">
      {/* Single payment method header only when wallet didn't cover part of the order. */}
      {!isSplit && (
        <div className="flex justify-between items-center mb-4 pb-4 border-b border-[var(--border-color)]">
          <h2 className="text-base font-semibold">{t("payment_method")}</h2>
          <span className="font-bold">{orderDetail?.payment_method}</span>
        </div>
      )}

      <div className="space-y-4">
        <div className="space-y-4">
          <div className="flex justify-between items-center">
            <span className="flex items-center gap-1.5 flex-wrap">
              {t("sub_total")}{" "}
              {/* Subtotal is already tax-inclusive. */}
              <span className="SecondaryTextColor text-[13px]">
                ({t("incl_tax") || "Incl. Tax"})
              </span>
              {taxBreakdownRows.length > 0 && (
                <TooltipProvider delayDuration={150}>
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <button
                        type="button"
                        className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 shrink-0"
                        aria-label={t("incl_tax") || "Incl. Tax"}
                      >
                        <FiInfo size={13} />
                      </button>
                    </TooltipTrigger>
                    <TooltipContent className="text-xs">
                      <div className="flex flex-col gap-0.5">
                        {taxBreakdownRows.map((tx: any, i: number) => (
                          <div
                            key={`subtotal-tax-${i}`}
                            className="flex justify-between gap-3"
                          >
                            <span>
                              {tx?.rate != null
                                ? `${tx?.name} (${tx?.rate}%)`
                                : tx?.name}
                            </span>
                            <span className="tabular-nums">
                              {money(tx?.amount)}
                            </span>
                          </div>
                        ))}
                      </div>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              )}
            </span>
            <span className="font-semibold">{money(subTotal)}</span>
          </div>

          {orderDetail?.additional_charges?.length > 0
            ? orderDetail?.additional_charges?.map((charge, index) => {
                return (
                  <div
                    className="flex justify-between items-center my-2"
                    key={index}
                  >
                    <span className="flex items-center gap-1.5 flex-wrap">
                      {charge?.name || charge?.title}
                      {Number(charge?.tax_amount) > 0 && (
                        <TooltipProvider delayDuration={150}>
                          <Tooltip>
                            <TooltipTrigger asChild>
                              <button
                                type="button"
                                className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 shrink-0"
                                aria-label={`${t("incl") || "Incl."} ${charge?.tax_name || t("tax") || "Tax"} ${money(charge?.tax_amount)}`}
                              >
                                <FiInfo size={13} />
                              </button>
                            </TooltipTrigger>
                            <TooltipContent className="text-xs">
                              {t("incl") || "Incl."} {charge?.tax_name || t("tax") || "Tax"}{" "}
                              {money(charge?.tax_amount)}
                              {(charge?.is_refundable == 1 ||
                                charge?.is_refundable === true) && (
                                <>
                                  {" "}
                                  (
                                  {t("tax_not_refundable") ||
                                    "tax not refundable"}
                                  )
                                </>
                              )}
                            </TooltipContent>
                          </Tooltip>
                        </TooltipProvider>
                      )}
                    </span>
                    <span className="font-semibold">
                      {money(charge?.amount)}
                    </span>
                  </div>
                );
              })
            : null}
          {deliveryChargeAmount != 0 && (
            <div className="flex justify-between items-center">
              <span className="flex items-center gap-1.5 flex-wrap">
                {t("delivery_charge")}
                {deliveryTaxLines.length > 0 && (
                  <TooltipProvider delayDuration={150}>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <button
                          type="button"
                          className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 shrink-0"
                          aria-label={t("tax") || "Tax"}
                        >
                          <FiInfo size={13} />
                        </button>
                      </TooltipTrigger>
                      <TooltipContent className="text-xs">
                        <div className="flex flex-col gap-0.5">
                          {deliveryTaxLines.map((tx: any, i: number) => (
                            <div
                              key={`delivery-tax-${i}`}
                              className="flex justify-between gap-3"
                            >
                              <span>
                                {tx?.rate != null
                                  ? `${tx?.name} (${tx?.rate}%)`
                                  : tx?.name}
                              </span>
                              <span className="tabular-nums">
                                {money(tx?.amount)}
                              </span>
                            </div>
                          ))}
                        </div>
                      </TooltipContent>
                    </Tooltip>
                  </TooltipProvider>
                )}
              </span>
              <span className="font-semibold">
                {money(deliveryChargeAmount)}
              </span>
            </div>
          )}

          {/* Surge charges (e.g. Night Charges). label/charge/is_refundable. */}
          {orderDetail?.surge_charges?.map((charge, index) => (
            <div className="flex justify-between items-center" key={`surge-${index}`}>
              <span className="flex items-center gap-1.5 flex-wrap">
                {charge?.label}
                <TaxInfo lines={chargeTaxLines(charge)} idKey={`surge-${index}`} />
                <RefundBadge refundable={charge?.is_refundable} />
              </span>
              <span className="font-semibold">{money(charge?.charge)}</span>
            </div>
          ))}

          {/* Zone additional charges (e.g. Packing/Handling). name/amount/is_refundable. */}
          {orderDetail?.zone_additional_charges?.map((charge, index) => (
            <div className="flex justify-between items-center" key={`zone-${index}`}>
              <span className="flex items-center gap-1.5 flex-wrap">
                {charge?.name}
                <TaxInfo lines={chargeTaxLines(charge)} idKey={`zone-${index}`} />
                <RefundBadge refundable={charge?.is_refundable} />
              </span>
              <span className="font-semibold">{money(charge?.amount)}</span>
            </div>
          ))}

          {orderDetail?.promo_discount != 0 && (
            <div className="flex justify-between items-center">
              <span className="">{t("promoDiscount")}</span>
              <span className="font-semibold">
                - {money(orderDetail?.promo_discount)}
              </span>
            </div>
          )}

          {/* Split case shows wallet in its own box below instead, avoiding double count. */}
          {walletUsed && !isSplit && (
            <div className="flex justify-between items-center">
              <span className="">{t("walletBalance")}</span>
              <span className="font-semibold">- {money(walletPaid)}</span>
            </div>
          )}

          {/* Payment split — wallet + method that settled the residual. */}
          {isSplit && (
            <>
              <p className="text-[11px] font-semibold uppercase tracking-wide SecondaryTextColor">
                {t("payment_split") || "Payment Split"}
              </p>
              <div className="flex items-center justify-between">
                <span className="flex items-center gap-2">
                  <RiWallet3Line size={16} className="primaryColor" />
                  {t("wallet") || "Wallet"}
                </span>
                <span className="font-semibold tabular-nums">
                  {money(walletPaid)}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="flex items-center gap-2 capitalize">
                  <RiBankCardLine size={16} className="primaryColor" />
                  {orderDetail?.payment_method}
                </span>
                <span className="font-semibold tabular-nums">
                  {money(residual)}
                </span>
              </div>
            </>
          )}

          <div className="pt-4 border-t border-[var(--border-color)]">
            <div className="flex justify-between items-center">
              <span className="font-bold text-base">
                {t("total")} {t("amount")}
              </span>
              <span className="textPrimaryColor font-bold text-lg">
                {/* grandTotal = wallet + gateway residual, the full order amount. */}
                {money(grandTotal)}
              </span>
            </div>
          </div>

          {/* Refund row for cancelled/returned orders. */}
          {Number(orderDetail?.refund_amount) > 0 && (
            <div className="flex items-center gap-3 rounded-xl border border-blue-100 bg-blue-50/70 px-3.5 py-3 dark:border-blue-500/20 dark:bg-blue-500/10">
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-blue-500 text-white">
                <RiRefund2Line size={20} />
              </span>
              <div className="min-w-0">
                <p className="text-[15px] font-semibold leading-tight text-blue-700 dark:text-blue-300">
                  {t("refund_amount") || "Refund Amount"}{" "}
                  {money(orderDetail?.refund_amount)}
                </p>
                {/* Wallet-paid refunds to wallet; else to original source. */}
                <p className="mt-0.5 text-[13px] leading-snug text-blue-600/70 dark:text-blue-400/70">
                  {walletUsed
                    ? t("refund_credited_to_wallet") || "Refunded to your wallet"
                    : t("refund_processed_to_source") ||
                      "Refunded to your original payment method"}
                </p>
              </div>
            </div>
          )}

          {Number(orderDetail?.saved_amount) > 0 && (
            <div className="flex items-center justify-center gap-1.5 rounded-md bg-green-50 px-3 py-2 text-sm font-semibold text-green-600">
              <LuBadgeCheck size={16} />
              {t("you_saved")} {money(orderDetail?.saved_amount)}
            </div>
          )}

          {orderDetail?.cashback_amount != 0 && (
            <div
              className="relative mt-1 flex items-center justify-between gap-3 overflow-hidden rounded-xl px-3.5 py-3 text-white"
              style={{
                background:
                  "linear-gradient(135deg, var(--primary-color), color-mix(in srgb, var(--primary-color) 78%, #000))",
              }}
            >
              {/* Decorative background bubbles */}
              <span className="pointer-events-none absolute -right-6 -top-8 h-24 w-24 rounded-full bg-white/10" />
              <span className="pointer-events-none absolute right-10 -bottom-10 h-20 w-20 rounded-full bg-white/5" />
              <span className="pointer-events-none absolute -left-5 -bottom-6 h-16 w-16 rounded-full bg-white/5" />

              <div className="relative flex min-w-0 items-center gap-3">
                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-white/15">
                  <LuGift size={18} />
                </span>
                <div className="min-w-0">
                  <p className="font-semibold text-sm leading-tight">
                    {money(orderDetail?.cashback_amount)} {t("cashback")}
                  </p>
                  <p className="mt-0.5 flex items-center gap-1 text-[11px] leading-tight text-white/70">
                    {Number(orderDetail?.cashback_credited) === 1 ? (
                      <>
                        <LuBadgeCheck size={12} />
                        {t("cashbackCredited")}
                      </>
                    ) : (
                      <>
                        <LuClock3 size={12} />
                        {t("cashbackPending")}
                      </>
                    )}
                  </p>
                </div>
              </div>

            </div>
          )}
        </div>
      </div>
    </div>
  );
};

// Small refundable / non-refundable tag shown next to surge & zone charges.
const RefundBadge = ({ refundable }: { refundable?: boolean | number }) => (
  <span
    className={`text-[11px] font-medium leading-none ${
      refundable
        ? "text-green-600 dark:text-green-400"
        : "text-gray-400 dark:text-zinc-500"
    }`}
  >
    ({refundable
      ? t("refundable") || "Refundable"
      : t("non_refundable") || "Non-refundable"})
  </span>
);

export default FinalCheckoutSummary;
