import { useCallback, useEffect, useState } from "react";
import { useSelector } from "react-redux";
import { t } from "@/utils/translation";
import {
  CONSENT_ACCEPTED,
  CONSENT_DECLINED,
  readConsent,
  writeConsent,
} from "@/utils/cookieConsent";
import { CookieIcon } from "@/components/icons";

// Bottom cookie banner, driven by web_settings.cookie_consent_*; choice persists via utils/cookieConsent and gates analytics in _app.js.
const CookieConsent = () => {
  const setting = useSelector((state: any) => state.Setting);
  const web = setting?.setting?.web_settings;

  const enabled = String(web?.cookie_consent_enabled ?? "") === "1";
  const title = web?.cookie_consent_title;
  const description = web?.cookie_consent_description;

  const [visible, setVisible] = useState(false);
  const [closing, setClosing] = useState(false);

  // Gated to mount: redux-persist/localStorage aren't readable during SSR.
  useEffect(() => {
    if (!enabled) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setVisible(false);
      return;
    }
    if (readConsent()) return;
    setVisible(true);
  }, [enabled]);

  const respond = useCallback(
    (answer: typeof CONSENT_ACCEPTED | typeof CONSENT_DECLINED) => {
      // Fires the in-tab event the analytics gate listens for.
      writeConsent(answer);
      setClosing(true);
      setTimeout(() => {
        setVisible(false);
        setClosing(false);
      }, 250);
    },
    [],
  );

  if (!visible || !enabled || !description) return null;

  return (
    <div
      // Full-width bar above mobile bottom nav; z below MaintenanceNotice/support.
      className={`fixed inset-x-0 bottom-[calc(3.75rem+env(safe-area-inset-bottom))] z-[9997] transition-all duration-300 md:bottom-0 ${
        closing ? "translate-y-full opacity-0" : "translate-y-0 opacity-100"
      }`}
      role="dialog"
      aria-live="polite"
      aria-label={title || t("cookie_consent")}
    >
      <div
        className="border-t"
        style={{
          backgroundColor: "var(--bs-body-bg)",
          borderColor: "var(--border-color)",
          boxShadow: "0 -12px 32px -20px rgba(15, 23, 42, 0.35)",
        }}
      >
        {/* Same container as rest of site, for matching gutters. */}
        <div className="container flex flex-col gap-3 py-3.5 text-start sm:flex-row sm:items-center sm:gap-5 sm:py-4">
          <div className="flex min-w-0 flex-1 items-start gap-3">
            <span
              className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full"
              style={{
                backgroundColor:
                  "color-mix(in srgb, var(--primary-color) 12%, transparent)",
                color: "var(--primary-color)",
              }}
              aria-hidden="true"
            >
              <CookieIcon size={16} />
            </span>

            <div className="min-w-0">
              <p className="text-sm font-semibold fontColor">
                {title || t("cookie_consent")}
              </p>
              <p className="mt-0.5 text-xs SecondaryTextColor sm:text-[13px]">
                {description}
              </p>
            </div>
          </div>

          {/* Decline/Accept kept equal weight, no dark-pattern nudging. */}
          <div className="flex shrink-0 items-center gap-2 ps-11 sm:ps-0">
            <button
              type="button"
              onClick={() => respond(CONSENT_DECLINED)}
              className="rounded-lg border px-4 py-2 text-xs font-semibold fontColor transition-colors hover:bg-gray-50 dark:hover:bg-zinc-800 sm:text-[13px]"
              style={{ borderColor: "var(--border-color)" }}
            >
              {t("decline")}
            </button>
            <button
              type="button"
              onClick={() => respond(CONSENT_ACCEPTED)}
              className="rounded-lg border px-4 py-2 text-xs font-semibold transition-colors sm:text-[13px]"
              style={{
                borderColor: "var(--primary-color)",
                color: "var(--primary-color)",
              }}
            >
              {t("accept")}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CookieConsent;
