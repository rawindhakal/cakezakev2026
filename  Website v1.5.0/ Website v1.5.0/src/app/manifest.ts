import type { MetadataRoute } from "next";
import { getSettingServer } from "@/api/serverApi";

// Else built once at build time, ignoring live admin PWA edits.
export const dynamic = "force-dynamic";

// PWA name/description/icon from admin settings; env fallbacks.
export default async function manifest(): Promise<MetadataRoute.Manifest> {
  const fallbackName = process.env.NEXT_PUBLIC_WEB_NAME || "App";
  let name = fallbackName;
  let description = process.env.NEXT_PUBLIC_META_TITLE || fallbackName;
  let iconUrl: string | null = null;
  let iconType = "image/png";

  try {
    const res = await getSettingServer({});
    const webSettings = res?.data?.web_settings;
    if (webSettings?.pwa_name) name = webSettings.pwa_name;
    if (webSettings?.pwa_description) description = webSettings.pwa_description;
    // pwa_icon is a /storage/-relative path, not a full URL.
    if (webSettings?.pwa_icon) {
      iconUrl = `${process.env.NEXT_PUBLIC_API_URL}/storage/${webSettings.pwa_icon}`;
      const ext = webSettings.pwa_icon.split(".").pop()?.toLowerCase();
      iconType =
        ext === "webp"
          ? "image/webp"
          : ext === "jpg" || ext === "jpeg"
            ? "image/jpeg"
            : ext === "svg"
              ? "image/svg+xml"
              : "image/png";
    }
  } catch {
    // Use defaults.
  }

  return {
    name,
    short_name: name,
    description,
    start_url: "/",
    scope: "/",
    display: "standalone",
    orientation: "portrait",
    background_color: "#ffffff",
    theme_color: "#000000",
    icons: iconUrl
      ? [
          { src: iconUrl, sizes: "192x192", type: iconType, purpose: "any" },
          { src: iconUrl, sizes: "512x512", type: iconType, purpose: "any" },
        ]
      : [
          {
            src: "/icons/icon-192.png",
            sizes: "192x192",
            type: "image/png",
            purpose: "any",
          },
          {
            src: "/icons/icon-512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "any",
          },
        ],
  };
}
