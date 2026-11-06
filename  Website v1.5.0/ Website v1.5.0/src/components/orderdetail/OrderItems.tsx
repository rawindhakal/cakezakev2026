import { t } from "@/utils/translation";
import React, { useState } from "react";
import { useSelector } from "react-redux";
import { toast } from "react-toastify";
import * as api from "@/api/apiRoutes";
import CancelReasonModal from "./CancelReasonModal";
import ReturnReasonModal from "./ReturnReasonModal";
import { TbTruckReturn } from "react-icons/tb";
import RatingUpdateModal from "./RatingUpdateModal";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import LightBox from "@/components/ui/LightBox";
import { RiFileTextLine } from "react-icons/ri";
import useCurrency from "@/hooks/useCurrency";
import PeekRating from "@/components/ui/peek-rating/PeekRating";
import CartLineAddons from "@/components/cart/CartLineAddons";
import { cartLineKey } from "@/utils/addons";
import ProductTypeTag from "../productdetail/ProductTypeTag";

// Prescription file url → true when it points at an image (else treat as pdf/doc).
const isImageUrl = (url: string | null | undefined) =>
  /\.(png|jpe?g|gif|webp|avif|bmp|svg)(\?.*)?$/i.test(url || "");

// No rating → 5 grey stars, click to instant-submit. Has rating → filled, read-only.
interface StarRatingProps {
  value?: number;
  editable?: boolean;
  onRate?: (star: number) => void;
  disabled?: boolean;
}

const StarRating = ({ value = 0, editable = false, onRate, disabled = false }: StarRatingProps) => (
  <PeekRating
    value={value}
    onChange={(star) => onRate?.(star)}
    readOnly={!editable}
    disabled={editable && disabled}
    allowClear={false}
    showTip={false}
    size={26}
    lift={4}
    activeColor="#DB9305"
    ariaLabel={t("rate_this_product_now") || "Rate this product"}
  />
);

// "Color: white, Size: m" from variant_attributes
const formatAttributes = (attrs: any) =>
  Array.isArray(attrs)
    ? attrs.map((a) => `${a?.name}: ${a?.value}`).join(", ")
    : "";

const linkBtn =
  "inline-flex items-center gap-2 text-sm font-medium whitespace-nowrap transition-colors hover:underline";

const actionBtn = {
  rate: `${linkBtn} text-[#55AE7B]`,
  rated: `${linkBtn} text-[#DB9305]`,
  // Subtle red-outline pill, fills on hover. Used for Cancel / Return.
  danger:
    "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-xl border border-[#DB3D26]/40 px-4 py-2 text-sm font-semibold text-[#DB3D26] transition-colors hover:bg-[#DB3D26] hover:text-white",
  disabled:
    "inline-flex items-center justify-center gap-2 rounded-xl border border-[var(--border-color)] px-5 py-2.5 text-sm font-semibold SecondaryTextColor cursor-not-allowed",
};

interface OrderItemsProps {
  // Order items / product rows have no shared type yet — see AGENTS.md rule 4.
  products: any[];
  handleFetchOrderDetail: () => Promise<void> | void;
  isShowProductRating: boolean;
  currency?: string;
  // Order-level fallback gates when per-item *_status flags are absent.
  orderIsCancellable?: boolean;
  orderIsReturnable?: boolean;
}

