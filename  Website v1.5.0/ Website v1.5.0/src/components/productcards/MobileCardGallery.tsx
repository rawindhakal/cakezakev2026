"use client";
import React, { useRef, useState } from "react";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";

interface MobileCardGalleryProps {
  images: string[];
  alt: string;
  /** Extra classes for each slide (padding, grayscale). */
  imgClassName?: string;
  /** Extra classes for the dot row (position above a variant bar). */
  dotsClassName?: string;
}

// Mobile counterpart to the cards' desktop hover slideshow: scroll-snap track
// with dots. Touch has no hover, so without this the extra images are unseen.
const MobileCardGallery = ({
  images,
  alt,
  imgClassName = "",
  dotsClassName = "bottom-1.5 start-2",
}: MobileCardGalleryProps) => {
  const trackRef = useRef<HTMLDivElement>(null);
  const [active, setActive] = useState(0);

  const handleScroll = () => {
    const el = trackRef.current;
    if (!el?.clientWidth) return;
    const idx = Math.round(Math.abs(el.scrollLeft) / el.clientWidth);
    if (idx !== active && images[idx]) setActive(idx);
  };

  // Blinkit-style window: at most 5 dots, active centered, the ones furthest
  // from it rendered smaller so a long gallery stays a fixed-width row.
  const WINDOW = 5;
  const start = Math.min(
    Math.max(active - Math.floor(WINDOW / 2), 0),
    Math.max(images.length - WINDOW, 0),
  );
  const visible = images.slice(start, start + WINDOW);
  const dotSize = (idx: number) => {
    const d = Math.abs(idx - active);
    if (d <= 1) return 6;
    if (d === 2) return 4;
    return 3;
  };

  return (
    <>
      <div
        ref={trackRef}
        onScroll={handleScroll}
        // swiper-no-swiping: a swipe here scrolls this track, not the parent slider.
        className="swiper-no-swiping md:hidden flex h-full w-full touch-pan-x touch-pan-y snap-x snap-mandatory overflow-x-auto overscroll-x-contain [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      >
        {images.map((src, idx) => (
          <ImageWithPlaceholder
            key={`${src}-${idx}`}
            src={src}
            alt={alt}
            width={300}
            height={300}
            priority={idx === 0}
            className={`h-full w-full shrink-0 snap-center snap-always object-contain ${imgClassName}`}
          />
        ))}
      </div>
      <div
        className={`md:hidden pointer-events-none absolute z-[6] flex items-center gap-[5px] ${dotsClassName}`}
      >
        {visible.map((src, i) => {
          const idx = start + i;
          const size = dotSize(idx);
          return (
            <span
              key={`dot-${src}-${idx}`}
              style={{ height: size, width: size }}
              className={`rounded-full transition-all duration-200 ${
                idx === active
                  ? "bg-gray-800 dark:bg-zinc-100"
                  : "bg-gray-300 dark:bg-zinc-600"
              }`}
            />
          );
        })}
      </div>
    </>
  );
};

export default MobileCardGallery;
