import { useEffect, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { toast } from "react-toastify";
import * as api from "@/api/apiRoutes";
import { t } from "@/utils/translation";
import {
  addGuestCartTotal,
  addtoGuestCart,
  setCart,
  setCartProducts,
  setCartSubTotal,
  subGuestCartTotal,
} from "@/redux/slices/cartSlice";
import {
  getCartTotalQuantity,
  getMaxAddableQuantity,
  hasReachedAllowedQty,
  isVariantInStock,
  isVariantOutOfStock,
  isVariantUnlimitedStock,
  variantStock,
} from "@/utils/helperFunction";
import {
  cardHasAddons,
  lineAddonPayload,
  productCartLines,
  productCartQty,
} from "@/utils/addons";
import { useDebouncedQuantity } from "@/hooks/useDebouncedQuantity";
import type { FlushCtx } from "@/hooks/useDebouncedQuantity";
import useIsHydrated from "@/hooks/useIsHydrated";
import useCurrency from "@/hooks/useCurrency";
import {
  toGaItem,
  trackAddToCart,
  trackRemoveFromCart,
} from "@/utils/analytics";

interface UseCartLineOptions {
  /** Seed for the variant picked before the cart-sync effect runs. */
  initialVariant?: any;
  /**
   * Block a guest add when the variant's status is 0. HomeVerticleProductCard
   * never had this check; the other three cards do.
   */
  guardDisabledVariantOnGuestAdd?: boolean;
  /**
   * Rethrow from removeFromCart's catch so the optimistic quantity reverts.
   * HomeVerticleProductCard swallowed it; the other three rethrow.
   */
  rethrowRemoveError?: boolean;
  /**
   * Read stock through variantStock()/isVariantUnlimitedStock() rather than the
   * raw variant fields. Differs only for a limited-stock variant with no stock
   * field: the helper reports unknown (Infinity), the raw read reports 0.
   */
  useStockHelpers?: boolean;
}

// Cart line state for one product card: variant selection, guest/server
// quantity, limit validation and the add/increase/decrease handlers. Extracted
// verbatim from the four product cards; the options above capture the only
// points where their copies had drifted apart.
const useCartLine = (product: any, options: UseCartLineOptions = {}) => {
  const {
    initialVariant,
    guardDisabledVariantOnGuestAdd = true,
    rethrowRemoveError = true,
    useStockHelpers = false,
  } = options;

  const dispatch = useDispatch();
  const cart = useSelector((state: any) => state.Cart);
  const setting = useSelector((state: any) => state.Setting.setting);
  const city = useSelector((state: any) => state.City.city);
  const hydrated = useIsHydrated();
  const { currencyCode } = useCurrency();

  const [selectedVariant, setSelectedVariant] = useState<any>(initialVariant);
  // A food product with addon groups must answer them before it can be added,
  // so the card opens the addon sheet instead of adding straight to the cart.
  const hasAddons = cardHasAddons(product);
  const [showAddons, setShowAddons] = useState(false);
  // "+" on a customisable dish asks whether to reuse the last picks; "-" asks
  // which line to take from when the dish sits in the cart more than once.
  const [showAddonRepeat, setShowAddonRepeat] = useState(false);
  const [showAddonLines, setShowAddonLines] = useState(false);

  // Stock inputs for getMaxAddableQuantity, in each card's original form.
  const unlimitedOf = (variant: any) =>
    useStockHelpers
      ? isVariantUnlimitedStock(variant)
      : variant?.is_unlimited_stock != 0;
  const stockOf = (variant: any) =>
    useStockHelpers ? variantStock(variant) : variant?.stock;

  useEffect(() => {
    const isMultiVariant = product?.variants?.length > 1;

    // Synchronize selected variant with cart for single variant products
    if (!isMultiVariant) {
      const cartList = cart?.isGuest ? cart?.guestCart : cart?.cartProducts;
      const inCart = product?.variants?.find((variant: any) =>
        cartList?.some((c: any) => c?.product_variant_id == variant?.id),
      );
      if (inCart) {
        // eslint-disable-next-line react-hooks/set-state-in-effect -- syncs selected variant with the cart's current line for this product
        setSelectedVariant(inCart);
        return;
      }
    }
    // Default to first in-stock variant
    const inStockVariant = product?.variants?.find((variant: any) =>
      isVariantInStock(variant),
    );
    setSelectedVariant(inStockVariant ?? product?.variants?.[0]);
  }, [
    product?.id,
    product?.variants,
    cart?.isGuest,
    cart?.cartProducts,
    cart?.guestCart,
  ]);

  const getProductQuantities = (products: any[]) => {
    return Object.entries(
      products?.reduce((quantities: Record<string, number>, product: any) => {
        const existingQty = quantities[product.product_id] || 0;
        return {
          ...quantities,
          [product.product_id]: existingQty + product.qty,
        };
      }, {}),
    ).map(([productId, qty]) => ({
      product_id: parseInt(productId),
      qty,
    }));
  };

  // Add product variant to cart
  const addToCart = async (
    productId: number | string,
    productVId: number | string,
    qty: number,
    ctx?: FlushCtx,
    addons?: any[],
  ) => {
    try {
      const response = await api.addToCart({
        product_id: productId,
        product_variant_id: productVId,
        qty: qty,
        latitude: city?.latitude,
        longitude: city?.longitude,
        addons,
      });
      // Guard against out-of-order responses
      if (ctx?.isStale?.()) return;
      if (response.status === 1) {
        // Update state from authoritative server cart
        const serverCart = response?.data?.cart?.map((item: any) => ({
          product_id: item?.id,
          product_variant_id: item?.variant_id,
          addons: item?.addons ?? [],
          qty: item?.variants?.[0]?.quantity ?? item?.quantity,
        }));
        dispatch(setCart({ data: response }));
        dispatch(setCartProducts({ data: serverCart ?? [] }));
        dispatch(setCartSubTotal({ data: response?.data?.sub_total }));
        trackAddToCart(
          toGaItem(product, selectedVariant, Number(qty) || 1),
          currencyCode,
        );
      } else {
        toast.error(response.message);
        // Throw to revert optimistic quantity
        throw new Error(response?.message || "addToCart failed");
      }
    } catch (error) {
      console.log("error", error);
      throw error;
    }
  };

  const removeFromCart = async (
    productId: number | string,
    variantId: number | string,
    units: number = 1,
    ctx?: FlushCtx,
    addons?: any[],
  ) => {
    try {
      const response = await api.removeFromCart({
        product_id: productId,
        product_variant_id: variantId,
        qty: units,
        addons,
      });
      // Guard against out-of-order responses
      if (ctx?.isStale?.()) return;
      // Treat 0-item response as successful removal
      const alreadyGone =
        response?.status !== 1 &&
        /not found|no item/i.test(response?.message || "");
      if (response?.status === 1 || alreadyGone) {
        // Update state from server cart
        const serverCart = response?.data?.cart?.map((item: any) => ({
          product_id: item?.id,
          product_variant_id: item?.variant_id,
          addons: item?.addons ?? [],
          qty: item?.variants?.[0]?.quantity ?? item?.quantity,
        }));
        dispatch(setCartSubTotal({ data: response?.data?.sub_total ?? 0 }));
        dispatch(setCartProducts({ data: serverCart ?? [] }));
        trackRemoveFromCart(
          toGaItem(product, selectedVariant, Number(units) || 1),
          currencyCode,
        );
      } else {
        toast.error(response.message);
        // Throw to revert optimistic quantity
        throw new Error(response?.message || "removeFromCart failed");
      }
    } catch (error) {
      console.log("error", error);
      if (rethrowRemoveError) throw error;
    }
  };

  const AddToGuestCart = (
    productId: number | string,
    productVariantId: number | string,
    Qty: number,
    isExisting: number,
    flag: "add" | "remove",
  ) => {
    const gaItem = toGaItem(product, selectedVariant, 1);
    if (flag === "add") trackAddToCart(gaItem, currencyCode);
    else trackRemoveFromCart(gaItem, currencyCode);
    const finalPrice =
      selectedVariant?.discounted_price !== 0
        ? selectedVariant?.discounted_price
        : selectedVariant?.price;
    if (isExisting) {
      let updatedProducts;
      if (Qty !== 0) {
        if (flag == "add") {
          dispatch(addGuestCartTotal({ data: finalPrice }));
        } else if (flag == "remove") {
          dispatch(subGuestCartTotal({ data: finalPrice }));
        }
        updatedProducts = cart?.guestCart?.map((product: any) => {
          if (
            product?.product_id == productId &&
            product?.product_variant_id == productVariantId
          ) {
            return { ...product, qty: Qty };
          } else {
            return product;
          }
        });
      } else {
        if (flag == "add") {
          dispatch(addGuestCartTotal({ data: finalPrice }));
        } else if (flag == "remove") {
          dispatch(subGuestCartTotal({ data: finalPrice }));
        }
        updatedProducts = cart?.guestCart?.filter(
          (product: any) =>
            product?.product_id != productId &&
            product?.product_variant_id != productVariantId,
        );
      }
      dispatch(addtoGuestCart({ data: updatedProducts }));
    } else {
      if (flag == "add") {
        dispatch(addGuestCartTotal({ data: finalPrice }));
      } else if (flag == "remove") {
        dispatch(subGuestCartTotal({ data: finalPrice }));
      }
      const productData = {
        product_id: productId,
        product_variant_id: productVariantId,
        qty: Qty,
        productPrice: finalPrice,
      };
      dispatch(addtoGuestCart({ data: [...cart?.guestCart, productData] }));
    }
  };

  const handleValidateAddExistingGuestProduct = (
    productQuantity: any[],
    quantity: number,
  ) => {
    const productQty = productQuantity?.find(
      (prdct: any) => prdct?.product_id == product?.id,
    )?.qty;

    const maxAddableExisting = getMaxAddableQuantity({
      maxCartItemsCount: setting?.max_cart_items_count,
      otherLinesQty: getCartTotalQuantity(cart?.guestCart) - (productQty || 0),
      totalAllowedQty: product?.total_allowed_quantity,
      isUnlimitedStock: unlimitedOf(selectedVariant),
      stock: stockOf(selectedVariant),
    });

    if (Number(product.is_unlimited_stock !== 0)) {
      if (hasReachedAllowedQty(productQty, product?.total_allowed_quantity)) {
        toast.error(t("max_cart_limit_error"));
      } else if (Number(productQty) >= maxAddableExisting) {
        toast.error(t("max_cart_limit_error"));
      } else {
        AddToGuestCart(product?.id, selectedVariant?.id, quantity, 1, "add");
      }
    } else {
      if (productQty >= Number(selectedVariant?.stock)) {
        toast.error(t("out_of_stock_message"));
      } else if (
        hasReachedAllowedQty(productQty, product?.total_allowed_quantity)
      ) {
        toast.error(t("max_cart_limit_error"));
      } else if (Number(productQty) >= maxAddableExisting) {
        toast.error(t("max_cart_limit_error"));
      } else {
        AddToGuestCart(product?.id, selectedVariant?.id, quantity, 1, "add");
      }
    }
  };

  const handleAddNewProductGuest = (productQuantity: any[]) => {
    const productQty = productQuantity?.find(
      (prdct: any) => prdct?.product_id == product?.id,
    )?.qty;

    const variantDisabled =
      guardDisabledVariantOnGuestAdd &&
      selectedVariant?.status !== undefined &&
      Number(selectedVariant?.status) === 0;

    const maxAddableNew = getMaxAddableQuantity({
      maxCartItemsCount: setting?.max_cart_items_count,
      otherLinesQty: getCartTotalQuantity(cart?.guestCart),
      totalAllowedQty: product?.total_allowed_quantity,
      isUnlimitedStock: unlimitedOf(selectedVariant),
      stock: stockOf(selectedVariant),
    });

    if (isVariantOutOfStock(selectedVariant) || variantDisabled) {
      toast.error(t("out_of_stock_message"));
    } else if (
      !hasReachedAllowedQty(
        Number(productQty || 0),
        product.total_allowed_quantity,
      )
    ) {
      if (maxAddableNew <= 0) {
        toast.error(t("maximum_cart_quantity_reach"));
      } else {
        AddToGuestCart(product?.id, selectedVariant?.id, 1, 0, "add");
      }
    } else {
      toast.error(t("out_of_stock_message"));
    }
  };

  const handleValidateAddNewProduct = (productQuantity: any[]) => {
    const productQty = productQuantity?.find(
      (prdct: any) => prdct?.product_id == product?.id,
    )?.qty;

    // Validate variant stock and status
    const variantDisabled =
      selectedVariant?.status !== undefined &&
      Number(selectedVariant?.status) === 0;

    if (hasReachedAllowedQty(productQty || 0, product?.total_allowed_quantity)) {
      toast.error(t("out_of_stock_message"));
    } else if (isVariantOutOfStock(selectedVariant) || variantDisabled) {
      toast.error(t("out_of_stock_message"));
    } else if (
      getMaxAddableQuantity({
        maxCartItemsCount: setting?.max_cart_items_count,
        otherLinesQty: getCartTotalQuantity(cart?.cartProducts),
        totalAllowedQty: product?.total_allowed_quantity,
        isUnlimitedStock: unlimitedOf(selectedVariant),
        stock: stockOf(selectedVariant),
      }) <= 0
    ) {
      toast.error(t("maximum_cart_quantity_reach"));
    } else {
      // Errors already toast inside addToCart; swallow so the rejection does not float.
      addToCart(product?.id, selectedVariant?.id, 1).catch(() => {});
    }
  };

  const isProductAlreadyAdded =
    (cart?.isGuest === false &&
      cart?.cartProducts?.find(
        (prdct: any) => prdct?.product_variant_id == selectedVariant?.id,
      )?.qty > 0) ||
    (cart?.isGuest === true &&
      cart?.guestCart?.find(
        (prdct: any) => prdct?.product_variant_id === selectedVariant?.id,
      )?.qty > 0);

  const addedQuantity =
    cart.isGuest === false
      ? cart?.cartProducts?.find(
          (prdct: any) => prdct?.product_variant_id == selectedVariant?.id,
        )?.qty
      : cart?.guestCart?.find(
          (prdct: any) => prdct?.product_variant_id == selectedVariant?.id,
        )?.qty;

  // Maximum allowed cart quantity
  const otherLinesQty =
    getCartTotalQuantity(cart?.cartProducts) - (addedQuantity || 0);
  const maxQty = getMaxAddableQuantity({
    maxCartItemsCount: setting?.max_cart_items_count,
    otherLinesQty,
    totalAllowedQty: product?.total_allowed_quantity,
    isUnlimitedStock: isVariantUnlimitedStock(selectedVariant),
    stock: variantStock(selectedVariant),
  });

  const guestMaxQty = getMaxAddableQuantity({
    maxCartItemsCount: setting?.max_cart_items_count,
    otherLinesQty:
      getCartTotalQuantity(cart?.guestCart) -
      (cart?.guestCart?.find(
        (prdct: any) => prdct?.product_variant_id == selectedVariant?.id,
      )?.qty || 0),
    totalAllowedQty: product?.total_allowed_quantity,
    isUnlimitedStock: isVariantUnlimitedStock(selectedVariant),
    stock: variantStock(selectedVariant),
  });

  // Debounced quantity management for server cart
  const {
    displayQty: serverDisplayQty,
    increment: serverIncrement,
    decrement: serverDecrement,
  } = useDebouncedQuantity({
    serverQty: addedQuantity || 0,
    onCommit: (qty, ctx) =>
      addToCart(product?.id, selectedVariant?.id, qty, ctx),
    onRemove: (units = 1, ctx) =>
      removeFromCart(product?.id, selectedVariant?.id, units, ctx),
    max: Number.isFinite(maxQty) ? maxQty : undefined,
    onMax: () =>
      toast.error(t("max_cart_limit_error"), {
        toastId: "max_cart_limit_error",
      }),
  });

  // Every cart line of this product and the dish count across them.
  const addonLines = hasAddons ? productCartLines(cart, product?.id) : [];
  const addonQty = hasAddons ? productCartQty(cart, product?.id) : 0;
  const lastAddonLine = addonLines[addonLines.length - 1];

  const syncGuestLines = (rows: any[]) => {
    dispatch(addtoGuestCart({ data: rows }));
  };

  const guestLineMatches = (row: any, line: any) =>
    row?.product_variant_id == line?.product_variant_id &&
    row?.addon_fingerprint === line?.addon_fingerprint;

  // Reuse a line's picks for one more dish — the server folds it into that
  // same line because the option fingerprint matches.
  const repeatAddonLine = async (line: any) => {
    if (!line) return;
    if (cart?.isGuest) {
      syncGuestLines(
        (cart?.guestCart ?? []).map((row: any) =>
          guestLineMatches(row, line) ? { ...row, qty: (row?.qty || 0) + 1 } : row,
        ),
      );
      dispatch(addGuestCartTotal({ data: line?.productPrice ?? 0 }));
      return;
    }
    await addToCart(
      product?.id,
      line?.product_variant_id,
      (Number(line?.qty) || 0) + 1,
      undefined,
      lineAddonPayload(line),
    ).catch(() => {});
  };

  const repeatLastAddonLine = () => repeatAddonLine(lastAddonLine);

  // Opening the sheet in the same tick as closing the prompt leaves Radix's old
  // overlay over a page with no panel. Opening partway through the 200ms exit
  // instead crossfades the two backdrops.
  const openAddonSheetAfterClose = () => {
    setShowAddonRepeat(false);
    setShowAddonLines(false);
    setTimeout(() => setShowAddons(true), 120);
  };

  const removeAddonLine = async (line: any) => {
    if (!line) return;
    if (cart?.isGuest) {
      const nextQty = (Number(line?.qty) || 0) - 1;
      syncGuestLines(
        (cart?.guestCart ?? [])
          .map((row: any) =>
            guestLineMatches(row, line) ? { ...row, qty: nextQty } : row,
          )
          .filter((row: any) => (Number(row?.qty) || 0) > 0),
      );
      dispatch(subGuestCartTotal({ data: line?.productPrice ?? 0 }));
      return;
    }
    await removeFromCart(
      product?.id,
      line?.product_variant_id,
      1,
      undefined,
      lineAddonPayload(line),
    );
  };

  const handleIntialAddToCart = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (hasAddons) {
      setShowAddons(true);
      return;
    }
    const quantity = getProductQuantities(cart?.cartProducts);
    if (cart?.isGuest) {
      handleAddNewProductGuest(quantity);
    } else {
      handleValidateAddNewProduct(quantity);
    }
  };

  const handleQuantityIncrease = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (hasAddons) {
      if (addonLines.length > 0) setShowAddonRepeat(true);
      else setShowAddons(true);
      return;
    }
    if (cart?.isGuest) {
      const productQuantity = getProductQuantities(cart?.guestCart);
      handleValidateAddExistingGuestProduct(
        productQuantity,
        cart?.guestCart?.find(
          (prdct: any) =>
            prdct?.product_id == product?.id &&
            prdct?.product_variant_id == selectedVariant?.id,
        )?.qty + 1,
      );
    } else {
      // Server cart increment
      serverIncrement();
    }
  };

  const handleQuantityDecrease = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (hasAddons) {
      if (addonLines.length > 1) setShowAddonLines(true);
      else if (addonLines.length === 1) removeAddonLine(addonLines[0]);
      return;
    }
    if (cart?.isGuest) {
      AddToGuestCart(
        product?.id,
        selectedVariant?.id,
        cart?.guestCart?.find(
          (prdct: any) => prdct?.product_variant_id == selectedVariant?.id,
        )?.qty - 1,
        1,
        "remove",
      );
    } else {
      // Server cart decrement
      serverDecrement();
    }
  };

  // Stepper visibility gated on hydration. An addon product counts every line
  // of itself, whatever the picks, so the stepper reads as one dish count.
  const showStepper = hasAddons
    ? hydrated && addonQty > 0
    : hydrated && (cart?.isGuest ? isProductAlreadyAdded : serverDisplayQty > 0);

  return {
    cart,
    setting,
    hasAddons,
    showAddons,
    setShowAddons,
    addonLines,
    addonQty,
    lastAddonLine,
    showAddonRepeat,
    setShowAddonRepeat,
    showAddonLines,
    setShowAddonLines,
    repeatLastAddonLine,
    repeatAddonLine,
    openAddonSheetAfterClose,
    removeAddonLine,
    selectedVariant,
    setSelectedVariant,
    isProductAlreadyAdded,
    // An addon product's stepper counts every line of the dish, not one line.
    addedQuantity: hasAddons ? addonQty : addedQuantity,
    maxQty,
    guestMaxQty,
    serverDisplayQty: hasAddons ? addonQty : serverDisplayQty,
    showStepper,
    handleIntialAddToCart,
    handleQuantityIncrease,
    handleQuantityDecrease,
  };
};

export default useCartLine;
