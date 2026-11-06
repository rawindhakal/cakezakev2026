import { useCallback, useEffect, useRef, useState } from "react";
import useStandalone from "@/hooks/useStandalone";
import { useSelector } from "react-redux";
import Image from "next/image";
import Link from "next/link";

// Mobile-only "install our app" sheet. Once per session, 7-day dismissal.
// Opens after 6s or first interaction, whichever comes first.

const LS_DISMISSED = "app_install_prompt_dismissed"; // "1" once dismissed
const LS_LAST_SHOWN = "app_install_prompt_last_shown"; // dismissal timestamp (ms)
const SS_SHOWN_THIS_SESSION = "app_install_prompt_session_shown"; // "1" per tab session

const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;
const SHOW_DELAY_MS = 6000;

const isBrowser = () => typeof window !== "undefined";

const getUserAgent = (): string => {
  if (!isBrowser()) return "";
  return navigator.userAgent || navigator.vendor || (window as any).opera || "";
};

const isAndroidUA = (ua: string) => /android/i.test(ua);
const isIOSUA = (ua: string) =>
  /iPad|iPhone|iPod/.test(ua) && !(isBrowser() && (window as any).MSStream);

// iPadOS reports as "Macintosh" — tablets intentionally excluded.
const isMobileDevice = (ua: string) => isAndroidUA(ua) || isIOSUA(ua);

const isDismissedWithin7Days = () => {
  if (!isBrowser()) return false;
  try {
    if (localStorage.getItem(LS_DISMISSED) !== "1") return false;
    const last = Number.parseInt(
      localStorage.getItem(LS_LAST_SHOWN) || "0",
      10,
    );
    if (!last) return false;
    return Date.now() - last < SEVEN_DAYS_MS;
  } catch {
    return false;
  }
};

const shownThisSession = () => {
  if (!isBrowser()) return false;
  try {
    return sessionStorage.getItem(SS_SHOWN_THIS_SESSION) === "1";
  } catch {
    return false;
  }
};

const AppInstallBottomSheet = () => {
  const [visible, setVisible] = useState(false);
  const [closing, setClosing] = useState(false);
  const isStandalone = useStandalone();

  const settings = useSelector((state: any) => state.Setting.setting);
  // Wait for a city — else this sheet stacks over the blocking location modal.
  const hasCity = useSelector((state: any) => state.City.city != null);

  const triggeredRef = useRef(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const ua = getUserAgent();
  const isIOS = isIOSUA(ua);

  const web = settings?.web_settings;
  const appName =
    web?.web_name || process.env.NEXT_PUBLIC_WEB_NAME || "eCommerce";
  const webLogo = web?.web_logo;
  const androidAppLink = web?.android_app_url;
  const iosAppLink = web?.ios_app_url;
  // API sends "" for an unconfigured store — normalize to undefined.
  const rawStoreLink = isIOS ? iosAppLink : androidAppLink;
  const storeLink =
    typeof rawStoreLink === "string" && rawStoreLink.trim()
      ? rawStoreLink.trim()
      : undefined;

  // No store URL for this platform → hide (CTA would open a blank tab).
  const eligible =
    isMobileDevice(ua) &&
    !!storeLink &&
    !isStandalone &&
    !isDismissedWithin7Days() &&
    !shownThisSession() &&
    hasCity;

  const open = useCallback(() => {
    if (triggeredRef.current || !eligible) return;
    triggeredRef.current = true;
    try {
      sessionStorage.setItem(SS_SHOWN_THIS_SESSION, "1");
    } catch {
      /* storage may be unavailable (private mode) – fall through */
    }
    setVisible(true);
  }, [eligible]);

  useEffect(() => {
    if (!eligible) return;

    timerRef.current = setTimeout(open, SHOW_DELAY_MS);

    const onInteract = () => open();
    const events = ["scroll", "click", "touchstart", "keydown"];
    events.forEach((e) =>
      window.addEventListener(e, onInteract, { once: true, passive: true }),
    );

    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
      events.forEach((e) => window.removeEventListener(e, onInteract));
    };
  }, [eligible, open]);

  const dismiss = useCallback(() => {
    try {
      localStorage.setItem(LS_DISMISSED, "1");
      localStorage.setItem(LS_LAST_SHOWN, String(Date.now()));
    } catch {
      /* ignore storage errors */
    }
    setClosing(true);
    setTimeout(() => {
      setVisible(false);
      setClosing(false);
    }, 280);
  }, []);

  if (!visible) return null;

  return (
    <div
      className="ai-sheet-root fixed inset-0 z-[9999] flex items-end justify-center md:hidden"
      role="dialog"
      aria-modal="true"
      aria-label="Install our app"
    >
      <div
        className={`absolute inset-0 bg-black/50 transition-opacity duration-300 ${
          closing ? "opacity-0" : "opacity-100"
        }`}
        onClick={dismiss}
      />

      <div
        className={`relative w-full max-w-md bg-white dark:bg-neutral-900 rounded-t-[24px] shadow-[0_-6px_30px_rgba(0,0,0,0.2)] px-5 pt-3 pb-[calc(18px+env(safe-area-inset-bottom))] ${
          closing
            ? "animate-[aiSlideDown_0.28s_ease-in_forwards]"
            : "animate-[aiSlideUp_0.36s_cubic-bezier(0.16,1,0.3,1)_forwards]"
        }`}
      >
        <div className="flex justify-center pb-4">
          <span className="h-1.5 w-11 rounded-full bg-gray-300 dark:bg-neutral-600" />
        </div>

        <div className="mb-5">
          {webLogo ? (
            <Image
              src={webLogo}
              alt={appName}
              width={140}
              height={40}
              className="h-9 w-auto object-contain mb-2.5"
            />
          ) : (
            <h3 className="text-lg font-bold secondryTextColor mb-1">
              {appName}
            </h3>
          )}
          <p className="text-sm leadColor leading-relaxed">
            Get a better experience in our mobile app — faster checkout,
            app-only offers & live order tracking.
          </p>
        </div>

        <div className="flex gap-2.5">
          <Link
            href={storeLink || "#"}
            target="_blank"
            rel="noopener noreferrer"
            onClick={dismiss}
            className="flex-1 text-center primaryBackColor text-white rounded-lg py-2.5 px-3 font-semibold text-sm whitespace-nowrap transition-opacity hover:opacity-90"
          >
            Get the App
          </Link>
          <button
            type="button"
            onClick={dismiss}
            className="flex-1 rounded-lg py-2.5 px-3 font-semibold text-sm whitespace-nowrap bg-gray-100 dark:bg-neutral-800 secondryTextColor transition-colors hover:bg-gray-200"
          >
            Continue on Website
          </button>
        </div>
      </div>

      <style jsx>{`
        @keyframes aiSlideUp {
          from {
            transform: translateY(100%);
          }
          to {
            transform: translateY(0);
          }
        }
        @keyframes aiSlideDown {
          from {
            transform: translateY(0);
          }
          to {
            transform: translateY(100%);
          }
        }
      `}</style>
    </div>
  );
};

export default AppInstallBottomSheet;
