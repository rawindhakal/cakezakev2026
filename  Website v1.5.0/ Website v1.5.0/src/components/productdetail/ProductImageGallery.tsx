"use client";
import React, { useState } from "react";
import { Swiper, SwiperSlide } from "swiper/react";
import "swiper/css";
import "swiper/css/navigation";
import { Navigation } from "swiper/modules";
import { IoIosArrowBack, IoIosArrowForward } from "react-icons/io";
import { BiHeart, BiSolidHeart } from "react-icons/bi";
import { RiShareForwardLine } from "react-icons/ri";
import { MdOutlineZoomOutMap } from "react-icons/md";
import useHydratedMediaQuery from "@/hooks/useHydratedMediaQuery";
import useDir from "@/hooks/useDir";
import { t } from "@/utils/translation";
import ProductLightbox from "./ProductLightbox";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import { FaPlay } from "react-icons/fa";
import ProductZoomImage from "./ProductZoomImage";
import ProductMedia from "./ProductMedia";
import { isVideoUrl } from "@/utils/helperFunction";
import PulseHeart from "@/components/ui/pulse-heart/PulseHeart";

interface ProductImageGalleryProps {
  product?: any;
  productImages?: string[];
  selectedImage?: string;
  onSelectImage: (image: string) => void;
  canHoverZoom?: boolean;
  isFavorite?: boolean;
  canToggleFavorite?: boolean;
  onToggleFavorite?: (e: React.MouseEvent) => void;
  onShare?: (e: React.MouseEvent) => void;
}

