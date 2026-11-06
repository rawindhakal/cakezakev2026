// Shared framer-motion timings + variants. Mirrors the Tailwind motion tokens
// in tailwind.config.js so CSS and JS animations stay in step.
import type { Transition, Variants } from "framer-motion";

export const DURATION = {
  fast: 0.15,
  base: 0.2,
  slow: 0.3,
  slower: 0.5,
} as const;

export const EASE = {
  standard: [0.2, 0, 0, 1],
  entrance: [0, 0, 0, 1],
  exit: [0.3, 0, 1, 1],
} as const;

export const transition: Record<"fast" | "base" | "slow", Transition> = {
  fast: { duration: DURATION.fast, ease: EASE.standard },
  base: { duration: DURATION.base, ease: EASE.standard },
  slow: { duration: DURATION.slow, ease: EASE.standard },
};

export const fade: Variants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1, transition: transition.base },
  exit: { opacity: 0, transition: transition.fast },
};

export const fadeUp: Variants = {
  hidden: { opacity: 0, y: 8 },
  visible: { opacity: 1, y: 0, transition: transition.slow },
  exit: { opacity: 0, y: 8, transition: transition.fast },
};

export const scaleIn: Variants = {
  hidden: { opacity: 0, scale: 0.97 },
  visible: { opacity: 1, scale: 1, transition: transition.base },
  exit: { opacity: 0, scale: 0.97, transition: transition.fast },
};

// Parent of a list: children fade up one after another.
export const stagger = (step = 0.04): Variants => ({
  hidden: {},
  visible: { transition: { staggerChildren: step } },
});
