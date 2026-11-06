import React from 'react';
import Skeleton from 'react-loading-skeleton';
import 'react-loading-skeleton/dist/skeleton.css';

interface CardSkeletonProps {
  height?: number | string;
  width?: number | string;
  padding?: string;
  variant?: "block" | "list" | "order" | "product";
}

// Reusable skeleton component supporting block, list, order, and product layout variants
const CardSkeleton = ({ height, width = "100%", padding, variant = "block" }: CardSkeletonProps) => {
    // Order card skeleton variant matching order list card structure
    if (variant === "order") {
        return (
            <div className={`px-4 py-2 ${padding ?? ""}`}>
                <div className="flex w-full flex-col overflow-hidden rounded-lg border border-[var(--border-color)] shadow-sm">
                    <div className="flex items-center justify-between gap-2 px-4 pt-4">
                        <Skeleton height={22} width={110} borderRadius={9999} />
                        <Skeleton height={28} width={28} borderRadius={9999} />
                    </div>
                    <div className="px-4 pt-2">
                        <Skeleton height={12} width={120} />
                    </div>
                    <div className="px-4 pt-1">
                        <Skeleton height={16} width={140} />
                    </div>
                    <div className="mt-3 flex w-full items-center gap-3 px-4">
                        <Skeleton height={48} width={48} borderRadius={8} />
                        <div className="min-w-0 flex-grow">
                            <Skeleton height={14} width="70%" />
                            <div className="mt-1">
                                <Skeleton height={11} width="40%" />
                            </div>
                        </div>
                        <Skeleton height={16} width={50} />
                    </div>
                    <div className="mt-3 flex items-center justify-between gap-2 border-t border-dashed border-[var(--border-color)] px-4 py-3">
                        <Skeleton height={20} width={90} />
                        <Skeleton height={14} width={60} />
                    </div>
                    <div className="flex gap-2 px-4 pb-4">
                        <Skeleton height={40} width="100%" borderRadius={8} />
                        <Skeleton height={40} width="100%" borderRadius={8} />
                    </div>
                </div>
            </div>
        );
    }

    // Mirrors VerticleProductCard: bordered card on md+, borderless with 4/5 image on mobile.
    if (variant === "product") {
        return (
            <div className="flex h-full flex-col overflow-hidden rounded-lg border cardBorder bg-white dark:bg-zinc-900 shadow-[0_2px_12px_rgba(0,0,0,0.04)] max-md:rounded-none max-md:border-0 max-md:bg-transparent max-md:shadow-none dark:max-md:bg-transparent">
                <div className="p-2 max-md:p-0">
                    <div className="relative aspect-[5/4] max-md:aspect-[4/5] w-full overflow-hidden rounded-xl leading-none">
                        <Skeleton height="100%" width="100%" borderRadius={12} className="!block !leading-none" containerClassName="absolute inset-0 block leading-none" />
                    </div>
                </div>
                {/* Mobile: price, title lines, weight */}
                <div className="md:hidden flex flex-col gap-1 px-0.5 pt-1.5">
                    <Skeleton height={16} width="45%" />
                    <Skeleton height={13} width="95%" />
                    <Skeleton height={13} width="70%" />
                    <Skeleton height={11} width="40%" />
                </div>
                {/* md+: brand, title, rating, then price + Add row */}
                <div className="max-md:hidden flex grow flex-col px-3 pt-1">
                    <Skeleton height={10} width="35%" />
                    <div className="mt-1">
                        <Skeleton height={14} width="85%" />
                    </div>
                    <div className="mt-1">
                        <Skeleton height={11} width="40%" />
                    </div>
                    <div className="mt-auto flex items-end justify-between gap-1.5 pt-1.5 pb-1.5">
                        <div className="flex flex-col gap-1">
                            <Skeleton height={16} width={60} />
                            <Skeleton height={12} width={42} />
                        </div>
                        <Skeleton height={36} width={92} borderRadius={8} />
                    </div>
                </div>
            </div>
        );
    }

    if (variant === "list") {
        return (
            <div className={`flex w-full ${padding ?? ""}`}>
                <div className="flex flex-row w-full min-h-[140px] gap-3 p-2.5 sm:p-3 border rounded-lg cardBorder">
                    {/* Thumbnail — same footprint as the real card's image box */}
                    <div className="shrink-0 self-start w-24 h-24 sm:w-28 sm:h-28">
                        <Skeleton height="100%" width="100%" borderRadius={12} />
                    </div>
                    {/* Details and action button skeleton */}
                    <div className="flex flex-1 min-w-0 flex-col">
                        <Skeleton height={14} width="85%" />
                        <div className="mt-1">
                            <Skeleton height={12} width="45%" />
                        </div>
                        <div className="mt-2">
                            <Skeleton height={16} width="30%" />
                        </div>
                        <div className="mt-auto pt-2">
                            <Skeleton height={40} width="100%" borderRadius={8} />
                        </div>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className={`flex  w-full ${padding}`}>
            <div className="w-full border rounded-lg cardBorder p-4">
                <Skeleton height={height} width={width} />
            </div>
        </div>
    );
};

export default CardSkeleton;
