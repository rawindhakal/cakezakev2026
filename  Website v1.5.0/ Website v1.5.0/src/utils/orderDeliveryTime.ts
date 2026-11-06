// Parse delivery time strings ("N minutes", "N mins") into milliseconds.
export const parseDeliverTimeToMs = (
  raw?: string | null,
): number | null => {
  if (raw == null) return null;
  const match = String(raw).trim().match(/(\d+(?:\.\d+)?)/);
  if (!match) return null;
  const minutes = Number(match[1]);
  return Number.isFinite(minutes) ? minutes * 60 * 1000 : null;
};

// Calculate remaining delivery time in milliseconds based on creation timestamp.
export const getRemainingMs = (
  createdAtIso: string,
  totalMs: number,
  nowMs: number = Date.now(),
): number => {
  const createdMs = new Date(createdAtIso).getTime();
  if (!Number.isFinite(createdMs)) return 0;
  return Math.max(0, totalMs - (nowMs - createdMs));
};

export const formatMsAsClock = (ms: number): string => {
  const totalSeconds = Math.max(0, Math.round(ms / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
};

// Format milliseconds into human-readable minute strings.
export const formatMsAsMinutes = (ms: number): string => {
  const minutes = Math.max(0, Math.ceil(ms / 60000));
  if (minutes === 0) return "reaching you soon";
  return minutes === 1 ? "1 minute" : `${minutes} minutes`;
};

