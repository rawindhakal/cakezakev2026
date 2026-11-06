"use client";

import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import * as api from "@/api/apiRoutes";
import { useSelector, useDispatch } from "react-redux";
import { t } from "@/utils/translation";
import {
  addtoGuestCart,
  setCart,
  setCartProducts,
  setCartSubTotal,
  setGuestCartTotal,
} from "@/redux/slices/cartSlice";
import { setFavoriteProductIds } from "@/redux/slices/FavoriteSlice";
import { toast } from "react-toastify";
import { useFavoriteToggle } from "@/hooks/useFavoriteToggle";
import useIsRtl from "@/hooks/useIsRtl";
import {
  exceedsAllowedQty,
  getCartTotalQuantity,
  getMaxAddableQuantity,
} from "@/utils/helperFunction";
import { useDebouncedQuantity } from "@/hooks/useDebouncedQuantity";
import useZoneHref from "@/hooks/useZoneHref";
import useStoreClosed from "@/hooks/useStoreClosed";
import useCurrency from "@/hooks/useCurrency";
import AddonsModal from "@/components/addonsmodal/AddonsModal";
import { hasAddonGroups } from "@/utils/addons";
import StoryDetailView from "./StoryDetailView";
import DialogDetailView from "./DialogDetailView";

// Track sync timestamps for favorite flags
const favoriteSyncedAt = new Map<any, number>();

interface ProductDetailModalProps {
  product: any;
  showDetailModal: boolean;
  setShowDetailModal: (show: boolean) => void;
  /** Layout format. */
  layout?: "dialog" | "story";
  /** Story expanded state. */
  storyExpanded?: boolean;
  onStoryExpandChange?: (expanded: boolean) => void;
}

