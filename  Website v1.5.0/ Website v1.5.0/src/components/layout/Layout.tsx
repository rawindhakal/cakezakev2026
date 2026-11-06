"use client";

import React, { Suspense, useState, useEffect, useLayoutEffect, useRef } from "react";
import dynamic from "next/dynamic";
import Header from "./Header";
import MobileViewCartPill from "./MobileViewCartPill";
import Footer from "./Footer";

// Back to Top / Spin & Win / Support dock (client-only).
const FloatingActionDock = dynamic(() => import("./FloatingActionDock"), {
  ssr: false,
});
import { setPaymentSetting, setSetting } from "@/redux/slices/settingSlice";
import { setCountrySetting } from "@/redux/slices/countrySettingSlice";
import { useSelector, useDispatch } from "react-redux";
import { useQueryClient } from "@tanstack/react-query";
import * as api from "@/api/apiRoutes";
import { ToastContainer } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import { FiCheck, FiX, FiAlertTriangle, FiInfo } from "react-icons/fi";
import Loader from "../loader/Loader";
import { setFavoriteProductIds } from "@/redux/slices/FavoriteSlice";
import PushNotification from "../firebasenotification/PushNotification";
import LangFile from "@/utils/en.json";
import {
  setAvailableLanguages,
  setSelectedLanguage,
} from "@/redux/slices/languageSlice";
import {
  setChannel,
  setLayoutTheme,
  setDeliveryTime,
  setDeliveryDistance,
  setStoreClosed,
} from "@/redux/slices/shopModeSlice";
import { usePathname } from "next/navigation";
// Untyped JS component; cast to any.
import MaintanceModeUntyped from "../error/MaintanceMode";
const MaintanceMode = MaintanceModeUntyped as any;
import MaintenanceNotice from "../error/MaintenanceNotice";
import CookieConsent from "../cookieconsent/CookieConsent";
import { subscribePublicChannel } from "@/lib/chatWs";
import OfflineOverlay from "../offline/OfflineOverlay";
import NavigationProgress from "../navigation/NavigationProgress";
import useZoneUrlSync from "@/hooks/useZoneUrlSync";
import useZoneAdopt from "@/hooks/useZoneAdopt";
import useZoneRequired from "@/hooks/useZoneRequired";
import useGuestFlagReconcile from "@/hooks/useGuestFlagReconcile";
import useSyncFavoriteIds from "@/hooks/useSyncFavoriteIds";
import { HOME_LAYOUT_INITIAL_SECTION_LIMIT } from "@/constants/homeLayout";
import { homeLayoutKey } from "@/utils/queryKeys";

// Settings are re-checked at most this often when the tab regains focus.
const SETTINGS_REVALIDATE_MS = 1000 * 60 * 5;

// Toast icon per type (styled in globals.css).
const TOAST_ICONS: Record<string, typeof FiInfo> = {
  success: FiCheck,
  error: FiX,
  warning: FiAlertTriangle,
  info: FiInfo,
};
const renderToastIcon = ({ type }: { type?: string }) => {
  const Icon = (type && TOAST_ICONS[type]) || FiInfo;
  return (
    <span className={`appToastIcon appToastIcon--${type || "default"}`}>
      <Icon />
    </span>
  );
};

// Set primary color CSS vars from settings.
const applyPrimaryColor = (webSettings: any, theme?: string) => {
  if (!webSettings) return;
  const root = document.documentElement.style;
  const isDark = theme === "dark";

  const primary = isDark
    ? webSettings.dark_mode_color || webSettings.color
    : webSettings.light_mode_color || webSettings.color;
  const light = isDark
    ? webSettings.dark_mode_color || webSettings.light_color
    : webSettings.light_mode_color || webSettings.light_color;

  if (primary) root.setProperty("--primary-color", primary);
  if (light) root.setProperty("--light-primary-color", light);
};

