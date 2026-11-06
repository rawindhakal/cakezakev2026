"use client";
import React, { useEffect, useRef, useState } from "react";
import { BiHeart, BiSolidHeart } from "react-icons/bi";
import { RiShareForwardLine } from "react-icons/ri";
import { FaStar } from "react-icons/fa";
import ProductLightbox from "./ProductLightbox";
import { t } from "@/utils/translation";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import ProductMedia from "./ProductMedia";
import { isVideoUrl } from "@/utils/helperFunction";
import PulseHeart from "@/components/ui/pulse-heart/PulseHeart";

interface MobileProductGalleryProps {
  product?: any;
  productImages?: string[];
  onSelectImage: (image: string) => void;
  isFavorite?: boolean;
  /** false for guests — skips the like pulse (toggle only toasts). */
  canToggleFavorite?: boolean;
  onToggleFavorite?: (e: React.MouseEvent) => void;
  onShare?: (e: React.MouseEvent) => void;
  /** Average rating + count for the corner chip (hidden when absent). */
  rating?: number;
  ratingCount?: number;
}

// Myntra-style mobile gallery: full-bleed, native swipe (scroll-snap), dots,
// floating wishlist/share, rating chip. Tap opens the fullscreen lightbox.
const MobileProductGallery = ({
  product,
  productImages,
  onSelectImage,
  isFavorite,
  canToggleFavorite = true,
  onToggleFavorite,
  onShare,
  rating,
  ratingCount,
}: MobileProductGalleryProps) => {
  const images = productImages?.length
    ? productImages
    : [product?.image_url].filter(Boolean);
  const trackRef = useRef<HTMLDivElement>(null);
  const [active, setActive] = useState(0);
  const [showLightbox, setShowLightbox] = useState(false);
  const [lightboxOrigin, setLightboxOrigin] = useState<HTMLImageElement | null>(null);

  // Variant switch replaces the gallery — jump back to the first image.
  useEffect(() => {
    trackRef.current?.scrollTo({ left: 0 });
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setActive(0);
  }, [images.join("|")]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleScroll = () => {
    const el = trackRef.current;
    if (!el || !el.clientWidth) return;
    const idx = Math.round(Math.abs(el.scrollLeft) / el.clientWidth);
    if (idx !== active && images[idx]) {
      setActive(idx);
      onSelectImage(images[idx]);
    }
  };

  const alt = product?.translations?.name ?? product?.name ?? "Product";
  // The lightbox shows stills only; clips play in the strip.
  const stills = images.filter((src: string) => !isVideoUrl(src));

  return (
    // -mx-4: bleed past the container's 1rem side padding to the screen edge.
    <div className="-mx-4">
      <div className="relative bg-gray-50 dark:bg-zinc-900">
        <div
          ref={trackRef}
          data-fly-image
          onScroll={handleScroll}
          className="flex snap-x snap-mandatory overflow-x-auto overscroll-x-contain [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        >
          {images.map((src, i) =>
            // A clip plays in place; tapping it must reach its own controls,
            // not the lightbox.
            isVideoUrl(src) ? (
              <div
                key={`${src}-${i}`}
                className="relative aspect-square max-h-[58svh] w-full shrink-0 snap-center snap-always"
              >
                <ProductMedia
                  src={src}
                  alt={alt}
                  className="h-full w-full object-contain"
                />
              </div>
            ) : (
              <button
                key={`${src}-${i}`}
                type="button"
                onClick={(e) => {
                  setLightboxOrigin(e.currentTarget.querySelector("img"));
                  setShowLightbox(true);
                }}
                className="relative aspect-square max-h-[58svh] w-full shrink-0 snap-center snap-always"
                aria-label={`${alt} ${i + 1}`}
              >
                <ImageWithPlaceholder
                  src={src}
                  alt={alt}
                  width={800}
                  height={1000}
                  priority={i === 0}
                  className="h-full w-full object-contain"
                />
              </button>
            ),
          )}
        </div>

        {/* Wishlist + share */}
        <div className="absolute end-3 top-3 flex flex-col gap-2">
          <PulseHeart
            liked={!!isFavorite}
            onToggle={onToggleFavorite}
            animate={canToggleFavorite}
            showCount={false}
            size={19}
            corner={999}
            pillColor="transparent"
            likedColor="var(--primary-color)"
            label={t("wishlist") || "Wishlist"}
            className="relative flex h-9 w-9 items-center justify-center rounded-full bg-white/95 shadow-md ring-1 ring-black/5 dark:bg-zinc-900/95"
          />
          <button
            type="button"
            onClick={onShare}
            aria-label={t("share") || "Share"}
            className="flex h-9 w-9 items-center justify-center rounded-full bg-white/95 shadow-md ring-1 ring-black/5 active:scale-90 dark:bg-zinc-900/95"
          >
            <RiShareForwardLine
              size={18}
              className="text-gray-700 dark:text-zinc-200"
            />
          </button>
        </div>

        {/* Rating chip */}
        {Number(rating) > 0 && (
          <span className="absolute bottom-3 start-3 z-10 inline-flex items-center gap-1 rounded-md bg-white/95 px-2 py-1 text-xs font-bold text-gray-900 shadow-sm dark:bg-zinc-900/95 dark:text-zinc-100">
            {Number(rating).toFixed(1)}
            <FaStar size={10} className="text-emerald-600" />
            {Number(ratingCount) > 0 && (
              <>
                <span className="mx-0.5 h-3 w-px bg-gray-300 dark:bg-zinc-600" />
                <span className="font-medium text-gray-600 dark:text-zinc-300">
                  {ratingCount}
                </span>
              </>
            )}
          </span>
        )}

        {/* Dots */}
        {images.length > 1 && (
          <div className="pointer-events-none absolute inset-x-0 bottom-3 flex justify-center gap-1.5">
            {images.map((_, i) => (
              <span
                key={i}
                className={`h-1.5 rounded-full shadow-sm transition duration-300 ${
                  i === active
                    ? "w-4 primaryBackColor"
                    : "w-1.5 bg-black/20 dark:bg-white/30"
                }`}
              />
            ))}
          </div>
        )}
      </div>

      <ProductLightbox
        open={showLightbox}
        close={() => setShowLightbox(false)}
        index={Math.max(0, stills.indexOf(images[active]))}
        slides={stills.map((src) => ({ src }))}
        originEl={lightboxOrigin}
      />
    </div>
  );
};

export default MobileProductGallery;
