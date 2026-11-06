import { getApp, getApps, initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import {
  deleteToken,
  getMessaging,
  getToken,
  isSupported,
  onMessage,
  type Messaging,
  type MessagePayload,
} from "firebase/messaging";
import { setFcmToken } from "@/redux/slices/userSlice";
import { createStickyNote } from "./stickynote";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID,
};
// Push needs real Firebase credentials; the shipped .env holds "xxxx" placeholders.
export const isFirebaseConfigured = (): boolean => {
  const k = process.env.NEXT_PUBLIC_FIREBASE_API_KEY || "";
  return k.length > 0 && !/^x+$/i.test(k);
};

const app = !getApps().length ? initializeApp(firebaseConfig) : getApp();
const auth = getAuth(app);
let messaging: Messaging | null = null;

const getMessagingInstance = async (): Promise<Messaging | null> => {
  if (messaging) return messaging;
  if (typeof window === "undefined") return null;

  try {
    const isSupportedBrowser = await isSupported();
    if (isSupportedBrowser) {
      messaging = getMessaging(app);
      return messaging;
    } else {
      if (typeof window !== "undefined" && sessionStorage.getItem("hide-unsupported-browser-note") !== "true") {
        console.log("Firebase Messaging is not supported in this browser.");
        createStickyNote();
      }
      return null;
    }
  } catch (err) {
    console.error("Error checking messaging support:", err);
    return null;
  }
};

export const registerServiceWorker = (): void => {
  if (!isFirebaseConfigured()) return;
  if (typeof window !== "undefined" && "serviceWorker" in navigator) {
    navigator.serviceWorker
      .register("/firebase-messaging-sw.js")
      .then((registration) => {
        console.log(
          "Service Worker registration successful, scope is:",
          registration.scope
        );
      })
      .catch((err) => {
        console.error("Service Worker registration failed:", err);
      });
  }
};

// Fetches the FCM token. opts.prompt (default false) controls whether it may
// show the permission dialog — only pass true from a real user gesture, never
// on mount, or it fails Lighthouse's audit and burns the one-shot permission.
// Returns the token (or null on failure) so a gesture handler can use it
// immediately without waiting on a redux re-render.
export const fetchToken = async (
  dispatch: (action: any) => void,
  { prompt = false }: { prompt?: boolean } = {},
): Promise<string | null> => {
  try {
    if (typeof Notification === "undefined") return null;

    const messagingInstance = await getMessagingInstance();
    if (!messagingInstance) {
      console.log("Messaging not initialized, can't fetch token.");
      return null;
    }

    // "default" means undecided — asking here is what triggers the dialog.
    if (Notification.permission !== "granted") {
      if (!prompt || Notification.permission === "denied") return null;
      const permission = await Notification.requestPermission();
      if (permission !== "granted") {
        console.log("Unable to get permission to notify.");
        return null;
      }
    }

    const currentToken = await getToken(messagingInstance, {
      vapidKey: process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY,
    });

    if (currentToken) {
      dispatch(setFcmToken({ data: currentToken }));
      return currentToken;
    }
    console.log(
      "No registration token available. Request permission to generate one."
    );
    return null;
  } catch (err) {
    console.error("An error occurred while retrieving token.", err);
    return null;
  }
};

// Subscribes to every foreground FCM message via callback (a Promise would
// only ever deliver the first). Returns an unsubscribe function.
export const onMessageListener = (
  callback?: (payload: MessagePayload) => void,
): (() => void) => {
  let unsubscribe = () => {};
  getMessagingInstance().then((messagingInstance) => {
    if (messagingInstance) {
      unsubscribe = onMessage(messagingInstance, (payload) => {
        console.log("Foreground message received. ", payload);
        callback?.(payload);
      });
    }
  });
  return () => unsubscribe();
};

// Returns this device's FCM token and unregisters it, so logout/account
// deletion can hand it to the backend and stop push to this browser.
export const revokeToken = async (): Promise<string> => {
  const messagingInstance = await getMessagingInstance();
  if (!messagingInstance) return "";

  const token = await getToken(messagingInstance, {
    vapidKey: process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY,
  }).catch((err) => {
    console.error("revokeToken: getToken failed", err);
    return "";
  });

  await deleteToken(messagingInstance).catch((err) => {
    console.error("revokeToken: deleteToken failed", err);
  });

  return token || "";
};

export { app, auth };
