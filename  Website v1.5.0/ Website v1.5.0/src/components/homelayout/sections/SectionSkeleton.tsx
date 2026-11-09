"use client";

import React from "react";
import Skeleton from "react-loading-skeleton";
import "react-loading-skeleton/dist/skeleton.css";
import CardSkeleton from "@/components/skeleton/CardSkeleton";

// Section loading skeleton placeholders.
const SectionSkeletonBody = ({ type }: { type?: string }) => {
  switch (type) {
    case "banner_slider":
      return <Skeleton className="w-full aspect-[3/1] rounded-md" />;

    case "grid_banner":
      return (
        <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
          {Array(3)
            .fill(0)
            .map((_, index) => (
              <Skeleton key={index} className="w-full aspect-[16/9] rounded-md" />
            ))}
        </div>
      );

    case "title_image":
      return <Skeleton className="w-full aspect-[1200/300] rounded-md" />;

    case "text_section":
      return (
        <div className="py-2">
          <Skeleton width={220} height={24} className="mb-2" />
          <Skeleton width="70%" height={16} />
        </div>
      );

    case "category_section":
    case "occasion_section":
    case "relationship_section":
      return (
        <>
          <div className="flex items-center justify-between mb-4">
            <Skeleton width={150} height={24} />
            <Skeleton width={80} height={24} />
          </div>
          <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-4">
            {Array(6)
              .fill(0)
              .map((_, index) => (
                <div key={index} className="flex flex-col items-center">
                  <Skeleton circle width={72} height={72} className="mb-2" />
                  <Skeleton width={56} height={14} />
                </div>
              ))}
          </div>
        </>
      );

    case "brand_section":
      return (
        <>
          <div className="flex items-center justify-between mb-4">
            <Skeleton width={150} height={24} />
            <Skeleton width={80} height={24} />
          </div>
          <div className="flex gap-6 overflow-hidden pb-2">
            {Array(6)
              .fill(0)
              .map((_, index) => (
                <div key={index} className="min-w-[120px] flex-shrink-0">
                  <Skeleton height={80} className="mb-2 rounded-md" />
                  <Skeleton width="80%" height={14} className="mx-auto" />
                </div>
              ))}
          </div>
        </>
      );

    case "product_slider":
    default:
      return (
        <>
          <div className="flex items-center justify-between mb-4">
            <Skeleton width={180} height={24} />
            <Skeleton width={100} height={24} />
          </div>
          <div className="flex gap-4 overflow-hidden pb-2">
            {Array(5)
              .fill(0)
              .map((_, index) => (
                <div key={index} className="w-[150px] md:w-[200px] flex-shrink-0">
                  <CardSkeleton variant="product" />
                </div>
              ))}
          </div>
        </>
      );
  }
};

interface SectionSkeletonProps {
  type?: string;
  fullBleed?: boolean;
  className?: string;
}

const SectionSkeleton = ({
  type,
  fullBleed = false,
  className = "",
}: SectionSkeletonProps) => (
  <div
    aria-busy="true"
    aria-hidden="true"
    className={`${fullBleed ? "w-full" : "container"} my-6 ${className}`.trim()}
  >
    <SectionSkeletonBody type={type} />
  </div>
);

export default SectionSkeleton;