// Fetch once per page load (survives route changes).
let __settingsFetched = false;
let __languageFetched = false;
// Last coords zone settings were fetched for (skips repeat calls).
let __fetchedCityCoordsKey: string | null = null;

interface LayoutProps {
  children: React.ReactNode;
}

const Layout = ({ children }: LayoutProps) => {
  // Must run before the zone hooks below.
  useZoneAdopt();
  useZoneUrlSync();
  // Zoned routes need a zone: redirect or open the location modal.
  useZoneRequired();
  // Sync wishlist ids per login/location.
  useSyncFavoriteIds();
  // Keep Cart.isGuest consistent with the auth token across rehydration.
  useGuestFlagReconcile();
  const pathname = usePathname();
  const pageRef = useRef<HTMLDivElement>(null);
  // Load the dock when the browser is idle.
  const [dockReady, setDockReady] = useState(false);
  useEffect(() => {
    const ric = (window as any).requestIdleCallback as
      | ((cb: () => void, opts?: { timeout: number }) => number)
      | undefined;
    if (ric) {
      const id = ric(() => setDockReady(true), { timeout: 2500 });
      return () => (window as any).cancelIdleCallback?.(id);
    }
    const t = setTimeout(() => setDockReady(true), 1500);
    return () => clearTimeout(t);
  }, []);
  const prevPathRef = useRef(pathname);
  // Fade page on route change (not on first load).
  useLayoutEffect(() => {
    if (prevPathRef.current === pathname) return;
    prevPathRef.current = pathname;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    // Opacity only; transform breaks fixed children.
    pageRef.current?.animate([{ opacity: 0 }, { opacity: 1 }], {
      duration: 250,
      easing: "ease-out",
    });
  }, [pathname]);
  const dispatch = useDispatch();
  const theme = "light";
  const setting = useSelector((state: any) => state.Setting);
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  const city = useSelector((state: any) => state.City.city);
  const shopMode = useSelector((state: any) => state.ShopMode.mode);
  // Same tab as HomeLayout so the query cache is shared.
  const selectedCategoryId = useSelector(
    (state: any) => state.ShopMode.selectedCategoryId,
  );
  const queryClient = useQueryClient();

  const [loading, setLoading] = useState(false);

  // Favicon from settings, rendered as a React <link> (raw DOM edits crashed navigation).
  const [faviconUrl, setFaviconUrl] = useState<string | null>(null);

  // Maintenance check waits for mount to match SSR.
  const [mounted, setMounted] = useState(false);
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setMounted(true);
  }, []);

  const fetchLanguage = async () => {
    try {
      const response = await api.getSystemLanguages({
        id: 0,
        isDefault: 0,
        systemType: 3,
      });
      if (response.status == 1) {
        if (response.data !== undefined) {
          if (response?.data?.length == 1) {
            try {
              const langRes = await api.getSystemLanguages({
                id: response?.data?.[0]?.id,
                isDefault: 1,
                systemType: 3,
              });
              if (langRes.status == 1) {
                document.documentElement.dir = (
                  langRes?.data?.type || "ltr"
                ).toLowerCase();
                dispatch(setSelectedLanguage({ data: langRes?.data }));
              } else {
                const language = {
                  id: 15,
                  name: "English",
                  code: "en",
                  type: "LTR",
                  system_type: 3,
                  is_default: 1,
                  json_data: LangFile,
                  display_name: "English",
                  system_type_name: "Website",
                };
                dispatch(setSelectedLanguage({ data: language }));
              }
            } catch (error) {
              console.log("error", error);
            }
          } else if (language == null) {
            const langId = response?.data?.find(
              (lang: any) => lang?.is_default == 1,
            )?.id;
            const langRes = await api.getSystemLanguages({
              id: langId,
              isDefault: 1,
              systemType: 3,
            });
            document.documentElement.dir = (
              langRes?.data?.type || "ltr"
            ).toLowerCase();
            dispatch(setSelectedLanguage({ data: langRes?.data }));
          }
          dispatch(setAvailableLanguages({ data: response.data }));
        } else {
          const language = {
            id: 15,
            name: "English",
            code: "en",
            type: "LTR",
            system_type: 3,
            is_default: 1,
            json_data: LangFile,
            display_name: "English",
            system_type_name: "Website",
          };
          dispatch(setSelectedLanguage({ data: language }));
        }
      }
    } catch (error) {
      console.log("Error", error);
    }
  };

  const fetchSetting = async (silent = false) => {
    if (!silent) setLoading(true);
    try {
      const res = await api.getSetting();
      // data is JSON (older API sent base64).
      const setting =
        typeof res.data === "string" ? JSON.parse(atob(res.data)) : res.data;
      dispatch(setSetting({ data: setting }));
      if (setting?.favorite_product_ids) {
        dispatch(setFavoriteProductIds({ data: setting.favorite_product_ids }));
      }
      applyPrimaryColor(setting?.web_settings, theme);
      if (setting?.favicon) {
        setFaviconUrl(setting.favicon);
      }
      if (!silent) setLoading(false);
    } catch (error) {
      if (!silent) setLoading(false);
      console.log("error", error);
    }
  };

  // Settings carry cache_versions, so they have to be re-checked for the
  // version sync to notice anything. Module-scoped fetch guard above runs once
  // per page load; this covers a tab left open.
  useEffect(() => {
    const revalidate = () => {
      if (document.visibilityState === "hidden") return;
      const fetchedAt = setting?.settingsFetchedTime
        ? new Date(setting.settingsFetchedTime).getTime()
        : 0;
      if (Date.now() - fetchedAt < SETTINGS_REVALIDATE_MS) return;
      fetchSetting(true);
    };
    window.addEventListener("focus", revalidate);
    document.addEventListener("visibilitychange", revalidate);
    return () => {
      window.removeEventListener("focus", revalidate);
      document.removeEventListener("visibilitychange", revalidate);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [setting?.settingsFetchedTime]);

  const fetchCountrySetting = async () => {
    try {
      const res = await api.getCountrySetting({
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      const data =
        typeof res.data === "string" ? JSON.parse(atob(res.data)) : res.data;
      dispatch(setCountrySetting({ data }));
    } catch (error) {
      console.log("error", error);
    }
  };

  const fetchPaymentSetting = async () => {
    // Needs city coords.
    if (!city?.latitude || !city?.longitude) return;
    setLoading(true);
    try {
      const res = await api.getPaymentSetting({
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      // status 0 = not deliverable: clear old gateways.
      if (res?.status === 0) {
        dispatch(setPaymentSetting({ data: null }));
      } else {
        dispatch(setPaymentSetting({ data: JSON.parse(atob(res.data)) }));
      }
      setLoading(false);
    } catch (error) {
      dispatch(setPaymentSetting({ data: null }));
      setLoading(false);
      console.log("error", error);
    }
  };

  useEffect(() => {
    // API sends RTL/LTR; dir needs lowercase.
    document.documentElement.dir = (language?.type || "ltr").toLowerCase();
  }, [language?.type]);

  useEffect(() => {
    if (!__settingsFetched) {
      __settingsFetched = true;
      // eslint-disable-next-line react-hooks/set-state-in-effect
      fetchSetting();
    }
    if (!__languageFetched) {
      __languageFetched = true;
      fetchLanguage();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [language?.id]);

  // Refetch zone settings when city coords change.
  useEffect(() => {
    if (!city?.latitude || !city?.longitude) return;
    const coordsKey = `${city.latitude},${city.longitude}`;
    if (__fetchedCityCoordsKey === coordsKey) return;
    __fetchedCityCoordsKey = coordsKey;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    fetchPaymentSetting();
    fetchCountrySetting();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [city?.latitude, city?.longitude]);

  useEffect(() => {
    applyPrimaryColor(setting?.setting?.web_settings, theme);
  }, [theme, setting?.setting?.web_settings]);

  // Home layout on every route keeps the header theme right; device matches HomeLayout's query key.
  const [device, setDevice] = useState("web");
  useEffect(() => {
    const compute = () => {
      const w = window.innerWidth;
      setDevice(w < 768 ? "app" : w < 1024 ? "tablet" : "web");
    };
    compute();
    window.addEventListener("resize", compute);
    return () => window.removeEventListener("resize", compute);
  }, []);

  // Language left the home-layout key, so a language switch has to invalidate.
  const prevLanguageId = useRef(language?.id);
  useEffect(() => {
    if (prevLanguageId.current === language?.id) return;
    prevLanguageId.current = language?.id;
    queryClient.invalidateQueries({ queryKey: ["home-layout"] });
  }, [language?.id, queryClient]);

  useEffect(() => {
    const latitude = city?.latitude || setting?.setting?.default_city?.latitude;
    const longitude =
      city?.longitude || setting?.setting?.default_city?.longitude;
    if (!latitude || !longitude) return;

    let cancelled = false;
    (async () => {
      try {
        // Same key and infinite type as HomeLayout so the cache is shared.
        const infiniteResult: any = await queryClient.fetchInfiniteQuery({
          queryKey: homeLayoutKey({
            latitude,
            longitude,
            categoryId: selectedCategoryId ?? null,
            shopMode,
          }),
          queryFn: async ({ pageParam }: any) => {
            const response = await api.getHomeLayout({
              latitude,
              longitude,
              category_id: selectedCategoryId ?? null,
              limit: HOME_LAYOUT_INITIAL_SECTION_LIMIT,
              offset: pageParam,
              device,
            });
            // Same store-closed shape as HomeLayout.
            if (response?.status === 0 && response?.message) {
              return { storeClosed: true, message: response.message };
            }
            return response?.data ?? null;
          },
          initialPageParam: 0,
          // Page 0 only; HomeLayout paginates.
          getNextPageParam: () => undefined,
          staleTime: 1000 * 60 * 5,
          gcTime: 1000 * 60 * 30,
        });
        if (cancelled) return;
        // Channel config is on page 0.
        const result: any = infiniteResult?.pages?.[0] ?? null;
        // Set before the early return so closed stores update too.
        dispatch(
          setStoreClosed(result?.branch_closed ?? (result?.storeClosed ? 1 : 0)),
        );
        if (!result || result.storeClosed) return;
        const data = result;

        if (process.env.NODE_ENV !== "production") {
          console.log("[CHANNEL TRACE] setChannel payload", {
            available_modes: data?.available_modes,
            nested_available_modes: data?.channel?.available_modes,
            layout_mode: data?.layout_mode,
            zone_slug: data?.zone_slug,
          });
        }
        dispatch(
          setChannel({
            ...data.channel,
            layout_mode: data?.layout_mode ?? data?.channel?.layout_mode,
            available_modes:
              data?.available_modes ?? data?.channel?.available_modes,
            requested: data?.requested ?? data?.channel?.requested,
            channel_label_quick:
              data?.quick_button_label ?? data?.channel_label_quick,
            channel_label_ecommerce:
              data?.ecommerce_button_label ?? data?.channel_label_ecommerce,
            zone_id: data?.zone_id,
            zone_slug: data?.zone_slug,
            search_suggestions: data?.search_suggestions,
          }),
        );
        // Active tab's theme, same pick as HomeLayout — page-level theme must not overwrite it.
        const tabs = data?.category_tabs;
        const activeId = selectedCategoryId ?? (Array.isArray(tabs) ? tabs[0]?.id : null);
        const activeTab = Array.isArray(tabs)
          ? tabs.find((tab: any) => String(tab?.id) === String(activeId))
          : null;
        const theme = activeTab?.background_theme ? activeTab : data?.layout;
        if (theme) dispatch(setLayoutTheme(theme));
        if (data?.time_to_deliver)
          dispatch(setDeliveryTime(data.time_to_deliver));
        if (data?.distance) dispatch(setDeliveryDistance(data.distance));
      } catch (error) {
        console.log("shop-mode sync error", error);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [
    shopMode,
    selectedCategoryId,
    city?.latitude,
    city?.longitude,
    language?.id,
    setting?.setting?.default_city?.latitude,
    setting?.setting?.default_city?.longitude,
    device,
    queryClient,
    dispatch,
  ]);

  // Live maintenance toggle (no loader flash).
  useEffect(() => {
    const unsubscribe = subscribePublicChannel(
      "maintenance",
      "maintenance.toggled",
      async () => {
        try {
          const res = await api.getSetting();
          const next =
            typeof res.data === "string"
              ? JSON.parse(atob(res.data))
              : res.data;
          dispatch(setSetting({ data: next }));
          applyPrimaryColor(next?.web_settings, theme);
        } catch (error) {
          console.log("maintenance refresh failed", error);
        }
      },
    );
    return unsubscribe;
  }, [dispatch]);

  const isMaintenanceMode =
    mounted && setting?.setting?.web_settings?.website_mode == 1;

  // Settings are persisted, so a returning visitor already has last session's
  // copy — paint from it and let the fetch revalidate behind the page. Only a
  // first-ever visit has nothing to show and has to wait.
  const hasPersistedSetting = !!setting?.setting;

  let content;
  if (loading && !hasPersistedSetting) {
    content = <Loader screen="full" />;
  } else if (isMaintenanceMode) {
    content = (
      <MaintanceMode
        message={setting?.setting?.web_settings?.website_mode_remark}
        endAt={setting?.setting?.web_settings?.website_mode_end}
      />
    );
  } else {
    content = (
      <PushNotification>
        {/* Own Suspense (useSearchParams). */}
        <Suspense fallback={null}>
          <NavigationProgress />
        </Suspense>

        {/* Upcoming maintenance notice. */}
        <MaintenanceNotice />

        {/* Suspense around Header only, so a bailout never blanks the page. */}
        <Suspense fallback={<div className="h-[64px] w-full" />}>
          <Header />
        </Suspense>
        {/* Fill viewport below header (not on payment status). */}
        <div
          ref={pageRef}
          style={
            pathname === "/web-payment-status"
              ? undefined
              : {
                  minHeight:
                    "calc(100vh - var(--layout-header-h, 0px) - var(--layout-strip-h, 0px))",
                }
          }
        >
          {children}
        </div>
        {/* Full-screen search page has no footer (app-style). */}
        {!/\/search\/?$/.test(pathname || "") && <Footer />}
        {/* Floating dock (loaded when idle). */}
        {dockReady && <FloatingActionDock />}
        <MobileViewCartPill />
        {/* Shows only if enabled and not answered. */}
        <CookieConsent />
        <ToastContainer
          theme={theme || "light"}
          rtl={language?.type === "RTL"}
          position={language?.type === "RTL" ? "top-left" : "top-right"}
          autoClose={3000}
          hideProgressBar={true}
          newestOnTop
          closeOnClick
          pauseOnHover
          pauseOnFocusLoss={false}
          draggable
          icon={renderToastIcon}
          className="appToastContainer"
          bodyClassName="appToastBody"
          toastClassName="appToast"
          progressClassName="appToastProgress"
        />
      </PushNotification>
    );
  }

  return (
    <section className="overflow-x-clip">
      {/* React hoists this into <head>; rendered only once settings give a favicon. */}
      {faviconUrl && (
        <link
          rel="shortcut icon"
          type="image/x-icon"
          href={faviconUrl}
          sizes="16x16 32x32 64x64"
        />
      )}
      <OfflineOverlay />
      {content}
    </section>
  );
};

export default Layout;
