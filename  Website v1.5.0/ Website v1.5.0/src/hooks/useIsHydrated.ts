import { useEffect, useState } from "react";

/** Hydration guard hook returning true after initial client mount. */
const useIsHydrated = (): boolean => {
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setHydrated(true);
  }, []);

  return hydrated;
};

export default useIsHydrated;

