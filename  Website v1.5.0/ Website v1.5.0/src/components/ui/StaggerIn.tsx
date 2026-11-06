"use client";
import React from "react";

interface StaggerInProps {
  /** Position in the list — drives the delay. */
  index?: number;
  /** Per-item delay in ms; capped so long lists don't crawl. */
  step?: number;
  maxDelayMs?: number;
  className?: string;
  children: React.ReactNode;
}

// Fades a just-loaded row/card in, slightly after the one before it. Lists swap
// from skeleton to content in a single frame otherwise, which reads as a jump.
const StaggerIn = ({
  index = 0,
  step = 45,
  maxDelayMs = 360,
  className = "",
  children,
}: StaggerInProps) => (
  <div
    className={`motion-safe:animate-contentIn ${className}`}
    style={{ animationDelay: `${Math.min(index * step, maxDelayMs)}ms` }}
  >
    {children}
  </div>
);

export default StaggerIn;
