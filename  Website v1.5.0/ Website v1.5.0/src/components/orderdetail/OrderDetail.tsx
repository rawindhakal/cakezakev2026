"use client";

import React, { useState, useEffect } from "react";
import { useParams } from "next/navigation";
import * as api from "@/api/apiRoutes";
import { toast } from "react-toastify";
import { t } from "@/utils/translation";
import { formatCustomDate } from "@/lib/utils";
import useCurrency from "@/hooks/useCurrency";
import OrderAdressCard from "./OrderAdressCard";
import OrderItems from "./OrderItems";
import OrderStepper from "./OrderStatusStepper";
import FinalCheckoutSummary from "./FinalCheckoutSummary";
import BuyerTaxLines from "./BuyerTaxLines";
import BreadCrumb from "../breadcrumb/BreadCrumb";
import OrderCancelModal from "../profiledashboard/orders/OrderCancelModal";
import LiveTrackingModal from "../profiledashboard/orders/LiveTrackingModal";
import { MdOutlineFileDownload } from "react-icons/md";
import { IoIosArrowRoundForward } from "react-icons/io";
import Loader from "../loader/Loader";
import DeliveryChat from "../chat/delivery/DeliveryChat";
import {
  LuPackage,
  LuCalendarDays,
  LuMapPin,
  LuReceipt,
  LuTruck,
  LuClipboardList,
  LuStore,
  LuX,
  LuPhone,
} from "react-icons/lu";
import { FaDirections } from "react-icons/fa";

interface SectionTitleProps {
  icon: React.ReactNode;
  children: React.ReactNode;
}

const SectionTitle = ({ icon, children }: SectionTitleProps) => (
  <h2 className="flex items-center gap-2.5 border-b border-[var(--border-color)] px-4 py-3 font-bold text-base md:text-lg">
    <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg primaryLightBack primaryColor">
      {icon}
    </span>
    {children}
  </h2>
);

