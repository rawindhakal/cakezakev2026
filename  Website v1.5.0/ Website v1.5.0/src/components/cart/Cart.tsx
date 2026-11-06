"use client";

import { useEffect, useRef, useState } from "react";
import dynamic from "next/dynamic";
import BreadCrumb from "../breadcrumb/BreadCrumb";
import CartProductCard from "./CartProductCard";
import CartCouponCard from "./CartCouponCard";
import CartOffersCarousel from "./CartOffersCarousel";
import { FiBookmark, FiChevronRight } from "react-icons/fi";
import { t } from "@/utils/translation";
import { useSelector, useDispatch } from "react-redux";
import {
  setCart,
  setCartCurrency,
  setCartDecimal,
  setCartProducts,
  setCartSubTotal,
  setDoorStepDeliveryMode,
  setSelfPickupMode,
  clearCartPromo,
} from "@/redux/slices/cartSlice";
import * as api from "@/api/apiRoutes";
import CouponCodeDrawer from "@/components/couponcode/CouponCodeDrawer";
import NoCartData from "@/assets/empty-state/empty-cart.svg";
import ThemedSvg from "@/components/notfound/ThemedSvg";
import CartPageSkeleton, { CartCouponSkeleton } from "./CartLoading";
import { useRouter } from "next/navigation";
import { clearAllFilter } from "@/redux/slices/productFilterSlice";
import useLazyLottie from "@/hooks/useLazyLottie";
import useZoneHref from "@/hooks/useZoneHref";
import useCurrency from "@/hooks/useCurrency";
import {
  cartLineKey,
  guestCartItemsParam,
  guestRowsHaveAddons,
} from "@/utils/addons";

const Lottie = dynamic(() => import("lottie-react"), { ssr: false });

