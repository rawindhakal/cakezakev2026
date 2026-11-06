import { FiMapPin, FiPhone, FiShoppingBag } from "react-icons/fi";
import { FaDirections } from "react-icons/fa";
import { t } from "@/utils/translation";
import SectionHeader from "./SectionHeader";

interface PickupStoreCardProps {
  /** checkoutData.pickup from getCart(checkout:1). */
  pickup: any;
}

const pillClass =
  "inline-flex items-center gap-1.5 rounded-full primaryLightBack px-2.5 py-1 text-[11px] font-bold primaryColor transition-opacity hover:opacity-80";

const PickupStoreCard = ({ pickup }: PickupStoreCardProps) => {
  const directionsHref =
    pickup?.latitude != null && pickup?.longitude != null
      ? `https://www.google.com/maps/dir/?api=1&destination=${pickup.latitude},${pickup.longitude}`
      : `https://maps.google.com/?q=${encodeURIComponent(pickup?.address ?? "")}`;

  return (
    <div className="bodyBackgroundColor cardBorder !rounded-lg shadow-sm overflow-hidden">
      <div className="flex flex-wrap items-center justify-between gap-x-2.5 gap-y-1.5 px-4 py-3 md:px-5 md:py-3.5 border-b">
        <SectionHeader
          icon={<FiShoppingBag size={18} />}
          title={t("pickup_from") || "Pickup from"}
        />
        <span
          className={`inline-flex w-fit shrink-0 items-center gap-1 whitespace-nowrap rounded-full px-2 py-1 text-[11px] font-bold md:px-2.5 md:text-xs ${
            pickup?.is_open_now
              ? "primaryLightBack primaryColor"
              : "bg-black/[0.04] SecondaryTextColor dark:bg-white/[0.06]"
          }`}
        >
          <span className="h-1.5 w-1.5 rounded-full bg-current" />
          {pickup?.is_open_now
            ? t("open_now") || "Open now"
            : t("closed_now") || "Closed now"}
        </span>
      </div>
      <div className="px-4 py-3 md:px-5 flex flex-col gap-1.5">
        {/* Own line, not an inline tail: this card sits in a ~330px column at
            every width, where "· Ready for pickup in 15 mins" broke mid-phrase. */}
        <div className="flex flex-col gap-0.5">
          <p className="text-sm font-bold textColor">{pickup?.branch_name}</p>
          {pickup?.preparation_time && (
            <p className="text-xs SecondaryTextColor">
              {t("ready_for_pickup_in") || "Ready for pickup in"}{" "}
              {pickup.preparation_time}
            </p>
          )}
        </div>

        {pickup?.address && (
          <div className="flex items-start gap-2 text-xs SecondaryTextColor leading-relaxed">
            <FiMapPin size={14} className="primaryColor shrink-0 mt-0.5" />
            <span className="min-w-0 flex-1">{pickup.address}</span>
          </div>
        )}

        {(pickup?.address || pickup?.contact_number) && (
          <div className="mt-0.5 flex flex-wrap items-center gap-2 text-xs">
            {pickup?.address && (
              <a
                href={directionsHref}
                target="_blank"
                rel="noopener noreferrer"
                className={pillClass}
              >
                <FaDirections size={12} className="shrink-0" />
                {t("get_directions") || "Get Directions"}
              </a>
            )}
            {pickup?.contact_number && (
              <a href={`tel:${pickup.contact_number}`} className={pillClass}>
                <FiPhone size={12} className="shrink-0" />
                {t("call_store") || "Call Store"}
              </a>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default PickupStoreCard;
