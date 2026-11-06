import { FiCheck } from "react-icons/fi";
import { payMethodIcon, payMethodSubtitle } from "./paymentMethods";

interface PayPickRowProps {
  opt: { value: string; label: string };
  active: boolean;
  onPick: () => void;
}

// Selectable payment method card.
const PayPickRow = ({ opt, active, onPick }: PayPickRowProps) => {
  const subtitle = payMethodSubtitle(opt.value);
  return (
    <button
      type="button"
      onClick={onPick}
      aria-pressed={active}
      className={`group relative flex items-center gap-3 rounded-xl border p-2.5 text-left transition duration-200 ${
        active
          ? "primaryColorBorder primaryLightBack dark:border-white dark:bg-white/[0.06] -translate-y-0.5 motion-reduce:translate-y-0 shadow-[0_8px_18px_-8px_rgba(0,0,0,0.22)]"
          : "cardBorder hover:border-gray-300 dark:hover:border-gray-600 hover:bg-black/[0.01] dark:hover:bg-white/[0.02] hover:shadow-sm"
      }`}
    >
      {/* brand logo tile */}
      <span
        className={`w-9 h-9 rounded-lg bg-white dark:bg-white/10 border cardBorder flex items-center justify-center shrink-0 transition duration-200 primaryColor dark:text-white ${
          active ? "shadow-sm scale-[1.03]" : "group-hover:shadow-sm"
        }`}
      >
        {payMethodIcon(opt.value)}
      </span>

      {/* name + subtitle */}
      <span className="flex flex-col min-w-0 flex-1">
        <span className="font-semibold text-sm md:text-[15px] textColor capitalize truncate">
          {opt.label}
        </span>
        {subtitle && (
          <span className="text-xs SecondaryTextColor leading-snug line-clamp-1 mt-0.5">
            {subtitle}
          </span>
        )}
      </span>

      {/* radio: fill scales in with a fading ripple ring */}
      <span
        className={`relative w-5 h-5 rounded-full flex items-center justify-center shrink-0 transition duration-200 ${
          active
            ? "text-white dark:text-black"
            : "border-2 border-gray-300 dark:border-gray-600 group-hover:border-gray-400 scale-95"
        }`}
      >
        {active && (
          <>
            <span aria-hidden className="ckAnimRipple absolute inset-0 rounded-full primaryBackColor dark:bg-white" />
            <span aria-hidden className="ckAnimDotIn absolute inset-0 rounded-full primaryBackColor dark:bg-white" />
            <FiCheck size={12} strokeWidth={3} className="ckAnimDotIn relative" />
          </>
        )}
      </span>
    </button>
  );
};

export default PayPickRow;
