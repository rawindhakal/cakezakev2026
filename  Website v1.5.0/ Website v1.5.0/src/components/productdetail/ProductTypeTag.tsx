import Image from "next/image";
import { t } from "@/utils/translation";
import { getProductTypeMeta } from "./productType";

interface ProductTypeTagProps {
  /** product_type / indicator value; anything unmapped renders nothing. */
  type: number | string | undefined | null;
  className?: string;
  iconSize?: number;
}

// Diet mark only — icon, no label text.
const ProductTypeTag = ({
  type,
  className = "",
  iconSize = 12,
}: ProductTypeTagProps) => {
  const meta = getProductTypeMeta(type as any);
  if (!meta) return null;
  return (
    <span
      className={`relative inline-block shrink-0 ${className}`}
      style={{ height: iconSize, width: iconSize }}
    >
      <Image
        src={meta.svg}
        fill
        alt={t(meta.labelKey)}
        className="object-contain"
      />
    </span>
  );
};

export default ProductTypeTag;
