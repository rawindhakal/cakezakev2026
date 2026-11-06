"use client";

import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import dynamic from "next/dynamic";
import { t } from "@/utils/translation";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import CartProductsCard from "./CartDrawerProductsCard";
import { useSelector, useDispatch } from "react-redux";
import * as api from "@/api/apiRoutes";
import NoCartData from "@/assets/empty-state/empty-cart.svg";
import {
  clearActiveGuestCart,
  clearCartPromo,
  setCartCurrency,
  setCartDecimal,
  setCartProducts,
  setCartPromo,
  setCartSubTotal,
  setDoorStepDeliveryMode,
  setGuestCartTotal,
  setSelfPickupMode,
} from "@/redux/slices/cartSlice";
import { usePathname, useRouter } from "next/navigation";
import CouponList from "@/components/couponcode/CouponList";
import ThemedSvg from "@/components/notfound/ThemedSvg";
import {
  RiArrowLeftLine,  
  RiDeleteBin6Line,
  RiWallet3Line,
  RiCloseFill,
  RiMapPin2Line,
  RiPencilLine,
} from "react-icons/ri";
import AppliedCouponCard from "./AppliedCouponCard";
import UnlockCouponNudge from "./UnlockCouponNudge";
import useLazyLottie from "@/hooks/useLazyLottie";
import { getPrimaryLottieRgb, recolorAnimation } from "@/utils/lottieColor";
import Link from "next/link";
import CartDrawerSkeletons from "./CartDrawerLoading";
import QuickCheckoutView from "./QuickCheckoutView";
import CartAddonEditor from "./CartAddonEditor";
import DeliveryModeToggle from "./DeliveryModeToggle";
import { clearAllFilter } from "@/redux/slices/productFilterSlice";
import { parseZonePath } from "@/utils/zoneUrl";
import useLanguages from "@/hooks/useLanguages";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
// Untyped JS — TS wrongly infers optional `actionLabel` as required.
import NotDeliverableMessageRaw from "@/components/not-deliverable/NotDeliverableMessage";
const NotDeliverableMessage = NotDeliverableMessageRaw as any;
import { formatCurrency } from "@/utils/helperFunction";
import useZoneHref from "@/hooks/useZoneHref";
import useStoreClosed from "@/hooks/useStoreClosed";
import useCurrency from "@/hooks/useCurrency";
import usePendingCouponAutoApply from "@/hooks/usePendingCouponAutoApply";
import CouponAutoApplyError from "./CouponAutoApplyError";
import AnimatedNumber from "@/components/ui/AnimatedNumber";
import {
  cartLineKey,
  guestCartItemsParam,
  guestRowsHaveAddons,
} from "@/utils/addons";

const Lottie = dynamic(() => import("lottie-react"), { ssr: false });

interface CartDrawerProps {
  showCart: boolean;
  setShowCart: (show: boolean) => void;
  // Header's — closing the cart unmounts this, so a local flag would die.
  setShowLogin: (show: boolean) => void;
  /** Unused. */
  setMobileActiveKey?: (key: any) => void;
}

