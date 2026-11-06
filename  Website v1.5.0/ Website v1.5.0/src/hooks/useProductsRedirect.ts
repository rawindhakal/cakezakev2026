"use client";

import { useCallback } from "react";
import { useDispatch } from "react-redux";
import { useRouter } from "next/navigation";
import useZoneHref from "@/hooks/useZoneHref";
import { clearAllFilter } from "@/redux/slices/productFilterSlice";
import { resolveIdCsvToSlugCsv } from "@/utils/categorySlugResolver";
import {
  buildProductsRedirectQuery,
  sanitizeRedirectParams,
} from "@/utils/urlProductFilters";

type ResolveCategoryTree = (() => Promise<any[]>) | undefined;

// `redirect_type: "products"` — opens the listing with the banner's filter set
// as its initial state. Shared by every section that renders a redirect block.
export default function useProductsRedirect(
  resolveCategoryTree?: ResolveCategoryTree,
) {
  const router = useRouter();
  const zoneHref = useZoneHref();
  const dispatch = useDispatch();

  return useCallback(
    async (node: any) => {
      const params = sanitizeRedirectParams(node?.redirect_params);
      // category_id arrives as an id; the listing URL carries slugs.
      let categorySlug = "";
      if (params.category_id) {
        const tree = (await resolveCategoryTree?.().catch(() => [])) || [];
        categorySlug =
          resolveIdCsvToSlugCsv(tree, params.category_id) || params.category_id;
      }
      // Drop any category/block scope the previous listing left in redux.
      dispatch(clearAllFilter({}));
      const qs = new URLSearchParams(
        buildProductsRedirectQuery(node?.redirect_params, {
          categorySlug,
          title: node?.redirect_title || "",
        }),
      ).toString();
      const dest = zoneHref("/products");
      router.push(qs ? `${dest}?${qs}` : dest);
    },
    [dispatch, resolveCategoryTree, router, zoneHref],
  );
}
