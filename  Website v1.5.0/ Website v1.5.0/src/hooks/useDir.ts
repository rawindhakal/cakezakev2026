import { useSelector } from "react-redux";
import useIsHydrated from "./useIsHydrated";

/** Hydration-safe text direction ("RTL" / "LTR") for active language. */
const useDir = (): string | undefined => {
  const type = useSelector(
    (state: any) => state.Language?.selectedLanguage?.type,
  );
  const hydrated = useIsHydrated();
  return hydrated ? type : undefined;
};

export default useDir;
