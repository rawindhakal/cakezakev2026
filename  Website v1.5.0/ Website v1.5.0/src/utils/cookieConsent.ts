// Shared cookie-consent choice: banner writes it, analytics scripts read it.
// Versioned key — bump to .v2 to re-prompt everyone after a policy change.
export const CONSENT_KEY = "cookie_consent.v1";

export const CONSENT_ACCEPTED = "accepted";
export const CONSENT_DECLINED = "declined";

// Fires on `window` so scripts react in the same page view. Custom event
// because `storage` only fires in other tabs, not the one that wrote it.
export const CONSENT_EVENT = "cookieconsentchange";

// Stored choice, or null if unanswered (always null on the server).
export const readConsent = (): string | null => {
  if (typeof window === "undefined") return null;
  try {
    return localStorage.getItem(CONSENT_KEY);
  } catch {
    return null; // Storage blocked (private mode) — treat as not consented.
  }
};

export const hasAcceptedCookies = (): boolean =>
  readConsent() === CONSENT_ACCEPTED;

// Persist the choice and notify listeners in this tab.
export const writeConsent = (
  answer: typeof CONSENT_ACCEPTED | typeof CONSENT_DECLINED,
): void => {
  try {
    localStorage.setItem(CONSENT_KEY, answer);
  } catch {
    /* ignore — the event below still fires */
  }
  try {
    window.dispatchEvent(new CustomEvent(CONSENT_EVENT, { detail: answer }));
  } catch {
    /* CustomEvent unavailable — nothing else to do */
  }
};
