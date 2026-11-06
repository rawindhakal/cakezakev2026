import React from "react";
import { useDispatch, useSelector } from "react-redux";
import { t } from "@/utils/translation";
import { setDeliveryType } from "@/redux/slices/checkoutSlice";
import { RiPhoneLine } from "react-icons/ri";
import { FaDirections } from "react-icons/fa";
import { LuStore } from "react-icons/lu";
import { SlLocationPin } from "react-icons/sl";
import { DeliveryIcon, PickupIcon } from "@/components/icons";

interface DeliveryModeToggleProps {
  /** Full cart response data from api.getCart() */
  checkoutData: any;
  /** Re-price in flight — hides the pickup card (data is still the old mode's). */
  totalsLoading?: boolean;
  /** Runs before dispatch so the parent sets loading in the same click. */
  onBeforeToggle?: () => void;
  /** Display-only toggle; hides the pickup card (guest can't order yet). */
  isGuest?: boolean;
}

// Delivery/pickup toggle + pickup store card. Toggling dispatches
// setDeliveryType, which re-prices the cart.
const DeliveryModeToggle = ({
  checkoutData,
  totalsLoading = false,
  onBeforeToggle,
  isGuest = false,
}: DeliveryModeToggleProps) => {
  const dispatch = useDispatch();
  const deliveryType = useSelector(
    (state: any) => state.Checkout.deliveryType as "delivery" | "pickup",
  );

  if (!checkoutData) return null;

  const deliveryAvailable = Number(checkoutData?.delivery_available) === 1;
  const pickupData = checkoutData?.pickup;
  const pickupAvailable = Number(checkoutData?.pickup_available) === 1;

  if (!deliveryAvailable && !pickupAvailable) return null;
  if (deliveryAvailable && !pickupAvailable && deliveryType === "delivery")
    return null;

  const showToggle = deliveryAvailable && pickupAvailable;
  const showPickupCard =
    !isGuest &&
    !totalsLoading &&
    (deliveryType === "pickup" || !deliveryAvailable) &&
    pickupData;

  // Prefer store lat/lng, else address text search.
  const directionsHref = (() => {
    if (pickupData?.latitude != null && pickupData?.longitude != null) {
      return `https://www.google.com/maps/dir/?api=1&destination=${pickupData.latitude},${pickupData.longitude}`;
    }
    if (pickupData?.address) {
      return `https://maps.google.com/?q=${encodeURIComponent(pickupData.address)}`;
    }
    return null;
  })();

  const handleToggle = (mode: "delivery" | "pickup") => {
    if (mode === deliveryType) return;
    onBeforeToggle?.();
    dispatch(setDeliveryType({ data: mode }));
  };

  return (
    <div className="flex flex-col gap-3">
      {showToggle && (
        <div
          className="flex items-center gap-1 rounded-lg p-1 shadow-sm"
          style={{
            backgroundColor:
              "color-mix(in srgb, var(--primary-color) 8%, transparent)",
          }}
        >
          <button
            type="button"
            id="delivery-mode-btn"
            onClick={() => handleToggle("delivery")}
            className={`flex flex-1 items-center justify-center gap-2 rounded-lg border px-3 py-2.5 text-sm font-semibold transition ${deliveryType === "delivery"
                ? "primaryLightBack primaryColor primaryColorBorder"
                : "border-transparent SecondaryTextColor hover:primaryColor"
              }`}
          >
            <DeliveryIcon size={16} />
            {t("delivery") || "Delivery"}
          </button>

          <button
            type="button"
            id="self-pickup-mode-btn"
            onClick={() => handleToggle("pickup")}
            className={`flex flex-1 items-center justify-center gap-2 rounded-lg border px-3 py-2.5 text-sm font-semibold transition ${deliveryType === "pickup"
                ? "primaryLightBack primaryColor primaryColorBorder"
                : "border-transparent SecondaryTextColor hover:primaryColor"
              }`}
          >
            <PickupIcon size={16} />
            {t("self_pickup") || "Self Pickup"}
          </button>
        </div>
      )}

      {/* Text-only — the Maps key lacks Static Maps API (403). */}
      {showPickupCard && (
        <div className="cardBorderPrimary bodyBackgroundColor p-2.5 flex flex-col gap-1.5">
          <div className="flex items-center gap-2.5">
            <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg primaryLightBack primaryColor">
              <LuStore size={17} />
            </span>
            <div className="min-w-0 flex-1">
              <h4 className="truncate font-bold textColor text-sm leading-tight">
                {pickupData?.branch_name}
              </h4>
              <div className="mt-0.5 flex flex-wrap items-center gap-x-1.5 gap-y-0.5 text-[11px] SecondaryTextColor">
                <span
                  className={`inline-flex items-center gap-1 font-bold ${
                    pickupData?.is_open_now
                      ? "primaryColor"
                      : "text-red-500 dark:text-red-400"
                  }`}
                >
                  <span className="h-1.5 w-1.5 rounded-full bg-current" />
                  {pickupData?.is_open_now
                    ? t("open_now") || "Open Now"
                    : t("closed_now") || "Closed Now"}
                </span>
                {pickupData?.preparation_time && (
                  <>
                    <span aria-hidden>·</span>
                    <span>
                      {t("ready_for_pickup_in") || "Ready for pickup in"}{" "}
                      {pickupData.preparation_time}
                    </span>
                  </>
                )}
                {pickupData?.distance != null && (
                  <>
                    <span aria-hidden>·</span>
                    <span>
                      {pickupData.distance} {pickupData.distance_unit || "km"}
                    </span>
                  </>
                )}
              </div>
            </div>
          </div>

          {pickupData?.address && (
            <div className="flex items-start gap-2 pt-1.5 border-t border-[color-mix(in_srgb,var(--primary-color)_12%,transparent)] text-xs SecondaryTextColor leading-relaxed">
              <SlLocationPin size={14} className="primaryColor shrink-0 mt-0.5" />
              <span className="min-w-0 flex-1">{pickupData.address}</span>
            </div>
          )}

          {(directionsHref || pickupData?.contact_number) && (
            <div className="flex items-center gap-4 text-xs">
              {directionsHref && (
                <a
                  href={directionsHref}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1 text-[11px] font-bold primaryColor hover:underline"
                >
                  <FaDirections size={13} className="shrink-0" />
                  {t("get_directions") || "Get Directions"}
                </a>
              )}
              {pickupData?.contact_number && (
                <a
                  href={`tel:${pickupData.contact_number}`}
                  className="inline-flex items-center gap-1.5 primaryColor font-semibold hover:underline"
                >
                  <RiPhoneLine size={13} className="shrink-0" />
                  {t("call_store") || "Call Store"}
                </a>
              )}
            </div>
          )}

          {!pickupAvailable && pickupData?.unavailable_reason && (
            <p className="rounded-lg bg-red-50 dark:bg-red-950/40 border border-red-200/60 dark:border-red-800/40 px-3 py-2 text-xs font-semibold text-red-600 dark:text-red-400">
              {pickupData.unavailable_reason}
            </p>
          )}
        </div>
      )}
    </div>
  );
};

export default DeliveryModeToggle;
