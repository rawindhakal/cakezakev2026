import { useSelector } from "react-redux";
import { store } from "@/redux/store";
import { t } from "@/utils/translation";

// Parse numeric value or return 0 for inactive limits.
const toNumber = (value: unknown): number => {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? n : 0;
};

const toFlag = (value: unknown): boolean => toNumber(value) > 0;

const DEFAULT_MIN = 6;

// Helper to read password rule from settings payload.
const readRule = (setting: any, key: string): unknown =>
  setting?.[key] ?? setting?.web_settings?.[key];

interface PasswordPolicy {
  min: number;
  max: number;
  requireUppercase: boolean;
  requireLowercase: boolean;
  requireNumber: boolean;
  requireSpecial: boolean;
}

// Normalize password policy options from settings payload.
const normalizePolicy = (setting: any): PasswordPolicy => ({
  min: toNumber(readRule(setting, "password_min_length")) || DEFAULT_MIN,
  max: toNumber(readRule(setting, "password_max_length")), // 0 = no maximum
  requireUppercase: toFlag(readRule(setting, "password_require_uppercase")),
  requireLowercase: toFlag(readRule(setting, "password_require_lowercase")),
  requireNumber: toFlag(readRule(setting, "password_require_number")),
  requireSpecial: toFlag(readRule(setting, "password_require_special")),
});

/** Imperative getter for current password policy from Redux store. */
export const getPasswordPolicy = (): PasswordPolicy =>
  normalizePolicy((store.getState() as any)?.Setting?.setting);

/** Reactive policy — re-renders the caller when the settings land. */
export const usePasswordPolicy = (): PasswordPolicy => {
  const setting = useSelector((state: any) => state.Setting?.setting);
  return normalizePolicy(setting);
};

// Helper to substitute template placeholders in translated strings.
const fill = (key: string, values: Record<string, number | string>): string =>
  Object.entries(values).reduce(
    (str, [k, v]) => str?.replace(`{${k}}`, String(v)),
    t(key),
  );

/** Evaluate password against active policy rules and return checklist items. */
interface PasswordRule {
  key: string;
  label: string;
  passed: boolean;
}

export const getPasswordRules = (
  password: string | null | undefined = "",
  policyArg: PasswordPolicy | null = null,
): PasswordRule[] => {
  const policy = policyArg ?? getPasswordPolicy();
  const value = String(password ?? "");
  const rules: PasswordRule[] = [];

  rules.push({
    key: "min",
    label:
      policy.max > 0
        ? fill("password_rule_length_range", {
            min: policy.min,
            max: policy.max,
          })
        : fill("password_rule_min_length", { min: policy.min }),
    // Range check covering both minimum and maximum length bounds.
    passed:
      value.length >= policy.min &&
      (policy.max === 0 || value.length <= policy.max),
  });

  if (policy.requireUppercase) {
    rules.push({
      key: "uppercase",
      label: t("password_rule_uppercase"),
      passed: /[A-Z]/.test(value),
    });
  }
  if (policy.requireLowercase) {
    rules.push({
      key: "lowercase",
      label: t("password_rule_lowercase"),
      passed: /[a-z]/.test(value),
    });
  }
  if (policy.requireNumber) {
    rules.push({
      key: "number",
      label: t("password_rule_number"),
      passed: /\d/.test(value),
    });
  }
  if (policy.requireSpecial) {
    rules.push({
      key: "special",
      label: t("password_rule_special"),
      // Special character matching non-alphanumeric and non-whitespace.
      passed: /[^A-Za-z0-9\s]/.test(value),
    });
  }

  return rules;
};

/** Validate password against policy and return first error message or null. */
export const validatePassword = (
  password: string | null | undefined,
  policy: PasswordPolicy | null = null,
): string | null => {
  if (!password) return null;
  const failed = getPasswordRules(password, policy).find((rule) => !rule.passed);
  return failed ? failed.label : null;
};

/** True when the password is present AND satisfies every active rule. */
export const isPasswordValid = (
  password: string | null | undefined,
  policy: PasswordPolicy | null = null,
): boolean => !!password && !validatePassword(password, policy);

/** Reactive password rules hook for component usage. */
export const usePasswordRules = (password: string | null | undefined = ""): PasswordRule[] =>
  getPasswordRules(password, usePasswordPolicy());

export const useValidatePassword = (password: string | null | undefined): string | null =>
  validatePassword(password, usePasswordPolicy());

