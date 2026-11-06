import { RiErrorWarningLine } from "react-icons/ri";
import { t } from "@/utils/translation";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import type { CartLineAddon } from "@/types/api/addons";

interface CartLineAddonsProps {
  addons?: CartLineAddon[];
  /** Line total for every addon, already multiplied by the line quantity. */
  addonTotal?: number;
  hasUnavailable?: 0 | 1 | boolean;
  /** Formats a number with the line's currency and decimals. */
  money: (value: number) => string;
  className?: string;
}

// Chosen options, nested under their product line and grouped by the question
// they answer. A linked option is a real catalogue product but never gets a
// cart line of its own — it shows here. addon_total is display only: the money
// is already inside the line price.
const CartLineAddons = ({
  addons,
  addonTotal,
  hasUnavailable,
  money,
  className = "",
}: CartLineAddonsProps) => {
  if (!addons?.length) return null;

  // One block per question, in the order the options arrived.
  const groups: Array<{ id: number; name: string; options: CartLineAddon[] }> = [];
  addons.forEach((addon) => {
    const group = groups.find((row) => row.id === addon.group_id);
    if (group) group.options.push(addon);
    else
      groups.push({
        id: addon.group_id,
        name: addon.group_name,
        options: [addon],
      });
  });

  return (
    <div
      className={`mt-2 flex flex-col gap-2 border-s-2 border-gray-100 ps-2.5 dark:border-zinc-800 ${className}`}
    >
      {groups.map((group) => (
        <div key={group.id} className="flex flex-col gap-1">
          <p className="text-[10px] font-semibold uppercase tracking-wide text-gray-400">
            {group.name}
          </p>
          {group.options.map((addon) => (
            <div
              key={addon.option_id}
              className="flex items-center gap-2 text-xs SecondaryTextColor"
            >
              {addon.image && (
                <span className="h-5 w-5 shrink-0 overflow-hidden rounded border border-gray-100 bg-white dark:border-zinc-800">
                  <ImageWithPlaceholder
                    src={addon.image}
                    alt={addon.option_name}
                    width={40}
                    height={40}
                    className="h-full w-full object-contain"
                  />
                </span>
              )}
              <span
                className={`min-w-0 flex-1 truncate ${
                  addon.available ? "" : "line-through opacity-60"
                }`}
              >
                {addon.qty > 1 ? `${addon.qty} × ` : ""}
                {addon.option_name}
              </span>
              <span className="shrink-0 whitespace-nowrap font-medium textColor">
                {/* line_price already covers this option's qty for one dish. */}
                {addon.is_free ? t("addon_free") : money(addon.line_price)}
              </span>
            </div>
          ))}
        </div>
      ))}

      {addonTotal ? (
        <div className="flex items-center gap-2 border-t border-dashed border-gray-100 pt-1.5 text-xs font-semibold textColor dark:border-zinc-800">
          <span className="min-w-0 flex-1 truncate">{t("addon_total")}</span>
          <span className="shrink-0 whitespace-nowrap">{money(addonTotal)}</span>
        </div>
      ) : null}

      {/* Checkout refuses while this is set, so warn here rather than at payment. */}
      {Number(hasUnavailable) === 1 && (
        <p className="flex items-center gap-1 text-xs font-medium text-[#ff5a5a]">
          <RiErrorWarningLine size={13} className="shrink-0" />
          {t("addon_unavailable_warning")}
        </p>
      )}
    </div>
  );
};

export default CartLineAddons;
