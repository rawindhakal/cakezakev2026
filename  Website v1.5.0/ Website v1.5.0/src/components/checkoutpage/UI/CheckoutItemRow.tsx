"use client";
import { toast } from "react-toastify";
import { FiMapPin, FiPlus, FiMinus, FiTrash2 } from "react-icons/fi";
import { MdRemoveShoppingCart } from "react-icons/md";
import { BsLock } from "react-icons/bs";
import { t } from "@/utils/translation";
import { getMaxAddableQuantity } from "@/utils/helperFunction";
import { useDebouncedQuantity, FlushCtx } from "@/hooks/useDebouncedQuantity";
import useStoreClosed from "@/hooks/useStoreClosed";
import ImageWithPlaceholder from "@/components/image-with-placeholder/ImageWithPlaceholder";
// Untyped JS component; cast to any.
import PrescriptionUploadRaw from "@/components/prescription/PrescriptionUpload";
const PrescriptionUpload = PrescriptionUploadRaw as any;

interface CheckoutItemRowProps {
  /** Cart line from getCart(checkout:1). */
  product: any;
  money: (amount?: number | string) => string;
  onCommitQty: (
    product: any,
    variantId: number | string,
    nextQty: number,
    ctx?: FlushCtx,
  ) => void | Promise<void>;
  onRemoveUnits: (
    product: any,
    variantId: number | string,
    units?: number,
    ctx?: FlushCtx,
  ) => void | Promise<void>;
  /** Store-wide max cart quantity. */
  maxCartItemsCount?: number | string | null;
  /** Total qty of all other cart lines. */
  otherLinesQty?: number;
  /** Variant can't be delivered to this address. */
  isUndeliverable?: boolean;
}

