"use client";

import React, { useEffect, useRef, useState } from "react";
import { useSelector } from "react-redux";
import { FiAlertCircle, FiInfo, FiMapPin, FiXCircle } from "react-icons/fi";
import { FaTruckFast } from "react-icons/fa6";
import * as api from "@/api/apiRoutes";
import { t } from "@/utils/translation";

// Remembered across PDPs so the shopper types it once (per-browser convenience).
const STORAGE_KEY = "pdp_pincode";
const PINCODE_RE = /^[A-Za-z0-9 -]{3,16}$/;

/** Result of check_serviceability that blocks buying; null = not blocked. */
export type PincodeBlock = { message: string } | null;

interface PincodeCheckProps {
  productVariantId?: number | string;
  quantity?: number;
  /** Fired with the blocking state after each check (null when buyable). */
  onBlockChange?: (block: PincodeBlock) => void;
  /** Product-level ETA, shown until a pincode check returns its own. */
  fallbackEta?: string;
}

// Accepts "DD-MM-YYYY, Day" (product API) or any Date-parsable text; returns "Fri, Oct 9".
const formatEtaDate = (raw: string) => {
  const dmy = raw.match(/^(\d{1,2})-(\d{1,2})-(\d{4})/);
  const date = dmy ? new Date(+dmy[3], +dmy[2] - 1, +dmy[1]) : new Date(raw);
  if (Number.isNaN(date.getTime())) return raw;
  return date.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" });
};

// Single delivery-ETA row shared by the pincode result and the product fallback date.
export const EtaLine = ({
  date,
  days,
  inset = false,
}: {
  date?: string;
  days?: number;
  /** Indent to line up with the pincode row's icon. */
  inset?: boolean;
}) => {
  if (!date && days == null) return null;
  return (
    <p
      className={`flex items-center gap-2 text-sm text-gray-700 dark:text-zinc-300 motion-safe:animate-etaIn ${inset ? "px-3" : ""}`}
    >
      <span className="flex shrink-0 motion-safe:animate-truckIn rtl:motion-safe:animate-truckInRtl">
        <FaTruckFast size={16} className="primaryColor rtl:-scale-x-100" />
      </span>
      <span dir="auto">
        {date ? t("delivery_by") || "Delivery by" : t("delivery_in") || "Delivery in"}{" "}
        <span className="font-bold text-gray-900 dark:text-zinc-100">
          {date ? formatEtaDate(date) : `${days} ${t("days") || "days"}`}
        </span>
      </span>
    </p>
  );
};

const readSaved = () => {
  try {
    return localStorage.getItem(STORAGE_KEY) || "";
  } catch {
    return "";
  }
};