const CartDrawer = ({
  showCart,
  setShowCart,
  setShowLogin,
  setMobileActiveKey,
}: CartDrawerProps) => {
  const zoneHref = useZoneHref();
  const { storeClosed, notifyClosed, closedProps } = useStoreClosed();
  const { clearAll: clearUrlFilters } = useUrlProductFilters();
  const dispatch = useDispatch();
  const router = useRouter();
  const pathname = usePathname();
  const { parseLangPath } = useLanguages();
  const city = useSelector((state: any) => state.City.city);
  const cart = useSelector((state: any) => state.Cart);
  const user = useSelector((state: any) => state.User);
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  const coupon = useSelector((state: any) => state.Cart.promo_code);
  const shopMode = useSelector((state: any) => state.ShopMode.mode);
  const activeChannel = shopMode === "quick" ? "quick" : "ecommerce";

  const openFetchedRef = useRef(false);
  const [cartProductsData, setCartProductsData] = useState<any[]>([]);
  usePendingCouponAutoApply({
    active: showCart,
    hasItems: cartProductsData.length > 0,
    subTotal: Number(cart?.cartSubTotal || 0),
  });
  const [cartData, setCartData] = useState<any>([]);
  const [loading, setLoading] = useState(false);
  const [couponLoading, setCouponLoading] = useState(false);
  const [showCouponCode, setShowCouponCode] = useState(false);
  // Row whose addons are being re-picked; swaps the drawer body for the editor.
  const [editAddonLine, setEditAddonLine] = useState<any>(null);
  const [couponCodes, setCouponCodes] = useState<any[]>([]);
  const [couponListLoading, setCouponListLoading] = useState(false);
  const [notDeliverableMessage, setNotDeliverableMessage] = useState<string | null>(null);
  const [showCouponSuccess, setShowCouponSuccess] = useState(false);
  const [clearLoading, setClearLoading] = useState(false);
  // Address picker is local only — never writes City.city (an address has no
  // zone slug/id; overwriting would break zone-dependent code).
  const [showAddressPicker, setShowAddressPicker] = useState(false);
  const [savedAddresses, setSavedAddresses] = useState<any[]>([]);
  const [addressListLoading, setAddressListLoading] = useState(false);
  const [switchingAddressId, setSwitchingAddressId] = useState<any>(null);
  const [selectedAddress, setSelectedAddress] = useState<any>(null);

  // Gift Lottie with black repainted to primary color.
  const giftAnimation = useLazyLottie(() => import("@/assets/gift.json"));
  // 331KB burst: own chunk, fetched after the drawer opens, not with it.
  const couponBurstAnimation = useLazyLottie(
    () => import("@/assets/order_place_animation/order_placed_back_animation.json"),
  );
  const giftLottie = useMemo(
    () =>
      giftAnimation
        ? recolorAnimation(giftAnimation, getPrimaryLottieRgb(), "black")
        : null,
    [giftAnimation],
  );

  // Zone setting first — /cart's currency can be stale (INR in an AED zone).
  const { currency: liveCurrency, decimals: liveDecimals } = useCurrency();
  const currency = liveCurrency || cartData?.currency || cart?.currency || "";
  const decimals =
    liveDecimals || cartData?.decimal_point || cart?.decimal_point || 0;
  const money = (amount: number | string = 0) => formatCurrency(amount, currency, decimals);

  // Burst only when promo_code changes to a new code (not re-apply/removal).
  const hadCouponRef = useRef(coupon?.promo_code || null);
  useEffect(() => {
    const nowCode = coupon?.promo_code || null;
    const prevCode = hadCouponRef.current;
    if (nowCode && nowCode !== prevCode && showCart) {
      setShowCouponSuccess(true);
      const timer = setTimeout(() => setShowCouponSuccess(false), 1600);
      hadCouponRef.current = nowCode;
      return () => clearTimeout(timer);
    }
    hadCouponRef.current = nowCode;
  }, [coupon?.promo_code, showCart]);

  // Only the latest request's response is applied.
  const fetchSeqRef = useRef(0);
  // coords: address picker override; defaults to city.
  const fetchCart = async (coords?: { latitude?: number; longitude?: number }) => {
    const seq = ++fetchSeqRef.current;
    setLoading(true);
    setNotDeliverableMessage(null);
    try {
      const cartData = await api.getCart({
        latitude: coords?.latitude ?? city?.latitude,
        longitude: coords?.longitude ?? city?.longitude,
      });
      if (seq !== fetchSeqRef.current) return;
      // Cart API decides deliverability. Blocked only if pickup is also
      // unavailable (QuickCheckoutView owns the mode toggle). Never empties cart.
      const isDeliverable =
        (Number(cartData?.data?.delivery_available) === 1 &&
          Number(cartData?.data?.is_deliverable_address) === 1) ||
        Number(cartData?.data?.pickup_available) === 1;

      if (cartData?.status == 1) {
        const normalizedCart = cartData?.data?.cart?.map((item: any) => {
          const variant = item?.variants?.[0] || {};
          return {
            ...item,
            product_id: item?.id,
            product_variant_id: item?.variant_id,
            addons: item?.addons ?? [],
            qty: variant?.quantity ?? item?.quantity,
            image_url: item?.images?.[0]?.image_url,
            attributes_text: variant?.attributes_text,
            variant_attributes:
              variant?.variant_attributes ?? item?.variant_attributes ?? [],
            total_allowed_quantity: item?.total_allowed_quantity ?? item?.stock,
          };
        });
        setCartProductsData(normalizedCart);
        dispatch(setCartSubTotal({ data: cartData?.data?.sub_total }));
        dispatch(setCartDecimal({ data: cartData?.data?.decimal_point }));
        dispatch(
          setCartCurrency({
            data: cartData?.data?.currency ?? "",
            channel: activeChannel,
          }),
        );
        dispatch(setSelfPickupMode({ data: cartData?.data?.self_pickup_mode }));
        dispatch(
          setDoorStepDeliveryMode({
            data: cartData?.data?.doorstep_delivery_mode,
          }),
        );
        setCartData(cartData?.data);
        setNotDeliverableMessage(
          isDeliverable
            ? null
            : t("sorry_we_are_not_delivering_on_selected_address"),
        );
        await handleApplyCoupon(cartData?.data?.sub_total);
        const productsData = normalizedCart?.map((product: any) => {
          return {
            product_id: product?.product_id,
            product_variant_id: product?.product_variant_id,
            // Picks travel with the row — two lines of one variant differ only by these.
            addons: product?.addons ?? [],
            qty: product?.qty,
          };
        });

        dispatch(setCartProducts({ data: productsData }));
        setLoading(false);
      } else {
        dispatch(setCartProducts({ data: [] }));
        dispatch(setCartSubTotal({ data: 0 }));
        setCartProductsData([]);
        if (cartData?.data && cartData?.message) {
          setNotDeliverableMessage(cartData.message);
        }
        setLoading(false);
      }
    } catch (error) {
      if (seq !== fetchSeqRef.current) return;
      setLoading(false);
      console.log("error", error);
    }
  };

  const handleToggleAddressPicker = async () => {
    setShowAddressPicker((prev) => !prev);
  };

  // Loaded up front so the "Deliver to" pill can label itself.
  const loadSavedAddresses = async () => {
    setAddressListLoading(true);
    try {
      const response: any = await api.getAddress();
      const list = Array.isArray(response?.data) ? response.data : [];
      setSavedAddresses(list);
      // Best-effort coord match, else default address.
      const match = list.find(
        (a: any) =>
          Number(a?.latitude) === Number(city?.latitude) &&
          Number(a?.longitude) === Number(city?.longitude),
      );
      setSelectedAddress(match || list.find((a: any) => a?.is_default == 1) || null);
    } catch (error) {
      console.log("Error", error);
    } finally {
      setAddressListLoading(false);
    }
  };  

  const handlePickAddress = async (addr: any) => {
    if (addr?.latitude == null || addr?.longitude == null) return;
    setSwitchingAddressId(addr?.id);
    try {
      await fetchCart({ latitude: addr.latitude, longitude: addr.longitude });
      setSelectedAddress(addr);
      setShowAddressPicker(false);
    } finally {
      setSwitchingAddressId(null);
    }
  };

  const handleApplyCoupon = async (currentAmount?: number) => {
    setCouponLoading(true);
    try {
      const response = await api.setPromoCode({
        promoCodeName: coupon?.promo_code,
        amount: currentAmount ?? cart?.cartSubTotal,
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      if (response.status == 1) {
        dispatch(setCartPromo({ data: response.data }));
        setShowCouponCode(false);
      } else {
        await handleRemoveCoupon();
      }
    } catch (error) {
      console.log("Error", error);
    } finally {
      setCouponLoading(false);
    }
  };


  const handleViewCoupons = async () => {
    setShowCouponCode(true);
    setCouponListLoading(true);
    try {
      const response = await api.getPromo({
        amount: cart?.cartSubTotal,
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      setCouponCodes(response?.data || []);
    } catch (error) {
      console.log("Error", error);
    } finally {
      setCouponListLoading(false);
    }
  };

  const fetchGuestCart = async () => {
    setLoading(true);
    try {
      const variantIds = cart?.guestCart?.map((p: any) => p.product_variant_id);
      const quantities = cart?.guestCart?.map((p: any) => p.qty);
      // Rows with addons cannot ride the CSV pair, so they go as items JSON.
      const withAddons = guestRowsHaveAddons(cart?.guestCart);
      const response = await api.getGuestCart({
        latitude: city?.latitude,
        longitude: city?.longitude,
        variant_ids: withAddons ? undefined : variantIds?.join(","),
        quantities: withAddons ? undefined : quantities?.join(","),
        items: withAddons ? guestCartItemsParam(cart?.guestCart) : undefined,
      });
      if (response.status == 1) {
        const normalizedCart = response?.data?.cart?.map((item: any) => {
          const variant = item?.variants?.[0] || {};
          return {
            ...item,
            product_id: item?.id,
            product_variant_id: item?.variant_id,
            addons: item?.addons ?? [],
            qty: variant?.quantity ?? item?.quantity,
            image_url: item?.images?.[0]?.image_url,
            attributes_text: variant?.attributes_text,
            variant_attributes:
              variant?.variant_attributes ?? item?.variant_attributes ?? [],
            total_allowed_quantity: item?.total_allowed_quantity ?? item?.stock,
          };
        });
        setCartProductsData(normalizedCart);
        setCartData(response?.data);
        dispatch(setCartSubTotal({ data: response?.data?.sub_total }));
        dispatch(setGuestCartTotal({ data: response?.data?.sub_total }));
        dispatch(
          setCartCurrency({
            data: response?.data?.currency ?? "",
            channel: activeChannel,
          }),
        );
      }
    } catch (error) {
      console.log("Error", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (showCart) {
      // One fetch per open (StrictMode double-invokes). Reset on close.
      if (openFetchedRef.current) return;
      openFetchedRef.current = true;

      setShowCouponCode(false);
      setShowAddressPicker(false);
      if (cart?.isGuest && cart?.guestCart?.length == 0) {
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setCartProductsData([]);
      } else if (!cart.isGuest) {
        fetchCart();
        loadSavedAddresses();
      } else if (cart?.guestCart?.length > 0 && cart?.isGuest) {
        fetchGuestCart();
      }
    } else {
      openFetchedRef.current = false;
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [showCart]);

  // Stable ref for QuickCheckoutView's onClose effect.
  const closeCartDrawer = useCallback(() => setShowCart(false), [setShowCart]);

  const handleCheckoutbtnClick = () => {
    if (storeClosed) {
      notifyClosed();
      return;
    }
    // Check the token too — isGuest can stay false after the token is gone.
    if (cart.isGuest || !user?.jwtToken) {
      setShowCart(false);
      setShowLogin(true);
    } else {
      router.push(zoneHref("/checkout"));
    }
  };

  const isCouponApplied = cart?.promo_code != null;
  // "wallet" coupons are cashback — they don't reduce the total.
  const isCashbackCoupon = cart?.promo_code?.discount_apply_type === "wallet";
  const promoDiscount = Number(cart?.promo_code?.discount || 0);
  const savedAmount = Number(cartData?.saved_amount || 0);
  const cartTotalWithCoupon =
    isCouponApplied && !isCashbackCoupon
      ? cart?.cartSubTotal - savedAmount - promoDiscount
      : cart?.cartSubTotal - savedAmount;
  const handleRemoveCoupon = async () => {
    setCouponLoading(true);
    dispatch(clearCartPromo());
    setCouponLoading(false);
  };
  // Already on /products → cancel the Link (a full reload would undo the reset).
  const isOnProductsRoute = () => {
    const path = pathname || "/";
    const { rest: afterLang } = parseLangPath(path);
    const { rest } = parseZonePath("/" + afterLang.join("/"));
    return rest[0] === "products" && rest.length === 1;
  };

  const handleShopNow = (e: React.MouseEvent<HTMLAnchorElement>) => {
    dispatch(clearAllFilter());
    // Filter values live in the URL — clear those too.
    clearUrlFilters();
    setShowCart(false);
    if (isOnProductsRoute()) e.preventDefault();
  };

  // Logged-in + items + deliverable → single-page checkout in the drawer.
  const useSinglePageCheckout =
    !cart?.isGuest &&
    user?.jwtToken &&
    cartProductsData?.length > 0 &&
    !notDeliverableMessage;

  let drawerTitle = t("shoppingCart");
  if (editAddonLine) {
    drawerTitle = t("addon_customize");
  } else if (showCouponCode) {
    drawerTitle = t("coupons");
  } else if (useSinglePageCheckout) {
    drawerTitle = t("checkout");
  }

  const renderCouponList = () => (
    <CouponList
      coupons={couponCodes}
      loading={couponListLoading}
      onApplied={() => setShowCouponCode(false)}
    />
  );

  const renderCouponFooter = () => {
    if (couponLoading) {
      return (
        <div className="mb-2 flex items-center justify-center py-2">
          {giftLottie ? (
            <Lottie
              animationData={giftLottie}
              loop={true}
              className="h-16 w-16"
            />
          ) : (
            <div className="h-16 w-16" />
          )}
        </div>
      );
    }
    if (!cart?.isGuest && !isCouponApplied) {
      return (
        <div className="mb-2 flex flex-col gap-2">
          <div className="overflow-hidden rounded-xl empty:hidden [&>div]:border-b-0">
            <CouponAutoApplyError />
          </div>

          <UnlockCouponNudge
            code={cartData?.unlock_promo_code}
            message={cartData?.unlock_message}
            onViewAll={handleViewCoupons}
          />
        </div>
      );
    }
    if (!cart?.isGuest && isCouponApplied) {
      return (
        // key replays the animation per new code.
        <AppliedCouponCard
          key={cart?.promo_code?.promo_code}
          code={cart?.promo_code?.promo_code}
          savedAmount={money(cart?.promo_code?.discount)}
          discountType={cart?.promo_code?.discount_type}
          onRemove={handleRemoveCoupon}
          loading={couponLoading}
        />
      );
    }
    return null;
  };

  const handleClearCart = async () => {
    setClearLoading(true);
    try {
      // Guest cart is redux-only — clear locally.
      if (cart?.isGuest) {
        dispatch(clearActiveGuestCart());
        setCartProductsData([]);
        setCartData([]);
        dispatch(clearCartPromo());
        setShowCouponCode(false);
        return;
      }
      const response = await api.deleteCart();
      if (response?.status == 1) {
        setCartProductsData([]);
        setCartData([]);
        dispatch(setCartProducts({ data: [] }));
        dispatch(setCartSubTotal({ data: 0 }));
        dispatch(clearCartPromo());
        setShowCouponCode(false);
      }
    } catch (error) {
      console.log("Error", error);
    } finally {
      setClearLoading(false);
    }
  };

  // "Deliver to" pill (matches QuickCheckoutView), expands to saved addresses.
  const renderAddressPicker = () => {
    if (cart?.isGuest) return null;
    return (
      <div className="mx-4 mt-3">
        {!showAddressPicker ? (
          <button
            type="button"
            onClick={handleToggleAddressPicker}
            className="flex w-full items-center gap-2.5 cardBorderPrimary !rounded-lg bodyBackgroundColor px-4 py-3 text-start shadow-sm transition-colors hover:primaryLightBack"
          >
            <RiMapPin2Line size={18} className="primaryColor shrink-0" />
            <div className="flex min-w-0 flex-grow flex-col">
              <span className="truncate text-sm font-bold textColor">
                {t("deliver_to") || "Deliver to"}{" "}
                {selectedAddress?.type || selectedAddress?.name || ""}
              </span>
              <span className="truncate text-xs SecondaryTextColor leading-snug">
                {selectedAddress
                  ? [
                      selectedAddress?.address,
                      selectedAddress?.area,
                      selectedAddress?.city,
                      selectedAddress?.state,
                      selectedAddress?.pincode,
                      selectedAddress?.country,
                    ]
                      .filter(Boolean)
                      .join(", ")
                  : t("select_delivery_address") || "Select delivery address"}
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
                  {t("delivery_address") || "Delivery Address"}
                </span>
              </span>
              <button
                type="button"
                onClick={() => setShowAddressPicker(false)}
                aria-label={t("close")}
                className="shrink-0"
              >
                <RiCloseFill size={18} />
              </button>
            </div>
            <div className="flex flex-col gap-2 p-3">
              {addressListLoading ? (
                <p className="py-1 text-center text-xs SecondaryTextColor">
                  {t("loading") || "Loading..."}
                </p>
              ) : savedAddresses.length === 0 ? (
                <p className="py-1 text-center text-xs SecondaryTextColor">
                  {t("no_saved_addresses") || "No saved addresses found."}
                </p>
              ) : (
                savedAddresses.map((addr) => (
                  <button
                    key={addr?.id}
                    type="button"
                    onClick={() => handlePickAddress(addr)}
                    disabled={switchingAddressId != null}
                    className={`flex flex-col items-start rounded-lg border p-3 text-left transition-colors disabled:opacity-50 ${
                      selectedAddress?.id === addr?.id
                        ? "primaryColorBorder dark:border-white dark:bg-white/5"
                        : "border-[color-mix(in_srgb,var(--primary-color)_15%,transparent)] hover:border-[color-mix(in_srgb,var(--primary-color)_35%,transparent)]"
                    }`}
                  >
                    <span className="flex items-center gap-1.5 text-sm font-bold textColor">
                      {addr?.type || addr?.name}
                      {addr?.is_default == 1 && (
                        <span className="text-[10px] font-semibold primaryColor">
                          • {t("default")}
                        </span>
                      )}
                    </span>
                    <span className="text-xs SecondaryTextColor line-clamp-1">
                      {[addr?.address, addr?.area, addr?.city, addr?.state, addr?.pincode, addr?.country]
                        .filter(Boolean)
                        .join(", ")}
                    </span>
                    {switchingAddressId === addr?.id && (
                      <span className="mt-1 text-[11px] primaryColor">
                        {t("checking_deliverability") || "Checking..."}
                      </span>
                    )}
                  </button>
                ))
              )}
            </div>
          </section>
        )}
      </div>
    );
  };

  const renderCartWithItems = () => (
    <>
      {renderAddressPicker()}
      {/* Guest-only, display-only — doesn't reprice the guest cart. */}
      {cart?.isGuest && (
        <div className="px-4 pt-2">
          <DeliveryModeToggle checkoutData={cartData} isGuest />
        </div>
      )}
      <div className="flex items-center justify-between px-4 py-2.5">
        <span className="text-sm font-medium SecondaryTextColor">
          {cartProductsData?.length} {t("items")}
        </span>
        <button
          type="button"
          className="flex items-center gap-1 text-sm font-medium text-red-500 transition-opacity hover:opacity-80 disabled:opacity-50"
          onClick={handleClearCart}
          disabled={clearLoading}
        >
          <RiDeleteBin6Line size={16} />
          {clearLoading ? "..." : t("clear_cart")}
        </button>
      </div>
      <div className="flex flex-grow flex-col gap-2 overflow-y-auto px-3 pb-3">
        {cartProductsData?.map((product, index) => (
          // Staggered entry on drawer open; capped so long carts don't lag.
          <div
            key={cartLineKey(product)}
            className="motion-safe:animate-etaIn"
            style={{ animationDelay: `${Math.min(index, 8) * 40}ms`, animationFillMode: "both" }}
          >
            <CartProductsCard
              product={product}
              cartProductsData={cartProductsData}
              setCartProductsData={setCartProductsData}
              setCartData={setCartData}
              currency={currency}
              decimals={decimals}
              onEditAddons={setEditAddonLine}
            />
          </div>
        ))}
      </div>
      {notDeliverableMessage && (
        <div className="mx-4 mb-2 flex items-start gap-2 rounded-lg border border-red-200 dark:border-red-500/30 bg-red-50 dark:bg-red-500/10 px-3 py-2">
          <p className="text-sm font-medium text-red-600 dark:text-red-400">
            {notDeliverableMessage}
          </p>
        </div>
      )}
      {/* Per-SKU restriction — some items can't reach a deliverable address. */}
      {!notDeliverableMessage &&
        Array.isArray(cartData?.undeliverable_variant_ids) &&
        cartData.undeliverable_variant_ids.length > 0 &&
        (() => {
          const restrictedIds = new Set(
            cartData.undeliverable_variant_ids.map((id: any) => String(id)),
          );
          const restrictedNames = cartProductsData
            .filter((p) => restrictedIds.has(String(p?.product_variant_id)))
            .map((p) => p?.name)
            .filter(Boolean);
          if (restrictedNames.length === 0) return null;
          return (
            <div className="mx-4 mb-2 flex items-start gap-2 rounded-lg border border-amber-200 dark:border-amber-500/30 bg-amber-50 dark:bg-amber-500/10 px-3 py-2">
              <p className="text-sm font-medium text-amber-700 dark:text-amber-400">
                {(t("items_not_deliverable_to_this_address") ||
                  "Can't be delivered to this address:") +
                  " " +
                  restrictedNames.join(", ")}
              </p>
            </div>
          );
        })()}
      <div className="sticky bottom-0 w-full border-t bg-white p-4 dark:bg-zinc-900">
        {renderCouponFooter()}

        <div className="space-y-2">
          {!cart.isGuest && (
            <div className="flex justify-between text-sm SecondaryTextColor">
              <span>{t("subtotal")}</span>
              <span>{money(cart?.cartSubTotal)}</span>
            </div>
          )}
          {!cart.isGuest && isCouponApplied && !isCashbackCoupon && (
            <div className="flex justify-between text-sm primaryColor dark:text-green-400">
              <span>{t("coupon_discount")}</span>
              <span>-{money(promoDiscount)}</span>
            </div>
          )}
          {!cart.isGuest && cartData?.saved_amount > 0 && (
            <div className="flex justify-between text-sm primaryColor dark:text-green-400">
              <span>{t("you_save")}</span>
              <span>{money(cartData?.saved_amount)}</span>
            </div>
          )}
          <div className="flex justify-between border-t pt-2 text-base font-bold textColor">
            <span>{t("total")}</span>
            <span>
              <AnimatedNumber
                value={cart.isGuest ? cart?.guestCartTotal : cartTotalWithCoupon}
                format={money}
              />
            </span>
          </div>
        </div>

        {/* Cashback: separate callout, not part of the total. */}
        {!cart.isGuest && isCouponApplied && isCashbackCoupon && (
          <div className="mt-3 flex items-center gap-2.5 rounded-lg bg-amber-500/10 px-3 py-2.5">
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

        <div className="mt-4 flex items-center gap-3">
          <button
            type="button"
            {...closedProps}
            className={`primaryBackColor flex-[1.5] rounded-lg py-2.5 text-sm font-bold text-white transition-opacity hover:opacity-90 disabled:bg-gray-200 disabled:text-gray-400 dark:disabled:bg-zinc-700 dark:disabled:text-zinc-500 disabled:cursor-not-allowed ${closedProps.className ?? ""}`}
            onClick={handleCheckoutbtnClick}
            disabled={!!notDeliverableMessage}
          >
            {!user?.jwtToken ? t("login_to_checkout") : t("checkout")}
          </button>
        </div>
      </div>
    </>
  );

  return (
    <Sheet open={showCart}>
      <SheetContent
        side={language?.type == "RTL" ? "left" : "right"}
        className="p-0 w-full sm:!max-w-md lg:!max-w-lg flex flex-col h-[100dvh]"
      >
        {showCouponSuccess && couponBurstAnimation && (
          <div className="pointer-events-none absolute inset-0 z-50 flex items-center justify-center overflow-hidden bg-black/5 backdrop-blur-[1px]">
            <Lottie
              className="absolute inset-0 h-full w-full"
              animationData={couponBurstAnimation}
              loop={false}
            />
          </div>
        )}
        <SheetHeader className="px-4 py-3 border-b text-left">
          <SheetTitle className="flex flex-row items-center justify-between">
            <div className="flex items-center gap-2">
              {(showCouponCode || editAddonLine) && (
                <button
                  type="button"
                  className="hover:cursor-pointer"
                  onClick={() =>
                    editAddonLine
                      ? setEditAddonLine(null)
                      : setShowCouponCode(false)
                  }
                  aria-label={t("back")}
                >
                  <RiArrowLeftLine size={24} />
                </button>
              )}
              <p className="text-xl font-bold">{drawerTitle}</p>
            </div>
            <button
              type="button"
              className="closeButtonBg flex items-center justify-center rounded-full p-2 transition-colors hover:opacity-80"
              onClick={() => setShowCart(false)}
              aria-label={t("close")}
            >
              <RiCloseFill size={22} />
            </button>
          </SheetTitle>
        </SheetHeader>

        {editAddonLine ? (
          <CartAddonEditor
            line={editAddonLine}
            money={money}
            onBack={() => setEditAddonLine(null)}
            onSaved={(payload?: any) => {
              setEditAddonLine(null);
              if (payload?.guestCart) fetchGuestCart();
              else if (!cart?.isGuest) fetchCart();
            }}
          />
        ) : showCouponCode ? (
          <div className="flex-grow overflow-y-auto">
            {renderCouponList()}
          </div>
        ) : loading ? (
          <CartDrawerSkeletons />
        ) : useSinglePageCheckout ? (
          <QuickCheckoutView
            onClose={closeCartDrawer}
            money={money}
            currency={currency}
            decimals={decimals}
            cartProductsData={cartProductsData}
            setCartProductsData={setCartProductsData}
            setCartData={setCartData}
            onViewCoupons={handleViewCoupons}
            onEditAddons={setEditAddonLine}
          />
        ) : cartProductsData?.length !== 0 ? (
          renderCartWithItems()
        ) : notDeliverableMessage ? (
          <NotDeliverableMessage
            message={notDeliverableMessage}
            onActionClick={() => setShowCart(false)}
          />
        ) : (
          <div className="flex h-full items-center justify-center px-8">
            <div className="flex flex-col items-center gap-3 text-center">
              <ThemedSvg
                src={NoCartData}
                alt="No Cart Data"
                className="w-48 object-contain sm:w-64"
              />
              <h1 className="text-xl font-bold">
                {t("empty_cart_list_message")}
              </h1>
              <p className="text-sm opacity-60">
                {t("empty_cart_list_description")}
              </p>
              <Link
                href={zoneHref("/products")}
                className="primaryBackColor mt-2 rounded-md px-6 py-2 font-bold text-white transition-opacity hover:opacity-90"
                onClick={handleShopNow}
              >
                {t("empty_cart_list_button_name")}
              </Link>
            </div>
          </div>
        )}
      </SheetContent>
    </Sheet>
  );
};

export default CartDrawer;
