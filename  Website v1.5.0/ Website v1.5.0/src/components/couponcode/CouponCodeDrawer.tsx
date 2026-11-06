import React, { useState, useEffect, useCallback } from "react";
import * as api from "@/api/apiRoutes";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { RiCloseFill } from "react-icons/ri";
import { t } from "@/utils/translation";
import CouponList from "./CouponList";
import { useSelector } from "react-redux";
import useDir from "@/hooks/useDir";

interface CouponCodeDrawerProps {
  showCouponCode: boolean;
  setShowCouponCode: (show: boolean) => void;
}

const CouponCodeDrawer = ({ showCouponCode, setShowCouponCode }: CouponCodeDrawerProps) => {
  const cart = useSelector((state: any) => state.Cart);
  const city = useSelector((state: any) => state.City);
  const checkout = useSelector((state: any) => state.Checkout);
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  const dir = useDir();
  // Promo code rows come from the untyped /promo API response — kept `any[]`.
  const [couponCodes, setCouponCodes] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);

  const handleFetchCouponCodes = useCallback(async () => {
    setLoading(true);
    try {
      const response = await api.getPromo({
        amount: cart?.cartSubTotal,
        latitude: city?.city?.latitude,
        longitude: city?.city?.longitude,
      });
      setCouponCodes(response?.data || []);
    } catch (error) {
      console.log("Error", error);
    } finally {
      setLoading(false);
    }
  }, [cart, city]);

  useEffect(() => {
    if (showCouponCode) {
      // intentional: fetches coupon codes when the drawer opens; the fetch's
      // own setCouponCodes lands async, but the call itself must fire here.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      handleFetchCouponCodes();
    }
  }, [showCouponCode, handleFetchCouponCodes]);

  const handleHideCouponCode = () => {
    setShowCouponCode(false);
  };
  return (
    <Sheet open={showCouponCode} modal={false}>
      <SheetContent
        className="flex h-screen w-full flex-col p-0 sm:!max-w-md lg:!max-w-lg"
        side={dir === "RTL" ? "left" : "right"}
        dir={dir}
      >
        <SheetHeader className="border-b px-0 py-3 text-left">
          <SheetTitle className="flex flex-row items-center justify-between p-2 text-2xl font-bold">
            <p className="text-2xl font-bold">{t("coupons")}</p>
            <div className="closeButtonBg rounded-full p-[8px]">
              <RiCloseFill
                className="hover:cursor-pointer"
                size={22}
                onClick={() => handleHideCouponCode()}
              />
            </div>
          </SheetTitle>
        </SheetHeader>
        <div className="flex-grow overflow-y-auto">
          <CouponList
            coupons={couponCodes}
            loading={loading}
            onApplied={() => setShowCouponCode(false)}
          />
        </div>
      </SheetContent>
    </Sheet>
  );
};

export default CouponCodeDrawer;
