"use client";
import React, { useEffect, useRef, useState } from "react";
import dynamic from "next/dynamic";
import { useDispatch, useSelector } from "react-redux";
import { toast } from "react-toastify";
import {
  FiMapPin,
  FiPlus,
  FiCreditCard,
  FiShoppingBag,
  FiTag,
  FiChevronRight,
  FiChevronLeft,
  FiCheck,
} from "react-icons/fi";
import { RiWallet3Line } from "react-icons/ri";

import * as api from "@/api/apiRoutes";
import { t } from "@/utils/translation";
import {
  formatCurrency,
  hasMissingRequiredPrescriptions,
} from "@/utils/helperFunction";
import type { FlushCtx } from "@/hooks/useDebouncedQuantity";
import { isRtl } from "@/lib/utils";
import { Checkbox } from "@/components/ui/checkbox";
import AnimatedNumber from "@/components/ui/AnimatedNumber";
import UnlockCouponNudge from "@/components/cart/UnlockCouponNudge";
import useBillingDetails from "@/hooks/useBillingDetails";
import useCurrency from "@/hooks/useCurrency";
import useLazyLottie from "@/hooks/useLazyLottie";
import useStoreClosed from "@/hooks/useStoreClosed";
import useCheckoutPayment from "@/hooks/useCheckoutPayment";
import { getPickupErrorMessage } from "@/utils/placeOrderErrors";

import CheckoutSkeleton from "./CheckoutSkeleton";
import CheckoutItemRow from "./UI/CheckoutItemRow";
import {
  toGaItem,
  trackBeginCheckout,
  trackPurchase,
} from "@/utils/analytics";
import AddressCard, { AddAddressTile } from "./UI/AddressCard";
import SectionHeader from "./UI/SectionHeader";
import RecommendationStrip from "./UI/RecommendationStrip";
import Row from "./UI/SummaryRow";
import BillingFields from "./UI/BillingFields";
import DeliveryTypeToggle from "./UI/DeliveryTypeToggle";
import PickupStoreCard from "./UI/PickupStoreCard";
import OrderNotes from "./UI/OrderNotes";
import GiftDetails from "@/components/gifting/GiftDetails";
import BuyerTaxDetails from "./UI/BuyerTaxDetails";
import useBuyerTaxField from "@/hooks/useBuyerTaxField";
import DeleteAddressDialog from "./UI/DeleteAddressDialog";
import { AppliedCouponTicket, CouponInput } from "./UI/CouponSection";
import { SavingsBanner, CashbackBanner, WalletCoversBanner } from "./UI/SummaryBanners";
import { PaymentMethodButton, PaymentPickerDialog } from "./UI/PaymentPicker";
import { paymentMethodKeys } from "./UI/paymentMethods";
import PlaceOrderProgress from "./UI/PlaceOrderProgress";

import {
  clearCartPromo,
  clearPrescriptions,
  setCartCheckout,
  setCartProducts,
  setCartPromo,
} from "@/redux/slices/cartSlice";
import {
  setAllAddresses,
  setSelectedAddresForEdit,
} from "@/redux/slices/addressSlice";
import {
  setAddress,
  setBuyerBusinessName,
  setBuyerTaxNumber,
  setCheckoutTotal,
  setOrderType,
  setDeliveryType,
  setPaymentMethod,
  setWalletChecked,
  setUserWalletBalance,
} from "@/redux/slices/checkoutSlice";
import { setCurrentUser } from "@/redux/slices/userSlice";

const NewAddressModal = dynamic(
  () => import("../newaddressmodal/NewAddressModal"),
  { ssr: false },
);
const StripeModal = dynamic(() => import("./StripeModal"), { ssr: false });
const CouponCodeDrawer = dynamic(
  () => import("../couponcode/CouponCodeDrawer"),
  { ssr: false },
);
const Lottie = dynamic(() => import("lottie-react"), { ssr: false });

