"use client";
import { useRef, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { useRouter } from "next/navigation";
import { toast } from "react-toastify";
import * as api from "@/api/apiRoutes";
import useZoneHref from "@/hooks/useZoneHref";
import { clearCartPromo } from "@/redux/slices/cartSlice";
import { setPhonePeCheckoutDetails } from "@/redux/slices/checkoutSlice";
import { submitPaymentForm, redirectToGateway } from "@/utils/submitPaymentForm";
import { launchPayuSdk } from "@/utils/payuSdk";
import { t } from "@/utils/translation";

// Paystack touches window at import; load client-side only.
let PaystackPop: any;
if (typeof window !== "undefined") {
  import("@paystack/inline-js").then((module) => {
    PaystackPop = module.default;
  });
}

interface UseCheckoutPaymentOptions {
  /** Wallet-reduced amount to charge. */
  payable: number;
  currencyCode?: string;
  setPaymentLoading: (loading: boolean) => void;
}

// Hands a placed order off to COD/wallet/online gateways.
const useCheckoutPayment = ({
  payable,
  currencyCode,
  setPaymentLoading,
}: UseCheckoutPaymentOptions) => {
  const router = useRouter();
  const zoneHref = useZoneHref();
  const dispatch = useDispatch();
  const user = useSelector((state: any) => state.User.user);
  const setting = useSelector((state: any) => state.Setting);
  const selectedMethod = useSelector(
    (state: any) => state.Checkout.selectedPaymentMethod,
  );

  // Ecom order_item_id from place_order.
  const orderItemIdRef = useRef<number | string | null>(null);
  const [showStripe, setShowStripe] = useState(false);
  const [stripeOrderId, setStripeOrderId] = useState<number | string | null>(null);
  const [stripeClientSecret, setStripeClientSecret] = useState<string | null>(null);
  const [stripeTransactionId, setStripeTransactionId] = useState<string | null>(null);

  // Ecom params for the status URL (empty for quick).
  const statusOrderSuffix = () =>
    orderItemIdRef.current
      ? `&order_item_id=${orderItemIdRef.current}&order_from=ecommerce`
      : "";

  const goToSuccess = (method: string, orderId: number | string) =>
    router.push(
      zoneHref(
        `/web-payment-status?status=success&type=order&payment_method=${method}&order_id=${orderId}${statusOrderSuffix()}`,
      ),
    );

  // Record the gateway transaction, then go to the status page.
  const confirmTransaction = async (
    orderId: number | string,
    transactionId: string,
    capitalizedMethod: string,
  ) => {
    setPaymentLoading(true);
    const response = await api.addTransaction({
      orderId,
      transactionId,
      paymentMethod: capitalizedMethod,
      type: "order",
    });
    setPaymentLoading(false);
    if (response.status == 1) return goToSuccess(selectedMethod, orderId);
    toast.error(response.message);
  };

  const initializeRazorpay = (): Promise<boolean> =>
    new Promise((resolve) => {
      const script = document.createElement("script");
      script.src = "https://checkout.razorpay.com/v1/checkout.js";
      script.onload = () => resolve(true);
      script.onerror = () => resolve(false);
      document.body.appendChild(script);
    });

  const handleRazorpayPayment = async (
    orderId: number | string,
    razorpayTransactionId: string,
    capitalizedMethod: string,
  ) => {
    try {
      if (!(await initializeRazorpay())) {
        console.error("RazorPay SDK Load Failed");
        return;
      }
      const cancelOrder = () => api.deleteOrder({ orderId });
      // Razorpay SDK is untyped.
      const options: any = {
        key: setting?.payment_setting?.razorpay_key,
        amount: Math.floor(payable * 100),
        currency: currencyCode ?? "",
        name: user?.name,
        description: setting?.setting?.app_name,
        image: setting?.setting?.web_settings?.web_logo,
        order_id: razorpayTransactionId,
        handler: async (res: any) => {
          if (!res.razorpay_payment_id) return;
          try {
            await confirmTransaction(orderId, res.razorpay_payment_id, capitalizedMethod);
          } catch (error) {
            console.error("Transaction error:", error);
          }
        },
        modal: { confirm_close: true, ondismiss: cancelOrder },
        prefill: { name: user?.name, email: user?.email, contact: user?.mobile },
        theme: { color: setting?.setting?.web_settings?.color },
      };
      const rzpay = new (window as any).Razorpay(options);
      rzpay.on("payment.cancel", cancelOrder);
      rzpay.on("payment.failed", cancelOrder);
      rzpay.open();
    } catch (error) {
      console.error("Error initializing Razorpay:", error);
    }
  };

  const handlePayStackPayment = (
    orderId: number | string,
    capitalizedMethod: string,
  ) => {
    try {
      const handler = PaystackPop.setup({
        key: setting?.payment_setting?.paystack_public_key,
        email: user?.email,
        amount: Number.parseFloat(String(payable)) * 100,
        currency: setting?.payment_setting?.paystack_currency_code,
        ref: new Date().getTime().toString(),
        label: setting?.setting?.support_email,
        onClose: () => api.deleteOrder({ orderId }),
        callback: async (res: any) => {
          try {
            await confirmTransaction(orderId, res.reference, capitalizedMethod);
          } catch (error) {
            console.log("Error", error);
          }
        },
      });
      handler.openIframe();
    } catch (error) {
      console.log("Paystack Error", error);
    }
  };

  const initiateTransaction = async (
    orderId: number | string,
    capitalizedMethod: string,
  ) => {
    const method = selectedMethod;
    try {
      if (method == "COD" || method == "wallet") return goToSuccess(method, orderId);
      if (method == "paystack") return handlePayStackPayment(orderId, capitalizedMethod);

      const response = await api.initiateTrasaction({
        orderId,
        paymentMethod: method === "payu" ? "payu" : capitalizedMethod,
        type: "order",
      });
      if (response.status != 1) {
        // Delete the order just created.
        await api.deleteOrder({ orderId });
        toast.error(response?.message);
        return;
      }
      if (method == "phonepe") dispatch(setPhonePeCheckoutDetails(response?.data));
      if (method == "razorpay") {
        handleRazorpayPayment(orderId, response?.data?.transaction_id, capitalizedMethod);
      } else if (method == "stripe") {
        setStripeOrderId(orderId);
        setStripeClientSecret(response?.data?.client_secret);
        setStripeTransactionId(response?.data?.id);
        setShowStripe(true);
      } else {
        dispatch(clearCartPromo());
        // PayU hosted checkout: plain redirect URL on another origin.
        if (redirectToGateway(response?.data)) return;
        // PayU returns a POST payload with sdk params and fallback form fields.
        if (response?.data?.type === "payload") {
          const payload = response?.data?.payload;
          if (payload?.sdk) {
            const launched = await launchPayuSdk({
              payload,
              onSuccess: () => {
                router.push(
                  zoneHref(
                    `/web-payment-status?status=success&type=order&payment_method=${method}&order_id=${orderId}${statusOrderSuffix()}`,
                  ),
                );
              },
              onFailure: async (_res, reason) => {
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
                      `/web-payment-status?status=failed&type=order&payment_method=${method}&order_id=${orderId}${statusOrderSuffix()}`,
                    ),
                  );
                }
              },
              onFallback: () => {
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
        const paymentUrls: Record<string, string | undefined> = {
          cashfree: response?.data?.redirectUrl,
          phonepe: response?.data?.redirectUrl,
          paytabs: response?.data?.redirectUrl,
          paypal: response?.data?.paypal_redirect_url,
          midtrans: response?.data?.snapUrl,
        };
        const redirectUrl = paymentUrls[method];
        if (redirectUrl) router.push(redirectUrl);
        else console.error("Unsupported payment method:", method);
      }
    } catch (error) {
      console.log("Error", error);
    }
  };

  const setOrderItemId = (id: number | string | null) => {
    orderItemIdRef.current = id;
  };

  return {
    setOrderItemId,
    initiateTransaction,
    stripe: {
      show: showStripe,
      setShow: setShowStripe,
      orderId: stripeOrderId,
      clientSecret: stripeClientSecret,
      transactionId: stripeTransactionId,
    },
  };
};

export default useCheckoutPayment;
