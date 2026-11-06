"use client";
import React, { useEffect, useState } from "react";
import Image from "next/image";
import { usePathname, useRouter } from "next/navigation";
import { useSelector } from "react-redux";
import { IoCartOutline, IoChevronForward } from "react-icons/io5";
import { t } from "@/utils/translation";
import useZoneHref from "@/hooks/useZoneHref";
import useIsHydrated from "@/hooks/useIsHydrated";

const sumQty = (list: any[]) =>
  Array.isArray(list) ? list.reduce((n, p) => n + (Number(p?.qty) || 0), 0) : 0;

// Routes where floating cart pill should hide
const HIDE_ON = /\/(cart|checkout|product|profile)(\/|$)/;

const MobileViewCartPill = () => {
  const cart = useSelector((state: any) => state.Cart);
  const pathname = usePathname() || "";
  const router = useRouter();
  const zoneHref = useZoneHref();
  const hydrated = useIsHydrated();

  const count = cart?.isGuest ? sumQty(cart?.guestCart) : sumQty(cart?.cartProducts);

  // Keep the previous count briefly so it can roll out as the new one rolls in.
  const [shownCount, setShownCount] = useState(count);
  const [prevCount, setPrevCount] = useState<number | null>(null);
  if (count !== shownCount) {
    setPrevCount(shownCount > 0 && count > 0 ? shownCount : null);
    setShownCount(count);
  }
  useEffect(() => {
    if (prevCount == null) return;
    const id = setTimeout(() => setPrevCount(null), 300);
    return () => clearTimeout(id);
  }, [prevCount, shownCount]);

  if (!hydrated || count <= 0 || HIDE_ON.test(pathname)) return null;

  // Cart thumbnail image
  const lines: any[] = cart?.cart?.data?.cart ?? [];
  const last = lines[lines.length - 1];
  const thumb = last?.image_url || last?.variants?.[0]?.image_url || null;

  const onProductList = /\/products\/?$/.test(pathname);

  return (
    <button
      type="button"
      onClick={() => router.push(zoneHref("/cart"))}
      aria-label={t("view_cart") || "View Cart"}
      className="fixed left-1/2 z-40 flex -translate-x-1/2 items-center gap-2.5 whitespace-nowrap rounded-full primaryBackColor p-1 pe-1.5 text-white shadow-[0_6px_20px_rgba(0,0,0,0.16)] cartAnimPillIn active:scale-[0.98] md:hidden"
      style={{
        bottom: `calc(${onProductList ? 16 : 72}px + env(safe-area-inset-bottom))`,
      }}
    >
      {/* Preferred flyToCart landing spot: it sits nearer the thumb than the header icon. */}
      <span
        data-cart-target
        data-cart-priority="2"
        className="relative flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden rounded-full bg-white"
      >
        {thumb ? (
          <Image src={thumb} alt="" fill sizes="36px" className="object-contain p-0.5" />
        ) : (
          <IoCartOutline size={18} className="primaryColor" />
        )}
      </span>
      <span className="flex flex-col items-start pe-1 leading-none">
        <span className="text-[14px] font-bold">{t("view_cart") || "View Cart"}</span>
        <span className="mt-0.5 text-[11px] opacity-90">
          <span className="relative inline-flex overflow-hidden align-bottom">
            {prevCount != null && (
              <span
                key={`out-${prevCount}-${count}`}
                aria-hidden="true"
                className="cartAnimRollOut absolute inset-x-0 top-0"
              >
                {prevCount}
              </span>
            )}
            <span
              key={count}
              className={`inline-block ${prevCount != null ? "cartAnimRollIn" : ""}`}
            >
              {count}
            </span>
          </span>{" "}
          {count === 1 ? t("item") || "Item" : t("items") || "Items"}
        </span>
      </span>
      <span className="flex h-8 w-8 items-center justify-center rounded-full bg-black/15">
        <IoChevronForward size={16} className="rtl:rotate-180" />
      </span>
    </button>
  );
};

export default MobileViewCartPill;
