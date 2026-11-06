/** Maintenance window timestamp and duration formatting helpers. */

/** Parse datetime string assuming UTC and return epoch milliseconds. */
export const parseUtc = (value: string | null | undefined): number | null => {
  if (!value || typeof value !== "string") return null;
  const m = value
    .trim()
    .match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?/);
  if (!m) {
    const fallback = Date.parse(value);
    return Number.isNaN(fallback) ? null : fallback;
  }
  const [, y, mo, d, h, mi, s] = m;
  return Date.UTC(+y, +mo - 1, +d, +h, +mi, +(s || 0));
};

/** Generate dismissal storage key for a scheduled maintenance window. */
export const windowKey = (
  startAt: string | number | null | undefined,
  endAt: string | number | null | undefined,
): string => `maintenance_notice_dismissed_${startAt || ""}_${endAt || ""}`;

/** Human duration for a span, e.g. "about 5 minutes" / "about 2 hours". */
export const formatDuration = (ms: number | null | undefined): string | null => {
  if (!ms || ms <= 0) return null;
  const mins = Math.round(ms / 60000);
  if (mins < 60) return `${mins} min`;
  const hours = Math.round(mins / 60);
  if (hours < 24) return `${hours} hr`;
  const days = Math.round(hours / 24);
  return `${days} day${days === 1 ? "" : "s"}`;
};

