// Sanitize payment gateway configuration to exclude secret credentials.

// Per-gateway enable flags ("1" = merchant enabled this method).
const PAYMENT_METHOD_FLAGS = [
  "razorpay_payment_method",
  "paypal_payment_method",
  "paystack_payment_method",
  "stripe_payment_method",
  "cashfree_payment_method",
  "midtrans_payment_method",
  "phonepay_payment_method",
  "paytabs_payment_method",
  "payu_payment_method",
];

// Client-safe public gateway keys and credentials.
const PUBLIC_FIELDS = [
  "razorpay_key",
  "stripe_publishable_key",
  "paystack_public_key",
  "paystack_currency_code",
];

const ALLOWED_KEYS = [...PAYMENT_METHOD_FLAGS, ...PUBLIC_FIELDS];

/** Strip payment settings payload down to client-safe public fields. */
export const sanitizePaymentSetting = (
  raw: Record<string, any> | null | undefined,
): Record<string, any> | null => {
  if (!raw || typeof raw !== "object") return null;
  const safe: Record<string, any> = {};
  for (const key of ALLOWED_KEYS) {
    if (raw[key] !== undefined) safe[key] = raw[key];
  }
  return safe;
};

export { ALLOWED_KEYS as PAYMENT_SETTING_ALLOWED_KEYS };

