// Custom event for opening the global SpinWin wheel modal.
export const OPEN_SPIN_WHEEL_EVENT = "spin-wheel:open";

export interface SpinWheelOrigin {
  x: number;
  y: number;
}

export const originFromElement = (
  el: Element | null | undefined,
): SpinWheelOrigin | undefined => {
  if (!el) return undefined;
  const r = el.getBoundingClientRect();
  return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
};

export const openSpinWheel = (origin?: SpinWheelOrigin): void => {
  if (typeof window === "undefined") return;
  window.dispatchEvent(
    new CustomEvent<SpinWheelOrigin | undefined>(OPEN_SPIN_WHEEL_EVENT, {
      detail: origin,
    }),
  );
};
