import { t } from "@/utils/translation";

// Maps self-pickup error code slugs to translated user-facing error messages.
export const getPickupErrorMessage = (message?: string): string | undefined => {

  if (!message) return undefined;
  const map: Record<string, string> = {
    self_pickup_not_available_for_this_store:
      t("self_pickup_not_available_for_this_store") ||
      "Self-pickup isn't available for this store",
    store_offers_pickup_only:
      t("store_offers_pickup_only") ||
      "This store only offers self-pickup, not delivery",
    pickup_order_items_must_be_from_single_store:
      t("pickup_order_items_must_be_from_single_store") ||
      "All items in a pickup order must be from the same store",
    pickup_store_changed_refresh_cart:
      t("pickup_store_changed_refresh_cart") ||
      "Your location has changed — please refresh your cart and try again",
    free_delivery_coupon_not_applicable_for_pickup:
      t("free_delivery_coupon_not_applicable_for_pickup") ||
      "This coupon's free delivery doesn't apply to self-pickup orders",
    invalid_delivery_type:
      t("invalid_delivery_type") || "Invalid delivery type selected",
  };
  return map[message];
};