const ProductDetailModal = ({
  product,
  showDetailModal,
  setShowDetailModal,
  layout = "dialog",
  storyExpanded = false,
  onStoryExpandChange,
}: ProductDetailModalProps) => {
  const isStory = layout === "story";
  const zoneHref = useZoneHref();
  const { guard: guardClosed, closedProps } = useStoreClosed();
  const rtl = useIsRtl();
  const dispatch = useDispatch();
  const router = useRouter();

  const setting = useSelector((state: any) => state.Setting);
  const city = useSelector((state: any) => state.City.city);
  const cityStatus = useSelector((state: any) => state.City.status);
  const shopMode = useSelector((state: any) => state.ShopMode.mode);
  const cart = useSelector((state: any) => state.Cart);
  const favoriteProductIds = useSelector(
    (state: any) => state.Favorite.favouriteProductIds,
  );
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  const user = useSelector((state: any) => state.User);

  // Ref tracking favorite IDs to avoid unnecessary refetches
  const favoriteProductIdsRef = useRef(favoriteProductIds);
  useEffect(() => {
    favoriteProductIdsRef.current = favoriteProductIds;
  }, [favoriteProductIds]);

  const ratingsCount = 10;
  const [productDetails, setProductDetails] = useState<any>([]);
  const [selectVariant, setSelectVariant] = useState<any>(
    product?.variants?.[0],
  );
  const [quantity, setQuantity] = useState(1);
  // Food product with questions: the sheet collects the answers and makes the
  // add call itself, so this modal never adds such a product directly.
  const [showAddons, setShowAddons] = useState(false);
  const [addonIntent, setAddonIntent] = useState<"cart" | "buy">("cart");
  const [productImages, setProductImages] = useState<any[]>([]);
  const [selectedImage, setSelectedImage] = useState("");
  const [isVariantAvailable, setIsVariantAvailable] = useState(false);
  const [isNotifyRequested, setIsNotifyRequested] = useState(
    !!selectVariant?.is_notify_requested,
  );
  const [notifyLoading, setNotifyLoading] = useState(false);
  const [isShareOpen, setIsShareOpen] = useState(false);
  const [featuresOpen, setFeaturesOpen] = useState(false);
  const [recentlyViewedProducts, setRecentlyViewedProducts] = useState<any[]>([]);

  // Touch gesture state and DOM refs for story mode
  const pullRef = useRef(0);
  const storyRootRef = useRef<HTMLDivElement>(null);
  const storyScrollRef = useRef<HTMLDivElement>(null);
  const touchRef = useRef<{
    x: number;
    y: number;
    t: number;
    fired: boolean;
    axis: "x" | "y" | null;
    pullFrom: number | null;
  } | null>(null);

  useEffect(() => {
    if (!storyExpanded) storyScrollRef.current?.scrollTo({ top: 0 });
  }, [storyExpanded]);

  // Recently viewed: logged-in only, same contract as the PDP page.
  useEffect(() => {
    const id = productDetails?.id ?? product?.id;
    if (!showDetailModal || !id || !user?.jwtToken) return;
    let cancelled = false;
    (async () => {
      try {
        await api.addRecentlyViewedProduct({
          productId: id,
          latitude: city?.latitude,
          longitude: city?.longitude,
        });
        const res = await api.getRecentlyViewedProducts({
          productId: id,
          latitude: city?.latitude,
          longitude: city?.longitude,
        });
        if (cancelled) return;
        const list =
          res?.status == 1 && Array.isArray(res?.data)
            ? res.data
                .filter((p: any) => p?.id !== id)
                .map((p: any) => ({
                  ...p,
                  image_url:
                    p?.image_url ||
                    p?.images?.[0]?.image_url ||
                    p?.variants?.[0]?.image ||
                    "",
                }))
            : [];
        setRecentlyViewedProducts(list);
      } catch (error) {
        console.log("Error", error);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [
    showDetailModal,
    productDetails?.id,
    product?.id,
    user?.jwtToken,
    city?.latitude,
    city?.longitude,
  ]);

  // Extract image URL from string or object
  const toImageUrl = (img: any) => (typeof img === "string" ? img : img?.image_url);

  // Derive display label for variant
  const getVariantLabel = (variant: any) => {
    if (variant?.measurement) {
      const unit =
        variant?.unit?.translations?.short_code ??
        variant?.unit?.short_code ??
        "";
      return `${variant.measurement} ${unit}`.trim();
    }
    if (Array.isArray(variant?.attributes) && variant.attributes.length) {
      return variant.attributes
        .map((a: any) => `${a?.attribute_value} ${a?.attribute_name}`.trim())
        .join(", ");
    }
    const name = (variant?.translations?.name ?? variant?.name ?? "").trim();
    const bases = [
      productDetails?.translations?.name,
      productDetails?.name,
      product?.translations?.name,
      product?.name,
    ]
      .map((n) => (n ?? "").trim())
      .filter(Boolean)
      .sort((a, b) => b.length - a.length);

    for (const base of bases) {
      if (name.toLowerCase().startsWith(base.toLowerCase())) {
        const rest = name
          .slice(base.length)
          .replace(/^[\s\-–—:,/|]+/, "")
          .trim();
        if (rest) return rest;
      }
    }
    return name;
  };

  // Per-axis variant selection
  const selectedAxisValue = (attrId: any) =>
    selectVariant?.attributes?.find((a: any) => a.attribute_id === attrId)
      ?.attribute_value_id;

  const findVariantForAxis = (attrId: any, valueId: any) => {
    const desired: Record<string, any> = {};
    (selectVariant?.attributes || []).forEach(
      (a: any) => (desired[a.attribute_id] = a.attribute_value_id),
    );
    desired[attrId] = valueId;
    const ids = Object.keys(desired).map(Number);
    return productDetails?.variants?.find((v: any) =>
      ids.every((id) =>
        v.attributes?.some(
          (a: any) => a.attribute_id === id && a.attribute_value_id === desired[id],
        ),
      ),
    );
  };

  const isAxisValueAvailable = (attrId: any, valueId: any) =>
    Boolean(findVariantForAxis(attrId, valueId));

  const handleSelectAxis = (attrId: any, valueId: any) => {
    const match = findVariantForAxis(attrId, valueId);
    if (match) handleChangeVariant(match);
  };

  // Lock body scroll when modal is open
  useEffect(() => {
    if (showDetailModal && !isStory) {
      const prev = document.body.style.overflow;
      document.body.style.overflow = "hidden";
      return () => {
        document.body.style.overflow = prev;
      };
    }
  }, [showDetailModal, isStory]);

  // Sync notify state with selected variant
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- sync notify state from selected variant
    setIsNotifyRequested(!!selectVariant?.is_notify_requested);
  }, [selectVariant?.id, selectVariant?.is_notify_requested]);

  // Fetch product details query
  const productQuery = useQuery({
    queryKey: [
      "product-by-id",
      product?.id,
      city?.latitude,
      city?.longitude,
      language?.id ?? language,
      shopMode,
    ],
    queryFn: () =>
      api.getProductById({
        latitude: city.latitude,
        longitude: city.longitude,
        id: product?.id,
      }),
    enabled: showDetailModal && !!product?.id && !!city?.latitude,
    staleTime: 1000 * 60 * 2,
    gcTime: 1000 * 60 * 10,
  });
  const loading = productQuery.isLoading;

  const ratingQuery = useQuery({
    queryKey: ["product-ratings", product?.id],
    queryFn: () =>
      api.getProductRatings({
        id: product?.id,
        limit: ratingsCount,
        offset: 0,
      }),
    enabled: showDetailModal && !!product?.id,
    staleTime: 1000 * 60 * 10,
  });
  const ratingData = ratingQuery.data?.data ?? {};

  // Apply product query data to local state
  useLayoutEffect(() => {
    const data = productQuery.data?.data;
    if (!data) return;
    const firstVariant = data?.variants?.[0];
    const variantImages = (firstVariant?.images || [])
      .map(toImageUrl)
      .filter(Boolean);
    const baseImages = [
      data?.image_url,
      ...(data?.images || []).map(toImageUrl),
    ].filter(Boolean);
    let gallery = variantImages.length ? variantImages : baseImages;
    if (isStory && product?.image_url) {
      gallery = [
        product.image_url,
        ...gallery.filter((g: any) => g !== product.image_url),
      ];
    }
    // eslint-disable-next-line react-hooks/set-state-in-effect -- seed local state from query data
    setProductImages(gallery);
    setSelectedImage(gallery[0] || data?.image_url || "");
    setProductDetails(data);
    if (firstVariant) setSelectVariant(firstVariant);
    if (
      data?.id != null &&
      favoriteSyncedAt.get(data.id) !== productQuery.dataUpdatedAt
    ) {
      favoriteSyncedAt.set(data.id, productQuery.dataUpdatedAt);
      const isFavorite = !!data?.is_favorite;
      const ids = favoriteProductIdsRef.current || [];
      const alreadyIn = ids.some((id: any) => id == data.id);
      if (isFavorite && !alreadyIn) {
        dispatch(setFavoriteProductIds({ data: [...ids, data.id] }));
      } else if (!isFavorite && alreadyIn) {
        dispatch(
          setFavoriteProductIds({
            data: ids.filter((id: any) => id != data.id),
          }),
        );
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [productQuery.data, productQuery.dataUpdatedAt]);

  function handleIsVariantAvailable() {
    if (product?.is_unlimited_stock == 0 && selectVariant?.stock <= 0) {
      setIsVariantAvailable(false);
    } else {
      setIsVariantAvailable(true);
    }
  }

  const handleToggleNotify = async () => {
    if (notifyLoading || !selectVariant?.id) return;
    setNotifyLoading(true);
    try {
      const response = isNotifyRequested
        ? await api.removeNotifyMe({ product_variant_id: selectVariant.id })
        : await api.notifyMe({
            product_variant_id: selectVariant.id,
            latitude: city?.latitude,
            longitude: city?.longitude,
          });
      if (response?.status === 1) {
        setIsNotifyRequested(!!response?.data?.is_notify_requested);
        if (response?.message) toast.success(response.message);
      } else {
        toast.error(
          response?.message ||
            t("something_went_wrong") ||
            "Something went wrong",
        );
      }
    } catch (error: any) {
      console.log("notify me error", error);
      toast.error(
        error?.response?.data?.message ||
          t("something_went_wrong") ||
          "Something went wrong",
      );
    } finally {
      setNotifyLoading(false);
    }
  };

  const handleChangeVariant = (variant: any) => {
    setSelectVariant(variant);
    const variantImages = (variant?.images || [])
      .map(toImageUrl)
      .filter(Boolean);
    const baseImages = [
      productDetails?.image_url,
      ...(productDetails?.images || []).map(toImageUrl),
    ].filter(Boolean);
    const gallery = variantImages.length ? variantImages : baseImages;
    setProductImages(gallery);
    setSelectedImage(gallery[0] || productDetails?.image_url || "");
  };

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- update variant availability status
    handleIsVariantAvailable();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectVariant, product?.is_unlimited_stock]);

  const handleHideDetailModal = () => {
    setShowDetailModal(false);
  };

  const variantCartQty =
    (cart?.isGuest ? cart?.guestCart : cart?.cartProducts)?.find(
      (prdct: any) =>
        prdct?.product_id == product?.id &&
        prdct?.product_variant_id == selectVariant?.id,
    )?.qty || 0;

  // The quick view stays open and steps back behind the sheet, so its backdrop
  // never fades out and the handover reads as one movement. Closing the sheet
  // brings it forward again.
  const openAddonSheet = (intent: "cart" | "buy") => {
    setAddonIntent(intent);
    setShowAddons(true);
  };

  const handleAddToCart = async () => {
    if (hasAddonGroups(addonProduct)) {
      openAddonSheet("cart");
      return;
    }
    let productQuantity = cart?.isGuest
      ? getProductQuantities(cart?.guestCart)
      : getProductQuantities(cart?.cartProducts);
    const isExisting = cart.guestCart.some(
      (cartProduct: any) =>
        cartProduct?.product_id == product?.id &&
        cartProduct?.product_variant_id == selectVariant?.id,
    );
    const productQty = productQuantity?.find(
      (prdct) => prdct?.product_id == product?.id,
    )?.qty;
    const cartProductQty = cart.cartProducts.find(
      (prdct: any) =>
        prdct?.product_id == product?.id &&
        selectVariant?.id == prdct?.product_variant_id,
    );
    if (Number(product?.is_unlimited_stock) == 0 && selectVariant?.stock <= 0) {
      toast.error(t("out_of_stock_message"));
      return;
    }
    if (cart?.isGuest) {
      const totalQty = (productQty ?? 0) + quantity;
      const maxAddable = getMaxAddableQuantity({
        maxCartItemsCount: setting?.setting?.max_cart_items_count,
        otherLinesQty:
          getCartTotalQuantity(cart?.guestCart) - (productQty || 0),
        totalAllowedQty: product?.total_allowed_quantity,
        isUnlimitedStock: Number(product?.is_unlimited_stock) != 0,
        stock: selectVariant?.stock,
      });
      if (exceedsAllowedQty(totalQty, product?.total_allowed_quantity)) {
        toast.error(t("max_cart_limit_error"));
      } else if (totalQty > maxAddable) {
        toast.error(t("max_cart_limit_error"));
      } else if (isExisting) {
        const updatedProduct = cart.guestCart?.map((cartProduct: any) => {
          if (
            cartProduct?.product_id == product?.id &&
            cartProduct?.product_variant_id == selectVariant?.id
          ) {
            return { ...cartProduct, qty: cartProduct.qty + quantity };
          } else {
            return cartProduct;
          }
        });
        dispatch(addtoGuestCart({ data: updatedProduct }));
        handleCalculateTotal(updatedProduct);
        setQuantity(1);
        toast.success(t("product_added_successfully"));
      } else {
        const productPrice =
          selectVariant.discounted_price !== 0
            ? selectVariant.discounted_price
            : selectVariant.price;
        const productData = {
          product_id: product?.id,
          product_variant_id: selectVariant?.id,
          qty: quantity,
          productPrice: productPrice,
        };
        dispatch(
          addtoGuestCart({ data: [...(cart?.guestCart ?? []), productData] }),
        );
        let products = [...(cart?.guestCart ?? []), productData];
        handleCalculateTotal(products);
        setQuantity(1);
        toast.success(t("product_added_successfully"));
      }
    } else {
      try {
        const totalQty = (productQty ?? 0) + quantity;
        const effectiveMaxQty = getMaxAddableQuantity({
          maxCartItemsCount: setting?.setting?.max_cart_items_count,
          otherLinesQty:
            getCartTotalQuantity(cart?.cartProducts) - (productQty || 0),
          totalAllowedQty: product?.total_allowed_quantity,
          isUnlimitedStock: Number(product?.is_unlimited_stock) != 0,
          stock: selectVariant?.stock,
        });
        if (exceedsAllowedQty(totalQty, product?.total_allowed_quantity)) {
          toast.error(t("max_cart_limit_error"));
        } else if (effectiveMaxQty <= 0 || totalQty > effectiveMaxQty) {
          toast.error(t("maximum_cart_quantity_reach"));
        } else {
          const response = await api.addToCart({
            product_id: product?.id,
            product_variant_id: selectVariant.id,
            qty: cartProductQty ? cartProductQty.qty + quantity : quantity,
            latitude: city?.latitude,
            longitude: city?.longitude,
          });
          if (response.status == 1) {
            if (cartProductQty) {
              const updatedProducts = cart.cartProducts.map((cartProduct: any) => {
                if (
                  cartProduct.product_id == product?.id &&
                  cartProduct.product_variant_id == selectVariant.id
                ) {
                  return {
                    ...cartProduct,
                    qty: cartProductQty
                      ? cartProductQty.qty + quantity
                      : quantity,
                  };
                } else {
                  return cartProduct;
                }
              });
              dispatch(setCartProducts({ data: updatedProducts }));
            } else {
              const productData = [
                ...cart.cartProducts,
                {
                  product_id: product?.id,
                  product_variant_id: selectVariant?.id,
                  qty: quantity,
                },
              ];
              dispatch(setCartProducts({ data: productData }));
            }
            dispatch(setCart({ data: response }));
            dispatch(setCartSubTotal({ data: response.sub_total }));
            toast.success(t("product_added_successfully"));
          } else {
            toast.error(response.message);
          }
        }
      } catch (error) {
        console.log("Error", error);
      }
    }
  };

  const getProductQuantities = (
    products: any[],
  ): { product_id: number; qty: number }[] => {
    return Object.entries(
      products?.reduce((quantities: Record<string, number>, product: any) => {
        const existingQty = quantities[product.product_id] || 0;
        return {
          ...quantities,
          [product.product_id]: existingQty + product.qty,
        };
      }, {}),
    ).map(([productId, qty]) => ({
      product_id: Number.parseInt(productId),
      qty: qty as number,
    }));
  };

  const handleCalculateTotal = (products: any[]) => {
    const total = products.reduce((prev, curr) => {
      prev += curr.productPrice * curr.qty;
      return prev;
    }, 0);
    dispatch(setGuestCartTotal({ data: total }));
  };

  const serverAddToCart = async (qty: number, ctx: any) => {
    try {
      const response = await api.addToCart({
        product_id: product?.id,
        product_variant_id: selectVariant?.id,
        qty,
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      if (ctx?.isStale?.()) return;
      if (response.status === 1) {
        const serverCart = response?.data?.cart?.map((item: any) => ({
          product_id: item?.id,
          product_variant_id: item?.variant_id,
          addons: item?.addons ?? [],
          qty: item?.variants?.[0]?.quantity ?? item?.quantity,
        }));
        dispatch(setCart({ data: response }));
        dispatch(setCartProducts({ data: serverCart ?? [] }));
        dispatch(setCartSubTotal({ data: response?.data?.sub_total }));
      } else {
        toast.error(response.message);
      }
    } catch (error) {
      console.log("error", error);
    }
  };

  const serverRemoveFromCart = async (ctx: any, units = 1) => {
    try {
      const response = await api.removeFromCart({
        product_id: product?.id,
        product_variant_id: selectVariant?.id,
        qty: units,
      });
      if (ctx?.isStale?.()) return;
      const alreadyGone =
        response?.status !== 1 &&
        /not found|no item/i.test(response?.message || "");
      if (response?.status === 1 || alreadyGone) {
        const serverCart = response?.data?.cart?.map((item: any) => ({
          product_id: item?.id,
          product_variant_id: item?.variant_id,
          addons: item?.addons ?? [],
          qty: item?.variants?.[0]?.quantity ?? item?.quantity,
        }));
        dispatch(setCartSubTotal({ data: response?.data?.sub_total ?? 0 }));
        dispatch(setCartProducts({ data: serverCart ?? [] }));
      } else {
        toast.error(response.message);
      }
    } catch (error) {
      console.log("error", error);
    }
  };

  const handleGuestIncrease = () => {
    if (
      exceedsAllowedQty(variantCartQty + 1, product?.total_allowed_quantity)
    ) {
      toast.error(t("max_cart_limit_error"));
      return;
    }
    if (
      Number(product?.is_unlimited_stock) == 0 &&
      variantCartQty >= selectVariant?.stock
    ) {
      toast.error(t("out_of_stock"));
      return;
    }
    const maxAddable = getMaxAddableQuantity({
      maxCartItemsCount: setting?.setting?.max_cart_items_count,
      otherLinesQty:
        getCartTotalQuantity(cart?.guestCart) - (variantCartQty || 0),
      totalAllowedQty: product?.total_allowed_quantity,
      isUnlimitedStock: Number(product?.is_unlimited_stock) != 0,
      stock: selectVariant?.stock,
    });
    if (variantCartQty >= maxAddable) {
      toast.error(t("max_cart_limit_error"));
      return;
    }
    const updated = cart.guestCart.map((cp: any) =>
      cp?.product_id == product?.id &&
      cp?.product_variant_id == selectVariant?.id
        ? { ...cp, qty: cp.qty + 1 }
        : cp,
    );
    dispatch(addtoGuestCart({ data: updated }));
    handleCalculateTotal(updated);
  };

  const handleGuestDecrease = () => {
    const updated = cart.guestCart
      .map((cp: any) =>
        cp?.product_id == product?.id &&
        cp?.product_variant_id == selectVariant?.id
          ? { ...cp, qty: cp.qty - 1 }
          : cp,
      )
      .filter((cp: any) => cp.qty > 0);
    dispatch(addtoGuestCart({ data: updated }));
    handleCalculateTotal(updated);
  };

  const {
    liked,
    toggle: handleProductLikes,
    canToggle: canToggleLike,
  } = useFavoriteToggle({
    productId: product?.id,
  });

  const handleChangeCoverImage = (image: string) => {
    setSelectedImage(image);
  };

  const handleBuyNow = async () => {
    // The sheet owns the add call, so leaving for the cart waits for onAdded.
    if (hasAddonGroups(addonProduct)) {
      openAddonSheet("buy");
      return;
    }
    await handleAddToCart();
    setShowDetailModal(false);
    router.push(zoneHref("/cart"));
  };

  const calculateDiscount = (discountPrice: number, actualPrice: number) => {
    const difference = actualPrice - discountPrice;
    return (difference / actualPrice) * 100;
  };

  const { currency, decimals: decimalPoint } = useCurrency();

  const hasDiscount =
    selectVariant?.discounted_price !== 0 &&
    selectVariant?.discounted_price !== selectVariant?.price;
  const discountLabel = hasDiscount
    ? `${calculateDiscount(
        selectVariant?.discounted_price,
        selectVariant?.price,
      ).toFixed(decimalPoint)}% ${t("off")}`
    : null;

  const quickDeliveryTime =
    setting?.setting?.web_settings?.delivery_time ||
    setting?.setting?.delivery_time ||
    10;
  const showQuickDelivery = shopMode === "quick" && cityStatus === "fulfill";
  const deliveryLabel =
    selectVariant?.time_to_deliver ||
    productDetails?.time_to_deliver ||
    `${t("delivery_in")} ${quickDeliveryTime} ${t("minutes")}`;

  const maxQty = getMaxAddableQuantity({
    maxCartItemsCount: setting?.setting?.max_cart_items_count,
    otherLinesQty:
      getCartTotalQuantity(cart?.cartProducts) - (variantCartQty || 0),
    totalAllowedQty: product?.total_allowed_quantity,
    isUnlimitedStock: Number(product?.is_unlimited_stock) != 0,
    stock: selectVariant?.stock,
  });

  const guestMaxQty = getMaxAddableQuantity({
    maxCartItemsCount: setting?.setting?.max_cart_items_count,
    otherLinesQty:
      getCartTotalQuantity(cart?.guestCart) - (variantCartQty || 0),
    totalAllowedQty: product?.total_allowed_quantity,
    isUnlimitedStock: Number(product?.is_unlimited_stock) != 0,
    stock: selectVariant?.stock,
  });

  const {
    displayQty: serverDisplayQty,
    increment: serverIncrement,
    decrement: serverDecrement,
  } = useDebouncedQuantity({
    serverQty: variantCartQty || 0,
    onCommit: (qty, ctx) => serverAddToCart(qty, ctx),
    onRemove: (units = 1, ctx) => serverRemoveFromCart(ctx, units),
    max: Number.isFinite(maxQty) ? maxQty : undefined,
    onMax: () =>
      toast.error(t("max_cart_limit_error"), {
        toastId: "max_cart_limit_error",
      }),
  });

  // The fetched row carries addon_groups; the card row only has has_addons.
  const addonProduct = productDetails?.id ? productDetails : product;
  const stepperQty = cart?.isGuest ? variantCartQty : serverDisplayQty;
  // One variant can back several lines with different picks, so a single
  // stepper cannot say which line it means.
  const showStepper = stepperQty > 0 && !hasAddonGroups(addonProduct);
  const handleStepperIncrease = () =>
    cart?.isGuest ? handleGuestIncrease() : serverIncrement();
  const handleStepperDecrease = () =>
    cart?.isGuest ? handleGuestDecrease() : serverDecrement();
  const handleStepperAdd = () => {
    // Both branches add a line directly, so the addon gate comes first.
    if (hasAddonGroups(addonProduct)) {
      openAddonSheet("cart");
      return;
    }
    return cart?.isGuest ? handleAddToCart() : serverIncrement();
  };

  const returnDaysCount = Number(productDetails?.return_days);
  const returnDaysLabel = returnDaysCount === 1 ? t("day") : t("days");
  const returnableText =
    returnDaysCount === 0
      ? t("easy_return")
      : `${t("returnable")} ${productDetails?.return_days} ${returnDaysLabel}`;
  const returnStatusText =
    productDetails?.return_status != 1 ? t("non-returnable") : returnableText;

  const CANCEL_STATUS_LABELS: Record<string | number, string> = {
    1: "paymentPending",
    2: "order_status_display_name_recieved",
    3: "processed",
    4: "order_status_display_name_shipped",
    5: "out_for_delivery",
    6: "order_status_display_name_delivered",
    7: "cancelled",
    8: "returned",
    9: "order_in_process",
    10: "ready_to_pickup",
  };
  const rawCancelTill =
    shopMode === "quick"
      ? (productDetails?.till_status_quick ?? productDetails?.till_status ?? product?.till_status_quick ?? product?.till_status)
      : (productDetails?.till_status_ecommerce ?? productDetails?.till_status ?? product?.till_status_ecommerce ?? product?.till_status);
  const cancelTillValue = Number(rawCancelTill);
  const cancelStatusLabel =
    CANCEL_STATUS_LABELS[cancelTillValue] ||
    CANCEL_STATUS_LABELS[String(rawCancelTill || "").toLowerCase()];

  const isCancelable =
    productDetails?.cancelable_status == 1 || product?.cancelable_status == 1;

  const cancelableText = !isCancelable
    ? t("non-cancelable")
    : cancelTillValue > 0 && cancelStatusLabel
      ? (t("cancelable") ? `${t("cancelable")}${t(cancelStatusLabel)}`.trim() : `${t("cancel_before")} ${t(cancelStatusLabel)}`.trim())
      : (t("cancelable") ? t("cancelable").replace(/\s+till\s*$/i, "").trim() : t("cancel_before"));

  // Touch gesture handlers for story view
  const applyPull = (px: number) => {
    pullRef.current = px;
    const el = storyRootRef.current;
    if (!el) return;
    el.style.transition = px
      ? "none"
      : "transform 220ms cubic-bezier(0.32,0.72,0,1)";
    el.style.transform = px
      ? `translate3d(0,${px}px,0) scale(${1 - px / 1600})`
      : "";
    if (storyExpanded) el.style.borderRadius = px ? "24px" : "";
  };

  const onStoryTouchStart = (e: React.TouchEvent) => {
    const t0 = e.touches[0];
    touchRef.current = {
      x: t0.clientX,
      y: t0.clientY,
      t: e.timeStamp,
      fired: false,
      axis: null,
      pullFrom: null,
    };
  };

  const onStoryTouchMove = (e: React.TouchEvent) => {
    const start = touchRef.current;
    if (!start || start.fired || !onStoryExpandChange) return;
    const dx = e.touches[0].clientX - start.x;
    const dy = e.touches[0].clientY - start.y;
    if (!start.axis) {
      if (Math.max(Math.abs(dx), Math.abs(dy)) < 8) return;
      start.axis = Math.abs(dy) > Math.abs(dx) ? "y" : "x";
    }
    if (start.axis === "x") return;
    const sc = storyScrollRef.current;
    const atTop = (sc?.scrollTop ?? 0) <= 0;
    if (!storyExpanded) {
      const scrollable = !!sc && sc.scrollHeight > sc.clientHeight + 4;
      if (dy < -40 && !scrollable) {
        start.fired = true;
        applyPull(0);
        onStoryExpandChange(true);
      } else if (dy > 0 && atTop) {
        const pull = Math.min(dy * 0.9, 260);
        if (pull > 110) {
          start.fired = true;
          handleHideDetailModal();
        } else {
          applyPull(pull);
        }
      }
    } else if (atTop && dy > 0) {
      const y = e.touches[0].clientY;
      if (start.pullFrom == null) start.pullFrom = y;
      const pulled = y - start.pullFrom;
      if (pulled > 60) {
        start.fired = true;
        applyPull(0);
        onStoryExpandChange(false);
      } else if (pulled > 0) {
        applyPull(pulled * 0.8);
      }
    }
  };

  const onStoryTouchEnd = (e: React.TouchEvent) => {
    const start = touchRef.current;
    const pull = pullRef.current;
    const flick =
      !!start &&
      pull > 12 &&
      (e.changedTouches[0]?.clientY - start.y) /
        Math.max(1, e.timeStamp - start.t) >
        0.4;
    if (storyExpanded && (pull > 45 || flick)) {
      onStoryExpandChange?.(false);
      applyPull(0);
    } else if (!storyExpanded && (pull > 55 || flick)) {
      handleHideDetailModal();
    } else if (pull) {
      applyPull(0);
    }
    touchRef.current = null;
  };

  const d = productDetails?.id ? productDetails : product;
  const productPath = zoneHref(`/product/${d?.slug}`);
  const shareUrl =
    typeof window !== "undefined"
      ? `${window.location.origin}${productPath}`
      : productPath;

  if (isStory) {
    return (
      <>
      <StoryDetailView
        rtl={rtl}
        product={product}
        productDetails={productDetails}
        selectVariant={selectVariant}
        productImages={productImages}
        selectedImage={selectedImage}
        ratingData={ratingData}
        showQuickDelivery={showQuickDelivery}
        currency={currency}
        hasDiscount={hasDiscount}
        discountLabel={discountLabel}
        deliveryLabel={deliveryLabel}
        isVariantAvailable={isVariantAvailable}
        isNotifyRequested={isNotifyRequested}
        notifyLoading={notifyLoading}
        handleToggleNotify={handleToggleNotify}
        handleChangeVariant={handleChangeVariant}
        handleSelectAxis={handleSelectAxis}
        selectedAxisValue={selectedAxisValue}
        isAxisValueAvailable={isAxisValueAvailable}
        getVariantLabel={getVariantLabel}
        showStepper={showStepper}
        stepperQty={stepperQty}
        guestMaxQty={guestMaxQty}
        maxQty={maxQty}
        cart={cart}
        closedProps={closedProps}
        guardClosed={guardClosed}
        handleStepperIncrease={handleStepperIncrease}
        handleStepperDecrease={handleStepperDecrease}
        handleStepperAdd={handleStepperAdd}
        handleHideDetailModal={handleHideDetailModal}
        liked={liked}
        canToggleLike={canToggleLike}
        handleProductLikes={handleProductLikes}
        handleChangeCoverImage={handleChangeCoverImage}
        storyExpanded={storyExpanded}
        onStoryExpandChange={onStoryExpandChange}
        isShareOpen={isShareOpen}
        setIsShareOpen={setIsShareOpen}
        featuresOpen={featuresOpen}
        setFeaturesOpen={setFeaturesOpen}
        returnStatusText={returnStatusText}
        cancelableText={cancelableText}
        storyRootRef={storyRootRef}
        storyScrollRef={storyScrollRef}
        onStoryTouchStart={onStoryTouchStart}
        onStoryTouchMove={onStoryTouchMove}
        onStoryTouchEnd={onStoryTouchEnd}
        recentlyViewedProducts={recentlyViewedProducts}
        shareUrl={shareUrl}
      />
      <AddonsModal
        product={addonProduct}
        showAddons={showAddons}
        setShowAddons={setShowAddons}
        variant={selectVariant}
        qty={quantity}
        stacked
        onAdded={() => {
          // The line is in the cart, so the quick view behind has served its
          // purpose either way.
          setShowDetailModal(false);
          if (addonIntent !== "buy") return;
          setAddonIntent("cart");
          router.push(zoneHref("/cart"));
        }}
      />
      </>
    );
  }

  return (
    <>
    <DialogDetailView
      showDetailModal={showDetailModal}
      rtl={rtl}
      loading={loading}
      product={product}
      productDetails={productDetails}
      selectVariant={selectVariant}
      productImages={productImages}
      selectedImage={selectedImage}
      ratingData={ratingData}
      currency={currency}
      hasDiscount={hasDiscount}
      discountLabel={discountLabel}
      showQuickDelivery={showQuickDelivery}
      deliveryLabel={deliveryLabel}
      isVariantAvailable={isVariantAvailable}
      isNotifyRequested={isNotifyRequested}
      notifyLoading={notifyLoading}
      handleToggleNotify={handleToggleNotify}
      handleChangeVariant={handleChangeVariant}
      handleSelectAxis={handleSelectAxis}
      selectedAxisValue={selectedAxisValue}
      isAxisValueAvailable={isAxisValueAvailable}
      getVariantLabel={getVariantLabel}
      showStepper={showStepper}
      stepperQty={stepperQty}
      guestMaxQty={guestMaxQty}
      maxQty={maxQty}
      cart={cart}
      closedProps={closedProps}
      guardClosed={guardClosed}
      handleStepperIncrease={handleStepperIncrease}
      handleStepperDecrease={handleStepperDecrease}
      handleStepperAdd={handleStepperAdd}
      handleBuyNow={handleBuyNow}
      handleHideDetailModal={handleHideDetailModal}
      liked={liked}
      canToggleLike={canToggleLike}
      handleProductLikes={handleProductLikes}
      handleChangeCoverImage={handleChangeCoverImage}
      returnStatusText={returnStatusText}
      cancelableText={cancelableText}
      pushedBack={showAddons}
    />
      <AddonsModal
        product={addonProduct}
        showAddons={showAddons}
        setShowAddons={setShowAddons}
        variant={selectVariant}
        qty={quantity}
        stacked
        onAdded={() => {
          // The line is in the cart, so the quick view behind has served its
          // purpose either way.
          setShowDetailModal(false);
          if (addonIntent !== "buy") return;
          setAddonIntent("cart");
          router.push(zoneHref("/cart"));
        }}
      />
    </>
  );
};

export default ProductDetailModal;
