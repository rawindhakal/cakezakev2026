import Image from "next/image";
import fewLeftIcon from "@/assets/few_left_icon.svg";
import { t } from "@/utils/translation";

interface FewLeftBadgeProps {
  variant?: any;
  product?: any;
  size?: number;
  className?: string;
  pulse?: boolean;
}

/** Low-stock notice component. */
const FewLeftBadge = ({
  variant,
  product,
  size = 12,
  className = "",
  pulse = false,
}: FewLeftBadgeProps) => {
  // Check if low stock threshold is reached
  const isLow =
    variant?.is_min_alert == true ||
    variant?.few_quantity_left == true ||
    product?.is_min_alert == true ||
    product?.few_quantity_left == true;

  if (!isLow) return null;

  return (
    <p
      className={`flex items-center gap-1 text-[10px] md:text-[11px] font-semibold textColor ${className}`}
    >
      <Image
        src={fewLeftIcon}
        alt=""
        aria-hidden="true"
        width={size}
        height={size}
        className={`shrink-0 ${pulse ? "motion-safe:animate-pulseOnce" : ""}`}
      />
      <span>{t("few_quantity_left") || "Only a few left"}</span>
    </p>
  );
};

export default FewLeftBadge;
