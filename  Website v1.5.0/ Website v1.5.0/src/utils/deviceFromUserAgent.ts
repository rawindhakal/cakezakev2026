// Server-side device bucket for home_layout: client uses innerWidth, SSR has no
// viewport so it reads User-Agent instead. A mismatch just triggers a client refetch.
export const deviceFromUserAgent = (
  userAgent?: string | null,
): "web" | "tablet" | "app" => {
  const ua = String(userAgent || "");
  if (!ua) return "web";
  // Order matters: iPad/Android tablets also match the mobile patterns below.
  if (/iPad|Tablet|PlayBook|Silk|(Android(?!.*Mobile))/i.test(ua)) return "tablet";
  if (/Mobile|iPhone|iPod|Android|BlackBerry|Opera Mini|IEMobile/i.test(ua)) {
    return "app";
  }
  return "web";
};
