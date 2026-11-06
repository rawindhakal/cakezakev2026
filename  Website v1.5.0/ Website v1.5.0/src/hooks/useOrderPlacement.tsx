"use client";

import { useState } from "react";
import dynamic from "next/dynamic";
import { useSelector, useDispatch } from "react-redux";
import { useRouter } from "next/navigation";
import * as api from "@/api/apiRoutes";
import { toast } from "react-toastify";
import { t } from "@/utils/translation";
import useZoneHref from "@/hooks/useZoneHref";
import { clearCartPromo, clearPrescriptions } from "@/redux/slices/cartSlice";
import {
  setBuyerBusinessName,
  setBuyerTaxNumber,
  setPhonePeCheckoutDetails,
} from "@/redux/slices/checkoutSlice";
import { getPickupErrorMessage } from "@/utils/placeOrderErrors";
import useCurrency from "@/hooks/useCurrency";
import { toGaItem, trackPurchase } from "@/utils/analytics";
import { submitPaymentForm, redirectToGateway } from "@/utils/submitPaymentForm";
import { launchPayuSdk } from "@/utils/payuSdk";

const StripeModal = dynamic(() => import("@/components/checkoutpage/StripeModal"), {
  ssr: false,
});

export interface PlaceOrderParams {
  /** "COD" | "wallet" | gateway label */
  method: string;
  /** amount to charge at the gateway */
  payable: number;
  subTotal: number;
  deliveryCharge: number;
  finalTotal: number;
  walletUsed: boolean;
  walletBalance: number;
  addressId?: number | string;
  orderNote?: string;
  promocodeId?: number;
  /** "delivery" | "pickup" — forwarded straight to api.placeOrder */
  delivery_type?: "delivery" | "pickup";
  /** Optional for pickup location validation; defaults to city selector. */
  latitude?: number | string;
  longitude?: number | string;
  prescriptions?: any;
  /** called after the order is created (e.g. close drawer) */
  onCreated?: () => void;
  /** Cart rows for the GA4 purchase event. Quick checkout keeps its cart in
   *  local state, so redux alone can't supply them. */
  analyticsItems?: any[];
  /** default true — when false, the billing* fields below are sent */
  billingSameAsShipping?: boolean;
  billingName?: string;
  billingMobile?: string;
  billingCountryCode?: string;
  billingAddress?: string;
  billingCity?: string;
  billingState?: string;
  billingPincode?: string;
  billingCountry?: string;
  billingRegionId?: string | number;
  buyerTaxNumber?: string;
  buyerBusinessName?: string;
}

