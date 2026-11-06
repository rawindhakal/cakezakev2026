import { useCallback, useEffect, useState } from "react";
import { useSelector } from "react-redux";
import { t } from "@/utils/translation";
import { formatDuration, parseUtc, windowKey } from "@/utils/maintenanceWindow";
import { ClockIcon, CloseIcon } from "@/components/icons";

/** Toast notice for upcoming scheduled maintenance windows */
const MaintenanceNotice = () => {
  const setting = useSelector((state: any) => state.Setting);
  const web = setting?.setting?.web_settings;

  const mode = String(web?.website_mode ?? "");
  const startAt = web?.website_mode_start;
  const endAt = web?.website_mode_end;

  const [visible, setVisible] = useState(false);
  const [closing, setClosing] = useState(false);
  // Clock timestamp state for countdown ticker
  const [now, setNow] = useState<number | null>(null);

  const startTime = parseUtc(startAt);
  const endTime = parseUtc(endAt);

  // Check if scheduled maintenance is in the future
  const isUpcoming =
    mode === "0" && startTime !== null && now !== null && startTime > now;

  useEffect(() => {
    // Initialize client clock ticker
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setNow(Date.now());
    const id = setInterval(() => setNow(Date.now()), 30000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    if (!isUpcoming) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setVisible(false);
      return;
    }
    try {
      if (localStorage.getItem(windowKey(startAt, endAt)) === "1") return;
    } catch {
      /* storage blocked (private mode) — fall through and show it */
    }
    setVisible(true);
  }, [isUpcoming, startAt, endAt]);

  const dismiss = useCallback(() => {
    try {
      localStorage.setItem(windowKey(startAt, endAt), "1");
    } catch {
      /* ignore storage errors */
    }
    setClosing(true);
    setTimeout(() => {
      setVisible(false);
      setClosing(false);
    }, 250);
  }, [startAt, endAt]);

  if (!visible || !isUpcoming) return null;

  // Format dates in user local timezone
  const dateTimeFmt = new Intl.DateTimeFormat(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  });
  const timeOnlyFmt = new Intl.DateTimeFormat(undefined, {
    timeStyle: "short",
  });

  // isUpcoming (checked above) guarantees startTime is set by this point.
  const startLabel = dateTimeFmt.format(startTime as number);

  // Format end time label, omitting date if same calendar day
  const endLabel = endTime
    ? new Date(endTime).toDateString() ===
      new Date(startTime as number).toDateString()
      ? timeOnlyFmt.format(endTime)
      : dateTimeFmt.format(endTime)
    : null;

  const duration =
    endTime && startTime ? formatDuration(endTime - startTime) : null;

  return (
    <div
      // Fixed bottom container positioned for RTL/LTR support
      className={`fixed bottom-4 start-1/2 z-[9998] w-[calc(100%-2rem)] max-w-sm -translate-x-1/2 transition-all duration-250 rtl:translate-x-1/2 sm:start-auto sm:end-5 sm:translate-x-0 sm:rtl:translate-x-0 ${
        closing ? "translate-y-3 opacity-0" : "translate-y-0 opacity-100"
      }`}
      role="status"
      aria-live="polite"
    >
      <div
        // Notice card content box
        className="relative flex gap-3 rounded-2xl border p-4 pe-10 text-start"
        style={{
          backgroundColor: "var(--bs-body-bg)",
          borderColor: "var(--border-color)",
          boxShadow: "0 18px 40px -18px rgba(15, 23, 42, 0.28)",
        }}
      >
        <span
          className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full"
          style={{
            backgroundColor:
              "color-mix(in srgb, var(--primary-color) 12%, transparent)",
            color: "var(--primary-color)",
          }}
          aria-hidden="true"
        >
          <ClockIcon size={16} />
        </span>

        <div className="min-w-0">
          <p className="text-sm font-semibold fontColor">
            {t("scheduled_maintenance")}
          </p>
          {/* Maintenance window description */}
          <p className="mt-0.5 text-xs SecondaryTextColor">
            {t("site_will_be_down_from")}{" "}
            {/* Formatted start and end timestamps */}
            <span className="font-medium fontColor [unicode-bidi:isolate]">
              {startLabel}
              {endLabel ? ` – ${endLabel}` : ""}
            </span>
            {duration ? (
              <>
                {" · "}
                <span className="[unicode-bidi:isolate]">{duration}</span>
              </>
            ) : null}
          </p>
        </div>

        <button
          type="button"
          onClick={dismiss}
          aria-label={t("close")}
          className="absolute end-2 top-2 flex h-7 w-7 items-center justify-center rounded-full opacity-60 transition-opacity hover:opacity-100"
        >
          <CloseIcon size={14} className="fontColor" />
        </button>
      </div>
    </div>
  );
};

export default MaintenanceNotice;
