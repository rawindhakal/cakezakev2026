interface ProgressRingProps {
  /** 0–1 fill amount. */
  progress: number;
  size?: number;
  strokeWidth?: number;
  color?: string;
  trackColor?: string;
  className?: string;
}

// Circular progress ring, e.g. "back to top" scroll progress on a round button.
const ProgressRing = ({
  progress,
  size = 48,
  strokeWidth = 2.5,
  color = "#fff",
  trackColor = "rgba(255,255,255,0.3)",
  className = "",
}: ProgressRingProps) => {
  const radius = size / 2 - strokeWidth * 2;
  const circumference = 2 * Math.PI * radius;
  const center = size / 2;

  return (
    <svg
      className={`pointer-events-none absolute inset-0 h-full w-full -rotate-90 ${className}`}
      viewBox={`0 0 ${size} ${size}`}
      aria-hidden="true"
    >
      <circle
        cx={center}
        cy={center}
        r={radius}
        fill="none"
        stroke={trackColor}
        strokeWidth={strokeWidth}
      />
      <circle
        cx={center}
        cy={center}
        r={radius}
        fill="none"
        stroke={color}
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeDasharray={circumference}
        strokeDashoffset={circumference * (1 - progress)}
        style={{ transition: "stroke-dashoffset 0.1s linear" }}
      />
    </svg>
  );
};

export default ProgressRing;
