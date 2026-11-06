"use client";

import { useState } from "react";
import { Provider } from "react-redux";
import { PersistGate } from "redux-persist/integration/react";
import { store, persistor } from "@/redux/store";
import { QueryClientProvider } from "@tanstack/react-query";
import { getQueryClient } from "./getQueryClient";
import AppContent from "./AppContent";
import AppErrorBoundary from "./AppErrorBoundary";
import MotionProvider from "@/components/motion/MotionProvider";

export default function Providers({
  children,
  langCodes,
}: {
  children: React.ReactNode;
  langCodes?: string[];
}) {
  // useState so the server gets one client per request (see getQueryClient).
  const [queryClient] = useState(getQueryClient);

  return (
    <QueryClientProvider client={queryClient}>
      <Provider store={store}>
        {/* Function-child form, not `loading` — the loading form renders null
            on the server, killing SSR HTML. */}
        <PersistGate persistor={persistor}>
          {(bootstrapped: boolean) => (
            <AppErrorBoundary>
              <MotionProvider>
                <AppContent bootstrapped={bootstrapped} langCodes={langCodes}>
                  {children}
                </AppContent>
              </MotionProvider>
            </AppErrorBoundary>
          )}
        </PersistGate>
      </Provider>
    </QueryClientProvider>
  );
}
