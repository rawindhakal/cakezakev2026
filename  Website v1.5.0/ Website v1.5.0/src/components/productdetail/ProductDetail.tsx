"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import * as api from "@/api/apiRoutes";
import { useDispatch, useSelector } from "react-redux";
import { useQuery } from "@tanstack/react-query";
import Image from "next/image";
import { FaStar, FaStarHalfAlt } from "react-icons/fa";
import {
  MdAddShoppingCart,
  MdRemoveShoppingCart,
} from "react-icons/md";
import { FiMinus, FiPlus } from "react-icons/fi";
import ProductPersonalise from "@/components/gifting/ProductPersonalise";
import { t } from "@/utils/translation";
import {
  exceedsAllowedQty,
  hasReachedAllowedQty,
  getCartTotalQuantity,
  getMaxAddableQuantity,
} from "@/utils/helperFunction";
import { useDebouncedQuantity } from "@/hooks/useDebouncedQuantity";
import ProductNotFoundImage from "@/assets/empty-state/no-product.svg";
import ThemedSvg from "@/components/notfound/ThemedSvg";
import { LuPill } from "react-icons/lu";
import TimeIcon from "../productcards/TimeIcon";
import CancelIcon from "@/assets/icon/cancel.svg";
import NotCancelIcon from "@/assets/icon/Not-cancel.svg";
import ReturnIcon from "@/assets/icon/return.svg";
import NoReturnIcon from "@/assets/icon/no-return.svg";
import CodIcon from "@/assets/icon/cod.svg";
import { setFavoriteProductIds } from "@/redux/slices/FavoriteSlice";
import ProductDescription from "./ProductDescription";
import ProductRecommendations from "./ProductRecommendations";
import BreadCrumb from "../breadcrumb/BreadCrumb";
import Loader from "../loader/Loader";
import { toast } from "react-toastify";
import {
  addtoGuestCart,
  setCart,
  setCartProducts,
  setCartSubTotal,
  setGuestCartTotal,
} from "@/redux/slices/cartSlice";
import { useFavoriteToggle } from "@/hooks/useFavoriteToggle";
import SimilarProducts from "../productslist/SimilarProducts";
import { usePathname, useParams, useRouter } from "next/navigation";
import Link from "next/link";
import ProductImageGallery from "./ProductImageGallery";
import MobileProductGallery from "./MobileProductGallery";
import ShareDrawer from "./ShareDrawer";
import useHydratedMediaQuery from "@/hooks/useHydratedMediaQuery";
import useDir from "@/hooks/useDir";
import MobileBottomSheet from "../mobile-bottom-sheet/MobileBottomSheet";
import {
  clearAllFilter,
  setListingSource,
} from "@/redux/slices/productFilterSlice";
import RecentalyViewedProducts from "../productslist/RecentalyViewedProducts";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { setIsRefetch } from "@/redux/slices/shopSlice";
import { setShopMode } from "@/redux/slices/shopModeSlice";
import { getProductTypeMeta } from "./productType";
import useZoneHref from "@/hooks/useZoneHref";
import useNavClick from "@/hooks/useNavClick";
import useStoreClosed from "@/hooks/useStoreClosed";
import useIsHydrated from "@/hooks/useIsHydrated";
import FewLeftBadge from "../productcards/FewLeftBadge";
import useCurrency from "@/hooks/useCurrency";
import { toGaItem, trackViewItem } from "@/utils/analytics";
import PincodeCheck, { type PincodeBlock, EtaLine } from "./PincodeCheck";
import StickyAddToCartBar from "./StickyAddToCartBar";
import PriceFlip from "./PriceFlip";
import { SlidingChipGroup } from "./SlidingChips";
import { flyToCart } from "@/utils/flyToCart";
import AnimatedNumber from "@/components/ui/AnimatedNumber";
import BellToggle from "@/components/ui/bell-toggle/BellToggle";
import { productKey } from "@/utils/queryKeys";
import AddonsModal from "@/components/addonsmodal/AddonsModal";
import AddonRepeatModal from "@/components/addonsmodal/AddonRepeatModal";
import AddonLinesModal from "@/components/addonsmodal/AddonLinesModal";
import {
  hasAddonGroups,
  lineAddonPayload,
  productCartLines,
  productCartQty,
} from "@/utils/addons";

interface ProductDetailProps {
  initialProduct?: any;
  initialProductMeta?: any;
}

