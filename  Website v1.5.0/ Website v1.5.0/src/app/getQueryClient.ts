import { QueryClient } from "@tanstack/react-query";

const makeQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 1000 * 60 * 5,
        gcTime: 1000 * 60 * 30,
        refetchOnWindowFocus: false,
        retry: 1,
      },
    },
  });

// Fresh client per server request (a shared one leaks cache across visitors);
// one per tab in the browser so cache survives route changes.
let browserQueryClient: QueryClient | undefined;
export const getQueryClient = () => {
  if (typeof window === "undefined") return makeQueryClient();
  if (!browserQueryClient) browserQueryClient = makeQueryClient();
  return browserQueryClient;
};
