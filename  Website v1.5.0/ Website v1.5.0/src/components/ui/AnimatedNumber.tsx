import { useEffect, useRef, useState } from "react";

interface AnimatedNumberProps {
  value: number | string;
  format: (value: number) => string;
  duration?: number;
  className?: string;
}

// Counts from the previous value to the new one; first render shows the value as-is.
const AnimatedNumber = ({ value, format, duration = 400, className = "" }: AnimatedNumberProps) => {
  const target = Number(value) || 0;
  const [display, setDisplay] = useState(target);
  const displayRef = useRef(target);

  useEffect(() => {
    const from = displayRef.current;
    if (from === target) return;
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const ms = reduceMotion ? 0 : duration;
    let frame = 0;
    const start = performance.now();
    const tick = (now: number) => {
      const progress = ms ? Math.min((now - start) / ms, 1) : 1;
      const eased = 1 - Math.pow(1 - progress, 3);
      const next = progress === 1 ? target : from + (target - from) * eased;
      displayRef.current = next;
      setDisplay(next);
      if (progress < 1) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [target, duration]);

  return <span className={`tabular-nums ${className}`}>{format(display)}</span>;
};

export default AnimatedNumber;
