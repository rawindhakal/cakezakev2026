import { FaPlay } from "react-icons/fa";
import ImageWithPlaceholder from "../image-with-placeholder/ImageWithPlaceholder";
import { isVideoUrl } from "@/utils/helperFunction";

interface ProductMediaProps {
  src?: string;
  alt?: string;
  width?: number;
  height?: number;
  className?: string;
  priority?: boolean;
  /** Thumbnails show a muted first frame; the main stage plays with controls. */
  thumb?: boolean;
  /** Draws a play glyph over a clip, for places that only show a frame. */
  badge?: boolean;
  sizes?: string;
  quality?: number;
}

// One gallery slide. The API sends clips under the same image_url key as
// stills, so each slide decides for itself which element to draw.
const ProductMedia = ({
  src,
  alt,
  width = 871,
  height = 871,
  className = "",
  priority = false,
  thumb = false,
  badge = false,
  sizes,
  quality,
}: ProductMediaProps) => {
  if (isVideoUrl(src)) {
    const clip = (
      <video
        src={src}
        className={badge ? "h-full w-full object-contain" : className}
        // A frame has to be fetched for a thumb's poster; the stage plays, so
        // it needs the data.
        preload={thumb ? "metadata" : "auto"}
        controls={!thumb}
        // Muted is what lets the stage start on its own — browsers block a
        // clip with sound. The controls are there to unmute it.
        muted
        autoPlay={!thumb}
        playsInline
        loop={thumb}
        aria-label={alt}
      />
    );
    if (!badge) return clip;
    return (
      <span className={`relative block ${className}`}>
        {clip}
        <span className="pointer-events-none absolute inset-0 flex items-center justify-center">
          <span className="flex h-6 w-6 items-center justify-center rounded-full bg-black/55 text-white">
            <FaPlay size={9} className="ms-[1px]" />
          </span>
        </span>
      </span>
    );
  }
  return (
    <ImageWithPlaceholder
      src={src}
      alt={alt}
      width={width}
      height={height}
      priority={priority}
      sizes={sizes}
      quality={quality}
      className={className}
    />
  );
};

export default ProductMedia;
