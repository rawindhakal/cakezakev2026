"use client";

import { useEffect } from "react";
import { useDispatch, useSelector } from "react-redux";
import { toast } from "react-toastify";
import * as api from "@/api/apiRoutes";
import { t } from "@/utils/translation";
import {
  setCartPromo,
  setPendingPromoCode,
  setPromoAutoApplyError,
} from "@/redux/slices/cartSlice";

// Module lock to prevent concurrent coupon validations.
let inFlight = false;

interface Options {
  /** Cart view is visible / usable right now. */
  active: boolean;
  hasItems: boolean;
  subTotal: number;
}

// Auto-applies pending promo code once cart has items.
const usePendingCouponAutoApply = ({ active, hasItems, subTotal }: Options) => {
  const dispatch = useDispatch();
  const pending = useSelector((s: any) => s.Cart?.pendingPromoCode as string | null);
  const applied = useSelector((s: any) => s.Cart?.promo_code);
  const city = useSelector((s: any) => s.City?.city);

  useEffect(() => {
    if (!active || !pending || !hasItems || !(subTotal > 0) || inFlight) return;

    if (
      String(applied?.promo_code || "").toUpperCase() === pending.toUpperCase()
    ) {
      dispatch(setPendingPromoCode(null));
      return;
    }

    const code = pending;
    const fail = (message?: string) => {
      const reason = message || t("invalid_coupon_code") || "Invalid coupon code";
      dispatch(setPromoAutoApplyError({ code, reason }));
      toast.error(
        `${t("coupon_not_applied") || "Coupon not applied"} (${code}): ${reason}`,
      );
    };

    inFlight = true;
    (async () => {
      try {
        const res = await api.setPromoCode({
          promoCodeName: pending,
          amount: subTotal,
          latitude: city?.latitude,
          longitude: city?.longitude,
        });
        if (res?.status == 1) {
          dispatch(setCartPromo({ data: res.data }));
          toast.success(t("coupon_applied") || "Coupon Applied");
        } else {
          fail(res?.message);
        }
      } catch (e: any) {
        fail(e?.response?.data?.message);
      } finally {
        dispatch(setPendingPromoCode(null));
        inFlight = false;
      }
    })();
  }, [active, pending, hasItems, subTotal, applied, city?.latitude, city?.longitude, dispatch]);
};

export default usePendingCouponAutoApply;
