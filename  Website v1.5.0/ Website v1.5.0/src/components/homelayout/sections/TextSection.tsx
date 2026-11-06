"use client";

import React from "react";
import { useSelector } from "react-redux";
import { useRouter } from "next/navigation";
import useZoneHref from "@/hooks/useZoneHref";
import useUrlProductFilters from "@/hooks/useUrlProductFilters";
import useDir from "@/hooks/useDir";
import useNavClick from "@/hooks/useNavClick";
import useProductsRedirect from "@/hooks/useProductsRedirect";
import { resolveIdCsvToSlugCsv } from "@/utils/categorySlugResolver";

interface TextSectionProps {
  block: any;
  borderRadius?: string | number;
  // Resolves category tree for navigation.
  resolveCategoryTree?: () => Promise<any[]>;
}

const TextSection = ({ block, borderRadius, resolveCategoryTree }: TextSectionProps) => {
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  const dir = useDir();
  const zoneHref = useZoneHref();
  const { buildQueryPatch } = useUrlProductFilters();
  const openProductsRedirect = useProductsRedirect(resolveCategoryTree);
  const router = useRouter();
  const config = block?.config || {};
  const { text_align, text_color, background_color, section_title, section_subtitle } = config;

  const clickable =
    !!section_title &&
    ((block?.redirect_type === "url" && block?.redirect_url) ||
      (block?.redirect_type === "product" && block?.redirect_slug) ||
      (block?.redirect_type === "category" && block?.redirect_id) ||
      (block?.redirect_type === "page" && block?.redirect_slug) ||
      // An all-blank filter set is valid: it opens the unfiltered listing.
      block?.redirect_type === "products");

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

  if (!section_title && !section_subtitle) return null;

  const blockPadding = Number.isFinite(Number(config?.block_padding))
    ? Number(config.block_padding)
    : 0;
  const BASE_INLINE_PADDING = 10;
  const blockPaddingStyle = {
    paddingTop: blockPadding,
    paddingBottom: blockPadding,
    paddingLeft: BASE_INLINE_PADDING + blockPadding,
    paddingRight: BASE_INLINE_PADDING + blockPadding,
  };

  const logicalAlign =
    text_align === "left"
      ? "start"
      : text_align === "right"
        ? "end"
        : text_align || "start";

  return (
    <section
      dir={dir}
      className="py-3 md:py-5"
      style={{
        ...(background_color ? { backgroundColor: background_color } : {}),
        ...(borderRadius != null ? { borderRadius, overflow: "hidden" } : {}),
      }}
    >
      <div
        style={{
          ...blockPaddingStyle,
          textAlign: logicalAlign,
          color: text_color || undefined,
        }}
      >
        {section_title && (
          <h2
            className={`text-xl sm:text-3xl font-extrabold leading-[29px] m-0 ${
              clickable ? "cursor-pointer hover:underline" : ""
            }`}
            style={{ color: text_color || undefined }}
            onClick={clickable ? handleClick : undefined}
            role={clickable ? "link" : undefined}
            tabIndex={clickable ? 0 : undefined}
            onKeyDown={
              clickable
                ? (e: React.KeyboardEvent) => {
                    if (e.key === "Enter" || e.key === " ") {
                      e.preventDefault();
                      handleClick();
                    }
                  }
                : undefined
            }
          >
            {section_title}
          </h2>
        )}
        {section_subtitle && (
          <p className="mt-1" style={{ color: text_color || undefined }}>
            {section_subtitle}
          </p>
        )}
      </div>
    </section>
  );
};

export default React.memo(TextSection);
