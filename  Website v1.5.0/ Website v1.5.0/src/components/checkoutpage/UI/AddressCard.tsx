"use client";
import { useEffect, useRef, useState } from "react";
import {
  FiMapPin,
  FiPlus,
  FiTrash2,
  FiEdit2,
  FiHome,
  FiBriefcase,
  FiMoreVertical,
} from "react-icons/fi";
import { t } from "@/utils/translation";

// Selectable address row with edit/delete menu.
interface AddressCardProps {
  /** address row shape from api.getAddress() — no exported type, kept `any`. */
  addr: any;
  active: boolean;
  onSelect: () => void;
  onEdit: () => void;
  onDelete: () => void;
  formatAddress: (a: any) => string;
}

const AddressCard = ({
  addr,
  active,
  onSelect,
  onEdit,
  onDelete,
  formatAddress,
}: AddressCardProps) => {
  const type = (addr?.type || "").toLowerCase();
  let TypeIcon = FiMapPin;
  if (type === "home") {
    TypeIcon = FiHome;
  } else if (type === "work" || type === "office") {
    TypeIcon = FiBriefcase;
  }
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!menuOpen) return;
    const close = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node))
        setMenuOpen(false);
    };
    document.addEventListener("mousedown", close);
    return () => document.removeEventListener("mousedown", close);
  }, [menuOpen]);

  return (
    <label
      className={`relative flex items-center gap-2.5 !rounded-xl border p-3 cursor-pointer transition ${
        active
          ? "primaryColorBorder dark:border-white dark:bg-white/5"
          : "cardBorder hover:border-gray-300 dark:hover:border-gray-600"
      }`}
    >
      <input
        type="radio"
        name="delivery_address"
        className="sr-only"
        checked={active}
        onChange={onSelect}
      />

      {/* radio */}
      <span
        className={`w-[18px] h-[18px] rounded-full border-2 flex items-center justify-center shrink-0 ${
          active
            ? "   dark:border-white"
            : "border-gray-300 dark:border-gray-600"
        }`}
      >
        {active && (
          <span className="w-2 h-2 rounded-full primaryBackColor dark:bg-white" />
        )}
      </span>

      {/* type icon */}
      <span
        className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 ${
          active
            ? "primaryBackColor text-white"
            : "primaryLightBack primaryColor dark:text-white"
        }`}
      >
        <TypeIcon size={15} />
      </span>

      {/* details */}
      <div className="flex flex-col min-w-0 flex-1">
        <div className="flex items-center gap-1.5">
          <span className="font-bold text-sm truncate">
            {addr?.type || addr?.name}
          </span>
          {addr?.is_default == 1 && (
            <span className="text-[10px] font-semibold primaryColor dark:text-white shrink-0">
              • {t("default")}
            </span>
          )}
        </div>
        <span className="text-xs SecondaryTextColor leading-snug line-clamp-1">
          {formatAddress(addr)}
        </span>
      </div>

      {/* 3-dot menu */}
      <div className="relative shrink-0" ref={menuRef}>
        <button
          type="button"
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            setMenuOpen((o) => !o);
          }}
          aria-label={t("action") || "Actions"}
          className={`w-8 h-8 flex items-center justify-center rounded-full transition ${
            menuOpen
              ? "primaryLightBack primaryColor dark:text-white"
              : "SecondaryTextColor hover:backgroundColor"
          }`}
        >
          <FiMoreVertical size={17} />
        </button>
        {menuOpen && (
          <div className="absolute right-0 top-9 z-20 w-36 rounded-xl border cardBorder bodyBackgroundColor shadow-xl ring-1 ring-black/5 dark:ring-white/10 p-1 origin-top-right animate-[fadeIn_.12s_ease-out]">
            <button
              type="button"
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setMenuOpen(false);
                onEdit();
              }}
              className="w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm font-medium textColor hover:primaryLightBack transition"
            >
              <span className="w-6 h-6 rounded-md primaryLightBack primaryColor dark:text-white flex items-center justify-center shrink-0">
                <FiEdit2 size={13} />
              </span>
              {t("edit")}
            </button>
            <button
              type="button"
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setMenuOpen(false);
                onDelete();
              }}
              className="w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm font-medium text-red-500 hover:bg-red-50 dark:hover:bg-red-500/10 transition"
            >
              <span className="w-6 h-6 rounded-md bg-red-50 dark:bg-red-500/10 text-red-500 flex items-center justify-center shrink-0">
                <FiTrash2 size={13} />
              </span>
              {t("delete")}
            </button>
          </div>
        )}
      </div>
    </label>
  );
};

export default AddressCard;

// Dashed "add address" tile for the empty state.
export const AddAddressTile = ({
  label,
  onClick,
}: {
  label: string;
  onClick: () => void;
}) => (
  <button
    type="button"
    onClick={onClick}
    className="primaryDashedBorder rounded-xl p-6 w-full flex flex-col items-center justify-center gap-2 font-bold text-base primaryColor dark:text-white"
  >
    <span className="w-12 h-12 rounded-full primaryLightBack flex items-center justify-center">
      <FiPlus size={22} />
    </span>
    {label}
  </button>
);
