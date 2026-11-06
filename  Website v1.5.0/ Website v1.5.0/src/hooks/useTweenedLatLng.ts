import { useEffect, useRef, useState } from "react";

interface LatLng {
  lat: number | null;
  lng: number | null;
}

// Glides a coordinate towards each new fix instead of jumping to it. A live
// feed that polls every few seconds otherwise teleports its marker.
const useTweenedLatLng = (
  target: LatLng | undefined,
  durationMs = 1200,
): LatLng | undefined => {
  const [value, setValue] = useState<LatLng | undefined>(target);
  const fromRef = useRef<LatLng | undefined>(target);
  const frameRef = useRef<number | null>(null);

  const lat = target?.lat ?? null;
  const lng = target?.lng ?? null;

  useEffect(() => {
    if (lat == null || lng == null) return;
    const from = fromRef.current;

    // First fix, a reduced-motion preference, or a jump too big to be a drive
    // (rider reassigned, GPS correction): snap instead of gliding across town.
    const far =
      from?.lat != null &&
      from?.lng != null &&
      Math.hypot(lat - from.lat, lng - from.lng) > 0.05;
    const reduced =
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    if (from?.lat == null || from?.lng == null || far || reduced) {
      fromRef.current = { lat, lng };
      setValue({ lat, lng });
      return;
    }

    const startLat = from.lat;
    const startLng = from.lng;
    const startedAt = performance.now();
    // easeOutCubic — quick departure, settles onto the new fix.
    const ease = (t: number) => 1 - Math.pow(1 - t, 3);

    const step = (now: number) => {
      const t = Math.min((now - startedAt) / durationMs, 1);
      const k = ease(t);
      const next = {
        lat: startLat + (lat - startLat) * k,
        lng: startLng + (lng - startLng) * k,
      };
      fromRef.current = next;
      setValue(next);
      if (t < 1) frameRef.current = requestAnimationFrame(step);
    };

    frameRef.current = requestAnimationFrame(step);
    return () => {
      if (frameRef.current != null) cancelAnimationFrame(frameRef.current);
    };
  }, [lat, lng, durationMs]);

  // value lags one render behind a first fix (effect has not run yet).
  if (lat == null || lng == null) return target;
  return value?.lat != null && value?.lng != null ? value : { lat, lng };
};

export default useTweenedLatLng;
