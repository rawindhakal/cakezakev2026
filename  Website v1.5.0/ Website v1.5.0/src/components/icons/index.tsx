import React, { forwardRef } from "react";

// Shared custom SVG icons (currentColor, so they follow text colour).
interface IconProps {
  size?: number;
  className?: string;
}

// Parcel — delivery mode.
export const DeliveryIcon = ({ size = 16, className = "" }: IconProps) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    className={`shrink-0 ${className}`}
    aria-hidden
  >
    <path
      fillRule="evenodd"
      clipRule="evenodd"
      d="M12 1.25C11.3953 1.25 10.8384 1.40029 10.2288 1.65242C9.64008 1.89588 8.95633 2.25471 8.1049 2.70153L6.03739 3.78651C4.99242 4.33487 4.15616 4.77371 3.51047 5.20491C2.84154 5.65164 2.32632 6.12201 1.95112 6.75918C1.57718 7.39421 1.40896 8.08184 1.32829 8.90072C1.24999 9.69558 1.24999 10.6731 1.25 11.9026V12.0974C1.24999 13.3268 1.24999 14.3044 1.32829 15.0993C1.40896 15.9182 1.57718 16.6058 1.95112 17.2408C2.32632 17.878 2.84154 18.3484 3.51047 18.7951C4.15616 19.2263 4.99241 19.6651 6.03737 20.2135L8.10481 21.2984C8.95628 21.7453 9.64006 22.1041 10.2288 22.3476C10.8384 22.5997 11.3953 22.75 12 22.75C12.6047 22.75 13.1616 22.5997 13.7712 22.3476C14.3599 22.1041 15.0437 21.7453 15.8951 21.2985L17.9626 20.2135C19.0076 19.6651 19.8438 19.2263 20.4895 18.7951C21.1585 18.3484 21.6737 17.878 22.0489 17.2408C22.4228 16.6058 22.591 15.9182 22.6717 15.0993C22.75 14.3044 22.75 13.3269 22.75 12.0975V11.9025C22.75 10.6731 22.75 9.69557 22.6717 8.90072C22.591 8.08184 22.4228 7.39421 22.0489 6.75918C21.6737 6.12201 21.1585 5.65164 20.4895 5.20491C19.8438 4.77371 19.0076 4.33487 17.9626 3.7865L15.8951 2.70154C15.0437 2.25472 14.3599 1.89589 13.7712 1.65242C13.1616 1.40029 12.6047 1.25 12 1.25ZM8.7708 4.04608C9.66052 3.57917 10.284 3.2528 10.802 3.03856C11.3062 2.83004 11.6605 2.75 12 2.75C12.3395 2.75 12.6938 2.83004 13.198 3.03856C13.716 3.2528 14.3395 3.57917 15.2292 4.04608L17.2292 5.09563C18.3189 5.66748 19.0845 6.07032 19.6565 6.45232C19.9387 6.64078 20.1604 6.81578 20.3395 6.99174L17.0088 8.65708L8.50895 4.18349L8.7708 4.04608ZM6.94466 5.00439L6.7708 5.09563C5.68111 5.66747 4.91553 6.07032 4.34352 6.45232C4.06131 6.64078 3.83956 6.81578 3.66054 6.99174L12 11.1615L15.3572 9.48289L7.15069 5.16369C7.07096 5.12173 7.00191 5.06743 6.94466 5.00439ZM2.93768 8.30737C2.88718 8.52125 2.84901 8.76413 2.82106 9.04778C2.75084 9.7606 2.75 10.6644 2.75 11.9415V12.0585C2.75 13.3356 2.75084 14.2394 2.82106 14.9522C2.88974 15.6494 3.02022 16.1002 3.24367 16.4797C3.46587 16.857 3.78727 17.1762 4.34352 17.5477C4.91553 17.9297 5.68111 18.3325 6.7708 18.9044L8.7708 19.9539C9.66052 20.4208 10.284 20.7472 10.802 20.9614C10.9656 21.0291 11.1134 21.0832 11.25 21.1255V12.4635L2.93768 8.30737ZM12.75 21.1255C12.8866 21.0832 13.0344 21.0291 13.198 20.9614C13.716 20.7472 14.3395 20.4208 15.2292 19.9539L17.2292 18.9044C18.3189 18.3325 19.0845 17.9297 19.6565 17.5477C20.2127 17.1762 20.5341 16.857 20.7563 16.4797C20.9798 16.1002 21.1103 15.6494 21.1789 14.9522C21.2492 14.2394 21.25 13.3356 21.25 12.0585V11.9415C21.25 10.6644 21.2492 9.7606 21.1789 9.04778C21.151 8.76412 21.1128 8.52125 21.0623 8.30736L17.75 9.96352V13C17.75 13.4142 17.4142 13.75 17 13.75C16.5858 13.75 16.25 13.4142 16.25 13V10.7135L12.75 12.4635V21.1255Z"
      fill="currentColor"
    />
  </svg>
);