const CheckoutUI = () => {
  const { storeClosed, notifyClosed, closedProps } = useStoreClosed();
  const dispatch = useDispatch();
  const rtl = isRtl();

  const cart = useSelector((state: any) => state.Cart);
  const address = useSelector((state: any) => state.Addresses);
  const user = useSelector((state: any) => state.User.user);
  const setting = useSelector((state: any) => state.Setting);
  const checkout = useSelector((state: any) => state.Checkout);
  const prescriptions = useSelector((state: any) => state.Cart.prescriptions);
  const city = useSelector((state: any) => state.City.city);
  const theme = useSelector((state: any) => state.Theme.theme);
  // Active channel (quick/ecommerce); refetch on change.
  const shopMode = useSelector((state: any) => state.ShopMode.mode);
  const activeChannel = cart?.activeChannel;

  // Cart counts; refetch when items change outside this page.
  const reduxCartCount = cart?.cartProducts?.length ?? 0;
  const guestCartCount = cart?.guestCart?.length ?? 0;

  const [loading, setLoading] = useState(true);
  // Fetch in flight (for the mode-mismatch banner, not the skeleton).
  const [deliveryTypeFetching, setDeliveryTypeFetching] = useState(false);
  const [checkoutLoading, setCheckoutLoading] = useState(false);
  const [paymentLoading, setPaymentLoading] = useState(false);
  // COD/wallet success: brief tick while the status page route loads.
  const [orderPlaced, setOrderPlaced] = useState(false);
  // Checkout (/cart?checkout=1) response.
  const [checkoutData, setCheckoutData] = useState<any>(null);
  const [checkOutError, setCheckOutError] = useState(false);
  // Undeliverable address blocks checkout but never empties the cart.
  const [deliveryError, setDeliveryError] = useState("");
  const lastCartRef = useRef<any>(null);
  // Guard against out-of-order responses when the user switches addresses fast.
  const fetchSeqRef = useRef(0);
  const [crossSell, setCrossSell] = useState<any[]>([]);
  const [upSell, setUpSell] = useState<any[]>([]);
  // Confetti burst shown briefly when a coupon is newly applied.
  const [showCouponBurst, setShowCouponBurst] = useState(false);
  // 331KB burst: own chunk, fetched after checkout mounts.
  const couponBurstAnimation = useLazyLottie(
    () => import("@/assets/order_place_animation/order_placed_back_animation.json"),
  );

  const [showAddAddres, setShowAddAddres] = useState(false);
  const [isAddressSelected, setIsAddressSelected] = useState(false);
  // Pickup: inline billing fields instead of the address modal.
  const [showManualBilling, setShowManualBilling] = useState(false);
  // Address pending delete (null = modal closed).
  const [addressToDelete, setAddressToDelete] = useState<any>(null);
  const [deletingAddress, setDeletingAddress] = useState(false);

  // Currency: zone setting first, then checkout response.
  const {
    currency: liveCurrency,
    currencyCode: liveCurrencyCode,
    decimals: liveDecimals,
  } = useCurrency();
  const currency =
    liveCurrency || checkoutData?.currency || cart?.currency;
  const decimals = liveDecimals || checkoutData?.decimal_point || 0;
  const currencyCode =
    liveCurrencyCode || checkoutData?.currency_code || cart?.currency_code;

  const [discountInput, setDiscountInput] = useState("");
  const [showCouponCode, setShowCouponCode] = useState(false);
  // Payment picker modal.
  const [showPaymentPicker, setShowPaymentPicker] = useState(false);

  const billingDetails = useBillingDetails();
  // Spec follows the billed party's country — resolve it from its coordinates.
  const buyerTaxField = useBuyerTaxField({
    latitude: checkout?.address?.latitude ?? city?.latitude,
    longitude: checkout?.address?.longitude ?? city?.longitude,
  });

  const getCurrentUser = async () => {
    try {
      // Zone-scoped user details.
      const response = await api.getUser({
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      dispatch(setCurrentUser({ data: response.data }));
    } catch (error) {
      console.log("error", error);
    }
  };

  const validateCouponCode = async () => {
    if (
      !cart?.promo_code?.promo_code ||
      !checkout?.address?.latitude ||
      !checkout?.address?.longitude
    )
      return;
    try {
      const response = await api.setPromoCode({
        promoCodeName: cart?.promo_code?.promo_code,
        amount: cart?.cartSubTotal,
        latitude: checkout?.address?.latitude,
        longitude: checkout?.address?.longitude,
        deliveryType: checkoutData?.delivery_type ?? checkout?.deliveryType,
      });
      if (response.status == 1) {
        dispatch(setCartPromo({ data: response.data }));
      } else {
        dispatch(clearCartPromo());
      }
    } catch (error) {
      console.log("Error", error);
    }
  };

  // Set fetching flag in the click so the mismatch banner doesn't flash.
  const handleDeliveryTypeChange = (mode: "delivery" | "pickup") => {
    setDeliveryTypeFetching(true);
    dispatch(setDeliveryType({ data: mode }));
  };

  const handleFetchCheckout = async () => {
    // Mark fetching without showing the full-page skeleton.
    setDeliveryTypeFetching(true);
    const couponseCodeId = cart?.promo_code?.promo_code_id;
    // Price by address, else city; pickup always uses city.
    const isPickupToggled = checkout?.deliveryType === "pickup";
    const latitude = isPickupToggled
      ? city?.latitude
      : (checkout?.address?.latitude ?? city?.latitude);
    const longitude = isPickupToggled
      ? city?.longitude
      : (checkout?.address?.longitude ?? city?.longitude);
    const orderType = checkout?.orderType;

    // No location: release the skeleton and stop.
    if (!latitude || !longitude || !orderType) {
      setLoading(false);
      setDeliveryTypeFetching(false);
      return;
    }

    // Only the latest request may update state.
    const seq = ++fetchSeqRef.current;
    console.log("[checkout] cart request →", {
      seq,
      addressId: checkout?.address?.id ?? null,
      latitude,
      longitude,
      orderType,
      promocode_id: couponseCodeId,
    });

    try {
      const response = await api.getCart({
        latitude,
        longitude,
        checkout: 1,
        promocode_id: couponseCodeId,
        address_id: checkout?.address?.id,
        delivery_type: checkout?.deliveryType,
      });

      // Drop stale response (a newer fetch already fired).
      if (seq !== fetchSeqRef.current) {
        console.log("[checkout] cart response IGNORED (stale)", {
          seq,
          latest: fetchSeqRef.current,
        });
        return;
      }
      // Deliverability comes from the cart API; pickup never blocks.
      const deliveryAvailable =
        Number(response?.data?.delivery_available) === 1;
      const isDeliverableAddress =
        Number(response?.data?.is_deliverable_address) === 1;
      const isPickupOrder = response?.data?.delivery_type === "pickup";
      const isDeliverable =
        isPickupOrder || (deliveryAvailable && isDeliverableAddress);
      console.log("[checkout] cart response ←", {
        seq,
        status: response?.status,
        delivery_available: response?.data?.delivery_available,
        is_deliverable_address: response?.data?.is_deliverable_address,
        delivery_type: response?.data?.delivery_type,
        cartBefore: (checkoutData?.cart ?? lastCartRef.current?.cart ?? [])
          .length,
      });

      if (response?.status == 1) {
        // Valid cart: always show items.
        dispatch(setCartCheckout({ data: response?.data }));
        dispatch(
          setCheckoutTotal({ data: Number(response?.data?.total_amount || 0) }),
        );
        setCheckoutData(response?.data);
        lastCartRef.current = response?.data; // remember last good cart

        if (isDeliverable) {
          // Serviceable or pickup → normal checkout.
          setCheckOutError(false);
          setDeliveryError("");
        } else {
          // NOT serviceable → keep cart visible, block checkout, show banner.
          setCheckOutError(true);
          setDeliveryError(
            t("sorry_we_are_not_delivering_on_selected_address") ||
              "Sorry, We are not delivering on selected address",
          );
        }
        console.log("[checkout] store updated", {
          deliverable: isDeliverable,
          cartAfter: response?.data?.cart?.length ?? 0,
          total: response?.data?.total_amount,
        });
      } else {
        // status 0 = empty cart for this channel; clear the screen.
        console.warn("[checkout] empty cart for channel — clearing", {
          seq,
          message: response?.message,
        });
        dispatch(setCartCheckout({ data: null }));
        dispatch(setCheckoutTotal({ data: 0 }));
        setCheckoutData(null);
        lastCartRef.current = null;
        setCheckOutError(false);
        setDeliveryError("");
      }
    } catch (error) {
      console.log("[checkout] cart request error", error);
      if (seq === fetchSeqRef.current) setCheckOutError(true);
    } finally {
      if (seq === fetchSeqRef.current) {
        setLoading(false);
        setDeliveryTypeFetching(false);
      }
    }
  };

  // Cross-sell + upsell suggestions.
  const fetchRecommendations = async () => {
    const latitude = checkout?.address?.latitude ?? city?.latitude;
    const longitude = checkout?.address?.longitude ?? city?.longitude;
    if (!latitude || !longitude) return;
    try {
      const response = await api.getCartRecommendations({
        latitude,
        longitude,
      });
      if (response?.status == 1) {
        setCrossSell(response?.data?.cross_sell?.products || []);
        setUpSell(response?.data?.upsell?.products || []);
      } else {
        setCrossSell([]);
        setUpSell([]);
      }
    } catch (error) {
      console.log("Error", error);
      setCrossSell([]);
      setUpSell([]);
    }
  };

  // selectNewestFrom: auto-select the just-added address.
  const fetchAddress = async (opts: { selectNewestFrom?: any[] } = {}) => {
    const { selectNewestFrom } = opts;
    try {
      const response: any = await api.getAddress();
      if (response.status == 1) {
        const list = response.data || [];
        dispatch(setAllAddresses({ data: list }));
        const defaultAddress = list.find((a: any) => a.is_default == 1);

        if (Array.isArray(selectNewestFrom)) {
          // Pick the freshly added address (id absent from the pre-add list).
          const prevIds = new Set(selectNewestFrom);
          const added = list.find((a: any) => !prevIds.has(a.id));
          dispatch(setAddress({ data: added || defaultAddress || list[0] }));
        } else if (checkout?.address != null) {
          // Keep selection, use its fresh copy.
          const fresh = list.find((a: any) => a.id === checkout.address.id);
          if (fresh) dispatch(setAddress({ data: fresh }));
        } else if (!defaultAddress) {
          dispatch(setAddress({ data: list[0] }));
        } else {
          dispatch(setAddress({ data: defaultAddress }));
        }
      } else {
        dispatch(setAllAddresses({ data: [] }));
      }
    } catch (error) {
      console.log("Error", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAddress();
    getCurrentUser();
    dispatch(setOrderType({ data: "doorstep" }));
    // eslint-disable-next-line react-hooks/exhaustive-deps -- run-once on mount only
  }, []);

  useEffect(() => {
    validateCouponCode();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- validateCouponCode is redefined every render (not memoized); only the coupon/subtotal inputs it reads should re-trigger it
  }, [cart?.promo_code?.promo_code, cart?.cartSubTotal]);

  // Confetti when a new coupon is applied.
  const hadCouponRef = useRef(cart?.promo_code?.promo_code || null);
  useEffect(() => {
    const nowCode = cart?.promo_code?.promo_code || null;
    const prevCode = hadCouponRef.current;
    hadCouponRef.current = nowCode;
    if (nowCode && nowCode !== prevCode) {
      setShowCouponBurst(true);
      const timer = setTimeout(() => setShowCouponBurst(false), 1600);
      return () => clearTimeout(timer);
    }
  }, [cart?.promo_code?.promo_code]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- data fetch when address/city/channel/coupon change
    handleFetchCheckout();
    fetchRecommendations();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- handleFetchCheckout/fetchRecommendations are redefined every render (not memoized); deps below are the intentional trigger list
  }, [
    cart?.promo_code?.promo_code_id,
    checkout?.address?.id,
    // Address edits keep the id; watch pricing fields too.
    checkout?.address?.state,
    checkout?.address?.pincode,
    checkout?.address?.latitude,
    checkout?.address?.longitude,
    // City is the fallback location.
    city?.latitude,
    city?.longitude,
    checkout?.orderType,
    // Delivery/pickup are priced differently.
    checkout?.deliveryType,
    // Channel change (quick/ecommerce).
    activeChannel,
    shopMode,
    // Cart changed outside this page.
    reduxCartCount,
    guestCartCount,
  ]);

  // On channel change, drop old data and show the skeleton until refetch.
  const didMountChannel = useRef(false);
  useEffect(() => {
    // Skip the initial mount — the mount effect already drives the first load.
    if (!didMountChannel.current) {
      didMountChannel.current = true;
      return;
    }
    // Clear the previous channel's cart (skip first mount).
    console.log("[checkout] channel changed → refetching", {
      activeChannel,
      shopMode,
    });
    lastCartRef.current = null;
    setCheckoutData(null);
    setCheckOutError(false);
    setDeliveryError("");
    setLoading(true);
  }, [activeChannel, shopMode]);

  // ---- cart quantity handlers ----
  // Commit a qty increase (debounced).
  const handleCommitQty = async (
    product: any,
    variantId: number | string,
    nextQty: number,
    ctx?: FlushCtx,
  ) => {
    if (nextQty < 1) return;
    try {
      const response = await api.addToCart({
        product_id: product?.id,
        product_variant_id: variantId,
        qty: nextQty,
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      if (ctx?.isStale?.()) return;
      if (response.status == 1) {
        await handleFetchCheckout();
        fetchRecommendations();
        await reapplyCoupon(response.sub_total);
      } else {
        toast.error(response.message);
      }
    } catch (error) {
      console.log("Error", error);
    }
  };

  // Remove units or the whole line, optimistically.
  const handleRemoveUnits = async (
    product: any,
    variantId: number | string,
    unitsArg?: number,
    ctx?: FlushCtx,
  ) => {
    const units = unitsArg ?? 1;
    // 1) Patch the on-screen cart.
    setCheckoutData((prev: any) => {
      if (!prev?.cart) return prev;
      const nextCart = prev.cart
        .map((item: any) => {
          const itemVariantId = item?.variants?.[0]?.id ?? item?.variant_id;
          if (itemVariantId != variantId) return item;
          const curQty = Number(
            item?.variants?.[0]?.quantity ?? item?.qty ?? 0,
          );
          const nextQty = curQty - units;
          if (nextQty <= 0) return null;
          return {
            ...item,
            qty: nextQty,
            variants: item?.variants?.[0]
              ? [
                  { ...item.variants[0], quantity: nextQty },
                  ...item.variants.slice(1),
                ]
              : item?.variants,
          };
        })
        .filter(Boolean);
      return { ...prev, cart: nextCart };
    });

    // 2) Patch redux so the header badge updates.
    const nextRedux = (cart?.cartProducts ?? [])
      .map((p: any) => {
        if (p?.product_variant_id != variantId) return p;
        const nextQty = Number(p?.qty ?? 0) - units;
        return nextQty <= 0 ? null : { ...p, qty: nextQty };
      })
      .filter(Boolean);
    dispatch(setCartProducts({ data: nextRedux }));

    // 3) Remove on server; refetch on failure.
    try {
      const response = await api.removeFromCart({
        product_id: product?.id,
        product_variant_id: variantId,
        qty: units,
      });
      if (ctx?.isStale?.()) return;
      const alreadyGone =
        response?.status != 1 &&
        /not found|no item/i.test(response?.message || "");
      if (response?.status == 1 || alreadyGone) {
        handleFetchCheckout();
        fetchRecommendations();
        await reapplyCoupon(response?.sub_total);
      } else {
        toast.error(response.message);
        // Server rejected the removal — resync so the UI matches the server.
        handleFetchCheckout();
      }
    } catch (error) {
      console.log("error", error);
      // Network failure — restore the true server cart.
      handleFetchCheckout();
    }
  };

  const reapplyCoupon = async (total?: number) => {
    const latitude = checkout?.address?.latitude;
    const longitude = checkout?.address?.longitude;
    if (!cart?.promo_code?.promo_code || !latitude || !longitude) return;
    try {
      const response = await api.setPromoCode({
        promoCodeName: cart?.promo_code?.promo_code,
        amount: total,
        latitude,
        longitude,
        deliveryType: checkoutData?.delivery_type ?? checkout?.deliveryType,
      });
      if (response.status == 1) {
        dispatch(setCartPromo({ data: response.data }));
      } else {
        dispatch(clearCartPromo());
      }
    } catch (error) {
      console.log("Error", error);
    }
  };

  // ---- discount code ----
  const handleApplyDiscount = async () => {
    const latitude = checkout?.address?.latitude;
    const longitude = checkout?.address?.longitude;
    if (!discountInput?.trim() || !latitude || !longitude) return;
    try {
      const response = await api.setPromoCode({
        promoCodeName: discountInput.trim(),
        amount: cart?.cartSubTotal,
        latitude,
        longitude,
        deliveryType: checkoutData?.delivery_type ?? checkout?.deliveryType,
      });
      if (response.status == 1) {
        dispatch(setCartPromo({ data: response.data }));
        toast.success(response.message);
        setDiscountInput("");
      } else {
        toast.error(response.message);
      }
    } catch (error) {
      console.log("Error", error);
    }
  };

  const handleRemoveDiscount = () => {
    dispatch(clearCartPromo());
  };

  // ---- address ----
  const handleSelectAddress = (addr: any) => {
    console.log("[checkout] address selected", {
      id: addr?.id,
      type: addr?.type,
      latitude: addr?.latitude,
      longitude: addr?.longitude,
    });
    // Clear the old error; refetch re-validates.
    setDeliveryError("");
    dispatch(setAddress({ data: addr }));
  };

  // Open the address modal in edit mode.
  const handleEditAddress = (addr: any) => {
    dispatch(setSelectedAddresForEdit({ data: addr }));
    setIsAddressSelected(true);
    setShowAddAddres(true);
  };

  // Open the styled confirm modal (was native window.confirm).
  const handleDeleteAddress = (addr: any) => setAddressToDelete(addr);

  const confirmDeleteAddress = async () => {
    const addr = addressToDelete;
    if (!addr) return;
    setDeletingAddress(true);
    try {
      const response = await api.deleteAddress({ id: addr?.id });
      if (response?.status == 1) {
        toast.success(response?.message || t("deleted"));
        // If the deleted address was selected, clear it so checkout falls back to city.
        if (checkout?.address?.id === addr?.id)
          dispatch(setAddress({ data: null }));
        fetchAddress();
        setAddressToDelete(null);
      } else {
        toast.error(response?.message);
      }
    } catch (error) {
      console.log("Error", error);
    } finally {
      setDeletingAddress(false);
    }
  };

  const formatAddress = (a: any) =>
    [a?.address, a?.area, a?.city, a?.state, a?.pincode, a?.country]
      .filter(Boolean)
      .join(", ");

  // ---- wallet ----
  const handleWalletToggle = () => {
    const nextChecked = !checkout?.isWalletChecked;
    if (nextChecked) {
      const balance = Number(user?.balance || 0);
      const total = Number(checkoutData?.total_amount || 0);
      const used = Math.min(balance, total);
      dispatch(setUserWalletBalance({ data: used }));
      // Wallet is the method only when it covers the full total.
      if (balance >= total && total > 0) {
        dispatch(setPaymentMethod({ data: "wallet" }));
      } else if (checkout?.selectedPaymentMethod === "wallet") {
        // was full-cover, now partial (e.g. total grew) — clear stale "wallet".
        dispatch(setPaymentMethod({ data: null }));
      }
    } else {
      dispatch(setUserWalletBalance({ data: 0 }));
      if (checkout?.selectedPaymentMethod === "wallet") {
        dispatch(setPaymentMethod({ data: null }));
      }
    }
    dispatch(setWalletChecked({ data: nextChecked }));
  };

  // place_order lacks order_id; read the newest order.
  const fetchLatestOrderId = async () => {
    try {
      const res = await api.getOrders({
        limit: 1,
        offset: 0,
        type: "",
        orderType: "",
      });
      const row = Array.isArray(res?.data) ? res.data[0] : res?.data;
      return row?.id ?? row?.order_id ?? null;
    } catch (error) {
      console.log("[placeOrder] fetchLatestOrderId failed", error);
      return null;
    }
  };

  const handlePlaceOrder = async () => {
    if (storeClosed) {
      notifyClosed();
      return;
    }
    const method = checkout?.selectedPaymentMethod;
    const capitalizedMethod =
      String(method).charAt(0).toUpperCase() + String(method).slice(1);
    const status = method === "COD" || method === "wallet" ? 2 : 1;
    try {
      // Hard block: can't place an order to an undeliverable address.
      if (deliveryError) {
        toast.error(deliveryError);
        return;
      }
      if (method == null) {
        toast.error(t("please_select_payment_method"));
        return;
      }
      // Wallet-only needs full cover.
      if (
        method === "wallet" &&
        Number(user?.balance || 0) < Number(checkoutData?.total_amount || 0)
      ) {
        toast.error(t("please_select_payment_method"));
        return;
      }
      // Delivery needs an address (based on the priced mode).
      if (
        checkout?.address == null &&
        checkout?.orderType == "doorstep" &&
        checkoutData?.delivery_type !== "pickup"
      ) {
        toast.error(t("please_select_address"));
        return;
      }
      // Pickup needs a saved address or filled billing fields.
      if (
        checkoutData?.delivery_type === "pickup" &&
        (showManualBilling ? !billingDetails.isFilled : checkout?.address == null)
      ) {
        toast.error(
          t("please_select_address_or_fill_billing_details") ||
            "Please pick an address or fill in billing details",
        );
        return;
      }
      // Block: required prescriptions (medical, is_prescription_required=1) missing.
      if (hasMissingRequiredPrescriptions(products, prescriptions)) {
        toast.error(
          t("please_upload_required_prescription") ||
            "Please upload a prescription for all required medical items",
        );
        return;
      }
      // Billing must be valid when not same as shipping (delivery only).
      if (checkoutData?.delivery_type !== "pickup" && !billingDetails.isValid) {
        toast.error(
          t("please_fill_billing_details") || "Please fill in billing details",
        );
        return;
      }
      const buyerTaxError = buyerTaxField.validate(checkout?.buyerTaxNumber);
      if (buyerTaxError) {
        toast.error(buyerTaxError);
        return;
      }
      setCheckoutLoading(true);
      const response = await api.placeOrder({
        productVariantId: cart?.checkout?.product_variant_id,
        quantity: cart?.checkout?.quantity,
        total: cart?.checkout?.sub_total,
        deliveryCharge: cart?.checkout?.delivery_charge,
        finalTotal: checkout?.checkoutTotal,
        walletUsed: checkout?.isWalletChecked,
        walletBalance: checkout?.usedWalletBalance,
        // Manual pickup billing has no address id.
        addressId:
          checkoutData?.delivery_type === "pickup" && showManualBilling
            ? undefined
            : checkout?.address?.id,
        orderNote: checkout?.orderNote,
        paymentMethod: method,
        promocodeId: cart?.promo_code?.promo_code_id,
        status,
        // Mode the cart was priced in.
        delivery_type: checkoutData?.delivery_type,
        // Same coords used to price the cart.
        latitude:
          checkoutData?.delivery_type === "pickup"
            ? city?.latitude
            : (checkout?.address?.latitude ?? city?.latitude),
        longitude:
          checkoutData?.delivery_type === "pickup"
            ? city?.longitude
            : (checkout?.address?.longitude ?? city?.longitude),
        prescriptions,
        // Manual pickup billing is the whole Bill To.
        billingSameAsShipping:
          checkoutData?.delivery_type === "pickup" && showManualBilling
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
        buyerTaxNumber: buyerTaxField.enabled ? checkout?.buyerTaxNumber : "",
        buyerBusinessName: buyerTaxField.enabled
          ? checkout?.buyerBusinessName
          : "",
      });
      if (response?.status == 1) {
        // Tax number is per order — don't carry it into the next one.
        dispatch(setBuyerTaxNumber({ data: "" }));
        dispatch(setBuyerBusinessName({ data: "" }));
        // Get the order id from the response or the newest order.
        let placedOrderId = response?.order_id ?? response?.data?.order_id;
        if (!placedOrderId) {
          placedOrderId = await fetchLatestOrderId();
        }
        // order_item_id only for ecommerce channel orders.
        setOrderItemId(
          activeChannel === "ecommerce"
            ? (response?.order_item_id ?? response?.data?.order_item_id ?? null)
            : null,
        );
        // GA4 purchase. Fired on order creation, not gateway settlement — a
        // pending gateway order still counts, same as the backend's order list.
        trackPurchase({
          transactionId: placedOrderId,
          value: Number(checkoutData?.total_amount) || 0,
          currency: currencyCode,
          shipping: Number(shipping) || 0,
          items: products.map((p: any) =>
            toGaItem(
              p,
              p?.variants?.[0],
              Number(p?.variants?.[0]?.quantity ?? p?.qty) || 1,
            ),
          ),
        });
        // Order created; clear uploaded prescriptions.
        dispatch(clearPrescriptions());
        // Await so the button stays disabled until handoff.
        await initiateTransaction(placedOrderId, capitalizedMethod);
        if (status === 2) setOrderPlaced(true);
        setCheckoutLoading(false);
      } else {
        setCheckoutLoading(false);
        toast.error(getPickupErrorMessage(response?.message) || response?.message);
        // Stale pickup location: refetch the cart.
        if (response?.message === "pickup_store_changed_refresh_cart") {
          handleFetchCheckout();
        }
      }
    } catch (error: any) {
      setCheckoutLoading(false);
      // Order may already exist; show the error.
      console.error(
        "[placeOrder] failed AFTER order may have been created:",
        error,
      );
      toast.error(error?.message || t("something_went_wrong"));
    }
  };

  // ---- derived values ----
  // Items: current response, else last good cart, else redux.
  /* eslint-disable react-hooks/refs */
  const products =
    checkoutData?.cart ||
    lastCartRef.current?.cart ||
    cart?.checkout?.cart ||
    [];
  // Read through a ref so the GA4 effect keys on the count, not array identity.
  const productsRef = useRef(products);
  productsRef.current = products;

  // GA4 begin_checkout — once per visit to this page, after the cart lands.
  const beginCheckoutSentRef = useRef(false);
  useEffect(() => {
    if (beginCheckoutSentRef.current || !productsRef.current.length) return;
    beginCheckoutSentRef.current = true;
    trackBeginCheckout(
      productsRef.current.map((p: any) =>
        toGaItem(p, p?.variants?.[0], Number(p?.variants?.[0]?.quantity ?? p?.qty) || 1),
      ),
      currencyCode,
    );
  }, [products.length, currencyCode]);
  console.log("[checkout] render", {
    items: products.length,
    deliveryError: deliveryError || null,
    checkOutError,
    loading,
  });
  // Variants restricted for this address.
  const undeliverableVariantIds = new Set(
    (checkoutData?.undeliverable_variant_ids ??
      lastCartRef.current?.undeliverable_variant_ids ??
      []
    ).map((id: any) => String(id)),
  );
  // Hide cross-sell items already in the cart.
  const cartProductIds = new Set(products.map((p) => p?.id));
  const crossSellItems = crossSell.filter((p) => !cartProductIds.has(p?.id));
  const upSellItems = upSell;
  // Enabled payment methods (COD = Pay at Store for pickup).
  const isPickupMode =
    (checkoutData?.delivery_type ?? checkout?.deliveryType) === "pickup";
  const paymentOptions = [
    ...(checkoutData?.cod_allowed == "1"
      ? [
          {
            value: "COD",
            label: isPickupMode
              ? t("pay_at_store") || "Pay at Store"
              : t("cash_on_delivery"),
          },
        ]
      : []),
    ...paymentMethodKeys
      .filter((m) => setting?.payment_setting?.[m.key] === "1")
      .map((m) => ({ value: m.label, label: t(m.label) || m.label })),
  ];
  const selectedPayment = paymentOptions.find(
    (o) => o.value === checkout?.selectedPaymentMethod,
  );
  const itemCount = products.reduce(
    (sum, p) => sum + Number(p?.variants?.[0]?.quantity ?? p?.qty ?? 0),
    0,
  );
  // Delivery charge/tax: API sends 3 shapes.
  const deliveryChargeObj =
    (typeof checkoutData?.delivery_charge === "object"
      ? checkoutData?.delivery_charge
      : null) || checkoutData?.delivery_charges;
  const shipping =
    deliveryChargeObj?.total_delivery_charge ??
    deliveryChargeObj?.amount ??
    (typeof checkoutData?.delivery_charge === "object"
      ? undefined
      : checkoutData?.delivery_charge);
  const deliveryChargeTax = deliveryChargeObj;
  // Courier reaches the address (null = not asked).
  const courierServiceable =
    checkoutData?.courier_serviceable ?? deliveryChargeObj?.courier_serviceable;
  // Non-zero tax rows for the subtotal tooltip.
  const taxBreakdownRows = !checkOutError
    ? (checkoutData?.tax_breakdown || []).filter(
        (tx: any) => Number(tx?.amount) > 0,
      )
    : [];
  const walletUsed = checkout?.isWalletChecked
    ? Number(checkout?.usedWalletBalance || 0)
    : 0;
  // Wallet covers the full order → hide other methods.
  const walletCoversFull =
    checkout?.isWalletChecked &&
    Number(user?.balance || 0) >= Number(checkoutData?.total_amount || 0) &&
    Number(checkoutData?.total_amount || 0) > 0;
  const payable = checkOutError
    ? cart?.cartSubTotal
    : Math.max(Number(checkoutData?.total_amount || 0) - walletUsed, 0);
  // Cashback coupons don't reduce the total.
  const isCashbackCoupon =
    (checkoutData?.promocode_details?.discount_apply_type ??
      cart?.promo_code?.discount_apply_type) === "wallet";
  const promoDiscount = Number(checkoutData?.promocode_details?.discount || 0);
  // Free delivery discounts shipping, not the items, so it reports no amount.
  const isFreeDeliveryCoupon =
    (checkoutData?.promocode_details?.discount_type ??
      cart?.promo_code?.discount_type) === "free_delivery";
  // Savings from API saved_amount (already includes promo).
  const totalSaved = checkOutError
    ? 0
    : Number(checkoutData?.saved_amount || 0);

  const money = (val: number | string = 0) => formatCurrency(val, currency, decimals);

  const { setOrderItemId, initiateTransaction, stripe } = useCheckoutPayment({
    payable,
    currencyCode,
    setPaymentLoading,
  });

  // Reset the tick if navigation never unmounts us.
  useEffect(() => {
    if (!orderPlaced) return;
    const id = setTimeout(() => setOrderPlaced(false), 1500);
    return () => clearTimeout(id);
  }, [orderPlaced]);

  const placeOrderDisabled =
    checkoutLoading ||
    orderPlaced ||
    products.length === 0 ||
    (!isPickupMode && !!deliveryError) ||
    hasMissingRequiredPrescriptions(products, prescriptions);

  // Busy/success keep the primary fill instead of the grey disabled look.
  const placeOrderBusy = checkoutLoading || orderPlaced;
  const placeOrderDisabledClass =
    "disabled:cursor-not-allowed disabled:bg-gray-200 disabled:text-gray-400 dark:disabled:bg-zinc-700 dark:disabled:text-zinc-500";
  let placeOrderInner: React.ReactNode = (
    <>
      {t("place_order")}
      {rtl ? <FiChevronLeft size={18} /> : <FiChevronRight size={18} />}
    </>
  );
  if (orderPlaced) {
    placeOrderInner = (
      <span className="ckAnimCheckPop flex items-center justify-center w-6 h-6 rounded-full bg-white/25">
        <FiCheck size={16} strokeWidth={3} />
        <span className="sr-only">{t("order_placed")}</span>
      </span>
    );
  } else if (checkoutLoading) {
    placeOrderInner = (
      <>
        <PlaceOrderProgress />
        <span className="relative">{t("placing_order") || "Placing order..."}</span>
      </>
    );
  }

  const chargeTaxNote = (charge: any) =>
    Number(charge?.tax_amount) > 0 &&
    `${t("incl") || "Incl."} ${charge?.tax_name || t("tax") || "Tax"} ${money(charge?.tax_amount)}${
      charge?.is_refundable
        ? ` (${t("tax_not_refundable") || "tax not refundable"})`
        : ""
    }`;

  const addressGrid = (
    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
      {address?.allAddresses?.map((addr: any) => (
        <AddressCard
          key={addr?.id}
          addr={addr}
          active={checkout?.address?.id === addr?.id}
          onSelect={() => handleSelectAddress(addr)}
          onEdit={() => handleEditAddress(addr)}
          onDelete={() => handleDeleteAddress(addr)}
          formatAddress={formatAddress}
        />
      ))}
    </div>
  );

  if (loading) return <CheckoutSkeleton />;
  if (paymentLoading) return <CheckoutSkeleton />;

  return (
    <section className="bodyBackgroundColor min-h-screen pb-40 md:pb-28 lg:pb-8">
      {/* Coupon-applied confetti burst — full-screen, non-blocking, plays once. */}
      {showCouponBurst && couponBurstAnimation && (
        <div className="pointer-events-none fixed inset-0 z-[100] flex items-center justify-center">
          <Lottie
            className="h-full w-full"
            animationData={couponBurstAnimation}
            loop={false}
            style={{ transform: "scale(1.3)" }}
          />
        </div>
      )}
      <div className="container py-4 md:py-8">
        {/* page heading */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-5">
          <div className="flex items-center gap-3">
            <span className="w-10 h-10 rounded-xl primaryLightBack primaryColor dark:text-white flex items-center justify-center shrink-0">
              <FiShoppingBag size={20} />
            </span>
            <div>
              <h1 className="font-bold text-2xl md:text-3xl leading-tight">
                {t("checkout")}
              </h1>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-12 gap-4 md:gap-6 items-start">
          {/* ---------- LEFT ---------- */}
          <div className="col-span-12 lg:col-span-8 flex flex-col gap-4 md:gap-6">
            {/* Delivery / Pickup toggle, only when pickup is available. */}
            {(checkoutData?.pickup_available != null
              ? checkoutData.pickup_available === 1
              : city?.pickup_available === 1) && (
              <DeliveryTypeToggle
                active={checkoutData?.delivery_type ?? checkout?.deliveryType}
                onChange={handleDeliveryTypeChange}
                showFallbackNote={
                  !checkOutError &&
                  !deliveryTypeFetching &&
                  !!checkoutData?.delivery_type &&
                  checkoutData.delivery_type !== checkout?.deliveryType
                }
                fallbackReason={checkoutData?.pickup?.unavailable_reason}
              />
            )}

            {checkoutData?.delivery_type === "pickup" ? (
              <>
              <PickupStoreCard pickup={checkoutData?.pickup} />

              {/* Pickup billing: saved address or inline fields. */}
              {/* No overflow-hidden: the address 3-dot menu must escape. */}
              <div className="bodyBackgroundColor cardBorder !rounded-lg shadow-sm">
                <div className="flex items-center justify-between gap-3 p-4 md:p-5 border-b">
                  <SectionHeader
                    icon={<FiCreditCard size={18} />}
                    title={t("billing_details") || "Billing Details"}
                  />
                  {address?.allAddresses?.length > 0 && !showManualBilling && (
                    <button
                      type="button"
                      className="flex items-center gap-1.5 text-sm font-semibold primaryColor dark:text-white shrink-0 hover:opacity-80 transition"
                      onClick={() => setShowManualBilling(true)}
                    >
                      <FiPlus size={16} />
                      {t("add_new_address") || "Add New Address"}
                    </button>
                  )}
                  {showManualBilling && address?.allAddresses?.length > 0 && (
                    <button
                      type="button"
                      className="inline-flex shrink-0 items-center gap-1.5 rounded-full primaryLightBack px-3 py-1.5 text-xs font-bold primaryColor transition-opacity hover:opacity-80"
                      onClick={() => setShowManualBilling(false)}
                    >
                      <FiChevronLeft size={14} className="shrink-0" />
                      {t("choose_saved_address") || "Choose a saved address"}
                    </button>
                  )}
                </div>

                <div className="p-4 md:p-5">
                  {!showManualBilling && address?.allAddresses?.length > 0 && (
                    addressGrid
                  )}

                  {!showManualBilling && !(address?.allAddresses?.length > 0) && (
                    <AddAddressTile label={t("add_new_address") || "Add New Address"} onClick={() => setShowManualBilling(true)} />
                  )}

                  {/* Inline billing fields (sent as billing_* params). */}
                  {showManualBilling && (
                    <BillingFields billingDetails={billingDetails} className="flex flex-col gap-3.5" />
                  )}
                </div>
              </div>
              </>
            ) : (
              /* Delivery Address */
              <div className="bodyBackgroundColor cardBorder !rounded-lg shadow-sm">
                <div className="flex justify-between items-center gap-3 p-4 md:p-5 border-b">
                  <div className="flex items-center gap-2.5 min-w-0 flex-wrap">
                    <SectionHeader
                      icon={<FiMapPin size={18} />}
                      title={t("delivery_address")}
                    />
                  </div>
                  {address?.allAddresses?.length > 0 && (
                    <button
                      type="button"
                      className="flex items-center gap-1.5 text-sm font-semibold primaryColor dark:text-white shrink-0 hover:opacity-80 transition"
                      onClick={() => {
                        setIsAddressSelected(false);
                        setShowAddAddres(true);
                      }}
                    >
                      <FiPlus size={16} />
                      {t("add_address")}
                    </button>
                  )}
                </div>

                <div className="p-4 md:p-5">
                  {address?.allAddresses?.length > 0 ? (
                    addressGrid
                  ) : (
                    <AddAddressTile label={t("add_address")} onClick={() => {
                        setIsAddressSelected(false);
                        setShowAddAddres(true);
                      }} />
                  )}

                  {/* Undeliverable address banner. */}
                  {deliveryError && (
                    <div className="mt-3 flex items-start gap-2.5 rounded-xl border border-red-200 dark:border-red-500/30 bg-red-50 dark:bg-red-500/10 px-3.5 py-2.5">
                      <FiMapPin
                        size={16}
                        className="text-red-500 shrink-0 mt-0.5"
                      />
                      <p className="text-sm font-medium text-red-600 dark:text-red-400">
                        {deliveryError}
                      </p>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Billing details (delivery only). */}
            {checkoutData?.delivery_type !== "pickup" && (
            <div className="bodyBackgroundColor cardBorder !rounded-lg shadow-sm overflow-hidden">
              <label className="flex items-center justify-between gap-3 p-4 md:p-5 cursor-pointer">
                <SectionHeader
                  icon={<FiCreditCard size={18} />}
                  title={t("billing_details") || "Billing Details"}
                />
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
                <BillingFields billingDetails={billingDetails} className="flex flex-col gap-3.5 p-4 md:p-5 border-t" />
              )}
            </div>
            )}

            {/* Your Cart */}
            <div className="bodyBackgroundColor cardBorder !rounded-lg shadow-sm overflow-hidden">
              <div className="flex items-center justify-between gap-3 p-4 md:p-5">
                <SectionHeader
                  icon={<FiShoppingBag size={18} />}
                  title={t("your_cart")}
                  count={`${itemCount} ${t("items")}`}
                />
              </div>
              <div className="flex flex-col">
                {products.map((product) => (
                  <CheckoutItemRow
                    key={product?.variant_id || product?.id}
                    product={product}
                    money={money}
                    maxCartItemsCount={setting?.setting?.max_cart_items_count}
                    otherLinesQty={
                      itemCount -
                      Number(
                        product?.variants?.[0]?.quantity ?? product?.qty ?? 0,
                      )
                    }
                    onCommitQty={handleCommitQty}
                    onRemoveUnits={handleRemoveUnits}
                    isUndeliverable={undeliverableVariantIds.has(
                      String(
                        product?.variants?.[0]?.id ?? product?.variant_id,
                      ),
                    )}
                  />
                ))}
                {products.length === 0 && (
                  <p className="text-sm SecondaryTextColor p-5 border-t">
                    {t("no_data_found")}
                  </p>
                )}

                {products.length > 0 && <GiftDetails />}

                {/* Delivery instruction (quick only). */}
                {shopMode === "quick" && products.length > 0 && <OrderNotes />}

                {/* Optional buyer tax registration, frozen onto the invoice. */}
                {buyerTaxField.enabled && products.length > 0 && (
                  <BuyerTaxDetails
                    label={buyerTaxField.label}
                    validate={buyerTaxField.validate}
                    className="border-t p-4 md:px-5"
                  />
                )}
              </div>
            </div>

            {/* Frequently bought together (cross-sell) */}
            <RecommendationStrip
              id="cross"
              title={t("frequently_bought_together")}
              products={crossSellItems}
            />

            {/* Upgrade your order (upsell) */}
            <RecommendationStrip
              id="upsell"
              title={t("upgrade_your_order")}
              products={upSellItems}
            />
          </div>

          {/* ---------- RIGHT ---------- */}
          <div className="col-span-12 lg:col-span-4 flex flex-col gap-4 md:gap-6 lg:sticky lg:top-24 lg:self-start">
            {/* Order summary (includes payment method). */}
            <div className="bodyBackgroundColor cardBorder !rounded-lg shadow-sm overflow-hidden">
              <div className="p-4 md:p-5 border-b">
                <span className="font-bold text-lg md:text-xl flex items-center gap-2">
                  <FiTag size={18} className="primaryColor dark:text-white" />
                  {t("order_summary")}
                </span>
              </div>
              <div className="px-4 md:px-5 py-4 md:py-5 flex flex-col gap-3">
                {!checkOutError && checkoutData?.unlock_message && (
                  <UnlockCouponNudge
                    code={checkoutData?.unlock_promo_code}
                    message={checkoutData?.unlock_message}
                  />
                )}

                <Row
                  label={
                    <>
                      {t("sub_total")} ({itemCount} {t("items")}){" "}
                      {/* Subtotal already includes tax. */}
                      {taxBreakdownRows.length > 0 && (
                        <span className="text-[11px]">
                          ({t("incl_tax") || "Incl. Tax"})
                        </span>
                      )}
                    </>
                  }
                  value={money(
                    checkOutError
                      ? cart?.cartSubTotal
                      : checkoutData?.sub_total,
                  )}
                  // Tax split shown in the (i) tooltip.
                  taxNote={
                    taxBreakdownRows.length > 0 && (
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
                    )
                  }
                />

                {!checkOutError &&
                  checkout?.orderType == "doorstep" &&
                  checkoutData?.delivery_type !== "pickup" && (
                    <Row
                      label={t("delivery_charge")}
                      value={money(shipping)}
                      taxNote={
                        Number(deliveryChargeTax?.tax_amount) > 0 &&
                        `${t("incl") || "Incl."} ${deliveryChargeTax?.tax_name || t("tax") || "Tax"} ${money(deliveryChargeTax?.tax_amount)}`
                      }
                    />
                  )}

                {/* Courier can't reach; we'll still deliver (info only). */}
                {!checkOutError &&
                  checkout?.orderType == "doorstep" &&
                  checkoutData?.delivery_type !== "pickup" &&
                  courierServiceable === false && (
                    <p className="-mt-1 text-xs text-amber-700 dark:text-amber-300">
                      {t("we_will_arrange_delivery") ||
                        "Delivery is not available at this pincode."}
                    </p>
                  )}

                {checkoutData?.additional_charges?.map((charge, i) => (
                  <Row
                    key={charge?.id ?? `${charge?.title}-${i}`}
                    label={charge?.title}
                    value={money(charge?.amount)}
                  />
                ))}

                {!checkOutError &&
                  checkoutData?.delivery_type !== "pickup" &&
                  checkoutData?.surge_charges?.map((charge, i) => (
                    <Row
                      key={charge?.id ?? `surge-${charge?.label}-${i}`}
                      label={charge?.label}
                      value={money(charge?.charge)}
                      badge={{ refundable: charge?.is_refundable }}
                      taxNote={chargeTaxNote(charge)}
                    />
                  ))}

                {!checkOutError &&
                  checkoutData?.zone_additional_charges?.map((charge, i) => (
                    <Row
                      key={charge?.id ?? `zone-${charge?.name}-${i}`}
                      label={charge?.name}
                      value={money(charge?.amount)}
                      badge={{ refundable: charge?.is_refundable }}
                      taxNote={chargeTaxNote(charge)}
                    />
                  ))}

                {checkoutData?.promocode_details && !checkOutError && (
                  <AppliedCouponTicket
                    code={
                      cart?.promo_code?.promo_code ||
                      checkoutData?.promocode_details?.promo_code
                    }
                    amountText={money(promoDiscount)}
                    isCashback={isCashbackCoupon}
                    isFreeDelivery={isFreeDeliveryCoupon}
                    onRemove={handleRemoveDiscount}
                  />
                )}

                {walletUsed > 0 && (
                  <Row
                    label={
                      <span className="flex items-center gap-1.5 font-medium">
                        <span className="inline-flex items-center justify-center p-1 rounded-md bg-emerald-500/10 text-emerald-600 dark:text-emerald-400">
                          <RiWallet3Line size={14} />
                        </span>
                        {t("store_credit_applied") || "Wallet Balance"}
                      </span>
                    }
                    value={
                      <span className="text-emerald-600 dark:text-emerald-400 font-bold">
                        - {money(walletUsed)}
                      </span>
                    }
                  />
                )}

                <CouponInput
                  value={discountInput}
                  onChange={setDiscountInput}
                  onApply={handleApplyDiscount}
                  onViewAll={() => setShowCouponCode(true)}
                />
                {/* grand total */}
                <div className="border-t border-dashed pt-3 flex items-center justify-between">
                  <div className="flex flex-col">
                    <span className="font-bold text-base textColor">
                      {t("total_with_vat")}
                    </span>
                    <span className="text-[11px] SecondaryTextColor">
                      {itemCount} {t("items")}
                    </span>
                  </div>
                  <span className="font-bold text-xl primaryColor dark:text-white">
                    <AnimatedNumber value={payable} format={money} />
                  </span>
                </div>

                {totalSaved > 0 && (
                  <SavingsBanner amountText={money(totalSaved)} />
                )}
                {isCashbackCoupon && promoDiscount > 0 && (
                  <CashbackBanner amountText={money(promoDiscount)} />
                )}

                {/* Payment method (hidden if wallet covers all). */}
                {walletCoversFull ? (
                  <WalletCoversBanner />
                ) : (
                  <PaymentMethodButton
                    selected={selectedPayment}
                    onClick={() => setShowPaymentPicker(true)}
                  />
                )}

                {/* Desktop place order (mobile uses bottom bar). */}
                <button
                  type="button"
                  {...closedProps}
                  className={`hidden lg:flex relative overflow-hidden items-center justify-center gap-1.5 w-full primaryBackColor text-white font-bold py-3 !rounded-xl transition duration-150 hover:opacity-95 active:scale-[0.97] motion-reduce:active:scale-100 ${placeOrderBusy ? "disabled:cursor-wait" : placeOrderDisabledClass} ${closedProps.className ?? ""}`}
                  disabled={placeOrderDisabled}
                  aria-busy={checkoutLoading}
                  onClick={handlePlaceOrder}
                >
                  {placeOrderInner}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Sticky mobile place-order bar */}
      <div className="lg:hidden fixed bottom-[60px] md:bottom-0 left-0 right-0 z-50 bodyBackgroundColor border-t shadow-[0_-2px_12px_rgba(0,0,0,0.08)] px-4 py-3 flex items-center gap-3">
        <div className="flex flex-col min-w-0">
          <span className="text-lg font-bold textColor leading-tight">
            <AnimatedNumber value={payable} format={money} />
          </span>
          <span className="text-[11px] SecondaryTextColor uppercase tracking-wide">
            {t("total_with_vat")}
          </span>
        </div>
        <button
          type="button"
          {...closedProps}
          className={`ml-auto flex-1 max-w-[60%] relative overflow-hidden primaryBackColor text-white font-bold py-3 !rounded-xl flex items-center justify-center gap-1 transition duration-150 active:scale-[0.97] motion-reduce:active:scale-100 ${placeOrderBusy ? "disabled:cursor-wait" : placeOrderDisabledClass} ${closedProps.className ?? ""}`}
          disabled={placeOrderDisabled}
          aria-busy={checkoutLoading}
          onClick={handlePlaceOrder}
        >
          {placeOrderInner}
        </button>
      </div>

      {showAddAddres && (
        <NewAddressModal
          fetchAddress={fetchAddress}
          showAddAddres={showAddAddres}
          setShowAddAddres={setShowAddAddres}
          isAddressSelected={isAddressSelected}
        />
      )}
      {showCouponCode && (
        <CouponCodeDrawer
          showCouponCode={showCouponCode}
          setShowCouponCode={setShowCouponCode}
        />
      )}

      <PaymentPickerDialog
        open={showPaymentPicker}
        onOpenChange={setShowPaymentPicker}
        overlayClassName={theme == "light" ? "bg-black/50" : "bg-black/70"}
        options={paymentOptions}
        selectedValue={checkout?.selectedPaymentMethod}
        onPick={(value) => {
          dispatch(setPaymentMethod({ data: value }));
          setShowPaymentPicker(false);
        }}
        codHeading={
          isPickupMode
            ? t("pay_at_store") || "Pay at Store"
            : t("cash_on_delivery")
        }
        walletBalanceText={user?.balance >= 1 ? money(user?.balance) : null}
        walletChecked={!!checkout?.isWalletChecked}
        onWalletToggle={handleWalletToggle}
      />

      <DeleteAddressDialog
        addressText={addressToDelete ? formatAddress(addressToDelete) : null}
        overlayClassName={theme == "light" ? "bg-white/80" : "bg-black/80"}
        deleting={deletingAddress}
        onCancel={() => setAddressToDelete(null)}
        onConfirm={confirmDeleteAddress}
      />

      {stripe.show && (
        <StripeModal
          showStripe={stripe.show}
          setShowStripe={stripe.setShow}
          amount={payable}
          // Stripe values are always set before show.
          clientSecret={stripe.clientSecret ?? ""}
          stripeTransId={stripe.transactionId ?? undefined}
          stripeOrderId={stripe.orderId != null ? String(stripe.orderId) : undefined}
          type="order"
        />
      )}
    </section>
  );
  /* eslint-enable react-hooks/refs */
};

export default CheckoutUI;
