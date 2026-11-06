import React, { useEffect, useMemo, useRef, useState } from "react";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { useSelector, useDispatch } from "react-redux";
import { t } from "@/utils/translation";
import * as api from "@/api/apiRoutes";
import { toast } from "react-toastify";
import useOrderPlacement from "@/hooks/useOrderPlacement";
import useStoreClosed from "@/hooks/useStoreClosed";
import { setAllAddresses, setSelectedAddresForEdit } from "@/redux/slices/addressSlice";
import { clearCartPromo } from "@/redux/slices/cartSlice";
import { setDeliveryType } from "@/redux/slices/checkoutSlice";
import { hasMissingRequiredPrescriptions } from "@/utils/helperFunction";
import DeliveryModeToggle from "./DeliveryModeToggle";
import AppliedCouponCard from "./AppliedCouponCard";
import UnlockCouponNudge from "./UnlockCouponNudge";
import {
  RiMapPin2Line,
  RiHome4Line,
  RiBriefcase4Line,
  RiWallet3Line,
  RiMoneyDollarCircleLine,
  RiAddLine,
  RiPencilLine,
  RiCheckLine,
  RiArrowLeftLine,
} from "react-icons/ri";
import { FiInfo, FiCreditCard } from "react-icons/fi";
import { MdOutlineCelebration } from "react-icons/md";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import CartDrawerSkeletons from "./CartDrawerLoading";
import CartProductsCard from "./CartDrawerProductsCard";
import RazorpayLogo from "@/assets/payment_methods_svgs/ic_razorpay.svg";
import PaypalLogo from "@/assets/payment_methods_svgs/ic_paypal.svg";
import PaystackLogo from "@/assets/payment_methods_svgs/ic_paystack.svg";
import StripeLogo from "@/assets/payment_methods_svgs/ic_stripe.svg";
import CashfreeLogo from "@/assets/payment_methods_svgs/ic_cashfree.svg";
import MidtransLogo from "@/assets/payment_methods_svgs/Midtrans.svg";
import PhonePeLogo from "@/assets/payment_methods_svgs/Phonepe.svg";
import PaytabsLogo from "@/assets/payment_methods_svgs/ic_paytabs.svg";
import PayuLogo from "@/assets/payment_methods_svgs/payu.png";

// Untyped JS.
import PlaceOrderProgress from "@/components/checkoutpage/UI/PlaceOrderProgress";
import NewAddressModalUntyped from "@/components/newaddressmodal/NewAddressModal";
const NewAddressModal = NewAddressModalUntyped as any;
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import PhoneNumberInput from "@/components/phonenumberinput/PhoneNumberInput";
import useBillingDetails from "@/hooks/useBillingDetails";
import useBuyerTaxField from "@/hooks/useBuyerTaxField";
import BuyerTaxDetails from "@/components/checkoutpage/UI/BuyerTaxDetails";
import usePendingCouponAutoApply from "@/hooks/usePendingCouponAutoApply";
import CouponAutoApplyError from "./CouponAutoApplyError";
import AnimatedNumber from "@/components/ui/AnimatedNumber";
import { cartLineKey } from "@/utils/addons";
import GiftDetails from "@/components/gifting/GiftDetails";

// Online gateways keyed by payment_setting flag (COD/wallet handled separately).
const GATEWAYS = [
  { key: "razorpay_payment_method", value: "razorpay", logo: RazorpayLogo },
  { key: "paypal_payment_method", value: "paypal", logo: PaypalLogo },
  { key: "paystack_payment_method", value: "paystack", logo: PaystackLogo },
  { key: "stripe_payment_method", value: "stripe", logo: StripeLogo },
  { key: "cashfree_payment_method", value: "cashfree", logo: CashfreeLogo },
  { key: "midtrans_payment_method", value: "midtrans", logo: MidtransLogo },
  { key: "phonepay_payment_method", value: "phonepe", logo: PhonePeLogo },
  { key: "paytabs_payment_method", value: "paytabs", logo: PaytabsLogo },
  { key: "payu_payment_method", value: "payu", logo: PayuLogo },
];

const CheckCircle = ({ active }: { active: boolean }) => (
  <span
    className={`relative flex h-6 w-6 shrink-0 items-center justify-center rounded-full border-2 transition-colors ${
      active
        ? "border-transparent text-white"
        : "border-[color-mix(in_srgb,var(--primary-color)_35%,transparent)]"
    }`}
  >
    {active && (
      <>
        <span aria-hidden className="ckAnimRipple absolute inset-0 rounded-full primaryBackColor" />
        <span aria-hidden className="ckAnimDotIn absolute inset-0 rounded-full primaryBackColor" />
        <RiCheckLine size={15} className="ckAnimDotIn relative" />
      </>
    )}
  </span>
);

interface QuickCheckoutViewProps {
  onClose: () => void;
  money: (amount?: number | string) => string;
  currency?: string;
  decimals?: number;
  cartProductsData?: any[];
  /** Hands a row up to the drawer, which swaps in its addon editor screen. */
  onEditAddons?: (line: any) => void;
  setCartProductsData: React.Dispatch<React.SetStateAction<any[]>>;
  setCartData?: React.Dispatch<React.SetStateAction<any>>;
  onViewCoupons: () => void;
}

