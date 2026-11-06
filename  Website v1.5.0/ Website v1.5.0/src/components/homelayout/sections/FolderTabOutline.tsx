"use client";

import { m } from "framer-motion";

// Folder tab SVG outline path drawing.
const FLARE = 8;
const TOP_RADIUS = 12;
const TAB_SLIDE_TRANSITION = {
  type: "spring" as const,
  stiffness: 420,
  damping: 38,
  mass: 0.7,
};

const FolderTabOutline = ({
  tabLeft,
  width,
  height,
  stripWidth,
  fill,
  stroke,
  gradientFrom,
  gradientTo,
  backgroundImageUrl,
}: {
  /** Active tab's left offset. */
  tabLeft: number;
  width: number;
  height: number;
  /** Full scroll width of the tab strip. */
  stripWidth: number;
  fill?: string;
  stroke: string;
  gradientFrom?: string;
  gradientTo?: string;
  backgroundImageUrl?: string;
}) => {
  if (!width || !height) return null;
  const w = Math.max(stripWidth, tabLeft + width) + FLARE;
  const h = height;
  const sw = 1.5;
  const half = sw / 2;
  const baseline = h - half;
  const radius = Math.min(TOP_RADIUS, width / 2, Math.max(h - FLARE - half, 0));
  const uid = `${Math.round(width)}x${Math.round(h)}`;
  const patternId = `folderTabFill-${uid}`;
  const gradientId = `folderTabGradient-${uid}`;
  const hasImage = !!backgroundImageUrl;
  const hasGradient = !hasImage && !!gradientFrom;
  const pathFill = (() => {
    if (hasImage) return `url(#${patternId})`;
    if (hasGradient) return `url(#${gradientId})`;
    return fill || "none";
  })();

  const tabOutline = [
    `M ${-FLARE} ${baseline}`,
    `A ${FLARE} ${FLARE} 0 0 0 0 ${baseline - FLARE}`,
    `V ${radius + half}`,
    `A ${radius} ${radius} 0 0 1 ${radius} ${half}`,
    `H ${width - radius}`,
    `A ${radius} ${radius} 0 0 1 ${width} ${radius + half}`,
    `V ${baseline - FLARE}`,
    `A ${FLARE} ${FLARE} 0 0 0 ${width + FLARE} ${baseline}`,
  ].join(" ");
  const tabFillD = `${tabOutline} Z`;

  return (
    <svg
      className="absolute bottom-0 left-0 pointer-events-none"
      style={{ width: w, height: h, overflow: "visible" }}
      viewBox={`0 0 ${w} ${h}`}
      aria-hidden
    >
      <defs>
        {hasImage && (
          <pattern
            id={patternId}
            patternUnits="userSpaceOnUse"
            x={-FLARE}
            width={width + FLARE * 2}
            height={h}
          >
            <image
              href={backgroundImageUrl}
              width={width + FLARE * 2}
              height={h}
              preserveAspectRatio="xMidYMid slice"
            />
          </pattern>
        )}
        {hasGradient && (
          <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={gradientFrom} />
            <stop offset="100%" stopColor={gradientTo || "transparent"} />
          </linearGradient>
        )}
      </defs>

      {/* Sliding tab group with baseline and path fill */}
      <m.g initial={false} animate={{ x: tabLeft }} transition={TAB_SLIDE_TRANSITION}>
        {pathFill !== "none" && <path d={tabFillD} fill={pathFill} stroke="none" />}
        <path
          d={`M ${-FLARE} ${baseline} H ${-w}`}
          fill="none"
          stroke={stroke}
          strokeWidth={sw}
        />
        <path
          d={`M ${width + FLARE} ${baseline} H ${w}`}
          fill="none"
          stroke={stroke}
          strokeWidth={sw}
        />
        <path
          d={tabOutline}
          fill="none"
          stroke={stroke}
          strokeWidth={sw}
          strokeLinejoin="round"
        />
      </m.g>
    </svg>
  );
};

export default FolderTabOutline;
