import { useCallback } from "react";
import { usePathname, useRouter } from "next/navigation";
import useLanguages from "@/hooks/useLanguages";
import { buildLocalizedPath } from "@/utils/canonicalUrl";

/** Hook providing navigation callback to switch current page language. */
const useLanguageSwitch = () => {
  const router = useRouter();
  const pathname = usePathname();
  const { parseLangPath, defaultCode } = useLanguages();

  return useCallback(
    (code: string) => {
      if (!code) return;
      const currentPath = pathname || "/";
      // Strip existing language segment from current path.
      const { rest } = parseLangPath(currentPath);
      const restPath = `/${rest.join("/")}`;

      // Construct localized path preserving zone segment.
      const nextPath = buildLocalizedPath({
        lang: code,
        zone: null,
        path: restPath,
        defaultCode,
      });

      const publicQuery = new URLSearchParams(window.location.search);
      publicQuery.delete("zone");
      publicQuery.delete("lang");
      publicQuery.delete("slug");
      const qs = publicQuery.toString();
      router.push(qs ? `${nextPath}?${qs}` : nextPath);
    },
    [router, pathname, parseLangPath, defaultCode],
  );
};

export default useLanguageSwitch;

