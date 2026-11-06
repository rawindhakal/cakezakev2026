"use client";

import React from "react";
import { SPIN_WIN_STAND_PATHS } from "@/components/icons";

interface SpinWinStandProps {
  onSpin: () => void;
  /** Whether the user can spin the wheel. */
  canSpin: boolean;
  disabled?: boolean;
  /** Label for the spin button. */
  label: string;
  /** Optional countdown node shown when out of spins. */
  countdown?: React.ReactNode;
  /** Runs bulb chase animation while spinning. */
  spinning?: boolean;
  /** Optional button color. */
  buttonColor?: string;
  /** Optional button text color. */
  buttonTextColor?: string;
  /** Optional bulb lights color. */
  lightColor?: string;
}

// Brand-derived palette colors and mixes.
const BTN = "var(--spinwin-button-color, var(--primary-color))";
const GOLD_TOP = `color-mix(in srgb, ${BTN} 18%, #fff)`;
const GOLD_MID = `color-mix(in srgb, ${BTN} 45%, #fff)`;
const GOLD_BOTTOM = `color-mix(in srgb, ${BTN} 68%, #fff)`;
const GOLD_TEXT = `color-mix(in srgb, ${BTN} 62%, #0A0A0A)`;
const LIP_TOP = `color-mix(in srgb, ${BTN} 72%, #0A0A0A)`;
const LIP_BOTTOM = `color-mix(in srgb, ${BTN} 52%, #0A0A0A)`;
const CRADLE = `color-mix(in srgb, ${BTN} 24%, #0A0A0A)`;

// Cabinet gradient steps & stroke colors.
const CAB_1 = "color-mix(in srgb, var(--primary-color) 55%, #fff)";
const CAB_2 = "color-mix(in srgb, var(--primary-color) 78%, #fff)";
const CAB_3 = "color-mix(in srgb, var(--primary-color) 72%, #0A0A0A)";
const CAB_4 = "color-mix(in srgb, var(--primary-color) 52%, #0A0A0A)";
const CAB_5 = "color-mix(in srgb, var(--primary-color) 46%, #0A0A0A)";
const CAB_STROKE =
  "color-mix(in srgb, color-mix(in srgb, var(--primary-color) 22%, #fff) 85%, transparent)";
const BASE_STROKE =
  "color-mix(in srgb, color-mix(in srgb, var(--primary-color) 30%, #fff) 30%, transparent)";
const CAB_SHADOW =
  "color-mix(in srgb, color-mix(in srgb, var(--primary-color) 22%, #0A0A0A) 55%, transparent)";

// Button dimensions in pixels.
const FACE_H = 42;
const LIP = 8;
const SOCKET_PAD = 3;

const CABINET_PATH = SPIN_WIN_STAND_PATHS.cabinet;
const BASE_PATH = SPIN_WIN_STAND_PATHS.base;
const PANEL_PATH = SPIN_WIN_STAND_PATHS.panel;
const LEFT_WING_PATH = SPIN_WIN_STAND_PATHS.leftWing;
const RIGHT_WING_PATH = SPIN_WIN_STAND_PATHS.rightWing;

// Side bulbs grid positions.
const DOT_ROWS = [155, 195, 235];
const DOT_COLS = { left: 74, right: 726 };

/**
 * The console stand beneath the wheel with side bulbs and SPIN button.
 */
