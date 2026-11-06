"use client";
import React, { useState } from "react";
import Image, { type StaticImageData } from "next/image";
import ImagePlaceholder from "../../assets/image-placeholder/image.png";
import { useSelector } from "react-redux";
import useIsHydrated from "@/hooks/useIsHydrated";

interface ImageWithPlaceholderProps {
  src?: string | StaticImageData | null;
  alt?: string;
  className?: string;
  handleOnClick?: React.MouseEventHandler<HTMLImageElement>;
  priority?: boolean;
  sizes?: string;
  quality?: number;
  width?: number;
  height?: number;
  fill?: boolean;
}

const ImageWithPlaceholder = ({
  src,
  alt,
  className,
  handleOnClick,
  priority,
  sizes,
  quality,
  width,
  height,
}: ImageWithPlaceholderProps) => {
  const setting = useSelector((state: any) => state.Setting);
  const [isLoading, setIsLoading] = useState(!src);
  const [isError, setIsError] = useState(false);
  // Use fallback placeholder until hydrated
  const isHydrated = useIsHydrated();
  const placeholderSrc =
    (isHydrated && setting?.setting?.web_settings?.placeholder_image) ||
    ImagePlaceholder;

  return (
    <Image
      src={!src || isLoading || isError ? placeholderSrc : src}
      alt={alt || ""}
      {...(width && height
        ? { width, height }
        : {fill: true, sizes: sizes || "100vw" })}
      quality={quality}
      priority={priority}
      className={className}
      onClick={handleOnClick}
      onLoad={() => {
        setIsLoading(false);
      }}
      onError={() => {
        setIsLoading(false);
        setIsError(true);
      }}
    />
  );
};

export default ImageWithPlaceholder;
