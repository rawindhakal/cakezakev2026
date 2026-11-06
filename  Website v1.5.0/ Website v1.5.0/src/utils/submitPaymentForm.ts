// Gateways that accept a POST only (PayU's _payment endpoint) can't be opened
// with router.push. Build a throwaway form and submit it so the browser leaves
// the SPA with a real POST.
export type PaymentFormPayload = {
  method?: string;
  action?: string;
  fields?: Record<string, unknown> | null;
};

/**
 * Posts `payload.fields` to `payload.action`.
 *
 * Values are written exactly as the API sent them — the gateway's hash is
 * computed over those precise strings, so coercing "1364.81" to a number or
 * dropping an empty udf4 produces "invalid hash". Only `fields` is posted;
 * siblings like `gateway`/`mode` are informational.
 */
export const submitPaymentForm = (payload?: PaymentFormPayload | null): boolean => {
  if (typeof document === "undefined") return false;
  const action = payload?.action;
  const fields = payload?.fields;
  if (!action || !fields || typeof fields !== "object") return false;

  const form = document.createElement("form");
  form.method = (payload?.method || "POST").toUpperCase();
  form.action = action;
  form.style.display = "none";

  for (const [name, value] of Object.entries(fields)) {
    const input = document.createElement("input");
    input.type = "hidden";
    input.name = name;
    // null/undefined -> "" so an empty udf still posts, as the hash expects.
    input.value = value == null ? "" : String(value);
    form.appendChild(input);
  }

  document.body.appendChild(form);
  form.submit();
  return true;
};

export type PaymentRedirectData = {
  type?: string;
  url?: string;
};

/**
 * Hosted-checkout gateways (PayU's `type: "redirect"`) return a plain URL on
 * another origin. `router.push` can't leave the app, so do a real navigation.
 */
export const redirectToGateway = (data?: PaymentRedirectData | null): boolean => {
  if (typeof window === "undefined") return false;
  if (data?.type !== "redirect" || !data?.url) return false;
  window.location.assign(data.url);
  return true;
};
