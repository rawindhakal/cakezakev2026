import { FiInfo } from "react-icons/fi";
import { DeliveryIcon, PickupIcon } from "@/components/icons";
import { t } from "@/utils/translation";

type DeliveryMode = "delivery" | "pickup";

interface DeliveryTypeToggleProps {
  active?: string;
  onChange: (mode: DeliveryMode) => void;
  /** Backend fell back to the other mode. */
  showFallbackNote: boolean;
  fallbackReason?: string;
}

const OPTIONS = [
  { mode: "delivery", Icon: DeliveryIcon, key: "delivery", fallback: "Delivery" },
  { mode: "pickup", Icon: PickupIcon, key: "self_pickup", fallback: "Self Pickup" },
] as const;

const DeliveryTypeToggle = ({
  active,
  onChange,
  showFallbackNote,
  fallbackReason,
}: DeliveryTypeToggleProps) => (
  <div className="bodyBackgroundColor cardBorder !rounded-lg shadow-sm p-2">
    <div
      dir="ltr"
      className="relative grid grid-cols-2 items-center rounded-lg gap-1.5 select-none"
    >
      {OPTIONS.map(({ mode, Icon, key, fallback }) => (
        <button
          key={mode}
          type="button"
          onClick={() => onChange(mode)}
          className={`flex items-center justify-center gap-1.5 px-3 h-[38px] text-sm font-semibold whitespace-nowrap rounded-lg border transition-colors ${
            active === mode
              ? "primaryLightBack primaryColor primaryColorBorder"
              : "border-transparent SecondaryTextColor"
          }`}
        >
          <Icon size={16} />
          {t(key) || fallback}
        </button>
      ))}
    </div>

    {showFallbackNote && (
      <p className="flex items-start gap-1.5 mt-2 px-1 text-xs font-medium text-amber-600 dark:text-amber-400">
        <FiInfo size={13} className="shrink-0 mt-0.5" />
        {fallbackReason ||
          t("requested_mode_unavailable") ||
          "That option isn't available right now — showing the other one instead."}
      </p>
    )}
  </div>
);

export default DeliveryTypeToggle;
