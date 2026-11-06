import { t } from "@/utils/translation";

// Default fallback mobile number length bounds.
const FALLBACK_MIN = 4;
const FALLBACK_MAX = 15;

/** Extract min and max mobile number length bounds for a given country. */
export const getMobileLengthBounds = (
  country?: any,
): { min: number; max: number } => {
  const min = Number(country?.min_mobile_length);
  const max = Number(country?.max_mobile_length);
  return {
    min: Number.isFinite(min) && min > 0 ? min : FALLBACK_MIN,
    max: Number.isFinite(max) && max > 0 ? max : FALLBACK_MAX,
  };
};

// Helper to substitute template placeholders in translated strings.
const fill = (key: string, values: Record<string, number | string>): string =>
  Object.entries(values).reduce(
    (str, [k, v]) => str?.replace(`{${k}}`, String(v)),
    t(key),
  );

/** Validate digits-only mobile number length against country bounds. */
export const validateMobileLength = (
  rawPhone: string | number | null | undefined,
  country?: any,
): string | null => {
  const digits = String(rawPhone ?? "").replace(/\D/g, "");
  if (!digits) return null;

  const { min, max } = getMobileLengthBounds(country);

  if (digits.length < min) {
    // Handle exact vs range length error formatting.
    return min === max
      ? fill("mobile_exact_length_error", { min })
      : fill("mobile_range_length_error", { min, max });
  }
  if (digits.length > max) {
    return fill("mobile_max_length_error", { max });
  }
  return null;
};

/** True when the number is present AND within its country's bounds. */
export const isMobileLengthValid = (
  rawPhone: string | number | null | undefined,
  country?: any,
): boolean => {
  const digits = String(rawPhone ?? "").replace(/\D/g, "");
  if (!digits) return false;
  return !validateMobileLength(digits, country);
};

