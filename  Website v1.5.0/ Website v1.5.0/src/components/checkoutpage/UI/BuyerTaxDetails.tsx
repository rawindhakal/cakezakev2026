"use client";
import { useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { FiChevronDown, FiChevronRight } from "react-icons/fi";
import { RiBuilding2Line } from "react-icons/ri";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { t } from "@/utils/translation";
import {
  setBuyerBusinessName,
  setBuyerTaxNumber,
} from "@/redux/slices/checkoutSlice";

interface BuyerTaxDetailsProps {
  /** buyer_tax_field of the billed party's country. */
  label: string;
  validate: (value: string) => string | null;
  className?: string;
}

// Optional business name + tax registration typed on the order form, beside the
// order note. Never saved to the address book — the same flat may order for a
// company one week and a person the next.
const BuyerTaxDetails = ({ label, validate, className = "" }: BuyerTaxDetailsProps) => {
  const dispatch = useDispatch();
  const taxNumber = useSelector((state: any) => state.Checkout.buyerTaxNumber);
  const businessName = useSelector(
    (state: any) => state.Checkout.buyerBusinessName,
  );
  const [open, setOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const filled = [businessName, taxNumber].filter(Boolean).join(" · ");
  const hint =
    t("business_details_hint")?.replace("{label}", label) ||
    `Add your ${label} to get a tax invoice`;

  return (
    <div className={className}>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="flex w-full items-center gap-3 text-left"
      >
        <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full primaryLightBack primaryColor">
          <RiBuilding2Line size={18} />
        </span>
        <div className="min-w-0 flex-grow">
          <p className="text-sm font-bold textColor">
            {t("business_details") || "Business details"}
          </p>
          <p className="truncate text-xs SecondaryTextColor">
            {filled || hint}
          </p>
        </div>
        <span className="shrink-0 SecondaryTextColor">
          {open ? <FiChevronDown size={18} /> : <FiChevronRight size={18} />}
        </span>
      </button>

      {open && (
        <div className="mt-3 flex flex-col gap-3">
          <div className="flex flex-col gap-1.5">
            <Label className="text-sm font-semibold textColor">
              {t("business_name") || "Business Name"}
            </Label>
            <Input
              type="text"
              maxLength={191}
              className="h-auto py-2.5"
              placeholder={t("business_name_placeholder") || "Legal name for the invoice"}
              value={businessName || ""}
              onChange={(e) =>
                dispatch(setBuyerBusinessName({ data: e.target.value }))
              }
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label className="text-sm font-semibold textColor">{label}</Label>
            <Input
              type="text"
              maxLength={64}
              className="h-auto py-2.5"
              placeholder={label}
              value={taxNumber || ""}
              onChange={(e) => {
                setError(null);
                dispatch(setBuyerTaxNumber({ data: e.target.value }));
              }}
              onBlur={(e) => setError(validate(e.target.value))}
            />
            {error && <span className="text-xs text-red-500">{error}</span>}
          </div>
          {(taxNumber || businessName) && (
            <button
              type="button"
              onClick={() => {
                setError(null);
                dispatch(setBuyerTaxNumber({ data: "" }));
                dispatch(setBuyerBusinessName({ data: "" }));
              }}
              className="self-start text-xs font-medium text-red-500 transition hover:text-red-600"
            >
              {t("clear") || "Clear"}
            </button>
          )}
        </div>
      )}
    </div>
  );
};

export default BuyerTaxDetails;
