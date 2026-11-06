import { useEffect, useState } from "react";
import { useMediaQuery } from "react-responsive";

/** Hydration-safe wrapper for responsive media queries. */
const useHydratedMediaQuery = (query: string): boolean => {
  const matches = useMediaQuery({ query });
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setMounted(true);
  }, []);

  return mounted && matches;
};

export default useHydratedMediaQuery;