const OrderItems = ({
  products,
  handleFetchOrderDetail,
  isShowProductRating,
  currency: currencyProp,
  orderIsCancellable,
  orderIsReturnable,
}: OrderItemsProps) => {
  const setting = useSelector((state: any) => state.Setting.setting);
  const user = useSelector((state: any) => state.User.user);
  // Live zone currency wins over order's placed-currency; currencyProp is a loading fallback.
  const { currency: resolvedCurrency } = useCurrency();
  const currency = resolvedCurrency || currencyProp;

  const [selectedProduct, setSelectedProduct] = useState<any>([]);
  const [showCancelMoodal, setShowCancelModal] = useState(false);
  const [showReturnModal, setShowReturnModal] = useState(false);
  const [showUpdateRating, setShowUpdateRating] = useState(false);
  const [ratingId, setRatingId] = useState<number | string | null>(null);
  // product id currently being rated (disables its stars during the API call).
  const [ratingProductId, setRatingProductId] = useState<number | string | null>(null);
  // Prescription lightbox — holds the image url currently being previewed.
  const [prescriptionImg, setPrescriptionImg] = useState<string | null>(null);

  // View an uploaded prescription: images open in the lightbox, PDFs in a new tab.
  const handleViewPrescription = (url: string | null | undefined) => {
    if (!url) return;
    if (isImageUrl(url)) setPrescriptionImg(url);
    else window.open(url, "_blank", "noopener,noreferrer");
  };

  // This user's rating for a product, handles both rating.user.id and rating.user_id shapes.
  const findUserRating = (product: any) =>
    product?.item_rating?.find(
      (r: any) => r?.user?.id == user?.id || r?.user_id == user?.id,
    );

  // Instant star rating: submit just the score; existing rating updates instead of re-adding.
  const handleInstantRate = async (product: any, star: number) => {
    // Rating API needs the product id, not the order-item id.
    const productId = product?.product_id ?? product?.id;
    setRatingProductId(productId);
    try {
      const existing = findUserRating(product);
      let response;
      if (existing?.id) {
        response = await api.updateReviewProduct({
          ratingId: existing.id,
          rating: star,
          review: existing?.review || "",
          deleteImages: "",
          images: [],
        });
      } else {
        response = await api.reviewProduct({
          productId,
          rating: star,
          review: "",
          images: [],
        });
      }
      if (response?.status == 1) {
        await handleFetchOrderDetail();
      } else {
        toast.error(response?.message);
      }
    } catch (error) {
      console.log("Error", error);
    } finally {
      setRatingProductId(null);
    }
  };

  const handleCancel = (product: any) => {
    setSelectedProduct(product);
    setShowCancelModal(true);
  };

  const handleReturn = (product: any) => {
    setSelectedProduct(product);
    setShowReturnModal(true);
  };


  const handleShowUpdateRating = (product: any) => {
    setRatingId(findUserRating(product)?.id);
    setShowUpdateRating(true);
  };

  // Cancel is order-level (parent renders it) when orderIsCancellable is passed; else per-item flags.
  const itemCanCancel = (product: any) => {
    if (orderIsCancellable !== undefined) {
      return false;
    }
    return (
      Number(product?.active_status) <= 6 &&
      Number(product?.active_status) <= Number(product?.till_status) &&
      Number(product?.cancelable_status) === 1
    );
  };

  const itemCanReturn = (product: any) => {
    if (product?.return_requested !== null) return false;
    if (orderIsReturnable !== undefined) {
      return orderIsReturnable === true && Number(product?.active_status) === 6;
    }
    return (
      Number(product?.active_status) === 6 &&
      Number(product?.return_status) === 1
    );
  };

  // Cancel/return/cancelled-badge column; rating has its own row below.
  const showAction = products?.some((product: any) => {
    const canCancel = itemCanCancel(product);
    const canReturn = itemCanReturn(product);
    const isCancelled = Number(product?.active_status) === 7;
    return canCancel || canReturn || isCancelled;
  });

  // Group items by product_id so pack-size variants share one rating row.
  const ratingGroups = new Map<any, any[]>();
  products?.forEach((product: any) => {
    const key = product?.product_id ?? product?.id;
    if (!ratingGroups.has(key)) ratingGroups.set(key, []);
    ratingGroups.get(key)!.push(product);
  });

  return (
    <div className="rounded-md  overflow-hidden">
      <div className="flex flex-col">
        {Array.from(ratingGroups.entries()).map(([groupKey, groupItems]) => (
          <div
            key={groupKey}
            className="my-2 rounded-lg border border-[var(--border-color)] bg-[hsl(var(--muted))] shadow-sm overflow-hidden"
          >
            {groupItems.map((product, indexInGroup) => {
          const isLastOfProduct = indexInGroup === groupItems.length - 1;

          const priceNode = (
            <p className="font-bold textColor whitespace-nowrap">
              {currency}
              {(product?.discounted_price && product?.discounted_price != 0
                ? product?.discounted_price
                : product?.price
              )?.toFixed(
                setting?.decimal_point ? setting?.decimal_point : 0,
              )}
            </p>
          );

          const actionsNode = showAction ? (
            <div className="flex flex-wrap items-center gap-x-6 gap-y-3">
              {itemCanCancel(product) && (
                <button
                  className={actionBtn.danger}
                  onClick={() => handleCancel(product)}
                >
                  <TbTruckReturn size={18} />
                  {t("cancel")}
                </button>
              )}

              {itemCanReturn(product) && (
                <button
                  className={actionBtn.danger}
                  onClick={() => handleReturn(product)}
                >
                  <TbTruckReturn size={18} />
                  {t("return")}
                </button>
              )}

              {Number(product?.active_status) === 7 && (
                <button className={actionBtn.disabled} disabled>
                  {t("cancelled")}
                </button>
              )}
            </div>
          ) : null;

          return (
            <div
              key={cartLineKey(product)}
              className={`p-4 bg-[hsl(var(--card))] flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between lg:gap-6 ${
                isLastOfProduct ? "" : "border-b border-dashed border-[var(--border-color)]"
              }`}
            >
              <div className="flex items-start gap-4 min-w-0 lg:flex-1">
                <div className="relative p-1 rounded-md flex-shrink-0 cardBorder">
                  <ImageWithPlaceholder
                    src={product?.image_url}
                    alt="Products"
                    width={72}
                    height={72}
                    className="w-16 h-16 lg:w-[72px] lg:h-[72px] backColor rounded"
                  />
                </div>

                <div className="min-w-0 flex flex-col gap-0.5">
                  <h2 className="font-semibold textColor line-clamp-2">
                    <ProductTypeTag
                      type={product?.product_type}
                      className="me-1 align-[-2px]"
                      iconSize={14}
                    />
                    {product?.product_name ?? product?.name}
                  </h2>
                  <p className="text-sm SecondaryTextColor">
                    {formatAttributes(product?.variant_attributes) || product?.variant_name
                      ? `${formatAttributes(product?.variant_attributes) || product?.variant_name} x ${product?.quantity}`
                      : `Qty: ${product?.quantity}`}
                  </p>
                  <CartLineAddons
                    addons={product?.addons}
                    addonTotal={product?.addon_total}
                    money={(value: number) => `${currency}${value}`}
                    className="max-w-md"
                  />
                  {Number(product?.return_requested) === 1 && (
                    <button className="text-left text-sm text-[#DB9305]">
                      {t("return_requested")}
                    </button>
                  )}
                  {Number(product?.return_requested) === 4 && (
                    <button className="text-left text-sm text-[#0DCaf0]">
                      {t("delivery_boy_assinged")}
                    </button>
                  )}
                  {Number(product?.return_requested) === 5 && (
                    <button className="text-left text-sm text-[#0d6efd]">
                      {t("deliver_boy_out_for_pickup")}
                    </button>
                  )}
                  {Number(product?.return_requested) === 6 && (
                    <button className="text-left text-sm text-[#6C757D]">
                      {t("item_received_from_customer")}
                    </button>
                  )}
                  {Number(product?.return_requested) === 7 && (
                    <>
                      <button className="text-left text-sm text-[#DB3D26]">
                        {t("return_request_cancel_by_delivery_boy")}
                      </button>
                      <p className="text-xs SecondaryTextColor">{`${t("branchNote")}: ${product?.cancellation_reason
                        }`}</p>
                    </>
                  )}
                  {Number(product?.return_requested) === 8 && (
                    <button className="text-left text-sm textColor">
                      {t("item_returned_to_branch")}
                    </button>
                  )}
                  {/* Cancellation reason — item-level, set once cancelled (active_status 7). */}
                  {Number(product?.active_status) === 7 &&
                    product?.cancellation_reason && (
                      <p className="text-xs SecondaryTextColor">{`${t("reason")}: ${product?.cancellation_reason}`}</p>
                    )}
                  {Number(product?.active_status) === 8 && (
                    <span className="text-sm text-[#DB3D26]">{`${t("total")} ${currency
                      }${product?.refund_amount} ${t("refunded")}`}</span>
                  )}
                  {Number(product?.return_requested) === 3 && (
                    <>
                      <button className="text-left text-sm text-red-500">
                        {t("return_rejected")}
                      </button>
                      <p className="text-xs SecondaryTextColor">{`${t("branchNote")}: ${product?.return_remarks
                        }`}</p>
                    </>
                  )}
                  {/* uploaded prescription — bordered chip (image → lightbox, pdf → tab) */}
                  {product?.prescription_url && (
                    <button
                      type="button"
                      onClick={() => handleViewPrescription(product.prescription_url)}
                      className="mt-1.5 inline-flex w-fit items-center gap-1.5 rounded-lg border primaryColorBorder px-3 py-1.5 text-xs font-semibold primaryColor transition-colors hover:primaryLightBack"
                    >
                      <RiFileTextLine size={15} className="shrink-0" />
                      {t("view_prescription") || "View prescription"}
                    </button>
                  )}
                </div>
              </div>

              <div className="hidden lg:flex flex-col items-end gap-3 flex-shrink-0">
                {priceNode}
                {actionsNode}
              </div>

              <div className="flex flex-col gap-3 lg:hidden">
                <div className="bottomBorder w-full"></div>
                <div className="flex items-center justify-between">
                  <p className="font-semibold SecondaryTextColor">{`${t("price")}:`}</p>
                  {priceNode}
                </div>
                {showAction && <div className="bottomBorder w-full"></div>}
                {actionsNode}
              </div>
            </div>
              );
            })}
            {/* Rating is product-level; rendered once per group using its first item. */}
            {isShowProductRating &&
              (() => {
                const repProduct = groupItems[0];
                if (Number(repProduct?.active_status) !== 6) return null;
                if (repProduct?.return_requested !== null) return null;
                const userRating = findUserRating(repProduct);
                const repProductId = repProduct?.product_id ?? repProduct?.id;
                return (
                  <div className="flex items-center justify-between gap-3 border-t border-[var(--border-color)] bg-[hsl(var(--muted))] px-4 py-3">
                    <p className="min-w-0 truncate text-xs font-medium SecondaryTextColor">
                      {groupItems.length > 1
                        ? `${groupItems.length} ${t("variants") || "variants"}`
                        : ""}
                    </p>
                    {userRating ? (
                      <div className="flex shrink-0 items-center gap-3">
                        <StarRating value={Number(userRating?.rate) || 0} />
                        <button
                          className={actionBtn.rate}
                          onClick={() => handleShowUpdateRating(repProduct)}
                        >
                          {userRating?.review
                            ? t("view_review") || "View Review"
                            : t("write_a_review") || "Write a Review"}
                        </button>
                      </div>
                    ) : (
                      <div className="flex shrink-0 flex-col items-end gap-1">
                        <StarRating
                          editable
                          disabled={ratingProductId === repProductId}
                          onRate={(star) => handleInstantRate(repProduct, star)}
                        />
                        <span className="text-xs SecondaryTextColor">
                          {t("rate_this_product_now") || "Rate this product now"}
                        </span>
                      </div>
                    )}
                  </div>
                );
              })()}
          </div>
        ))}
      </div>
      <CancelReasonModal
        showCancelMoodal={showCancelMoodal}
        setShowCancelModal={setShowCancelModal}
        selectedProduct={selectedProduct}
        handleFetchOrderDetail={handleFetchOrderDetail}
      />
      <ReturnReasonModal
        showReturnModal={showReturnModal}
        setShowReturnModal={setShowReturnModal}
        selectedProduct={selectedProduct}
        handleFetchOrderDetail={handleFetchOrderDetail}
      />
      <RatingUpdateModal
        ratingId={ratingId}
        showUpdateRating={showUpdateRating}
        setShowUpdateRating={setShowUpdateRating}
        handleFetchOrderDetail={handleFetchOrderDetail}
      />
      {prescriptionImg && (
        <LightBox
          showLightBox={!!prescriptionImg}
          setShowLightbox={(open) => !open && setPrescriptionImg(null)}
          images={[{ src: prescriptionImg }]}
          imageIndex={0}
        />
      )}
    </div>
  );
};

export default OrderItems;
