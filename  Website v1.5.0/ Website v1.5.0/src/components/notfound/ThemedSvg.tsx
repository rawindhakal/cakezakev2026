import { useEffect, useRef, useState } from "react";
import type { StaticImageData } from "next/image";

// Map baked accent colors to theme CSS variables
const ACCENT_MAP: [RegExp, string][] = [
  [/#2A55E5/gi, "var(--primary-color)"],
  [/#fc7832/gi, "var(--primary-color)"],
  // Store closed accent colors
  [/#0277fa/gi, "var(--primary-color)"],
  [
    /#3f9aff/gi,
    "color-mix(in srgb, var(--primary-color) 65%, white)",
  ],
  [
    /#e3edf9/gi,
    "color-mix(in srgb, var(--primary-color) 18%, white)",
  ],
  [
    /#f8fbff/gi,
    "color-mix(in srgb, var(--primary-color) 6%, white)",
  ],
  [
    /#ac3e04/gi,
    "color-mix(in srgb, var(--primary-color) 70%, black)",
  ],
  [
    /#f0d3c4/gi,
    "color-mix(in srgb, var(--primary-color) 25%, white)",
  ],
  [
    /#f8ebe4/gi,
    "color-mix(in srgb, var(--primary-color) 10%, white)",
  ],
];

export interface ThemedSvgProps {
  /** imported svg (URL string, or { src }) */
  src: string | StaticImageData | null | undefined;
  className?: string;
  alt?: string;
}

/** Inlines SVG and applies dynamic primary theme colors. */
const ThemedSvg = ({ src, className = "", alt = "" }: ThemedSvgProps) => {
  const url = typeof src === "string" ? src : src?.src;
  const [markup, setMarkup] = useState<string | null>(null);
  const ref = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    let alive = true;
    if (!url) return;
    fetch(url)
      .then((r) => (r.ok ? r.text() : Promise.reject(r.status)))
      .then((raw) => {
        if (!alive) return;
        // Replace colors, strip fixed dimensions, and remove background blur
        const themed = ACCENT_MAP
          .reduce((svg, [hex, shade]) => svg.replace(hex, shade), raw)
          .replace(/<svg([^>]*?)\s(width|height)="[^"]*"/gi, "<svg$1")
          .replace(/<foreignObject[\s\S]*?<\/foreignObject>/gi, "");
        setMarkup(themed);
      })
      .catch(() => alive && setMarkup(null));
    return () => {
      alive = false;
    };
  }, [url]);

  if (markup) {
    return (
      <span
        ref={ref}
        role="img"
        aria-label={alt}
        className={`block mx-auto [&>svg]:block [&>svg]:h-auto [&>svg]:w-full [&>svg]:max-h-full ${className}`}
        dangerouslySetInnerHTML={{ __html: markup }}
      />
    );
  }

  // Image fallback before SVG is loaded
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={url} alt={alt} className={className} />;
};

export default ThemedSvg;
