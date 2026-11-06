"use client";
import React, { useEffect, useRef, useState } from "react";

interface ChipRect {
  left: number;
  top: number;
  width: number;
  height: number;
  animate: boolean;
}

// Sums offsetLeft/Top up to `ancestor` so wrapped rows and nested positioned parents (swiper slides) resolve.
const offsetWithin = (el: HTMLElement, ancestor: Element | null) => {
  let x = 0;
  let y = 0;
  let node: HTMLElement | null = el;
  while (node && node !== ancestor) {
    x += node.offsetLeft;
    y += node.offsetTop;
    node = node.offsetParent as HTMLElement | null;
  }
  return { x, y };
};

// Measures the chip marked data-chip-active="true" inside the container; recomputes on resize.
export const useChipIndicator = (activeKey: unknown) => {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const indicatorRef = useRef<HTMLSpanElement | null>(null);
  const [rect, setRect] = useState<ChipRect | null>(null);

  useEffect(() => {
    const box = containerRef.current;
    if (!box) return;
    let alive = true;
    const measure = () => {
      if (!alive) return;
      const ind = indicatorRef.current;
      const el = box.querySelector<HTMLElement>('[data-chip-active="true"]');
      if (!ind || !el || !el.offsetWidth) {
        setRect(null);
        return;
      }
      const { x, y } = offsetWithin(el, ind.offsetParent);
      const w = el.offsetWidth;
      const h = el.offsetHeight;
      setRect((prev) =>
        prev &&
        prev.left === x &&
        prev.top === y &&
        prev.width === w &&
        prev.height === h
          ? prev
          : { left: x, top: y, width: w, height: h, animate: !!prev },
      );
    };
    measure();
    document.fonts?.ready.then(measure);
    if (typeof ResizeObserver === "undefined") {
      return () => {
        alive = false;
      };
    }
    const observer = new ResizeObserver(measure);
    observer.observe(box);
    box
      .querySelectorAll<HTMLElement>("[data-chip-active]")
      .forEach((el) => observer.observe(el));
    return () => {
      alive = false;
      observer.disconnect();
    };
  }, [activeKey]);

  return { containerRef, indicatorRef, rect };
};

interface ChipIndicatorProps {
  indicatorRef: React.RefObject<HTMLSpanElement | null>;
  rect: ChipRect | null;
  className?: string;
  slot?: string;
}

// Single highlight that slides between chips; hidden until first measured.
export const ChipIndicator = ({
  indicatorRef,
  rect,
  className = "",
  slot,
}: ChipIndicatorProps) => (
  <span
    ref={indicatorRef}
    slot={slot}
    aria-hidden
    className={`pointer-events-none absolute left-0 top-0 z-0 box-border will-change-transform ${
      rect?.animate
        ? "transition-[transform,width,height] duration-[250ms] ease-[cubic-bezier(0.22,1,0.36,1)] motion-reduce:transition-none"
        : ""
    } ${rect ? className : "invisible"}`}
    style={
      rect
        ? {
            width: rect.width,
            height: rect.height,
            transform: `translate3d(${rect.left}px, ${rect.top}px, 0)`,
          }
        : { width: 0, height: 0 }
    }
  />
);

interface SlidingChipGroupProps {
  activeKey: unknown;
  className?: string;
  indicatorClassName?: string;
  // `ready` is true once the indicator is placed, so the active chip can drop its own fill.
  children: (ready: boolean) => React.ReactNode;
}

// Chip row (flex / flex-wrap) whose active highlight slides between chips.
export const SlidingChipGroup = ({
  activeKey,
  className = "",
  indicatorClassName = "",
  children,
}: SlidingChipGroupProps) => {
  const { containerRef, indicatorRef, rect } = useChipIndicator(activeKey);
  return (
    <div ref={containerRef} className={`relative ${className}`}>
      <ChipIndicator
        indicatorRef={indicatorRef}
        rect={rect}
        className={indicatorClassName}
      />
      {children(!!rect)}
    </div>
  );
};