// Delivery check for one variant. Only mounted when product_by_id said
// pincode_check_available == 1 — never decided locally. Renders the four
// API outcomes: neutral (not checked), deliverable (ETA + charge), soft
// warning (courier can't, shop still can), blocked (courier-only zone).
const PincodeCheck = ({
  productVariantId,
  quantity = 1,
  onBlockChange,
  fallbackEta,
}: PincodeCheckProps) => {
  const city = useSelector((state: any) => state.City?.city);

  const [pincode, setPincode] = useState("");
  const [editing, setEditing] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  // check_serviceability data — untyped API payload.
  const [result, setResult] = useState<any>(null);
  const checkedPinRef = useRef("");
  const formRef = useRef<HTMLFormElement>(null);

  const showError = (message: string) => {
    setError(message);
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    formRef.current?.animate(
      [0, -6, 6, -4, 4, 0].map((x) => ({ transform: `translateX(${x}px)` })),
      { duration: 350, easing: "ease-in-out" },
    );
  };

  const runCheck = async (pin: string) => {
    const value = pin.trim();
    if (!PINCODE_RE.test(value)) {
      showError(t("invalid_pincode") || "Please enter a valid pincode");
      return;
    }
    setError("");
    setLoading(true);
    try {
      const res = await api.checkServiceability({
        pincode: value,
        latitude: city?.latitude,
        longitude: city?.longitude,
        productVariantId,
        quantity,
        cod: true,
      });
      if (res?.status == 1 && res?.data) {
        setResult(res.data);
        setEditing(false);
        checkedPinRef.current = value;
        try {
          localStorage.setItem(STORAGE_KEY, value);
        } catch {}
        onBlockChange?.(
          res.data.serviceable === false
            ? { message: res.data.message || "" }
            : null,
        );
      } else {
        showError(res?.message || t("something_went_wrong"));
      }
    } catch (err) {
      console.log("Error", err);
      showError(t("something_went_wrong"));
    } finally {
      setLoading(false);
    }
  };

  // Saved pincode → check on mount; re-check when the variant/qty changes
  // since the store, weight and charge depend on them.
  useEffect(() => {
    const pin = checkedPinRef.current || readSaved();
    if (!pin) return;
    setPincode(pin);
    runCheck(pin);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [productVariantId, quantity, city?.latitude, city?.longitude]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    runCheck(pincode);
  };

  const handleChange = () => {
    setEditing(true);
    setResult(null);
    onBlockChange?.(null);
  };

  const renderResult = () => {
    if (!result) return <EtaLine inset date={fallbackEta} />;
    const { checked, serviceable, courier_serviceable, message } = result;

    if (!checked) {
      return (
        <>
          <p className="flex items-start gap-2 px-3 text-xs text-gray-600 dark:text-zinc-300">
            <FiInfo size={15} className="mt-px shrink-0" />
            <span dir="auto">{message}</span>
          </p>
          <EtaLine inset date={fallbackEta} />
        </>
      );
    }

    if (courier_serviceable) {
      return result.eta_text || result.eta_days != null ? (
        <EtaLine inset date={result.eta_text} days={result.eta_days} />
      ) : (
        <EtaLine inset date={fallbackEta} />
      );
    }

    if (serviceable) {
      return (
        <p className="flex items-start gap-2 rounded-lg bg-amber-50 dark:bg-amber-500/10 px-3 py-2 text-xs text-amber-800 dark:text-amber-300">
          <FiAlertCircle size={15} className="mt-px shrink-0" />
          <span dir="auto">
            {t("we_will_arrange_delivery") || "Delivery is not available at this pincode."}
          </span>
        </p>
      );
    }

    return (
      <p className="flex items-start gap-2 rounded-lg bg-red-50 dark:bg-red-500/10 px-3 py-2 text-xs font-medium text-red-700 dark:text-red-400">
        <FiXCircle size={15} className="mt-px shrink-0" />
        <span dir="auto">{message}</span>
      </p>
    );
  };

  return (
    <div className="flex flex-col gap-2.5">
      {editing ? (
        <form
          ref={formRef}
          onSubmit={handleSubmit}
          className={`flex h-10 items-center gap-2 rounded-lg border px-3 transition focus-within:border-[var(--primary-color)] motion-safe:animate-fadeSwap ${
            error
              ? "border-red-400"
              : "border-gray-200 dark:border-zinc-700"
          }`}
        >
          <FiMapPin size={16} className="shrink-0 text-gray-400" />
          <input
            type="text"
            inputMode="text"
            maxLength={16}
            value={pincode}
            onChange={(e) => {
              setPincode(e.target.value);
              if (error) setError("");
            }}
            placeholder={t("enter_pincode") || "Enter Pincode"}
            aria-label={t("enter_pincode") || "Enter Pincode"}
            className="min-w-0 flex-1 bg-transparent text-sm text-gray-900 dark:text-zinc-100 outline-none placeholder:text-gray-400"
          />
          <button
            type="submit"
            disabled={loading || !pincode.trim()}
            className="shrink-0 text-sm font-bold primaryColor dark:text-white transition hover:opacity-80 disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {loading ? "..." : t("check") || "Check"}
          </button>
        </form>
      ) : (
        <div className="flex h-10 items-center justify-between gap-2 rounded-lg bg-gray-50 dark:bg-zinc-800 px-3 motion-safe:animate-fadeSwap">
          <span className="flex min-w-0 items-center gap-2 text-sm text-gray-700 dark:text-zinc-200">
            <FiMapPin size={16} className="shrink-0 primaryColor dark:text-white" />
            <span className="truncate">
              {t("deliver_to") || "Deliver to"}{" "}
              <span className="font-bold text-gray-900 dark:text-zinc-100">
                {result?.pincode || pincode}
              </span>
            </span>
          </span>
          <button
            type="button"
            onClick={handleChange}
            className="shrink-0 text-sm font-bold primaryColor dark:text-white transition hover:opacity-80"
          >
            {t("change") || "Change"}
          </button>
        </div>
      )}

      {error && <p className="px-3 text-xs text-red-600 dark:text-red-400">{error}</p>}
      {loading && !editing ? null : renderResult()}
    </div>
  );
};

export default PincodeCheck;
