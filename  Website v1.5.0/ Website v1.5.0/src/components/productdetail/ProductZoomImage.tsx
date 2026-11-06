import React, { useEffect, useRef, useState } from "react";
import { useSelector } from "react-redux";

interface ProductZoomImageProps {
  image?: string;
  overlay?: React.ReactNode;
  alt?: string;
}

const ZOOM = 2.2;

const clamp = (v: number, min: number, max: number) => Math.min(Math.max(v, min), max);

const ProductZoomImage = ({ image, overlay, alt = "" }: ProductZoomImageProps) => {
  const setting = useSelector((state: any) => state.Setting);
  const placeholder = setting?.setting?.web_settings?.placeholder_image;
  const language = useSelector((state: any) => state.Language.selectedLanguage);
  const isRtl = language?.type?.toLowerCase() === "rtl";

  const [imgSrc, setImgSrc] = useState(image || placeholder);
  const [show, setShow] = useState(false);
  const [pos, setPos] = useState({ x: 0.5, y: 0.5 });
  const [size, setSize] = useState({ w: 0, h: 0 });
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- syncs the displayed image with the image/placeholder props
    setImgSrc(image || placeholder);
  }, [image, placeholder]);

  const handleMove = (e: React.MouseEvent<HTMLDivElement>) => {
    // Ignore mouse move over overlay controls
    if ((e.target as HTMLElement)?.closest?.("[data-zoom-ignore]")) return;
    const rect = boxRef.current?.getBoundingClientRect();
    if (!rect) return;
    setSize({ w: rect.width, h: rect.height });
    setPos({
      x: clamp((e.clientX - rect.left) / rect.width, 0, 1),
      y: clamp((e.clientY - rect.top) / rect.height, 0, 1),
    });
  };

  // Clamp lens position within image bounds
  const half = 1 / (2 * ZOOM);
  const cx = clamp(pos.x, half, 1 - half);
  const cy = clamp(pos.y, half, 1 - half);

  // Calculate zoom panel image translation
  const tx = -(cx * size.w * ZOOM - size.w / 2);
  const ty = -(cy * size.h * ZOOM - size.h / 2);

  return (
    <div
      ref={boxRef}
      className="relative h-full w-full"
      onMouseEnter={() => setShow(true)}
      onMouseLeave={() => setShow(false)}
      onMouseMove={handleMove}
    >
      {/* eslint-disable-next-line @next/next/no-img-element -- needs onError fallback + raw pixel sizing for the zoom transform math below */}
      <img
        src={imgSrc}
        alt={alt}
        onError={() => setImgSrc(placeholder)}
        // High priority image fetch
        fetchPriority="high"
        decoding="async"
        className="h-full w-full object-contain select-none [backface-visibility:hidden] [transform:translateZ(0)] [will-change:transform]"
        draggable={false}
      />

      {/* Overlay buttons */}
      {overlay}

      {/* Zoom lens */}
      {show && (
        <div
          className="pointer-events-none absolute border border-gray-400 bg-white/30"
          style={{
            width: `${(1 / ZOOM) * 100}%`,
            height: `${(1 / ZOOM) * 100}%`,
            left: `${cx * 100}%`,
            top: `${cy * 100}%`,
            transform: "translate(-50%, -50%)",
          }}
        />
      )}

      {/* Zoom panel */}
      {show && size.w > 0 && (
        <div
          dir="ltr"
          className={`pointer-events-none absolute top-0 z-[1000] overflow-hidden rounded-xl border border-gray-200 bg-white shadow-lg ${
            isRtl ? "right-full mr-4" : "left-full ml-4"
          }`}
          style={{ width: size.w, height: size.h }}
        >
          {/* eslint-disable-next-line @next/next/no-img-element -- needs raw pixel width/height for the zoom transform math above */}
          <img
            src={imgSrc}
            alt=""
            loading="lazy"
            decoding="async"
            className="max-w-none object-contain"
            style={{
              width: size.w * ZOOM,
              height: size.h * ZOOM,
              transform: `translate(${tx}px, ${ty}px)`,
            }}
            draggable={false}
          />
        </div>
      )}
    </div>
  );
};

export default ProductZoomImage;
