import React, { useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { toast } from "react-toastify";
import * as api from "@/api/apiRoutes";
import { setCartPromo } from "@/redux/slices/cartSlice";
import { t } from "@/utils/translation";
import CouponCodeCard from "./CouponCodeCard";
import NoCouponFound from "@/assets/empty-state/no-coupon.svg";
import ThemedSvg from "@/components/notfound/ThemedSvg";

interface CouponListProps {
  coupons: any[];
  loading?: boolean;
  /** Called after a coupon applies (closes the list/drawer). */
  onApplied: () => void;
}

const SectionTitle = ({ children }: { children: React.ReactNode }) => (
  <h4 className="px-1 pb-2 pt-5 text-[11px] font-bold uppercase tracking-wider SecondaryTextColor">
    {children}
  </h4>
);

// Ticket cards spaced apart so borders and rounded corners read cleanly.
const CouponStack = ({
  coupons,
  onApplied,
}: {
  coupons: any[];
  onApplied: () => void;
}) => (
  <div className="flex flex-col gap-3">
    {coupons.map((coupon) => (
      <div
        key={coupon?.id}
        className="rounded-xl bg-white dark:bg-zinc-900"
      >
        <CouponCodeCard coupon={coupon} setShowCouponCode={() => onApplied()} />
      </div>
    ))}
  </div>
);

// Myntra-style coupon picker: code input + CHECK, then Available / Unlock
// sections of checkbox rows. Shared by the cart drawer and cart page drawer.
const CouponList = ({ coupons, loading = false, onApplied }: CouponListProps) => {
  const dispatch = useDispatch();
  const cart = useSelector((state: any) => state.Cart);
  const city = useSelector((state: any) => state.City?.city);
  const [code, setCode] = useState("");
  const [checking, setChecking] = useState(false);
  const [error, setError] = useState("");

  const available = (coupons || []).filter((c) => c?.is_applicable != 0);
  const locked = (coupons || []).filter((c) => c?.is_applicable == 0);

  const handleCheck = async () => {
    const value = code.trim();
    if (!value || checking) return;
    setChecking(true);
    setError("");
    try {
      const response = await api.setPromoCode({
        promoCodeName: value,
        amount: cart?.cartSubTotal,
        latitude: city?.latitude,
        longitude: city?.longitude,
      });
      if (response.status == 1) {
        dispatch(setCartPromo({ data: response.data }));
        toast.success(response.message);
        setCode("");
        onApplied();
      } else {
        setError(response.message || t("invalid_coupon_code"));
      }
    } catch (err) {
      console.log("Error", err);
      setError(t("something_went_wrong"));
    } finally {
      setChecking(false);
    }
  };

  return (
    <div className="min-h-full">
      <div className="px-3 pt-3">
        <div
          className={`flex h-12 items-center rounded-xl border bg-white transition-colors dark:bg-zinc-900 ${
            error
              ? "border-red-400"
              : "border-gray-300 focus-within:border-gray-500 dark:border-zinc-700"
          }`}
        >
          <input
            type="text"
            value={code}
            onChange={(e) => {
              setCode(e.target.value.toUpperCase());
              if (error) setError("");
            }}
            onKeyDown={(e) => e.key === "Enter" && handleCheck()}
            placeholder={t("enter_coupon_code") || "Enter coupon code"}
            className="h-full min-w-0 flex-1 bg-transparent px-4 text-sm font-semibold uppercase tracking-wide outline-none placeholder:font-normal placeholder:normal-case placeholder:tracking-normal placeholder:SecondaryTextColor textColor"
          />
          <button
            type="button"
            onClick={handleCheck}
            disabled={!code.trim() || checking}
            className="h-full shrink-0 px-4 text-sm font-bold uppercase tracking-wider primaryColor transition-opacity disabled:opacity-40"
          >
            {checking ? "..." : t("check") || "Check"}
          </button>
        </div>
        {error && <p className="mt-1.5 px-1 text-xs text-red-500">{error}</p>}
      </div>

      {loading ? (
        <div className="flex flex-col gap-3 px-3 pt-5">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="space-y-3 rounded-xl border border-gray-200 p-3 dark:border-zinc-800">
              <div className="flex gap-3">
                <span className="h-12 w-12 animate-pulse rounded-lg bg-gray-200 dark:bg-zinc-800" />
                <div className="flex-1 space-y-2 pt-1">
                  <span className="block h-3.5 w-36 animate-pulse rounded bg-gray-200 dark:bg-zinc-800" />
                  <span className="block h-3 w-24 animate-pulse rounded bg-gray-200 dark:bg-zinc-800" />
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="h-7 w-28 animate-pulse rounded-md bg-gray-200 dark:bg-zinc-800" />
                <span className="h-8 w-20 animate-pulse rounded-md bg-gray-200 dark:bg-zinc-800" />
              </div>
            </div>
          ))}
        </div>
      ) : (coupons || []).length === 0 ? (
        <div className="flex flex-col items-center gap-3 px-6 py-12 text-center">
          <ThemedSvg src={NoCouponFound} alt="" className="h-40 w-40" />
          <p className="text-base font-bold">{t("no_coupon_code_available")}</p>
        </div>
      ) : (
        <div className="px-3 pb-5">
          {available.length > 0 && (
            <section>
              <SectionTitle>{t("available_coupons") || "Available Coupons"}</SectionTitle>
              <CouponStack coupons={available} onApplied={onApplied} />
            </section>
          )}
          {locked.length > 0 && (
            <section>
              <SectionTitle>{t("unlock_coupons") || "Unlock Coupons"}</SectionTitle>
              <CouponStack coupons={locked} onApplied={onApplied} />
            </section>
          )}
        </div>
      )}
    </div>
  );
};

export default CouponList;
