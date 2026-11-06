import React, { useState } from "react";
import Link from "next/link";
import { useDispatch, useSelector } from "react-redux";
import { toast } from "react-toastify";
import { BiTrash } from "react-icons/bi";
import { AiFillStar } from "react-icons/ai";
import * as api from "@/api/apiRoutes";
import { t } from "@/utils/translation";

import { formatCurrency, isVideoUrl} from "@/utils/helperFunction";
import useZoneHref from "@/hooks/useZoneHref";
import useCurrency from "@/hooks/useCurrency";
import useStoreClosed from "@/hooks/useStoreClosed";
import {
  setCart,
  setCartProducts,
  setCartSubTotal,
} from "@/redux/slices/cartSlice";
import { syncFavoriteId } from "@/redux/slices/FavoriteSlice";
import ProductTypeTag from "../productdetail/ProductTypeTag";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";

interface WishlistCardProps {
  product: any;
  setWishlistProducts: (products: any[]) => void;
  wishlistProducts: any[];
  setTotal: (updater: (prevTotal: number) => number) => void;
  handleFetchLikedProducts: () => Promise<void> | void;
}

const WishlistCard = ({
  product,
  setWishlistProducts,
  wishlistProducts,
  setTotal,
  handleFetchLikedProducts,
}: WishlistCardProps) => {
  const zoneHref = useZoneHref();
  const dispatch = useDispatch();
  const city = useSelector((state: any) => state.City.city);
  const cartProducts = useSelector((state: any) => state.Cart.cartProducts);
  const { guard: guardClosed, closedProps } = useStoreClosed();
  const [moving, setMoving] = useState(false);
  // Format currency with zone defaults
  const { currency, decimals } = useCurrency(product);
  const money = (val: number) => formatCurrency(val, currency, decimals, true);

  const handleRemoveFromWishlist = async (prdctId: number | string) => {
    try {
      const response = await api.removeFromFavorite({ product_id: prdctId });
      if (response.status == 1) {
        const updateProducts = wishlistProducts?.filter(
          (prdct) => prdct?.id != prdctId,
        );
        setWishlistProducts(updateProducts);
        setTotal((prevTotal) => prevTotal - 1);
        await handleFetchLikedProducts();
      } else {
        console.log(response.message);
      }
    } catch (error) {
      console.log("Error", error);
    }
  };

  // Move product to cart and remove from wishlist
  const handleMoveToBag = async () => {
    const variantId = product?.variants?.[0]?.id;
    if (!variantId || moving) return;
    setMoving(true);
    try {
      const existingQty = Number(
        cartProducts?.find((p: any) => p?.product_variant_id == variantId)
          ?.qty ?? 0,
      );
      const cartRes = await api.addToCart({
        product_id: product?.id,
        product_variant_id: variantId,
        qty: existingQty > 0 ? existingQty : 1,
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      if (cartRes?.status != 1) {
        toast.error(cartRes?.message);
        return;
      }
      // Update cart state from server
      const serverCart = cartRes?.data?.cart?.map((item: any) => ({
        product_id: item?.id,
        product_variant_id: item?.variant_id,
        addons: item?.addons ?? [],
        qty: item?.variants?.[0]?.quantity ?? item?.quantity,
      }));
      dispatch(setCart({ data: cartRes }));
      dispatch(setCartProducts({ data: serverCart ?? [] }));
      dispatch(setCartSubTotal({ data: cartRes?.data?.sub_total }));

      const favRes = await api.removeFromFavorite({ product_id: product?.id });
      if (favRes?.status == 1) {
        dispatch(syncFavoriteId({ id: product?.id, liked: false }));
        setWishlistProducts(
          wishlistProducts?.filter((prdct) => prdct?.id != product?.id),
        );
        setTotal((prevTotal) => prevTotal - 1);
      }
      toast.success(t("moved_to_bag") || "Moved to bag");
    } catch (error) {
      console.log("Error", error);
      toast.error(t("something_went_wrong"));
    } finally {
      setMoving(false);
    }
  };

  // Extract image and variant details
  const firstImage = product?.images?.[0];
  // A clip never shows on a card, so the first still wins.
  const imageUrl =
    [
      product?.image_url,
      typeof firstImage === "string" ? firstImage : firstImage?.image_url,
      product?.variants?.[0]?.image,
    ].find((url) => url && !isVideoUrl(url)) || "";

  const hasDiscount =
    product?.variants?.[0]?.discounted_price !== 0 &&
    product?.variants?.[0]?.discounted_price !== product?.variants?.[0]?.price;
  const variantLabel = (
    product?.variants?.[0]?.attributes_text ||
    [
      product?.variants?.[0]?.measurement,
      product?.variants?.[0]?.unit?.translations?.name ??
        product?.variants?.[0]?.stock_unit_name,
    ]
      .filter(Boolean)
      .join(" ")
  ).trim();

  const discountPercent = Number(product?.discount_percent) || null;
  const ratingValue = Number(product?.rating) || 0;
  const ratingCount = product?.rating_count;
  const inStock = product?.in_stock;
  const brandName = product?.brand_name;
  const productName = product?.translations?.name ?? product?.name;

  const displayPrice = hasDiscount
    ? product?.variants?.[0]?.discounted_price
    : product?.variants?.[0]?.price;

  return (
    <div className="group relative flex items-stretch gap-3 rounded-lg border border-gray-200 bg-white dark:bg-zinc-900 dark:border-zinc-800 p-2.5 sm:p-3 transition-all duration-200 hover:border-gray-300 hover:shadow-[0_2px_12px_rgba(0,0,0,0.06)]">
      {/* Thumbnail — small, contain (no crop) on a soft panel */}
      <Link
        href={zoneHref(`/product/${product?.slug}`)}
        prefetch={false}
        className="relative h-[72px] w-[72px] sm:h-[88px] sm:w-[88px] shrink-0 self-center overflow-hidden rounded-lg bg-[#f5f6f8] dark:bg-zinc-800"
      >
        <ImageWithPlaceholder
          className={`h-full w-full object-contain p-1.5 transition-transform duration-200 group-hover:scale-105 ${inStock ? "" : "opacity-60 grayscale"}`}
          alt={productName}
          src={imageUrl}
          width={200}
          height={200}
        />
      </Link>

      {/* One full-width column: name gets the whole row, price sits inline
          below it (a separate right-hand price column squeezed the name). */}
      <div className="flex min-w-0 flex-1 flex-col justify-center gap-1">
        <Link
          href={zoneHref(`/product/${product?.slug}`)}
          prefetch={false}
          className="flex min-w-0 flex-col gap-1 pe-7"
        >
          {brandName && (
            <span className="text-[10px] font-bold uppercase tracking-wide SecondaryTextColor leading-none">
              {brandName}
            </span>
          )}
          <h3 className="textColor text-[13px] sm:text-sm font-semibold leading-snug line-clamp-2 capitalize">
            <ProductTypeTag
              type={product?.product_type ?? product?.indicator}
              className="me-1.5 align-[-2px]"
              iconSize={14}
            />
            {productName}
          </h3>

          <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
            {variantLabel && (
              <span className="max-w-full truncate text-[11px] SecondaryTextColor">
                {variantLabel}
              </span>
            )}
            {!!product?.product_rating && Number(ratingCount) > 0 && (
              <span className="flex items-center gap-0.5 rounded bg-green-600 px-1 py-px text-[10px] font-bold text-white">
                {ratingValue}
                <AiFillStar size={8} />
              </span>
            )}
            <span
              className={`flex items-center gap-1 whitespace-nowrap text-[11px] font-medium ${
                inStock ? "text-green-600" : "text-red-500"
              }`}
            >
              <span
                className={`h-1.5 w-1.5 rounded-full ${
                  inStock ? "bg-green-500" : "bg-red-500"
                }`}
              />
              {inStock ? t("inStock") : t("OutOfStock")}
            </span>
          </div>
        </Link>

        {/* Price + Move to Bag share the last row — button outside the Link so
          clicking it doesn't navigate. */}
        <div className="mt-0.5 flex flex-wrap items-center justify-between gap-2">
          <div className="flex flex-wrap items-baseline gap-x-1.5 leading-tight">
            <span className="textColor text-[15px] sm:text-base font-bold whitespace-nowrap">
              {money(displayPrice)}
            </span>
            {hasDiscount && (
              <>
                <span className="SecondaryTextColor text-[11px] line-through whitespace-nowrap">
                  {money(product?.variants?.[0]?.price)}
                </span>
                {discountPercent && (
                  <span className="text-[11px] font-bold text-green-600 whitespace-nowrap">
                    {discountPercent}% {t("off")}
                  </span>
                )}
              </>
            )}
          </div>
          <button
            type="button"
            {...closedProps}
            onClick={guardClosed(handleMoveToBag)}
            disabled={!inStock || moving}
            className={`shrink-0 rounded-md border primaryBorder px-3 py-1.5 text-[11px] font-bold uppercase tracking-wide primaryColor transition hover:primaryBackColor hover:text-white disabled:cursor-not-allowed disabled:border-gray-200 disabled:text-gray-400 disabled:hover:bg-transparent dark:disabled:border-zinc-700 ${closedProps.className ?? ""}`}
          >
            {moving ? "..." : t("move_to_bag") || "Move to Bag"}
          </button>
        </div>
      </div>

      <button
        type="button"
        onClick={() => handleRemoveFromWishlist(product?.id)}
        aria-label={t("delete")}
        className="absolute end-1.5 top-1.5 flex h-7 w-7 items-center justify-center rounded-full text-gray-400 hover:bg-red-50 hover:text-red-500 dark:hover:bg-red-950/30 transition-colors"
      >
        <BiTrash size={16} />
      </button>
    </div>
  );
};

export default WishlistCard;
