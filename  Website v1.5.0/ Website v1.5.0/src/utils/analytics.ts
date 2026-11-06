"use client";

import { event } from "@/utils/gtag";

// GA4 recommended ecommerce events. Every helper no-ops when GA is disabled
// or consent was declined — that check lives in gtag.ts's isGaEnabled().
// Shapes follow https://developers.google.com/analytics/devguides/collection/ga4/ecommerce

export interface GaItem {
  item_id: string;
  item_name: string;
  item_variant?: string;
  item_category?: string;
  item_brand?: string;
  price?: number;
  quantity?: number;
}

const num = (v: any): number | undefined => {
  const n = Number(v);
  return Number.isFinite(n) ? n : undefined;
};

// Product shapes differ per endpoint (listing, detail, cart row), so read each
// field through the aliases the API actually sends.
export const toGaItem = (
  product: any,
  variant?: any,
  quantity?: number,
): GaItem => ({
  item_id: String(product?.id ?? product?.product_id ?? ""),
  item_name: String(product?.name ?? product?.product_name ?? ""),
  item_variant: variant?.variant_value ?? variant?.measurement_unit_name,
  item_category: product?.category_name ?? product?.category?.name,
  item_brand: product?.brand_name ?? product?.brand?.name,
  price:
    num(variant?.discounted_price) ||
    num(variant?.price) ||
    num(product?.discounted_price) ||
    num(product?.price),
  quantity: quantity ?? 1,
});

const itemsValue = (items: GaItem[]): number =>
  items.reduce((sum, i) => sum + (i.price ?? 0) * (i.quantity ?? 1), 0);

export const trackViewItem = (item: GaItem, currency?: string): void =>
  event("view_item", { currency, value: itemsValue([item]), items: [item] });

export const trackAddToCart = (item: GaItem, currency?: string): void =>
  event("add_to_cart", { currency, value: itemsValue([item]), items: [item] });

export const trackRemoveFromCart = (item: GaItem, currency?: string): void =>
  event("remove_from_cart", {
    currency,
    value: itemsValue([item]),
    items: [item],
  });

export const trackViewCart = (items: GaItem[], currency?: string): void =>
  event("view_cart", { currency, value: itemsValue(items), items });

export const trackBeginCheckout = (items: GaItem[], currency?: string): void =>
  event("begin_checkout", { currency, value: itemsValue(items), items });

export const trackAddPaymentInfo = (
  items: GaItem[],
  paymentType?: string,
  currency?: string,
): void =>
  event("add_payment_info", {
    currency,
    value: itemsValue(items),
    payment_type: paymentType,
    items,
  });

export interface PurchaseParams {
  transactionId: string | number;
  value: number;
  currency?: string;
  tax?: number;
  shipping?: number;
  coupon?: string;
  items: GaItem[];
}

export const trackPurchase = ({
  transactionId,
  value,
  currency,
  tax,
  shipping,
  coupon,
  items,
}: PurchaseParams): void =>
  event("purchase", {
    transaction_id: String(transactionId),
    value,
    currency,
    tax,
    shipping,
    coupon,
    items,
  });
