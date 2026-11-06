"use client";

import React, { useState, useEffect } from "react";
import { useSelector } from "react-redux";
import { t } from "@/utils/translation";
import { usePathname } from "next/navigation";
import useStandalone from "@/hooks/useStandalone";

const MobileBottomSheet = () => {
  const isStandalone = useStandalone();
  const [showAppNotInstalledPopup, setShowAppNotInstalledPopup] =
    useState(false);
  const settings = useSelector((state: any) => state.Setting.setting);

  const path = usePathname();

  const androidAppLink = settings?.web_settings?.android_app_url;
  const iosAppLink = settings?.web_settings?.ios_app_url;
  const appName = process.env.NEXT_PUBLIC_WEB_NAME || "eCommerce";

  // Deep link URI scheme from settings or fallback
  const appScheme =
    settings?.deeplink_schema || process.env.NEXT_PUBLIC_WEB_NAME || "eCommerce";

  const [isAndroid, setIsAndroid] = useState(false);
  const [isIOS, setIsIOS] = useState(false);
  const [isMobileWidth, setIsMobileWidth] = useState(false);

  const currentStoreLink = isAndroid
    ? androidAppLink
    : isIOS
      ? iosAppLink
      : androidAppLink;

  useEffect(() => {
    if (typeof window === "undefined") return;
    const userAgent =
      navigator.userAgent || navigator.vendor || (window as any).opera || "";
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setIsAndroid(/android/i.test(userAgent));
    setIsIOS(/iPad|iPhone|iPod/.test(userAgent) && !(window as any).MSStream);

    const updateWidth = () => setIsMobileWidth(window.innerWidth < 769);
    updateWidth();
    window.addEventListener("resize", updateWidth);
    return () => window.removeEventListener("resize", updateWidth);
  }, []);

  useEffect(() => {
    const handleVisibilityChange = () => {
      if (!document.hidden) {
        if (Date.now() - (window as any).lastDeepLinkAttempt < 1000) {
          setShowAppNotInstalledPopup(false);
        }
      }
    };

    document.addEventListener("visibilitychange", handleVisibilityChange);
    return () => {
      document.removeEventListener("visibilitychange", handleVisibilityChange);
    };
  }, []);

  const attemptDeepLink = () => {
    // Sanitize app scheme name for deep link URL
    const sanitizedAppName =
      appScheme
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]/g, "") || "app";

    const currentPath = path;

    const hostname =
      typeof window !== "undefined" ? window.location.hostname : "";

    let deepLink = `${sanitizedAppName}://${hostname}${currentPath}`;

    (window as any).lastDeepLinkAttempt = Date.now();

    const appCheckTimeout = setTimeout(() => {
      if (!document.hidden) {
        console.error("App not installed, showing popup");
        setShowAppNotInstalledPopup(true);
      }
    }, 2000);

    if (isIOS) {
      const iframe = document.createElement("iframe");
      iframe.style.display = "none";
      iframe.src = deepLink;
      document.body.appendChild(iframe);

      setTimeout(() => {
        document.body.removeChild(iframe);
      }, 100);
    }

    if (isAndroid) {
      window.onerror = function (message) {
        if (
          String(message).includes("Failed to launch") &&
          String(message).includes("intent://")
        ) {
          clearTimeout(appCheckTimeout);

          setShowAppNotInstalledPopup(true);

          window.onerror = null;
          return true;
        }
      };
    }

    try {
      // Trigger custom app deep link URL
      // eslint-disable-next-line @next/next/no-location-assign-relative-destination
      window.location.href = deepLink;
    } catch (e) {
      console.error("Error opening app:", e);
      clearTimeout(appCheckTimeout);

      setShowAppNotInstalledPopup(true);
    }
  };

  // Auto-attempt deep link once per session on mobile
  useEffect(() => {
    if (!isMobileWidth || isStandalone) return;
    if (!isAndroid && !isIOS) return;
    if (sessionStorage.getItem("hasAttemptedDeepLink")) return;
    sessionStorage.setItem("hasAttemptedDeepLink", "true");
    // eslint-disable-next-line react-hooks/set-state-in-effect -- navigates away / arms a timeout; not derivable from render
    attemptDeepLink();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isMobileWidth, isStandalone, isAndroid, isIOS]);


  const handleDownloadApp = () => {
    setShowAppNotInstalledPopup(false);

    if (currentStoreLink) {
      window.location.href = currentStoreLink;
    } else {
      if (isAndroid) {
        window.location.href = `https://play.google.com/store/search?q=${appName}&c=apps`;
      } else if (isIOS) {
        window.location.href = `https://apps.apple.com/search?term=${appName}`;
      }
    }
  };

  if (!isMobileWidth) {
    return null;
  }
  // Skip deep link check if running in standalone web app mode
  if (isStandalone) {
    return null;
  }

  return (
    <>
      {showAppNotInstalledPopup && (
        <div className="fixed inset-0 z-[9999] flex items-center justify-center p-4">
          <div
            className="absolute inset-0 bg-black/50 backdrop-blur-sm"
            onClick={() => setShowAppNotInstalledPopup(false)}
          />

          <div className="relative footer rounded-2xl p-6 max-w-sm w-full shadow-xl">
            <h3 className="text-lg font-bold secondryTextColor mb-3">
              {t("appNotInstalled")}
            </h3>
            <p className="text-sm text-white mb-6">
              {isAndroid
                ? t("downloadPromptPlayStore")
                : t("downloadPromptAppStore")}
            </p>

            <div className="flex gap-3">
              <button
                className="flex-1 primaryBackColor text-white rounded-lg py-3 px-4 font-semibold text-base transition-opacity hover:opacity-90"
                onClick={handleDownloadApp}
              >
                {isAndroid ? t("playStore") : t("appStore")}
              </button>
              <button
                className="flex-1 text-white bg-black rounded-lg py-3 px-4 font-semibold text-base transition-colors hover:bg-gray-200"
                onClick={() => setShowAppNotInstalledPopup(false)}
              >
                {t("cancel")}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};

export default MobileBottomSheet;