// Bag — self pickup mode.
export const PickupIcon = ({ size = 16, className = "" }: IconProps) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 18 18"
    fill="none"
    className={`shrink-0 ${className}`}
    aria-hidden
  >
    <path
      d="M6.375 10.6875C6.375 12.1275 7.56 13.3125 9 13.3125C10.44 13.3125 11.625 12.1275 11.625 10.6875"
      stroke="currentColor"
      strokeWidth="1.125"
      strokeMiterlimit="10"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M6.60758 1.5L3.89258 4.2225"
      stroke="currentColor"
      strokeWidth="1.125"
      strokeMiterlimit="10"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M11.3926 1.5L14.1076 4.2225"
      stroke="currentColor"
      strokeWidth="1.125"
      strokeMiterlimit="10"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M1.5 5.88745C1.5 4.49995 2.2425 4.38745 3.165 4.38745H14.835C15.7575 4.38745 16.5 4.49995 16.5 5.88745C16.5 7.49995 15.7575 7.38745 14.835 7.38745H3.165C2.2425 7.38745 1.5 7.49995 1.5 5.88745Z"
      stroke="currentColor"
      strokeWidth="1.125"
    />
    <path
      d="M2.625 7.5L3.6825 13.98C3.9225 15.435 4.5 16.5 6.645 16.5H11.1675C13.5 16.5 13.845 15.48 14.115 14.07L15.375 7.5"
      stroke="currentColor"
      strokeWidth="1.125"
      strokeLinecap="round"
    />
  </svg>
);

// Cookie — consent banner icon.
export const CookieIcon = ({ size = 16, className = "" }: IconProps) => (
  <svg
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    width={size}
    height={size}
    className={`shrink-0 ${className}`}
  >
    <path d="M12 2a10 10 0 1 0 10 10 4 4 0 0 1-5-5 4 4 0 0 1-5-5Z" />
    <circle cx="8.5" cy="12.5" r="0.6" fill="currentColor" />
    <circle cx="12.5" cy="9" r="0.6" fill="currentColor" />
    <circle cx="13" cy="15" r="0.6" fill="currentColor" />
  </svg>
);

// Shopping cart — Demo buy-now CTA.
export const CartIcon = ({ size = 16, className = "" }: IconProps) => (
  <svg
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    width={size}
    height={size}
    className={`shrink-0 ${className}`}
  >
    <circle cx="8" cy="21" r="1" />
    <circle cx="19" cy="21" r="1" />
    <path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12" />
  </svg>
);

// Clock — maintenance notice icon.
export const ClockIcon = ({ size = 16, className = "" }: IconProps) => (
  <svg
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    width={size}
    height={size}
    className={`shrink-0 ${className}`}
  >
    <circle cx="12" cy="12" r="9" />
    <path d="M12 7v5l3 2" />
  </svg>
);

// Close (X) — plain stroke glyph.
export const CloseIcon = ({ size = 16, className = "" }: IconProps) => (
  <svg
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    width={size}
    height={size}
    className={`shrink-0 ${className}`}
  >
    <path d="M18 6 6 18M6 6l12 12" />
  </svg>
);

// Zigzag/scalloped edge under a discount ribbon.
export const ZigzagEdgeIcon = ({ size, className = "" }: IconProps & { size?: number }) => (
  <svg
    className={`block w-full primaryColor ${className}`}
    height={size ?? 6}
    viewBox="0 0 40 6"
    preserveAspectRatio="none"
    aria-hidden="true"
  >
    <path
      fill="currentColor"
      d="M0,0 Q2.5,6 5,0 Q7.5,6 10,0 Q12.5,6 15,0 Q17.5,6 20,0 Q22.5,6 25,0 Q27.5,6 30,0 Q32.5,6 35,0 Q37.5,6 40,0 Z"
    />
  </svg>
);

