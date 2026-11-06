"use client";

import { m } from "framer-motion";
import { SPIN_WHEEL_POINTER_PATH } from "@/components/icons";

interface SpinWheelPointerProps {
  /** Pointer fill color. */
  backgroundColor?: string;
  /** Wobbles the pointer while the wheel is spinning. */
  spinning?: boolean;
}

const W = 48;
const H = 30.5;
const POINTER_PATH = SPIN_WHEEL_POINTER_PATH;

const BG_FALLBACK = "color-mix(in srgb, var(--primary-color) 42%, #fff)";
const SHADE_ANCHOR = "color-mix(in srgb, var(--primary-color) 30%, #0A0A0A)";

/**
 * Animated pointer indicator mounted above the spin wheel.
 */
const SpinWheelPointer = ({
  backgroundColor,
  spinning = false,
}: SpinWheelPointerProps) => {
  const bg = backgroundColor || BG_FALLBACK;
  const stroke = `color-mix(in srgb, ${bg} 55%, #fff)`;

  return (
    <div
      className="pointer-events-none absolute left-1/2 z-30 -translate-x-1/2"
      style={{ top: -24 }}
    >
      <m.svg
        width={W + 20}
        height={H + 20}
        viewBox={`-10 -10 ${W + 20} ${H + 20}`}
        fill="none"
        style={{ originX: "50%", originY: "0%" }}
        animate={spinning ? { rotate: [-8, 8, -8] } : { rotate: 0 }}
        transition={
          spinning
            ? { duration: 0.25, repeat: Infinity, ease: "easeInOut" }
            : { duration: 0.25 }
        }
      >
        <defs>
          <linearGradient id="swpPointerFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor={`color-mix(in srgb, ${bg} 45%, #fff)`} />
            <stop offset="0.5" stopColor={bg} />
            <stop
              offset="1"
              stopColor={`color-mix(in srgb, ${bg} 78%, ${SHADE_ANCHOR})`}
            />
          </linearGradient>
          <filter id="swpPointerBlur" x="-100%" y="-100%" width="300%" height="300%">
            <feGaussianBlur stdDeviation="1.4" />
          </filter>
        </defs>
        {/* Shadow */}
        <path
          d={POINTER_PATH}
          transform="translate(0, 5)"
          fill="#1e0e50"
          opacity="0.55"
          filter="url(#swpPointerBlur)"
        />
        {/* Pointer shape */}
        <path
          d={POINTER_PATH}
          fill="url(#swpPointerFill)"
          stroke={stroke}
          strokeWidth="2.5"
          strokeLinejoin="round"
        />
      </m.svg>
    </div>
  );
};

export default SpinWheelPointer;
