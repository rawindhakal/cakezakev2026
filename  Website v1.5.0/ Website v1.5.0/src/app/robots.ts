import type { MetadataRoute } from "next";
import { isDemoModeServer } from "@/api/serverApi";

// Generated from NEXT_PUBLIC_BASE_URL so each white-label deploy's Sitemap
// line points at its own domain. Demo mode disallows all crawling.
export default async function robots(): Promise<MetadataRoute.Robots> {
  const base = (process.env.NEXT_PUBLIC_BASE_URL || "").replace(/\/+$/, "");

  if (await isDemoModeServer()) {
    return {
      rules: {
        userAgent: "*",
        disallow: "/",
      },
    };
  }

  return {
    rules: {
      userAgent: "*",
      allow: "/",
    },
    sitemap: `${base}/sitemap.xml`,
  };
}