// N vertical bars — column-count view toggle (2/3/4/5 columns).
export const ColumnsIcon = ({
  count = 4,
  size = 18,
  className = "",
}: IconProps & { count?: number }) => {
  const gap = 2;
  const totalGap = gap * (count - 1);
  const barW = (size - totalGap) / count;
  return (
    <svg
      width={size}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
      fill="currentColor"
      aria-hidden="true"
      className={`shrink-0 ${className}`}
    >
      {Array.from({ length: count }).map((_, i) => (
        <rect key={i} x={i * (barW + gap)} y={0} width={barW} height={size} rx={1} />
      ))}
    </svg>
  );
};

// Lucide bell (ISC) — notify/notification glyph.
export const BellIcon = ({ size = 16, className = "" }: IconProps) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    className={`shrink-0 ${className}`}
  >
    <path d="M10.268 21a2 2 0 0 0 3.464 0" />
    <path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326" />
  </svg>
);

// Bell notification wave animation — left wave.
export const BellWaveLeftIcon = forwardRef<
  SVGSVGElement,
  { className?: string; style?: React.CSSProperties }
>(({ className = "", style }, ref) => (
  <svg
    ref={ref}
    className={`bell-toggle__wave bell-toggle__wave--left ${className}`}
    style={style}
    viewBox="0 0 14 14"
    aria-hidden="true"
  >
    <path d="M14 8a6 6 0 0 0-6 6" />
    <path d="M14 4A10 10 0 0 0 4 14" />
  </svg>
));
BellWaveLeftIcon.displayName = "BellWaveLeftIcon";

// Bell notification wave animation — right wave.
export const BellWaveRightIcon = forwardRef<
  SVGSVGElement,
  { className?: string; style?: React.CSSProperties }
>(({ className = "", style }, ref) => (
  <svg
    ref={ref}
    className={`bell-toggle__wave bell-toggle__wave--right ${className}`}
    style={style}
    viewBox="0 0 14 14"
    aria-hidden="true"
  >
    <path d="M0 8a6 6 0 0 1 6 6" />
    <path d="M0 4a10 10 0 0 1 10 10" />
  </svg>
));
BellWaveRightIcon.displayName = "BellWaveRightIcon";

// Bell clapper variant body SVG.
export const BellClapperBodyIcon = ({ size = 24, className = "" }: IconProps) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    className={`shrink-0 ${className}`}
    aria-hidden="true"
  >
    <path d="M6 16.5V10a6 6 0 0 1 12 0v6.5l1.6 2.3H4.4L6 16.5z" />
    <path d="M12 2.5V4" />
  </svg>
);

// Bell clapper variant dot SVG.
export const BellClapperDotIcon = ({ size = 24, className = "" }: IconProps) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    className={`shrink-0 ${className}`}
    aria-hidden="true"
  >
    <circle cx="12" cy="20.4" r="1.7" fill="currentColor" />
  </svg>
);

// Lucide paths (ISC), 24x24 stroke icons for pulse button variants.
export const PULSE_ICONS: Record<string, string[]> = {
  heart: [
    "M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z",
  ],
  star: [
    "M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z",
  ],
  thumb: [
    "M7 10v12",
    "M15 5.88 14 10h5.83a2 2 0 0 1 1.92 2.56l-2.33 8A2 2 0 0 1 17.5 22H4a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2h2.76a2 2 0 0 0 1.79-1.11L12 2a3.13 3.13 0 0 1 3 3.88Z",
  ],
};

export const HeartIcon = ({ size = 24, className = "" }: IconProps) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    className={`shrink-0 ${className}`}
    aria-hidden="true"
  >
    <path d={PULSE_ICONS.heart[0]} />
  </svg>
);

export const StarIcon = ({ size = 24, className = "" }: IconProps) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    className={`shrink-0 ${className}`}
    aria-hidden="true"
  >
    <path d={PULSE_ICONS.star[0]} />
  </svg>
);

export const ThumbIcon = ({ size = 24, className = "" }: IconProps) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    className={`shrink-0 ${className}`}
    aria-hidden="true"
  >
    {PULSE_ICONS.thumb.map((d) => (
      <path key={d} d={d} />
    ))}
  </svg>
);

