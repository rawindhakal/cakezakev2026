"use client";

import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { useSelector } from "react-redux";
import * as api from "@/api/apiRoutes";
import { t } from "@/utils/translation";
import SearchProductRow from "@/components/search/SearchProductRow";

const LIMIT = 12;

const firstImage = (p: any) => {
  const img = p?.images?.[0];
  return p?.image_url || (typeof img === "string" ? img : img?.image_url) || "";
};

// Same shape ProductsList hands its cards.
export const adaptProduct = (p: any) => {
  const hasVariants = Array.isArray(p?.variants) && p.variants.length > 0;
  const adaptVariant = (v: any) => ({
    ...v,
    price: v?.price ?? p?.price ?? p?.min_price ?? 0,
    discounted_price: v?.discounted_price ?? 0,
    stock: v?.stock ?? 0,
    is_unlimited_stock: v?.is_unlimited_stock ?? p?.is_unlimited_stock ?? 0,
    status: v?.status ?? 1,
    measurement: v?.measurement ?? v?.attributes_text ?? "",
    unit: v?.unit ?? { short_code: "" },
  });
  return {
    ...p,
    name: p?.name || p?.short_description || "",
    image_url: firstImage(p),
    total_allowed_quantity: p?.total_allowed_quantity ?? p?.stock ?? 999,
    average_rating: p?.average_rating ?? p?.rating ?? 0,
    rating_count: p?.rating_count || 0,
    time_to_deliver: p?.time_to_deliver || "",
    variants: hasVariants
      ? p.variants.map(adaptVariant)
      : [
          {
            id: p?.variant_id ?? p?.id,
            price: p?.price ?? p?.min_price ?? 0,
            discounted_price: p?.discounted_price ?? 0,
            stock: p?.stock ?? 0,
            is_unlimited_stock: p?.is_unlimited_stock ?? 0,
            status: 1,
            measurement: "",
            unit: { short_code: "" },
          },
        ],
  };
};

// Heading with a slow brand-colour light sweep across the text.
const ShineText = ({ text }: { text: string }) => (
  <span className="shineText">{text}</span>
);

// Default product row shown under an empty, focused search box (Blinkit-style).
const SearchMindProducts = ({ enabled }: { enabled: boolean }) => {
  const latitude = useSelector((s: any) => s.City?.city?.latitude);
  const longitude = useSelector((s: any) => s.City?.city?.longitude);
  const shopMode = useSelector((s: any) => s.ShopMode?.mode);

  const { data = [], isLoading } = useQuery({
    queryKey: ["search-mind-products", latitude, longitude, shopMode],
    queryFn: async () => {
      const res = await api.getProductByFilter({
        latitude,
        longitude,
        filters: { limit: LIMIT, offset: 0, sort: "popular" },
      });
      return Array.isArray(res?.data) ? res.data : [];
    },
    enabled: enabled && latitude != null && longitude != null,
    staleTime: 1000 * 60 * 5,
  });

  const products = useMemo(() => data.map(adaptProduct), [data]);

  if (!isLoading && products.length === 0) return null;

  return (
    <SearchProductRow
      title={<ShineText text={t("whats_on_your_mind") || "What's on your mind?"} />}
      products={products}
      isLoading={isLoading}
      animate
    />
  );
};

export default SearchMindProducts;
