"use client";

import React, { useEffect, useMemo, useState } from "react";
import dynamic from "next/dynamic";
import { useSelector } from "react-redux";
import { FaArrowUp } from "react-icons/fa";
import { BiSupport } from "react-icons/bi";
import { LuChevronLeft, LuChevronRight, LuX } from "react-icons/lu";
import { RiCloseFill } from "react-icons/ri";
import { cn } from "@/lib/utils";
import { t } from "@/utils/translation";
import useIsRtl from "@/hooks/useIsRtl";
import useIsHydrated from "@/hooks/useIsHydrated";
import useCountdown from "@/hooks/useCountdown";
import { useSpinWheel } from "@/hooks/useSpinWheel";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import SpinWinPanel from "@/components/spinwin/SpinWinPanel";
import { m } from "framer-motion";
import {
  OPEN_SPIN_WHEEL_EVENT,
  originFromElement,
  type SpinWheelOrigin,
} from "@/components/spinwin/spinWheelEvents";
import SupportChat from "@/components/chat/support/SupportChat";
import spinningWheelAnimation from "@/assets/spinning_wheel.json";
import { getPrimaryLottieRgb, recolorAnimation } from "@/utils/lottieColor";
import ProgressRing from "@/components/ui/ProgressRing";

// Client-only dynamic import for Lottie
const Lottie = dynamic(() => import("lottie-react"), { ssr: false });