// SpinWin stand graphics paths for cabinet, base, panel, and wings.
export const SPIN_WIN_STAND_PATHS = {
  cabinet: `
  M 8 105
  Q 8 78 36 68
  L 310 10
  Q 400 -8 490 10
  L 764 68
  Q 792 78 792 105
  L 792 250
  Q 792 294 748 294
  L 52 294
  Q 8 294 8 250
  Z
`,
  base: `
  M 8 240
  L 792 240
  L 792 318
  Q 792 350 760 350
  L 40 350
  Q 8 350 8 318
  Z
`,
  panel: `
  M 36 134
  Q 36 112 62 103
  L 322 52
  Q 400 36 478 52
  L 738 103
  Q 764 112 764 134
  L 764 244
  Q 764 266 742 266
  L 58 266
  Q 36 266 36 244
  Z
`,
  leftWing: "M 76 -190 L 10 -50 L 10 250 L 76 250 Z",
  rightWing: "M 724 -190 L 790 -50 L 790 250 L 724 250 Z",
};

// Rounded polygon path generator for pointers.
export const createRoundedPolygonPath = (
  pts: [number, number][],
  r: number,
) => {
  const n = pts.length;
  const toward = (a: [number, number], b: [number, number]) => {
    const dx = b[0] - a[0];
    const dy = b[1] - a[1];
    const len = Math.hypot(dx, dy) || 1;
    const d = Math.min(r, len / 2);
    return [a[0] + (dx / len) * d, a[1] + (dy / len) * d];
  };
  let d = "";
  for (let i = 0; i < n; i++) {
    const prev = pts[(i - 1 + n) % n];
    const cur = pts[i];
    const next = pts[(i + 1) % n];
    const start = toward(cur, prev);
    const end = toward(cur, next);
    d += `${i === 0 ? "M" : "L"} ${start[0]} ${start[1]} Q ${cur[0]} ${cur[1]} ${end[0]} ${end[1]} `;
  }
  return `${d}Z`;
};

export const SPIN_WHEEL_POINTER_PATH = createRoundedPolygonPath(
  [
    [0, 0],
    [48, 0],
    [24, 30.5],
  ],
  5,
);

// Refer & Earn steps connector SVG with dashed arcs and arrowhead.
export const ReferStepConnectorIcon = ({
  isRtl = false,
  className = "",
}: {
  isRtl?: boolean;
  className?: string;
}) => (
  <svg
    className={`pointer-events-none absolute left-0 top-3 h-6 w-full ${
      isRtl ? "-scale-x-100" : ""
    } ${className}`}
    viewBox="0 0 320 24"
    fill="none"
    preserveAspectRatio="none"
    aria-hidden="true"
  >
    <defs>
      <marker
        id="referArrow"
        viewBox="0 0 10 10"
        refX="4"
        refY="5"
        markerWidth="6"
        markerHeight="6"
        orient="auto-start-reverse"
      >
        <path
          d="M1 1L8 5L1 9"
          fill="none"
          stroke="var(--primary-color)"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </marker>
    </defs>
    <path
      d="M84 11 Q107 -2 130 11"
      stroke="color-mix(in srgb, var(--primary-color) 55%, transparent)"
      strokeWidth="1.6"
      strokeDasharray="4 4"
      strokeLinecap="round"
      markerEnd="url(#referArrow)"
    />
    <path
      d="M190 11 Q213.5 -2 237 11"
      stroke="color-mix(in srgb, var(--primary-color) 55%, transparent)"
      strokeWidth="1.6"
      strokeDasharray="4 4"
      strokeLinecap="round"
      markerEnd="url(#referArrow)"
    />
  </svg>
);

const PROMO_SEGMENT_HUES = [
  "#F0508C",
  "#8B3FD9",
  "#3B6FE0",
  "#22B3C9",
  "#57C24A",
  "#F2C230",
  "#F09135",
  "#E14B3C",
];
const PROMO_CX = 36;
const PROMO_CY = 36;
const PROMO_R_SEGMENTS = 27;
const PROMO_R_RIM = 30;
const PROMO_RIM_W = 7;

const promoToRad = (deg: number) => ((deg - 90) * Math.PI) / 180;
const promoPointOn = (r: number, deg: number) => [
  PROMO_CX + r * Math.cos(promoToRad(deg)),
  PROMO_CY + r * Math.sin(promoToRad(deg)),
];

