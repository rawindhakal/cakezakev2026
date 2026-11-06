"use client";

import React, { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import pageNotFound from "@/assets/not_found_images/404.svg";
import { t } from "@/utils/translation";
import Link from "next/link";
import ThemedSvg from "@/components/notfound/ThemedSvg";
import { RESERVED_ROUTES } from "@/utils/reservedRoutes";
import { DEFAULT_LANGUAGE } from "@/utils/languageRoutes";

// Safe translation fallback during SSR
const safeT = (key: string, fallback: string) => {
  try {
    const val = t(key);
    return val && val !== key ? val : fallback;
  } catch {
    return fallback;
  }
};

/** Shared 404 UI component. */
const Custom404 = () => {
  const pathname = usePathname();
  // Prevent hydration mismatch by using fallback until mounted
  const [mounted, setMounted] = useState(false);
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- mark mounted state
    setMounted(true);
  }, []);
  const label = (key: string, fallback: string) =>
    mounted ? safeT(key, fallback) : fallback;
  // Build home href preserving language prefix
  const buildHomeHref = () => {
    try {
      const path = pathname || "/";
      const segs = path.split("/").filter(Boolean);
      // Extract valid language prefix
      if (
        segs[0] &&
        /^[a-z]{2,5}$/.test(segs[0]) &&
        segs[0] !== DEFAULT_LANGUAGE &&
        !RESERVED_ROUTES.has(segs[0])
      ) {
        return `/${segs[0]}`;
      }
      return "/";
    } catch {
      // Fallback to root route on error
      return "/";
    }
  };
  return (
    <section className="min-h-screen w-full flex items-center justify-center px-4 py-10">
      <div className="flex flex-col items-center justify-center gap-6 text-center max-w-2xl w-full">
        <ThemedSvg
          src={pageNotFound}
          alt="Page Not found image"
          className="w-full max-w-xl"
        />
        <h1 className="text-3xl md:text-4xl font-bold">
          404 {label("page_not_found", "Page Not Found")}
        </h1>
        <p className="text-lg md:text-xl text-gray-500">
          {label(
            "page_not_found_description",
            "The page you are looking for could not be found.",
          )}
        </p>
        <Link
          href={buildHomeHref()}
          className="primaryBackColor text-white font-semibold text-base px-6 py-2.5 rounded-md mt-2"
        >
          {label("home", "Home")}
        </Link>
      </div>
    </section>
  );
};

export default Custom404;
