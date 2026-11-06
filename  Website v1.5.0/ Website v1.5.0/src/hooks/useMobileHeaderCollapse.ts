import { useEffect, useRef, useState } from "react";

// Measures the collapsible mobile home header, publishes its height as
// --layout-header-collapse, and tracks the back-to-top pill's visibility.
const useMobileHeaderCollapse = (collapseHomeTop: boolean) => {
  const mobileTopRef = useRef<HTMLDivElement>(null);
  const [mobileTopH, setMobileTopH] = useState(0);
  const [showBackToTop, setShowBackToTop] = useState(false);

  useEffect(() => {
    const el = mobileTopRef.current;
    const root = document.documentElement;
    const publish = (h: number) => {
      root.style.setProperty("--layout-header-collapse", `${h}px`);
      window.dispatchEvent(new Event("layout-header-collapse"));
    };
    if (!collapseHomeTop || !el) {
      setMobileTopH(0);
      publish(0);
      return;
    }
    const measure = () => {
      const h = el.getBoundingClientRect().height;
      setMobileTopH(h);
      publish(h);
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => {
      ro.disconnect();
      publish(0);
    };
  }, [collapseHomeTop]);

  useEffect(() => {
    if (!collapseHomeTop) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- reset when leaving mobile home
      setShowBackToTop(false);
      return;
    }
    let raf = 0;
    const onScroll = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => setShowBackToTop(window.scrollY > 900));
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("scroll", onScroll);
    };
  }, [collapseHomeTop]);

  return { mobileTopRef, mobileTopH, showBackToTop };
};

export default useMobileHeaderCollapse;
