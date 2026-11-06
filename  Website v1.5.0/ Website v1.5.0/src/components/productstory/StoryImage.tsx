"use client";
import React from "react";
import Image from "next/image";

interface StoryImageProps {
  src?: string;
  alt?: string;
  priority?: boolean;
}

// Story sheet image. Fixed width/sizes/quality so the preview and the full card
// resolve to the same optimised URL (fetched once, then served from cache).
// No fade-in: fading from opacity-0 on every mount made cached images blink.
const StoryImage = ({ src, alt, priority }: StoryImageProps) => {
  if (!src) return null;
  return (
    <Image
      src={src}
      alt={alt || ""}
      width={640}
      height={640}
      sizes="100vw"
      quality={70}
      priority={priority}
      // Neighbour cards sit off-screen horizontally — load them up front
      // rather than lazily, so a swipe never lands on a blank panel.
      loading={priority ? undefined : "eager"}
      draggable={false}
      className="h-full w-full select-none object-contain"
    />
  );
};

export default StoryImage;
