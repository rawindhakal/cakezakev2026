import { isZoneCandidate } from "@/utils/reservedRoutes";
import { ZONE_PREFIXABLE_ROUTES } from "@/utils/zonePrefixable";

// Helpers for parsing and constructing zone-prefixed URLs.

/** Parse pathname into zone slug (if present) and remaining path segments. */
export interface ZonePath {
  zone: string | null;
  rest: string[];
}

export const parseZonePath = (pathname = ""): ZonePath => {
  const segments = pathname.split("/").filter(Boolean);
  if (segments.length >= 1 && isZoneCandidate(segments[0])) {
    return { zone: segments[0], rest: segments.slice(1) };
  }
  return { zone: null, rest: segments };
};

/** Build zone-prefixed URL from pathname and target zone slug. */
export const buildZoneUrl = (
  pathname = "",
  zoneSlug: string | null | undefined,
): string | null => {
  if (!zoneSlug) return null;
  const { rest } = parseZonePath(pathname);
  return buildZonePath(rest, zoneSlug);
};

/** Prefix path segments with target zone slug for zone-compatible routes. */
export const buildZonePath = (
  rest: string[] = [],
  zoneSlug: string | null | undefined,
): string | null => {
  if (!zoneSlug) return null;
  // Bare home (or a bare zone URL) -> that zone's home.
  if (!rest.length) return `/${zoneSlug}`;
  if (!ZONE_PREFIXABLE_ROUTES.has(rest[0])) return null;
  return `/${zoneSlug}/${rest.join("/")}`;
};