const OrderDetail = () => {
  const params = useParams();
  const orderid = params?.orderid;
  // Order detail payload shape has no shared type yet — see AGENTS.md rule 4.
  const [orderDetail, setOrderDetail] = useState<any>({});
  const [loading, setLoading] = useState(false);
  const [showCancelModal, setShowCancelModal] = useState(false);
  const [showLiveTracking, setShowLiveTracking] = useState(false);

  const handleFetchOrderDetail = async () => {
    setLoading(true);
    try {
      const response = await api.getOrders({ orderId: orderid });
      if (response?.status == 1) {
        setOrderDetail(response.data[0]);
      } else {
        console.log("Error", response);
      }
    } catch (error) {
      console.log("Error", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (orderid) {
      // intentional: fetches order detail when the route's orderid is known.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      handleFetchOrderDetail();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [orderid]);

  const handleDownloadInvoice = async () => {
    try {
      const response = await api.downloadInvoice({ orderId: orderid });
      const fileURL = window.URL.createObjectURL(new Blob([response.data]));
      const fileLink = document.createElement("a");
      fileLink.href = fileURL;
      fileLink.setAttribute("download", "Invoice-No:" + orderid + ".pdf");
      document.body.appendChild(fileLink);
      fileLink.click();
    } catch (error: any) {
      if (error?.request?.statusText) {
        toast.error(error.request.statusText);
      } else if (error?.message) {
        toast.error(error.message);
      } else {
        toast.error(t("something_went_wrong"));
      }
    }
  };

  // Billing data seen both top-level and nested under address — check both shapes.
  const billingAddress =
    orderDetail?.billing_address || orderDetail?.address?.billing;
  const billingSameAsShipping =
    orderDetail?.billing_same_as_shipping ??
    orderDetail?.address?.billing_same_as_shipping;

  // Placed order's own currency wins over viewer's current zone.
  const { currency } = useCurrency(orderDetail);
  const hasOtp =
    orderDetail?.active_status < 6 &&
    orderDetail?.otp !== null &&
    orderDetail?.otp !== undefined &&
    Number(orderDetail?.otp) !== 0;

  // Pickup orders have no rider and no live tracking.
  const isPickupOrder = orderDetail?.delivery_type === "pickup";
  // v1.5.0 renamed pickup_store to pickup_branch; older payloads still send pickup_store.
  const pickupBranch = orderDetail?.pickup_branch || orderDetail?.pickup_store;

  return (
    <section className="bg-[var(--bg-color)]">
      {/* Show the order number instead of the raw id in the last crumb. */}
      <BreadCrumb title={orderDetail?.order_number ?? undefined} />
      <div className="container mt-4 mb-10">
        {loading && !orderDetail?.id ? (
          <Loader />
        ) : (
          <div className="flex flex-col gap-5">
            {/* Header — accent bar leading edge, identity left, action rail right. */}
            <div className="relative overflow-hidden rounded-2xl border border-[var(--border-color)] bg-white dark:bg-zinc-900 shadow-sm">
              <span className="absolute inset-y-0 left-0 w-1 primaryBackColor" />

              <div className="flex flex-col gap-5 p-5 pl-6 md:p-6 md:pl-7 lg:flex-row lg:items-center lg:justify-between">
                {/* identity */}
                <div className="flex items-start gap-4 md:items-center">
                  <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl primaryLightBack primaryColor md:h-13 md:w-13">
                    <LuPackage size={24} />
                  </span>
                  <div className="min-w-0">
                    {/* items-end: keeps status badge aligned beside the order number. */}
                    <div className="flex flex-wrap items-end gap-x-3 gap-y-1.5">
                      {/* order_number carries its own prefix; "#" added only to bare id fallback. */}
                      <div className="min-w-0">
                        <p className="text-xs font-medium SecondaryTextColor leading-none">
                          {t("orderNumber")}
                        </p>
                        <h1 className="mt-1 font-bold text-lg md:text-xl tracking-tight textColor">
                          {orderDetail?.order_number ?? `#${orderDetail?.id}`}
                        </h1>
                      </div>
                      {orderDetail?.order_status_name && (
                        <span
                          className="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-bold primaryColor"
                          style={{
                            backgroundColor:
                              "color-mix(in srgb, var(--primary-color) 10%, transparent)",
                          }}
                        >
                          <span className="relative flex h-1.5 w-1.5">
                            <span className="absolute inline-flex h-full w-full animate-ping rounded-full primaryBackColor opacity-70" />
                            <span className="relative inline-flex h-1.5 w-1.5 rounded-full primaryBackColor" />
                          </span>
                          {orderDetail?.order_status_name}
                        </span>
                      )}
                      {/* Self Pickup badge */}
                      {isPickupOrder && (
                        <span className="inline-flex items-center gap-1 rounded-full bg-blue-100 px-2.5 py-1 text-xs font-bold text-blue-700 dark:bg-blue-900/30 dark:text-blue-400">
                          <LuStore size={11} />
                          {t("self_pickup") || "Self Pickup"}
                        </span>
                      )}
                    </div>
                    <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1.5 SecondaryTextColor">
                      <span className="inline-flex items-center gap-1.5 text-sm">
                        <LuCalendarDays size={14} className="shrink-0" />
                        {formatCustomDate(orderDetail?.date)}
                      </span>
                      {orderDetail?.channel && (
                        // No dot separator: on a narrow screen the channel wraps
                        // to its own line and the dot was left dangling.
                        <span className="inline-flex items-center gap-1.5 text-sm font-medium capitalize">
                            <LuStore size={14} className="shrink-0" />
                            {orderDetail?.channel}
                          </span>
                      )}
                    </div>
                  </div>
                </div>

                {/* action rail */}
                <div className="flex flex-wrap items-stretch gap-2.5 lg:shrink-0 lg:justify-end">
                  {hasOtp && (
                    <div className="inline-flex h-11 flex-1 basis-[140px] items-center justify-center gap-2.5 rounded-xl border border-[var(--border-color)] bg-[var(--bg-color)] px-3.5 sm:flex-none sm:basis-auto">
                      <span className="text-[10px] font-semibold uppercase tracking-wider SecondaryTextColor">
                        {t("otp")}
                      </span>
                      <span className="font-extrabold text-base tracking-[0.18em] primaryColor">
                        {orderDetail?.otp}
                      </span>
                    </div>
                  )}
                  {/* Chats now live as rows at the bottom of the page. */}
                  <button
                    className="inline-flex h-11 flex-1 basis-[140px] items-center justify-center gap-2 rounded-xl border border-[var(--border-color)] px-4 text-sm font-semibold textColor sm:flex-none sm:basis-auto transition hover:primaryLightBack hover:primaryColor"
                    onClick={handleDownloadInvoice}
                  >
                    <MdOutlineFileDownload size={18} /> {t("GetInvoice")}
                  </button>
                </div>
              </div>
            </div>

            {/* Body */}
            <div className="grid grid-cols-1 gap-5 lg:grid-cols-12">
              {/* Left */}
              <div className="flex flex-col gap-5 lg:col-span-8">
                {(orderDetail?.delivery_date || orderDetail?.gift_message || orderDetail?.recipient_name) && (
                  <div className="overflow-hidden rounded-2xl border border-[var(--border-color)] bg-white dark:bg-zinc-900 shadow-sm">
                    <SectionTitle icon={<LuClipboardList size={18} />}>
                      Delivery &amp; gift details
                    </SectionTitle>
                    <div className="grid gap-1 p-4 text-sm">
                      {orderDetail?.delivery_date && (
                        <p><b>Delivery:</b> {new Date(String(orderDetail.delivery_date).substring(0, 10) + "T00:00:00").toLocaleDateString(undefined, { weekday: "short", day: "2-digit", month: "short", year: "numeric" })}{orderDetail?.delivery_slot ? ` · ${orderDetail.delivery_slot}` : ""}</p>
                      )}
                      {orderDetail?.recipient_name && (
                        <p><b>To:</b> {orderDetail.recipient_name}{orderDetail?.recipient_phone ? ` · ${orderDetail.recipient_phone}` : ""}</p>
                      )}
                      {orderDetail?.occasion && <p><b>Occasion:</b> {orderDetail.occasion}</p>}
                      {orderDetail?.personalization && <p><b>Personalisation:</b> {orderDetail.personalization}</p>}
                      {orderDetail?.gift_message && <p><b>Card message:</b> “{orderDetail.gift_message}”</p>}
                    </div>
                  </div>
                )}

                {orderDetail?.order_note && (
                  <div className="overflow-hidden rounded-2xl border border-[var(--border-color)] bg-white dark:bg-zinc-900 shadow-sm">
                    <SectionTitle icon={<LuClipboardList size={18} />}>
                      {t("order_note_title")}
                    </SectionTitle>
                    <div className="p-4">
                      <p className="text-sm leading-relaxed">
                        {orderDetail?.order_note}
                      </p>
                    </div>
                  </div>
                )}

                {/* Pickup: show the store's address, not orderDetail.address. */}
                {isPickupOrder && pickupBranch && (
                  <div className="overflow-hidden rounded-2xl border border-[var(--border-color)] bg-white dark:bg-zinc-900 shadow-sm">
                    <SectionTitle icon={<LuStore size={18} />}>
                      {t("pickup_from") || "Pickup from"}
                    </SectionTitle>
                    <div className="p-4 flex flex-col gap-2.5">
                      <div className="flex items-center justify-between gap-2">
                        <p className="font-bold text-base textColor">
                          {pickupBranch.branch_name}
                        </p>
                        {pickupBranch.is_open_now != null && (
                          <span
                            className={`inline-flex w-fit shrink-0 items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-bold ${
                              pickupBranch.is_open_now
                                ? "primaryLightBack primaryColor"
                                : "bg-black/[0.04] SecondaryTextColor dark:bg-white/[0.06]"
                            }`}
                          >
                            <span className="h-1.5 w-1.5 rounded-full bg-current" />
                            {pickupBranch.is_open_now
                              ? t("open_now") || "Open now"
                              : t("closed_now") || "Closed now"}
                          </span>
                        )}
                      </div>

                      {pickupBranch.address && (
                        <div className="flex items-start gap-2 text-xs SecondaryTextColor leading-relaxed">
                          <LuMapPin size={14} className="primaryColor shrink-0 mt-0.5" />
                          <span className="min-w-0 flex-1">
                            {pickupBranch.address}
                          </span>
                        </div>
                      )}

                      {(pickupBranch.address ||
                        pickupBranch.contact_number) && (
                        <div className="flex items-center gap-2 text-xs">
                          {pickupBranch.address && (
                            <a
                              href={
                                pickupBranch.latitude != null &&
                                pickupBranch.longitude != null
                                  ? `https://www.google.com/maps/dir/?api=1&destination=${pickupBranch.latitude},${pickupBranch.longitude}`
                                  : `https://maps.google.com/?q=${encodeURIComponent(pickupBranch.address)}`
                              }
                              target="_blank"
                              rel="noopener noreferrer"
                              className="inline-flex items-center gap-1.5 rounded-full primaryLightBack px-2.5 py-1 text-[11px] font-bold primaryColor transition-opacity hover:opacity-80"
                            >
                              <FaDirections size={12} className="shrink-0" />
                              {t("get_directions") || "Get Directions"}
                            </a>
                          )}
                          {pickupBranch.contact_number && (
                            <a
                              href={`tel:${pickupBranch.contact_number}`}
                              className="inline-flex items-center gap-1.5 rounded-full primaryLightBack px-2.5 py-1 text-[11px] font-bold primaryColor transition-opacity hover:opacity-80"
                            >
                              <LuPhone size={12} className="shrink-0" />
                              {t("call_store") || "Call Store"}
                            </a>
                          )}
                        </div>
                      )}
                    </div>
                  </div>
                )}

                {/* Shipping always shown; billing joins as second column when it differs. */}
                {!isPickupOrder && orderDetail?.address && (
                  <div className="overflow-hidden rounded-2xl border border-[var(--border-color)] bg-white dark:bg-zinc-900 shadow-sm">
                    <SectionTitle icon={<LuMapPin size={18} />}>
                      {t("addresses") || "Addresses"}
                    </SectionTitle>
                    <div className="grid grid-cols-1 sm:grid-cols-2">
                      <div
                        className={
                          billingAddress && !billingSameAsShipping
                            ? "p-4 border-b sm:border-b-0 sm:border-r border-[var(--border-color)]"
                            : "p-4"
                        }
                      >
                        {billingAddress && !billingSameAsShipping && (
                          <p className="mb-2 text-xs font-bold uppercase tracking-wide SecondaryTextColor">
                            {t("shippingAdress")}
                          </p>
                        )}
                        <OrderAdressCard orderDetail={orderDetail} />
                        {(!billingAddress || !!billingSameAsShipping) && (
                          <BuyerTaxLines orderDetail={orderDetail} />
                        )}
                      </div>
                      {billingAddress && !billingSameAsShipping && (
                        <div className="p-4">
                          <p className="mb-2 text-xs font-bold uppercase tracking-wide SecondaryTextColor">
                            {t("billing_address") || "Billing Address"}
                          </p>
                          <h2 className="text-sm font-bold mb-1.5">
                            {billingAddress?.name}
                          </h2>
                          <p className="text-sm SecondaryTextColor">
                            {billingAddress?.address}
                          </p>
                          <p className="mt-1.5 text-sm font-medium ">
                            {t("phone")} : {billingAddress?.mobile}
                          </p>
                          <BuyerTaxLines orderDetail={orderDetail} />
                        </div>
                      )}
                    </div>
                  </div>
                )}

                {/* Items */}
                <div className="overflow-hidden rounded-2xl border border-[var(--border-color)] bg-white dark:bg-zinc-900 shadow-sm">
                  <SectionTitle icon={<LuPackage size={18} />}>
                    {t("items")}
                  </SectionTitle>
                  <div className="p-4">
                    <OrderItems
                      products={orderDetail?.items}
                      currency={currency}
                      handleFetchOrderDetail={handleFetchOrderDetail}
                      orderIsCancellable={orderDetail?.is_cancellable}
                      orderIsReturnable={orderDetail?.is_returnable}
                      isShowProductRating={
                        !!orderDetail?.product_rating &&
                        orderDetail?.product_rating != "0"
                      }
                    />

                    {/* Order-level cancel — cancels the whole order, not one item. */}
                    {orderDetail?.is_cancellable === true && (
                      <div className="mt-4 flex flex-col gap-1 border-t border-[var(--border-color)] pt-4 sm:flex-row sm:items-center sm:justify-between">
                        <p className="text-sm SecondaryTextColor">
                          {t("cancel_full_order_note") ||
                            "Cancelling will cancel all items in this order."}
                        </p>
                        <button
                          type="button"
                          onClick={() => setShowCancelModal(true)}
                          className="inline-flex shrink-0 items-center justify-center gap-2 rounded-xl border border-[#DB3D26]/40 px-4 py-2 text-sm font-semibold text-[#DB3D26] transition-colors hover:bg-[#DB3D26] hover:text-white"
                        >
                          <LuX size={16} />
                          {t("cancel_order") || t("cancel")}
                        </button>
                      </div>
                    )}
                  </div>
                </div>

                {/* Help rows — side-by-side when both chats show, else full width. */}
                {orderid && (
                  <div
                    className={
                      orderDetail?.is_delivery_boy_chat_visible === true
                        ? "grid grid-cols-1 gap-4 sm:grid-cols-2"
                        : ""
                    }
                  >
                    {orderDetail?.is_delivery_boy_chat_visible === true && (
                      <DeliveryChat
                        orderId={Array.isArray(orderid) ? orderid[0] : orderid}
                        orderItemId={undefined}
                        orderStatus={orderDetail?.active_status}
                        deliveryBoy={undefined}
                        variant="row"
                        label={undefined}
                        subtitle={undefined}
                      />
                    )}
                    <DeliveryChat
                      orderId={Array.isArray(orderid) ? orderid[0] : orderid}
                      orderItemId={undefined}
                      orderStatus={orderDetail?.active_status}
                      deliveryBoy={undefined}
                      mode="orderAdmin"
                      variant="row"
                      label={undefined}
                      subtitle={undefined}
                    />
                  </div>
                )}
              </div>

              {/* Right */}
              <div className="flex flex-col gap-5 lg:col-span-4 lg:sticky lg:top-4 lg:self-start">
                {orderDetail?.timeline?.length > 0 && (
                  <div className="overflow-hidden rounded-2xl border border-[var(--border-color)] bg-white dark:bg-zinc-900 shadow-sm">
                    <SectionTitle icon={<LuTruck size={18} />}>
                      {t("track_order")}
                    </SectionTitle>
                    <div className="p-4">
                      <OrderStepper orderDetail={orderDetail} />
                      {/* Track button — hidden for pickup orders (no rider) */}
                      {![7, 8, 12, 13].includes(
                        Number(orderDetail?.active_status),
                      ) && !isPickupOrder && (
                        <button
                          type="button"
                          onClick={() => setShowLiveTracking(true)}
                          style={{
                            backgroundColor:
                              "color-mix(in srgb, var(--primary-color) 10%, transparent)",
                          }}
                          className="mt-4 flex w-full items-center justify-center gap-2 whitespace-nowrap rounded-xl border border-[var(--primary-color)] px-3 py-2.5 text-sm font-semibold textPrimaryColor"
                        >
                          <span className="relative flex h-2 w-2 shrink-0">
                            <span className="absolute inline-flex h-full w-full animate-ping rounded-full primaryBackColor opacity-75" />
                            <span className="relative inline-flex h-2 w-2 rounded-full primaryBackColor" />
                          </span>
                          <LuTruck size={15} className="shrink-0" />
                          {t("track_order")}
                          <IoIosArrowRoundForward
                            size={18}
                            className="shrink-0"
                          />
                        </button>
                      )}
                    </div>
                  </div>
                )}
                <div className="overflow-hidden rounded-2xl border border-[var(--border-color)] bg-white dark:bg-zinc-900 shadow-sm">
                  <SectionTitle icon={<LuReceipt size={18} />}>
                    {t("billing_details")}
                  </SectionTitle>
                  <div className="p-4">
                    {/* No Addresses card on a pickup order, so the billed party shows here. */}
                    {(isPickupOrder || !orderDetail?.address) && (
                      <BuyerTaxLines
                        orderDetail={orderDetail}
                        className="mb-3 border-b border-[var(--border-color)] pb-3"
                      />
                    )}
                    <FinalCheckoutSummary orderDetail={orderDetail} />
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      <OrderCancelModal
        open={showCancelModal}
        setOpen={setShowCancelModal}
        order={orderDetail}
        onCancelled={handleFetchOrderDetail}
      />
      <LiveTrackingModal
        showLiveTracking={showLiveTracking}
        setShowLiveTracking={setShowLiveTracking}
        order={orderDetail}
      />
    </section>
  );
};

export default OrderDetail;
