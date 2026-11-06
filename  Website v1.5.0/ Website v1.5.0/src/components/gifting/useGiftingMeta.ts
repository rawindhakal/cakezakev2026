"use client";
import { useEffect, useState } from "react";
import { getGiftingMeta } from "@/api/apiRoutes";

export interface GiftingMeta {
  occasions: { id: number; name: string; slug: string; image?: string | null }[];
  relationships: { id: number; name: string; slug: string; image?: string | null }[];
  delivery_types: {
    id: number;
    name: string;
    slug: string;
    description?: string | null;
    time_window?: string | null;
    extra_charge?: number | string;
  }[];
}

const EMPTY: GiftingMeta = { occasions: [], relationships: [], delivery_types: [] };
let cache: GiftingMeta | null = null;

// Occasions / relationships / delivery types, fetched once per session.
export default function useGiftingMeta(): GiftingMeta {
  const [meta, setMeta] = useState<GiftingMeta>(cache || EMPTY);
  useEffect(() => {
    if (cache) return;
    getGiftingMeta()
      .then((res) => {
        if (res?.status === 1 && res.data) {
          cache = res.data;
          setMeta(res.data);
        }
      })
      .catch(() => {});
  }, []);
  return meta;
}
