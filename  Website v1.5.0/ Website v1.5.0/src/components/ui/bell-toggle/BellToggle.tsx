"use client";

import React, { useEffect, useLayoutEffect, useRef, useState } from "react";
import {
  animate,
  m,
  useMotionValue,
  useReducedMotion,
  useTransform,
  type AnimationPlaybackControls,
} from "framer-motion";

import "./BellToggle.css";
import {
  BellIcon,
  BellWaveLeftIcon,
  BellWaveRightIcon,
  BellClapperBodyIcon,
  BellClapperDotIcon,
} from "@/components/icons";

const SPRING_UI = { type: "spring", duration: 0.3, bounce: 0 } as const;
const SEG_EASE = "cubic-bezier(0.77, 0, 0.175, 1)";
const WARP = 0.6;
// [height, font, icon, padding-x, gap]
const SIZES = {
  sm: [36, 12.5, 14, 15, 8],
  md: [44, 13.5, 16, 19, 9],
  lg: [52, 15, 18, 23, 10],
} as const;
const WOBBLE = { amplitude: 0.4, passes: 3, duration: 420 };

const passOffset = (k: number, passes: number) =>
  1 - Math.pow(1 - (k + 2 / 3) / (passes + 1), WARP);
const ringKeyframes = (from: number, amplitude: number, passes: number, decay: number) => {
  const frames: Keyframe[] = [{ transform: `rotate(${from}deg)`, offset: 0, easing: SEG_EASE }];
  for (let k = 0; k < passes; k++) {
    const angle = amplitude * Math.pow(1 - k / passes, decay) * (k % 2 ? 1 : -1);
    frames.push({
      transform: `rotate(${angle.toFixed(2)}deg)`,
      offset: passOffset(k, passes),
      easing: SEG_EASE,
    });
  }
  frames.push({ transform: "rotate(0deg)", offset: 1 });
  return frames;
};
const liveAngle = (el: Element) => {
  const tf = getComputedStyle(el).transform;
  if (!tf || tf === "none") return 0;
  const mtx = new DOMMatrix(tf);
  return (Math.atan2(mtx.b, mtx.a) * 180) / Math.PI;
};

// Ring + waves on one bell element; shared by BellToggle-style buttons that keep their own layout.
const ringBell = (
  glyph: HTMLElement,
  waveL: SVGSVGElement | null,
  waveR: SVGSVGElement | null,
  amplitude = 17,
  passes = 5,
  duration = 820,
  decay = 1,
) => {
  glyph.getAnimations().forEach((a) => a.cancel());
  glyph.animate(ringKeyframes(liveAngle(glyph), amplitude, passes, decay), {
    duration,
    easing: "linear",
  });
  for (let k = 0; k < passes; k++) {
    const side = k % 2 ? waveR : waveL;
    if (!side) continue;
    const strength = Math.pow(1 - k / passes, decay);
    side.animate(
      [
        { opacity: 0, transform: "scale(0.55)" },
        { opacity: 0.9 * strength, offset: 0.3 },
        { opacity: 0, transform: "scale(1.25)" },
      ],
      { duration: 380, delay: passOffset(k, passes) * duration, easing: "ease-out" },
    );
  }
};

/** Bell icon that rings (with waves) when `on` turns true after mount — for existing buttons. */
export const RingBell = ({
  on,
  size = 14,
  className = "",
}: {
  on: boolean;
  size?: number;
  className?: string;
}) => {
  const glyphRef = useRef<HTMLSpanElement>(null);
  const waveL = useRef<SVGSVGElement>(null);
  const waveR = useRef<SVGSVGElement>(null);
  const prevOn = useRef(on);
  // Waves scale with the icon (CSS default is a fixed 14px).
  const waveStyle = { width: size * 0.6, height: size * 0.6, top: -size * 0.15 };
  useEffect(() => {
    const was = prevOn.current;
    prevOn.current = on;
    if (!on || was || !glyphRef.current) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    // Gentler than BellToggle: small swing, fewer passes for icon-sized bells.
    ringBell(glyphRef.current, waveL.current, waveR.current, 11, 4, 620);
  }, [on]);
  // className on a plain wrapper: .bell-toggle__bell's display would override utilities like max-md:hidden.
  return (
    <span aria-hidden="true" className={`inline-flex ${className}`}>
      <span
        className="bell-toggle__bell"
        style={{ "--bt-icon": `${size}px`, "--bt-pivot": "16%" } as React.CSSProperties}
      >
        <span ref={glyphRef} className="bell-toggle__glyph">
          <BellIcon size={size} />
        </span>
        <BellWaveLeftIcon ref={waveL} style={waveStyle} />
        <BellWaveRightIcon ref={waveR} style={waveStyle} />
      </span>
    </span>
  );
};

