"use client";
import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import Image from "next/image";
import { FiChevronDown, FiGlobe } from "react-icons/fi";
import { fetchDialCountries } from "./PhoneNumberInput";

/** Standalone country dropdown picker. */
// Raw country object from API
interface CountrySelectProps {
  value?: any;
  onChange?: (country: any) => void;
  onReady?: (country: any) => void;
  onReferralStatus?: (isOn: boolean) => void;
  label?: string;
  hasError?: boolean;
}

interface MenuPos {
  left: number;
  top: number;
  width: number;
}

const CountrySelect = ({
  value,
  onChange,
  onReady,
  onReferralStatus,
  label,
  hasError = false,
}: CountrySelectProps) => {
  const [countries, setCountries] = useState<any[]>([]);
  const [open, setOpen] = useState(false);
  // Menu portal coordinates
  const [menuPos, setMenuPos] = useState<MenuPos | null>(null);
  const ref = useRef<HTMLDivElement>(null);
  const btnRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const fetchCountries = async () => {
      try {
        // Fetch countries using shared promise cache
        const res = await fetchDialCountries();
        if (res?.status == 1 && Array.isArray(res?.data) && res.data.length) {
          setCountries(res.data);
          const envCode = process.env.NEXT_PUBLIC_DEFAULT_COUNTRY_CODE;
          const match =
            res.data.find(
              (c: any) => c.code === envCode || c.dial_code === envCode,
            ) || res.data[0];
          onReady?.(match);
          // Update referral status
          onReferralStatus?.(
            (match?.is_referal_on ?? res?.is_referal_on) == 1,
          );
        }
      } catch (error: any) {
        console.log("Error fetching countries", error);
      }
    };
    fetchCountries();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Compute fixed menu position
  const positionMenu = () => {
    const r = btnRef.current?.getBoundingClientRect();
    if (r) setMenuPos({ left: r.left, top: r.bottom + 4, width: r.width });
  };

  const toggleOpen = () => {
    setOpen((v) => {
      const next = !v;
      if (next) positionMenu();
      return next;
    });
  };

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      // Close on click outside trigger or portal menu
      const target = e.target as HTMLElement;
      if (
        ref.current &&
        !ref.current.contains(target) &&
        !target.closest?.("[data-country-menu]")
      )
        setOpen(false);
    };
    // Reposition menu on scroll or resize
    const onReflow = () => positionMenu();
    document.addEventListener("mousedown", onDown);
    window.addEventListener("scroll", onReflow, true);
    window.addEventListener("resize", onReflow);
    return () => {
      document.removeEventListener("mousedown", onDown);
      window.removeEventListener("scroll", onReflow, true);
      window.removeEventListener("resize", onReflow);
    };
  }, [open]);

  const selected = countries.find((c) => c.id === value);

  const handleSelect = (country: any) => {
    onChange?.(country);
    onReferralStatus?.(country?.is_referal_on == 1);
    setOpen(false);
  };

  return (
    <div className="relative w-full" ref={ref}>
      {label && (
        <label className="mb-1 block text-base font-bold">{label}</label>
      )}
      <button
        ref={btnRef}
        type="button"
        onClick={toggleOpen}
        aria-haspopup="listbox"
        aria-expanded={open}
        className={`mt-1.5 flex w-full items-center justify-between rounded-lg border py-2.5 px-4 text-sm transition duration-200 bg-[#f4f5f7] dark:bg-zinc-800 text-start ${
          hasError
            ? "border-red-400 focus:border-red-500 focus:ring-2 focus:ring-red-100"
            : "cardBorder focus:primaryColorBorder focus:ring-2 focus:ring-[var(--primary-color,#29363f)]/15"
        } textColor`}
      >
        <div className="flex items-center gap-2.5">
          {selected?.logo_url ? (
            <Image
              src={selected.logo_url}
              alt={selected.code}
              width={22}
              height={16}
              className="h-4 w-[22px] shrink-0 rounded-[2px] object-cover"
            />
          ) : (
            <FiGlobe className="text-gray-400" size={16} />
          )}
          <span className="truncate">{selected?.name || "—"}</span>
        </div>
        <FiChevronDown
          size={16}
          className={`text-gray-500 transition-transform ${
            open ? "rotate-180" : ""
          }`}
        />
      </button>

      {open &&
        menuPos &&
        typeof document !== "undefined" &&
        createPortal(
        <ul
          role="listbox"
          data-country-menu
          style={{
            position: "fixed",
            left: menuPos.left,
            top: menuPos.top,
            width: menuPos.width,
          }}
          className="z-[100] max-h-60 overflow-y-auto rounded-lg border border-gray-200 bg-white py-1 shadow-lg dark:border-zinc-700 dark:bg-zinc-900"
        >
          {countries.map((c) => {
            const active = value === c.id;
            return (
              <li key={c.id} role="option" aria-selected={active}>
                <button
                  type="button"
                  onClick={() => handleSelect(c)}
                  className={`flex w-full items-center gap-2.5 px-3 py-2 text-start text-sm transition-colors hover:primaryLightBack ${
                    active ? "primaryLightBack primaryColor font-semibold" : ""
                  }`}
                >
                  {c.logo_url && (
                    <Image
                      src={c.logo_url}
                      alt={c.code}
                      width={22}
                      height={16}
                      className="h-4 w-[22px] shrink-0 rounded-[2px] object-cover"
                    />
                  )}
                  <span className="flex-1 truncate">{c.name}</span>
                  <span className="text-gray-500">{c.dial_code}</span>
                </button>
              </li>
            );
          })}
        </ul>,
          document.body,
        )}
    </div>
  );
};

export default CountrySelect;
