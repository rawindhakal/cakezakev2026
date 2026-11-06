"use client";

import { LazyMotion, MotionConfig } from "framer-motion";

// Features load on demand so the ~34kB animation bundle stays out of first
// paint. domMax (not domAnimation) because ProductsList/ProductStory use
// layout animations.
const loadFeatures = () =>
  import("framer-motion").then((mod) => mod.domMax);

export default function MotionProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    // strict: `m.*` only — a stray `motion.*` would re-import the full bundle.
    <LazyMotion features={loadFeatures} strict>
      {/* Honours the OS "reduce motion" setting for every framer animation. */}
      <MotionConfig reducedMotion="user">{children}</MotionConfig>
    </LazyMotion>
  );
}
