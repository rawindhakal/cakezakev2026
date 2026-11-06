"use client";

import React, { useState } from "react";
import { m } from "framer-motion";

interface SpinWinConfettiProps {
  active: boolean;
}

const COLORS = ["#FF6B6B", "#4ECDC4", "#FFD166", "#6C63FF", "#06D6A0"];
const PIECE_COUNT = 44;

/**
 * Confetti particle animation burst for win celebrations.
 */
const SpinWinConfetti = ({ active }: SpinWinConfettiProps) => {
  // Generate random confetti pieces once on initial mount.
  const [pieces] = useState(() =>
    Array.from({ length: PIECE_COUNT }).map((_, i) => ({
      id: i,
      left: Math.random() * 100,
      delay: Math.random() * 0.3,
      duration: 1.6 + Math.random() * 1.1,
      rotate: Math.random() * 360,
      drift: (Math.random() - 0.5) * 120,
      color: COLORS[i % COLORS.length],
      size: 6 + Math.random() * 6,
      isCircle: i % 3 === 0,
    })),
  );

  if (!active) return null;

  return (
    <div className="pointer-events-none absolute inset-0 z-40 overflow-hidden">
      {pieces.map((p) => (
        <m.span
          key={p.id}
          className="absolute top-0"
          style={{
            left: `${p.left}%`,
            width: p.size,
            height: p.size,
            backgroundColor: p.color,
            borderRadius: p.isCircle ? "9999px" : "2px",
          }}
          initial={{ y: -20, x: 0, opacity: 1, rotate: 0 }}
          animate={{
            y: "110vh",
            x: p.drift,
            opacity: [1, 1, 0],
            rotate: p.rotate,
          }}
          transition={{
            duration: p.duration,
            delay: p.delay,
            ease: "easeIn",
          }}
        />
      ))}
    </div>
  );
};

export default SpinWinConfetti;
