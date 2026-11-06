import type { ReactNode } from "react";
import Image, { type StaticImageData } from "next/image";
import ThemedSvg from "./ThemedSvg";

// Returns SVG URL if image is SVG
const svgUrlOf = (img: string | StaticImageData | undefined) => {
  const url = typeof img === "string" ? img : img?.src;
  return typeof url === "string" && /\.svg(\?|$)/i.test(url) ? url : null;
};

export interface NotFoundProps {
  image?: string | StaticImageData;
  title?: string;
  description?: ReactNode;
  size?: number;
  className?: string;
  children?: ReactNode;
}

/** Reusable empty / not-found state component. */
const NotFound = ({
  image,
  title,
  description,
  size = 260,
  className = "",
  children,
}: NotFoundProps) => {
  return (
    <div
      className={`w-full flex flex-col items-center justify-center text-center gap-3 py-10 px-4 ${className}`}
    >
      {image &&
        (svgUrlOf(image) ? (
          <ThemedSvg
            src={svgUrlOf(image)}
            alt={title || "Not found"}
            className="w-3/4 max-w-[260px]"
          />
        ) : (
          <Image
            src={image}
            alt={title || "Not found"}
            width={size}
            height={size}
            unoptimized
            className="h-auto w-3/4 max-w-[260px]"
          />
        ))}
      {title && (
        <h2 className="text-lg md:text-xl font-bold fontColor">{title}</h2>
      )}
      {description && (
        <p className="text-sm SecondaryTextColor max-w-sm">{description}</p>
      )}
      {children}
    </div>
  );
};

export default NotFound;