export interface BellToggleProps {
  offLabel?: string;
  onLabel?: string;
  icon?: React.ReactNode;
  label?: string;
  color?: string;
  background?: string;
  onColor?: string;
  onBackground?: string;
  size?: keyof typeof SIZES;
  /** Overrides the size preset's height (px), e.g. to match neighbouring controls. */
  height?: number;
  radius?: number;
  ringAmplitude?: number;
  ringPasses?: number;
  ringDecay?: number;
  ringDuration?: number;
  ringPivot?: number;
  crossfadeMs?: number;
  revealBounce?: number;
  count?: number;
  badge?: boolean;
  badgeColor?: string;
  badgeTextColor?: string;
  waves?: boolean;
  clapper?: boolean;
  pressed?: boolean;
  defaultPressed?: boolean;
  onChange?: (pressed: boolean) => void;
  disabled?: boolean;
  className?: string;
}

export default function BellToggle({
  offLabel = "Notify me",
  onLabel = "You'll be notified",
  icon,
  label,
  color = "#f5f5f5",
  background = "#27272a",
  onColor = "#18181b",
  onBackground = "#f5f5f5",
  size = "md",
  height,
  radius = 22,
  ringAmplitude = 17,
  ringPasses = 5,
  ringDecay = 1,
  ringDuration = 820,
  ringPivot = 16,
  crossfadeMs = 200,
  revealBounce = 0,
  count = 0,
  badge = true,
  badgeColor = "#ef4444",
  badgeTextColor = "#ffffff",
  waves = true,
  clapper = false,
  pressed,
  defaultPressed = false,
  onChange,
  disabled = false,
  className = "",
}: BellToggleProps) {
  const [inner, setInner] = useState(defaultPressed);
  const on = pressed ?? inner;
  const reduce = useReducedMotion();
  const rootRef = useRef<HTMLSpanElement>(null);
  const glyphRef = useRef<HTMLSpanElement>(null);
  const clapperRef = useRef<HTMLSpanElement>(null);
  const waveLeft = useRef<SVGSVGElement>(null);
  const waveRight = useRef<SVGSVGElement>(null);
  const offRef = useRef<HTMLSpanElement>(null);
  const onRef = useRef<HTMLSpanElement>(null);
  const lastInput = useRef<"pointer" | "keyboard">("pointer");
  const pending = useRef<"pointer" | "keyboard" | null>(null);
  const spring = useRef<AnimationPlaybackControls | null>(null);
  const prevCount = useRef(count);
  const [h, fs, iconSize, px, gap] = SIZES[size] ?? SIZES.md;

  const t = useMotionValue(on ? 1 : 0);
  const wOff = useMotionValue(0);
  const wOn = useMotionValue(0);
  // Clips the pill to the current label's width while both faces share one grid cell.
  const clip = useTransform(
    [t, wOff, wOn],
    ([v, a, b]: number[]) => `${Math.max(a, b) - (a + (b - a) * v)}px`,
  );

  useLayoutEffect(() => {
    const measure = () => {
      if (offRef.current) wOff.set(offRef.current.offsetWidth);
      if (onRef.current) wOn.set(onRef.current.offsetWidth);
    };
    measure();
    const observer = new ResizeObserver(measure);
    if (offRef.current) observer.observe(offRef.current);
    if (onRef.current) observer.observe(onRef.current);
    document.fonts?.ready.then(measure);
    return () => observer.disconnect();
  }, [offLabel, onLabel, size, wOff, wOn]);

  const swing = (amplitude: number, passes: number, duration: number) => {
    const el = glyphRef.current;
    if (!el) return;
    el.getAnimations().forEach((a) => a.cancel());
    el.animate(ringKeyframes(liveAngle(el), amplitude, passes, ringDecay), {
      duration,
      easing: "linear",
    });
    const c = clapperRef.current;
    if (c) {
      c.getAnimations().forEach((a) => a.cancel());
      c.animate(ringKeyframes(liveAngle(c), amplitude * 1.6, passes, ringDecay), {
        duration,
        delay: 70,
        easing: "linear",
      });
    }
    if (!waves) return;
    for (let k = 0; k < passes; k++) {
      const side = k % 2 ? waveRight.current : waveLeft.current;
      if (!side) continue;
      const strength = Math.pow(1 - k / passes, ringDecay);
      side.animate(
        [
          { opacity: 0, transform: "scale(0.55)" },
          { opacity: 0.9 * strength, offset: 0.3 },
          { opacity: 0, transform: "scale(1.25)" },
        ],
        { duration: 380, delay: passOffset(k, passes) * duration, easing: "ease-out" },
      );
    }
  };

  // Spring the width + ring the bell only for pointer toggles; keyboard/prop syncs jump.
  useLayoutEffect(() => {
    const pointer = pending.current === "pointer" && !reduce;
    pending.current = null;
    spring.current?.stop();
    if (pointer) spring.current = animate(t, on ? 1 : 0, { ...SPRING_UI, bounce: revealBounce });
    else t.jump(on ? 1 : 0);
    if (on && pointer) swing(ringAmplitude, ringPasses, ringDuration);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [on]);
  useLayoutEffect(() => () => spring.current?.stop(), []);

  useEffect(() => {
    const was = prevCount.current;
    prevCount.current = count;
    if (count > was && on && !reduce)
      swing(ringAmplitude * WOBBLE.amplitude, WOBBLE.passes, WOBBLE.duration);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [count]);

  const toggle = () => {
    pending.current = lastInput.current;
    if (pressed === undefined) setInner(!on);
    onChange?.(!on);
  };
  const press = (e: React.PointerEvent) => {
    lastInput.current = "pointer";
    if (e.button === 0 && !disabled && rootRef.current) rootRef.current.dataset.pressed = "";
  };
  const release = () => {
    if (rootRef.current) delete rootRef.current.dataset.pressed;
  };
  const key = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" || e.key === " ") lastInput.current = "keyboard";
  };

  const showBadge = badge && on && count > 0;

  return (
    <m.span
      ref={rootRef}
      className={`bell-toggle${className ? ` ${className}` : ""}`}
      data-on={on ? "true" : "false"}
      data-disabled={disabled ? "" : undefined}
      style={
        {
          "--bt-clip": clip,
          "--bt-color": color,
          "--bt-bg": background,
          "--bt-on-color": onColor,
          "--bt-on-bg": onBackground,
          "--bt-badge": badgeColor,
          "--bt-badge-ink": badgeTextColor,
          "--bt-radius": `${radius}px`,
          "--bt-fade": `${crossfadeMs}ms`,
          "--bt-pivot": `${ringPivot}%`,
          "--bt-h": `${height ?? h}px`,
          "--bt-fs": `${fs}px`,
          "--bt-icon": `${iconSize}px`,
          "--bt-px": `${px}px`,
          "--bt-gap": `${gap}px`,
        } as unknown as React.ComponentProps<typeof m.span>["style"]
      }
    >
      <button
        type="button"
        className="bell-toggle__button"
        aria-pressed={on}
        aria-label={label ?? offLabel}
        disabled={disabled}
        onPointerDown={press}
        onPointerUp={release}
        onPointerCancel={release}
        onPointerLeave={release}
        onKeyDown={key}
        onClick={toggle}
      >
        <span className="bell-toggle__bell" aria-hidden="true">
          <span ref={glyphRef} className="bell-toggle__glyph">
            {clapper ? (
              <BellClapperBodyIcon size={iconSize} />
            ) : (
              (icon ?? <BellIcon size={iconSize} />)
            )}
          </span>
          {clapper ? (
            <span ref={clapperRef} className="bell-toggle__clapper">
              <BellClapperDotIcon size={iconSize} />
            </span>
          ) : null}
          {waves ? (
            <>
              <BellWaveLeftIcon ref={waveLeft} />
              <BellWaveRightIcon ref={waveRight} />
            </>
          ) : null}
          {badge ? (
            <span className="bell-toggle__badge" data-show={showBadge ? "" : undefined}>
              <span key={count} className="bell-toggle__digit">
                {count > 9 ? "9+" : count}
              </span>
            </span>
          ) : null}
        </span>
        <span className="bell-toggle__say" aria-hidden="true">
          <span ref={offRef} className="bell-toggle__face bell-toggle__face--off">
            {offLabel}
          </span>
          <span ref={onRef} className="bell-toggle__face bell-toggle__face--on">
            {onLabel}
          </span>
        </span>
      </button>
    </m.span>
  );
}
