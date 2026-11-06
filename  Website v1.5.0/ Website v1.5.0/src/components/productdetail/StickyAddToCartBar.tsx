import { ReactNode, RefObject, useEffect, useState } from "react";
import Image from "next/image";

interface StickyAddToCartBarProps {
  /** Inline cart actions; bar shows once they scroll above the viewport. */
  targetRef: RefObject<HTMLElement | null>;
  image?: string;
  name?: string;
  price?: ReactNode;
  children: ReactNode;
}

// Mobile/tablet bar that mirrors the cart actions; sits above the mobile bottom nav.
const StickyAddToCartBar = ({ targetRef, image, name, price, children }: StickyAddToCartBarProps) => {
  const [visible, setVisible] = useState(false);
  const [navHeight, setNavHeight] = useState(0);

  useEffect(() => {
    const el = targetRef.current;
    if (!el) return;
    const observer = new IntersectionObserver(([entry]) => {
      setVisible(!entry.isIntersecting && entry.boundingClientRect.top < 0);
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, [targetRef]);

  useEffect(() => {
    const measure = () => {
      const nav = document.querySelector<HTMLElement>("nav.fixed.bottom-0");
      setNavHeight(nav?.offsetHeight || 0);
    };
    measure();
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, [visible]);

  return (
    <>
      <div className="h-20 lg:hidden" aria-hidden />
      <div
        className={`fixed inset-x-0 z-40 lg:hidden border-t border-gray-200 dark:border-zinc-700/60 bg-white dark:bg-zinc-900 shadow-[0_-2px_12px_rgba(0,0,0,0.08)] transition-transform duration-300 ${
          visible ? "translate-y-0" : "translate-y-[150%] pointer-events-none"
        }`}
        style={{ bottom: navHeight }}
        aria-hidden={!visible}
      >
        <div className="container flex items-center gap-3 px-4 py-2.5">
          {image && (
            <div className="relative hidden sm:block h-11 w-11 shrink-0 overflow-hidden rounded-md cardBorder border">
              <Image src={image} alt={name || ""} fill sizes="44px" className="object-cover" />
            </div>
          )}
          <div className="hidden sm:flex min-w-0 flex-col">
            <span className="truncate text-sm font-semibold textColor">{name}</span>
            {price && <span className="text-sm font-bold primaryColor">{price}</span>}
          </div>
          {price && <span className="sm:hidden shrink-0 text-base font-extrabold textColor">{price}</span>}
          <div className="ms-auto flex min-w-0 flex-1 justify-end sm:max-w-[360px]">{children}</div>
        </div>
      </div>
    </>
  );
};

export default StickyAddToCartBar;