// One cart line with its own debounced qty stepper.
const CheckoutItemRow = ({
  product,
  money,
  onCommitQty,
  onRemoveUnits,
  maxCartItemsCount,
  otherLinesQty,
  isUndeliverable,
}: CheckoutItemRowProps) => {
  const { guard: guardClosed, closedProps } = useStoreClosed();
  const variant = product?.variants?.[0] || {};
  const unitPrice =
    product?.discounted_price && product?.discounted_price != 0
      ? product?.discounted_price
      : product?.price;
  const productName = product?.product?.translations?.name || product?.name;
  const imageUrl = product?.images?.[0]?.image_url || variant?.image;
  const serverQty = Number(variant?.quantity ?? product?.qty ?? 0);
  const variantText = variant?.attributes_text;
  const variantId = variant?.id ?? product?.variant_id;

  const maxQty = getMaxAddableQuantity({
    maxCartItemsCount,
    otherLinesQty,
    totalAllowedQty: product?.total_allowed_quantity,
    isUnlimitedStock: product?.is_unlimited_stock !== 0,
    stock: product?.stock,
  });

  // Out of stock: limited stock (is_unlimited_stock === 0) AND nothing left.
  const stockLeft = Number(variant?.stock ?? product?.stock ?? 0);
  const outOfStock =
    Number(product?.is_unlimited_stock) === 0 && stockLeft <= 0;

  const { displayQty, increment, decrement } = useDebouncedQuantity({
    serverQty,
    onCommit: (qty, ctx) => onCommitQty(product, variantId, qty, ctx),
    onRemove: (units, ctx) => onRemoveUnits(product, variantId, units, ctx),
    max: Number.isFinite(maxQty) ? maxQty : undefined,
    onMax: () =>
      toast.error(t("max_cart_limit_error"), {
        toastId: "max_cart_limit_error",
      }),
  });

  const qty = displayQty;
  // Grey out + at the max qty.
  const atMaxQty = Number.isFinite(maxQty) && qty >= maxQty;

  // Strike-through original price + % off when the item is discounted.
  const basePrice = Number(product?.price) || 0;
  const hasDiscount = unitPrice && basePrice && unitPrice < basePrice;
  const offPercent = hasDiscount
    ? Math.round(((basePrice - unitPrice) / basePrice) * 100)
    : 0;

  return (
    <div className="flex gap-3 md:gap-4 px-4 md:px-5 py-4 border-t hover:bg-black/[0.015] dark:hover:bg-white/[0.02] transition-colors">
      {/* image */}
      <div className="relative w-[72px] h-[72px] md:w-20 md:h-20 rounded-xl overflow-hidden cardBorder shrink-0 bg-white dark:bg-zinc-900">
        <ImageWithPlaceholder
          src={imageUrl}
          alt={productName}
          width={160}
          height={160}
          className={`w-full h-full object-contain p-1.5 ${
            outOfStock ? "opacity-40 grayscale" : ""
          }`}
        />
      </div>

      {/* details */}
      <div className="flex flex-col min-w-0 flex-1 gap-1">
        {/* top row: name (left) + line total (right) — Flipkart-style alignment */}
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <h3 className="font-semibold text-sm md:text-base line-clamp-2 leading-snug">
              {productName}
            </h3>
            {variantText && (
              <p className="text-xs SecondaryTextColor truncate mt-0.5">
                {variantText}
              </p>
            )}
          </div>
          <div className="flex flex-col items-end shrink-0">
            <span className="font-bold text-sm md:text-base whitespace-nowrap">
              {money(unitPrice * qty)}
            </span>
            {qty > 1 && (
              <span className="text-[11px] SecondaryTextColor whitespace-nowrap">
                {qty} × {money(unitPrice)}
              </span>
            )}
          </div>
        </div>

        {/* unit price + strike + % off */}
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-sm font-semibold textColor">
            {money(unitPrice)}
          </span>
          {hasDiscount && (
            <>
              <span className="text-xs SecondaryTextColor line-through">
                {money(basePrice)}
              </span>
              <span className="text-[11px] font-bold text-green-600 dark:text-green-400">
                {offPercent}% {t("off")}
              </span>
            </>
          )}
        </div>

        {product?.slab_discount_message && (
          <p className="inline-flex w-fit items-center gap-1.5 rounded-md border border-green-200 dark:border-green-800 bg-green-50 dark:bg-green-900/15 px-2 py-1 text-[11px] font-semibold text-green-700 dark:text-green-400">
            <BsLock size={12} className="shrink-0" />
            {product?.slab_discount_message}
          </p>
        )}

        {/* Qty stepper, prescription upload, remove. */}
        <div className="flex flex-wrap items-center gap-3 mt-1">
          {isUndeliverable ? (
            <span className="inline-flex items-center gap-1.5 rounded-full border border-red-200 dark:border-red-500/30 bg-red-50 dark:bg-red-500/10 px-3 py-1.5 text-[11px] font-semibold text-red-500 dark:text-red-400">
              <FiMapPin size={14} className="shrink-0" />
              {t("not_deliverable_to_this_address") ||
                "Can't be delivered to this address"}
            </span>
          ) : outOfStock ? (
            <span className="inline-flex items-center gap-1.5 rounded-full border border-red-200 dark:border-red-500/30 bg-red-50 dark:bg-red-500/10 px-3 py-1.5 text-[11px] font-semibold text-red-500 dark:text-red-400">
              <MdRemoveShoppingCart size={14} className="shrink-0" />
              {t("sold_out") || "Sold Out"}
            </span>
          ) : (
            <span className="text-xs SecondaryTextColor">1 item</span>
          )}
          {/* prescription — medical (product_type 5) only */}
          {Number(product?.product_type) === 5 && (
            <PrescriptionUpload
              variantId={variantId}
              isRequired={product?.is_prescription_required}
              inline
            />
          )}
          <button
            type="button"
            className="ml-auto flex items-center gap-1.5 text-xs font-semibold text-red-500 hover:text-red-600 px-2 py-1 rounded-lg hover:bg-red-50 dark:hover:bg-red-500/10 transition"
            onClick={() => onRemoveUnits(product, variantId, qty)}
            aria-label={t("delete")}
          >
            <FiTrash2 size={15} />
            <span className="hidden sm:inline">{t("delete")}</span>
          </button>
        </div>
      </div>
    </div>
  );
};

export default CheckoutItemRow;
