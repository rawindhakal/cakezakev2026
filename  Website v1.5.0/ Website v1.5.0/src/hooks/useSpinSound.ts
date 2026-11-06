import { useCallback, useEffect, useRef, useState } from "react";

const MUTE_KEY = "spinWheelMuted";
const SPIN_SOUND_SRC = "/spin-sound.mp3";

// Web Audio API synthesised sound FX for spin wheel.

const readMuted = (): boolean => {
  try {
    return localStorage.getItem(MUTE_KEY) === "1";
  } catch {
    // Private windows and blocked site data throw on access.
    return false;
  }
};

export default function useSpinSound() {
  const ctxRef = useRef<AudioContext | null>(null);
  const spinAudioRef = useRef<HTMLAudioElement | null>(null);
  const [muted, setMuted] = useState(false);

  // Sync initial mute preference from localStorage on mount.
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- one-time post-mount sync from localStorage, not a cascading update
    setMuted(readMuted());
  }, []);

  useEffect(
    () => () => {
      ctxRef.current?.close().catch(() => {});
      ctxRef.current = null;
      spinAudioRef.current?.pause();
      spinAudioRef.current = null;
    },
    [],
  );

  // Lazy AudioContext initialization on user interaction.
  const getContext = useCallback((): AudioContext | null => {
    if (typeof window === "undefined") return null;
    const Ctor: typeof AudioContext | undefined =
      window.AudioContext || (window as any).webkitAudioContext;
    if (!Ctor) return null;
    try {
      ctxRef.current ??= new Ctor();
      if (ctxRef.current.state === "suspended") ctxRef.current.resume().catch(() => {});
      return ctxRef.current;
    } catch {
      return null;
    }
  }, []);

  const toggleMuted = useCallback(() => {
    setMuted((prev) => {
      const next = !prev;
      try {
        localStorage.setItem(MUTE_KEY, next ? "1" : "0");
      } catch {
        // Preference just won't persist; the toggle still works this session.
      }
      return next;
    });
  }, []);

  /** One ratchet click — the wheel passing a peg. */
  const playTick = useCallback(
    (volume = 1) => {
      if (muted) return;
      const ctx = getContext();
      if (!ctx) return;
      const now = ctx.currentTime;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "square";
      // Pitch variation and short exponential decay for click effect.
      osc.frequency.setValueAtTime(1180 + Math.random() * 140, now);
      gain.gain.setValueAtTime(0.05 * volume, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.035);
      osc.connect(gain).connect(ctx.destination);
      osc.start(now);
      osc.stop(now + 0.04);
    },
    [getContext, muted],
  );

  // Lazy HTMLAudioElement creation for spin audio asset.
  const getSpinAudio = useCallback((): HTMLAudioElement | null => {
    if (typeof window === "undefined") return null;
    try {
      spinAudioRef.current ??= new Audio(SPIN_SOUND_SRC);
      return spinAudioRef.current;
    } catch {
      return null;
    }
  }, []);

  /** Wheel-turning sound — starts when the spin begins. */
  const playSpinSound = useCallback(() => {
    if (muted) return;
    const audio = getSpinAudio();
    if (!audio) return;
    audio.currentTime = 0;
    audio.play().catch(() => {});
  }, [getSpinAudio, muted]);

  /** Stops the wheel-turning sound — call when the spin animation ends. */
  const stopSpinSound = useCallback(() => {
    spinAudioRef.current?.pause();
  }, []);

  /** Rising arpeggio for a win. */
  const playWin = useCallback(() => {
    if (muted) return;
    const ctx = getContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    // Major triad arpeggio resolving up an octave.
    [1046.5, 1318.5, 1568, 2093].forEach((freq, i) => {
      const at = now + i * 0.1;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "triangle";
      osc.frequency.setValueAtTime(freq, at);
      gain.gain.setValueAtTime(0.0001, at);
      gain.gain.exponentialRampToValueAtTime(0.16, at + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, at + 0.42);
      osc.connect(gain).connect(ctx.destination);
      osc.start(at);
      osc.stop(at + 0.45);
    });
  }, [getContext, muted]);

  return { muted, toggleMuted, playTick, playWin, playSpinSound, stopSpinSound };
}
