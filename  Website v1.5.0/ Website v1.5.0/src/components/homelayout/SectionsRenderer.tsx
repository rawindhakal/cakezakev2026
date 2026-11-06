"use client";

import React, { useState } from "react";
import dynamic from "next/dynamic";
import { toCssRadius, toCssRadiusCorners } from "@/utils/helperFunction";
import SectionSkeleton from "./sections/SectionSkeleton";
import { ProductStoryProvider } from "@/components/productstory/ProductStoryContext";

// Dynamic section imports. Each needs a `loading` placeholder of roughly the
// real section's height — without one the chunk pops in and pushes everything
// below it down (measured 0.229 CLS on the home page).
const placeholder = (type: string, fullBleed = false) => {
  const Loading = () => <SectionSkeleton type={type} fullBleed={fullBleed} />;
  return Loading;
};

const TextSection = dynamic(() => import("./sections/TextSection"), {
  loading: placeholder("text_section"),
});
const ProductSliderSection = dynamic(
  () => import("./sections/ProductSliderSection"),
  { loading: placeholder("product_slider") },
);
const BannerSliderSection = dynamic(
  () => import("./sections/BannerSliderSection"),
  {
    loading: () => (
      <div className="w-full aspect-[1200/650] animate-pulse bg-black/5" />
    ),
  },
);
const CategorySection = dynamic(() => import("./sections/CategorySection"), {
  loading: placeholder("category_section"),
});
const BrandSection = dynamic(() => import("./sections/BrandSection"), {
  loading: placeholder("brand_section"),
});
const ProductTabsSection = dynamic(
  () => import("./sections/ProductTabsSection"),
  { loading: placeholder("product_slider") },
);
const GridBannerSection = dynamic(
  () => import("./sections/GridBannerSection"),
  { loading: placeholder("grid_banner") },
);
const TitleImageSection = dynamic(
  () => import("./sections/TitleImageSection"),
  { loading: placeholder("title_image") },
);

// Render block component by type.
const renderBlock = (
  block: any,
  sectionRadius: string | number | undefined,
  device: string,
  resolveCategoryTree: () => Promise<any[]>,
  isLcpCandidate = false,
) => {
  switch (block?.type) {
    case "text_section":
      return (
        <TextSection
          block={block}
          borderRadius={sectionRadius}
          resolveCategoryTree={resolveCategoryTree}
        />
      );
    case "product_slider":
      return (
        <ProductSliderSection
          block={block}
          borderRadius={sectionRadius}
          device={device}
        />
      );
    case "banner_slider":
      return (
        <BannerSliderSection
          block={block}
          borderRadius={sectionRadius}
          device={device}
          priority={isLcpCandidate}
          resolveCategoryTree={resolveCategoryTree}
        />
      );
    case "grid_banner":
      return (
        <GridBannerSection
          block={block}
          borderRadius={sectionRadius}
          device={device}
          priority={isLcpCandidate}
          resolveCategoryTree={resolveCategoryTree}
        />
      );
    case "title_image":
      return (
        <TitleImageSection
          block={block}
          borderRadius={sectionRadius}
          device={device}
          priority={isLcpCandidate}
          resolveCategoryTree={resolveCategoryTree}
        />
      );
    case "category_section":
      return (
        <CategorySection
          block={block}
          borderRadius={sectionRadius}
          device={device}
        />
      );
    case "brand_section":
      return (
        <BrandSection block={block} borderRadius={sectionRadius} device={device} />
      );
    case "product_tabs":
      return (
        <ProductTabsSection
          block={block}
          borderRadius={sectionRadius}
          device={device}
        />
      );
    default:
      return null;
  }
};

interface SectionsRendererProps {
  sections: any[];
  device: string;
  resolveCategoryTree: () => Promise<any[]>;
  firstPageSectionCount?: number;
}

const SectionsRenderer = ({
  sections,
  device,
  resolveCategoryTree,
}: SectionsRendererProps) => {
  // Sections past the first render came from scroll pagination and fade up in.
  const [initialCount] = useState(() => sections.length);
  return (
    <ProductStoryProvider>
      {sections.map((section: any, sectionIndex: number) => {
        const sectionRadius =
          toCssRadiusCorners(section?.border_radius_corners) ??
          toCssRadius(section?.border_radius);
        const isFullBleed =
          section?.blocks?.[0]?.type === "banner_slider" &&
          section?.blocks?.[0]?.config?.carousel_style === "full_width";
        return (
          <div
            key={section?.id}
            className={`${isFullBleed ? "w-full" : "container"} ${sectionIndex >= initialCount ? "loadMoreIn" : ""}`}
            style={{
              marginTop: section?.margin_top || undefined,
              marginBottom: section?.margin_bottom || undefined,
              borderRadius: sectionRadius,
              overflow: sectionRadius ? "hidden" : undefined,
            }}
          >
            {(section?.blocks || []).map((block: any, blockIndex: number) => (
              <React.Suspense
                key={block?.id}
                fallback={<SectionSkeleton type={block?.type} />}
              >
                {renderBlock(
                  block,
                  sectionRadius,
                  device,
                  resolveCategoryTree,
                  sectionIndex === 0 && blockIndex === 0,
                )}
              </React.Suspense>
            ))}
          </div>
        );
      })}
    </ProductStoryProvider>
  );
};

export default SectionsRenderer;
