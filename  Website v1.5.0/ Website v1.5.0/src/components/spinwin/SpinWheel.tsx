"use client";

import React, { useEffect, useMemo, useRef, useState } from "react";
import { m, useMotionValue, useMotionValueEvent } from "framer-motion";
import Image from "next/image";
import { FiVolume2, FiVolumeX } from "react-icons/fi";
import { FaStar } from "react-icons/fa";
import SpinWheelPointer from "./SpinWheelPointer";
import type { SpinWheelSegment, SpinWheelTheme } from "@/types/spinWin";

interface SpinWheelProps {
  segments: SpinWheelSegment[];
  selectedSegment: SpinWheelSegment | null;
  /** Jitter offset (-0.5..0.5) to vary slice landing position. */
  jitter?: number;
  spinning: boolean;
  /** Increment to trigger re-spin animation. */
  spinToken: number;
  onSpinComplete: () => void;
  /** Whether the user can trigger a spin. */
  canSpin: boolean;
  /** Theme styling from API response. */
  theme?: SpinWheelTheme;
  /** Ratchet tick callback as pointer crosses segments. */
  onTick?: () => void;
  muted?: boolean;
  onToggleMuted?: () => void;
}

const EXTRA_TURNS = 6;
const BULB_COUNT = 24;

// Theme fallback palette derived from --primary-color.
const P = "var(--primary-color)";
const mixLight = (n: number) => `color-mix(in srgb, ${P} ${n}%, #fff)`;
const mixDark = (n: number) => `color-mix(in srgb, ${P} ${n}%, #0A0A0A)`;

// Bezel metallic gradient stops.
const BEZEL_BASE = mixLight(60);
const BEZEL_HI = mixLight(22);
const BEZEL_LO = mixDark(88);
const BEZEL_HI_2 = mixLight(38);
const BEZEL_LO_2 = mixDark(72);
const BEZEL_INNER_SHADE = `color-mix(in srgb, ${mixDark(60)} 50%, transparent)`;

// Bulb socket highlights and glows.
const SOCKET_LIT = mixDark(34);
const SOCKET_DEEP = mixDark(18);
const BULB_GLOW = `color-mix(in srgb, ${mixLight(14)} 90%, transparent)`;

// Center hub dome colors.
const HUB_HI = mixLight(45);
const HUB_MID = mixDark(92);
const HUB_LO = mixDark(66);

