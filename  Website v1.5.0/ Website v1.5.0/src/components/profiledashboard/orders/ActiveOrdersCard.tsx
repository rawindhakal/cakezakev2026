import React, { useState } from "react";
import { t } from "@/utils/translation";
import { TbCurrentLocation } from "react-icons/tb";
import {
  LuPackage,
  LuMapPin,
  LuTruck,
  LuWallet,
  LuChevronDown,
  LuEye,
  LuRotateCcw,
  LuDownload,
  LuStore,
} from "react-icons/lu";
import { formatCustomDate } from "@/lib/utils";
import Link from "next/link";
import LiveTrackingModal from "./LiveTrackingModal";
import ReoderConfirmModal from "./ReoderConfirmModal";
import OrderCancelModal from "./OrderCancelModal";
import ImageWithPlaceholder from "@/components/image-with-placeholder/ImageWithPlaceholder";
import * as api from "@/api/apiRoutes";
import { toast } from "react-toastify";
import useZoneHref from "@/hooks/useZoneHref";
import useCurrency from "@/hooks/useCurrency";
import ProductTypeTag from "../../productdetail/ProductTypeTag";

const STATUS_MAP: Record<number, { label: string; cls: string }> = {
  1: { label: "paymentPending", cls: "paymentPendingStatus" },
  2: { label: "order_status_display_name_recieved", cls: "orderRecieved" },
  3: { label: "processed", cls: "orderProcessed" },
  4: { label: "order_status_display_name_shipped", cls: "orderShipped" },
  5: { label: "out_for_delivery", cls: "orderOutForDelivery" },
  6: { label: "order_status_display_name_delivered", cls: "orderDelivered" },
  7: { label: "cancelled", cls: "orderCancelled" },
  8: { label: "returned", cls: "orderReturned" },
  9: { label: "order_in_process", cls: "orderInProcess" },
  10: { label: "ready_to_pickup", cls: "orderReadyToPickup" },
};

// "Color: white, Size: m" from variant_attributes
const formatAttributes = (attrs: any) =>
  Array.isArray(attrs)
    ? attrs.map((a) => `${a?.name}: ${a?.value}`).join(", ")
    : "";

interface ActiveOrdersCardProps {
  order: any;
  onCancelled?: () => void;
  channel: string;
  shopMode: string;
  availableModes: string;
}

