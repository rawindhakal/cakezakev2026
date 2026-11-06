interface TimeIconProps {
  size?: number;
  className?: string;
}

/**
 * Delivery-ETA stopwatch. The dial and crown come from time_icon.svg and take
 * the surrounding text colour; the wedge is redrawn here in the primary colour
 * fills clockwise from 12 o'clock, then drains the same way, looping from and
 * back to the artwork's own three-quarter wedge.
 */
const TimeIcon = ({ size = 9, className = "" }: TimeIconProps) => (
  <svg
    aria-hidden="true"
    focusable="false"
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    className={`inline-block shrink-0 ${className}`}
  >
    <path
      d="M12 4C10.0222 4 8.08879 4.58649 6.4443 5.6853C4.79981 6.78412 3.51809 8.3459 2.76121 10.1732C2.00433 12.0004 1.8063 14.0111 2.19215 15.9509C2.578 17.8907 3.53041 19.6725 4.92894 21.0711C6.32746 22.4696 8.10929 23.422 10.0491 23.8078C11.9889 24.1937 13.9996 23.9957 15.8268 23.2388C17.6541 22.4819 19.2159 21.2002 20.3147 19.5557C21.4135 17.9112 22 15.9778 22 14C21.9969 11.3488 20.9423 8.80707 19.0676 6.93239C17.1929 5.0577 14.6512 4.00313 12 4ZM12 22.1818C10.3818 22.1818 8.79992 21.702 7.45443 20.8029C6.10894 19.9039 5.06025 18.6261 4.44099 17.131C3.82173 15.636 3.6597 13.9909 3.9754 12.4038C4.29109 10.8167 5.07034 9.35883 6.21458 8.21458C7.35883 7.07033 8.81669 6.29109 10.4038 5.97539C11.9909 5.6597 13.636 5.82172 15.131 6.44099C16.6261 7.06025 17.9039 8.10893 18.8029 9.45442C19.702 10.7999 20.1818 12.3818 20.1818 14C20.1794 16.1692 19.3166 18.2489 17.7828 19.7828C16.2489 21.3166 14.1692 22.1794 12 22.1818Z"
      fill="currentColor"
    />
    <rect x="8" y="1" width="8" height="2" rx="1" fill="currentColor" />
    {/* r 3.5 with a 7 wide stroke paints a solid r-7 pie; pathLength 100 lets
        the keyframes state the wedge's sweep as a percentage. */}
    <circle
      cx="12"
      cy="14"
      r="3.5"
      fill="none"
      stroke="var(--primary-color)"
      strokeWidth="7"
      pathLength={100}
      strokeDasharray="75 100"
      className="clockWedgeSweep"
    />
  </svg>
);

export default TimeIcon;