const SpinWinStand = ({
  onSpin,
  canSpin,
  disabled,
  label,
  countdown,
  spinning,
  buttonColor,
  buttonTextColor,
  lightColor,
}: SpinWinStandProps) => {
  const showCountdown = Boolean(countdown) && !canSpin;
  return (
    <div
      className={`relative -mt-[10%] w-full max-w-[700px] ${
        spinning ? "spinStandSpinning" : ""
      }`}
      style={
        lightColor
          ? ({ "--spinwin-light-color": lightColor } as React.CSSProperties)
          : undefined
      }
    >
      {/* Side wings */}
      <svg
        aria-hidden
        className="pointer-events-none absolute inset-0 z-[-1] block w-full overflow-visible"
        viewBox="0 0 800 355"
        style={{ aspectRatio: "800 / 355" }}
      >
        <defs>
          <linearGradient id="spin-wing-fill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="color-mix(in srgb, var(--primary-color) 70%, #fff)" />
            <stop offset="40%" stopColor="color-mix(in srgb, var(--primary-color) 60%, #0A0A0A)" />
            <stop offset="100%" stopColor="color-mix(in srgb, var(--primary-color) 35%, #0A0A0A)" />
          </linearGradient>
        </defs>
        <path
          d={LEFT_WING_PATH}
          fill="url(#spin-wing-fill)"
          stroke="color-mix(in srgb, var(--primary-color) 75%, #fff)"
          strokeWidth="2"
          strokeLinejoin="round"
        />
        <path
          d={RIGHT_WING_PATH}
          fill="url(#spin-wing-fill)"
          stroke="color-mix(in srgb, var(--primary-color) 75%, #fff)"
          strokeWidth="2"
          strokeLinejoin="round"
        />
      </svg>

      {/* Main cabinet */}
      <svg
        aria-hidden
        className="relative block w-full overflow-visible"
        viewBox="0 0 800 355"
        style={{
          aspectRatio: "800 / 355",
          filter: `drop-shadow(0 12px 20px ${CAB_SHADOW})`,
        }}
      >
        <defs>
          <linearGradient id="spin-stand-body" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor={CAB_1} />
            <stop offset="1" stopColor={CAB_2} />
          </linearGradient>
          <linearGradient id="spin-stand-inner" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={CAB_1} />
            <stop offset="25%" stopColor={CAB_2} />
            <stop offset="50%" stopColor={CAB_3} />
            <stop offset="75%" stopColor={CAB_4} />
            <stop offset="100%" stopColor={CAB_5} />
          </linearGradient>
          <linearGradient id="spin-stand-base" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor={CAB_3} />
            <stop offset="1" stopColor={CAB_5} />
          </linearGradient>
          <clipPath id="spin-stand-clip">
            <path d={CABINET_PATH} />
          </clipPath>
        </defs>

        {/* Base plinth */}
        <path
          d={BASE_PATH}
          fill="url(#spin-stand-base)"
          stroke={BASE_STROKE}
          strokeWidth="1.5"
          strokeLinejoin="round"
        />

        {/* Cabinet body */}
        <path
          d={CABINET_PATH}
          fill="url(#spin-stand-body)"
          stroke={CAB_STROKE}
          strokeWidth="3"
          strokeLinejoin="round"
        />

        <g clipPath="url(#spin-stand-clip)">
          <path d={PANEL_PATH} fill="url(#spin-stand-inner)" />
        </g>
      </svg>

      {/* Bulbs */}
      {(Object.keys(DOT_COLS) as (keyof typeof DOT_COLS)[]).map((side) =>
        DOT_ROWS.map((cy) => (
          <span
            key={`${side}-${cy}`}
            aria-hidden
            className="spinStandDot pointer-events-none absolute z-[5] w-[3.2%] -translate-x-1/2 -translate-y-1/2 rounded-full"
            style={{
              left: `${(DOT_COLS[side] / 800) * 100}%`,
              top: `${(cy / 355) * 100}%`,
              aspectRatio: "1",
            }}
          />
        )),
      )}

      {/* Action button */}
      <div
        className="absolute left-1/2 top-[54%] w-[44%] sm:w-[36%] max-w-[175px] -translate-x-1/2 -translate-y-1/2"
        style={
          buttonColor
            ? ({ "--spinwin-button-color": buttonColor } as React.CSSProperties)
            : undefined
        }
      >
        {showCountdown ? (
          <div className="absolute left-1/2 top-1/2 w-max -translate-x-1/2 -translate-y-1/2">
            {countdown}
          </div>
        ) : (
          <button
            type="button"
            onClick={onSpin}
            disabled={disabled}
            aria-label={label}
            className={`group relative block w-full leading-none ${
              canSpin ? "cursor-pointer" : "cursor-not-allowed"
            }`}
            style={{
              aspectRatio: `175 / ${FACE_H + LIP + SOCKET_PAD * 2}`,
              maxHeight: FACE_H + LIP + SOCKET_PAD * 2,
              // Keeps face tappable when aspect height gets too small on mobile.
              minHeight: 44,
              filter: "drop-shadow(0 6px 8px rgba(0,0,0,0.45))",
            }}
          >
            {/* Socket */}
            <span
              aria-hidden
              className="absolute inset-0 rounded-[12px]"
              style={{
                background: canSpin ? CRADLE : "#15181C",
                boxShadow: `inset 0 0 0 1px ${
                  canSpin
                    ? `color-mix(in srgb, ${BTN} 35%, #fff)`
                    : "rgba(255,255,255,0.15)"
                }`,
              }}
            />

            <span
              className="absolute"
              style={{
                left: SOCKET_PAD,
                right: SOCKET_PAD,
                top: SOCKET_PAD,
                bottom: SOCKET_PAD,
              }}
            >
              {/* Underside lip */}
              <span
                aria-hidden
                className="absolute inset-x-0 bottom-0 top-[3px] rounded-[9px]"
                style={{
                  background: canSpin
                    ? `linear-gradient(180deg, ${LIP_BOTTOM} 0%, ${LIP_TOP} 100%)`
                    : "linear-gradient(180deg, #3E434A 0%, #5B6169 100%)",
                }}
              />

              {/* Button face */}
              <span
                className={`absolute inset-x-0 top-0 flex items-center justify-center rounded-[9px] transition duration-[250ms] ease-out ${
                  canSpin && !disabled
                    ? "group-hover:-translate-y-[3px] group-focus-visible:-translate-y-[3px] group-hover:brightness-105 group-active:translate-y-[7px] group-active:brightness-100 group-active:duration-[80ms]"
                    : ""
                }`}
                style={{
                  bottom: LIP,
                  background: canSpin
                    ? `linear-gradient(180deg, ${GOLD_TOP} 0%, ${GOLD_MID} 45%, ${GOLD_BOTTOM} 100%)`
                    : "linear-gradient(180deg, #B6BDC4 0%, #8A929B 45%, #6B7280 100%)",
                  boxShadow: canSpin
                    ? `inset 0 1.5px 0 rgba(255,255,255,0.75), inset 0 -2px 3px color-mix(in srgb, color-mix(in srgb, ${BTN} 70%, #0A0A0A) 35%, transparent)`
                    : "inset 0 1.5px 0 #D3D8DD",
                  color: canSpin ? buttonTextColor || GOLD_TEXT : "#E5E7EB",
                }}
              >
                <span
                  className="flex items-center justify-center px-3 font-black uppercase tracking-[1px]"
                  style={{
                    fontSize: "clamp(14px, 4.6vw, 21px)",
                    textShadow: "0 1px 0 rgba(255,243,176,0.5)",
                  }}
                >
                  {label}
                </span>
              </span>
            </span>
          </button>
        )}
      </div>
    </div>
  );
};

export default SpinWinStand;
