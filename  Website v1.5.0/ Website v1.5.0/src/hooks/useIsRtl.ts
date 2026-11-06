import { useSelector } from "react-redux";
import useIsHydrated from "./useIsHydrated";

/** Hydration-safe hook checking if active language direction is RTL. */
const useIsRtl = (): boolean => {
  const type = useSelector(
    (state: any) => state.Language?.selectedLanguage?.type,
  );
  const hydrated = useIsHydrated();
  return hydrated && type === "RTL";
};

export default useIsRtl;

