/**
 * PayU SDK integration (Bolt on Web).
 *
 * Supports launching PayU Bolt modal when `payload.sdk` is returned from
 * customer/initiate_transaction. If Bolt cannot be loaded or fails to launch,
 * gracefully falls back to the form-based POST flow (`submitPaymentForm`).
 */

export interface PayUSdkData {
  merchant_key: string;
  txnid: string;
  amount: string;
  product_info: string;
  first_name: string;
  email: string;
  phone: string;
  surl: string;
  furl: string;
  udf?: Record<string, string>;
  is_production?: boolean;
  environment?: number;
  user_credentials?: string;
  hashes?: {
    payment?: string;
    vas_for_mobile_sdk?: string;
    payment_related_details_for_mobile_sdk?: string;
    get_user_cards?: string;
    save_user_card?: string;
    edit_user_card?: string;
    delete_user_card?: string;
    [key: string]: string | undefined;
  };
  hash?: string;
  [key: string]: any;
}

export interface PayUPayload {
  sdk?: PayUSdkData;
  method?: string;
  action?: string;
  fields?: Record<string, unknown> | null;
  gateway?: string;
  mode?: string;
  [key: string]: any;
}

export interface LaunchPayuOptions {
  payload?: PayUPayload | null;
  onSuccess?: (res?: any) => void;
  onFailure?: (res?: any, reason?: string) => void;
  onFallback?: () => void;
}

/**
 * Loads the PayU Bolt JavaScript SDK script dynamically.
 * Production: https://jssdk.payu.in/bolt/bolt.min.js
 * Sandbox / UAT: https://jssdk-uat.payu.in/bolt/bolt.min.js
 */
export const loadPayUBoltScript = (isProduction = false): Promise<boolean> => {
  if (typeof window === "undefined") return Promise.resolve(false);
  if (typeof (window as any).bolt?.launch === "function") return Promise.resolve(true);

  return new Promise((resolve) => {
    const scriptId = "payu-bolt-script";
    const src = isProduction
      ? "https://jssdk.payu.in/bolt/bolt.min.js"
      : "https://jssdk-uat.payu.in/bolt/bolt.min.js";

    const existing = document.getElementById(scriptId) as HTMLScriptElement | null;
    if (existing) {
      if (existing.src === src && typeof (window as any).bolt?.launch === "function") {
        return resolve(true);
      }
      existing.remove();
    }

    const script = document.createElement("script");
    script.id = scriptId;
    script.src = src;
    script.async = true;

    const checkBoltReady = () => {
      if (typeof (window as any).bolt?.launch === "function") {
        resolve(true);
      } else {
        let attempts = 0;
        const interval = setInterval(() => {
          attempts++;
          if (typeof (window as any).bolt?.launch === "function") {
            clearInterval(interval);
            resolve(true);
          } else if (attempts >= 10) {
            clearInterval(interval);
            resolve(false);
          }
        }, 50);
      }
    };

    script.onload = () => checkBoltReady();
    script.onerror = (err) => {
      console.error("[PayU SDK] Failed to load Bolt script from", src, err);
      resolve(false);
    };

    document.body.appendChild(script);
  });
};

/**
 * Launches PayU checkout via Bolt SDK.
 *
 * Parameters passed to `bolt.launch` match the official PayU Web SDK specification:
 * key, txnid, amount, productinfo, firstname, email, phone, surl, furl, hash, udf1..udf5.
 *
 * Returns true if the SDK modal was opened, or false if it couldn't be launched (triggering fallback).
 */
export const launchPayuSdk = async (options: LaunchPayuOptions): Promise<boolean> => {
  const { payload, onSuccess, onFailure, onFallback } = options;
  const sdk = payload?.sdk;
  if (!sdk || typeof window === "undefined") {
    onFallback?.();
    return false;
  }

  const isProduction = Boolean(
    sdk.is_production === true ||
      sdk.environment === 0 ||
      payload?.mode === "production" ||
      payload?.mode === "live"
  );

  const loaded = await loadPayUBoltScript(isProduction);
  const bolt = (window as any).bolt;

  if (!loaded || !bolt || typeof bolt.launch !== "function") {
    console.warn("[PayU SDK] Bolt SDK not available, falling back to form submit");
    onFallback?.();
    return false;
  }

  const boltData: Record<string, any> = {
    key: sdk.merchant_key,
    txnid: sdk.txnid,
    amount: sdk.amount,
    productinfo: sdk.product_info || sdk.productinfo || "",
    firstname: sdk.first_name || sdk.firstname || "",
    email: sdk.email || "",
    phone: sdk.phone || "",
    surl: sdk.surl,
    furl: sdk.furl,
    hash: sdk.hashes?.payment || sdk.hash || "",
    udf1: sdk.udf?.udf1 ?? "",
  };

  if (sdk.udf && typeof sdk.udf === "object") {
    if (sdk.udf.udf2 != null && sdk.udf.udf2 !== "") boltData.udf2 = sdk.udf.udf2;
    if (sdk.udf.udf3 != null && sdk.udf.udf3 !== "") boltData.udf3 = sdk.udf.udf3;
    if (sdk.udf.udf4 != null && sdk.udf.udf4 !== "") boltData.udf4 = sdk.udf.udf4;
    if (sdk.udf.udf5 != null && sdk.udf.udf5 !== "") boltData.udf5 = sdk.udf.udf5;
  }

  try {
    bolt.launch(boltData, {
      responseHandler: (BOLT: any) => {
        const txnStatus =
          BOLT?.response?.txnStatus ||
          BOLT?.txnStatus ||
          BOLT?.status ||
          "";
        const normalized = String(txnStatus).toUpperCase();
        if (normalized === "SUCCESS") {
          onSuccess?.(BOLT);
        } else {
          onFailure?.(BOLT, String(txnStatus).toLowerCase() || "failed");
        }
      },
      catchException: (BOLT: any) => {
        console.error("[PayU SDK] catchException:", BOLT);
        onFailure?.(BOLT, "exception");
      },
    });
    return true;
  } catch (error) {
    console.error("[PayU SDK] Failed to launch Bolt:", error);
    onFallback?.();
    return false;
  }
};
