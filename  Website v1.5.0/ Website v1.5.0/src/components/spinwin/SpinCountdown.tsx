"use client";

import { t } from "@/utils/translation";
import type { Countdown } from "@/hooks/useCountdown";

/**
 * Countdown timer display for next available spin.
 */
interface SpinCountdownProps {
  countdown: Countdown;
  /** Compact style variant. */
  compact?: boolean;
}

const Tile = ({ value, compact }: { value: number; compact?: boolean }) => (
  <span
    className={`flex items-center justify-center rounded-[14px] font-extrabold tabular-nums text-white ${
      compact ? "h-11 w-[52px] text-[22px]" : "h-[54px] w-[62px] text-[27px]"
    }`}
    style={{
      background: "#111014",
      boxShadow: "0 3px 8px rgba(0,0,0,0.45)",
    }}
  >
    {String(value).padStart(2, "0")}
  </span>
);

const Colon = ({ compact }: { compact?: boolean }) => (
  <span
    aria-hidden
    className={`font-extrabold text-white ${
      compact ? "text-[18px]" : "text-[22px]"
    }`}
  >
    :
  </span>
);

const SpinCountdown = ({ countdown, compact }: SpinCountdownProps) => (
  <div className="flex flex-col items-center gap-2">
    <span
      className={`font-semibold text-white ${
        compact ? "text-[15px]" : "text-[18px]"
      }`}
    >
      {t("next_spin_in") || "Next Spin In"}
    </span>

    <div
      className={`flex items-center ${compact ? "gap-1.5" : "gap-2"}`}
      role="timer"
      aria-label={`${t("next_spin_in") || "Next spin in"} ${countdown.label}`}
    >
      <Tile value={countdown.hours} compact={compact} />
      <Colon compact={compact} />
      <Tile value={countdown.minutes} compact={compact} />
      <Colon compact={compact} />
      <Tile value={countdown.seconds} compact={compact} />
    </div>
  </div>
);

export default SpinCountdown;