const ActiveOrdersCard = ({ order, onCancelled, channel, shopMode, availableModes }: ActiveOrdersCardProps) => {
  const zoneHref = useZoneHref();
  const [showReoderModal, setShowReorderModal] = useState(false);
  const [showLiveTracking, setShowLiveTracking] = useState(false);
  const [showCancelModal, setShowCancelModal] = useState(false);
  const [open, setOpen] = useState(false);
  const [downloading, setDownloading] = useState(false);
  const { currency } = useCurrency(order);

  // Determine whether to display the Reorder button
  const headerMatchesTab =
    (shopMode === "quick" && channel === "quick") ||
    (shopMode === "allShop" && channel === "ecommerce");
  const showReorder = availableModes !== "both" || headerMatchesTab;

  // Fetch invoice PDF blob and trigger browser download
  const handleDownloadInvoice = async () => {
    if (downloading) return;
    setDownloading(true);
    try {
      const response = await api.downloadInvoice({ orderId: order?.id });
      const fileURL = window.URL.createObjectURL(new Blob([response.data]));
      const fileLink = document.createElement("a");
      fileLink.href = fileURL;
      fileLink.setAttribute("download", `Invoice-No:${order?.id}.pdf`);
      document.body.appendChild(fileLink);
      fileLink.click();
      fileLink.remove();
      window.URL.revokeObjectURL(fileURL);
    } catch (error: any) {
      toast.error(
        error?.request?.statusText ||
          error?.message ||
          t("something_went_wrong"),
      );
    } finally {
      setDownloading(false);
    }
  };

  const items = order?.items || [];
  const itemCount = items.length;

  const city = order?.city || order?.address_city;
  const payment = order?.payment_method || order?.payment_type;
  const eta =
    order?.estimated_delivery_time ||
    order?.delivery_time ||
    order?.estimate_delivery_time;

  const status = STATUS_MAP[order?.active_status] || {
    label: "returned",
    cls: "orderReturned",
  };

  const price = (v: number | string) => `${currency}${v}`;
  // Compute display total combining wallet and gateway payments
  const walletPaid = Number(order?.paid_wallet ?? order?.wallet_balance ?? 0);
  const walletUsed = walletPaid > 0;
  const displayTotal = walletUsed
    ? walletPaid + Number(order?.final_total || 0)
    : order?.final_total;
  // Format payment method label for split wallet payments
  const gatewayResidual = Number(order?.final_total || 0);
  const paymentLabel =
    walletUsed && gatewayResidual > 0 && payment
      ? `${t("wallet") || "Wallet"} + ${payment}`
      : payment;

  // Self-pickup order check
  const isPickupOrder = order?.delivery_type === "pickup";

  return (
    <div className="px-2 pb-3">
      <div className="flex w-full flex-col overflow-hidden rounded-xl border border-[var(--border-color)] bg-white shadow-sm dark:bg-zinc-900">
        {/* Row 1: status pill + invoice download */}
        <div className="flex items-center justify-between gap-2 px-4 pt-4">
          <div className="flex flex-wrap items-center gap-1.5 min-w-0">
            <span
              className={`inline-flex shrink-0 items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-bold ${status.cls}`}
              style={{
                border: "none",
                backgroundColor:
                  "color-mix(in srgb, currentColor 12%, transparent)",
              }}
            >
              <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-current" />
              <span className="whitespace-nowrap">
                {order?.order_status_name || t(status.label)}
              </span>
            </span>
            {/* Self Pickup badge */}
            {isPickupOrder && (
              <span className="inline-flex shrink-0 items-center gap-1.5 whitespace-nowrap rounded-full bg-blue-100 px-2.5 py-1 text-xs font-bold text-blue-700 dark:bg-blue-900/30 dark:text-blue-400">
                <LuStore size={12} />
                {t("self_pickup") || "Self Pickup"}
              </span>
            )}
          </div>
          <div className="flex shrink-0 items-center gap-2">
            <button
              type="button"
              onClick={handleDownloadInvoice}
              disabled={downloading}
              className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full textPrimaryColor transition disabled:opacity-50"
              style={{
                backgroundColor:
                  "color-mix(in srgb, var(--primary-color) 12%, transparent)",
              }}
              title={t("download_invoice") || t("GetInvoice") || "Download Invoice"}
            >
              <LuDownload size={14} />
            </button>
          </div>
        </div>

        {/* Row 2: date */}
        <p className="px-4 pt-1 text-xs SecondaryTextColor">
          {formatCustomDate(order?.date)}
        </p>

        {order?.delivery_date && (
          <p className="px-4 pt-1 text-xs font-semibold primaryColor">
            🗓 Delivery:{" "}
            {new Date(String(order.delivery_date).substring(0, 10) + "T00:00:00").toLocaleDateString(undefined, { weekday: "short", day: "2-digit", month: "short" })}
            {order?.delivery_slot ? ` · ${order.delivery_slot}` : ""}
          </p>
        )}

        {/* Row 3: order id + city + track */}
        <div className="flex items-center justify-between gap-2 px-4 pt-2">
          <div className="min-w-0">
            <p className="font-bold text-base leading-tight truncate">
              {t("order")} {order?.order_number ?? `#${order?.id}`}
            </p>
            {city && (
              <p className="mt-1 flex items-center gap-1 text-xs SecondaryTextColor">
                <LuMapPin size={12} className="shrink-0" />
                <span className="truncate">{city}</span>
              </p>
            )}
          </div>
          {/* Live tracking button for out-for-delivery orders */}
          {order?.active_status == "5" && !isPickupOrder && (
            <button
              type="button"
              onClick={() => setShowLiveTracking(true)}
              aria-label={t("track_order")}
              style={{
                backgroundColor:
                  "color-mix(in srgb, var(--primary-color) 10%, transparent)",
              }}
              className="group flex shrink-0 items-center gap-1.5 rounded-full border border-[var(--primary-color)] py-1.5 pl-3 pr-2.5 text-xs font-semibold textPrimaryColor transition hover:opacity-80"
            >
              <span className="relative flex h-1.5 w-1.5 shrink-0">
                <span className="absolute inline-flex h-full w-full animate-ping rounded-full primaryBackColor opacity-75" />
                <span className="relative inline-flex h-1.5 w-1.5 rounded-full primaryBackColor" />
              </span>
              <span className="whitespace-nowrap">{t("track_order")}</span>
              <TbCurrentLocation size={15} className="shrink-0" />
            </button>
          )}
        </div>

        {/* Thumbnail + summary */}
        <button
          type="button"
          onClick={() => setOpen((o) => !o)}
          className="mt-3 flex w-full items-center gap-3 px-4 text-start"
        >
          <div className="relative aspect-square h-12 w-12 shrink-0 overflow-hidden rounded-lg border border-[var(--border-color)] bg-white">
            {items[0]?.image_url ? (
              <ImageWithPlaceholder
                src={items[0]?.image_url}
                alt={items[0]?.name || "product"}
                fill
                className="h-full w-full object-contain p-1"
              />
            ) : (
              <div className="flex h-full w-full items-center justify-center SecondaryTextColor">
                <LuPackage size={18} />
              </div>
            )}
          </div>
          <div className="min-w-0 flex-grow">
            <p className="truncate font-semibold text-sm">
              <ProductTypeTag
                type={items[0]?.product_type}
                className="me-1 align-[-2px]"
                iconSize={13}
              />
              {items[0]?.name}
            </p>
            <p className="truncate text-xs SecondaryTextColor">
              {itemCount > 1
                ? `+${itemCount - 1} ${t("moteItems") || "more items"}`
                : formatAttributes(items[0]?.variant_attributes)}
            </p>
          </div>
          {itemCount > 1 && (
            <LuChevronDown
              size={18}
              className={`shrink-0 SecondaryTextColor transition-transform duration-300 ${
                open ? "rotate-180" : ""
              }`}
            />
          )}
        </button>

        {/* Expanded item list with height transition */}
        <div
          className={`grid transition-[grid-template-rows] duration-300 ease-in-out ${
            open ? "grid-rows-[1fr]" : "grid-rows-[0fr]"
          }`}
        >
          <div className="overflow-hidden min-h-0">
            <div className="mt-2 flex flex-col divide-y divide-dashed divide-[var(--border-color)] px-4">
              {items.map((it, i) => {
                const disc = it?.discounted_price != 0;
                const unit = disc ? it?.discounted_price : it?.price;
                const qty = it?.quantity || it?.qty || 1;
                return (
                  <div
                    key={i}
                    className="flex items-center justify-between gap-2 text-sm py-2"
                  >
                    <span className="min-w-0 flex-grow truncate">
                      <ProductTypeTag
                        type={it?.product_type}
                        className="me-1 align-[-2px]"
                        iconSize={13}
                      />
                      {it?.name}{" "}
                      <span className="SecondaryTextColor">× {qty}</span>
                    </span>
                    <span className="shrink-0 font-semibold whitespace-nowrap">
                      {price(unit * qty)}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* ETA */}
        {eta && (
          <div className="mx-4 mt-3 flex items-center gap-1.5 rounded-lg px-3 py-2 text-sm font-semibold textPrimaryColor"
            style={{
              backgroundColor:
                "color-mix(in srgb, var(--primary-color) 10%, transparent)",
            }}
          >
            <LuTruck size={15} />
            {t("est_delivery") || "Est. Delivery"} {eta}
          </div>
        )}

        {/* Total + payment */}
        <div className="mt-3 flex items-center justify-between gap-2 border-t border-dashed border-[var(--border-color)] px-4 py-3">
          <div className="flex min-w-0 items-baseline gap-1.5">
            <span className="shrink-0 text-xs SecondaryTextColor">
              {t("total")}
            </span>
            <span className="truncate font-bold text-lg">
              {price(displayTotal)}
            </span>
          </div>
          {payment && (
            <span className="flex shrink-0 items-center gap-1.5 whitespace-nowrap text-xs font-medium uppercase SecondaryTextColor">
              <LuWallet size={14} />
              {paymentLabel}
            </span>
          )}
        </div>

        {/* Actions */}
        <div className="@container mt-auto flex flex-col gap-2 px-4 pb-4">
          {/* Responsive action button container */}
          <div className="grid grid-cols-1 gap-2 @[280px]:grid-cols-2">
            {showReorder && (
              <button
                className="flex min-w-0 items-center justify-center gap-1.5 whitespace-nowrap rounded-xl border border-[var(--border-color)] px-3 py-2.5 text-sm font-semibold transition-colors hover:bg-black/5"
                onClick={() => setShowReorderModal(true)}
              >
                <LuRotateCcw size={15} className="shrink-0" />
                <span className="truncate">{t("reorder")}</span>
              </button>
            )}
            <Link
              href={zoneHref(`/order-detail/${order?.id}`)}
              className={`flex min-w-0 items-center justify-center gap-1.5 whitespace-nowrap rounded-xl primaryBackColor px-3 py-2.5 text-sm font-semibold text-white ${
                !showReorder ? "@[280px]:col-span-2" : ""
              }`}
            >
              <LuEye size={15} className="shrink-0" />
              <span className="truncate">{t("view_details")}</span>
            </Link>
          </div>
        </div>
      </div>

      <OrderCancelModal
        open={showCancelModal}
        setOpen={setShowCancelModal}
        order={order}
        onCancelled={onCancelled}
      />
      <LiveTrackingModal
        showLiveTracking={showLiveTracking}
        setShowLiveTracking={setShowLiveTracking}
        order={order}
      />
      <ReoderConfirmModal
        showReoderModal={showReoderModal}
        setShowReorderModal={setShowReorderModal}
        order={order}
        orderChannel="quick"
      />
    </div>
  );
};

export default ActiveOrdersCard;