const Cart = () => {
  const zoneHref = useZoneHref();
  const dispatch = useDispatch();
  const router = useRouter();
  const city = useSelector((state: any) => state.City.city);
  const cart = useSelector((state: any) => state.Cart);
  const user = useSelector((state: any) => state.User);
  const shopMode = useSelector((state: any) => state.ShopMode.mode);
  const activeChannel = shopMode === "quick" ? "quick" : "ecommerce";
  const [cartProductsData, setCartProductsData] = useState<any[]>([]);
  const [showCouponCode, setShowCouponCode] = useState(false);
  const [cartData, setCartData] = useState<any>([]);
  const [loading, setLoading] = useState(false);
  const [initialLoad, setInitialLoad] = useState(true);
  const [showCouponBurst, setShowCouponBurst] = useState(false);
  // 324KB of Lottie JSON — its own chunk, fetched after mount.
  const couponBurstAnimation = useLazyLottie(
    () => import("@/assets/order_place_animation/order_placed_back_animation.json"),
  );

  // Confetti only when promo_code changes to a new code (not re-validate/removal).
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

  // setCartCurrency/setCartDecimal below are for other state.Cart readers.
  const { currency, decimals } = useCurrency();

  // /cart fetched on load + channel switch only; mutations sync via redux.
  const fetchGuestCart = async () => {
    setLoading(true);
    try {
      const variantIds = cart?.guestCart?.map((p) => p.product_variant_id);
      const quantities = cart?.guestCart?.map((p) => p.qty);
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
        setCartProductsData(response.data.cart);
        dispatch(setCartSubTotal({ data: response?.data?.sub_total }));
        dispatch(
          setCartCurrency({
            data: response?.data?.currency ?? "",
            channel: activeChannel,
          }),
        );
        dispatch(setCartDecimal({ data: response?.data?.decimal_point }));
      }
      setLoading(false);
      setInitialLoad(false);
    } catch (error) {
      setLoading(false);
      setInitialLoad(false);
      console.log("Error", error);
    }
  };

  const fetchCart = async () => {
    setLoading(true);
    try {
      const res = await api.getCart({
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      if (res?.status == 1) {
        setCartProductsData(res?.data?.cart);
        dispatch(setCart({ data: res }));
        dispatch(setCartSubTotal({ data: res?.data?.sub_total }));
        dispatch(
          setCartCurrency({
            data: res?.data?.currency ?? "",
            channel: activeChannel,
          }),
        );
        dispatch(setCartDecimal({ data: res?.data?.decimal_point }));
        dispatch(setSelfPickupMode({ data: res?.data?.self_pickup_mode }));
        dispatch(
          setDoorStepDeliveryMode({
            data: res?.data?.doorstep_delivery_mode,
          }),
        );
        setCartData(res?.data);
        setLoading(false);
        setInitialLoad(false);
        const productsData = res?.data?.cart?.map((product) => {
          return {
            product_id: product?.id,
            product_variant_id: product?.variant_id,
            // Picks travel with the row — two lines of one variant differ only by these.
            addons: product?.addons ?? [],
            qty: Number(product?.variants?.[0]?.quantity ?? product?.qty ?? 0),
          };
        });
        dispatch(setCartProducts({ data: productsData }));
      } else {
        dispatch(setCartProducts({ data: [] }));
        dispatch(setCart({ data: { data: { cart: [] } } }));
        dispatch(setCartSubTotal({ data: 0 }));
        setCartProductsData([]);
        setLoading(false);
        setInitialLoad(false);
      }
    } catch (error) {
      setLoading(false);
      setInitialLoad(false);
      console.log("error", error);
    }
  };

  useEffect(() => {
    if (cart?.isGuest && cart?.guestCart?.length == 0) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setCartProductsData([]);
      setInitialLoad(false);
    } else if (!cart.isGuest) {
      fetchCart();
    } else if (cart?.guestCart?.length > 0 && cart?.isGuest) {
      fetchGuestCart();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [shopMode]);

  // Rows mirror redux server cart — every mutation dispatches setCart.
  const reduxServerCart = cart?.cart?.data?.cart;
  useEffect(() => {
    if (cart?.isGuest) return;
    if (!Array.isArray(reduxServerCart)) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setCartProductsData(reduxServerCart);
    setInitialLoad(false);
  }, [reduxServerCart, cart?.isGuest]);

  if (initialLoad) {
    return (
      <>
        <BreadCrumb />
        <CartPageSkeleton />
      </>
    );
  }

  if (!loading && cartProductsData?.length === 0) {
    return (
      <section>
        <BreadCrumb />
        <div className="container">
          <div className="flex items-center justify-center h-full my-auto mx-10">
            <div className="flex items-center justify-center flex-col gap-2 my-4">
              <ThemedSvg
                src={NoCartData}
                alt="No Cart Data"
                className="w-3/4 max-w-[280px] object-contain"
              />
              <h1 className="font-bold text-[22px] text-center py-2">
                {t("empty_cart_list_message")}
              </h1>
              <p className="font-bold text-xs text-center">
                {t("empty_cart_list_description")}
              </p>
              <button
                type="button"
                onClick={() => {
                  router.push(zoneHref("/products"));
                  dispatch(clearAllFilter());
                  setShowCouponCode(false);
                  dispatch(clearCartPromo());
                }}
                className="primaryBackColor text-white font-bold p-1 rounded-sm"
              >
                {t("empty_cart_list_button_name")}
              </button>
            </div>
          </div>
        </div>
      </section>
    );
  }

  return (
    <section>
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
      <BreadCrumb />
      <div className="container">
        {
          // No skeleton on mutations — it flashed the whole cart on every remove.
          <div className="my-12 px-2">
            <div className="flex flex-col gap-1">
              <h1 className="font-bold text-2xl">{t("myCart")}</h1>
              <p className="font-medium text-base">
                {`${t("there_are")} ${cartProductsData?.length} ${t(
                  "product_in_your_cart",
                )}`}
              </p>
            </div>
            <div className="grid grid-cols-12 gap-4 mt-6">
              <div className="col-span-12 lg:col-span-7 xl:col-span-8 flex flex-col gap-4 w-full min-w-0 self-start">
                <CartOffersCarousel
                  onOpenCoupons={() => setShowCouponCode(true)}
                />
                <div className="flex items-center justify-between gap-2 px-1">
                  <span className="text-base font-bold uppercase tracking-wide">
                    {cartProductsData?.length} {t("items")}
                  </span>
                </div>
                {/* Don't filter by cartProducts qty — mismatches mid-debounce
                    and hides the row. */}
                <div className="flex flex-col gap-3">
                  {cartProductsData?.map((product, index) => (
                    <CartProductCard
                      key={cartLineKey(product)}
                      staggerIndex={index}
                      product={product}
                      cartProductsData={cartProductsData}
                      setCartProductsData={setCartProductsData}
                      setCartData={setCartData}
                      currency={currency}
                      decimals={decimals}
                    />
                  ))}
                </div>
                {user?.jwtToken && (
                  <button
                    type="button"
                    onClick={() => router.push(zoneHref("/profile/wishlist"))}
                    className="flex items-center gap-3 cardBorder rounded-md px-4 py-4 text-start hover:bg-black/[0.02] dark:hover:bg-white/[0.03] transition"
                  >
                    <FiBookmark size={18} className="shrink-0" />
                    <span className="flex-1 text-sm font-bold textColor">
                      {t("add_more_from_wishlist") || "Add More From Wishlist"}
                    </span>
                    <FiChevronRight size={20} className="shrink-0 rtl:-scale-x-100" />
                  </button>
                )}
              </div>
              <div className="col-span-12 lg:col-span-5 xl:col-span-4">
                {loading ? (
                  <CartCouponSkeleton />
                ) : (
                  <CartCouponCard
                    setShowCouponCode={setShowCouponCode}
                    cartData={cartData}
                  />
                )}
              </div>
            </div>
          </div>
        }
      </div>
      <CouponCodeDrawer
        showCouponCode={showCouponCode}
        setShowCouponCode={setShowCouponCode}
      />
    </section>
  );
};

export default Cart;
