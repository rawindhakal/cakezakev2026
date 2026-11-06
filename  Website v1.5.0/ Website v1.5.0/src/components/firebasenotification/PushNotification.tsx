"use client";

import { useEffect, type ReactNode } from "react";
import { useDispatch } from "react-redux";

// Dynamically import Firebase to keep it off the initial bundle

interface PushNotificationLayoutProps {
  children: ReactNode;
}

const PushNotificationLayout = ({ children }: PushNotificationLayoutProps) => {
  const dispatch = useDispatch();

  useEffect(() => {
    // Track unmount state and active listener subscription
    let cancelled = false;
    let unsubscribe: (() => void) | null = null;

    import("@/utils/firebase")
      .then(({ fetchToken, onMessageListener, registerServiceWorker, isFirebaseConfigured }) => {
        if (cancelled || !isFirebaseConfigured()) return;
        registerServiceWorker();
        // Fetch existing FCM token without prompting on page load
        fetchToken(dispatch);
        // Fires for EVERY foreground message, not just the first.
        unsubscribe = onMessageListener((payload) => {
          const note = payload?.notification || payload?.data;
          // Guard the constructor: it throws if permission isn't granted.
          if (
            note?.title &&
            typeof Notification !== "undefined" &&
            Notification.permission === "granted"
          ) {
            new Notification(note.title, {
              body: note.body,
              icon: note.icon,
            });
          }
        });
        if (cancelled) {
          // Unmounted while onMessageListener was being set up.
          unsubscribe?.();
          unsubscribe = null;
        }
      })
      .catch((err) => console.error("Failed to load firebase:", err?.message));

    return () => {
      cancelled = true;
      unsubscribe?.();
    };
  }, [dispatch]);

  return <>{children}</>;
};

export default PushNotificationLayout;
