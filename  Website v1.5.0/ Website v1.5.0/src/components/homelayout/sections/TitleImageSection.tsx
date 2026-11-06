"use client";

import React from "react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { pickDeviceImage, toCssAspectRatio } from "@/utils/helperFunction";
import { resolveIdCsvToSlugCsv } from "@/utils/categorySlugResolver";
import useZoneHref from "@/hooks/useZoneHref";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import useNavClick from "@/hooks/useNavClick";
import useProductsRedirect from "@/hooks/useProductsRedirect";

interface TitleImageSectionProps {
  block: any;
  borderRadius?: string | number;
  device?: string;
  priority?: boolean;
  // Resolves category tree for navigation.
  resolveCategoryTree?: () => Promise<any[]>;
}

// Priority gates LCP image promotion for title image.
const TitleImageSection = ({
  block,
  borderRadius,
  device = "web",
  priority = false,
  resolveCategoryTree,
}: TitleImageSectionProps) => {
  const zoneHref = useZoneHref();
  const { buildQueryPatch } = useUrlProductFilters();
  const openProductsRedirect = useProductsRedirect(resolveCategoryTree);
  const router = useRouter();

  const src = pickDeviceImage(block?.images, device, block?.image_url);

  const imageAspectRaw =
    block?.config?.image_aspect && typeof block.config.image_aspect === "object"
      ? pickDeviceImage(block.config.image_aspect, device)
      : block?.config?.image_aspect;
  const aspectRatio = toCssAspectRatio(imageAspectRaw) ?? null;

  const clickable =
    (block?.redirect_type === "url" && block?.redirect_url) ||
    (block?.redirect_type === "product" && block?.redirect_slug) ||
    (block?.redirect_type === "category" && block?.redirect_id) ||
    (block?.redirect_type === "page" && block?.redirect_slug) ||
    // An all-blank filter set is valid: it opens the unfiltered listing.
    block?.redirect_type === "products";

  const { run: runNavClick } = useNavClick();

  const navigate = async () => {
    if (block?.redirect_type === "url" && block?.redirect_url) {
      window.open(block.redirect_url, "_blank");
    } else if (block?.redirect_type === "product" && block?.redirect_slug) {
      router.push(zoneHref(`/product/${block.redirect_slug}`));
    } else if (block?.redirect_type === "category" && block?.redirect_id) {
      const tree = (await resolveCategoryTree?.()) || [];
      const slug =
        resolveIdCsvToSlugCsv(tree, block.redirect_id.toString()) ||
        block.redirect_id.toString();
      const qs = new URLSearchParams(
        buildQueryPatch({ category_id: slug }),
      ).toString();
      const dest = zoneHref("/products");
      router.push(qs ? `${dest}?${qs}` : dest);
    } else if (block?.redirect_type === "products") {
      await openProductsRedirect(block);
    } else if (block?.redirect_type === "page" && block?.redirect_slug) {
      router.push(zoneHref(`/page/${block.redirect_slug}`));
    }
  };

  const handleClick = () => runNavClick(navigate);

  if (!src) return null;

  return (
    <section >
  
        <div
          className={`relative w-full overflow-hidden ${
            clickable ? "cursor-pointer" : ""
          }`}
          style={{ borderRadius, ...(aspectRatio ? { aspectRatio } : {}) }}
          onClick={clickable ? handleClick : undefined}
        >
          <Image
            src={src}
            alt="Title image"
            priority={priority}
            className={`w-full ${aspectRatio ? "h-full object-cover" : "h-auto object-contain"}`}
            width={1920}
            height={640}
            sizes="100vw"
            quality={75}
          />
        </div>

    </section>
  );
};

export default React.memo(TitleImageSection);
