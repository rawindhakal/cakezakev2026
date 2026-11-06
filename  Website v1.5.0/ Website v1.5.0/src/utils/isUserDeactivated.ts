// Pure predicate (no store/translation imports, avoids a circular import with
// axios). Backend reports a deactivated account as status:1 (success) with
// status_code "USER_DEACTIVATED", so callers must check this, not just `status`.
const normalize = (v?: unknown): string =>
  String(v || "")
    .trim()
    .toLowerCase()
    .replace(/[\s.]+/g, "_");

export const isUserDeactivated = (res?: unknown): boolean => {
  if (!res || typeof res !== "object") return false;
  const r = res as { status_code?: string; message?: string };
  const code = normalize(r?.status_code);
  const message = normalize(r?.message);
  return (
    code === "user_deactivated" ||
    /deactivated|de_activated/.test(message) // covers older key-style/human text
  );
};

// True when a fetched user object is deactivated (status 1 = active, 0 = deactivated).
export const isDeactivatedUser = (
  user?: { status?: number | string | null } | null,
): boolean => {
  if (!user) return false;
  const status = user?.status;
  if (status === undefined || status === null || status === "") return false;
  return Number(status) === 0;
};
