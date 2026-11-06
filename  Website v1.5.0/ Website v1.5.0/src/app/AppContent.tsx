"use client";

import { Suspense, useEffect, useState } from "react";
import { useSelector, useDispatch } from "react-redux";
import {
  setSelectedLanguage,
  setLanguageCodes,
} from "@/redux/slices/languageSlice";
import * as api from "@/api/apiRoutes";
import Loader from "@/components/loader/Loader";
import Layout from "@/components/layout/Layout";
import AppInstallBottomSheet from "@/components/app-install-bottom-sheet/AppInstallBottomSheet";
import { usePathname } from "next/navigation";
import Script from "next/script";
import { GA_MEASUREMENT_ID, pageview } from "@/utils/gtag";
import useLanguages from "@/hooks/useLanguages";
import useCookieConsent from "@/hooks/useCookieConsent";
import { markTranslationsHydrated } from "@/utils/translation";
import { useAppNavigate } from "@/hooks/useAppNavigate";
import useLocaleQueryInvalidation from "@/hooks/useLocaleQueryInvalidation";
import useCacheVersionSync from "@/hooks/useCacheVersionSync";
import NavigationEvents from "./NavigationEvents";

export default function AppContent({
  children,
  bootstrapped,
  langCodes,
}: {
  children: React.ReactNode;
  bootstrapped: boolean;
  langCodes?: string[];
}) {
  const pathname = usePathname();
  const dispatch = useDispatch();
  const { parseLangPath, defaultCode } = useLanguages();
  // Navigation in flight (searchParams-only updates don't trigger it).
  const { isPending: loading } = useAppNavigate();
  const [, forceTick] = useState(0);
  useLocaleQueryInvalidation();
  // Refetch a data group when the backend says its version changed.
  useCacheVersionSync();

  // t() stays English until redux-persist rehydrates (matches SSR). Then unpin
  // it and re-render this subtree once so raw t() calls pick up the language.
  useEffect(() => {
    if (!bootstrapped) return;
    markTranslationsHydrated();
    // eslint-disable-next-line react-hooks/set-state-in-effect
    forceTick((n) => n + 1);
  }, [bootstrapped]);

  // Seed SSR language codes so /ur/... isn't parsed as a zone on first paint.
  useEffect(() => {
    if (Array.isArray(langCodes) && langCodes.length) {
      dispatch(setLanguageCodes(langCodes));
    }
  }, [langCodes, dispatch]);
  const selectedLanguage = useSelector(
    (state: any) => state.Language.selectedLanguage,
  );
  const availableLanguages = useSelector(
    (state: any) => state.Language.availableLanguages,
  );

  // URL → Redux: URL language is source of truth. Redux → URL lives in the
  // switcher (Header.handleLanguageChange), not here.
  useEffect(() => {
    const { lang: urlLang } = parseLangPath(pathname || "/");
    const urlCode = urlLang || defaultCode;
    const reduxCode = selectedLanguage?.code;
    if (!reduxCode || urlCode === reduxCode) return;

    const match = availableLanguages?.find((l: any) => l?.code === urlCode);
    if (!match?.id) return;

    // Defer a tick: the switcher dispatches before router.push updates
    // pathname, so a stale pathname would flip the language straight back.
    let active = true;
    const timer = setTimeout(() => {
      if (!active) return;
      // Refetch by id — the list entry lacks json_data, which t() needs.
      api
        .getSystemLanguages({ id: match.id, isDefault: 0, systemType: 3 })
        .then((res: any) => {
          if (!active || res?.status != 1 || !res?.data) return;
          dispatch(setSelectedLanguage({ data: res.data }));
          if (res.data?.type) {
            document.documentElement.dir = res.data.type.toLowerCase();
          }
        })
        .catch((err: any) => console.log("URL language adopt failed:", err?.message));
    }, 0);
    return () => {
      active = false;
      clearTimeout(timer);
    };
  }, [
    pathname,
    availableLanguages,
    selectedLanguage?.code,
    dispatch,
    parseLangPath,
    defaultCode,
  ]);

  const setting = useSelector((state: any) => state.Setting?.setting);

  // Clarity keys vary by backend build: `_web` first, then `_customer`, then
  // bare — top-level or under web_settings.
  const clarityStatus =
    setting?.clarity_status_web ??
    setting?.web_settings?.clarity_status_web ??
    setting?.clarity_status_customer ??
    setting?.web_settings?.clarity_status_customer ??
    setting?.clarity_status ??
    setting?.web_settings?.clarity_status;

  const clarityProjectId = String(
    setting?.clarity_project_id_web ??
      setting?.web_settings?.clarity_project_id_web ??
      setting?.clarity_project_id_customer ??
      setting?.web_settings?.clarity_project_id_customer ??
      setting?.clarity_project_id ??
      setting?.web_settings?.clarity_project_id ??
      process.env.NEXT_PUBLIC_CLARITY_PROJECT_ID ??
      "",
  ).trim();

  const isClarityEnabled =
    (String(clarityStatus) === "1" || clarityStatus === true) &&
    Boolean(clarityProjectId);

  // Consent required only when the banner is enabled (else none can be given).
  const consentRequired =
    String(setting?.web_settings?.cookie_consent_enabled ?? "") === "1";
  const { accepted: cookiesAccepted } = useCookieConsent();
  const analyticsAllowed = !consentRequired || cookiesAccepted;

  return (
    <>
      {/* Suspense required by useSearchParams(). Reports GA page views. */}
      <Suspense fallback={null}>
        <NavigationEvents />
      </Suspense>
      {/* GA4. send_page_view off — NavigationEvents tracks views. */}
      {GA_MEASUREMENT_ID && analyticsAllowed && (
        <>
          <Script
            id="ga-lib"
            strategy="lazyOnload"
            src={`https://www.googletagmanager.com/gtag/js?id=${GA_MEASUREMENT_ID}`}
          />
          <Script
            id="ga-init"
            strategy="lazyOnload"
            // First view here — gtag doesn't exist on mount.
            onReady={() =>
              pageview(window.location.pathname + window.location.search)
            }
          >
            {`window.dataLayer = window.dataLayer || [];
              function gtag(){dataLayer.push(arguments);}
              gtag('js', new Date());
              gtag('config', '${GA_MEASUREMENT_ID}', { send_page_view: false });`}
          </Script>
        </>
      )}
      {isClarityEnabled && clarityProjectId && analyticsAllowed && (
        <Script
          id="ms-clarity"
          key={clarityProjectId}
          strategy="lazyOnload"
        >
          {`(function(c,l,a,r,i,t,y){
              c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};
              t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;
              y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);
          })(window, document, "clarity", "script", "${clarityProjectId}");`}
        </Script>
      )}
      {loading && <Loader screen="full" />}
      {/* Once here so Header/Footer persist across navigations. */}
      <Layout>{children}</Layout>
      <AppInstallBottomSheet />
    </>
  );
}
