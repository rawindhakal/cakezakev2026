import { useEffect, useRef, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import * as api from "@/api/apiRoutes";
import { setDefaultCountry } from "@/redux/slices/locationModalSlice";

/** Hook to resolve and store default country on application startup. */
const useDefaultCountry = (): { resolving: boolean } => {
  const dispatch = useDispatch();
  const selectedCountry = useSelector(
    (state: any) => state?.LocationModal?.selectedCountry,
  );
  const [resolving, setResolving] = useState(!selectedCountry?.id);
  // Guard against duplicate fetch requests across renders and remounts.
  const requested = useRef(false);

  useEffect(() => {
    if (selectedCountry?.id) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setResolving(false);
      return;
    }
    if (requested.current) return;
    requested.current = true;

    // Fetch countries and dispatch default country to Redux.
    api
      .getCountriesWithDefault()
      .then((res: any) => {
        const countries = res?.data || [];
        // Loose == : the API sends is_default as 1 (number) or "1" (string).
        const fallback = countries.find((c: any) => c?.is_default == 1);
        if (fallback) dispatch(setDefaultCountry(fallback));
      })
      .catch((err: any) => {
        console.log("Default country fetch failed:", err?.message);
        requested.current = false;
      })
      .finally(() => {
        setResolving(false);
      });
  }, [selectedCountry?.id, dispatch]);

  return { resolving };
};

export default useDefaultCountry;

