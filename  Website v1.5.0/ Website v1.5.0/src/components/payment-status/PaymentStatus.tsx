"use client";
import React, { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import dynamic from "next/dynamic";
import { useDispatch, useSelector } from "react-redux";
import * as api from "@/api/apiRoutes";
import {
  clearCartPromo,
  setCart,
  setCartProducts,
  setCartSubTotal,
} from "@/redux/slices/cartSlice";
import {
  clearCheckout,
  clearPhonePeCheckoutDetails,
} from "@/redux/slices/checkoutSlice";
import { t } from "@/utils/translation";
import { formatCurrency } from "@/utils/helperFunction";

const Lottie = dynamic(() => import("lottie-react"), { ssr: false });

// Cache PhonePe transaction status per session
const phonepeTxnResults = new Map<
  string,
  "pending" | { status: "success" | "failed" | "pending" }
>();
import useLazyLottie from "@/hooks/useLazyLottie";
import useZoneHref from "@/hooks/useZoneHref";
import useCurrency from "@/hooks/useCurrency";

const PaymentStatus = () => {
  const zoneHref = useZoneHref();
  const dispatch = useDispatch();
  const phonePeData = useSelector(
    (state: any) => state.Checkout.phonepecheckoutdetails,
  );
  const router = useRouter();
  const searchParams = useSearchParams();
  // Convert searchParams to query object
  const query = React.useMemo(
    () => Object.fromEntries(searchParams?.entries() ?? []),
    [searchParams],
  );

  const [status, setStatus] = useState<"" | "pending" | "success" | "failed">("");
  // Lazy load status animation Lottie files
  const animationOne = useLazyLottie(
    () => import("@/assets/order_place_animation/order_placed_back_animation.json"),
    status === "success",
  );
  const animationTwo = useLazyLottie(
    () => import("@/assets/order_place_animation/order_success_tick_animation.json"),
    status === "success",
  );
  const animationFailed = useLazyLottie(
    () => import("@/assets/order_place_animation/order_failed_animation.json"),
    status === "failed",
  );
  const [type, setType] = useState<"" | "order" | "wallet" | "subscription">("");
  // Order receipt details
  const [order, setOrder] = useState<any>(null);
  // Auto-redirect countdown in seconds
  const [countdown, setCountdown] = useState<number | null>(null);

  // Format currency with order fallback
  const { currency: fallbackCurrency, decimals: fallbackDecimals } =
    useCurrency(order);

  const checkPaymentStatus = ({
    status,
    status_code,
    transaction_status,
  }: {
    status?: string;
    status_code?: string | number;
    transaction_status?: string;
  }) => {
    if (status === "pending" || transaction_status === "pending")
      return "pending";
    if (
      status === "success" ||
      status === "PAYMENT_SUCCESS" ||
      (status_code === "200" && transaction_status === "capture")
    )
      return "success";
    return "failed";
  };
  const isWalletTransaction = ({
    type,
    order_id,
  }: {
    type?: string;
    order_id?: string;
  }) => type === "wallet" || order_id?.startsWith("wallet-");

  const isSubscriptionTransaction = ({
    type,
    order_id,
  }: {
    type?: string;
    order_id?: string;
  }) => type === "subscription" || order_id?.startsWith("subscription-");

  const extractOrderNumber = (orderId?: string | null): string | null => {
    if (!orderId) return null;
    const regex = /^order-(\d+)-\d+$/;
    const match = orderId.match(regex);
    return match ? match[1] : /^\d+$/.test(orderId) ? orderId : null;
  };

  const clearCartState = () => {
    dispatch(setCart({ data: [] }));
    dispatch(clearCartPromo());
    dispatch(setCartSubTotal({ data: 0 }));
    dispatch(setCartProducts({ data: [] }));
    dispatch(clearCheckout());
  };

  // Clear cart state on payment success
  useEffect(() => {
    if (status === "success" && type === "order") clearCartState();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- clearCartState is a plain closure re-created each render; only status/type should re-trigger this
  }, [status, type]);

  const handlePaymentClose = async () => {
    // Server cart may already be empty; always reset local state.
    try {
      await api.deleteCart();
    } catch (error) {
      console.error("Error", error);
    } finally {
      clearCartState();
      router.replace(zoneHref("/"));
    }
  };

  const handleFailedOrder = async (
    orderId: string | number | null = null,
    { redirect = true }: { redirect?: boolean } = {},
  ) => {
    if (!query || Object.keys(query).length === 0) return;
    let localOrderId: string | number | null;
    if (orderId == null) {
      localOrderId = extractOrderNumber(query.order_id);
    } else {
      localOrderId = orderId;
    }
    try {
      await api.deleteOrder({ orderId: localOrderId });
      dispatch(clearCheckout());
      // Delete failed order
      if (redirect) router.push(zoneHref("/"));
    } catch (error) {
      console.error("Error", error);
    }
  };

  const handleWalletClose = () => {
    router.replace(zoneHref("/"));
  };

  const handleGetOrderStatusPhonepe = async (txnId) => {
    try {
      const response = await api.getOrderStatusPhonepe({
        token: phonePeData.token,
        transaction_id: phonePeData.merchantOrderId,
      });

      const remoteStatus = response?.data?.status;
      const remoteOrderId = response?.data?.order_id;
      let resolved;
      if (remoteStatus == "COMPLETED") {
        resolved = "success";
      } else if (remoteStatus == "FAILED") {
        // Delete failed order on PhonePe check
        await handleFailedOrder(remoteOrderId, { redirect: false });
        resolved = "failed";
      } else {
        await handleFailedOrder(remoteOrderId, { redirect: false });
        resolved = "pending";
      }
      // Cache status and clear PhonePe checkout details
      if (txnId) phonepeTxnResults.set(txnId, { status: resolved });
      if (resolved !== "pending") dispatch(clearPhonePeCheckoutDetails());
      // Redirect to web payment status
      const orderIdForUrl = extractOrderNumber(remoteOrderId) || remoteOrderId;
      router.replace(
        zoneHref(
          `/web-payment-status?status=${resolved}&type=order&payment_method=phonepe${
            orderIdForUrl ? `&order_id=${orderIdForUrl}` : ""
          }`,
        ),
      );
    } catch (error) {
      // Clear pending marker on error
      if (txnId) phonepeTxnResults.delete(txnId);
      console.log("error", error);
    }
  };

  // Start countdown timer when status resolves
  const finishRedirect = () => {
    if (type == "wallet" || type == "subscription") handleWalletClose();
    else if (status === "failed") handleFailedOrder();
    else handlePaymentClose();
  };
  useEffect(() => {
    if (!type || !status || status === "pending") return;
    const secs = status === "success" ? 8 : 4;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- starts the redirect countdown once type/status resolve
    setCountdown(secs);
    const tick = setInterval(() => {
      setCountdown((c) => {
        if (Number(c) <= 1) {
          clearInterval(tick);
          finishRedirect();
          return 0;
        }
        return Number(c) - 1;
      });
    }, 1000);
    return () => clearInterval(tick);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- finishRedirect is a plain closure re-created each render; effect intentionally re-runs only on type/status
  }, [type, status]);

  // Fetch Quick or ecom order details for receipt
  useEffect(() => {
    const rawId = query?.order_id;
    if (status !== "success" || type !== "order" || !rawId) return;
    const orderId = extractOrderNumber(rawId) || rawId;
    let alive = true;
    (async () => {
      try {
        const quickRes = await api.getOrders({
          limit: 1,
          offset: 0,
          orderId,
          type: "",
          orderType: "",
        });
        const quickRow = Array.isArray(quickRes?.data)
          ? quickRes.data[0]
          : quickRes?.data;
        if (quickRow) {
          if (alive) setOrder({ ...quickRow, __ecom: false });
          return;
        }
        // Fallback to ecom order fetch
        const ecomRes = await api.getEcomOrders({
          limit: 20,
          offset: 0,
          type: "",
        });
        const ecomRows = Array.isArray(ecomRes?.data) ? ecomRes.data : [];
        const ecomRow =
          ecomRows.find((r) => String(r?.order_id) === String(orderId)) || null;
        if (alive && ecomRow) setOrder({ ...ecomRow, __ecom: true });
      } catch (e) {
        console.log("order fetch (receipt) failed", e);
      }
    })();
    return () => {
      alive = false;
    };
  }, [status, type, query?.order_id]);

  // Verify PhonePe payment transaction
  useEffect(() => {
    if (!query || Object.keys(query).length === 0) return;
    if (query?.payment_method == "phonepe") {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- derives type/status from router query, which settles asynchronously
      setType("order");
      if (query?.status) {
        setStatus(query.status as "success" | "failed" | "pending");
        return;
      }
      const txnId = phonePeData?.merchantOrderId || query?.transaction_id;
      if (!txnId) return;
      const cached = phonepeTxnResults.get(txnId);
      if (cached && cached !== "pending") {
        setStatus(cached.status);
        return;
      }
      if (cached === "pending") return;
      phonepeTxnResults.set(txnId, "pending");
      handleGetOrderStatusPhonepe(txnId);
      return;
    }
    const paymentStatus = checkPaymentStatus(query);
    const isWallet = isWalletTransaction(query);
    const isSubscription = isSubscriptionTransaction(query);
    setType(isWallet ? "wallet" : isSubscription ? "subscription" : "order");
    setStatus(paymentStatus);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- handleGetOrderStatusPhonepe is a plain closure; effect intentionally re-runs only on query/phonePeData
  }, [query, phonePeData]);

  // Check if COD payment method
  const isCod =
    String(order?.payment_method || query?.payment_method || "").toLowerCase() ===
    "cod";
  const isWalletOrSub = type == "wallet" || type == "subscription";
  const goHome = isWalletOrSub ? handleWalletClose : handlePaymentClose;
  // Extract order reference ID
  const orderRef = !isWalletOrSub
    ? extractOrderNumber(query?.order_id) || query?.order_id || null
    : null;

  const prettyMethod = (m?: string | null) =>
    !m ? null : String(m).charAt(0).toUpperCase() + String(m).slice(1);

  // Currency formatting helper
  const money = (v?: number | string | null) =>
    v == null || v === ""
      ? null
      : formatCurrency(v, fallbackCurrency, fallbackDecimals || 2);
  const has = (v?: number | string | null) => v != null && Number(v) !== 0;

  // Determine display total
  const isWalletPayment =
    (order?.payment_method || query?.payment_method) === "wallet";
  const grandTotal = isWalletPayment
    ? (order?.final_total ?? order?.remaining_final)
    : (order?.remaining_final ?? order?.final_total);
  const heroAmount =
    grandTotal != null && Number(grandTotal) !== 0 ? money(grandTotal) : null;
  const paidVia = prettyMethod(order?.payment_method || query?.payment_method);

  // Build receipt metadata rows
  const metaRows: { label: string; value: string }[] = [
    (order?.order_number || orderRef) && {
      label: order?.order_number
        ? t("orderNumber") || "Order Number"
        : t("order_id") || "Order ID",
      value: order?.order_number ?? `#${orderRef}`,
    },
    has(order?.transaction_id) && {
      label: t("transaction_id") || "Transaction ID",
      value: String(order?.transaction_id),
    },
    paidVia && {
      label: t("payment_method") || "Payment Method",
      value: paidVia,
    },
  ].filter(Boolean);

  const viewOrder = () => {
    // Ecom orders open the ecom detail; URL hint only if the order never loaded.
    if (order?.__ecom && order?.id)
      router.push(zoneHref(`/order-detail/${order.id}?type=ecommerce`));
    else if (order?.id) router.push(zoneHref(`/order-detail/${order.id}`));
    else if (query?.order_from === "ecommerce" && query?.order_item_id)
      router.push(
        zoneHref(`/order-detail/${query.order_item_id}?type=ecommerce`),
      );
    else if (orderRef) router.push(zoneHref(`/order-detail/${orderRef}`));
    else router.push(zoneHref("/profile/activeorders"));
  };

  const renderContent = () => {
    if (status == "success") {
      return (
        <StatusCard
          accent="success"
          title={
            type == "wallet"
              ? t("wallet_add_success") || "Wallet Recharged!"
              : type == "subscription"
                ? t("subscription_add_success") || "Subscribed!"
                : isCod
                  ? t("order_placed_success") || "Order Placed!"
                  : t("payment_success") || "Payment Success!"
          }
          subtitle={
            type == "wallet"
              ? t("wallet_add_description")
              : type == "subscription"
                ? t("subscription_add_description")
                : t("order_placed_description") ||
                  "Your Order has been successfully placed."
          }
          heroAmount={isWalletOrSub ? null : heroAmount}
          heroLabel={
            isCod
              ? t("amount_due") || "Amount Due"
              : t("total_payment") || "Total Payment"
          }
          metaRows={isWalletOrSub ? [] : metaRows}
          art={
            animationTwo ? (
              <Lottie
                className="h-28 w-28"
                animationData={animationTwo}
                loop={false}
              />
            ) : (
              <div className="h-28 w-28" />
            )
          }
          countdown={countdown}
          onHome={goHome}
          secondary={
            !isWalletOrSub
              ? {
                  label: t("view_orders") || "View my orders",
                  onClick: viewOrder,
                }
              : undefined
          }
        />
      );
    }

    if (status == "failed") {
      return (
        <StatusCard
          accent="failed"
          title={t("payment_failed") || "Payment Failed"}
          subtitle={
            t("order_failed_sub_description") ||
            "No amount has been deducted. Please try again."
          }
          art={
            animationFailed ? (
              <Lottie
                className="h-24 w-24"
                animationData={animationFailed}
                loop={false}
              />
            ) : (
              <div className="h-24 w-24" />
            )
          }
          countdown={countdown}
          onHome={isWalletOrSub ? handleWalletClose : handleFailedOrder}
          secondary={
            !isWalletOrSub
              ? {
                  label: t("try_again") || "Try again",
                  onClick: () => router.push(zoneHref("/checkout")),
                }
              : undefined
          }
        />
      );
    }

    if (status == "pending") {
      return (
        <StatusCard
          accent="pending"
          title={t("payment_pending") || "Payment Pending"}
          subtitle={
            t("payment_pending_sub_description") ||
            "This can take a moment. We'll update your order once it's confirmed."
          }
          art={
            <span className="h-16 w-16 rounded-full border-4 border-amber-200 border-t-amber-500 animate-spin dark:border-amber-500/20 dark:border-t-amber-400" />
          }
          onHome={goHome}
        />
      );
    }

    // Initial resolving state — clean spinner, no blank flash.
    return (
      <div className="flex flex-col items-center gap-4 py-10">
        <span className="h-10 w-10 rounded-full border-4 border-black/10 border-t-[var(--primary-color)] animate-spin dark:border-white/10" />
        <p className="text-sm SecondaryTextColor">
          {t("please_wait") || "Please wait…"}
        </p>
      </div>
    );
  };

  return (
    <section className="relative bodyBackgroundColor flex items-start justify-center overflow-hidden px-4 pt-10 pb-16 sm:pt-14">
      {/* Full-screen confetti on success. */}
      {status === "success" && (
        <div className="pointer-events-none fixed inset-0 z-0">
          {animationOne && (
            <Lottie
              className="h-full w-full"
              animationData={animationOne}
              loop
              style={{ transform: "scale(1.4)" }}
            />
          )}
        </div>
      )}
      <div className="relative z-10 w-full max-w-md">{renderContent()}</div>
    </section>
  );
};

interface StatusCardProps {
  accent: "success" | "failed" | "pending";
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  heroAmount?: string | null;
  heroLabel?: string;
  metaRows?: { label: string; value: string }[];
  art: React.ReactNode;
  countdown?: number | null;
  /** Button onClick; may receive the click event. */
  onHome: (...args: any[]) => void | Promise<void>;
  secondary?: { label: string; onClick: () => void };
}

// Receipt card: seal, title, amount, rows, countdown, torn edge.
const StatusCard = ({
  accent,
  title,
  subtitle,
  heroAmount,
  heroLabel,
  metaRows = [],
  art,
  countdown,
  onHome,
  secondary,
}: StatusCardProps) => {
  const seal = {
    success: "text-emerald-500",
    failed: "text-red-500",
    pending: "text-amber-500",
  }[accent];



  return (
    <div className="ps-card relative rounded-[26px] bodyBackgroundColor border border-black/[0.05] dark:border-white/10 shadow-[0_30px_80px_-30px_rgba(0,0,0,0.35)] overflow-hidden pb-3">
      {/* premium top accent — primary gradient hairline */}
      <div
        className="h-1 w-full"
        style={{
          background:
            "linear-gradient(90deg, transparent, var(--primary-color), transparent)",
        }}
      />

      <div className="px-6 pt-7 sm:px-9 text-center">
        {/* status seal / animation with a soft radial glow behind it */}
        <div className="relative mx-auto flex items-center justify-center">
          <span
            className="pointer-events-none absolute h-24 w-24 rounded-full blur-2xl opacity-60"
            style={{
              background:
                "radial-gradient(circle, color-mix(in srgb, var(--primary-color) 30%, transparent), transparent 70%)",
            }}
          />
          <div className={`relative flex items-center justify-center ${seal}`}>
            {art}
          </div>
        </div>

        <h1 className="mt-2 text-xl sm:text-2xl font-extrabold textColor tracking-tight">
          {title}
        </h1>
        {subtitle && (
          <p className="mt-1.5 text-sm SecondaryTextColor">{subtitle}</p>
        )}
      </div>

      {/* hero amount — tinted panel so the total pops */}
      {heroAmount && (
        <div className="px-5 sm:px-7 pt-6">
          <div className="rounded-2xl primaryLightBack px-5 py-4 text-center">
            {heroLabel && (
              <p className="text-[11px] font-bold uppercase tracking-[0.16em] primaryColor dark:text-white/70">
                {heroLabel}
              </p>
            )}
            <p
              className="mt-1 text-4xl sm:text-[2.6rem] font-extrabold tracking-tight tabular-nums leading-none"
              style={{ color: "var(--primary-color)" }}
            >
              {heroAmount}
            </p>
          </div>
        </div>
      )}

      {/* meta rows — clean caption/value pairs on hairline dividers */}
      {metaRows.length > 0 && (
        <div className="px-6 sm:px-9 pt-5">
          {metaRows.map((r, i) => (
            <div
              key={r.label}
              className={`flex items-center justify-between gap-4 py-2.5 ${
                i !== metaRows.length - 1
                  ? "border-b border-black/[0.06] dark:border-white/[0.08]"
                  : ""
              }`}
            >
              <span className="text-[13px] SecondaryTextColor">{r.label}</span>
              <span className="text-[13px] font-bold textColor tabular-nums text-right break-all">
                {r.value}
              </span>
            </div>
          ))}
        </div>
      )}

      {/* actions */}
      <div className="px-6 sm:px-9 pt-6 flex flex-col items-stretch gap-2.5">
        <button
          onClick={onHome}
          className="w-full primaryBackColor text-white font-bold py-3 rounded-2xl transition hover:opacity-95 active:scale-[0.99] shadow-lg shadow-black/5"
        >
          {typeof countdown === "number" && countdown > 0
            ? `${t("home") || "Home"} · ${countdown}${t("seconds_short") || "s"}`
            : t("home") || "Home"}
        </button>

        {secondary && (
          <button
            onClick={secondary.onClick}
            className="w-full py-2.5 rounded-2xl font-semibold text-sm primaryColor dark:text-white hover:bg-black/[0.03] dark:hover:bg-white/5 transition"
          >
            {secondary.label}
          </button>
        )}

      </div>

      {/* Scalloped torn bottom edge. */}
      <div className="ps-scallop mt-5 h-3 bodyBackgroundColor" />

      <style jsx>{`
        .ps-card {
          animation: psCardIn 0.45s cubic-bezier(0.16, 1, 0.3, 1) both;
        }
        @keyframes psCardIn {
          from {
            opacity: 0;
            transform: translateY(12px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
        /* semicircle scallops along the bottom edge */
        .ps-scallop {
          -webkit-mask: radial-gradient(
            circle 6px at 6px 0,
            transparent 6px,
            #000 6.5px
          );
          mask: radial-gradient(
            circle 6px at 6px 0,
            transparent 6px,
            #000 6.5px
          );
          -webkit-mask-size: 12px 12px;
          mask-size: 12px 12px;
          -webkit-mask-position: bottom;
          mask-position: bottom;
          -webkit-mask-repeat: repeat-x;
          mask-repeat: repeat-x;
        }
        @media (prefers-reduced-motion: reduce) {
          .ps-card {
            animation: none;
          }
        }
      `}</style>
    </div>
  );
};

export default PaymentStatus;