const ProductDetail = ({
  initialProduct = null,
  initialProductMeta = null,
}: ProductDetailProps) => {
  const zoneHref = useZoneHref();
  const { storeClosed, guard: guardClosed, closedProps } = useStoreClosed();
  const isHydrated = useIsHydrated();
  const isMobileScreen = useHydratedMediaQuery("(max-width: 765px)");
  const canHoverZoom = useHydratedMediaQuery("(min-width: 1024px)");

  const dispatch = useDispatch();
  const router = useRouter();
  const { run: runNavClick } = useNavClick();
  const params = useParams();
  const slug = params?.slug;
  const pathname = usePathname();
  const city = useSelector((state: any) => state.City.city);
  const cityStatus = useSelector((state: any) => state.City.status);
  const shopMode = useSelector((state: any) => state.ShopMode.mode);
  const setting = useSelector((state: any) => state.Setting);
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  // SSR coords/mode until hydrated, so the seeded cache entry is hit on first render.
  const queryLatitude = !isHydrated
    ? initialProductMeta?.latitude
    : city?.latitude || initialProductMeta?.latitude;
  const queryLongitude = !isHydrated
    ? initialProductMeta?.longitude
    : city?.longitude || initialProductMeta?.longitude;
  const queryShopMode = isHydrated
    ? shopMode
    : (initialProductMeta?.shopMode ?? shopMode);
  const dir = useDir();
  const cart = useSelector((state: any) => state.Cart);
  const user = useSelector((state: any) => state.User);
  const favoriteProductIds = useSelector(
    (state: any) => state.Favorite.favouriteProductIds,
  );
  const favoriteProductIdsRef = useRef(favoriteProductIds);
  useEffect(() => {
    favoriteProductIdsRef.current = favoriteProductIds;
  }, [favoriteProductIds]);
  const [isMobileDevice, setIsMobileDevice] = useState(false);
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- reads the isMobile query param on mount, client-only by design
    setIsMobileDevice(
      new URLSearchParams(window.location.search).get("isMobile") === "true",
    );
  }, []);

  const [product, setProduct] = useState<any>(initialProduct?.data ?? []);
  const [selectVariant, setSelectedVariant] = useState<any>(
    initialProduct?.data?.variants?.[0] ?? null,
  );
  const pickPreselectedVariant = (variants: any) => {
    const list = Array.isArray(variants) ? variants : [];
    return list.length ? list[0] : undefined;
  };

  const [ratingData, setRatingData] = useState<any>({});
  const [quantity, setQuantity] = useState(1);
  // Food product with questions: the sheet collects the answers and makes the
  // add call itself, so this page never adds such a product directly.
  const [showAddons, setShowAddons] = useState(false);
  // Buy Now on a food product can only leave for the cart once the sheet has
  // actually added the line, so the intent is remembered until then.
  const [addonIntent, setAddonIntent] = useState<"cart" | "buy">("cart");
  // "+" asks whether to reuse the last picks; "-" asks which line to take from
  // when the dish sits in the cart more than once.
  const [showAddonRepeat, setShowAddonRepeat] = useState(false);
  const [showAddonLines, setShowAddonLines] = useState(false);
  const [pincodeBlock, setPincodeBlock] = useState<PincodeBlock>(null);
  const [productImages, setProductImages] = useState<any[]>([]);
  const [selectedImage, setSelectedImage] = useState("");
  const [isShareOpen, setIsShareOpen] = useState(false);
  const [isVariantAvailable, setIsVariantAvailable] = useState(false);
  const [isNotifyRequested, setIsNotifyRequested] = useState(
    !!selectVariant?.is_notify_requested,
  );
  const [notifyLoading, setNotifyLoading] = useState(false);
  const [productNotAvailable, setProductNotAvailable] = useState(false);
  const [notDeliverableMessage, setNotDeliverableMessage] = useState<
    string | null
  >(null);
  const [recentlyVisitedProduct, setRecentlyVisitedProduct] = useState<any[]>(
    [],
  );

  const shortDescRef = useRef<HTMLParagraphElement>(null);
  const recommendationsRef = useRef<HTMLDivElement>(null);
  const cartActionsRef = useRef<HTMLDivElement>(null);
  const [isShortDescClamped, setIsShortDescClamped] = useState(false);
  // Set on first Add/+/- click so the stepper doesn't animate on load.
  const [qtyAnim, setQtyAnim] = useState(false);

  const ratingsCount = 10;

  const handleAddRecentlyViewedProduct = async (product: any) => {
    try {
      if (user?.jwtToken) {
        await api.addRecentlyViewedProduct({
          productId: product?.id,
          latitude: city?.latitude,
          longitude: city?.longitude,
        });
      }
    } catch (error) {
      console.log("Error", error);
    }
  };

  const handleFetchRecentlyViewedProducts = async (product: any) => {
    try {
      if (user?.jwtToken) {
        const res = await api.getRecentlyViewedProducts({
          productId: product?.id,
          latitude: city?.latitude,
          longitude: city?.longitude,
        });
        if (res.status == 1) {
          const list = Array.isArray(res?.data)
            ? res.data
                .filter((p) => p?.id !== product?.id)
                .map((p) => ({
                  ...p,
                  image_url:
                    p?.image_url ||
                    p?.images?.[0]?.image_url ||
                    p?.variants?.[0]?.image ||
                    "",
                }))
            : [];
          setRecentlyVisitedProduct(list);
        } else {
          setRecentlyVisitedProduct([]);
        }
      }
    } catch (error) {
      console.log("Error", error);
    }
  };

  const {
    isLoading: queryLoading,
    data: productResponse,
    isError,
  } = useQuery({
    queryKey: productKey({
      slug,
      latitude: queryLatitude,
      longitude: queryLongitude,
      shopMode: queryShopMode,
    }),
    queryFn: async () => {
      try {
        const res = await api.getProductById({
          slug: slug,
          latitude: city.latitude,
          longitude: city.longitude,
          id: -1,
        });
        return res;
      } catch (err) {
        console.error("API Crash:", err);
        throw err;
      }
    },
    enabled: !!slug && !!queryLatitude,
    staleTime: 1000 * 60 * 5,
    retry: 1,
  });

  useEffect(() => {
    if (productResponse) {
      const res = productResponse;
      if (res.status == 1) {
        // eslint-disable-next-line react-hooks/set-state-in-effect -- syncs local product state from the react-query response
        setProductNotAvailable(false);
        setNotDeliverableMessage(null);
        setProduct(res?.data);
        setSelectedVariant(
          pickPreselectedVariant(res?.data?.variants) ??
            res?.data?.variants?.[0],
        );
        {
          const productId = res?.data?.id;
          const isFavorite = !!res?.data?.is_favorite;
          if (productId != null) {
            const ids = favoriteProductIdsRef.current || [];
            const alreadyIn = ids.some((id: any) => id == productId);
            if (isFavorite && !alreadyIn) {
              dispatch(setFavoriteProductIds({ data: [...ids, productId] }));
            } else if (!isFavorite && alreadyIn) {
              dispatch(
                setFavoriteProductIds({
                  data: ids.filter((id: any) => id != productId),
                }),
              );
            }
          }
        }
        dispatch(setIsRefetch());
      } else if (/not deliverable/i.test(res?.message || "")) {
        setNotDeliverableMessage(res?.message);
        setProductNotAvailable(false);
      } else {
        setProductNotAvailable(true);
        setNotDeliverableMessage(null);
      }
    }
  }, [productResponse, dispatch]);

  const didPreselectRef = useRef(false);
  useEffect(() => {
    didPreselectRef.current = false;
  }, [product?.id]);
  useEffect(() => {
    if (!product?.id || didPreselectRef.current) return;
    const match = pickPreselectedVariant(product?.variants);
    if (match) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- default-selects the first variant once the product loads
      setSelectedVariant(match);
      didPreselectRef.current = true;
    }
  }, [product?.id, product?.variants]);

  useEffect(() => {
    if (!product?.id || !user?.jwtToken) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- clears the recently-viewed list when signed out
      setRecentlyVisitedProduct([]);
      return;
    }
    handleAddRecentlyViewedProduct(product);
    handleFetchRecentlyViewedProducts(product);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [product?.id, user?.jwtToken, city?.latitude, city?.longitude]);

  const toImageUrl = (img) => (typeof img === "string" ? img : img?.image_url);

  useEffect(() => {
    if (!product?.id) return;
    const variantImages = (selectVariant?.images || [])
      .map(toImageUrl)
      .filter(Boolean);
    const baseImages = [
      product?.image_url,
      ...(product?.images || []).map(toImageUrl),
    ].filter(Boolean);
    const gallery = variantImages.length ? variantImages : baseImages;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- rebuilds the image gallery from the selected variant/product
    setProductImages(gallery);
    setSelectedImage(gallery[0] || product?.image_url || "");
  }, [product, selectVariant]);

  useEffect(() => {
    const el = shortDescRef.current;
    if (!el) return;
    const check = () =>
      setIsShortDescClamped(el.scrollHeight > el.clientHeight + 1);
    check();
    window.addEventListener("resize", check);
    return () => window.removeEventListener("resize", check);
  }, [product?.short_description]);

  const getVariantLabel = (variant) => {
    if (variant?.measurement) {
      const unit =
        variant?.unit?.translations?.short_code ??
        variant?.unit?.short_code ??
        "";
      return `${variant.measurement} ${unit}`.trim();
    }
    if (Array.isArray(variant?.attributes) && variant.attributes.length) {
      return variant.attributes
        .map((a) => `${a?.attribute_value} ${a?.attribute_name}`.trim())
        .join(", ");
    }
    return variant?.name ?? "";
  };

  const displayName =
    selectVariant?.translations?.name ??
    selectVariant?.name ??
    product?.translations?.name ??
    product?.name;

  const isColorAxis = (axis) => /colou?r/i.test(axis?.attribute_name || "");

  const selectedAxisValue = (attrId) =>
    selectVariant?.attributes?.find((a) => a.attribute_id === attrId)
      ?.attribute_value_id;

  const findVariantForAxis = (attrId, valueId) => {
    const desired = {};
    (selectVariant?.attributes || []).forEach(
      (a) => (desired[a.attribute_id] = a.attribute_value_id),
    );
    desired[attrId] = valueId;
    const ids = Object.keys(desired).map(Number);
    return product?.variants?.find((v) =>
      ids.every((id) =>
        v.attributes?.some(
          (a) => a.attribute_id === id && a.attribute_value_id === desired[id],
        ),
      ),
    );
  };

  const isAxisValueAvailable = (attrId, valueId) => {
    const variant = findVariantForAxis(attrId, valueId);
    if (!variant) return false;
    if (variant?.status == 0) return false;
    if (product?.is_unlimited_stock == 0 && Number(variant?.stock) <= 0) {
      return false;
    }
    return true;
  };

  const handleSelectAxis = (attrId, valueId) => {
    const match = findVariantForAxis(attrId, valueId);
    if (match) handleChangeVariant(match);
  };

  const handleIsVariantAvailable = useCallback(() => {
    if (
      (product?.is_unlimited_stock == 0 && selectVariant?.stock <= 0) ||
      selectVariant?.status == 0
    ) {
      setIsVariantAvailable(false);
    } else {
      setIsVariantAvailable(true);
    }
  }, [product, selectVariant]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- recomputes availability when the product/selected variant changes
    handleIsVariantAvailable();
  }, [handleIsVariantAvailable]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- syncs local toggle from the newly selected variant's own flag
    setIsNotifyRequested(!!selectVariant?.is_notify_requested);
  }, [selectVariant?.id, selectVariant?.is_notify_requested]);

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

  const { data: ratingResponse } = useQuery({
    queryKey: ["product-ratings", product?.id],
    queryFn: () =>
      api.getProductRatings({
        id: product?.id,
        limit: ratingsCount,
        offset: 0,
      }),
    enabled: !!product?.id,
    staleTime: 1000 * 60 * 10,
  });

  useEffect(() => {
    if (ratingResponse?.data) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- syncs local rating state from the react-query response
      setRatingData(ratingResponse.data);
    }
  }, [ratingResponse]);
  const { currency, currencyCode, decimals: decimalPoint } = useCurrency();

  // GA4 view_item — once per product, after its data lands.
  const viewTrackedRef = useRef<string | null>(null);
  useEffect(() => {
    const id = product?.id ? String(product.id) : null;
    if (!id || viewTrackedRef.current === id) return;
    viewTrackedRef.current = id;
    trackViewItem(toGaItem(product), currencyCode);
  }, [product, currencyCode]);

  const quickDeliveryTime =
    setting?.setting?.web_settings?.delivery_time ||
    setting?.setting?.delivery_time ||
    10;
  const hasLocation = cityStatus === "fulfill";
  const showQuickDelivery = isHydrated && shopMode === "quick" && hasLocation;
  const deliveryLabel =
    selectVariant?.time_to_deliver ||
    product?.time_to_deliver ||
    `${t("delivery_in")} ${quickDeliveryTime} ${t("minutes")}`;

  const handleChangeVariant = (variant) => {
    setQuantity(1);
    setSelectedVariant(variant);
  };
  const calculateDiscount = (discountPrice, actualPrice) => {
    const difference = actualPrice - discountPrice;
    const actualDiscountPrice = difference / actualPrice;
    return actualDiscountPrice * 100;
  };

  const variantCartQty =
    (cart?.isGuest ? cart?.guestCart : cart?.cartProducts)?.find(
      (prdct) =>
        prdct?.product_id == product?.id &&
        prdct?.product_variant_id == selectVariant?.id,
    )?.qty || 0;

  const serverAddToCart = async (qty, ctx) => {
    try {
      const response = await api.addToCart({
        product_id: product?.id,
        product_variant_id: selectVariant?.id,
        qty: Number(qty),
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      if (ctx?.isStale?.()) return;
      if (response.status == 1) {
        const serverCart = response?.data?.cart?.map((item) => ({
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

  const serverRemoveFromCart = async (units = 1, ctx) => {
    try {
      const response = await api.removeFromCart({
        product_id: product?.id,
        product_variant_id: selectVariant?.id,
        qty: units,
      });
      if (ctx?.isStale?.()) return;
      const alreadyGone =
        response?.status != 1 &&
        /not found|no item/i.test(response?.message || "");
      if (response?.status == 1 || alreadyGone) {
        const serverCart = response?.data?.cart?.map((item) => ({
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

  const stepperMaxQty = getMaxAddableQuantity({
    maxCartItemsCount: setting?.setting?.max_cart_items_count,
    otherLinesQty:
      getCartTotalQuantity(cart?.cartProducts) - (variantCartQty || 0),
    totalAllowedQty: product?.total_allowed_quantity,
    isUnlimitedStock: selectVariant?.is_unlimited_stock != 0,
    stock: selectVariant?.stock,
  });

  const guestStepperMaxQty = getMaxAddableQuantity({
    maxCartItemsCount: setting?.setting?.max_cart_items_count,
    otherLinesQty:
      getCartTotalQuantity(cart?.guestCart) - (variantCartQty || 0),
    totalAllowedQty: product?.total_allowed_quantity,
    isUnlimitedStock: selectVariant?.is_unlimited_stock != 0,
    stock: selectVariant?.stock,
  });

  const {
    displayQty: serverDisplayQty,
    increment: serverIncrement,
    decrement: serverDecrement,
  } = useDebouncedQuantity({
    serverQty: variantCartQty || 0,
    onCommit: (qty, ctx) => serverAddToCart(qty, ctx),
    onRemove: (units = 1, ctx) => serverRemoveFromCart(units, ctx),
    max: Number.isFinite(stepperMaxQty) ? stepperMaxQty : undefined,
    onMax: () =>
      toast.error(t("max_cart_limit_error"), {
        toastId: "max_cart_limit_error",
      }),
  });

  const isAddonProduct = hasAddonGroups(product);
  // Every cart line of this dish, whatever its picks, and the total across them.
  const addonLines = isAddonProduct ? productCartLines(cart, product?.id) : [];
  const addonQty = isAddonProduct ? productCartQty(cart, product?.id) : 0;
  const lastAddonLine = addonLines[addonLines.length - 1];

  const repeatAddonLine = async (line: any) => {
    if (!line) return;
    if (cart?.isGuest) {
      const updated = (cart?.guestCart ?? []).map((row: any) =>
        row?.product_variant_id == line?.product_variant_id &&
        row?.addon_fingerprint === line?.addon_fingerprint
          ? { ...row, qty: (Number(row?.qty) || 0) + 1 }
          : row,
      );
      dispatch(addtoGuestCart({ data: updated }));
      handleCalculateTotal(updated);
      return;
    }
    try {
      const response = await api.addToCart({
        product_id: product?.id,
        product_variant_id: line?.product_variant_id,
        qty: (Number(line?.qty) || 0) + 1,
        latitude: city?.latitude,
        longitude: city?.longitude,
        addons: lineAddonPayload(line),
      });
      if (response?.status == 1) {
        const serverCart = response?.data?.cart?.map((item) => ({
          product_id: item?.id,
          product_variant_id: item?.variant_id,
          addons: item?.addons ?? [],
          qty: item?.variants?.[0]?.quantity ?? item?.quantity,
        }));
        dispatch(setCart({ data: response }));
        dispatch(setCartProducts({ data: serverCart ?? [] }));
        dispatch(setCartSubTotal({ data: response?.data?.sub_total }));
      } else {
        toast.error(response?.message);
      }
    } catch (error) {
      console.log("error", error);
    }
  };

  const removeAddonLine = async (line: any) => {
    if (!line) return;
    if (cart?.isGuest) {
      const updated = (cart?.guestCart ?? [])
        .map((row: any) =>
          row?.product_variant_id == line?.product_variant_id &&
          row?.addon_fingerprint === line?.addon_fingerprint
            ? { ...row, qty: (Number(row?.qty) || 0) - 1 }
            : row,
        )
        .filter((row: any) => (Number(row?.qty) || 0) > 0);
      dispatch(addtoGuestCart({ data: updated }));
      handleCalculateTotal(updated);
      return;
    }
    try {
      const response = await api.removeFromCart({
        product_id: product?.id,
        product_variant_id: line?.product_variant_id,
        qty: 1,
        addons: lineAddonPayload(line),
      });
      const alreadyGone =
        response?.status != 1 &&
        /not found|no item/i.test(response?.message || "");
      if (response?.status == 1 || alreadyGone) {
        const serverCart = response?.data?.cart?.map((item) => ({
          product_id: item?.id,
          product_variant_id: item?.variant_id,
          addons: item?.addons ?? [],
          qty: item?.variants?.[0]?.quantity ?? item?.quantity,
        }));
        dispatch(setCartSubTotal({ data: response?.data?.sub_total ?? 0 }));
        dispatch(setCartProducts({ data: serverCart ?? [] }));
      } else {
        toast.error(response?.message);
      }
    } catch (error) {
      console.log("error", error);
    }
  };

  // An addon dish counts every line of itself, so the stepper reads as one
  // dish count rather than one line's.
  const stepperQty = isAddonProduct
    ? addonQty
    : cart?.isGuest
      ? variantCartQty
      : serverDisplayQty;
  const showCartStepper = stepperQty > 0;
  const stepperAtMax = isAddonProduct
    ? false
    : cart?.isGuest
    ? stepperQty >= guestStepperMaxQty
    : stepperQty >= stepperMaxQty;

  const handleStepperAdd = () => {
    setQuantity(1);
    // Both branches below add a line directly, so the addon gate has to come
    // first — serverIncrement would otherwise post /cart/add with no addons.
    if (hasAddonGroups(product)) {
      setAddonIntent("cart");
      setShowAddons(true);
      return;
    }
    if (cart?.isGuest) {
      handleAddToCart();
    } else {
      serverIncrement();
    }
    setTimeout(() => {
      recommendationsRef.current?.scrollIntoView({
        behavior: "smooth",
        block: "start",
      });
    }, 350);
  };

  const handleGuestStepperIncrease = () => {
    if (
      selectVariant?.is_unlimited_stock == 0 &&
      variantCartQty >= Number(selectVariant?.stock)
    ) {
      toast.error(t("out_of_stock_message"), {
        toastId: "out_of_stock_message",
      });
      return;
    }
    if (hasReachedAllowedQty(variantCartQty, product?.total_allowed_quantity)) {
      toast.error(t("max_cart_limit_error"), {
        toastId: "max_cart_limit_error",
      });
      return;
    }
    const maxAddable = getMaxAddableQuantity({
      maxCartItemsCount: setting?.setting?.max_cart_items_count,
      otherLinesQty:
        getCartTotalQuantity(cart?.guestCart) - (variantCartQty || 0),
      totalAllowedQty: product?.total_allowed_quantity,
      isUnlimitedStock: selectVariant?.is_unlimited_stock != 0,
      stock: selectVariant?.stock,
    });
    if (variantCartQty >= maxAddable) {
      toast.error(t("max_cart_limit_error"));
      return;
    }
    const updatedProducts = cart?.guestCart?.map((cartProduct) =>
      cartProduct?.product_id == product?.id &&
      cartProduct?.product_variant_id == selectVariant?.id
        ? { ...cartProduct, qty: Number(cartProduct?.qty) + 1 }
        : cartProduct,
    );
    dispatch(addtoGuestCart({ data: updatedProducts }));
    handleCalculateTotal(updatedProducts);
  };

  const handleGuestStepperDecrease = () => {
    if (variantCartQty <= 1) {
      const remaining = cart?.guestCart?.filter(
        (cartProduct) =>
          !(
            cartProduct?.product_id == product?.id &&
            cartProduct?.product_variant_id == selectVariant?.id
          ),
      );
      dispatch(addtoGuestCart({ data: remaining }));
      handleCalculateTotal(remaining);
      return;
    }
    const updatedProducts = cart?.guestCart?.map((cartProduct) =>
      cartProduct?.product_id == product?.id &&
      cartProduct?.product_variant_id == selectVariant?.id
        ? { ...cartProduct, qty: Number(cartProduct?.qty) - 1 }
        : cartProduct,
    );
    dispatch(addtoGuestCart({ data: updatedProducts }));
    handleCalculateTotal(updatedProducts);
  };

  // Opening the sheet in the same tick as closing a prompt leaves Radix's old
  // overlay over a page with no panel. Open partway through its 200ms exit.
  const openAddonSheetAfterClose = () => {
    setShowAddonRepeat(false);
    setShowAddonLines(false);
    setAddonIntent("cart");
    setTimeout(() => setShowAddons(true), 120);
  };

  const handleStepperIncrease = () => {
    if (isAddonProduct) {
      if (addonLines.length > 0) setShowAddonRepeat(true);
      else setShowAddons(true);
      return;
    }
    if (cart?.isGuest) {
      handleGuestStepperIncrease();
    } else {
      serverIncrement();
    }
  };

  const handleStepperDecrease = () => {
    if (isAddonProduct) {
      if (addonLines.length > 1) setShowAddonLines(true);
      else if (addonLines.length === 1) removeAddonLine(addonLines[0]);
      return;
    }
    if (cart?.isGuest) {
      handleGuestStepperDecrease();
    } else {
      serverDecrement();
    }
  };

  const handleCalculateTotal = (products) => {
    const total = products.reduce((prev, curr) => {
      prev += curr.productPrice * curr.qty;
      return prev;
    }, 0);
    dispatch(setGuestCartTotal({ data: total }));
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

  const handleAddToCart = async () => {
    if (hasAddonGroups(product)) {
      setAddonIntent("cart");
      setShowAddons(true);
      return;
    }
    let productQuantity = cart?.isGuest
      ? getProductQuantities(cart?.guestCart)
      : getProductQuantities(cart?.cartProducts);
    const isExisting = cart.guestCart.some(
      (cartProduct) =>
        cartProduct?.product_id == product?.id &&
        cartProduct?.product_variant_id == selectVariant?.id,
    );
    const productQty = productQuantity?.find(
      (prdct) => prdct?.product_id == product?.id,
    )?.qty;
    const cartProductQty = cart.cartProducts.find(
      (prdct) =>
        prdct?.product_id == product?.id &&
        selectVariant?.id == prdct?.product_variant_id,
    );
    const totalQty = productQty ? productQty + quantity : quantity;
    if (Number(product?.is_unlimited_stock) == 0 && selectVariant?.stock <= 0) {
      toast.error(t("out_of_stock_message"), {
        toastId: "out_of_stock_message",
      });
      return;
    }
    if (cart?.isGuest) {
      const maxAddable = getMaxAddableQuantity({
        maxCartItemsCount: setting?.setting?.max_cart_items_count,
        otherLinesQty:
          getCartTotalQuantity(cart?.guestCart) - (productQty || 0),
        totalAllowedQty: product?.total_allowed_quantity,
        isUnlimitedStock: selectVariant?.is_unlimited_stock != 0,
        stock: selectVariant?.stock,
      });
      if (exceedsAllowedQty(totalQty, product?.total_allowed_quantity)) {
        toast.error(t("max_cart_limit_error"), {
          toastId: "max_cart_limit_error",
        });
      } else if (totalQty > maxAddable) {
        toast.error(t("max_cart_limit_error"), {
          toastId: "max_cart_limit_error",
        });
      } else {
        if (isExisting) {
          const updatedProduct = cart.guestCart?.map((cartProduct) => {
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
          dispatch(addtoGuestCart({ data: [...cart?.guestCart, productData] }));
          let products = [...cart.guestCart, productData];
          handleCalculateTotal(products);
          setQuantity(1);
          toast.success(t("product_added_successfully"));
        }
      }
    } else {
      try {
        const effectiveMaxQty = getMaxAddableQuantity({
          maxCartItemsCount: setting?.setting?.max_cart_items_count,
          otherLinesQty:
            getCartTotalQuantity(cart?.cartProducts) - (productQty || 0),
          totalAllowedQty: product?.total_allowed_quantity,
          isUnlimitedStock: Number(product?.is_unlimited_stock) != 0,
          stock: selectVariant?.stock,
        });
        if (exceedsAllowedQty(totalQty, product?.total_allowed_quantity)) {
          toast.error(t("max_cart_limit_error"), {
            toastId: "max_cart_limit_error",
          });
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
              const updatedProducts = cart.cartProducts.map((cartProduct) => {
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
          } else if (response?.message == "opps_stock_is_not_available") {
            toast.error(t("out_of_stock_message"));
          } else {
            toast.error(response?.message);
          }
        }
      } catch (error) {
        console.log("Error", error);
      }
    }
  };

  const {
    liked: isFavorite,
    toggle: handleProductLikes,
    canToggle: canToggleFavorite,
  } = useFavoriteToggle({
    productId: product?.id,
  });

  const handleChangeCoverImage = (image) => {
    setSelectedImage(image);
  };

  const handleBuyNow = () => {
    // The sheet owns the add call, so leaving for the cart waits for onAdded.
    if (hasAddonGroups(product)) {
      setAddonIntent("buy");
      setShowAddons(true);
      return;
    }
    runNavClick(async () => {
      await handleAddToCart();
      router.push(zoneHref("/cart"));
    });
  };

  const activeBlock =
    product?.pincode_check_available == 1 ? pincodeBlock : null;
  const guardBuy = <A extends any[]>(handler: (...args: A) => any) =>
    guardClosed((...args: A) => {
      if (activeBlock) {
        toast.error(
          activeBlock.message || t("not_deliverable") || "Not deliverable",
        );
        return;
      }
      return handler(...args);
    });
  const blockedCls = activeBlock ? "opacity-50 cursor-not-allowed" : "";

  const hasDiscount =
    selectVariant?.discounted_price !== 0 &&
    selectVariant?.discounted_price !== selectVariant?.price;
  const displayPrice = hasDiscount
    ? selectVariant?.discounted_price
    : selectVariant?.price;
  // Keep the API's own decimals ("120.25" vs "120") while counting.
  const displayPriceDecimals = (String(displayPrice ?? "").split(".")[1] || "")
    .length;
  const discountLabel = hasDiscount
    ? `${calculateDiscount(
        selectVariant?.discounted_price,
        selectVariant?.price,
      ).toFixed(decimalPoint)}% ${t("off")}`
    : null;

  const brandId = product?.brand_id ?? product?.brand?.id;
  const handleBrandNavigation = () => {
    if (!brandId) return;
    dispatch(clearAllFilter());
    dispatch(setListingSource({ data: "all" }));
    const dest = zoneHref("/products");
    const qs = new URLSearchParams({
      brand: String(parseInt(brandId)),
    }).toString();
    runNavClick(() => router.push(`${dest}?${qs}`));
  };

  if (queryLoading) {
    return (
      <section>
        <div className="h-[100vh]">
          <Loader screen="full" />
        </div>
      </section>
    );
  }

  if (notDeliverableMessage) {
    return (
      <section>
        <div className="h-full w-full flex flex-col items-center gap-3 my-4">
          <ThemedSvg
            src={ProductNotFoundImage}
            alt={"not deliverable here"}
            className="w-full max-w-[400px]"
          />
          <p className="text-2xl font-bold text-center max-w-md">
            {t("not_deliverable_in_this_mode") ||
              "This product isn't available in Shop All at your current location. Try switching back to Quick."}
          </p>
          <button
            type="button"
            onClick={() => dispatch(setShopMode({ mode: "quick" }))}
            className="px-4 py-2 rounded-md font-medium primaryBackColor text-white"
          >
            {t("switch_to_quick") || "Switch to Quick"}
          </button>
        </div>
      </section>
    );
  }

  if (isError || productNotAvailable == true) {
    return (
      <section>
        <div className="h-full w-full flex flex-col items-center my-4">
          <ThemedSvg
            src={ProductNotFoundImage}
            alt={"not product found"}
            className="w-full max-w-[400px]"
          />
          <p className="text-3xl font-bold w-1/3 text-center">
            {t("oops")} {t("product_is_either_unavailable_or_does_not_exist")}
          </p>
          <Link
            href={"/"}
            className="px-4 py-2 rounded-md font-medium primaryBackColor text-white"
          >
            {t("go_back")}
          </Link>
        </div>
      </section>
    );
  }

  const cartActions = isVariantAvailable ? (
    <div className="flex w-full max-w-[360px] items-center gap-2">
      {showCartStepper ? (
        <button
          type="button"
          onClick={guardClosed(handleStepperDecrease)}
          {...closedProps}
          className={`flex h-10 flex-1 items-center justify-center gap-2 rounded-lg border primaryBorder primaryBackColor text-[13px] font-semibold text-white ${closedProps.className ?? ""}`}
        >
          <FiMinus /> Remove from cart
        </button>
      ) : (
        <button
          type="button"
          // eslint-disable-next-line react-hooks/refs -- handleStepperAdd only reads recommendationsRef.current inside a later setTimeout callback, not during render
          onClick={guardBuy(handleStepperAdd)}
          onClickCapture={(e) => {
            setQtyAnim(true);
            // Nothing reaches the cart yet when the addon sheet opens.
            if (!storeClosed && !activeBlock && !hasAddonGroups(product))
              flyToCart(e.currentTarget, "[data-fly-image]");
          }}
          {...closedProps}
          className={`flex h-10 flex-1 items-center justify-center gap-2 whitespace-nowrap rounded-lg border primaryBorder primaryColor dark:text-white dark:border-white/40 text-[13px] font-semibold transition hover:primaryBackColor hover:text-white hover:border-transparent ${closedProps.className ?? ""} ${blockedCls}`}
        >
          <MdAddShoppingCart size={16} />
          {t("add_to_cart")}
        </button>
      )}
      <button
        type="button"
        onClick={guardBuy(handleBuyNow)}
        {...closedProps}
        className={`flex h-10 flex-1 items-center justify-center whitespace-nowrap rounded-lg primaryBackColor text-[13px] font-semibold text-white transition hover:opacity-90 ${closedProps.className ?? ""} ${blockedCls}`}
      >
        {t("buy_now")}
      </button>
    </div>
  ) : (
    <div className="flex flex-wrap items-center gap-2.5">
      <div className="inline-flex h-10 w-fit items-center gap-2 rounded-lg border border-[#db3d26]/30 bg-[#db3d26]/10 px-4 text-sm font-semibold text-[#db3d26]">
        <MdRemoveShoppingCart size={16} />
        {t("out_of_stock")}
      </div>
      <BellToggle
        pressed={isNotifyRequested}
        onChange={handleToggleNotify}
        offLabel={t("notify_me") || "Notify Me"}
        onLabel={t("notify_requested") || "Notified"}
        height={40}
        radius={8}
        background="var(--primary-color)"
        color="#ffffff"
        onBackground="color-mix(in srgb, var(--primary-color) 10%, transparent)"
        onColor="var(--primary-color)"
        badge={false}
      />
    </div>
  );

  return (
    <section>
      <div className="hidden md:block">
        <BreadCrumb
          title={product?.translations?.name ?? product?.name}
          categoryId={product?.category_id ?? product?.category?.id}
          categorySlug={product?.category_slug ?? product?.category?.slug}
        />
      </div>
      <div className="container mb-6">
        <div className="md:mt-1">
          <div className="flex flex-col justify-center">
            <div className="grid grid-cols-1 lg:grid-cols-12 md:mt-2 gap-4 max-md:gap-2 items-start">
              <div className="relative z-20 col-span-12 lg:col-span-6 flex flex-col gap-4 lg:sticky lg:top-[120px] lg:self-start">
                <div className="md:hidden">
                  <MobileProductGallery
                    product={product}
                    productImages={productImages}
                    onSelectImage={handleChangeCoverImage}
                    isFavorite={isFavorite}
                    onToggleFavorite={
                      handleProductLikes as (e: React.MouseEvent) => void
                    }
                    canToggleFavorite={canToggleFavorite}
                    onShare={() => setIsShareOpen(true)}
                    rating={
                      product?.product_rating == true
                        ? ratingData?.average_rating
                        : undefined
                    }
                    ratingCount={product?.rating_count}
                  />
                </div>
                <div className="hidden md:block">
                  <ProductImageGallery
                    product={product}
                    productImages={productImages}
                    selectedImage={selectedImage}
                    onSelectImage={handleChangeCoverImage}
                    canHoverZoom={canHoverZoom}
                    isFavorite={isFavorite}
                    onToggleFavorite={
                      handleProductLikes as (e: React.MouseEvent) => void
                    }
                    canToggleFavorite={canToggleFavorite}
                    onShare={() => setIsShareOpen(true)}
                  />
                </div>
              </div>
              <div className="col-span-12 lg:col-span-6">
                <div className="relative flex flex-col gap-2 md:gap-3">
                  <h1 className="text-lg leading-snug md:pe-12 md:text-3xl font-bold md:leading-tight">
                    {displayName}
                  </h1>

                  {product?.brand_name && (
                    <div className="flex items-center gap-1.5 text-xs md:text-sm">
                      <span className="text-gray-500 dark:text-zinc-400">
                        {t("brand")}
                      </span>
                      {brandId ? (
                        <button
                          type="button"
                          onClick={handleBrandNavigation}
                          className="font-semibold primaryColor hover:underline"
                        >
                          {product?.brand_name}
                        </button>
                      ) : (
                        <span className="font-semibold primaryColor">
                          {product?.brand_name}
                        </span>
                      )}
                    </div>
                  )}

                  {product?.product_rating == true &&
                    (ratingData?.average_rating > 0 ||
                      product?.rating_count > 0) && (
                      <div className="flex items-center gap-2 text-xs md:text-sm text-gray-500 dark:text-zinc-400">
                        <div className="flex">
                          {[1, 2, 3, 4, 5].map((star) => {
                            const roundedRating =
                              Math.round(
                                (ratingData?.average_rating || 0) * 2,
                              ) / 2;
                            if (star <= Math.floor(roundedRating)) {
                              return (
                                <FaStar
                                  key={star}
                                  size={16}
                                  className="fill-yellow-400 text-yellow-400"
                                />
                              );
                            } else if (
                              star === Math.floor(roundedRating) + 1 &&
                              roundedRating % 1 === 0.5
                            ) {
                              return (
                                <FaStarHalfAlt
                                  key={star}
                                  size={16}
                                  className="fill-yellow-400 text-yellow-400"
                                />
                              );
                            }
                            return (
                              <FaStar
                                key={star}
                                size={16}
                                className="fill-gray-200 text-gray-200"
                              />
                            );
                          })}
                        </div>
                        <span className="font-bold text-gray-900 dark:text-zinc-100">
                          {(ratingData?.average_rating || 0).toFixed(0)}
                          <span className="font-normal text-gray-400 dark:text-zinc-500">
                            /5.0
                          </span>
                        </span>
                        <span className="text-gray-500 dark:text-zinc-400">
                          ({product?.rating_count || 0} {t("reviews")})
                        </span>
                      </div>
                    )}

                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <PriceFlip
                      flipKey={selectVariant?.id}
                      className="flex flex-wrap items-baseline gap-x-2 gap-y-1 sm:gap-3"
                    >
                      <span className="text-xl md:text-3xl font-extrabold tracking-tight text-gray-900 dark:text-zinc-100">
                        <AnimatedNumber
                          value={displayPrice}
                          format={(v) =>
                            `${currency}${v.toFixed(displayPriceDecimals)}`
                          }
                        />
                      </span>
                      {hasDiscount && (
                        <span className="text-sm md:text-lg font-medium text-gray-400 dark:text-zinc-500 line-through">
                          {currency}
                          {selectVariant?.price}
                        </span>
                      )}
                      {discountLabel && (
                        <span className="whitespace-nowrap self-center rounded-md bg-green-100 px-1.5 py-0.5 text-[10px] md:px-2 md:py-1 md:text-xs font-bold uppercase text-green-700">
                          {discountLabel}
                        </span>
                      )}
                    </PriceFlip>

                    {showQuickDelivery && (
                      <div className="inline-flex w-fit items-center gap-1.5 md:gap-2 rounded-full primaryLightBack py-1 ps-1.5 pe-3 text-xs md:py-1.5 md:ps-2 md:pe-3.5 md:text-sm">
                        <span className="flex h-6 w-6 md:h-7 md:w-7 items-center justify-center rounded-full bg-white dark:bg-zinc-900 shadow-sm">
                          <TimeIcon size={16} className="primaryColor" />
                        </span>
                        <span dir="auto" className="font-bold primaryColor">
                          {deliveryLabel}
                        </span>
                      </div>
                    )}
                  </div>

                  <FewLeftBadge
                    pulse
                    variant={selectVariant}
                    product={product}
                    size={14}
                    className="!text-xs md:!text-sm !font-bold"
                  />

                  {product?.short_description && (
                    <div className="flex flex-col items-start gap-1">
                      <p
                        ref={shortDescRef}
                        className="line-clamp-3 text-sm leading-5 md:text-base md:leading-6 font-normal text-gray-600 dark:text-zinc-300"
                      >
                        {product?.short_description}
                      </p>
                      {isShortDescClamped && (
                        <TooltipProvider delayDuration={150}>
                          <Tooltip>
                            <TooltipTrigger asChild>
                              <button
                                type="button"
                                className="primaryColor text-sm font-medium underline underline-offset-2"
                              >
                                {t("view_more")}
                              </button>
                            </TooltipTrigger>
                            <TooltipContent className="max-w-sm text-gray-600 dark:text-zinc-300">
                              {product?.short_description}
                            </TooltipContent>
                          </Tooltip>
                        </TooltipProvider>
                      )}
                    </div>
                  )}

                  {product?.variants?.length > 1 &&
                    (Array.isArray(product?.variant_axes) &&
                    product.variant_axes.length ? (
                      <div className="flex flex-wrap gap-x-6 gap-y-3">
                        {product.variant_axes.map((axis) => {
                          const sel = selectedAxisValue(axis.attribute_id);
                          return (
                            <div
                              key={axis.attribute_id}
                              className="flex min-w-[120px] flex-col gap-1.5"
                            >
                              <p className="text-sm font-semibold text-gray-700 dark:text-zinc-200">
                                {axis.attribute_name}
                              </p>
                              <SlidingChipGroup
                                activeKey={sel}
                                className="flex flex-wrap gap-2"
                                indicatorClassName="rounded-lg border primaryBorder primaryLightBack dark:bg-white/10 dark:border-white"
                              >
                                {(ready) => axis.values?.map((val) => {
                                  const isSel = sel === val.attribute_value_id;
                                  const available =
                                    isSel ||
                                    isAxisValueAvailable(
                                      axis.attribute_id,
                                      val.attribute_value_id,
                                    );
                                  const swatch =
                                    val.swatch_value ||
                                    val.color ||
                                    (isColorAxis(axis)
                                      ? val.attribute_value
                                      : null);
                                  return (
                                    <button
                                      key={val.attribute_value_id}
                                      type="button"
                                      data-chip-active={isSel}
                                      disabled={!available}
                                      aria-disabled={!available}
                                      title={
                                        available
                                          ? undefined
                                          : t("not_available")
                                      }
                                      onClick={() =>
                                        handleSelectAxis(
                                          axis.attribute_id,
                                          val.attribute_value_id,
                                        )
                                      }
                                      className={`relative flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-[13px] font-medium transition ${
                                        isSel
                                          ? ready
                                            ? "border-transparent primaryColor dark:text-white"
                                            : "primaryBorder primaryLightBack primaryColor dark:bg-white/10 dark:text-white dark:border-white"
                                          : !available
                                            ? "border-gray-200 dark:border-zinc-700 text-gray-400 dark:text-zinc-600 line-through opacity-60 cursor-not-allowed"
                                            : "border-gray-200 dark:border-zinc-700 text-gray-700 dark:text-zinc-200 hover:border-gray-400"
                                      }`}
                                    >
                                      {val.attribute_value}
                                    </button>
                                  );
                                })}
                              </SlidingChipGroup>
                            </div>
                          );
                        })}
                      </div>
                    ) : (
                      <div className="flex flex-col gap-3">
                        <p className="text-base font-medium">
                          {t("chooseVariant")} :{" "}
                          <span className="font-semibold">
                            {getVariantLabel(selectVariant)}
                          </span>
                        </p>
                        <SlidingChipGroup
                          activeKey={selectVariant?.id}
                          className="flex flex-wrap gap-3"
                          indicatorClassName="rounded-full border primaryBorder primaryBackColor"
                        >
                          {(ready) =>
                            product?.variants?.map((variant) => (
                              <button
                                key={variant.id}
                                type="button"
                                data-chip-active={selectVariant?.id == variant?.id}
                                onClick={() => handleChangeVariant(variant)}
                                className={`relative rounded-full border px-5 py-2 text-sm font-medium transition duration-300 ${
                                  selectVariant?.id == variant?.id
                                    ? ready
                                      ? "border-transparent text-white"
                                      : "primaryBorder primaryBackColor text-white"
                                    : "border-[#DFE3E8] dark:border-zinc-700 text-gray-700 dark:text-zinc-200 hover:primaryBorder"
                                }`}
                              >
                                {getVariantLabel(variant)}
                              </button>
                            ))
                          }
                        </SlidingChipGroup>
                      </div>
                    ))}

                  <hr className="border-gray-200 dark:border-zinc-700 my-0.5" />

                  <div ref={cartActionsRef} className="flex flex-col gap-2">
                    <ProductPersonalise product={product} />
                    {cartActions}
                  </div>

                  {isHydrated &&
                    shopMode !== "quick" &&
                    (product?.estimated_delivery_date ||
                      product?.pincode_check_available == 1) && (
                      <div className="flex flex-col gap-3 rounded-xl border border-gray-200 dark:border-zinc-700 p-4">
                        <span className="text-xs font-bold uppercase tracking-wide text-gray-700 dark:text-zinc-200">
                          {t("delivery_options") || "Delivery Options"}
                        </span>
                        {product?.pincode_check_available == 1 ? (
                          <PincodeCheck
                            productVariantId={selectVariant?.id}
                            quantity={quantity}
                            onBlockChange={setPincodeBlock}
                            fallbackEta={product?.estimated_delivery_date}
                          />
                        ) : (
                          <EtaLine date={product?.estimated_delivery_date} />
                        )}
                      </div>
                    )}

                  <div
                    className={`flex items-stretch divide-x divide-gray-200 dark:divide-zinc-700 rounded-xl border border-gray-200 dark:border-zinc-700 py-3 ${dir === "RTL" ? "divide-x-reverse" : ""}`}
                  >
                    {(() => {
                      const typeMeta = getProductTypeMeta(
                        product?.product_type ?? product?.indicator,
                      );
                      if (!typeMeta) return null;
                      const { svg, Icon, labelKey, color } = typeMeta as any;
                      return (
                        <div className="flex flex-1 flex-col items-center justify-center gap-1.5 px-2 text-center">
                          {svg ? (
                            <span className="relative h-8 w-8">
                              <Image
                                src={svg}
                                fill
                                alt={t(labelKey)}
                                className="object-contain"
                              />
                            </span>
                          ) : (
                            <Icon className={`h-7 w-7 ${color}`} />
                          )}
                          <span className="text-[11px] font-semibold leading-tight text-gray-700 dark:text-zinc-200">
                            {t(labelKey)}
                          </span>
                        </div>
                      );
                    })()}

                    <div className="flex flex-1 flex-col items-center justify-center gap-1.5 px-2 text-center">
                      <ThemedSvg
                        src={
                          product?.cancelable_status == 1
                            ? CancelIcon
                            : NotCancelIcon
                        }
                        alt="cancelable"
                        className="h-8 w-8"
                      />
                      <span className="text-[11px] font-semibold leading-tight text-gray-700 dark:text-zinc-200">
                        {product?.cancelable_status == 1
                          ? (() => {
                              const STATUS_LABELS: Record<
                                string | number,
                                string
                              > = {
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
                              const rawTill =
                                shopMode === "quick"
                                  ? (product?.till_status_quick ?? product?.till_status)
                                  : (product?.till_status_ecommerce ?? product?.till_status);
                              const tillValue = Number(rawTill);
                              const statusLabel =
                                STATUS_LABELS[tillValue] ||
                                STATUS_LABELS[
                                  String(rawTill || "").toLowerCase()
                                ];
                              if (tillValue > 0 && statusLabel) {
                                const prefix = t("cancelable");
                                const labelText = t(statusLabel);
                                return prefix
                                  ? `${prefix}${labelText}`.trim()
                                  : `${t("cancel_before")} ${labelText}`.trim();
                              }
                              const fallback = t("cancelable");
                              return fallback
                                ? fallback.replace(/\s+till\s*$/i, "").trim()
                                : t("cancel_before");
                            })()
                          : t("non-cancelable")}
                      </span>
                    </div>

                    <div className="flex flex-1 flex-col items-center justify-center gap-1.5 px-2 text-center">
                      <ThemedSvg
                        src={
                          product?.return_status == 1
                            ? ReturnIcon
                            : NoReturnIcon
                        }
                        alt="returnable"
                        className="h-8 w-8"
                      />
                      <span className="text-[11px] font-semibold leading-tight text-gray-700 dark:text-zinc-200">
                        {product?.return_status == 1
                          ? Number(product?.return_days) === 0
                            ? t("easy_return")
                            : `${t("returnable")} ${product?.return_days} ${Number(product?.return_days) === 1 ? t("day") : t("days")}`
                          : t("non-returnable")}
                      </span>
                    </div>

                    {product?.cod_allowed == 1 && (
                      <div className="flex flex-1 flex-col items-center justify-center gap-1.5 px-2 text-center">
                        <ThemedSvg
                          src={CodIcon}
                          alt="cash on delivery"
                          className="h-8 w-8"
                        />
                        <span className="text-[11px] font-semibold leading-tight text-gray-700 dark:text-zinc-200">
                          {t("cash_on_delivery")}
                        </span>
                      </div>
                    )}
                  </div>

                  {Number(product?.product_type) === 5 &&
                    product?.prescription_note && (
                      <div className="flex items-start gap-3 rounded-r-lg primaryColorBorder border-0 border-l-4 primaryLightBack px-4 py-3">
                        <LuPill
                          size={18}
                          className="mt-0.5 shrink-0 primaryColor"
                        />
                        <div className="flex flex-col gap-1">
                          <span className="text-xs font-bold uppercase tracking-wide primaryColor">
                            {t("prescription_required") ||
                              "Prescription Required"}
                          </span>
                          <span className="text-sm leading-relaxed text-gray-700 dark:text-zinc-200 whitespace-pre-line">
                            {product?.prescription_note?.replace(/\*\*/g, "")}
                          </span>
                        </div>
                      </div>
                    )}

                  <div
                    dir={dir === "RTL" ? "rtl" : "ltr"}
                    className="flex flex-col gap-3 text-sm"
                  >
                    {product?.category_name && (
                      <div className="flex gap-2">
                        <span className="font-semibold whitespace-nowrap text-start">
                          {t("category")} :
                        </span>
                        <span className="text-gray-600 dark:text-zinc-300">
                          {product?.category_name}
                        </span>
                      </div>
                    )}
                    {product?.tag_names && (
                      <div className="flex gap-2">
                        <span className="font-semibold whitespace-nowrap text-start">
                          {t("tag")} :
                        </span>
                        <span className="text-gray-600 dark:text-zinc-300">
                          {Array.isArray(product?.tag_names)
                            ? product.tag_names.join(", ")
                            : product?.tag_names}
                        </span>
                      </div>
                    )}
                    {product?.made_in?.name && (
                      <div className="flex gap-2">
                        <span className="font-semibold whitespace-nowrap text-start">
                          {t("made_in")} :
                        </span>
                        <span className="text-gray-600 dark:text-zinc-300">
                          {product?.made_in?.name}
                        </span>
                      </div>
                    )}
                    {product?.branch_name && (
                      <div className="flex gap-2">
                        <span className="font-semibold whitespace-nowrap text-start">
                          {t("sold_by")} :
                        </span>
                        <span className="text-gray-600 dark:text-zinc-300">
                          {product?.branch_name}
                        </span>
                      </div>
                    )}
                    {product?.manufacturer && (
                      <div className="flex gap-2">
                        <span className="font-semibold whitespace-nowrap text-start">
                          {t("manufacturer")} :
                        </span>
                        <span className="text-gray-600 dark:text-zinc-300">
                          {product?.manufacturer}
                        </span>
                      </div>
                    )}

                    {product?.fssai_lic_no && (
                      <div className="flex items-center gap-2">
                        <span className="font-semibold whitespace-nowrap text-start">
                          {t("fssai_license_no")}
                        </span>
                        {product?.fssai_lic_img && (
                          <Image
                            width={100}
                            height={100}
                            src={product?.fssai_lic_img}
                            className="w-9 h-9 object-contain"
                            alt="fssaiImage"
                          />
                        )}
                        <span className="text-gray-600 dark:text-zinc-300">
                          {product?.fssai_lic_no}
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        {Array.isArray(selectVariant?.custom_sections) &&
          selectVariant.custom_sections.length > 0 && (
            <div className="rounded-sm my-2 cardBorder p-4 flex flex-col gap-5">
              <h2 className="text-lg md:text-xl font-bold textColor">
                {t("specifications")}
              </h2>
              {selectVariant.custom_sections.map((section) => (
                <div key={section?.section_id} className="flex flex-col gap-2">
                  {section?.section_name && (
                    <h3 className="text-base font-semibold primaryColor dark:text-zinc-200">
                      {section?.section_name}
                    </h3>
                  )}
                  <div className="overflow-hidden rounded-md cardBorder">
                    {section?.fields?.map((field, index) => (
                      <div
                        key={`${section?.section_id}-${index}`}
                        className={`flex flex-col sm:flex-row sm:items-start gap-1 sm:gap-4 px-4 py-2.5 ${
                          index % 2 === 0 ? "backgroundColor" : ""
                        }`}
                      >
                        <span className="w-full sm:w-56 shrink-0 text-sm font-medium text-gray-600 dark:text-zinc-300">
                          {field?.field_label}
                        </span>
                        <span className="flex-1 min-w-0 text-sm font-semibold break-words textColor">
                          {field?.value ?? "-"}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}

        <ProductDescription product={product} ratingData={ratingData} />
        {product?.id && (
          <div ref={recommendationsRef} className="scroll-mt-28">
            <ProductRecommendations productId={product?.id} />
          </div>
        )}
        {product?.id && <SimilarProducts productId={product?.id} />}
        <RecentalyViewedProducts
          recentalyViewedProducts={recentlyVisitedProduct}
        />
      </div>
      {!isMobileDevice && (
        <StickyAddToCartBar
          targetRef={cartActionsRef}
          image={selectedImage || product?.image_url}
          name={displayName}
          price={`${currency}${hasDiscount ? selectVariant?.discounted_price : selectVariant?.price}`}
        >
          {cartActions}
        </StickyAddToCartBar>
      )}
      {isMobileScreen && isMobileDevice && <MobileBottomSheet />}
      <ShareDrawer
        open={isShareOpen}
        onClose={() => setIsShareOpen(false)}
        url={`${process.env.NEXT_PUBLIC_BASE_URL}${decodeURI(pathname)}`}
        title={displayName}
        description={product?.short_description}
        image={selectedImage || product?.image_url}
      />
      <AddonsModal
        product={product}
        showAddons={showAddons}
        setShowAddons={setShowAddons}
        variant={selectVariant}
        qty={quantity}
        onAdded={() => {
          if (addonIntent !== "buy") return;
          setAddonIntent("cart");
          runNavClick(() => router.push(zoneHref("/cart")));
        }}
      />
      <AddonRepeatModal
        open={showAddonRepeat}
        setOpen={setShowAddonRepeat}
        product={product}
        lastLine={lastAddonLine}
        onRepeat={() => repeatAddonLine(lastAddonLine)}
        onAddNew={openAddonSheetAfterClose}
      />
      <AddonLinesModal
        open={showAddonLines}
        setOpen={setShowAddonLines}
        product={product}
        lines={addonLines}
        onRemoveLine={removeAddonLine}
        onRepeatLine={repeatAddonLine}
        onAddNew={openAddonSheetAfterClose}
      />
    </section>
  );
};

export default ProductDetail;
