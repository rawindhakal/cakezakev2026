"use client";

import { useEffect, useRef } from "react";
import Lightbox, { type Slide } from "yet-another-react-lightbox";
import Zoom from "yet-another-react-lightbox/plugins/zoom";
import Thumbnails from "yet-another-react-lightbox/plugins/thumbnails";
import Counter from "yet-another-react-lightbox/plugins/counter";
import "yet-another-react-lightbox/styles.css";
import "yet-another-react-lightbox/plugins/thumbnails.css";
import "yet-another-react-lightbox/plugins/counter.css";

interface ProductLightboxProps {
  open: boolean;
  close: () => void;
  index: number;
  slides: Slide[];
  /** Tapped image; the lightbox grows out of its on-screen rect. */
  originEl?: HTMLImageElement | null;
}

interface Box {
  left: number;
  top: number;
  width: number;
  height: number;
}

const EASE = "cubic-bezier(0.22,1,0.36,1)";
const FLIGHT_MS = 300;

// Visible area of an object-fit: contain image of size nw×nh inside `box`.
const fitContain = (box: Box, nw: number, nh: number): Box => {
  if (!nw || !nh || !box.width || !box.height) return box;
  const s = Math.min(box.width / nw, box.height / nh);
  const width = nw * s;
  const height = nh * s;
  return {
    left: box.left + (box.width - width) / 2,
    top: box.top + (box.height - height) / 2,
    width,
    height,
  };
};

// Fullscreen product gallery: pinch / double-tap / wheel zoom, plus thumbnails + counter for multi-image products.
const ProductLightbox = ({ open, close, index, slides, originEl }: ProductLightboxProps) => {
  const multi = slides.length > 1;
  const cleanupRef = useRef<(() => void) | null>(null);

  const endFlight = () => {
    cleanupRef.current?.();
    cleanupRef.current = null;
  };

  useEffect(() => endFlight, []);

  // Flies a fixed clone of the tapped image into the current slide's rect, hiding the real slide until it lands.
  const startFlight = () => {
    endFlight();
    const origin = originEl;
    if (!origin?.isConnected || !origin.naturalWidth) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const slide = document.querySelector<HTMLElement>(".yarl__portal .yarl__slide_current");
    if (!slide) return;
    const target = slide.querySelector<HTMLImageElement>("img.yarl__slide_image");
    const nw = origin.naturalWidth;
    const nh = origin.naturalHeight;
    const from = fitContain(origin.getBoundingClientRect(), nw, nh);
    const to =
      target?.complete && target.naturalWidth
        ? fitContain(target.getBoundingClientRect(), target.naturalWidth, target.naturalHeight)
        : fitContain(slide.getBoundingClientRect(), nw, nh);
    if (!from.width || !to.width) return;

    const clone = document.createElement("img");
    clone.src = origin.currentSrc || origin.src;
    clone.alt = "";
    clone.setAttribute("aria-hidden", "true");
    Object.assign(clone.style, {
      position: "fixed",
      left: `${to.left}px`,
      top: `${to.top}px`,
      width: `${to.width}px`,
      height: `${to.height}px`,
      objectFit: "contain",
      transformOrigin: "0 0",
      pointerEvents: "none",
      zIndex: "10000",
      willChange: "transform",
    });
    document.body.appendChild(clone);
    slide.style.opacity = "0";

    let done = false;
    let timer = 0;
    const finish = () => {
      if (done) return;
      done = true;
      window.clearTimeout(timer);
      target?.removeEventListener("load", finish);
      slide.style.opacity = "";
      clone.remove();
    };
    cleanupRef.current = finish;

    const anim = clone.animate(
      [
        {
          transform: `translate(${from.left - to.left}px, ${from.top - to.top}px) scale(${from.width / to.width}, ${from.height / to.height})`,
        },
        { transform: "none" },
      ],
      { duration: FLIGHT_MS, easing: EASE },
    );
    anim.onfinish = () => {
      // Hold the clone until the full-size slide image has loaded (capped).
      if (!target || (target.complete && target.naturalWidth)) return finish();
      target.addEventListener("load", finish);
      timer = window.setTimeout(finish, 1200);
    };
  };

  return (
    <Lightbox
      open={open}
      close={close}
      index={index}
      slides={slides}
      plugins={multi ? [Zoom, Thumbnails, Counter] : [Zoom]}
      animation={{
        fade: 250,
        swipe: 300,
        zoom: 300,
        easing: { fade: "ease", swipe: EASE, navigation: EASE },
      }}
      on={{
        entering: () => requestAnimationFrame(startFlight),
        exiting: endFlight,
      }}
      zoom={{
        maxZoomPixelRatio: 3,
        zoomInMultiplier: 2,
        doubleTapDelay: 300,
        doubleClickDelay: 300,
        scrollToZoom: true,
      }}
      thumbnails={{ width: 64, height: 64, border: 1, borderRadius: 8, padding: 2, gap: 8, imageFit: "contain" }}
      carousel={{ finite: !multi }}
      controller={{ closeOnBackdropClick: true }}
      styles={{
        container: { backgroundColor: "#000000e6" },
        thumbnailsContainer: { backgroundColor: "#000000b3" },
        thumbnail: { backgroundColor: "#ffffff" },
      }}
    />
  );
};

export default ProductLightbox;
