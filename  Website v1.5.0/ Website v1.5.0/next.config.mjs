
let apiHost = "";
try {
  apiHost = new URL(process.env.NEXT_PUBLIC_API_URL).hostname;
} catch {
  console.warn("[next.config] NEXT_PUBLIC_API_URL missing or invalid");
}

const apex = (() => {
  if (!apiHost) return "";
  const labels = apiHost.split(".");
  return labels.length >= 2 ? labels.slice(-2).join(".") : apiHost;
})();

const IMAGE_PATHS = ["/storage/**", "/public/storage/**", "/images/**"];

const imageHosts = new Set();
if (apex) imageHosts.add(`**.${apex}`);
if (apiHost) imageHosts.add(apiHost);

const remotePatterns = [...imageHosts].flatMap((hostname) =>
  IMAGE_PATHS.map((pathname) => ({
    protocol: "https",
    hostname,
    port: "",
    pathname,
  })),
);

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Remove console.log in production (keep error/warn).
  compiler: {
    removeConsole:
      process.env.NODE_ENV === "production" ? { exclude: ["error", "warn"] } : false,
  },
  // Standalone build for VPS/Docker; copy public/ and .next/static next to server.js. Never enable in dev (public/ returns 400).
  // ...(process.env.NODE_ENV === "production" ? { output: "standalone" } : {}),
  images: {
    // Skip Next's image optimizer (metered on Vercel); images are already webp.
    unoptimized: true,
    formats: ["image/avif", "image/webp"],
    remotePatterns,
    qualities: [70, 75, 95],
    // Max 1920 — no element renders wider.
    deviceSizes: [640, 750, 828, 1080, 1200, 1920],
    // Cache optimized images for 1 day.
    minimumCacheTTL: 86400,
  },

  experimental: {
    scrollRestoration: true,
    // Client router cache. Default dynamic:0 meant every back-navigation to a
    // `ƒ` route refetched its RSC payload and re-ran the server data load —
    // going home → away → home rebuilt the whole page each time.
    staleTimes: {
      dynamic: 30,
      static: 300,
    },
    // Tree-shake icon/animation libraries to only what's imported.
    optimizePackageImports: ["react-icons", "lucide-react", "framer-motion"],
  },
};

// Long cache for static icons (static export sets these in its host config instead).
if (process.env.NEXT_PUBLIC_SEO !== "false") {
  nextConfig.headers = async () => [
    {
      source: "/icons/:path*",
      headers: [
        { key: "Cache-Control", value: "public, max-age=31536000, immutable" },
      ],
    },
    {
      source: "/favicon.webp",
      headers: [
        { key: "Cache-Control", value: "public, max-age=31536000, immutable" },
      ],
    },
  ];
}

// SEO off → static HTML export (no server, so no image optimizer).
if (process.env.NEXT_PUBLIC_SEO === "false") {
  nextConfig.output = "export";
  nextConfig.images.unoptimized = true;
}
export default nextConfig;
