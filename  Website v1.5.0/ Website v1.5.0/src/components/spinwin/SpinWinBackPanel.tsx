"use client";

/**
 * Brand-colored card panel mounted behind the SpinWin wheel and stand.
 */
interface SpinWinBackPanelProps {
  /** Round all corners if true; defaults to top corners only. */
  roundedAll?: boolean;
  /** Inset distance from the bottom of the column. */
  bottom?: string;
  /** Panel width as a CSS length/percentage. */
  width?: string;
  /** Corner radius in pixels. */
  radius?: number;
}

const SpinWinBackPanel = ({
  roundedAll = false,
  bottom = "4%",
  width = "100%",
  radius = 28,
}: SpinWinBackPanelProps) => (
  <div
    aria-hidden
    className="pointer-events-none absolute left-1/2 top-[-1px] z-0 -translate-x-1/2"
    style={{
      width,
      bottom,
      borderRadius: roundedAll
        ? `${radius}px`
        : `${radius}px ${radius}px 0 0`,
      background:
        "linear-gradient(180deg, color-mix(in srgb, var(--primary-color) 42%, #0A0A0A) 0%, color-mix(in srgb, var(--primary-color) 47%, #0A0A0A) 25%, color-mix(in srgb, var(--primary-color) 53%, #0A0A0A) 50%, color-mix(in srgb, var(--primary-color) 90%, #0A0A0A) 85%, var(--primary-color) 100%)",
      border: "1px solid color-mix(in srgb, var(--primary-color) 32%, #fff)",
      borderBottomWidth: roundedAll ? "1px" : "0",
      boxShadow:
        "0 4px 12px color-mix(in srgb, color-mix(in srgb, var(--primary-color) 22%, #0A0A0A) 28%, transparent), 0 18px 48px color-mix(in srgb, color-mix(in srgb, var(--primary-color) 22%, #0A0A0A) 35%, transparent)",
    }}
  />
);

export default SpinWinBackPanel;
