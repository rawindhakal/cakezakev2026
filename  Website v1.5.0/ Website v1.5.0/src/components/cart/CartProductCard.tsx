import React, { useEffect, useRef, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import * as api from "@/api/apiRoutes";
import {
  addtoGuestCart,
  clearCartPromo,
  setCart,
  setCartProducts,
  setCartPromo,
  setCartSubTotal,
  setGuestCartTotal,
} from "@/redux/slices/cartSlice";
import { toast } from "react-toastify";
import { RiCloseLine } from "react-icons/ri";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { syncFavoriteId } from "@/redux/slices/FavoriteSlice";
import { FaMinus, FaPlus } from "react-icons/fa";
import { BsLock } from "react-icons/bs";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import { t } from "@/utils/translation";
import AnimatedNumber from "@/components/ui/AnimatedNumber";
import {
  formatCurrency,
  hasReachedAllowedQty,
  getCartTotalQuantity,
  getMaxAddableQuantity,
} from "@/utils/helperFunction";
import { useDebouncedQuantity, FlushCtx } from "@/hooks/useDebouncedQuantity";
import useStoreClosed from "@/hooks/useStoreClosed";
import useCurrency from "@/hooks/useCurrency";
// Untyped JS — TS misinfers its props from JSDoc.
import PrescriptionUploadRaw from "@/components/prescription/PrescriptionUpload";
import CartLineAddons from "./CartLineAddons";
import ProductTypeTag from "../productdetail/ProductTypeTag";
import { cartLineKey, findCartLine, lineAddonPayload } from "@/utils/addons";
const PrescriptionUpload = PrescriptionUploadRaw as any;

interface StepperProps {
  closedProps: Record<string, any>;
  addedQuantity: number;
  onDecrease: () => void;
  onIncrease: () => void;
  pending: boolean;
  atMax: boolean;
}

const Stepper = ({
  closedProps,
  addedQuantity,
  onDecrease,
  onIncrease,
  pending,
  atMax,
}: StepperProps) => (
  <div
    {...closedProps}
    className={`flex items-center h-7 rounded bg-black/[0.05] dark:bg-white/[0.08] overflow-hidden ${closedProps.className ?? ""}`}
  >
    <button
      type="button"
      className="w-7 h-7 flex items-center justify-center textColor hover:opacity-70 disabled:opacity-30 transition"
      onClick={onDecrease}
      disabled={addedQuantity <= 1}
      aria-label={t("decrease")}
    >
      <FaMinus size={9} />
    </button>
    <span className="text-xs font-semibold w-6 text-center overflow-hidden">
      <span
        key={addedQuantity}
        className={`inline-block motion-safe:animate-qtyPop ${
          pending ? "opacity-50 animate-pulse" : ""
        }`}
      >
        {addedQuantity}
      </span>
    </span>
    <button
      type="button"
      className="w-7 h-7 flex items-center justify-center textColor hover:opacity-70 disabled:opacity-30 disabled:cursor-not-allowed transition"
      onClick={onIncrease}
      disabled={atMax}
      aria-disabled={atMax}
      aria-label={t("increase")}
    >
      <FaPlus size={9} />
    </button>
  </div>
);

interface CartProductCardProps {
  product: any;
  /** Position in the list — staggers the fade-in after a skeleton load. */
  staggerIndex?: number;
  cartProductsData: any[];
  setCartProductsData: React.Dispatch<React.SetStateAction<any[]>>;
  setCartData?: React.Dispatch<React.SetStateAction<any>>;
  currency?: string;
  decimals?: number;
}

const CartProductCard = ({
  product,
  staggerIndex = 0,
  cartProductsData,
  setCartProductsData,
  setCartData,
  currency,
  decimals,
}: CartProductCardProps) => {
  const dispatch = useDispatch();
  const { guard: guardClosed, closedProps } = useStoreClosed();
  const cart = useSelector((state: any) => state.Cart);
  const setting = useSelector((state: any) => state.Setting.setting);

  const { currency: liveCurrency, decimals: liveDecimals } = useCurrency();
  const cur = currency || liveCurrency;
  const dec = decimals ?? liveDecimals;
  const money = (amount: number | string = 0) =>
    formatCurrency(amount, cur, dec);

  const coupon = useSelector((state: any) => state.Cart.promo_code);
  const city = useSelector((state: any) => state.City.city);
  const user = useSelector((state: any) => state.User);
  const [totalPrice, setTotalPrice] = useState<number | undefined>();
  const [showRemoveModal, setShowRemoveModal] = useState(false);
  const [removing, setRemoving] = useState(false);
  const rowRef = useRef<HTMLDivElement>(null);
  const [movingToWishlist, setMovingToWishlist] = useState(false);

  // New API keys, falling back to old ones.
  const productId = product?.id ?? product?.["product_id"];
  const variantId = product?.variant_id ?? product?.["product_variant_id"];
  const productName = product?.name ?? product?.product?.translations?.name;
  const productImage =
    product?.images?.[0]?.image_url ??
    product?.variants?.[0]?.image ??
    product?.image_url;
  // Same product+variant can sit in the cart twice with different picks.
  const lineKey = cartLineKey(product);
  const variantText =
    product?.variants?.[0]?.attributes_text ??
    `${product?.measurement || ""} ${product?.unit?.translations?.short_code || ""}`.trim();

  const getProductQuantities = (products?: any[]) => {
    return Object.entries(
      products?.reduce((quantities: Record<string, number>, item: any) => {
        const key = item.product_variant_id ?? item.product_id;
        const existingQty = quantities[key] || 0;
        return {
          ...quantities,
          [key]: existingQty + item.qty,
        };
      }, {}) as Record<string, number>,
    ).map(([variantKey, qty]) => ({
      product_variant_id: Number.parseInt(variantKey, 10),
      qty,
    }));
  };

  useEffect(() => {
    const rows = cart?.isGuest ? cart?.guestCart : cart?.cartProducts;
    const productQty = findCartLine(rows, product)?.qty;
    const finalPrice =
      product?.discounted_price == 0
        ? product?.price
        : product?.discounted_price;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setTotalPrice(finalPrice * Number(productQty));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cart]);

  // Rebuild from the server cart (source of truth). sub_total is under
  // response.data, not response.
  const syncFromServerCart = (response: any) => {
    const serverCart = response?.data?.cart?.map((item: any) => ({
      product_id: item?.id,
      product_variant_id: item?.variant_id,
      addons: item?.addons ?? [],
      qty: item?.variants?.[0]?.quantity ?? item?.quantity,
    }));
    dispatch(setCartProducts({ data: serverCart ?? [] }));
    dispatch(setCartSubTotal({ data: response?.data?.sub_total ?? 0 }));
    // Full cart in redux — the cart page renders from it, no getCart per action.
    dispatch(setCart({ data: response }));
    if (typeof setCartData === "function" && response?.data) {
      setCartData((prev: any) => ({ ...prev, ...response.data }));
    }
    // Iterate the server array (not prev) so added/dropped rows and
    // qty-dependent fields (slab message, prices) stay fresh.
    const serverItems = response?.data?.cart ?? [];
    setCartProductsData((prev) => {
      const prevRows = prev ?? [];
      const next = serverItems.map((serverItem: any) => {
        const priorRow = prevRows.find(
          (row: any) => cartLineKey(row) == cartLineKey(serverItem),
        );
        return { ...priorRow, ...serverItem };
      });
      return next;
    });
  };

  // Clear promo when the cart empties (kept out of the pure updater above).
  useEffect(() => {
    if ((cartProductsData?.length ?? 0) <= 0) {
      dispatch(clearCartPromo());
    }
  }, [cartProductsData?.length, dispatch]);

  const handleRemoveFromCart = async (units: number, ctx?: FlushCtx) => {
    try {
      const response = await api.removeFromCart({
        product_id: productId,
        product_variant_id: variantId,
        qty: units,
        // Picks out this line when the product sits in the cart twice.
        addons: lineAddonPayload(product),
      });
      if (ctx?.isStale?.()) return;
      // "not found" = already gone server-side — still drop the row.
      const alreadyGone =
        response?.status != 1 &&
        /not found|no item/i.test(response?.message || "");
      if (response?.status == 1 || alreadyGone) {
        syncFromServerCart(response);
        if (response?.status == 1) {
          await handleApplyCoupon(response?.data?.sub_total);
        }
      } else {
        toast.error(response.message);
      }
    } catch (error) {
      console.log("error", error);
    }
  };

  const handleCalculateTotal = (products?: any[]) => {
    const total = products?.reduce((prev: number, curr: any) => {
      prev += curr?.productPrice * curr.qty;
      return prev;
    }, 0);
    dispatch(setCartSubTotal({ data: total }));
    dispatch(setGuestCartTotal({ data: total }));
  };

  const handleGuestCartRemove = () => {
    const remainItems = cart?.guestCart?.filter(
      (cartProduct: any) => cartLineKey(cartProduct) !== lineKey,
    );
    const updatedProducts = cartProductsData?.filter(
      (cartProduct: any) => cartLineKey(cartProduct) !== lineKey,
    );
    setCartProductsData(updatedProducts);
    dispatch(addtoGuestCart({ data: remainItems }));
    handleCalculateTotal(remainItems);
  };

  // Drop the row locally first, then call the API. Don't touch redux here — an
  // early refetch would return the item and make the row blink back.
  const handleServerRemoveOptimistic = async () => {
    setCartProductsData((prev) =>
      (prev ?? []).filter((row: any) => cartLineKey(row) != lineKey),
    );
    const lineQty = serverAddedQty ?? product?.qty ?? 1;
    await handleRemoveFromCart(lineQty);
  };

  // Collapse the row first, then drop it — removing it outright made items pop
  // out with no sense of where they went.
  const handleRemoveItem = async () => {
    if (removing) return;
    const reduced =
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (!reduced) {
      // Pin the row's height so the collapse starts from its real size.
      rowRef.current?.style.setProperty(
        "--cart-row-h",
        `${rowRef.current.offsetHeight}px`,
      );
      setRemoving(true);
      await new Promise((r) => setTimeout(r, 450));
    }
    if (cart.isGuest) {
      handleGuestCartRemove();
    } else {
      await handleServerRemoveOptimistic();
    }
  };

  // Wishlist first, then drop from cart — so a failed add never loses the item.
  const handleMoveToWishlist = async () => {
    if (!user?.jwtToken) {
      toast.error(t("required_login_message_for_wishlist"), {
        toastId: "required_login_message_for_wishlist",
      });
      return;
    }
    setMovingToWishlist(true);
    try {
      const response = await api.addToFavorite({ product_id: productId });
      const alreadyThere =
        response?.status != 1 && /already/i.test(response?.message || "");
      if (response?.status == 1 || alreadyThere) {
        dispatch(syncFavoriteId({ id: productId, liked: true }));
        setShowRemoveModal(false);
        toast.success(response?.message || t("move_to_wishlist"));
        await handleRemoveItem();
      } else {
        toast.error(response?.message);
      }
    } catch (error) {
      console.log("Error", error);
      toast.error(t("something_went_wrong"));
    } finally {
      setMovingToWishlist(false);
    }
  };

  const serverCommitQty = async (qty: number, ctx?: FlushCtx) => {
    try {
      const response = await api.addToCart({
        product_id: productId,
        product_variant_id: variantId,
        qty: Number(qty),
        latitude: city?.latitude,
        longitude: city?.longitude,
        addons: lineAddonPayload(product),
      });
      if (ctx?.isStale?.()) return;
      if (response.status == 1) {
        syncFromServerCart(response);
        await handleApplyCoupon(
          response?.data?.sub_total ?? response.sub_total,
        );
      } else {
        toast.error(response.message);
      }
    } catch (error) {
      console.log("Error", error);
    }
  };

  const handleGuestIncrease = () => {
    const productQuantity = getProductQuantities(cart?.guestCart);
    const productQty = productQuantity?.find(
      (prdct: any) => prdct?.product_variant_id == variantId,
    )?.qty;
    if (
      product?.is_unlimited_stock === 0 &&
      Number(productQty) >= Number(product?.stock)
    ) {
      toast.error(t("out_of_stock_message"));
      return;
    }
    if (hasReachedAllowedQty(productQty, product?.total_allowed_quantity)) {
      toast.error(t("max_cart_limit_error"), {
        toastId: "max_cart_limit_error",
      });
      return;
    }
    const maxAddable = getMaxAddableQuantity({
      maxCartItemsCount: setting?.max_cart_items_count,
      otherLinesQty: getCartTotalQuantity(cart?.guestCart) - (productQty || 0),
      totalAllowedQty: product?.total_allowed_quantity,
      isUnlimitedStock: product?.is_unlimited_stock != 0,
      stock: product?.stock,
    });
    if (Number(productQty) >= maxAddable) {
      toast.error(t("max_cart_limit_error"), {
        toastId: "max_cart_limit_error",
      });
      return;
    }
    const updatedProducts = cart?.guestCart?.map((cartProduct: any) => {
      if (cartLineKey(cartProduct) == lineKey) {
        return { ...cartProduct, qty: Number(cartProduct?.qty + 1) };
      }
      return cartProduct;
    });
    handleCalculateTotal(updatedProducts);
    dispatch(addtoGuestCart({ data: updatedProducts }));
  };

  const handleQuantityIncrease = async () => {
    try {
      if (cart.isGuest) {
        handleGuestIncrease();
      } else {
        serverIncrement();
      }
    } catch (error) {
      console.log("Error", error);
    }
  };

  // Re-validate coupon against the new total.
  const handleApplyCoupon = async (total: number) => {
    if (!coupon?.promo_code) return;
    try {
      const response = await api.setPromoCode({
        promoCodeName: coupon?.promo_code,
        amount: total,
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      if (response.status == 1) {
        dispatch(setCartPromo({ data: response.data }));
      } else {
        await handleRemoveCoupon();
      }
    } catch (error) {
      console.log("Error", error);
    }
  };

  const handleGuestDecrease = () => {
    const variantQty = cart?.guestCart?.find(
      (prdct: any) => cartLineKey(prdct) == lineKey,
    )?.qty;
    if (variantQty <= 1) {
      // Stepper stops at 1; trash removes the last unit.
      return;
    }
    const updatedProducts = cart?.guestCart?.map((cartProduct: any) => {
      if (cartLineKey(cartProduct) == lineKey) {
        return { ...cartProduct, qty: Number(cartProduct?.qty - 1) };
      }
      return cartProduct;
    });
    handleCalculateTotal(updatedProducts);
    dispatch(addtoGuestCart({ data: updatedProducts }));
  };

  const handleQuantityDecrease = async () => {
    try {
      if (cart.isGuest) {
        handleGuestDecrease();
      } else {
        serverDecrement();
      }
    } catch (error) {
      console.log("error", error);
    }
  };

  const handleRemoveCoupon = async () => {
    dispatch(clearCartPromo());
  };

  const serverAddedQty = findCartLine(cart?.cartProducts, product)?.qty;
  const guestAddedQty = findCartLine(cart?.guestCart, product)?.qty;

  // MIN(store-wide capacity left, per-product cap, stock).
  const maxQty = getMaxAddableQuantity({
    maxCartItemsCount: setting?.max_cart_items_count,
    otherLinesQty:
      getCartTotalQuantity(cart?.cartProducts) - (serverAddedQty || 0),
    totalAllowedQty: product?.total_allowed_quantity,
    isUnlimitedStock: product?.is_unlimited_stock != 0,
    stock: product?.stock,
  });

  const guestMaxQty = getMaxAddableQuantity({
    maxCartItemsCount: setting?.max_cart_items_count,
    otherLinesQty: getCartTotalQuantity(cart?.guestCart) - (guestAddedQty || 0),
    totalAllowedQty: product?.total_allowed_quantity,
    isUnlimitedStock: product?.is_unlimited_stock != 0,
    stock: product?.stock,
  });

  // Server cart: optimistic stepper, one commit after clicks settle.
  const {
    displayQty: serverDisplayQty,
    increment: serverIncrement,
    decrement: serverDecrement,
    pending: serverPending,
  } = useDebouncedQuantity({
    serverQty: serverAddedQty || 0,
    onCommit: (qty, ctx) => serverCommitQty(qty, ctx),
    onRemove: (units, ctx) => handleRemoveFromCart(units, ctx),
    max: Number.isFinite(maxQty) ? maxQty : undefined,
    onMax: () =>
      toast.error(t("max_cart_limit_error"), {
        toastId: "max_cart_limit_error",
      }),
  });

  const addedQuantity = !cart.isGuest ? serverDisplayQty : guestAddedQty;
  const hasDiscount =
    product?.discounted_price != 0 &&
    product?.discounted_price < product?.price;
  const unitPrice = hasDiscount ? product?.discounted_price : product?.price;

  const lineQty = Number(addedQuantity) || 1;
  const offPct =
    hasDiscount && Number(product?.price) > 0
      ? Math.round(
          ((Number(product?.price) - Number(unitPrice)) /
            Number(product?.price)) *
            100,
        )
      : 0;
  const brandName = product?.brand_name ?? product?.brand?.name;
  const branchName = product?.branch?.branch_name ?? product?.branch_name;

  return (
    <div
      ref={rowRef}
      style={{
        animationDelay: removing
          ? undefined
          : `${Math.min(staggerIndex * 45, 360)}ms`,
      }}
      className={`relative flex items-start gap-3 p-2.5 cardBorder rounded-md w-full min-w-0 overflow-hidden bg-white dark:bg-transparent ${
        removing
          ? "cartAnimRowOut pointer-events-none"
          : "motion-safe:animate-contentIn"
      }`}
    >
      <div className="relative w-20 h-24 sm:w-24 sm:h-28 rounded overflow-hidden shrink-0 bg-white">
        <ImageWithPlaceholder
          src={productImage}
          alt={productName}
          width={224}
          height={288}
          className="w-full h-full object-contain"
        />
      </div>

      {/* Mobile: details → price → slab, stacked. sm+: price moves to its own
          right column so wide cards don't leave the right side empty. */}
      <div className="grid grid-cols-1 sm:grid-cols-[minmax(0,1fr)_auto] gap-x-6 gap-y-1 min-w-0 flex-1 self-stretch pe-7">
        <div className="flex flex-col min-w-0 gap-0.5">
          {brandName && (
            <p className="text-sm font-bold textColor truncate">{brandName}</p>
          )}
          <h3
            className={`text-sm leading-snug line-clamp-1 ${
              brandName ? "textColor" : "font-bold textColor"
            }`}
          >
            <ProductTypeTag
              type={product?.product_type ?? product?.indicator}
              className="me-1.5 align-[-2px]"
              iconSize={15}
            />
            {productName}
          </h3>
          {branchName && (
            <p className="text-xs SecondaryTextColor truncate">
              {t("sold_by") || "Sold by"}: {branchName}
            </p>
          )}

          {/* Uploaded prescription link wraps to its own line (basis-full). */}
          <div className="flex flex-wrap items-center gap-1.5 mt-1">
            {variantText && (
              <span className="inline-flex items-center rounded bg-black/[0.05] dark:bg-white/[0.08] px-2 py-1 min-h-7 text-xs font-semibold textColor max-w-full whitespace-normal break-words">
                {variantText}
              </span>
            )}
            <button
              type="button"
              {...closedProps}
              aria-label="Remove from cart"
              onClick={() => handleRemoveItem()}
              className={`inline-flex h-8 items-center rounded-lg border primaryBorderColor px-3 text-xs font-semibold primaryColor hover:primaryLightBack ${closedProps.className ?? ""}`}
            >
              Remove
            </button>
            {/* product_type 5 = medical */}
            {Number(product?.product_type) === 5 && (
              <PrescriptionUpload
                variantId={variantId}
                isRequired={product?.is_prescription_required}
                inline
              />
            )}
          </div>
        </div>

        <div className="flex items-center gap-2 flex-wrap mt-0.5 sm:mt-0 sm:col-start-2 sm:row-start-1 sm:row-span-2 sm:self-center sm:flex-col sm:items-end sm:gap-0.5 sm:text-end">
          <span className="text-sm sm:text-base font-bold textColor">
            <AnimatedNumber value={totalPrice ?? 0} format={money} />
          </span>
          {hasDiscount && (
            <span className="flex items-center gap-2 whitespace-nowrap">
              <span className="text-sm SecondaryTextColor line-through">
                {money(Number(product?.price) * lineQty)}
              </span>
              {offPct > 0 && (
                <span className="text-sm font-medium text-[#ff5a5a]">
                  {offPct}% {t("off") || "OFF"}
                </span>
              )}
            </span>
          )}
        </div>

        <CartLineAddons
          addons={product?.addons}
          addonTotal={product?.addon_total}
          hasUnavailable={product?.has_unavailable_addons}
          money={money}
          className="sm:col-start-1 max-w-md"
        />

        {product?.slab_discount_message && (
          <p className="sm:col-start-1 inline-flex w-fit items-center gap-1.5 rounded-md border border-green-200 dark:border-green-800 bg-green-50 dark:bg-green-900/15 px-2 py-1 text-[11px] font-semibold text-green-700 dark:text-green-400">
            <BsLock size={12} className="shrink-0" />
            {product.slab_discount_message}
          </p>
        )}
      </div>

      <button
        type="button"
        className="absolute top-2 end-2 p-1 textColor hover:opacity-70 transition"
        onClick={() => setShowRemoveModal(true)}
        aria-label={t("delete")}
      >
        <RiCloseLine size={22} />
      </button>

      <Dialog open={showRemoveModal} onOpenChange={setShowRemoveModal}>
        <DialogContent
          className="w-[calc(100%-32px)] sm:max-w-[360px] p-4 md:p-4 gap-0 rounded-md bg-white dark:bg-zinc-950"
          title={t("move_from_bag") || "Move from Bag"}
        >
          <div className="flex gap-3 pb-4 border-b">
            <div className="w-12 h-16 shrink-0 rounded overflow-hidden bg-white">
              <ImageWithPlaceholder
                src={productImage}
                alt={productName}
                width={96}
                height={128}
                className="w-full h-full object-contain"
              />
            </div>
            <div className="min-w-0 flex-1 pe-6">
              <p className="text-sm font-bold textColor">
                {t("move_from_bag") || "Move from Bag"}
              </p>
              <p className="text-sm SecondaryTextColor mt-0.5">
                {t("move_from_bag_message") ||
                  "Are you sure you want to move this item from bag?"}
              </p>
            </div>
            <button
              type="button"
              onClick={() => setShowRemoveModal(false)}
              aria-label={t("close") || "Close"}
              className="absolute top-3 end-3 p-1 textColor hover:opacity-70"
            >
              <RiCloseLine size={22} />
            </button>
          </div>
          <div className="flex items-center pt-3">
            <button
              type="button"
              onClick={() => {
                setShowRemoveModal(false);
                handleRemoveItem();
              }}
              className="flex-1 py-1.5 text-xs font-bold uppercase tracking-wide SecondaryTextColor hover:textColor transition"
            >
              {t("remove") || "Remove"}
            </button>
            <span className="h-6 w-px bg-gray-200 dark:bg-zinc-700" />
            <button
              type="button"
              onClick={handleMoveToWishlist}
              disabled={movingToWishlist}
              className="flex-1 py-1.5 text-xs font-bold uppercase tracking-wide primaryColor transition disabled:opacity-50"
            >
              {t("move_to_wishlist") || "Move to Wishlist"}
            </button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default CartProductCard;