export const SpinWheelPromoIcon = forwardRef<
  SVGSVGElement,
  {
    goldId: string;
    hubId: string;
    className?: string;
  }
>(({ goldId, hubId, className = "" }, ref) => (
  <svg
    ref={ref}
    aria-hidden
    viewBox="0 0 72 72"
    className={`pointer-events-none absolute -bottom-[20px] -end-[22px] h-[80px] w-[80px] @[260px]:-bottom-[24px] @[260px]:-end-[29px] @[260px]:h-[96px] @[260px]:w-[96px] @[300px]:-bottom-[37.5px] @[300px]:-end-[45px] @[300px]:h-[150px] @[300px]:w-[150px] ${className}`}
  >
    <defs>
      <linearGradient id={goldId} x1="0" y1="0" x2="0.7" y2="1">
        <stop offset="0" stopColor="#FFE07A" />
        <stop offset="0.45" stopColor="#F5B726" />
        <stop offset="1" stopColor="#D98E12" />
      </linearGradient>
      <linearGradient id={hubId} x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stopColor="#FFD84D" />
        <stop offset="1" stopColor="#F0A81E" />
      </linearGradient>
    </defs>
    <g className="promoWheelSpin">
      {Array.from({ length: 12 }).map((_, i) => {
        const start = (i * 360) / 12;
        const end = ((i + 1) * 360) / 12;
        const [x0, y0] = promoPointOn(PROMO_R_SEGMENTS, start);
        const [x1, y1] = promoPointOn(PROMO_R_SEGMENTS, end);
        return (
          <path
            key={i}
            d={`M${PROMO_CX} ${PROMO_CY} L${x0} ${y0} A${PROMO_R_SEGMENTS} ${PROMO_R_SEGMENTS} 0 0 1 ${x1} ${y1} Z`}
            fill={PROMO_SEGMENT_HUES[i % PROMO_SEGMENT_HUES.length]}
          />
        );
      })}
    </g>
    <circle
      cx={PROMO_CX}
      cy={PROMO_CY}
      r={PROMO_R_RIM}
      fill="none"
      stroke={`url(#${goldId})`}
      strokeWidth={PROMO_RIM_W}
    />
    {Array.from({ length: 12 }).map((_, i) => {
      const [bx, by] = promoPointOn(PROMO_R_RIM, (i * 360) / 12 + 360 / 12 / 2);
      return <circle key={i} cx={bx} cy={by} r="1.5" fill="#FFF3C4" />;
    })}
    <circle cx={PROMO_CX} cy={PROMO_CY} r="12.5" fill="#FFF8E1" />
    <circle
      cx={PROMO_CX}
      cy={PROMO_CY}
      r="10.5"
      fill={`url(#${hubId})`}
      stroke="#C8860C"
      strokeWidth="1"
    />
    <text
      x={PROMO_CX}
      y={PROMO_CY + 2.6}
      textAnchor="middle"
      fontSize="7"
      fontWeight="900"
      letterSpacing="0.2"
      fill="#7A4A00"
    >
      SPIN
    </text>
    <g className="promoWheelPointer" transform={`rotate(-45 ${PROMO_CX} ${PROMO_CY})`}>
      <path
        d={`M${PROMO_CX} ${PROMO_CY - PROMO_R_RIM + 5} L${PROMO_CX + 6} ${PROMO_CY - PROMO_R_RIM - 5} L${PROMO_CX - 6} ${PROMO_CY - PROMO_R_RIM - 5} Z`}
        fill="#FFF3C4"
        stroke={`url(#${goldId})`}
        strokeWidth="2.5"
        strokeLinejoin="round"
      />
    </g>
  </svg>
));
SpinWheelPromoIcon.displayName = "SpinWheelPromoIcon";

// SVG container for animated pulse glyph paths.
export const PulseGlyphIcon = forwardRef<
  SVGGElement,
  { paths: string[]; className?: string }
>(({ paths, className = "" }, ref) => (
  <svg
    viewBox="0 0 24 24"
    xmlns="http://www.w3.org/2000/svg"
    className={className}
    aria-hidden="true"
  >
    <g ref={ref}>
      {paths.map((d) => (
        <path key={d} d={d} vectorEffect="non-scaling-stroke" />
      ))}
    </g>
  </svg>
));
PulseGlyphIcon.displayName = "PulseGlyphIcon";







