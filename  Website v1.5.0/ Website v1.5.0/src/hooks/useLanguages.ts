import { useMemo } from "react";
import { useSelector } from "react-redux";
import { useParams } from "next/navigation";
import {
  parseLangPath as parseLangPathBase,
  DEFAULT_LANGUAGE,
} from "@/utils/languageRoutes";

/** Client-side language configuration hook backed by Redux state and route parameters. */
const useLanguages = () => {
  // Extract lang route parameter from active route.
  const params = useParams<{ lang?: string }>();
  const available = useSelector(
    (state: any) => state?.Language?.availableLanguages,
  );
  // Seeded language codes from SSR page properties.
  const seededCodes = useSelector((state: any) => state?.Language?.languageCodes);
  const routeLangParam = params?.lang;

  return useMemo(() => {
    const rows = Array.isArray(available) ? available : [];
    const codes = new Set<string>();
    let defaultCode = DEFAULT_LANGUAGE;
    for (const r of rows) {
      if (!r?.code) continue;
      codes.add(r.code);
      if (r.is_default == 1) defaultCode = r.code;
    }
    // Merge seeded codes (present before availableLanguages loads).
    if (Array.isArray(seededCodes)) {
      for (const c of seededCodes) if (c) codes.add(c);
    }
    // The URL's own language always counts, even before availableLanguages loads.
    if (routeLangParam) codes.add(routeLangParam);
    // Always know the default even before either list loads.
    codes.add(defaultCode);

    const prefixCodes = [...codes].filter((c) => c !== defaultCode);
    const langInfo = { codes, defaultCode };

    return {
      codes,
      defaultCode,
      prefixCodes,
      parseLangPath: (path: string) => parseLangPathBase(path, langInfo),
    };
  }, [available, seededCodes, routeLangParam]);
};

export default useLanguages;

