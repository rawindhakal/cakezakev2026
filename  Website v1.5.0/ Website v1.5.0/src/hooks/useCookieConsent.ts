import { useEffect, useState } from "react";
import {
  CONSENT_ACCEPTED,
  CONSENT_EVENT,
  CONSENT_KEY,
  readConsent,
} from "@/utils/cookieConsent";

/** Custom hook to track and synchronize visitor cookie consent state across tabs. */
interface CookieConsentResult {
  consent: string | null;
  accepted: boolean;
  answered: boolean;
}

const useCookieConsent = (): CookieConsentResult => {
  const [consent, setConsent] = useState<string | null>(null);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- SSR-unreadable localStorage; same hydration contract as useIsHydrated
    setConsent(readConsent());

    const sync = () => setConsent(readConsent());
    const onStorage = (e: StorageEvent) => {
      // Ignore unrelated storage keys unless storage is cleared wholesale.
      if (e.key === null || e.key === CONSENT_KEY) sync();
    };

    window.addEventListener(CONSENT_EVENT, sync);
    window.addEventListener("storage", onStorage);
    return () => {
      window.removeEventListener(CONSENT_EVENT, sync);
      window.removeEventListener("storage", onStorage);
    };
  }, []);

  return {
    consent,
    accepted: consent === CONSENT_ACCEPTED,
    answered: consent !== null,
  };
};

export default useCookieConsent;

