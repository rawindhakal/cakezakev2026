import { t } from "@/utils/translation";

interface BuyerTaxLinesProps {
  /** The placed order — carries the frozen snapshot. */
  orderDetail: any;
  className?: string;
}

// Business name and tax registration number of the billed party, as frozen on
// the order. The label is stored with the order on purpose: an admin can rename
// the country's field later and an old invoice keeps its own wording. Never
// read from an address — the number lives only on the order.
const BuyerTaxLines = ({ orderDetail, className = "" }: BuyerTaxLinesProps) => {
  const taxNumber = orderDetail?.buyer_tax_number;
  const businessName = orderDetail?.buyer_business_name;
  if (!taxNumber && !businessName) return null;

  return (
    <div className={`mt-2 flex flex-col gap-0.5 text-sm ${className}`}>
      {businessName && (
        <p className="SecondaryTextColor">
          {t("business_name") || "Business Name"} :{" "}
          <span className="font-semibold">{businessName}</span>
        </p>
      )}
      {taxNumber && (
        <p className="SecondaryTextColor">
          {orderDetail?.buyer_tax_label || t("tax_number") || "Tax Number"} :{" "}
          {taxNumber}
        </p>
      )}
    </div>
  );
};

export default BuyerTaxLines;