/** Product image gallery component with zoom and thumbnails. */
const ProductImageGallery = ({
  product,
  productImages,
  selectedImage,
  onSelectImage,
  canHoverZoom,
  isFavorite,
  canToggleFavorite = true,
  onToggleFavorite,
  onShare,
}: ProductImageGalleryProps) => {
  // Hydration-safe media query breakpoint
  const isLgUp = useHydratedMediaQuery("(min-width: 1024px)");
  const dir = useDir();

  // Lightbox state and handler
  const [showLightbox, setShowLightbox] = useState(false);
  const [lightboxOrigin, setLightboxOrigin] = useState<HTMLImageElement | null>(null);
  // The lightbox shows stills only; clips play in place on the main stage.
  const stills = (productImages || []).filter((src) => !isVideoUrl(src));
  const slides = stills.map((src) => ({ src }));
  const openLightbox = (e: React.MouseEvent<HTMLElement>) => {
    if (!((productImages?.length ?? 0) > 0)) return;
    setLightboxOrigin(e.currentTarget.closest("[data-fly-image]")?.querySelector("img") ?? null);
    setShowLightbox(true);
  };
  const selectedIndex = Math.max(0, stills.indexOf(selectedImage ?? ""));

  const Thumb = ({ image }: { image: string }) => (
    <button
      type="button"
      onClick={() => onSelectImage(image)}
      className={`relative box-border aspect-square w-full shrink-0 overflow-hidden rounded-lg border bg-white dark:bg-zinc-900 transition ${
        selectedImage === image
          ? "primaryBorder border-2 shadow-sm"
          : "border-[#E5E7EB] dark:border-zinc-700 opacity-70 hover:opacity-100 hover:border-gray-400"
      }`}
    >
      <ProductMedia
        thumb
        src={image}
        alt={product?.name}
        height={114}
        width={114}
        className="h-full w-full object-contain p-1.5"
      />
      {isVideoUrl(image) && (
        <span className="pointer-events-none absolute inset-0 flex items-center justify-center">
          <span className="flex h-6 w-6 items-center justify-center rounded-full bg-black/55 text-white">
            <FaPlay size={9} className="ms-[1px]" />
          </span>
        </span>
      )}
    </button>
  );

  // Vertical thumbnail gallery for desktop
  const VerticalThumbs = () =>
    (productImages?.length ?? 0) > 0 && (
      <div className="flex max-h-[600px] w-[80px] shrink-0 flex-col gap-2.5 overflow-y-auto pr-1 [&::-webkit-scrollbar]:hidden">
        {productImages!.map((image) => (
          <Thumb key={image} image={image} />
        ))}
      </div>
    );

  // Horizontal thumbnail swiper for mobile
  const overflows = (productImages?.length || 0) > 5;
  const HorizontalThumbs = () =>
    (productImages?.length ?? 0) > 0 && (
      <div
        dir={dir}
        className={`relative flex items-center ${overflows ? "px-7" : "px-0"}`}
      >
        {overflows && (
          <button
            type="button"
            aria-label="Previous thumbnails"
            className="thumb-prev absolute left-0 top-1/2 z-10 flex h-6 w-6 -translate-y-1/2 items-center justify-center rounded-full border border-gray-200 dark:border-zinc-700 bg-white dark:bg-zinc-900 text-gray-500 dark:text-zinc-400 shadow-sm hover:bg-gray-50 dark:hover:bg-zinc-800"
          >
            <IoIosArrowBack size={13} />
          </button>
        )}
        <Swiper
          spaceBetween={8}
          slidesPerView="auto"
          modules={[Navigation]}
          navigation={{ prevEl: ".thumb-prev", nextEl: ".thumb-next" }}
          className="brand-swiper w-full [&_.swiper-slide]:!w-16"
        >
          {productImages!.map((image) => (
            <SwiperSlide key={image}>
              <Thumb image={image} />
            </SwiperSlide>
          ))}
        </Swiper>
        {overflows && (
          <button
            type="button"
            aria-label="Next thumbnails"
            className="thumb-next absolute right-0 top-1/2 z-10 flex h-6 w-6 -translate-y-1/2 items-center justify-center rounded-full border border-gray-200 dark:border-zinc-700 bg-white dark:bg-zinc-900 text-gray-500 dark:text-zinc-400 shadow-sm hover:bg-gray-50 dark:hover:bg-zinc-800"
          >
            <IoIosArrowForward size={13} />
          </button>
        )}
      </div>
    );

  return (
    <div className="flex h-fit flex-col gap-4 rounded-lg border border-[#DFE3E8] dark:border-zinc-700 bg-white dark:bg-zinc-900 p-4 lg:flex-row lg:gap-4">
      {/* Desktop thumbnails */}
      {/* eslint-disable-next-line react-hooks/static-components -- VerticalThumbs closes over productImages/onSelectImage/selectedImage; hoisting would require threading all of them as props */}
      {isLgUp && <VerticalThumbs />}

      {/* Main image container */}
      <div className="relative min-w-0 flex-1">
        <div
          key={selectedImage}
          data-fly-image
          className="relative flex w-full h-[380px] sm:h-[500px] lg:h-[600px] items-center justify-center motion-safe:animate-fadeSwap"
        >
          {(() => {
            // Overlay controls for wishlist, share, and zoom
            const Overlay = (
              <>
                {/* Wishlist button */}
                <span data-zoom-ignore className="absolute right-2 top-2 z-20">
                  <PulseHeart
                    liked={!!isFavorite}
                    onToggle={onToggleFavorite}
                    animate={canToggleFavorite}
                    showCount={false}
                    size={20}
                    corner={999}
                    pillColor="transparent"
                    likedColor="var(--primary-color)"
                    label={t("wishlist") || "Wishlist"}
                    className="flex h-10 w-10 items-center justify-center rounded-full border border-gray-200 dark:border-zinc-700 bg-white dark:bg-zinc-900 shadow-md hover:primaryBorder"
                  />
                </span>

                {/* Share button */}
                <button
                  type="button"
                  data-zoom-ignore
                  onClick={onShare}
                  aria-label="share"
                  className="absolute right-2 top-14 z-20 flex h-10 w-10 items-center justify-center rounded-full border border-gray-200 dark:border-zinc-700 bg-white dark:bg-zinc-900 shadow-md hover:primaryBorder"
                >
                  <RiShareForwardLine
                    size={20}
                    className="text-gray-500 dark:text-zinc-400"
                  />
                </button>

                {/* Lightbox enlarge button */}
                {selectedImage && !isVideoUrl(selectedImage) && (
                  <button
                    type="button"
                    data-zoom-ignore
                    onClick={openLightbox}
                    aria-label={t("click_to_enlarge")}
                    className="group absolute bottom-2 left-2 z-20 flex h-10 items-center gap-0 overflow-hidden rounded-full border border-gray-200 dark:border-zinc-700 bg-white dark:bg-zinc-900 px-2.5 shadow-md transition-all hover:gap-2 hover:px-4 hover:primaryBorder"
                  >
                    <MdOutlineZoomOutMap
                      size={18}
                      className="shrink-0 text-gray-600 dark:text-zinc-300"
                    />
                    <span className="max-w-0 whitespace-nowrap text-sm font-medium text-gray-700 dark:text-zinc-200 opacity-0 transition-all duration-200 group-hover:max-w-[160px] group-hover:opacity-100">
                      {t("click_to_enlarge")}
                    </span>
                  </button>
                )}
              </>
            );

            // A clip owns its own controls, so neither zoom nor the lightbox
            // applies to it.
            if (isVideoUrl(selectedImage)) {
              return (
                <>
                  <ProductMedia
                    src={selectedImage}
                    alt={product?.name}
                    className="h-full w-full object-contain"
                  />
                  {Overlay}
                </>
              );
            }

            return canHoverZoom ? (
              <ProductZoomImage image={selectedImage} overlay={Overlay} />
            ) : (
              <>
                <ImageWithPlaceholder
                  src={selectedImage}
                  alt={product?.name}
                  width={871}
                  height={871}
                  priority
                  className="h-full w-full object-contain"
                />
                {Overlay}
              </>
            );
          })()}
        </div>
      </div>

      {/* Mobile thumbnails */}
      {/* eslint-disable-next-line react-hooks/static-components -- HorizontalThumbs closes over productImages/dir/overflows/onSelectImage/selectedImage; hoisting would require threading all of them as props */}
      {!isLgUp && <HorizontalThumbs />}

      <ProductLightbox
        open={showLightbox}
        close={() => setShowLightbox(false)}
        index={selectedIndex}
        slides={slides}
        originEl={lightboxOrigin}
      />
    </div>
  );
};

export default ProductImageGallery;