// Single-page in-drawer checkout: items, address, payment, bill on one scroll.
// getAddress → getCart(checkout:1) → placeOrder (useOrderPlacement).
const QuickCheckoutView = ({
  onClose,
  money,
  currency,
  decimals,
  cartProductsData = [],
  onEditAddons,
  setCartProductsData,
  setCartData,
  onViewCoupons,
}: QuickCheckoutViewProps) => {
  const dispatch = useDispatch();
  const pathname = usePathname();
  const { storeClosed, notifyClosed, closedProps } = useStoreClosed();
  const cart = useSelector((state: any) => state.Cart);
  const user = useSelector((state: any) => state.User);
  const paymentSetting = useSelector((state: any) => state.Setting.payment_setting);
  const city = useSelector((state: any) => state.City.city);
  const shopMode = useSelector((state: any) => state.ShopMode.mode);
  const appliedCoupon = useSelector((state: any) => state.Cart.promo_code);
  const prescriptions = useSelector((state: any) => state.Cart.prescriptions);
  const deliveryType = useSelector(
    (state: any) => state.Checkout.deliveryType as "delivery" | "pickup",
  );
  const { placeOrder, paymentLoading, StripePortal } = useOrderPlacement();

  const [addresses, setAddresses] = useState<any[]>([]);
  const [selectedAddress, setSelectedAddress] = useState<any>(null);
  const [addressLoading, setAddressLoading] = useState(true);
  // Spec follows the billed party's country — resolve it from its coordinates.
  const buyerTaxField = useBuyerTaxField({
    latitude: selectedAddress?.latitude ?? city?.latitude,
    longitude: selectedAddress?.longitude ?? city?.longitude,
  });
  const [checkoutData, setCheckoutData] = useState<any>(null);
  // Response's delivery_type wins — redux can carry a stale "pickup".
  const isPickup = checkoutData
    ? checkoutData.delivery_type === "pickup"
    : deliveryType === "pickup";
  const [totalsLoading, setTotalsLoading] = useState(false);
  // "COD" | "wallet" | gateway value.
  const [paymentMethod, setPaymentMethod] = useState<string | null>(null);
  const [useWallet, setUseWallet] = useState(false);
  const [showAddAddress, setShowAddAddress] = useState(false);
  // Modal's isAddressSelected = edit mode (prefilled) vs blank.
  const [isEditingAddress, setIsEditingAddress] = useState(false);
  const [orderNote, setOrderNote] = useState("");
  const billingDetails = useBillingDetails();
  const buyerTaxNumber = useSelector(
    (state: any) => state.Checkout.buyerTaxNumber,
  );
  const buyerBusinessName = useSelector(
    (state: any) => state.Checkout.buyerBusinessName,
  );
  // Pickup: inline Bill To fields sent as billing_* (no saved address created).
  const [showManualBilling, setShowManualBilling] = useState(false);
  const paymentSectionRef = useRef<HTMLElement>(null);
  const cartSectionRef = useRef<HTMLElement>(null);
  const [showAllAddresses, setShowAllAddresses] = useState(false);
  const mountFetchedRef = useRef(false);

  // Close on the payment-status page — client nav keeps the drawer mounted.
  useEffect(() => {
    if (pathname?.includes("web-payment-status")) onClose?.();
  }, [pathname, onClose]);

  const walletBalance = Number(user?.user?.balance || 0);
  const enabledGateways = GATEWAYS.filter(
    (g) => paymentSetting?.[g.key] === "1",
  );

  const formatAddress = (a: any) =>
    [a?.address, a?.area, a?.city, a?.state, a?.pincode, a?.country]
      .filter(Boolean)
      .join(", ");

  const addressIcon = (type?: string) => {
    const key = String(type || "").toLowerCase();
    if (key === "home") return RiHome4Line;
    if (key === "work" || key === "office") return RiBriefcase4Line;
    return RiMapPin2Line;
  };

  // selectNewestFrom = prior ids; the new id gets auto-selected. Only the
  // latest request's response is applied.
  const loadAddressesSeqRef = useRef(0);
  const loadAddresses = async ({
    selectNewestFrom,
  }: { selectNewestFrom?: any[] } = {}) => {
    const seq = ++loadAddressesSeqRef.current;
    setAddressLoading(true);
    try {
      const res: any = await api.getAddress();
      if (seq !== loadAddressesSeqRef.current) return;
      const list = Array.isArray(res?.data) ? res.data : [];
      setAddresses(list);
      // Modal reads allAddresses for its prior-id snapshot.
      dispatch(setAllAddresses({ data: list }));
      let newest: any;
      if (Array.isArray(selectNewestFrom)) {
        const prev = new Set(selectNewestFrom);
        newest = list.find((a: any) => !prev.has(a?.id));
      }
      // Keep current selection, swapped for its fresh (possibly edited) copy.
      setSelectedAddress(
        (current: any) =>
          newest ||
          list.find((a: any) => a?.id === current?.id) ||
          list.find((a: any) => a?.is_default == 1) ||
          list[0] ||
          null,
      );
    } catch (error) {
      if (seq !== loadAddressesSeqRef.current) return;
      console.log("[quick-checkout] getAddress failed", error);
    } finally {
      if (seq === loadAddressesSeqRef.current) setAddressLoading(false);
    }
  };

  useEffect(() => {
    // Once per mount (StrictMode double-invokes).
    if (mountFetchedRef.current) return;
    mountFetchedRef.current = true;

    loadAddresses();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Checkout totals. Pickup prices at city coords — the picked address is only
  // a Bill To. With no address yet, city coords still resolve mode availability.
  useEffect(() => {
    let alive = true;
    (async () => {
      setTotalsLoading(true);
      try {
        const res = await api.getCart({
          latitude: isPickup
            ? city?.latitude
            : (selectedAddress?.latitude ?? city?.latitude),
          longitude: isPickup
            ? city?.longitude
            : (selectedAddress?.longitude ?? city?.longitude),
          checkout: 1,
          promocode_id: cart?.promo_code?.promo_code_id || 0,
          address_id: selectedAddress?.id,
          delivery_type: deliveryType,
        });
        if (!alive) return;
        if (res?.status == 1) {
          setCheckoutData(res?.data);
        } else {
          setCheckoutData(null);
          // Delivery errors don't apply to pickup.
          if (res?.message && !isPickup) toast.error(res.message);
        }
      } catch (error) {
        console.log("[quick-checkout] getCart(checkout) failed", error);
      } finally {
        if (alive) setTotalsLoading(false);
      }
    })();
    return () => {
      alive = false;
    };
    // Address pricing fields watched (edits keep the id; state flips IGST vs
    // CGST+SGST). cartSubTotal refreshes the bill on every +/-.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    selectedAddress?.id,
    selectedAddress?.state,
    selectedAddress?.pincode,
    selectedAddress?.latitude,
    selectedAddress?.longitude,
    cart?.promo_code?.promo_code_id,
    cart?.cartSubTotal,
    deliveryType,
  ]);

  // API sends delivery_charge as scalar, object, or delivery_charges — handle all.
  const deliveryChargeObj =
    (typeof checkoutData?.delivery_charge === "object"
      ? checkoutData?.delivery_charge
      : null) || checkoutData?.delivery_charges;
  const deliveryCharge = useMemo(() => {
    const val =
      deliveryChargeObj?.total_delivery_charge ??
      deliveryChargeObj?.amount ??
      (typeof checkoutData?.delivery_charge === "object"
        ? undefined
        : checkoutData?.delivery_charge);
    return Number(val || 0);
  }, [checkoutData, deliveryChargeObj]);

  const deliveryChargeTax = deliveryChargeObj;

  const subTotal = Number(checkoutData?.sub_total ?? cart?.cartSubTotal ?? 0);
  usePendingCouponAutoApply({
    active: true,
    hasItems: cartProductsData?.length > 0,
    subTotal,
  });
  const totalAmount = Number(checkoutData?.total_amount ?? subTotal);
  const codAllowed = checkoutData?.cod_allowed == "1";
  // Per-address deliverability from the cart API. Callers gate on !isPickup.
  const isDeliverable =
    checkoutData == null ||
    (Number(checkoutData?.delivery_available) === 1 &&
      Number(checkoutData?.is_deliverable_address) === 1);
  // Some SKUs are zone-restricted even when the address is deliverable.
  const undeliverableVariantIds = new Set(
    (checkoutData?.undeliverable_variant_ids ?? []).map((id: any) =>
      String(id),
    ),
  );
  const walletCoversAll = walletBalance >= totalAmount && totalAmount > 0;

  // "wallet" coupons are cashback — they don't reduce the price.
  const isCashbackCoupon = appliedCoupon?.discount_apply_type === "wallet";
  const promoDiscount = Number(appliedCoupon?.discount || 0);
  const productSaved = Number(checkoutData?.saved_amount || 0);
  // saved_amount already includes the promo — don't add it again.
  const totalSaved = productSaved;

  // Display-only charge rows (already in total_amount); taxAmount is inclusive.
  const chargeRows: {
    label: string;
    amount: number;
    refundable?: any;
    taxAmount?: number;
    taxName?: string;
  }[] = [
    ...(checkoutData?.additional_charges || []).map((c: any) => ({
      label: c?.title,
      amount: Number(c?.amount || 0),
      refundable: undefined,
    })),
    ...(checkoutData?.surge_charges || []).map((c: any) => ({
      label: c?.label,
      amount: Number(c?.charge || 0),
      refundable: c?.is_refundable,
      taxAmount: Number(c?.tax_amount || 0),
      taxName: c?.tax_name,
    })),
    ...(checkoutData?.zone_additional_charges || []).map((c: any) => ({
      label: c?.name,
      amount: Number(c?.amount || 0),
      refundable: c?.is_refundable,
      taxAmount: Number(c?.tax_amount || 0),
      taxName: c?.tax_name,
    })),
  ].filter((r) => r.label);

  // Subtotal tax tooltip rows. Gate on rows, not tax_breakdown_available
  // (unreliable).
  const taxBreakdownRows = (checkoutData?.tax_breakdown || []).filter(
    (tx: any) => Number(tx?.amount) > 0,
  );

  const walletUsedAmount = useWallet ? Math.min(walletBalance, totalAmount) : 0;
  const payable = Math.max(totalAmount - walletUsedAmount, 0);

  let walletStatusLabel;
  if (walletCoversAll) {
    walletStatusLabel = useWallet
      ? t("pay_fully_with_wallet") || "Paying fully with wallet"
      : t("pay_fully_with_wallet") || "Pay fully with wallet";
  } else if (useWallet) {
    walletStatusLabel = `${t("wallet_applied") || "Applied"} ${money(walletUsedAmount)}`;
  } else {
    walletStatusLabel = t("redeem_at_checkout") || "Redeem at checkout";
  }

  // Partial wallet rides along; the chosen method pays the rest.
  const effectiveMethod =
    useWallet && walletCoversAll ? "wallet" : paymentMethod;

  const missingRx = hasMissingRequiredPrescriptions(
    cartProductsData,
    prescriptions,
  );

  // Pickup: saved address OR inline billing (isFilled, not isValid — no
  // shipping address to be "same as").
  const addressSatisfied = isPickup
    ? !!selectedAddress || billingDetails.isFilled
    : !!selectedAddress;

  const canPlace =
    addressSatisfied &&
    !paymentLoading &&
    !totalsLoading &&
    !!effectiveMethod &&
    !missingRx;

  const handlePlaceOrder = async () => {
    if (storeClosed) {
      notifyClosed();
      return;
    }
    if (!isPickup && !selectedAddress) {
      toast.error(t("please_select_address"));
      return;
    }
    if (isPickup && !selectedAddress && !billingDetails.isFilled) {
      toast.error(
        t("please_select_address_or_fill_billing_details") ||
          "Please pick an address or fill in billing details",
      );
      return;
    }
    if (!isPickup && !isDeliverable) {
      toast.error(t("sorry_we_are_not_delivering_on_selected_address"));
      return;
    }
    if (!effectiveMethod) {
      toast.error(t("please_select_payment_method"));
      return;
    }
    if (missingRx) {
      toast.error(
        t("please_upload_required_prescription") ||
          "Please upload a prescription for all required medical items",
      );
      return;
    }
    if (!isPickup && !billingDetails.isValid) {
      toast.error(
        t("please_fill_billing_details") || "Please fill in billing details",
      );
      return;
    }
    const buyerTaxError = buyerTaxField.validate(buyerTaxNumber);
    if (buyerTaxError) {
      toast.error(buyerTaxError);
      return;
    }
    // Only COD/wallet close the drawer — gateways (Stripe modal etc.) live here.
    const settlesInline =
      effectiveMethod === "COD" || effectiveMethod === "wallet";

    await placeOrder({
      analyticsItems: checkoutData?.cart,
      method: effectiveMethod,
      payable,
      subTotal,
      deliveryCharge,
      finalTotal: payable,
      walletUsed: useWallet,
      walletBalance: walletUsedAmount,
      // Shipping for delivery, Bill To for pickup.
      addressId: selectedAddress?.id,
      orderNote: orderNote?.trim() || "",
      promocodeId: cart?.promo_code?.promo_code_id || 0,
      delivery_type: deliveryType,
      latitude: selectedAddress?.latitude ?? city?.latitude,
      longitude: selectedAddress?.longitude ?? city?.longitude,
      prescriptions,
      onCreated: settlesInline ? () => onClose?.() : undefined,
      // Pickup w/o address: force false (checkbox hidden, defaults true) or
      // the backend ignores the typed fields.
      billingSameAsShipping:
        isPickup && !selectedAddress
          ? false
          : billingDetails.billing.sameAsShipping,
      billingName: billingDetails.billing.name,
      billingMobile: billingDetails.billing.mobile,
      billingCountryCode: billingDetails.billing.countryCode,
      billingAddress: billingDetails.billing.address,
      billingCity: billingDetails.billing.city,
      billingState: billingDetails.billing.state,
      billingPincode: billingDetails.billing.pincode,
      billingCountry: billingDetails.billing.country,
      billingRegionId: billingDetails.regionIdToSend,
      buyerTaxNumber: buyerTaxField.enabled ? buyerTaxNumber : "",
      buyerBusinessName: buyerTaxField.enabled ? buyerBusinessName : "",
    });
  };

  // CTA guides to the next missing step instead of sitting disabled.
  const cta = (() => {
    if (!isPickup && !selectedAddress)
      return {
        label: t("add_new_address") || "Add New Address",
        action: () => setShowAddAddress(true),
        ready: false,
      };
    if (!isPickup && !isDeliverable)
      return {
        label: t("sorry_we_are_not_delivering_on_selected_address"),
        action: () => setShowAllAddresses(true),
        ready: false,
        blocked: true,
      };
    if (!effectiveMethod)
      return {
        label: t("select_payment_method") || "Select Payment Method",
        action: () =>
          paymentSectionRef.current?.scrollIntoView({
            behavior: "smooth",
            block: "center",
          }),
        ready: false,
      };
    if (missingRx)
      return {
        label: t("upload_prescription") || "Upload Prescription",
        action: () => {
          toast.error(
            t("please_upload_required_prescription") ||
              "Please upload a prescription for all required medical items",
          );
          cartSectionRef.current?.scrollIntoView({
            behavior: "smooth",
            block: "start",
          });
        },
        ready: false,
      };
    return {
      label: t("place_order") || "Place Order",
      action: handlePlaceOrder,
      ready: true,
    };
  })();

  // False positive: refs are only touched inside cta.action click handlers.
  // eslint-disable-next-line react-hooks/refs
  const ctaClosedSpreadProps = cta.ready ? closedProps : {};
  // eslint-disable-next-line react-hooks/refs
  const ctaClosedClassName = cta.ready ? (closedProps.className ?? "") : "";

  return (
    <>
      {/* flex-1 min-h-0, not h-full — h-full pushed the footer off-screen. */}
      <div className="flex min-h-0 flex-1 flex-col bodyBackgroundColor">
        <div className="flex-grow space-y-4 overflow-y-auto p-4">
          {checkoutData && (
            <DeliveryModeToggle
              checkoutData={checkoutData}
              totalsLoading={totalsLoading}
              onBeforeToggle={() => setTotalsLoading(true)}
            />
          )}

          {/* Address pill, expands to the picker. Delivery: shipping; pickup: Bill To. */}
          {addressLoading ? (
            <section className="bodyBackgroundColor cardBorderPrimary !rounded-lg p-4 shadow-sm">
              <CartDrawerSkeletons />
            </section>
          ) : !showAllAddresses && selectedAddress ? (
            <button
              type="button"
              onClick={() => setShowAllAddresses(true)}
              className="flex w-full items-center gap-2.5 cardBorderPrimary !rounded-lg bodyBackgroundColor px-4 py-3 text-start shadow-sm transition-colors hover:primaryLightBack"
            >
              <RiMapPin2Line size={18} className="primaryColor shrink-0" />
              <div className="flex min-w-0 flex-grow flex-col">
                <span className="truncate text-sm font-bold textColor">
                  {isPickup
                    ? t("billing_address") || "Billing address"
                    : t("deliver_to") || "Deliver to"}{" "}
                  {selectedAddress?.type || selectedAddress?.name}
                </span>
                <span className="truncate text-xs SecondaryTextColor leading-snug">
                  {formatAddress(selectedAddress)}
                </span>
              </div>
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full primaryLightBack primaryColor">
                <RiPencilLine size={14} />
              </span>
            </button>
          ) : (
            <section className="bodyBackgroundColor cardBorderPrimary !rounded-lg shadow-sm">
              <div className="flex items-center justify-between gap-3 border-b px-4 py-2.5">
                <span className="flex min-w-0 items-center gap-2 font-bold text-base textColor">
                  <RiMapPin2Line size={17} className="primaryColor shrink-0" />
                  <span className="truncate">
                    {isPickup
                      ? t("billing_address") || "Billing Address"
                      : t("delivery_address")}
                  </span>
                </span>
              </div>
              <div className="p-4 flex flex-col gap-3">
                {addresses.length === 0 && !showManualBilling && (
                  <button
                    type="button"
                    onClick={() =>
                      isPickup
                        ? setShowManualBilling(true)
                        : setShowAddAddress(true)
                    }
                    className="flex w-full items-center justify-center gap-2 rounded-lg border-2 border-dashed border-[color-mix(in_srgb,var(--primary-color)_25%,transparent)] py-4 text-sm font-semibold primaryColor"
                  >
                    <RiAddLine size={18} />
                    {t("add_new_address") || "Add New Address"}
                  </button>
                )}

                {addresses.length > 0 && !showManualBilling && (
                  <div className="flex flex-col gap-2">
                    {addresses.map((addr) => {
                      const Icon = addressIcon(addr?.type);
                      const active = selectedAddress?.id === addr?.id;
                      return (
                        <label
                          key={addr?.id}
                          className={`relative flex items-center gap-2.5 rounded-lg border p-3 cursor-pointer transition ${
                            active
                              ? "primaryColorBorder dark:border-white dark:bg-white/5"
                              : "border-[color-mix(in_srgb,var(--primary-color)_15%,transparent)] hover:border-[color-mix(in_srgb,var(--primary-color)_35%,transparent)]"
                          }`}
                        >
                          <input
                            type="radio"
                            name="quick_delivery_address"
                            className="sr-only"
                            checked={active}
                            onChange={() => {
                              setSelectedAddress(addr);
                              setShowAllAddresses(false);
                            }}
                          />
                          <span
                            className={`w-[18px] h-[18px] rounded-full border-2 flex items-center justify-center shrink-0 ${
                              active
                                ? "primaryColorBorder dark:border-white"
                                : "border-gray-300 dark:border-gray-600"
                            }`}
                          >
                            {active && (
                              <span className="w-2 h-2 rounded-full primaryBackColor dark:bg-white" />
                            )}
                          </span>
                          <span
                            className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 ${
                              active
                                ? "primaryBackColor text-white"
                                : "primaryLightBack primaryColor dark:text-white"
                            }`}
                          >
                            <Icon size={15} />
                          </span>
                          <div className="flex flex-col min-w-0 flex-1">
                            <div className="flex items-center gap-1.5">
                              <span className="font-bold text-sm truncate">
                                {addr?.type || addr?.name}
                              </span>
                              {addr?.is_default == 1 && (
                                <span className="text-[10px] font-semibold primaryColor dark:text-white shrink-0">
                                  • {t("default")}
                                </span>
                              )}
                            </div>
                            <span className="text-xs SecondaryTextColor leading-snug line-clamp-1">
                              {formatAddress(addr)}
                            </span>
                          </div>
                          <button
                            type="button"
                            aria-label={t("edit") || "Edit"}
                            // Don't let the parent <label> select this address.
                            onClick={(e) => {
                              e.preventDefault();
                              e.stopPropagation();
                              dispatch(setSelectedAddresForEdit({ data: addr }));
                              setIsEditingAddress(true);
                              setShowAddAddress(true);
                            }}
                            className="shrink-0 rounded-lg p-1.5 text-SecondaryTextColor transition-colors hover:primaryLightBack hover:primaryColor"
                          >
                            <RiPencilLine size={15} />
                          </button>
                        </label>
                      );
                    })}
                    <button
                      type="button"
                      onClick={() => {
                        if (isPickup) {
                          // Clear the pick so typed fields become the Bill To.
                          setSelectedAddress(null);
                          setShowManualBilling(true);
                          return;
                        }
                        setIsEditingAddress(false);
                        setShowAddAddress(true);
                      }}
                      className="flex w-full items-center justify-center gap-1.5 rounded-xl border border-dashed border-[color-mix(in_srgb,var(--primary-color)_25%,transparent)] py-2.5 text-sm font-semibold primaryColor transition-colors hover:primaryLightBack"
                    >
                      <RiAddLine size={16} />
                      {t("add_new_address") || "Add New Address"}
                    </button>
                  </div>
                )}

                {/* Pickup-only inline Bill To — no address record created. */}
                {isPickup && showManualBilling && (
                  <div className="flex flex-col gap-3.5">
                    {addresses.length > 0 && (
                      <button
                        type="button"
                        onClick={() => setShowManualBilling(false)}
                        className="inline-flex w-fit items-center gap-1.5 self-start rounded-full primaryLightBack px-3 py-1.5 text-xs font-bold primaryColor transition-opacity hover:opacity-80"
                      >
                        <RiArrowLeftLine size={14} className="shrink-0" />
                        {t("choose_saved_address") || "Choose a saved address"}
                      </button>
                    )}
                    <div className="flex flex-col gap-1.5">
                      <Label className="text-sm font-semibold textColor">{t("name")}</Label>
                      <Input
                        type="text"
                        className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent"
                        placeholder={t("name")}
                        value={billingDetails.billing.name}
                        onChange={(e) => billingDetails.setField("name", e.target.value)}
                        required
                      />
                    </div>
                    <div className="grid grid-cols-1 gap-3.5">
                      <div className="flex flex-col gap-1.5">
                        <Label className="text-sm font-semibold textColor">{t("mobileNumber")}</Label>
                        <div className="-mt-1.5">
                          <PhoneNumberInput
                            value={billingDetails.billing.mobile}
                            countryCode={billingDetails.billing.countryCode}
                            onChange={billingDetails.handleMobileChange}
                            onCountryReady={billingDetails.handleMobileCountryReady}
                          />
                        </div>
                      </div>
                      <div className="flex flex-col gap-1.5">
                        <Label className="text-sm font-semibold textColor">{t("enter_city")}</Label>
                        <Input
                          type="text"
                          className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent"
                          placeholder={t("enter_city")}
                          value={billingDetails.billing.city}
                          
                          onChange={(e) => billingDetails.setField("city", e.target.value)}
                          required
                        />
                      </div>
                    </div>
                    <div className="flex flex-col gap-1.5">
                      <Label className="text-sm font-semibold textColor">{t("address")}</Label>
                      <Input
                        type="text"
                        placeholder={t("address")}
                        value={billingDetails.billing.address}
                        onChange={(e) => billingDetails.setField("address", e.target.value)}
                        required
                      />
                    </div>
                    <div className="grid grid-cols-2 gap-3.5">
                      <div className="flex flex-col gap-1.5">
                        <Label className="text-sm font-semibold textColor">{t("enter_pincode")}</Label>
                        <Input
                          type="text"
                          className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent"
                          placeholder={t("enter_pincode")}
                          value={billingDetails.billing.pincode}
                          onChange={(e) => billingDetails.setField("pincode", e.target.value)}
                        />
                      </div>
                      <div className="flex flex-col gap-1.5">
                        <Label className="text-sm font-semibold textColor">{t("enter_country")}</Label>
                        <Select
                          value={billingDetails.billing.countryId || undefined}
                          onValueChange={billingDetails.handleCountryChange}
                        >
                          <SelectTrigger className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent focus:primaryColorBorder focus:ring-2 focus:ring-[color-mix(in_srgb,var(--primary-color)_25%,transparent)]">
                            <SelectValue placeholder={t("enter_country")} />
                          </SelectTrigger>
                          <SelectContent>
                            {billingDetails.countries.map((c: any) => (
                              <SelectItem key={c.id} value={String(c.id)}>
                                {c.name}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                      <div className="flex flex-col gap-1.5">
                        <Label className="text-sm font-semibold textColor">{t("enter_region")}</Label>
                        {billingDetails.regionsEmpty ? (
                          <Input
                            type="text"
                            className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent"
                            placeholder={t("enter_region")}
                            value={billingDetails.billing.regionId}
                            onChange={(e) =>
                              billingDetails.handleRegionChange(e.target.value)
                            }
                          />
                        ) : (
                          <Select
                            value={billingDetails.billing.regionId || undefined}
                            onValueChange={billingDetails.handleRegionChange}
                            disabled={!billingDetails.billing.countryId}
                          >
                            <SelectTrigger className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent focus:primaryColorBorder focus:ring-2 focus:ring-[color-mix(in_srgb,var(--primary-color)_25%,transparent)]">
                              <SelectValue placeholder={t("enter_region")} />
                            </SelectTrigger>
                            <SelectContent>
                              {billingDetails.regions.map((region: any) => (
                                <SelectItem key={region.id} value={String(region.id)}>
                                  {region.name}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        )}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            </section>
          )}

          {/* Only once a real address is picked (city-coords result is meaningless). */}
          {!isPickup && !!selectedAddress && !isDeliverable && (
            <div className="flex items-start gap-2 rounded-lg border border-red-200 dark:border-red-500/30 bg-red-50 dark:bg-red-500/10 px-3 py-2.5">
              <p className="text-sm font-medium text-red-600 dark:text-red-400">
                {t("sorry_we_are_not_delivering_on_selected_address")}
              </p>
            </div>
          )}

          {/* Billing details. Hidden for pickup (no shipping to be "same as")
              and when undeliverable. */}
          {!isPickup && isDeliverable && (
          <section className="bodyBackgroundColor cardBorderPrimary !rounded-lg shadow-sm">
            <label className="flex items-center justify-between gap-2 border-b border-[color-mix(in_srgb,var(--primary-color)_15%,transparent)] p-4 cursor-pointer">
              <span className="font-bold text-lg textColor">
                {t("billing_details") || "Billing Details"}
              </span>
              <span className="flex items-center gap-2 text-sm font-semibold textColor">
                {t("billing_same_as_shipping") || "Same as shipping address"}
                <Checkbox
                  checked={billingDetails.billing.sameAsShipping}
                  onCheckedChange={(checked) =>
                    billingDetails.setSameAsShipping(checked === true)
                  }
                  className="primaryColorBorder data-[state=checked]:primaryBackColor"
                />
              </span>
            </label>
            {!billingDetails.billing.sameAsShipping && (
              <div className="flex flex-col gap-3.5 p-4">
                <div className="flex flex-col gap-1.5">
                  <Label className="text-sm font-semibold textColor">{t("name")}</Label>
                  <Input
                    type="text"
                    className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent"
                    placeholder={t("name")}
                    value={billingDetails.billing.name}
                    onChange={(e) => billingDetails.setField("name", e.target.value)}
                    required
                  />
                </div>
                <div className="grid grid-cols-1 gap-3.5">
                  <div className="flex flex-col gap-1.5">
                    <Label className="text-sm font-semibold textColor">{t("mobileNumber")}</Label>
                    {/* Cancels PhoneNumberInput's built-in mt-1.5. */}
                    <div className="-mt-1.5">
                      <PhoneNumberInput
                        value={billingDetails.billing.mobile}
                        countryCode={billingDetails.billing.countryCode}
                        onChange={billingDetails.handleMobileChange}
                        onCountryReady={billingDetails.handleMobileCountryReady}
                      />
                    </div>
                  </div>
                  <div className="flex flex-col gap-1.5">
                    <Label className="text-sm font-semibold textColor">{t("enter_city")}</Label>
                    <Input
                      type="text"
                      className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent"
                      placeholder={t("enter_city")}
                      value={billingDetails.billing.city}
                      onChange={(e) => billingDetails.setField("city", e.target.value)}
                      required
                    />
                  </div>
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label className="text-sm font-semibold textColor">{t("address")}</Label>
                  <Input
                    type="text"
                    placeholder={t("address")}
                    value={billingDetails.billing.address}
                    onChange={(e) => billingDetails.setField("address", e.target.value)}
                    required
                  />
                </div>
                <div className="grid grid-cols-2 gap-3.5">
                  <div className="flex flex-col gap-1.5">
                    <Label className="text-sm font-semibold textColor">{t("enter_pincode")}</Label>
                    <Input
                      type="text"
                      className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent"
                      placeholder={t("enter_pincode")}
                      value={billingDetails.billing.pincode}
                      onChange={(e) => billingDetails.setField("pincode", e.target.value)}
                    />
                  </div>
                  <div className="flex flex-col gap-1.5">
                    <Label className="text-sm font-semibold textColor">{t("enter_country")}</Label>
                    <Select
                      value={billingDetails.billing.countryId || undefined}
                      onValueChange={billingDetails.handleCountryChange}
                    >
                      <SelectTrigger className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent focus:primaryColorBorder focus:ring-2 focus:ring-[color-mix(in_srgb,var(--primary-color)_25%,transparent)]">
                        <SelectValue placeholder={t("enter_country")} />
                      </SelectTrigger>
                      <SelectContent>
                        {billingDetails.countries.map((c: any) => (
                          <SelectItem key={c.id} value={String(c.id)}>
                            {c.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="flex flex-col gap-1.5">
                    <Label className="text-sm font-semibold textColor">{t("enter_region")}</Label>
                    {/* No region list → free text (regionId holds the name). */}
                    {billingDetails.regionsEmpty ? (
                      <Input
                        type="text"
                        className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent"
                        placeholder={t("enter_region")}
                        value={billingDetails.billing.regionId}
                        onChange={(e) =>
                          billingDetails.handleRegionChange(e.target.value)
                        }
                      />
                    ) : (
                      <Select
                        value={billingDetails.billing.regionId || undefined}
                        onValueChange={billingDetails.handleRegionChange}
                        disabled={!billingDetails.billing.countryId}
                      >
                        <SelectTrigger className="h-auto py-2.5 bg-[#f4f5f7] dark:bg-zinc-800 border-transparent focus:primaryColorBorder focus:ring-2 focus:ring-[color-mix(in_srgb,var(--primary-color)_25%,transparent)]">
                          <SelectValue placeholder={t("enter_region")} />
                        </SelectTrigger>
                        <SelectContent>
                          {billingDetails.regions.map((region: any) => (
                            <SelectItem key={region.id} value={String(region.id)}>
                              {region.name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  </div>
                </div>
              </div>
            )}
          </section>
          )}

          {cartProductsData?.length > 0 && (
            <section
              ref={cartSectionRef}
              className="scroll-mt-4 bodyBackgroundColor cardBorderPrimary !rounded-lg shadow-sm"
            >
              <div className="flex items-center justify-between gap-3 border-b border-[color-mix(in_srgb,var(--primary-color)_15%,transparent)] p-4">
                <span className="flex items-center gap-2 font-bold text-lg textColor">
                  {t("shoppingCart") || "Your Cart"}
                  <span className="text-sm font-normal SecondaryTextColor">
                    ({cartProductsData.length} {t("items")})
                  </span>
                </span>
              </div>
              <div className="flex flex-col gap-2 p-3">
                {cartProductsData.map((product) => (
                  <CartProductsCard
                    key={cartLineKey(product)}
                    product={product}
                    cartProductsData={cartProductsData}
                    setCartProductsData={setCartProductsData}
                    setCartData={setCartData}
                    currency={currency}
                    decimals={decimals}
                    onEditAddons={onEditAddons}
                  />
                ))}
              </div>
              {!isPickup &&
                undeliverableVariantIds.size > 0 &&
                (() => {
                  const restrictedNames = cartProductsData
                    .filter((p) =>
                      undeliverableVariantIds.has(
                        String(p?.product_variant_id),
                      ),
                    )
                    .map((p) => p?.name)
                    .filter(Boolean);
                  if (restrictedNames.length === 0) return null;
                  return (
                    <div className="mx-3 mb-3 flex items-start gap-2 rounded-lg border border-amber-200 dark:border-amber-500/30 bg-amber-50 dark:bg-amber-500/10 px-3 py-2">
                      <p className="text-sm font-medium text-amber-700 dark:text-amber-400">
                        {(t("items_not_deliverable_to_this_address") ||
                          "Can't be delivered to this address:") +
                          " " +
                          restrictedNames.join(", ")}
                      </p>
                    </div>
                  );
                })()}
            </section>
          )}

          {appliedCoupon ? (
            <AppliedCouponCard
              key={appliedCoupon?.promo_code}
              code={appliedCoupon?.promo_code}
              savedAmount={money(appliedCoupon?.discount)}
              discountType={appliedCoupon?.discount_type}
              onRemove={() => dispatch(clearCartPromo())}
              loading={false}
            />
          ) : (
            // Typed codes go through the coupon drawer's CHECK input.
            <div className="flex flex-col gap-2">
              <div className="overflow-hidden rounded-xl empty:hidden [&>div]:border-b-0">
                <CouponAutoApplyError />
              </div>
              <UnlockCouponNudge
                code={checkoutData?.unlock_promo_code}
                message={checkoutData?.unlock_message}
                onViewAll={onViewCoupons}
              />
            </div>
          )}

          {/* Gifting: recipient, delivery date, card message. */}
          <section className="bodyBackgroundColor cardBorderPrimary !rounded-lg shadow-sm">
            <GiftDetails />
          </section>

          {/* Quick only — ecommerce ships, no delivery-partner note. */}
          {shopMode === "quick" && (
            <section className="bodyBackgroundColor cardBorderPrimary !rounded-lg shadow-sm">
              <div className="border-b border-[color-mix(in_srgb,var(--primary-color)_15%,transparent)] p-4">
                <span className="flex items-center gap-2 font-bold text-lg textColor">
                  {t("order_notes") ||
                    t("delivery_instruction") ||
                    "Delivery Instruction"}
                </span>
              </div>
              <div className="p-4">
                <p className="mb-2 text-xs SecondaryTextColor">
                  {t("order_notes_hint") ||
                    "Add a delivery instruction for the delivery partner (optional)."}
                </p>
                <textarea
                  rows={2}
                  value={orderNote}
                  onChange={(e) => setOrderNote(e.target.value)}
                  placeholder={
                    t("order_notes_placeholder") ||
                    "e.g. Leave at the door, call on arrival…"
                  }
                  className="w-full resize-none rounded-lg border border-[color-mix(in_srgb,var(--primary-color)_15%,transparent)] bg-transparent p-3 text-sm outline-none transition-colors focus:primaryColorBorder textColor placeholder:SecondaryTextColor"
                />
              </div>
            </section>
          )}

          {/* Optional buyer tax registration, frozen onto the invoice. */}
          {buyerTaxField.enabled && (
            <section className="bodyBackgroundColor cardBorderPrimary !rounded-lg shadow-sm">
              <BuyerTaxDetails
                label={buyerTaxField.label}
                validate={buyerTaxField.validate}
                className="p-4"
              />
            </section>
          )}

          <section
            ref={paymentSectionRef}
            className="scroll-mt-4 bodyBackgroundColor cardBorderPrimary !rounded-lg shadow-sm"
          >
            <div className="border-b border-[color-mix(in_srgb,var(--primary-color)_15%,transparent)] p-4">
              <span className="flex items-center gap-2 font-bold text-lg textColor">
                {t("payment_method") || "Payment Method"}
              </span>
            </div>
            <div className="p-4">
              <div className="flex flex-col gap-2">
                {walletBalance > 0 && (
                  <button
                    type="button"
                    onClick={() => {
                      setUseWallet((v) => !v);
                      if (!useWallet && walletCoversAll)
                        setPaymentMethod("wallet");
                      if (useWallet && paymentMethod === "wallet")
                        setPaymentMethod(null);
                    }}
                    className={`flex items-center gap-3 rounded-lg border p-3 transition-colors ${
                      useWallet
                        ? "primaryColorBorder primaryLightBack"
                        : "border-[color-mix(in_srgb,var(--primary-color)_15%,transparent)] hover:bg-gray-50 dark:hover:bg-zinc-800"
                    }`}
                  >
                    <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full primaryLightBack primaryColor">
                      <RiWallet3Line size={18} />
                    </span>
                    <div className="min-w-0 flex-grow text-left">
                      <p className="text-sm font-bold textColor">
                        {t("wallet_balance") || "Wallet Balance"}
                      </p>
                      <p className="text-[11px] SecondaryTextColor">
                        {walletStatusLabel}
                      </p>
                    </div>
                    <span className="shrink-0 text-sm font-extrabold primaryColor tabular-nums">
                      {money(walletBalance)}
                    </span>
                    <CheckCircle active={useWallet} />
                  </button>
                )}

                {/* Wallet full-cover ⇒ it IS the payment; hide the rest. */}
                {!(useWallet && walletCoversAll) && codAllowed && (
                  <button
                    type="button"
                    onClick={() => setPaymentMethod("COD")}
                    className={`flex items-center gap-3 rounded-lg border p-3 transition ${
                      paymentMethod === "COD"
                        ? "primaryColorBorder primaryLightBack -translate-y-0.5 motion-reduce:translate-y-0 shadow-[0_8px_18px_-8px_rgba(0,0,0,0.22)]"
                        : "border-[color-mix(in_srgb,var(--primary-color)_15%,transparent)] hover:bg-gray-50 dark:hover:bg-zinc-800"
                    }`}
                  >
                    <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full primaryLightBack primaryColor">
                      <RiMoneyDollarCircleLine size={18} />
                    </span>
                    <div className="min-w-0 flex-grow text-left">
                      <p className="text-sm font-bold textColor">
                        {isPickup
                          ? t("pay_at_store") || "Pay at Store"
                          : t("cash_on_delivery") || "Cash on Delivery"}
                      </p>
                      <p className="text-[11px] SecondaryTextColor">
                        {isPickup
                          ? t("pay_at_store") || "Pay at Store"
                          : t("pay_when_you_receive") || "Pay when you receive"}
                      </p>
                    </div>
                    <CheckCircle active={paymentMethod === "COD"} />
                  </button>
                )}
              </div>

              {!(useWallet && walletCoversAll) &&
                enabledGateways.length > 0 && (
                  <>
                    <div className="my-3 flex items-center gap-2">
                      <span className="h-px flex-grow bg-[color-mix(in_srgb,var(--primary-color)_18%,transparent)]" />
                      <span className="text-[10px] font-semibold uppercase tracking-wider SecondaryTextColor">
                        {t("pay_online") || "Pay Online"}
                      </span>
                      <span className="h-px flex-grow bg-[color-mix(in_srgb,var(--primary-color)_18%,transparent)]" />
                    </div>
                    <div className="flex flex-col gap-1.5">
                      {enabledGateways.map((g) => {
                        const active = paymentMethod === g.value;
                        return (
                          <button
                            type="button"
                            key={g.value}
                            onClick={() => setPaymentMethod(g.value)}
                            className={`flex items-center gap-3 rounded-lg border px-3 py-2.5 transition ${
                              active
                                ? "primaryColorBorder primaryLightBack -translate-y-0.5 motion-reduce:translate-y-0 shadow-[0_8px_18px_-8px_rgba(0,0,0,0.22)]"
                                : "border-[color-mix(in_srgb,var(--primary-color)_15%,transparent)] hover:bg-gray-50 dark:hover:bg-zinc-800"
                            }`}
                          >
                            <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-white ring-1 ring-black/5 dark:bg-zinc-800">
                              {g.logo ? (
                                <Image
                                  src={g.logo}
                                  alt={g.value}
                                  height={16}
                                  className="h-4 w-auto object-contain"
                                />
                              ) : (
                                <FiCreditCard size={16} className="textColor" />
                              )}
                            </span>
                            <span className="flex-grow truncate text-left text-sm font-semibold capitalize textColor">
                              {t(g.value) || g.value}
                            </span>
                            <CheckCircle active={active} />
                          </button>
                        );
                      })}
                    </div>
                  </>
                )}
            </div>
          </section>

          {/* Inside the scroll area so charges never push the footer off-screen. */}
          <section className="bodyBackgroundColor cardBorderPrimary !rounded-lg shadow-sm">
            <div className="border-b border-[color-mix(in_srgb,var(--primary-color)_15%,transparent)] p-4">
              <span className="flex items-center gap-2 font-bold text-lg textColor">
                {t("bill_details") || t("order_summary") || "Bill Details"}
              </span>
            </div>
            <div className="space-y-1.5 p-4">
              <div className="flex justify-between text-[13px] SecondaryTextColor">
                <span className="flex items-center gap-1.5">
                  {t("subtotal")}{" "}
                  {/* Subtotal is tax-inclusive; per-tax split in the tooltip. */}
                  {taxBreakdownRows.length > 0 && (
                    <>
                      <span className="text-[11px]">
                        ({t("incl_tax") || "Incl. Tax"})
                      </span>
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
                    </>
                  )}
                </span>
                <span className="tabular-nums">{money(subTotal)}</span>
              </div>
              {!isPickup && (
                <div className="flex justify-between text-[13px] SecondaryTextColor">
                  <span className="flex items-center gap-1.5">
                    {t("delivery_charge") || "Delivery Charge"}
                    {Number(deliveryChargeTax?.tax_amount) > 0 && (
                      <TooltipProvider delayDuration={150}>
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <button
                              type="button"
                              className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 shrink-0"
                              aria-label={`${t("incl") || "Incl."} ${deliveryChargeTax?.tax_name || t("tax") || "Tax"} ${money(deliveryChargeTax?.tax_amount)}`}
                            >
                              <FiInfo size={13} />
                            </button>
                          </TooltipTrigger>
                          <TooltipContent className="text-xs">
                            {t("incl") || "Incl."} {deliveryChargeTax?.tax_name || t("tax") || "Tax"}{" "}
                            {money(deliveryChargeTax?.tax_amount)}
                          </TooltipContent>
                        </Tooltip>
                      </TooltipProvider>
                    )}
                  </span>
                  <span className="tabular-nums">
                    {deliveryCharge > 0
                      ? money(deliveryCharge)
                      : t("free") || "Free"}
                  </span>
                </div>
              )}
              {chargeRows.map((c, i) => (
                <div
                  key={`charge-${i}`}
                  className="flex justify-between text-[13px] SecondaryTextColor"
                >
                  <span className="flex items-center gap-1.5">
                    {c.label}
                    {c.refundable != null && (
                      <span
                        className={`text-[10px] font-semibold ${
                          c.refundable == 1 || c.refundable === true
                            ? "text-emerald-600 dark:text-emerald-400"
                            : "text-gray-400"
                        }`}
                      >
                        {c.refundable == 1 || c.refundable === true
                          ? `(${t("refundable") || "Refundable"})`
                          : `(${t("non_refundable") || "Non-refundable"})`}
                      </span>
                    )}
                    {/* Amount already includes taxAmount. */}
                    {Number(c.taxAmount) > 0 && (
                      <TooltipProvider delayDuration={150}>
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <button
                              type="button"
                              className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 shrink-0"
                              aria-label={`${t("incl") || "Incl."} ${c.taxName || t("tax") || "Tax"} ${money(c.taxAmount)}`}
                            >
                              <FiInfo size={13} />
                            </button>
                          </TooltipTrigger>
                          <TooltipContent className="text-xs">
                            {t("incl") || "Incl."} {c.taxName || t("tax") || "Tax"}{" "}
                            {money(c.taxAmount)}
                            {(c.refundable == 1 || c.refundable === true) && (
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
                  <span className="tabular-nums">{money(c.amount)}</span>
                </div>
              ))}
              {/* Instant coupons only — cashback gets its own callout. */}
              {appliedCoupon &&
                !isCashbackCoupon &&
                Number(appliedCoupon?.discount || 0) > 0 && (
                  <div className="flex justify-between text-[13px] primaryColor">
                    <span>{t("coupon_discount") || "Coupon Discount"}</span>
                    <span className="tabular-nums">
                      -{money(appliedCoupon?.discount)}
                    </span>
                  </div>
                )}
              {useWallet && walletUsedAmount > 0 && (
                <div className="flex justify-between text-[13px] primaryColor">
                  <span>{t("wallet") || "Wallet"}</span>
                  <span className="tabular-nums">
                    -{money(walletUsedAmount)}
                  </span>
                </div>
              )}
            </div>
            {/* Savings callout with a scalloped top edge. */}
            {totalSaved > 0 && (
              <div
                className="flex items-center justify-center gap-2 bg-gradient-to-r from-emerald-50 via-green-50 to-teal-50 px-3.5 pb-3 pt-4 text-center dark:from-emerald-500/10 dark:via-green-500/10 dark:to-teal-500/10"
                style={{
                  WebkitMaskImage:
                    "radial-gradient(circle 8px at 8px -2px, transparent 8px, #000 8.5px)",
                  maskImage:
                    "radial-gradient(circle 8px at 8px -2px, transparent 8px, #000 8.5px)",
                  WebkitMaskSize: "16px 100%",
                  maskSize: "16px 100%",
                  WebkitMaskRepeat: "repeat-x",
                  maskRepeat: "repeat-x",
                  borderRadius: "0 0 8px 8px",
                }}
              >
                <MdOutlineCelebration
                  size={18}
                  className="shrink-0 text-emerald-600 dark:text-emerald-400"
                />
                <p className="text-sm font-semibold text-emerald-700 dark:text-emerald-300">
                  {t("you_saved")}{" "}
                  <span className="font-extrabold">{money(totalSaved)}</span>{" "}
                  <span className="font-normal text-emerald-600/80 dark:text-emerald-400/70">
                    {t("you_saved_on_this_order")}
                  </span>
                </p>
              </div>
            )}
          </section>

          {appliedCoupon && isCashbackCoupon && (
            <div className="flex items-center gap-2.5 rounded-lg bg-amber-500/10 px-3.5 py-2.5">
              <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-amber-500/15 text-amber-600 dark:text-amber-400">
                <RiWallet3Line size={18} />
              </span>
              <div className="min-w-0 flex-grow">
                <p className="text-sm font-bold text-amber-700 dark:text-amber-400">
                  {t("you_will_earn_cashback")} {money(promoDiscount)}
                </p>
                <p className="text-[11px] text-amber-700/80 dark:text-amber-400/80">
                  {t("cashback_added_to_wallet")}
                </p>
              </div>
            </div>
          )}
        </div>

        <div className="shrink-0 w-full border-t bg-white px-4 pb-4 pt-3 shadow-[0_-4px_20px_-10px_rgba(0,0,0,0.15)] dark:bg-zinc-900">
          <div className="mb-3 flex items-center justify-between">
            <div className="flex flex-col leading-tight">
              <span className="text-[11px] font-medium uppercase tracking-wide SecondaryTextColor">
                {t("total") || "Total"}
              </span>
              {(chargeRows.length > 0 || deliveryCharge > 0) && (
                <span className="text-[10px] SecondaryTextColor">
                  {t("inclusive_of_charges") || "Incl. all charges"}
                </span>
              )}
            </div>
            <span className="text-2xl font-extrabold primaryColor tabular-nums">
              <AnimatedNumber value={payable} format={money} />
            </span>
          </div>
          {/* Guide states stay enabled; only real blockers disable. */}
          <button
            type="button"
            onClick={cta.action}
            disabled={paymentLoading || totalsLoading || cta.blocked}
            {...ctaClosedSpreadProps}
            aria-busy={paymentLoading}
            className={`primaryBackColor relative flex w-full items-center justify-center gap-2 overflow-hidden rounded-lg py-3.5 text-[15px] font-bold text-white shadow-sm transition duration-150 hover:opacity-90 active:scale-[0.97] motion-reduce:active:scale-100 ${
              paymentLoading
                ? "disabled:cursor-wait"
                : "disabled:cursor-not-allowed disabled:bg-gray-200 disabled:text-gray-400 disabled:shadow-none dark:disabled:bg-zinc-700 dark:disabled:text-zinc-500"
            } ${ctaClosedClassName}`}
          >
            {paymentLoading && <PlaceOrderProgress />}
            {paymentLoading ? (
              <span className="relative flex items-center gap-2">
                <span className="h-4 w-4 animate-spin rounded-full border-2 border-white/40 border-t-white" />
                {t("placing_order") || "Placing order..."}
              </span>
            ) : (
              cta.label
            )}
          </button>
        </div>
        {StripePortal}
      </div>

      <NewAddressModal
        showAddAddres={showAddAddress}
        setShowAddAddres={setShowAddAddress}
        isAddressSelected={isEditingAddress}
        fetchAddress={loadAddresses}
        adoptZone={false}
      />
    </>
  );
};

export default QuickCheckoutView;
