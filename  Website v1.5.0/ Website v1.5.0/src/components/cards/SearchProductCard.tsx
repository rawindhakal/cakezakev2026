import { setProductBySearch } from '@/redux/slices/productFilterSlice'
import Link from 'next/link'
import React from 'react'
import { useDispatch } from 'react-redux'
import ImageWithPlaceholder from '../image-with-placeholder/ImageWithPlaceholder'
import useZoneHref from "@/hooks/useZoneHref";
import useCurrency from "@/hooks/useCurrency";
import { formatCurrency } from "@/utils/helperFunction";

interface SearchProductCardProps {
  product: any;
  onResultClick?: () => void;
  highlight?: string;
}

const escapeRegExp = (value: string) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// Bolds every typed word inside the product name.
const HighlightText = ({ text, query }: { text: string; query?: string }) => {
  const words = (query || "").trim().split(/\s+/).filter(Boolean).map(escapeRegExp);
  if (!text || words.length === 0) return <>{text}</>;
  const parts = text.split(new RegExp(`(${words.join("|")})`, "gi"));
  return (
    <>
      {parts.map((part, i) =>
        i % 2 === 1 ? (
          <mark key={i} className="bg-transparent font-extrabold primaryColor">
            {part}
          </mark>
        ) : (
          <span key={i} className="font-normal">{part}</span>
        ),
      )}
    </>
  );
};

const SearchProductCard = ({ product, onResultClick, highlight }: SearchProductCardProps) => {
  const zoneHref = useZoneHref();
    const dispatch = useDispatch()
    const { currency, decimals } = useCurrency();

    const handleSearchProductClick = () => {
        // Clear results + Header's search text so the dropdown closes.
        dispatch(setProductBySearch({ data: [] }))
        onResultClick?.()
    }

    // Search API nests the image under images[]; variant image as fallback.
    const productImage =
        product?.image_url ??
        product?.images?.[0]?.image_url ??
        product?.variants?.[0]?.image
    return (
        <Link href={zoneHref(`/product/${product?.slug}`)} prefetch={false} onClick={() => handleSearchProductClick()} className="w-full group">
            <div className="flex items-center gap-3 px-4 py-2.5 border-b border-gray-100 dark:border-zinc-800/80 last:border-b-0 hover:bg-zinc-50 dark:hover:bg-zinc-800/40 transition duration-200">
                <div className="w-10 h-10 flex-shrink-0">
                    <ImageWithPlaceholder src={productImage} width={150} height={150} className="w-full h-full object-cover rounded-md border border-gray-100 dark:border-zinc-700/50" alt="product image" />
                </div>
                <div className="flex flex-col flex-grow text-start min-w-0">
                    <div className="text-sm font-semibold text-zinc-800 dark:text-zinc-200 truncate group-hover:text-primary-color transition-colors duration-200">
                        <HighlightText text={product?.translations?.name ?? product?.name ?? ""} query={highlight} />
                    </div>
                    <div className="text-xs font-medium mt-0.5">
                        {
                            product?.discounted_price ?
                                <div className="text-zinc-900 dark:text-zinc-100 flex items-center gap-1.5">
                                    <span>{formatCurrency(product?.discounted_price, currency, decimals, true)}</span>
                                    <span className='line-through text-zinc-400 dark:text-zinc-500 font-normal'>{formatCurrency(product?.price, currency, decimals, true)}</span>
                                </div> :
                                <div className="text-zinc-700 dark:text-zinc-300">{formatCurrency(product?.price, currency, decimals, true)}</div>
                        }
                    </div>
                </div>
            </div>
        </Link>
    )
}

export default SearchProductCard
