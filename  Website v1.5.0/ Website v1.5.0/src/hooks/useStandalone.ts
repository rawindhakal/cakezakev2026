  import { useEffect, useState } from "react";

  // Detects whether the app is running as an installed PWA (standalone mode or navigator.standalone).
  const useStandalone = (): boolean => {
    const [isStandalone, setIsStandalone] = useState(false);

    useEffect(() => {
      if (typeof window === "undefined") return;

      const query = window.matchMedia?.("(display-mode: standalone)");
      const compute = () =>
        setIsStandalone(
          // Check display-mode media query and non-standard iOS navigator.standalone.
          query?.matches === true ||
            (window.navigator as any)?.standalone === true,
        );

      compute();

      if (!query) return;
      // Listen for display-mode media query changes.
      if (query.addEventListener) {
        query.addEventListener("change", compute);
        return () => query.removeEventListener("change", compute);
      }
      query.addListener(compute);
      return () => query.removeListener(compute);
    }, []);

    return isStandalone;
  };

  export default useStandalone;
