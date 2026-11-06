import React from "react";
import Skeleton from "react-loading-skeleton";
import "react-loading-skeleton/dist/skeleton.css";

// Skeleton loader for product detail page
const ProductDetailSkeleton = () => (
  <section className="bodyBackgroundColor min-h-screen">
    <div className="border-b border-[var(--border-color)]">
      <div className="container py-3">
        <Skeleton height={14} width={180} />
      </div>
    </div>

    <div className="container mb-6">
      <div className="grid grid-cols-1 gap-4 mt-2 lg:grid-cols-12">
        {/* Image gallery */}
        <div className="col-span-12 flex flex-col gap-4 lg:col-span-6">
          <Skeleton height={420} borderRadius={12} />
          <div className="flex gap-3">
            {Array.from({ length: 4 }).map((_, index) => (
              <Skeleton key={index} height={72} width={72} borderRadius={8} />
            ))}
          </div>
        </div>

        {/* Title / price / details */}
        <div className="col-span-12 flex flex-col gap-4 lg:col-span-6">
          <Skeleton height={16} width={120} />
          <Skeleton height={28} width="80%" />
          <Skeleton height={16} width="50%" />
          <div className="flex items-center gap-3">
            <Skeleton height={32} width={100} />
            <Skeleton height={20} width={70} />
          </div>
          <Skeleton height={1} width="100%" />
          <div className="flex flex-wrap gap-2">
            {Array.from({ length: 4 }).map((_, index) => (
              <Skeleton key={index} height={36} width={64} borderRadius={8} />
            ))}
          </div>
          <Skeleton height={48} width="100%" borderRadius={10} />
          <Skeleton height={14} width="100%" count={3} />
        </div>
      </div>
    </div>
  </section>
);

export default ProductDetailSkeleton;
