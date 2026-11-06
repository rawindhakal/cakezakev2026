"use client";
import React, { useEffect, useRef } from "react";

interface PriceFlipProps {
  flipKey: unknown;
  as?: "span" | "div";
  className?: string;
  children: React.ReactNode;
}

// Plays a short slide-up fade when `flipKey` changes, without remounting children (keeps AnimatedNumber counting).
const PriceFlip = ({ flipKey, as = "div", className = "", children }: PriceFlipProps) => {
  const ref = useRef<HTMLElement | null>(null);
  const prevKey = useRef(flipKey);

  useEffect(() => {
    if (prevKey.current === flipKey) return;
    prevKey.current = flipKey;
    const el = ref.current;
    if (!el?.animate || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    el.animate(
      [
        { opacity: 0, transform: "translateY(35%)" },
        { opacity: 1, transform: "none" },
      ],
      { duration: 250, easing: "cubic-bezier(0.22,1,0.36,1)" },
    );
  }, [flipKey]);

  const Tag = as;
  return (
    <Tag ref={ref as React.Ref<HTMLDivElement>} className={className}>
      {children}
    </Tag>
  );
};

export default PriceFlip;