// Floating action dock containing Spin & Win, Support, and Back to Top
const FloatingActionDock = () => {
  const rtl = useIsRtl();
  const userId = useSelector((s: any) => s.User?.user?.id);
  const setting = useSelector((s: any) => s.Setting?.setting);
  const spinWheelAvailable = setting?.spin_wheel_available == 1;

  const [scrollVisible, setScrollVisible] = useState(false);
  const [scrollProgress, setScrollProgress] = useState(0);
  const [spinOpen, setSpinOpen] = useState(false);
  const [spinOrigin, setSpinOrigin] = useState<SpinWheelOrigin | null>(null);
  const openSpinFrom = (origin?: SpinWheelOrigin | null) => {
    setSpinOrigin(origin ?? null);
    setSpinOpen(true);
  };
  const [supportOpen, setSupportOpen] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  // Collapse mobile dock on scroll
  useEffect(() => {
    if (!mobileOpen) return;
    const startY = window.scrollY;
    const onScroll = () => {
      if (Math.abs(window.scrollY - startY) > 60) setMobileOpen(false);
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, [mobileOpen]);

  // Spin wheel query & countdown state
  const isHydrated = useIsHydrated();
  const city = useSelector((s: any) => s.City?.city);
  const latitude = isHydrated ? city?.latitude : undefined;
  const longitude = isHydrated ? city?.longitude : undefined;
  const { data: spinData } = useSpinWheel({
    latitude,
    longitude,
    enabled: isHydrated && spinWheelAvailable,
  });
  const outOfSpins =
    spinData?.requires_login !== 1 && spinData?.spins?.can_spin === false;
  const nextSpinCountdown = useCountdown(
    outOfSpins ? spinData?.spins?.next_spin_at : null,
  );

  // Recolor Lottie animation with primary color. Kept eager: the dock renders
  // on every page, so a lazy chunk showed an empty slot on first paint.
  const spinLottie = useMemo(
    () => recolorAnimation(spinningWheelAnimation, getPrimaryLottieRgb(), "black"),
    [],
  );

  useEffect(() => {
    const onScroll = () => {
      const scrollTop = window.scrollY;
      const docHeight =
        document.documentElement.scrollHeight - window.innerHeight;
      setScrollVisible(scrollTop > 400);
      setScrollProgress(docHeight > 0 ? Math.min(scrollTop / docHeight, 1) : 0);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
    };
  }, []);

  // Listen for global open spin wheel events
  useEffect(() => {
    const openWheel = (e: Event) =>
      openSpinFrom((e as CustomEvent<SpinWheelOrigin | undefined>).detail);
    window.addEventListener(OPEN_SPIN_WHEEL_EVENT, openWheel);
    return () => window.removeEventListener(OPEN_SPIN_WHEEL_EVENT, openWheel);
  }, []);

  const scrollToTop = () => window.scrollTo({ top: 0, behavior: "smooth" });

  const isLoggedIn = Boolean(userId);
  const hiddenTranslateClass = rtl ? "-translate-x-full" : "translate-x-full";
  const hasDockContent =
    isHydrated && (spinWheelAvailable || isLoggedIn || scrollVisible);
  const withCollapse = (fn: () => void) => () => {
    setMobileOpen(false);
    fn();
  };
  const ExpandIcon = rtl ? LuChevronRight : LuChevronLeft;
  const CollapseIcon = rtl ? LuChevronLeft : LuChevronRight;

  return (
    <>
      {/* Mobile edge tab */}
      {hasDockContent && (
        <button
          type="button"
          onClick={() => setMobileOpen((v) => !v)}
          aria-label={
            mobileOpen ? t("close") || "Close" : t("more") || "Show shortcuts"
          }
          aria-expanded={mobileOpen}
          className={cn(
            "fixed z-40 flex h-12 w-6 items-center justify-center text-white shadow-lg md:hidden",
            "bottom-[calc(var(--mobile-dock-bottom,72px)+env(safe-area-inset-bottom))]",
            rtl ? "start-0 rounded-e-xl" : "end-0 rounded-s-xl",
          )}
          style={{
            background:
              "linear-gradient(135deg, var(--primary-color), color-mix(in srgb, var(--primary-color) 70%, #000))",
          }}
        >
          {mobileOpen ? <CollapseIcon size={16} /> : <ExpandIcon size={16} />}
        </button>
      )}

      <div
        className={cn(
          "fixed z-40 flex flex-col items-center transition-transform duration-300 ease-out md:translate-x-0",
          "bottom-[calc(var(--mobile-dock-bottom,72px)+env(safe-area-inset-bottom))] md:bottom-6",
          rtl ? "start-8 md:start-6" : "end-8 md:end-6",
          !mobileOpen &&
            (rtl
              ? "max-md:-translate-x-[calc(100%+2.5rem)]"
              : "max-md:translate-x-[calc(100%+2.5rem)]"),
        )}
      >
        {/* Floating action buttons pill */}
        <div
          className={cn(
            "flex flex-col items-center gap-1.5 rounded-full p-1.5",
            "transition-transform duration-300 ease-out will-change-transform",
            scrollVisible ? "-translate-y-14" : "translate-y-0",
          )}
          style={{
            background:
              "color-mix(in srgb, var(--primary-color) 8%, transparent)",
            boxShadow:
              "0 12px 28px -14px color-mix(in srgb, var(--primary-color) 55%, transparent)",
          }}
        >
          {spinWheelAvailable && (
            <div className="relative">
              <DockButton
                label={t("spin_and_win") || "Spin & Win"}
                onClick={(e) => {
                  setMobileOpen(false);
                  openSpinFrom(originFromElement(e?.currentTarget));
                }}
                rtl={rtl}
                variant="outline"
              >
                <Lottie
                  animationData={spinLottie}
                  loop
                  autoplay
                  className="h-11 w-11"
                />
              </DockButton>

              {/* Next spin countdown badge */}
              {nextSpinCountdown && !nextSpinCountdown.finished && (
                <span
                  className="pointer-events-none absolute -bottom-1 left-1/2 -translate-x-1/2 rounded-full px-1.5 py-[1px] text-[9px] font-bold leading-tight text-white tabular-nums shadow-sm"
                  style={{ backgroundColor: "var(--primary-color)" }}
                >
                  {nextSpinCountdown.label}
                </span>
              )}
            </div>
          )}

          {isLoggedIn && (
            <DockButton
              label={t("support") || "Support"}
              onClick={withCollapse(() => setSupportOpen(true))}
              rtl={rtl}
              variant="outline"
            >
              <BiSupport size={20} />
            </DockButton>
          )}
        </div>

        {/* Back to top button */}
        <div
          className={cn(
            "absolute bottom-0 transition-[transform,opacity] duration-300 ease-out will-change-transform",
            scrollVisible
              ? "translate-y-0 scale-100 opacity-100"
              : "pointer-events-none translate-y-4 scale-50 opacity-0",
          )}
        >
          <DockButton
            label={t("back_to_top") || "Back to Top"}
            onClick={withCollapse(scrollToTop)}
            rtl={rtl}
            variant="filled"
          >
            <ProgressRing progress={scrollProgress} size={48} />
            <FaArrowUp size={16} className="relative" />
          </DockButton>
        </div>
      </div>

      {/* Spin & Win dialog */}
      <Dialog open={spinWheelAvailable && spinOpen} onOpenChange={setSpinOpen}>
        {spinWheelAvailable && spinOpen && (
          <button
            type="button"
            onClick={() => setSpinOpen(false)}
            aria-label={t("close")}
            className="primaryBackColor fixed end-4 top-4 z-[71] flex h-9 w-9 items-center justify-center rounded-full text-white shadow-lg transition hover:opacity-90"
          >
            <RiCloseFill size={18} />
          </button>
        )}
        <DialogContent
          className={cn(
            "w-full sm:max-w-3xl rounded-[28px] p-0 gap-0 border-0 shadow-none bg-transparent",
            spinOrigin && "data-[state=open]:animate-none",
          )}
          overlayClassName="bg-black/70"
          title={t("spin_and_win") || "Spin & Win"}
        >
          <SpinWheelFlyIn origin={spinOrigin}>
            <SpinWinPanel onNavigateAway={() => setSpinOpen(false)} />
          </SpinWheelFlyIn>
        </DialogContent>
      </Dialog>

      {/* Support chat drawer */}
      <div
        className={cn(
          "fixed inset-0 z-[70] transition",
          supportOpen ? "pointer-events-auto" : "pointer-events-none",
        )}
      >
        <button
          type="button"
          aria-label={t("close") || "Close"}
          className={cn(
            "absolute inset-0 cursor-default bg-black/40 backdrop-blur-[1px] transition-opacity duration-300",
            supportOpen ? "opacity-100" : "opacity-0",
          )}
          onClick={() => setSupportOpen(false)}
        />
        <div
          className={cn(
            "absolute top-0 h-full w-full sm:w-[420px] bg-white dark:bg-zinc-900 shadow-2xl flex flex-col overscroll-contain transition-transform duration-300 ease-out",
            rtl ? "left-0" : "right-0",
            supportOpen ? "translate-x-0" : hiddenTranslateClass,
          )}
        >
          <button
            type="button"
            onClick={() => setSupportOpen(false)}
            aria-label={t("close") || "Close"}
            className={cn(
              "absolute top-3 z-10 flex h-8 w-8 items-center justify-center rounded-full bg-white/20 text-white transition hover:bg-white/30",
              rtl ? "left-3" : "right-3",
            )}
          >
            <LuX size={18} />
          </button>
          {supportOpen && (
            <div className="flex h-full flex-col [&>div]:h-full [&>div]:rounded-none [&>div]:border-0 [&>div]:shadow-none">
              <SupportChat />
            </div>
          )}
        </div>
      </div>
    </>
  );
};

// Animated container for spin wheel modal
const SpinWheelFlyIn = ({
  origin,
  children,
}: {
  origin: SpinWheelOrigin | null;
  children: React.ReactNode;
}) => {
  const [flying, setFlying] = useState(true);
  const reduceMotion =
    typeof window !== "undefined" &&
    window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  if (!origin || reduceMotion || typeof window === "undefined") {
    return <>{children}</>;
  }
  const dx = origin.x - window.innerWidth / 2;
  const dy = origin.y - window.innerHeight / 2;
  return (
    <m.div
      className={flying ? "spinFlyIn spinFlyIn--moving" : "spinFlyIn"}
      initial={{ x: dx, y: dy, scale: 0.05, opacity: 0 }}
      animate={{ x: 0, y: 0, scale: 1, opacity: 1 }}
      transition={{
        x: { delay: 0.05, duration: 0.9, ease: [0.22, 1, 0.36, 1] },
        y: { delay: 0.05, duration: 0.9, ease: [0.22, 1, 0.36, 1] },
        scale: { delay: 0.05, duration: 0.9, ease: [0.65, 0, 0.35, 1] },
        opacity: { delay: 0.05, duration: 0.25, ease: "easeOut" },
      }}
      onAnimationComplete={() => setFlying(false)}
      style={{
        transformOrigin: "center center",
        // Keep the layer promoted only while moving, then let it repaint crisply.
        willChange: flying ? "transform, opacity" : "auto",
        backfaceVisibility: "hidden",
      }}
    >
      {children}
    </m.div>
  );
};

const DockButton = ({
  label,
  onClick,
  rtl,
  variant,
  children,
}: {
  label: string;
  onClick: (e?: React.MouseEvent<HTMLButtonElement>) => void;
  rtl: boolean;
  variant: "filled" | "outline";
  children: React.ReactNode;
}) => (
  <div className="group relative">
    <span
      className={cn(
        "pointer-events-none absolute top-1/2 -translate-y-1/2 whitespace-nowrap rounded-full px-3.5 py-1.5 text-xs font-bold text-white opacity-0 shadow-lg transition duration-200 group-hover:opacity-100",
        rtl
          ? "left-full ml-3 -translate-x-2 group-hover:translate-x-0"
          : "right-full mr-3 translate-x-2 group-hover:translate-x-0",
      )}
      style={{
        background:
          "linear-gradient(135deg, var(--primary-color), color-mix(in srgb, var(--primary-color) 70%, #000))",
      }}
    >
      {label}
      <span
        className={cn(
          "absolute top-1/2 h-2 w-2 -translate-y-1/2 rotate-45",
          rtl ? "-left-1" : "-right-1",
        )}
        style={{ background: "var(--primary-color)" }}
      />
    </span>

    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className={cn(
        "relative flex h-12 w-12 items-center justify-center rounded-full shadow-lg transition-transform duration-200 hover:scale-110 active:scale-95",
        variant === "filled"
          ? "text-white"
          : "bg-white text-[var(--primary-color)] ring-1 ring-black/5 dark:bg-zinc-900 dark:ring-white/10",
      )}
      style={
        variant === "filled"
          ? {
              background:
                "linear-gradient(135deg, var(--primary-color), color-mix(in srgb, var(--primary-color) 70%, #000))",
            }
          : undefined
      }
    >
      {children}
    </button>
  </div>
);

export default FloatingActionDock;

