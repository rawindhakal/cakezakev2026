import React, { useRef, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import * as api from "@/api/apiRoutes";
import {
  addtoGuestCart,
  clearCartPromo,
  setCartDecimal,
  setCartProducts,
  setCartPromo,
  setCartSubTotal,
  setGuestCartTotal,
} from "@/redux/slices/cartSlice";
import { toast } from "react-toastify";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import { t } from "@/utils/translation";
import { FiEdit2, FiMinus, FiPlus } from "react-icons/fi";
import { BsLock } from "react-icons/bs";
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
import {
  addonSummary,
  cartLineKey,
  findCartLine,
  lineAddonPayload,
} from "@/utils/addons";
const PrescriptionUpload = PrescriptionUploadRaw as any;

interface CartDrawerProductsCardProps {
  product: any;
  /** Rich rows that guest qty updates merge onto. */
  cartProductsData?: any[];
  setCartProductsData: React.Dispatch<React.SetStateAction<any[]>>;
  setCartData?: React.Dispatch<React.SetStateAction<any>>;
  currency?: string;
  decimals?: number;
  /** Opens the drawer's own edit screen for this row's addons. */
  onEditAddons?: (line: any) => void;
}

const CartDrawerProductsCard = ({
  product,
  cartProductsData,
  setCartProductsData,
  setCartData,
  currency,
  decimals,
  onEditAddons,
}: CartDrawerProductsCardProps) => {
  const dispatch = useDispatch();
  const { guard: guardClosed, closedProps } = useStoreClosed();

  const { currency: liveCurrency, decimals: liveDecimals } = useCurrency();
  const cur = currency ?? liveCurrency;
  const dec = decimals ?? liveDecimals;
  const money = (amount: number | string = 0) => formatCurrency(amount, cur, dec);
  const cart = useSelector((state: any) => state.Cart);
  const setting = useSelector((state: any) => state.Setting.setting);
  const coupon = useSelector((state: any) => state.Cart.promo_code);
  const city = useSelector((state: any) => state.City.city);
  const [removing, setRemoving] = useState(false);
  const rowRef = useRef<HTMLDivElement>(null);

  // Same product+variant can sit in the cart twice with different picks.
  const lineKey = cartLineKey(product);
  // Food rows keep their picks behind an Edit button, not an itemised list.
  const hasAddons =
    Number(product?.is_food) === 1 && (product?.addons?.length ?? 0) > 0;

  // Guest cart is local-only — no getGuestCart per click. Redux guest rows are
  // bare, so qty updates merge onto the rendered rich rows.
  const recalculateGuestTotal = (products?: any[]) => {
    const total = (products ?? []).reduce((sum: number, item: any) => {
      const unitPrice =
        item?.discounted_price != 0 ? item?.discounted_price : item?.price;
      return sum + Number(unitPrice || 0) * Number(item?.qty || 0);
    }, 0);
    dispatch(setGuestCartTotal({ data: total }));
    dispatch(setCartSubTotal({ data: total }));
  };

  const refreshGuestCart = (guestCartItems?: any[]) => {
    dispatch(addtoGuestCart({ data: guestCartItems ?? [] }));
    // From the prop, not a setState updater (updaters must not dispatch).
    const prevRows = cartProductsData ?? [];
    const next = (guestCartItems ?? [])
      .map((guestRow: any) => {
        const priorRow = prevRows.find(
          (row: any) => cartLineKey(row) == cartLineKey(guestRow),
        );
        return { ...priorRow, ...guestRow };
      })
      // No rich row → can't render; drop.
      .filter((row: any) => row?.product_id != null);
    setCartProductsData(next);
    recalculateGuestTotal(next);
  };

  // Rebuild from the server cart, not a closure snapshot (races on rapid clicks).
  const syncFromServerCart = (response: any) => {
    const serverCart = response?.data?.cart?.map((item: any) => ({
      product_id: item?.id,
      product_variant_id: item?.variant_id,
      addons: item?.addons ?? [],
      qty: item?.variants?.[0]?.quantity ?? item?.quantity,
    }));
    dispatch(setCartProducts({ data: serverCart ?? [] }));
    dispatch(setCartSubTotal({ data: response?.data?.sub_total ?? 0 }));
    dispatch(setCartDecimal({ data: response?.data?.decimal_point }));

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
        return {
          ...priorRow,
          ...serverItem,
          product_id: serverItem?.id,
          product_variant_id: serverItem?.variant_id,
          addons: serverItem?.addons ?? [],
          qty:
            serverItem?.variants?.[0]?.quantity ??
            serverItem?.quantity ??
            priorRow?.qty,
          slab_discount_message: serverItem?.slab_discount_message ?? "",
          price: serverItem?.price ?? priorRow?.price,
          discounted_price:
            serverItem?.discounted_price ?? priorRow?.discounted_price,
          discount_percent:
            serverItem?.discount_percent ?? priorRow?.discount_percent,
          image_url: serverItem?.images?.[0]?.image_url ?? priorRow?.image_url,
        };
      });
      return next;
    });

    // Outside the updater — no dispatch during render.
    if (serverItems.length <= 0) dispatch(clearCartPromo());
  };

  const handleRemoveFromCart = async (units: number, ctx?: FlushCtx) => {
    try {
      const response = await api.removeFromCart({
        product_id: product?.product_id,
        product_variant_id: product?.product_variant_id,
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
        setRemoving(false);
      }
    } catch (error) {
      console.log("error", error);
      setRemoving(false);
    }
  };

  // Blocks repeat X clicks in flight (they raced into a false "Cart Is Empty").
  const removingRef = useRef(false);

  const handleRemoveWholeLine = async (): Promise<boolean> => {
    if (removingRef.current) return false;
    removingRef.current = true;
    try {
      // Flag AND full qty — some backends ignore the flag.
      const lineQty = serverAddedQty ?? product?.qty;
      const response = await api.removeFromCart({
        product_id: product?.product_id,
        product_variant_id: product?.product_variant_id,
        qty: lineQty,
        isRemoveAll: true,
        addons: lineAddonPayload(product),
      });
      const alreadyGone =
        response?.status != 1 &&
        /not found|no item/i.test(response?.message || "");
      if (response?.status == 1 || alreadyGone) {
        syncFromServerCart(response);
        if (response?.status == 1) {
          await handleApplyCoupon(response?.data?.sub_total);
        }
        return true;
      }
      toast.error(response.message);
      return false;
    } catch (error) {
      console.log("error", error);
      return false;
    } finally {
      removingRef.current = false;
    }
  };

  const handleGuestCartRemove = async () => {
    const remainItems = cart?.guestCart?.filter(
      (cartProduct: any) => cartLineKey(cartProduct) !== lineKey,
    );
    await refreshGuestCart(remainItems);
  };

  // Pin the row's height so the collapse starts from its real size.
  const startRowExit = () => {
    rowRef.current?.style.setProperty(
      "--cart-row-h",
      `${rowRef.current.offsetHeight}px`,
    );
    setRemoving(true);
  };

  // X removes the whole line. Slide + collapse first so the row reads as leaving.
  const handleRemoveItem = async () => {
    if (removing) return;
    const reduced =
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (!reduced) {
      startRowExit();
      await new Promise((r) => setTimeout(r, 450));
    }
    if (cart.isGuest) {
      await handleGuestCartRemove();
    } else if (!(await handleRemoveWholeLine())) {
      setRemoving(false);
    }
  };

  const getProductQuantities = (products?: any[]) => {
    return Object.entries(
      products?.reduce((quantities: Record<string, number>, item: any) => {
        const existingQty = quantities[item.product_id] || 0;
        return { ...quantities, [item.product_id]: existingQty + item.qty };
      }, {}) as Record<string, number>,
    ).map(([productId, qty]) => ({
      product_id: Number.parseInt(productId, 10),
      qty,
    }));
  };

  const serverCommitQty = async (qty: number, ctx?: FlushCtx) => {
    try {
      const response = await api.addToCart({
        product_id: product?.product_id,
        product_variant_id: product?.product_variant_id,
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

  const handleGuestIncrease = async () => {
    const productQuantity = getProductQuantities(cart?.guestCart);
    const productQty = productQuantity?.find(
      (prdct: any) => prdct?.product_id == product?.product_id,
    )?.qty;
    if (
      product?.is_unlimited_stock === 0 &&
      Number(productQty) >= Number(product?.stock)
    ) {
      toast.error(t("out_of_stock_message"));
      return;
    }
    if (hasReachedAllowedQty(productQty, product?.total_allowed_quantity)) {
      toast.error(t("max_cart_limit_error"), { toastId: "max_cart_limit_error" });
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
      toast.error(t("max_cart_limit_error"), { toastId: "max_cart_limit_error" });
      return;
    }
    const updatedProducts = cart?.guestCart?.map((cartProduct: any) => {
      if (cartLineKey(cartProduct) == lineKey) {
        return { ...cartProduct, qty: Number(cartProduct?.qty + 1) };
      }
      return cartProduct;
    });
    await refreshGuestCart(updatedProducts);
  };

  const handleQuantityIncrease = async () => {
    try {
      if (cart.isGuest) {
        await handleGuestIncrease();
      } else {
        serverIncrement();
      }
    } catch (error) {
      console.log("Error", error);
    }
  };

  // Re-validate coupon against the new total.
  const handleApplyCoupon = async (total: number) => {
    try {
      const response = await api.setPromoCode({
        promoCodeName: coupon?.promo_code,
        amount: total,
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

  const handleRemoveCoupon = async () => {
    dispatch(clearCartPromo());
  };

  const handleGuestDecrease = async () => {
    const variantQty = cart?.guestCart?.find(
      (prdct: any) => cartLineKey(prdct) == lineKey,
    )?.qty;
    if (variantQty <= 1) {
      await handleRemoveItem();
      return;
    }
    const updatedProducts = cart?.guestCart?.map((cartProduct: any) => {
      if (cartLineKey(cartProduct) == lineKey) {
        return { ...cartProduct, qty: Number(cartProduct?.qty - 1) };
      }
      return cartProduct;
    });
    await refreshGuestCart(updatedProducts);
  };

  const handleQuantityDecrease = async () => {
    try {
      if (cart.isGuest) {
        await handleGuestDecrease();
      } else {
        // Last unit: exit now, the debounced remove drops the row after.
        if (serverDisplayQty <= 1) startRowExit();
        serverDecrement();
      }
    } catch (error) {
      console.log("error", error);
    }
  };

  const serverAddedQty = findCartLine(cart?.cartProducts, product)?.qty;
  const guestAddedQty = findCartLine(cart?.guestCart, product)?.qty;

  // MIN(store-wide capacity left, per-product cap, stock).
  const maxQty = getMaxAddableQuantity({
    maxCartItemsCount: setting?.max_cart_items_count,
    otherLinesQty: getCartTotalQuantity(cart?.cartProducts) - (serverAddedQty || 0),
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

  const guestMaxQty = getMaxAddableQuantity({
    maxCartItemsCount: setting?.max_cart_items_count,
    otherLinesQty: getCartTotalQuantity(cart?.guestCart) - (guestAddedQty || 0),
    totalAllowedQty: product?.total_allowed_quantity,
    isUnlimitedStock: product?.is_unlimited_stock != 0,
    stock: product?.stock,
  });

  // Disable + at the cap, even before the debounced commit lands.
  const atMaxQty =
    Number(addedQuantity) >= (cart?.isGuest ? guestMaxQty : maxQty);

  const hasDiscount =
    product?.discounted_price != 0 &&
    product?.discounted_price !== product?.price;
  const discountPercent = product?.discount_percent;

  const renderVariantInfo = () => {
    if (
      Array.isArray(product?.variant_attributes) &&
      product.variant_attributes.length > 0
    ) {
      return (
        <div className="flex flex-wrap gap-1">
          {product.variant_attributes.map((attr, i) => (
            <span
              key={`${attr?.name}-${i}`}
              className="inline-flex items-center gap-1 rounded-md bg-gray-100 dark:bg-zinc-800 px-1.5 py-0.5 text-[10px] text-gray-600 dark:text-zinc-300"
            >
              <span className="font-medium opacity-60">{attr?.name}:</span>
              <span className="font-semibold capitalize">{attr?.value}</span>
            </span>
          ))}
        </div>
      );
    }
    if (product?.attributes_text) {
      return (
        <p className="truncate text-xs opacity-60">{product?.attributes_text}</p>
      );
    }
    return null;
  };

  return (
    <div
      ref={rowRef}
      className={`group flex gap-3 overflow-hidden rounded-lg border bg-white dark:bg-zinc-900 p-2.5 transition hover:shadow-md ${
        removing
          ? "cartAnimRowOut pointer-events-none"
          : "motion-safe:animate-rowIn"
      }`}
      style={{
        borderColor:
          "color-mix(in srgb, var(--primary-color) 16%, transparent)",
      }}
    >
      <div className="relative h-[84px] w-[84px] shrink-0 overflow-hidden rounded-lg bg-gray-50 dark:bg-zinc-800">
        {/* Cast: ImageWithPlaceholder doesn't type `fill`. */}
        <ImageWithPlaceholder
          {...({
            src: product?.image_url,
            alt: product?.name ?? "Image",
            fill: true,
            sizes: "96px",
            className: "h-full w-full object-contain p-1.5",
          } as any)}
        />
        {hasDiscount && discountPercent ? (
          <span className="absolute left-0 top-0 primaryBackColor rounded-br-lg px-1.5 py-0.5 text-[10px] font-bold text-white shadow-sm">
            {discountPercent}% {t("off")}
          </span>
        ) : null}
      </div>

      <div className="flex min-w-0 flex-1 flex-col">
        <h2 className="line-clamp-2 text-sm font-semibold leading-snug capitalize">
          <ProductTypeTag
            type={product?.product_type ?? product?.indicator}
            className="me-1.5 align-[-2px]"
            iconSize={15}
          />
          {product?.name ?? product?.product?.translations?.name}
        </h2>

        <div className="mt-1 flex flex-wrap items-center gap-1">
          {renderVariantInfo()}
          {hasAddons && (
            <button
              type="button"
              onClick={() => onEditAddons?.(product)}
              className="inline-flex items-center gap-1 rounded-md primaryLightBack px-1.5 py-0.5 text-[10px] font-semibold primaryColor transition active:scale-95"
            >
              <FiEdit2 size={10} className="shrink-0" />
              {t("edit")}
            </button>
          )}
        </div>

        {hasAddons ? (
          <p className="mt-1.5 line-clamp-2 text-xs SecondaryTextColor">
            {addonSummary(product)}
          </p>
        ) : (
          <CartLineAddons
            addons={product?.addons}
            addonTotal={product?.addon_total}
            hasUnavailable={product?.has_unavailable_addons}
            money={money}
          />
        )}

        {hasAddons && Number(product?.has_unavailable_addons) === 1 && (
          <p className="mt-1 text-[11px] font-medium text-[#ff5a5a]">
            {t("addon_unavailable_warning")}
          </p>
        )}

        {product?.slab_discount_message ? (
          <p className="mt-1.5 inline-flex w-fit items-center gap-1.5 rounded-md border border-green-200 dark:border-green-800 bg-green-50 dark:bg-green-900/15 px-2 py-1 text-[11px] font-semibold text-green-700 dark:text-green-400">
            <BsLock size={12} className="shrink-0" />
            {product.slab_discount_message}
          </p>
        ) : null}

        {(() => {
          const isMedical = Number(product?.product_type) === 5;
          const Stepper = (
            <button
              type="button"
              {...closedProps}
              aria-label="Remove from cart"
              className={`flex h-8 w-fit items-center gap-1.5 rounded-lg border primaryBorderColor px-3 text-xs font-semibold primaryColor transition-colors hover:primaryLightBack ${closedProps.className ?? ""}`}
              onClick={() => handleRemoveItem()}
            >
              <FiMinus size={14} /> Remove
            </button>
          );
          const Price = (
            <div className="flex h-8 items-center gap-1.5">
              <span className="text-[15px] font-extrabold">
                {money(
                  hasDiscount ? product?.discounted_price : product?.price,
                )}
              </span>
              {hasDiscount ? (
                <span className="text-xs line-through opacity-50">
                  {money(product?.price)}
                </span>
              ) : null}
            </div>
          );

          // Medical: stacked on mobile so the upload button isn't squeezed.
          if (isMedical) {
            const Prescription = (
              <PrescriptionUpload
                variantId={product?.product_variant_id}
                isRequired={product?.is_prescription_required}
                inline
              />
            );
            return (
              <>
                <div className="mt-auto flex flex-col gap-1.5 pt-2 sm:hidden">
                  {Stepper}
                  {Price}
                  {Prescription}
                </div>
                <div className="mt-auto hidden items-center justify-between gap-3 pt-2 sm:flex">
                  <div className="flex min-w-0 flex-col gap-1">
                    {Price}
                    {Prescription}
                  </div>
                  <div className="shrink-0">{Stepper}</div>
                </div>
              </>
            );
          }

          return (
            <div className="mt-auto flex flex-col gap-1.5 pt-2 sm:flex-row-reverse sm:items-center sm:justify-between sm:gap-2">
              {Stepper}
              <div className="sm:text-right">{Price}</div>
            </div>
          );
        })()}
      </div>

    </div>
  );
};

export default CartDrawerProductsCard;