const SpinWheel = ({
  segments,
  selectedSegment,
  jitter = 0,
  spinning,
  spinToken,
  onSpinComplete,
  canSpin,
  theme,
  onTick,
  muted,
  onToggleMuted,
}: SpinWheelProps) => {
  const segmentAngle = 360 / (segments.length || 1);

  // Emit audio ticks based on live rotation.
  const rotation = useMotionValue(0);
  const lastTickSegment = useRef(0);
  useMotionValueEvent(rotation, "change", (deg) => {
    if (!onTick || !spinning) return;
    const crossed = Math.floor(deg / segmentAngle);
    if (crossed !== lastTickSegment.current) {
      lastTickSegment.current = crossed;
      onTick();
    }
  });
  useEffect(() => {
    if (spinning) lastTickSegment.current = Math.floor(rotation.get() / segmentAngle);
  }, [spinning, spinToken, rotation, segmentAngle]);

  // Target rotation angle to align the selected segment under pointer.
  const targetRotation = useMemo(() => {
    if (!selectedSegment) return 0;
    const index = segments.findIndex((s) => s.id === selectedSegment.id);
    if (index === -1) return 0;
    const sliceCenter = index * segmentAngle + segmentAngle / 2;
    return 360 * EXTRA_TURNS - sliceCenter - jitter * (segmentAngle * 0.4);
  }, [selectedSegment, segments, segmentAngle, jitter]);

  // Resting rotation angle when idle.
  const [landedRotation, setLandedRotation] = useState<number | null>(null);
  const restRotation = landedRotation ?? 360 - segmentAngle / 2;

  const conicGradient = useMemo(() => {
    if (segments.length === 0) return undefined;
    const stops = segments.map((s, i) => {
      const from = i * segmentAngle;
      const to = from + segmentAngle;
      return `${s.color} ${from}deg ${to}deg`;
    });
    return `conic-gradient(${stops.join(", ")})`;
  }, [segments, segmentAngle]);

  // Dynamic scale factor based on total segment count.
  const REFERENCE_SEGMENT_COUNT = 6;
  const densityScale = Math.min(
    1,
    REFERENCE_SEGMENT_COUNT / (segments.length || REFERENCE_SEGMENT_COUNT),
  );

  // Maximum label block width based on wedge geometry.
  const LABEL_RADIUS = 0.42;
  const SAFE = 0.8;
  const halfAngleRad = (segmentAngle / 2) * (Math.PI / 180);
  const labelMaxWidth = Math.min(
    34,
    2 * LABEL_RADIUS * Math.tan(halfAngleRad) * SAFE * 50,
  );

  const pointerColor = theme?.pointer_color;
  const borderColor = theme?.border_color;
  const lineColor = theme?.line_color;

  const bezelGradient = borderColor
    ? `conic-gradient(from 180deg, ${borderColor}, color-mix(in srgb, ${borderColor} 55%, #fff), color-mix(in srgb, ${borderColor} 80%, #000), color-mix(in srgb, ${borderColor} 60%, #fff), color-mix(in srgb, ${borderColor} 85%, #000), color-mix(in srgb, ${borderColor} 55%, #fff), ${borderColor})`
    : `conic-gradient(from 180deg, ${BEZEL_BASE}, ${BEZEL_HI}, ${BEZEL_LO}, ${BEZEL_HI_2}, ${BEZEL_LO_2}, ${BEZEL_HI}, ${BEZEL_BASE})`;

  const isGlossy = theme?.segment_fill !== "flat";

  if (segments.length === 0) return null;

  return (
    <div className="relative z-10 mx-auto flex w-full max-w-[700px] flex-col items-center">
      {onToggleMuted && (
        <button
          type="button"
          onClick={onToggleMuted}
          aria-label={muted ? "Unmute spin sounds" : "Mute spin sounds"}
          aria-pressed={muted}
          className="absolute right-0 top-0 z-30 flex h-8 w-8 items-center justify-center rounded-full bg-black/25 text-white backdrop-blur-sm transition hover:bg-black/40 active:scale-95"
        >
          {muted ? <FiVolumeX size={15} /> : <FiVolume2 size={15} />}
        </button>
      )}

      <div
        // Purely decorative — its square box overlaps the stand pulled up beneath it.
        className="pointer-events-none relative z-10 flex aspect-square w-full items-center justify-center"
        style={{ containerType: "inline-size" }}
      >
        <SpinWheelPointer backgroundColor={pointerColor} spinning={spinning} />

        {/* Outer bezel ring */}
        <div
          className="absolute inset-0 rounded-full p-[18px]"
          style={{
            background: bezelGradient,
            boxShadow: `0 20px 40px -16px rgba(0,0,0,0.45), inset 0 2px 4px rgba(255,255,255,0.85), inset 0 -3px 6px ${BEZEL_INNER_SHADE}`,
          }}
        >
          {/* Bezel lights */}
          {Array.from({ length: BULB_COUNT }).map((_, i) => {
            const angle = (360 / BULB_COUNT) * i;
            return (
              <span
                key={i}
                className="pointer-events-none absolute inset-0"
                style={{ transform: `rotate(${angle}deg)` }}
              >
                <span
                  className="absolute left-1/2 top-[4.5px] h-[10px] w-[10px] -translate-x-1/2 rounded-full shadow-[inset_0_1px_1px_rgba(255,255,255,0.25),0_1px_2px_rgba(0,0,0,0.4)]"
                  style={{
                    background: `radial-gradient(circle at 35% 30%, ${SOCKET_LIT}, ${SOCKET_DEEP})`,
                  }}
                />
                <span
                  className="absolute left-1/2 top-[6px] h-[7px] w-[7px] -translate-x-1/2 rounded-full bg-[#FFFBEA]"
                  style={{ boxShadow: `0 0 6px 2px ${BULB_GLOW}` }}
                />
              </span>
            );
          })}

          {/* Wheel face */}
          <m.div
            key={spinToken}
            className="relative h-full w-full rounded-full shadow-[inset_0_0_20px_rgba(0,0,0,0.18)]"
            style={{
              background: conicGradient,
              willChange: "transform",
              backfaceVisibility: "hidden",
              rotate: rotation,
            }}
            initial={{ rotate: restRotation }}
            animate={{ rotate: spinning ? targetRotation : restRotation }}
            transition={
              spinning
                ? {
                    duration: 4.2,
                    ease: [0.15, 0.9, 0.25, 1],
                  }
                : { duration: 0 }
            }
            onAnimationComplete={() => {
              if (!spinning) return;
              setLandedRotation(((targetRotation % 360) + 360) % 360);
              onSpinComplete();
            }}
          >
            {/* Segment divider lines */}
            {lineColor &&
              segments.map((_, i) => (
                <span
                  key={`divider-${i}`}
                  className="pointer-events-none absolute left-1/2 top-1/2 h-1/2 w-[2px] origin-top rounded-full"
                  style={{
                    backgroundColor: lineColor,
                    boxShadow: `0 0 3px color-mix(in srgb, ${lineColor} 60%, transparent)`,
                    transform: `translateX(-50%) rotate(${i * segmentAngle + 180}deg)`,
                  }}
                />
              ))}

            {/* Glossy overlay */}
            {isGlossy && (
              <span className="pointer-events-none absolute inset-0 rounded-full bg-[radial-gradient(circle_at_32%_28%,rgba(255,255,255,0.35),transparent_45%),radial-gradient(circle_at_50%_50%,transparent_58%,rgba(0,0,0,0.18))]" />
            )}

            {segments.map((segment, i) => {
              const rotate = i * segmentAngle + segmentAngle / 2;
              const textColor = segment.text_color || "#ffffff";
              const showIcon =
                Boolean(segment.icon_url) && segment.display_mode !== "name";
              const showLabel = segment.display_mode !== "icon";
              return (
                <div
                  key={segment.id}
                  className="absolute inset-0 flex justify-center"
                  style={{ transform: `rotate(${rotate}deg)` }}
                >
                  <div
                    className="mt-[9%] flex flex-col items-center gap-[1.5cqw] px-[2cqw]"
                    style={{
                      maxWidth: `${labelMaxWidth}cqw`,
                    }}
                  >
                    {showIcon && (
                      <span
                        className="relative flex shrink-0 items-center justify-center"
                        style={{
                          width: `${(showLabel ? 11 : 14) * densityScale}cqw`,
                          height: `${(showLabel ? 11 : 14) * densityScale}cqw`,
                        }}
                      >
                        <span className="relative h-full w-full">
                          <Image
                            src={segment.icon_url!}
                            alt={segment.label}
                            fill
                            sizes="60px"
                            className="object-contain"
                            unoptimized
                          />
                        </span>
                      </span>
                    )}
                    {showLabel && (
                      <span
                        className="line-clamp-3 w-full overflow-hidden break-words text-center font-bold leading-[1.15]"
                        style={{
                          color: textColor,
                          fontSize: `${2.7 * densityScale}cqw`,
                        }}
                      >
                        {segment.label}
                      </span>
                    )}
                  </div>
                </div>
              );
            })}
          </m.div>

          {/* Center dome */}
          <div className="pointer-events-none absolute inset-0 z-20 flex items-center justify-center">
            <div
              aria-hidden
              className="flex h-[22%] w-[22%] items-center justify-center overflow-visible rounded-full p-[3px]"
              style={{
                background: borderColor
                  ? `linear-gradient(135deg, color-mix(in srgb, ${borderColor} 60%, #fff), ${borderColor} 45%, color-mix(in srgb, ${borderColor} 65%, #000))`
                  : "linear-gradient(135deg, #ffffff, #d8d8d8 45%, #a8a8a8)",
                boxShadow: [
                  "0 3px 6px rgba(0,0,0,0.45)",
                  "0 8px 16px rgba(0,0,0,0.3)",
                  "inset 0 1px 1px rgba(255,255,255,0.6)",
                  "inset 0 -1px 2px rgba(0,0,0,0.25)",
                ].join(", "),
              }}
            >
              {theme?.hub_icon_url ? (
                <span className="relative block h-full w-full overflow-hidden rounded-full">
                  <Image
                    src={theme.hub_icon_url}
                    alt=""
                    fill
                    unoptimized
                    className="object-cover"
                  />
                </span>
              ) : (
                <div
                  key="dome"
                  className="flex h-full w-full items-center justify-center rounded-full shadow-[inset_0_2px_4px_rgba(255,255,255,0.4),inset_0_-3px_6px_rgba(0,0,0,0.28)]"
                  style={{
                    color: "#ffffff",
                    background: !canSpin
                      ? "radial-gradient(circle at 35% 28%, #B6BDC4, #8A929B 55%, #6B7280)"
                      : pointerColor
                        ? `radial-gradient(circle at 35% 28%, color-mix(in srgb, ${pointerColor} 80%, #fff), ${pointerColor} 55%, color-mix(in srgb, ${pointerColor} 70%, #000))`
                        : `radial-gradient(circle at 35% 28%, ${HUB_HI}, ${HUB_MID} 55%, ${HUB_LO})`,
                  }}
                >
                  <FaStar
                    className="h-[42%] w-[42%]"
                    style={{
                      filter:
                        "drop-shadow(0 2px 2px rgba(0,0,0,0.45)) drop-shadow(0 4px 8px rgba(0,0,0,0.3))",
                    }}
                  />
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SpinWheel;