// Shared order placement and payment gateway handling for checkout and quick-checkout.
export default function useOrderPlacement() {
  const dispatch = useDispatch();
  const router = useRouter();
  const zoneHref = useZoneHref();
  const setting = useSelector((state: any) => state.Setting.setting);
  const countrySetting = useSelector((state: any) => state.CountrySetting?.countrySetting);
  const paymentSetting = useSelector((state: any) => state.Setting.payment_setting);
  const user = useSelector((state: any) => state.User.user);
  const city = useSelector((state: any) => state.City.city);
  const cart = useSelector((state: any) => state.Cart);
  const { currencyCode } = useCurrency();

  const [paymentLoading, setPaymentLoading] = useState(false);
  // Stripe embedded flow state.
  const [showStripe, setShowStripe] = useState(false);
  const [stripeClientSecret, setStripeClientSecret] = useState("");
  const [stripeTransactionId, setStripeTransactionId] = useState("");
  const [stripeOrderId, setStripeOrderId] = useState("");
  const [stripeAmount, setStripeAmount] = useState(0);


  const statusUrl = (method: string, orderId: number | string) =>
    zoneHref(
      `/web-payment-status?status=success&type=order&payment_method=${method}&order_id=${orderId}`,
    );

  // place_order returns only {status,message}; read the newest order back for its id.
  const fetchLatestOrderId = async (): Promise<number | string | null> => {
    try {
      const res: any = await api.getOrders({ limit: 1, offset: 0, type: "", orderType: "" });
      const row = Array.isArray(res?.data) ? res.data[0] : res?.data;
      return row?.id ?? row?.order_id ?? null;
    } catch (error) {
      console.log("[useOrderPlacement] fetchLatestOrderId failed", error);
      return null;
    }
  };

  const initializeRazorpay = (): Promise<boolean> =>
    new Promise((resolve) => {
      const script = document.createElement("script");
      script.src = "https://checkout.razorpay.com/v1/checkout.js";
      script.onload = () => resolve(true);
      script.onerror = () => resolve(false);
      document.body.appendChild(script);
    });

  const handleRazorpayCancel = async (orderId: number | string) => {
    await api.deleteOrder({ orderId });
  };

  const handleRazorpayPayment = async (
    orderId: number | string,
    transactionId: string,
    amount: number,
    method: string,
    capitalized: string,
    currency?: string,
  ) => {
    const ok = await initializeRazorpay();
    if (!ok) {
      console.error("Razorpay SDK load failed");
      return;
    }
    const options: any = {
      key: paymentSetting?.razorpay_key,
      amount: Math.floor(amount * 100),
      // Currency selection with fallback.
      currency: currency || countrySetting?.currency_code || setting?.currency_code || "INR",
      name: user?.name,
      description: setting?.app_name,
      image: setting?.web_settings?.web_logo,
      order_id: transactionId,
      handler: async (res: any) => {
        if (!res?.razorpay_payment_id) return;
        try {
          setPaymentLoading(true);
          const response: any = await api.addTransaction({
            orderId,
            transactionId: res.razorpay_payment_id,
            paymentMethod: capitalized,
            type: "order",
          });
          if (response.status === 1) {
            setPaymentLoading(false);
            return router.push(statusUrl(method, orderId));
          }
          setPaymentLoading(false);
          toast.error(response.message);
        } catch (error) {
          console.error("[useOrderPlacement] razorpay transaction error", error);
          setPaymentLoading(false);
        }
      },
      modal: {
        confirm_close: true,
        ondismiss: async () => {
          await handleRazorpayCancel(orderId);
        },
      },
      prefill: { name: user?.name, email: user?.email, contact: user?.mobile },
      theme: { color: setting?.web_settings?.color },
    };
    // window.Razorpay injected by SDK script.
    const rzpay = new (window as any).Razorpay(options);
    rzpay.on("payment.cancel", () => handleRazorpayCancel(orderId));
    rzpay.on("payment.failed", () => api.deleteOrder({ orderId }));
    rzpay.open();
  };

  const handlePaystackPayment = async (
    orderId: number | string,
    amount: number | string,
    method: string,
    capitalized: string,
  ) => {
    try {
      const { default: PaystackPop }: any = await import("@paystack/inline-js");
      const handler = PaystackPop.setup({
        key: paymentSetting?.paystack_public_key,
        email: user?.email,
        amount: parseFloat(String(amount)) * 100,
        currency: paymentSetting?.paystack_currency_code,
        ref: `${Date.now()}`,
        label: setting?.support_email,
        onClose: () => api.deleteOrder({ orderId }),
        callback: async (res: any) => {
          try {
            setPaymentLoading(true);
            const response: any = await api.addTransaction({
              orderId,
              transactionId: res.reference,
              paymentMethod: capitalized,
              type: "order",
            });
            if (response.status == 1) {
              setPaymentLoading(false);
              return router.push(statusUrl(method, orderId));
            }
            setPaymentLoading(false);
            toast.error(response.message);
          } catch (error) {
            console.log("[useOrderPlacement] paystack error", error);
            setPaymentLoading(false);
          }
        },
      });
      handler.openIframe();
    } catch (error) {
      console.log("[useOrderPlacement] paystack setup error", error);
    }
  };

  // Runs the gateway step for an already-created order. `payable` = amount to charge.
  const runTransaction = async (
    orderId: number | string,
    method: string,
    payable: number,
  ) => {
    const capitalized = String(method).charAt(0).toUpperCase() + String(method).slice(1);

    if (method === "COD" || method === "wallet") {
      dispatch(clearCartPromo());
      dispatch(clearPrescriptions());
      return router.push(statusUrl(method, orderId));
    }
    if (method === "paystack") {
      return handlePaystackPayment(orderId, payable, method, capitalized);
    }

    const response: any = await api.initiateTrasaction({
      orderId,
      paymentMethod: method === "payu" ? "payu" : capitalized,
      type: "order",
      latitude: city?.latitude,
      longitude: city?.longitude,
    });
    if (response.status != 1) {
      await api.deleteOrder({ orderId });
      toast.error(response?.message);
      return;
    }

    if (method === "phonepe") dispatch(setPhonePeCheckoutDetails(response?.data));

    if (method === "razorpay") {
      return handleRazorpayPayment(
        orderId,
        response?.data?.transaction_id,
        payable,
        method,
        capitalized,
        response?.data?.currency,
      );
    }
    if (method === "stripe") {
      setStripeOrderId(String(orderId));
      setStripeClientSecret(response?.data?.client_secret);
      setStripeTransactionId(response?.data?.id);
      setStripeAmount(payable);
      setShowStripe(true);
      return;
    }
    // Redirect gateways.
    dispatch(clearCartPromo());
    dispatch(clearPrescriptions());
    // PayU hosted checkout: plain redirect URL on another origin.
    if (redirectToGateway(response?.data)) return;
    // PayU returns a POST payload with sdk params and fallback form fields.
    if (response?.data?.type === "payload") {
      const payload = response?.data?.payload;
      if (payload?.sdk) {
        setPaymentLoading(true);
        const launched = await launchPayuSdk({
          payload,
          onSuccess: () => {
            setPaymentLoading(false);
            router.push(statusUrl(method, orderId));
          },
          onFailure: async (_res, reason) => {
            setPaymentLoading(false);
            if (reason === "cancel" || reason === "cancelled") {
              toast.error(t("payment_cancelled") || "Payment cancelled");
              try {
                await api.deleteOrder({ orderId });
              } catch (e) {
                console.error(e);
              }
            } else {
              router.push(
                zoneHref(
                  `/web-payment-status?status=failed&type=order&payment_method=${method}&order_id=${orderId}`,
                ),
              );
            }
          },
          onFallback: () => {
            setPaymentLoading(false);
            if (!submitPaymentForm(payload)) {
              toast.error(t("something_went_wrong"));
            }
          },
        });
        if (launched) return;
      }
      if (submitPaymentForm(payload)) return;
      toast.error(t("something_went_wrong"));
      return;
    }
    const redirectUrls: Record<string, string | undefined> = {
      cashfree: response?.data?.redirectUrl,
      phonepe: response?.data?.redirectUrl,
      paytabs: response?.data?.redirectUrl,
      paypal: response?.data?.paypal_redirect_url,
      midtrans: response?.data?.snapUrl,
      // PayU without the SDK payload: hosted checkout link.
      payu: response?.data?.url,
    };
    const url =
      redirectUrls[method] ||
      (response?.data?.type === "redirect" ? response?.data?.url : undefined);
    if (!url) {
      console.error("[useOrderPlacement] unsupported method:", method);
      return;
    }
    // Gateway checkouts live off-origin; router.push can't leave the app.
    if (/^https?:\/\//i.test(url)) window.location.assign(url);
    else router.push(url);
  };

  // Create order and trigger payment workflow.
  const placeOrder = async ({
    method,
    payable,
    analyticsItems,
    subTotal,
    deliveryCharge,
    finalTotal,
    walletUsed,
    walletBalance,
    addressId,
    orderNote = "",
    promocodeId = 0,
    delivery_type,
    latitude,
    longitude,
    prescriptions = null,
    onCreated,
    billingSameAsShipping = true,
    billingName = "",
    billingMobile = "",
    billingCountryCode = "",
    billingAddress = "",
    billingCity = "",
    billingState = "",
    billingPincode = "",
    billingCountry = "",
    billingRegionId,
    buyerTaxNumber = "",
    buyerBusinessName = "",
  }: PlaceOrderParams): Promise<boolean> => {
    // COD & wallet settle immediately (status 2); gateways create as pending (1).
    const status = method === "COD" || method === "wallet" ? 2 : 1;
    setPaymentLoading(true);
    try {
      const response: any = await api.placeOrder({
        total: subTotal,
        deliveryCharge,
        finalTotal,
        walletUsed,
        walletBalance,
        addressId,
        orderNote,
        paymentMethod: method,
        promocodeId,
        status,
        delivery_type,
        latitude: latitude ?? city?.latitude,
        longitude: longitude ?? city?.longitude,
        prescriptions,
        billingSameAsShipping,
        billingName,
        billingMobile,
        billingCountryCode,
        billingAddress,
        billingCity,
        billingState,
        billingPincode,
        billingCountry,
        billingRegionId,
        buyerTaxNumber,
        buyerBusinessName,
      });
      if (response?.status != 1) {
        toast.error(
          getPickupErrorMessage(response?.message) ||
            response?.message ||
            t("something_went_wrong"),
        );
        setPaymentLoading(false);
        return false;
      }
      // Tax number is per order — don't carry it into the next one.
      dispatch(setBuyerTaxNumber({ data: "" }));
      dispatch(setBuyerBusinessName({ data: "" }));
      let orderId = response?.order_id ?? response?.data?.order_id;
      if (!orderId) orderId = await fetchLatestOrderId();
      // GA4 purchase. Fired on order creation, not gateway settlement — a
      // pending gateway order still counts, same as the backend's order list.
      const purchasedItems = (analyticsItems ?? cart?.checkout?.cart ?? []).map((p: any) =>
        toGaItem(
          p,
          p?.variants?.[0],
          Number(p?.variants?.[0]?.quantity ?? p?.qty) || 1,
        ),
      );
      trackPurchase({
        transactionId: orderId,
        value: Number(finalTotal) || 0,
        currency: currencyCode,
        shipping: Number(deliveryCharge) || 0,
        items: purchasedItems,
      });
      onCreated?.();
      await runTransaction(orderId, method, payable);
      setPaymentLoading(false);
      return true;
    } catch (error: any) {
      console.error("[useOrderPlacement] placeOrder failed", error);
      toast.error(error?.message || t("something_went_wrong"));
      setPaymentLoading(false);
      return false;
    }
  };

  // Cast StripeModal to any to bypass unneeded setWalletModal prop.
  const StripeModalAny = StripeModal as any;
  const StripePortal = showStripe ? (
    <StripeModalAny
      showStripe={showStripe}
      setShowStripe={setShowStripe}
      amount={stripeAmount}
      clientSecret={stripeClientSecret}
      stripeTransId={stripeTransactionId}
      stripeOrderId={stripeOrderId}
      type="order"
    />
  ) : null;

  return { placeOrder, paymentLoading, StripePortal };
}
