import { useEffect, useState } from "react";

export interface Countdown {
  /** Whole hours remaining (can exceed 24). */
  hours: number;
  minutes: number;
  seconds: number;
  /** Formatted countdown string. */
  label: string;
  /** Whether countdown target has passed. */
  finished: boolean;
}

const pad = (n: number) => String(n).padStart(2, "0");

// Ticks once per second toward a target ISO timestamp with SSR hydration safety.
export default function useCountdown(target?: string | null): Countdown | null {
  const [now, setNow] = useState<number | null>(null);

  useEffect(() => {
    if (!target) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- one-time reset when the target itself changes, not a cascading update
      setNow(null);
      return;
    }
    setNow(Date.now());
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, [target]);

  if (!target || now == null) return null;

  const targetMs = new Date(target).getTime();
  if (Number.isNaN(targetMs)) return null;

  const remaining = Math.max(targetMs - now, 0);
  const totalSeconds = Math.floor(remaining / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  return {
    hours,
    minutes,
    seconds,
    label: hours > 0
      ? `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`
      : `${pad(minutes)}:${pad(seconds)}`,
    finished: remaining === 0,
  };
}

